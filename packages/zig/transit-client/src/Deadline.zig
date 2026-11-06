//! Process-local awake-clock cap. Never serialized or used as durable evidence.
const std = @import("std");
const Self = @This();

until: std.Io.Clock.Timestamp,

pub fn init(io: std.Io, milliseconds: u32, parent: ?Self) Self {
    const value: Self = .{ .until = .fromNow(io, .{ .clock = .awake, .raw = .fromMilliseconds(milliseconds) }) };
    return if (parent) |cap| value.limit(cap) else value;
}

pub fn limit(self: Self, other: Self) Self {
    std.debug.assert(self.until.clock == .awake and other.until.clock == .awake);
    return if (self.until.compare(.lt, other.until)) self else other;
}

pub fn check(self: Self, io: std.Io) error{AuthorityTimeout}!void {
    if (self.until.durationFromNow(io).raw.nanoseconds <= 0) return error.AuthorityTimeout;
}

pub fn timeout(self: Self) std.Io.Timeout {
    return .{ .deadline = self.until };
}

test "child budgets preserve the earlier exact cap including equality" {
    const Clock = struct {
        fn now(raw: ?*anyopaque, clock: std.Io.Clock) std.Io.Timestamp {
            std.debug.assert(clock == .awake);
            return .{ .nanoseconds = @as(*i96, @ptrCast(@alignCast(raw.?))).* };
        }
    };
    var now: i96 = 7;
    var vtable = std.testing.io.vtable.*;
    vtable.now = Clock.now;
    const io: std.Io = .{ .userdata = &now, .vtable = &vtable };
    const parent: Self = .{ .until = .{ .clock = .awake, .raw = .{ .nanoseconds = 2000008 } } };
    try std.testing.expectEqual(1000007, init(io, 1, parent).until.raw.nanoseconds);
    try std.testing.expectEqual(parent, init(io, 3, parent));
    now = 2000007;
    const child = init(io, 3, parent);
    try std.testing.expectEqual(parent, child);
    try child.check(io);
    now += 1;
    try std.testing.expectError(error.AuthorityTimeout, child.check(io));
    try std.testing.expectError(error.AuthorityTimeout, init(io, 3, parent).check(io));
    try std.testing.expectEqual(parent.until, child.timeout().deadline);
}
