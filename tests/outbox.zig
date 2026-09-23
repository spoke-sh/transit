const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const t = std.testing;

const Fanout = struct { state: i64, outputs: [core.max_turn_outputs]?core.Output = @splat(null) };
fn fanout(state: i64, input: i64) !Fanout {
    var result: Fanout = .{ .state = try std.math.add(i64, state, input) };
    if (input == 99) result.outputs = .{ .{ .pid = 1, .value = core.Value.integer(1) }, .{ .pid = 1, .value = core.Value.integer(2) }, .{ .pid = 2, .value = core.Value.integer(3) }, null };
    return result;
}
const Engine = core.Engine(adapter.Store);
fn request(e: *Engine, key: core.Ed25519.KeyPair, command: core.Command) !core.SignedRequest {
    var current = command;
    if (current == .turn) current.turn.expected_revision = (try e.state.process(current.turn.pid)).revision;
    return core.sign(.{ .realm = e.state.realm, .principal = 0, .sequence = (try e.state.principal(0)).sequence + 1, .command = current }, key);
}
fn submit(e: *Engine, key: core.Ed25519.KeyPair, command: core.Command) !u64 {
    var current = command;
    if (current == .turn) current.turn.expected_revision = (try e.state.process(current.turn.pid)).revision;
    return e.submit(try request(e, key, current));
}
fn consume(e: *Engine, key: core.Ed25519.KeyPair, pid: u64) !void {
    const p = (try e.state.process(pid)).*;
    if (p.owner == null) _ = try submit(e, key, .{ .own = .{ .pid = pid, .worker = 0, .expected_generation = p.generation } });
    const input = (try e.nextInput(pid, e.state.position)).?;
    _ = try submit(e, key, .{ .turn = .{ .pid = pid, .generation = (try e.state.process(pid)).generation, .input = input.position, .result = core.Value.integer((try p.state.asInteger()) + (try input.admission.?.value.asInteger())) } });
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try core.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const genesis: core.Genesis = .{ .realm = 46, .root_key = root.public_key.toBytes(), .retry_policy = .last_per_principal };
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-proof", .name = "outbox" } } };
    if (std.mem.eql(u8, args[2], "write")) {
        try store.journal.create();
        var e = try Engine.bootstrap(&store, genesis);
        for (0..3) |_| _ = try submit(&e, root, .{ .spawn = .{ .allow_trim = true } });
        _ = try submit(&e, root, .{ .own = .{ .pid = 3, .worker = 0, .expected_generation = 0 } });
        const input = try submit(&e, root, .{ .send = .{ .pid = 3, .value = core.Value.integer(99) } });
        _ = try submit(&e, root, .{ .turn = .{ .pid = 3, .generation = 1, .input = input, .result = core.Value.integer(99), .outputs = (try fanout(0, 99)).outputs } });
        _ = try submit(&e, root, .{ .checkpoint = {} });
        // All three pending payloads must survive removal of their source turn.
        try store.publishCheckpoint(&(try core.Checkpoint.create(init.gpa, genesis, &e.state)));
    } else if (std.mem.eql(u8, args[2], "recover")) {
        var e = try Engine.open(&store, genesis);
        try t.expectEqual(.pending, (try e.state.output(1)).phase);
        try store.maintain(&(try core.Checkpoint.create(init.gpa, genesis, &e.state)));
        try t.expectError(error.HistoryReclaimed, store.read(0));
        try t.expectError(error.RouteBlocked, submit(&e, root, .{ .deliver = .{ .pid = 1, .output = 2, .courier = 0 } }));
        _ = try submit(&e, root, .{ .deliver = .{ .pid = 2, .output = 3, .courier = 0 } });
        try consume(&e, root, 2);
        _ = try submit(&e, root, .{ .checkpoint = {} });
        try store.publishCheckpoint(&(try core.Checkpoint.create(init.gpa, genesis, &e.state)));
    } else if (std.mem.eql(u8, args[2], "checkpoint")) {
        var e = try Engine.open(&store, genesis);
        try t.expectEqual(@as(i64, 3), try (try e.state.process(2)).state.asInteger());
        try t.expectEqual(.pending, (try e.state.output(1)).phase);
        const first = try request(&e, root, .{ .deliver = .{ .pid = 1, .output = 1, .courier = 0 } });
        const receipt = try e.submit(first);
        e = try Engine.open(&store, genesis);
        try t.expectEqual(receipt, try e.submit(first));
        try t.expectEqual(@as(u64, 1), (try e.state.process(1)).admitted);
        try consume(&e, root, 1);
        _ = try submit(&e, root, .{ .checkpoint = {} });
        try store.maintain(&(try core.Checkpoint.create(init.gpa, genesis, &e.state)));
    } else if (std.mem.eql(u8, args[2], "trim_recover")) {
        try t.expectError(error.HistoryReclaimed, store.read(0));
        var e = try Engine.open(&store, genesis);
        try t.expectEqual(.pending, (try e.state.output(2)).phase);
        _ = try submit(&e, root, .{ .deliver = .{ .pid = 1, .output = 2, .courier = 0 } });
        try consume(&e, root, 1);
        try t.expectEqual(@as(i64, 3), try (try e.state.process(1)).state.asInteger());
        try t.expectEqual(@as(i64, 3), try (try e.state.process(2)).state.asInteger());
        try t.expectEqual(@as(i64, 99), try (try e.state.process(3)).state.asInteger());
        try t.expectError(error.OutputAlreadyResolved, submit(&e, root, .{ .deliver = .{ .pid = 1, .output = 1, .courier = 0 } }));
    } else return error.UnknownPhase;
    std.debug.print("outbox {s}: passed\n", .{args[2]});
}
