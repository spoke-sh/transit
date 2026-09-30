//! Physical v1 pressure proof: one resident page, retained state, finite reserve.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const g = core.protocol.Growth;
const t = std.testing;
const Engine = core.growing.Engine(adapter.Store, adapter.PackedPageStore);
const ceiling = 96;
const reserve = 96;
const Expected = struct { pid: u64, resource: u64, finite: u64, effect: u64, attempt: u64, last: g.SignedRequest, receipt: u64 };

fn clock(context: *anyopaque) !core.Time.Sample {
    return .{ .unix_ms = @as(*u64, @ptrCast(@alignCast(context))).* };
}
fn pair() !core.Ed25519.KeyPair {
    return core.Ed25519.KeyPair.generateDeterministic(@splat(19));
}
fn signed(engine: *Engine, command: g.Command) !g.SignedRequest {
    return g.sign(.{ .realm = 53, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = command }, try pair());
}
fn submit(engine: *Engine, command: g.Command) !u64 {
    return engine.submit(try signed(engine, command));
}
fn query(engine: *Engine, kind: @FieldType(g.Query, "kind")) !g.Response {
    return engine.query(try g.signQuery(.{ .realm = 53, .principal = 0, .kind = kind }, try pair()));
}
fn value(index: u8) core.Value {
    return core.Value.init(&@as([256]u8, @splat(index))) catch unreachable;
}
fn write(engine: *Engine) !Expected {
    _ = try submit(engine, .{ .grant = .{ .subject = 65536, .public_key = (try pair()).public_key.toBytes(), .permissions = core.all_permissions } });
    const pid = try submit(engine, .{ .spawn = .{} });
    const resource = try submit(engine, .{ .create_resource = .{ .writer = pid, .owned = false } });
    _ = try submit(engine, .{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = core.protocol.State.all_permissions } });
    _ = try submit(engine, .{ .associate = .{ .pid = pid, .name = try core.Value.init("state"), .resource = resource } });
    _ = try submit(engine, .{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 0 } });
    var last: g.SignedRequest = undefined;
    var receipt: u64 = 0;
    for (0..10) |batch| {
        const input = try submit(engine, .{ .send = .{ .pid = pid, .value = .{} } });
        const view = try submit(engine, .{ .open_view = .{ .pid = pid, .generation = 2, .input = input, .expected_revision = (try engine.process(pid)).revision, .resource = resource, .revision = (try query(engine, .{ .resource = resource })).body.resource.revision, .deadline_ms = 1000 } });
        var turn: g.Turn = .{ .pid = pid, .generation = 2, .input = input, .expected_revision = (try engine.process(pid)).revision, .views = .{ view, null, null, null }, .write_view = view };
        for (&turn.mutations, 0..) |*mutation, offset| {
            const index: u8 = @intCast(batch * 4 + offset);
            mutation.* = .{ .key = try core.Value.init(&.{index}), .value = value(index) };
        }
        last = try signed(engine, .{ .turn = turn });
        receipt = try engine.submit(last);
    }
    const finite = try submit(engine, .{ .spawn = .{ .work_before_ms = 100, .settle_before_ms = 110 } });
    _ = try submit(engine, .{ .send = .{ .pid = finite, .value = .{} } });
    const input = try submit(engine, .{ .send = .{ .pid = pid, .value = .{} } });
    const effect = try submit(engine, .{ .turn = .{ .pid = pid, .generation = 2, .input = input, .expected_revision = (try engine.process(pid)).revision, .effect = value(42) } });
    const attempt = try submit(engine, .{ .dispatch = .{ .pid = pid, .effect = effect } });
    while (engine.head.position < ceiling) _ = try submit(engine, .{ .send = .{ .pid = pid, .value = value(1) } });
    return .{ .pid = pid, .resource = resource, .finite = finite, .effect = effect, .attempt = attempt, .last = last, .receipt = receipt };
}
fn verify(engine: *Engine, expected: Expected) !void {
    const response = try query(engine, .{ .capabilities = {} });
    try t.expectEqual(@as(?u64, ceiling), response.body.capabilities.admission_ceiling);
    try t.expectEqual(@as(u64, reserve), response.body.capabilities.control_reserve);
    const before = engine.head.position;
    const created = engine.page_store.created;
    try t.expectError(error.AdmissionClosed, submit(engine, .{ .send = .{ .pid = expected.pid, .value = .{} } }));
    try t.expectEqual(expected.receipt, try engine.submit(expected.last));
    try t.expectEqual(before, engine.head.position);
    try t.expectEqual(created, engine.page_store.created);
    const resource = (try query(engine, .{ .resource = expected.resource })).body.resource;
    try t.expectEqual(@as(u64, 40), resource.entries);
    var after: ?core.Value = null;
    var count: u8 = 0;
    while (true) {
        const page = (try query(engine, .{ .entries = .{ .resource = expected.resource, .revision = resource.revision, .after = after } })).body.entries.page;
        for (page.entries) |slot| if (slot) |entry| {
            try t.expectEqualSlices(u8, &.{count}, entry.key.slice());
            try t.expect(entry.value.eql(value(count)));
            count += 1;
        };
        after = page.next;
        if (after == null) break;
    }
    try t.expectEqual(@as(u8, 40), count);
    const process = try engine.process(expected.pid);
    try t.expectEqual(.running, process.lifecycle);
    try t.expectEqual(@as(u64, 0), process.cancelled);
    if (engine.head.position > ceiling) {
        try t.expectEqual(process.admitted, process.consumed);
        try t.expectEqual(.expired, (try engine.process(expected.finite)).lifecycle);
        try t.expectEqual(@as(u64, 1), (try engine.process(expected.finite)).cancelled);
        const effect = (try query(engine, .{ .effects = .{ .pid = expected.pid } })).body.effects.entries[0].?;
        try t.expectEqual(expected.effect, effect.id);
        try t.expectEqual(.closed_unknown, effect.phase);
        try t.expectEqual(@as(u16, 0), (try engine.principal(65536)).grant.permissions);
    } else try t.expect(process.admitted > process.consumed);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 256 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-capacity", .name = "authority" } } };
    var pages = try adapter.PackedPageStore.init(init.gpa, store.journal, 1);
    defer pages.deinit();
    const genesis: core.growing.Genesis = .{ .realm = 53, .root_key = (try pair()).public_key.toBytes(), .max_clock_error_ms = 1, .allow_history_trim = true, .admission_ceiling = ceiling, .control_reserve = reserve };
    const writing = std.mem.eql(u8, args[2], "write");
    if (writing) {
        try store.journal.create();
        try pages.create();
    }
    var engine = if (writing) try Engine.bootstrap(&store, &pages, genesis) else try Engine.open(&store, &pages, genesis);
    var now: u64 = if (writing) 10 else 200;
    engine.clock = .{ .context = &now, .read = clock };
    var oracle = store.journal;
    oracle.stream.name = "proof-expectations";
    const expected = if (writing) blk: {
        const result = try write(&engine);
        try oracle.create();
        const bytes = try std.json.Stringify.valueAlloc(init.gpa, result, .{});
        defer init.gpa.free(bytes);
        try t.expect(try oracle.append(0, bytes));
        break :blk result;
    } else blk: {
        var response = try oracle.read(0);
        defer response.deinit();
        const parsed = try std.json.parseFromSlice(Expected, init.gpa, response.body, .{});
        defer parsed.deinit();
        break :blk parsed.value;
    };
    if (std.mem.eql(u8, args[2], "pressure")) {
        const request = try signed(&engine, .{ .revoke = 65536 });
        if (engine.submit(request)) |_| return error.PressuredStoreAcceptedMutation else |_| {}
        try engine.refresh();
        try t.expectEqual(@as(u64, ceiling), engine.head.position);
        try t.expectEqual(core.all_permissions, (try engine.principal(65536)).grant.permissions);
    } else if (std.mem.eql(u8, args[2], "control")) {
        _ = try submit(&engine, .{ .revoke = 65536 });
        _ = try submit(&engine, .{ .expire = expected.finite });
        _ = try submit(&engine, .{ .close_effect = .{ .pid = expected.pid, .effect = expected.effect, .attempt = expected.attempt } });
        while ((try query(&engine, .{ .process = expected.pid })).body.process.input) |input| {
            _ = try submit(&engine, .{ .turn = .{ .pid = expected.pid, .generation = 2, .input = input.position, .expected_revision = (try engine.process(expected.pid)).revision } });
        }
        _ = try submit(&engine, .{ .checkpoint = {} });
        try store.maintain(engine.head);
        try t.expect(engine.head.position < ceiling + reserve);
    } else if (!writing and !std.mem.eql(u8, args[2], "recover")) return error.UnknownPhase;
    pages.clearCache();
    try verify(&engine, expected);
    try t.expect(40 * 256 > pages.residentBytes());
    if (engine.head.position > ceiling) {
        try t.expectError(error.HistoryReclaimed, store.read(0));
        try store.maintain(engine.head);
    }
    var buffer: [2048]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(.{ .profile = "native_v1", .phase = args[2], .admission_ceiling = ceiling, .control_reserve = reserve, .position = engine.head.position, .rows = 40, .resident_bytes = pages.residentBytes(), .created_pages = pages.created, .page_requests = pages.requests }, .{}, &stdout.interface);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
