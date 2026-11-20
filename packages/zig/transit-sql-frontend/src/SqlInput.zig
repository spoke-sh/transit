//! Bounded and streaming lexical framing around the selected SQL lexer rules.
//! Accepts unfinished tokens for editing; Sql.parse remains authoritative at submission.
const std = @import("std");
const sql = @import("Sql.zig");
pub const Kind = enum { space, comment, word, number, string, quoted, symbol };
pub const Token = Scan.Token;
/// Interactive line-editor drafts and cursor assistance remain u16-addressed.
pub const max_editor_bytes = 4096;
pub const EditorScan = Scanner(u16, max_editor_bytes);
/// Single executable statement and program source bound (1 MiB); offsets use u32.
pub const max_source_bytes = sql.max_statement_bytes;
pub const SourceScan = Scanner(u32, max_source_bytes);
/// Offline source compilation module bound (1 MiB); multi-file budgets live in Compiler.
pub const CompilerScan = Scanner(u32, 1024 * 1024);
/// Multi-statement migration source script bound (2 MiB).
pub const max_script_bytes = 2 * 1024 * 1024;
pub const ScriptScan = Scanner(u32, max_script_bytes);
pub const Scan = Scanner(u32, sql.max_statement_bytes);
pub const Range = struct { start: u16, end: u16, quoted: bool = false };

pub const StreamToken = struct {
    kind: Kind,
    start: u64,
    end: u64,
    line: u64,
    column: u64,
    first_byte: u8,
    closed: bool = true,
    at_eof: bool = false,
    word_buf: [16]u8 = @splat(0),
    word_len: u5 = 0,

    pub fn len(self: StreamToken) u64 {
        return self.end - self.start;
    }

    pub fn isWord(self: StreamToken, expected: []const u8) bool {
        if (self.kind != .word or self.len() != expected.len or expected.len > self.word_buf.len) return false;
        return std.ascii.eqlIgnoreCase(self.word_buf[0..self.word_len], expected);
    }

    pub fn isWordPrefixOf(self: StreamToken, expected: []const u8) bool {
        if (self.kind != .word or self.len() > expected.len or self.len() > self.word_buf.len) return false;
        return std.ascii.startsWithIgnoreCase(expected, self.word_buf[0..self.word_len]);
    }
};

/// Allocation-free incremental SQL lexer over arbitrary byte chunks.
pub const StreamLexer = struct {
    pub const Mode = enum {
        idle,
        space,
        maybe_dash,
        line_comment,
        maybe_slash,
        block_comment,
        block_comment_slash,
        block_comment_star,
        string,
        string_quote,
        quoted,
        quoted_quote,
        word,
        number,
        utf8_symbol,
    };

    offset: u64 = 0,
    line: u64 = 1,
    column: u64 = 1,
    mode: Mode = .idle,
    token_start: u64 = 0,
    token_line: u64 = 1,
    token_column: u64 = 1,
    first_byte: u8 = 0,
    comment_depth: u8 = 0,
    word_buf: [16]u8 = @splat(0),
    word_len: u5 = 0,
    utf8_buf: [4]u8 = @splat(0),
    utf8_len: u3 = 0,
    utf8_expected: u3 = 0,

    pub fn inComment(self: StreamLexer) bool {
        return switch (self.mode) {
            .line_comment, .block_comment, .block_comment_slash, .block_comment_star => true,
            else => false,
        };
    }

    pub fn inSignificantToken(self: StreamLexer) bool {
        return switch (self.mode) {
            .idle, .space, .line_comment, .block_comment, .block_comment_slash, .block_comment_star => false,
            .maybe_dash, .maybe_slash, .string, .string_quote, .quoted, .quoted_quote, .word, .number, .utf8_symbol => true,
        };
    }

    fn startToken(self: *StreamLexer, first: u8, mode: Mode) void {
        self.token_start = self.offset;
        self.token_line = self.line;
        self.token_column = self.column;
        self.first_byte = first;
        self.word_len = 0;
        self.mode = mode;
    }

    fn consumeByte(self: *StreamLexer, byte: u8) error{InvalidSqlEncoding}!void {
        if (byte == 0 or byte == 1) return error.InvalidSqlEncoding;
        if (self.utf8_expected == 0) {
            if (byte >= 0x80) {
                const seq = std.unicode.utf8ByteSequenceLength(byte) catch return error.InvalidSqlEncoding;
                self.utf8_buf[0] = byte;
                self.utf8_len = 1;
                self.utf8_expected = seq;
            }
        } else {
            if ((byte & 0xc0) != 0x80) return error.InvalidSqlEncoding;
            self.utf8_buf[self.utf8_len] = byte;
            self.utf8_len += 1;
            if (self.utf8_len == self.utf8_expected) {
                _ = std.unicode.utf8Decode(self.utf8_buf[0..self.utf8_expected]) catch return error.InvalidSqlEncoding;
                self.utf8_len = 0;
                self.utf8_expected = 0;
            }
        }
        self.offset += 1;
        if (byte == '\n') {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }
    }

    fn emit(self: *StreamLexer, kind: Kind, closed: bool, at_eof: bool) StreamToken {
        const tok: StreamToken = .{
            .kind = kind,
            .start = self.token_start,
            .end = self.offset,
            .line = self.token_line,
            .column = self.token_column,
            .first_byte = self.first_byte,
            .closed = closed,
            .at_eof = at_eof,
            .word_buf = self.word_buf,
            .word_len = self.word_len,
        };
        self.mode = .idle;
        self.word_len = 0;
        return tok;
    }

    pub fn nextInChunk(self: *StreamLexer, chunk: []const u8, index: *usize) error{ InvalidSqlEncoding, CommentTooDeep }!?StreamToken {
        while (index.* < chunk.len) {
            const byte = chunk[index.*];
            switch (self.mode) {
                .idle => {
                    if (std.mem.indexOfScalar(u8, " \t\r\n", byte) != null) {
                        self.startToken(byte, .space);
                        try self.consumeByte(byte);
                        index.* += 1;
                    } else if (byte == '-') {
                        self.startToken(byte, .maybe_dash);
                        try self.consumeByte(byte);
                        index.* += 1;
                    } else if (byte == '/') {
                        self.startToken(byte, .maybe_slash);
                        try self.consumeByte(byte);
                        index.* += 1;
                    } else if (byte == '\'' or byte == '"') {
                        self.startToken(byte, if (byte == '\'') .string else .quoted);
                        try self.consumeByte(byte);
                        index.* += 1;
                    } else if (std.ascii.isAlphabetic(byte) or byte == '_') {
                        self.startToken(byte, .word);
                        self.word_buf[0] = byte;
                        self.word_len = 1;
                        try self.consumeByte(byte);
                        index.* += 1;
                    } else if (std.ascii.isDigit(byte)) {
                        self.startToken(byte, .number);
                        try self.consumeByte(byte);
                        index.* += 1;
                    } else if (byte < 0x80) {
                        self.startToken(byte, .idle);
                        try self.consumeByte(byte);
                        index.* += 1;
                        return self.emit(.symbol, true, false);
                    } else {
                        self.startToken(byte, .utf8_symbol);
                        try self.consumeByte(byte);
                        index.* += 1;
                    }
                },
                .space => {
                    if (std.mem.indexOfScalar(u8, " \t\r\n", byte) != null) {
                        try self.consumeByte(byte);
                        index.* += 1;
                    } else return self.emit(.space, true, false);
                },
                .maybe_dash => {
                    if (byte == '-') {
                        try self.consumeByte(byte);
                        index.* += 1;
                        self.mode = .line_comment;
                    } else return self.emit(.symbol, true, false);
                },
                .line_comment => {
                    if (byte == '\r' or byte == '\n') {
                        if (self.utf8_expected != 0) return error.InvalidSqlEncoding;
                        return self.emit(.comment, true, false);
                    }
                    try self.consumeByte(byte);
                    index.* += 1;
                },
                .maybe_slash => {
                    if (byte == '*') {
                        try self.consumeByte(byte);
                        index.* += 1;
                        self.comment_depth = 1;
                        self.mode = .block_comment;
                    } else return self.emit(.symbol, true, false);
                },
                .block_comment => {
                    try self.consumeByte(byte);
                    index.* += 1;
                    if (byte == '/') self.mode = .block_comment_slash else if (byte == '*') self.mode = .block_comment_star;
                },
                .block_comment_slash => {
                    if (byte == '*') {
                        if (self.comment_depth == sql.max_comment_depth) return error.CommentTooDeep;
                        try self.consumeByte(byte);
                        index.* += 1;
                        self.comment_depth += 1;
                        self.mode = .block_comment;
                    } else {
                        try self.consumeByte(byte);
                        index.* += 1;
                        self.mode = if (byte == '/') .block_comment_slash else .block_comment;
                    }
                },
                .block_comment_star => {
                    if (byte == '/') {
                        try self.consumeByte(byte);
                        index.* += 1;
                        self.comment_depth -= 1;
                        if (self.comment_depth == 0) return self.emit(.comment, true, false);
                        self.mode = .block_comment;
                    } else {
                        try self.consumeByte(byte);
                        index.* += 1;
                        self.mode = if (byte == '*') .block_comment_star else .block_comment;
                    }
                },
                .string => {
                    try self.consumeByte(byte);
                    index.* += 1;
                    if (byte == '\'') self.mode = .string_quote;
                },
                .string_quote => {
                    if (byte == '\'') {
                        try self.consumeByte(byte);
                        index.* += 1;
                        self.mode = .string;
                    } else return self.emit(.string, true, false);
                },
                .quoted => {
                    try self.consumeByte(byte);
                    index.* += 1;
                    if (byte == '"') self.mode = .quoted_quote;
                },
                .quoted_quote => {
                    if (byte == '"') {
                        try self.consumeByte(byte);
                        index.* += 1;
                        self.mode = .quoted;
                    } else return self.emit(.quoted, true, false);
                },
                .word => {
                    if (std.ascii.isAlphanumeric(byte) or byte == '_') {
                        if (self.word_len < self.word_buf.len) {
                            self.word_buf[self.word_len] = byte;
                            self.word_len += 1;
                        }
                        try self.consumeByte(byte);
                        index.* += 1;
                    } else return self.emit(.word, true, false);
                },
                .number => {
                    if (std.ascii.isDigit(byte)) {
                        try self.consumeByte(byte);
                        index.* += 1;
                    } else return self.emit(.number, true, false);
                },
                .utf8_symbol => {
                    try self.consumeByte(byte);
                    index.* += 1;
                    if (self.utf8_expected == 0) return self.emit(.symbol, true, false);
                },
            }
        }
        return null;
    }

    pub fn finish(self: *StreamLexer) error{InvalidSqlEncoding}!?StreamToken {
        if (self.utf8_expected != 0) return error.InvalidSqlEncoding;
        return switch (self.mode) {
            .idle => null,
            .space => self.emit(.space, true, true),
            .maybe_dash, .maybe_slash => self.emit(.symbol, true, true),
            .line_comment => self.emit(.comment, false, true),
            .block_comment, .block_comment_slash, .block_comment_star => blk: {
                self.comment_depth = 0;
                break :blk self.emit(.comment, false, true);
            },
            .string => self.emit(.string, false, true),
            .string_quote => self.emit(.string, true, true),
            .quoted => self.emit(.quoted, false, true),
            .quoted_quote => self.emit(.quoted, true, true),
            .word => self.emit(.word, true, true),
            .number => self.emit(.number, true, true),
            .utf8_symbol => unreachable,
        };
    }
};

fn Scanner(comptime Offset: type, comptime max_bytes: usize) type {
    return struct {
        const Self = @This();
        pub const Token = struct { kind: Kind, start: Offset, end: Offset, closed: bool = true };
        text: []const u8,
        position: usize = 0,
        pub fn init(text: []const u8) !Self {
            if (text.len > max_bytes) return error.StatementTooLarge;
            if (!std.unicode.utf8ValidateSlice(text) or std.mem.indexOfAny(u8, text, &.{ 0, 1 }) != null) return error.InvalidSqlEncoding;
            return .{ .text = text };
        }
        pub fn next(self: *Self) !?Self.Token {
            if (self.position == self.text.len) return null;
            var lexer: StreamLexer = .{};
            var index: usize = 0;
            const slice = self.text[self.position..];
            const tok = (try lexer.nextInChunk(slice, &index)) orelse (try lexer.finish()).?;
            const start = self.position + @as(usize, @intCast(tok.start));
            const end = self.position + @as(usize, @intCast(tok.end));
            self.position = end;
            return .{ .kind = tok.kind, .start = @intCast(start), .end = @intCast(end), .closed = tok.closed };
        }
    };
}

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
        if (token.kind == .symbol and text[token.start] == ';') {
            classifyStatement(text[begin..token.end], roles[begin..token.end]);
            begin = token.end;
        }
    }
    if (begin < text.len) classifyStatement(text[begin..], roles[begin..]);
}

fn classifyStatement(text: []const u8, roles: []sql.TokenRole) void {
    sql.classifyTokens(text, roles);
    classifyTable(text, roles);
    var scan = Scan.init(text) catch return;
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
        if (role != .unknown) {
            for (roles[token.start..token.end]) |*slot| if (slot.* == .unknown) {
                slot.* = role;
            };
        }
    }
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

/// First explicit outer terminator; returned end includes ';'. Compound bodies
/// use the source framer, while editor byte and unfinished-input bounds remain.
/// No terminator means keep editing, even if a complete statement could compile.
pub fn terminator(text: []const u8) !?u16 {
    _ = try EditorScan.init(text);
    return if (try @import("SqlScript.zig").editorTerminator(text)) |end| @intCast(end) else null;
}
/// Cursor-local statement, retaining its suffix for binding. Dot commands end
/// at a line boundary; SQL separators inside strings/comments remain inert.
pub fn active(text: []const u8, cursor: u16, console: bool) !Range {
    _ = try EditorScan.init(text);
    if (cursor > text.len or !std.unicode.utf8ValidateSlice(text[0..cursor])) return error.InvalidSqlCursor;
    var start: usize = 0;
    while (true) {
        while (start < cursor and std.mem.indexOfScalar(u8, " \t\r\n", text[start]) != null) start += 1;
        const dot = console and start < text.len and text[start] == '.';
        const end = if (dot) start + (std.mem.indexOfScalar(u8, text[start..], '\n') orelse (text.len - start)) else start + (try terminator(text[start..]) orelse (text.len - start));
        if (cursor < end or (dot and cursor == end) or end == text.len and (dot or end == start or text[end - 1] != ';')) return .{ .start = @intCast(start), .end = @intCast(end) };
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
    const dot = try active("  .help sql\nSELECT 1", 11, true);
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
    var scan = try EditorScan.init(text);
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
test "editor framing retains every incomplete Queue program prefix and its cursor range" {
    const t = std.testing;
    const body = "CREATE DATAFLOW action FROM QUEUE input AS event AS BEGIN LET id = event.id; BEGIN ATOMIC IF id > 0 THEN REQUIRE TRUE ELSE 'Invalid;'; END IF; INSERT INTO output VALUES (id) ON CONFLICT (id) DO ASSERT SAME ROW; END; LET observed = SELECT * FROM output WHERE id = event.id; BEGIN ATOMIC REQUIRE observed.id = id ELSE 'Missing'; END; END;";
    inline for (.{ body, "EXPLAIN " ++ body }) |statement| {
        for (0..statement.len) |end| try t.expectEqual(null, try terminator(statement[0..end]));
        try t.expectEqual(statement.len, (try terminator(statement ++ " SELECT 1;")).?);
        const range = try active(statement ++ " SELECT 1;", @intCast(statement.len / 2), true);
        try t.expectEqualStrings(statement, (statement ++ " SELECT 1;")[range.start..range.end]);
    }
    try t.expectEqual(@as(u16, 1), (try terminator(";;SELECT 1;")).?);
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
    const actual = try std.testing.allocator.alloc(sql.TokenRole, text.len);
    defer std.testing.allocator.free(actual);
    const wanted = try std.testing.allocator.alloc(sql.TokenRole, text.len);
    defer std.testing.allocator.free(wanted);
    @memset(wanted, .unknown);
    var offset: usize = 0;
    for (expected) |span| {
        const start = std.mem.indexOfPos(u8, text, offset, span[0]) orelse unreachable;
        offset = start + span[0].len;
        @memset(wanted[start..offset], span[1]);
    }
    classify(text, actual);
    try std.testing.expectEqualSlices(sql.TokenRole, wanted, actual);
}

test "relational highlighting follows joins aliases and grouped aggregate syntax" {
    try expectRoles("SELECT * FROM people INNER JOIN items ON items.id = people.id;", &.{
        .{ "SELECT", .keyword },   .{ "FROM", .keyword }, .{ "people", .identifier }, .{ "INNER", .keyword }, .{ "JOIN", .keyword },
        .{ "items", .identifier }, .{ "ON", .keyword },   .{ "items", .identifier },  .{ "id", .identifier }, .{ "people", .identifier },
        .{ "id", .identifier },
    });
    try expectRoles("SELECT value, COUNT(*) AS count FROM items GROUP BY value ORDER BY count ASC;", &.{
        .{ "SELECT", .keyword }, .{ "value", .identifier }, .{ "COUNT", .function },   .{ "AS", .keyword },  .{ "count", .identifier },
        .{ "FROM", .keyword },   .{ "items", .identifier }, .{ "GROUP", .keyword },    .{ "BY", .keyword },  .{ "value", .identifier },
        .{ "ORDER", .keyword },  .{ "BY", .keyword },       .{ "count", .identifier }, .{ "ASC", .keyword },
    });
    try expectRoles("SELECT SUM(value) AS sum FROM items HAVING sum > 1 ORDER BY sum DESC;", &.{
        .{ "SELECT", .keyword }, .{ "SUM", .function },     .{ "value", .identifier }, .{ "AS", .keyword },     .{ "sum", .identifier },
        .{ "FROM", .keyword },   .{ "items", .identifier }, .{ "HAVING", .keyword },   .{ "sum", .identifier }, .{ "1", .number },
        .{ "ORDER", .keyword },  .{ "BY", .keyword },       .{ "sum", .identifier },   .{ "DESC", .keyword },
    });
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
    const oversized = try std.testing.allocator.alloc(u8, sql.max_statement_bytes + 1);
    defer std.testing.allocator.free(oversized);
    @memset(oversized, 'x');
    const roles = try std.testing.allocator.alloc(sql.TokenRole, oversized.len);
    defer std.testing.allocator.free(roles);
    classify(oversized, roles);
    for (roles) |role| try std.testing.expectEqual(.unknown, role);
    classify("SELECT \xff", roles[0..8]);
    for (roles[0..8]) |role| try std.testing.expectEqual(.unknown, role);
    const statement = "SELECT value FROM items WHERE value IS VALUE;";
    const maximum = try std.testing.allocator.alloc(u8, sql.max_statement_bytes);
    defer std.testing.allocator.free(maximum);
    @memset(maximum, ' ');
    @memcpy(maximum[0..statement.len], statement);
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

test "qualified wildcards retain contextual highlighting after the projection" {
    // COUNT is an identifier as the alias, while the later AS keyword and
    // numeric LIMIT prove that classification continued beyond count.*.
    try expectRoles("SELECT count.* FROM items AS count WHERE count.id > 0 LIMIT 2;", &.{
        .{ "SELECT", .keyword }, .{ "count", .identifier }, .{ "FROM", .keyword }, .{ "items", .identifier }, .{ "AS", .keyword }, .{ "count", .identifier }, .{ "WHERE", .keyword }, .{ "count", .identifier }, .{ "id", .identifier }, .{ "0", .number }, .{ "LIMIT", .keyword }, .{ "2", .number },
    });
    try expectRoles("SELECT \"I\".* FROM items \"I\" LEFT JOIN people p ON p.id = \"I\".id ORDER BY p.id;", &.{
        .{ "SELECT", .keyword }, .{ "\"I\"", .identifier }, .{ "FROM", .keyword }, .{ "items", .identifier }, .{ "\"I\"", .identifier }, .{ "LEFT", .keyword }, .{ "JOIN", .keyword }, .{ "people", .identifier }, .{ "p", .identifier }, .{ "ON", .keyword }, .{ "p", .identifier }, .{ "id", .identifier }, .{ "\"I\"", .identifier }, .{ "id", .identifier }, .{ "ORDER", .keyword }, .{ "BY", .keyword }, .{ "p", .identifier }, .{ "id", .identifier },
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
    var storage: [4096]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&storage);
    try writer.writeAll("INSERT INTO t VALUES ");
    for (0..1018) |i| {
        if (i != 0) try writer.writeByte(',');
        try writer.writeAll("(0)");
    }
    const text = writer.buffered();
    var roles: [4096]sql.TokenRole = @splat(.unknown);
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

test "streaming lexer matches bounded scanner across arbitrary chunk splits and zero heap allocations" {
    const t = std.testing;
    const memory = @import("transit_memory");
    const sample =
        "-- line comment 東京 🌱\r\n" ++
        "/* outer /* nested //* **/ * / */ still outer */\n" ++
        "SELECT 'it''s; ''🌱''', \"quo\"\"ted;\"\"id\", -42, 10 / 2, 🌱\n" ++
        "FROM _items_1234567890_abcdef WHERE a = 1;-- trailing without newline";

    var baseline_scan = try SourceScan.init(sample);
    var expected: [64]SourceScan.Token = undefined;
    var expected_len: usize = 0;
    while (try baseline_scan.next()) |tok| {
        expected[expected_len] = tok;
        expected_len += 1;
    }

    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    probe.begin(true);

    for ([_]usize{ 1, 2, 3, 5, 7, 13, 31, sample.len }) |step| {
        var lexer: StreamLexer = .{};
        var actual_index: usize = 0;
        var offset: usize = 0;
        while (offset < sample.len) {
            const chunk = sample[offset..@min(sample.len, offset + step)];
            var idx: usize = 0;
            while (try lexer.nextInChunk(chunk, &idx)) |tok| {
                const want = expected[actual_index];
                try t.expectEqual(want.kind, tok.kind);
                try t.expectEqual(@as(u64, want.start), tok.start);
                try t.expectEqual(@as(u64, want.end), tok.end);
                try t.expectEqual(want.closed, tok.closed);
                try t.expectEqual(sample[want.start], tok.first_byte);
                actual_index += 1;
            }
            try t.expectEqual(chunk.len, idx);
            offset += chunk.len;
        }
        if (try lexer.finish()) |tok| {
            const want = expected[actual_index];
            try t.expectEqual(want.kind, tok.kind);
            try t.expectEqual(@as(u64, want.start), tok.start);
            try t.expectEqual(@as(u64, want.end), tok.end);
            try t.expectEqual(want.closed, tok.closed);
            try t.expect(tok.at_eof);
            actual_index += 1;
        }
        try t.expectEqual(expected_len, actual_index);
    }

    var prng = std.Random.DefaultPrng.init(0x517cc1b727220a95);
    const random = prng.random();
    for (0..32) |_| {
        var lexer: StreamLexer = .{};
        var actual_index: usize = 0;
        var offset: usize = 0;
        while (offset < sample.len) {
            const step = random.intRangeAtMost(usize, 1, 11);
            const chunk = sample[offset..@min(sample.len, offset + step)];
            var idx: usize = 0;
            while (try lexer.nextInChunk(chunk, &idx)) |tok| {
                const want = expected[actual_index];
                try t.expectEqual(want.kind, tok.kind);
                try t.expectEqual(@as(u64, want.start), tok.start);
                try t.expectEqual(@as(u64, want.end), tok.end);
                try t.expectEqual(want.closed, tok.closed);
                actual_index += 1;
            }
            offset += chunk.len;
        }
        if (try lexer.finish()) |tok| {
            const want = expected[actual_index];
            try t.expectEqual(want.kind, tok.kind);
            try t.expectEqual(@as(u64, want.start), tok.start);
            try t.expectEqual(@as(u64, want.end), tok.end);
            try t.expectEqual(want.closed, tok.closed);
            actual_index += 1;
        }
        try t.expectEqual(expected_len, actual_index);
    }
    try probe.verify();

    // Encoding and nesting rejections across 1-byte boundaries.
    for ([_][]const u8{
        "SELECT \x00",
        "SELECT \x01",
        "SELECT \xff",
        "SELECT '\xf0\x28\x8c\xbc'",
        "SELECT '\xf0\x9f\x8c'",
        "-- \xf0\nSELECT 1",
        "SELECT '\xc0\xaf'",
        "SELECT '\xed\xa0\x80'",
    }) |bad| {
        var lexer: StreamLexer = .{};
        var caught = false;
        for (bad) |b| {
            var idx: usize = 0;
            const one = [_]u8{b};
            _ = lexer.nextInChunk(&one, &idx) catch |err| {
                try t.expectEqual(error.InvalidSqlEncoding, err);
                caught = true;
                break;
            };
        }
        if (!caught) {
            try t.expectError(error.InvalidSqlEncoding, lexer.finish());
        }
    }

    var deep_lexer: StreamLexer = .{};
    var deep_caught = false;
    outer: for (0..(sql.max_comment_depth + 1)) |_| {
        for ("/* ") |b| {
            var idx: usize = 0;
            const one = [_]u8{b};
            _ = deep_lexer.nextInChunk(&one, &idx) catch |err| {
                try t.expectEqual(error.CommentTooDeep, err);
                deep_caught = true;
                break :outer;
            };
        }
    }
    try t.expect(deep_caught);
}
