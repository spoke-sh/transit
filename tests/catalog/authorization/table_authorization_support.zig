//! Synthetic bootstrap through signed public native authorization operations.
//! These helpers never write catalog/provider records or invent authority IDs.
pub fn login(comptime c: type, admin: anytype, name: []const u8, principal: u64, key: c.protocol.Ed25519.KeyPair, pid: ?u64) !u64 {
    const p = c.protocol;
    const role = (try admin.authorization(.{ .create_role = .{ .name = try p.Value.init(name), .login = true } })).?;
    _ = try admin.authorization(.{ .bind_credential = .{ .principal = principal, .role = role, .public_key = key.public_key.toBytes(), .pid = pid } });
    _ = try admin.authorization(.{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = role, .privileges = p.permission(.inspect) | p.permission(.send) } });
    return role;
}
pub fn profile(comptime c: type, admin: anytype, scope: c.Model.Scope, registrar: u64, owner: u64) !c.TableAuthority.Profile {
    const a = c.TableAuthority;
    const database_domain = (try admin.authorization(.{ .register_domain = .{ .lifetime_resource = scope.resource, .registrar = registrar, .actions = a.connect } })).?;
    const schema_domain = (try admin.authorization(.{ .register_domain = .{ .lifetime_resource = scope.resource, .registrar = registrar, .actions = a.usage | a.create } })).?;
    const table_domain = (try admin.authorization(.{ .register_domain = .{ .lifetime_resource = scope.resource, .registrar = registrar, .actions = a.table_actions } })).?;
    const stream_domain = (try admin.authorization(.{ .register_domain = .{ .lifetime_resource = scope.resource, .registrar = registrar, .actions = a.actions(.stream) } })).?;
    const queue_domain = (try admin.authorization(.{ .register_domain = .{ .lifetime_resource = scope.resource, .registrar = registrar, .actions = a.actions(.queue) } })).?;
    const database = (try admin.authorization(.{ .register_object = .{ .domain = database_domain, .owner = owner, .binding = try a.binding(scope, .database, 0) } })).?;
    const schema = (try admin.authorization(.{ .register_object = .{ .domain = schema_domain, .owner = owner, .schema = a.reference(database), .binding = try a.binding(scope, .schema, 1) } })).?;
    return .{ .database_domain = database_domain, .schema_domain = schema_domain, .table_domain = table_domain, .stream_domain = stream_domain, .queue_domain = queue_domain, .database = database, .initial_schema = 1, .initial_schema_authority = schema };
}
pub fn loginRole(comptime c: type, wire: *c.client.Client, realm: u64, principal: u64, key: c.protocol.Ed25519.KeyPair) !u64 {
    const client: c.client.AuthorizationClient = .{ .transport = wire, .realm = realm, .principal = principal, .key = key };
    return (try client.read(.identity)).body.authorization.body.identity.login_role;
}
pub fn grantDefaults(comptime c: type, admin: anytype, authority: c.TableAuthority.Profile, creator: u64, grantee: u64, privileges: u64) !void {
    const a = c.TableAuthority;
    _ = try admin.authorization(.{ .grant = .{ .object = a.reference(authority.database), .grantee = grantee, .privileges = a.connect } });
    _ = try admin.authorization(.{ .grant = .{ .object = a.reference(authority.initial_schema_authority), .grantee = grantee, .privileges = a.usage } });
    _ = try admin.authorization(.{ .default_grant = .{ .creator = creator, .schema = a.reference(authority.initial_schema_authority), .domain = authority.table_domain, .grantee = grantee, .privileges = privileges } });
}
pub fn tablePrivileges(comptime c: type, admin: anytype, configuration: anytype, object: u64, grantee: u64, privileges: u64, allow: bool) !void {
    const binding = try c.TableAuthority.binding(configuration.scope, .table, object);
    const target = (try admin.query(.{ .authorization = .{ .kind = .{ .binding = .{ .domain = configuration.authority.table_domain, .key = binding } } } })).body.authorization.body.binding orelse return error.MissingProofTable;
    _ = try admin.authorization(if (allow) .{ .grant = .{ .object = target.reference, .grantee = grantee, .privileges = privileges } } else .{ .revoke_privileges = .{ .object = target.reference, .grantee = grantee, .privileges = privileges, .behavior = .cascade } });
}
