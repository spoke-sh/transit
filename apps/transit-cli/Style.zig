//! Console presentation only. Color never changes text, source escaping or streams.
const std = @import("std");
const fuze = @import("transit_query").fuze;
const input = fuze.SqlInput;
const Self = @This();

enabled: bool = false,

pub fn detect(init: std.process.Init) Self {
    if (init.environ_map.get("NO_COLOR")) |value| if (value.len != 0) return .{};
    if (init.environ_map.get("TERM")) |value| if (std.mem.eql(u8, value, "dumb")) return .{};
    return .{ .enabled = std.Io.File.stderr().isTty(init.io) catch false };
}

pub const Color = enum { plain, word, literal, number, comment, failure, category, emphasis };

pub fn code(self: Self, color: Color) []const u8 {
    if (!self.enabled) return "";
    return switch (color) {
        .plain => "\x1b[0m",
        .word => "\x1b[36m",
        .literal => "\x1b[32m",
        .number => "\x1b[35m",
        .comment => "\x1b[2m",
        .failure => "\x1b[1;31m",
        .category => "\x1b[33m",
        .emphasis => "\x1b[1m",
    };
}

pub fn text(self: Self, out: *std.Io.Writer, color: Color, value: []const u8) !void {
    if (color != .plain) try out.writeAll(self.code(color));
    try out.writeAll(value);
    if (color != .plain) try out.writeAll(self.code(.plain));
}

/// Shared token colors for the editable draft, submitted echo and redacted SQL.
pub const Syntax = struct {
    roles: [fuze.Sql.max_statement_bytes]fuze.Sql.TokenRole = @splat(.unknown),

    pub fn init(value: []const u8) Syntax {
        _ = input.Scan.init(value) catch return .{};
        var result: Syntax = .{};
        var start: usize = 0;
        while (start < value.len) {
            start += std.mem.indexOfNone(u8, value[start..], " \t\r\n") orelse break;
            if (value[start] == '.') {
                const end = start + (std.mem.indexOfScalar(u8, value[start..], '\n') orelse value.len - start);
                const command_end = start + (std.mem.indexOfAny(u8, value[start..end], " \t\r") orelse end - start);
                // Shell arguments are not SQL, even when they contain keywords,
                // quotes, path separators or comment delimiters.
                @memset(result.roles[start..end], .identifier);
                @memset(result.roles[start + 1 .. command_end], .keyword);
                start = end;
            } else {
                const end = start + (input.terminator(value[start..]) catch null orelse value.len - start);
                input.classify(value[start..end], result.roles[start..end]);
                start = end;
            }
        }
        return result;
    }

    pub fn at(self: *const Syntax, offset: usize) Color {
        return if (offset < self.roles.len) roleColor(self.roles[offset]) else .plain;
    }
};

fn roleColor(role: fuze.Sql.TokenRole) Color {
    return switch (role) {
        .keyword, .function, .type_name => .word,
        .literal => .literal,
        .comment => .comment,
        .number, .parameter => .number,
        .unknown, .identifier => .plain,
    };
}

test "SQL identifiers and quoted names use the default foreground" {
    var buffer: [512]u8 = undefined;
    var out: std.Io.Writer = .fixed(&buffer);
    const style: Self = .{ .enabled = true };
    try style.sql(&out, "SELECT id, value FROM items;");
    try std.testing.expectEqualStrings("\x1b[36mSELECT\x1b[0m id, value \x1b[36mFROM\x1b[0m items;", out.buffered());
    out.end = 0;
    try style.sql(&out, "select \"FROM\", selectivity from \"items\"");
    try std.testing.expectEqualStrings("\x1b[36mselect\x1b[0m \"FROM\", selectivity \x1b[36mfrom\x1b[0m \"items\"", out.buffered());
    out.end = 0;
    try style.sql(&out, ".timing on");
    try std.testing.expectEqualStrings(".\x1b[36mtiming\x1b[0m on", out.buffered());
}

test "contextual SQL colors survive scrolling and leave dot arguments plain" {
    const value = ".read SELECT 'unterminated; /*\n.timing on\nSELECT value FROM items WHERE value IS VALUE;";
    const syntax = Syntax.init(value);
    // Editor scrolling need not start at the beginning or visit bytes in order.
    try std.testing.expectEqual(Color.word, syntax.at(std.mem.lastIndexOf(u8, value, "VALUE").?));
    try std.testing.expectEqual(Color.plain, syntax.at(std.mem.indexOf(u8, value, "value").?));
    try std.testing.expectEqual(Color.plain, syntax.at(std.mem.indexOf(u8, value, "SELECT").?));
    try std.testing.expectEqual(Color.word, syntax.at(std.mem.indexOf(u8, value, "timing").?));
    try std.testing.expectEqual(Color.plain, syntax.at(value.len));
    var buffer: [1024]u8 = undefined;
    var out: std.Io.Writer = .fixed(&buffer);
    try (Self{ .enabled = true }).sql(&out, value);
    try std.testing.expectEqualStrings(
        ".\x1b[36mread\x1b[0m SELECT 'unterminated; /*\n.\x1b[36mtiming\x1b[0m on\n\x1b[36mSELECT\x1b[0m value \x1b[36mFROM\x1b[0m items \x1b[36mWHERE\x1b[0m value \x1b[36mIS\x1b[0m \x1b[36mVALUE\x1b[0m;",
        out.buffered(),
    );
    out.end = 0;
    try (Self{}).sql(&out, value);
    try std.testing.expectEqualStrings(value, out.buffered());
}

test "SQL colors preserve incomplete Unicode and multiple statements" {
    const value = "SELECT \"café\" FROM items; SELECT value FROM items WHERE value = 'it''s; FROM";
    var buffer: [1024]u8 = undefined;
    var out: std.Io.Writer = .fixed(&buffer);
    try (Self{ .enabled = true }).sql(&out, value);
    try std.testing.expectEqualStrings(
        "\x1b[36mSELECT\x1b[0m \"café\" \x1b[36mFROM\x1b[0m items; \x1b[36mSELECT\x1b[0m value \x1b[36mFROM\x1b[0m items \x1b[36mWHERE\x1b[0m value = \x1b[32m'it''s; FROM\x1b[0m",
        out.buffered(),
    );
}

test "diagnostic colors use original context after redaction and clipping" {
    for ([_][]const u8{
        "SELECT value FROM items " ++ @as([80]u8, @splat(' ')) ++ "WHERE value IS VALUE LIMIT;",
        "SELECT value FROM items " ++ @as([80]u8, @splat(' ')) ++ "WHERE value = '99.123'::FLOAT64 LIMIT;",
    }, [_][]const u8{ "VALUE", "FLOAT64" }) |value, keyword| {
        const diagnostic = fuze.SqlDiagnostic.query(value, error.InvalidSqlSyntax, true).?;
        try std.testing.expect(std.mem.startsWith(u8, diagnostic.context[0..diagnostic.context_len], "..."));
        for (diagnostic.context[0..diagnostic.context_len], diagnostic.context_roles[0..diagnostic.context_len]) |byte, role| {
            if (byte == '*') try std.testing.expectEqual(fuze.Sql.TokenRole.unknown, role);
        }
        var buffer: [4096]u8 = undefined;
        var out: std.Io.Writer = .fixed(&buffer);
        try diagnostic.renderStyled(&out, Self{ .enabled = true });
        var token_buffer: [64]u8 = undefined;
        const colored = try std.fmt.bufPrint(&token_buffer, "\x1b[36m{s}\x1b[0m", .{keyword});
        try std.testing.expect(std.mem.indexOf(u8, out.buffered(), colored) != null);
        try std.testing.expect(std.mem.indexOf(u8, out.buffered(), "\x1b[36mvalue") == null);
        try std.testing.expect(std.mem.indexOf(u8, out.buffered(), "99.123") == null);
        var plain_buffer: [4096]u8 = undefined;
        var plain: std.Io.Writer = .fixed(&plain_buffer);
        try diagnostic.render(&plain);
        out.end = 0;
        try diagnostic.renderStyled(&out, Self{});
        try std.testing.expectEqualStrings(plain.buffered(), out.buffered());
    }
}

pub fn sql(self: Self, out: *std.Io.Writer, value: []const u8) !void {
    var syntax = Syntax.init(value);
    var active: Color = .plain;
    for (value, 0..) |byte, offset| {
        const color = syntax.at(offset);
        if (color != active) try out.writeAll(self.code(color));
        active = color;
        try out.writeByte(byte);
    }
    if (active != .plain) try out.writeAll(self.code(.plain));
}

/// Excerpt roles were captured before masking and clipping the original input.
pub fn source(self: Self, out: *std.Io.Writer, value: []const u8, roles: []const fuze.Sql.TokenRole) !void {
    var active: Color = .plain;
    for (value, roles) |byte, role| {
        const color = roleColor(role);
        if (color != active) try out.writeAll(self.code(color));
        active = color;
        try out.writeByte(byte);
    }
    if (active != .plain) try out.writeAll(self.code(.plain));
}

/// Hints are static prose: emphasize dot commands and uppercase SQL vocabulary.
pub fn hint(self: Self, out: *std.Io.Writer, value: []const u8) !void {
    var offset: usize = 0;
    while (offset < value.len) {
        const start = offset;
        const dot = value[offset] == '.' and offset + 1 < value.len and std.ascii.isAlphabetic(value[offset + 1]) and
            (offset == 0 or std.ascii.isWhitespace(value[offset - 1]));
        if (dot) offset += 1;
        while (offset < value.len and (std.ascii.isAlphanumeric(value[offset]) or value[offset] == '_')) offset += 1;
        if (offset == start) {
            try out.writeByte(value[offset]);
            offset += 1;
            continue;
        }
        const word = value[start..offset];
        const upper = word.len > 1 and std.ascii.isUpper(word[0]) and std.mem.indexOfNone(u8, word, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_") == null;
        try self.text(out, if (dot or upper) .word else .plain, word);
    }
}

pub fn write(self: Self, out: *std.Io.Writer, part: fuze.SqlDiagnostic.Part, value: []const u8) !void {
    switch (part) {
        .hint => try self.hint(out, value),
        else => try self.text(out, switch (part) {
            .summary => .emphasis,
            .category => .category,
            .cause, .marker => .failure,
            .location, .expected => .word,
            .hint => unreachable,
        }, value),
    }
}
