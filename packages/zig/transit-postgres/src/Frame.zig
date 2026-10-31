//! PostgreSQL v3 framing, independent of SQL and transport ownership.
const std = @import("std");
const limits = @import("root.zig").wire.Limits;
pub const ssl_request = 80877103;
pub const gss_request = 80877104;
pub const cancel_request = 80877102;
pub const Message = struct { tag: u8, payload: []const u8, consumed: usize };
pub const Startup = struct { code: u32, payload: []const u8, consumed: usize };
pub const Input = @import("root.zig").wire.Input(struct {
    pub const prefix_bytes = 5;
    maximum: u32,
    pub fn capacity(self: @This()) !usize {
        if (self.maximum < 4 or self.maximum > limits.max_frame_bytes) return error.InvalidFrameBudget;
        return @as(usize, self.maximum) + 1;
    }
    pub fn frameSize(self: @This(), prefix: *const [prefix_bytes]u8) !usize {
        return @import("Frame.zig").frameSize(prefix, self.maximum);
    }
});
fn length(bytes: *const [4]u8, maximum: u32, minimum: u32) !u32 {
    if (maximum > limits.max_frame_bytes or maximum < minimum) return error.InvalidFrameBudget;
    const n = std.mem.readInt(u32, bytes, .big);
    if (n < minimum or n > std.math.maxInt(i32)) return error.InvalidMessageLength;
    if (n > maximum) return error.FrameTooLarge;
    return n;
}
pub fn startup(bytes: []const u8, maximum: u32) !?Startup {
    if (bytes.len < 4) return null;
    const n = try length(bytes[0..4], maximum, 8);
    if (bytes.len < n) return null;
    const code = std.mem.readInt(u32, bytes[4..8], .big);
    if ((code == ssl_request or code == gss_request) and n != 8) return error.InvalidUpgradeRequest;
    if (code == cancel_request and n != 16) return error.InvalidCancelRequest;
    return .{ .code = code, .payload = bytes[8..n], .consumed = n };
}
pub fn frameSize(prefix: *const [5]u8, maximum: u32) !usize {
    return @as(usize, try length(prefix[1..5], maximum, 4)) + 1;
}
pub fn decode(bytes: []const u8, maximum: u32) !?Message {
    if (bytes.len < 5) return null;
    const total = try frameSize(bytes[0..5], maximum);
    if (bytes.len < total) return null;
    return .{ .tag = bytes[0], .payload = bytes[5..total], .consumed = total };
}
pub fn header(tag: u8, payload_bytes: usize, maximum: u32) ![5]u8 {
    if (maximum < 4 or maximum > limits.max_frame_bytes or payload_bytes > maximum - 4) return error.FrameTooLarge;
    var out: [5]u8 = undefined;
    out[0] = tag;
    std.mem.writeInt(u32, out[1..5], @intCast(payload_bytes + 4), .big);
    return out;
}
test "PostgreSQL frame prefixes, coalescing and signed lengths" {
    const t = std.testing;
    // Python struct.pack('!cI', b'Q', 13) + b'SELECT 1\0'.
    const bytes = "Q\x00\x00\x00\x0dSELECT 1\x00S\x00\x00\x00\x04";
    for (0..14) |i| try t.expectEqual(@as(?Message, null), try decode(bytes[0..i], 4096));
    const first = (try decode(bytes, 4096)).?;
    try t.expectEqualStrings("SELECT 1\x00", first.payload);
    try t.expectEqual(@as(usize, 14), first.consumed);
    try t.expectEqual(@as(u8, 'S'), (try decode(bytes[first.consumed..], 4096)).?.tag);
    try t.expectError(error.InvalidMessageLength, decode("Q\xff\xff\xff\xff", 4096));
    try t.expectError(error.InvalidMessageLength, decode("Q\x00\x00\x00\x03", 4096));
    try t.expectError(error.FrameTooLarge, decode("Q\x00\x01\x00\x00", 4096));
    const upgrade = "\x00\x00\x00\x08\x04\xd2\x16\x2f";
    try t.expectEqual(@as(u32, ssl_request), (try startup(upgrade, 4096)).?.code);
    try t.expectError(error.InvalidUpgradeRequest, startup("\x00\x00\x00\x09\x04\xd2\x16\x2fx", 4096));
}

test "incremental PostgreSQL input preserves every split and stops at frame ownership" {
    const t = std.testing;
    const bytes = "Q\x00\x00\x00\x0dSELECT 1\x00S\x00\x00\x00\x04";
    for (0..15) |split| {
        var storage: [33]u8 = undefined;
        var input = try Input.init(&storage, .{ .maximum = 32 });
        try t.expectEqual(split, try input.feed(bytes[0..split]));
        if (split < 14) try t.expect((try input.next()) == .input);
        try t.expectEqual(14 - split, try input.feed(bytes[split..]));
        const frame = (try input.next()).frame;
        try t.expectEqualStrings(bytes[0..14], frame);
        try t.expectEqual(@as(usize, 0), try input.feed(bytes[14..]));
        try input.release();
        try t.expect(std.mem.allEqual(u8, storage[0..14], 0));
        try t.expectEqual(@as(usize, 5), try input.feed(bytes[14..]));
        try t.expectEqualStrings(bytes[14..], (try input.next()).frame);
    }
}

test "incremental PostgreSQL input requests bounded growth only after a valid header" {
    const t = std.testing;
    var prefix: [5]u8 = undefined;
    var input = try Input.init(&prefix, .{ .maximum = 32 });
    try t.expectEqual(@as(usize, 5), try input.feed("Q\x00\x00\x00\x0dSELECT 1\x00"));
    try t.expectEqual(@as(usize, 14), (try input.next()).capacity);
    try t.expectError(error.FrameIncomplete, input.release());
    var storage: [14]u8 = undefined;
    @memcpy(storage[0..5], &prefix);
    try input.supply(&storage);
    try t.expectEqual(@as(usize, 9), try input.feed("SELECT 1\x00"));
    try t.expectEqualStrings("SELECT 1\x00", (try decode((try input.next()).frame, 32)).?.payload);
    try input.release();
    try t.expectError(error.FrameTooLarge, input.feed("Q\x00\x00\x00\x21"));
    try t.expectError(error.FrameInputClosed, input.next());
    try t.expectError(error.FrameInputClosed, input.release());
}

test "incremental PostgreSQL input cannot turn truncation or invalid advancement into a command" {
    const t = std.testing;
    var storage: [33]u8 = undefined;
    var input = try Input.init(&storage, .{ .maximum = 32 });
    _ = try input.feed("Q\x00\x00\x00\x0dSELECT");
    try t.expectError(error.FrameIncomplete, input.release());
    input.abort();
    try t.expectError(error.FrameInputClosed, input.next());
    input = try Input.init(&storage, .{ .maximum = 32 });
    try t.expectError(error.InvalidFrameAdvance, input.advance(6));
    try t.expectError(error.FrameInputClosed, input.next());
    try t.expectError(error.InvalidFrameCapacity, Input.init(storage[0..4], .{ .maximum = 32 }));
    try t.expectError(error.InvalidFrameBudget, Input.init(&storage, .{ .maximum = 3 }));
}
