const std = @import("std");
const e = std.testing;
const f = @import("root.zig");
const t = f.Types;
const Prepared = f.LogicalPrepared;
const basis: [32]u8 = @splat(7);
const schema: t.Type = .{ .structure = &.{
    .{ .name = "id", .type = .int128 },
    .{ .name = "name", .type = .utf8, .nullable = true },
    .{ .name = "value", .type = .int64 },
    .{ .name = "maximum", .type = .uint64 },
    .{ .name = "detail", .type = .{ .structure = &.{.{ .name = "nested", .type = .int32 }} } },
} };
const text = "SELECT detail, id, name FROM people WHERE id >= $1 AND NOT (name = $2 OR name IS NULL) LIMIT $3";
const values = [_]t.Values.Atom{ .{ .signed = std.math.minInt(i128) }, .{ .bytes = "it's 東京'; DROP TABLE people; -- $4" }, .{ .unsigned = std.math.maxInt(u64) } };
test "SQL single atoms preserve typed plan bytes with grouping and parameters" {
    const input: t.Type = .{ .structure = &.{.{ .name = "id", .type = .int128, .nullable = true }} };
    for ([_]struct { sql: []const u8, atom: f.LogicalQuery.Plan.Atom, parameters: []const t.Values.Atom }{
        .{ .sql = "SELECT id FROM people WHERE ((id = -1))", .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .signed = -1 } } }, .parameters = &.{} },
        .{ .sql = "SELECT id FROM people WHERE ((id = $1))", .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .signed = -1 } } }, .parameters = &.{.{ .signed = -1 }} },
        .{ .sql = "SELECT id FROM people WHERE ((id IS NULL))", .atom = .{ .state = .{ .column = 0, .value = .null } }, .parameters = &.{} },
    }) |case| {
        var template = try Prepared.init(e.allocator, case.sql, "people", input, basis, null);
        defer template.deinit();
        var bound = try template.bind(e.allocator, "people", input, basis, case.parameters, null);
        defer bound.deinit();
        const typed: f.LogicalQuery.Plan = .{ .schema = input, .source_basis = basis, .projection = &.{0}, .predicate = switch (case.atom) {
            inline else => |value, tag| @unionInit(@FieldType(f.LogicalQuery.Plan, "predicate"), @tagName(tag), value),
        } };
        var actual: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
        var expected: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
        try e.expectEqualSlices(u8, try f.LogicalPlanCodec.encode(typed, &expected), try f.LogicalPlanCodec.encode(bound.plan, &actual));
        try e.expectEqual(try typed.fingerprint(), try bound.plan.fingerprint());
    }
}
fn owned(allocator: std.mem.Allocator) !void {
    var input = text.*;
    var value_bytes = "it's 東京'; DROP TABLE people; -- $4".*;
    var template = try Prepared.init(allocator, &input, "people", schema, basis, null);
    var template_live = true;
    defer if (template_live) template.deinit();
    @memset(&input, 0);
    try e.expectEqual(@as(usize, 3), template.parameterTypes().len);
    try e.expectEqual(.int128, template.parameterTypes()[0]);
    const parameters = [_]t.Values.Atom{ values[0], .{ .bytes = &value_bytes }, values[2] };
    var bound = try template.bind(allocator, "people", schema, basis, &parameters, null);
    defer bound.deinit();
    template.deinit();
    template_live = false;
    @memset(&value_bytes, 0);
    try e.expectEqual(std.math.maxInt(u64), bound.plan.limit.?);
    try e.expectEqual(std.math.minInt(i128), bound.plan.predicate.program.instructions[0].atom.compare.value.signed);
    try e.expectEqualStrings(values[1].bytes, bound.plan.predicate.program.instructions[1].atom.compare.value.bytes);
    try e.expectEqualStrings("nested", bound.plan.schema.structure[4].type.structure[0].name);
    try e.expectEqual(.true_value, try bound.plan.predicate.program.truth(bound.plan.schema, &.{
        .{ .value = .{ .atom = values[0] } }, .{ .value = .{ .atom = .{ .bytes = "Ada" } } },
    }));
    var bytes: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    _ = try f.LogicalPlanCodec.encode(bound.plan, &bytes);
}
test "logical templates and independent bindings own text schema and exact values through every allocation failure" {
    try owned(e.allocator);
    try e.checkAllAllocationFailures(e.allocator, owned, .{});
}
test "logical template bindings match independent canonical plan bytes" {
    const Fixture = struct { schema_hex: []const u8, select_hex: []const u8, select_fingerprint: []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, e.allocator, @embedFile("fixtures/table-schema.json"), .{ .ignore_unknown_fields = true });
    defer fixture.deinit();
    var schema_bytes: [f.TableSchema.max_bytes]u8 = undefined;
    var table = try f.TableSchema.decode(e.allocator, try std.fmt.hexToBytes(&schema_bytes, fixture.value.schema_hex));
    defer table.deinit();
    var fields: [128]t.Field = undefined;
    const input = try table.schema.rowType(&fields);
    var template = try Prepared.init(e.allocator, "SELECT name AS chosen, id FROM people WHERE id = $1 OR name IS NULL LIMIT $2", "people", input, basis, null);
    defer template.deinit();
    var bound = try template.bind(e.allocator, "people", input, basis, &.{ .{ .signed = 12 }, .{ .unsigned = 3 } }, null);
    defer bound.deinit();
    var expected: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    var actual: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    try e.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, fixture.value.select_hex), try f.LogicalPlanCodec.encode(bound.plan, &actual));
    var fingerprint: [32]u8 = undefined;
    try e.expectEqualSlices(u8, try std.fmt.hexToBytes(&fingerprint, fixture.value.select_fingerprint), &try bound.plan.fingerprint());
}
test "logical templates infer every scalar comparison family and keep bound atom bits" {
    for ([_]struct { kind: t.Type, value: t.Values.Atom }{
        .{ .kind = .int8, .value = .{ .signed = -128 } },
        .{ .kind = .int16, .value = .{ .signed = -32768 } },
        .{ .kind = .int32, .value = .{ .signed = std.math.minInt(i32) } },
        .{ .kind = .int64, .value = .{ .signed = std.math.minInt(i64) } },
        .{ .kind = .int128, .value = .{ .signed = std.math.minInt(i128) } },
        .{ .kind = .uint8, .value = .{ .unsigned = 255 } },
        .{ .kind = .uint16, .value = .{ .unsigned = 65535 } },
        .{ .kind = .uint32, .value = .{ .unsigned = std.math.maxInt(u32) } },
        .{ .kind = .uint64, .value = .{ .unsigned = std.math.maxInt(u64) } },
        .{ .kind = .uint128, .value = .{ .unsigned = std.math.maxInt(u128) } },
        .{ .kind = .float32, .value = .{ .float = -0.0 } },
        .{ .kind = .float64, .value = .{ .float = -0.0 } },
        .{ .kind = .{ .decimal = .{ .precision = 38, .scale = 7 } }, .value = .{ .decimal = -12345678901234567890123456789012345678 } },
        .{ .kind = .boolean, .value = .{ .boolean = true } },
        .{ .kind = .utf8, .value = .{ .bytes = "東京" } },
        .{ .kind = .binary, .value = .{ .bytes = "\x00\xff" } },
        .{ .kind = .date, .value = .{ .date = -1 } },
        .{ .kind = .time, .value = .{ .time = 86399999999999 } },
        .{ .kind = .{ .timestamp = .civil }, .value = .{ .timestamp = -1 } },
        .{ .kind = .{ .timestamp = .utc }, .value = .{ .timestamp = 1 } },
        .{ .kind = .uuid, .value = .{ .uuid = @splat(255) } },
    }) |case| {
        const input: t.Type = .{ .structure = &.{.{ .name = "x", .type = case.kind }} };
        var template = try Prepared.init(e.allocator, "SELECT x FROM people WHERE x = $01 OR NOT x <> $1", "people", input, basis, null);
        defer template.deinit();
        try e.expectEqual(@as(usize, 1), template.parameterTypes().len);
        try e.expect(try case.kind.eql(template.parameterTypes()[0]));
        var bound = try template.bind(e.allocator, "people", input, basis, &.{case.value}, null);
        defer bound.deinit();
        const value = bound.plan.predicate.program.instructions[0].atom.compare.value;
        try e.expectEqualDeep(case.value, value);
        if (case.value == .float) try e.expectEqual(@as(u64, @bitCast(case.value.float)), @as(u64, @bitCast(value.float)));
        try e.expectEqual(.true_value, try bound.plan.predicate.program.truth(input, &.{.{ .value = .{ .atom = case.value } }}));
    }
}
test "logical parameter inference rejects gaps incompatible repeated descriptors unsupported operands and invalid sites" {
    for ([_]struct { sql: []const u8, cause: anyerror }{
        .{ .sql = "SELECT id FROM people WHERE id = $0", .cause = error.InvalidParameterIndex },
        .{ .sql = "SELECT id FROM people WHERE id = $", .cause = error.InvalidParameterIndex },
        .{ .sql = "SELECT id FROM people WHERE id = $4294967296", .cause = error.InvalidParameterIndex },
        .{ .sql = "SELECT id FROM people WHERE id = $2", .cause = error.ParameterGap },
        .{ .sql = "SELECT id FROM people WHERE id = $66", .cause = error.ParameterGap },
        .{ .sql = "SELECT id FROM people WHERE id = $1 OR name = $1", .cause = error.ParameterTypeConflict },
        .{ .sql = "SELECT id FROM people WHERE id = $1 LIMIT $1", .cause = error.ParameterTypeConflict },
        .{ .sql = "SELECT id FROM people WHERE detail = $1", .cause = error.UnsupportedComparison },
        .{ .sql = "SELECT id AS alias FROM people WHERE alias = $1", .cause = error.UnknownColumn },
        .{ .sql = "SELECT id FROM people WHERE id = -$1", .cause = error.InvalidParameterSite },
        .{ .sql = "SELECT id FROM people WHERE id = $1::int128", .cause = error.UnsupportedConstruct },
        .{ .sql = "SELECT COUNT(*) FROM people LIMIT $1", .cause = error.UnsupportedAggregateLimit },
    }) |case| try e.expectError(case.cause, Prepared.init(e.allocator, case.sql, "people", schema, basis, null));
    const decimals: t.Type = .{ .structure = &.{
        .{ .name = "a", .type = .{ .decimal = .{ .precision = 12, .scale = 2 } } },
        .{ .name = "b", .type = .{ .decimal = .{ .precision = 12, .scale = 3 } } },
    } };
    try e.expectError(error.ParameterTypeConflict, Prepared.init(e.allocator, "SELECT * FROM people WHERE a = $1 OR b = $1", "people", decimals, basis, null));
    try e.expectError(error.UnboundParameters, f.TableSelect.compile(e.allocator, text, "people", schema, basis, null));
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    var parser = try f.SqlTyped.initTemplate(arena.allocator(), text, null);
    const syntax = try f.TableSelect.syntax(&parser, schema);
    try e.expectError(error.UnboundParameters, syntax.bind(arena.allocator(), "people", schema, basis, null));
}
test "logical parameters preserve exact source binding widths limits and owned diagnostics" {
    var template = try Prepared.init(e.allocator, text, "people", schema, basis, null);
    defer template.deinit();
    var diagnostic: f.Sql.Binding = .{};
    try e.expectError(error.ParameterCountMismatch, template.bind(e.allocator, "people", schema, basis, &.{}, &diagnostic));
    try e.expectEqual(@as(usize, 3), diagnostic.expected_count.?);
    var wrong = values;
    wrong[0] = .{ .unsigned = 1 };
    try e.expectError(error.TypeMismatch, template.bind(e.allocator, "people", schema, basis, &wrong, &diagnostic));
    try e.expectEqual(@as(u32, 1), diagnostic.parameter.?);
    try e.expectEqual(std.mem.indexOf(u8, text, "$1").?, diagnostic.location.?.offset);
    var empty: std.heap.FixedBufferAllocator = .init(&.{});
    try e.expectError(error.SourceChanged, template.bind(empty.allocator(), "other", schema, basis, &values, null));
    try e.expectError(error.SourceChanged, template.bind(empty.allocator(), "people", schema, @splat(8), &values, null));
    try e.expectError(error.SourceChanged, template.bind(empty.allocator(), "people", .{ .structure = &.{.{ .name = "id", .type = .int32 }} }, basis, &values, null));
    var limit = try Prepared.init(e.allocator, "SELECT * FROM people WHERE maximum >= $1 LIMIT $1", "people", schema, basis, null);
    defer limit.deinit();
    var zero = try limit.bind(e.allocator, "people", schema, basis, &.{.{ .unsigned = 0 }}, null);
    defer zero.deinit();
    try e.expectEqual(@as(?u64, 0), zero.plan.limit);
    try e.expectError(error.Overflow, limit.bind(e.allocator, "people", schema, basis, &.{.{ .unsigned = @as(u128, std.math.maxInt(u64)) + 1 }}, null));
    var derived = try Prepared.init(e.allocator, "SELECT SUM(n) AS total FROM (SELECT value AS n FROM people WHERE id > $1 LIMIT $2) AS x", "people", schema, basis, null);
    defer derived.deinit();
    var summed = try derived.bind(e.allocator, "people", schema, basis, &.{ .{ .signed = 1 }, .{ .unsigned = 4 } }, null);
    defer summed.deinit();
    try e.expectEqual(.sum, summed.plan.aggregate);
    try e.expectEqual(@as(u8, 2), summed.plan.projection[0]);
    try e.expectEqualStrings("total", summed.plan.output_names[0].?);
}

test "logical parameter preparation rejects oversized text and bindings before allocation or conversion" {
    var empty: std.heap.FixedBufferAllocator = .init(&.{});
    const oversized: [f.Sql.max_statement_bytes + 1]u8 = @splat('a');
    try e.expectError(error.StatementTooLarge, Prepared.init(empty.allocator(), &oversized, "people", schema, basis, null));
    var template = try Prepared.init(e.allocator, "SELECT * FROM people WHERE name = $1", "people", schema, basis, null);
    defer template.deinit();
    const bytes: [t.Query.max_cell_bytes + 1]u8 = @splat(255);
    try e.expectError(error.CellTooLarge, template.bind(empty.allocator(), "people", schema, basis, &.{.{ .bytes = &bytes }}, null));
    var detail: f.Sql.Binding = .{};
    try e.expectError(error.UnsupportedComparison, Prepared.init(e.allocator, "SELECT * FROM people WHERE detail = $1 AND id = $2", "people", schema, basis, &detail));
    try e.expectEqual(@as(?u32, 1), detail.parameter);
    try e.expectEqualStrings("structure", detail.expected.?);
}
test "logical templates bound repeated parameter work by the predicate machine and preserve wide schemas" {
    var text_bytes: [4096]u8 = undefined;
    var text_writer: std.Io.Writer = .fixed(&text_bytes);
    try text_writer.writeAll("SELECT * FROM people WHERE ");
    for (0..32) |index| {
        if (index != 0) try text_writer.writeAll(" AND ");
        if (index == 0) try text_writer.writeAll("NOT ");
        try text_writer.print("id = ${d}", .{index + 1});
    }
    try text_writer.writeAll(" LIMIT $33");
    var template = try Prepared.init(e.allocator, text_writer.buffered(), "people", schema, basis, null);
    defer template.deinit();
    try e.expectEqual(@as(usize, 33), template.parameterTypes().len);
    var bindings: [33]t.Values.Atom = @splat(.{ .signed = 17 });
    bindings[32] = .{ .unsigned = 0 };
    var bound = try template.bind(e.allocator, "people", schema, basis, &bindings, null);
    defer bound.deinit();
    try e.expectEqual(@as(usize, 64), bound.plan.predicate.program.instructions.len);
    var too_many_bytes: [4096]u8 = undefined;
    const too_many = try std.fmt.bufPrint(&too_many_bytes, "{s} AND id = $34", .{text_writer.buffered()[0..std.mem.indexOf(u8, text_writer.buffered(), " LIMIT").?]});
    try e.expectError(error.PredicateTooComplex, Prepared.init(e.allocator, too_many, "people", schema, basis, null));
    var wide = try f.TableDdl.compile(e.allocator, "CREATE TABLE people(a INT, b INT, c INT, d INT, e INT, f INT, g INT, h INT, i INT, j INT, k INT, l INT, id INT128)", null, null);
    defer wide.deinit();
    var fields: [128]t.Field = undefined;
    const input = try (try wide.statement.create.bind(1)).rowType(&fields);
    var select = try Prepared.init(e.allocator, "SELECT * FROM people WHERE id = $1", "people", input, basis, null);
    defer select.deinit();
    var selected = try select.bind(e.allocator, "people", input, basis, &.{.{ .signed = std.math.maxInt(i128) }}, null);
    defer selected.deinit();
    try e.expectEqual(@as(usize, 13), selected.plan.projection.len);
    try e.expectEqual(@as(u8, 12), selected.plan.predicate.compare.column);
}
test "logical templates retain literal dollar bytes and allow parameter-free plans" {
    for ([_][]const u8{
        "SELECT * FROM people WHERE name = '$1''; -- $2' /* $3 */",
        "SELECT id FROM people WHERE id > 100",
        "SELECT COUNT(*) FROM people",
    }) |query| {
        var template = try Prepared.init(e.allocator, query, "people", schema, basis, null);
        defer template.deinit();
        try e.expectEqual(@as(usize, 0), template.parameterTypes().len);
        var bound = try template.bind(e.allocator, "people", schema, basis, &.{}, null);
        defer bound.deinit();
        var direct = try f.TableSelect.compile(e.allocator, query, "people", schema, basis, null);
        defer direct.deinit();
        try e.expectEqualSlices(u8, &try direct.plan.fingerprint(), &try bound.plan.fingerprint());
    }
}

test "logical binding distinguishes the finite plan budget from caller output buffer exhaustion" {
    var template = try Prepared.init(e.allocator, "SELECT name FROM people WHERE name = $1 OR name = $1 OR name = $1", "people", schema, basis, null);
    defer template.deinit();
    const large: [t.Query.max_cell_bytes]u8 = @splat('x');
    try e.expectError(error.PlanTooLarge, template.bind(e.allocator, "people", schema, basis, &.{.{ .bytes = &large }}, null));
    var small = try template.bind(e.allocator, "people", schema, basis, &.{.{ .bytes = "Ada" }}, null);
    defer small.deinit();
    try e.expectError(error.WriteFailed, f.LogicalPlanCodec.encode(small.plan, &.{}));
    try e.expectEqualStrings("sql.plan_too_large", (try f.SqlDiagnostic.query("SELECT name FROM people", error.PlanTooLarge, true).?.structured()).code.slice());
}

test "logical binding owns full UTF8 names at their original failing token" {
    const identifier = "東京\"" ++ @as([248]u8, @splat('x'));
    const quoted = "\"東京\"\"" ++ @as([248]u8, @splat('x')) ++ "\"";
    var statement = ("SELECT " ++ quoted ++ " FROM people").*;
    var detail: f.Sql.Binding = .{};
    try e.expectError(error.UnknownColumn, Prepared.init(e.allocator, &statement, "people", schema, basis, &detail));
    @memset(&statement, 0);
    try e.expectEqualStrings(identifier, detail.subject.?.slice());
    try e.expectEqual(@as(usize, 7), detail.location.?.offset);
    try e.expectEqualStrings("people", detail.scope[0..detail.scope_len]);
    const rendered = try f.SqlDiagnostic.bound("SELECT missing FROM people", error.UnknownColumn, true, detail).?.structured();
    try e.expectEqualStrings(identifier, rendered.facts[0].?.value.?.text.slice());
    try e.expectError(error.UnknownQualifier, Prepared.init(e.allocator, "SELECT other.id FROM people", "people", schema, basis, &detail));
    try e.expectEqualStrings("other", detail.subject.?.slice());
    try e.expectEqual(@as(usize, 7), detail.location.?.offset);
    try e.expectError(error.UnknownSource, Prepared.init(e.allocator, "SELECT id FROM other", "people", schema, basis, &detail));
    try e.expectEqualStrings("other", detail.subject.?.slice());
    try e.expectEqual(@as(usize, 15), detail.location.?.offset);
}

test "typed SELECT preserves original grammar and literal mismatch evidence" {
    const bound_schema: f.Types.Type = .{ .structure = &.{.{ .name = "value", .type = .int64 }} };
    var detail: f.Sql.Binding = .{};
    try e.expectError(error.InvalidSqlSyntax, f.LogicalPrepared.init(e.allocator, "SELECT * FROM", "items", bound_schema, @splat(1), &detail));
    try e.expectEqualStrings("an identifier", detail.location.?.expected.?);
    try e.expectError(error.UnknownQualifier, f.LogicalPrepared.init(e.allocator, "SELECT wrong.value FROM items AS i", "items", bound_schema, @splat(1), &detail));
    try e.expectEqualStrings("wrong", detail.subject.?.slice());
    try e.expectEqualStrings("i", detail.scope[0..detail.scope_len]);
    var statement_bytes = "SELECT * FROM items AS i WHERE i.value = 'wrong'".*;
    try e.expectError(error.TypeMismatch, f.LogicalPrepared.init(e.allocator, &statement_bytes, "items", bound_schema, @splat(1), &detail));
    @memset(&statement_bytes, 0);
    try e.expectEqualStrings("value", detail.subject.?.slice());
    try e.expectEqualStrings("i", detail.scope[0..detail.scope_len]);
    try e.expectEqualStrings("int64", detail.expected.?);
    try e.expectEqualStrings("utf8", detail.actual.?);
    try e.expectEqualStrings("\"wrong\"", detail.literal[0..detail.literal_len]);
    try e.expectError(error.Overflow, f.LogicalPrepared.init(e.allocator, "SELECT * FROM items WHERE value = 9223372036854775808", "items", bound_schema, @splat(1), &detail));
    try e.expectEqual(@as(usize, 34), detail.location.?.offset);
}
