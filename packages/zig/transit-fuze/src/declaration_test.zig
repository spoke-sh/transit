const std = @import("std");
const f = @import("root.zig");
const d = f.Declaration;
const expect = std.testing.expect;
const expectError = std.testing.expectError;

test "state declarations own names and preserve unspecified nullability" {
    var text = "create table Items (id INT64 NOT NULL, value UTF8, enabled BOOL NULL, body BINARY)".*;
    const definition = try d.compile(&text);
    @memset(&text, '?');
    try std.testing.expectEqualStrings("items", definition.name.slice());
    try expect(definition.body.table[0].?.nullability == .not_null);
    try expect(definition.body.table[1].?.nullability == .unspecified);
    try expect(definition.body.table[2].?.nullability == .null);
    try expect(definition.body.table[3].?.type == .binary);
    var output: [512]u8 = undefined;
    const formatted = try definition.format(&output);
    try std.testing.expectEqualStrings("CREATE TABLE \"items\" (\"id\" INT64 NOT NULL, \"value\" UTF8, \"enabled\" BOOL NULL, \"body\" BINARY);", formatted);
    try expect(std.meta.eql(definition, try d.compile(formatted)));
}

test "state declarations normalize syntax and preserve quoted identity" {
    for ([_][]const u8{
        "/*outer /*nested*/ */CREATE DOCUMENT \"Notebook\"; --tail",
        "CREATE KV settings (UTF8)",
        "CREATE KV flags (BOOL)",
        "CREATE KV counters (INT64)",
        "CREATE KV bodies (BINARY)",
        "CREATE TABLE \"TABLE\" (\"NULL\" INT64, \"null\" BINARY NULL)",
        "CREATE TABLE eight (a INT64,b BOOL,c UTF8,d BINARY,e INT64,f BOOL,g UTF8,h BINARY)",
    }) |text| {
        const definition = try d.compile(text);
        var first: [512]u8 = undefined;
        var second: [512]u8 = undefined;
        const formatted = try definition.format(&first);
        const restored = try d.compile(formatted);
        try expect(std.meta.eql(definition, restored));
        try std.testing.expectEqualStrings(formatted, try restored.format(&second));
        try expectError(error.UnsupportedStatement, f.Sql.parse(formatted));
        try expect((try f.Sql.parseInspection(formatted)) == null);
        try expectError(error.WriteFailed, definition.format(first[0 .. formatted.len - 1]));
    }
    try expect((try f.Sql.parseDeclaration("SELECT * FROM items")) == null);
    try expectError(error.UnsupportedStatement, d.compile("SELECT * FROM items"));
}

test "state declarations reject incomplete, ambiguous and oversized input" {
    for ([_][]const u8{
        "CREATE",                                                           "CREATE TABLE",                                  "CREATE TABLE items ()",                                                                        "CREATE TABLE items (id)",
        "CREATE TABLE items (id INT64,)",                                   "CREATE TABLE items (id INT64 NOT)",             "CREATE TABLE items (id INT64 NULL NOT NULL)",                                                  "CREATE TABLE items (id INT64 DEFAULT 1)",
        "CREATE TABLE items (id UINT64)",                                   "CREATE TABLE items (id FLOAT64)",               "CREATE TABLE items (id 'INT64')",                                                              "CREATE TABLE items (id \"INT64\")",
        "CREATE TABLE items (id INT64 PRIMARY KEY)",                        "CREATE TABLE items AS SELECT * FROM other",     "CREATE TABLE items (a INT64,b INT64,c INT64,d INT64,e INT64,f INT64,g INT64,h INT64,i INT64)", "CREATE TABLE items (id INT64, ID UTF8)",
        "CREATE TABLE items (id INT64, \"id\" UTF8)",                       "CREATE TABLE items (INT64 INT64)",              "CREATE TABLE a.b (id INT64)",                                                                  "CREATE KV settings ()",
        "CREATE KV settings (INT64,NULL)",                                  "CREATE KV settings (INT64 NULL)",               "CREATE DOCUMENT notebook ()",                                                                  "CREATE DOCUMENT IF NOT EXISTS notebook",
        "CREATE DOCUMENT notebook; CREATE DOCUMENT other",                  "CREATE DOCUMENT notebook;;",                    "CREATE DOCUMENT \"not ebook\"",
        "CREATE DOCUMENT \"é\"",
        "CREATE DOCUMENT notebook /*",                                      "CREATE DOCUMENT abcdefghijklmnopq",             "CREATE DOCUMENT notebook\x00",                                                                 "CREATE DOCUMENT notebook\xff",
        "CREATE CONNECTION http TO http (endpoint='https://example.test')", "CREATE SOURCE items FROM http CONNECTION conn", "CREATE SINK items INTO http CONNECTION conn",
    }) |text| {
        if (d.compile(text)) |_| return error.InvalidDeclarationAccepted else |_| {}
    }
    try expectError(error.StatementTooLarge, d.compile(&@as([f.Sql.max_statement_bytes + 1]u8, @splat(' '))));
    var nested: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&nested);
    for (0..f.Sql.max_comment_depth + 1) |_| try writer.writeAll("/*");
    try expectError(error.CommentTooDeep, d.compile(writer.buffered()));
}

test "typed declarations enforce contiguous columns and canonical owned names" {
    const original = try d.compile("CREATE TABLE items (id INT64 NOT NULL,value INT64 NULL)");
    var changed = original;
    changed.body.table[0] = null;
    try expectError(error.InvalidColumnCount, changed.validate());
    changed = original;
    changed.body.table[2] = changed.body.table[1];
    changed.body.table[1] = null;
    try expectError(error.InvalidColumnCount, changed.validate());
    changed = original;
    changed.body.table[1].?.name = changed.body.table[0].?.name;
    try expectError(error.DuplicateColumn, changed.validate());
    changed = original;
    changed.name.len = 255;
    try expectError(error.InvalidColumnName, changed.validate());
    changed = original;
    changed.body.table[1].?.name.bytes[15] = 'x';
    try expectError(error.InvalidColumnName, changed.validate());
    var output: [512]u8 = undefined;
    try expectError(error.InvalidColumnName, changed.format(&output));
}
