const std = @import("std");
const pg = @import("transit_postgres");
const mysql = @import("transit_mysql");
const memory = @import("transit_memory");
const Reader = @import("FrameInput.zig").Reader;
const Peer = struct {
    bytes: []const u8,
    offset: usize = 0,
    calls: usize = 0,
    pub fn readExact(self: *@This(), into: []u8) !void {
        self.calls += 1;
        const count = @min(into.len, self.bytes.len - self.offset);
        @memcpy(into[0..count], self.bytes[self.offset..][0..count]);
        self.offset += count;
        if (count != into.len) return error.EndOfStream;
    }
};
fn largeFrame() [9005]u8 {
    var frame: [9005]u8 = @splat('x');
    @memcpy(frame[0..5], "Q\x00\x00\x23\x2c"); // 9004, including the length word.
    return frame;
}
test "connection input grows once then reuses capacity with zero allocator calls" {
    const t = std.testing;
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var reader = try Reader(pg.Frame.Input).init(probe.allocator(), .{ .maximum = 10000 });
    defer reader.deinit();
    const large = largeFrame();
    var peer: Peer = .{ .bytes = &large };
    try t.expectEqualStrings(&large, try reader.read(&peer));
    try t.expectEqual(@as(usize, large.len), reader.bytes.len);
    try t.expectError(error.FrameStillBorrowed, reader.read(&peer));
    reader.release();
    probe.begin(true);
    for (0..100) |i| {
        peer = .{ .bytes = if (i % 2 == 0) &large else "S\x00\x00\x00\x04" };
        const frame = try reader.read(&peer);
        try t.expectEqualStrings(peer.bytes, frame);
        reader.release();
        try t.expect(std.mem.allEqual(u8, reader.bytes[0..peer.bytes.len], 0));
    }
    try probe.verify();
}
test "invalid sequence and oversized headers never read or reserve a body" {
    const t = std.testing;
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var reader = try Reader(mysql.Frame.Input).init(probe.allocator(), .{ .maximum = 10000, .expected = 0 });
    defer reader.deinit();
    probe.begin(true);
    var peer: Peer = .{ .bytes = "\xff\xff\xff\x00must not be read" };
    try t.expectError(error.FrameTooLarge, reader.read(&peer));
    try t.expectEqual(@as(usize, 4), peer.offset);
    try t.expectEqual(@as(usize, 1), peer.calls);
    try t.expectError(error.FrameInputClosed, reader.read(&peer));
    try probe.verify();
}
test "EOF after a partial body poisons the input and never becomes completion" {
    const t = std.testing;
    var reader = try Reader(pg.Frame.Input).init(t.allocator, .{ .maximum = 10000 });
    defer reader.deinit();
    var peer: Peer = .{ .bytes = "Q\x00\x00\x00\x0dSECRET" };
    try t.expectError(error.EndOfStream, reader.read(&peer));
    try t.expectError(error.FrameInputClosed, reader.read(&peer));
    try t.expect(!reader.borrowed);
}
fn allocationFailure(allocator: std.mem.Allocator) !void {
    var reader = try Reader(pg.Frame.Input).init(allocator, .{ .maximum = 10000 });
    defer reader.deinit();
    const large = largeFrame();
    var peer: Peer = .{ .bytes = &large };
    _ = try reader.read(&peer);
    reader.release();
}
test "frame growth allocation failures release the connection reservation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationFailure, .{});
}
