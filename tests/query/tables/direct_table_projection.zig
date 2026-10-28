//! Projection through the signed disk owner, retained reader and finite Fuze.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const f = q.fuze;
const t = std.testing;
const Snapshot = c.DirectTableProtocol.Snapshot;

fn execute(intent: *const c.DirectTableIntent, client: c.DirectTableClient) !void {
    const admitted = try intent.admit(client);
    defer admitted.deinit();
    const applied = try intent.operation(client, .execute, 32);
    defer applied.deinit();
    switch (applied.value.result) {
        .ddl => |value| try t.expect(value == .committed),
        .rows => |value| try t.expect(value == .committed),
        else => return error.UnexpectedProjectionOutcome,
    }
}
fn insert(client: c.DirectTableClient, operation: u64, sql: []const u8, ingestion: c.storage.TablePartition.Ingestion) !void {
    var prepared = try c.DirectTablePreparedDml.prepare(client.allocator, client, 1, sql, .transit, null);
    defer prepared.deinit();
    var intent = try prepared.bind(client.allocator, client, operation, &.{}, ingestion, null);
    defer intent.deinit();
    try execute(&intent, client);
}
fn pin(client: c.DirectTableClient, operation: u64, name: []const u8) !Snapshot {
    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer lookup.deinit();
    const value = lookup.value.result.lookup.?;
    const response = try client.call(.{ .pin = .{ .object = value.interpretation.interpretation.object, .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = operation }, .expected = value.position } });
    defer response.deinit();
    return .{ .object = value.interpretation.interpretation.object, .handle = response.value.result.pin };
}
fn open(client: c.DirectTableClient, snapshot: Snapshot, name: []const u8, sql: []const u8) !q.direct.DirectTableQuery {
    return q.direct.DirectTableQuery.openRetained(client.allocator, client, snapshot, name, sql, .{ .requests = 200, .rows = 64, .result_bytes = 65536 }, null, null, .{});
}
fn scores(query: *q.direct.DirectTableQuery) !void {
    try t.expect(query.execution.scan.reader.filter != null);
    try t.expectEqualSlices(u8, &.{ 0, 2, 3 }, query.execution.scan.reader.projection.?.columns());
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const output = try query.schema(&fields);
    try t.expectEqualStrings("first", output.structure[0].name);
    try t.expectEqualStrings("second", output.structure[1].name);
    var count: usize = 0;
    while (true) {
        var batch = try query.nextBatch(3);
        defer batch.deinit();
        for (batch.rows[0..batch.len]) |row| {
            count += 1;
            try t.expectEqual(@as(i128, @intCast(count)), row.?.cells[0].value.atom.signed);
            try t.expectEqualDeep(row.?.cells[0], row.?.cells[1]);
        }
        if (batch.complete) break;
    }
    try t.expectEqual(@as(usize, 18), count);
    try t.expectEqual(@as(u64, 18), query.execution.scan.reader.consumed);
}

pub fn run(client: c.DirectTableClient, admin: anytype, role: u64) !void {
    var arena: std.heap.ArenaAllocator = .init(client.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var ddl = try c.DirectTablePreparedDdl.prepare(a, client, 1, "CREATE TABLE projected_rows (k BIGINT PRIMARY KEY, payload TEXT, label TEXT COLLATE ASCII_CI, score BIGINT)", .transit, null);
    defer ddl.deinit();
    var creation = try ddl.bind(a, client, 98000, 930);
    defer creation.deinit();
    try execute(&creation.table, client);
    const payload = try a.alloc(u8, 16384);
    @memset(payload, 'x');
    const metadata = try client.call(.{ .lookup = .{ .namespace = 1, .name = "projected_rows" } });
    defer metadata.deinit();
    var schema = try f.TableSchema.decode(a, try metadata.value.result.lookup.?.schema.decode(a, f.TableSchema.max_bytes));
    defer schema.deinit();
    // Wide typed ingestion has its own byte budget; SQL scalar parameters keep
    // their separate 220-byte bound.
    var cells: [17][4]f.Types.Values.Cell = undefined;
    var rows: [17][]const f.Types.Values.Cell = undefined;
    for (&cells, &rows, 0..) |*row, *reference, i| {
        row.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(17 - i) } } }, .{ .value = .{ .atom = .{ .bytes = payload } } }, .{ .value = .{ .atom = .{ .bytes = "Alpha" } } }, .{ .value = .{ .atom = .{ .signed = @intCast(i + 1) } } } };
        reference.* = row;
    }
    var insertion = try c.DirectTableIntent.fromDml(a, client.connection, metadata.value.result.lookup.?, 98001, .{ .name = "projected_rows", .schema = schema.schema, .action = .{ .insert = &rows } }, .bulk);
    defer insertion.deinit();
    try execute(&insertion, client);
    try insert(client, 98002, "INSERT INTO projected_rows VALUES (18,'wal','Alpha',18)", .point);
    const snapshot = try pin(client, 98003, "projected_rows");
    defer (client.call(.{ .release = snapshot }) catch unreachable).deinit();
    // A later write must not alter the retained source or projected coverage.
    try insert(client, 98004, "INSERT INTO projected_rows VALUES (19,'later','Alpha',19)", .point);
    var reader = try c.DirectTableReader.open(client.allocator, client, snapshot);
    defer reader.deinit();
    try t.expectError(error.InvalidProjection, reader.selectColumns(&.{3}));
    try t.expectError(error.Rejected, client.call(.{ .column_scan = .{ .snapshot = snapshot, .columns = &.{3}, .after = null, .limits = .{} } }));
    try reader.selectColumns(&.{ 0, 3 });
    var first = (try reader.next(client, .{ .rows = 2, .encoded_bytes = 1024 })).?;
    defer first.deinit();
    try t.expectEqual(@as(usize, 2), first.count);
    try t.expectEqual(@as(usize, 2), first.rows[0].?.row().cells.len);
    try t.expectEqual(@as(i128, 17), first.rows[0].?.row().cells[0].value.atom.signed);
    try t.expectError(error.InvalidTableCursor, reader.selectColumns(&.{0}));
    try t.expectError(error.InvalidTableCursor, client.call(.{ .column_scan = .{ .snapshot = snapshot, .columns = &.{0}, .after = reader.after, .limits = .{} } }));
    while (try reader.next(client, .{ .rows = 2, .encoded_bytes = 1024 })) |next| {
        var batch = next;
        batch.deinit();
    }
    try t.expect(reader.complete and reader.consumed == 18);
    try t.expectEqual(@as(i128, 1), first.rows[0].?.row().cells[1].value.atom.signed);
    var query = try open(client, snapshot, "projected_rows", "SELECT score AS first, score AS second FROM projected_rows WHERE label = 'ALPHA'");
    defer query.deinit();
    try scores(&query);
    var prepared = try q.direct.DirectTablePrepared.prepare(a, client, 1, "SELECT score AS first, score AS second FROM projected_rows WHERE label = $1", .transit, null);
    defer prepared.deinit();
    var bound = try q.direct.DirectTableQuery.openPreparedRetained(client.allocator, client, snapshot, &prepared, &.{.{ .bytes = "aLPHa" }}, .{ .requests = 200, .rows = 64, .result_bytes = 65536 }, null, null, .{});
    defer bound.deinit();
    try scores(&bound);
    try filters(client, snapshot);
    for ([_]struct { sql: []const u8, expected: u64 }{
        .{ .sql = "SELECT COUNT(*) FROM projected_rows", .expected = 18 },
        .{ .sql = "SELECT COUNT(score) FROM projected_rows WHERE label = 'ALPHA'", .expected = 18 },
        .{ .sql = "SELECT SUM(score) FROM projected_rows", .expected = 171 },
    }) |case| {
        var aggregate = try open(client, snapshot, "projected_rows", case.sql);
        defer aggregate.deinit();
        try t.expect(aggregate.execution.scan.reader.projection != null);
        var batch = try aggregate.nextBatch(8);
        defer batch.deinit();
        try t.expect(batch.complete and batch.len == 1);
        const value = batch.rows[0].?.cells[0].value.atom;
        try t.expectEqual(case.expected, if (value == .signed) @as(u64, @intCast(value.signed)) else @as(u64, @intCast(value.unsigned)));
    }
    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = "projected_rows" } });
    defer lookup.deinit();
    const object = c.TableAuthority.reference(lookup.value.result.lookup.?.authorization);
    errdefer _ = admin.change(.{ .transfer_object = .{ .object = object, .owner = role } }) catch null;
    const Revoke = struct {
        admin: @TypeOf(admin),
        object: @TypeOf(object),
        fn evaluate(context: *anyopaque, batch: *f.Batch, _: ?*const std.atomic.Value(bool)) !void {
            const self: *@This() = @ptrCast(@alignCast(context));
            batch.evaluate();
            _ = try self.admin.change(.{ .transfer_object = .{ .object = self.object, .owner = 0 } });
        }
    };
    var revoke: Revoke = .{ .admin = admin, .object = object };
    var denied = try q.direct.DirectTableQuery.openRetained(client.allocator, client, snapshot, "projected_rows", "SELECT score FROM projected_rows WHERE score > 16", .{ .requests = 100, .rows = 8, .result_bytes = 8192 }, null, null, .{ .runner = .{ .context = &revoke, .evaluate = Revoke.evaluate } });
    defer denied.deinit();
    try t.expectError(error.AccessDenied, denied.nextBatch(8));
    try t.expectError(error.AccessDenied, query.nextBatch(8));
    _ = try admin.change(.{ .transfer_object = .{ .object = object, .owner = role } });
    try t.expectError(error.FailedQuery, denied.nextBatch(8));
    var empty_denied = try q.direct.DirectTableQuery.openRetained(client.allocator, client, snapshot, "projected_rows", "SELECT COUNT(*) FROM projected_rows WHERE score > 18", .{ .requests = 100, .rows = 8, .result_bytes = 8192 }, null, null, .{ .runner = .{ .context = &revoke, .evaluate = Revoke.evaluate } });
    defer empty_denied.deinit();
    try t.expectError(error.AccessDenied, empty_denied.nextBatch(8));
    _ = try admin.change(.{ .transfer_object = .{ .object = object, .owner = role } });
    try states(client, role, a);
    const released = try pin(client, 98005, "projected_rows");
    var closed = try open(client, released, "projected_rows", "SELECT score FROM projected_rows");
    defer closed.deinit();
    (try client.call(.{ .release = released })).deinit();
    try t.expectError(error.Conflict, closed.nextBatch(8));
    try t.expectEqual(q.protocol.ErrorCode.QueryExpired, closed.native_rejection.?);
    std.debug.print("Table projection: wide segments and WAL rows, 1 KiB pages, column-bound cursors, exact retained coverage, owned rows, prepared ASCII_CI predicates, named duplicates, aggregates, ordered failures and post-compute/terminal revocation passed.\n", .{});
}

fn states(client: c.DirectTableClient, role: u64, a: std.mem.Allocator) !void {
    // A keyless Table verifies identity keys and original diagnostic names when
    // the physical plan drops a column before the aggregate input. Accepted
    // Table rows cannot store type-error/conflict cells; SUM supplies a real
    // ordered operator failure instead.
    const schema: f.TableSchema.Schema = .{ .object = 931, .revision = 1, .next_column = 4, .columns = &.{
        .{ .id = 1, .name = "payload", .type = .binary },
        .{ .id = 2, .name = "value", .type = .int64 },
        .{ .id = 3, .name = "extra", .type = .binary },
    } };
    const values = [_]f.Types.Values.Cell{ .null, .{ .value = .{ .atom = .{ .signed = std.math.maxInt(i64) } } }, .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .signed = -std.math.maxInt(i64) } } }, .null };
    var changes: [values.len]c.DirectTableProtocol.RowChange = undefined;
    const scratch = try a.alloc(u8, f.TableRow.max_bytes);
    for (values, &changes, 0..) |value, *change, i| {
        const row: f.TableRow.Row = .{ .identity = try c.DirectTableProtocol.Rows.insertIdentity(.{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 98101 }, @intCast(i)), .cells = &.{ .null, value, .null } };
        change.* = .{ .insert = try .encode(a, try row.encode(schema, scratch)) };
    }
    try @import("fixture_direct_captured_query").tableRows(a, client, role, "projection_states", 98100, schema, &changes);
    const snapshot = try pin(client, 98102, "projection_states");
    defer (client.call(.{ .release = snapshot }) catch unreachable).deinit();
    var prefix = try open(client, snapshot, "projection_states", "SELECT value FROM projection_states WHERE value > 0 LIMIT 1");
    defer prefix.deinit();
    var first = try prefix.nextBatch(8);
    defer first.deinit();
    try t.expect(first.complete and first.len == 1);
    try t.expectEqualSlices(u8, &.{1}, prefix.execution.scan.reader.projection.?.columns());
    {
        var failed = try open(client, snapshot, "projection_states", "SELECT SUM(value) FROM projection_states WHERE value > 0");
        defer failed.deinit();
        try t.expectError(error.Overflow, failed.nextBatch(8));
        const evidence = failed.execution.failure.?;
        try t.expectEqual(@as(u64, 3), evidence.row);
        try t.expectEqualStrings("value", evidence.columnName());
        try t.expectEqualDeep(try failed.compiled.plan.fingerprint(), evidence.plan);
        try t.expectError(error.FailedQuery, failed.nextBatch(8));
    }
    for ([_]struct { sql: []const u8, expected: u128 }{
        .{ .sql = "SELECT COUNT(*) FROM projection_states", .expected = 5 },
        .{ .sql = "SELECT COUNT(value) FROM projection_states", .expected = 3 },
    }) |case| {
        var counted = try open(client, snapshot, "projection_states", case.sql);
        defer counted.deinit();
        var count = try counted.nextBatch(8);
        defer count.deinit();
        try t.expect(count.complete and count.len == 1);
        try t.expectEqual(case.expected, count.rows[0].?.cells[0].value.atom.unsigned);
    }
}

fn filters(client: c.DirectTableClient, snapshot: Snapshot) !void {
    var query = try open(client, snapshot, "projected_rows", "SELECT score FROM projected_rows WHERE score > 16");
    defer query.deinit();
    var reader = try c.DirectTableReader.open(client.allocator, client, snapshot);
    defer reader.deinit();
    try reader.selectPlan(query.compiled.plan);
    for (0..2) |i| {
        var skipped = (try reader.next(client, .{ .rows = 2, .encoded_bytes = 1024 })).?;
        defer skipped.deinit();
        try t.expect(!skipped.complete and skipped.count == 0 and reader.after != null);
        try t.expectEqual(@as(u64, (i + 1) * 8), reader.consumed);
    }
    var selected = (try reader.next(client, .{ .rows = 2, .encoded_bytes = 1024 })).?;
    defer selected.deinit();
    try t.expect(selected.complete and selected.count == 2 and reader.consumed == 18);
    try t.expectEqualSlices(u64, &.{ 17, 18 }, selected.ordinals[0..2]);
    var result = try query.nextBatch(8);
    defer result.deinit();
    try t.expect(result.complete and result.len == 2);
    try t.expectEqual(@as(u64, 18), query.execution.scanned);
    for (result.rows[0..2], 17..) |row, i| try t.expectEqual(@as(i128, @intCast(i)), row.?.cells[0].value.atom.signed);
    for ([_]struct { sql: []const u8, count: u8, scanned: u64 }{
        .{ .sql = "SELECT score FROM projected_rows WHERE score > 16 LIMIT 1", .count = 1, .scanned = 17 },
        .{ .sql = "SELECT score FROM projected_rows WHERE score > 16 LIMIT 0", .count = 0, .scanned = 0 },
        .{ .sql = "SELECT score FROM projected_rows WHERE score > 18", .count = 0, .scanned = 18 },
    }) |case| {
        var limited = try open(client, snapshot, "projected_rows", case.sql);
        defer limited.deinit();
        var batch = try limited.nextBatch(8);
        defer batch.deinit();
        try t.expect(batch.complete and batch.len == case.count);
        try t.expectEqual(case.scanned, limited.execution.scanned);
        try t.expectEqual(case.scanned, limited.execution.scan.reader.consumed);
    }
    for ([_]struct { sql: []const u8, expected: u64 }{
        .{ .sql = "SELECT COUNT(*) FROM projected_rows WHERE score > 18", .expected = 0 },
        .{ .sql = "SELECT COUNT(score) FROM projected_rows WHERE score > 16", .expected = 2 },
        .{ .sql = "SELECT SUM(score) FROM projected_rows WHERE score > 16", .expected = 35 },
    }) |case| {
        var aggregate = try open(client, snapshot, "projected_rows", case.sql);
        defer aggregate.deinit();
        var batch = try aggregate.nextBatch(8);
        defer batch.deinit();
        try t.expect(batch.complete and batch.len == 1);
        try t.expectEqual(@as(u64, 18), aggregate.execution.scanned);
        const value = batch.rows[0].?.cells[0].value.atom;
        try t.expectEqual(case.expected, if (value == .signed) @as(u64, @intCast(value.signed)) else @as(u64, @intCast(value.unsigned)));
    }
    const filter = reader.filter.?;
    var wrong = filter.plan.plan;
    wrong.source_basis[0] ^= 1;
    var buffer: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    const wire = try c.DirectTableProtocol.Binary.encode(client.allocator, try f.LogicalPlanCodec.encode(wrong, &buffer));
    defer client.allocator.free(wire.base64);
    try t.expectError(error.Rejected, client.call(.{ .filter_scan = .{ .snapshot = snapshot, .plan = wire, .fingerprint = try wrong.fingerprint(), .after = null, .limits = .{} } }));
    try t.expectEqual(q.protocol.ErrorCode.InvalidRequest, client.service.last_rejection.?);
    var fingerprint = filter.fingerprint;
    fingerprint[0] ^= 1;
    try t.expectError(error.Conflict, client.call(.{ .filter_scan = .{ .snapshot = snapshot, .plan = filter.wire, .fingerprint = fingerprint, .after = null, .limits = .{} } }));
    try t.expectEqual(q.protocol.ErrorCode.Conflict, client.service.last_rejection.?);
    std.debug.print("Table filtering: two empty pages, original ordinals, segment/WAL matches, LIMIT, empty aggregates, wrong source and wrong plan rejection passed.\n", .{});
}
