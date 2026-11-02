//! Bounded private object derivation for one transition. New pages/containers
//! remain in reusable memory until persist() stages them in the real provider.
//! Recovery can derive the same roots without writing or requiring intermediate
//! objects that never belonged to an accepted root. This supplies no acceptance.
const std = @import("std");
const Objects = @import("TransitObjectStore.zig");
const Self = @This();
const vacant = std.math.maxInt(u32);
const Entry = struct {
    key_from: u32,
    key_len: u16,
    from: u32,
    len: u32,
    digest: [32]u8,
    selected: u8 = 0,
    examined: u8 = 0,
    expected: [32]u8 = undefined,
    next_pending: u32 = vacant,
    fn metadata(self: Entry) Objects.ObjectMeta {
        return .{ .size = self.len, .sha256 = self.digest };
    }
};
pub const Options = struct { bytes: usize, objects: u32, resident_bytes: usize };

allocator: std.mem.Allocator,
underlying: Objects.ObjectStore,
buffer: []u8,
entries: []Entry,
slots: []u32,
used: usize = 0,
count: u32 = 0,
first_pending: u32 = vacant,
last_pending: u32 = vacant,

pub fn init(allocator: std.mem.Allocator, underlying: Objects.ObjectStore, options: Options) !Self {
    if (options.bytes == 0 or options.bytes > 64 * 1024 * 1024 or options.objects == 0 or options.objects > 65536) return error.InvalidCandidateObjectBudget;
    const capacity = try std.math.ceilPowerOfTwo(usize, @as(usize, options.objects) * 2);
    const resident = options.bytes + @as(usize, options.objects) * @sizeOf(Entry) + capacity * @sizeOf(u32);
    if (resident > options.resident_bytes) return error.InvalidCandidateObjectBudget;
    const buffer = try allocator.alloc(u8, options.bytes);
    errdefer allocator.free(buffer);
    const entries = try allocator.alloc(Entry, options.objects);
    errdefer allocator.free(entries);
    const slots = try allocator.alloc(u32, capacity);
    @memset(slots, vacant);
    return .{ .allocator = allocator, .underlying = underlying, .buffer = buffer, .entries = entries, .slots = slots };
}
pub fn deinit(self: *Self) void {
    self.allocator.free(self.slots);
    self.allocator.free(self.entries);
    self.allocator.free(self.buffer);
    self.* = undefined;
}
pub fn residentBytes(self: Self) usize {
    return self.buffer.len + self.entries.len * @sizeOf(Entry) + self.slots.len * @sizeOf(u32);
}
/// The owner discards any derived TreeStore cache before using an abandoned
/// root or a different base. No borrowed object bytes escape this adapter.
pub fn reset(self: *Self, underlying: Objects.ObjectStore) !void {
    if (underlying.context == @as(*anyopaque, @ptrCast(self)) and underlying.vtable == &vtable) return error.InvalidCandidateObjectBase;
    self.underlying = underlying;
    self.used = 0;
    self.count = 0;
    self.first_pending = vacant;
    self.last_pending = vacant;
    @memset(self.slots, vacant);
}
fn key(self: Self, entry: Entry) []const u8 {
    return self.buffer[entry.key_from..][0..entry.key_len];
}
fn bytes(self: Self, entry: Entry) []const u8 {
    return self.buffer[entry.from..][0..entry.len];
}
fn slot(self: Self, name: []const u8) !usize {
    var at: usize = @as(usize, @truncate(std.hash.Wyhash.hash(0, name))) & (self.slots.len - 1);
    for (0..self.slots.len) |_| {
        const index = self.slots[at];
        if (index == vacant or std.mem.eql(u8, self.key(self.entries[index]), name)) return at;
        at = (at + 1) & (self.slots.len - 1);
    }
    return error.CandidateObjectBudgetExceeded;
}
pub fn objectStore(self: *Self) Objects.ObjectStore {
    return .{ .context = self, .vtable = &vtable };
}
/// Classification only: presence in this private overlay is never evidence of
/// provider persistence. Conservatively classify a failed lookup as private.
pub fn contains(self: *Self, name: []const u8) bool {
    const at = self.slot(name) catch return true;
    return self.slots[at] != vacant;
}

/// A traversal only marks objects created in this candidate. Existing immutable
/// objects cannot reference a newly derived object, so the owner can stop there.
/// Eight independent domains allow one object to be interpreted by more than
/// one typed walker. The intrusive queue reuses the budgeted entry allocation.
pub fn beginSelection(self: *Self) void {
    for (self.entries[0..self.count]) |*entry| {
        entry.selected = 0;
        entry.examined = 0;
        entry.next_pending = vacant;
    }
    self.first_pending = vacant;
    self.last_pending = vacant;
}
pub fn select(self: *Self, name: []const u8, domain: u3, expected: [32]u8) !void {
    const index = self.slots[try self.slot(name)];
    if (index == vacant) return;
    const entry = &self.entries[index];
    const mask = @as(u8, 1) << domain;
    if (entry.selected != 0 and !std.mem.eql(u8, &entry.expected, &expected)) return error.InvalidCandidateObject;
    if (entry.selected & mask != 0) return;
    const queued = entry.selected != entry.examined;
    entry.selected |= mask;
    entry.expected = expected;
    if (!queued) {
        if (self.last_pending != vacant) self.entries[self.last_pending].next_pending = index else self.first_pending = index;
        self.last_pending = index;
    }
}
pub const Selected = struct { name: []const u8, digest: [32]u8, expected: [32]u8, domain: u3 };
pub fn nextSelected(self: *Self) ?Selected {
    if (self.first_pending == vacant) return null;
    const index = self.first_pending;
    const entry = &self.entries[index];
    const pending = entry.selected & ~entry.examined;
    const domain: u3 = @intCast(@ctz(pending));
    entry.examined |= @as(u8, 1) << domain;
    if (entry.selected == entry.examined) {
        self.first_pending = entry.next_pending;
        entry.next_pending = vacant;
        if (self.first_pending == vacant) self.last_pending = vacant;
    }
    return .{ .name = self.key(entry.*), .digest = entry.digest, .expected = entry.expected, .domain = domain };
}
pub fn isSelected(self: *Self, name: []const u8) bool {
    // A failed classification can retain extra staging work, never omit it.
    const index = self.slots[self.slot(name) catch return true];
    return index != vacant and self.entries[index].selected != 0;
}
/// Success stages every private object durably; only the owner's subsequent
/// fenced WAL publication can accept the derived roots. On failure, retain the
/// original operation and retry these same immutable objects if needed.
pub fn persist(self: *Self) !void {
    return self.persistSelected(struct {
        pub fn keep(_: @This(), _: []const u8) bool {
            return true;
        }
    }{});
}

/// The owner may exclude intermediate artifacts proven unreachable from every
/// accepted reference in this candidate. This never deletes existing objects;
/// it is not a substitute for the retained storage graph's collection authority.
pub fn persistSelected(self: *Self, selection: anytype) !void {
    var batch: [Objects.max_put_batch]Objects.ImmutablePut = undefined;
    var count: usize = 0;
    for (self.entries[0..self.count]) |entry| {
        if (!selection.keep(self.key(entry))) continue;
        batch[count] = .{ .key = self.key(entry), .bytes = self.bytes(entry), .sha256 = entry.digest };
        count += 1;
        if (count == batch.len) {
            try self.persistBatch(batch[0..count]);
            count = 0;
        }
    }
    if (count != 0) try self.persistBatch(batch[0..count]);
}
fn persistBatch(self: *Self, batch: []const Objects.ImmutablePut) !void {
    var metadata: [Objects.max_put_batch]Objects.ObjectMeta = undefined;
    try self.underlying.putImmutableBatch(batch, metadata[0..batch.len]);
    for (batch, metadata[0..batch.len]) |item, stored| {
        if (stored.size != item.bytes.len or !std.mem.eql(u8, &stored.sha256, &item.sha256)) return error.InvalidCandidateObject;
    }
}
fn put(ctx: *anyopaque, name: []const u8, value: []const u8, digest: [32]u8) !Objects.ObjectMeta {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const at = try self.slot(name);
    const index = self.slots[at];
    if (index != vacant) {
        const entry = self.entries[index];
        if (!std.mem.eql(u8, &entry.digest, &digest) or !std.mem.eql(u8, self.bytes(entry), value)) return error.ImmutableObjectConflict;
        return entry.metadata();
    }
    if (self.count == self.entries.len or name.len > self.buffer.len - self.used or value.len > self.buffer.len - self.used - name.len) return error.CandidateObjectBudgetExceeded;
    const entry: Entry = .{ .key_from = @intCast(self.used), .key_len = @intCast(name.len), .from = @intCast(self.used + name.len), .len = @intCast(value.len), .digest = digest };
    @memcpy(self.buffer[self.used..][0..name.len], name);
    @memcpy(self.buffer[self.used + name.len ..][0..value.len], value);
    self.entries[self.count] = entry;
    self.slots[at] = self.count;
    self.count += 1;
    self.used += name.len + value.len;
    return entry.metadata();
}
fn head(ctx: *anyopaque, name: []const u8) !?Objects.ObjectMeta {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const index = self.slots[try self.slot(name)];
    return if (index == vacant) self.underlying.head(name) else self.entries[index].metadata();
}
fn get(ctx: *anyopaque, name: []const u8, offset: u64, length: u32, out: []u8) ![]const u8 {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const index = self.slots[try self.slot(name)];
    if (index == vacant) return self.underlying.getRange(name, offset, length, out);
    const value = self.bytes(self.entries[index]);
    if (offset > value.len) return error.InvalidObjectRange;
    const size = @min(length, value.len - @as(usize, @intCast(offset)));
    @memcpy(out[0..size], value[@intCast(offset)..][0..size]);
    return out[0..size];
}
fn conditional(_: *anyopaque, _: []const u8, _: Objects.Condition, _: []const u8) !bool {
    return error.CandidateMutationUnsupported;
}
fn getObject(ctx: *anyopaque, name: []const u8, out: []u8) !?Objects.ObjectMeta {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const index = self.slots[try self.slot(name)];
    if (index == vacant) return self.underlying.getObject(name, out);
    const value = self.bytes(self.entries[index]);
    if (value.len > out.len) return error.BufferTooSmall;
    @memcpy(out[0..value.len], value);
    return self.entries[index].metadata();
}
fn delete(_: *anyopaque, _: []const u8) !void {
    return error.CandidateMutationUnsupported;
}
const vtable: Objects.ObjectStore.VTable = .{ .putImmutable = put, .putConditional = conditional, .getRange = get, .getObject = getObject, .head = head, .delete = delete };
