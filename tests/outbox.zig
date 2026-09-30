//! Destination ordering and atomic counter/output recovery with pending delivery.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const disk = @import("native_disk.zig");
const Engine = disk.Engine;
const t = std.testing;
fn submit(e: *Engine, key: core.Ed25519.KeyPair, command: core.Command) !u64 {
    return disk.submit(e, key, 0, command);
}
fn output(e: *Engine, id: u64) !disk.g.Outbox {
    return disk.record(e, disk.g.Outbox, .output, id);
}
fn consume(e: *Engine, key: core.Ed25519.KeyPair, pid: u64) !void {
    const input = (try disk.input(e, pid)).?;
    _ = try submit(e, key, try disk.counterTurn(e, key, 0, pid, (try disk.counter(e, pid)) + (try input.value.asInteger())));
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    const root = try core.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const genesis: core.Genesis = .{ .realm = 46, .root_key = root.public_key.toBytes(), .allow_history_trim = true, .max_clock_error_ms = 0 };
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = "transit-proof", .name = "outbox" } } };
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
        for (0..3) |_| _ = try submit(&e, root, .{ .spawn = .{} });
        for (1..4) |pid| {
            try disk.provisionCounter(&e, root, pid, 0);
            _ = try submit(&e, root, .{ .own = .{ .pid = pid, .worker = 0, .expected_generation = 1 } });
        }
        _ = try submit(&e, root, .{ .send = .{ .pid = 3, .value = core.Value.integer(99) } });
        var turn = try disk.counterTurn(&e, root, 0, 3, 99);
        turn.turn.outputs = .{ .{ .pid = 1, .value = core.Value.integer(1) }, .{ .pid = 1, .value = core.Value.integer(2) }, .{ .pid = 2, .value = core.Value.integer(3) }, null };
        _ = try submit(&e, root, turn);
        _ = try submit(&e, root, .{ .checkpoint = {} });
        try disk.publish(&store);
    } else if (std.mem.eql(u8, args[2], "recover")) {
        try t.expectEqual(.pending, (try output(&e, 1)).phase);
        try store.maintain(e.head);
        try t.expectError(error.HistoryReclaimed, store.read(0));
        try t.expectError(error.RouteBlocked, submit(&e, root, .{ .deliver = 2 }));
        _ = try submit(&e, root, .{ .deliver = 3 });
        try consume(&e, root, 2);
        _ = try submit(&e, root, .{ .checkpoint = {} });
        try disk.publish(&store);
    } else if (std.mem.eql(u8, args[2], "checkpoint")) {
        try t.expectEqual(@as(i64, 3), try disk.counter(&e, 2));
        try t.expectEqual(.pending, (try output(&e, 1)).phase);
        const first = try disk.signed(&e, root, 0, .{ .deliver = 1 });
        const receipt = try e.submit(first);
        e = try Engine.open(&store, &pages, genesis);
        e.clock = .{ .context = &clock, .read = disk.Clock.read };
        try t.expectEqual(receipt, try e.submit(first));
        try t.expectEqual(@as(u64, 1), (try e.process(1)).admitted);
        try consume(&e, root, 1);
        _ = try submit(&e, root, .{ .checkpoint = {} });
        try store.maintain(e.head);
    } else if (std.mem.eql(u8, args[2], "trim_recover")) {
        try t.expectError(error.HistoryReclaimed, store.read(0));
        try t.expectEqual(.pending, (try output(&e, 2)).phase);
        _ = try submit(&e, root, .{ .deliver = 2 });
        try consume(&e, root, 1);
        try t.expectEqual(@as(i64, 3), try disk.counter(&e, 1));
        try t.expectEqual(@as(i64, 3), try disk.counter(&e, 2));
        try t.expectEqual(@as(i64, 99), try disk.counter(&e, 3));
        try t.expectError(error.OutputAlreadyResolved, submit(&e, root, .{ .deliver = 1 }));
    } else return error.UnknownPhase;
    std.debug.print("outbox {s}: passed\n", .{args[2]});
}
