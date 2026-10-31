//! Deterministic admission for active client work, independent of durable data.
//! The embedding context serializes transitions and owns I/O, clocks and joins.
const std = @import("std");
const Self = @This();

pub const Lane = enum { data, control };
pub const State = enum { open, closing, joined };
pub const Limits = struct {
    data: usize,
    control: usize,

    pub fn validate(self: Limits) !void {
        if (self.data == 0 or self.control == 0) return error.InvalidClientCapacity;
        _ = std.math.add(usize, self.data, self.control) catch return error.InvalidClientCapacity;
    }
};

limits: Limits,
state: State = .open,
data: usize = 0,
control: usize = 0,

pub fn init(limits: Limits) !Self {
    try limits.validate();
    return .{ .limits = limits };
}

/// Refusal precedes dispatch. Control never borrows the data reserve or vice versa.
pub fn enter(self: *Self, lane: Lane) !void {
    if (self.state == .joined or (self.state == .closing and lane == .data)) return error.ClientContextClosed;
    const active, const limit = switch (lane) {
        .data => .{ &self.data, self.limits.data },
        .control => .{ &self.control, self.limits.control },
    };
    if (active.* == limit) return error.ClientCapacityExceeded;
    active.* += 1;
}

pub fn leave(self: *Self, lane: Lane) !void {
    const active = switch (lane) {
        .data => &self.data,
        .control => &self.control,
    };
    if (active.* == 0) return error.InvalidClientAdmission;
    active.* -= 1;
}

pub fn beginClose(self: *Self) void {
    if (self.state == .open) self.state = .closing;
}

pub fn idle(self: Self) bool {
    return self.data == 0 and self.control == 0;
}

/// This records a local join only. It establishes no durable operation outcome.
pub fn join(self: *Self) !void {
    if (self.state == .open or !self.idle()) return error.ClientWorkOutstanding;
    self.state = .joined;
}

test "data saturation preserves a distinct bounded control reserve" {
    const t = std.testing;
    var state = try Self.init(.{ .data = 2, .control = 1 });
    try state.enter(.data);
    try state.enter(.data);
    try t.expectError(error.ClientCapacityExceeded, state.enter(.data));
    try state.enter(.control);
    try t.expectError(error.ClientCapacityExceeded, state.enter(.control));
    state.beginClose();
    try t.expectError(error.ClientContextClosed, state.enter(.data));
    try t.expectError(error.ClientWorkOutstanding, state.join());
    try state.leave(.control);
    try state.enter(.control);
    try state.leave(.data);
    try state.leave(.data);
    try t.expectError(error.ClientWorkOutstanding, state.join());
    try state.leave(.control);
    try state.join();
    try state.join();
    state.beginClose();
    try t.expectEqual(.joined, state.state);
    try t.expectError(error.ClientContextClosed, state.enter(.control));
    try t.expectError(error.InvalidClientAdmission, state.leave(.data));
}

test "admission rejects invalid capacities before allocating or admitting work" {
    for ([_]Limits{ .{ .data = 0, .control = 1 }, .{ .data = 1, .control = 0 }, .{ .data = std.math.maxInt(usize), .control = 1 } }) |limits|
        try std.testing.expectError(error.InvalidClientCapacity, Self.init(limits));
}
