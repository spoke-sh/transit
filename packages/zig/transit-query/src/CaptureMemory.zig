//! The capture adapter owns a fixed buffer, independently of transport memory.
//! Only a failed allocation from this buffer establishes adapter exhaustion.
const std = @import("std");
const Self = @This();
fixed: std.heap.FixedBufferAllocator,
failed: bool = false,

pub fn init(buffer: []u8) Self {
    return .{ .fixed = .init(buffer) };
}
pub fn allocator(self: *Self) std.mem.Allocator {
    return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
}
pub fn failure(self: *const Self, err: anyerror) anyerror {
    // Canonical grant validation uses an allocating JSON writer, which exposes
    // allocation failure as WriteFailed. A writer error alone proves nothing.
    return if (self.failed and (err == error.OutOfMemory or err == error.WriteFailed)) error.QueryAdapterBudgetExceeded else err;
}
fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(raw));
    const bytes = self.fixed.allocator().rawAlloc(len, alignment, ra);
    self.failed = bytes == null;
    return bytes;
}
fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) bool {
    const self: *Self = @ptrCast(@alignCast(raw));
    // A declined in-place growth is a capacity probe, not allocation failure:
    // callers may fall back to a new allocation or keep the existing buffer.
    return self.fixed.allocator().rawResize(bytes, alignment, len, ra);
}
fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(raw));
    return self.fixed.allocator().rawRemap(bytes, alignment, len, ra);
}
fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ra: usize) void {
    const self: *Self = @ptrCast(@alignCast(raw));
    self.fixed.allocator().rawFree(bytes, alignment, ra);
}

test "capture memory distinguishes external failures from buffer exhaustion and growth probes" {
    const t = std.testing;
    var bytes: [64]u8 = undefined;
    var memory: Self = .init(&bytes);
    const a = memory.allocator();
    const first = try a.alloc(u8, 40);
    try t.expectEqual(error.WriteFailed, memory.failure(error.WriteFailed));
    try t.expect(!a.resize(first, 65));
    try t.expectEqual(error.OutOfMemory, memory.failure(error.OutOfMemory));
    try t.expect(a.remap(first, 65) == null);
    try t.expectEqual(error.OutOfMemory, memory.failure(error.OutOfMemory));
    try t.expectError(error.OutOfMemory, a.alloc(u8, 25));
    try t.expectEqual(error.QueryAdapterBudgetExceeded, memory.failure(error.OutOfMemory));
    try t.expectEqual(error.AccessDenied, memory.failure(error.AccessDenied));
    a.free(first);
    const recovered = try a.alloc(u8, 64);
    try t.expectEqual(error.OutOfMemory, memory.failure(error.OutOfMemory));
    a.free(recovered);
    var empty: Self = .init(&.{});
    var output: std.Io.Writer.Allocating = .init(empty.allocator());
    defer output.deinit();
    try t.expectError(error.WriteFailed, output.writer.writeAll("canonical grant"));
    try t.expectEqual(error.QueryAdapterBudgetExceeded, empty.failure(error.WriteFailed));
}
