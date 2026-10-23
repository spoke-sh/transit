//! Direct retained-source pushdown agrees with complete logical predicates.
const std = @import("std");
const t = std.testing;
const q = @import("transit_query");
const c = q.catalog;
const f = q.fuze;
const w = c.DirectTableProtocol;
const support = @import("direct_captured_query.zig");
fn matches(plan: f.LogicalQuery.Plan, cells: []const f.Types.Values.Cell) !bool {
    var failed: ?f.LogicalQuery.Plan.PredicateFailure = null;
    return plan.matches(cells, &failed);
}
pub fn run(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64) !void {
    const alloc = init.arena.allocator();
    const schema: f.TableSchema.Schema = .{ .object = 85, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64, .nullable = false }, .{ .id = 2, .name = "value", .type = .int64 } }, .primary_key = &.{1} };
    var keys: [43]i64 = undefined;
    keys[0] = std.math.minInt(i64);
    for (keys[1..42], 0..) |*value, i| value.* = @as(i64, @intCast(i)) - 20;
    keys[42] = std.math.maxInt(i64);
    var cells: [43][2]f.Types.Values.Cell = undefined;
    var changes: [43]w.RowChange = undefined;
    const scratch = try alloc.alloc(u8, f.TableRow.max_bytes);
    for (keys, &cells, &changes, 0..) |value, *row, *change, i| {
        row.* = .{ .{ .value = .{ .atom = .{ .signed = value } } }, if (value == 0) .null else .{ .value = .{ .atom = .{ .signed = value } } } };
        change.* = .{ .insert = try .encode(alloc, try (f.TableRow.Row{ .identity = try w.Rows.insertIdentity(.{ .scope = client.connection.scope, .principal = 101, .operation = 1051 }, @intCast(i)), .cells = row }).encode(schema, scratch)) };
    }
    try support.tableRows(alloc, client, role, "predicate_edges", 1050, schema, &changes);
    const found = try client.call(.{ .lookup = .{ .namespace = 1, .name = "predicate_edges" } });
    defer found.deinit();
    const definition = found.value.result.lookup.?;
    var source = try q.TableSource.from(init.gpa, client.connection, definition);
    defer source.deinit();
    const acquired = try client.call(.{ .pin = .{ .object = definition.interpretation.interpretation.object, .owner = .{ .scope = client.connection.scope, .principal = 101, .operation = 1052 }, .expected = definition.position } });
    defer acquired.deinit();
    const snapshot: w.Snapshot = .{ .object = definition.interpretation.interpretation.object, .handle = acquired.value.result.pin };
    const basis = try source.source.capture(init.gpa, client, snapshot);
    const start = try q.TableSource.Cursor.start(basis);
    for (0..2) |column| for (std.enums.values(f.Unified.Plan.Comparison)) |op| for ([_]i64{ std.math.minInt(i64), -21, -1, 0, 19, 21, std.math.maxInt(i64) }) |bound| {
        const plan: f.LogicalQuery.Plan = .{ .schema = source.source.row_type, .source_basis = try basis.fingerprint(), .projection = &.{ 0, 1 }, .predicate = .{ .compare = .{ .column = @intCast(column), .op = op, .value = .{ .signed = bound } } } };
        var expected: [keys.len]i64 = undefined;
        var expected_count: usize = 0;
        for (keys, cells) |key, row| if (try matches(plan, &row)) {
            expected[expected_count] = key;
            expected_count += 1;
        };
        var cursor = start;
        var count: usize = 0;
        var pages: usize = 0;
        while (!cursor.done) {
            var page = try source.source.page(init.gpa, basis, cursor, plan, client);
            defer page.deinit();
            for (page.engine().rows) |row| if (try matches(plan, row.cells)) {
                try t.expect(count < expected_count);
                try t.expectEqual(@as(i128, expected[count]), row.cells[0].value.atom.signed);
                count += 1;
            };
            pages += 1;
            cursor = page.next;
        }
        try t.expectEqual(expected_count, count);
        if (column == 0 and op == .eq) try t.expectEqual(@as(usize, 1), pages) else try t.expect(pages > 1);
    };
    const point: f.LogicalQuery.Plan = .{ .schema = source.source.row_type, .source_basis = try basis.fingerprint(), .projection = &.{ 0, 1 }, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .signed = 1 } } } };
    var compound = point;
    compound.predicate = .{ .program = .{ .instructions = &.{ .{ .atom = .{ .compare = point.predicate.compare } }, .{ .atom = .all }, .disjunction } } };
    var cursor = start;
    var selected: usize = 0;
    while (!cursor.done) {
        var page = try source.source.page(init.gpa, basis, cursor, compound, client);
        defer page.deinit();
        for (page.engine().rows) |row| {
            try t.expect(try matches(compound, row.cells));
            try t.expectEqual(@as(i128, keys[selected]), row.cells[0].value.atom.signed);
            selected += 1;
        }
        cursor = page.next;
    }
    try t.expectEqual(keys.len, selected);
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(basis.retained.authority.table), .owner = 0 } });
    try t.expectError(error.CatalogDenied, source.source.page(init.gpa, basis, start, point, client));
    try t.expectError(error.CatalogDenied, source.source.page(init.gpa, basis, start, compound, client));
    _ = try admin.change(.{ .transfer_object = .{ .object = c.TableAuthority.reference(basis.retained.authority.table), .owner = role } });
    (try client.call(.{ .release = snapshot })).deinit();
}
