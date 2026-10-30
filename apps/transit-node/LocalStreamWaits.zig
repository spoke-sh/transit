//! Bounded active wait registrations, independent of durable Stream population.
//! A notification only prompts another currently authorized predicate check.
const std = @import("std");
const c = @import("transit_catalog");
const Notification = @import("transit_io").Notification;
const Self = @This();
pub const capacity = 64;
pub const Ticket = Notification.Ticket;
const Key = struct { object: c.protocol.DataLifecycle.Object, partition: u32 };
const Registration = struct { key: Key, serial: u64 };

allocator: std.mem.Allocator,
io: std.Io,
notification: Notification,
mutex: std.Io.Mutex = .init,
registrations: [capacity]?Registration = @splat(null),

pub fn create(allocator: std.mem.Allocator, io: std.Io) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{ .allocator = allocator, .io = io, .notification = try .init(allocator, capacity) };
    return self;
}
/// The host joins every request before destruction.
pub fn destroy(self: *Self) void {
    self.notification.deinit(self.io) catch unreachable;
    self.allocator.destroy(self);
}
pub fn register(self: *Self, target: c.protocol.StreamQueue.Partition) !Ticket {
    try target.validate();
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const ticket = try self.notification.register(self.io);
    std.debug.assert(self.registrations[ticket.slot] == null);
    self.registrations[ticket.slot] = .{
        .key = .{ .object = target.interpretation.object, .partition = target.partition },
        .serial = ticket.serial,
    };
    return ticket;
}
/// Count active registrations for the stable object/partition, including this
/// ticket. A declaration edit cannot evade its wait budget with another revision.
pub fn count(self: *Self, ticket: Ticket) !u32 {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    if (ticket.owner != &self.notification or ticket.slot >= capacity) return error.StaleNotificationTicket;
    const registration = self.registrations[ticket.slot] orelse return error.StaleNotificationTicket;
    if (registration.serial != ticket.serial) return error.StaleNotificationTicket;
    var total: u32 = 0;
    for (self.registrations) |slot| if (slot) |active| {
        if (std.meta.eql(active.key, registration.key)) total += 1;
    };
    return total;
}
pub fn wait(self: *Self, ticket: Ticket, deadline: std.Io.Timeout) !Notification.Outcome {
    return self.notification.wait(self.io, ticket, deadline);
}
pub fn release(self: *Self, ticket: Ticket) void {
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);
    self.notification.release(self.io, ticket) catch unreachable;
    self.registrations[ticket.slot] = null;
}
pub fn notify(self: *Self) void {
    self.notification.notify(self.io);
}
pub fn close(self: *Self) void {
    self.notification.close(self.io);
}

test "Stream wait registrations use stable partition budgets and retain pre-park publications" {
    const t = std.testing;
    const waits = try Self.create(t.allocator, t.io);
    defer waits.destroy();
    var target: c.protocol.StreamQueue.Partition = .{
        .definition = c.protocol.Growth.current_definition,
        .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(5) },
        .partition = 0,
    };
    const first = try waits.register(target);
    defer waits.release(first);
    target.interpretation.revision += 1;
    const revised = try waits.register(target);
    defer waits.release(revised);
    target.partition = 1;
    const other = try waits.register(target);
    defer waits.release(other);
    try t.expectEqual(@as(u32, 2), try waits.count(first));
    try t.expectEqual(@as(u32, 2), try waits.count(revised));
    try t.expectEqual(@as(u32, 1), try waits.count(other));
    waits.notify();
    try t.expectEqual(Notification.Outcome.changed, try waits.wait(first, .{ .duration = .{ .raw = .fromMilliseconds(1), .clock = .awake } }));
    waits.close();
    try t.expectError(error.NotificationClosed, waits.register(target));
    try t.expectEqual(Notification.Outcome.closed, try waits.wait(revised, .none));
}
