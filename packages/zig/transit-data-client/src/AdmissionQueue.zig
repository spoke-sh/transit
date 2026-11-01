//! Bounded volatile admission metadata. The context owns synchronization and
//! facet eligibility; queue order grants neither execution nor remote authority.
const std = @import("std");
const Lane = @import("Admission.zig").Lane;
const Self = @This();

pub const Limits = struct { data: usize = 0, control: usize = 0 };
pub const Ticket = struct { slot: usize, serial: u64 };
const Entry = struct { facet: usize, lane: Lane, serial: u64 };
allocator: std.mem.Allocator,
entries: []?Entry,
limits: Limits,
data: usize = 0,
control: usize = 0,
serial: u64 = 1,

pub fn init(allocator: std.mem.Allocator, limits: Limits) !Self {
    const count = std.math.add(usize, limits.data, limits.control) catch return error.InvalidClientCapacity;
    // std.Io.Condition uses a u16 waiter count. Reserve one for joined close.
    if (count >= std.math.maxInt(u16)) return error.InvalidClientCapacity;
    const entries = try allocator.alloc(?Entry, count);
    @memset(entries, null);
    return .{ .allocator = allocator, .entries = entries, .limits = limits };
}
pub fn deinit(self: *Self) void {
    std.debug.assert(self.empty());
    self.allocator.free(self.entries);
    self.* = undefined;
}
pub fn empty(self: Self) bool {
    return self.data == 0 and self.control == 0;
}
pub fn enqueue(self: *Self, facet: usize, lane: Lane) !Ticket {
    const count, const limit = switch (lane) {
        .data => .{ &self.data, self.limits.data },
        .control => .{ &self.control, self.limits.control },
    };
    for (self.entries) |entry| if (entry) |value| {
        if (value.facet == facet) return error.Busy;
    };
    if (count.* == limit) return error.ClientCapacityExceeded;
    if (self.serial == std.math.maxInt(u64)) return error.ClientAdmissionExhausted;
    for (self.entries, 0..) |*entry, index| if (entry.* == null) {
        entry.* = .{ .facet = facet, .lane = lane, .serial = self.serial };
        self.serial += 1;
        count.* += 1;
        return .{ .slot = index, .serial = entry.*.?.serial };
    };
    unreachable;
}
pub fn remove(self: *Self, ticket: Ticket) !void {
    if (ticket.slot >= self.entries.len) return error.StaleClientAdmission;
    const entry = self.entries[ticket.slot] orelse return error.StaleClientAdmission;
    if (entry.serial != ticket.serial) return error.StaleClientAdmission;
    switch (entry.lane) {
        .data => self.data -= 1,
        .control => self.control -= 1,
    }
    self.entries[ticket.slot] = null;
}

/// Oldest eligible facet in this lane. Each facet has at most one waiter:
/// a busy result cannot block unrelated facets and a newcomer cannot overtake
/// an already eligible waiter. Eligibility is read under the context's mutex.
pub fn first(self: Self, lane: Lane, context: anytype, comptime eligible: anytype) ?Ticket {
    var selected: ?Ticket = null;
    for (self.entries, 0..) |entry, index| if (entry) |value| {
        if (value.lane != lane or !eligible(context, value.facet)) continue;
        if (selected == null or value.serial < selected.?.serial)
            selected = .{ .slot = index, .serial = value.serial };
    };
    return selected;
}

test "admission order skips busy facets but never overtakes eligible older work" {
    const t = std.testing;
    const Ready = struct {
        fn eligible(values: []const bool, index: usize) bool {
            return values[index];
        }
    };
    var queue = try Self.init(t.allocator, .{ .data = 3, .control = 1 });
    defer queue.deinit();
    const oldest = try queue.enqueue(0, .data);
    const second = try queue.enqueue(1, .data);
    const third = try queue.enqueue(2, .data);
    const control = try queue.enqueue(3, .control);
    try t.expectError(error.Busy, queue.enqueue(0, .control));
    try t.expectError(error.ClientCapacityExceeded, queue.enqueue(4, .data));
    try t.expectError(error.ClientCapacityExceeded, queue.enqueue(4, .control));
    var ready = [_]bool{ false, true, true, true };
    try t.expectEqual(second, queue.first(.data, @as([]const bool, &ready), Ready.eligible).?);
    try t.expectEqual(control, queue.first(.control, @as([]const bool, &ready), Ready.eligible).?);
    try queue.remove(second);
    const replacement = try queue.enqueue(1, .data);
    try t.expectEqual(third, queue.first(.data, @as([]const bool, &ready), Ready.eligible).?);
    ready[0] = true;
    try t.expectEqual(oldest, queue.first(.data, @as([]const bool, &ready), Ready.eligible).?);
    try queue.remove(oldest);
    try queue.remove(third);
    try t.expectEqual(replacement, queue.first(.data, @as([]const bool, &ready), Ready.eligible).?);
    try t.expectError(error.StaleClientAdmission, queue.remove(second));
    try queue.remove(replacement);
    try queue.remove(control);
    try t.expect(queue.empty());
}

test "admission queue reuses fixed capacity without allocation or serial wrap" {
    const t = std.testing;
    var allocator: t.FailingAllocator = .init(t.allocator, .{});
    var queue = try Self.init(allocator.allocator(), .{ .data = 1, .control = 1 });
    defer queue.deinit();
    allocator.fail_index = allocator.alloc_index;
    for (0..4096) |index| {
        const data = try queue.enqueue(index, .data);
        const control = try queue.enqueue(index + 1, .control);
        try queue.remove(data);
        try queue.remove(control);
    }
    try t.expect(!allocator.has_induced_failure);
    queue.serial = std.math.maxInt(u64);
    try t.expectError(error.ClientAdmissionExhausted, queue.enqueue(0, .data));
    try t.expectError(error.InvalidClientCapacity, Self.init(t.allocator, .{ .data = std.math.maxInt(usize), .control = 1 }));
    try t.expectError(error.InvalidClientCapacity, Self.init(t.allocator, .{ .data = std.math.maxInt(u16) }));
}
