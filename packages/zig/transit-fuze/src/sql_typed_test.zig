const std = @import("std");
const e = std.testing;
const Parser = @import("SqlTyped.zig");
const sql = @import("Sql.zig");
const t = @import("Types.zig");

test "unbound literal syntax retains nested source spans and exact text until binding" {
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    const text = "STRUCT(-170141183460469231731687303715884105728, MAP(2,'it''s',1,NULL), UNION(chosen, LIST(DATE '2000-02-29'))) /* tail */";
    var parser = try Parser.init(arena.allocator(), text, null);
    const syntax = try parser.literal(null);
    try parser.finish();
    try e.expectEqualStrings("-170141183460469231731687303715884105728", syntax.value.structure[0].value.number);
    try e.expectEqualStrings("it's", syntax.value.structure[1].value.map[1].value.string);
    try e.expectEqualStrings("chosen", syntax.value.structure[2].value.tagged_union.name);
    try e.expectEqualStrings("STRUCT(-170141183460469231731687303715884105728, MAP(2,'it''s',1,NULL), UNION(chosen, LIST(DATE '2000-02-29')))", text[syntax.span.start..syntax.span.end]);
    const kind: t.Type = .{ .structure = &.{
        .{ .name = "n", .type = .int128 },
        .{ .name = "m", .type = .{ .map = .{ .key = &.int32, .value = .{ .type = &.utf8, .nullable = true } } } },
        .{ .name = "u", .type = .{ .tagged_union = &.{.{ .name = "chosen", .type = .{ .list = .{ .type = &.date } } }} } },
    } };
    const bound = try syntax.bind(arena.allocator(), kind, null);
    try e.expectEqual(std.math.minInt(i128), bound.value.structure[0].value.atom.signed);
    try e.expectEqual(@as(i128, 1), bound.value.structure[1].value.map[0].key.signed);
    try e.expectEqual(@as(usize, 1), bound.value.structure[2].value.tagged_union.value.value.list.len);
}

test "typed literal failures identify the original failing child after syntax has advanced" {
    const cases = .{
        .{ "LIST(1, 128) trailing", @as(t.Type, .{ .list = .{ .type = &.int8 } }), error.Overflow, "128" },
        .{ "MAP(1,'one', 1,'duplicate')", @as(t.Type, .{ .map = .{ .key = &.int32, .value = .{ .type = &.utf8 } } }), error.DuplicateMapKey, "1,'duplicate'" },
        .{ "UNION(absent, 1)", @as(t.Type, .{ .tagged_union = &.{.{ .name = "chosen", .type = .int32 }} }), error.UnknownUnionAlternative, "absent" },
        .{ "INTERVAL(1,NULL,3)", @as(t.Type, .interval), error.InvalidSqlSyntax, "NULL" },
        .{ "STRUCT(LIST(1))", @as(t.Type, .{ .structure = &.{.{ .name = "n", .type = .int32 }} }), error.InvalidSqlSyntax, "LIST" },
        .{ "X'zz'", @as(t.Type, .binary), error.InvalidBinaryLiteral, "X'zz'" },
    };
    inline for (cases) |case| {
        var arena: std.heap.ArenaAllocator = .init(e.allocator);
        defer arena.deinit();
        var location: sql.Location = .{};
        var parser = try Parser.init(arena.allocator(), case[0], &location);
        try e.expectError(case[2], parser.value(case[1]));
        try e.expectEqual(std.mem.indexOf(u8, case[0], case[3]).?, location.offset);
    }
}

test "direct literal binding rejects recursive and oversized syntax before allocation" {
    const Literal = Parser.Literal;
    var syntax: Literal = .{ .span = .{ .start = 0, .end = 0 }, .value = .null };
    syntax.value = .{ .list = @as(*const [1]Literal, &syntax) };
    try e.expectError(error.ValueBudgetExceeded, syntax.bind(e.failing_allocator, .int32, null));
    const oversized: [sql.max_statement_bytes + 1]u8 = @splat('1');
    syntax.value = .{ .number = &oversized };
    try e.expectError(error.ValueBudgetExceeded, syntax.bind(e.failing_allocator, .int128, null));
    syntax.value = .{ .number = "1" };
    syntax.span = .{ .start = 2, .end = 1 };
    try e.expectError(error.InvalidSqlSyntax, syntax.bind(e.failing_allocator, .int32, null));
}

test "unbound and bound literal arenas release every partial allocation" {
    try e.checkAllAllocationFailures(e.allocator, allocationCase, .{});
}
fn allocationCase(allocator: std.mem.Allocator) !void {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    var parser = try Parser.init(arena.allocator(), "MAP(2, LIST('a','b'), 1, LIST('c'))", null);
    const syntax = try parser.literal(null);
    try parser.finish();
    _ = try syntax.bind(arena.allocator(), .{ .map = .{ .key = &.int32, .value = .{ .type = &.{ .list = .{ .type = &.utf8 } } } } }, null);
}
