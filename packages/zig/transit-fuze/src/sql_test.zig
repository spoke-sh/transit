const std = @import("std");
const f = @import("root.zig");
const sql = f.Sql;
const m = f.model;
const t = std.testing;
fn source(kind: m.Type) !sql.Source {
    return .{ .name = try m.Name.init("items"), .schema = .{ .names = .{ try m.Name.init("id"), try m.Name.init("value") }, .value_type = kind } };
}
test "SQL compilation preserves explicit plans and owns every parsed byte" {
    var text = "SELECT value, id FROM items WHERE value <> 'it''s 東京' LIMIT 2".*;
    const ast = try sql.parse(&text);
    @memset(&text, 'x');
    const expected: f.Stream.Plan = .{
        .predicate = .{ .compare = .{ .column = 1, .op = .ne, .value = .{ .utf8 = try m.Bytes.init("it's 東京") } } },
        .projection = .{ 1, 0 },
        .limit = 2,
    };
    try t.expectEqualDeep(expected, try sql.compile(ast, try source(.utf8)));
    try t.expectEqualDeep(f.Stream.Plan{}, try sql.plan("SELECT * FROM items", try source(.int64)));
    try t.expectEqualDeep(f.Stream.Plan{ .aggregate = .count, .limit = 0 }, try sql.plan("SELECT count(*) FROM (SELECT * FROM items LIMIT 0) AS chosen", try source(.int64)));
    try t.expectEqualDeep(f.Stream.Plan{ .aggregate = .sum, .projection = .{ 1, null }, .limit = 2, .predicate = .{ .is_null = 0 } }, try sql.plan("SELECT sum(chosen.value) FROM (SELECT value FROM items WHERE id IS NULL LIMIT 2) AS chosen", try source(.int64)));
    const binary = try sql.plan("SELECT * FROM items WHERE value = '\\x00FF'::bytea", try source(.binary));
    try t.expectEqualSlices(u8, &.{ 0, 255 }, binary.predicate.compare.value.binary.slice());
}
test "SQL bounded lexical decoding and complete-input rejection" {
    const schema = try source(.int64);
    try t.expectError(error.StatementTooLarge, sql.parse(&(@as([sql.max_statement_bytes + 1]u8, @splat(' ')))));
    try t.expectError(error.InvalidSqlEncoding, sql.parse("SELECT * FROM items\x00"));
    try t.expectError(error.InvalidSqlEncoding, sql.parse("SELECT * FROM items\xff"));
    try t.expectError(error.InvalidColumnName, sql.parse("SELECT seventeenlettersx FROM items"));
    try t.expectError(error.InvalidColumnName, sql.parse("SELECT \"a\"\"b\" FROM items"));
    try t.expectError(error.LiteralOutOfRange, sql.parse("SELECT * FROM items WHERE id = 9223372036854775808"));
    try t.expectError(error.LiteralOutOfRange, sql.parse("SELECT * FROM items WHERE id = -9223372036854775809"));
    try t.expectError(error.LiteralOutOfRange, sql.parse("SELECT * FROM items LIMIT 18446744073709551616"));
    try t.expectError(error.UnsupportedAggregateLimit, sql.plan("SELECT count(*) FROM items LIMIT 0", schema));
    try t.expectError(error.UnsupportedLimit, sql.plan("SELECT * FROM items LIMIT 18446744073709551615", schema));
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
    try t.expectError(error.CellTooLarge, sql.plan(cell_large, try source(.utf8)));
    const binary_max = try literalText(&buffer, "ff", m.max_cell_bytes, true);
    const max_plan = try sql.plan(binary_max, try source(.binary));
    try t.expectEqual(m.max_cell_bytes, max_plan.predicate.compare.value.binary.len);
    try t.expectError(error.UnknownColumn, sql.plan("SELECT \"VALUE\" FROM items", schema));
}
test "compiled sum retains checked overflow, cancellation and source fences" {
    const table = try source(.int64);
    const plan = try sql.plan("SELECT sum(value) FROM items", table);
    const basis: m.Basis = .{ .resource = 7, .revision = 9, .schema = try table.schema.fingerprint() };
    const bound = try plan.bind(basis, table.schema);
    const rows = [_]m.Row{
        .{ .key = 1, .value = .{ .int64 = std.math.maxInt(i64) } },
        .{ .key = 2, .value = .{ .int64 = 1 } },
        .{ .key = 3, .value = .{ .int64 = -1 } },
    };
    var workspace: [f.execution.working_bytes]u8 = undefined;
    var output: [8192]u8 = undefined;
    const cancel = f.execution.Cancellation.init(false);
    const first = try f.Stream.step(bound, bound.start(), .{ .ordinal = 0, .source = .{ .basis = basis, .schema = table.schema, .rows = rows[0..1] }, .end = false }, &workspace, &output, &cancel);
    const second: f.Stream.Page = .{ .ordinal = 1, .source = .{ .basis = basis, .schema = table.schema, .rows = rows[1..] }, .end = true };
    try t.expectError(error.Overflow, f.Stream.step(bound, first.progress, second, &workspace, &output, &cancel));
    var changed = second;
    changed.source.basis.revision += 1;
    try t.expectError(error.SourceChanged, f.Stream.step(bound, first.progress, changed, &workspace, &output, &cancel));
    const cancelled = f.execution.Cancellation.init(true);
    try t.expectError(error.Cancelled, f.Stream.step(bound, first.progress, second, &workspace, &output, &cancelled));
    const limited = try sql.plan("SELECT sum(value) FROM (SELECT * FROM items LIMIT 1) AS chosen", table);
    const bounded = try limited.bind(basis, table.schema);
    const result = try f.Stream.step(bounded, bounded.start(), .{ .ordinal = 0, .source = .{ .basis = basis, .schema = table.schema, .rows = &rows }, .end = true }, &workspace, &output, &cancel);
    try t.expectEqual(std.math.maxInt(i64), result.progress.sum.?);
    try t.expectEqual(f.Stream.Finish.limit, result.progress.finished.?);
}
test "bounded arbitrary SQL never crashes or bypasses plan validation" {
    var random = std.Random.DefaultPrng.init(12);
    const alphabet = "SELECT from where id value 0123456789'-+<>!=/*;\"\n()_";
    var bytes: [512]u8 = undefined;
    const table = try source(.int64);
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
        const plan = sql.compile(ast, table) catch continue;
        accepted += 1;
        _ = try plan.bind(.{ .resource = 7, .revision = 9, .schema = try table.schema.fingerprint() }, table.schema);
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
