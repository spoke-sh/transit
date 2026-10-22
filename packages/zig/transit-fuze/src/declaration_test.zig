const std = @import("std");
const f = @import("root.zig");
const d = f.Declaration;
const expect = std.testing.expect;
const expectError = std.testing.expectError;

test "offline KV definitions own names and canonical review text" {
    var text = "create kv Items (UTF8)".*;
    const definition = try d.compile(&text);
    @memset(&text, '?');
    try std.testing.expectEqualStrings("items", definition.name.slice());
    try expect(definition.body.kv == .utf8);
    var output: [512]u8 = undefined;
    const formatted = try definition.format(&output);
    try std.testing.expectEqualStrings("CREATE KV \"items\" (UTF8);", formatted);
    try expect(std.meta.eql(definition, try d.compile(formatted)));
}

test "state declarations normalize syntax and preserve quoted identity" {
    for ([_][]const u8{
        "/*outer /*nested*/ */CREATE DOCUMENT \"Notebook\"; --tail",
        "CREATE KV settings (UTF8)",
        "CREATE KV flags (BOOL)",
        "CREATE KV counters (INT64)",
        "CREATE KV bodies (BINARY)",
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

test "typed offline declarations enforce canonical owned names" {
    const original = try d.compile("CREATE DOCUMENT items");
    var changed = original;
    changed.name.len = 255;
    try expectError(error.InvalidColumnName, changed.validate());
    changed = original;
    changed.name.bytes[15] = 'x';
    try expectError(error.InvalidColumnName, changed.validate());
    var output: [512]u8 = undefined;
    try expectError(error.InvalidColumnName, changed.format(&output));
}

test "general Table declarations have one parser and schema owner" {
    const text = "CREATE TABLE people(id INTEGER PRIMARY KEY, name VARCHAR(40), amount DECIMAL(18,2), tags LIST(UTF8))";
    try expectError(error.UnsupportedDeclaration, d.compile(text));
    var definition = try f.TableDdl.compile(std.testing.allocator, text, null, null);
    defer definition.deinit();
    const schema = try definition.statement.create.bind(9);
    try expect(schema.columns[0].type == .int32 and !schema.columns[0].nullable);
    try expect(schema.columns[1].nullable and schema.columns[1].max_characters == 40);
    try expect(schema.columns[2].type == .decimal and schema.columns[3].type == .list);
    try expect(schema.columns.len == 4 and schema.primary_key.len == 1);
}

test "declarative object kind and state actions map definitions and validate names" {
    const kv_def = try d.compile("CREATE KV settings (UTF8)");
    try expect(kv_def.objectKind() == .kv);
    const kv_action = kv_def.toStateAction();
    try kv_action.validate();
    try expect(kv_action == .create_kv);
    try std.testing.expectEqualStrings("settings", kv_action.create_kv.name.slice());
    try expect(kv_action.create_kv.value_type == .utf8);

    const doc_def = try d.compile("CREATE DOCUMENT notebook");
    try expect(doc_def.objectKind() == .document);
    const doc_action = doc_def.toStateAction();
    try doc_action.validate();
    try expect(doc_action == .create_document);
    try std.testing.expectEqualStrings("notebook", doc_action.create_document.name.slice());
}
