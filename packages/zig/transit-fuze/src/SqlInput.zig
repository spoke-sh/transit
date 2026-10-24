//! Bounded editor framing around the selected SQL lexer rules. No execution.
//! This accepts unfinished tokens; Sql.parse remains authoritative at submission.
const std = @import("std");
const sql = @import("Sql.zig");
pub const Kind = enum { space, comment, word, number, string, quoted, symbol };
pub const Token = struct { kind: Kind, start: u16, end: u16, closed: bool = true };
pub const Range = struct { start: u16, end: u16, quoted: bool = false };
pub const Scan = struct {
    text: []const u8,
    position: usize = 0,
    pub fn init(text: []const u8) !Scan {
        if (text.len > sql.max_statement_bytes) return error.StatementTooLarge;
        if (!std.unicode.utf8ValidateSlice(text) or std.mem.indexOfAny(u8, text, &.{ 0, 1 }) != null) return error.InvalidSqlEncoding;
        return .{ .text = text };
    }
    pub fn next(self: *Scan) !?Token {
        const start = self.position;
        if (start == self.text.len) return null;
        const rest = self.text[start..];
        const byte = rest[0];
        var closed = true;
        const kind: Kind = if (std.mem.indexOfScalar(u8, " \t\r\n", byte) != null) value: {
            self.position += 1;
            while (self.position < self.text.len and std.mem.indexOfScalar(u8, " \t\r\n", self.text[self.position]) != null) self.position += 1;
            break :value .space;
        } else if (std.mem.startsWith(u8, rest, "--")) value: {
            self.position += std.mem.indexOfAny(u8, rest, "\r\n") orelse rest.len;
            closed = self.position != self.text.len;
            break :value .comment;
        } else if (std.mem.startsWith(u8, rest, "/*")) value: {
            self.position += 2;
            var depth: usize = 1;
            while (self.position < self.text.len and depth > 0) {
                const remaining = self.text[self.position..];
                if (std.mem.startsWith(u8, remaining, "/*")) {
                    depth += 1;
                    if (depth > sql.max_comment_depth) return error.CommentTooDeep;
                    self.position += 2;
                } else if (std.mem.startsWith(u8, remaining, "*/")) {
                    depth -= 1;
                    self.position += 2;
                } else self.position += 1;
            }
            closed = depth == 0;
            break :value .comment;
        } else if (byte == '\'' or byte == '"') value: {
            self.position += 1;
            closed = false;
            while (self.position < self.text.len) {
                const current = self.text[self.position];
                self.position += 1;
                if (current == byte) {
                    if (self.position < self.text.len and self.text[self.position] == byte) {
                        self.position += 1;
                    } else {
                        closed = true;
                        break;
                    }
                }
            }
            break :value if (byte == '\'') .string else .quoted;
        } else if (std.ascii.isAlphabetic(byte) or byte == '_') value: {
            self.position += 1;
            while (self.position < self.text.len and (std.ascii.isAlphanumeric(self.text[self.position]) or self.text[self.position] == '_')) self.position += 1;
            break :value .word;
        } else if (std.ascii.isDigit(byte)) value: {
            self.position += 1;
            while (self.position < self.text.len and std.ascii.isDigit(self.text[self.position])) self.position += 1;
            break :value .number;
        } else value: {
            self.position += 1;
            break :value .symbol;
        };
        return .{ .kind = kind, .start = @intCast(start), .end = @intCast(self.position), .closed = closed };
    }
};

/// Bounded lexical colors with roles supplied by the production parser. Every
/// statement is parsed by the applicable owners; malformed suffixes retain
/// lexical evidence. No schema lookup or execution is implicit.
/// This is local presentation, not validation, capability discovery or binding.
pub fn classify(text: []const u8, roles: []sql.TokenRole) void {
    @memset(roles, .unknown);
    if (roles.len != text.len) return;
    var scan = Scan.init(text) catch return;
    var begin: usize = 0;
    while (true) {
        const token = (scan.next() catch break) orelse break;
        const role: sql.TokenRole = switch (token.kind) {
            .word => if (sql.isReserved(text[token.start..token.end])) .keyword else .identifier,
            .quoted => .identifier,
            .string => .literal,
            .number => .number,
            .comment => .comment,
            else => .unknown,
        };
        @memset(roles[token.start..token.end], role);
        if (token.kind == .symbol and text[token.start] == ';') {
            classifyStatement(text[begin..token.end], roles[begin..token.end]);
            begin = token.end;
        }
    }
    if (begin < text.len) classifyStatement(text[begin..], roles[begin..]);
}

fn classifyStatement(text: []const u8, roles: []sql.TokenRole) void {
    var parsed: [sql.max_statement_bytes]sql.TokenRole = undefined;
    sql.classifyTokens(text, parsed[0..text.len]);
    classifyTable(text, parsed[0..text.len]);
    for (roles, parsed[0..text.len]) |*role, contextual| if (contextual != .unknown) {
        role.* = contextual;
    };
}

// General Table grammar uses arena-owned syntax. A fixed workspace bounds this
// presentation path independently of execution allocations; exhaustion preserves
// the prefix already classified and the lexical roles on the remaining suffix.
const classification_bytes = 256 * 1024;
fn classifyTable(text: []const u8, roles: []sql.TokenRole) void {
    var workspace: [classification_bytes]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(&workspace);
    classifyTableWithAllocator(text, roles, fixed.allocator()) catch {};
}
fn classifyTableWithAllocator(text: []const u8, roles: []sql.TokenRole, allocator: std.mem.Allocator) !void {
    const Parser = @import("SqlTyped.zig");
    var parser = try Parser.init(allocator, text, null);
    parser.roles = roles;
    const explain = try parser.takeWord("EXPLAIN");
    if (explain or parser.word("SELECT")) {
        const start = parser.lexer.start;
        const relational = @import("RelationalSql.zig");
        if (try relational.required(text[start..])) {
            var syntax = try relational.parseWithContext(allocator, text[start..], null, .{ .roles = roles[start..] });
            defer syntax.deinit();
            return;
        }
        _ = try @import("TableSelect.zig").syntax(&parser, null);
    } else if (parser.word("INSERT") or parser.word("UPDATE") or parser.word("DELETE")) {
        _ = try @import("TableDml.zig").syntax(&parser, null);
    } else if (parser.word("CREATE") or parser.word("ALTER") or parser.word("DROP")) {
        _ = try @import("TableDdl.zig").syntax(&parser, null);
    } else return;
    try parser.finish();
}

/// First explicit terminator outside quotes/comments; returned end includes ';'.
/// No terminator means keep editing, even if a complete statement could compile.
pub fn terminator(text: []const u8) !?u16 {
    var scan = try Scan.init(text);
    while (try scan.next()) |token| if (token.kind == .symbol and text[token.start] == ';') return token.end;
    return null;
}
/// Cursor-local statement, retaining its suffix for binding. Dot commands end
/// at a line boundary; SQL separators inside strings/comments remain inert.
pub fn active(text: []const u8, cursor: u16, console: bool) !Range {
    _ = try Scan.init(text);
    if (cursor > text.len or !std.unicode.utf8ValidateSlice(text[0..cursor])) return error.InvalidSqlCursor;
    var start: usize = 0;
    while (true) {
        while (start < cursor and std.mem.indexOfScalar(u8, " \t\r\n", text[start]) != null) start += 1;
        const dot = console and start < text.len and text[start] == '.';
        const end = if (dot) start + (std.mem.indexOfScalar(u8, text[start..], '\n') orelse (text.len - start)) else start + (try terminator(text[start..]) orelse (text.len - start));
        if (cursor < end or end == text.len and (dot or end == start or text[end - 1] != ';')) return .{ .start = @intCast(start), .end = @intCast(end) };
        if (end == text.len) return .{ .start = @intCast(end), .end = @intCast(end) };
        start = end + @intFromBool(dot);
    }
}

test "active statement respects cursor, suffix, comments and dot command lines" {
    const t = std.testing;
    const text = ".mode table\nSELECT ';';\n SELECT va FROM items; SELECT 2";
    const range = try active(text, 33, true);
    try t.expectEqualStrings("SELECT va FROM items;", text[range.start..range.end]);
    const empty = try active("SELECT ';';", 11, true);
    try t.expectEqual(empty.start, empty.end);
    const dot = try active("  .help sql\nSELECT 1", 5, true);
    try t.expectEqualStrings(".help sql", "  .help sql\nSELECT 1"[dot.start..dot.end]);
}

pub fn significant(text: []const u8) !bool {
    var scan = try Scan.init(text);
    while (try scan.next()) |token| if (token.kind != .space and token.kind != .comment) return true;
    return false;
}
/// Replacement includes the current token's suffix, preventing duplicate text
/// when completing at an interior cursor. Comment/literal positions suppress it.
pub fn replacement(text: []const u8, cursor: u16) !?Range {
    var scan = try Scan.init(text);
    if (cursor > text.len or !std.unicode.utf8ValidateSlice(text[0..cursor])) return error.InvalidSqlCursor;
    while (try scan.next()) |token| {
        if (cursor < token.start) break;
        if (cursor > token.end) continue;
        switch (token.kind) {
            .word, .quoted => return .{ .start = token.start, .end = token.end, .quoted = token.kind == .quoted },
            .comment, .string => if (cursor < token.end or !token.closed) return null,
            .space => if (cursor < token.end) break,
            .number => if (cursor < token.end) return null,
            .symbol => {},
        }
    }
    return .{ .start = cursor, .end = cursor };
}

test "framing respects nested comments, doubled quotes, multiline input and explicit terminators" {
    const t = std.testing;
    for ([_][]const u8{ "SELECT ';' FROM items", "SELECT 'it''s; /quit' FROM items", "/* ; /* ; */ */ SELECT *\nFROM items", "SELECT \"semi;name\" FROM items", "-- ; /quit\nSELECT * FROM items" }) |text| {
        try t.expectEqual(null, try terminator(text));
        var buffer: [512]u8 = undefined;
        const complete = try std.fmt.bufPrint(&buffer, "{s}; /quit", .{text});
        try t.expectEqual(text.len + 1, (try terminator(complete)).?);
        try t.expect(try significant(text));
    }
    try t.expect(!try significant(" -- ignored\n/* ; */ "));
    try t.expectEqual(null, try terminator("SELECT 'unfinished;"));
    try t.expectEqual(null, try terminator("/* unfinished;"));
    try t.expectEqual(@as(u16, 9), (try terminator("SELECT 1;SELECT 2;")).?);
}
test "cursor ranges replace whole tokens and reject split UTF-8 or protected lexical context" {
    const t = std.testing;
    try t.expectEqual(Range{ .start = 7, .end = 12 }, (try replacement("SELECT value FROM items", 9)).?);
    try t.expectEqual(Range{ .start = 7, .end = 14, .quoted = true }, (try replacement("SELECT \"value\"", 10)).?);
    try t.expectEqual(Range{ .start = 7, .end = 10, .quoted = true }, (try replacement("SELECT \"va", 10)).?);
    try t.expectEqual(Range{ .start = 7, .end = 7 }, (try replacement("SELECT ", 7)).?);
    try t.expectEqual(null, try replacement("SELECT '🌱;value'", 13));
    try t.expectError(error.InvalidSqlCursor, replacement("SELECT '🌱;value'", 9));
    try t.expectEqual(null, try replacement("SELECT /* column */ id", 12));
    try t.expectError(error.InvalidSqlCursor, replacement("SELECT", 7));
}

const ExpectedRole = struct { []const u8, sql.TokenRole };
fn expectRoles(text: []const u8, expected: []const ExpectedRole) !void {
    var actual: [sql.max_statement_bytes]sql.TokenRole = undefined;
    var wanted: [sql.max_statement_bytes]sql.TokenRole = @splat(.unknown);
    var offset: usize = 0;
    for (expected) |span| {
        const start = std.mem.indexOfPos(u8, text, offset, span[0]) orelse unreachable;
        offset = start + span[0].len;
        @memset(wanted[start..offset], span[1]);
    }
    classify(text, actual[0..text.len]);
    try std.testing.expectEqualSlices(sql.TokenRole, wanted[0..text.len], actual[0..text.len]);
}

test "relational highlighting follows joins aliases and grouped aggregate syntax" {
    try expectRoles("EXPLAIN SELECT l.k, SUM(r.v) AS total FROM lefts l LEFT JOIN rights r ON l.k=r.k GROUP BY l.k;", &.{
        .{ "EXPLAIN", .keyword }, .{ "SELECT", .keyword }, .{ "l", .identifier }, .{ "k", .identifier }, .{ "SUM", .function }, .{ "r", .identifier }, .{ "v", .identifier }, .{ "AS", .keyword }, .{ "total", .identifier }, .{ "FROM", .keyword }, .{ "lefts", .identifier }, .{ "l", .identifier }, .{ "LEFT", .keyword }, .{ "JOIN", .keyword }, .{ "rights", .identifier }, .{ "r", .identifier }, .{ "ON", .keyword }, .{ "l", .identifier }, .{ "k", .identifier }, .{ "r", .identifier }, .{ "k", .identifier }, .{ "GROUP", .keyword }, .{ "BY", .keyword }, .{ "l", .identifier }, .{ "k", .identifier },
    });
}

test "highlighting distinguishes contextual names from consumed SQL syntax" {
    try expectRoles("SELECT value FROM items WHERE value IS VALUE;", &.{
        .{ "SELECT", .keyword }, .{ "value", .identifier }, .{ "FROM", .keyword }, .{ "items", .identifier },
        .{ "WHERE", .keyword },  .{ "value", .identifier }, .{ "IS", .keyword },   .{ "VALUE", .keyword },
    });
    const names = [_][]const u8{ "MISSING", "TYPE_ERROR", "VALUE", "CONFLICT", "UINT64", "FLOAT64", "EXPLAIN", "INSERT", "UPDATE", "DELETE", "SET", "VALUES" };
    for (names) |name| {
        var text: [512]u8 = undefined;
        const query = try std.fmt.bufPrint(&text, "SELECT {s}.{s} AS {s} FROM {s} AS {s} WHERE {s} IS VALUE;", .{ name, name, name, name, name, name });
        try expectRoles(query, &.{
            .{ "SELECT", .keyword }, .{ name, .identifier }, .{ name, .identifier }, .{ "AS", .keyword },    .{ name, .identifier },
            .{ "FROM", .keyword },   .{ name, .identifier }, .{ "AS", .keyword },    .{ name, .identifier }, .{ "WHERE", .keyword },
            .{ name, .identifier },  .{ "IS", .keyword },    .{ "VALUE", .keyword },
        });
    }
    try expectRoles("select \"FROM\", selectivity from \"items\";", &.{
        .{ "select", .keyword }, .{ "\"FROM\"", .identifier }, .{ "selectivity", .identifier }, .{ "from", .keyword }, .{ "\"items\"", .identifier },
    });
}

test "highlighting covers aggregate templates casts derived inputs and Boolean predicates" {
    for ([_][]const u8{ "NULL", "MISSING", "TYPE_ERROR", "VALUE", "CONFLICT" }) |state| {
        var buffer: [128]u8 = undefined;
        const text = try std.fmt.bufPrint(&buffer, "SELECT COUNT(*) FROM items WHERE value IS {s};", .{state});
        try expectRoles(text, &.{ .{ "SELECT", .keyword }, .{ "COUNT", .function }, .{ "FROM", .keyword }, .{ "items", .identifier }, .{ "WHERE", .keyword }, .{ "value", .identifier }, .{ "IS", .keyword }, .{ state, .keyword } });
    }
    try expectRoles("SELECT SUM(value.value) AS explain FROM (SELECT value AS value FROM update AS value WHERE value.value = '1844'::uint64 LIMIT $1) AS value LIMIT $2;", &.{
        .{ "SELECT", .keyword },    .{ "SUM", .function },     .{ "value", .identifier }, .{ "value", .identifier }, .{ "AS", .keyword },       .{ "explain", .identifier },
        .{ "FROM", .keyword },      .{ "SELECT", .keyword },   .{ "value", .identifier }, .{ "AS", .keyword },       .{ "value", .identifier }, .{ "FROM", .keyword },
        .{ "update", .identifier }, .{ "AS", .keyword },       .{ "value", .identifier }, .{ "WHERE", .keyword },    .{ "value", .identifier }, .{ "value", .identifier },
        .{ "'1844'", .literal },    .{ "uint64", .type_name }, .{ "LIMIT", .keyword },    .{ "$1", .parameter },     .{ "AS", .keyword },       .{ "value", .identifier },
        .{ "LIMIT", .keyword },     .{ "$2", .parameter },
    });
    try expectRoles("SELECT COUNT(value) FROM items WHERE NOT (value IS MISSING OR value = '1.5'::FLOAT64) AND id >= -2;", &.{
        .{ "SELECT", .keyword }, .{ "COUNT", .function },   .{ "value", .identifier }, .{ "FROM", .keyword },      .{ "items", .identifier },
        .{ "WHERE", .keyword },  .{ "NOT", .keyword },      .{ "value", .identifier }, .{ "IS", .keyword },        .{ "MISSING", .keyword },
        .{ "OR", .keyword },     .{ "value", .identifier }, .{ "'1.5'", .literal },    .{ "FLOAT64", .type_name }, .{ "AND", .keyword },
        .{ "id", .identifier },  .{ "-2", .number },
    });
    try expectRoles("SELECT * FROM items WHERE value = $1 LIMIT $2;", &.{
        .{ "SELECT", .keyword }, .{ "FROM", .keyword }, .{ "items", .identifier }, .{ "WHERE", .keyword }, .{ "value", .identifier }, .{ "$1", .parameter }, .{ "LIMIT", .keyword }, .{ "$2", .parameter },
    });
}

test "highlighting covers mutation declaration and inspection parser roots" {
    try expectRoles("INSERT INTO update (value, missing) VALUES (-1, TRUE), (2, NULL); UPDATE update SET value = X'00ff' WHERE missing = +2; DELETE FROM update WHERE value = 1;", &.{
        .{ "INSERT", .keyword }, .{ "INTO", .keyword },      .{ "update", .identifier }, .{ "value", .identifier }, .{ "missing", .identifier }, .{ "VALUES", .keyword }, .{ "-1", .number },     .{ "TRUE", .literal },       .{ "2", .number },  .{ "NULL", .literal },
        .{ "UPDATE", .keyword }, .{ "update", .identifier }, .{ "SET", .keyword },       .{ "value", .identifier }, .{ "X", .type_name },        .{ "'00ff'", .literal }, .{ "WHERE", .keyword }, .{ "missing", .identifier }, .{ "+2", .number }, .{ "DELETE", .keyword },
        .{ "FROM", .keyword },   .{ "update", .identifier }, .{ "WHERE", .keyword },     .{ "value", .identifier }, .{ "1", .number },
    });
    try expectRoles("CREATE TABLE update (value INT64 NOT NULL, missing UTF8 NULL); CREATE KV value (BINARY); CREATE DOCUMENT explain; CREATE KV conflict (BOOL);", &.{
        .{ "CREATE", .keyword }, .{ "TABLE", .keyword }, .{ "update", .identifier }, .{ "value", .identifier }, .{ "INT64", .type_name }, .{ "NOT", .keyword },      .{ "NULL", .keyword },       .{ "missing", .identifier }, .{ "UTF8", .type_name }, .{ "NULL", .keyword },
        .{ "CREATE", .keyword }, .{ "KV", .keyword },    .{ "value", .identifier },  .{ "BINARY", .type_name }, .{ "CREATE", .keyword },  .{ "DOCUMENT", .keyword }, .{ "explain", .identifier }, .{ "CREATE", .keyword },     .{ "KV", .keyword },     .{ "conflict", .identifier },
        .{ "BOOL", .type_name },
    });
    try expectRoles("DESCRIBE update; SHOW TABLES; SHOW SOURCES; EXPLAIN SELECT value FROM explain WHERE value IS CONFLICT;", &.{
        .{ "DESCRIBE", .keyword }, .{ "update", .identifier }, .{ "SHOW", .keyword },     .{ "TABLES", .keyword }, .{ "SHOW", .keyword },       .{ "SOURCES", .keyword },
        .{ "EXPLAIN", .keyword },  .{ "SELECT", .keyword },    .{ "value", .identifier }, .{ "FROM", .keyword },   .{ "explain", .identifier }, .{ "WHERE", .keyword },
        .{ "value", .identifier }, .{ "IS", .keyword },        .{ "CONFLICT", .keyword },
    });
    try expectRoles("SHOW SINKS; SHOW CONNECTIONS;", &.{ .{ "SHOW", .keyword }, .{ "SINKS", .keyword }, .{ "SHOW", .keyword }, .{ "CONNECTIONS", .keyword } });
}

test "highlighting keeps incomplete tokens inert and confines malformed suffixes" {
    try expectRoles("SELECT \"va", &.{ .{ "SELECT", .keyword }, .{ "\"va", .identifier } });
    try expectRoles("SELECT value FROM items WHERE value = 'it''s; FROM", &.{
        .{ "SELECT", .keyword }, .{ "value", .identifier }, .{ "FROM", .keyword }, .{ "items", .identifier }, .{ "WHERE", .keyword }, .{ "value", .identifier }, .{ "'it''s; FROM", .literal },
    });
    try expectRoles("/* SELECT /* FROM */ ; */ SELECT value FROM items -- IS VALUE\nWHERE value IS TYPE_ERROR;", &.{
        .{ "/* SELECT /* FROM */ ; */", .comment }, .{ "SELECT", .keyword }, .{ "value", .identifier }, .{ "FROM", .keyword }, .{ "items", .identifier }, .{ "-- IS VALUE", .comment }, .{ "WHERE", .keyword }, .{ "value", .identifier }, .{ "IS", .keyword }, .{ "TYPE_ERROR", .keyword },
    });
    try expectRoles("SELECT value FROM items WHERE value = $0; SELECT value FROM items WHERE value IS VALUE;", &.{
        .{ "SELECT", .keyword }, .{ "value", .identifier }, .{ "FROM", .keyword }, .{ "items", .identifier }, .{ "WHERE", .keyword }, .{ "value", .identifier }, .{ "$0", .parameter },
        .{ "SELECT", .keyword }, .{ "value", .identifier }, .{ "FROM", .keyword }, .{ "items", .identifier }, .{ "WHERE", .keyword }, .{ "value", .identifier }, .{ "IS", .keyword },
        .{ "VALUE", .keyword },
    });
    try expectRoles("SELECT value FROM items WHERE value IS INVALID AND update IS VALUE;", &.{
        .{ "SELECT", .keyword }, .{ "value", .identifier }, .{ "FROM", .keyword }, .{ "items", .identifier }, .{ "WHERE", .keyword }, .{ "value", .identifier }, .{ "IS", .keyword }, .{ "INVALID", .identifier }, .{ "AND", .keyword }, .{ "update", .identifier }, .{ "IS", .keyword }, .{ "VALUE", .identifier },
    });
    var oversized: [sql.max_statement_bytes + 1]u8 = @splat('x');
    var roles: [oversized.len]sql.TokenRole = undefined;
    classify(&oversized, &roles);
    for (roles) |role| try std.testing.expectEqual(.unknown, role);
    classify("SELECT \xff", roles[0..8]);
    for (roles[0..8]) |role| try std.testing.expectEqual(.unknown, role);
    const statement = "SELECT value FROM items WHERE value IS VALUE;";
    const maximum = statement ++ @as([sql.max_statement_bytes - statement.len]u8, @splat(' '));
    try expectRoles(maximum, &.{ .{ "SELECT", .keyword }, .{ "value", .identifier }, .{ "FROM", .keyword }, .{ "items", .identifier }, .{ "WHERE", .keyword }, .{ "value", .identifier }, .{ "IS", .keyword }, .{ "VALUE", .keyword } });
}

test "general Table highlighting follows aliases nested type and literal positions" {
    for (@import("SqlTypes.zig").aliases) |entry| {
        var buffer: [256]u8 = undefined;
        const text = try std.fmt.bufPrint(&buffer, "CREATE TABLE people (id {s});", .{entry.name});
        // Multiword spellings have unclassified whitespace between type tokens.
        var words = std.mem.tokenizeScalar(u8, entry.name, ' ');
        const first = words.next().?;
        if (words.next()) |second| {
            try expectRoles(text, &.{ .{ "CREATE", .keyword }, .{ "TABLE", .keyword }, .{ "people", .identifier }, .{ "id", .identifier }, .{ first, .type_name }, .{ second, .type_name } });
        } else try expectRoles(text, &.{ .{ "CREATE", .keyword }, .{ "TABLE", .keyword }, .{ "people", .identifier }, .{ "id", .identifier }, .{ first, .type_name } });
    }
    try expectRoles("CREATE TABLE people (payload STRUCT(decimal DECIMAL(18,2), tags LIST(TEXT)) DEFAULT STRUCT(1.25,LIST('a',NULL)), PRIMARY KEY(payload));", &.{
        .{ "CREATE", .keyword }, .{ "TABLE", .keyword }, .{ "people", .identifier }, .{ "payload", .identifier }, .{ "STRUCT", .type_name }, .{ "decimal", .identifier }, .{ "DECIMAL", .type_name }, .{ "18", .number }, .{ "2", .number }, .{ "tags", .identifier }, .{ "LIST", .type_name }, .{ "TEXT", .type_name }, .{ "DEFAULT", .keyword }, .{ "STRUCT", .function }, .{ "1.25", .number }, .{ "LIST", .function }, .{ "'a'", .literal }, .{ "NULL", .literal }, .{ "PRIMARY", .keyword }, .{ "KEY", .keyword }, .{ "payload", .identifier },
    });
    try expectRoles("INSERT INTO people (map, union) VALUES (MAP(2,'two',1,NULL), UNION(chosen,ARRAY(-1,2)));", &.{
        .{ "INSERT", .keyword }, .{ "INTO", .keyword }, .{ "people", .identifier }, .{ "map", .identifier }, .{ "union", .identifier }, .{ "VALUES", .keyword }, .{ "MAP", .function }, .{ "2", .number }, .{ "'two'", .literal }, .{ "1", .number }, .{ "NULL", .literal }, .{ "UNION", .function }, .{ "chosen", .identifier }, .{ "ARRAY", .function }, .{ "-1", .number }, .{ "2", .number },
    });
    try expectRoles("UPDATE people SET amount=- /* note */ 1.25e-3, created=DATE '2000-02-29', bytes=X'00ff', duration=INTERVAL(1,2,3) WHERE amount IS NOT TYPE_ERROR;", &.{
        .{ "UPDATE", .keyword }, .{ "people", .identifier }, .{ "SET", .keyword }, .{ "amount", .identifier }, .{ "-", .number }, .{ "/* note */", .comment }, .{ "1.25e-3", .number }, .{ "created", .identifier }, .{ "DATE", .type_name }, .{ "'2000-02-29'", .literal }, .{ "bytes", .identifier }, .{ "X", .type_name }, .{ "'00ff'", .literal }, .{ "duration", .identifier }, .{ "INTERVAL", .function }, .{ "1", .number }, .{ "2", .number }, .{ "3", .number }, .{ "WHERE", .keyword }, .{ "amount", .identifier }, .{ "IS", .keyword }, .{ "NOT", .keyword }, .{ "TYPE_ERROR", .keyword },
    });
}

test "general ALTER DROP and EXPLAIN consume contextual grammar without metadata" {
    try expectRoles("ALTER TABLE alter RENAME COLUMN rename TO renamed; DROP TABLE IF EXISTS alter RESTRICT;", &.{
        .{ "ALTER", .keyword }, .{ "TABLE", .keyword }, .{ "alter", .identifier }, .{ "RENAME", .keyword }, .{ "COLUMN", .keyword }, .{ "rename", .identifier }, .{ "TO", .keyword }, .{ "renamed", .identifier }, .{ "DROP", .keyword }, .{ "TABLE", .keyword }, .{ "IF", .keyword }, .{ "EXISTS", .keyword }, .{ "alter", .identifier }, .{ "RESTRICT", .keyword },
    });
    try expectRoles("ALTER TABLE people ADD COLUMN amount DECIMAL(18,2) DEFAULT 12.50; ALTER TABLE people ALTER COLUMN amount SET DEFAULT -1.25;", &.{
        .{ "ALTER", .keyword }, .{ "TABLE", .keyword }, .{ "people", .identifier }, .{ "ADD", .keyword }, .{ "COLUMN", .keyword }, .{ "amount", .identifier }, .{ "DECIMAL", .type_name }, .{ "18", .number }, .{ "2", .number }, .{ "DEFAULT", .keyword }, .{ "12.50", .number }, .{ "ALTER", .keyword }, .{ "TABLE", .keyword }, .{ "people", .identifier }, .{ "ALTER", .keyword }, .{ "COLUMN", .keyword }, .{ "amount", .identifier }, .{ "SET", .keyword }, .{ "DEFAULT", .keyword }, .{ "-1.25", .number },
    });
    try expectRoles("ALTER TABLE people ALTER COLUMN amount SET DATA TYPE DOUBLE PRECISION; ALTER TABLE people ALTER COLUMN amount DROP NOT NULL;", &.{
        .{ "ALTER", .keyword }, .{ "TABLE", .keyword }, .{ "people", .identifier }, .{ "ALTER", .keyword }, .{ "COLUMN", .keyword }, .{ "amount", .identifier }, .{ "SET", .keyword }, .{ "DATA", .keyword }, .{ "TYPE", .keyword }, .{ "DOUBLE", .type_name }, .{ "PRECISION", .type_name }, .{ "ALTER", .keyword }, .{ "TABLE", .keyword }, .{ "people", .identifier }, .{ "ALTER", .keyword }, .{ "COLUMN", .keyword }, .{ "amount", .identifier }, .{ "DROP", .keyword }, .{ "NOT", .keyword }, .{ "NULL", .keyword },
    });
    try expectRoles("EXPLAIN SELECT p.amount FROM people AS p WHERE p.amount >= -1.25e+3;", &.{
        .{ "EXPLAIN", .keyword }, .{ "SELECT", .keyword }, .{ "p", .identifier }, .{ "amount", .identifier }, .{ "FROM", .keyword }, .{ "people", .identifier }, .{ "AS", .keyword }, .{ "p", .identifier }, .{ "WHERE", .keyword }, .{ "p", .identifier }, .{ "amount", .identifier }, .{ "-1.25e+3", .number },
    });
    try expectRoles("ALTER TABLE people ALTER COLUMN payload SET DEFAULT STRUCT(1, LIST('a", &.{
        .{ "ALTER", .keyword }, .{ "TABLE", .keyword }, .{ "people", .identifier }, .{ "ALTER", .keyword }, .{ "COLUMN", .keyword }, .{ "payload", .identifier }, .{ "SET", .keyword }, .{ "DEFAULT", .keyword }, .{ "STRUCT", .function }, .{ "1", .number }, .{ "LIST", .function }, .{ "'a", .literal },
    });
}

test "general SQL classification fits dense bounded statements and tolerates allocator exhaustion" {
    const e = std.testing;
    var storage: [sql.max_statement_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&storage);
    try writer.writeAll("INSERT INTO t VALUES ");
    for (0..1018) |i| {
        if (i != 0) try writer.writeByte(',');
        try writer.writeAll("(0)");
    }
    const text = writer.buffered();
    var roles: [sql.max_statement_bytes]sql.TokenRole = @splat(.unknown);
    var workspace: [classification_bytes]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(&workspace);
    try classifyTableWithAllocator(text, roles[0..text.len], fixed.allocator());
    try e.expectEqual(sql.TokenRole.number, roles[text.len - 2]);
    try e.expect(fixed.end_index <= classification_bytes);
    const small = "ALTER TABLE people ALTER amount SET DEFAULT STRUCT(1, LIST('a'))";
    try e.expectError(error.OutOfMemory, classifyTableWithAllocator(small, roles[0..small.len], e.failing_allocator));
    classify(small, roles[0..small.len]);
    try e.expectEqual(sql.TokenRole.function, roles[std.mem.indexOf(u8, small, "LIST").?]);
}
