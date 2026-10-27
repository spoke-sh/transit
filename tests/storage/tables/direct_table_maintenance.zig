//! Real signed Table storage observations, physical work and retained readers.
const std = @import("std");
const c = @import("transit_query").catalog;
const support = @import("fixture_direct_captured_query");
const t = std.testing;
const counts = [_]usize{ 256, 1, 1 };
const ids = [_]u64{ 7, 71, 8 }; // Two identities collide in the bounded age cache.
pub const State = struct { sources: [3]c.DirectTableReader.Basis, current: [3]?c.DirectTableReader.Basis = @splat(null) };

pub fn prepare(init: std.process.Init, client: c.DirectTableClient, role: u64) !State {
    (try client.call(.initialize)).deinit();
    var state: State = .{ .sources = undefined };
    for (&state.sources, ids, counts, 0..) |*source, object, count, i| {
        var arena: std.heap.ArenaAllocator = .init(init.gpa);
        defer arena.deinit();
        var name: [32]u8 = undefined;
        const title = try std.fmt.bufPrint(&name, "flushing_{d}", .{object});
        try support.table(arena.allocator(), client, role, object, title, 30000 + 2 * i, count);
        const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = title } });
        defer lookup.deinit();
        const selected = lookup.value.result.lookup.?;
        const pinned = try client.call(.{ .pin = .{ .object = selected.interpretation.interpretation.object, .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 40000 + i }, .expected = selected.position } });
        defer pinned.deinit();
        var reader = try c.DirectTableReader.open(init.gpa, client, .{ .object = selected.interpretation.interpretation.object, .handle = pinned.value.result.pin });
        defer reader.deinit();
        source.* = reader.basis;
    }
    try verify(init, client, &state, false);
    return state;
}

pub fn inspect(client: c.DirectTableClient, state: State, output: *std.Io.Writer) !void {
    var observations: [3]c.DirectCatalog.StorageObservation = undefined;
    for (&observations, state.sources) |*observation, source| {
        const response = try client.call(.{ .storage = .{ .object = source.snapshot.object, .pending_limit = 1024 } });
        defer response.deinit();
        observation.* = response.value.result.storage;
    }
    try std.json.Stringify.value(observations, .{}, output);
}

fn rows(init: std.process.Init, client: c.DirectTableClient, source: c.DirectTableReader.Basis, count: usize) !void {
    var reader = try c.DirectTableReader.open(init.gpa, client, source.snapshot);
    defer reader.deinit();
    try t.expectEqualDeep(source, reader.basis);
    var seen: usize = 0;
    while (try reader.next(client, .{ .rows = 7 })) |page_value| {
        var page = page_value;
        defer page.deinit();
        for (page.rows[0..page.count]) |slot| {
            const row = slot.?;
            try t.expectEqual(@as(i128, @intCast(seen)), row.row().cells[0].value.atom.signed);
            seen += 1;
        }
    }
    try t.expectEqual(count, seen);
}

pub fn verify(init: std.process.Init, client: c.DirectTableClient, state: *State, flushed: bool) !void {
    for (state.sources, counts, 0..) |source, count, i| {
        const response = try client.call(.{ .storage = .{ .object = source.snapshot.object, .pending_limit = 1024 } });
        defer response.deinit();
        const observed = response.value.result.storage;
        try t.expect(observed.pending.complete);
        try t.expectEqual(@as(u64, if (flushed) 0 else count), observed.pending.rows);
        try t.expectEqual(source.changed_lsn, observed.changed_lsn);
        try t.expectEqual(@as(u64, 0), observed.history_floor);
        try rows(init, client, source, count);
        if (flushed) {
            const target: c.DirectCatalog.FlushTarget = .{ .object = source.snapshot.object, .through = source.accepted };
            const repeated = try client.call(.{ .flush = target });
            defer repeated.deinit();
            try t.expect(repeated.value.result.flush.complete);
            try t.expectEqualDeep(observed, repeated.value.result.flush.observed);
            if (state.current[i] == null) {
                const pinned = try client.call(.{ .pin = .{ .object = source.snapshot.object, .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 50000 + i }, .expected = observed.position } });
                defer pinned.deinit();
                var current = try c.DirectTableReader.open(init.gpa, client, .{ .object = source.snapshot.object, .handle = pinned.value.result.pin });
                defer current.deinit();
                state.current[i] = current.basis;
            }
            try rows(init, client, state.current[i].?, count);
        }
    }
}
