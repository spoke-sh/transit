const std = @import("std");
const t = std.testing;
const f = @import("root.zig");
const m = f.model;
const mutation = f.TableMutation;
fn target(kind: m.Type) !mutation.Target {
    return .{ .name = try m.Name.init("items"), .schema = .{ .names = .{ try m.Name.init("id"), try m.Name.init("value") }, .value_type = kind } };
}

test "mutation SQL preserves literal types, column order, full-width keys and null" {
    const cases = .{
        .{ m.Type.int64, "-9223372036854775808", m.Cell{ .int64 = std.math.minInt(i64) } },
        .{ m.Type.boolean, "TRUE", m.Cell{ .boolean = true } },
        .{ m.Type.utf8, "'it''s 東京'", m.Cell{ .utf8 = try m.Bytes.init("it's 東京") } },
        .{ m.Type.binary, "'\\x00ff'::bytea", m.Cell{ .binary = try m.Bytes.init(&.{ 0, 255 }) } },
    };
    inline for (cases) |case| {
        const source = try target(case[0]);
        const result = try mutation.compile("/* input */ INSERT INTO items (value,id) VALUES (" ++ case[1] ++ ",9223372036854775807), (NULL,-9223372036854775808); -- end", source);
        const rows = result.operation.insert;
        try t.expectEqual(std.math.maxInt(i64), rows[0].?.key);
        try t.expect(std.meta.eql(case[2], rows[0].?.value));
        try t.expectEqual(std.math.minInt(i64), rows[1].?.key);
        try t.expect(rows[1].?.value == .null and rows[2] == null);
        const updated = try mutation.compile("UPDATE items SET items.value = " ++ case[1] ++ " WHERE items.id = -1", source);
        try t.expectEqual(@as(i64, -1), updated.operation.update.key);
        try t.expect(std.meta.eql(case[2], updated.operation.update.value));
        try t.expectEqual(@as(i64, 7), (try mutation.compile("DELETE FROM items WHERE id = +7", source)).operation.delete);
    }
    const full = try mutation.compile("INSERT INTO items (id,value) VALUES (1,NULL),(2,3),(3,4)", try target(.int64));
    try t.expectEqual(@as(i64, 3), full.operation.insert[2].?.key);
    const quoted: mutation.Target = .{ .name = try m.Name.init("Items"), .schema = (try target(.int64)).schema };
    _ = try mutation.compile("DELETE FROM \"Items\" WHERE id=1", quoted);
    try t.expectError(error.UnknownSource, mutation.compile("DELETE FROM Items WHERE id=1", quoted));
}

test "mutation compiler rejects broader SQL without changing SELECT acceptance" {
    const source = try target(.int64);
    const cases = .{
        .{ "INSERT INTO other (id,value) VALUES(1,2)", error.UnknownSource },
        .{ "INSERT INTO items (id,id) VALUES(1,2)", error.DuplicateColumn },
        .{ "INSERT INTO items (id,unknown) VALUES(1,2)", error.UnknownColumn },
        .{ "INSERT INTO items (id,value) VALUES(NULL,2)", error.NullPrimaryKey },
        .{ "INSERT INTO items (id,value) VALUES(TRUE,2)", error.TypeMismatch },
        .{ "INSERT INTO items (id,value) VALUES(1,TRUE)", error.TypeMismatch },
        .{ "INSERT INTO items (id,value) VALUES(1,2),(1,3)", error.DuplicateMutationKey },
        .{ "INSERT INTO items (id,value) VALUES(1,1),(2,2),(3,3),(4,4)", error.MutationBatchTooLarge },
        .{ "UPDATE items SET id=2 WHERE id=1", error.ImmutablePrimaryKey },
        .{ "UPDATE items SET value=2 WHERE value=1", error.UnsupportedMutationPredicate },
        .{ "UPDATE items SET other.value=2 WHERE id=1", error.UnknownQualifier },
        .{ "DELETE FROM items WHERE id=NULL", error.NullPrimaryKey },
        .{ "DELETE FROM items WHERE other.id=1", error.UnknownQualifier },
        .{ "DELETE FROM items WHERE id=1 OR id=2", error.UnsupportedConstruct },
        .{ "DELETE FROM items WHERE id=1 RETURNING *", error.UnsupportedConstruct },
        .{ "DELETE FROM items WHERE id=1; SELECT * FROM items", error.UnsupportedConstruct },
        .{ "DELETE FROM items WHERE id=9223372036854775808", error.LiteralOutOfRange },
        .{ "UPDATE items SET value='1'::uint64 WHERE id=1", error.UnsupportedLiteral },
        .{ "UPDATE items SET value=1+1 WHERE id=1", error.UnsupportedConstruct },
    };
    inline for (cases) |case| try t.expectError(case[1], mutation.compile(case[0], source));
    for ([_][]const u8{
        "INSERT INTO items VALUES(1,2)",          "INSERT INTO items (id,value) SELECT * FROM items",
        "INSERT INTO items (id,value) VALUES(1)", "INSERT INTO items (id,value) VALUES()",
        "UPDATE items SET value=1",               "DELETE FROM items",
        "DELETE FROM items WHERE id>0",
    }) |text| {
        if (mutation.compile(text, source)) |_| return error.ExpectedRejection else |_| {}
    }
    try t.expectEqual(@as(?f.Sql.Mutation, null), try f.Sql.parseMutation("SELECT * FROM items"));
    try t.expectError(error.UnsupportedStatement, f.Sql.parse("DELETE FROM items WHERE id=1"));
    // Mutation words stay contextual, preserving already valid source names.
    _ = try f.Sql.parse("SELECT set FROM update WHERE insert=1");
    try t.expectError(error.StatementTooLarge, f.Sql.parseMutation(&@as([4097]u8, @splat(' '))));
}

test "typed mutation plans reject empty, sparse, duplicate and ill-typed batches" {
    const schema = (try target(.int64)).schema;
    var plan: mutation.Plan = .{ .schema = schema, .operation = .{ .insert = @splat(null) } };
    try t.expectError(error.InvalidMutationPlan, plan.validate());
    plan.operation.insert[0] = .{ .key = 1, .value = .null };
    plan.operation.insert[2] = .{ .key = 2, .value = .null };
    try t.expectError(error.InvalidMutationPlan, plan.validate());
    plan.operation.insert[1] = .{ .key = 2, .value = .null };
    try t.expectError(error.DuplicateMutationKey, plan.validate());
    plan.operation.insert[2] = .{ .key = 3, .value = .{ .boolean = false } };
    try t.expectError(error.TypeMismatch, plan.validate());
    var ast = (try f.Sql.parseMutation("UPDATE items SET value='ok' WHERE id=1")).?;
    ast.operation.update.literal.utf8.len = std.math.maxInt(u16);
    try t.expectError(error.LiteralTooLarge, mutation.lower(ast, try target(.utf8)));
}

test "mutation variable-width literals enforce the Table storage boundary" {
    var buffer: [1024]u8 = undefined;
    const text: [221]u8 = @splat('x');
    const valid = try std.fmt.bufPrint(&buffer, "INSERT INTO items (id,value) VALUES(1,'{s}')", .{text[0..220]});
    const plan = try mutation.compile(valid, try target(.utf8));
    try t.expectEqual(@as(u8, 220), plan.operation.insert[0].?.value.utf8.len);
    const large = try std.fmt.bufPrint(&buffer, "INSERT INTO items (id,value) VALUES(1,'{s}')", .{text});
    try t.expectError(error.CellTooLarge, mutation.compile(large, try target(.utf8)));
    const hex: [440]u8 = @splat('f');
    const binary = try std.fmt.bufPrint(&buffer, "UPDATE items SET value='\\x{s}'::bytea WHERE id=1", .{hex});
    const updated = try mutation.compile(binary, try target(.binary));
    try t.expectEqualSlices(u8, &@as([220]u8, @splat(255)), updated.operation.update.value.binary.slice());
    try t.expectError(error.InvalidBinaryLiteral, mutation.compile("INSERT INTO items (id,value) VALUES(1,'\\x0'::bytea)", try target(.binary)));
}
