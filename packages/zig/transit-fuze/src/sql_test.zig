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
        .{ .prefix = "SELECT id, value ", .keyword = "FROM" },
        .{ .prefix = "SELECT * FROM ", .role = .source },
        .{ .prefix = "SELECT * FROM items ", .keyword = "WHERE", .symbol = .semi },
        .{ .prefix = "SELECT * FROM items WHERE ", .role = .column },
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
    const literal = try sql.hints("SELECT * FROM items WHERE id = ");
    try t.expectEqualStrings("id", literal.literal_column.?.name.slice());
    try t.expectEqualStrings("items", literal.source.?.slice());
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
