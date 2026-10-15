//! Resolve selected SQL administration to the same owned typed actions used by
//! native callers. Compilation and name lookup never publish a policy change.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const a = p.Authorization;
const syntax = c.fuze.AuthorizationSql;
pub const Identity = struct { operation: u64 = 0, schema: ?u64 = null };
pub const Action = union(enum) { authorization: a.Action, schema: c.SchemaCatalog.Request, set_role: ?u64 };
pub const Plan = struct {
    definition: p.Growth.Definition,
    scope: c.Model.Scope,
    principal: u64,
    role: u64,
    expected_revision: u64,
    action: Action,
    pub fn validate(self: Plan) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.scope.validate();
        if (self.principal > p.max_counter) return error.InvalidAuthorizationPlan;
        try a.roleId(self.role);
        try a.revision(self.expected_revision);
        switch (self.action) {
            .authorization => |value| try a.validateQuery(.{ .kind = .{ .preview = .{ .expected_revision = self.expected_revision, .action = value } } }),
            .schema => |value| {
                try value.validate();
                if (value.principal != self.principal or !std.meta.eql(value.scope, self.scope)) return error.InvalidAuthorizationPlan;
            },
            .set_role => |value| if (value) |role| try a.roleId(role),
        }
    }
};

pub fn privileges(value: syntax.Privileges, kind: syntax.Kind) !u64 {
    const mask = try value.forKind(kind);
    var result: u64 = 0;
    inline for (.{ .{ syntax.Privilege.connect, c.TableAuthority.connect }, .{ syntax.Privilege.usage, c.TableAuthority.usage }, .{ syntax.Privilege.create, c.TableAuthority.create }, .{ syntax.Privilege.select, c.TableAuthority.select }, .{ syntax.Privilege.insert, c.TableAuthority.insert }, .{ syntax.Privilege.update, c.TableAuthority.update }, .{ syntax.Privilege.delete, c.TableAuthority.delete } }) |mapping| {
        if (mask & syntax.bit(mapping[0]) != 0) result |= mapping[1];
    }
    return result;
}
fn behavior(value: syntax.Behavior) a.RevokeBehavior {
    return if (value == .cascade) .cascade else .restrict;
}
fn option(value: ?syntax.Option) ?a.MembershipOption {
    return if (value) |which| switch (which) {
        .admin => .admin,
        .inherit => .inherit,
        .set => .set,
    } else null;
}

/// Resolver owns current identity, scoped object visibility and a single policy
/// basis. Its result is entirely owned; no SQL arena slice survives lowering.
pub fn lower(statement: syntax.Statement, resolver: anytype, identity: Identity) !Action {
    return switch (statement) {
        .create_role => |value| .{ .authorization = .{ .create_role = .{ .name = try p.Value.init(value.name), .login = value.options.login orelse false, .create_role = value.options.create_role orelse false } } },
        .alter_role => |value| .{ .authorization = .{ .alter_role = .{ .id = try resolver.role(.{ .named = value.name }), .login = value.options.login, .create_role = value.options.create_role } } },
        .rename_role => |value| .{ .authorization = .{ .alter_role = .{ .id = try resolver.role(.{ .named = value.name }), .name = try p.Value.init(value.to) } } },
        .drop_role => |name| .{ .authorization = .{ .retire_role = .{ .id = try resolver.role(.{ .named = name }) } } },
        .membership => |value| .{ .authorization = .{ .membership = .{ .member = try resolver.role(value.member), .role = try resolver.role(.{ .named = value.role }), .admin = value.admin, .inherit = value.inherit, .set = value.set } } },
        .revoke_membership => |value| .{ .authorization = .{ .revoke_role = .{ .member = try resolver.role(value.member), .role = try resolver.role(.{ .named = value.role }), .option = option(value.option), .behavior = behavior(value.behavior) } } },
        .grant => |value| result: {
            const mask = try privileges(value.privileges, value.object.kind);
            break :result .{ .authorization = .{ .grant = .{ .object = try resolver.object(value.object), .grantee = try resolver.role(value.grantee), .privileges = mask, .grant_options = if (value.grant_option) mask else 0 } } };
        },
        .revoke => |value| .{ .authorization = .{ .revoke_privileges = .{ .object = try resolver.object(value.grant.object), .grantee = try resolver.role(value.grant.grantee), .privileges = try privileges(value.grant.privileges, value.grant.object.kind), .grant_option_only = value.option_only, .behavior = behavior(value.behavior) } } },
        .default_grant => |value| result: {
            const mask = try privileges(value.privileges, .table);
            break :result .{ .authorization = .{ .default_grant = .{ .creator = try resolver.role(value.creator), .schema = try resolver.object(.{ .kind = .schema, .name = .{ .name = value.schema } }), .domain = resolver.description.configuration.authority.table_domain, .grantee = try resolver.role(value.grantee), .privileges = mask, .grant_options = if (value.grant_option) mask else 0 } } };
        },
        .default_revoke => |value| .{ .authorization = .{ .revoke_defaults = .{ .creator = try resolver.role(value.defaults.creator), .schema = try resolver.object(.{ .kind = .schema, .name = .{ .name = value.defaults.schema } }), .domain = resolver.description.configuration.authority.table_domain, .grantee = try resolver.role(value.defaults.grantee), .privileges = try privileges(value.defaults.privileges, .table), .grant_option_only = value.option_only } } },
        .transfer => |value| .{ .authorization = .{ .transfer_object = .{ .object = try resolver.object(value.object), .owner = try resolver.role(value.owner) } } },
        .set_role => |name| result: {
            const selected = if (name) |value| try resolver.role(.{ .named = value }) else null;
            try resolver.select(selected);
            break :result .{ .set_role = selected };
        },
        .create_schema => |value| .{ .schema = .{ .scope = resolver.description.configuration.scope, .principal = resolver.description.subject.principal, .operation = identity.operation, .schema = identity.schema orelse return error.SchemaIdentityRequired, .expected_revision = 0, .action = .{ .create = .{ .name = try .init(value.name), .owner = try resolver.role(value.owner) } } } },
        .rename_schema => |value| result: {
            const namespace = try resolver.namespace(value.name);
            break :result .{ .schema = .{ .scope = namespace.scope, .principal = resolver.description.subject.principal, .operation = identity.operation, .schema = namespace.id, .expected_revision = namespace.revision, .action = .{ .rename = try .init(value.to) } } };
        },
        .drop_schema => |name| result: {
            const namespace = try resolver.namespace(name);
            break :result .{ .schema = .{ .scope = namespace.scope, .principal = resolver.description.subject.principal, .operation = identity.operation, .schema = namespace.id, .expected_revision = namespace.revision, .action = .drop } };
        },
    };
}

const Resolver = struct {
    allocator: std.mem.Allocator,
    client: *c.TableClient,
    description: c.TableClient.Description,
    authority: c.TableAuthority.Context,
    fn revision(self: *Resolver, value: u64) !void {
        if (value != self.description.authorization_revision) return error.StaleAuthorizationRevision;
    }
    fn role(self: *Resolver, value: syntax.Role) !u64 {
        return switch (value) {
            .public => a.public_role,
            .current_role => self.description.subject.role,
            .session_user => self.description.subject.login_role,
            .named => |name| result: {
                const response = try self.authority.client.read(.{ .resolve = try p.Value.init(name) });
                try self.revision(response.body.authorization.revision);
                break :result response.body.authorization.body.resolve.id;
            },
        };
    }
    fn namespace(self: *Resolver, name: []const u8) !c.TableAuthority.Schema {
        return (try self.client.schema(try .init(name))) orelse error.CatalogSchemaMissing;
    }
    fn object(self: *Resolver, value: syntax.Object) !a.ObjectRef {
        return switch (value.kind) {
            .database => result: {
                if (value.name.schema != null or !std.mem.eql(u8, value.name.name, self.description.configuration.database_name.slice())) return error.CatalogDatabaseMismatch;
                break :result c.TableAuthority.reference(self.description.configuration.authority.database);
            },
            .schema => c.TableAuthority.reference((try self.namespace(value.name.name)).authorization),
            .table => result: {
                var selected = self.client.*;
                if (value.name.schema) |name| selected.connection.namespace = (try self.namespace(name)).id;
                var table = (try selected.lookup(self.allocator, try .init(value.name.name))) orelse return error.TableNotFound;
                defer table.deinit();
                break :result c.TableAuthority.reference(table.authority.authorization);
            },
        };
    }
    fn select(self: *Resolver, selected: ?u64) !void {
        var guard = try c.TableAuthority.guard(self.authority.subject, self.description.configuration.authority, null, null, .database);
        guard.selectable = selected orelse self.description.subject.login_role;
        const response = try self.authority.observe(guard);
        try self.revision(response.body.authorization.revision);
    }
};

pub fn compile(client: *c.TableClient, allocator: std.mem.Allocator, text: []const u8, identity: Identity, location: ?*c.fuze.Sql.Location) !Plan {
    var parsed = try syntax.compile(allocator, text, location);
    defer parsed.deinit();
    var resolver: Resolver = .{ .allocator = allocator, .client = client, .description = try client.describeDatabase(), .authority = try client.authorizationContext() };
    const action = try lower(parsed.statement, &resolver, identity);
    if (action == .schema) try action.schema.validate();
    const current = try resolver.authority.client.read(.identity);
    try resolver.revision(current.body.authorization.revision);
    const plan: Plan = .{ .definition = p.Growth.current_definition, .scope = client.connection.scope, .principal = resolver.description.subject.principal, .role = resolver.description.subject.role, .expected_revision = resolver.description.authorization_revision, .action = action };
    try plan.validate();
    return plan;
}

test "SQL administration resolves stable actions with distinct session and active roles" {
    const t = std.testing;
    const Fake = struct {
        description: c.TableClient.Description = .{
            .configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .administrator = 17, .authority = c.testing.Authority.profile, .database_name = c.TableAuthority.Name.init("test") catch unreachable, .table_limits = .{ .record_bytes = 4096, .staging_bytes = 8192, .staging_records = 2 } },
            .subject = .{ .principal = 17, .login_role = 8, .role = 7, .credential_epoch = 1, .audience = 3, .context = @splat(0) },
            .authorization_revision = 10,
            .resource_revision = 20,
        },
        selected: ?u64 = null,
        fn role(_: *@This(), value: syntax.Role) !u64 {
            return switch (value) {
                .public => a.public_role,
                .current_role => 7,
                .session_user => 8,
                .named => |name| if (std.mem.eql(u8, name, "reader")) 9 else error.UnknownAuthorizationRole,
            };
        }
        fn object(_: *@This(), value: syntax.Object) !a.ObjectRef {
            return .{ .kind = .domain, .id = if (value.kind == .schema) 60 else 42 };
        }
        fn namespace(self: *@This(), name: []const u8) !c.TableAuthority.Schema {
            if (!std.mem.eql(u8, name, "sales")) return error.CatalogSchemaMissing;
            return .{ .scope = self.description.configuration.scope, .id = 6, .authorization = 60, .name = try .init(name), .revision = 3 };
        }
        fn select(self: *@This(), value: ?u64) !void {
            self.selected = value;
        }
    };
    const Case = struct { sql: []const u8, expected: a.Action };
    const cases = [_]Case{
        .{ .sql = "GRANT SELECT, UPDATE ON TABLE sales.orders TO reader WITH GRANT OPTION", .expected = .{ .grant = .{ .object = .{ .kind = .domain, .id = 42 }, .grantee = 9, .privileges = 5, .grant_options = 5 } } },
        .{ .sql = "REVOKE GRANT OPTION FOR SELECT ON orders FROM reader CASCADE", .expected = .{ .revoke_privileges = .{ .object = .{ .kind = .domain, .id = 42 }, .grantee = 9, .privileges = 1, .grant_option_only = true, .behavior = .cascade } } },
        .{ .sql = "GRANT reader TO SESSION_USER WITH INHERIT FALSE", .expected = .{ .membership = .{ .member = 8, .role = 9, .inherit = false } } },
        .{ .sql = "GRANT USAGE ON SCHEMA sales TO CURRENT_ROLE", .expected = .{ .grant = .{ .object = .{ .kind = .domain, .id = 60 }, .grantee = 7, .privileges = 1 } } },
        .{ .sql = "ALTER DEFAULT PRIVILEGES IN SCHEMA sales GRANT SELECT ON TABLES TO PUBLIC", .expected = .{ .default_grant = .{ .creator = 7, .schema = .{ .kind = .domain, .id = 60 }, .domain = 3, .grantee = a.public_role, .privileges = 1 } } },
    };
    var resolver: Fake = .{};
    for (cases) |case| {
        var parsed = try syntax.compile(t.allocator, case.sql, null);
        defer parsed.deinit();
        try t.expectEqualDeep(case.expected, (try lower(parsed.statement, &resolver, .{})).authorization);
    }
    var rename = try syntax.compile(t.allocator, "ALTER SCHEMA sales RENAME TO accounts", null);
    defer rename.deinit();
    const renamed = (try lower(rename.statement, &resolver, .{ .operation = 95 })).schema;
    try t.expectEqual(@as(u64, 6), renamed.schema);
    try t.expectEqual(@as(u64, 3), renamed.expected_revision);
    try t.expectEqualStrings("accounts", renamed.action.rename.slice());
    var selected = try syntax.compile(t.allocator, "SET ROLE reader", null);
    defer selected.deinit();
    try t.expectEqual(@as(?u64, 9), (try lower(selected.statement, &resolver, .{})).set_role);
    try t.expectEqual(@as(?u64, 9), resolver.selected);
    try t.expectEqual(@as(u64, 1), try privileges(.{ .all = true }, .database));
    try t.expectEqual(@as(u64, 3), try privileges(.{ .all = true }, .schema));
    try t.expectEqual(@as(u64, 15), try privileges(.{ .all = true }, .table));
    try t.expectError(error.InvalidSqlPrivilege, privileges(.{ .mask = syntax.bit(.connect) }, .table));
}
