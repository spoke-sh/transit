//! Bounded borrowed wire input. Protocol owners choose byte order and grammar.
const std = @import("std");
const Self = @This();
bytes: []const u8,
offset: usize = 0,
pub fn take(self: *Self, count: usize) ![]const u8 {
    if (count > self.bytes.len - self.offset) return error.InvalidWireMessage;
    const result = self.bytes[self.offset..][0..count];
    self.offset += count;
    return result;
}
pub fn int(self: *Self, comptime T: type, endian: std.builtin.Endian) !T {
    const bytes = try self.take(@sizeOf(T));
    return std.mem.readInt(T, bytes[0..@sizeOf(T)], endian);
}
pub fn byte(self: *Self) !u8 {
    return (try self.take(1))[0];
}
pub fn cstring(self: *Self, maximum: usize) ![]const u8 {
    const remaining = self.bytes[self.offset..];
    const end = std.mem.indexOfScalar(u8, remaining, 0) orelse return error.InvalidWireMessage;
    if (end > maximum) return error.WireValueTooLarge;
    const result = try self.take(end);
    _ = try self.byte();
    return result;
}
pub fn finish(self: Self) !void {
    if (self.offset != self.bytes.len) return error.InvalidWireMessage;
}
pub fn appendInt(out: *std.ArrayList(u8), allocator: std.mem.Allocator, comptime T: type, value: T, endian: std.builtin.Endian) !void {
    var encoded: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &encoded, value, endian);
    try out.appendSlice(allocator, &encoded);
}
