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

/// One bounded disclosure/publication may depend on several domain objects.
/// This is a per-operation limit, independent of retained object cardinality.
pub const max_requirements = 16;
pub const Claim = struct {
    definition: p.Growth.Definition,
    realm: Id,
    principal: Id,
    credential_epoch: u64,
    role: ?Id,
    audience: Id,
    /// Domain-owned digest of the complete immutable operation or read request.
    context: [32]u8,
    pub fn validate(self: Claim) !void {
        if (self.definition != p.Growth.current_definition or self.realm == 0 or self.realm > p.max_counter or self.principal > p.max_counter or self.audience == 0 or self.audience > p.max_counter) return error.InvalidAuthorizationCredential;
        try revision(self.credential_epoch);
        if (self.role) |id| try roleId(id);
    }
    pub fn digest(self: Claim) ![32]u8 {
        try self.validate();
        var bytes: [1024]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(self, &encoder);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.authorization.subject.v1\x00");
        hash.update(writer.buffered());
        return hash.finalResult();
    }
};
pub const Proof = struct {
    claim: Claim,
    signature: [64]u8,
    pub fn sign(claim: Claim, key: p.Ed25519.KeyPair) !Proof {
        return .{ .claim = claim, .signature = (try key.sign(&try claim.digest(), null)).toBytes() };
    }
    pub fn verify(self: Proof, public_key: [32]u8) !void {
        try p.Ed25519.Signature.fromBytes(self.signature).verify(&try self.claim.digest(), try p.Ed25519.PublicKey.fromBytes(public_key));
    }
};
/// Native admission is already a verified signature. Its immutable claim can
/// authorize bounded continuations without enlarging application messages.
pub const Subject = union(enum) {
    signed: Proof,
    accepted: struct { pid: Id, input: Id, principal: Id },
    pub fn validate(self: Subject) !void {
        switch (self) {
            .signed => |proof| try proof.claim.validate(),
            .accepted => |value| if (value.pid == 0 or value.pid > p.max_counter or value.input == 0 or value.input > p.max_counter or value.principal > p.max_counter) return error.InvalidAuthorizationCredential,
        }
    }
    pub fn audience(self: Subject) Id {
        return switch (self) {
            .signed => |proof| proof.claim.audience,
            .accepted => |value| value.pid,
        };
    }
    pub fn principal(self: Subject) Id {
        return switch (self) {
            .signed => |proof| proof.claim.principal,
            .accepted => |value| value.principal,
        };
    }
    pub fn matches(self: Subject, value: Verified) bool {
        if (value.principal != self.principal() or value.audience != self.audience()) return false;
        return switch (self) {
            .signed => |proof| value.credential_epoch == proof.claim.credential_epoch and std.mem.eql(u8, &value.context, &proof.claim.context) and (proof.claim.role == null or proof.claim.role == value.role),
            .accepted => true,
        };
    }
};
pub fn inputContext(value: p.Value) ![32]u8 {
    try value.validate();
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.authorization.input.v1\x00");
    hash.update(value.slice());
    return hash.finalResult();
}
pub const Requirement = struct {
    object: ObjectRef,
    privileges: Privileges = 0,
    access: enum { all, any, ownership, visible } = .all,
    pub fn validate(self: Requirement) !void {
        try self.object.validate();
        try mask(self.privileges);
        if ((self.privileges == 0) != (self.access == .ownership)) return error.InvalidAuthorizationPrivilege;
    }
};
pub const Guard = struct {
    subject: Subject,
    requirements: [max_requirements]?Requirement,
    /// A domain operation may assign one new owner only if the original login
    /// can select it. This is independent of inherited data/owner privileges.
    selectable: ?Id = null,
    /// Conjunction of current requirements. Different predicates remain distinct.
    pub fn merge(self: Guard, other: Guard) !Guard {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self.subject, other.subject)) return error.InvalidAuthorizationCredential;
        var combined = self;
        if (other.selectable) |role| {
            if (combined.selectable) |previous| if (previous != role) return error.AuthorizationBudgetExceeded;
            combined.selectable = role;
        }
        for (other.requirements) |slot| {
            const requirement = slot orelse break;
            for (&combined.requirements) |*entry| {
                if (entry.*) |*previous| {
                    if (std.meta.eql(previous.*, requirement)) break;
                    if (previous.object.eql(requirement.object) and previous.access == .all and requirement.access == .all) {
                        previous.privileges |= requirement.privileges;
                        break;
                    }
                } else {
                    entry.* = requirement;
                    break;
                }
            } else return error.AuthorizationBudgetExceeded;
        }
        return combined;
    }
    pub fn validate(self: Guard) !void {
        try self.subject.validate();
        if (self.selectable) |role| try roleId(role);
        if (self.requirements[0] == null) return error.InvalidAuthorizationPrivilege;
        var ended = false;
        for (self.requirements) |slot| {
            const value = slot orelse {
                ended = true;
                continue;
            };
            if (ended) return error.InvalidAuthorizationPrivilege;
            try value.validate();
        }
    }
};
pub const Verified = struct { principal: Id, login_role: Id, role: Id, credential_epoch: u64, audience: Id, context: [32]u8 };

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
    /// Immutable domain-owned identity commitment. Names are not binding keys.
    binding: ?[32]u8 = null,
    parent: ?ObjectRef = null,
    revision: u64,
    retired: bool = false,
    pub fn validate(self: Object) !void {
        try self.reference.validate();
        try roleId(self.owner);
        if (self.registrar > p.max_counter) return error.InvalidAuthorizationObject;
        try mask(self.actions);
        if ((self.reference.kind == .domain) != (self.domain != null)) return error.InvalidAuthorizationObject;
        if ((self.binding != null or self.parent != null) and self.domain == null) return error.InvalidAuthorizationObject;
        if (self.parent) |parent| try parent.validate();
        if (self.domain) |id| if (id == 0 or id >= public_role) return error.InvalidAuthorizationObject;
        try revision(self.revision);
    }
};

pub const Domain = struct {
    id: Id,
    registrar: Id,
    actions: Privileges,
    /// Explicit native lifetime prerequisite for this domain's operations.
    /// It grants no resource read/write access and is immutable after creation.
    lifetime_resource: ?Id,
    revision: u64,
    enabled: bool = true,
    pub fn validate(self: Domain) !void {
        if (self.id == 0 or self.id >= public_role or self.registrar > p.max_counter or self.actions == 0) return error.InvalidAuthorizationDomain;
        if (self.lifetime_resource) |resource| if (resource == 0 or resource > p.max_counter) return error.InvalidAuthorizationDomain;
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
    membership: struct { member: Id, role: Id, admin: ?bool = null, inherit: ?bool = null, set: ?bool = null },
    revoke_membership: struct { id: Id, option: ?MembershipOption = null, behavior: RevokeBehavior = .restrict },
    revoke_role: struct { member: Id, role: Id, option: ?MembershipOption = null, behavior: RevokeBehavior = .restrict },
    register_domain: struct { registrar: Id, actions: Privileges, lifetime_resource: ?Id = null },
    register_object: struct { domain: Id, owner: Id, schema: ?ObjectRef = null, binding: ?[32]u8 = null },
    transfer_object: struct { object: ObjectRef, owner: Id },
    retire_object: ObjectRef,
    grant: struct { object: ObjectRef, grantee: Id, privileges: Privileges, grant_options: Privileges = 0 },
    revoke: struct { id: Id, privileges: Privileges, grant_option_only: bool = false, behavior: RevokeBehavior = .restrict },
    revoke_privileges: struct { object: ObjectRef, grantee: Id, privileges: Privileges, grant_option_only: bool = false, behavior: RevokeBehavior = .restrict },
    default_grant: struct { creator: Id, schema: ObjectRef, domain: Id, grantee: Id, privileges: Privileges, grant_options: Privileges = 0 },
    revoke_default: Id,
    revoke_defaults: struct { creator: Id, schema: ObjectRef, domain: Id, grantee: Id, privileges: Privileges, grant_option_only: bool = false },
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
/// Native admission evidence, retained independently of the current credential.
/// Both fields are required: a self-supplied saved signer is not trusted.
pub const BeginIdentity = struct { public_key: [32]u8, digest: [32]u8 };
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

/// A read-only execution of the same candidate transitions as apply. An
/// incomplete preview is explicitly not validation of the remaining cascade.
pub const Preview = struct {
    complete: bool,
    changed_records: u64,
    steps: u64,
    pages: u32,
    reads: u32,
};
pub const preview_pages = 32;
pub const preview_steps = 64;
pub const preview_reads = 4096;

pub const Cursor = struct { revision: u64, after: Id, scope: [32]u8 };
pub fn ReadPage(comptime T: type) type {
    return struct { records: [page_size]?T, next: ?Cursor };
}
pub const Query = struct {
    role: ?Id = null,
    kind: union(enum) {
        identity: void,
        preview: struct { expected_revision: u64, action: Action },
        authenticate: Subject,
        check: Guard,
        decision: struct { object: ObjectRef, privileges: Privileges },
        role: Id,
        resolve: p.Value,
        roles: ?Cursor,
        memberships: struct { member: Id, cursor: ?Cursor = null },
        object: ObjectRef,
        binding: struct { domain: Id, key: [32]u8 },
        registration: struct { domain: Id, key: [32]u8 },
        grants: struct { object: ObjectRef, grantee: Id, cursor: ?Cursor = null },
        defaults: struct { creator: Id, cursor: ?Cursor = null },
        change: Id,
        operation: Id,
        receipt: p.Growth.Request,
    },
};
pub const Result = struct {
    revision: u64,
    role: Id,
    body: union(enum) {
        identity: struct { principal: Id, login_role: Id, credential_epoch: u64 },
        preview: Preview,
        authenticate: Verified,
        check: Verified,
        decision: Decision,
        role: Role,
        resolve: Role,
        roles: ReadPage(Role),
        memberships: ReadPage(Membership),
        object: Object,
        binding: ?Object,
        registration: ?struct { outcome: Outcome, action: Action },
        grants: ReadPage(Grant),
        defaults: ReadPage(DefaultGrant),
        change: Outcome,
        operation: struct { outcome: Outcome, action: Action, begin: BeginIdentity },
        receipt: ?p.Receipt,
    },
};

pub fn validateQuery(query: Query) !void {
    if (query.role) |id| try roleId(id);
    switch (query.kind) {
        .preview => |value| try revision(value.expected_revision),
        .receipt => |value| {
            try p.Growth.validate(value);
        },
        .authenticate => |value| try value.validate(),
        .check => |value| try value.validate(),
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
        inline .binding, .registration => |value| if (value.domain == 0 or value.domain >= public_role) return error.InvalidAuthorizationDomain,
        .grants => |value| {
            try value.object.validate();
            if (value.grantee > public_role) return error.InvalidAuthorizationRole;
            if (value.cursor) |cursor| try revision(cursor.revision);
        },
        .defaults => |value| {
            try roleId(value.creator);
            if (value.cursor) |cursor| try revision(cursor.revision);
        },
        .change, .operation => |id| if (id == 0 or id > p.max_counter) return error.InvalidAuthorizationChange,
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
        .preview => |value| {
            if (result.revision != query.kind.preview.expected_revision or value.pages > preview_pages or value.reads > preview_reads or value.steps > preview_steps) return error.InvalidRead;
        },
        .receipt => |value| if (value) |receipt| if (receipt.position == 0 or receipt.position > p.max_counter) return error.InvalidRead,
        inline .authenticate, .check => |value, tag| {
            const subject = if (comptime tag == .authenticate) query.kind.authenticate else query.kind.check.subject;
            if (!subject.matches(value)) return error.InvalidRead;
            try roleId(value.role);
            try roleId(value.login_role);
        },
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
        .binding => |slot| if (slot) |value| {
            try value.validate();
            if (value.domain != query.kind.binding.domain or value.binding == null or !std.mem.eql(u8, &value.binding.?, &query.kind.binding.key) or value.revision > result.revision) return error.InvalidRead;
        },
        .registration => |slot| if (slot) |value| {
            if (value.action != .register_object) return error.InvalidRead;
            const action = value.action.register_object;
            if (action.domain != query.kind.registration.domain or action.binding == null or !std.mem.eql(u8, &action.binding.?, &query.kind.registration.key) or value.outcome.id == 0) return error.InvalidRead;
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
        .operation => |value| if (value.outcome.id != query.kind.operation or value.outcome.basis > value.outcome.revision or value.outcome.revision > result.revision and value.outcome.status == .published) return error.InvalidRead,
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

test "service subject signatures and native admission contexts match independent bytes" {
    const t = std.testing;
    const Vector = struct { canonical: []const u8, sha256: []const u8, signature: [64]u8 };
    const Fixture = struct {
        public_key: [32]u8,
        subject: Vector,
        utf8_subject: Vector,
        input: struct { value: p.Value, digest: []const u8 },
    };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/authorization-subject-v1.json"), .{});
    defer fixture.deinit();
    var expected: [32]u8 = undefined;
    for ([_]Vector{ fixture.value.subject, fixture.value.utf8_subject }) |vector| {
        const parsed = try p.Json.parseFromSlice(Claim, t.allocator, vector.canonical);
        defer parsed.deinit();
        const proof: Proof = .{ .claim = parsed.value, .signature = vector.signature };
        try proof.verify(fixture.value.public_key);
        _ = try std.fmt.hexToBytes(&expected, vector.sha256);
        try t.expectEqualSlices(u8, &expected, &try proof.claim.digest());
        var changed = proof;
        changed.claim.audience += 1;
        try t.expectError(error.SignatureVerificationFailed, changed.verify(fixture.value.public_key));
    }
    _ = try std.fmt.hexToBytes(&expected, fixture.value.input.digest);
    try t.expectEqualSlices(u8, &expected, &try inputContext(fixture.value.input.value));
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
