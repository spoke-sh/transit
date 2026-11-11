//! Ephemeral test realm provisioning through signed public operations. A failed
//! or uncertain submission aborts this realm; it is never submitted as new work.
const std = @import("std");
const g = @import("transit_sql_service");
const c = g.catalog;
const p = c.protocol;
const n = p.Growth;
pub const caller = 10;
pub const registrar = 26;
pub const realm = 1;
pub const Result = struct { catalog: c.DirectCatalog.Configuration, role: u64 };
const Self = @This();
wire: *g.wire.Client,
root: p.Ed25519.KeyPair,

fn query(self: Self, kind: @FieldType(n.Query, "kind")) !n.Response {
    return self.wire.query(.{ .realm = realm, .principal = 0, .kind = kind }, self.root);
}
fn submit(self: Self, command: n.Command) !u64 {
    const basis = try self.query(.capabilities);
    const signed = try n.sign(.{ .realm = realm, .principal = 0, .sequence = try std.math.add(u64, basis.principal_sequence, 1), .command = command }, self.root);
    return (try self.wire.submit(signed)).position;
}
pub fn authorize(self: Self, action: p.Authorization.Action) !u64 {
    const policy = (try self.query(.{ .authorization = .{ .kind = .identity } })).body.authorization;
    const id = try self.submit(.{ .authorization = .{ .begin = .{ .expected_revision = policy.revision, .action = action } } });
    for (0..1024) |_| {
        const observed = (try self.query(.{ .authorization = .{ .kind = .{ .change = id } } })).body.authorization;
        const change = observed.body.change;
        if (change.status == .published) return change.created_id orelse 0;
        if (change.basis != observed.revision) return error.TestProvisioningConflict;
        _ = try self.submit(.{ .authorization = switch (change.status) {
            .preparing => .{ .advance = id },
            .ready => .{ .publish = id },
            else => return error.TestProvisioningFailed,
        } });
    }
    return error.TestProvisioningBudget;
}
pub fn provision(self: Self, caller_key: p.Ed25519.KeyPair, registrar_key: p.Ed25519.KeyPair) !Result {
    const owner = try self.submit(.{ .spawn = .{} });
    const resource = try self.submit(.{ .create_resource = .{ .writer = owner } });
    _ = try self.submit(.{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = p.State.all_permissions } });
    _ = try self.submit(.{ .create_principal = .{ .subject = registrar, .public_key = registrar_key.public_key.toBytes(), .permissions = p.permission(.inspect) } });
    const role = try self.authorize(.{ .create_role = .{ .name = try .init("test_owner"), .login = true } });
    _ = try self.authorize(.{ .bind_credential = .{ .principal = caller, .role = role, .public_key = caller_key.public_key.toBytes() } });
    _ = try self.authorize(.{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = role, .privileges = p.permission(.inspect) | p.permission(.send) } });
    _ = try self.submit(.{ .grant_resource = .{ .resource = resource, .subject = caller, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    const scope: c.Model.Scope = .{ .realm = realm, .resource = resource, .catalog = 1 };
    var domains: [9]u64 = undefined;
    inline for (.{ .database, .schema, .table, .stream, .queue, .kv, .connection, .source, .sink }, 0..) |kind, i| {
        domains[i] = try self.authorize(.{ .register_domain = .{ .registrar = registrar, .lifetime_resource = resource, .actions = c.TableAuthority.actions(kind) } });
    }
    const database = try self.authorize(.{ .register_object = .{ .domain = domains[0], .owner = role, .binding = try c.TableAuthority.binding(scope, .database, 0) } });
    const schema = try self.authorize(.{ .register_object = .{ .domain = domains[1], .owner = role, .schema = c.TableAuthority.reference(database), .binding = try c.TableAuthority.binding(scope, .schema, 1) } });
    return .{ .role = role, .catalog = .{
        .scope = scope,
        .branch = 1,
        .partition = 1,
        .audience = owner,
        .authority = .{ .database_domain = domains[0], .schema_domain = domains[1], .table_domain = domains[2], .stream_domain = domains[3], .queue_domain = domains[4], .kv_domain = domains[5], .connection_domain = domains[6], .source_domain = domains[7], .sink_domain = domains[8], .database = database, .initial_schema = 1, .initial_schema_authority = schema },
        .database_name = try .init("transit"),
        .initial_schema_name = try .init("public"),
    } };
}
