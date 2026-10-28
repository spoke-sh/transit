//! Bounded reusable reservations with independent lifetimes. Block headers and
//! alignment waste live inside the one charged reserve. No backing fallback.
//! Allocation/free are serialized; payloads belong exclusively to their callers.
const std = @import("std");
const Self = @This();
pub const granule = 64;
const absent = std.math.maxInt(usize);
const Block = struct {
    size: usize,
    previous: usize,
    next_free: usize = absent,
    prev_free: usize = absent,
    requested: usize = 0,
    alignment: usize = 0,
    allocated: bool = false,
};
comptime {
    std.debug.assert(@sizeOf(Block) <= granule);
}
parent: ?std.mem.Allocator,
buffer: []align(granule) u8,
first_free: usize = 0,
mutex: std.atomic.Mutex = .unlocked,
live_bytes: usize = 0,
occupied_bytes: usize = 0,
peak_occupied_bytes: usize = 0,
reservations: usize = 0,
refusals: usize = 0,

pub fn init(parent: std.mem.Allocator, capacity: usize) !Self {
    if (capacity < granule * 2) return error.InvalidWorkspaceCapacity;
    // Round down rather than silently exceeding a caller's admitted reserve.
    const size = capacity & ~@as(usize, granule - 1);
    // This is backing capacity, not an initialized payload. Allocator.alloc
    // poisons the entire slice in safe builds, faulting in every unused page.
    // The parent still accounts for the full reserve; fromBuffer initializes
    // its metadata and ordinary borrower allocations retain their own poisoning.
    const pointer = parent.rawAlloc(size, .fromByteUnits(granule), @returnAddress()) orelse return error.OutOfMemory;
    const bytes = @as([*]align(granule) u8, @alignCast(pointer))[0..size];
    errdefer parent.free(bytes);
    var self = try fromBuffer(bytes);
    self.parent = parent;
    return self;
}
/// The backing owner accounts for and outlives this slab and all its objects.
/// The caller must hold an exclusive lease on the supplied bytes.
pub fn fromBuffer(bytes: []align(granule) u8) !Self {
    if (bytes.len < granule * 2) return error.InvalidWorkspaceCapacity;
    var self: Self = .{ .parent = null, .buffer = bytes[0 .. bytes.len & ~@as(usize, granule - 1)] };
    self.block(0).* = .{ .size = self.buffer.len, .previous = 0 };
    return self;
}
pub fn deinit(self: *Self) void {
    std.debug.assert(self.live_bytes == 0 and self.occupied_bytes == 0);
    std.crypto.secureZero(u8, self.buffer);
    if (self.parent) |parent| parent.free(self.buffer);
    self.* = undefined;
}
pub fn allocator(self: *Self) std.mem.Allocator {
    return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
}
/// Reassign an idle reserve only after every borrower has joined and freed its
/// reservations. Lifetime high-water accounting survives reuse. Erasure includes
/// freed payloads, padding and old headers before rebuilding the empty free list.
pub fn reset(self: *Self, erase: bool) error{MemoryInUse}!void {
    self.lock();
    defer self.mutex.unlock();
    if (self.live_bytes != 0 or self.occupied_bytes != 0) return error.MemoryInUse;
    if (erase) std.crypto.secureZero(u8, self.buffer);
    self.block(0).* = .{ .size = self.buffer.len, .previous = 0 };
    self.first_free = 0;
}
fn lock(self: *Self) void {
    while (!self.mutex.tryLock()) std.atomic.spinLoopHint();
}
fn block(self: *Self, offset: usize) *Block {
    std.debug.assert(offset <= self.buffer.len - granule and offset % granule == 0);
    return @ptrCast(@alignCast(self.buffer[offset..].ptr));
}
fn round(value: usize, alignment: usize) ?usize {
    const sum = std.math.add(usize, value, alignment - 1) catch return null;
    return sum & ~(alignment - 1);
}
fn removeFree(self: *Self, offset: usize) void {
    const item = self.block(offset);
    std.debug.assert(!item.allocated);
    if (item.prev_free == absent) self.first_free = item.next_free else self.block(item.prev_free).next_free = item.next_free;
    if (item.next_free != absent) self.block(item.next_free).prev_free = item.prev_free;
}
fn insertFree(self: *Self, offset: usize) void {
    const item = self.block(offset);
    item.allocated = false;
    item.requested = 0;
    item.prev_free = absent;
    item.next_free = self.first_free;
    if (self.first_free != absent) self.block(self.first_free).prev_free = offset;
    self.first_free = offset;
}
fn nextPrevious(self: *Self, offset: usize) void {
    const item = self.block(offset);
    const end = offset + item.size;
    if (end != self.buffer.len) self.block(end).previous = item.size;
}
fn allocate(self: *Self, len: usize, alignment: usize) ?[*]u8 {
    self.reservations += 1;
    const size = std.math.add(usize, round(len, granule) orelse return null, granule) catch return null;
    var current = self.first_free;
    while (current != absent) {
        const original = self.block(current).*;
        const base = @intFromPtr(self.buffer.ptr);
        const address = round(base + current + granule, @max(granule, alignment)) orelse return null;
        const offset = address - base - granule;
        const leading = offset - current;
        if (leading > original.size or size > original.size - leading) {
            current = original.next_free;
            continue;
        }
        self.removeFree(current);
        if (leading != 0) {
            self.block(current).* = .{ .size = leading, .previous = original.previous };
            self.insertFree(current);
        }
        self.block(offset).* = .{ .size = size, .previous = if (leading == 0) original.previous else leading, .requested = len, .alignment = alignment, .allocated = true };
        const trailing = original.size - leading - size;
        if (trailing != 0) {
            self.block(offset + size).* = .{ .size = trailing, .previous = size };
            self.insertFree(offset + size);
            self.nextPrevious(offset + size);
        } else self.nextPrevious(offset);
        self.live_bytes += len;
        self.occupied_bytes += size;
        self.peak_occupied_bytes = @max(self.peak_occupied_bytes, self.occupied_bytes);
        return self.buffer.ptr + offset + granule;
    }
    return null;
}
fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    self.lock();
    defer self.mutex.unlock();
    return self.allocate(len, alignment.toByteUnits()) orelse {
        self.refusals += 1;
        return null;
    };
}
fn locate(self: *Self, bytes: []u8, alignment: std.mem.Alignment) usize {
    const offset = @intFromPtr(bytes.ptr) - @intFromPtr(self.buffer.ptr) - granule;
    const item = self.block(offset);
    std.debug.assert(item.allocated and item.requested == bytes.len and item.alignment == alignment.toByteUnits());
    return offset;
}
fn coalesce(self: *Self, original: usize) void {
    var offset = original;
    var item = self.block(offset);
    item.allocated = false;
    if (item.previous != 0) {
        const before = offset - item.previous;
        if (!self.block(before).allocated) {
            self.removeFree(before);
            self.block(before).size += item.size;
            offset = before;
            item = self.block(offset);
        }
    }
    const after = offset + item.size;
    if (after != self.buffer.len and !self.block(after).allocated) {
        self.removeFree(after);
        item.size += self.block(after).size;
    }
    self.nextPrevious(offset);
    self.insertFree(offset);
}
fn resize(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, _: usize) bool {
    const self: *Self = @ptrCast(@alignCast(context));
    self.lock();
    defer self.mutex.unlock();
    const offset = self.locate(bytes, alignment);
    const item = self.block(offset);
    const size = std.math.add(usize, round(len, granule) orelse return false, granule) catch return false;
    const previous_size = item.size;
    if (size > item.size) {
        const after = offset + item.size;
        if (after == self.buffer.len or self.block(after).allocated or size - item.size > self.block(after).size) return false;
        const available = self.block(after).size;
        self.removeFree(after);
        item.size += available;
    }
    if (size < item.size) {
        const remainder = item.size - size;
        item.size = size;
        self.block(offset + size).* = .{ .size = remainder, .previous = size };
        self.coalesce(offset + size);
    } else self.nextPrevious(offset);
    item.requested = len;
    self.live_bytes = self.live_bytes - bytes.len + len;
    self.occupied_bytes = self.occupied_bytes - previous_size + item.size;
    self.peak_occupied_bytes = @max(self.peak_occupied_bytes, self.occupied_bytes);
    return true;
}
fn remap(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
    return if (resize(context, bytes, alignment, len, ra)) bytes.ptr else null;
}
fn free(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, _: usize) void {
    const self: *Self = @ptrCast(@alignCast(context));
    self.lock();
    defer self.mutex.unlock();
    const offset = self.locate(bytes, alignment);
    self.live_bytes -= bytes.len;
    self.occupied_bytes -= self.block(offset).size;
    self.coalesce(offset);
}

test "slab admission charges its full reserve without touching unused payload bytes" {
    const t = std.testing;
    var backing: [8192]u8 align(granule) = @splat(0x5a);
    var fixed: std.heap.FixedBufferAllocator = .init(&backing);
    var budget: @import("Budget.zig") = .{ .parent = fixed.allocator(), .limit = backing.len };
    var probe: @import("AllocationProbe.zig") = .{ .parent = budget.allocator() };
    var slab = try init(probe.allocator(), backing.len);
    try t.expectEqual(backing.len, budget.used);
    try t.expectEqual(backing.len, probe.live_bytes);
    try t.expect(std.mem.allEqual(u8, backing[granule..], 0x5a));
    // Reassignment still erases the entire reserve, including unused bytes.
    probe.begin(true);
    try slab.reset(true);
    try t.expect(std.mem.allEqual(u8, backing[granule..], 0));
    try probe.verify();
    slab.deinit();
    try t.expectEqual(0, budget.used);
    try t.expectEqual(0, probe.live_bytes);
}

test "slab retains independent values through varied alignment fragmentation and reuse" {
    const t = std.testing;
    var probe: @import("AllocationProbe.zig") = .{ .parent = t.allocator };
    var slab = try init(probe.allocator(), 128 * 1024);
    defer slab.deinit();
    const a = slab.allocator();
    const Item = struct { bytes: []u8, alignment: std.mem.Alignment, fill: u8 };
    var items: [32]?Item = @splat(null);
    defer for (items) |item| if (item) |value| a.rawFree(value.bytes, value.alignment, @returnAddress());
    probe.begin(true);
    for (0..2000) |i| {
        const index = (i * 13) % items.len;
        if (items[index]) |value| {
            try t.expect(std.mem.allEqual(u8, value.bytes, value.fill));
            a.rawFree(value.bytes, value.alignment, @returnAddress());
            items[index] = null;
        }
        const alignment: std.mem.Alignment = .fromByteUnits(@as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(i % 13)));
        const len = 1 + i * 37 % 2048;
        if (a.rawAlloc(len, alignment, @returnAddress())) |pointer| {
            try t.expect(std.mem.isAligned(@intFromPtr(pointer), alignment.toByteUnits()));
            const bytes = pointer[0..len];
            const fill: u8 = @truncate(i);
            @memset(bytes, fill);
            items[index] = .{ .bytes = bytes, .alignment = alignment, .fill = fill };
        }
        for (items) |item| if (item) |value| try t.expect(std.mem.allEqual(u8, value.bytes, value.fill));
    }
    for (&items) |*item| if (item.*) |value| {
        a.rawFree(value.bytes, value.alignment, @returnAddress());
        item.* = null;
    };
    // Complete coalescing recovers all payload capacity, including headers of
    // previous alignment gaps; the one live block still needs its own header.
    const whole = try a.alignedAlloc(u8, .fromByteUnits(granule), slab.buffer.len - granule);
    a.free(whole);
    try probe.verify();
    try t.expectEqual(slab.buffer.len, probe.live_bytes);
    try t.expectEqual(0, slab.occupied_bytes);
}
test "slab resize preserves adjacent borrowers and recovers trailing space" {
    const t = std.testing;
    var slab = try init(t.allocator, 1024);
    defer slab.deinit();
    const a = slab.allocator();
    var first = try a.dupe(u8, "retained");
    const second = try a.dupe(u8, "neighbor");
    try t.expect(!a.resize(first, 128));
    try t.expectEqualStrings("neighbor", second);
    a.free(second);
    try t.expect(a.resize(first, 512));
    first = first.ptr[0..512];
    try t.expectEqualStrings("retained", first[0..8]);
    try t.expect(a.resize(first, 8));
    first = first.ptr[0..8];
    const tail = try a.alloc(u8, 512);
    a.free(tail);
    a.free(first);
    try t.expectEqual(0, slab.live_bytes);
}

test "borrowed slab lifetime stays inside its exclusive pool lease" {
    const t = std.testing;
    var probe: @import("AllocationProbe.zig") = .{ .parent = t.allocator };
    var pool = try @import("Pool.zig").init(probe.allocator(), &.{4097});
    defer pool.deinit();
    probe.begin(true);
    for (0..100) |_| {
        const lease = try pool.acquire(4097);
        defer lease.release(true) catch unreachable;
        var slab = try fromBuffer(lease.value.owner.buffer);
        defer slab.deinit();
        try t.expectEqual(4096, slab.buffer.len);
        try t.expectError(error.MemoryPoolExhausted, pool.acquire(1));
        const value = try slab.allocator().dupe(u8, "owned until joined");
        slab.allocator().free(value);
        try slab.reset(true);
        try t.expect(std.mem.allEqual(u8, slab.buffer[granule..], 0));
    }
    try probe.verify();
    try t.expectEqual(pool.reservedBytes(), probe.live_bytes);
}

test "idle slab reassignment erases freed payloads without invalidating a borrower" {
    const t = std.testing;
    var probe: @import("AllocationProbe.zig") = .{ .parent = t.allocator };
    var slab = try init(probe.allocator(), 4096);
    defer slab.deinit();
    const a = slab.allocator();
    probe.begin(true);
    for (0..100) |_| {
        {
            const value = try a.alloc(u8, 1024);
            defer a.free(value);
            @memset(value, 0xa5);
            try t.expectError(error.MemoryInUse, slab.reset(true));
            try t.expect(std.mem.allEqual(u8, value, 0xa5));
        }
        try slab.reset(true);
        try t.expect(std.mem.allEqual(u8, slab.buffer[granule..], 0));
        // Allocator.alloc may poison new values in Debug; inspect erasure before
        // acquisition and independently check that the full capacity is reusable.
        const whole = try a.alloc(u8, slab.buffer.len - granule);
        a.free(whole);
    }
    try probe.verify();
    try t.expectEqual(4096, probe.live_bytes);
}

test "slab exhaustion and failed growth preserve live borrowers and retained accounting" {
    const t = std.testing;
    var budget: @import("Budget.zig") = .{ .parent = t.allocator, .limit = 1024 };
    var slab = try init(budget.allocator(), 1024);
    const a = slab.allocator();
    var value = try a.dupe(u8, "unchanged");
    defer a.free(value);
    try t.expectEqual(1024, budget.used);
    try t.expectError(error.OutOfMemory, a.realloc(value, 1024));
    try t.expectEqualStrings("unchanged", value);
    try t.expectEqual(value.len, slab.live_bytes);
    try t.expectEqual(1024, budget.used);
    value = try a.realloc(value, 512);
    try t.expectEqualStrings("unchanged", value[0..9]);
    a.free(value);
    value = &.{};
    try t.expectEqual(0, slab.live_bytes);
    try t.expectEqual(1024, budget.used);
    slab.deinit();
    try t.expectEqual(0, budget.used);
}
