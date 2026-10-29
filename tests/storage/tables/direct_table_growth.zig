//! Public catalog and retained-row traversal beyond the resident page cache.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const t = std.testing;
const support = @import("fixture_direct_captured_query");
const count = 139;
const first_object = 10000;
pub const State = struct { basis: c.DirectTableReader.Basis };

fn listing(client: c.DirectTableClient) !void {
    var after: ?u64 = null;
    var seen: u64 = 0;
    var position: ?q.protocol.DataLifecycle.Position = null;
    for (0..256) |_| {
        const response = try client.call(.{ .list = .{ .namespace = 1, .after = after } });
        defer response.deinit();
        const page = response.value.result.list;
        if (position) |original| try t.expectEqualDeep(original, page.directory_position);
        position = page.directory_position;
        for (page.entries) |slot| if (slot) |entry| {
            try t.expectEqual(first_object + seen, entry.interpretation.object.object);
            var text: [32]u8 = undefined;
            try t.expectEqualStrings(try std.fmt.bufPrint(&text, "growing_{d}", .{seen}), entry.name.slice());
            seen += 1;
        };
        after = page.next orelse {
            try t.expectEqual(@as(u64, count), seen);
            return;
        };
    }
    return error.CatalogPageBudget;
}

fn rows(allocator: std.mem.Allocator, client: c.DirectTableClient, state: State) !void {
    var reader = try c.DirectTableReader.open(allocator, client, state.basis.snapshot);
    defer reader.deinit();
    try t.expectEqualDeep(state.basis, reader.basis);
    var seen: u64 = 0;
    // The public reader owns at most eight decoded rows per batch. Neither the
    // metadata traversal nor row traversal accumulates the durable collection.
    while (try reader.next(client, .{ .rows = 7 })) |value| {
        var page = value;
        defer page.deinit();
        try t.expect(page.count <= 7);
        for (page.rows[0..page.count]) |slot| {
            const row = slot orelse return error.MissingGrowthRow;
            try t.expectEqual(@as(i128, @intCast(seen)), row.row().cells[0].value.atom.signed);
            seen += 1;
        }
        if (page.complete) try t.expectEqual(@as(u64, count), seen);
    }
    try t.expectEqual(@as(u64, count), seen);
}

pub fn write(init: std.process.Init, client: c.DirectTableClient, role: u64) !State {
    var first_arena = std.heap.ArenaAllocator.init(init.gpa);
    defer first_arena.deinit();
    try support.table(first_arena.allocator(), client, role, first_object, "growing_0", 100000, count);
    const metadata = try client.call(.{ .lookup = .{ .namespace = 1, .name = "growing_0" } });
    defer metadata.deinit();
    const definition = metadata.value.result.lookup.?;
    const pinned = try client.call(.{ .pin = .{ .object = definition.interpretation.interpretation.object, .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 200000 }, .expected = definition.position } });
    defer pinned.deinit();
    var reader = try c.DirectTableReader.open(init.gpa, client, .{ .object = definition.interpretation.interpretation.object, .handle = pinned.value.result.pin });
    defer reader.deinit();
    const state: State = .{ .basis = reader.basis };
    try t.expectEqual(@as(u64, count), state.basis.row_count);
    for (1..count) |i| {
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        var text: [32]u8 = undefined;
        try support.table(arena.allocator(), client, role, first_object + i, try std.fmt.bufPrint(&text, "growing_{d}", .{i}), 100000 + 2 * i, 0);
    }
    try listing(client);
    try rows(init.gpa, client, state);
    return state;
}

pub fn recover(init: std.process.Init, client: c.DirectTableClient, state: State) !void {
    try read(init, client, state);
    (try client.call(.{ .release = state.basis.snapshot })).deinit();
}

pub fn read(init: std.process.Init, client: c.DirectTableClient, state: State) !void {
    try listing(client);
    try rows(init.gpa, client, state);
    const status = try client.call(.{ .pin_status = .{ .object = state.basis.snapshot.object, .owner = state.basis.snapshot.handle.owner } });
    defer status.deinit();
    try t.expectEqualDeep(state.basis.snapshot.handle, status.value.result.pin_state.handle.?);
    try t.expect(!status.value.result.pin_state.released);
}

/// A bounded public observation per Table, without retaining the catalog in RAM.
pub fn maintenance(client: c.DirectTableClient, state: State, output: *std.Io.Writer) !void {
    var pending_rows: u64 = 0;
    var busy_tables: usize = 0;
    var segments: u64 = 0;
    for (0..count) |index| {
        var object = state.basis.snapshot.object;
        object.object = first_object + index;
        const response = try client.call(.{ .storage = .{ .object = object, .pending_limit = 1024 } });
        defer response.deinit();
        const observed = response.value.result.storage;
        try t.expectEqual(@as(u64, if (index == 0) count else 0), observed.live_rows);
        try t.expectEqual(0, observed.history_floor);
        try t.expect(observed.pending.complete);
        pending_rows += observed.pending.rows;
        segments += observed.next_segment - 1;
        const work = observed.maintenance;
        const busy = observed.pending.rows != 0 or work.archive_target != null or work.compaction_target != null or
            work.archive_source_lsn != work.archived_source_lsn or
            work.compaction_source_lsn != work.compacted_source_lsn;
        if (busy) {
            busy_tables += 1;
        } else if (work.archive_source_lsn != 0) {
            try t.expect(observed.archive_through > 0);
            try t.expect((observed.recovery_through orelse return error.MissingGrowthRecovery) >= observed.archive_through);
        }
    }
    try std.json.Stringify.value(.{ .tables = count, .rows = count, .pending_rows = pending_rows, .busy_tables = busy_tables, .segments = segments }, .{}, output);
}
