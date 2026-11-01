//! Table completion grammar, typed suggestions and bounded candidate ownership.
//! This module consumes schemas and never acquires metadata or executes SQL.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const a = q.Assistance;
const Parser = f.SqlTyped;
pub const Source = struct { name: []const u8, schema: f.TableSchema.Schema };
pub const Builder = struct {
    allocator: std.mem.Allocator,
    prefix: []const u8,
    quoted: bool,
    items: [a.max_items]a.Item = undefined,
    exact: [a.max_items]bool = undefined,
    count: usize = 0,
    limited: bool = false,
    pub fn add(self: *Builder, raw: []const u8, kind: @FieldType(a.Item, "kind"), detail: []const u8) !void {
        return self.addQualified(raw, null, kind, detail);
    }
    fn addQualified(self: *Builder, raw: []const u8, qualifier: ?[]const u8, kind: @FieldType(a.Item, "kind"), detail: []const u8) !void {
        if (raw.len < self.prefix.len) return;
        const identifier = kind == .source or kind == .column;
        if (self.quoted) {
            if (!identifier or !std.mem.startsWith(u8, raw, self.prefix)) return;
        } else if (!std.ascii.eqlIgnoreCase(raw[0..self.prefix.len], self.prefix)) return;
        // Quoted identifiers preserve case, embedded quotes and the full 255
        // byte name. Completion never inserts terminal control characters.
        for (raw) |byte| if (byte < 32 or byte == 127) return;
        if (qualifier) |name| for (name) |byte| if (byte < 32 or byte == 127) return;
        var buffer: [1029]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        if (identifier) {
            if (qualifier) |name| {
                try quotedName(&writer, name);
                try writer.writeByte('.');
            }
            try quotedName(&writer, raw);
        } else try writer.writeAll(raw);
        try a.offer(self.allocator, &self.items, &self.exact, &self.count, &self.limited, self.prefix, raw, writer.buffered(), kind, detail);
    }
    pub fn clear(self: *Builder) void {
        for (self.items[0..self.count]) |item| self.allocator.free(item.text);
    }
};
fn quotedName(writer: *std.Io.Writer, name: []const u8) !void {
    try writer.writeByte('"');
    for (name) |byte| {
        try writer.writeByte(byte);
        if (byte == '"') try writer.writeByte(byte);
    }
    try writer.writeByte('"');
}
pub fn ignored(err: anyerror) !void {
    if (err == error.OutOfMemory) return err;
}
pub fn statement(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    var parser = try Parser.init(allocator, text, null);
    if (try parser.takeWord("EXPLAIN")) return text[parser.lexer.start..];
    return text;
}
pub fn target(allocator: std.mem.Allocator, text: []const u8) !?[]const u8 {
    var parser = try Parser.init(allocator, text, null);
    if (parser.word("SELECT")) return try f.TableSelect.target(allocator, text);
    if (parser.word("UPDATE") or parser.word("INSERT") or parser.word("DELETE")) return (try f.TableDml.target(allocator, text)).name;
    if (parser.word("ALTER") or parser.word("DROP")) return (try f.TableDdl.target(allocator, text)).name;
    if (try parser.takeWord("DESCRIBE")) return try parser.named(.source);
    if (try parser.takeWord("SHOW")) {
        if (!(try parser.takeWord("STORAGE"))) return null;
        if (!(try parser.takeWord("FOR"))) return null;
        return try parser.named(.source);
    }
    return null;
}
/// The compiler supplies cursor expectations. Binding failures before the
/// cursor produce no guessed continuations. The optional schema is actual
/// authorized metadata, never a fabricated source for speculative compilation.
pub fn expectations(allocator: std.mem.Allocator, text: []const u8, definition: ?Source) !Parser.Editor {
    var editor: Parser.Editor = .{};
    var parser = try Parser.init(allocator, text, null);
    // Parsing is schema-independent. Keep the completion owner's authorized
    // metadata scoped to the same source even before bound compilation finishes.
    if (definition) |value| {
        const subject = target(allocator, text) catch |err| blk: {
            try ignored(err);
            break :blk null;
        };
        if (subject) |name| if (!std.mem.eql(u8, name, value.name)) return editor;
    }
    if (parser.token.tag == .eof) {
        for ([_][]const u8{ "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP", "SHOW", "DESCRIBE", "EXPLAIN" }) |word| editor.word(word);
        return editor;
    }
    if (parser.word("SELECT")) {
        if (definition) |value| {
            var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
            var semantics: [f.TableSchema.max_columns]f.ColumnSemantics = undefined;
            for (value.schema.columns, semantics[0..value.schema.columns.len]) |column, *out| out.* = column.semantics;
            var compiled = f.TableSelect.compileSemantics(allocator, text, value.name, try value.schema.rowType(&fields), @splat(0), null, &editor, semantics[0..value.schema.columns.len]) catch |err| {
                try ignored(err);
                return editor;
            };
            compiled.deinit();
        } else _ = f.TableSelect.targetWithEditor(allocator, text, &editor) catch |err| {
            try ignored(err);
            return editor;
        };
    } else if (parser.word("CREATE") or parser.word("ALTER") or parser.word("DROP")) {
        if (parser.word("ALTER") and definition == null) {
            _ = f.TableDdl.targetWithEditor(allocator, text, &editor) catch |err| {
                try ignored(err);
                return editor;
            };
        } else {
            var compiled = f.TableDdl.compileWithEditor(allocator, text, if (definition) |value| value.schema else null, null, &editor) catch |err| {
                try ignored(err);
                return editor;
            };
            compiled.deinit();
        }
    } else if (parser.word("INSERT") or parser.word("UPDATE") or parser.word("DELETE")) {
        if (definition) |value| {
            var compiled = f.TableDml.compileWithEditor(allocator, text, value.name, value.schema, null, &editor) catch |err| {
                try ignored(err);
                return editor;
            };
            compiled.deinit();
        } else _ = f.TableDml.targetWithEditor(allocator, text, &editor) catch |err| {
            try ignored(err);
            return editor;
        };
    } else {
        parser.editor = &editor;
        if (try parser.takeWord("SHOW")) {
            if (try parser.takeWord("STORAGE")) {
                parser.requireWord("FOR") catch |err| {
                    try ignored(err);
                    return editor;
                };
                _ = parser.named(.source) catch |err| {
                    try ignored(err);
                    return editor;
                };
            } else parser.requireWord("TABLES") catch |err| try ignored(err);
        } else if (try parser.takeWord("DESCRIBE")) {
            _ = parser.named(.source) catch |err| {
                try ignored(err);
                return editor;
            };
        }
    }
    return editor;
}
pub fn suggestions(builder: *Builder, editor: Parser.Editor, definition: ?Source, qualifier: ?[]const u8) !void {
    if (editor.name_role == .column) if (definition) |value| {
        if (editor.qualifier) |actual| if (qualifier == null or !std.mem.eql(u8, actual.slice(), qualifier.?)) return;
        for (value.schema.columns) |column| {
            if (editor.sum_only and (column.type != .int64 and column.type != .decimal)) continue;
            try builder.add(column.name, .column, @tagName(column.type));
        }
    };
    if (editor.type_name) {
        for (f.SqlTypes.aliases) |alias| try builder.add(alias.name, .keyword, "Logical type");
        for ([_][]const u8{ "DECIMAL", "NUMERIC", "STRUCT", "LIST", "ARRAY", "MAP", "UNION" }) |name| try builder.add(name, .keyword, "Logical type");
    }
    if (editor.value_type) |kind| switch (kind) {
        .utf8 => try builder.add("''", .literal, "UTF-8 literal"),
        .uuid => try builder.add("'00000000-0000-0000-0000-000000000000'", .literal, "UUID literal"),
        .binary => try builder.add("X''", .literal, "Binary literal"),
        .boolean, .date, .time, .timestamp, .interval, .structure, .list, .array, .map, .tagged_union, .json => {},
        else => try builder.add("0", .literal, "Exact typed numeric literal"),
    };
    for (editor.words) |word| if (word) |value| {
        // Ordinary cells cannot persist missing. NULL admission is checked by
        // the actual column/default constraints; completion makes no promise.
        if (editor.value_type != null and std.mem.eql(u8, value, "MISSING")) continue;
        if (std.mem.eql(u8, value, "CASCADE") or std.mem.eql(u8, value, "USING")) continue;
        try builder.add(value, .keyword, "Table SQL grammar");
    };
    for (editor.symbols) |symbol| if (symbol) |value| {
        if (editor.sum_only and value == .star) continue;
        const text: ?[]const u8 = switch (value) {
            .left => "(",
            .right => ")",
            .comma => ",",
            .dot => ".",
            .star => "*",
            .semi => null,
            .eq => "=",
            .ne => "<>",
            .lt => "<",
            .le => "<=",
            .gt => ">",
            .ge => ">=",
            else => null,
        };
        if (text) |raw| try builder.add(raw, .symbol, "Table SQL grammar");
    };
}
pub const RelationalSource = struct { alias: []const u8, schema: f.TableSchema.Schema };
pub fn relationalExpectations(allocator: std.mem.Allocator, text: []const u8, sources: []const RelationalSource) !Parser.Editor {
    var editor: Parser.Editor = .{};
    const Lookup = struct {
        sources: []const RelationalSource,
        fn resolve(raw: ?*const anyopaque, reference: f.RelationalSql.Reference) ?f.Types.Type {
            const self: *const @This() = @ptrCast(@alignCast(raw.?));
            var found: ?f.Types.Type = null;
            for (self.sources) |source| {
                if (reference.qualifier) |alias| if (!std.mem.eql(u8, alias, source.alias)) continue;
                for (source.schema.columns) |column| if (std.mem.eql(u8, column.name, reference.name)) {
                    if (found != null or (column.type != .int64 and column.type != .decimal)) return null;
                    found = column.type;
                };
            }
            return found;
        }
    };
    const lookup: Lookup = .{ .sources = sources };
    var syntax = f.RelationalSql.parseWithContext(allocator, text, null, .{ .editor = &editor, .lookup = .{ .context = &lookup, .resolve = Lookup.resolve } }) catch |err| {
        try ignored(err);
        return editor;
    };
    syntax.deinit();
    return editor;
}
pub fn relationalSuggestions(builder: *Builder, editor: Parser.Editor, sources: []const RelationalSource) !void {
    if (editor.name_role == .column) for (sources) |source| {
        if (editor.qualifier) |alias| if (!std.mem.eql(u8, alias.slice(), source.alias)) continue;
        for (source.schema.columns) |column| {
            if ((column.type != .int64 and column.type != .decimal)) continue;
            try builder.addQualified(column.name, if (editor.qualifier == null and sources.len > 1) source.alias else null, .column, "int64");
        }
    };
    var admitted = editor;
    for (&admitted.words) |*slot| if (slot.*) |word| {
        if (editor.value_type != null and std.mem.eql(u8, word, "NULL")) {
            slot.* = null;
            continue;
        }
        for ([_][]const u8{ "MISSING", "TYPE_ERROR", "VALUE", "CONFLICT" }) |unsupported| if (std.mem.eql(u8, word, unsupported)) {
            slot.* = null;
            break;
        };
    };
    try suggestions(builder, admitted, null, null);
}
fn fixture(allocator: std.mem.Allocator, text: []const u8, expected: []const []const u8, forbidden: []const []const u8) !void {
    var declaration = try f.TableDdl.compile(allocator, "CREATE TABLE people (identifier INTEGER PRIMARY KEY, display_name VARCHAR(200), score BIGINT, active BOOLEAN, amount DECIMAL(18,2))", null, null);
    defer declaration.deinit();
    const source: Source = .{ .name = "people", .schema = try declaration.statement.create.bind(51) };
    const range = (try f.SqlInput.replacement(text, @intCast(text.len))).?;
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    var builder: Builder = .{ .allocator = allocator, .prefix = text[range.start..], .quoted = false };
    defer builder.clear();
    const editor = try expectations(arena.allocator(), text[0..range.start], source);
    try suggestions(&builder, editor, source, "people");
    for (expected) |word| {
        var found = false;
        for (builder.items[0..builder.count]) |item| if (std.mem.eql(u8, item.text, word)) {
            found = true;
            break;
        };
        if (!found) std.debug.print("missing {s} for {s}\n", .{ word, text });
        try std.testing.expect(found);
    }
    for (forbidden) |word| for (builder.items[0..builder.count]) |item| try std.testing.expect(!std.mem.eql(u8, item.text, word));
}
test "general Table continuations come from selected production grammar and actual column types" {
    const allocator = std.testing.allocator;
    try fixture(allocator, "SHOW ", &.{ "TABLES", "STORAGE" }, &.{"SELECT"});
    try fixture(allocator, "SHOW STORAGE ", &.{"FOR"}, &.{ "TABLES", "\"identifier\"" });
    try fixture(allocator, "CREATE ", &.{"TABLE"}, &.{"SELECT"});
    try fixture(allocator, "CREATE TABLE people (name VAR", &.{"VARCHAR"}, &.{"VARBINARY"});
    try fixture(allocator, "CREATE TABLE people (name TEXT ", &.{ "NOT", "NULL", "DEFAULT", "PRIMARY" }, &.{ "UNIQUE", "CHECK", "REFERENCES" });
    try fixture(allocator, "ALTER TABLE people ", &.{ "RENAME", "ADD", "DROP", "ALTER" }, &.{"CASCADE"});
    try fixture(allocator, "ALTER TABLE people DROP COLUMN dis", &.{"\"display_name\""}, &.{"\"identifier\""});
    try fixture(allocator, "DROP TABLE people ", &.{"RESTRICT"}, &.{"CASCADE"});
    try fixture(allocator, "ALTER TABLE people DROP COLUMN display_name ", &.{"RESTRICT"}, &.{"CASCADE"});
    try fixture(allocator, "ALTER TABLE people ALTER COLUMN display_name SET ", &.{ "DEFAULT", "NOT", "DATA" }, &.{"CASCADE"});
    try fixture(allocator, "UPDATE people SET display_name = ", &.{ "DEFAULT", "''", "NULL" }, &.{ "MISSING", "TRUE", "0" });
    try fixture(allocator, "UPDATE people SET active = ", &.{ "DEFAULT", "TRUE", "FALSE" }, &.{ "MISSING", "0" });
    try fixture(allocator, "INSERT INTO people (dis", &.{"\"display_name\""}, &.{"SET"});
    try fixture(allocator, "SELECT ", &.{ "\"identifier\"", "\"display_name\"", "COUNT", "SUM" }, &.{"JOIN"});
    try fixture(allocator, "SELECT SUM(", &.{"\"score\""}, &.{ "\"identifier\"", "\"display_name\"", "*" });
    try fixture(allocator, "DELETE FROM people WHERE display_name ", &.{ "IS", "=", "<>" }, &.{"JOIN"});
    try fixture(allocator, "SELECT score FROM people WHERE active = ", &.{ "TRUE", "FALSE" }, &.{ "MISSING", "0" });
    try fixture(allocator, "SELECT score FROM people WHERE active IS ", &.{ "NULL", "MISSING", "VALUE", "TYPE_ERROR", "CONFLICT" }, &.{"ERROR"});
    try fixture(allocator, "SELECT wrong.", &.{}, &.{ "\"identifier\"", "\"display_name\"" });
    try fixture(allocator, "UPDATE absent SET ", &.{}, &.{ "\"identifier\"", "\"display_name\"" });
    try fixture(allocator, "ALTER TABLE absent ALTER COLUMN ", &.{}, &.{ "\"identifier\"", "\"display_name\"" });
    try fixture(allocator, "SELECT score FROM absent WHERE ", &.{}, &.{ "\"identifier\"", "\"display_name\"" });
}
test "identifier suggestions retain long Unicode and quoted names without terminal controls" {
    const allocator = std.testing.allocator;
    var builder: Builder = .{ .allocator = allocator, .prefix = "", .quoted = false };
    defer builder.clear();
    const long: [255]u8 = @splat('z');
    try builder.add(&long, .column, "utf8");
    try builder.add("a\"🌱", .column, "utf8");
    try builder.add("private\x1b[2J", .column, "utf8");
    try std.testing.expectEqual(2, builder.count);
    try std.testing.expectEqual(257, builder.items[1].text.len);
    try std.testing.expectEqualStrings("\"a\"\"🌱\"", builder.items[0].text);
}
test "completion owns strings and cleans up at every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            try fixture(allocator, "UPDATE people SET display_name = ", &.{ "DEFAULT", "''" }, &.{"MISSING"});
        }
    }.run, .{});
}

fn relationalFixture(allocator: std.mem.Allocator, text: []const u8, expected: []const []const u8, forbidden: []const []const u8) !void {
    const columns = [_]f.TableSchema.Column{
        .{ .id = 1, .name = "key", .type = .int64 },
        .{ .id = 2, .name = "value", .type = .int64 },
        .{ .id = 3, .name = "label", .type = .utf8 },
    };
    const schema: f.TableSchema.Schema = .{ .object = 11, .revision = 1, .next_column = 4, .columns = &columns };
    const sources = [_]RelationalSource{ .{ .alias = "l", .schema = schema }, .{ .alias = "r", .schema = schema } };
    const range = (try f.SqlInput.replacement(text, @intCast(text.len))).?;
    var builder: Builder = .{ .allocator = allocator, .prefix = text[range.start..], .quoted = false };
    defer builder.clear();
    const editor = try relationalExpectations(allocator, text[0..range.start], &sources);
    try relationalSuggestions(&builder, editor, &sources);
    for (expected) |word| {
        var found = false;
        for (builder.items[0..builder.count]) |item| if (std.mem.eql(u8, item.text, word)) {
            found = true;
        };
        if (!found) std.debug.print("missing {s} for {s}\n", .{ word, text });
        try std.testing.expect(found);
    }
    for (forbidden) |word| for (builder.items[0..builder.count]) |item| try std.testing.expect(!std.mem.eql(u8, item.text, word));
}
test "relational completion qualifies aliases and limits columns to the admitted type" {
    try relationalFixture(std.testing.allocator, "SELECT ", &.{ "\"l\".\"key\"", "\"r\".\"key\"", "SUM", "COUNT" }, &.{ "\"key\"", "\"l\".\"label\"" });
    try relationalFixture(std.testing.allocator, "SELECT r.va", &.{"\"value\""}, &.{ "\"r\".\"value\"", "\"key\"" });
    try relationalFixture(std.testing.allocator, "SELECT absent.", &.{}, &.{ "\"key\"", "\"value\"" });
    try relationalFixture(std.testing.allocator, "SELECT SUM(", &.{"\"r\".\"value\""}, &.{ "*", "\"r\".\"label\"" });
    try relationalFixture(std.testing.allocator, "SELECT l.key FROM lefts l LEFT ", &.{ "JOIN", "OUTER" }, &.{ "RIGHT", "FULL" });
    try relationalFixture(std.testing.allocator, "SELECT l.key FROM lefts l GROUP BY ", &.{"\"l\".\"key\""}, &.{ "LIMIT", "HAVING" });
    try relationalFixture(std.testing.allocator, "SELECT l.key FROM lefts l WHERE l.key IS ", &.{ "NOT", "NULL" }, &.{ "MISSING", "VALUE", "TYPE_ERROR", "CONFLICT" });
    try relationalFixture(std.testing.allocator, "SELECT l.key FROM lefts l WHERE l.key = ", &.{"0"}, &.{ "TRUE", "FALSE", "''", "NULL" });
    try relationalFixture(std.testing.allocator, "SELECT l.key FROM lefts l WHERE key ", &.{}, &.{ "IS", "=", "<>" });
    try std.testing.checkAllAllocationFailures(std.testing.allocator, relationalFixture, .{ "SELECT l.va", &.{"\"value\""}, &.{"\"label\""} });
}

test "qualified identifier ranking uses the typed column spelling before quoting" {
    const t = std.testing;
    var builder: Builder = .{ .allocator = t.allocator, .prefix = "v", .quoted = false };
    defer builder.clear();
    try builder.addQualified("Value", "a", .column, "int64");
    try builder.addQualified("value", "z", .column, "int64");
    try t.expectEqualStrings("\"z\".\"value\"", builder.items[0].text);
    try t.expectEqualStrings("\"a\".\"Value\"", builder.items[1].text);
}
