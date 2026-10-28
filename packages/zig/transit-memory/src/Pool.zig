//! Concurrent admission into fixed size-class workspaces. Slot contents have one
//! borrower; callers join all work and release leases before destroying a pool.
const std = @import("std");
const Workspace = @import("Workspace.zig");
const Self = @This();
parent: std.mem.Allocator,
slots: []Workspace,
backing: []align(Workspace.alignment) u8,
mutex: std.atomic.Mutex = .unlocked,

pub fn init(parent: std.mem.Allocator, capacities: []const usize) !Self {
    if (capacities.len == 0) return error.InvalidWorkspaceCapacity;
    var total: usize = 0;
    for (capacities) |capacity| {
        if (capacity == 0) return error.InvalidWorkspaceCapacity;
        total = try std.math.add(usize, total, try aligned(capacity));
    }
    const slots = try parent.alloc(Workspace, capacities.len);
    errdefer parent.free(slots);
    const backing = try parent.alignedAlloc(u8, .fromByteUnits(Workspace.alignment), total);
    errdefer parent.free(backing);
    var offset: usize = 0;
    for (slots, capacities) |*slot, capacity| {
        slot.* = .fromBuffer(@alignCast(backing[offset..][0..capacity]));
        offset += try aligned(capacity);
    }
    return .{ .parent = parent, .slots = slots, .backing = backing };
}
fn aligned(capacity: usize) !usize {
    return (try std.math.add(usize, capacity, Workspace.alignment - 1)) & ~@as(usize, Workspace.alignment - 1);
}
fn lock(self: *Self) void {
    while (!self.mutex.tryLock()) std.atomic.spinLoopHint();
}
pub fn reservedBytes(self: *const Self) usize {
    return self.backing.len + self.slots.len * @sizeOf(Workspace);
}
pub fn acquire(self: *Self, minimum: usize) !Lease {
    self.lock();
    defer self.mutex.unlock();
    var best: ?usize = null;
    for (self.slots, 0..) |*slot, index| {
        if (slot.active or slot.buffer.len < minimum) continue;
        if (best == null or slot.buffer.len < self.slots[best.?].buffer.len) best = index;
    }
    const index = best orelse return error.MemoryPoolExhausted;
    return .{ .pool = self, .value = try self.slots[index].acquire() };
}
pub const Lease = struct {
    pool: *Self,
    value: Workspace.Lease,
    pub fn allocator(self: Lease) !std.mem.Allocator {
        self.pool.lock();
        defer self.pool.mutex.unlock();
        return self.value.allocator();
    }
    pub fn reset(self: *Lease) !void {
        self.pool.lock();
        defer self.pool.mutex.unlock();
        try self.value.reset();
    }
    pub fn release(self: Lease, erase: bool) !void {
        self.pool.lock();
        defer self.pool.mutex.unlock();
        try self.value.release(erase);
    }
};
pub fn deinit(self: *Self) void {
    for (self.slots) |*slot| slot.deinit();
    self.parent.free(self.backing);
    self.parent.free(self.slots);
    self.* = undefined;
}

test "pool reuses the smallest fitting slot and retains independent borrowers" {
    const t = std.testing;
    var probe: @import("AllocationProbe.zig") = .{ .parent = t.allocator };
    var pool = try init(probe.allocator(), &.{ 1024, 64, 256 });
    defer pool.deinit();
    probe.begin(true);
    for (0..100) |_| {
        const small = try pool.acquire(32);
        const data = try (try small.allocator()).dupe(u8, "still retained");
        const middle = try pool.acquire(100);
        try t.expectEqual(256, middle.value.owner.buffer.len);
        try middle.release(false);
        const large = try pool.acquire(300);
        try t.expectError(error.MemoryPoolExhausted, pool.acquire(300));
        try t.expectEqualStrings("still retained", data);
        try small.release(false);
        try large.release(false);
        try t.expectError(error.StaleMemoryLease, small.release(false));
    }
    try probe.verify();
    try t.expectEqual(pool.reservedBytes(), probe.live_bytes);
}
fn failures(a: std.mem.Allocator) !void {
    var pool = try init(a, &.{ 128, 512 });
    defer pool.deinit();
    const lease = try pool.acquire(100);
    defer lease.release(false) catch unreachable;
    _ = try (try lease.allocator()).alloc(u8, 100);
}
test "pool initialization failures release every backing allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, failures, .{});
}
