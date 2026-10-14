//! Owned authorization values. No evaluator, storage or transport lives here.
const std = @import("std");
const p = @import("root.zig");

pub const Id = u64;
pub const public_role: Id = p.max_counter;
pub const root_role: Id = 0;
pub const max_name_bytes = 63;
pub const page_size = 8;
pub const max_vertices = 256;
pub const max_records = 4096;
pub const max_depth = 32;
pub const Privileges = u64;
pub const all_privileges: Privileges = p.max_counter;

pub const Limits = struct {
    vertices: u16 = max_vertices,
    records: u16 = max_records,
    depth: u8 = max_depth,
    pub fn validate(self: Limits) !void {
        if (self.vertices == 0 or self.vertices > max_vertices or self.records == 0 or self.records > max_records or self.depth == 0 or self.depth > max_depth) return error.InvalidAuthorizationBudget;
    }
};

pub const ObjectRef = struct {
    kind: enum(u8) { realm = 1, process = 2, resource = 3, domain = 4 },
    id: Id,
    pub fn validate(self: ObjectRef) !void {
        if (self.id > p.max_counter) return error.InvalidAuthorizationObject;
        if (self.kind != .realm and self.id == 0) return error.InvalidAuthorizationObject;
    }
    pub fn eql(a: ObjectRef, b: ObjectRef) bool {
        return a.kind == b.kind and a.id == b.id;
    }
};

pub const Role = struct {
    id: Id,
    name: p.Value,
    owner: Id,
    revision: u64,
    login: bool = false,
    enabled: bool = true,
    create_role: bool = false,
    /// Direct native provisioning owns this private role's replacement lifecycle.
    native: bool = false,
    retired: bool = false,
    pub fn validate(self: Role) !void {
        try roleId(self.id);
        try roleId(self.owner);
        try name(self.name);
        try revision(self.revision);
    }
};

pub const Object = struct {
    reference: ObjectRef,
    owner: Id,
    /// Principal permitted to bind this generic object to its domain lifecycle.
    registrar: Id,
    actions: Privileges,
    /// An authorized framework declares the action vocabulary for its objects.
    domain: ?Id = null,
    revision: u64,
    retired: bool = false,
    pub fn validate(self: Object) !void {
        try self.reference.validate();
        try roleId(self.owner);
        if (self.registrar > p.max_counter) return error.InvalidAuthorizationObject;
        try mask(self.actions);
        if ((self.reference.kind == .domain) != (self.domain != null)) return error.InvalidAuthorizationObject;
        if (self.domain) |id| if (id == 0 or id >= public_role) return error.InvalidAuthorizationObject;
        try revision(self.revision);
    }
};

pub const Domain = struct {
    id: Id,
    registrar: Id,
    actions: Privileges,
    revision: u64,
    enabled: bool = true,
    pub fn validate(self: Domain) !void {
        if (self.id == 0 or self.id >= public_role or self.registrar > p.max_counter or self.actions == 0) return error.InvalidAuthorizationDomain;
        try mask(self.actions);
        try revision(self.revision);
    }
};

/// A credential authenticates a principal; privileges belong to the bound role.
/// Epoch changes invalidate sessions without transferring or reviving grants.
pub const Credential = struct {
    principal: Id,
    public_key: [32]u8,
    role: Id,
    pid: ?Id,
    epoch: u64,
    revision: u64,
    enabled: bool,
    native: bool = false,
    pub fn validate(self: Credential) !void {
        if (self.principal > p.max_counter or self.pid == 0 or (self.pid orelse 0) > p.max_counter) return error.InvalidAuthorizationCredential;
        try roleId(self.role);
        try revision(self.epoch);
        try revision(self.revision);
        _ = try p.Ed25519.PublicKey.fromBytes(self.public_key);
    }
};

pub const DefaultGrant = struct {
    id: Id,
    creator: Id,
    schema: ObjectRef,
    domain: Id,
    grantee: Id,
    privileges: Privileges,
    grant_options: Privileges,
    revision: u64,
    enabled: bool = true,
    pub fn validate(self: DefaultGrant) !void {
        if (self.id == 0 or self.id >= public_role or self.domain == 0 or self.domain >= public_role or self.grantee > public_role) return error.InvalidAuthorizationGrant;
        try roleId(self.creator);
        try self.schema.validate();
        try mask(self.privileges);
        try mask(self.grant_options);
        if (self.grant_options & ~self.privileges != 0 or (self.grantee == public_role and self.grant_options != 0)) return error.InvalidAuthorizationGrant;
        try revision(self.revision);
    }
};

pub const Membership = struct {
    id: Id,
    member: Id,
    role: Id,
    grantor: Id,
    revision: u64,
    admin: bool = false,
    inherit: bool = true,
    set: bool = true,
    enabled: bool = true,
    pub fn validate(self: Membership) !void {
        if (self.id == 0 or self.id > p.max_counter or self.member == self.role) return error.InvalidRoleMembership;
        try roleId(self.member);
        try roleId(self.role);
        try roleId(self.grantor);
        try revision(self.revision);
    }
};

pub const Grant = struct {
    id: Id,
    object: ObjectRef,
    grantee: Id,
    grantor: Id,
    privileges: Privileges,
    grant_options: Privileges = 0,
    revision: u64,
    enabled: bool = true,
    pub fn validate(self: Grant) !void {
        if (self.id == 0 or self.id > p.max_counter or self.grantee > public_role) return error.InvalidAuthorizationGrant;
        try self.object.validate();
        try roleId(self.grantor);
        try mask(self.privileges);
        try mask(self.grant_options);
        if (self.grant_options & ~self.privileges != 0 or (self.grantee == public_role and self.grant_options != 0)) return error.InvalidAuthorizationGrant;
        try revision(self.revision);
    }
};

pub const Decision = struct {
    policy_revision: u64,
    role: Id,
    object: ObjectRef,
    requested: Privileges,
    allowed: Privileges,
    grantable: Privileges,
    records: u16,
    pub fn permits(self: Decision) bool {
        return self.allowed & self.requested == self.requested;
    }
};

pub const RevokeBehavior = enum { restrict, cascade };
pub const MembershipOption = enum { admin, inherit, set };
pub const Action = union(enum) {
    create_role: struct { name: p.Value, login: bool = false, create_role: bool = false },
    alter_role: struct { id: Id, name: ?p.Value = null, owner: ?Id = null, login: ?bool = null, enabled: ?bool = null, create_role: ?bool = null },
    retire_role: struct { id: Id, behavior: RevokeBehavior = .restrict },
    membership: struct { member: Id, role: Id, admin: bool = false, inherit: bool = true, set: bool = true },
    revoke_membership: struct { id: Id, option: ?MembershipOption = null, behavior: RevokeBehavior = .restrict },
    register_domain: struct { registrar: Id, actions: Privileges },
    register_object: struct { domain: Id, owner: Id, schema: ?ObjectRef = null },
    transfer_object: struct { object: ObjectRef, owner: Id },
    retire_object: ObjectRef,
    grant: struct { object: ObjectRef, grantee: Id, privileges: Privileges, grant_options: Privileges = 0 },
    revoke: struct { id: Id, privileges: Privileges, grant_option_only: bool = false, behavior: RevokeBehavior = .restrict },
    default_grant: struct { creator: Id, schema: ObjectRef, domain: Id, grantee: Id, privileges: Privileges, grant_options: Privileges = 0 },
    revoke_default: Id,
    bind_credential: struct { principal: Id, role: Id, public_key: [32]u8, pid: ?Id = null },
    rotate_credential: struct { principal: Id, expected_epoch: u64, public_key: [32]u8 },
    disable_credential: struct { principal: Id, expected_epoch: u64 },
};

/// The administration workflow always retains the original signed begin.
/// Advancing a private candidate confers no permission; publish selects its root.
pub const Command = union(enum) {
    begin: struct { expected_revision: u64, role: ?Id = null, action: Action },
    advance: Id,
    publish: Id,
    abandon: Id,
};
pub const Status = enum { preparing, ready, published, abandoned };
pub const Outcome = struct {
    id: Id,
    principal: Id,
    role: Id,
    basis: u64,
    revision: u64,
    status: Status,
    created_id: ?Id,
    changed_records: u64,
    steps: u64,
};

pub const Cursor = struct { revision: u64, after: Id, scope: [32]u8 };
pub fn ReadPage(comptime T: type) type {
    return struct { records: [page_size]?T, next: ?Cursor };
}
pub const Query = struct {
    role: ?Id = null,
    kind: union(enum) {
        identity: void,
        decision: struct { object: ObjectRef, privileges: Privileges },
        role: Id,
        resolve: p.Value,
        roles: ?Cursor,
        memberships: struct { member: Id, cursor: ?Cursor = null },
        object: ObjectRef,
        grants: struct { object: ObjectRef, grantee: Id, cursor: ?Cursor = null },
        defaults: struct { creator: Id, cursor: ?Cursor = null },
        change: Id,
    },
};
pub const Result = struct {
    revision: u64,
    role: Id,
    body: union(enum) {
        identity: struct { principal: Id, login_role: Id, credential_epoch: u64 },
        decision: Decision,
        role: Role,
        resolve: Role,
        roles: ReadPage(Role),
        memberships: ReadPage(Membership),
        object: Object,
        grants: ReadPage(Grant),
        defaults: ReadPage(DefaultGrant),
        change: Outcome,
    },
};

pub fn validateQuery(query: Query) !void {
    if (query.role) |id| try roleId(id);
    switch (query.kind) {
        .decision => |value| {
            try value.object.validate();
            try mask(value.privileges);
        },
        .role => |id| try roleId(id),
        .resolve => |value| try name(value),
        .roles => |cursor| if (cursor) |value| try revision(value.revision),
        .memberships => |value| {
            try roleId(value.member);
            if (value.cursor) |cursor| try revision(cursor.revision);
        },
        .object => |value| try value.validate(),
        .grants => |value| {
            try value.object.validate();
            if (value.grantee > public_role) return error.InvalidAuthorizationRole;
            if (value.cursor) |cursor| try revision(cursor.revision);
        },
        .defaults => |value| {
            try roleId(value.creator);
            if (value.cursor) |cursor| try revision(cursor.revision);
        },
        .change => |id| if (id == 0 or id > p.max_counter) return error.InvalidAuthorizationChange,
        .identity => {},
    }
}
pub fn cursorScope(query: Query, realm: Id, principal: Id, role: Id) ![32]u8 {
    var normalized = query;
    normalized.role = role;
    switch (normalized.kind) {
        .roles => normalized.kind.roles = null,
        inline .memberships, .grants, .defaults => |_, tag| @field(normalized.kind, @tagName(tag)).cursor = null,
        else => return error.InvalidAuthorizationCursor,
    }
    var bytes: [1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try std.json.Stringify.value(.{ .definition = p.Growth.current_definition, .realm = realm, .principal = principal, .query = normalized }, .{}, &writer);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.authorization.cursor.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}
pub fn validateResult(result: Result, query: Query, realm: Id, principal: Id) !void {
    try revision(result.revision);
    try roleId(result.role);
    if (query.role) |id| if (id != result.role) return error.InvalidRead;
    if (!std.mem.eql(u8, @tagName(result.body), @tagName(query.kind))) return error.InvalidRead;
    switch (result.body) {
        .identity => |value| {
            if (value.principal != principal) return error.InvalidRead;
            try roleId(value.login_role);
            try revision(value.credential_epoch);
        },
        .decision => |value| {
            const requested = query.kind.decision;
            if (value.policy_revision != result.revision or value.role != result.role or !value.object.eql(requested.object) or value.requested != requested.privileges or (value.allowed | value.grantable) & ~value.requested != 0 or value.records > max_records) return error.InvalidRead;
        },
        inline .role, .resolve => |value, tag| {
            try value.validate();
            if (value.revision > result.revision) return error.InvalidRead;
            if (comptime tag == .role) {
                if (value.id != query.kind.role) return error.InvalidRead;
            } else if (!value.name.eql(query.kind.resolve)) return error.InvalidRead;
        },
        .object => |value| {
            try value.validate();
            if (!value.reference.eql(query.kind.object) or value.revision > result.revision) return error.InvalidRead;
        },
        inline .roles, .memberships, .grants, .defaults => |page, tag| {
            const cursor = if (comptime tag == .roles) query.kind.roles else @field(query.kind, @tagName(tag)).cursor;
            const scope = try cursorScope(query, realm, principal, result.role);
            if (cursor) |value| if (value.revision != result.revision or !std.mem.eql(u8, &value.scope, &scope)) return error.InvalidRead;
            var last: u64 = if (cursor) |value| value.after else 0;
            var count: usize = 0;
            var ended = false;
            for (page.records) |slot| {
                const value = slot orelse {
                    ended = true;
                    continue;
                };
                try value.validate();
                const initial_root = if (comptime tag == .roles) cursor == null and count == 0 and value.id == 0 else false;
                if (ended or value.revision > result.revision or (value.id <= last and !initial_root)) return error.InvalidRead;
                if (comptime tag == .memberships) {
                    if (value.member != query.kind.memberships.member) return error.InvalidRead;
                }
                if (comptime tag == .grants) {
                    if (value.grantee != query.kind.grants.grantee or !value.object.eql(query.kind.grants.object)) return error.InvalidRead;
                }
                if (comptime tag == .defaults) {
                    if (value.creator != query.kind.defaults.creator) return error.InvalidRead;
                }
                last = value.id;
                count += 1;
            }
            if (page.next) |next| if (count == 0 or next.after != last or next.revision != result.revision or !std.mem.eql(u8, &next.scope, &scope)) return error.InvalidRead;
        },
        .change => |value| if (value.id != query.kind.change or value.basis > value.revision or value.revision > result.revision and value.status == .published) return error.InvalidRead,
    }
}

pub fn Page(comptime T: type) type {
    return struct {
        records: [page_size]?T = @splat(null),
        next: ?Id = null,
    };
}

pub fn name(value: p.Value) !void {
    try value.validate();
    if (value.len == 0 or value.len > max_name_bytes or !std.unicode.utf8ValidateSlice(value.slice()) or std.mem.indexOfScalar(u8, value.slice(), 0) != null) return error.InvalidAuthorizationName;
}
pub fn roleId(id: Id) !void {
    if (id >= public_role) return error.InvalidAuthorizationRole;
}
pub fn revision(value: u64) !void {
    if (value > p.max_counter) return error.InvalidAuthorizationRevision;
}
pub fn mask(value: Privileges) !void {
    if (value & ~all_privileges != 0) return error.InvalidAuthorizationPrivilege;
}

test "authorization values reject public delegation, malformed names and masks" {
    const t = std.testing;
    var grant: Grant = .{ .id = 1, .object = .{ .kind = .domain, .id = 2 }, .grantee = public_role, .grantor = 0, .privileges = 1, .revision = 1 };
    try grant.validate();
    grant.grant_options = 1;
    try t.expectError(error.InvalidAuthorizationGrant, grant.validate());
    grant.grantee = 3;
    grant.grant_options = 2;
    try t.expectError(error.InvalidAuthorizationGrant, grant.validate());
    try t.expectError(error.InvalidAuthorizationName, name(try p.Value.init("bad\x00name")));
    try t.expectError(error.InvalidAuthorizationName, name(try p.Value.init("\xff")));
    try name(try p.Value.init("分析员"));
    try t.expectError(error.InvalidAuthorizationPrivilege, mask(@as(u64, 1) << 63));
    try t.expectError(error.InvalidAuthorizationBudget, (Limits{ .vertices = 0 }).validate());
}

test "authorization signing and cursor scope match independent Python OpenSSL vectors" {
    const t = std.testing;
    const Vector = struct { canonical: []const u8, sha256: []const u8, signature: [64]u8 };
    const Fixture = struct {
        version: u8,
        public_key: [32]u8,
        request: Vector,
        query: Vector,
        turn: Vector,
        entries: Vector,
        cursor: struct { realm: Id, principal: Id, role: Id, query: Query, scope: []const u8 },
    };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/authorization-v1.json"), .{});
    defer fixture.deinit();
    try t.expectEqual(@as(u8, 1), fixture.value.version);
    const public = try p.Ed25519.PublicKey.fromBytes(fixture.value.public_key);
    const request = try std.json.parseFromSlice(p.Growth.Request, t.allocator, fixture.value.request.canonical, .{});
    defer request.deinit();
    try p.Growth.validate(request.value);
    const request_digest = try p.Growth.digest(request.value);
    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, fixture.value.request.sha256);
    try t.expectEqualSlices(u8, &expected, &request_digest);
    try p.Ed25519.Signature.fromBytes(fixture.value.request.signature).verify(&request_digest, public);
    const query = try std.json.parseFromSlice(p.Growth.Query, t.allocator, fixture.value.query.canonical, .{});
    defer query.deinit();
    try p.Growth.validateQuery(query.value);
    const query_digest = try p.Growth.queryDigest(query.value);
    _ = try std.fmt.hexToBytes(&expected, fixture.value.query.sha256);
    try t.expectEqualSlices(u8, &expected, &query_digest);
    try p.Ed25519.Signature.fromBytes(fixture.value.query.signature).verify(&query_digest, public);
    const cursor = fixture.value.cursor;
    const actual = try cursorScope(cursor.query, cursor.realm, cursor.principal, cursor.role);
    _ = try std.fmt.hexToBytes(&expected, cursor.scope);
    try t.expectEqualSlices(u8, &expected, &actual);
    try t.expect(!std.mem.eql(u8, &actual, &try cursorScope(cursor.query, cursor.realm + 1, cursor.principal, cursor.role)));
    try t.expect(!std.mem.eql(u8, &actual, &try cursorScope(cursor.query, cursor.realm, cursor.principal + 1, cursor.role)));
    try t.expect(!std.mem.eql(u8, &actual, &try cursorScope(cursor.query, cursor.realm, cursor.principal, cursor.role + 1)));
}
