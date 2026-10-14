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
    if (value == 0 or value > p.max_counter) return error.InvalidAuthorizationRevision;
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
