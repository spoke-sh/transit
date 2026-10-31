//! Classic packet framing. Sequence belongs to one command/authentication
//! exchange. SQL requests fit below the protocol's continuation-packet size.
const std = @import("std");
const limits = @import("root.zig").wire.Limits;
pub const Message = struct { sequence: u8, payload: []const u8, consumed: usize };
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
