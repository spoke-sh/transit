const std = @import("std");
const r = @import("Relational.zig");
const sql = @import("RelationalSql.zig");
const schema = @import("TableSchema.zig");
const t = std.testing;
const columns = [_]schema.Column{ .{ .id = 1, .name = "key", .type = .int64 }, .{ .id = 2, .name = "value", .type = .int64 } };
const sources = [_]r.Source{
    .{ .alias = "l", .realm = 1, .resource = 101, .catalog = 9, .owner = 7, .schema = .{ .object = 11, .revision = 1, .next_column = 3, .columns = &columns } },
    .{ .alias = "r", .realm = 1, .resource = 202, .catalog = 9, .owner = 7, .schema = .{ .object = 22, .revision = 1, .next_column = 3, .columns = &columns } },
};
const budgets: r.Budgets = .{ .resident_bytes = 4096, .spill_bytes = 8192, .result_bytes = 16384, .output_rows = 1000, .work_steps = 10000, .source_pins = 2 };
const statement = "SELECT l.key, COUNT(*) AS rows, COUNT(r.value) AS values, SUM(r.value) AS total FROM lefts l LEFT JOIN rights r ON r.key = l.key GROUP BY l.key";
fn roundtrip(allocator: std.mem.Allocator) !void {
    var syntax = try sql.parse(allocator, statement, null);
    defer syntax.deinit();
    const plan = try syntax.bind(&sources, .captured, budgets, null);
    const parsed = try std.json.parseFromSlice(struct { identity: struct { prepared: []const u8 } }, allocator, @embedFile("fixtures/relational.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try t.expectEqualStrings(parsed.value.identity.prepared, &std.fmt.bytesToHex(&try plan.fingerprint(), .lower));
    try t.expectEqualStrings("lefts", syntax.targets[0].name);
    try t.expectEqualStrings("rights", syntax.targets[1].name);
}
test "relational SQL and the independent typed definition have the same identity" {
    try roundtrip(t.allocator);
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), roundtrip, .{});
}
test "relational SQL binds shared three-valued predicates and precise unknown names" {
    var location: @import("Sql.zig").Location = .{};
    var syntax = try sql.parse(t.allocator, "SELECT l.value FROM lefts l WHERE NOT (l.key = -1 OR l.value IS NULL) AND l.value >= 3", &location);
    defer syntax.deinit();
    const plan = try syntax.bind(sources[0..1], .interactive, budgets, &location);
    try t.expectEqual(@as(usize, 6), plan.filter.instructions.len);
    var unknown = try sql.parse(t.allocator, "SELECT l.missing FROM lefts l", &location);
    defer unknown.deinit();
    try t.expectError(error.UnknownColumn, unknown.bind(sources[0..1], .interactive, budgets, &location));
    try t.expectEqual(@as(usize, 9), location.offset);
    var ambiguous = try sql.parse(t.allocator, "SELECT key FROM lefts l JOIN rights r ON l.key = r.key", null);
    defer ambiguous.deinit();
    try t.expectError(error.AmbiguousRelationalColumn, ambiguous.bind(&sources, .interactive, budgets, null));
}
test "relational compiler rejects unsupported composition before source binding" {
    for ([_][]const u8{
        "SELECT DISTINCT l.key FROM lefts l",
        "SELECT l.key FROM lefts l LIMIT 1",
        "SELECT l.key FROM lefts l ORDER BY l.key",
        "SELECT l.key FROM lefts l GROUP BY l.key HAVING COUNT(*) > 1",
        "SELECT l.key FROM lefts l RIGHT JOIN rights r ON l.key = r.key",
        "SELECT l.key FROM lefts l JOIN rights r ON l.key > r.key",
        "SELECT l.key FROM lefts l JOIN rights r ON l.key = r.key JOIN more m ON l.key = m.key",
    }) |text| {
        if (sql.parse(t.allocator, text, null)) |value| {
            var owned = value;
            owned.deinit();
            return error.UnexpectedSqlAcceptance;
        } else |_| {}
    }
}
