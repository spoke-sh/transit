//! Explicit host namespace operations and native policy preparation. Returned
//! bindings/records are saved work; no read or compilation submits them.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const h = c.DirectTableValues;
const v = c.TableValues;
const w = c.DirectTableProtocol;
const n = c.DirectNamespace;
const Allocator = std.mem.Allocator;
pub const NamespaceBinding = struct {
    definition: p.Growth.Definition,
    connection: h.Connection,
    operation: []const u8,
    namespace: u64,
    expected: ?v.Namespace,
    action: union(enum) { create: struct { name: []const u8, owner: u64 }, rename: []const u8, drop },
    pub fn native(self: NamespaceBinding) !n.Binding {
        const result: n.Binding = .{ .definition = self.definition, .connection = try self.connection.native(), .operation = try v.unsigned(self.operation), .namespace = self.namespace, .expected = if (self.expected) |value| .{ .scope = try value.scope.native(), .id = value.id, .authorization = value.authorization, .name = try .init(value.name), .revision = value.revision, .retired = value.retired } else null, .action = switch (self.action) {
            .create => |value| .{ .create = .{ .name = try .init(value.name), .owner = value.owner } },
            .rename => |name| .{ .rename = try .init(name) },
            .drop => .drop,
        } };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: Allocator, value: n.Binding) !NamespaceBinding {
        try value.validate();
        return .{ .definition = value.definition, .connection = try h.Connection.foreign(allocator, value.connection), .operation = try v.decimal(allocator, value.operation), .namespace = value.namespace, .expected = if (value.expected) |found| try v.Namespace.foreign(allocator, found) else null, .action = switch (value.action) {
            .create => |found| .{ .create = .{ .name = try allocator.dupe(u8, found.name.slice()), .owner = found.owner } },
            .rename => |name| .{ .rename = try allocator.dupe(u8, name.slice()) },
            .drop => .drop,
        } };
    }
    fn check(self: NamespaceBinding, connection: w.Connection) !n.Binding {
        const result = try self.native();
        if (!std.meta.eql(result.connection, connection)) return error.CatalogIdentityConflict;
        return result;
    }
};
pub const PolicyPlan = struct {
    definition: p.Growth.Definition,
    connection: h.Connection,
    role: u64,
    expected_revision: u64,
    action: union(enum) { authorization: p.Authorization.Action, set_role: ?u64 },
    fn validate(self: PolicyPlan, connection: w.Connection) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (!std.meta.eql(try self.connection.native(), connection)) return error.CatalogIdentityConflict;
        if (connection.role) |selected| if (selected != self.role) return error.InvalidAuthorizationPlan;
        const plan: c.AuthorizationSql.Plan = .{ .definition = self.definition, .scope = connection.scope, .principal = connection.principal, .role = self.role, .expected_revision = self.expected_revision, .action = switch (self.action) {
            .authorization => |value| .{ .authorization = value },
            .set_role => |value| .{ .set_role = value },
        } };
        try plan.validate();
    }
};
pub const Action = union(enum) {
    compile_namespace: struct {
        pub const json_schema_text_bounds = .{ .sql = 4096 };
        namespace: u64,
        operation: []const u8,
        create_namespace: ?u64,
        sql: []const u8,
    },
    preview_namespace: NamespaceBinding,
    namespace_operation: struct { binding: NamespaceBinding, command: n.Command, steps: u16 },
    compile_policy: struct {
        pub const json_schema_text_bounds = .{ .sql = 4096 };
        namespace: u64,
        sql: []const u8,
    },
    prepare_policy: PolicyPlan,
};
pub const NamespaceOperation = struct {
    binding: NamespaceBinding,
    position: h.Position,
    phase: @FieldType(n.Operation, "phase"),
    reason: n.Reason,
    after: ?[]const u8,
    resulting: ?v.Namespace,
};
pub const Result = union(enum) {
    namespace_binding: NamespaceBinding,
    namespace_preview: struct { binding: NamespaceBinding, position: h.Position, current: ?v.Namespace, reason: n.Reason },
    namespace_observation: union(enum) { not_observed, operation: NamespaceOperation },
    policy_plan: PolicyPlan,
    policy_prepared: c.station.client.AuthorizationChange.Client.Prepared,
};
pub fn apply(allocator: Allocator, client: c.DirectTableClient, action: Action, location: ?*c.fuze.Sql.Location) !Result {
    switch (action) {
        .compile_namespace => |input| {
            const plan = try c.DirectAuthorizationSql.prepareNamespace(client, input.namespace, input.sql, .{}, location);
            if ((plan.action == .create) != (input.create_namespace != null)) return error.InvalidDirectCatalogOperation;
            const binding = try plan.bind(try v.unsigned(input.operation), input.create_namespace);
            return .{ .namespace_binding = try NamespaceBinding.foreign(allocator, binding) };
        },
        .preview_namespace => |input| {
            const response = try client.call(.{ .namespace_preview = try input.check(client.connection) });
            defer response.deinit();
            const value = response.value.result.namespace_preview;
            return .{ .namespace_preview = .{ .binding = try NamespaceBinding.foreign(allocator, value.binding), .position = try h.Position.foreign(allocator, value.position), .current = if (value.current) |found| try v.Namespace.foreign(allocator, found) else null, .reason = value.reason } };
        },
        .namespace_operation => |input| {
            const response = try client.call(.{ .namespace_operation = .{ .binding = try input.binding.check(client.connection), .command = input.command, .steps = input.steps } });
            defer response.deinit();
            return .{ .namespace_observation = switch (response.value.result.namespace_operation) {
                .not_observed => .not_observed,
                .operation => |value| .{ .operation = .{ .binding = try NamespaceBinding.foreign(allocator, value.binding), .position = try h.Position.foreign(allocator, value.position), .phase = value.phase, .reason = value.reason, .after = if (value.after) |after| try v.decimal(allocator, after) else null, .resulting = if (value.resulting) |found| try v.Namespace.foreign(allocator, found) else null } },
            } };
        },
        .compile_policy => |input| {
            const plan = try c.DirectAuthorizationSql.compile(client, input.namespace, input.sql, .{}, location);
            return .{ .policy_plan = .{ .definition = plan.definition, .connection = try h.Connection.foreign(allocator, client.connection), .role = plan.role, .expected_revision = plan.expected_revision, .action = switch (plan.action) {
                .authorization => |value| .{ .authorization = value },
                .set_role => |value| .{ .set_role = value },
                .schema => return error.UnsupportedDirectSchemaAdministration,
            } } };
        },
        .prepare_policy => |plan| {
            try plan.validate(client.connection);
            if (plan.action != .authorization) return error.InvalidAuthorizationPlan;
            // Freeze the originally selected role, then let the native owner
            // check current selection eligibility and the exact policy basis.
            const change: c.station.client.AuthorizationChange.Client = .{ .authority = .{ .transport = client.authority, .realm = client.connection.scope.realm, .principal = client.connection.principal, .role = plan.role, .key = client.key } };
            return .{ .policy_prepared = try change.prepare(plan.expected_revision, plan.action.authorization) };
        },
    }
}

test "direct namespace host bindings preserve exact full-width operation recovery" {
    const t = std.testing;
    const original: n.Binding = .{ .definition = p.Growth.current_definition, .connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = std.math.maxInt(u64) }, .branch = 1, .principal = 4, .role = null, .audience = 5 }, .operation = std.math.maxInt(u64), .namespace = 43, .expected = null, .action = .{ .create = .{ .name = try .init("host_namespace"), .owner = 1 } } };
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const converted = try NamespaceBinding.foreign(arena.allocator(), original);
    try t.expectEqualDeep(original, try converted.native());
    const bytes = try p.Json.valueAlloc(arena.allocator(), converted);
    const parsed = try p.Json.parseFromSliceOwned(NamespaceBinding, t.allocator, bytes);
    defer parsed.deinit();
    _ = arena.reset(.free_all);
    try t.expectEqualDeep(original, try parsed.value.check(original.connection));
    var other = original.connection;
    other.principal += 1;
    try t.expectError(error.CatalogIdentityConflict, parsed.value.check(other));
}
