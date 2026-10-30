//! Bounded verified WAL payload cache. Callers serialize access and retain this
//! owner through every borrow. Cache residency confers no read authorization,
//! durable retention or append acceptance; those belong to the partition.
const std = @import("std");
const d = @import("transit_protocol").DataLifecycle;
const Self = @This();

pub const Binding = struct { position: d.Position, content: d.Content };
pub const Options = struct { slots: u16, borrow_slots: u16, slot_bytes: u32, resident_bytes: u64 };
const Slot = struct { binding: ?Binding = null, pins: u32 = 0 };
const Held = struct { serial: u64, slot: usize };

allocator: std.mem.Allocator,
slots: []Slot,
held: []?Held,
slab: []align(64) u8,
stride: usize,
slot_bytes: usize,
next_slot: usize = 0,
next_serial: u64 = 1,
verified: u64 = 0,

pub fn init(allocator: std.mem.Allocator, options: Options) !Self {
    if (options.slots == 0 or options.borrow_slots == 0 or options.slot_bytes == 0 or options.slot_bytes > @import("TransitLog.zig").max_payload_bytes) return error.InvalidTailBudget;
    const stride = std.mem.alignForward(usize, @as(usize, options.slot_bytes) + 64, 64);
    const bytes = std.math.mul(usize, options.slots, stride) catch return error.InvalidTailBudget;
    const metadata = @as(u64, options.slots) * @sizeOf(Slot) + @as(u64, options.borrow_slots) * @sizeOf(?Held);
    if (bytes > options.resident_bytes or metadata > options.resident_bytes - bytes) return error.InvalidTailBudget;
    const slots = try allocator.alloc(Slot, options.slots);
    errdefer allocator.free(slots);
    @memset(slots, .{});
    const held = try allocator.alloc(?Held, options.borrow_slots);
    errdefer allocator.free(held);
    @memset(held, null);
    const slab = try allocator.alignedAlloc(u8, .fromByteUnits(64), bytes);
    return .{ .allocator = allocator, .slots = slots, .held = held, .slab = slab, .stride = stride, .slot_bytes = options.slot_bytes };
}

/// An outstanding borrow prevents destruction as well as eviction.
pub fn deinit(self: *Self) !void {
    for (self.held) |held| if (held != null) return error.OutstandingTailBorrows;
    self.allocator.free(self.slab);
    self.allocator.free(self.held);
    self.allocator.free(self.slots);
    self.* = undefined;
}

fn validate(self: *const Self, binding: Binding) !void {
    try binding.position.validate();
    try binding.content.validate();
    if (binding.position.next_lsn == 0 or binding.content.bytes > self.slot_bytes) return error.InvalidTailBinding;
}

fn find(self: *const Self, binding: Binding) !?usize {
    try self.validate(binding);
    for (self.slots, 0..) |slot, index| if (slot.binding) |present| {
        if (std.meta.eql(present.position, binding.position)) {
            if (!std.meta.eql(present.content, binding.content)) return error.TailContentConflict;
            return index;
        }
    };
    return null;
}

/// On a hit the previously verified bytes remain unchanged. On a miss verify
/// once before replacement, then copy into a reusable aligned slab. Pinning
/// pressure refuses cache admission; it never discards a durable log record.
pub fn admit(self: *Self, binding: Binding, bytes: []const u8) !void {
    try self.validate(binding);
    if (bytes.len != binding.content.bytes) return error.InvalidTailContent;
    if (try self.find(binding) != null) return;
    var destination: ?usize = null;
    for (0..self.slots.len) |distance| {
        const index = (self.next_slot + distance) % self.slots.len;
        if (self.slots[index].pins == 0) {
            destination = index;
            break;
        }
    }
    const index = destination orelse return error.TailCachePinned;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (!std.mem.eql(u8, &digest, &binding.content.sha256)) return error.InvalidTailContent;
    const target = self.slab[index * self.stride ..][0..self.stride];
    // A caller may admit a slice borrowed from a different cache slot.
    std.mem.copyForwards(u8, target[0..bytes.len], bytes);
    @memset(target[bytes.len..][0..64], 0);
    self.slots[index] = .{ .binding = binding };
    self.next_slot = (index + 1) % self.slots.len;
    self.verified +|= 1;
}

pub const Borrow = struct {
    owner: *Self,
    entry: usize,
    serial: u64,

    fn current(self: Borrow) !Held {
        if (self.entry >= self.owner.held.len) return error.InvalidTailBorrow;
        const held = self.owner.held[self.entry] orelse return error.InvalidTailBorrow;
        if (held.serial != self.serial) return error.InvalidTailBorrow;
        return held;
    }

    /// Borrowed bytes remain valid until release. The partition must recheck
    /// current rights after buffering and immediately before disclosure.
    pub fn bytes(self: Borrow) ![]const u8 {
        const held = try self.current();
        const binding = self.owner.slots[held.slot].binding.?;
        return self.owner.slab[held.slot * self.owner.stride ..][0..@intCast(binding.content.bytes)];
    }

    /// Copies of a released handle cannot release a later borrow's pin.
    pub fn release(self: Borrow) !void {
        const held = try self.current();
        self.owner.slots[held.slot].pins -= 1;
        self.owner.held[self.entry] = null;
    }
};

pub fn borrow(self: *Self, binding: Binding) !?Borrow {
    const index = try self.find(binding) orelse return null;
    if (self.next_serial == std.math.maxInt(u64)) return error.TailBorrowIdentityExhausted;
    for (self.held, 0..) |*entry, i| if (entry.* == null) {
        entry.* = .{ .serial = self.next_serial, .slot = index };
        self.slots[index].pins += 1;
        self.next_serial += 1;
        return .{ .owner = self, .entry = i, .serial = entry.*.?.serial };
    };
    return error.TailBorrowLimitExceeded;
}
