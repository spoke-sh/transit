//! Stream coordinates survive buffer reuse without retaining SQL or paths borrowed
//! from a short-lived input arena. Byte coordinates include skipped whitespace.
const std = @import("std");
const d = @import("transit_query").protocol.Diagnostic;
const Self = @This();
pub const Cursor = struct {
    offset: u64 = 0,
    line: u64 = 1,
    column: u64 = 1,
    pub fn advance(self: *Cursor, byte: u8) void {
        self.offset += 1;
        if (byte == '\n') {
            self.line += 1;
            self.column = 1;
        } else self.column += 1;
    }
};
source: d.Path,
source_truncated: bool,
start: Cursor = .{},
statement: u64 = 1,
completed: u64 = 0,
sql: bool = true,

pub fn init(source: []const u8) !Self {
    const path = try d.Path.truncate(source);
    return .{ .source = path, .source_truncated = path.slice().len != source.len };
}
pub fn absolute(self: Self, location: d.Location) !d.Location {
    var result = location;
    result.source = self.source;
    result.source_truncated = self.source_truncated;
    result.statement = .init(self.statement);
    result.offset = .init(try std.math.add(u64, self.start.offset, try location.offset.value()));
    const line = try location.line.value();
    result.line = .init(try std.math.add(u64, self.start.line - 1, line));
    if (line == 1) result.byte_column = .init(try std.math.add(u64, self.start.column - 1, try location.byte_column.value()));
    return result;
}
pub fn enrich(self: Self, value: *d) !void {
    if (self.sql) {
        if (value.location) |location| value.location = try self.absolute(location);
        for (&value.facts) |*slot| if (slot.*) |*fact| {
            if (fact.field == .parameter_use and fact.value != null and fact.value.? == .unsigned) {
                fact.value.?.unsigned = .init(try std.math.add(u64, self.start.offset, try fact.value.?.unsigned.value()));
            }
        };
    }
    try value.fact(.completed_statements, .execution, .{ .unsigned = .init(self.completed) });
}
pub fn render(self: Self, out: *std.Io.Writer) !void {
    try out.writeAll("Input: \"");
    for (self.source.slice()) |byte| switch (byte) {
        '"', '\\' => {
            try out.writeByte('\\');
            try out.writeByte(byte);
        },
        0x20...0x21, 0x23...0x5b, 0x5d...0x7e => try out.writeByte(byte),
        else => try out.print("\\x{x:0>2}", .{byte}),
    };
    try out.print("\"{s}; statement {d} starts at byte {d}, line {d}, byte column {d}.\nPreviously completed commands: {d}; their effects are not rolled back by this failure.\n", .{ if (self.source_truncated) " [truncated]" else "", self.statement, self.start.offset, self.start.line, self.start.column, self.completed });
}

test "absolute SQL coordinates include skipped comments, CRLF and UTF-8 bytes" {
    var cursor: Cursor = .{};
    for ("-- 東京\r\n.show\r\n  ") |byte| cursor.advance(byte);
    var input = try init("script.sql");
    input.start = cursor;
    input.statement = 2;
    input.completed = 1;
    const first = try input.absolute(.{ .offset = .init(7), .length = .init(0), .line = .init(1), .byte_column = .init(8) });
    try std.testing.expectEqual(@as(u64, 3), try first.line.value());
    try std.testing.expectEqual(@as(u64, 10), try first.byte_column.value());
    const next = try input.absolute(.{ .offset = .init(9), .length = .init(0), .line = .init(2), .byte_column = .init(2) });
    try std.testing.expectEqual(@as(u64, 4), try next.line.value());
    try std.testing.expectEqual(@as(u64, 2), try next.byte_column.value());
}
