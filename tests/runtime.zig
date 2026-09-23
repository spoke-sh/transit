const std = @import("std");
const transit = @import("transit");
const adapter = @import("transit_ursula");
const t = std.testing;

const Engine = transit.Engine(adapter.Store);
fn submit(e: *Engine, key: transit.Ed25519.KeyPair, command: transit.Command) !u64 {
    var current = command;
    if (current == .turn) current.turn.expected_revision = (try e.state.process(current.turn.pid)).revision;
    return e.submit(try transit.sign(.{ .realm = e.state.realm, .principal = 0, .sequence = (try e.state.principal(0)).sequence + 1, .command = current }, key));
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try transit.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const worker = try transit.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const fresh = try transit.Ed25519.KeyPair.generateDeterministic(@splat(9));
    const genesis: transit.Genesis = .{ .realm = 48, .root_key = root.public_key.toBytes(), .retry_policy = .last_per_principal };
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-proof", .name = "runtime" } } };
    if (std.mem.eql(u8, args[2], "write")) {
        try store.journal.create();
        var e = try Engine.bootstrap(&store, genesis);
        _ = try submit(&e, root, .{ .spawn = .{ .allow_trim = true } });
        _ = try submit(&e, root, .{ .grant = .{ .subject = 1, .public_key = worker.public_key.toBytes(), .permissions = transit.permission(.execute) | transit.permission(.inspect), .pid = 1 } });
        _ = try submit(&e, root, .{ .runtime_intent = .{ .pid = 1, .expected_revision = 0, .instance = @splat(1), .resource = @splat(2), .workload = @splat(3) } });
    } else if (std.mem.eql(u8, args[2], "recover")) {
        var e = try Engine.open(&store, genesis);
        try t.expectEqual(.pending, (try e.state.process(1)).binding.?.phase);
        _ = try submit(&e, root, .{ .runtime_observe = .{ .pid = 1, .revision = 1, .operation = 3, .incarnation = @splat(4), .outcome = .ready } });
        _ = try submit(&e, root, .{ .activate = .{ .pid = 1, .revision = 1, .expected_generation = 1, .worker = 1, .public_key = fresh.public_key.toBytes(), .worker_incarnation = @splat(5) } });
        _ = try submit(&e, root, .{ .checkpoint = {} });
        try store.publishCheckpoint(&(try transit.Checkpoint.create(init.gpa, genesis, &e.state)));
    } else if (std.mem.eql(u8, args[2], "checkpoint")) {
        var e = try Engine.open(&store, genesis);
        try store.maintain(&(try transit.Checkpoint.create(init.gpa, genesis, &e.state)));
        _ = try submit(&e, root, .{ .terminate = 1 });
        _ = try submit(&e, root, .{ .runtime_intent = .{ .pid = 1, .expected_revision = 1, .instance = @splat(1), .resource = @splat(2), .workload = @splat(3), .desired = .stopped } });
    } else if (std.mem.eql(u8, args[2], "trim_recover")) {
        var e = try Engine.open(&store, genesis);
        const p = (try e.state.process(1)).*;
        try t.expectEqual(.terminated, p.lifecycle);
        try t.expectEqual(@as(?u8, null), p.owner);
        try t.expectEqual(@as(u64, 2), p.binding.?.revision);
        try t.expectEqualSlices(u8, &(@as([16]u8, @splat(4))), &p.binding.?.incarnation.?);
        try t.expectEqualSlices(u8, &fresh.public_key.toBytes(), &(try e.state.principal(1)).grant.public_key);
        _ = try submit(&e, root, .{ .runtime_observe = .{ .pid = 1, .revision = 2, .operation = p.binding.?.operation, .incarnation = @splat(4), .outcome = .stopped } });
        try t.expectError(error.RetiredProcess, submit(&e, root, .{ .activate = .{ .pid = 1, .revision = 2, .expected_generation = p.generation, .worker = 1, .public_key = worker.public_key.toBytes(), .worker_incarnation = @splat(6) } }));
    } else return error.UnknownPhase;
    std.debug.print("runtime {s}: passed\n", .{args[2]});
}
