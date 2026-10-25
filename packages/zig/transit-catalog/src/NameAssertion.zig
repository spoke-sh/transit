//! Durable conditional DDL evidence when no Table mutation is required. The
//! catalog acceptance position belongs to the name assertion, not a Table root.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;

pub const Binding = struct {
    definition: p.Growth.Definition,
    connection: c.DirectTableProtocol.Connection,
    operation: u64,
    namespace: u64,
    name: c.TableAuthority.Name,
    action: enum { create_if_not_exists, drop_if_exists },
    expected: ?d.Definition,
    /// Commitment to the complete proposed SQL/typed declaration, including
    /// its schema even when an existing object makes creation unnecessary.
    intent: [32]u8,

    pub fn identity(self: Binding) d.Operation {
        return .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = self.operation };
    }
    pub fn validate(self: Binding) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.identity().validate();
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        if ((self.action == .create_if_not_exists) != (self.expected != null) or std.mem.allEqual(u8, &self.intent, 0)) return error.InvalidCatalogAssertion;
        if (self.expected) |expected| {
            try expected.validate();
            try self.connection.object(expected.object);
        }
    }
    pub fn requireSame(self: Binding, other: Binding) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
};
pub const Command = enum { inspect, accept, cancel };
pub const Outcome = struct {
    binding: Binding,
    position: d.Position,
    state: enum { unchanged, rejected, cancelled },
    reason: enum { none, condition_changed },
    pub fn validate(self: Outcome) !void {
        try self.binding.validate();
        try self.position.validate();
        if (self.position.next_lsn == 0 or (self.state == .rejected) != (self.reason != .none)) return error.InvalidCatalogAssertion;
    }
};
pub const Observation = union(enum) { not_observed, outcome: Outcome };
pub const Preview = struct {
    binding: Binding,
    position: d.Position,
    current: ?d.Definition,
    matches: bool,
};

test "catalog name assertions distinguish absent names from exact existing definitions" {
    const t = std.testing;
    const scope: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    var absent: Binding = .{ .definition = p.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 4, .principal = 5, .role = null }, .operation = 7, .namespace = 1, .name = try .init("events"), .action = .drop_if_exists, .expected = null, .intent = @splat(9) };
    try absent.validate();
    var present = absent;
    present.action = .create_if_not_exists;
    try t.expectError(error.InvalidCatalogAssertion, present.validate());
    present.expected = .{ .object = .{ .scope = scope, .branch = 1, .object = 8 }, .revision = 1, .digest = @splat(11) };
    try present.validate();
    try t.expectError(error.DataIdentityConflict, absent.requireSame(present));
    var changed = present;
    changed.expected.?.object.object += 1;
    try t.expectError(error.DataIdentityConflict, present.requireSame(changed));
    changed = present;
    changed.intent[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, present.requireSame(changed));
    changed = absent;
    changed.connection.role = 0;
    try t.expectError(error.DataIdentityConflict, absent.requireSame(changed));
    const cancelled: Outcome = .{ .binding = absent, .position = .{ .partition = 1, .next_lsn = 2 }, .state = .cancelled, .reason = .none };
    try cancelled.validate();
    absent.expected = present.expected;
    try t.expectError(error.InvalidCatalogAssertion, absent.validate());
}
