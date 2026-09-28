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
