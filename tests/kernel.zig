const std = @import("std");
const transit = @import("transit");
const adapter = @import("transit_ursula");
fn counter(state: i64, input: i64) !transit.Decision {
    return .{ .state = try std.math.add(i64, state, input) };
}
const Engine = transit.Engine(adapter.Store, counter);
const t = std.testing;

fn signed(e: *Engine, key: transit.Ed25519.KeyPair, principal: u8, command: transit.Command) !transit.SignedRequest {
    return transit.sign(.{ .realm = 42, .principal = principal, .sequence = (try e.state.principal(principal)).sequence + 1, .command = command }, key);
}
fn submit(e: *Engine, key: transit.Ed25519.KeyPair, principal: u8, command: transit.Command) !u64 {
    return e.submit(try signed(e, key, principal, command));
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try transit.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const worker = try transit.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const genesis: transit.Genesis = .{ .realm = 42, .root_key = root.public_key.toBytes(), .retry_policy = .last_per_principal };
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-proof", .name = "kernel" } } };
    if (std.mem.eql(u8, args[2], "write")) {
        try store.journal.create();
        var e = try Engine.bootstrap(&store, genesis);
        // Bootstrap retry cannot allocate another realm or reset authorization.
        _ = try Engine.bootstrap(&store, genesis);
        _ = try submit(&e, root, 0, .{ .grant = .{ .subject = 1, .public_key = worker.public_key.toBytes(), .permissions = transit.permission(.execute) | transit.permission(.inspect), .pid = 2 } });
        const spawn = try signed(&e, root, 0, .{ .spawn = .{ .allow_trim = true } });
        _ = try e.submit(spawn); // Deliberately forget its receipt.
        var recovered = try Engine.open(&store, genesis);
        const pid = try recovered.submit(spawn);
        try t.expectEqual(@as(u64, 2), pid);
        _ = try submit(&recovered, root, 0, .{ .own = .{ .pid = pid, .worker = 1, .expected_generation = 0 } });
        for (0..100) |_| _ = try submit(&recovered, root, 0, .{ .send = .{ .pid = pid, .value = 1 } });
        const first = (try recovered.nextInput(pid, recovered.state.position)).?;
        const proposal = try signed(&recovered, worker, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = first.position, .result = 1 } });
        var competing = try Engine.open(&store, genesis);
        const a = try recovered.prepare(proposal);
        const b = try competing.prepare(proposal);
        _ = try recovered.commit(a);
        try t.expectError(error.Conflict, competing.commit(b));
        // Retrying a lost turn acknowledgement returns the existing receipt.
        try t.expectEqual(a.record.position, try competing.submit(proposal));
        const input = (try recovered.nextInput(pid, recovered.state.position)).?;
        const pending = try recovered.prepare(try signed(&recovered, worker, 1, .{ .turn = .{ .pid = pid, .generation = 1, .input = input.position, .result = 2 } }));
        _ = try submit(&competing, root, 0, .{ .revoke = 1 });
        try t.expectError(error.Conflict, recovered.commit(pending));
        try t.expectError(error.Forbidden, recovered.submit(try signed(&recovered, worker, 1, .{ .inspect = pid })));
    } else if (std.mem.eql(u8, args[2], "recover")) {
        var e = try Engine.open(&store, genesis);
        try t.expectEqual(@as(i64, 1), (try e.state.process(2)).state);
        try t.expectEqual(@as(u64, 100), (try e.state.process(2)).admitted);
        try t.expectError(error.Forbidden, submit(&e, worker, 1, .{ .inspect = 2 }));
        _ = try submit(&e, root, 0, .{ .grant = .{ .subject = 1, .public_key = worker.public_key.toBytes(), .permissions = transit.permission(.execute) | transit.permission(.inspect), .pid = 2 } });
        _ = try submit(&e, root, 0, .{ .own = .{ .pid = 2, .expected_generation = 1, .worker = 1 } });
        const next = (try e.nextInput(2, e.state.position)).?;
        try t.expectError(error.StaleGeneration, submit(&e, worker, 1, .{ .turn = .{ .pid = 2, .generation = 1, .input = next.position, .result = 2 } }));
        while (try e.nextInput(2, e.state.position)) |input| {
            _ = try submit(&e, worker, 1, .{ .turn = .{ .pid = 2, .generation = 2, .input = input.position, .result = (try e.state.process(2)).state + input.request.command.send.value } });
        }
        try t.expectEqual(@as(i64, 100), (try e.state.process(2)).state);
        _ = try submit(&e, root, 0, .{ .checkpoint = {} });
        const checkpoint = try transit.Checkpoint.create(init.gpa, genesis, e.state);
        // The launcher kills Ursula after publication, before trim is recorded.
        try store.publishCheckpoint(checkpoint);
    } else if (std.mem.eql(u8, args[2], "checkpoint")) {
        var e = try Engine.open(&store, genesis);
        try t.expectEqual(@as(i64, 100), (try e.state.process(2)).state);
        var idle_store: adapter.Store = .{ .journal = store.journal };
        var idle = try Engine.open(&idle_store, genesis);
        _ = try submit(&e, root, 0, .{ .inspect = 2 });
        _ = try submit(&e, root, 0, .{ .checkpoint = {} });
        const checkpoint = try transit.Checkpoint.create(init.gpa, genesis, e.state);
        try store.maintain(checkpoint);
        // A live authority with an independent cache catches up after trim.
        try idle.refresh();
        try t.expectEqual(@as(i64, 100), (try idle.state.process(2)).state);
        try t.expectEqual(e.state.position, idle.state.position);
        try store.maintain(checkpoint); // Idempotent cleanup after lost acknowledgement.
        try t.expectError(error.HistoryReclaimed, store.read(0));
        _ = try submit(&e, root, 0, .{ .send = .{ .pid = 2, .value = 7 } });
        try t.expectError(error.PendingWork, submit(&e, root, 0, .{ .checkpoint = {} }));
    } else if (std.mem.eql(u8, args[2], "trim_recover")) {
        try t.expectError(error.HistoryReclaimed, store.read(0));
        var e = try Engine.open(&store, genesis);
        try t.expectEqual(@as(i64, 100), (try e.state.process(2)).state);
        const input = (try e.nextInput(2, e.state.position)).?;
        _ = try submit(&e, worker, 1, .{ .turn = .{ .pid = 2, .generation = 2, .input = input.position, .result = 107 } });
        _ = try submit(&e, root, 0, .{ .terminate = 2 });
        var replay = try Engine.open(&store, genesis);
        try t.expectEqual(.terminated, (try replay.state.process(2)).lifecycle);
        try t.expectEqual(@as(i64, 107), (try replay.state.process(2)).state);
        try t.expectError(error.RetiredProcess, submit(&replay, root, 0, .{ .send = .{ .pid = 2, .value = 1 } }));
    } else return error.UnknownPhase;
    std.debug.print("kernel {s}: passed\n", .{args[2]});
}
