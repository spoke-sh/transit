const std = @import("std");
const f = @import("root.zig");
const sql = f.Sql;
const m = f.model;
const t = std.testing;
fn source(allocator: std.mem.Allocator, kind: f.Unified.Type) !f.Unified.Sql.Source {
    const columns = try allocator.dupe(f.Unified.Column, &.{
        .{ .name = try f.Unified.Name.init("id"), .type = .int64 },
        .{ .name = try f.Unified.Name.init("value"), .type = kind },
    });
    return .{ .name = try f.Unified.Name.init("items"), .schema = .{ .columns = columns } };
}
test "inspection shares lexical bounds and never lowers as executable SELECT" {
    const described = (try sql.parseInspection("/* scope */ DeScRiBe \"Items\"; -- end")).?;
    try t.expectEqualStrings("Items", described.describe.slice());
    inline for (comptime std.meta.fieldNames(sql.Catalog)) |name| {
        try t.expectEqual(@field(sql.Catalog, name), (try sql.parseInspection("SHOW " ++ name ++ ";")).?.show);
    }
    const select = "SELECT sum(chosen.value) FROM (SELECT value FROM items WHERE id > 0 LIMIT 2) AS chosen";
    try t.expectEqualDeep(try sql.parse(select), (try sql.parseInspection("EXPLAIN " ++ select)).?.explain);
    try t.expect((try sql.parseInspection(select)) == null);
    try t.expectError(error.UnsupportedStatement, sql.parse("EXPLAIN " ++ select));
    try t.expectError(error.UnsupportedStatement, sql.parse("DESCRIBE items"));
    try t.expectError(error.UnsupportedStatement, sql.parse("SHOW TABLES"));
    try t.expectError(error.UnsupportedConstruct, sql.parseInspection("DESCRIBE items; SELECT * FROM items"));
    try t.expectError(error.UnsupportedConstruct, sql.parseInspection("SHOW TABLES WHERE id = 1"));
    try t.expectError(error.UnsupportedCatalog, sql.parseInspection("SHOW DOCUMENTS"));
    try t.expectError(error.UnsupportedStatement, sql.parseInspection("EXPLAIN ANALYZE SELECT * FROM items"));
    try t.expectError(error.InvalidSqlSyntax, sql.parseInspection("DESCRIBE items /*"));
    try t.expectError(error.InvalidSqlEncoding, sql.parseInspection("SHOW TABLES\x00"));
    try t.expectError(error.StatementTooLarge, sql.parseInspection(&(@as([sql.max_statement_bytes + 1]u8, @splat(' ')))));
    _ = try sql.parse("SELECT explain FROM explain");
}
test "SQL bounded lexical decoding and complete-input rejection" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const schema = try source(allocator, .int64);
    try t.expectError(error.StatementTooLarge, sql.parse(&(@as([sql.max_statement_bytes + 1]u8, @splat(' ')))));
    try t.expectError(error.InvalidSqlEncoding, sql.parse("SELECT * FROM items\x00"));
    try t.expectError(error.InvalidSqlEncoding, sql.parse("SELECT * FROM items\xff"));
    try t.expectError(error.InvalidColumnName, sql.parse("SELECT seventeenlettersx FROM items"));
    _ = try sql.parse("SELECT id AS abcdefghijklmnop FROM items");
    try t.expectError(error.InvalidColumnName, sql.parse("SELECT id AS abcdefghijklmnopq FROM items"));
    try t.expectError(error.InvalidColumnName, sql.parse("SELECT count(*) AS abcdefghijklmnopq FROM items"));
    try t.expectError(error.InvalidColumnName, sql.parse("SELECT id AS \"\" FROM items"));
    try t.expectError(error.InvalidColumnName, sql.parse("SELECT \"a\"\"b\" FROM items"));
    try t.expectError(error.LiteralOutOfRange, sql.parse("SELECT * FROM items WHERE id = 9223372036854775808"));
    try t.expectError(error.LiteralOutOfRange, sql.parse("SELECT * FROM items WHERE id = -9223372036854775809"));
    try t.expectError(error.LiteralOutOfRange, sql.parse("SELECT * FROM items LIMIT 18446744073709551616"));
    try t.expectError(error.UnsupportedAggregateLimit, f.Unified.Sql.plan(allocator, "SELECT count(*) FROM items LIMIT 0", schema));
    try t.expectEqual(std.math.maxInt(u64), (try f.Unified.Sql.plan(allocator, "SELECT * FROM items LIMIT 18446744073709551615", schema)).limit.?);
    try t.expectError(error.InvalidSqlSyntax, sql.parse("SELECT * FROM items /* unterminated"));
    try t.expectError(error.InvalidSqlSyntax, sql.parse("SELECT * FROM items WHERE value = 'unterminated"));
    try t.expectError(error.UnsupportedConstruct, sql.parse("SELECT * FROM items; SELECT * FROM items;"));
    try t.expectError(error.UnsupportedConstruct, sql.parse("SELECT * FROM items;;"));
    try t.expectError(error.UnsupportedConstruct, sql.parse("SELECT * FROM items WHERE value = 'a'\n'b'"));
    try t.expectError(error.UnsupportedConstruct, sql.parse("SELECT * FROM items ORDER BY id"));
    _ = try sql.parse("/* outer /* inner */ outer */ SELECT * FROM items; -- done");
    var buffer: [4096]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    for (0..sql.max_comment_depth) |_| try writer.writeAll("/*");
    for (0..sql.max_comment_depth) |_| try writer.writeAll("*/");
    try writer.writeAll(" SELECT * FROM items");
    _ = try sql.parse(writer.buffered());
    writer = .fixed(&buffer);
    for (0..sql.max_comment_depth + 1) |_| try writer.writeAll("/*");
    try t.expectError(error.CommentTooDeep, sql.parse(writer.buffered()));
    const huge = try literalText(&buffer, "x", sql.max_literal_bytes + 1, false);
    try t.expectError(error.LiteralTooLarge, sql.parse(huge));
    const cell_large = try literalText(&buffer, "x", m.max_cell_bytes + 1, false);
    try t.expectError(error.CellTooLarge, f.Unified.Sql.plan(allocator, cell_large, try source(allocator, .utf8)));
    const binary_max = try literalText(&buffer, "ff", m.max_cell_bytes, true);
    const max_plan = try f.Unified.Sql.plan(allocator, binary_max, try source(allocator, .binary));
    try t.expectEqual(m.max_cell_bytes, max_plan.predicate.compare.value.binary.len);
    try t.expectError(error.UnknownColumn, f.Unified.Sql.plan(allocator, "SELECT \"VALUE\" FROM items", schema));
}
test "bounded arbitrary SQL never crashes or bypasses plan validation" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var random = std.Random.DefaultPrng.init(12);
    const alphabet = "SELECT from where id value 0123456789'-+<>!=/*;\"\n()_";
    var bytes: [512]u8 = undefined;
    const table = try source(allocator, .int64);
    var accepted: usize = 0;
    for (0..2000) |iteration| {
        const seed = "SELECT sum(value) FROM (SELECT * FROM items WHERE id >= -2 LIMIT 32) AS chosen";
        var size = random.random().uintLessThan(usize, bytes.len);
        if (iteration % 2 == 0) {
            size = seed.len;
            @memcpy(bytes[0..size], seed);
            bytes[random.random().uintLessThan(usize, size)] = alphabet[random.random().uintLessThan(usize, alphabet.len)];
        } else {
            for (bytes[0..size]) |*byte| byte.* = alphabet[random.random().uintLessThan(usize, alphabet.len)];
        }
        const ast = sql.parse(bytes[0..size]) catch continue;
        const plan = f.Unified.Sql.compile(allocator, ast, table) catch continue;
        accepted += 1;
        _ = try plan.bind(.{ .kind = .table, .resource = 7, .revision = 9, .contract = @splat(7), .schema = try table.schema.fingerprint() }, table.schema);
    }
    try t.expect(accepted > 0);
}

fn literalText(buffer: []u8, pattern: []const u8, count: usize, binary: bool) ![]const u8 {
    var writer: std.Io.Writer = .fixed(buffer);
    try writer.writeAll("SELECT * FROM items WHERE value = '");
    if (binary) try writer.writeAll("\\x");
    for (0..count) |_| try writer.writeAll(pattern);
    try writer.writeAll(if (binary) "'::bytea" else "'");
    return writer.buffered();
}

test "incomplete grammar expectations come from the production parser" {
    const Cases = struct { prefix: []const u8, keyword: ?[]const u8 = null, role: ?sql.NameRole = null, symbol: ?sql.Tag = null };
    for ([_]Cases{
        .{ .prefix = "", .keyword = "SELECT" },
        .{ .prefix = "SELECT ", .keyword = "COUNT", .role = .column, .symbol = .star },
        .{ .prefix = "SELECT id ", .keyword = "FROM", .symbol = .comma },
        .{ .prefix = "SELECT id ", .keyword = "AS" },
        .{ .prefix = "SELECT id AS ", .role = .alias },
        .{ .prefix = "SELECT id AS key, ", .role = .column },
        .{ .prefix = "SELECT count(*) ", .keyword = "AS" },
        .{ .prefix = "SELECT count(*) AS ", .role = .alias },
        .{ .prefix = "SELECT sum(value) AS ", .role = .alias },
        .{ .prefix = "SELECT id, value ", .keyword = "FROM" },
        .{ .prefix = "SELECT * FROM ", .role = .source },
        .{ .prefix = "SELECT * FROM items ", .keyword = "WHERE", .symbol = .semi },
        .{ .prefix = "SELECT * FROM items WHERE ", .role = .column, .keyword = "NOT", .symbol = .left },
        .{ .prefix = "SELECT * FROM items WHERE id = 1 ", .keyword = "AND" },
        .{ .prefix = "SELECT * FROM items WHERE id = 1 AND ", .keyword = "NOT", .role = .column, .symbol = .left },
        .{ .prefix = "SELECT * FROM items WHERE NOT (id = 1 ", .keyword = "OR", .symbol = .right },
        .{ .prefix = "SELECT * FROM items WHERE NOT (id = 1 OR ", .role = .column },
        .{ .prefix = "SELECT * FROM items WHERE id ", .keyword = "IS", .symbol = .eq },
        .{ .prefix = "SELECT * FROM items WHERE id IS ", .keyword = "NULL" },
        .{ .prefix = "SELECT * FROM items WHERE id > ", .symbol = .integer },
        .{ .prefix = "SELECT * FROM items LIMIT ", .symbol = .integer },
        .{ .prefix = "SELECT COUNT(", .symbol = .star },
        .{ .prefix = "SELECT COUNT(*) ", .keyword = "FROM" },
        .{ .prefix = "SELECT SUM(", .role = .column },
        .{ .prefix = "/* one /* two */ */ SELECT ", .role = .column },
        .{ .prefix = "-- ; ignored\nSELECT ", .role = .column },
    }) |case| {
        const hints = try sql.hints(case.prefix);
        if (case.keyword) |expected| {
            var found = false;
            for (hints.words) |word| if (word) |value| {
                if (std.mem.eql(u8, value, expected)) {
                    found = true;
                    break;
                }
            };
            try t.expect(found);
        }
        if (case.role) |expected| try t.expectEqual(expected, hints.name_role.?);
        if (case.symbol) |expected| try t.expect(std.mem.indexOfScalar(?sql.Tag, &hints.symbols, expected) != null);
    }
    const qualified = try sql.hints("SELECT \"items\".");
    try t.expectEqual(sql.NameRole.column, qualified.name_role.?);
    try t.expectEqualStrings("items", qualified.qualifier.?.slice());
    try t.expect((try sql.hints("SELECT SUM(")).sum_only);
    const count_column = try sql.hints("SELECT COUNT(");
    try t.expect(!count_column.sum_only);
    try t.expectEqual(sql.NameRole.column, count_column.name_role.?);
    try t.expect(std.mem.indexOfScalar(?sql.Tag, &count_column.symbols, .star) != null);
    const literal = try sql.hints("SELECT * FROM items WHERE id = ");
    try t.expectEqualStrings("id", literal.literal_column.?.name.slice());
    try t.expectEqualStrings("items", literal.source.?.slice());
    const aliased = try sql.hints("SELECT * FROM items AS x WHERE x.");
    try t.expectEqualStrings("items", aliased.source.?.slice());
    try t.expectEqualStrings("x", aliased.source_alias.?.slice());
    try t.expectEqualStrings("x", aliased.qualifier.?.slice());
    try t.expectEqual(sql.NameRole.column, aliased.name_role.?);
    try t.expectEqual(sql.NameRole.alias, (try sql.hints("SELECT * FROM items AS ")).name_role.?);
    const renamed = try sql.hints("SELECT id AS key FROM items AS x WHERE x.");
    try t.expectEqualStrings("x", renamed.source_alias.?.slice());
    try t.expectEqualStrings("x", renamed.qualifier.?.slice());
    const plain = try sql.hints("SELECT id AS key FROM items WHERE ");
    try t.expect(plain.source_alias == null);
    try t.expectEqual(sql.NameRole.column, plain.name_role.?);
    for ([_][]const u8{ "DELETE ", "SELECT * JOIN ", "SELECT 'open;", "SELECT \"open", "/* open", "-- ignored" }) |prefix| {
        const hints = try sql.hints(prefix);
        try t.expect(hints.name_role == null);
        for (hints.words) |word| try t.expect(word == null);
        for (hints.symbols) |symbol| try t.expect(symbol == null);
    }
    try t.expectError(error.InvalidSqlEncoding, sql.hints("SELECT \x01"));
    try t.expectError(error.UnsupportedConstruct, sql.parse("SELECT \x01"));
    try t.expectError(error.StatementTooLarge, sql.hints(&(@as([4097]u8, @splat(' ')))));
}

test "Boolean SQL owns compact literals and preserves precedence without recursion" {
    const Instruction = sql.PredicateProgram.Instruction;
    const cases = .{
        .{ "id = 1 OR id = 2 AND NOT id = 3", [_]std.meta.Tag(Instruction){ .atom, .atom, .atom, .negate, .conjunction, .disjunction } },
        .{ "NOT (id = 1 OR id = 2) AND id = 3", [_]std.meta.Tag(Instruction){ .atom, .atom, .disjunction, .negate, .atom, .conjunction } },
    };
    inline for (cases) |case| {
        const ast = try sql.parse("SELECT * FROM items WHERE " ++ case[0]);
        try ast.predicate.program.validate();
        try t.expectEqual(case[1].len, ast.predicate.program.count);
        for (case[1], ast.predicate.program.instructions[0..case[1].len]) |tag, instruction| try t.expectEqual(tag, std.meta.activeTag(instruction));
    }
    var text = "SELECT * FROM items WHERE value = 'it''s 東京' OR NOT value = '\\x00ff'::bytea".*;
    var ast: sql.Ast = undefined;
    try sql.parseInto(&text, &ast, null);
    const copy = ast;
    @memset(&text, 0);
    @memset(&ast.predicate.program.bytes, 0);
    const program = &copy.predicate.program;
    const first = try program.expand(program.instructions[0].atom);
    const second = try program.expand(program.instructions[1].atom);
    try t.expectEqualStrings("it's 東京", first.compare.literal.utf8.slice());
    try t.expectEqualStrings("\\x00ff", second.compare.literal.binary.slice());
    // Literal bytes are bounded once per statement, not once per instruction.
    try t.expect(@sizeOf(sql.PredicateProgram) < 16 * 1024);
    try t.expectEqualDeep(try sql.parse("SELECT * FROM items WHERE id = 1"), try sql.parse("SELECT * FROM items WHERE (((id = 1)))"));
    var invalid = copy;
    invalid.predicate.program.instructions[0].atom.compare.literal.utf8.start = 65535;
    try t.expectError(error.InvalidPredicateProgram, invalid.predicate.program.validate());
    invalid = copy;
    invalid.predicate.program.count = 255;
    try t.expectError(error.InvalidPredicateProgram, invalid.predicate.program.validate());
}

test "Boolean SQL bounds instructions and operator nesting at exact limits" {
    var buffer: [sql.max_statement_bytes]u8 = undefined;
    for ([_]usize{ 63, 64 }) |count| {
        var out: std.Io.Writer = .fixed(&buffer);
        try out.writeAll("SELECT * FROM items WHERE ");
        for (0..count) |_| try out.writeAll("NOT ");
        try out.writeAll("id = 1");
        if (count == 63) {
            const ast = try sql.parse(out.buffered());
            try t.expectEqual(64, ast.predicate.program.count);
        } else try t.expectError(error.PredicateTooComplex, sql.parse(out.buffered()));
    }
    for ([_]usize{ 64, 65 }) |count| {
        var out: std.Io.Writer = .fixed(&buffer);
        try out.writeAll("SELECT * FROM items WHERE ");
        try out.splatByteAll('(', count);
        try out.writeAll("id = 1");
        try out.splatByteAll(')', count);
        if (count == 64) {
            try t.expect((try sql.parse(out.buffered())).predicate == .compare);
        } else try t.expectError(error.PredicateTooComplex, sql.parse(out.buffered()));
    }
    var out: std.Io.Writer = .fixed(&buffer);
    try out.writeAll("SELECT * FROM items WHERE id = 1");
    for (0..32) |_| try out.writeAll(" AND id = 1");
    try t.expectError(error.PredicateTooComplex, sql.parse(out.buffered()));
    for ([_][]const u8{ "NOT", "()", "id = 1 AND", "(id = 1", "id = 1)", "id = 1 OR AND id = 2", "(id = 1 LIMIT 2)" }) |suffix| {
        out = .fixed(&buffer);
        try out.print("SELECT * FROM items WHERE {s}", .{suffix});
        if (sql.parse(out.buffered())) |_| return error.UnexpectedSuccess else |_| {}
    }
    var location: sql.Location = .{};
    try t.expectError(error.InvalidSqlSyntax, sql.parseLocated("SELECT * FROM items WHERE (id = 1", &location));
    try t.expectEqualStrings(")", location.expected.?);
    try t.expectEqual(@as(usize, 33), location.offset);
}
