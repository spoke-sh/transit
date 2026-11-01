//! Declared comparison semantics through the signed, disk-backed Table owner.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const f = q.fuze;
const t = std.testing;
fn execute(intent: *const c.DirectTableIntent, client: c.DirectTableClient) !void {
    const admitted = try intent.admit(client);
    defer admitted.deinit();
    const applied = try intent.operation(client, .execute, 32);
    defer applied.deinit();
    switch (applied.value.result) {
        .ddl => |value| try t.expect(value == .committed),
        .rows => |value| try t.expect(value == .committed),
        else => return error.UnexpectedCollationOutcome,
    }
}
fn mutate(client: c.DirectTableClient, operation: u64, sql: []const u8) !void {
    var prepared = try c.DirectTablePreparedDml.prepare(client.allocator, client, 1, sql, .transit, null);
    defer prepared.deinit();
    var intent = try prepared.bind(client.allocator, client, operation, &.{}, .bulk, null);
    defer intent.deinit();
    try execute(&intent, client);
}
fn pin(client: c.DirectTableClient, operation: u64, name: []const u8) !c.DirectTableProtocol.Snapshot {
    const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer lookup.deinit();
    const value = lookup.value.result.lookup.?;
    const response = try client.call(.{ .pin = .{ .object = value.interpretation.interpretation.object, .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = operation }, .expected = value.position } });
    defer response.deinit();
    return .{ .object = value.interpretation.interpretation.object, .handle = response.value.result.pin };
}
fn count(client: c.DirectTableClient, snapshot: c.DirectTableProtocol.Snapshot, name: []const u8, sql: []const u8, expected: u64) !void {
    var query = try q.direct.DirectTableQuery.openRetained(client.allocator, client, snapshot, name, sql, .{ .requests = 100, .rows = 8, .result_bytes = 8192 }, null, null, .{});
    defer query.deinit();
    var rows = try query.nextBatch(8);
    defer rows.deinit();
    try t.expect(rows.complete and rows.len == 1);
    try t.expectEqual(@as(u128, expected), rows.rows[0].?.cells[0].value.atom.unsigned);
}
pub fn run(client: c.DirectTableClient) !void {
    for ([_]struct { name: []const u8, collation: []const u8, range_count: u64, equality_count: u64, literal: []const u8 = "ALPHA" }{
        .{ .name = "folded_rows", .collation = "ASCII_CI", .range_count = 2, .equality_count = 1 },
        .{ .name = "cp037_rows", .collation = "EBCDIC_CP037", .range_count = 3, .equality_count = 0 },
        .{ .name = "cp037_pad_rows", .collation = "EBCDIC_037_PAD", .range_count = 3, .equality_count = 1, .literal = "Alpha   " },
        .{ .name = "cp1047_rows", .collation = "EBCDIC_1047_NOPAD", .range_count = 3, .equality_count = 0, .literal = "Alpha   " },
    }, 0..) |case, i| {
        var arena: std.heap.ArenaAllocator = .init(client.allocator);
        defer arena.deinit();
        const a = arena.allocator();
        const base: u64 = 97000 + i * 100;
        const ddl_text = try std.fmt.allocPrint(a, "CREATE TABLE {s} (k TEXT COLLATE {s} PRIMARY KEY, label TEXT COLLATE {s})", .{ case.name, case.collation, case.collation });
        var ddl = try c.DirectTablePreparedDdl.prepare(a, client, 1, ddl_text, .transit, null);
        defer ddl.deinit();
        var creation = try ddl.bind(a, client, base, 920 + i);
        defer creation.deinit();
        try execute(&creation.table, client);
        try mutate(client, base + 1, try std.fmt.allocPrint(a, "INSERT INTO {s} VALUES ('a','Alpha'),('B','Bravo'),('0','Zero'),('z','Zulu'),('c','Charlie')", .{case.name}));
        const snapshot = try pin(client, base + 2, case.name);
        defer (client.call(.{ .release = snapshot }) catch unreachable).deinit();
        // The index path and identity scan must use the same declared order.
        try count(client, snapshot, case.name, try std.fmt.allocPrint(a, "SELECT COUNT(*) FROM {s} WHERE k < 'B'", .{case.name}), case.range_count);
        try count(client, snapshot, case.name, try std.fmt.allocPrint(a, "SELECT COUNT(*) FROM {s} WHERE k < 'B' AND k IS NOT NULL", .{case.name}), case.range_count);
        const equality = try std.fmt.allocPrint(a, "SELECT COUNT(*) FROM {s} WHERE label = '{s}'", .{ case.name, case.literal });
        try count(client, snapshot, case.name, equality, case.equality_count);
        var prepared = try q.direct.DirectTablePrepared.prepare(a, client, 1, try std.fmt.allocPrint(a, "SELECT COUNT(*) FROM {s} WHERE label = $1", .{case.name}), .transit, null);
        defer prepared.deinit();
        var query = try q.direct.DirectTableQuery.openPreparedRetained(a, client, snapshot, &prepared, &.{.{ .bytes = case.literal }}, .{ .requests = 100, .rows = 8, .result_bytes = 8192 }, null, null, .{});
        defer query.deinit();
        var result = try query.nextBatch(8);
        defer result.deinit();
        try t.expect(result.complete and result.len == 1);
        try t.expectEqual(@as(u128, case.equality_count), result.rows[0].?.cells[0].value.atom.unsigned);

        // Captured descriptions carry the same semantics through source, plan,
        // neutral values and canonical encoding, before a retained page is read.
        const lookup = try client.call(.{ .lookup = .{ .namespace = 1, .name = case.name } });
        defer lookup.deinit();
        var source = try q.TableSource.from(a, client.connection, lookup.value.result.lookup.?);
        defer source.deinit();
        const definition: q.SourceDefinition = .{ .resource = client.connection.scope.resource, .source = .{ .table = source.source } };
        var template = try q.SqlTemplate.init(a, definition, case.name, try std.fmt.allocPrint(a, "SELECT k FROM {s} WHERE label = $1", .{case.name}));
        defer template.deinit();
        var bound = try template.bind(a, definition, &.{.{ .bytes = case.literal }}, .{ .pages = 100, .segments = 100, .result_bytes = 8192 });
        defer bound.deinit();
        const neutral = try q.Values.Bundle.fromNative(a, bound.bundle);
        const restored = try neutral.native(a);
        try t.expectEqualDeep(bound.bundle.plan.collations, restored.plan.collations);
        const captured = try source.source.capture(a, client, snapshot);
        const plan = try restored.bind(try captured.fingerprint());
        var page = try source.source.page(a, captured, try .start(captured), plan, client);
        defer page.deinit();
        try t.expect(page.next.done);
        var selected: u64 = 0;
        for (page.owned[0..page.count]) |row| {
            var failure: ?f.LogicalQuery.Plan.PredicateFailure = null;
            if (try plan.matches(row.?.row().cells, &failure)) selected += 1;
        }
        try t.expectEqual(case.equality_count, selected);
        var forged = bound.bundle;
        forged.plan.collations = .{};
        try t.expectError(error.SourceChanged, forged.validate());

        try mutate(client, base + 3, try std.fmt.allocPrint(a, "UPDATE {s} SET label = 'Changed' WHERE label = '{s}'", .{ case.name, case.literal }));
        const current = try pin(client, base + 4, case.name);
        defer (client.call(.{ .release = current }) catch unreachable).deinit();
        try count(client, current, case.name, try std.fmt.allocPrint(a, "SELECT COUNT(*) FROM {s} WHERE label = 'Changed'", .{case.name}), case.equality_count);
        try count(client, snapshot, case.name, equality, case.equality_count);
        try mutate(client, base + 5, try std.fmt.allocPrint(a, "DELETE FROM {s} WHERE k < 'B'", .{case.name}));
        const deleted = try pin(client, base + 6, case.name);
        defer (client.call(.{ .release = deleted }) catch unreachable).deinit();
        try count(client, deleted, case.name, try std.fmt.allocPrint(a, "SELECT COUNT(*) FROM {s}", .{case.name}), 5 - case.range_count);
        if (i != 0) {
            try count(client, deleted, case.name, try std.fmt.allocPrint(a, "SELECT COUNT(*) FROM {s} WHERE k = 'B '", .{case.name}), if (i == 2) 1 else 0);
            try mutate(client, base + 7, try std.fmt.allocPrint(a, "INSERT INTO {s} VALUES ('^','Caret'),('¬','Not-sign')", .{case.name}));
            const punctuation = try pin(client, base + 8, case.name);
            defer (client.call(.{ .release = punctuation }) catch unreachable).deinit();
            const expected: u64 = if (i == 3) 0 else 1;
            try count(client, punctuation, case.name, try std.fmt.allocPrint(a, "SELECT COUNT(*) FROM {s} WHERE k < '^'", .{case.name}), expected);
            try count(client, punctuation, case.name, try std.fmt.allocPrint(a, "SELECT COUNT(*) FROM {s} WHERE k < '^' AND k IS NOT NULL", .{case.name}), expected);
            try count(client, snapshot, case.name, try std.fmt.allocPrint(a, "SELECT COUNT(*) FROM {s}", .{case.name}), 5);
        }
    }
    std.debug.print("Table collations: ASCII_CI/CP037/CP037 PAD/CP1047, range/scan controls, prepared and captured plans, UPDATE/DELETE and retained snapshots passed.\n", .{});
}
