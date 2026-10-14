//! PostgreSQL v3 framing, independent of SQL and transport ownership.
const std = @import("std");
const limits = @import("root.zig").gateway.Limits;
pub const ssl_request = 80877103;
pub const gss_request = 80877104;
pub const cancel_request = 80877102;
pub const Message = struct { tag: u8, payload: []const u8, consumed: usize };
pub const Startup = struct { code: u32, payload: []const u8, consumed: usize };
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
pub fn decode(bytes: []const u8, maximum: u32) !?Message {
    if (bytes.len < 5) return null;
    const n = try length(bytes[1..5], maximum, 4);
    const total: usize = @as(usize, n) + 1;
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
pub const Owned = struct {
    allocator: std.mem.Allocator,
    tag: u8,
    payload: []u8,
    pub fn deinit(self: *Owned) void {
        self.allocator.free(self.payload);
        self.* = undefined;
    }
};
pub fn read(allocator: std.mem.Allocator, transport: anytype, maximum: u32) !Owned {
    var prefix: [5]u8 = undefined;
    try transport.readExact(&prefix);
    const n = try length(prefix[1..5], maximum, 4);
    const payload = try allocator.alloc(u8, n - 4);
    errdefer allocator.free(payload);
    try transport.readExact(payload);
    return .{ .allocator = allocator, .tag = prefix[0], .payload = payload };
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
