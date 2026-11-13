//! An owned transaction context over the shared database lifecycle. No actor,
//! scheduler, background retry or automatic rollback is involved.
const std = @import("std");
const c = @import("transit_catalog");
const Session = c.DirectTransactionSession;
const Self = @This();
pub const State = Session.State;
pub const Journal = Session.Journal;
pub const Event = Session.Event;
pub const Action = Session.Action;
pub const Result = Session.Result;
pub const Write = Session.Write;

state: State,
journal: Journal,
allocator: ?std.mem.Allocator,
targets: ?[]c.protocol.Transaction.Target,
busy: std.atomic.Value(bool) = .init(false),

/// Copies the only borrowed part of State. The journal and its storage must
/// outlive this context. Construction and deinitialization perform no I/O.
pub fn init(allocator: std.mem.Allocator, state: State, journal: Journal) !Self {
    try state.validate();
    var result = try borrowed(state, journal);
    if (state.begin.selection == .explicit_objects) {
        const targets = try allocator.dupe(c.protocol.Transaction.Target, state.begin.selection.explicit_objects);
        result.state.begin.selection = .{ .explicit_objects = targets };
        result.targets = targets;
    }
    result.allocator = allocator;
    return result;
}
/// Embedding hosts may lend an already-owned Begin target slice. Its lifetime
/// includes every call; this avoids allocating a new arena for each actor turn.
pub fn borrowed(state: State, journal: Journal) !Self {
    try state.validate();
    return .{ .state = state, .journal = journal, .allocator = null, .targets = null };
}
pub fn deinit(self: *Self) void {
    std.debug.assert(!self.busy.load(.acquire));
    if (self.targets) |targets| self.allocator.?.free(targets);
    self.* = undefined;
}
/// Context.callTransaction owns transport admission. Native embedding hosts
/// can supply their existing signed client; both use this same implementation.
pub fn apply(self: *Self, client: c.DirectTableClient, action: Action) !Result {
    if (self.busy.swap(true, .acquire)) return error.Busy;
    defer self.busy.store(false, .release);
    return (Session{ .state = &self.state, .journal = self.journal }).apply(client, action);
}
pub fn privateClient(self: *Self, client: c.DirectTableClient) !c.DirectTableClient {
    if (self.busy.swap(true, .acquire)) return error.Busy;
    defer self.busy.store(false, .release);
    try self.state.validate();
    if (self.state.statement != null or self.state.control != null) return error.TransactionSessionPending;
    if (self.state.command != null) return error.TransactionSessionSettling;
    return Session.privateClient(client, self.state.begin.key);
}
