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
test "relational qualified wildcard selects one source in schema order" {
    var cols = columns;
    for (&cols) |*column| column.nullable = false;
    var inputs = sources;
    for (&inputs) |*input| input.schema.columns = &cols;
    for ([_][]const u8{ "r", "l" }, 0..) |qualifier, index| {
        const source_index = 1 - index;
        const text = try std.fmt.allocPrint(t.allocator, "SELECT {s}.* FROM lefts l LEFT JOIN rights r ON r.key = l.key ORDER BY l.key", .{qualifier});
        defer t.allocator.free(text);
        var syntax = try sql.parse(t.allocator, text, null);
        defer syntax.deinit();
        const plan = try syntax.bind(&inputs, .interactive, budgets, null);
        try t.expectEqual(columns.len, plan.outputs.len);
        var fields: [2]@import("Types.zig").Field = undefined;
        _ = try plan.outputSchema(&fields);
        for (fields) |field| try t.expectEqual(source_index == 1, field.nullable);
        for (plan.outputs, columns) |output, column| {
            try t.expectEqualStrings(column.name, output.name);
            try t.expect(output.expression.eql(.{ .column = .{ .source = @intCast(source_index), .id = column.id } }));
        }
        const explicit_text = try std.fmt.allocPrint(t.allocator, "SELECT {s}.key, {s}.value FROM lefts l LEFT JOIN rights r ON r.key = l.key ORDER BY l.key", .{ qualifier, qualifier });
        defer t.allocator.free(explicit_text);
        var explicit = try sql.parse(t.allocator, explicit_text, null);
        defer explicit.deinit();
        try t.expectEqualSlices(u8, &try plan.fingerprint(), &try (try explicit.bind(&inputs, .interactive, budgets, null)).fingerprint());
    }
    var single = try sql.parse(t.allocator, "SELECT l.* FROM lefts l ORDER BY key", null);
    defer single.deinit();
    const plan = try single.bind(sources[0..1], .interactive, budgets, null);
    try t.expectEqualStrings("key", plan.outputs[0].name);
    for ([_][]const u8{
        "SELECT missing.* FROM lefts l JOIN rights r ON l.key = r.key",
        "SELECT lefts.* FROM lefts l JOIN rights r ON l.key = r.key",
    }) |text| {
        var syntax = try sql.parse(t.allocator, text, null);
        defer syntax.deinit();
        var location: @import("Sql.zig").Location = .{};
        try t.expectError(error.UnknownRelationalSource, syntax.bind(&sources, .interactive, budgets, &location));
        try t.expectEqual(@as(usize, 7), location.offset);
    }
}

test "relational joined star expands both schemas with qualified output names" {
    const cols = [_]schema.Column{ .{ .id = 5, .name = "id", .type = .int64 }, .{ .id = 9, .name = "value", .type = .int64 } };
    var inputs = sources;
    for (&inputs, [_][]const u8{ "people", "items" }) |*input, alias| {
        input.alias = alias;
        input.schema.columns = &cols;
        input.schema.next_column = 10;
    }
    var people_columns = cols;
    people_columns[0].type = .int32;
    people_columns[1].name = "name";
    people_columns[1].type = .utf8;
    inputs[0].schema.columns = &people_columns;
    var item_columns = cols;
    item_columns[0].nullable = false;
    inputs[1].schema.columns = &item_columns;
    inputs[1].schema.primary_key = &.{5};
    for ([_][]const u8{
        "SELECT * FROM people INNER JOIN items ON items.id = people.id;",
        "SELECT * FROM people JOIN items ON items.id = people.id;",
    }) |text| {
        try t.expect(try sql.required(text));
        var syntax = try sql.parse(t.allocator, text, null);
        defer syntax.deinit();
        const plan = try syntax.bind(&inputs, .interactive, budgets, null);
        var fields: [4]@import("Types.zig").Field = undefined;
        _ = try plan.outputSchema(&fields);
        try t.expectEqual(@import("Types.zig").Type.int32, fields[0].type);
        try t.expectEqual(@import("Types.zig").Type.int64, fields[2].type);
        const names = [_][]const u8{ "people.id", "people.name", "items.id", "items.value" };
        try t.expectEqual(names.len, plan.outputs.len);
        for (plan.outputs, names, 0..) |output, name, i| {
            try t.expectEqualStrings(name, output.name);
            try t.expect(output.expression.eql(.{ .column = .{ .source = @intCast(i / 2), .id = cols[i % 2].id } }));
        }
        // Wildcard lowering has exactly the existing explicit-plan semantics.
        var explicit = try sql.parse(t.allocator, "SELECT people.id AS \"people.id\", people.name AS \"people.name\", items.id AS \"items.id\", items.value AS \"items.value\" FROM people JOIN items ON people.id = items.id", null);
        defer explicit.deinit();
        try t.expectEqualSlices(u8, &try plan.fingerprint(), &try (try explicit.bind(&inputs, .interactive, budgets, null)).fingerprint());
    }
}

fn joinedStar(allocator: std.mem.Allocator) !void {
    var cols = columns;
    for (&cols) |*column| column.nullable = false;
    var inputs = sources;
    for (&inputs) |*input| input.schema.columns = &cols;
    var syntax = try sql.parse(allocator, "SELECT * FROM lefts l LEFT OUTER JOIN rights r ON r.key = l.key WHERE l.value > $1 ORDER BY r.value DESC LIMIT $2", null);
    defer syntax.deinit();
    // Bound names belong to the supplied output arena, including prepared binds.
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    var parameters: sql.Parameters = .{};
    const plan = try syntax.bindParameters(arena.allocator(), &inputs, .interactive, budgets, null, &parameters, &.{ .{ .signed = 0 }, .{ .unsigned = 2 } });
    var fields: [4]@import("Types.zig").Field = undefined;
    _ = try plan.outputSchema(&fields);
    for (fields, [_][]const u8{ "l.key", "l.value", "r.key", "r.value" }, 0..) |field, name, i| {
        try t.expectEqualStrings(name, field.name);
        try t.expectEqual(i >= 2, field.nullable);
        try t.expectEqual(@import("Types.zig").Type.int64, field.type);
    }
    try t.expectEqual(@as(?u64, 2), plan.limit);
    try t.expect(plan.order_by[0].expression.eql(.{ .column = .{ .source = 1, .id = 2 } }));
    var bytes: [@import("RelationalCodec.zig").max_bytes]u8 = undefined;
    var decoded = try @import("RelationalCodec.zig").decode(allocator, try @import("RelationalCodec.zig").encode(plan, &bytes));
    defer decoded.deinit();
    try t.expectEqualSlices(u8, &try plan.fingerprint(), &try decoded.plan.fingerprint());
}

test "relational joined star preserves left nullability parameters and allocation cleanup" {
    try joinedStar(t.allocator);
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), joinedStar, .{});
}

test "relational star preserves single source names and ambiguous reference errors" {
    var single = try sql.parse(t.allocator, "SELECT * FROM lefts l ORDER BY key", null);
    defer single.deinit();
    const plan = try single.bind(sources[0..1], .interactive, budgets, null);
    try t.expectEqualStrings("key", plan.outputs[0].name);
    try t.expectEqualStrings("value", plan.outputs[1].name);
    var ambiguous = try sql.parse(t.allocator, "SELECT * FROM lefts l JOIN rights r ON l.key = r.key ORDER BY key", null);
    defer ambiguous.deinit();
    try t.expectError(error.AmbiguousRelationalColumn, ambiguous.bind(&sources, .interactive, budgets, null));
}

test "relational joined star retains projection and generated name bounds" {
    var cols: [65]schema.Column = undefined;
    var names: [65][8]u8 = undefined;
    for (&cols, &names, 0..) |*column, *name, i| column.* = .{
        .id = i + 1,
        .name = try std.fmt.bufPrint(name, "c{d}", .{i}),
        .type = .int64,
    };
    var inputs = sources;
    for (&inputs) |*input| {
        input.schema.columns = cols[0..64];
        input.schema.next_column = 66;
    }
    var syntax = try sql.parse(t.allocator, "SELECT * FROM lefts l JOIN rights r ON l.c0 = r.c0", null);
    defer syntax.deinit();
    const plan = try syntax.bind(&inputs, .interactive, budgets, null);
    try t.expectEqual(r.max_outputs, plan.outputs.len);
    inputs[1].schema.columns = &cols;
    try t.expectError(error.InvalidRelationalOutputs, syntax.bind(&inputs, .interactive, budgets, null));

    var selected = try sql.parse(t.allocator, "SELECT r.* FROM lefts l JOIN rights r ON l.c0 = r.c0", null);
    defer selected.deinit();
    try t.expectEqual(@as(usize, 65), (try selected.bind(&inputs, .interactive, budgets, null)).outputs.len);

    const long_name: [254]u8 = @splat('x');
    cols[0].name = &long_name;
    for (&inputs) |*input| input.schema.columns = cols[0..1];
    var oversized = try sql.parse(t.allocator, "SELECT * FROM lefts l JOIN rights r ON l.\"" ++ long_name ++ "\" = r.\"" ++ long_name ++ "\"", null);
    defer oversized.deinit();
    try t.expectError(error.InvalidRelationalName, oversized.bind(&inputs, .interactive, budgets, null));
}

test "relational joined star preserves quoted aliases and rejects dotted label collisions" {
    var inputs = sources;
    inputs[0].alias = "P";
    inputs[1].alias = "I";
    var syntax = try sql.parse(t.allocator, "SELECT * FROM lefts AS \"P\" JOIN rights AS \"I\" ON \"P\".key = \"I\".key", null);
    defer syntax.deinit();
    const plan = try syntax.bind(&inputs, .interactive, budgets, null);
    try t.expectEqualStrings("P.key", plan.outputs[0].name);
    try t.expectEqualStrings("I.key", plan.outputs[2].name);

    var left_cols = columns;
    left_cols[0].name = "b.key";
    inputs[0].alias = "a";
    inputs[0].schema.columns = &left_cols;
    inputs[1].alias = "a.b";
    var collision = try sql.parse(t.allocator, "SELECT * FROM lefts a JOIN rights \"a.b\" ON a.\"b.key\" = \"a.b\".key", null);
    defer collision.deinit();
    try t.expectError(error.DuplicateRelationalOutput, collision.bind(&inputs, .interactive, budgets, null));
}

test "relational aggregate names remain identifiers outside function calls" {
    var input = sources[0];
    input.alias = "items";
    for ([_][]const u8{
        "SELECT value, COUNT(*) AS count FROM items GROUP BY value ORDER BY count ASC;",
        "SELECT value, COUNT /* call */ (*) AS CoUnT FROM items GROUP BY value ORDER BY COUNT ASC;",
        "SELECT value, COUNT(*) AS \"count\" FROM items GROUP BY value ORDER BY \"count\" ASC;",
    }) |text| {
        try t.expect(try sql.required(text));
        var syntax = try sql.parse(t.allocator, text, null);
        defer syntax.deinit();
        const plan = try syntax.bind(&.{input}, .interactive, budgets, null);
        try t.expectEqualStrings("count", plan.outputs[1].name);
        try t.expect(plan.outputs[1].expression.eql(.count_all));
        try t.expect(plan.order_by[0].expression.eql(.count_all));
        try t.expectEqual(r.Direction.asc, plan.order_by[0].direction);
    }
    var syntax = try sql.parse(t.allocator, "SELECT value, SUM(key) AS sum, COUNT(key) AS count FROM items GROUP BY value HAVING count > 1 AND sum IS NOT NULL ORDER BY sum DESC, count ASC", null);
    defer syntax.deinit();
    const plan = try syntax.bind(&.{input}, .interactive, budgets, null);
    try t.expect(plan.having.instructions[0].compare.expression.eql(.{ .count = .{ .source = 0, .id = 1 } }));
    try t.expect(plan.order_by[0].expression.eql(.{ .sum = .{ .source = 0, .id = 1 } }));
    try t.expect(plan.order_by[1].expression.eql(.{ .count = .{ .source = 0, .id = 1 } }));
}

test "MySQL relational dialect preserves the same bound plan with backtick identifiers" {
    const quoted = "SELECT `l`.`key`, COUNT(*) AS `rows`, COUNT(`r`.`value`) AS `values`, SUM(`r`.`value`) AS `total` FROM `lefts` `l` LEFT JOIN `rights` `r` ON `r`.`key` = `l`.`key` GROUP BY `l`.`key`";
    try t.expect(try sql.requiredDialect(quoted, .mysql));
    var mysql = try sql.parseDialect(t.allocator, quoted, null, .mysql);
    defer mysql.deinit();
    var original = try sql.parse(t.allocator, statement, null);
    defer original.deinit();
    try t.expectEqualSlices(u8, &try (try original.bind(&sources, .captured, budgets, null)).fingerprint(), &try (try mysql.bind(&sources, .captured, budgets, null)).fingerprint());
    var parameterized = try sql.parseDialect(t.allocator, "SELECT COUNT(*) FROM `lefts` l WHERE `key` = ?", null, .mysql);
    defer parameterized.deinit();
    try t.expectError(error.ParameterCountMismatch, parameterized.bind(sources[0..1], .interactive, budgets, null));
}

test "relational parameters preserve typed templates through grouping ordering and null binding" {
    const types = @import("Types.zig");
    var syntax = try sql.parse(t.allocator, "SELECT l.key, SUM(l.value) AS total FROM lefts l WHERE l.value > $1 GROUP BY l.key HAVING total > $1 ORDER BY total DESC LIMIT $2", null);
    defer syntax.deinit();
    var parameters: sql.Parameters = .{};
    const prototype = try syntax.bindParameters(syntax.arena.allocator(), sources[0..1], .interactive, budgets, null, &parameters, null);
    try t.expectEqual(@as(usize, 2), parameters.slice().len);
    try t.expectEqual(types.Type.int64, parameters.slice()[0]);
    try t.expectEqual(types.Type.uint64, parameters.slice()[1]);
    const original = try prototype.fingerprint();
    for ([_]?types.Values.Atom{ .{ .signed = 3 }, null, .{ .signed = -5 } }) |value| {
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        var inferred: sql.Parameters = .{};
        const bound = try syntax.bindParameters(arena.allocator(), sources[0..1], .interactive, budgets, null, &inferred, &.{ value, .{ .unsigned = 7 } });
        try t.expectEqual(@as(?u64, 7), bound.limit);
        try t.expectEqual(value == null, bound.filter.instructions[0].compare.value == null);
        try t.expectEqual(value == null, bound.having.instructions[0].compare.value == null);
        try t.expectEqualSlices(u8, &original, &try prototype.fingerprint());
        var bytes: [@import("RelationalCodec.zig").max_bytes]u8 = undefined;
        var decoded = try @import("RelationalCodec.zig").decode(t.allocator, try @import("RelationalCodec.zig").encode(bound, &bytes));
        defer decoded.deinit();
        try t.expectEqualSlices(u8, &try bound.fingerprint(), &try decoded.plan.fingerprint());
    }
    var gap = try sql.parse(t.allocator, "SELECT l.key FROM lefts l WHERE l.key > $2 ORDER BY l.key", null);
    defer gap.deinit();
    var inferred: sql.Parameters = .{};
    try t.expectError(error.ParameterGap, gap.bindParameters(gap.arena.allocator(), sources[0..1], .interactive, budgets, null, &inferred, null));
    var conflict = try sql.parse(t.allocator, "SELECT l.key FROM lefts l WHERE l.key > $1 ORDER BY l.key LIMIT $1", null);
    defer conflict.deinit();
    inferred = .{};
    try t.expectError(error.ParameterTypeConflict, conflict.bindParameters(conflict.arena.allocator(), sources[0..1], .interactive, budgets, null, &inferred, null));
}
test "relational routing distinguishes clause words from existing names" {
    for ([_][]const u8{
        "SELECT count, sum FROM items",
        "SELECT value AS count, key AS sum FROM items",
        "SELECT join, group FROM items",
        "SELECT value FROM join",
        "SELECT value FROM group",
        "SELECT join.value FROM items AS join",
        "SELECT group.value FROM items AS group",
        "SELECT value FROM items WHERE join = 1 AND group = 2",
        "SELECT value FROM \"group\" AS \"join\" WHERE value = 1",
        "SELECT COUNT(*) FROM (SELECT * FROM items LIMIT 2) AS join",
    }) |text| try t.expect(!try sql.required(text));
    for ([_][]const u8{
        "SELECT l.value FROM \"left\" l JOIN \"right\" r ON l.key=r.key",
        "SELECT l.value FROM items AS \"left\" LEFT JOIN others r ON l.key=r.key",
        "SELECT key, COUNT(*) FROM group GROUP BY key",
        "SELECT key FROM items WHERE group = 1 GROUP BY key",
        "SELECT key FROM items ORDER BY key",
        "SELECT COUNT(*) FROM items HAVING COUNT(*) > 1",
        "SELECT COUNT(*), SUM(value) FROM items",
    }) |text| try t.expect(try sql.required(text));
}

test "relational HAVING binds a hidden scalar aggregate before inferring its operand" {
    const decimal: @import("Types.zig").Type = .{ .decimal = .{ .precision = 8, .scale = 2 } };
    const cols = [_]schema.Column{
        .{ .id = 1, .name = "key", .type = .int64 },
        .{ .id = 2, .name = "value", .type = decimal },
    };
    var source = sources[0];
    source.schema.columns = &cols;
    var syntax = try sql.parse(t.allocator, "SELECT l.key FROM lefts l GROUP BY l.key HAVING SUM(DECIMAL_ADD(l.value,l.value,8,2,REJECT)) > $1 ORDER BY l.key", null);
    defer syntax.deinit();
    var parameters: sql.Parameters = .{};
    const plan = try syntax.bindParameters(syntax.arena.allocator(), &.{source}, .interactive, budgets, null, &parameters, null);
    try t.expect(try decimal.eql(parameters.slice()[0]));
    try t.expect(plan.having.instructions[0].compare.expression.sum.source == r.computed_source);
    try plan.validate();
}
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
        "SELECT l.key FROM lefts l RIGHT JOIN rights r ON l.key = r.key",
        "SELECT l.key FROM lefts l JOIN rights r ON l.key > r.key",
        "SELECT l.key FROM lefts l JOIN rights r ON l.key = r.key JOIN more m ON l.key = m.key",
        "SELECT l.key FROM lefts l ORDER BY l.key NULLS",
        "SELECT l.key FROM lefts l GROUP BY l.key HAVING",
    }) |text| {
        if (sql.parse(t.allocator, text, null)) |value| {
            var owned = value;
            owned.deinit();
            return error.UnexpectedSqlAcceptance;
        } else |_| {}
    }
}
test "relational SQL binds HAVING, ORDER BY and LIMIT with output alias resolution" {
    var syntax = try sql.parse(
        t.allocator,
        "SELECT l.key AS k, COUNT(*) AS n, SUM(l.value) AS total FROM lefts l GROUP BY l.key HAVING n > 1 AND total IS NOT NULL ORDER BY total DESC NULLS FIRST, k ASC NULLS LAST LIMIT 5",
        null,
    );
    defer syntax.deinit();
    const plan = try syntax.bind(sources[0..1], .interactive, budgets, null);
    try t.expectEqual(@as(usize, 4), plan.having.instructions.len);
    try t.expectEqual(@as(usize, 2), plan.order_by.len);
    try t.expect(plan.order_by[0].expression.eql(.{ .sum = .{ .source = 0, .id = 2 } }));
    try t.expectEqual(r.Direction.desc, plan.order_by[0].direction);
    try t.expectEqual(r.NullOrder.first, plan.order_by[0].nulls);
    try t.expect(plan.order_by[1].expression.eql(.{ .column = .{ .source = 0, .id = 1 } }));
    try t.expectEqual(r.Direction.asc, plan.order_by[1].direction);
    try t.expectEqual(r.NullOrder.last, plan.order_by[1].nulls);
    try t.expectEqual(@as(?u64, 5), plan.limit);
}

test "relational editor expectations and source discovery share the executable parser" {
    const Parser = @import("SqlTyped.zig");
    const Case = struct { text: []const u8, word: ?[]const u8 = null, name: ?Parser.NameRole = null, qualifier: ?[]const u8 = null, sum_only: bool = false };
    for ([_]Case{
        .{ .text = "SELECT ", .word = "COUNT", .name = .column },
        .{ .text = "SELECT SUM(", .name = .column, .sum_only = true },
        .{ .text = "SELECT l.", .name = .column, .qualifier = "l" },
        .{ .text = "SELECT l.key FROM lefts l LEFT ", .word = "JOIN" },
        .{ .text = "SELECT l.key FROM lefts l JOIN ", .name = .source },
        .{ .text = "SELECT l.key FROM lefts l JOIN rights r ON r.", .name = .column, .qualifier = "r" },
        .{ .text = "SELECT l.key FROM lefts l GROUP ", .word = "BY" },
        .{ .text = "SELECT l.key FROM lefts l GROUP BY ", .name = .column },
    }) |case| {
        var editor: Parser.Editor = .{};
        if (sql.parseWithContext(t.allocator, case.text, null, .{ .editor = &editor })) |value| {
            var owned = value;
            owned.deinit();
        } else |err| if (err == error.OutOfMemory) return err;
        try t.expectEqual(case.name, editor.name_role);
        try t.expectEqual(case.sum_only, editor.sum_only);
        if (case.qualifier) |expected| try t.expectEqualStrings(expected, editor.qualifier.?.slice());
        if (case.word) |word| {
            var found_word = false;
            for (editor.words) |slot| if (slot) |value| {
                if (std.mem.eql(u8, value, word)) found_word = true;
            };
            try t.expect(found_word);
        }
    }
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    var found: [2]sql.Target = undefined;
    try t.expectEqual(2, try sql.discoverTargets(arena.allocator(), "SELECT l. FROM lefts l LEFT JOIN rights r ON l.key=r.key", &found));
    try t.expectEqualStrings("lefts", found[0].name);
    try t.expectEqualStrings("l", found[0].alias);
    try t.expectEqualStrings("rights", found[1].name);
    try t.expectEqualStrings("r", found[1].alias);
    try t.expectError(error.InvalidSqlSyntax, sql.discoverTargets(arena.allocator(), "SELECT 'FROM private'", &found));
}
test "relational clauses are not mistaken for an implicit source alias" {
    var joined = try sql.parse(t.allocator, "SELECT lefts.key, rights.value FROM lefts LEFT JOIN rights ON lefts.key=rights.key", null);
    defer joined.deinit();
    try t.expectEqualStrings("lefts", joined.targets[0].alias);
    try t.expectEqualStrings("rights", joined.targets[1].alias);
    try t.expectEqual(.left, joined.join.?.kind);
    var grouped = try sql.parse(t.allocator, "SELECT key, COUNT(*) AS n FROM lefts GROUP BY key", null);
    defer grouped.deinit();
    try t.expectEqualStrings("lefts", grouped.targets[0].alias);
    try t.expectEqual(1, grouped.groups.len);
}
