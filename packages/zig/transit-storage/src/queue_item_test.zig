const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const q = p.StreamQueue;
const Item = @import("QueueItem.zig");
const Time = @import("LogTime.zig");
const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
const target: q.Partition = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(7) }, .partition = 0 };
const policy: p.StreamQueueDeclaration.Queue = .{ .ordering = .unordered, .key_column = null, .lease_ms = 100, .maximum_lease_ms = 200, .maximum_attempts = 2, .backoff = .{ .initial_ms = 20, .maximum_ms = 100, .multiplier = 2 }, .dead_letter = null };
fn claim(operation: u64) q.Claim {
    return .{ .target = target, .operation = .{ .scope = scope, .principal = 8, .operation = operation }, .maximum = 4, .lease_ms = 100 };
}
fn settlement(lease: q.Lease, operation: u64, action: @FieldType(q.Settlement, "action")) q.Settlement {
    return .{ .operation = .{ .scope = scope, .principal = 8, .operation = operation }, .lease = lease, .action = action };
}

test "queue item conservative intervals separate visibility liveness and expiry" {
    const original = try Item.initial(0, 8, 80);
    try t.expectError(error.QueueNotVisible, original.acquire(.available, claim(1), policy, .{ .earliest_ms = 79, .latest_ms = 90 }));
    const first = try original.acquire(.available, claim(1), policy, .{ .earliest_ms = 80, .latest_ms = 90 });
    try t.expectEqual(@as(u64, 190), first.lease.?.expires_ms);
    try t.expectEqual(@as(u64, 1), first.epoch);
    const ack = settlement(first.lease.?, 2, .ack);
    const uncertain: Time.Sample = .{ .earliest_ms = 189, .latest_ms = 190 };
    try t.expectError(error.QueueTimeUnavailable, first.settle(.acquired, ack, policy, uncertain));
    try t.expectError(error.QueueTimeUnavailable, first.expire(.acquired, policy, uncertain));
    try t.expectError(error.QueueLeaseExpired, first.settle(.acquired, ack, policy, .exact(190)));
    const expired = try first.expire(.acquired, policy, .{ .earliest_ms = 190, .latest_ms = 195 });
    try t.expect(expired.lease == null and expired.blocked == .none);
    try t.expectEqual(@as(u64, 210), expired.visible_ms);
    try t.expectError(error.QueueNotVisible, expired.acquire(.available, claim(3), policy, .{ .earliest_ms = 209, .latest_ms = 210 }));
    const second = try expired.acquire(.available, claim(3), policy, .exact(210));
    try t.expectEqual(@as(u64, 2), second.epoch);
    try t.expectEqual(@as(u64, 2), second.attempts);
    try t.expectError(error.QueueLeaseFenced, second.settle(.acquired, ack, policy, .exact(211)));
    const exhausted = try second.settle(.acquired, settlement(second.lease.?, 4, .{ .nack = .{ .visible_ms = 0 } }), policy, .exact(230));
    try t.expect(exhausted.state == .available and exhausted.item.blocked == .exhausted);
    try t.expect(exhausted.item.lease == null);
    try t.expectError(error.QueueRetryExhausted, exhausted.item.acquire(.available, claim(5), policy, .exact(1000)));
}

test "queue item renewal replaces exact receipts and current policy limits its deadline" {
    const first = try (try Item.initial(3, 8, 0)).acquire(.available, claim(1), policy, .exact(100));
    const extend = settlement(first.lease.?, 2, .{ .extend = .{ .expires_ms = 250 } });
    const renewed = try first.settle(.acquired, extend, policy, .exact(120));
    try t.expect(renewed.state == .acquired);
    try t.expectEqual(@as(u64, 250), renewed.item.lease.?.expires_ms);
    try t.expectEqual(first.epoch, renewed.item.epoch);
    try t.expectError(error.QueueLeaseFenced, renewed.item.settle(.acquired, settlement(first.lease.?, 3, .ack), policy, .exact(121)));
    var tighter = policy;
    tighter.maximum_lease_ms = 100;
    try t.expectError(error.InvalidQueueLeaseDuration, first.settle(.acquired, extend, tighter, .exact(120)));
    try t.expectError(error.QueueLeaseExpired, first.settle(.acquired, extend, policy, .exact(200)));
    const acked = try renewed.item.settle(.acquired, settlement(renewed.item.lease.?, 4, .ack), policy, .exact(249));
    try t.expect(acked.state == .acked and acked.item.lease == null);
    try t.expectError(error.QueueLeaseFenced, acked.item.settle(.acked, settlement(renewed.item.lease.?, 4, .ack), policy, .exact(249)));
    // Original accepted ACK lookup belongs to the operation receipt owner;
    // applying the same ACK again is not how an original result is recovered.
}

test "queue item retries preserve FIFO head delay and block DLQ without terminalizing source" {
    var configured = policy;
    configured.dead_letter = target.interpretation;
    configured.dead_letter.?.object.object = 5;
    configured.maximum_attempts = 1;
    const first = try (try Item.initial(0, 8, 0)).acquire(.available, claim(1), configured, .exact(100));
    var linked = first;
    linked.next_key = 7;
    const blocked = try linked.expire(.acquired, configured, .exact(1000));
    try t.expect(blocked.blocked == .dead_letter and blocked.next_key == 7 and blocked.lease == null);
    try blocked.requireState(.available);
    try t.expectError(error.QueueStateConflict, blocked.requireState(.archived));
    const retry = try first.settle(.acquired, settlement(first.lease.?, 2, .{ .nack = .{ .visible_ms = 900 } }), policy, .{ .earliest_ms = 110, .latest_ms = 120 });
    try t.expectEqual(@as(u64, 900), retry.item.visible_ms);
    const backoff = try first.settle(.acquired, settlement(first.lease.?, 3, .{ .nack = .{ .visible_ms = 0 } }), policy, .{ .earliest_ms = 110, .latest_ms = 120 });
    try t.expectEqual(@as(u64, 140), backoff.item.visible_ms);
    const after_downtime = try first.expire(.acquired, policy, .exact(1000));
    try t.expectEqual(@as(u64, 220), after_downtime.visible_ms);
}

test "queue item fences malformed state and checked counter deadline overflow" {
    try t.expectError(error.InvalidQueueItem, Item.initial(8, 8, 0));
    var item = try Item.initial(0, 8, 0);
    try t.expectError(error.QueueStateConflict, item.requireState(.acquired));
    item.next_key = 0;
    try t.expectError(error.InvalidQueueItem, item.validate());
    item.next_key = null;
    item.epoch = std.math.maxInt(u64);
    item.attempts = 1;
    try t.expectError(error.QueueLeaseEpochExhausted, item.acquire(.available, claim(1), policy, .exact(100)));
    item.epoch = 1;
    try t.expectError(error.QueueLeaseDeadlineOverflow, item.acquire(.available, claim(1), policy, .exact(std.math.maxInt(u64) - 99)));
    const initial = try Item.initial(0, 8, 0);
    var leased = try initial.acquire(.available, claim(1), policy, .exact(std.math.maxInt(u64) - 110));
    try t.expectError(error.QueueRetryDeadlineOverflow, leased.expire(.acquired, policy, .exact(std.math.maxInt(u64))));
    leased.lease.?.offset = 1;
    try t.expectError(error.InvalidQueueItem, leased.validate());
}
