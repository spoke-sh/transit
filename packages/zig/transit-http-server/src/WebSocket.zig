//! Bounded RFC 6455 mechanics. Hosts own credentials, subprotocol and lifetime.
const std = @import("std");
const root = @import("root.zig");
pub const max_message_bytes = 8192;
pub const max_fragments = 32;
pub const Opcode = enum(u8) { text = 1, close = 8, ping = 9, pong = 10 };
pub const Message = struct { opcode: Opcode, bytes: []const u8 };
pub const Decoder = struct {
    data: [max_message_bytes]u8 = undefined,
    control: [125]u8 = undefined,
    len: usize = 0,
    fragments: usize = 0,
    fragmented: bool = false,
    /// The returned slice lasts until the next read. Control frames may arrive
    /// between fragments; only a complete text message is UTF-8 validated.
    pub fn next(self: *Decoder, input: *std.Io.Reader) !Message {
        while (true) {
            const h = (try input.takeArray(2)).*;
            if (h[0] & 0x70 != 0 or h[1] & 0x80 == 0) return error.WebSocketProtocol;
            const fin = h[0] & 0x80 != 0;
            const op = h[0] & 0xf;
            const short = h[1] & 0x7f;
            const len: u64 = switch (short) {
                126 => blk: {
                    const value = try input.takeInt(u16, .big);
                    if (value < 126) return error.WebSocketProtocol;
                    break :blk value;
                },
                127 => blk: {
                    const value = try input.takeInt(u64, .big);
                    if (value <= 65535 or value >> 63 != 0) return error.WebSocketProtocol;
                    break :blk value;
                },
                else => short,
            };
            switch (op) {
                0 => if (!self.fragmented) return error.WebSocketProtocol,
                1 => if (self.fragmented) return error.WebSocketProtocol,
                2 => return error.WebSocketBinaryUnsupported,
                8, 9, 10 => if (!fin or len > 125) return error.WebSocketProtocol,
                else => return error.WebSocketProtocol,
            }
            if (len > max_message_bytes) return error.WebSocketMessageTooLarge;
            const control = op >= 8;
            if (!control) {
                if (op == 1) {
                    self.len = 0;
                    self.fragments = 0;
                }
                self.fragments += 1;
                if (self.fragments > max_fragments or len > max_message_bytes - self.len) return error.WebSocketMessageTooLarge;
            }
            const mask = (try input.takeArray(4)).*;
            const output = if (control) self.control[0..@intCast(len)] else self.data[self.len..][0..@intCast(len)];
            try input.readSliceAll(output);
            for (output, 0..) |*byte, i| byte.* ^= mask[i % 4];
            if (control) {
                if (op == 8) try validateClose(output);
                return .{ .opcode = @fromBackingInt(op), .bytes = output };
            }
            self.len += @intCast(len);
            self.fragmented = !fin;
            if (fin) {
                if (!std.unicode.utf8ValidateSlice(self.data[0..self.len])) return error.WebSocketInvalidUtf8;
                return .{ .opcode = .text, .bytes = self.data[0..self.len] };
            }
        }
    }
};
pub fn validateClose(bytes: []const u8) !void {
    if (bytes.len == 0) return;
    if (bytes.len == 1 or bytes.len > 125) return error.WebSocketProtocol;
    const code = std.mem.readInt(u16, bytes[0..2], .big);
    switch (code) {
        1000...1003, 1007...1014, 3000...4999 => {},
        else => return error.WebSocketProtocol,
    }
    if (!std.unicode.utf8ValidateSlice(bytes[2..])) return error.WebSocketInvalidUtf8;
}
fn token(list: []const u8, expected: []const u8, insensitive: bool) bool {
    var parts = std.mem.splitScalar(u8, list, ',');
    while (parts.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " \t");
        if (if (insensitive) std.ascii.eqlIgnoreCase(trimmed, expected) else std.mem.eql(u8, trimmed, expected)) return true;
    }
    return false;
}
/// Return the validated RFC nonce. No extension is negotiated. Origin/Host are
/// additional mandatory decisions at the consumer's authentication boundary.
pub fn handshake(request: *std.http.Server.Request, subprotocol: []const u8) ![]const u8 {
    try root.validateHead(request);
    if (request.head.method != .GET or request.head.content_length != null or request.head.transfer_encoding != .none) return error.WebSocketHandshake;
    if (!std.ascii.eqlIgnoreCase((try root.header(request, "upgrade")) orelse "", "websocket") or
        !token((try root.header(request, "connection")) orelse "", "upgrade", true) or
        !std.mem.eql(u8, (try root.header(request, "sec-websocket-version")) orelse "", "13") or
        !token((try root.header(request, "sec-websocket-protocol")) orelse "", subprotocol, false)) return error.WebSocketHandshake;
    _ = try root.header(request, "sec-websocket-extensions");
    const key = (try root.header(request, "sec-websocket-key")) orelse return error.WebSocketHandshake;
    if (key.len != 24) return error.WebSocketHandshake;
    var nonce: [16]u8 = undefined;
    if ((std.base64.standard.Decoder.calcSizeForSlice(key) catch return error.WebSocketHandshake) != 16) return error.WebSocketHandshake;
    std.base64.standard.Decoder.decode(&nonce, key) catch return error.WebSocketHandshake;
    var canonical: [24]u8 = undefined;
    if (!std.mem.eql(u8, key, std.base64.standard.Encoder.encode(&canonical, &nonce))) return error.WebSocketHandshake;
    return key;
}
pub fn closeCode(err: anyerror) u16 {
    return switch (err) {
        error.WebSocketInvalidUtf8 => 1007,
        error.WebSocketMessageTooLarge => 1009,
        error.WebSocketBinaryUnsupported => 1003,
        error.WebSocketProtocol => 1002,
        else => 1011,
    };
}
test "fragmented UTF-8 permits interleaved control and preserves message ownership" {
    // Independent RFC-style masks, split the three-byte euro sign across frames.
    var input: std.Io.Reader = .fixed(&.{ 0x01, 0x81, 1, 2, 3, 4, 0xe3, 0x89, 0x81, 1, 2, 3, 4, 'q', 0x80, 0x82, 1, 2, 3, 4, 0x83, 0xae });
    var decoder: Decoder = .{};
    const ping = try decoder.next(&input);
    try std.testing.expectEqual(Opcode.ping, ping.opcode);
    try std.testing.expectEqualStrings("p", ping.bytes);
    const text = try decoder.next(&input);
    try std.testing.expectEqual(Opcode.text, text.opcode);
    try std.testing.expectEqualStrings("€", text.bytes);
}
test "invalid masks RSV opcodes lengths UTF-8 and fragmented control reject" {
    const cases = [_][]const u8{
        &.{ 0x81, 0 },                   &.{ 0xc1, 0x80 }, &.{ 0x83, 0x80 },         &.{ 0x89, 0xfe, 0, 126 },
        &.{ 0x09, 0x80 },                &.{ 0x80, 0x80 }, &.{ 0x81, 0xfe, 0, 125 }, &.{ 0x81, 0x81, 0, 0, 0, 0, 0xff },
        &.{ 0x88, 0x81, 0, 0, 0, 0, 0 },
    };
    for (cases) |bytes| {
        var input: std.Io.Reader = .fixed(bytes);
        var decoder: Decoder = .{};
        if (decoder.next(&input)) |_| return error.InvalidFrameAccepted else |_| {}
    }
}
test "fragment count and accumulated message size are bounded before payload reads" {
    var bytes: [256]u8 = undefined;
    for (0..33) |i| @memcpy(bytes[i * 6 ..][0..6], &[_]u8{ if (i == 0) 0x01 else 0x00, 0x80, 0, 0, 0, 0 });
    var input: std.Io.Reader = .fixed(bytes[0 .. 33 * 6]);
    var decoder: Decoder = .{};
    try std.testing.expectError(error.WebSocketMessageTooLarge, decoder.next(&input));
    input = .fixed(&.{ 0x81, 0xfe, 0x20, 0x01 });
    decoder = .{};
    try std.testing.expectError(error.WebSocketMessageTooLarge, decoder.next(&input));
    try std.testing.expectError(error.WebSocketProtocol, validateClose(&.{ 0x03, 0xed })); // 1005 cannot appear on the wire
    try validateClose(&.{ 0x03, 0xe8 });
}
