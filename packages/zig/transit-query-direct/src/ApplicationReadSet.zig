//! Ephemeral evidence for one guard evaluation and its protected operands.
//! The native bounded check_set verifies coexisting public bases; this owner
//! never manufactures a snapshot, pin, dispatch permit or durable read receipt.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const w = c.DirectTableProtocol;
const Self = @This();
pub const limit = w.Action.json_schema_sequence_bounds.check_set;

connection: w.Connection,
checks: [limit]w.ReadCheck = undefined,
count: usize = 0,
policy_revision: ?u64 = null,
sealed: bool = false,

pub fn policy(self: *Self, revision: u64) !void {
    if (revision == 0) return error.TransactionAuthorityChanged;
    if (self.policy_revision) |expected| {
        if (expected != revision) return error.TransactionAuthorityChanged;
    } else self.policy_revision = revision;
}

pub fn add(self: *Self, check: w.ReadCheck, revision: u64) !void {
    try self.connection.validate();
    try self.policy(revision);
    switch (check) {
        .current_state => |state| try state.validate(self.connection.scope, self.connection.branch),
        .current_connector => |connector| try connector.validate(self.connection.scope, self.connection.branch),
        .dependency => |edge| {
            try edge.validate();
            try self.connection.object(edge.source.object);
            try self.connection.object(edge.dependent.interpretation.object);
        },
        else => return error.InvalidTableAccessRequest,
    }
    for (self.checks[0..self.count]) |existing| {
        if (check == .current_state and existing == .current_state and
            std.meta.eql(check.current_state.guard.source.interpretation.object, existing.current_state.guard.source.interpretation.object))
        {
            if (check.current_state.kind != existing.current_state.kind or check.current_state.namespace != existing.current_state.namespace) return error.TransactionConflict;
            // Repeated reads may observe acceptance-only advances. Keep the
            // earliest actual basis; never replace a changed guard with a new cut.
            try existing.current_state.guard.requireUnchanged(check.current_state.guard);
            return;
        }
        if (std.meta.eql(existing, check)) return;
        if (check == .current_connector and existing == .current_connector and
            std.meta.eql(check.current_connector.interpretation.object, existing.current_connector.interpretation.object)) return error.InvalidSourceControl;
    }
    if (self.sealed) return error.TransactionReadChanged;
    if (self.count == self.checks.len) return error.InvalidTableReadBudget;
    self.checks[self.count] = check;
    self.count += 1;
}

/// After sealing, only identical/coherent repetitions of recorded reads may
/// redeem cached operands. New sources require a fresh evaluation and check.
pub fn verify(self: *Self, client: c.DirectTableClient) !void {
    if (client.transaction != null or !std.meta.eql(client.connection, self.connection)) return error.InvalidTransactionGuard;
    if (self.count == 0 or self.policy_revision == null) return error.InvalidTableReadBudget;
    const response = try client.call(.{ .check_set = self.checks[0..self.count] });
    defer response.deinit();
    try self.policy(response.value.policy_revision);
    self.sealed = true;
}

test "application read sets retain earliest bases, authority and finite sealed coverage" {
    const t = std.testing;
    const connection: w.Connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .audience = 4, .principal = 5, .role = 6 };
    var self: Self = .{ .connection = connection };
    const first: w.ReadCheck = .{ .current_state = .{ .namespace = 1, .kind = .table, .guard = .{ .source = .{ .interpretation = .{ .object = .{ .scope = connection.scope, .branch = 1, .object = 7 }, .revision = 1, .digest = @splat(1) }, .accepted = .{ .partition = 3, .next_lsn = 10 } }, .changed_lsn = 8 } } };
    try self.add(first, 4);
    var next = first;
    next.current_state.guard.source.accepted.next_lsn = 12;
    try self.add(next, 4);
    try t.expectEqual(@as(usize, 1), self.count);
    try t.expectEqualDeep(first, self.checks[0]);
    next.current_state.guard.changed_lsn = 11;
    try t.expectError(error.TransactionConflict, self.add(next, 4));
    try t.expectError(error.TransactionAuthorityChanged, self.add(first, 5));
    self.sealed = true;
    try self.add(first, 4);
    next = first;
    next.current_state.guard.source.interpretation.object.object += 1;
    try t.expectError(error.TransactionReadChanged, self.add(next, 4));
    self.sealed = false;
    while (self.count < limit) {
        next.current_state.guard.source.interpretation.object.object = 7 + self.count;
        try self.add(next, 4);
    }
    next.current_state.guard.source.interpretation.object.object += 1;
    try t.expectError(error.InvalidTableReadBudget, self.add(next, 4));
    try t.expectEqual(@as(usize, limit), self.count);
    try t.expectEqualDeep(first, self.checks[0]);
}
