//! Exact frontend bodies. All byte slices borrow the bounded frame owner.
const std = @import("std");
const g = @import("root.zig").wire;
const Reader = g.Bytes;
const maximum = g.Limits.max_parameters;
pub const Format = enum(u16) { text = 0, binary = 1 };
pub const Formats = struct {
    values: [maximum]Format = undefined,
    count: u16 = 0,
    fn read(reader: *Reader) !Formats {
        var result: Formats = .{ .count = try reader.int(u16, .big) };
        if (result.count > maximum) return error.TooManyWireFormats;
        for (result.values[0..result.count]) |*value| value.* = std.enums.fromInt(Format, try reader.int(u16, .big)) orelse return error.UnsupportedWireFormat;
        return result;
    }
    pub fn validate(self: *const Formats, count: usize) !void {
        if (self.count != 0 and self.count != 1 and self.count != count) return error.WireFormatCountMismatch;
    }
    pub fn at(self: *const Formats, index: usize) Format {
        return switch (self.count) {
            0 => .text,
            1 => self.values[0],
            else => self.values[index],
        };
    }
};
pub const Parse = struct { name: []const u8, sql: []const u8, oids: [maximum]u32 = undefined, count: u16 };
pub const Bind = struct { portal: []const u8, statement: []const u8, formats: Formats, values: [maximum]?[]const u8 = undefined, count: u16, results: Formats };
pub const Target = struct { kind: enum { statement, portal }, name: []const u8 };
pub const Execute = struct { portal: []const u8, rows: u32 };
pub const Message = union(enum) { query: []const u8, parse: Parse, bind: Bind, describe: Target, close: Target, execute: Execute, sync, flush, terminate };
fn name(reader: *Reader) ![]const u8 {
    const value = try reader.cstring(g.Limits.max_name_bytes);
    if (!std.unicode.utf8ValidateSlice(value)) return error.InvalidWireText;
    return value;
}
fn text(reader: *Reader) ![]const u8 {
    const value = try reader.cstring(g.Limits.statement_bytes);
    if (!std.unicode.utf8ValidateSlice(value)) return error.InvalidWireText;
    return value;
}
fn target(reader: *Reader) !Target {
    const kind: Target = .{ .kind = switch (try reader.byte()) {
        'S' => .statement,
        'P' => .portal,
        else => return error.InvalidWireTarget,
    }, .name = try name(reader) };
    return kind;
}
pub fn decode(tag: u8, payload: []const u8) !Message {
    if (payload.len > g.Limits.max_frame_bytes - 4) return error.FrameTooLarge;
    var reader: Reader = .{ .bytes = payload };
    const result: Message = switch (tag) {
        'Q' => .{ .query = try text(&reader) },
        'P' => blk: {
            var parsed: Parse = .{ .name = try name(&reader), .sql = try text(&reader), .count = try reader.int(u16, .big) };
            if (parsed.count > maximum) return error.TooManyWireParameters;
            for (parsed.oids[0..parsed.count]) |*oid| oid.* = try reader.int(u32, .big);
            break :blk .{ .parse = parsed };
        },
        'B' => blk: {
            var bound: Bind = .{ .portal = try name(&reader), .statement = try name(&reader), .formats = try Formats.read(&reader), .count = try reader.int(u16, .big), .results = undefined };
            if (bound.count > maximum) return error.TooManyWireParameters;
            try bound.formats.validate(bound.count);
            for (bound.values[0..bound.count]) |*value| {
                const length = try reader.int(i32, .big);
                value.* = if (length == -1) null else if (length < 0) return error.InvalidWireMessage else try reader.take(@intCast(length));
            }
            bound.results = try Formats.read(&reader);
            break :blk .{ .bind = bound };
        },
        'D' => .{ .describe = try target(&reader) },
        'C' => .{ .close = try target(&reader) },
        'E' => blk: {
            const portal = try name(&reader);
            const rows = try reader.int(i32, .big);
            if (rows < 0) return error.InvalidWireMessage;
            break :blk .{ .execute = .{ .portal = portal, .rows = @intCast(rows) } };
        },
        'S' => .sync,
        'H' => .flush,
        'X' => .terminate,
        else => return error.UnsupportedWireMessage,
    };
    try reader.finish();
    return result;
}
pub fn saslInitial(payload: []const u8) ![]const u8 {
    var reader: Reader = .{ .bytes = payload };
    const mechanism = try reader.cstring(32);
    if (!std.mem.eql(u8, mechanism, "SCRAM-SHA-256")) return error.UnsupportedAuthentication;
    const count = try reader.int(i32, .big);
    if (count < 0 or count > 512) return error.InvalidAuthentication;
    const result = try reader.take(@intCast(count));
    try reader.finish();
    return result;
}
test "frontend bodies consume exactly one message and retain NULL distinctly" {
    const t = std.testing;
    const bytes = "\x00s\x00\x00\x01\x00\x01\x00\x02\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00";
    const bound = (try decode('B', bytes)).bind;
    try t.expectEqualStrings("s", bound.statement);
    try t.expectEqual(@as(?[]const u8, null), bound.values[0]);
    try t.expectEqualStrings("", bound.values[1].?);
    try t.expectEqual(Format.binary, bound.formats.at(1));
    for (0..bytes.len) |end| try t.expectError(error.InvalidWireMessage, decode('B', bytes[0..end]));
    try t.expectError(error.InvalidWireMessage, decode('S', "x"));
    try t.expectError(error.InvalidWireMessage, decode('Q', "SELECT 1\x00x"));
    try t.expectError(error.InvalidWireTarget, decode('D', "x\x00"));
    try t.expectError(error.InvalidWireMessage, decode('E', "\x00\xff\xff\xff\xff"));
    try t.expectError(error.WireFormatCountMismatch, decode('B', "\x00\x00\x00\x02\x00\x00\x00\x01\x00\x03"));
    const parsed = (try decode('P', "s\x00SELECT x FROM t WHERE x=$1\x00\x00\x01\x00\x00\x00\x15")).parse;
    try t.expectEqual(@as(u32, 21), parsed.oids[0]);
}
