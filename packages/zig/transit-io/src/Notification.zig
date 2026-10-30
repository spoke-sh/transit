//! Bounded, process-local wakeups. Register before rechecking the durable
//! predicate, then wait only if that recheck still requires progress. A wakeup
//! carries no acceptance, authorization, or completion evidence.
const std = @import("std");
const Self = @This();
allocator: std.mem.Allocator,
slots: []Slot,
free: ?u16,
active: usize = 0,
serial: u64 = 1,
generation: u64 = 1,
closed: bool = false,
mutex: std.Io.Mutex = .init,
condition: std.Io.Condition = .init,

const Slot = struct {
    serial: u64 = 0,
    next: ?u16,
    waiting: bool = false,
};
pub const Ticket = struct {
    owner: *Self,
    slot: u16,
    serial: u64,
    observed: u64,
};
pub const Outcome = enum { changed, timeout, closed };
/// Condition's waiter count is u16. This is an active-operation capacity,
/// independent of durable object or record cardinality.
pub const max_waiters = std.math.maxInt(u16);

pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
    if (capacity == 0 or capacity > max_waiters) return error.InvalidNotificationCapacity;
    const slots = try allocator.alloc(Slot, capacity);
    for (slots, 0..) |*slot, index| slot.* = .{
        .next = if (index + 1 < capacity) @intCast(index + 1) else null,
    };
    return .{ .allocator = allocator, .slots = slots, .free = 0 };
}

/// The owner must stay at the same address from the first registration until
/// all tickets are released. Exhaustion refuses new waits, never durable work.
pub fn register(self: *Self, io: std.Io) !Ticket {
    try self.mutex.lock(io);
    defer self.mutex.unlock(io);
    if (self.closed) return error.NotificationClosed;
    const index = self.free orelse return error.NotificationCapacityExceeded;
    if (self.serial == std.math.maxInt(u64)) return error.NotificationSerialExhausted;
    const slot = &self.slots[index];
    self.free = slot.next;
    slot.* = .{ .serial = self.serial, .next = null };
    self.serial += 1;
    self.active += 1;
    return .{ .owner = self, .slot = index, .serial = slot.serial, .observed = self.generation };
}

fn validate(self: *Self, ticket: Ticket) !*Slot {
    if (ticket.owner != self or ticket.slot >= self.slots.len or ticket.serial == 0 or ticket.observed == 0 or ticket.observed > self.generation)
        return error.StaleNotificationTicket;
    const slot = &self.slots[ticket.slot];
    if (slot.serial != ticket.serial) return error.StaleNotificationTicket;
    return slot;
}

/// A ticket admits one waiter. Release it after wait returns, also on timeout
/// or cancellation. Rechecking the predicate and registering a new ticket is
/// the caller's responsibility; an old ticket does not become a new wait.
pub fn wait(self: *Self, io: std.Io, ticket: Ticket, timeout: std.Io.Timeout) !Outcome {
    const deadline = timeout.toDeadline(io);
    try self.mutex.lock(io);
    defer self.mutex.unlock(io);
    const slot = try self.validate(ticket);
    if (slot.waiting) return error.NotificationAlreadyWaiting;
    slot.waiting = true;
    defer slot.waiting = false;
    while (!self.closed and self.generation == ticket.observed) {
        self.condition.waitTimeout(io, &self.mutex, deadline) catch |err| switch (err) {
            error.Timeout => if (!self.closed and self.generation == ticket.observed) return .timeout,
            else => return err,
        };
    }
    return if (self.closed) .closed else .changed;
}

pub fn release(self: *Self, io: std.Io, ticket: Ticket) !void {
    self.mutex.lockUncancelable(io);
    defer self.mutex.unlock(io);
    const slot = try self.validate(ticket);
    if (slot.waiting) return error.NotificationStillWaiting;
    slot.* = .{ .next = self.free };
    self.free = ticket.slot;
    self.active -= 1;
}

/// Call after publication or recovery makes progress observable. Non-failing:
/// a volatile wakeup cannot turn accepted work into a reported rejection.
pub fn notify(self: *Self, io: std.Io) void {
    self.mutex.lockUncancelable(io);
    defer self.mutex.unlock(io);
    if (self.closed) return;
    if (self.generation == std.math.maxInt(u64)) {
        self.closed = true;
    } else self.generation += 1;
    self.condition.broadcast(io);
}

pub fn close(self: *Self, io: std.Io) void {
    self.mutex.lockUncancelable(io);
    defer self.mutex.unlock(io);
    self.closed = true;
    self.condition.broadcast(io);
}

/// Close, join all tasks and release their tickets before destruction. After
/// successful destruction no caller may access this owner.
pub fn deinit(self: *Self, io: std.Io) !void {
    self.mutex.lockUncancelable(io);
    defer self.mutex.unlock(io);
    if (self.active != 0) return error.NotificationTicketsOutstanding;
    self.closed = true;
    self.allocator.free(self.slots);
    self.slots = &.{};
    self.free = null;
}

test "registration recheck and parking preserve notifications at every boundary" {
    const t = std.testing;
    var value = try Self.init(t.allocator, 2);
    defer value.deinit(t.io) catch unreachable;
    // A notification before registration is covered by the following durable
    // recheck. Events after registration must wake even before wait starts.
    for (0..3) |boundary| {
        var durable: u64 = 0;
        if (boundary == 0) {
            durable += 1;
            value.notify(t.io);
        }
        const ticket = try value.register(t.io);
        defer value.release(t.io, ticket) catch unreachable;
        if (boundary == 1) {
            durable += 1;
            value.notify(t.io);
        }
        const observed = durable;
        if (boundary == 2) {
            durable += 1;
            value.notify(t.io);
        }
        if (observed == 0) try t.expectEqual(.changed, try value.wait(t.io, ticket, .none));
        try t.expectEqual(1, durable);
    }
}

test "notification tickets bound active waits reject ABA and preserve absolute deadlines" {
    const t = std.testing;
    var probe: @import("transit_memory").AllocationProbe = .{ .parent = t.allocator };
    var value = try Self.init(probe.allocator(), 1);
    defer value.deinit(t.io) catch unreachable;
    probe.begin(true);
    const old = try value.register(t.io);
    try t.expectError(error.NotificationCapacityExceeded, value.register(t.io));
    try t.expectError(error.NotificationTicketsOutstanding, value.deinit(t.io));
    try value.release(t.io, old);
    const ticket = try value.register(t.io);
    try t.expectEqual(old.slot, ticket.slot);
    try t.expectError(error.StaleNotificationTicket, value.wait(t.io, old, .none));
    try t.expectError(error.StaleNotificationTicket, value.release(t.io, old));
    const deadline: std.Io.Timeout = .{ .deadline = .now(t.io, .awake) };
    try t.expectEqual(.timeout, try value.wait(t.io, ticket, deadline));
    value.notify(t.io);
    try t.expectEqual(.changed, try value.wait(t.io, ticket, deadline));
    try value.release(t.io, ticket);
    for (0..1000) |_| {
        const next = try value.register(t.io);
        value.notify(t.io);
        try t.expectEqual(.changed, try value.wait(t.io, next, .none));
        try value.release(t.io, next);
    }
    try probe.verify();
    value.serial = std.math.maxInt(u64);
    try t.expectError(error.NotificationSerialExhausted, value.register(t.io));
    value.notify(t.io);
    try t.expect(!value.closed);
    value.generation = std.math.maxInt(u64);
    value.notify(t.io);
    try t.expect(value.closed);
    try t.expectError(error.NotificationClosed, value.register(t.io));
}

const Waiter = struct {
    fn run(owner: *Self, io: std.Io, ticket: Ticket, ready: *std.Io.Event) !Outcome {
        ready.set(io);
        return owner.wait(io, ticket, .none);
    }
};
test "broadcast cancellation and closure join bounded waiters without polling" {
    const t = std.testing;
    var value = try Self.init(t.allocator, 2);
    defer value.deinit(t.io) catch unreachable;
    {
        const first = try value.register(t.io);
        defer value.release(t.io, first) catch unreachable;
        const second = try value.register(t.io);
        defer value.release(t.io, second) catch unreachable;
        var ready: std.Io.Event = .unset;
        var first_task = try t.io.concurrent(Waiter.run, .{ &value, t.io, first, &ready });
        defer _ = first_task.cancel(t.io) catch .closed;
        ready.waitUncancelable(t.io);
        var second_ready: std.Io.Event = .unset;
        var second_task = try t.io.concurrent(Waiter.run, .{ &value, t.io, second, &second_ready });
        defer _ = second_task.cancel(t.io) catch .closed;
        second_ready.waitUncancelable(t.io);
        value.notify(t.io);
        try t.expectEqual(.changed, try first_task.await(t.io));
        try t.expectEqual(.changed, try second_task.await(t.io));
    }
    const canceled = try value.register(t.io);
    var cancel_ready: std.Io.Event = .unset;
    var cancel_task = try t.io.concurrent(Waiter.run, .{ &value, t.io, canceled, &cancel_ready });
    cancel_ready.waitUncancelable(t.io);
    try t.expectError(error.Canceled, cancel_task.cancel(t.io));
    try value.release(t.io, canceled);
    const closing = try value.register(t.io);
    defer value.release(t.io, closing) catch unreachable;
    var close_ready: std.Io.Event = .unset;
    var close_task = try t.io.concurrent(Waiter.run, .{ &value, t.io, closing, &close_ready });
    defer _ = close_task.cancel(t.io) catch .closed;
    close_ready.waitUncancelable(t.io);
    value.close(t.io);
    try t.expectEqual(.closed, try close_task.await(t.io));
    try t.expectError(error.NotificationClosed, value.register(t.io));
    value.notify(t.io);
}
