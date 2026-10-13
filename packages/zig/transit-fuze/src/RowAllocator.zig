//! One bounded reusable allocation for transient decoded rows. Larger or
//! simultaneous allocations use the original allocator and keep normal limits.
//! The stable owner outlives every borrowing arena; public output never borrows it.
const std = @import("std");
const Self = @This();
pub const cache_bytes = 4096;
backing: std.mem.Allocator,
buffer: [cache_bytes]u8 align(64) = undefined,
used: bool = false,
pub fn init(backing: std.mem.Allocator) !*Self {
    const self = try backing.create(Self);
    self.* = .{ .backing = backing };
    return self;
}
pub fn deinit(self: *Self) void {
    std.debug.assert(!self.used);
    const backing = self.backing;
    backing.destroy(self);
}
pub fn allocator(self: *Self) std.mem.Allocator {
    return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
}
fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    if (!self.used and len <= cache_bytes and alignment.toByteUnits() <= 64) {
        self.used = true;
        return &self.buffer;
    }
    return self.backing.rawAlloc(len, alignment, ret);
}
fn resize(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
    const self: *Self = @ptrCast(@alignCast(context));
    if (memory.ptr == self.buffer[0..].ptr) return len <= cache_bytes;
    return self.backing.rawResize(memory, alignment, len, ret);
}
fn remap(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    if (memory.ptr == self.buffer[0..].ptr) return if (len <= cache_bytes) memory.ptr else null;
    return self.backing.rawRemap(memory, alignment, len, ret);
}
fn free(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
    const self: *Self = @ptrCast(@alignCast(context));
    if (memory.ptr == self.buffer[0..].ptr) {
        std.debug.assert(self.used);
        self.used = false;
    } else self.backing.rawFree(memory, alignment, ret);
}
