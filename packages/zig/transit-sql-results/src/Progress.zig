//! Deterministic logical progress. Adapters erase transport repeats before
//! receiving rows. Resource release and a successful terminal are distinct.
const std = @import("std");
const r = @import("root.zig");
const Self = @This();
identity: r.Identity,
received: u64 = 0,
delivered: u64 = 0,
outcome: union(enum) { open, complete: r.Completion, failed, cancelled } = .open,
consumption: enum { reading, exhausted, stopped } = .reading,
released: bool = false,

fn same(self: Self, identity: r.Identity) !void {
    if (!std.meta.eql(self.identity, identity)) return error.ResultIdentityChanged;
}
pub fn receive(self: *Self, identity: r.Identity, rows: u64) !void {
    try self.same(identity);
    if (self.released or self.consumption != .reading or self.outcome != .open or rows == 0) return error.InvalidResultTransition;
    self.received = std.math.add(u64, self.received, rows) catch return error.ResultCountOverflow;
}
pub fn deliver(self: *Self, rows: u64) !void {
    if (self.released or self.consumption != .reading or (self.outcome != .open and self.outcome != .complete) or rows == 0 or rows > self.received - self.delivered) return error.InvalidResultTransition;
    self.delivered += rows;
    if (self.outcome == .complete and self.delivered == self.received) self.consumption = .exhausted;
}
pub fn finish(self: *Self, identity: r.Identity, terminal: r.Completion) !void {
    try self.same(identity);
    try terminal.validateShape();
    if (self.released or self.consumption != .reading or self.outcome != .open) return error.InvalidResultTransition;
    if (terminal.rows != self.received) return error.InvalidResultCount;
    self.outcome = .{ .complete = terminal };
    if (self.delivered == self.received) self.consumption = .exhausted;
}
pub fn fail(self: *Self, cancelled: bool) void {
    if (self.outcome == .open) self.outcome = if (cancelled) .cancelled else .failed;
    if (self.consumption == .reading) self.consumption = .stopped;
}
pub fn release(self: *Self) void {
    self.released = true;
    if (self.consumption == .reading) self.consumption = .stopped;
}
pub fn completion(self: Self) ?r.Completion {
    return if (self.outcome == .complete) self.outcome.complete else null;
}
