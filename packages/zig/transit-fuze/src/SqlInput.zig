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
/// statement is parsed once; malformed suffixes keep only lexical evidence.
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
    for (roles, parsed[0..text.len]) |*role, contextual| if (contextual != .unknown) {
        role.* = contextual;
    };
}

/// First explicit terminator outside quotes/comments; returned end includes ';'.
/// No terminator means keep editing, even if a complete statement could compile.
pub fn terminator(text: []const u8) !?u16 {
    var scan = try Scan.init(text);
    while (try scan.next()) |token| if (token.kind == .symbol and text[token.start] == ';') return token.end;
    return null;
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
    try expectRoles("INSERT INTO update (value, missing) VALUES (-1, TRUE), (2, NULL); UPDATE update SET value = '\\x00ff'::bytea WHERE missing = +2; DELETE FROM update WHERE value = 1;", &.{
        .{ "INSERT", .keyword }, .{ "INTO", .keyword },      .{ "update", .identifier }, .{ "value", .identifier }, .{ "missing", .identifier }, .{ "VALUES", .keyword },  .{ "-1", .number },     .{ "TRUE", .literal },       .{ "2", .number },  .{ "NULL", .literal },
        .{ "UPDATE", .keyword }, .{ "update", .identifier }, .{ "SET", .keyword },       .{ "value", .identifier }, .{ "'\\x00ff'", .literal },  .{ "bytea", .type_name }, .{ "WHERE", .keyword }, .{ "missing", .identifier }, .{ "+2", .number }, .{ "DELETE", .keyword },
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
