//! Concurrent hierarchical reservations. These count capacity, not logical
//! values. Parent chains are immutable, acyclic and outlive every reservation.
const std = @import("std");
const Self = @This();
limit: usize,
parent: ?*Self = null,
used: std.atomic.Value(usize) = .init(0),
peak: std.atomic.Value(usize) = .init(0),
refusals: std.atomic.Value(usize) = .init(0),

pub fn reserve(self: *Self, bytes: usize) error{MemoryBudgetExceeded}!void {
    var previous = self.used.load(.acquire);
    while (true) {
        if (bytes > self.limit - previous) {
            _ = self.refusals.fetchAdd(1, .monotonic);
            return error.MemoryBudgetExceeded;
        }
        previous = self.used.cmpxchgWeak(previous, previous + bytes, .acq_rel, .acquire) orelse break;
    }
    if (self.parent) |parent| parent.reserve(bytes) catch |err| {
        _ = self.used.fetchSub(bytes, .acq_rel);
        _ = self.refusals.fetchAdd(1, .monotonic);
        return err;
    };
    _ = self.peak.fetchMax(previous + bytes, .monotonic);
}

/// A stable, concurrent backing allocator for independently lived borrowers.
/// It retains no allocation-local state. The adapter, quota and parent must
/// outlive every allocation, including arenas returned by a completed call.
pub const Allocator = struct {
    parent: std.mem.Allocator,
    quota: *Self,

    /// Typed construction can preserve configured refusal separately from a
    /// backing allocation failure. Free with allocator().destroy as usual.
    pub fn create(self: *Allocator, comptime T: type) !*T {
        try self.quota.reserve(@sizeOf(T));
        return self.parent.create(T) catch |err| {
            self.quota.release(@sizeOf(T));
            return err;
        };
    }

    pub fn allocator(self: *Allocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *Allocator = @ptrCast(@alignCast(raw));
        self.quota.reserve(len) catch return null;
        return self.parent.rawAlloc(len, alignment, ra) orelse {
            self.quota.release(len);
            return null;
        };
    }
    fn grow(self: *Allocator, before: usize, after: usize) bool {
        if (after > before) self.quota.reserve(after - before) catch return false;
        return true;
    }
    fn rollback(self: *Allocator, before: usize, after: usize) void {
        if (after > before) self.quota.release(after - before);
    }
    fn shrink(self: *Allocator, before: usize, after: usize) void {
        if (before > after) self.quota.release(before - after);
    }
    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) bool {
        const self: *Allocator = @ptrCast(@alignCast(raw));
        if (!self.grow(bytes.len, len)) return false;
        if (!self.parent.rawResize(bytes, alignment, len, ra)) {
            self.rollback(bytes.len, len);
            return false;
        }
        self.shrink(bytes.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
        const self: *Allocator = @ptrCast(@alignCast(raw));
        if (!self.grow(bytes.len, len)) return null;
        const result = self.parent.rawRemap(bytes, alignment, len, ra) orelse {
            self.rollback(bytes.len, len);
            return null;
        };
        self.shrink(bytes.len, len);
        return result;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *Allocator = @ptrCast(@alignCast(raw));
        self.parent.rawFree(bytes, alignment, ra);
        self.quota.release(bytes.len);
    }
};

test "quota allocator retains independent arenas and rolls back backing failure" {
    const t = std.testing;
    var quota: Self = .{ .limit = 4096 };
    var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    var adapter: Allocator = .{ .parent = failing.allocator(), .quota = &quota };
    try t.expectError(error.OutOfMemory, adapter.allocator().alloc(u8, 1));
    try t.expectEqual(0, quota.used.load(.acquire));
    try t.expectEqual(0, quota.refusals.load(.acquire));
    adapter.parent = t.allocator;
    var first: std.heap.ArenaAllocator = .init(adapter.allocator());
    var second: std.heap.ArenaAllocator = .init(adapter.allocator());
    const retained = try first.allocator().dupe(u8, "original result");
    _ = try second.allocator().alloc(u8, 1024);
    try t.expectError(error.OutOfMemory, adapter.allocator().alloc(u8, 4096));
    try t.expectEqual(1, quota.refusals.load(.acquire));
    second.deinit();
    try t.expectEqualStrings("original result", retained);
    try t.expect(quota.used.load(.acquire) != 0);
    first.deinit();
    try t.expectEqual(0, quota.used.load(.acquire));
}
pub fn release(self: *Self, bytes: usize) void {
    const previous = self.used.fetchSub(bytes, .acq_rel);
    std.debug.assert(bytes <= previous);
    if (self.parent) |parent| parent.release(bytes);
}

test "quota allocator growth rollback and shrink preserve the exact backing charge" {
    const t = std.testing;
    var quota: Self = .{ .limit = 64 };
    var buffer: [128]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(&buffer);
    var adapter: Allocator = .{ .parent = fixed.allocator(), .quota = &quota };
    const a = adapter.allocator();
    var bytes = try a.alloc(u8, 32);
    @memset(bytes, 17);
    try t.expect(!a.resize(bytes, 65));
    try t.expectEqual(32, quota.used.load(.acquire));
    bytes = a.remap(bytes, 48).?;
    try t.expectEqual(48, quota.used.load(.acquire));
    try t.expect(std.mem.allEqual(u8, bytes[0..32], 17));
    // A backing failure rolls back a permitted growth without classifying it
    // as quota exhaustion. The original bytes remain owned and charged.
    const blocker = try fixed.allocator().alloc(u8, 80);
    try t.expect(a.remap(bytes, 64) == null);
    try t.expectEqual(48, quota.used.load(.acquire));
    try t.expectEqual(1, quota.refusals.load(.acquire));
    fixed.allocator().free(blocker);
    try t.expect(a.resize(bytes, 16));
    bytes = bytes[0..16];
    try t.expectEqual(16, quota.used.load(.acquire));
    a.free(bytes);
    try t.expectEqual(0, quota.used.load(.acquire));
}

test "typed quota allocation distinguishes refusal from backing failure" {
    const t = std.testing;
    var quota: Self = .{ .limit = 32 };
    var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    var adapter: Allocator = .{ .parent = failing.allocator(), .quota = &quota };
    try t.expectError(error.MemoryBudgetExceeded, adapter.create([33]u8));
    try t.expectError(error.OutOfMemory, adapter.create([32]u8));
    try t.expectEqual(0, quota.used.load(.acquire));
    try t.expectEqual(1, quota.refusals.load(.acquire));
    adapter.parent = t.allocator;
    const value = try adapter.create([32]u8);
    try t.expectEqual(32, quota.used.load(.acquire));
    adapter.allocator().destroy(value);
    try t.expectEqual(0, quota.used.load(.acquire));
}

test "hierarchical refusal rolls back only the attempted reservation" {
    const t = std.testing;
    var host: Self = .{ .limit = 96 };
    var first: Self = .{ .parent = &host, .limit = 80 };
    var second: Self = .{ .parent = &host, .limit = 80 };
    try first.reserve(64);
    try t.expectError(error.MemoryBudgetExceeded, second.reserve(40));
    try t.expectEqual(0, second.used.load(.acquire));
    try t.expectEqual(64, host.used.load(.acquire));
    try second.reserve(32);
    first.release(64);
    second.release(32);
    try t.expectEqual(0, host.used.load(.acquire));
    try t.expectEqual(96, host.peak.load(.acquire));
}
fn contend(quota: *Self) void {
    for (0..1000) |_| {
        quota.reserve(8) catch continue;
        quota.release(8);
    }
}
test "concurrent child reservations preserve the shared parent ceiling" {
    var parent: Self = .{ .limit = 16 };
    var children: [4]Self = @splat(.{ .parent = &parent, .limit = 8 });
    var threads: [4]std.Thread = undefined;
    var started: usize = 0;
    defer for (threads[0..started]) |thread| thread.join();
    for (&children, &threads) |*child, *thread| {
        thread.* = try std.Thread.spawn(.{}, contend, .{child});
        started += 1;
    }
    for (threads) |thread| thread.join();
    started = 0;
    try std.testing.expectEqual(0, parent.used.load(.acquire));
    try std.testing.expect(parent.peak.load(.acquire) <= parent.limit);
}
