//! Classic packet framing. Sequence belongs to one command/authentication
//! exchange. SQL requests fit below the protocol's continuation-packet size.
const std = @import("std");
const limits = @import("root.zig").wire.Limits;
pub const Message = struct { sequence: u8, payload: []const u8, consumed: usize };
pub const Input = @import("root.zig").wire.Input(struct {
    pub const prefix_bytes = 4;
    expected: u8,
    maximum: u32,
    pub fn capacity(self: @This()) !usize {
        if (self.maximum == 0 or self.maximum > limits.max_frame_bytes) return error.InvalidFrameBudget;
        return @as(usize, self.maximum) + 4;
    }
    pub fn frameSize(self: @This(), prefix: *const [prefix_bytes]u8) !usize {
        return @import("Frame.zig").frameSize(prefix, self.expected, self.maximum);
    }
});
fn length(prefix: *const [4]u8, expected: u8, maximum: u32) !u32 {
    if (maximum == 0 or maximum > limits.max_frame_bytes) return error.InvalidFrameBudget;
    if (prefix[3] != expected) return error.PacketSequenceMismatch;
    const n = std.mem.readInt(u24, prefix[0..3], .little);
    // 0xffffff requires continuation; it already exceeds this bounded profile.
    // Reject at its header without allocating or consuming an oversized body.
    if (n > maximum) return error.FrameTooLarge;
    return n;
}
pub fn frameSize(prefix: *const [4]u8, expected: u8, maximum: u32) !usize {
    return @as(usize, try length(prefix, expected, maximum)) + 4;
}
pub fn decode(bytes: []const u8, expected: u8, maximum: u32) !?Message {
    if (bytes.len < 4) return null;
    const total = try frameSize(bytes[0..4], expected, maximum);
    if (bytes.len < total) return null;
    return .{ .sequence = expected, .payload = bytes[4..total], .consumed = total };
}
pub fn header(sequence: u8, payload_bytes: usize, maximum: u32) ![4]u8 {
    if (maximum == 0 or maximum > limits.max_frame_bytes or payload_bytes > maximum) return error.FrameTooLarge;
    var out: [4]u8 = undefined;
    std.mem.writeInt(u24, out[0..3], @intCast(payload_bytes), .little);
    out[3] = sequence;
    return out;
}
test "MySQL fragmentation, sequence and continuation bounds precede allocation" {
    const t = std.testing;
    const bytes = "\x09\x00\x00\x00\x03SELECT 1\x01\x00\x00\x00\x0e";
    for (0..13) |i| try t.expectEqual(@as(?Message, null), try decode(bytes[0..i], 0, 4096));
    const first = (try decode(bytes, 0, 4096)).?;
    try t.expectEqualStrings("\x03SELECT 1", first.payload);
    try t.expectEqual(@as(usize, 13), first.consumed);
    try t.expectEqualStrings("\x0e", (try decode(bytes[first.consumed..], 0, 4096)).?.payload);
    try t.expectError(error.PacketSequenceMismatch, decode(bytes, 1, 4096));
    try t.expectError(error.FrameTooLarge, decode("\xff\xff\xff\x00", 0, limits.max_frame_bytes));
    try t.expectEqual(@as(u8, 255), (try decode("\x00\x00\x00\xff", 255, 4096)).?.sequence);
    try t.expectEqualSlices(u8, bytes[0..4], &(try header(0, 9, 4096)));
}

test "incremental MySQL input preserves every split coalesced packet and empty packet" {
    const t = std.testing;
    const bytes = "\x09\x00\x00\x00\x03SELECT 1\x00\x00\x00\x00";
    for (0..14) |split| {
        var storage: [36]u8 = undefined;
        var input = try Input.init(&storage, .{ .maximum = 32, .expected = 0 });
        try t.expectEqual(split, try input.feed(bytes[0..split]));
        if (split < 13) try t.expect((try input.next()) == .input);
        try t.expectEqual(13 - split, try input.feed(bytes[split..]));
        try t.expectEqualStrings(bytes[0..13], (try input.next()).frame);
        try t.expectEqual(@as(usize, 0), try input.feed(bytes[13..]));
        try input.release();
        try t.expect(std.mem.allEqual(u8, storage[0..13], 0));
        try t.expectEqual(@as(usize, 4), try input.feed(bytes[13..]));
        try t.expectEqualStrings("", (try decode((try input.next()).frame, 0, 32)).?.payload);
    }
}

test "incremental MySQL input fences sequence and continuation before body capacity" {
    const t = std.testing;
    var prefix: [4]u8 = undefined;
    var input = try Input.init(&prefix, .{ .maximum = 32, .expected = 255 });
    try t.expectError(error.PacketSequenceMismatch, input.feed("\x09\x00\x00\x00"));
    try t.expectError(error.FrameInputClosed, input.next());
    input = try Input.init(&prefix, .{ .maximum = 32, .expected = 0 });
    try t.expectError(error.FrameTooLarge, input.feed("\xff\xff\xff\x00"));
    try t.expectError(error.FrameInputClosed, input.next());
    input = try Input.init(&prefix, .{ .maximum = 32, .expected = 0 });
    _ = try input.feed("\x09\x00\x00\x00");
    try t.expectEqual(@as(usize, 13), (try input.next()).capacity);
    try t.expectError(error.InvalidFrameCapacity, input.supply(&prefix));
    var storage: [13]u8 = undefined;
    @memcpy(storage[0..4], &prefix);
    try input.supply(&storage);
    _ = try input.feed("\x03SELECT 1");
    try t.expectEqualStrings("\x03SELECT 1", (try decode((try input.next()).frame, 0, 32)).?.payload);
}
