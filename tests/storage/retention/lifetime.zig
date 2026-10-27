const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const t = std.testing;

const disk = @import("fixture_native_disk");
const Engine = disk.Engine;
const Clock = struct {
    now: u64,
    fn read(context: *anyopaque) !core.Time.Sample {
        const self: *Clock = @ptrCast(@alignCast(context));
        return .{ .unix_ms = self.now };
    }
};
fn submit(e: *Engine, key: core.Ed25519.KeyPair, principal: u8, command: core.Command) !u64 {
    var current = command;
    if (current == .turn) current.turn.expected_revision = (try e.process(current.turn.pid)).revision;
    return e.submit(try core.sign(.{ .realm = e.genesis.realm, .principal = principal, .sequence = (try e.principal(principal)).sequence + 1, .command = current }, key));
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try core.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const worker = try core.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const genesis: core.Genesis = .{ .realm = 45, .root_key = root.public_key.toBytes(), .allow_history_trim = true, .max_clock_error_ms = 0 };
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-proof", .name = "lifetime" } } };
    var pages = try adapter.PackedPageStore.init(init.gpa, store.journal, 8);
    defer pages.deinit();
    var clock: Clock = .{ .now = 10 };
    if (std.mem.eql(u8, args[2], "write")) {
        try store.journal.create();
        try pages.create();
        var e = try Engine.bootstrap(&store, &pages, genesis);
        e.clock = .{ .context = &clock, .read = Clock.read };
        const pid = try submit(&e, root, 0, .{ .spawn = .{ .work_before_ms = 100, .settle_before_ms = 200, .allow_collection = true } });
        _ = try submit(&e, root, 0, .{ .grant = .{ .subject = 1, .public_key = worker.public_key.toBytes(), .permissions = core.permission(.execute), .pid = pid } });
        _ = try submit(&e, root, 0, .{ .own = .{ .pid = pid, .worker = 1, .expected_generation = 0 } });
        const input = try submit(&e, root, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(7) } });
        _ = try submit(&e, worker, 1, .{ .begin_turn = .{ .pid = pid, .generation = 1, .input = input } });
    } else if (std.mem.eql(u8, args[2], "recover")) {
        var e = try Engine.open(&store, &pages, genesis);
        clock.now = 110;
        e.clock = .{ .context = &clock, .read = Clock.read };
        const permit = (try e.process(1)).turn_permit.?;
        try t.expectError(error.DeadlineExpired, submit(&e, root, 0, .{ .send = .{ .pid = 1, .value = core.Value.integer(9) } }));
        _ = try submit(&e, root, 0, .{ .own = .{ .pid = 1, .worker = 1, .expected_generation = 1 } });
        _ = try submit(&e, worker, 1, .{ .turn = .{ .pid = 1, .generation = 2, .input = permit.input, .expected_revision = 0, .permit = permit.id } });
        _ = try submit(&e, root, 0, .{ .checkpoint = {} });
        try disk.publish(&store);
    } else if (std.mem.eql(u8, args[2], "checkpoint")) {
        var e = try Engine.open(&store, &pages, genesis);
        clock.now = 201;
        e.clock = .{ .context = &clock, .read = Clock.read };
        try t.expectError(error.DeadlineExpired, submit(&e, root, 0, .{ .own = .{ .pid = 1, .worker = 1, .expected_generation = 2 } }));
        var maintenance: core.growing.Maintenance = .{};
        const expiry = (try maintenance.next(&e, try Clock.read(&clock))) orelse return error.ExpectedExpiry;
        _ = try submit(&e, root, 0, expiry);
        _ = try submit(&e, root, 0, .{ .checkpoint = {} });
        try store.maintain(e.head);
    } else if (std.mem.eql(u8, args[2], "trim_recover")) {
        try t.expectError(error.HistoryReclaimed, store.read(0));
        var e = try Engine.open(&store, &pages, genesis);
        try t.expectEqual(.expired, (try e.process(1)).lifecycle);
        try t.expectEqual(@as(u64, 1), (try e.process(1)).consumed);
        try t.expectEqual(@as(?core.protocol.Growth.Input, null), try disk.input(&e, 1));
        try t.expectEqual(@as(u64, 201), e.head.time_floor_ms);
        clock.now = 50;
        e.clock = .{ .context = &clock, .read = Clock.read };
        try t.expectError(error.ClockRollback, submit(&e, root, 0, .{ .spawn = .{ .work_before_ms = 300, .settle_before_ms = 400 } }));
        clock.now = 202;
        try t.expectError(error.RetiredProcess, submit(&e, root, 0, .{ .own = .{ .pid = 1, .worker = 1, .expected_generation = 2 } }));
    } else return error.UnknownPhase;
    std.debug.print("lifetime {s}: passed\n", .{args[2]});
}
