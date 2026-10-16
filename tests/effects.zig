const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const t = std.testing;

const disk = @import("native_disk.zig");
const g = disk.g;
const Engine = disk.Engine;
// The worker grant at position 2 is this fixture's last policy publication.
const policy_revision: u64 = 2;

fn submit(e: *Engine, key: core.Ed25519.KeyPair, principal: u8, command: core.Command) !u64 {
    var current = command;
    if (current == .turn) current.turn.expected_revision = (try e.process(current.turn.pid)).revision;
    return e.submit(try core.sign(.{
        .realm = e.genesis.realm,
        .principal = principal,
        .sequence = (try e.principal(principal)).sequence + 1,
        .command = current,
    }, key));
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try core.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const worker = try core.Ed25519.KeyPair.generateDeterministic(@splat(8));
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    for ([_]bool{ false, true }) |close_unknown| {
        const genesis: core.Genesis = .{ .realm = if (close_unknown) 44 else 43, .root_key = root.public_key.toBytes(), .allow_history_trim = true };
        var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-proof", .name = if (close_unknown) "closed-effects" else "effects" } } };
        var pages = try adapter.PackedPageStore.init(init.gpa, store.journal, 8);
        defer pages.deinit();
        if (std.mem.eql(u8, args[2], "write")) {
            try store.journal.create();
            try pages.create();
            var e = try Engine.bootstrap(&store, &pages, genesis);
            const pid = try submit(&e, root, 0, .{ .spawn = .{ .allow_collection = true } });
            try t.expectEqual(policy_revision, try submit(&e, root, 0, .{ .grant = .{
                .subject = 1,
                .public_key = worker.public_key.toBytes(),
                .permissions = core.permission(.execute) | core.permission(.effect),
                .pid = pid,
            } }));
            _ = try submit(&e, root, 0, .{ .own = .{ .pid = pid, .worker = 1, .expected_generation = 0 } });
            const input = try submit(&e, root, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(9) } });
            const effect = try submit(&e, worker, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .expected_revision = 0, .effect = core.Value.integer(9) } });
            const attempt = try submit(&e, root, 0, .{ .dispatch = .{ .pid = pid, .effect = effect } });
            // The executor has authorization but no durable result. Restart must
            // preserve uncertainty, even if the worker actually paused before I/O.
            _ = try submit(&e, root, 0, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = null } });
            _ = try submit(&e, root, 0, .{ .checkpoint = {} });
            try disk.publish(&store);
        } else if (std.mem.eql(u8, args[2], "recover")) {
            var e = try Engine.open(&store, &pages, genesis);
            const effect = (try disk.record(&e, g.Effect, .effect, 5));
            try t.expectEqual(.unknown, effect.phase);
            try t.expectEqual(policy_revision, effect.authorization_policy.?);
            try t.expectEqual(policy_revision, effect.last_observation.?.policy_revision);
            try t.expectEqual(@as(?u64, 6), effect.attempt);
            try t.expectError(error.AttemptAlreadyAuthorized, submit(&e, root, 0, .{ .dispatch = .{ .pid = 1, .effect = 5 } }));
            try store.maintain(e.head);
            try t.expectError(error.HistoryReclaimed, store.read(0));
            if (close_unknown) {
                const response = try core.sign(.{ .realm = e.genesis.realm, .principal = 0, .sequence = (try e.principal(0)).sequence + 1, .command = .{ .observe = .{ .pid = 1, .effect = 5, .attempt = 6, .result = core.Value.integer(10) } } }, root);
                const pending = try e.prepare(response);
                var closer = try Engine.open(&store, &pages, genesis);
                const close = try core.sign(.{ .realm = closer.genesis.realm, .principal = 0, .sequence = (try closer.principal(0)).sequence + 1, .command = .{ .close_effect = .{ .pid = 1, .effect = 5, .attempt = 6 } } }, root);
                const receipt = try closer.submit(close);
                try t.expectError(error.Conflict, e.commit(pending));
                e = try Engine.open(&store, &pages, genesis);
                try t.expectEqual(receipt, try e.submit(close));
                _ = try submit(&e, root, 0, .{ .checkpoint = {} });
                try disk.publish(&store);
            } else {
                _ = try submit(&e, root, 0, .{ .terminate = 1 });
            }
        } else if (std.mem.eql(u8, args[2], "checkpoint")) {
            var e = try Engine.open(&store, &pages, genesis);
            if (close_unknown) {
                try t.expectEqual(.running, (try e.process(1)).lifecycle);
                try t.expectEqual(.closed_unknown, (try disk.record(&e, g.Effect, .effect, 5)).phase);
                const closed = try disk.record(&e, g.Effect, .effect, 5);
                try t.expect(closed.closed_at != null);
                try t.expectEqual(.abandoned, closed.closure.?.reason);
                try t.expectEqual(@as(u64, 0), closed.closure.?.principal);
                try t.expectEqual(policy_revision, closed.closure.?.policy_revision);
                const diagnostic = try core.protocol.EffectDiagnostic.from(genesis.realm, e.head.position, closed);
                try t.expectEqualStrings("effect.reconciliation_abandoned", diagnostic.code.slice());
                try store.maintain(e.head);
                try t.expectError(error.ReconciliationClosed, submit(&e, root, 0, .{ .observe = .{ .pid = 1, .effect = 5, .attempt = 6, .result = core.Value.integer(10) } }));
                try t.expectError(error.AttemptAlreadyAuthorized, submit(&e, root, 0, .{ .dispatch = .{ .pid = 1, .effect = 5 } }));
            } else {
                try t.expectEqual(.terminated, (try e.process(1)).lifecycle);
                try t.expectEqual(.unknown, (try disk.record(&e, g.Effect, .effect, 5)).phase);
                try t.expectError(error.RetiredProcess, submit(&e, root, 0, .{ .dispatch = .{ .pid = 1, .effect = 5 } }));
            }
            try t.expectError(error.InvalidAttempt, submit(&e, worker, 1, .{ .observe = .{ .pid = 1, .effect = 5, .attempt = 6, .result = core.Value.integer(10) } }));
            // Late evidence settles the attempt; it must not revive the caller or
            // deliver to a replacement process with a different PID.
            if (!close_unknown) _ = try submit(&e, root, 0, .{ .observe = .{ .pid = 1, .effect = 5, .attempt = 6, .result = core.Value.integer(10) } });
            _ = try submit(&e, root, 0, .{ .checkpoint = {} });
            try store.maintain(e.head);
        } else if (std.mem.eql(u8, args[2], "trim_recover")) {
            try t.expectError(error.HistoryReclaimed, store.read(0));
            var e = try Engine.open(&store, &pages, genesis);
            const p = (try e.process(1));
            try t.expectEqual(@as(@TypeOf(p.lifecycle), if (close_unknown) .running else .terminated), p.lifecycle);
            try t.expectEqual(@as(i64, 9), try (try disk.record(&e, g.Effect, .effect, 5)).payload.asInteger());
            try t.expectEqual(@as(u64, 1), p.admitted);
            const effect = (try disk.record(&e, g.Effect, .effect, 5));
            try t.expectEqual(@as(@TypeOf(effect.phase), if (close_unknown) .closed_unknown else .observed), effect.phase);
            try t.expectEqual(@as(@TypeOf(effect.closure.?.reason), if (close_unknown) .abandoned else .observed), effect.closure.?.reason);
            try t.expectEqual(policy_revision, effect.authorization_policy.?);
            try t.expectEqual(if (close_unknown) @as(?i64, null) else 10, if (effect.result) |v| try v.asInteger() else null);
            try t.expectEqual(@as(?g.Input, null), try disk.input(&e, 1));
            try t.expectError(error.ReconciliationClosed, submit(&e, root, 0, .{ .observe = .{ .pid = 1, .effect = 5, .attempt = 6, .result = core.Value.integer(99) } }));
        } else return error.UnknownPhase;
    }
    std.debug.print("effects {s}: passed\n", .{args[2]});
}
