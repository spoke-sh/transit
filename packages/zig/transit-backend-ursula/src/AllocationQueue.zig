//! Durable FIFO of physical allocations. One conditional append reserves bytes,
//! or consumes exactly one old item while optionally carrying it to the tail.
//! Retained cardinality never determines a resident collection.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("root.zig");
const Segment = adapter.Segment;
const Self = @This();
pub const Limits = core.protocol.Storage.Limits;
pub const Allocation = struct {
    identity: Segment.Identity,
    bytes: u64,
    frames: u16,
    data_bytes: u32,
    fenced: bool,
    digest: [32]u8,
    control: bool,
    pub fn validate(self: Allocation) !void {
        try self.identity.validate();
        if ((self.fenced and self.data_bytes != 0) or (!self.fenced and (self.data_bytes == 0 or self.data_bytes >= self.bytes))) return error.InvalidStorageAllocation;
        if (self.bytes == 0 or self.bytes > Segment.max_bytes + 4096 or self.frames == 0 or self.frames > Segment.max_frames) return error.InvalidStorageAllocation;
    }
};
pub const State = struct {
    definition: core.protocol.Growth.Definition,
    position: u64,
    cursor: u64,
    data_bytes: u64,
    control_bytes: u64,
    reclaimed_bytes: u64,
    item: ?Allocation,
    pub fn validate(self: State, position: u64) !void {
        if (self.position != position or self.position > core.protocol.max_counter or self.cursor > position or self.data_bytes > core.protocol.max_counter or self.control_bytes > core.protocol.max_counter) return error.InvalidAllocationHistory;
        if (self.item) |item| try item.validate();
    }
    pub fn reserve(self: State, allocation: Allocation, limits: Limits) !State {
        try allocation.validate();
        try limits.validate();
        var next = self;
        next.position = try std.math.add(u64, self.position, 1);
        const amount = if (allocation.control) &next.control_bytes else &next.data_bytes;
        amount.* = try std.math.add(u64, amount.*, allocation.bytes);
        if (amount.* > (if (allocation.control) limits.control_bytes else limits.bytes)) return error.StorageQuota;
        next.item = allocation;
        try next.validate(next.position);
        return next;
    }
    pub fn fence(self: State, at: u64, item: Allocation) !State {
        if (item.fenced) return error.InvalidStorageAllocation;
        var next = try self.consume(at, item, true);
        const amount = if (item.control) &next.control_bytes else &next.data_bytes;
        amount.* = std.math.sub(u64, amount.*, item.data_bytes) catch return error.InvalidAllocationHistory;
        next.reclaimed_bytes = try std.math.add(u64, next.reclaimed_bytes, item.data_bytes);
        next.item.?.bytes -= item.data_bytes;
        next.item.?.data_bytes = 0;
        next.item.?.fenced = true;
        try next.validate(next.position);
        return next;
    }
    pub fn consume(self: State, at: u64, item: ?Allocation, keep: bool) !State {
        if (at != self.cursor or at > self.position or (item == null and keep)) return error.AllocationConflict;
        var next = self;
        next.position = try std.math.add(u64, self.position, 1);
        next.cursor = try std.math.add(u64, at, 1);
        next.item = if (keep) item else null;
        if (item) |allocation| if (!keep) {
            const amount = if (allocation.control) &next.control_bytes else &next.data_bytes;
            amount.* = std.math.sub(u64, amount.*, allocation.bytes) catch return error.InvalidAllocationHistory;
            next.reclaimed_bytes = try std.math.add(u64, next.reclaimed_bytes, allocation.bytes);
        };
        try next.validate(next.position);
        return next;
    }
};
authority: adapter.Journal,
name: [45]u8,
limits: Limits,

pub fn init(authority: adapter.Journal, limits: Limits) !Self {
    try limits.validate();
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.physical.allocations.v1\x00");
    hash.update(authority.stream.bucket);
    hash.update("\x00");
    hash.update(authority.stream.name);
    var name: [45]u8 = undefined;
    name[0..2].* = "a-".*;
    _ = std.base64.url_safe_no_pad.Encoder.encode(name[2..], &hash.finalResult());
    return .{ .authority = authority, .name = name, .limits = limits };
}
pub fn journal(self: *Self) adapter.Journal {
    var value = self.authority;
    value.stream.name = &self.name;
    return value;
}
pub fn create(self: *Self) !void {
    try self.journal().create();
    if (try self.journal().tail() == 0) _ = try self.append(.{ .definition = core.protocol.Growth.current_definition, .position = 0, .cursor = 0, .data_bytes = 0, .control_bytes = 0, .reclaimed_bytes = 0, .item = null });
    _ = try self.current();
}
pub fn read(self: *Self, at: u64) !State {
    var response = try self.authority.send(.{ .read = .{ .stream = self.journal().stream, .options = .{ .position = .{ .record = at }, .max_records = 1 } } });
    defer response.deinit();
    try response.head.requireSuccess();
    const metadata = try response.head.metadata();
    if (metadata.record_start != at or metadata.record_next != try std.math.add(u64, at, 1) or response.body.len > adapter.max_record_bytes) return error.InvalidAllocationHistory;
    const parsed = try std.json.parseFromSlice(State, self.authority.client.http.allocator, response.body, .{});
    defer parsed.deinit();
    try parsed.value.validate(at);
    return parsed.value;
}
pub fn current(self: *Self) !State {
    const tail = try self.journal().tail();
    if (tail == 0) return error.MissingAllocationHistory;
    return self.read(tail - 1);
}
fn append(self: *Self, state: State) !bool {
    try state.validate(state.position);
    var bytes: [adapter.max_record_bytes]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    try std.json.Stringify.value(state, .{}, &out);
    return self.journal().append(state.position, out.buffered());
}
/// A lost acknowledgement returns uncertainty without creating any bytes. The
/// reservation remains enumerable, even if no creator ever reaches the provider.
pub fn reserve(self: *Self, allocation: Allocation) !void {
    for (0..8) |_| {
        const state = try self.current();
        if (try self.append(try state.reserve(allocation, self.limits))) return;
    }
    return error.AllocationConflict;
}
/// The maintenance owner supplies verified keep/delete evidence. Re-read the
/// actual queue item; callers cannot substitute a smaller charge or another ID.
pub fn trim(self: *Self) !void {
    const state = try self.current();
    try @import("LedgerTrim.zig").run(self.journal(), state.cursor);
}
pub fn consume(self: *Self, at: u64, expected: ?Allocation, keep: bool) !void {
    const original = try self.read(at);
    if (!std.meta.eql(original.item, expected)) return error.AllocationConflict;
    for (0..8) |_| {
        const state = try self.current();
        if (state.cursor != at) return error.AllocationConflict;
        if (try self.append(try state.consume(at, original.item, keep))) return;
    }
    return error.AllocationConflict;
}

test "allocation queue carries ownership and releases each charge only once" {
    const t = std.testing;
    const initial: State = .{ .definition = core.protocol.Growth.current_definition, .position = 0, .cursor = 0, .data_bytes = 0, .control_bytes = 0, .reclaimed_bytes = 0, .item = null };
    const item: Allocation = .{ .identity = .{ .epoch = 1, .nonce = @splat(9) }, .bytes = 100, .frames = 1, .data_bytes = 80, .fenced = false, .digest = @splat(1), .control = false };
    var state = try initial.reserve(item, .{ .bytes = 100 });
    try t.expectError(error.StorageQuota, state.reserve(item, .{ .bytes = 100 }));
    var control = item;
    control.control = true;
    state = try state.reserve(control, .{ .bytes = 100 });
    state = try state.consume(0, null, false);
    state = try state.consume(1, item, true);
    try t.expectEqual(@as(u64, 100), state.data_bytes);
    try t.expectEqualDeep(item, state.item.?);
    state = try state.consume(2, control, false);
    try t.expectEqual(@as(u64, 0), state.control_bytes);
    try t.expectEqual(@as(u64, 100), state.reclaimed_bytes);
    try t.expectError(error.AllocationConflict, state.consume(2, control, false));
    try t.expectError(error.AllocationConflict, state.consume(3, null, true));
    state = try state.consume(3, null, false);
    state = try state.fence(4, item);
    try t.expectEqual(@as(u64, 20), state.data_bytes);
    try t.expectEqual(@as(u64, 180), state.reclaimed_bytes);
    try t.expect(state.item.?.fenced);
    try t.expectEqual(@as(u32, 0), state.item.?.data_bytes);
    try t.expectError(error.InvalidStorageAllocation, state.fence(state.cursor, state.item.?));
}

/// After a permanent closed-name fence and confirmed trim, release only data
/// bytes. Its bounded checkpoint/name charge remains owned by the carried item.
pub fn fence(self: *Self, at: u64, item: Allocation) !void {
    const original = try self.read(at);
    if (!std.meta.eql(original.item, @as(?Allocation, item))) return error.AllocationConflict;
    for (0..8) |_| {
        const state = try self.current();
        if (state.cursor != at) return error.AllocationConflict;
        if (try self.append(try state.fence(at, item))) return;
    }
    return error.AllocationConflict;
}
