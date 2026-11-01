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
    try t.expectEqualDeep(configured.dead_letter.?, blocked.blocked.dead_letter);
    configured.dead_letter.?.object.object = 6;
    // Later declaration edits cannot redirect an already selected destination.
    try t.expectEqual(@as(u64, 5), blocked.blocked.dead_letter.object.object);
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

fn transfer(lease: q.Lease) p.Transaction.TerminalTransfer {
    var destination = target;
    destination.interpretation.object.object = 5;
    return .{ .operation = claim(10).operation, .source = .{ .nack = lease }, .destination = .{
        .target = destination,
        .operation = claim(11).operation,
        .kind = .queue,
        .producer = null,
        .rows = 1,
        .payload = .{ .bytes = 128, .sha256 = @splat(12) },
    } };
}

test "queue item transfer candidates fence live leases and recorded exhausted destinations" {
    var configured = policy;
    configured.dead_letter = target.interpretation;
    configured.dead_letter.?.object.object = 5;
    configured.maximum_attempts = 1;
    const leased = try (try Item.initial(0, 2, 0)).acquire(.available, claim(1), configured, .exact(100));
    var request = transfer(leased.lease.?);
    const live = try leased.transfer(.acquired, request, configured, .exact(199));
    try t.expect(live.state == .archived and live.item.lease == null and live.item.blocked == .none);
    try t.expect(live.item.blocked_after_ms == null);
    try t.expectError(error.QueueLeaseExpired, leased.transfer(.acquired, request, configured, .exact(200)));
    try t.expectError(error.QueueTimeUnavailable, leased.transfer(.acquired, request, configured, .{ .earliest_ms = 199, .latest_ms = 200 }));
    var stale = request;
    stale.source.nack.epoch += 1;
    try t.expectError(error.QueueLeaseFenced, leased.transfer(.acquired, stale, configured, .exact(150)));
    var changed = configured;
    changed.dead_letter.?.object.object = 6;
    try t.expectError(error.InvalidTransactionTransfer, leased.transfer(.acquired, request, changed, .exact(150)));

    const exhausted = try leased.expire(.acquired, configured, .exact(1000));
    try t.expectEqual(@as(?u64, 200), exhausted.blocked_after_ms);
    request.source = .{ .exhausted = .{ .target = target, .offset = 0, .lease_epoch = 1, .attempt = 1, .not_before_ms = 200 } };
    // Maintenance uses the recorded bound and destination, even when later
    // policy permits more attempts or chooses a different destination.
    changed.maximum_attempts = 10;
    const terminal = try exhausted.transfer(.available, request, changed, .exact(200));
    try t.expect(terminal.state == .archived and terminal.item.blocked_after_ms == null);
    try t.expectError(error.QueueTimeUnavailable, exhausted.transfer(.available, request, changed, .{ .earliest_ms = 199, .latest_ms = 200 }));
    stale = request;
    stale.source.exhausted.not_before_ms = 199;
    try t.expectError(error.QueueStateConflict, exhausted.transfer(.available, stale, changed, .exact(200)));
    stale = request;
    stale.destination.target.interpretation.object.object = 6;
    try t.expectError(error.InvalidTransactionTransfer, exhausted.transfer(.available, stale, changed, .exact(200)));
    try t.expectError(error.QueueStateConflict, terminal.item.transfer(.archived, request, changed, .exact(200)));
    var malformed = exhausted;
    malformed.blocked_after_ms = null;
    try t.expectError(error.InvalidQueueItem, malformed.validate());
    const missing_bound =
        \\{"offset":0,"batch_next":2,"next_key":null,"visible_ms":0,"epoch":0,"attempts":0,"lease":null,"blocked":{"none":{}}}
    ;
    try t.expectError(error.MissingField, p.Json.parseFromSlice(Item, t.allocator, missing_bound));

    const at_zero = try (try Item.initial(0, 2, 0)).acquire(.available, claim(1), configured, .exact(0));
    const nacked = try at_zero.settle(.acquired, settlement(at_zero.lease.?, 2, .{ .nack = .{ .visible_ms = 0 } }), configured, .exact(0));
    request.source.exhausted.not_before_ms = 0;
    try t.expectEqual(@as(?u64, 0), nacked.item.blocked_after_ms);
    try t.expectEqual(.archived, (try nacked.item.transfer(.available, request, configured, .exact(0))).state);
}
