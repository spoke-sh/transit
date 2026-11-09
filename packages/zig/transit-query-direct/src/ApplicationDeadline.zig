//! One original invocation's absolute deadline, conservatively projected onto
//! a live worker's monotonic clock. Rechecks can only shorten its local budget.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const Self = @This();

original: p.StreamQueue.ClaimReceipt,
absolute_ms: ?u64,
local_until_ms: u64,
last_local_ms: u64,
last_upper_ms: u64,

/// The caller has verified this original native claim. A later effect or worker
/// must reuse it, including after input ACK; local task admission is not origin.
pub fn init(original: p.StreamQueue.ClaimReceipt, deadline: ?[]const u8, now_ms: u64, timeout_ms: u32, request_until_ms: u64) !Self {
    try original.validate();
    if (original.rows != 1 or timeout_ms == 0) return error.InvalidApplicationDeadline;
    const absolute = if (deadline) |text|
        std.math.add(u64, original.observed_ms, try q.fuze.ApplicationProgram.deadlineMilliseconds(text)) catch return error.InvalidApplicationDeadline
    else
        null;
    const local_until = @min(request_until_ms, std.math.add(u64, now_ms, timeout_ms) catch return error.InvalidApplicationDeadline);
    if (local_until <= now_ms) return error.ApplicationReservationExpired;
    return .{ .original = original, .absolute_ms = absolute, .local_until_ms = local_until, .last_local_ms = now_ms, .last_upper_ms = original.observed_ms };
}

/// before_ms is sampled BEFORE requesting native time. Charging the whole RPC
/// duration avoids extending a deadline with transit, scheduling or TLS delay.
/// The observation is current public Queue state, never a client wall clock.
pub fn observe(self: *Self, observation: p.QueueRead.TimeObservation, before_ms: u64, after_ms: u64) !u32 {
    try observation.validate();
    if (before_ms < self.last_local_ms or after_ms < before_ms) return error.ClockUnavailable;
    if (!std.meta.eql(observation.cut.target, self.original.claim.target) or
        observation.cut.accepted.partition != self.original.accepted.partition or
        observation.cut.accepted.next_lsn < self.original.accepted.next_lsn) return error.InvalidQueueResponse;
    if (observation.time.latest_ms < self.last_upper_ms or
        observation.floor_ms == null or observation.floor_ms.? < self.original.observed_ms) return error.LogTimeRegression;
    self.last_upper_ms = observation.time.latest_ms;
    if (self.absolute_ms) |absolute| {
        if (observation.time.latest_ms >= absolute) {
            self.local_until_ms = @min(self.local_until_ms, before_ms);
        } else {
            // Saturation cannot extend the already finite local timeout.
            self.local_until_ms = @min(self.local_until_ms, before_ms +| (absolute - observation.time.latest_ms));
        }
    }
    return self.remaining(after_ms);
}

pub fn remaining(self: *Self, now_ms: u64) !u32 {
    if (now_ms < self.last_local_ms) return error.ClockUnavailable;
    self.last_local_ms = now_ms;
    if (now_ms >= self.local_until_ms) return error.ApplicationReservationExpired;
    return std.math.cast(u32, self.local_until_ms - now_ms) orelse return error.InvalidApplicationDeadline;
}

pub fn now(io: std.Io) !u64 {
    return std.math.cast(u64, std.Io.Clock.awake.now(io).toMilliseconds()) orelse error.ClockUnavailable;
}

/// Native clients preserve current rights and original invocation fences. This
/// read is bounded by the caller's enclosing cancellation/deadline scope.
pub fn refresh(self: *Self, client: q.catalog.DirectTableClient) !u32 {
    if (client.transaction != null) return error.InvalidTransactionGuard;
    const io = client.service.http.io;
    const before = try now(io);
    _ = try self.remaining(before);
    const response = try client.call(.{ .queue = .{ .current_time = self.original.claim.target } });
    defer response.deinit();
    if (response.value.result != .queue) return error.InvalidQueueResponse;
    const result = response.value.result.queue;
    if (result == .recovering) return error.QueueRecoveryPending;
    if (result != .current_time) return error.InvalidQueueResponse;
    return self.observe(result.current_time, before, try now(io));
}

fn fixture() p.StreamQueue.ClaimReceipt {
    const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    return .{
        .claim = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(1) }, .partition = 0 }, .operation = .{ .scope = scope, .principal = 5, .operation = 6 }, .maximum = 1, .lease_ms = 60000, .predicate = null },
        .accepted = .{ .partition = 7, .next_lsn = 10 },
        .observed_ms = 1000,
        .expires_ms = 61000,
        .rows = 1,
        .leases = .{ .sha256 = @splat(2), .bytes = 100 },
    };
}
fn sample(original: p.StreamQueue.ClaimReceipt, upper: u64) p.QueueRead.TimeObservation {
    return .{ .cut = .{ .target = original.claim.target, .accepted = original.accepted, .retained_from = 0, .next = 1 }, .time = .{ .earliest_ms = upper - 10, .latest_ms = upper }, .floor_ms = original.observed_ms };
}

test "application deadlines keep the original claim across effects and charge the full native time read" {
    const t = std.testing;
    const original = fixture();
    var first = try init(original, "5s", 100, 10000, 20000);
    try t.expectEqual(@as(u32, 4850), try first.observe(sample(original, 1100), 100, 150));
    // Rechecking a slow/stationary wall clock cannot lengthen the local budget.
    try t.expectEqual(@as(u32, 4800), try first.observe(sample(original, 1100), 150, 200));
    try t.expectEqual(@as(u64, 5000), first.local_until_ms);
    var second = try init(original, "5s", 2000, 10000, 20000);
    try t.expectEqual(@as(u32, 950), try second.observe(sample(original, 5000), 2000, 2050));
    try t.expectEqual(@as(?u64, 6000), second.absolute_ms);
    try t.expectError(error.ApplicationReservationExpired, second.observe(sample(original, 6000), 2050, 2100));
    try t.expectError(error.ApplicationReservationExpired, first.remaining(5000));
}

test "application deadlines refuse regressing clocks foreign cuts overflow and shorter request lifetimes" {
    const t = std.testing;
    const original = fixture();
    var self = try init(original, "5s", 100, 1000, 300);
    try t.expectEqual(@as(u32, 150), try self.observe(sample(original, 1100), 100, 150));
    try t.expectError(error.ClockUnavailable, self.remaining(149));
    try t.expectError(error.ClockUnavailable, self.observe(sample(original, 1200), 149, 151));
    try t.expectError(error.LogTimeRegression, self.observe(sample(original, 1050), 150, 160));
    var invalid = sample(original, 1200);
    invalid.floor_ms = null;
    try t.expectError(error.LogTimeRegression, self.observe(invalid, 150, 160));
    invalid = sample(original, 1200);
    invalid.cut.target.partition += 1;
    try t.expectError(error.InvalidQueueResponse, self.observe(invalid, 150, 160));
    invalid = sample(original, 1200);
    invalid.cut.accepted.next_lsn -= 1;
    try t.expectError(error.InvalidQueueResponse, self.observe(invalid, 150, 160));
    try t.expectError(error.ApplicationReservationExpired, self.remaining(300));
    try t.expectError(error.InvalidApplicationDeadline, init(original, "18446744073709551615ms", 100, 1000, 20000));
    try t.expectError(error.ApplicationReservationExpired, init(original, "5s", 100, 1000, 100));
    var unlimited = try init(original, null, 100, 1000, 20000);
    try t.expectEqual(@as(u32, 950), try unlimited.observe(sample(original, 100000), 100, 150));
}
