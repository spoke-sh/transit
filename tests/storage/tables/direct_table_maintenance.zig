//! Real signed Table storage observations, physical work and retained readers.
const std = @import("std");
const c = @import("transit_query").catalog;
const support = @import("fixture_direct_captured_query");
const t = std.testing;
const w = c.DirectTableProtocol;
const counts = [_]usize{ 256, 1, 1 };
const ids = [_]u64{ 7, 71, 8 }; // Two identities collide in the bounded age cache.
const write_count = 48;
const rows_per_write = 1;
pub const State = struct {
    sources: [3]c.DirectTableReader.Basis,
    current: [3]?c.DirectTableReader.Basis = @splat(null),
    maintained: [3]?c.DirectTableReader.Basis = @splat(null),
    writes: ?[write_count]w.Rows = null,
    written: [3]?c.DirectTableReader.Basis = @splat(null),
};

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

/// Fixed retained reads can overlap physical relocation without creating pins,
/// choosing newer cuts or changing the maintenance workload. Each sample checks
/// every independent expected value before reporting completion.
pub fn foreground(init: std.process.Init, client: c.DirectTableClient, state: State, output: *std.Io.Writer) !void {
    for (0..16) |sample| {
        const begin = std.Io.Clock.awake.now(init.io);
        for (state.sources, counts) |source, count| try rows(init, client, source, count);
        const elapsed = begin.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        try std.json.Stringify.value(.{ .sample = sample, .rows = 258, .elapsed_ns = elapsed }, .{}, output);
        try output.writeByte('\n');
        try output.flush();
    }
}

/// Save the complete finite write plan before sending any mutation. Physical
/// maintenance may advance accepted positions; these inserts constrain the
/// exact definition and independent new keys, not a disposable physical root.
pub fn planWrites(init: std.process.Init, client: c.DirectTableClient, state: *State) !void {
    try t.expect(state.writes == null);
    const alloc = init.arena.allocator();
    var writes: [write_count]w.Rows = undefined;
    for (&writes, 0..) |*write, index| {
        const table = index % ids.len;
        const source = state.sources[table];
        const schema: c.fuze.TableSchema.Schema = .{ .object = ids[table], .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }}, .primary_key = &.{1} };
        var schema_bytes: [c.fuze.TableSchema.max_bytes]u8 = undefined;
        const identity: c.protocol.DataLifecycle.Operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 70000 + index };
        const changes = try alloc.alloc(w.RowChange, rows_per_write);
        for (changes, 0..) |*change, row_index| {
            var row_bytes: [c.fuze.TableRow.max_bytes]u8 = undefined;
            const row: c.fuze.TableRow.Row = .{
                .identity = try w.Rows.insertIdentity(identity, @intCast(row_index)),
                .cells = &.{.{ .value = .{ .atom = .{ .signed = @intCast(counts[table] + index / ids.len * rows_per_write + row_index) } } }},
            };
            change.* = .{ .insert = try .encode(alloc, try row.encode(schema, &row_bytes)) };
        }
        write.* = .{
            .binding = .{ .definition = c.protocol.Growth.current_definition, .identity = identity, .target = source.snapshot.object, .action = .insert, .expected_definition = source.interpretation.interpretation, .expected_data = null, .intent = @splat(0) },
            .interpretation = source.interpretation,
            .schema = try .encode(alloc, try schema.encode(&schema_bytes)),
            .changes = changes,
            .ingestion = .point,
        };
        write.binding.intent = try write.digest(alloc);
    }
    state.writes = writes;
}

pub fn runWrites(init: std.process.Init, client: c.DirectTableClient, state: State, recover: bool, output: *std.Io.Writer) !void {
    for (state.writes.?, 0..) |write, index| {
        const begin = std.Io.Clock.awake.now(init.io);
        if (!recover) (try client.call(.{ .admit_rows = write })).deinit();
        const response = try client.call(.{ .operation = .{ .binding = write.binding, .command = if (recover) .inspect else .execute, .steps = 32 } });
        defer response.deinit();
        try t.expect(response.value.result.rows == .committed);
        try t.expectEqual(@as(u64, counts[index % ids.len] + (index / ids.len + 1) * rows_per_write), response.value.result.rows.committed.outcome.live_rows);
        try std.json.Stringify.value(.{ .sample = index, .rows = rows_per_write, .elapsed_ns = begin.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), .receipt = response.value.result }, .{}, output);
        try output.writeByte('\n');
        try output.flush();
        if (!recover) {
            const inspected = try client.call(.{ .operation = .{ .binding = write.binding, .command = .inspect, .steps = 1 } });
            defer inspected.deinit();
            try t.expectEqualDeep(response.value.result, inspected.value.result);
        }
    }
}

pub fn verifyWritten(init: std.process.Init, client: c.DirectTableClient, state: *State) !void {
    for (state.sources, counts, 0..) |source, count, index| {
        // The original cuts must still exclude every later insertion.
        try rows(init, client, source, count);
        if (state.written[index] == null) {
            const observed = try client.call(.{ .storage = .{ .object = source.snapshot.object, .pending_limit = 1024 } });
            defer observed.deinit();
            const response = try client.call(.{ .pin = .{ .object = source.snapshot.object, .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 72000 + index }, .expected = observed.value.result.storage.position } });
            defer response.deinit();
            var reader = try c.DirectTableReader.open(init.gpa, client, .{ .object = source.snapshot.object, .handle = response.value.result.pin });
            defer reader.deinit();
            state.written[index] = reader.basis;
        }
        try rows(init, client, state.written[index].?, count + write_count / ids.len * rows_per_write);
    }
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
            // Concurrent physical work may advance its accepted root. It must
            // preserve logical state and the original fixed flush obligation.
            const after = repeated.value.result.flush.observed;
            try t.expect(after.position.next_lsn >= observed.position.next_lsn);
            try t.expectEqualDeep(observed.interpretation, after.interpretation);
            try t.expectEqual(observed.changed_lsn, after.changed_lsn);
            try t.expectEqual(observed.live_rows, after.live_rows);
            try t.expectEqual(observed.history_floor, after.history_floor);
            try t.expect(after.pending.complete and after.pending.rows == 0);
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

pub fn maintained(init: std.process.Init, client: c.DirectTableClient, state: *State) !void {
    try verify(init, client, state, true);
    for (state.sources, counts, 0..) |source, count, i| {
        if (state.maintained[i] == null) {
            const observed = try client.call(.{ .storage = .{ .object = source.snapshot.object, .pending_limit = 1024 } });
            defer observed.deinit();
            const pinned = try client.call(.{ .pin = .{ .object = source.snapshot.object, .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 60000 + i }, .expected = observed.value.result.storage.position } });
            defer pinned.deinit();
            var reader = try c.DirectTableReader.open(init.gpa, client, .{ .object = source.snapshot.object, .handle = pinned.value.result.pin });
            defer reader.deinit();
            state.maintained[i] = reader.basis;
        }
        try rows(init, client, state.maintained[i].?, count);
    }
}
