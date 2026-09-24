//! Source identity comes exclusively from the authenticated Transit envelope.
const std = @import("std");
const p = @import("transit_client").protocol;
const Frame = @This();
pub const version = 1;
pub const header_bytes = 13;
pub const max_payload = p.Value.max_bytes - header_bytes;
pub const Kind = enum(u8) { cast = 1, call = 2, reply = 3, result_chunk = 4, result_complete = 5, result_ack = 6, cancel = 7, timeout = 8 };
kind: Kind,
correlation: u64 = 0,
payload: p.Value = .{},

pub fn encode(self: Frame) !p.Value {
    try self.payload.validate();
    if (self.payload.len > max_payload) return error.MessageTooLarge;
    if ((self.kind == .cast) != (self.correlation == 0)) return error.InvalidCorrelation;
    var result = try p.Value.init(&@as([header_bytes]u8, @splat(0)));
    result.data[0..4].* = "STN1".*;
    result.data[4] = @backingInt(self.kind);
    std.mem.writeInt(u64, result.data[5..13], self.correlation, .little);
    @memcpy(result.data[header_bytes..][0..self.payload.len], self.payload.slice());
    result.len += self.payload.len;
    return result;
}

pub fn decode(value: p.Value) !Frame {
    try value.validate();
    if (value.len < header_bytes or !std.mem.eql(u8, value.data[0..4], "STN1")) return error.InvalidFrame;
    const kind = std.enums.fromInt(Kind, value.data[4]) orelse return error.UnsupportedFrame;
    const correlation = std.mem.readInt(u64, value.data[5..13], .little);
    if ((kind == .cast) != (correlation == 0)) return error.InvalidCorrelation;
    return .{ .kind = kind, .correlation = correlation, .payload = try p.Value.init(value.slice()[header_bytes..]) };
}

pub fn source(input: p.Input) !u64 {
    if (input.origin.version != 1) return error.UnsupportedOrigin;
    return switch (input.origin.source) {
        .process => |origin| origin.pid,
        else => error.ExpectedProcessOrigin,
    };
}

test "frames preserve full correlation width and reject ambiguous shapes" {
    const original: Frame = .{ .kind = .call, .correlation = std.math.maxInt(u64), .payload = try p.Value.init(&.{ 0, 255 }) };
    const restored = try decode(try original.encode());
    try std.testing.expectEqual(original.correlation, restored.correlation);
    try std.testing.expect(original.payload.eql(restored.payload));
    try std.testing.expectError(error.InvalidFrame, decode(try p.Value.init("STN")));
    try std.testing.expectError(error.InvalidCorrelation, (Frame{ .kind = .reply }).encode());
    try std.testing.expectError(error.MessageTooLarge, (Frame{ .kind = .cast, .payload = try p.Value.init(&@as([max_payload + 1]u8, @splat(0))) }).encode());
    var malformed = try original.encode();
    malformed.data[4] = 255;
    try std.testing.expectError(error.UnsupportedFrame, decode(malformed));
}
