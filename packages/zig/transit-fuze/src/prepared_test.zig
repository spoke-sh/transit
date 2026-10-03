const std = @import("std");
const f = @import("root.zig");
const m = f.Unified;
const t = std.testing;

fn columns(kind: m.Type) ![2]m.Column {
    return .{ .{ .name = try m.Name.init("id"), .type = .int64 }, .{ .name = try m.Name.init("value"), .type = kind } };
}
fn source(fields: []const m.Column) !m.Sql.Source {
    return .{ .name = try m.Name.init("items"), .schema = .{ .columns = fields } };
}

test "parameter syntax is opt-in, owned and rejected by ordinary lowering until bound" {
    // Ordinary Boolean SQL remains available; the template grammar has one
    // comparison site and must reject programs rather than overwrite bindings.
    try t.expectError(error.UnsupportedConstruct, f.Sql.parseTemplate("SELECT * FROM items WHERE id = $1 OR id = $2", null));
    try t.expectError(error.UnsupportedConstruct, f.Sql.parseTemplate("SELECT * FROM items WHERE NOT id = 1", null));

    var text = "SELECT value FROM items WHERE id > $1 LIMIT $2; -- $99".*;
    const parsed = try f.Sql.parseTemplate(&text, null);
    @memset(&text, 0);
    try t.expect(parsed.ast.unbound_parameters);
    try t.expectEqual(@as(u32, 1), parsed.parameters.comparison.?.index);
    try t.expectEqual(@as(u32, 2), parsed.parameters.limit.?.index);
    try t.expectEqualStrings("items", parsed.ast.source.slice());
    const fields = try columns(.int64);
    const src = try source(&fields);
    try t.expectError(error.UnboundParameters, m.Sql.compile(t.allocator, parsed.ast, src));
    var input: [8]u8 = undefined;
    var output: [8]u8 = undefined;
    try t.expectError(error.UnboundParameters, @import("SqlLowering.zig").lower(&parsed.ast, "items", &.{ "id", "value" }, &input, &output));
    const limit_only = try f.Sql.parseTemplate("SELECT * FROM items LIMIT $1", null);
    try t.expectError(error.UnboundParameters, m.Sql.compile(t.allocator, limit_only.ast, src));
    const quoted = try f.Sql.parseTemplate("SELECT value FROM items WHERE value = '$1''; -- $2' /* $3 */", null);
    try t.expect(!quoted.ast.unbound_parameters and !quoted.parameters.any());
    try t.expectEqualStrings("$1'; -- $2", quoted.ast.predicate.compare.literal.utf8.slice());
    try t.expectError(error.UnsupportedConstruct, f.Sql.parse("SELECT * FROM items LIMIT $1"));
    try t.expectError(error.UnsupportedConstruct, f.Sql.parse("SELECT * FROM items WHERE id = $1"));
    for ([_][]const u8{
        "SELECT * FROM items LIMIT $0",
        "SELECT * FROM items LIMIT $",
        "SELECT * FROM items LIMIT $4294967296",
    }) |invalid| try t.expectError(error.InvalidParameterIndex, f.Sql.parseTemplate(invalid, null));
    for ([_][]const u8{
        "SELECT $1 FROM items",
        "SELECT * FROM $1",
        "SELECT * FROM items WHERE id = -$1",
        "SELECT * FROM items WHERE id = $1::int64",
        "SELECT * FROM items WHERE id = $1 + 2",
        "SELECT * FROM items LIMIT $1; SELECT * FROM items",
    }) |invalid| {
        if (f.Sql.parseTemplate(invalid, null)) |_| return error.AcceptedInvalidTemplate else |_| {}
    }
}

test "binding preserves all scalar kinds and canonical plans without interpreting parameter bytes as SQL" {
    const values = [_]m.Scalar{
        .{ .int64 = std.math.minInt(i64) },
        .{ .uint64 = std.math.maxInt(u64) },
        .{ .float64 = -1.25e30 },
        .{ .boolean = true },
        .{ .utf8 = "it's 東京'; DROP TABLE items; -- $2" },
        .{ .binary = "\x00\xff\x01$1" },
    };
    for (values) |value| {
        const fields = try columns(std.meta.activeTag(value));
        const src = try source(&fields);
        var prepared = try f.Prepared.init(t.allocator, "SELECT value AS chosen FROM items WHERE value = $1 LIMIT $2", src);
        defer prepared.deinit();
        try t.expectEqualSlices(m.Type, &.{ std.meta.activeTag(value), .uint64 }, prepared.parameterTypes());
        var bound = try prepared.bind(t.allocator, src, &.{ value, .{ .uint64 = std.math.maxInt(u64) } });
        defer bound.deinit();
        const expected: m.Plan = .{
            .projection = &.{1},
            .predicate = .{ .compare = .{ .column = 1, .op = .eq, .value = value } },
            .limit = std.math.maxInt(u64),
            .output_names = .{ try m.Name.init("chosen"), null, null, null, null, null, null, null },
        };
        var actual_bytes: [m.Codec.max_plan_bytes]u8 = undefined;
        var expected_bytes: [m.Codec.max_plan_bytes]u8 = undefined;
        try t.expectEqualSlices(u8, try m.Codec.encode(expected, &expected_bytes), try m.Codec.encode(bound.plan, &actual_bytes));
        try t.expect(try bound.plan.matches(.{ .cells = &.{ .{ .value = .{ .int64 = 0 } }, .{ .value = value } } }));
        try t.expect(!try bound.plan.matches(.{ .cells = &.{ .{ .value = .{ .int64 = 0 } }, .null } }));
        try t.expect(!try bound.plan.matches(.{ .cells = &.{ .{ .value = .{ .int64 = 0 } }, .missing } }));
        try t.expectError(error.QueryTypeError, bound.plan.matches(.{ .cells = &.{ .{ .value = .{ .int64 = 0 } }, .{ .type_error = .unknown } } }));
        try t.expectError(error.QueryConflict, bound.plan.matches(.{ .cells = &.{ .{ .value = .{ .int64 = 0 } }, .{ .conflict = &.{} } } }));
    }
}

test "parameter ordinals are complete, context typed and reusable in compatible positions" {
    const fields = try columns(.int64);
    const src = try source(&fields);
    for ([_][]const u8{
        "SELECT * FROM items WHERE id = $2",
        "SELECT * FROM items LIMIT $4294967295",
        "SELECT * FROM items WHERE id = $1 LIMIT $3",
    }) |invalid| try t.expectError(error.ParameterGap, f.Prepared.init(t.allocator, invalid, src));
    try t.expectError(error.ParameterTypeConflict, f.Prepared.init(t.allocator, "SELECT * FROM items WHERE id = $1 LIMIT $1", src));
    try t.expectError(error.UnsupportedAggregateLimit, f.Prepared.init(t.allocator, "SELECT count(*) FROM items LIMIT $1", src));
    try t.expectError(error.UnknownColumn, f.Prepared.init(t.allocator, "SELECT value AS named FROM items WHERE named = $1", src));
    const unsigned_fields = try columns(.uint64);
    const unsigned = try source(&unsigned_fields);
    var repeated = try f.Prepared.init(t.allocator, "SELECT value FROM items WHERE value >= $01 LIMIT $1", unsigned);
    defer repeated.deinit();
    try t.expectEqualSlices(m.Type, &.{.uint64}, repeated.parameterTypes());
    var bound = try repeated.bind(t.allocator, unsigned, &.{.{ .uint64 = 7 }});
    defer bound.deinit();
    try t.expectEqual(@as(?u64, 7), bound.plan.limit);
    try t.expectEqual(@as(u64, 7), bound.plan.predicate.compare.value.uint64);
}

test "prepared derived input preserves aliases, input limits and empty result semantics" {
    const fields = try columns(.int64);
    const src = try source(&fields);
    var prepared = try f.Prepared.init(t.allocator, "SELECT count(chosen.renamed) AS present FROM (SELECT row.value AS renamed FROM items AS row WHERE row.id > $2 LIMIT $1) AS chosen", src);
    defer prepared.deinit();
    try t.expectEqualSlices(m.Type, &.{ .uint64, .int64 }, prepared.parameterTypes());
    var empty = try prepared.bind(t.allocator, src, &.{ .{ .uint64 = 0 }, .{ .int64 = -3 } });
    defer empty.deinit();
    try t.expectEqual(m.Plan.Aggregate.count_values, empty.plan.aggregate);
    try t.expectEqualSlices(u8, &.{1}, empty.plan.projection);
    try t.expectEqual(@as(?u64, 0), empty.plan.limit);
    try t.expectEqualStrings("present", empty.plan.output_names[0].?.slice());
    var more = try prepared.bind(t.allocator, src, &.{ .{ .uint64 = 5 }, .{ .int64 = 10 } });
    defer more.deinit();
    try t.expectEqual(@as(?u64, 0), empty.plan.limit);
    try t.expectEqual(@as(?u64, 5), more.plan.limit);
    try t.expectEqual(@as(i64, -3), empty.plan.predicate.compare.value.int64);
    try t.expectEqual(@as(i64, 10), more.plan.predicate.compare.value.int64);
}

test "binding rejects changed names and schema and preserves exact scalar bounds" {
    var fields = try columns(.utf8);
    const src = try source(&fields);
    var prepared = try f.Prepared.init(t.allocator, "SELECT value FROM items WHERE value = $1", src);
    defer prepared.deinit();
    try t.expectError(error.ParameterCountMismatch, prepared.bind(t.allocator, src, &.{}));
    try t.expectError(error.ParameterCountMismatch, prepared.bind(t.allocator, src, &.{ .{ .utf8 = "a" }, .{ .utf8 = "b" } }));
    try t.expectError(error.TypeMismatch, prepared.bind(t.allocator, src, &.{.{ .binary = "a" }}));
    try t.expectError(error.InvalidUtf8, prepared.bind(t.allocator, src, &.{.{ .utf8 = "\xff" }}));
    const over: [m.max_cell_bytes + 1]u8 = @splat('a');
    try t.expectError(error.CellTooLarge, prepared.bind(t.allocator, src, &.{.{ .utf8 = &over }}));
    var maximum = try prepared.bind(t.allocator, src, &.{.{ .utf8 = over[0..m.max_cell_bytes] }});
    defer maximum.deinit();
    try t.expectEqual(m.max_cell_bytes, maximum.plan.predicate.compare.value.utf8.len);
    var other = src;
    other.name = try m.Name.init("replacement");
    try t.expectError(error.SourceChanged, prepared.bind(t.allocator, other, &.{.{ .utf8 = "a" }}));
    fields[1].type = .binary;
    try t.expectError(error.SourceChanged, prepared.bind(t.allocator, src, &.{.{ .binary = "a" }}));
    fields[1].type = .utf8;
    fields[1].name = try m.Name.init("renamed");
    try t.expectError(error.SourceChanged, prepared.bind(t.allocator, src, &.{.{ .utf8 = "a" }}));
    other = src;
    other.schema.version = 2;
    try t.expectError(error.UnsupportedSchema, prepared.bind(t.allocator, other, &.{.{ .utf8 = "a" }}));
    const float_fields = try columns(.float64);
    const floats = try source(&float_fields);
    var floating = try f.Prepared.init(t.allocator, "SELECT value FROM items WHERE value = $1", floats);
    defer floating.deinit();
    try t.expectError(error.NonFiniteValue, floating.bind(t.allocator, floats, &.{.{ .float64 = std.math.nan(f64) }}));
}

fn ownedBindings(allocator: std.mem.Allocator) !void {
    const fields = try columns(.utf8);
    const src = try source(&fields);
    var prepared = try f.Prepared.init(allocator, "SELECT value AS selected FROM items WHERE value = $1 LIMIT $2", src);
    var alive = true;
    defer if (alive) prepared.deinit();
    var bytes = "a'; -- $3".*;
    var bound = try prepared.bind(allocator, src, &.{ .{ .utf8 = &bytes }, .{ .uint64 = 2 } });
    defer bound.deinit();
    @memset(&bytes, 0);
    prepared.deinit();
    alive = false;
    try t.expectEqualStrings("a'; -- $3", bound.plan.predicate.compare.value.utf8);
    try t.expectEqualSlices(u8, &.{1}, bound.plan.projection);
    try t.expectEqualStrings("selected", bound.plan.output_names[0].?.slice());
    try bound.plan.validate(src.schema);
}
test "prepared and bound storage have independent ownership under every allocation failure" {
    try ownedBindings(t.allocator);
    try t.checkAllAllocationFailures(t.allocator, ownedBindings, .{});
}

test "constant templates preserve literals after releasing the template" {
    const fields = try columns(.utf8);
    const src = try source(&fields);
    var bound = blk: {
        var prepared = try f.Prepared.init(t.allocator, "SELECT value FROM items WHERE value = 'owned $1'", src);
        defer prepared.deinit();
        try t.expectEqual(@as(usize, 0), prepared.parameterTypes().len);
        var result = try prepared.bind(t.allocator, src, &.{});
        errdefer result.deinit();
        try t.expect(result.plan.predicate.compare.value.utf8.ptr != prepared.prototype.predicate.compare.value.utf8.ptr);
        break :blk result;
    };
    defer bound.deinit();
    try t.expectEqualStrings("owned $1", bound.plan.predicate.compare.value.utf8);
    try bound.plan.validate(src.schema);
}

test "parameter diagnostics retain actual use sites types counts and schema evidence" {
    var fields = try columns(.int64);
    const src = try source(&fields);
    const conflicting = "SELECT value FROM items WHERE id = $1\nLIMIT $1";
    var detail: f.Sql.Binding = .{};
    try t.expectError(error.ParameterTypeConflict, f.Prepared.initDiagnostic(t.allocator, conflicting, src, &detail));
    try t.expectEqual(@as(?u32, 1), detail.parameter);
    try t.expectEqualStrings("int64", detail.expected.?);
    try t.expectEqualStrings("uint64", detail.actual.?);
    try t.expectEqual(std.mem.indexOf(u8, conflicting, "$1"), detail.parameter_sites[0]);
    try t.expectEqual(std.mem.lastIndexOf(u8, conflicting, "$1"), detail.parameter_sites[1]);
    try t.expectEqual(detail.parameter_sites[1].?, detail.location.?.offset);
    const diagnostic = f.SqlDiagnostic.bound(conflicting, error.ParameterTypeConflict, true, detail).?;
    try t.expectEqual(@as(usize, 2), diagnostic.line);
    try t.expect(std.mem.indexOf(u8, diagnostic.detail[0..diagnostic.detail_len], "Use at line 2, byte column 7") != null);

    try t.expectError(error.ParameterGap, f.Prepared.initDiagnostic(t.allocator, "SELECT * FROM items LIMIT $2", src, &detail));
    try t.expectEqual(@as(?u32, 1), detail.missing_parameter);
    try t.expectEqual(@as(?u32, 2), detail.parameter);
    try t.expectError(error.InvalidParameterIndex, f.Prepared.initDiagnostic(t.allocator, "SELECT *\nFROM items LIMIT $0", src, &detail));
    try t.expectEqual(@as(usize, 26), detail.location.?.offset);

    const sql = "SELECT value FROM items WHERE id = $1 LIMIT $2";
    var prepared = try f.Prepared.initDiagnostic(t.allocator, sql, src, &detail);
    defer prepared.deinit();
    try t.expectError(error.ParameterCountMismatch, prepared.bindDiagnostic(t.allocator, src, &.{}, &detail));
    try t.expectEqual(@as(?usize, 2), detail.expected_count);
    try t.expectEqual(@as(?usize, 0), detail.actual_count);
    try t.expectEqual(null, detail.parameter);
    try t.expectError(error.TypeMismatch, prepared.bindDiagnostic(t.allocator, src, &.{ .{ .int64 = 3 }, .{ .utf8 = "\x1b[31m\n$1'" } }, &detail));
    try t.expectEqual(@as(?u32, 2), detail.parameter);
    try t.expectEqualStrings("uint64", detail.expected.?);
    try t.expectEqualStrings("utf8", detail.actual.?);
    try t.expect(std.mem.indexOf(u8, detail.literal[0..detail.literal_len], "\\x1b") != null);
    try t.expectEqual(std.mem.indexOf(u8, sql, "$2"), detail.parameter_sites[0]);
    try t.expectEqual(null, detail.parameter_sites[1]);

    fields[1].type = .utf8;
    try t.expectError(error.SourceChanged, prepared.bindDiagnostic(t.allocator, src, &.{ .{ .int64 = 3 }, .{ .uint64 = 1 } }, &detail));
    try t.expectEqual(prepared.schema_fingerprint, detail.expected_schema.?);
    try t.expectEqual(try src.schema.fingerprint(), detail.actual_schema.?);
    try t.expectEqual(null, detail.parameter);
}
