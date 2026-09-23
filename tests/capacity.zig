//! Fixed, finite physical-capacity profile. Controlled time isolates disk faults
//! from the clock proof; no production authority or external destination.
const std = @import("std");
const t = std.testing;
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");

const Engine = core.Engine(adapter.Store);
fn clock(context: *anyopaque) !core.Time.Sample {
    const now: *u64 = @ptrCast(@alignCast(context));
    return .{ .unix_ms = now.* };
}
fn submit(e: *Engine, key: core.Ed25519.KeyPair, command: core.Command) !u64 {
    var current = command;
    if (current == .turn) current.turn.expected_revision = (try e.state.process(current.turn.pid)).revision;
    return e.submit(try core.sign(.{ .realm = e.state.realm, .principal = 0, .sequence = (try e.state.principal(0)).sequence + 1, .command = current }, key));
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-capacity", .name = "authority" } } };
    const root = try core.Ed25519.KeyPair.generateDeterministic(@splat(19));
    const worker = try core.Ed25519.KeyPair.generateDeterministic(@splat(20));
    const genesis: core.Genesis = .{ .realm = 53, .root_key = root.public_key.toBytes(), .retry_policy = .last_per_principal, .max_clock_error_ms = 1, .admission_ceiling = 256 };
    const write = std.mem.eql(u8, args[2], "write");
    if (write) try store.journal.create();
    var e = if (write) try Engine.bootstrap(&store, genesis) else try Engine.open(&store, genesis);
    var now: u64 = if (write) 10 else 200;
    e.clock = .{ .context = &now, .read = clock };
    if (write) {
        _ = try submit(&e, root, .{ .grant = .{ .subject = 1, .public_key = worker.public_key.toBytes(), .permissions = core.permission(.inspect) } });
        try t.expectEqual(@as(u64, 2), try submit(&e, root, .{ .spawn = .{ .allow_trim = true } }));
        _ = try submit(&e, root, .{ .own = .{ .pid = 2, .worker = 0, .expected_generation = 0 } });
        try t.expectEqual(@as(u64, 4), try submit(&e, root, .{ .spawn = .{ .allow_trim = true, .deadline_ms = 100, .settle_before_ms = 110 } }));
        _ = try submit(&e, root, .{ .send = .{ .pid = 2, .value = core.Value.integer(9) } });
        _ = try submit(&e, root, .{ .turn = .{ .pid = 2, .generation = 1, .input = 5, .result = core.Value.integer(9), .effect = core.Value.integer(9) } });
        _ = try submit(&e, root, .{ .dispatch = .{ .pid = 2, .effect = 6 } });
        _ = try submit(&e, root, .{ .send = .{ .pid = 4, .value = core.Value.integer(42) } });
        while (e.state.position < genesis.admission_ceiling.?) _ = try submit(&e, root, .{ .send = .{ .pid = 2, .value = core.Value.integer(1) } });
        try t.expectError(error.AdmissionClosed, submit(&e, root, .{ .send = .{ .pid = 2, .value = core.Value.integer(999) } }));
        try t.expectEqual(@as(u64, 0), (try e.state.process(2)).cancelled);
    } else if (std.mem.eql(u8, args[2], "control")) {
        // Only the preallocated reserve is released by the harness. The filler
        // remains in place, so these writes really depend on that reservation.
        _ = try submit(&e, root, .{ .revoke = 1 });
        _ = try submit(&e, root, .{ .expire = 4 });
        _ = try submit(&e, root, .{ .close_effect = .{ .pid = 2, .effect = 6, .attempt = 7 } });
        while (try e.nextInput(2, e.state.position)) |input| {
            const p = (try e.state.process(2)).*;
            _ = try submit(&e, root, .{ .turn = .{ .pid = 2, .generation = p.generation, .input = input.position, .result = core.Value.integer((try p.state.asInteger()) + 1) } });
        }
        _ = try submit(&e, root, .{ .checkpoint = {} });
        try store.maintain(&(try core.Checkpoint.create(init.gpa, genesis, &e.state)));
        try t.expect(e.state.position < genesis.admission_ceiling.? + core.controlRecordBudget(genesis.admission_ceiling.?));
    } else if (!std.mem.eql(u8, args[2], "recover")) return error.UnknownPhase;
    if (!write) {
        try t.expectError(error.HistoryReclaimed, store.read(0));
        try t.expectEqual(@as(i64, 256), try (try e.state.process(2)).state.asInteger());
        try t.expectEqual(@as(u64, 0), (try e.state.process(2)).cancelled);
        try t.expectEqual(.running, (try e.state.process(2)).lifecycle);
        try t.expectEqual(.expired, (try e.state.process(4)).lifecycle);
        try t.expectEqual(@as(u64, 1), (try e.state.process(4)).cancelled);
        try t.expectEqual(.closed_unknown, (try e.state.effect(6)).phase);
        try t.expectEqual(@as(u16, 0), (try e.state.principal(1)).grant.permissions);
        try t.expectError(error.AdmissionClosed, submit(&e, root, .{ .send = .{ .pid = 2, .value = core.Value.integer(1) } }));
        // Restarted maintenance is read-only once publication/trim succeeded.
        try store.maintain(&(try core.Checkpoint.create(init.gpa, genesis, &e.state)));
    }
    std.debug.print("capacity {s}: position={d}, reserve-record-bound={d}\n", .{ args[2], e.state.position, core.controlRecordBudget(genesis.admission_ceiling.?) });
}
