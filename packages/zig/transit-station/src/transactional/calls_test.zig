//! Unit tests for transactional Envelope, Wait, Turn call/reply/cancel staging
//! and Actor multi-mailbox participant canonicalization.
const std = @import("std");
const s = @import("root.zig");
const c = s.catalog;
const p = c.protocol;
const t = std.testing;

fn partition(object: u64, ord: u32) p.StreamQueue.Partition {
    return .{
        .definition = p.Growth.current_definition,
        .interpretation = .{
            .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = object },
            .revision = 1,
            .digest = @splat(@intCast(object)),
        },
        .partition = ord,
    };
}

test "private transactional turn stages correlated calls, timer tickets, replies and cancellations" {
    const Store = struct {
        map: std.StringHashMapUnmanaged([]const u8) = .empty,
        fn get(raw: *anyopaque, allocator: std.mem.Allocator, key: []const u8) !?[]const u8 {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const found = self.map.get(key) orelse return null;
            return try allocator.dupe(u8, found);
        }
    };
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var store: Store = .{};
    const inbox = partition(10, 0);
    const peer = partition(11, 0);
    const timers = partition(12, 0);
    const undeclared = partition(99, 0);
    const source: p.StreamQueue.RecordIdentity = .{
        .target = inbox,
        .operation = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 7, .operation = 50 },
        .ordinal = 0,
    };

    // 1. Caller turn issues an untimed call to inbox and a timed call to peer.
    var bad_target = try s.Turn.initWithContext(alloc, .{}, .{ .context = &store, .get = Store.get }, source, "start", .{
        .turn_id = 3,
        .actor_pid = 20,
        .inbox = inbox,
        .mailboxes = &.{peer},
        .timers = timers,
        .envelope = .{ .kind = .cast, .correlation = 0, .payload = "start" },
        .origin = .{ .external = 7 },
    });
    try t.expectError(error.UndeclaredMailboxTarget, bad_target.call(undeclared, 21, "bad"));
    try t.expectError(error.PoisonedTurn, bad_target.finish());

    var bad_reply = try s.Turn.initWithContext(alloc, .{}, .{ .context = &store, .get = Store.get }, source, "start", .{
        .turn_id = 3,
        .actor_pid = 20,
        .inbox = inbox,
        .envelope = .{ .kind = .cast, .correlation = 0, .payload = "start" },
        .origin = .{ .external = 7 },
    });
    try t.expectError(error.ExpectedCall, bad_reply.reply(inbox, "nope"));

    var caller = try s.Turn.initWithContext(alloc, .{}, .{ .context = &store, .get = Store.get }, source, "start", .{
        .turn_id = 3,
        .actor_pid = 20,
        .inbox = inbox,
        .mailboxes = &.{peer},
        .timers = timers,
        .envelope = .{ .kind = .cast, .correlation = 0, .payload = "start" },
        .origin = .{ .external = 7 },
    });

    const corr1 = try caller.call(inbox, 21, "req-1");
    const corr2 = try caller.callWithTimer(peer, 22, "req-2", 4500, 88);
    try t.expect(corr1 != corr2);
    try t.expectEqual(@as(u64, 21), (try caller.waiting(corr1)).?.target_pid);
    try t.expectEqual(@as(?u64, 4500), (try caller.waiting(corr2)).?.deadline_ms);
    try t.expectEqual(@as(?u64, 88), (try caller.waiting(corr2)).?.observer);

    const caller_draft = try caller.finish();
    try t.expectEqual(@as(usize, 2), caller_draft.puts.len);
    // corr1 -> 1 call message; corr2 -> 1 call message + 1 delayed TimerTicket.
    try t.expectEqual(@as(usize, 3), caller_draft.messages.len);
    try t.expectEqual(@as(u64, 0), caller_draft.messages[0].visible_ms);
    try t.expectEqual(@as(u64, 0), caller_draft.messages[1].visible_ms);
    try t.expectEqual(@as(u64, 4500), caller_draft.messages[2].visible_ms);
    const ticket = try s.Timer.Ticket.decode(alloc, try caller_draft.messages[2].body.decode(alloc, 4096));
    try t.expectEqual(corr2, ticket.correlation);
    try t.expectEqual(@as(u64, 20), ticket.target_pid);

    // Seed caller's committed KV with Wait(corr1) and test cancelWait in turn 4.
    const wait1_key = try caller_draft.puts[0].key.decode(alloc, 64);
    const wait1_val = try caller_draft.puts[0].value.?.decode(alloc, 4096);
    try store.map.put(alloc, wait1_key, wait1_val);

    var cancel_turn = try s.Turn.initWithContext(alloc, .{}, .{ .context = &store, .get = Store.get }, source, "cancel", .{
        .turn_id = 4,
        .actor_pid = 20,
        .inbox = inbox,
        .mailboxes = &.{peer},
        .timers = timers,
        .envelope = .{ .kind = .cast, .correlation = 0, .payload = "cancel" },
        .origin = .{ .external = 7 },
    });
    try cancel_turn.cancelWait(corr1);
    try t.expectEqual(s.Wait.Phase.cancelled, (try cancel_turn.waiting(corr1)).?.phase);
    const cancel_draft = try cancel_turn.finish();
    try t.expectError(error.WaitAlreadyClosed, cancel_turn.cancelWait(corr1));
    try t.expectEqual(@as(usize, 1), cancel_draft.messages.len);
    const cancel_env = try s.Envelope.decode(try cancel_draft.messages[0].body.decode(alloc, 4096));
    try t.expectEqual(s.Envelope.Kind.cancel, cancel_env.kind);
    try t.expectEqual(corr1, cancel_env.correlation);

    // 2. Callee turn replies exclusively to the authenticated caller PID.
    var callee = try s.Turn.initWithContext(alloc, .{}, .{ .context = &store, .get = Store.get }, source, "req-1", .{
        .turn_id = 1,
        .actor_pid = 21,
        .inbox = inbox,
        .envelope = .{ .kind = .call, .correlation = corr1, .payload = "req-1" },
        .origin = .{ .actor = .{
            .realm = 1,
            .pid = 20,
            .principal = 7,
            .generation = 1,
            .code = 1,
            .workload = null,
            .transaction = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 7, .operation = 49 },
        } },
    });
    try callee.reply(inbox, "ans-1");
    const callee_draft = try callee.finish();
    try t.expectEqual(@as(usize, 1), callee_draft.messages.len);
    try t.expectEqual(@as(u64, 20), callee_draft.messages[0].pid);
    const reply_env = try s.Envelope.decode(try callee_draft.messages[0].body.decode(alloc, 4096));
    try t.expectEqual(s.Envelope.Kind.reply, reply_env.kind);
    try t.expectEqual(corr1, reply_env.correlation);
    try t.expectEqualStrings("ans-1", reply_env.payload);
}
