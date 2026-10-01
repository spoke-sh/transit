//! Counts Fuze/host-requested allocations, excluding libc and std.Io internals.
const std = @import("std");
const Self = @This();
backing: std.mem.Allocator,
live_bytes: usize = 0,
peak_bytes: usize = 0,
allocated_bytes: usize = 0,
allocations: usize = 0,
resizes: usize = 0,
pub fn allocator(self: *Self) std.mem.Allocator {
    return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
}
pub fn reset(self: *Self) void {
    self.peak_bytes = self.live_bytes;
    self.allocated_bytes = 0;
    self.allocations = 0;
    self.resizes = 0;
}
fn change(self: *Self, before: usize, after: usize) void {
    self.live_bytes = self.live_bytes - before + after;
    self.peak_bytes = @max(self.peak_bytes, self.live_bytes);
    self.allocated_bytes += after -| before;
}
fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const bytes = self.backing.rawAlloc(len, alignment, ret) orelse return null;
    self.allocations += 1;
    self.change(0, len);
    return bytes;
}
fn resize(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
    const self: *Self = @ptrCast(@alignCast(ctx));
    if (!self.backing.rawResize(bytes, alignment, len, ret)) return false;
    self.resizes += 1;
    self.change(bytes.len, len);
    return true;
}
fn remap(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const result = self.backing.rawRemap(bytes, alignment, len, ret) orelse return null;
    self.resizes += 1;
    self.change(bytes.len, len);
    return result;
}
fn free(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.backing.rawFree(bytes, alignment, ret);
    self.change(bytes.len, 0);
}
