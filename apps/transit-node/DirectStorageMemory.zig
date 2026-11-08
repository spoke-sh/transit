//! One exclusive local owner's direct-storage backing allocation envelope.
//! Reservations are disjoint: ordinary work cannot spend recovery or collector
//! capacity. No buffers are eagerly allocated. All borrowers join before deinit.
const std = @import("std");
const memory = @import("transit_memory");
const p = @import("transit_client").protocol;
const Self = @This();

total: memory.Quota,
data: memory.Quota,
control: memory.Quota,
maintenance: memory.Quota,
collection: memory.Quota,
data_allocator: memory.Quota.Allocator,
control_allocator: memory.Quota.Allocator,
collection_allocator: memory.Quota.Allocator,

/// Initialize in place; quota ancestors and allocator contexts never move.
pub fn init(self: *Self, parent: std.mem.Allocator, settings: p.Storage.Settings) !void {
    try settings.admission.validate();
    try settings.maintenance.validate();
    const data: usize = settings.admission.data_bytes;
    const control: usize = settings.admission.control_bytes;
    const work: usize = settings.maintenance.resident_bytes;
    const collection = p.Storage.Admission.collection_bytes;
    self.* = .{
        .total = .{ .limit = data + control + work + collection },
        .data = .{ .limit = data, .parent = &self.total },
        .control = .{ .limit = control, .parent = &self.total },
        .maintenance = .{ .limit = work, .parent = &self.total },
        .collection = .{ .limit = collection, .parent = &self.total },
        .data_allocator = .{ .parent = parent, .quota = &self.data },
        .control_allocator = .{ .parent = parent, .quota = &self.control },
        .collection_allocator = .{ .parent = parent, .quota = &self.collection },
    };
}
pub fn deinit(self: *Self) void {
    inline for (.{ &self.total, &self.data, &self.control, &self.maintenance, &self.collection }) |quota|
        std.debug.assert(quota.used.load(.acquire) == 0);
    self.* = undefined;
}
pub fn allocator(self: *Self, control: bool) std.mem.Allocator {
    return if (control) self.control_allocator.allocator() else self.data_allocator.allocator();
}
fn observe(quota: *const memory.Quota) p.Storage.AdmissionPool {
    const used = quota.used.load(.acquire);
    return .{
        .memory = .{ .limit = quota.limit, .used = used, .peak = @max(used, quota.peak.load(.acquire)) },
        .refusals = @min(p.max_counter, quota.refusals.load(.acquire)),
    };
}
pub fn observation(self: *const Self) p.Storage.AdmissionObservation {
    return .{ .total = observe(&self.total), .data = observe(&self.data), .control = observe(&self.control), .maintenance = observe(&self.maintenance), .collection = observe(&self.collection) };
}

test "direct storage pressure preserves recovery and collection with retained owners" {
    const t = std.testing;
    var owner: Self = undefined;
    try owner.init(t.allocator, .{ .admission = .{ .data_bytes = 1024 * 1024, .control_bytes = 1024 * 1024 } });
    defer owner.deinit();
    var requests: @import("DirectRequestMemory.zig") = .{};
    requests.attach(&owner);
    var first = requests.request(t.allocator, false);
    const response = try first.allocator().alloc(u8, 768 * 1024);
    const retained = try owner.allocator(false).alloc(u8, 256 * 1024);
    try t.expectError(error.OutOfMemory, first.allocator().alloc(u8, 1));
    const recovery = try owner.allocator(true).alloc(u8, 4096);
    const collection = try owner.collection_allocator.allocator().alloc(u8, 4096);
    try owner.observation().validate();
    try t.expectEqual(1024 * 1024 + 8192, owner.total.used.load(.acquire));
    first.allocator().free(response);
    try t.expectEqual(256 * 1024, owner.data.used.load(.acquire));
    owner.allocator(false).free(retained);
    owner.allocator(true).free(recovery);
    owner.collection_allocator.allocator().free(collection);
}
