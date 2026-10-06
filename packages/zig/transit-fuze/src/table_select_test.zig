const std = @import("std");
const e = std.testing;
const select = @import("TableSelect.zig");
const logical = @import("LogicalQuery.zig");
const types = @import("Types.zig");
const ddl = @import("TableDdl.zig");
const dml = @import("TableDml.zig");
const Cell = types.Values.Cell;
const basis: [32]u8 = @splat(17);
const Scan = struct {
    allocator: std.mem.Allocator,
    rows: []const []const Cell,
    offset: usize = 0,
    complete: bool = false,
    fail_at: ?usize = null,
    pub fn deinit(_: *Scan) void {}
    pub fn next(self: *Scan) !?logical.Row {
        if (self.fail_at == self.offset) return error.ReadFailure;
        if (self.offset == self.rows.len) {
            self.complete = true;
            return null;
        }
        var arena: std.heap.ArenaAllocator = .init(self.allocator);
        errdefer arena.deinit();
        const cells = try arena.allocator().dupe(Cell, self.rows[self.offset]);
        self.offset += 1;
        return .{ .arena = arena, .cells = cells };
    }
};
test "typed SELECT shares exact literals and recursive projection with DML" {
    var created = try ddl.compile(e.allocator, "CREATE TABLE \"人\" (\"識別\" INTEGER PRIMARY KEY, amount DECIMAL(18,2), date DATE, payload LIST(TEXT), n INT64)", null, null);
    defer created.deinit();
    const schema = try created.statement.create.bind(19);
    var inserted = try dml.compile(e.allocator, "INSERT INTO \"人\" VALUES (1,12.50,DATE '2000-02-29',LIST('hi',NULL),7),(2,NULL,NULL,LIST(),NULL)", "人", schema, null);
    defer inserted.deinit();
    var fields: [128]types.Field = undefined;
    const query_schema = try schema.rowType(&fields);
    var query = try select.compile(e.allocator, "SELECT p.payload AS nested, p.amount, p.\"識別\" FROM \"人\" AS p WHERE p.amount >= 12.00 AND p.date = DATE '2000-02-29'", "人", query_schema, basis, null);
    defer query.deinit();
    try e.expectEqualSlices(u8, &.{ 3, 1, 0 }, query.plan.projection);
    var output: [128]types.Field = undefined;
    try e.expectEqualStrings("nested", (try query.plan.outputSchema(&output)).structure[0].name);
    var execution = try logical.Execution(Scan, .full_source).init(.{ .allocator = e.allocator, .rows = inserted.plan.action.insert }, query.plan);
    defer execution.deinit();
    var row = (try execution.next()).?;
    defer row.deinit();
    try e.expectEqualStrings("hi", row.cells[0].value.list[0].value.atom.bytes);
    try e.expect(row.cells[0].value.list[1] == .null);
    try e.expectEqual(@as(i128, 1250), row.cells[1].value.atom.decimal);
    try e.expect(try execution.next() == null);
    try e.expectEqual(@as(u64, 2), execution.scanned);
    try e.expectEqual(@as(u64, 1), execution.emitted);
}
test "general SELECT preserves finite aggregates over projected limited inputs" {
    const schema: types.Type = .{ .structure = &.{ .{ .name = "id", .type = .int32 }, .{ .name = "n", .type = .int64, .nullable = true } } };
    const rows: []const []const Cell = &.{ &.{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .signed = 7 } } } }, &.{ .{ .value = .{ .atom = .{ .signed = 2 } } }, .null } };
    const cases = .{
        .{ "SELECT COUNT(*) AS total FROM people", @as(i128, 2) },
        .{ "SELECT COUNT(n) FROM people", @as(i128, 1) },
        .{ "SELECT SUM(n) FROM people", @as(i128, 7) },
        .{ "SELECT SUM(q.amount) AS total FROM (SELECT p.n AS amount FROM people p WHERE p.id>=1 LIMIT 1) AS q", @as(i128, 7) },
        .{ "SELECT COUNT(*) FROM (SELECT * FROM people LIMIT 0) AS q", @as(i128, 0) },
    };
    inline for (cases) |case| {
        var query = try select.compile(e.allocator, case[0], "people", schema, basis, null);
        defer query.deinit();
        var execution = try logical.Execution(Scan, .full_source).init(.{ .allocator = e.allocator, .rows = rows }, query.plan);
        defer execution.deinit();
        var row = (try execution.next()).?;
        defer row.deinit();
        const actual = row.cells[0].value.atom;
        try e.expectEqual(case[1], if (actual == .signed) actual.signed else @as(i128, @intCast(actual.unsigned)));
        try e.expect(try execution.next() == null);
        try e.expect(execution.complete);
    }
}
test "general SELECT supports every schema column and long quoted names" {
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    var fields: [128]types.Field = undefined;
    for (&fields, 0..) |*field, i| field.* = .{ .name = try std.fmt.allocPrint(arena.allocator(), "c{d}", .{i}), .type = if (i % 2 == 0) .uint128 else .utf8, .nullable = true };
    var all = try select.compile(e.allocator, "SELECT * FROM wide", "wide", .{ .structure = &fields }, basis, null);
    defer all.deinit();
    try e.expectEqual(@as(usize, 128), all.plan.projection.len);
    try e.expectEqual(@as(u8, 127), all.plan.projection[127]);
    var text: std.Io.Writer.Allocating = .init(arena.allocator());
    try text.writer.writeAll("SELECT ");
    for (fields, 0..) |field, i| {
        if (i != 0) try text.writer.writeByte(',');
        try text.writer.writeAll(field.name);
    }
    try text.writer.writeAll(" FROM wide");
    var explicit = try select.compile(e.allocator, text.written(), "wide", .{ .structure = &fields }, basis, null);
    defer explicit.deinit();
    try e.expectEqualDeep(try all.plan.fingerprint(), try explicit.plan.fingerprint());
    const long_name: [255]u8 = @splat('a');
    const statement = "SELECT \"" ++ long_name ++ "\" AS \"" ++ long_name ++ "\" FROM \"" ++ long_name ++ "\"";
    var named = try select.compile(e.allocator, statement, &long_name, .{ .structure = &.{.{ .name = &long_name, .type = .boolean }} }, basis, null);
    defer named.deinit();
    try e.expectEqualStrings(&long_name, named.name);
    try e.expectEqualStrings(&long_name, named.plan.output_names[0].?);
    try e.expectEqualStrings(&long_name, try select.target(arena.allocator(), statement));
    try e.expectEqualStrings("wide", try select.target(arena.allocator(), "SELECT COUNT(*) FROM (SELECT * FROM wide LIMIT 1) AS w"));
}
test "general SELECT rejects complete invalid bindings and unsupported constructs" {
    const schema: types.Type = .{ .structure = &.{.{ .name = "n", .type = .int64, .nullable = true }} };
    const cases = .{
        .{ "SELECT * FROM other", error.UnknownSource },
        .{ "SELECT x.n FROM people", error.UnknownQualifier },
        .{ "SELECT no FROM people", error.UnknownColumn },
        .{ "SELECT n,n FROM people", error.DuplicateProjection },
        .{ "SELECT n AS x,n AS x FROM people", error.DuplicateField },
        .{ "SELECT n FROM people WHERE n = NULL", error.UnsupportedNullComparison },
        .{ "SELECT COUNT(*) FROM people LIMIT 1", error.UnsupportedAggregateLimit },
        .{ "SELECT * FROM people LIMIT -1", error.InvalidSqlSyntax },
        .{ "SELECT * FROM people LIMIT 18446744073709551616", error.LiteralOutOfRange },
        .{ "SELECT * FROM people; DROP TABLE people", error.UnsupportedConstruct },
        .{ "SELECT * FROM people JOIN other ON people.n=other.n", error.UnsupportedConstruct },
        .{ "SELECT * FROM (SELECT * FROM people) AS q", error.UnsupportedConstruct },
        .{ "SELECT SUM(q.n) FROM (SELECT n AS amount FROM people) AS q", error.UnknownColumn },
    };
    inline for (cases) |case| try e.expectError(case[1], select.compile(e.allocator, case[0], "people", schema, basis, null));
    var duplicate = try select.compile(e.allocator, "SELECT n AS first,n AS second FROM people", "people", schema, basis, null);
    defer duplicate.deinit();
    try e.expectEqual(@as(usize, 2), duplicate.plan.projection.len);
}
fn ownership(allocator: std.mem.Allocator) !void {
    const text = try allocator.dupe(u8, "SELECT n AS named FROM people WHERE n>=7 OR NOT n IS NULL");
    defer allocator.free(text);
    var query = try select.compile(allocator, text, "people", .{ .structure = &.{.{ .name = "n", .type = .int64, .nullable = true }} }, basis, null);
    defer query.deinit();
    @memset(text, 0);
    try e.expectEqualStrings("people", query.name);
    try e.expectEqualStrings("named", query.plan.output_names[0].?);
    var failure: ?logical.Plan.PredicateFailure = null;
    try e.expect(try query.plan.matches(&.{.{ .value = .{ .atom = .{ .signed = 7 } } }}, &failure));
}
test "general SELECT owns literals and releases every failed allocation" {
    try e.checkAllAllocationFailures(e.allocator, ownership, .{});
}
test "selected-prefix execution stops at LIMIT while file verification consumes the tail" {
    var query = try select.compile(e.allocator, "SELECT * FROM people LIMIT 1", "people", .{ .structure = &.{.{ .name = "n", .type = .int64 }} }, basis, null);
    defer query.deinit();
    const scan: Scan = .{ .allocator = e.allocator, .rows = &.{&.{.{ .value = .{ .atom = .{ .signed = 7 } } }}}, .fail_at = 1 };
    var selected = try logical.Execution(Scan, .selected_prefix).init(scan, query.plan);
    defer selected.deinit();
    var row = (try selected.next()).?;
    row.deinit();
    try e.expect(try selected.next() == null);
    try e.expect(selected.complete and !selected.scan.complete);
    var full = try logical.Execution(Scan, .full_source).init(scan, query.plan);
    defer full.deinit();
    row = (try full.next()).?;
    row.deinit();
    try e.expectError(error.ReadFailure, full.next());
    try e.expect(!full.complete and full.failed);
}
