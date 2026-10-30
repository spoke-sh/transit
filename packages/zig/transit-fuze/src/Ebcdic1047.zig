//! IBM CP1047 (z/OS UNIX System Services / Open Systems Latin-1 EBCDIC) bijective table.
//! Source: https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/EBCDIC/CP1047.TXT
const std = @import("std");
const Ebcdic037 = @import("Ebcdic037.zig");

pub const to_latin1: [256]u8 = blk: {
    var table = Ebcdic037.to_latin1;
    // CP1047 differs from CP037 by three exact transpositions on ASCII brackets/circumflex:
    // 0x5F <-> 0xB0 ('^' 0x5E <-> '¬' 0xAC)
    // 0xAD <-> 0xBA ('[' 0x5B <-> 'Ý' 0xDD)
    // 0xBB <-> 0xBD ('¨' 0xA8 <-> ']' 0x5D)
    table[0x5F] = 0x5E;
    table[0xB0] = 0xAC;
    table[0xAD] = 0x5B;
    table[0xBA] = 0xDD;
    table[0xBB] = 0xA8;
    table[0xBD] = 0x5D;
    break :blk table;
};

pub const from_latin1: [256]u8 = blk: {
    var inverse: [256]u8 = undefined;
    var seen: [256]bool = @splat(false);
    for (to_latin1, 0..) |scalar, byte| {
        if (seen[scalar]) @compileError("CP1047 mapping must be bijective");
        seen[scalar] = true;
        inverse[scalar] = @intCast(byte);
    }
    break :blk inverse;
};

pub const Iterator = struct {
    utf8: std.unicode.Utf8Iterator,
    pub fn init(bytes: []const u8) !Iterator {
        const view = try std.unicode.Utf8View.init(bytes);
        return .{ .utf8 = view.iterator() };
    }
    pub fn next(self: *Iterator) !?u8 {
        const scalar = self.utf8.nextCodepoint() orelse return null;
        if (scalar > 255) return error.UnrepresentableEbcdic1047;
        return from_latin1[@intCast(scalar)];
    }
};

pub fn validate(bytes: []const u8) !void {
    var iterator = try Iterator.init(bytes);
    while (try iterator.next()) |_| {}
}

pub fn encode(bytes: []const u8, out: []u8) ![]const u8 {
    var writer: std.Io.Writer = .fixed(out);
    var iterator = try Iterator.init(bytes);
    while (try iterator.next()) |byte| try writer.writeByte(byte);
    return writer.buffered();
}

pub fn decode(bytes: []const u8, out: []u8) ![]const u8 {
    var writer: std.Io.Writer = .fixed(out);
    for (bytes) |byte| {
        var utf8: [4]u8 = undefined;
        const length = try std.unicode.utf8Encode(to_latin1[byte], &utf8);
        try writer.writeAll(utf8[0..length]);
    }
    return writer.buffered();
}
