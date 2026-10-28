const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const Range = @import("DirectTableCountRange.zig");
const t = std.testing;
const schema: f.TableSchema.Schema = .{
    .object = 1,
    .revision = 1,
    .next_column = 3,
    .columns = &.{ .{ .id = 1, .name = "k", .type = .int64, .nullable = false }, .{ .id = 2, .name = "v", .type = .int64 } },
    .primary_key = &.{1},
};

test "count range bounds match independent signed selection masks" {
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const row_type = try schema.rowType(&fields);
    const Case = struct { predicate: []const u8, selected: u7 };
    // Bits refer to [-9, -3, 0, 1, 2, 7, 14], independently of the encoder.
    for ([_]Case{
        .{ .predicate = "k > 1", .selected = 0b1110000 },
        .{ .predicate = "k >= 1", .selected = 0b1111000 },
        .{ .predicate = "k < 1", .selected = 0b0000111 },
        .{ .predicate = "k <= 1", .selected = 0b0001111 },
        .{ .predicate = "k = 1", .selected = 0b0001000 },
        .{ .predicate = "k >= -3 AND k < 7", .selected = 0b0011110 },
        .{ .predicate = "k > 1 AND k >= 2 AND k <= 7 AND k < 14", .selected = 0b0110000 },
        .{ .predicate = "k >= 2 AND k > 2 AND k <= 7", .selected = 0b0100000 },
        .{ .predicate = "k > 2 AND k >= 2 AND k < 7 AND k <= 7", .selected = 0 },
        .{ .predicate = "k >= 7 AND k <= 2", .selected = 0 },
        .{ .predicate = "k >= 2 AND k < 2", .selected = 0 },
        .{ .predicate = "k = 2 AND k >= 2", .selected = 0b0010000 },
    }) |case| {
        const sql = try std.fmt.allocPrint(t.allocator, "SELECT COUNT(*) FROM items WHERE {s}", .{case.predicate});
        defer t.allocator.free(sql);
        var compiled = try f.TableSelect.compile(t.allocator, sql, "items", row_type, @splat(1), null);
        defer compiled.deinit();
        const range = Range.qualify(schema, compiled.plan) orelse return error.ExpectedCountRange;
        for ([_]i64{ -9, -3, 0, 1, 2, 7, 14 }, 0..) |value, index| {
            const cells = [_]f.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = value } } }};
            var bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
            const key = try f.Collation.encodePrimaryKeySortKey(schema, &cells, false, &bytes);
            const expected = (case.selected & (@as(u7, 1) << @intCast(index))) != 0;
            try t.expectEqual(expected, range.interval().contains(key));
            var failure: ?f.LogicalQuery.Plan.PredicateFailure = null;
            try t.expectEqual(expected, try compiled.plan.matches(&.{ cells[0], .null }, &failure));
        }
    }
}

test "count range qualification preserves order-sensitive and general predicates" {
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    for ([_][]const u8{
        "SELECT k FROM items WHERE k > 1",            "SELECT SUM(k) FROM items WHERE k > 1",
        "SELECT COUNT(k) FROM items WHERE k > 1",     "SELECT COUNT(*) FROM items",
        "SELECT COUNT(*) FROM items WHERE k != 1",    "SELECT COUNT(*) FROM items WHERE k > 1 OR k < 0",
        "SELECT COUNT(*) FROM items WHERE NOT k > 1", "SELECT COUNT(*) FROM items WHERE k > 1 AND v = 2",
        "SELECT COUNT(*) FROM items WHERE k IS NULL",
    }) |sql| {
        var compiled = try f.TableSelect.compile(t.allocator, sql, "items", try schema.rowType(&fields), @splat(1), null);
        defer compiled.deinit();
        try t.expect(Range.qualify(schema, compiled.plan) == null);
    }
    var compiled = try f.TableSelect.compile(t.allocator, "SELECT COUNT(*) FROM items WHERE k > 1", "items", try schema.rowType(&fields), @splat(1), null);
    defer compiled.deinit();
    for ([_]u64{ 0, 2 }) |limit| {
        var limited = compiled.plan;
        limited.limit = limit;
        try t.expect(Range.qualify(schema, limited) == null);
    }
    var null_bound = compiled.plan;
    null_bound.predicate = .{ .null_compare = .{ .column = 0, .op = .gt } };
    try t.expect(Range.qualify(schema, null_bound) == null);
    var keyless = schema;
    keyless.primary_key = &.{};
    try t.expect(Range.qualify(keyless, compiled.plan) == null);
    var composite = schema;
    composite.primary_key = &.{ 1, 2 };
    try t.expect(Range.qualify(composite, compiled.plan) == null);
}

test "count range owns text bounds and rejects unencodable or unsupported keys" {
    var columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "k", .type = .utf8, .nullable = false, .collation = .utf8_binary }};
    const text_schema: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var literal = [_]u8{ 'a', 0, 'b' };
    var plan: f.LogicalQuery.Plan = .{
        .schema = try text_schema.rowType(&fields),
        .source_basis = @splat(1),
        .projection = &.{0},
        .aggregate = .count,
        .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .bytes = &literal } } },
    };
    const range = Range.qualify(text_schema, plan) orelse return error.ExpectedCountRange;
    @memset(&literal, 'z');
    const Case = struct { text: []const u8, selected: bool };
    for ([_]Case{
        .{ .text = "", .selected = false },       .{ .text = "a", .selected = false },
        .{ .text = "a\x00a", .selected = false }, .{ .text = "a\x00b", .selected = true },
        .{ .text = "aa", .selected = true },
        .{ .text = "東京", .selected = true },
    }) |case| {
        var bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
        const cells = [_]f.Types.Values.Cell{.{ .value = .{ .atom = .{ .bytes = case.text } } }};
        try t.expectEqual(case.selected, range.interval().contains(try f.Collation.encodePrimaryKeySortKey(text_schema, &cells, false, &bytes)));
    }
    const wide: [4096]u8 = @splat('x');
    plan.predicate.compare.value = .{ .bytes = &wide };
    try t.expect(Range.qualify(text_schema, plan) == null);
    columns[0].max_characters = 2;
    plan.predicate.compare.value = .{ .bytes = "abc" };
    try t.expect(Range.qualify(text_schema, plan) == null);
    columns[0].max_characters = null;
    columns[0].collation = .ascii_ci;
    try t.expect(Range.qualify(text_schema, plan) == null);
}

test "count range follows declared key position and canonical floating zero" {
    const floating: f.TableSchema.Schema = .{
        .object = 1,
        .revision = 1,
        .next_column = 3,
        .columns = &.{ .{ .id = 1, .name = "v", .type = .int64 }, .{ .id = 2, .name = "k", .type = .float64, .nullable = false } },
        .primary_key = &.{2},
    };
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var plan: f.LogicalQuery.Plan = .{
        .schema = try floating.rowType(&fields),
        .source_basis = @splat(1),
        .projection = &.{0},
        .aggregate = .count,
        .predicate = .{ .compare = .{ .column = 1, .op = .ge, .value = .{ .float = -0.0 } } },
    };
    const Comparison = @FieldType(@FieldType(f.LogicalPredicate.Atom, "compare"), "op");
    for ([_]Comparison{ .ge, .gt }) |op| {
        plan.predicate.compare.op = op;
        const range = Range.qualify(floating, plan) orelse return error.ExpectedCountRange;
        for ([_]f64{ -1.0, -0.0, 0.0, 1.0 }) |value| {
            const cells = [_]f.Types.Values.Cell{.{ .value = .{ .atom = .{ .float = value } } }};
            var bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
            const expected = if (op == .ge) value >= 0.0 else value > 0.0;
            try t.expectEqual(expected, range.interval().contains(try f.Collation.encodePrimaryKeySortKey(floating, &cells, false, &bytes)));
        }
    }
}
