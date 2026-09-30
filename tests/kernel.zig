//! Conditional commits, current authorization and KV recovery over real disk.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const disk = @import("native_disk.zig");
const Engine = disk.Engine;
const signed = disk.signed;
const submit = disk.submit;
const t = std.testing;
fn inspect(e: *Engine, worker: core.Ed25519.KeyPair) !void {
    _ = try e.query(try disk.g.signQuery(.{ .realm = 42, .principal = 1, .kind = .{ .process = 2 } }, worker));
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try core.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const worker = try core.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const genesis: core.Genesis = .{ .realm = 42, .root_key = root.public_key.toBytes(), .allow_history_trim = true, .max_clock_error_ms = 0 };
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-proof", .name = "kernel" } } };
    var pages = try adapter.PackedPageStore.init(init.gpa, store.journal, 8);
    defer pages.deinit();
    const write = std.mem.eql(u8, args[2], "write");
    if (write) {
        try store.journal.create();
        try pages.create();
    }
    var e = if (write) try Engine.bootstrap(&store, &pages, genesis) else try Engine.open(&store, &pages, genesis);
    var clock: disk.Clock = .{};
    e.clock = .{ .context = &clock, .read = disk.Clock.read };
    if (write) {
        _ = try Engine.bootstrap(&store, &pages, genesis);
        _ = try submit(&e, root, 0, .{ .grant = .{ .subject = 1, .public_key = worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.inspect), .pid = 2 } });
        const spawn = try signed(&e, root, 0, .{ .spawn = .{} });
        _ = try e.submit(spawn); // Lost receipt cannot allocate another identity.
        var recovered = try Engine.open(&store, &pages, genesis);
        recovered.clock = e.clock;
        const pid = try recovered.submit(spawn);
        try t.expectEqual(@as(u64, 2), pid);
        try disk.provisionCounter(&recovered, root, pid, 1);
        _ = try submit(&recovered, root, 0, .{ .own = .{ .pid = pid, .worker = 1, .expected_generation = 1 } });
        for (0..100) |_| _ = try submit(&recovered, root, 0, .{ .send = .{ .pid = pid, .value = core.Value.integer(1) } });
        const proposal = try signed(&recovered, worker, 1, try disk.counterTurn(&recovered, worker, 1, pid, 1));
        var competing = try Engine.open(&store, &pages, genesis);
        competing.clock = e.clock;
        const a = try recovered.prepare(proposal);
        const b = try competing.prepare(proposal);
        try t.expectEqual(@as(i64, 0), try disk.counter(&recovered, pid));
        _ = try recovered.commit(a);
        try t.expectError(error.Conflict, competing.commit(b));
        try t.expectEqual(a.record.position, try competing.submit(proposal));
        const pending = try recovered.prepare(try signed(&recovered, worker, 1, try disk.counterTurn(&recovered, worker, 1, pid, 2)));
        _ = try submit(&competing, root, 0, .{ .revoke = 1 });
        try t.expectError(error.Conflict, recovered.commit(pending));
        try t.expectError(error.Forbidden, inspect(&recovered, worker));
    } else if (std.mem.eql(u8, args[2], "recover")) {
        try t.expectEqual(@as(i64, 1), try disk.counter(&e, 2));
        try t.expectEqual(@as(u64, 100), (try e.process(2)).admitted);
        try t.expectError(error.Forbidden, inspect(&e, worker));
        _ = try submit(&e, root, 0, .{ .grant = .{ .subject = 1, .public_key = worker.public_key.toBytes(), .permissions = core.permission(.execute) | core.permission(.inspect), .pid = 2 } });
        // Reissuing a principal does not revive its resource grants.
        _ = try submit(&e, root, 0, .{ .grant_resource = .{ .resource = try disk.counterResource(&e, 2), .subject = 1, .permissions = 7 } });
        _ = try submit(&e, root, 0, .{ .own = .{ .pid = 2, .expected_generation = 2, .worker = 1 } });
        const next = (try disk.input(&e, 2)).?;
        try t.expectError(error.StaleGeneration, submit(&e, worker, 1, .{ .turn = .{ .pid = 2, .generation = 2, .input = next.position, .expected_revision = 0 } }));
        while (try disk.input(&e, 2)) |input| {
            const command = try disk.counterTurn(&e, worker, 1, 2, (try disk.counter(&e, 2)) + (try input.value.asInteger()));
            _ = try submit(&e, worker, 1, command);
        }
        try t.expectEqual(@as(i64, 100), try disk.counter(&e, 2));
        _ = try submit(&e, root, 0, .{ .checkpoint = {} });
        try disk.publish(&store); // SIGKILL after publication, before trim.
    } else if (std.mem.eql(u8, args[2], "checkpoint")) {
        try t.expectEqual(@as(i64, 100), try disk.counter(&e, 2));
        var idle_store: adapter.Store = .{ .journal = store.journal };
        var idle_pages = try adapter.PackedPageStore.init(init.gpa, store.journal, 8);
        defer idle_pages.deinit();
        var idle = try Engine.open(&idle_store, &idle_pages, genesis);
        _ = try submit(&e, root, 0, .{ .checkpoint = {} });
        try store.maintain(e.head);
        try idle.refresh();
        try t.expectEqual(@as(i64, 100), try disk.counter(&idle, 2));
        try t.expectEqual(e.head.position, idle.head.position);
        try store.maintain(e.head);
        try t.expectError(error.HistoryReclaimed, store.read(0));
        _ = try submit(&e, root, 0, .{ .send = .{ .pid = 2, .value = core.Value.integer(7) } });
        // Paged mailbox roots retain pending inputs across prefix trim.
        _ = try submit(&e, root, 0, .{ .checkpoint = {} });
        try store.maintain(e.head);
    } else if (std.mem.eql(u8, args[2], "trim_recover")) {
        try t.expectError(error.HistoryReclaimed, store.read(0));
        try t.expectEqual(@as(i64, 100), try disk.counter(&e, 2));
        try t.expectEqual(@as(i64, 7), try (try disk.input(&e, 2)).?.value.asInteger());
        _ = try submit(&e, worker, 1, try disk.counterTurn(&e, worker, 1, 2, 107));
        _ = try submit(&e, root, 0, .{ .terminate = 2 });
        var replay = try Engine.open(&store, &pages, genesis);
        try t.expectEqual(.terminated, (try replay.process(2)).lifecycle);
        try t.expectEqual(@as(i64, 107), try disk.counter(&replay, 2));
        try t.expectError(error.RetiredProcess, submit(&replay, root, 0, .{ .send = .{ .pid = 2, .value = core.Value.integer(1) } }));
    } else return error.UnknownPhase;
    std.debug.print("kernel {s}: passed\n", .{args[2]});
}
