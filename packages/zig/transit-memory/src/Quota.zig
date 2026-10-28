//! Concurrent hierarchical reservations. These count capacity, not logical
//! values. Parent chains are immutable, acyclic and outlive every reservation.
const std = @import("std");
const Self = @This();
limit: usize,
parent: ?*Self = null,
used: std.atomic.Value(usize) = .init(0),
peak: std.atomic.Value(usize) = .init(0),

pub fn reserve(self: *Self, bytes: usize) error{MemoryBudgetExceeded}!void {
    var previous = self.used.load(.acquire);
    while (true) {
        if (bytes > self.limit - previous) return error.MemoryBudgetExceeded;
        previous = self.used.cmpxchgWeak(previous, previous + bytes, .acq_rel, .acquire) orelse break;
    }
    if (self.parent) |parent| parent.reserve(bytes) catch |err| {
        _ = self.used.fetchSub(bytes, .acq_rel);
        return err;
    };
    _ = self.peak.fetchMax(previous + bytes, .monotonic);
}
pub fn release(self: *Self, bytes: usize) void {
    const previous = self.used.fetchSub(bytes, .acq_rel);
    std.debug.assert(bytes <= previous);
    if (self.parent) |parent| parent.release(bytes);
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
