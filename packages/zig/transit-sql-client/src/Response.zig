//! One response lease. The slot outlives every response and its borrowed frame,
//! directory and parse metadata. Releasing a slot returns bounded reservations.
const std = @import("std");
const api = @import("root.zig").protocol;
const Self = @This();
value: api.Response,
lease: Lease,

pub fn validate(self: Self) !void {
    try self.lease.validate();
}
/// End all views before release. A copied response is not another lease owner.
pub fn deinit(self: Self) void {
    self.lease.release() catch unreachable;
}
pub const Slot = struct {
    arena: std.heap.ArenaAllocator = undefined,
    directory: [api.ResultFrame.max_columns][]const u8 = undefined,
    generation: u64 = 0,
    active: bool = false,
    pub fn acquire(self: *Slot, allocator: std.mem.Allocator) !Lease {
        if (self.active) return error.SqlResponseBusy;
        const generation = try std.math.add(u64, self.generation, 1);
        self.arena = .init(allocator);
        self.generation = generation;
        self.active = true;
        return .{ .slot = self, .generation = generation };
    }
};
pub const Lease = struct {
    slot: *Slot,
    generation: u64,
    pub fn validate(self: Lease) error{StaleSqlResponse}!void {
        if (!self.slot.active or self.slot.generation != self.generation) return error.StaleSqlResponse;
    }
    pub fn allocator(self: Lease) !std.mem.Allocator {
        try self.validate();
        return self.slot.arena.allocator();
    }
    pub fn decode(self: Lease, bytes: []align(api.ResultFrame.alignment) const u8, binary: bool) !Self {
        const a = try self.allocator();
        return .{ .value = try api.decodeResponseInto(a, &self.slot.directory, bytes, binary), .lease = self };
    }
    pub fn release(self: Lease) error{StaleSqlResponse}!void {
        try self.validate();
        self.slot.arena.deinit();
        self.slot.active = false;
    }
};

test "response slots retain independent owners and reject stale release after reuse" {
    const t = std.testing;
    const memory = @import("transit_memory");
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var slab = try memory.Slab.init(probe.allocator(), 128 * 1024);
    defer slab.deinit();
    var slots: [2]Slot = @splat(.{});
    probe.begin(true);
    const retained = try slots[0].acquire(slab.allocator());
    defer retained.release() catch unreachable;
    const value = try (try retained.allocator()).dupe(u8, "retained response");
    try t.expectError(error.SqlResponseBusy, slots[0].acquire(slab.allocator()));
    for (0..1000) |iteration| {
        const lease = try slots[1].acquire(slab.allocator());
        const bytes = try (try lease.allocator()).alignedAlloc(u8, .fromByteUnits(64), 1 + iteration % 16384);
        @memset(bytes, @truncate(iteration));
        try t.expectEqualStrings("retained response", value);
        try lease.release();
        try t.expectError(error.StaleSqlResponse, lease.release());
        const next = try slots[1].acquire(slab.allocator());
        try t.expectError(error.StaleSqlResponse, lease.allocator());
        try next.release();
    }
    try probe.verify();
    try t.expectEqual(slab.buffer.len, probe.live_bytes);
}
