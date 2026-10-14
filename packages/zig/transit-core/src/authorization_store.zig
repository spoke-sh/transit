//! Paged owned policy records. A Snapshot becomes authority only through the
//! native journal; these methods stage private immutable roots, never publish.
const std = @import("std");
const core = @import("root.zig");
const a = core.protocol.Authorization;
const c = core.catalog;
const pages = core.pages;

pub const Snapshot = struct {
    catalog: c.Snapshot,
    revision: u64,
    next_id: u64,
    pub fn validate(self: Snapshot) !void {
        try self.catalog.validate();
        try a.revision(self.revision);
        if (self.next_id == 0 or self.next_id >= a.public_role) return error.InvalidAuthorizationState;
    }
};

pub fn objectKey(reference: a.ObjectRef) !pages.Key {
    try reference.validate();
    return c.key(.authorization_object, @backingInt(reference.kind), reference.id, "");
}
fn idKey(namespace: c.Namespace, id: u64) pages.Key {
    return c.key(namespace, id, 0, "") catch unreachable;
}
fn nameKey(name: core.Value) !pages.Key {
    try a.name(name);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(name.slice(), &hash, .{});
    return c.key(.authorization_name, std.mem.readInt(u64, hash[0..8], .big), std.mem.readInt(u64, hash[8..16], .big), hash[16..]);
}
fn grantNamespace(reference: a.ObjectRef) c.Namespace {
    return switch (reference.kind) {
        .realm => .authorization_realm_grant,
        .process => .authorization_process_grant,
        .resource => .authorization_resource_grant,
        .domain => .authorization_domain_grant,
    };
}
fn grantKey(value: a.Grant) !pages.Key {
    var id: [8]u8 = undefined;
    std.mem.writeInt(u64, &id, value.id, .big);
    return c.key(grantNamespace(value.object), value.object.id, value.grantee, &id);
}

pub fn Store(comptime PageStore: type) type {
    return struct {
        const Self = @This();
        catalog: c.Catalog(PageStore),
        revision: u64,
        next_id: u64,
        pub fn open(page_store: *PageStore, basis: Snapshot) !Self {
            try basis.validate();
            return .{ .catalog = try c.Catalog(PageStore).open(page_store, basis.catalog), .revision = basis.revision, .next_id = basis.next_id };
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{ .catalog = self.catalog.snapshot, .revision = self.revision, .next_id = self.next_id };
        }
        pub fn allocate(self: *Self) !u64 {
            if (self.next_id >= a.public_role - 1) return error.AuthorizationIdentityExhausted;
            const id = self.next_id;
            self.next_id += 1;
            return id;
        }
        fn current(self: *Self, value: anytype) !void {
            try value.validate();
            if (value.revision != self.revision) return error.InvalidAuthorizationRevision;
        }
        pub fn role(self: *Self, id: u64) !?a.Role {
            return self.catalog.get(a.Role, idKey(.authorization_role, id));
        }
        pub fn named(self: *Self, name: core.Value) !?a.Role {
            const id = (try self.catalog.get(u64, try nameKey(name))) orelse return null;
            const value = (try self.role(id)) orelse return error.InvalidAuthorizationState;
            if (!value.name.eql(name) or value.retired) return error.InvalidAuthorizationState;
            return value;
        }
        pub fn putRole(self: *Self, value: a.Role) !void {
            try self.current(value);
            if (try self.named(value.name)) |other| if (other.id != value.id) return error.AuthorizationNameExists;
            if (try self.role(value.id)) |previous| {
                if (previous.retired and !value.retired) return error.RetiredAuthorizationRole;
                if (!previous.name.eql(value.name) or value.retired) try self.catalog.remove(try nameKey(previous.name));
            }
            try self.catalog.put(idKey(.authorization_role, value.id), value);
            if (!value.retired) try self.catalog.put(try nameKey(value.name), value.id);
        }
        pub fn object(self: *Self, reference: a.ObjectRef) !?a.Object {
            return self.catalog.get(a.Object, try objectKey(reference));
        }
        pub fn bound(self: *Self, domain_id: u64, binding: [32]u8) !?a.Object {
            const id = (try self.catalog.get(u64, try c.key(.authorization_binding, domain_id, 0, &binding))) orelse return null;
            const value = (try self.object(.{ .kind = .domain, .id = id })) orelse return error.InvalidAuthorizationState;
            if (value.domain != domain_id or value.binding == null or !std.mem.eql(u8, &value.binding.?, &binding)) return error.InvalidAuthorizationState;
            return value;
        }
        pub fn putObject(self: *Self, value: a.Object) !void {
            try self.current(value);
            if (try self.object(value.reference)) |previous| {
                if (previous.retired and !value.retired) return error.RetiredAuthorizationObject;
                if (previous.registrar != value.registrar or previous.domain != value.domain or previous.actions != value.actions or !std.meta.eql(previous.binding, value.binding) or !std.meta.eql(previous.parent, value.parent)) return error.InvalidAuthorizationObject;
            }
            if (value.binding) |binding| {
                const domain_id = value.domain orelse return error.InvalidAuthorizationObject;
                if (try self.bound(domain_id, binding)) |previous| if (!previous.reference.eql(value.reference)) return error.AuthorizationNameExists;
                try self.catalog.put(try c.key(.authorization_binding, domain_id, 0, &binding), value.reference.id);
            }
            try self.catalog.put(try objectKey(value.reference), value);
        }
        pub fn domain(self: *Self, id: u64) !?a.Domain {
            return self.catalog.get(a.Domain, idKey(.authorization_domain, id));
        }
        pub fn putDomain(self: *Self, value: a.Domain) !void {
            try self.current(value);
            if (try self.domain(value.id)) |previous| if (previous.registrar != value.registrar or previous.actions != value.actions) return error.InvalidAuthorizationDomain;
            try self.catalog.put(idKey(.authorization_domain, value.id), value);
        }
        pub fn credential(self: *Self, principal: u64) !?a.Credential {
            return self.catalog.get(a.Credential, idKey(.authorization_credential, principal));
        }
        pub fn putCredential(self: *Self, value: a.Credential) !void {
            try self.current(value);
            try self.catalog.put(idKey(.authorization_credential, value.principal), value);
        }
        pub fn membership(self: *Self, id: u64) !?a.Membership {
            return self.catalog.get(a.Membership, idKey(.authorization_membership, id));
        }
        pub fn putMembership(self: *Self, value: a.Membership) !void {
            try self.current(value);
            if (try self.membership(value.id)) |previous| if (previous.member != value.member or previous.role != value.role or previous.grantor != value.grantor) return error.InvalidRoleMembership;
            try self.catalog.put(idKey(.authorization_membership, value.id), value);
            const index = try c.key(.authorization_member, value.member, value.id, "");
            if (value.enabled) try self.catalog.put(index, value) else try self.catalog.remove(index);
        }
        pub fn memberships(self: *Self, member: u64, after: ?u64) !a.Page(a.Membership) {
            const batch = try self.catalog.scan(a.Membership, .{ .namespace = .authorization_member, .major = member }, if (after) |id| try c.key(.authorization_member, member, id, "") else null);
            var result: a.Page(a.Membership) = .{};
            for (batch.records, 0..) |slot, i| if (slot) |record| {
                if (!std.meta.eql(record.key, try c.key(.authorization_member, member, record.value.id, ""))) return error.InvalidAuthorizationState;
                result.records[i] = record.value;
            };
            if (batch.next) |cursor| result.next = std.mem.readInt(u64, cursor.data[9..17], .big);
            return result;
        }
        pub fn grant(self: *Self, id: u64) !?a.Grant {
            return self.catalog.get(a.Grant, idKey(.authorization_grant, id));
        }
        pub fn putGrant(self: *Self, value: a.Grant) !void {
            try self.current(value);
            if (try self.grant(value.id)) |previous| if (!previous.object.eql(value.object) or previous.grantee != value.grantee or previous.grantor != value.grantor) return error.InvalidAuthorizationGrant;
            try self.catalog.put(idKey(.authorization_grant, value.id), value);
            if (value.enabled and value.privileges != 0) try self.catalog.put(try grantKey(value), value) else try self.catalog.remove(try grantKey(value));
        }
        pub fn transferGrant(self: *Self, previous: a.Grant, old_owner: u64, new_owner: u64) !void {
            var value = previous;
            if (value.grantor == old_owner) value.grantor = new_owner;
            if (value.grantee == old_owner) value.grantee = new_owner;
            value.revision = self.revision;
            try self.current(value);
            const stored = (try self.grant(value.id)) orelse return error.UnknownAuthorizationGrant;
            if (!std.meta.eql(stored, previous)) return error.InvalidAuthorizationState;
            try self.catalog.remove(try grantKey(previous));
            try self.catalog.put(idKey(.authorization_grant, value.id), value);
            if (value.enabled and value.privileges != 0) try self.catalog.put(try grantKey(value), value);
        }
        pub fn grants(self: *Self, reference: a.ObjectRef, grantee: u64, after: ?u64) !a.Page(a.Grant) {
            const cursor = if (after) |id| try grantKey(.{ .id = id, .object = reference, .grantee = grantee, .grantor = 0, .privileges = 0, .revision = self.revision }) else null;
            const batch = try self.catalog.scan(a.Grant, .{ .namespace = grantNamespace(reference), .major = reference.id, .minor = grantee }, cursor);
            var result: a.Page(a.Grant) = .{};
            for (batch.records, 0..) |slot, i| if (slot) |record| {
                if (!std.meta.eql(record.key, try grantKey(record.value))) return error.InvalidAuthorizationState;
                result.records[i] = record.value;
            };
            if (batch.next) |next| {
                if (next.len != 25) return error.InvalidAuthorizationState;
                result.next = std.mem.readInt(u64, next.data[17..25], .big);
            }
            return result;
        }
        pub fn defaultGrant(self: *Self, id: u64) !?a.DefaultGrant {
            return self.catalog.get(a.DefaultGrant, idKey(.authorization_default, id));
        }
        pub fn putDefault(self: *Self, value: a.DefaultGrant) !void {
            try self.current(value);
            if (try self.defaultGrant(value.id)) |previous| if (previous.creator != value.creator or !previous.schema.eql(value.schema) or previous.domain != value.domain or previous.grantee != value.grantee) return error.InvalidAuthorizationGrant;
            try self.catalog.put(idKey(.authorization_default, value.id), value);
            try self.catalog.put(try c.key(.authorization_creator_default, value.creator, value.id, ""), value);
        }
    };
}
