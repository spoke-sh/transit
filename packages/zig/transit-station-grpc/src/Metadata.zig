//! Ordered HPACK field observations. Values retain their original wire spelling;
//! binary metadata stays base64 here, independent of any application decoder.
const std = @import("std");
const rpc = @import("root.zig");
pub const maximum_bytes = 8192;
pub const Block = struct {
    fields: [64]rpc.transport.Field = undefined,
    count: usize = 0,
    status: ?u32 = null,
    pub fn entries(self: *const Block) []const rpc.transport.Field {
        return self.fields[0..self.count];
    }
};
pub const Captured = struct { bytes: []const u8, omitted: u32 };
pub fn required(name: []const u8) bool {
    for ([_][]const u8{ ":status", "content-type", "grpc-status", "grpc-encoding" }) |key| if (std.mem.eql(u8, key, name)) return true;
    return false;
}
fn validateField(field: rpc.transport.Field) !void {
    if (field.name.len == 0 or field.name.len > maximum_bytes or field.value.len > maximum_bytes) return error.InvalidGrpcMetadata;
    if (!std.mem.eql(u8, field.name, ":status")) for (field.name) |byte| if (!(byte >= 'a' and byte <= 'z') and !std.ascii.isDigit(byte) and byte != '_' and byte != '-' and byte != '.') return error.InvalidGrpcMetadata;
    for (field.value) |byte| if (byte < 32 or byte > 126) return error.InvalidGrpcMetadata;
    if (std.mem.endsWith(u8, field.name, "-bin")) {
        var items = std.mem.splitScalar(u8, field.value, ',');
        var decoded: [maximum_bytes]u8 = undefined;
        while (items.next()) |item| {
            const value = std.mem.trim(u8, item, " ");
            const decoder = if (std.mem.endsWith(u8, value, "=")) std.base64.standard.Decoder else std.base64.standard_no_pad.Decoder;
            const len = decoder.calcSizeForSlice(value) catch return error.InvalidGrpcMetadata;
            decoder.decode(decoded[0..len], value) catch return error.InvalidGrpcMetadata;
        }
    }
}
/// Validate the whole incoming block before filtering. Secret-bearing fields
/// must remain off the explicit allowlist; omitted fields are counted, not saved.
pub fn capture(fields: []const rpc.transport.Field, allowlist: []const []const u8, trailers: bool, buffer: []u8) !Captured {
    if (fields.len > 64 or allowlist.len > 64) return error.GrpcBudgetExceeded;
    var kept: [64]rpc.transport.Field = undefined;
    var count: usize = 0;
    var total: usize = 8;
    for (fields) |field| {
        try validateField(field);
        total += 6 + field.name.len + field.value.len;
        if (total > maximum_bytes) return error.GrpcBudgetExceeded;
        const keep = required(field.name) or for (allowlist) |name| {
            if (std.mem.eql(u8, name, field.name)) break true;
        } else false;
        if (keep) {
            kept[count] = field;
            count += 1;
        }
    }
    var out: std.Io.Writer = .fixed(buffer[0..@min(buffer.len, maximum_bytes)]);
    try out.writeAll("GRH1");
    try out.writeInt(u32, @intCast(count), .little);
    for (kept[0..count]) |field| {
        try out.writeInt(u16, @intCast(field.name.len), .little);
        try out.writeInt(u32, @intCast(field.value.len), .little);
        try out.writeAll(field.name);
        try out.writeAll(field.value);
    }
    _ = try decode(out.buffered(), trailers);
    return .{ .bytes = out.buffered(), .omitted = @intCast(fields.len - count) };
}
/// The result borrows exact bytes. This verifies protocol metadata, not peer
/// honesty, HTTP/2 END_STREAM, authority or Exchange coverage.
pub fn decode(bytes: []const u8, trailers: bool) !Block {
    if (bytes.len < 8 or bytes.len > maximum_bytes or !std.mem.eql(u8, bytes[0..4], "GRH1")) return error.InvalidGrpcMetadata;
    var result: Block = .{ .count = std.mem.readInt(u32, bytes[4..8], .little) };
    if (result.count > result.fields.len) return error.InvalidGrpcMetadata;
    var offset: usize = 8;
    var saw_status = false;
    var content_type = false;
    var encoding = false;
    var message = false;
    for (result.fields[0..result.count], 0..) |*field, index| {
        if (bytes.len - offset < 6) return error.InvalidGrpcMetadata;
        const key_len = std.mem.readInt(u16, bytes[offset..][0..2], .little);
        const value_len = std.mem.readInt(u32, bytes[offset + 2 ..][0..4], .little);
        offset += 6;
        if (@as(u64, key_len) + value_len > bytes.len - offset) return error.InvalidGrpcMetadata;
        field.* = .{ .name = bytes[offset..][0..key_len], .value = bytes[offset + key_len ..][0..value_len] };
        offset += key_len + value_len;
        try validateField(field.*);
        if (std.mem.eql(u8, field.name, ":status")) {
            if (trailers or index != 0 or saw_status or !std.mem.eql(u8, field.value, "200")) return error.InvalidGrpcMetadata;
            saw_status = true;
        } else if (std.mem.eql(u8, field.name, "content-type")) {
            if (content_type or trailers or !(std.mem.eql(u8, field.value, "application/grpc") or std.mem.startsWith(u8, field.value, "application/grpc+"))) return error.InvalidGrpcMetadata;
            content_type = true;
        } else if (std.mem.eql(u8, field.name, "grpc-encoding")) {
            if (encoding or trailers or !std.mem.eql(u8, field.value, "identity")) return error.InvalidGrpcMetadata;
            encoding = true;
        } else if (std.mem.eql(u8, field.name, "grpc-status")) {
            if (result.status != null or field.value.len == 0 or field.value.len > 2) return error.InvalidGrpcMetadata;
            for (field.value) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidGrpcMetadata;
            const status = try std.fmt.parseInt(u32, field.value, 10);
            if (status > 16) return error.InvalidGrpcMetadata;
            result.status = status;
        } else if (std.mem.eql(u8, field.name, "grpc-message")) {
            if (message) return error.InvalidGrpcMetadata;
            message = true;
        }
    }
    if (offset != bytes.len or (!trailers and (!saw_status or !content_type)) or (trailers and result.status == null)) return error.InvalidGrpcMetadata;
    return result;
}
