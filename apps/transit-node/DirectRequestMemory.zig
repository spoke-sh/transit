//! Concurrent direct-request backing bytes, including retained HTTP responses.
//! This owner reserves capacity only; it does not preallocate or retain a slab.
const std = @import("std");
const memory = @import("transit_memory");
const Self = @This();

const Requests = @import("transit_client").protocol.Storage.Requests;
const defaults: Requests = .{};
request_bytes: u32 = defaults.request_bytes,
data: memory.Quota = .{ .limit = defaults.data_bytes },
control: memory.Quota = .{ .limit = defaults.control_bytes },

pub const Report = struct {
    alloc_attempts: usize,
    growing_resize_attempts: usize,
    remap_attempts: usize,
    acquired_bytes: usize,
    live_bytes: usize,
    peak_bytes: usize,
    pub fn capture(probe: *const memory.AllocationProbe) Report {
        return .{ .alloc_attempts = probe.counts.alloc_attempts, .growing_resize_attempts = probe.counts.growing_resize_attempts, .remap_attempts = probe.counts.remap_attempts, .acquired_bytes = probe.counts.acquired_bytes, .live_bytes = probe.live_bytes, .peak_bytes = probe.peak_bytes };
    }
};

pub fn init(settings: Requests) !Self {
    try settings.validate();
    return .{ .request_bytes = settings.request_bytes, .data = .{ .limit = settings.data_bytes }, .control = .{ .limit = settings.control_bytes } };
}

/// Keep both this owner and the returned single-request budget at stable
/// addresses until parsing, private work and the joined response write end.
pub fn request(self: *Self, parent: std.mem.Allocator, control: bool) memory.Budget {
    return .{
        .parent = parent,
        .quota = if (control) &self.control else &self.data,
        .limit = if (control) self.control.limit else self.request_bytes,
    };
}

test "held direct responses consume shared capacity without consuming the control reserve" {
    const t = std.testing;
    var owner: Self = .{ .data = .{ .limit = 128 }, .control = .{ .limit = 32 } };
    var first = owner.request(t.allocator, false);
    var second = owner.request(t.allocator, false);
    var recovery = owner.request(t.allocator, true);
    var scratch = std.heap.ArenaAllocator.init(first.allocator());
    _ = try scratch.allocator().alloc(u8, 16);
    scratch.deinit();
    const response = try first.allocator().dupe(u8, &@as([96]u8, @splat(7)));
    try t.expectError(error.OutOfMemory, second.allocator().alloc(u8, 33));
    try t.expect(second.exhausted);
    try t.expectEqual(96, owner.data.used.load(.acquire));
    const receipt = try recovery.allocator().alloc(u8, 32);
    recovery.allocator().free(receipt);
    try t.expectEqualSlices(u8, &@as([96]u8, @splat(7)), response);
    // A joined success, disconnect or cancellation frees the response before
    // releasing its request budget. Another request can then use the capacity.
    first.allocator().free(response);
    const next = try second.allocator().alloc(u8, 128);
    second.allocator().free(next);
    try t.expectEqual(0, owner.data.used.load(.acquire));
    try t.expectEqual(0, owner.control.used.load(.acquire));
    try t.expectEqual(0, first.used);
    try t.expectEqual(0, second.used);
    try t.expectEqual(0, recovery.used);
}
