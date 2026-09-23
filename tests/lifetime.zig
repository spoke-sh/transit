const std = @import("std");
const transit = @import("transit");
const adapter = @import("transit_ursula");
const t = std.testing;

const Engine = transit.Engine(adapter.Store);
const Clock = struct {
    now: u64,
    fn read(context: *anyopaque) !transit.Time.Sample {
        const self: *Clock = @ptrCast(@alignCast(context));
        return .{ .unix_ms = self.now };
    }
};
fn submit(e: *Engine, key: transit.Ed25519.KeyPair, principal: u8, command: transit.Command) !u64 {
    var current = command;
    if (current == .turn) current.turn.expected_revision = (try e.state.process(current.turn.pid)).revision;
    return e.submit(try transit.sign(.{ .realm = e.state.realm, .principal = principal, .sequence = (try e.state.principal(principal)).sequence + 1, .command = current }, key));
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try transit.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const worker = try transit.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const genesis: transit.Genesis = .{ .realm = 45, .root_key = root.public_key.toBytes(), .retry_policy = .last_per_principal, .max_clock_error_ms = 0 };
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-proof", .name = "lifetime" } } };
    var clock: Clock = .{ .now = 10 };
    if (std.mem.eql(u8, args[2], "write")) {
        try store.journal.create();
        var e = try Engine.bootstrap(&store, genesis);
        e.clock = .{ .context = &clock, .read = Clock.read };
        const pid = try submit(&e, root, 0, .{ .spawn = .{ .deadline_ms = 100, .settle_before_ms = 200, .allow_trim = true } });
        _ = try submit(&e, root, 0, .{ .grant = .{ .subject = 1, .public_key = worker.public_key.toBytes(), .permissions = transit.permission(.execute), .pid = pid } });
        _ = try submit(&e, root, 0, .{ .own = .{ .pid = pid, .worker = 1, .expected_generation = 0 } });
        const input = try submit(&e, root, 0, .{ .send = .{ .pid = pid, .value = transit.Value.integer(7) } });
        _ = try submit(&e, worker, 1, .{ .begin_turn = .{ .pid = pid, .generation = 1, .input = input } });
    } else if (std.mem.eql(u8, args[2], "recover")) {
        var e = try Engine.open(&store, genesis);
        clock.now = 110;
        e.clock = .{ .context = &clock, .read = Clock.read };
        const permit = (try e.state.process(1)).turn_permit.?;
        try t.expectError(error.DeadlineExpired, submit(&e, root, 0, .{ .send = .{ .pid = 1, .value = transit.Value.integer(9) } }));
        _ = try submit(&e, root, 0, .{ .own = .{ .pid = 1, .worker = 1, .expected_generation = 1 } });
        _ = try submit(&e, worker, 1, .{ .turn = .{ .pid = 1, .generation = 2, .input = permit.input, .permit = permit.id, .result = transit.Value.integer(7) } });
        _ = try submit(&e, root, 0, .{ .checkpoint = {} });
        try store.publishCheckpoint(&(try transit.Checkpoint.create(init.gpa, genesis, &e.state)));
    } else if (std.mem.eql(u8, args[2], "checkpoint")) {
        var e = try Engine.open(&store, genesis);
        clock.now = 201;
        e.clock = .{ .context = &clock, .read = Clock.read };
        try t.expectError(error.DeadlineExpired, submit(&e, root, 0, .{ .own = .{ .pid = 1, .worker = 1, .expected_generation = 2 } }));
        _ = try submit(&e, root, 0, (try e.state.nextMaintenance(try Clock.read(&clock))).?);
        _ = try submit(&e, root, 0, .{ .checkpoint = {} });
        try store.maintain(&(try transit.Checkpoint.create(init.gpa, genesis, &e.state)));
    } else if (std.mem.eql(u8, args[2], "trim_recover")) {
        try t.expectError(error.HistoryReclaimed, store.read(0));
        var e = try Engine.open(&store, genesis);
        try t.expectEqual(.expired, (try e.state.process(1)).lifecycle);
        try t.expectEqual(@as(i64, 7), try (try e.state.process(1)).state.asInteger());
        try t.expectEqual(@as(u64, 201), e.state.time_floor_ms);
        clock.now = 50;
        e.clock = .{ .context = &clock, .read = Clock.read };
        try t.expectError(error.ClockRollback, submit(&e, root, 0, .{ .spawn = .{ .deadline_ms = 300, .settle_before_ms = 400 } }));
        clock.now = 202;
        try t.expectError(error.RetiredProcess, submit(&e, root, 0, .{ .own = .{ .pid = 1, .worker = 1, .expected_generation = 2 } }));
    } else return error.UnknownPhase;
    std.debug.print("lifetime {s}: passed\n", .{args[2]});
}
