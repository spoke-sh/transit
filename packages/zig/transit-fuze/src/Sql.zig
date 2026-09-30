//! Allocation-free SQL syntax and completion. Parsing owns its bounded AST;
//! the current Unified.Sql compiler resolves an explicitly supplied source.
const std = @import("std");
const f = @import("root.zig");
const m = f.model;
pub const max_statement_bytes = 4096;
pub const max_comment_depth = 16;
pub const max_literal_bytes = 2 + 2 * m.max_cell_bytes;

pub const Column = struct { qualifier: ?m.Name = null, name: m.Name };
/// Both null means star. Otherwise first is present and second is optional.
pub const Projection = [2]?Column;
pub const Selection = union(enum) { rows: Projection, count, sum: Column };
pub const Text = struct {
    bytes: [max_literal_bytes]u8 = @splat(0),
    len: u16 = 0,
    pub fn slice(self: *const Text) []const u8 {
        return self.bytes[0..self.len];
    }
};
pub const Literal = union(enum) { null, int64: i64, boolean: bool, utf8: Text, binary: Text };
pub const Predicate = union(enum) {
    all,
    is_null: Column,
    compare: struct { column: Column, op: f.Unified.Plan.Comparison, literal: Literal },
};
pub const Input = struct { projection: Projection, limit: ?u64, alias: m.Name };
pub const Ast = struct {
    source: m.Name,
    selection: Selection,
    predicate: Predicate = .all,
    limit: ?u64 = null,
    input: ?Input = null,
};

/// Returned AST contains no pointers into text, allocations, effects or authority.
pub fn parse(text: []const u8) !Ast {
    if (text.len > max_statement_bytes) return error.StatementTooLarge;
    if (!std.unicode.utf8ValidateSlice(text) or std.mem.indexOfScalar(u8, text, 0) != null) return error.InvalidSqlEncoding;
    var parser: Parser = .{ .lexer = .{ .text = text } };
    return statement(&parser);
}
fn statement(parser: *Parser) !Ast {
    try parser.advance();
    if (!parser.word("SELECT")) return error.UnsupportedStatement;
    try parser.advance();
    const selection = try parser.selection();
    if (parser.assistance) |h| h.aggregate = selection != .rows;
    try parser.requireWord("FROM");
    const derived = if (selection == .rows and parser.token.tag == .cursor) false else try parser.take(.left);
    if (derived) {
        if (selection == .rows) return error.UnsupportedConstruct;
        if (parser.assistance) |h| h.aggregate = false;
        try parser.requireWord("SELECT");
        const projected = try parser.projection();
        try parser.requireWord("FROM");
        var ast: Ast = .{ .source = try parser.name(), .selection = selection };
        if (parser.assistance) |h| h.source = ast.source;
        ast.predicate = try parser.predicate();
        const limit = try parser.limit();
        try parser.require(.right);
        try parser.requireWord("AS");
        parser.name_role = .alias;
        ast.input = .{ .projection = projected, .limit = limit, .alias = try parser.name() };
        if (parser.assistance) |h| h.aggregate = true;
        ast.limit = try parser.limit();
        try parser.end();
        return ast;
    }
    var ast: Ast = .{ .source = try parser.name(), .selection = selection };
    if (parser.assistance) |h| h.source = ast.source;
    ast.predicate = try parser.predicate();
    ast.limit = try parser.limit();
    try parser.end();
    return ast;
}

/// Shared checked SQL literal decoding; the returned value owns its bytes.
pub fn literalCell(literal: Literal) !m.Cell {
    return switch (literal) {
        .null => .null,
        .int64 => |value| .{ .int64 = value },
        .boolean => |value| .{ .boolean = value },
        .utf8 => |value| .{ .utf8 = try m.Bytes.init(value.slice()) },
        .binary => |value| blk: {
            const text = value.slice();
            if (!std.mem.startsWith(u8, text, "\\x") or (text.len - 2) % 2 != 0) return error.InvalidBinaryLiteral;
            var bytes: [m.max_cell_bytes]u8 = undefined;
            const decoded = std.fmt.hexToBytes(&bytes, text[2..]) catch return error.InvalidBinaryLiteral;
            break :blk .{ .binary = try m.Bytes.init(decoded) };
        },
    };
}

pub const Tag = enum { cursor, eof, word, quoted, string, integer, left, right, comma, dot, star, cast, plus, minus, eq, ne, lt, le, gt, ge, semi };
const Token = struct { tag: Tag, text: []const u8 };
const Lexer = struct {
    text: []const u8,
    position: usize = 0,
    cursor_enabled: bool = false,
    fn next(self: *Lexer) !Token {
        while (self.position < self.text.len) {
            const rest = self.text[self.position..];
            if (std.mem.indexOfScalar(u8, " \t\r\n", rest[0]) != null) {
                self.position += 1;
            } else if (std.mem.startsWith(u8, rest, "--")) {
                self.position += std.mem.indexOfAny(u8, rest, "\r\n") orelse rest.len;
            } else if (std.mem.startsWith(u8, rest, "/*")) {
                self.position += 2;
                var depth: usize = 1;
                while (depth > 0) {
                    if (self.position == self.text.len) return error.InvalidSqlSyntax;
                    const remaining = self.text[self.position..];
                    if (std.mem.startsWith(u8, remaining, "/*")) {
                        depth += 1;
                        if (depth > max_comment_depth) return error.CommentTooDeep;
                        self.position += 2;
                    } else if (std.mem.startsWith(u8, remaining, "*/")) {
                        depth -= 1;
                        self.position += 2;
                    } else self.position += 1;
                }
            } else break;
        }
        const start = self.position;
        if (start == self.text.len) return .{ .tag = .eof, .text = "" };
        const byte = self.text[start];
        self.position += 1;
        const tag: Tag = if (std.ascii.isAlphabetic(byte) or byte == '_') blk: {
            while (self.position < self.text.len and (std.ascii.isAlphanumeric(self.text[self.position]) or self.text[self.position] == '_')) self.position += 1;
            break :blk .word;
        } else if (std.ascii.isDigit(byte)) blk: {
            while (self.position < self.text.len and std.ascii.isDigit(self.text[self.position])) self.position += 1;
            break :blk .integer;
        } else switch (byte) {
            '\'', '"' => blk: {
                while (true) {
                    if (self.position == self.text.len) return error.InvalidSqlSyntax;
                    const current = self.text[self.position];
                    self.position += 1;
                    if (current == byte) {
                        if (self.position < self.text.len and self.text[self.position] == byte) {
                            self.position += 1;
                        } else break;
                    }
                }
                break :blk if (byte == '\'') .string else .quoted;
            },
            1 => if (self.cursor_enabled) .cursor else return error.UnsupportedConstruct,
            '(' => .left,
            ')' => .right,
            ',' => .comma,
            '.' => .dot,
            '*' => .star,
            '+' => .plus,
            '-' => .minus,
            ';' => .semi,
            '=' => .eq,
            ':' => if (self.consume(':')) .cast else return error.UnsupportedConstruct,
            '!' => if (self.consume('=')) .ne else return error.UnsupportedConstruct,
            '<' => if (self.consume('=')) .le else if (self.consume('>')) .ne else .lt,
            '>' => if (self.consume('=')) .ge else .gt,
            else => return error.UnsupportedConstruct,
        };
        return .{ .tag = tag, .text = self.text[start..self.position] };
    }
    fn consume(self: *Lexer, byte: u8) bool {
        if (self.position == self.text.len or self.text[self.position] != byte) return false;
        self.position += 1;
        return true;
    }
};
const Parser = struct {
    lexer: Lexer,
    token: Token = undefined,
    assistance: ?*Hints = null,
    name_role: NameRole = .source,
    fn advance(self: *Parser) !void {
        self.token = try self.lexer.next();
    }
    fn word(self: *const Parser, expected: []const u8) bool {
        if (self.token.tag == .cursor) if (self.assistance) |h| h.word(expected);
        return self.token.tag == .word and std.ascii.eqlIgnoreCase(self.token.text, expected);
    }
    fn requireWord(self: *Parser, expected: []const u8) !void {
        if (!self.word(expected)) return error.UnsupportedConstruct;
        try self.advance();
    }
    fn take(self: *Parser, tag: Tag) !bool {
        if (self.token.tag == .cursor) if (self.assistance) |h| h.symbol(tag);
        if (self.token.tag != tag) return false;
        try self.advance();
        return true;
    }
    fn require(self: *Parser, tag: Tag) !void {
        if (!try self.take(tag)) return error.InvalidSqlSyntax;
    }
    fn end(self: *Parser) !void {
        _ = try self.take(.semi);
        if (self.token.tag != .eof) return error.UnsupportedConstruct;
    }
    fn name(self: *Parser) !m.Name {
        var bytes: [16]u8 = undefined;
        const token = self.token;
        if (token.tag == .cursor) if (self.assistance) |h| {
            h.name_role = self.name_role;
            return error.IncompleteSql;
        };
        if (token.tag != .word and token.tag != .quoted) return error.InvalidSqlSyntax;
        // Match the reference grammar's reserved keyword set exactly.
        if (token.tag == .word) {
            inline for (.{ "SELECT", "WHERE", "LIMIT", "COUNT", "SUM", "IS", "TRUE", "FALSE", "BYTEA", "CREATE", "CONNECTION", "CONNECTIONS", "SOURCE", "SOURCES", "SINK", "SINKS", "TABLE", "TABLES", "DOCUMENT", "KV", "TO", "FROM", "INTO", "WITH", "GRANT", "REVOKE", "ON", "SHOW", "DESCRIBE", "NOT", "NULL", "SECRET", "AS", "OF", "FOR", "SYSTEM_TIME", "INT64", "BOOL", "UTF8", "BINARY" }) |keyword| {
                if (std.ascii.eqlIgnoreCase(token.text, keyword)) return error.InvalidSqlSyntax;
            }
        }
        const raw = if (token.tag == .quoted) token.text[1 .. token.text.len - 1] else token.text;
        if (raw.len > bytes.len) return error.InvalidColumnName;
        for (raw, 0..) |byte, i| bytes[i] = if (token.tag == .word) std.ascii.toLower(byte) else byte;
        const result = try m.Name.init(bytes[0..raw.len]);
        try self.advance();
        return result;
    }
    fn column(self: *Parser) !Column {
        const previous = self.name_role;
        self.name_role = .column;
        defer self.name_role = previous;
        const first = try self.name();
        if (try self.take(.dot)) {
            if (self.assistance) |h| h.qualifier = first;
            const column_name = try self.name();
            if (self.assistance) |h| h.qualifier = null;
            return .{ .qualifier = first, .name = column_name };
        }
        return .{ .name = first };
    }
    fn projection(self: *Parser) !Projection {
        if (try self.take(.star)) return .{ null, null };
        const first = try self.column();
        return .{ first, if (try self.take(.comma)) try self.column() else null };
    }
    fn selection(self: *Parser) !Selection {
        const count = self.word("COUNT");
        if (count or self.word("SUM")) {
            try self.advance();
            try self.require(.left);
            const result: Selection = if (count) blk: {
                try self.require(.star);
                break :blk .count;
            } else value: {
                if (self.assistance) |h| h.sum_only = true;
                const column_value = try self.column();
                if (self.assistance) |h| h.sum_only = false;
                break :value .{ .sum = column_value };
            };
            try self.require(.right);
            return result;
        }
        return .{ .rows = try self.projection() };
    }
    fn predicate(self: *Parser) !Predicate {
        if (!self.word("WHERE")) return .all;
        try self.advance();
        const col = try self.column();
        if (self.assistance) |h| h.predicate_column = col;
        if (self.word("IS")) {
            try self.advance();
            try self.requireWord("NULL");
            if (self.assistance) |h| h.predicate_column = null;
            return .{ .is_null = col };
        }
        if (self.token.tag == .cursor) if (self.assistance) |h| {
            for ([_]Tag{ .eq, .ne, .lt, .le, .gt, .ge }) |tag| h.symbol(tag);
        };
        const op: f.Unified.Plan.Comparison = switch (self.token.tag) {
            .eq => .eq,
            .ne => .ne,
            .lt => .lt,
            .le => .le,
            .gt => .gt,
            .ge => .ge,
            else => return error.UnsupportedConstruct,
        };
        try self.advance();
        if (self.assistance) |h| h.literal_column = col;
        const value = try self.literal();
        if (self.assistance) |h| {
            h.literal_column = null;
            h.predicate_column = null;
        }
        return .{ .compare = .{ .column = col, .op = op, .literal = value } };
    }
    fn literal(self: *Parser) !Literal {
        if (self.word("NULL")) {
            try self.advance();
            return .null;
        }
        if (self.word("TRUE") or self.word("FALSE")) {
            const value = self.word("TRUE");
            try self.advance();
            return .{ .boolean = value };
        }
        if (self.token.tag == .string) {
            var value: Text = .{};
            const raw = self.token.text[1 .. self.token.text.len - 1];
            var pos: usize = 0;
            while (pos < raw.len) : (pos += 1) {
                if (value.len == max_literal_bytes) return error.LiteralTooLarge;
                value.bytes[value.len] = raw[pos];
                value.len += 1;
                if (raw[pos] == '\'') pos += 1;
            }
            try self.advance();
            if (try self.take(.cast)) {
                try self.requireWord("BYTEA");
                return .{ .binary = value };
            }
            return .{ .utf8 = value };
        }
        const negative = try self.take(.minus);
        if (!negative) _ = try self.take(.plus);
        if (self.token.tag == .cursor) if (self.assistance) |h| h.symbol(.integer);
        if (self.token.tag != .integer) return error.InvalidSqlSyntax;
        const unsigned = std.fmt.parseInt(u64, self.token.text, 10) catch return error.LiteralOutOfRange;
        const value: i128 = if (negative) -@as(i128, unsigned) else unsigned;
        const result = std.math.cast(i64, value) orelse return error.LiteralOutOfRange;
        try self.advance();
        return .{ .int64 = result };
    }
    fn limit(self: *Parser) !?u64 {
        if (!self.word("LIMIT")) return null;
        try self.advance();
        if (self.token.tag == .cursor) if (self.assistance) |h| h.symbol(.integer);
        if (self.token.tag != .integer) return error.InvalidSqlSyntax;
        const result = std.fmt.parseInt(u64, self.token.text, 10) catch return error.LiteralOutOfRange;
        try self.advance();
        return result;
    }
};

pub const NameRole = enum { source, column, alias };
/// Expectations from the production parser at a token boundary. Static keyword
/// slices and owned names only; no catalog, I/O, authority or source-text borrow.
/// Consumers must apply their executable capability and authorized type profile.
pub const Hints = struct {
    words: [16]?[]const u8 = @splat(null),
    symbols: [16]?Tag = @splat(null),
    name_role: ?NameRole = null,
    source: ?m.Name = null,
    qualifier: ?m.Name = null,
    literal_column: ?Column = null,
    predicate_column: ?Column = null,
    sum_only: bool = false,
    aggregate: bool = false,
    fn word(self: *Hints, value: []const u8) void {
        for (&self.words) |*slot| {
            if (slot.*) |existing| {
                if (std.mem.eql(u8, existing, value)) return;
            } else {
                slot.* = value;
                return;
            }
        }
        unreachable; // finite alternatives in the parser, not catalog cardinality
    }
    fn symbol(self: *Hints, value: Tag) void {
        for (&self.symbols) |*slot| {
            if (slot.*) |existing| {
                if (existing == value) return;
            } else {
                slot.* = value;
                return;
            }
        }
        unreachable;
    }
};
/// `prefix` ends before the token being replaced. Incomplete quotes/comments
/// naturally suppress expectations because the parser cannot reach the cursor.
/// A malformed prefix produces no candidates; complete compilation is separate.
pub fn hints(prefix: []const u8) !Hints {
    if (prefix.len > max_statement_bytes) return error.StatementTooLarge;
    if (!std.unicode.utf8ValidateSlice(prefix) or std.mem.indexOfAny(u8, prefix, &.{ 0, 1 }) != null) return error.InvalidSqlEncoding;
    var bytes: [max_statement_bytes + 1]u8 = undefined;
    @memcpy(bytes[0..prefix.len], prefix);
    bytes[prefix.len] = 1;
    var result: Hints = .{};
    var parser: Parser = .{ .lexer = .{ .text = bytes[0 .. prefix.len + 1], .cursor_enabled = true }, .assistance = &result };
    _ = statement(&parser) catch {};
    return result;
}
