const std = @import("std");
const transit = @import("transit");
const adapter = @import("transit_ursula");
const t = std.testing;

fn counter(state: i64, input: i64) !transit.Decision {
    return .{ .state = try std.math.add(i64, state, input), .effect = if (input == 9) 9 else null };
}
const Engine = transit.Engine(adapter.Store, counter);

fn submit(e: *Engine, key: transit.Ed25519.KeyPair, principal: u8, command: transit.Command) !u64 {
    return e.submit(try transit.sign(.{
        .realm = e.state.realm,
        .principal = principal,
        .sequence = (try e.state.principal(principal)).sequence + 1,
        .command = command,
    }, key));
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try transit.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const worker = try transit.Ed25519.KeyPair.generateDeterministic(@splat(8));
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    for ([_]bool{ false, true }) |close_unknown| {
        const genesis: transit.Genesis = .{ .realm = if (close_unknown) 44 else 43, .root_key = root.public_key.toBytes(), .retry_policy = .last_per_principal };
        var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-proof", .name = if (close_unknown) "closed-effects" else "effects" } } };
        if (std.mem.eql(u8, args[2], "write")) {
            try store.journal.create();
            var e = try Engine.bootstrap(&store, genesis);
            const pid = try submit(&e, root, 0, .{ .spawn = .{ .allow_trim = true } });
            _ = try submit(&e, root, 0, .{ .grant = .{
                .subject = 1,
                .public_key = worker.public_key.toBytes(),
                .permissions = transit.permission(.execute) | transit.permission(.effect),
                .pid = pid,
            } });
            _ = try submit(&e, root, 0, .{ .own = .{ .pid = pid, .worker = 1, .expected_generation = 0 } });
            const input = try submit(&e, root, 0, .{ .send = .{ .pid = pid, .value = 9 } });
            const effect = try submit(&e, worker, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input, .result = 9, .effect = 9 } });
            const attempt = try submit(&e, root, 0, .{ .dispatch = .{ .pid = pid, .effect = effect } });
            // The executor has authorization but no durable result. Restart must
            // preserve uncertainty, even if the worker actually paused before I/O.
            _ = try submit(&e, root, 0, .{ .observe = .{ .pid = pid, .effect = effect, .attempt = attempt, .result = null } });
            _ = try submit(&e, root, 0, .{ .checkpoint = {} });
            try store.publishCheckpoint(try transit.Checkpoint.create(init.gpa, genesis, e.state));
        } else if (std.mem.eql(u8, args[2], "recover")) {
            var e = try Engine.open(&store, genesis);
            const effect = (try e.state.effect(5)).*;
            try t.expectEqual(.unknown, effect.phase);
            try t.expectEqual(@as(?u64, 6), effect.attempt);
            try t.expectError(error.AttemptAlreadyAuthorized, submit(&e, root, 0, .{ .dispatch = .{ .pid = 1, .effect = 5 } }));
            try store.maintain(try transit.Checkpoint.create(init.gpa, genesis, e.state));
            try t.expectError(error.Gone, store.read(0));
            if (close_unknown) {
                const response = try transit.sign(.{ .realm = e.state.realm, .principal = 0, .sequence = (try e.state.principal(0)).sequence + 1, .command = .{ .observe = .{ .pid = 1, .effect = 5, .attempt = 6, .result = 10 } } }, root);
                const pending = try e.prepare(response);
                var closer = try Engine.open(&store, genesis);
                const close = try transit.sign(.{ .realm = closer.state.realm, .principal = 0, .sequence = (try closer.state.principal(0)).sequence + 1, .command = .{ .close_effect = .{ .pid = 1, .effect = 5, .attempt = 6 } } }, root);
                const receipt = try closer.submit(close);
                try t.expectError(error.Conflict, e.commit(pending));
                e = try Engine.open(&store, genesis);
                try t.expectEqual(receipt, try e.submit(close));
                _ = try submit(&e, root, 0, .{ .checkpoint = {} });
                try store.publishCheckpoint(try transit.Checkpoint.create(init.gpa, genesis, e.state));
            } else {
                _ = try submit(&e, root, 0, .{ .terminate = 1 });
            }
        } else if (std.mem.eql(u8, args[2], "checkpoint")) {
            var e = try Engine.open(&store, genesis);
            if (close_unknown) {
                try t.expectEqual(.running, (try e.state.process(1)).lifecycle);
                try t.expectEqual(.closed_unknown, (try e.state.effect(5)).phase);
                try t.expect((try e.state.effect(5)).closed_at != null);
                try store.maintain(try transit.Checkpoint.create(init.gpa, genesis, e.state));
                try t.expectError(error.ReconciliationClosed, submit(&e, root, 0, .{ .observe = .{ .pid = 1, .effect = 5, .attempt = 6, .result = 10 } }));
                try t.expectError(error.AttemptAlreadyAuthorized, submit(&e, root, 0, .{ .dispatch = .{ .pid = 1, .effect = 5 } }));
            } else {
                try t.expectEqual(.terminated, (try e.state.process(1)).lifecycle);
                try t.expectEqual(.unknown, (try e.state.effect(5)).phase);
                try t.expectError(error.RetiredProcess, submit(&e, root, 0, .{ .dispatch = .{ .pid = 1, .effect = 5 } }));
            }
            try t.expectError(error.InvalidAttempt, submit(&e, worker, 1, .{ .observe = .{ .pid = 1, .effect = 5, .attempt = 6, .result = 10 } }));
            // Late evidence settles the attempt; it must not revive the caller or
            // deliver to a replacement process with a different PID.
            if (!close_unknown) _ = try submit(&e, root, 0, .{ .observe = .{ .pid = 1, .effect = 5, .attempt = 6, .result = 10 } });
            _ = try submit(&e, root, 0, .{ .checkpoint = {} });
            try store.maintain(try transit.Checkpoint.create(init.gpa, genesis, e.state));
        } else if (std.mem.eql(u8, args[2], "trim_recover")) {
            try t.expectError(error.Gone, store.read(0));
            var e = try Engine.open(&store, genesis);
            const p = (try e.state.process(1)).*;
            try t.expectEqual(@as(@TypeOf(p.lifecycle), if (close_unknown) .running else .terminated), p.lifecycle);
            try t.expectEqual(@as(i64, 9), p.state);
            try t.expectEqual(@as(u64, 1), p.admitted);
            const effect = (try e.state.effect(5)).*;
            try t.expectEqual(@as(@TypeOf(effect.phase), if (close_unknown) .closed_unknown else .observed), effect.phase);
            try t.expectEqual(if (close_unknown) @as(?i64, null) else 10, effect.result);
            try t.expectEqual(@as(?transit.Record, null), try e.nextInput(1, e.state.position));
            try t.expectError(error.ReconciliationClosed, submit(&e, root, 0, .{ .observe = .{ .pid = 1, .effect = 5, .attempt = 6, .result = 99 } }));
        } else return error.UnknownPhase;
    }
    std.debug.print("effects {s}: passed\n", .{args[2]});
}
