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
    scan: ?input.Scan,
    token: ?input.Token = null,
    command_start: ?usize = null,

    pub fn init(value: []const u8) Syntax {
        const start = std.mem.indexOfNone(u8, value, " \t\r\n") orelse value.len;
        return .{ .scan = input.Scan.init(value) catch null, .command_start = if (start < value.len and value[start] == '.') start + 1 else null };
    }

    pub fn at(self: *Syntax, offset: usize) Color {
        if (self.scan) |*scan| while (self.token == null or self.token.?.end <= offset) {
            self.token = scan.next() catch null;
            if (self.token == null) break;
        };
        return if (self.token) |token| switch (token.kind) {
            .word => if (if (self.command_start) |start| start == token.start else fuze.Sql.isReserved(self.scan.?.text[token.start..token.end])) .word else .plain,
            .string => .literal,
            .number => .number,
            .comment => .comment,
            else => .plain,
        } else .plain;
    }
};

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
        .source => try self.sql(out, value),
        .hint => try self.hint(out, value),
        else => try self.text(out, switch (part) {
            .summary => .emphasis,
            .category => .category,
            .cause, .marker => .failure,
            .location, .expected => .word,
            .source, .hint => unreachable,
        }, value),
    }
}
