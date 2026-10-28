//! Measures the allocator immediately below a workspace. Sealing forbids any
//! backing allocation, growing resize or remap, including attempted fallbacks.
//! Single borrower; independent workers use independent probes or host locking.
const std = @import("std");
const Self = @This();
pub const Counts = struct {
    alloc_attempts: usize = 0,
    alloc_successes: usize = 0,
    resize_attempts: usize = 0,
    resize_successes: usize = 0,
    growing_resize_attempts: usize = 0,
    remap_attempts: usize = 0,
    remap_successes: usize = 0,
    frees: usize = 0,
    requested_bytes: usize = 0,
    acquired_bytes: usize = 0,
    released_bytes: usize = 0,
    forbidden_attempts: usize = 0,
};
parent: std.mem.Allocator,
counts: Counts = .{},
live_bytes: usize = 0,
peak_bytes: usize = 0,
sealed: bool = false,

pub fn allocator(self: *Self) std.mem.Allocator {
    return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
}
/// Start a measurement interval without forgetting retained backing bytes.
pub fn begin(self: *Self, sealed: bool) void {
    self.counts = .{};
    self.peak_bytes = self.live_bytes;
    self.sealed = sealed;
}
pub fn verify(self: *const Self) error{BackingAllocationAfterWarmup}!void {
    if (self.counts.alloc_attempts != 0 or self.counts.growing_resize_attempts != 0 or self.counts.remap_attempts != 0)
        return error.BackingAllocationAfterWarmup;
}
fn changed(self: *Self, previous: usize, next: usize) void {
    self.live_bytes = self.live_bytes - previous + next;
    self.peak_bytes = @max(self.peak_bytes, self.live_bytes);
    self.counts.acquired_bytes += next -| previous;
    self.counts.released_bytes += previous -| next;
}
fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    self.counts.alloc_attempts += 1;
    self.counts.requested_bytes += len;
    if (self.sealed) {
        self.counts.forbidden_attempts += 1;
        return null;
    }
    const result = self.parent.rawAlloc(len, alignment, ra) orelse return null;
    self.counts.alloc_successes += 1;
    self.changed(0, len);
    return result;
}
fn resize(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) bool {
    const self: *Self = @ptrCast(@alignCast(context));
    self.counts.resize_attempts += 1;
    if (len > bytes.len) self.counts.growing_resize_attempts += 1;
    self.counts.requested_bytes += len -| bytes.len;
    if (self.sealed and len > bytes.len) {
        self.counts.forbidden_attempts += 1;
        return false;
    }
    if (!self.parent.rawResize(bytes, alignment, len, ra)) return false;
    self.counts.resize_successes += 1;
    self.changed(bytes.len, len);
    return true;
}
fn remap(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    self.counts.remap_attempts += 1;
    self.counts.requested_bytes += len -| bytes.len;
    if (self.sealed) {
        self.counts.forbidden_attempts += 1;
        return null;
    }
    const result = self.parent.rawRemap(bytes, alignment, len, ra) orelse return null;
    self.counts.remap_successes += 1;
    self.changed(bytes.len, len);
    return result;
}
fn free(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ra: usize) void {
    const self: *Self = @ptrCast(@alignCast(context));
    self.parent.rawFree(bytes, alignment, ra);
    self.counts.frees += 1;
    self.changed(bytes.len, 0);
}

test "sealed probes reject allocation resize and remap attempts without losing live accounting" {
    const t = std.testing;
    var probe: Self = .{ .parent = t.allocator };
    const a = probe.allocator();
    const bytes = try a.alloc(u8, 48);
    probe.begin(true);
    try t.expectError(error.OutOfMemory, a.alloc(u8, 1));
    try t.expect(!a.resize(bytes, 96));
    try t.expect(a.remap(bytes, 96) == null);
    try t.expectEqual(3, probe.counts.forbidden_attempts);
    try t.expectEqual(48, probe.live_bytes);
    try t.expectEqual(0, probe.counts.alloc_successes);
    try t.expectError(error.BackingAllocationAfterWarmup, probe.verify());
    probe.begin(true);
    try probe.verify();
    a.free(bytes);
    try t.expectEqual(0, probe.live_bytes);
    try t.expectEqual(48, probe.peak_bytes);
    try t.expectEqual(48, probe.counts.released_bytes);
}

test "an outer probe detects a path bypassing the inner allocator" {
    const t = std.testing;
    var outer: Self = .{ .parent = t.allocator };
    var inner: Self = .{ .parent = outer.allocator() };
    outer.begin(true);
    inner.begin(true);
    try t.expectError(error.OutOfMemory, outer.allocator().alloc(u8, 8));
    try inner.verify();
    try t.expectError(error.BackingAllocationAfterWarmup, outer.verify());
}
