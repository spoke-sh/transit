//! GRB1 preserves original protobuf bytes, including empty messages.
const std = @import("std");
const rpc = @import("root.zig");
const Self = @This();
pub const maximum_bytes = 65544;
items: [64][]const u8 = undefined,
count: usize = 0,
wire_bytes: u32 = 0,
pub fn messages(self: *const Self) []const []const u8 {
    return self.items[0..self.count];
}
pub fn validate(items: []const []const u8, shape: rpc.Shape, limits: rpc.transport.Limits) !void {
    try (rpc.transport.Request{ .method = "/scope.Service/Method", .shape = shape, .messages = items }).validate(limits);
}
pub fn encode(items: []const []const u8, shape: rpc.Shape, limits: rpc.transport.Limits, buffer: []u8) ![]const u8 {
    try validate(items, shape, limits);
    var out: std.Io.Writer = .fixed(buffer);
    try out.writeAll("GRB1");
    try out.writeInt(u32, @intCast(items.len), .little);
    for (items) |message| {
        try out.writeInt(u32, @intCast(message.len), .little);
        try out.writeAll(message);
    }
    return out.buffered();
}
/// Returned slices borrow the immutable input; no schema decoding or allocation.
pub fn decode(bytes: []const u8, shape: rpc.Shape, limits: rpc.transport.Limits) !Self {
    if (bytes.len < 8 or bytes.len > maximum_bytes or !std.mem.eql(u8, bytes[0..4], "GRB1")) return error.InvalidGrpcBatch;
    var result: Self = .{ .count = std.mem.readInt(u32, bytes[4..8], .little) };
    if (result.count > result.items.len) return error.InvalidGrpcBatch;
    var offset: usize = 8;
    for (result.items[0..result.count]) |*item| {
        if (bytes.len - offset < 4) return error.InvalidGrpcBatch;
        const len = std.mem.readInt(u32, bytes[offset..][0..4], .little);
        offset += 4;
        if (len > bytes.len - offset) return error.InvalidGrpcBatch;
        item.* = bytes[offset..][0..len];
        offset += len;
        result.wire_bytes += len + 5;
    }
    if (offset != bytes.len) return error.InvalidGrpcBatch;
    try validate(result.messages(), shape, limits);
    return result;
}
