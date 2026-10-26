const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const t = std.testing;

const disk = @import("fixture_native_disk");
const Engine = disk.Engine;
fn submit(e: *Engine, key: core.Ed25519.KeyPair, command: core.Command) !u64 {
    var current = command;
    if (current == .turn) current.turn.expected_revision = (try e.process(current.turn.pid)).revision;
    return e.submit(try core.sign(.{ .realm = e.genesis.realm, .principal = 0, .sequence = (try e.principal(0)).sequence + 1, .command = current }, key));
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try core.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const worker = try core.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const fresh = try core.Ed25519.KeyPair.generateDeterministic(@splat(9));
    const genesis: core.Genesis = .{ .realm = 48, .root_key = root.public_key.toBytes(), .allow_history_trim = true };
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-proof", .name = "runtime" } } };
    var pages = try adapter.PackedPageStore.init(init.gpa, store.journal, 8);
    defer pages.deinit();
    if (std.mem.eql(u8, args[2], "write")) {
        try store.journal.create();
        try pages.create();
        var e = try Engine.bootstrap(&store, &pages, genesis);
        _ = try submit(&e, root, .{ .spawn = .{ .allow_collection = true } });
        _ = try submit(&e, root, .{ .grant = .{ .subject = 1, .public_key = worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.inspect), .pid = 1 } });
        _ = try submit(&e, root, .{ .runtime_intent = .{ .pid = 1, .expected_revision = 0, .instance = @splat(1), .resource = @splat(2), .workload = @splat(3) } });
    } else if (std.mem.eql(u8, args[2], "recover")) {
        var e = try Engine.open(&store, &pages, genesis);
        try t.expectEqual(.pending, (try e.process(1)).binding.?.phase);
        _ = try submit(&e, root, .{ .runtime_observe = .{ .pid = 1, .revision = 1, .operation = 3, .incarnation = @splat(4), .outcome = .ready } });
        _ = try submit(&e, root, .{ .activate = .{ .pid = 1, .revision = 1, .expected_generation = 1, .worker = 1, .public_key = fresh.public_key.toBytes(), .worker_incarnation = @splat(5) } });
        const stop = try submit(&e, root, .{ .runtime_intent = .{ .pid = 1, .expected_revision = 1, .instance = @splat(1), .resource = @splat(2), .workload = @splat(3), .desired = .stopped } });
        _ = try submit(&e, root, .{ .runtime_observe = .{ .pid = 1, .revision = 2, .operation = stop, .incarnation = @splat(4), .outcome = .stopped } });
        _ = try submit(&e, root, .{ .runtime_upgrade = .{ .pid = 1, .expected_revision = 2, .expected_workload = @splat(3), .workload = @splat(6), .expected_code = 1, .expected_state_revision = 0 } });
        _ = try submit(&e, root, .{ .checkpoint = {} });
        try disk.publish(&store);
    } else if (std.mem.eql(u8, args[2], "checkpoint")) {
        var e = try Engine.open(&store, &pages, genesis);
        const binding = (try e.process(1)).binding.?;
        try t.expectEqual(@as(?[32]u8, @splat(3)), binding.upgrade_from);
        try store.maintain(e.head);
        _ = try submit(&e, root, .{ .runtime_observe = .{ .pid = 1, .revision = 3, .operation = binding.operation, .incarnation = @splat(4), .outcome = .stopped } });
        _ = try submit(&e, root, .{ .terminate = 1 });
    } else if (std.mem.eql(u8, args[2], "trim_recover")) {
        var e = try Engine.open(&store, &pages, genesis);
        const p = (try e.process(1));
        try t.expectEqual(.terminated, p.lifecycle);
        try t.expectEqual(@as(?u64, null), p.owner);
        try t.expectEqual(@as(u64, 3), p.binding.?.revision);
        try t.expectEqual(@as(?[32]u8, null), p.binding.?.upgrade_from);
        try t.expectEqual(@as([32]u8, @splat(6)), p.binding.?.workload);
        try t.expectEqualSlices(u8, &(@as([16]u8, @splat(4))), &p.binding.?.incarnation.?);
        try t.expectEqualSlices(u8, &fresh.public_key.toBytes(), &(try e.principal(1)).grant.public_key);
        try t.expectError(error.RetiredProcess, submit(&e, root, .{ .activate = .{ .pid = 1, .revision = 3, .expected_generation = p.generation, .worker = 1, .public_key = worker.public_key.toBytes(), .worker_incarnation = @splat(6) } }));
    } else return error.UnknownPhase;
    std.debug.print("runtime {s}: passed\n", .{args[2]});
}
