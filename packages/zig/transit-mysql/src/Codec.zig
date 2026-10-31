//! MySQL length-encoded primitives. SQL NULL belongs to row/parameter framing.
const std = @import("std");
const g = @import("root.zig").wire;
pub const Reader = g.Bytes;
pub fn length(reader: *Reader) !u64 {
    return switch (try reader.byte()) {
        0...250 => |n| n,
        252 => try reader.int(u16, .little),
        253 => blk: {
            const bytes = try reader.take(3);
            break :blk @as(u64, bytes[0]) | (@as(u64, bytes[1]) << 8) | (@as(u64, bytes[2]) << 16);
        },
        254 => try reader.int(u64, .little),
        else => error.InvalidWireLength,
    };
}
pub fn string(reader: *Reader, maximum: usize) ![]const u8 {
    const count = try length(reader);
    if (count > maximum) return error.WireValueTooLarge;
    return reader.take(@intCast(count));
}
pub fn appendLength(allocator: std.mem.Allocator, out: *std.ArrayList(u8), n: u64) !void {
    if (n < 251) return out.append(allocator, @intCast(n));
    if (n <= 0xffff) {
        try out.append(allocator, 252);
        return Reader.appendInt(out, allocator, u16, @intCast(n), .little);
    }
    if (n <= 0xffffff) {
        try out.append(allocator, 253);
        try out.appendSlice(allocator, &.{ @truncate(n), @truncate(n >> 8), @truncate(n >> 16) });
        return;
    }
    try out.append(allocator, 254);
    return Reader.appendInt(out, allocator, u64, n, .little);
}
pub fn appendString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), bytes: []const u8) !void {
    if (bytes.len > g.Limits.max_frame_bytes) return error.WireValueTooLarge;
    try appendLength(allocator, out, bytes.len);
    try out.appendSlice(allocator, bytes);
}
test "independent length-encoded integer vectors and reserved markers" {
    const t = std.testing;
    const cases = .{ .{ @as(u64, 250), "\xfa" }, .{ @as(u64, 251), "\xfc\xfb\x00" }, .{ @as(u64, 65536), "\xfd\x00\x00\x01" }, .{ std.math.maxInt(u64), "\xfe\xff\xff\xff\xff\xff\xff\xff\xff" } };
    inline for (cases) |item| {
        var reader: Reader = .{ .bytes = item[1] };
        try t.expectEqual(item[0], try length(&reader));
        try reader.finish();
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(t.allocator);
        try appendLength(t.allocator, &encoded, item[0]);
        try t.expectEqualSlices(u8, item[1], encoded.items);
    }
    var reserved: Reader = .{ .bytes = "\xfb" };
    try t.expectError(error.InvalidWireLength, length(&reserved));
    var oversize: Reader = .{ .bytes = "\xfe\xff\xff\xff\xff\xff\xff\xff\xff" };
    try t.expectError(error.WireValueTooLarge, string(&oversize, 4096));
}
