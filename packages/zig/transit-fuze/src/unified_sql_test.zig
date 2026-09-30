const std = @import("std");
const f = @import("root.zig");
const m = f.Unified;
const t = std.testing;
fn source(columns: []const m.Column) !m.Sql.Source {
    return .{ .name = try m.Name.init("items"), .schema = .{ .columns = columns } };
}
test "unified SQL owns projections and literal bytes and preserves v1 parsing" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const columns = [_]m.Column{
        .{ .name = try m.Name.init("id"), .type = .int64 },
        .{ .name = try m.Name.init("value"), .type = .utf8 },
        .{ .name = try m.Name.init("replica"), .type = .uint64 },
    };
    var text = "SELECT value, id FROM items WHERE value <> 'it''s 東京' LIMIT 18446744073709551615".*;
    const plan = try m.Sql.plan(arena.allocator(), &text, try source(&columns));
    @memset(&text, 0);
    try t.expectEqualSlices(u8, &.{ 1, 0 }, plan.projection);
    try t.expectEqualStrings("it's 東京", plan.predicate.compare.value.utf8);
    try t.expectEqual(std.math.maxInt(u64), plan.limit.?);
    const star = try m.Sql.plan(arena.allocator(), "SELECT * FROM items", try source(&columns));
    try t.expectEqualSlices(u8, &.{ 0, 1, 2 }, star.projection);
    try t.expect(star.limit == null);
    var bytes: [m.Codec.max_plan_bytes]u8 = undefined;
    const saved = try m.Codec.encode(plan, &bytes);
    const restored = try m.Codec.decode(saved);
    try t.expectEqualSlices(u8, plan.projection, restored.projection);
    try t.expectEqualStrings(plan.predicate.compare.value.utf8, restored.predicate.compare.value.utf8);
}
test "unified SQL keeps explicit null distinct and preserves ordered failure" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const columns = [_]m.Column{.{ .name = try m.Name.init("value"), .type = .int64 }};
    const src = try source(&columns);
    const nulls = try m.Sql.plan(arena.allocator(), "SELECT value FROM items WHERE value IS NULL", src);
    try t.expect(try nulls.matches(.{ .cells = &.{.null} }));
    try t.expect(!try nulls.matches(.{ .cells = &.{.missing} }));
    const comparison = try m.Sql.plan(arena.allocator(), "SELECT value FROM items WHERE value > 0", src);
    try t.expect(!try comparison.matches(.{ .cells = &.{.null} }));
    try t.expect(!try comparison.matches(.{ .cells = &.{.missing} }));
    try t.expectError(error.QueryTypeError, comparison.matches(.{ .cells = &.{.{ .type_error = .utf8 }} }));
    try t.expectError(error.QueryConflict, comparison.matches(.{ .cells = &.{.{ .conflict = &.{} }} }));
    const plan = try m.Sql.plan(arena.allocator(), "SELECT sum(chosen.value) FROM (SELECT value FROM items LIMIT 1) AS chosen", src);
    try t.expectEqual(m.Plan.Aggregate.sum, plan.aggregate);
    try t.expectEqual(@as(?u64, 1), plan.limit);
    const rows = [_]m.Row{
        .{ .cells = &.{.{ .value = .{ .int64 = std.math.maxInt(i64) } }} },
        .{ .cells = &.{.{ .value = .{ .int64 = 1 } }} },
        .{ .cells = &.{.{ .value = .{ .int64 = -1 } }} },
    };
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    const cancel = f.execution.Cancellation.init(false);
    inline for (.{ m.SourceKind.kv, m.SourceKind.table, m.SourceKind.document }) |kind| {
        const basis: m.Basis = .{ .kind = kind, .resource = 1, .revision = 9, .schema = try src.schema.fingerprint(), .contract = @splat(7) };
        const bound = try plan.bind(basis, src.schema);
        var changed = basis;
        changed.revision += 1;
        try t.expectError(error.SourceChanged, m.Stream.step(bound, .start(bound), .{ .basis = changed, .ordinal = 0, .rows = &rows, .end = true }, workspace, &output, &cancel));
        const cancelled = f.execution.Cancellation.init(true);
        try t.expectError(error.Cancelled, m.Stream.step(bound, .start(bound), .{ .basis = basis, .ordinal = 0, .rows = &rows, .end = true }, workspace, &output, &cancelled));
        const result = try m.Stream.step(bound, .start(bound), .{ .basis = basis, .ordinal = 0, .rows = &rows, .end = true }, workspace, &output, &cancel);
        try t.expectEqual(std.math.maxInt(i64), result.progress.sum.?);
        try t.expectEqual(m.Stream.Finish.limit, result.progress.finished.?);
        const unlimited = try m.Sql.plan(arena.allocator(), "SELECT sum(value) FROM items", src);
        const full = try unlimited.bind(basis, src.schema);
        try t.expectError(error.Overflow, m.Stream.step(full, .start(full), .{ .basis = basis, .ordinal = 0, .rows = &rows, .end = true }, workspace, &output, &cancel));
    }
}
test "unified SQL rejects unsupported semantics without broadening v1" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const columns = [_]m.Column{
        .{ .name = try m.Name.init("id"), .type = .int64 },
        .{ .name = try m.Name.init("value"), .type = .uint64 },
    };
    const src = try source(&columns);
    const a = arena.allocator();
    try t.expectError(error.UnsupportedNullComparison, m.Sql.plan(a, "SELECT * FROM items WHERE id = NULL", src));
    try t.expectError(error.TypeMismatch, m.Sql.plan(a, "SELECT * FROM items WHERE value = 1", src));
    try t.expectError(error.UnsupportedAggregate, m.Sql.plan(a, "SELECT sum(value) FROM items", src));
    try t.expectError(error.UnsupportedAggregateLimit, m.Sql.plan(a, "SELECT count(*) FROM items LIMIT 1", src));
    try t.expectError(error.UnknownColumn, m.Sql.plan(a, "SELECT sum(chosen.id) FROM (SELECT value FROM items) AS chosen", src));
    try t.expectError(error.DuplicateProjection, m.Sql.plan(a, "SELECT id, id FROM items", src));
    try t.expectError(error.UnknownSource, m.Sql.plan(a, "SELECT * FROM other", src));
    try t.expectError(error.UnknownQualifier, m.Sql.plan(a, "SELECT other.id FROM items", src));
    try t.expectError(error.UnsupportedStatement, m.Sql.plan(a, "CREATE KV items (UTF8)", src));
    try t.expectError(error.UnsupportedConstruct, m.Sql.plan(a, "SELECT * FROM items; SELECT * FROM items", src));
}

test "wide SQL projections preserve order and reject holes in externally supplied ASTs" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var columns: [8]m.Column = undefined;
    for (&columns, 0..) |*column, i| {
        column.* = .{ .name = try m.Name.init(&.{ 'c', @as(u8, @intCast(i)) + '0' }), .type = .int64 };
    }
    const src = try source(&columns);
    const plan = try m.Sql.plan(arena.allocator(), "SELECT c7, c6, c5, c4, c3, c2, c1, c0 FROM items", src);
    try t.expectEqualSlices(u8, &.{ 7, 6, 5, 4, 3, 2, 1, 0 }, plan.projection);
    try t.expectError(error.DuplicateProjection, m.Sql.plan(arena.allocator(), "SELECT c0, c1, c0 FROM items", src));
    try t.expectError(error.InvalidProjection, m.Sql.plan(arena.allocator(), "SELECT c0, c1, c2, c3, c4, c5, c6, c7, c0 FROM items", src));
    var ast = try f.Sql.parse("SELECT c0, c1, c2 FROM items");
    ast.selection.rows[1] = null;
    try t.expectError(error.InvalidProjection, m.Sql.compile(arena.allocator(), ast, src));
    ast.selection.rows[0] = null;
    try t.expectError(error.InvalidProjection, m.Sql.compile(arena.allocator(), ast, src));
    const hints = try f.Sql.hints("SELECT c0, c1, ");
    try t.expectEqual(f.Sql.NameRole.column, hints.name_role.?);
}

test "SQL exposes five exact states and existing full-width scalar plans" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const columns = [_]m.Column{
        .{ .name = try m.Name.init("counter"), .type = .uint64 },
        .{ .name = try m.Name.init("fraction"), .type = .float64 },
        .{ .name = try m.Name.init("value"), .type = .utf8 },
    };
    const src = try source(&columns);
    const states = [_]m.State{ .null, .missing, .type_error, .value, .conflict };
    for ([_][]const u8{ "NULL", "MISSING", "TYPE_ERROR", "VALUE", "CONFLICT" }, states) |word, state| {
        const text = try std.fmt.allocPrint(a, "SELECT value FROM items WHERE value IS {s}", .{word});
        const plan = try m.Sql.plan(a, text, src);
        const cells = [_]m.Cell{ .null, .missing, .{ .type_error = .int64 }, .{ .value = .{ .utf8 = "ok" } }, .{ .conflict = &.{} } };
        for (cells, states) |cell, expected| try t.expectEqual(state == expected, try plan.matches(.{ .cells = &.{ .null, .null, cell } }));
        var actual: [m.Codec.max_plan_bytes]u8 = undefined;
        var wanted: [m.Codec.max_plan_bytes]u8 = undefined;
        try t.expectEqualSlices(u8, try m.Codec.encode(.{ .projection = &.{2}, .predicate = .{ .state = .{ .column = 2, .value = state } } }, &wanted), try m.Codec.encode(plan, &actual));
    }
    const wide = try m.Sql.plan(a, "SELECT counter FROM items WHERE counter = '18446744073709551615'::uint64", src);
    try t.expectEqual(std.math.maxInt(u64), wide.predicate.compare.value.uint64);
    const negative_zero = try m.Sql.plan(a, "SELECT fraction FROM items WHERE fraction = '-0.0'::float64", src);
    try t.expectEqual(@as(u64, 1) << 63, @as(u64, @bitCast(negative_zero.predicate.compare.value.float64)));
    var bytes: [m.Codec.max_plan_bytes]u8 = undefined;
    const decoded = try m.Codec.decode(try m.Codec.encode(negative_zero, &bytes));
    try t.expectEqual(@as(u64, 1) << 63, @as(u64, @bitCast(decoded.predicate.compare.value.float64)));
    for ([_][]const u8{ "-1", "+1", "1_000", "", "1.0", " 1" }) |literal| {
        const text = try std.fmt.allocPrint(a, "SELECT counter FROM items WHERE counter = '{s}'::uint64", .{literal});
        try t.expectError(error.InvalidNumericLiteral, m.Sql.plan(a, text, src));
    }
    try t.expectError(error.LiteralOutOfRange, m.Sql.plan(a, "SELECT counter FROM items WHERE counter = '18446744073709551616'::uint64", src));
    for ([_][]const u8{ "NaN", "Infinity", "0x1p0", "1_000", "", ".", "1e", " 1" }) |literal| {
        const text = try std.fmt.allocPrint(a, "SELECT fraction FROM items WHERE fraction = '{s}'::float64", .{literal});
        try t.expectError(error.InvalidNumericLiteral, m.Sql.plan(a, text, src));
    }
    try t.expectError(error.LiteralOutOfRange, m.Sql.plan(a, "SELECT fraction FROM items WHERE fraction = '1e999'::float64", src));
    try t.expectError(error.TypeMismatch, m.Sql.plan(a, "SELECT fraction FROM items WHERE fraction = '1'::uint64", src));
    try t.expectError(error.TypeMismatch, m.Sql.plan(a, "SELECT counter FROM items WHERE counter = '1'::float64", src));
    _ = try f.Sql.parse("SELECT missing, type_error, value, conflict, uint64, float64 FROM items");
}
