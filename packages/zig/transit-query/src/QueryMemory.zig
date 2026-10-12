//! Allocation accounting for a single finite-query owner. Freed bytes release
//! capacity; failed growth leaves both the allocation and accounting unchanged.
const std = @import("std");
const Self = @This();
parent: std.mem.Allocator,
limit: usize,
used: usize = 0,
peak: usize = 0,
exhausted: bool = false,
pub fn allocator(self: *Self) std.mem.Allocator {
    return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
}
fn permits(self: *Self, previous: usize, next: usize) bool {
    if (next > self.limit - (self.used - previous)) {
        self.exhausted = true;
        return false;
    }
    return true;
}
fn account(self: *Self, previous: usize, next: usize) void {
    self.used = self.used - previous + next;
    self.peak = @max(self.peak, self.used);
}
fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    if (!self.permits(0, len)) return null;
    const bytes = self.parent.rawAlloc(len, alignment, ra) orelse return null;
    self.account(0, len);
    return bytes;
}
fn resize(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) bool {
    const self: *Self = @ptrCast(@alignCast(context));
    if (!self.permits(bytes.len, len)) return false;
    if (!self.parent.rawResize(bytes, alignment, len, ra)) return false;
    self.account(bytes.len, len);
    return true;
}
fn remap(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    if (!self.permits(bytes.len, len)) return null;
    const result = self.parent.rawRemap(bytes, alignment, len, ra) orelse return null;
    self.account(bytes.len, len);
    return result;
}
fn free(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ra: usize) void {
    const self: *Self = @ptrCast(@alignCast(context));
    self.parent.rawFree(bytes, alignment, ra);
    self.account(bytes.len, 0);
}
test "query memory bounds simultaneous allocations and releases capacity after failure" {
    const t = std.testing;
    var budget: Self = .{ .parent = t.allocator, .limit = 64 };
    const a = budget.allocator();
    const first = try a.alloc(u8, 40);
    try t.expectError(error.OutOfMemory, a.alloc(u8, 25));
    try t.expect(!a.resize(first, 65));
    try t.expectEqual(@as(usize, 40), budget.used);
    a.free(first);
    const second = try a.alloc(u8, 64);
    try t.expectEqual(@as(usize, 64), budget.peak);
    a.free(second);
    try t.expectEqual(@as(usize, 0), budget.used);
}
