//! Grow with the received body, never beyond its explicit wire budget.
const std = @import("std");
const Self = @This();
allocator: std.mem.Allocator,
limit: usize,
writer: std.Io.Writer = .{ .buffer = &.{}, .vtable = &.{ .drain = drain, .rebase = rebase, .flush = flush } },
allocation_failed: bool = false,

pub fn deinit(self: *Self) void {
    self.allocator.free(self.writer.buffer);
}
fn grow(self: *Self, extra: usize) std.Io.Writer.Error!void {
    if (extra > self.limit - self.writer.end) return error.WriteFailed;
    const needed = self.writer.end + extra;
    if (needed <= self.writer.buffer.len) return;
    const capacity = @max(needed, @min(self.limit, @max(4096, self.writer.buffer.len * 2)));
    self.writer.buffer = self.allocator.realloc(self.writer.buffer, capacity) catch {
        self.allocation_failed = true;
        return error.WriteFailed;
    };
}
fn drain(writer: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
    const self: *Self = @fieldParentPtr("writer", writer);
    var count = std.math.mul(usize, data[data.len - 1].len, splat) catch return error.WriteFailed;
    for (data[0 .. data.len - 1]) |bytes| count = std.math.add(usize, count, bytes.len) catch return error.WriteFailed;
    try self.grow(count);
    for (data[0 .. data.len - 1]) |bytes| {
        @memcpy(writer.buffer[writer.end..][0..bytes.len], bytes);
        writer.end += bytes.len;
    }
    const pattern = data[data.len - 1];
    for (0..splat) |_| {
        @memcpy(writer.buffer[writer.end..][0..pattern.len], pattern);
        writer.end += pattern.len;
    }
    return count;
}
fn rebase(writer: *std.Io.Writer, _: usize, extra: usize) std.Io.Writer.Error!void {
    const self: *Self = @fieldParentPtr("writer", writer);
    try self.grow(extra);
}
fn flush(_: *std.Io.Writer) std.Io.Writer.Error!void {}

test "incremental bodies preserve bytes and reject growth past the exact bound" {
    const t = std.testing;
    var body: Self = .{ .allocator = t.allocator, .limit = 10000 };
    defer body.deinit();
    try body.writer.splatByteAll(17, 4000);
    try body.writer.splatByteAll(29, 6000);
    try t.expectEqual(@as(usize, 10000), body.writer.buffer.len);
    try t.expect(std.mem.allEqual(u8, body.writer.buffered()[0..4000], 17));
    try t.expect(std.mem.allEqual(u8, body.writer.buffered()[4000..], 29));
    try t.expectError(error.WriteFailed, body.writer.writeByte(1));
    try t.expect(!body.allocation_failed);
}
