//! Stable, single-borrower owner of a fixed aligned reserve. No reset, allocation
//! or resize can consult a backing allocator after initialization.
const std = @import("std");
const Self = @This();
pub const alignment = 64;
parent: ?std.mem.Allocator,
buffer: []align(alignment) u8,
fixed: std.heap.FixedBufferAllocator,
generation: u64 = 0,
active: bool = false,
exhausted: bool = false,
peak: usize = 0,

pub fn init(parent: std.mem.Allocator, capacity: usize) !Self {
    if (capacity == 0) return error.InvalidWorkspaceCapacity;
    const buffer = try parent.alignedAlloc(u8, .fromByteUnits(alignment), capacity);
    var self = fromBuffer(buffer);
    self.parent = parent;
    return self;
}
/// The supplied backing owner accounts for and outlives this workspace.
pub fn fromBuffer(buffer: []align(alignment) u8) Self {
    return .{ .parent = null, .buffer = buffer, .fixed = .init(buffer) };
}
pub fn deinit(self: *Self) void {
    std.debug.assert(!self.active);
    if (self.parent) |parent| parent.free(self.buffer);
    self.* = undefined;
}
pub fn acquire(self: *Self) !Lease {
    if (self.active) return error.WorkspaceBusy;
    self.generation = try std.math.add(u64, self.generation, 1);
    self.fixed.reset();
    self.exhausted = false;
    self.active = true;
    return .{ .owner = self, .generation = self.generation };
}
pub const Lease = struct {
    owner: *Self,
    generation: u64,
    pub fn validate(self: Lease) error{StaleMemoryLease}!void {
        if (!self.owner.active or self.generation != self.owner.generation) return error.StaleMemoryLease;
    }
    /// The allocator and all returned slices borrow this lease. They cannot be
    /// used after reset/release; checking a stale raw slice is not possible.
    pub fn allocator(self: Lease) !std.mem.Allocator {
        try self.validate();
        return .{ .ptr = self.owner, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    pub fn mark(self: Lease) !Mark {
        try self.validate();
        return .{ .owner = self.owner, .generation = self.generation, .offset = self.owner.fixed.end_index };
    }
    /// Ends every allocation after the mark. The caller must release its views.
    pub fn rewind(self: Lease, point: Mark) !void {
        try self.validate();
        if (point.owner != self.owner or point.generation != self.generation or point.offset > self.owner.fixed.end_index) return error.InvalidMemoryMark;
        self.owner.fixed.end_index = point.offset;
        self.owner.exhausted = false;
    }
    /// Ends all views and allocator borrows; the updated lease can be used again.
    pub fn reset(self: *Lease) !void {
        try self.validate();
        const next = try std.math.add(u64, self.generation, 1);
        self.owner.fixed.reset();
        self.owner.exhausted = false;
        self.owner.generation = next;
        self.generation = next;
    }
    /// Erasure is explicit so secret-bearing request slots clear their bytes
    /// without requiring payload-wide writes for every immutable data view.
    pub fn release(self: Lease, erase: bool) !void {
        try self.validate();
        if (erase) std.crypto.secureZero(u8, self.owner.buffer);
        self.owner.fixed.reset();
        self.owner.active = false;
    }
};
pub const Mark = struct { owner: *Self, generation: u64, offset: usize };
fn alloc(context: *anyopaque, len: usize, alignment_: std.mem.Alignment, ra: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    std.debug.assert(self.active);
    const result = self.fixed.allocator().rawAlloc(len, alignment_, ra);
    self.exhausted = result == null;
    self.peak = @max(self.peak, self.fixed.end_index);
    return result;
}
fn resize(context: *anyopaque, bytes: []u8, alignment_: std.mem.Alignment, len: usize, ra: usize) bool {
    const self: *Self = @ptrCast(@alignCast(context));
    std.debug.assert(self.active);
    const result = self.fixed.allocator().rawResize(bytes, alignment_, len, ra);
    self.exhausted = !result;
    self.peak = @max(self.peak, self.fixed.end_index);
    return result;
}
fn remap(context: *anyopaque, bytes: []u8, alignment_: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
    return if (resize(context, bytes, alignment_, len, ra)) bytes.ptr else null;
}
fn free(context: *anyopaque, bytes: []u8, alignment_: std.mem.Alignment, ra: usize) void {
    const self: *Self = @ptrCast(@alignCast(context));
    std.debug.assert(self.active);
    self.fixed.allocator().rawFree(bytes, alignment_, ra);
}

test "workspace reset preserves charged capacity without backing allocation" {
    const t = std.testing;
    var probe: @import("AllocationProbe.zig") = .{ .parent = t.allocator };
    var workspace = try init(probe.allocator(), 4096);
    defer workspace.deinit();
    var lease = try workspace.acquire();
    defer lease.release(false) catch unreachable;
    probe.begin(true);
    for (0..1000) |i| {
        const a = try lease.allocator();
        const bytes = try a.alignedAlloc(u8, .fromByteUnits(64), if (i % 2 == 0) 31 else 2048);
        try t.expect(std.mem.isAligned(@intFromPtr(bytes.ptr), 64));
        @memset(bytes, @truncate(i));
        const stale = lease;
        try lease.reset();
        try t.expectError(error.StaleMemoryLease, stale.allocator());
    }
    try probe.verify();
    try t.expectEqual(4096, probe.live_bytes);
    try t.expectEqual(4096, probe.peak_bytes);
}
test "workspace refuses capacity and restores transactional append marks" {
    const t = std.testing;
    var workspace = try init(t.allocator, 128);
    defer workspace.deinit();
    const lease = try workspace.acquire();
    try t.expectError(error.WorkspaceBusy, workspace.acquire());
    const a = try lease.allocator();
    const retained = try a.dupe(u8, "kept");
    const point = try lease.mark();
    _ = try a.alloc(u8, 100);
    try t.expectError(error.OutOfMemory, a.alloc(u8, 128));
    try t.expect(workspace.exhausted);
    try lease.rewind(point);
    _ = try a.alloc(u8, 124);
    try t.expectEqualStrings("kept", retained);
    try lease.release(true);
    try t.expect(std.mem.allEqual(u8, workspace.buffer, 0));
    try t.expectError(error.StaleMemoryLease, lease.release(false));
    const next = try workspace.acquire();
    defer next.release(false) catch unreachable;
    try t.expectError(error.InvalidMemoryMark, next.rewind(point));
}
