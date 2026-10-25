//! Resolve selected SQL administration to the same owned typed actions used by
//! native callers. Compilation and name lookup never publish a policy change.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const a = p.Authorization;
const syntax = c.fuze.AuthorizationSql;
const Resolver = struct {
    allocator: std.mem.Allocator,
    client: *c.TableClient,
    description: c.TableClient.Description,
    authority: c.TableAuthority.Context,
    fn revision(self: *Resolver, value: u64) !void {
        if (value != self.description.authorization_revision) return error.StaleAuthorizationRevision;
    }
    pub fn role(self: *Resolver, value: syntax.Role) !u64 {
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
    pub fn namespace(self: *Resolver, name: []const u8) !c.TableAuthority.Schema {
        return (try self.client.schema(try .init(name))) orelse error.CatalogSchemaMissing;
    }
    pub fn object(self: *Resolver, value: syntax.Object) !a.ObjectRef {
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
    pub fn select(self: *Resolver, selected: ?u64) !void {
        var guard = try c.TableAuthority.guard(self.authority.subject, self.description.configuration.authority, null, null, .database);
        guard.selectable = selected orelse self.description.subject.login_role;
        const response = try self.authority.observe(guard);
        try self.revision(response.body.authorization.revision);
    }
};

pub fn compile(client: *c.TableClient, allocator: std.mem.Allocator, text: []const u8, identity: c.AuthorizationLowering.Identity, location: ?*c.fuze.Sql.Location) !c.AuthorizationLowering.Plan {
    var parsed = try syntax.compile(allocator, text, location);
    defer parsed.deinit();
    var resolver: Resolver = .{ .allocator = allocator, .client = client, .description = try client.describeDatabase(), .authority = try client.authorizationContext() };
    const action = try c.AuthorizationLowering.lower(parsed.statement, &resolver, identity);
    if (action == .schema) try action.schema.validate();
    const current = try resolver.authority.client.read(.identity);
    try resolver.revision(current.body.authorization.revision);
    const plan: c.AuthorizationLowering.Plan = .{ .definition = p.Growth.current_definition, .scope = client.connection.scope, .principal = resolver.description.subject.principal, .role = resolver.description.subject.role, .expected_revision = resolver.description.authorization_revision, .action = action };
    try plan.validate();
    return plan;
}
