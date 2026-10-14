//! Injected authorization for deterministic tests; not a native authority proof.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const t = std.testing;
const Self = @This();
input: u64 = 1,
rights: std.AutoHashMapUnmanaged(u64, Rights) = .empty,
object_rights: std.AutoHashMapUnmanaged(struct { principal: u64, object: u64 }, u64) = .empty,
bindings: std.AutoHashMapUnmanaged([32]u8, p.Authorization.Object) = .empty,
last_subject: u64 = 17,
pub const profile: c.TableAuthority.Profile = .{ .database_domain = 1, .schema_domain = 2, .table_domain = 3, .database = 4, .initial_schema = 1, .initial_schema_authority = 5 };
/// Injected authorization answers for catalog transition tests. Native graph,
/// signatures and disk enforcement have separate independent integration tests.
pub const Rights = struct {
    principal: u64,
    revision: u64 = 1,
    inspect: bool = true,
    create: bool = true,
    read: bool = true,
    insert: bool = true,
    update: bool = true,
    delete: bool = true,
    alter: bool = true,
    drop: bool = true,
    pub fn administrator(_: c.Model.Scope, principal: u64) !Rights {
        return .{ .principal = principal };
    }
};
pub fn setRights(self: *Self, value: Rights) !void {
    try self.rights.put(t.allocator, value.principal, value);
}
pub fn grantObject(self: *Self, principal: u64, object: u64, privileges: u64) !void {
    try self.object_rights.put(t.allocator, .{ .principal = principal, .object = object }, privileges);
}
pub fn authorizationSubject(self: *Self, who: u64, audience: u64) !p.Authorization.Subject {
    return .{ .accepted = .{ .pid = audience, .input = self.input, .principal = who } };
}
pub fn requireAuthorization(self: *Self, guard: p.Authorization.Guard) !p.Authorization.Verified {
    return (try authorize(self, guard)) orelse error.AccessDenied;
}
pub fn authorize(raw: *anyopaque, guard: p.Authorization.Guard) !?p.Authorization.Verified {
    const self: *Self = @ptrCast(@alignCast(raw));
    const who = guard.subject.principal();
    const rights = self.rights.get(who) orelse if (who == 17 or who == 0) Rights{ .principal = who } else return null;
    if (!self.rights.contains(who)) {
        var registered = self.bindings.valueIterator();
        while (registered.next()) |object| if (object.domain == profile.database_domain and object.owner != who) return null;
    }
    self.last_subject = who;
    for (guard.requirements) |slot| {
        const requirement = slot orelse break;
        if (!rights.inspect) return null;
        const owner = rights.alter and rights.drop;
        if (requirement.access == .ownership) {
            if (!owner) return null;
            continue;
        }
        const allowed: u64 = if (requirement.object.id == profile.database) c.TableAuthority.connect else if (requirement.object.id == profile.initial_schema_authority) c.TableAuthority.usage | (if (rights.create) c.TableAuthority.create else @as(u64, 0)) else self.object_rights.get(.{ .principal = who, .object = requirement.object.id }) orelse (@as(u64, @intFromBool(rights.read)) | (@as(u64, @intFromBool(rights.insert)) << 1) | (@as(u64, @intFromBool(rights.update)) << 2) | (@as(u64, @intFromBool(rights.delete)) << 3));
        const matches = switch (requirement.access) {
            .all => allowed & requirement.privileges == requirement.privileges,
            .any => allowed & requirement.privileges != 0,
            .visible => allowed & requirement.privileges != 0 or owner,
            .ownership => unreachable,
        };
        if (!matches) return null;
    }
    return .{ .principal = who, .role = who, .credential_epoch = 1, .audience = guard.subject.audience(), .context = if (guard.subject == .signed) guard.subject.signed.claim.context else @splat(0) };
}
pub fn binding(raw: *anyopaque, domain: u64, identity: [32]u8) !?p.Authorization.Object {
    const self: *Self = @ptrCast(@alignCast(raw));
    if (self.bindings.get(identity)) |value| return value;
    const id: u64 = if (domain == profile.database_domain) profile.database else if (domain == profile.schema_domain) profile.initial_schema_authority else 100 + self.bindings.count();
    const value: p.Authorization.Object = .{ .reference = c.TableAuthority.reference(id), .domain = domain, .binding = identity, .parent = if (domain == profile.database_domain) null else c.TableAuthority.reference(if (domain == profile.schema_domain) profile.database else profile.initial_schema_authority), .owner = self.last_subject, .registrar = 2, .revision = 1, .actions = if (domain == profile.database_domain) c.TableAuthority.connect else if (domain == profile.schema_domain) c.TableAuthority.usage | c.TableAuthority.create else c.TableAuthority.table_actions };
    try self.bindings.put(t.allocator, identity, value);
    return value;
}
pub fn deinit(self: *Self) void {
    self.rights.deinit(t.allocator);
    self.object_rights.deinit(t.allocator);
    self.bindings.deinit(t.allocator);
}
pub fn clone(self: *Self) !Self {
    var rights = try self.rights.clone(t.allocator);
    errdefer rights.deinit(t.allocator);
    var object_rights = try self.object_rights.clone(t.allocator);
    errdefer object_rights.deinit(t.allocator);
    return .{ .rights = rights, .object_rights = object_rights, .bindings = try self.bindings.clone(t.allocator), .input = self.input, .last_subject = self.last_subject };
}
