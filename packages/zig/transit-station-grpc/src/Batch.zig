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
    return validateDiagnostic(items, shape, limits, null);
}
pub fn validateDiagnostic(items: []const []const u8, shape: rpc.Shape, limits: rpc.transport.Limits, context: ?*?rpc.Service.Rejection) !void {
    var detail: ?rpc.transport.Validation = null;
    (rpc.transport.Request{ .method = "/scope.Service/Method", .shape = shape, .messages = items }).validateDiagnostic(limits, &detail) catch |err| return rpc.Request.transportFailure(context, detail, .invalid_request, err);
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
    return decodeDiagnostic(bytes, shape, limits, null);
}
fn reject(context: ?*?rpc.Service.Rejection, check: rpc.exchange.AdmissionRejection.Check, field: []const u8, expected: rpc.exchange.AdmissionRejection.Scalar, actual: rpc.exchange.AdmissionRejection.Scalar) anyerror {
    if (context) |slot| if (slot.* == null) {
        slot.* = rpc.Service.Rejection.detail(.invalid_request, check, field, expected, actual, error.InvalidGrpcBatch);
    };
    return error.InvalidGrpcBatch;
}
pub fn decodeDiagnostic(bytes: []const u8, shape: rpc.Shape, limits: rpc.transport.Limits, context: ?*?rpc.Service.Rejection) !Self {
    if (bytes.len < 8) return reject(context, .policy, "request.batch.bytes", .{ .text = "at least 8 bytes" }, .{ .unsigned = bytes.len });
    if (bytes.len > maximum_bytes) return reject(context, .maximum, "request.batch.bytes", .{ .unsigned = maximum_bytes }, .{ .unsigned = bytes.len });
    if (!std.mem.eql(u8, bytes[0..4], "GRB1")) return reject(context, .equal, "request.batch.magic", .{ .text = "GRB1" }, .redacted);
    var result: Self = .{ .count = std.mem.readInt(u32, bytes[4..8], .little) };
    if (result.count > result.items.len) return reject(context, .maximum, "request.batch.count", .{ .unsigned = result.items.len }, .{ .unsigned = result.count });
    var offset: usize = 8;
    for (result.items[0..result.count], 0..) |*item, index| {
        var path_bytes: [64]u8 = undefined;
        if (bytes.len - offset < 4) return reject(context, .policy, try std.fmt.bufPrint(&path_bytes, "request.batch[{d}].length", .{index}), .{ .text = "4-byte length prefix" }, .{ .unsigned = bytes.len - offset });
        const len = std.mem.readInt(u32, bytes[offset..][0..4], .little);
        offset += 4;
        if (len > bytes.len - offset) return reject(context, .equal, try std.fmt.bufPrint(&path_bytes, "request.batch[{d}].bytes", .{index}), .{ .unsigned = len }, .{ .unsigned = bytes.len - offset });
        item.* = bytes[offset..][0..len];
        offset += len;
        result.wire_bytes += len + 5;
    }
    if (offset != bytes.len) return reject(context, .equal, "request.batch.trailing_bytes", .{ .unsigned = 0 }, .{ .unsigned = bytes.len - offset });
    try validateDiagnostic(result.messages(), shape, limits, context);
    return result;
}
