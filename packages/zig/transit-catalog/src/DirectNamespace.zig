//! Exact namespace intent and catalog-owned acceptance. Native objects remain
//! the current permission authority, including after logical retirement.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const a = c.TableAuthority;

pub const Binding = struct {
    definition: p.Growth.Definition,
    connection: c.DirectTableProtocol.Connection,
    operation: u64,
    namespace: u64,
    expected: ?a.Schema,
    action: union(enum) { create: struct { name: a.Name, owner: u64 }, rename: a.Name, drop },

    pub fn identity(self: Binding) d.Operation {
        return .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = self.operation };
    }
    pub fn validate(self: Binding) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.identity().validate();
        try c.Model.nativeId(self.namespace);
        if ((self.action == .create) != (self.expected == null)) return error.InvalidDirectCatalogOperation;
        if (self.expected) |expected| {
            try expected.validate();
            if (expected.id != self.namespace or expected.retired or !std.meta.eql(expected.scope, self.connection.scope)) return error.InvalidDirectCatalogOperation;
        }
        switch (self.action) {
            .create => |value| {
                try value.name.validate();
                try p.Authorization.roleId(value.owner);
            },
            .rename => |value| try value.validate(),
            .drop => {},
        }
    }
    pub fn proposedName(self: Binding) a.Name {
        return switch (self.action) {
            .create => |value| value.name,
            .rename => |value| value,
            .drop => self.expected.?.name,
        };
    }
    pub fn requireSame(self: Binding, other: Binding) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
};
pub const Command = enum { inspect, admit, execute, cancel };
pub const Reason = enum { none, name_conflict, object_conflict, stale_definition, dependency };
pub const Operation = struct {
    binding: Binding,
    position: d.Position,
    phase: enum { admitted, applied, rejected, cancelled },
    reason: Reason,
    /// A bounded DROP scan resumes only while its namespace admission fence is
    /// retained. This cursor never certifies a complete catalog observation.
    after: ?u64,
    resulting: ?a.Schema,
    pub fn validate(self: Operation) !void {
        try self.binding.validate();
        try self.position.validate();
        if (self.position.next_lsn == 0 or (self.phase == .rejected) != (self.reason != .none) or
            (self.phase == .applied) != (self.resulting != null) or
            (self.after != null and (self.phase != .admitted or self.binding.action != .drop))) return error.InvalidDirectCatalogOperation;
        if (self.after) |after| if (after == 0) return error.InvalidDirectCatalogOperation;
        if (self.resulting) |result| {
            try result.validate();
            if (result.id != self.binding.namespace or !std.meta.eql(result.scope, self.binding.connection.scope) or
                result.retired != (self.binding.action == .drop) or !std.meta.eql(result.name, self.binding.proposedName()) or
                result.revision != (if (self.binding.expected) |expected| try std.math.add(u64, expected.revision, 1) else @as(u64, 1))) return error.InvalidDirectCatalogOperation;
            if (self.binding.expected) |expected| if (result.authorization != expected.authorization) return error.InvalidDirectCatalogOperation;
        }
    }
};
pub const Observation = union(enum) { not_observed, operation: Operation };
pub const Preview = struct { binding: Binding, position: d.Position, current: ?a.Schema, reason: Reason };
pub const Name = struct { namespace: u64, name: a.Name };
