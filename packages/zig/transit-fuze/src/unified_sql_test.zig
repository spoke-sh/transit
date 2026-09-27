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
    const old: f.Sql.Source = .{ .name = try f.model.Name.init("items"), .schema = .{ .names = .{ try f.model.Name.init("id"), try f.model.Name.init("value") }, .value_type = .int64 } };
    try t.expectError(error.UnsupportedLimit, f.Sql.plan("SELECT * FROM items LIMIT 33", old));
    _ = try f.Sql.plan("SELECT * FROM items WHERE value = NULL", old);
}
