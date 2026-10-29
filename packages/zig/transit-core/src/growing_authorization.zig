//! Native ownership of policy publication and authenticated administrative work.
const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;
const g = p.Growth;
const a = p.Authorization;
const c = core.catalog;
const growth = @import("growing.zig");
const policy = core.authorization_store;
const admin = core.authorization_admin;
// Persist admission identity beside the private candidate. It survives policy
// publication and credential rotation; a saved record never supplies its trust.
const RecordedChange = struct { change: admin.Change, begin: a.BeginIdentity };
pub const realm: a.ObjectRef = .{ .kind = .realm, .id = 0 };

/// Memoize only the mathematical signature check for an exact proof/key pair.
/// This carries no rights, identity status, selected role or lifetime evidence.
/// Authentication still loads the current principal and evaluates current policy.
pub const ProofCache = struct {
    const Entry = struct { proof: a.Proof, key: [32]u8 };
    entries: [8]?Entry = @splat(null),
    next: usize = 0,
    hits: u64 = 0,
    verifications: u64 = 0,
    pub fn verify(self: *ProofCache, proof: a.Proof, key: [32]u8) !void {
        for (self.entries) |slot| if (slot) |entry| {
            if (std.meta.eql(entry.proof, proof) and std.mem.eql(u8, &entry.key, &key)) {
                self.hits +|= 1;
                return;
            }
        };
        self.verifications +|= 1;
        try proof.verify(key);
        self.entries[self.next] = .{ .proof = proof, .key = key };
        self.next = (self.next + 1) % self.entries.len;
    }
};

test "domain proof cache binds complete claims signatures and public keys" {
    const t = std.testing;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(17));
    const other = try p.Ed25519.KeyPair.generateDeterministic(@splat(29));
    const proof = try a.Proof.sign(.{ .definition = g.current_definition, .realm = 1, .principal = 1, .credential_epoch = 1, .role = null, .audience = 2, .context = @splat(3) }, key);
    var cache: ProofCache = .{};
    try cache.verify(proof, key.public_key.toBytes());
    try cache.verify(proof, key.public_key.toBytes());
    try t.expectEqual(1, cache.verifications);
    try t.expectEqual(1, cache.hits);
    var changed = proof;
    changed.claim.context[0] ^= 1;
    if (cache.verify(changed, key.public_key.toBytes())) |_| return error.TestExpectedError else |_| {}
    changed = proof;
    changed.signature[0] ^= 1;
    if (cache.verify(changed, key.public_key.toBytes())) |_| return error.TestExpectedError else |_| {}
    if (cache.verify(proof, other.public_key.toBytes())) |_| return error.TestExpectedError else |_| {}
    try t.expectEqual(1, cache.hits);
    for (0..cache.entries.len) |i| {
        var claim = proof.claim;
        claim.context[0] = @intCast(10 + i);
        try cache.verify(try a.Proof.sign(claim, key), key.public_key.toBytes());
    }
    const before = cache.verifications;
    try cache.verify(proof, key.public_key.toBytes());
    try t.expectEqual(before + 1, cache.verifications);
}

pub fn controlCommand(engine: anytype, command: a.Command) !bool {
    const action: a.Action = switch (command) {
        .begin => |value| value.action,
        .abandon => return true,
        .advance, .publish => |id| action: {
            var current = try engine.state();
            const recorded = (try current.get(RecordedChange, growth.address(.authorization_change, id))) orelse return error.UnknownAuthorizationChange;
            break :action recorded.change.action;
        },
    };
    return switch (action) {
        .revoke, .revoke_privileges, .revoke_membership, .revoke_role, .revoke_default, .revoke_defaults, .retire_role, .retire_object, .disable_credential, .rotate_credential => true,
        .alter_role => |value| value.name == null and value.owner == null and value.create_role == null and value.login != true and value.enabled != true,
        else => false,
    };
}

pub fn bootstrap(page_store: anytype, key: [32]u8) !policy.Snapshot {
    var store = try policy.Store(@TypeOf(page_store.*)).open(page_store, .{ .catalog = .{}, .revision = 0, .next_id = 1 });
    try store.putRole(.{ .id = 0, .name = try p.Value.init("root"), .owner = 0, .revision = 0, .login = true, .create_role = true, .native = true });
    try store.putCredential(.{ .principal = 0, .public_key = key, .role = 0, .pid = null, .epoch = 0, .revision = 0, .enabled = true, .native = true });
    try store.putObject(.{ .reference = realm, .owner = 0, .registrar = 0, .actions = p.all_permissions, .revision = 0 });
    try store.putGrant(.{ .id = try store.allocate(), .object = realm, .grantee = 0, .grantor = 0, .privileges = p.all_permissions, .revision = 0 });
    return store.snapshot();
}
pub fn principal(engine: anytype, id: u64) !growth.Principal {
    var current = try engine.state();
    const sequence = (try current.get(growth.Sequence, growth.address(.principal, id))) orelse return error.Unauthorized;
    var store = try engine.authorization();
    const credential = (try store.credential(id)) orelse return error.Unauthorized;
    try credential.validate();
    const role = (try store.role(credential.role)) orelse return error.InvalidAuthorizationState;
    try role.validate();
    const enabled = credential.enabled and role.enabled and role.login and !role.retired;
    var permissions: u64 = 0;
    if (enabled) {
        var evaluator = try core.authorization.Evaluator(@TypeOf(store)).init(&store, store.revision, engine.genesis.authorization_limits);
        permissions = (try evaluator.evaluate(role.id, realm, p.all_permissions)).allowed;
        if (credential.pid) |pid| {
            const reference: a.ObjectRef = .{ .kind = .process, .id = pid };
            if (try store.object(reference) != null) permissions |= (try evaluator.evaluate(role.id, reference, p.all_permissions)).allowed;
        }
    }
    return .{ .grant = .{ .subject = id, .public_key = credential.public_key, .permissions = @intCast(permissions), .pid = credential.pid }, .role = credential.role, .enabled = enabled, .credential_epoch = credential.epoch, .revision = store.revision, .epoch = if (credential.native) credential.role else credential.epoch, .sequence = sequence.sequence };
}
pub fn object(engine: anytype, next: *growth.Head, reference: a.ObjectRef, actions: u64) !void {
    var store = try policy.Store(@TypeOf(engine.page_store.*)).open(engine.page_store, next.authorization);
    store.next_id = next.authorization_next_id;
    store.revision = engine.head.position;
    if (try store.object(reference) == null) try store.putObject(.{ .reference = reference, .owner = 0, .registrar = 0, .actions = actions, .revision = store.revision });
    next.authorization = store.snapshot();
    next.authorization_next_id = store.next_id;
}
pub fn nativeGrant(engine: anytype, candidate: anytype, next: *growth.Head, request: g.Request) !void {
    if (request.principal != 0) return error.Forbidden;
    const value = if (request.command == .grant) request.command.grant else request.command.create_principal;
    if (value.subject == 0 or value.permissions & ~p.all_permissions != 0) return error.InvalidGrant;
    _ = try p.Ed25519.PublicKey.fromBytes(value.public_key);
    var store = try policy.Store(@TypeOf(engine.page_store.*)).open(engine.page_store, next.authorization);
    // All validation below is by point lookup. Stage the bounded role/name,
    // credential, object and grant/index changes together, so shared policy
    // paths are written once. Only the eventual native append publishes them.
    var pending: c.Candidate = .{};
    store.catalog.pending = &pending;
    store.next_id = next.authorization_next_id;
    store.revision = engine.head.position;
    const previous = try store.credential(value.subject);
    if (previous) |old| {
        if (request.command == .create_principal or !old.native) return error.InvalidGrant;
        var retired = (try store.role(old.role)) orelse return error.InvalidAuthorizationState;
        retired.retired = true;
        retired.enabled = false;
        retired.revision = store.revision;
        try store.putRole(retired);
    }
    const id = try store.allocate();
    var bytes: [a.max_name_bytes]u8 = undefined;
    const name = try p.Value.init(try std.fmt.bufPrint(&bytes, "native/{d}/{d}", .{ value.subject, id }));
    try store.putRole(.{ .id = id, .name = name, .owner = 0, .revision = store.revision, .login = true, .native = true });
    try store.putCredential(.{ .principal = value.subject, .public_key = value.public_key, .role = id, .pid = value.pid, .epoch = store.revision, .revision = store.revision, .enabled = true, .native = true });
    const reference: a.ObjectRef = if (value.pid) |pid| .{ .kind = .process, .id = pid } else realm;
    if (try store.object(reference) == null) try store.putObject(.{ .reference = reference, .owner = 0, .registrar = 0, .actions = p.all_permissions, .revision = store.revision });
    const target = (try store.object(reference)) orelse return error.InvalidAuthorizationState;
    if (target.retired) return error.RetiredAuthorizationObject;
    try store.putGrant(.{ .id = try store.allocate(), .object = reference, .grantee = id, .grantor = target.owner, .privileges = value.permissions, .revision = store.revision });
    if (previous == null) try candidate.put(growth.address(.principal, value.subject), growth.Sequence{ .sequence = 0 });
    try store.catalog.flush();
    next.authorization = store.snapshot();
    next.authorization_next_id = store.next_id;
}
pub fn nativeRevoke(engine: anytype, next: *growth.Head, request: g.Request) !void {
    if (request.principal != 0 or request.command.revoke == 0) return error.Forbidden;
    var store = try policy.Store(@TypeOf(engine.page_store.*)).open(engine.page_store, next.authorization);
    store.next_id = next.authorization_next_id;
    store.revision = engine.head.position;
    var credential = (try store.credential(request.command.revoke)) orelse return error.UnknownPrincipal;
    credential.enabled = false;
    credential.epoch = store.revision;
    credential.revision = store.revision;
    try store.putCredential(credential);
    if (credential.native) {
        var role = (try store.role(credential.role)) orelse return error.InvalidAuthorizationState;
        role.retired = true;
        role.enabled = false;
        role.revision = store.revision;
        try store.putRole(role);
    }
    next.authorization = store.snapshot();
    next.authorization_next_id = store.next_id;
}
pub fn rotate(engine: anytype, next: *growth.Head, id: u64, key: [32]u8) !void {
    var store = try policy.Store(@TypeOf(engine.page_store.*)).open(engine.page_store, next.authorization);
    store.next_id = next.authorization_next_id;
    store.revision = engine.head.position;
    var credential = (try store.credential(id)) orelse return error.UnknownPrincipal;
    if (!credential.enabled) return error.Forbidden;
    credential.public_key = key;
    credential.epoch = store.revision;
    credential.revision = store.revision;
    try store.putCredential(credential);
    next.authorization = store.snapshot();
    next.authorization_next_id = store.next_id;
}
pub fn resourceGrant(engine: anytype, next: *growth.Head, subject: u64, resource: u64, permissions: u8) !void {
    var store = try policy.Store(@TypeOf(engine.page_store.*)).open(engine.page_store, next.authorization);
    store.next_id = next.authorization_next_id;
    store.revision = engine.head.position;
    const credential = (try store.credential(subject)) orelse return error.UnknownPrincipal;
    const target = (try store.object(.{ .kind = .resource, .id = resource })) orelse return error.InvalidAuthorizationState;
    if (target.retired and permissions != 0) return error.RetiredAuthorizationObject;
    const key = try c.key(.authorization_native_resource_grant, resource, subject, "");
    var previous: ?a.Grant = null;
    if (try store.catalog.get(u64, key)) |id| previous = (try store.grant(id)) orelse return error.InvalidAuthorizationState;
    var value: a.Grant = if (previous) |old| if (old.grantee == credential.role) old else .{ .id = try store.allocate(), .object = .{ .kind = .resource, .id = resource }, .grantee = credential.role, .grantor = target.owner, .privileges = 0, .revision = store.revision } else .{ .id = try store.allocate(), .object = .{ .kind = .resource, .id = resource }, .grantee = credential.role, .grantor = target.owner, .privileges = 0, .revision = store.revision };
    value.privileges = permissions;
    value.grant_options = 0;
    value.revision = store.revision;
    try store.putGrant(value);
    try store.catalog.put(key, value.id);
    next.authorization = store.snapshot();
    next.authorization_next_id = store.next_id;
}
pub fn resourceAllowed(engine: anytype, subject: growth.Principal, resource: u64, rights: u8) !void {
    if (!subject.enabled) return error.Forbidden;
    var store = try engine.authorization();
    var check = try core.authorization.Evaluator(@TypeOf(store)).init(&store, store.revision, engine.genesis.authorization_limits);
    if (!(try check.evaluate(subject.role, .{ .kind = .resource, .id = resource }, rights)).permits()) return error.Forbidden;
}
pub fn nativeHas(engine: anytype, subject: growth.Principal, pid: ?u64, needed: p.Permission) !bool {
    if (!subject.enabled) return false;
    if (subject.grant.pid) |scope| if (pid != scope) return false;
    const bit = p.permission(needed);
    if (subject.grant.permissions & bit != 0) return true;
    const target = pid orelse return false;
    var store = try engine.authorization();
    const reference: a.ObjectRef = .{ .kind = .process, .id = target };
    if (try store.object(reference) == null) return false;
    var check = try core.authorization.Evaluator(@TypeOf(store)).init(&store, store.revision, engine.genesis.authorization_limits);
    return (try check.evaluate(subject.role, reference, bit)).permits();
}
/// Explicit selection replaces the login role's effective privileges. The
/// credential's PID restriction still bounds every selected role.
pub fn selectedNativeHas(engine: anytype, subject: growth.Principal, selected: ?u64, pid: ?u64, needed: p.Permission) !bool {
    const caller = try actor(engine, subject.grant.subject, selected);
    if (caller.role == subject.role) return nativeHas(engine, subject, pid, needed);
    var store = try engine.authorization();
    var check = try core.authorization.Evaluator(@TypeOf(store)).init(&store, store.revision, engine.genesis.authorization_limits);
    var active = subject;
    active.role = caller.role;
    active.grant.permissions = @intCast((try check.evaluate(caller.role, realm, p.permission(needed))).allowed);
    return nativeHas(engine, active, pid, needed);
}
pub fn retireObject(engine: anytype, next: *growth.Head, reference: a.ObjectRef) !bool {
    var store = try policy.Store(@TypeOf(engine.page_store.*)).open(engine.page_store, next.authorization);
    store.next_id = next.authorization_next_id;
    var target = (try store.object(reference)) orelse return error.InvalidAuthorizationState;
    if (target.retired) return false;
    store.revision = engine.head.position;
    target.retired = true;
    target.revision = store.revision;
    try store.putObject(target);
    next.authorization = store.snapshot();
    next.authorization_next_id = store.next_id;
    return true;
}

pub fn actor(engine: anytype, principal_id: u64, selected: ?u64) !admin.Actor {
    return selectActor(engine, try engine.principal(principal_id), selected);
}

// Authentication already loaded this principal from the current immutable
// native head. Reuse that value for role selection within the same check.
fn selectActor(engine: anytype, identity: growth.Principal, selected: ?u64) !admin.Actor {
    if (!identity.enabled) return error.Forbidden;
    const role = selected orelse identity.role;
    var store = try engine.authorization();
    var check = try core.authorization.Evaluator(@TypeOf(store)).init(&store, store.revision, engine.genesis.authorization_limits);
    if (!try check.canSet(identity.role, role)) return error.Forbidden;
    return .{ .principal = identity.grant.subject, .role = role, .login_role = identity.role };
}

/// The authority authenticates the original subject independently of the
/// executor. Domain owners bind claim.context to their immutable request.
pub fn authenticate(engine: anytype, subject: a.Subject, audience: u64) !a.Verified {
    try subject.validate();
    if (subject.audience() != audience) return error.Forbidden;
    const claim = switch (subject) {
        .signed => |proof| proof.claim,
        .accepted => |value| claim: {
            var state = try engine.state();
            break :claim (try state.get(a.Claim, try c.key(.authorization_origin, value.pid, value.input, ""))) orelse return error.Forbidden;
        },
    };
    try claim.validate();
    if (claim.realm != engine.genesis.realm or claim.audience != audience or claim.principal != subject.principal()) return error.Forbidden;
    const identity = try engine.principal(claim.principal);
    if (!identity.enabled) return error.Forbidden;
    if (identity.credential_epoch != claim.credential_epoch) return error.StaleAuthorizationCredential;
    if (subject == .signed) engine.authorization_proofs.verify(subject.signed, identity.grant.public_key) catch return error.Forbidden;
    const selected = try selectActor(engine, identity, claim.role);
    return .{ .principal = selected.principal, .login_role = identity.role, .role = selected.role, .credential_epoch = identity.credential_epoch, .audience = audience, .context = claim.context };
}
pub fn guard(engine: anytype, value: a.Guard, audience: u64) !a.Verified {
    return guardWithTime(engine, value, audience, .current);
}
/// Native transitions use their recorded time sample; public current checks
/// acquire time only when a declared domain lifetime requires it.
pub fn guardAt(engine: anytype, value: a.Guard, audience: u64, sample: ?core.Time.Sample) !a.Verified {
    return guardWithTime(engine, value, audience, .{ .sampled = sample });
}
const GuardTime = union(enum) { current, sampled: ?core.Time.Sample };
fn guardWithTime(engine: anytype, value: a.Guard, audience: u64, time: GuardTime) !a.Verified {
    try value.validate();
    const subject = try authenticate(engine, value.subject, audience);
    var store = try engine.authorization();
    var check = try core.authorization.Evaluator(@TypeOf(store)).init(&store, store.revision, engine.genesis.authorization_limits);
    if (value.selectable) |role| if (subject.role != a.root_role and !try check.canSet(subject.login_role, role)) return error.Forbidden;
    for (value.requirements) |slot| {
        const required = slot orelse break;
        if (required.access == .ownership) {
            if (!try check.owns(subject.role, required.object)) return error.Forbidden;
        } else {
            const decision = check.evaluate(subject.role, required.object, required.privileges) catch |err| switch (err) {
                error.UnknownAuthorizationObject, error.InvalidAuthorizationPrivilege => return error.Forbidden,
                else => return err,
            };
            const allowed = switch (required.access) {
                .all => decision.permits(),
                .any => decision.allowed != 0,
                .visible => decision.allowed != 0 or try check.owns(subject.role, required.object),
                .ownership => unreachable,
            };
            if (!allowed) return error.Forbidden;
        }
    }
    // Rights and usability are distinct. Only realm administration can bind a
    // domain to a native resource; callers cannot probe arbitrary lifetimes by
    // supplying an unchecked resource ID in their guard. Check these prerequisites
    // under the same native fence as publication, after permission succeeds.
    for (value.requirements) |slot| {
        const required = slot orelse break;
        if (required.object.kind != .domain) continue;
        const object_value = (try store.object(required.object)) orelse return error.Forbidden;
        const domain = (try store.domain(object_value.domain orelse return error.InvalidAuthorizationObject)) orelse return error.InvalidAuthorizationDomain;
        if (domain.lifetime_resource) |resource| requireDomainLifetime(engine, resource, time) catch |err| switch (err) {
            // A known unusable prerequisite denies this guard. Preserve the
            // ordinary rejection path so workers can record a disposition after
            // a publication race; storage/clock uncertainty still propagates.
            error.StateResourceExpired, error.UnknownStateResource => return error.Forbidden,
            else => return err,
        };
    }
    return subject;
}
fn requireDomainLifetime(engine: anytype, resource: u64, time: GuardTime) !void {
    switch (time) {
        .current => try engine.requireResourceLifetime(resource),
        .sampled => |sample| try @import("growing_state.zig").usable(engine, try @import("growing_state.zig").resource(engine, resource), sample),
    }
}
pub fn apply(engine: anytype, candidate: anytype, next: *growth.Head, request: g.Request) !void {
    switch (request.command.authorization) {
        .begin => |value| {
            if (value.expected_revision != engine.head.authorization.revision) return error.StaleAuthorizationRevision;
            const caller = try actor(engine, request.principal, value.role);
            var store = try engine.authorization();
            const registration = if (value.action == .register_object and value.action.register_object.binding != null) try c.key(.authorization_registration, value.action.register_object.domain, 0, &value.action.register_object.binding.?) else null;
            if (registration != null) {
                const domain = (try store.domain(value.action.register_object.domain)) orelse return error.Forbidden;
                if (!domain.enabled or (domain.registrar != caller.principal and caller.role != a.root_role)) return error.Forbidden;
            }
            if (registration) |key| if (try candidate.get(u64, key)) |prior| {
                const previous = (try candidate.get(RecordedChange, growth.address(.authorization_change, prior))) orelse return error.InvalidAuthorizationState;
                if (previous.change.outcome.status != .abandoned) return error.AuthorizationNameExists;
            };
            const change = try admin.begin(&store, caller, engine.head.position, value.action, engine.genesis.authorization_limits, engine.genesis.authorization_change_quota);
            next.authorization_next_id = store.next_id;
            try candidate.put(growth.address(.authorization_change, change.outcome.id), RecordedChange{
                .change = change,
                .begin = .{ .public_key = (try engine.principal(request.principal)).grant.public_key, .digest = try g.digest(request) },
            });
            if (registration) |key| try candidate.put(key, change.outcome.id);
        },
        inline .advance, .publish, .abandon => |id, tag| {
            var recorded = (try candidate.get(RecordedChange, growth.address(.authorization_change, id))) orelse return error.UnknownAuthorizationChange;
            const change = &recorded.change;
            if (change.outcome.principal != request.principal) {
                if (tag != .abandon or (try actor(engine, request.principal, null)).role != a.root_role) return error.Forbidden;
            } else _ = try actor(engine, request.principal, if (tag == .abandon) null else change.outcome.role);
            if (change.outcome.status == .published or change.outcome.status == .abandoned) return error.InvalidAuthorizationChange;
            if (comptime tag == .abandon) {
                change.outcome.status = .abandoned;
            } else {
                if (change.outcome.basis != engine.head.authorization.revision) return error.StaleAuthorizationRevision;
                if (comptime tag == .advance) {
                    var store = try policy.Store(@TypeOf(engine.page_store.*)).open(engine.page_store, change.candidate);
                    store.next_id = engine.head.authorization_next_id;
                    change.candidate.next_id = store.next_id;
                    try admin.advance(&store, change, engine.genesis.authorization_limits);
                    next.authorization_next_id = store.next_id;
                } else {
                    if (change.outcome.status != .ready) return error.InvalidAuthorizationChange;
                    next.authorization = change.candidate;
                    change.outcome.status = .published;
                    if (change.action == .bind_credential) {
                        const bound = change.action.bind_credential.principal;
                        if (try candidate.get(growth.Sequence, growth.address(.principal, bound)) != null) return error.AuthorizationCredentialExists;
                        try candidate.put(growth.address(.principal, bound), growth.Sequence{ .sequence = 0 });
                    }
                }
            }
            try candidate.put(growth.address(.authorization_change, id), recorded);
        },
    }
}

fn cursor(value: ?a.Cursor, revision: u64, scope: [32]u8) !?u64 {
    if (value) |selected| {
        if (selected.revision != revision) return error.StaleAuthorizationRevision;
        if (!std.mem.eql(u8, &scope, &selected.scope)) return error.InvalidAuthorizationCursor;
        return selected.after;
    }
    return null;
}
fn readPage(comptime T: type, page: a.Page(T), revision: u64, scope: [32]u8) a.ReadPage(T) {
    return .{ .records = page.records, .next = if (page.next) |after| .{ .after = after, .revision = revision, .scope = scope } else null };
}
fn records(store: anytype, comptime T: type, namespace: c.Namespace, major: ?u64, after: ?u64) !a.Page(T) {
    const key = if (after) |id| if (major) |scope| try c.key(namespace, scope, id, "") else growth.address(namespace, id) else null;
    const batch = try store.catalog.scan(T, .{ .namespace = namespace, .major = major }, key);
    var page: a.Page(T) = .{};
    var last: ?u64 = null;
    for (batch.records, 0..) |slot, index| if (slot) |record| {
        page.records[index] = record.value;
        last = record.value.id;
    };
    if (batch.next != null) page.next = last orelse return error.InvalidAuthorizationState;
    return page;
}
pub fn read(engine: anytype, identity: growth.Principal, query: a.Query) !a.Result {
    const caller = try actor(engine, identity.grant.subject, query.role);
    var store = try engine.authorization();
    const observer = caller.role == a.root_role or (identity.grant.pid == null and identity.grant.permissions & p.permission(.inspect) != 0);
    const body: @FieldType(a.Result, "body") = switch (query.kind) {
        .receipt => |request| result: {
            if (request.realm != engine.genesis.realm) return error.Forbidden;
            // A process inspector may verify a known send's exact admission.
            // This reveals no request bytes and does not extend inspection to
            // another process or to the sender's administrative operations.
            if (request.principal != identity.grant.subject and caller.role != a.root_role) {
                if (request.command != .send or !try nativeHas(engine, identity, request.command.send.pid, .inspect)) return error.Forbidden;
            }
            var state = try engine.state();
            const receipt = (try state.get(growth.Receipt, try c.key(.receipt, request.principal, request.sequence, ""))) orelse {
                if (request.sequence <= (try engine.principal(request.principal)).sequence) return error.MissingReceipt;
                break :result .{ .receipt = null };
            };
            if (!std.mem.eql(u8, &receipt.digest, &try g.digest(request))) return error.ConflictingRetry;
            break :result .{ .receipt = .{ .position = receipt.position } };
        },
        .preview => |value| result: {
            if (value.expected_revision != store.revision) return error.StaleAuthorizationRevision;
            break :result .{ .preview = try @import("authorization_preview.zig").run(engine.page_store, store.snapshot(), caller, engine.head.position, value.action, engine.genesis.authorization_limits, engine.genesis.authorization_change_quota) };
        },
        inline .authenticate, .check => |value, tag| result: {
            const subject = if (comptime tag == .authenticate) value else value.subject;
            // A caller may ask authority to evaluate its own signed guard.
            // This reveals only that caller's current decision and lets a host
            // forward an action-bound check without a privileged service key.
            // Authenticating someone else (or accepted historical work) retains
            // the audience's native inspection requirement.
            const own_check = comptime tag == .check;
            const original = own_check and subject == .signed and subject.principal() == identity.grant.subject;
            if (!original and !try nativeHas(engine, identity, subject.audience(), .inspect)) return error.Forbidden;
            const verified = if (comptime tag == .authenticate) try authenticate(engine, subject, subject.audience()) else try guard(engine, value, subject.audience());
            break :result @unionInit(@FieldType(a.Result, "body"), @tagName(tag), verified);
        },
        .identity => .{ .identity = .{ .principal = identity.grant.subject, .login_role = identity.role, .credential_epoch = identity.credential_epoch } },
        .decision => |value| result: {
            var check = try core.authorization.Evaluator(@TypeOf(store)).init(&store, store.revision, engine.genesis.authorization_limits);
            const decision = check.evaluate(caller.role, value.object, value.privileges) catch |err| switch (err) {
                error.UnknownAuthorizationObject, error.InvalidAuthorizationPrivilege => return error.Forbidden,
                else => return err,
            };
            if (!decision.permits()) return error.Forbidden;
            break :result .{ .decision = decision };
        },
        inline .role, .resolve => |value, tag| result: {
            const selected = (if (comptime tag == .role) try store.role(value) else try store.named(value)) orelse return error.Forbidden;
            // Named logical roles are the public realm-local role directory.
            // Private native adapters remain undiscoverable to ordinary users.
            if (!observer and selected.id != caller.role and selected.owner != caller.role and (tag == .role or (selected.native and selected.id != a.root_role))) return error.Forbidden;
            break :result @unionInit(@FieldType(a.Result, "body"), @tagName(tag), selected);
        },
        .roles => |value| result: {
            if (!observer) return error.Forbidden;
            const scope = try a.cursorScope(query, engine.genesis.realm, identity.grant.subject, caller.role);
            break :result .{ .roles = readPage(a.Role, try records(&store, a.Role, .authorization_role, null, try cursor(value, store.revision, scope)), store.revision, scope) };
        },
        .memberships => |value| result: {
            if (!observer and value.member != caller.role) return error.Forbidden;
            const scope = try a.cursorScope(query, engine.genesis.realm, identity.grant.subject, caller.role);
            break :result .{ .memberships = readPage(a.Membership, try store.memberships(value.member, try cursor(value.cursor, store.revision, scope)), store.revision, scope) };
        },
        .object => |value| result: {
            const selected = (try store.object(value)) orelse return error.Forbidden;
            if (!observer and selected.owner != caller.role) {
                var check = try core.authorization.Evaluator(@TypeOf(store)).init(&store, store.revision, engine.genesis.authorization_limits);
                if ((try check.evaluate(caller.role, value, selected.actions)).allowed == 0) return error.Forbidden;
            }
            break :result .{ .object = selected };
        },
        .binding => |value| result: {
            const domain = (try store.domain(value.domain)) orelse return error.Forbidden;
            if (!observer and domain.registrar != identity.grant.subject) return error.Forbidden;
            break :result .{ .binding = try store.bound(value.domain, value.key) };
        },
        .registration => |value| result: {
            const domain = (try store.domain(value.domain)) orelse return error.Forbidden;
            if (domain.registrar != identity.grant.subject and caller.role != a.root_role) return error.Forbidden;
            var state = try engine.state();
            const id = (try state.get(u64, try c.key(.authorization_registration, value.domain, 0, &value.key))) orelse break :result .{ .registration = null };
            const recorded = (try state.get(RecordedChange, growth.address(.authorization_change, id))) orelse return error.InvalidAuthorizationState;
            const change = recorded.change;
            break :result .{ .registration = .{ .outcome = change.outcome, .action = change.action } };
        },
        .grants => |value| result: {
            const selected = (try store.object(value.object)) orelse return error.Forbidden;
            if (!observer and value.grantee != caller.role and selected.owner != caller.role) return error.Forbidden;
            const scope = try a.cursorScope(query, engine.genesis.realm, identity.grant.subject, caller.role);
            break :result .{ .grants = readPage(a.Grant, try store.grants(value.object, value.grantee, try cursor(value.cursor, store.revision, scope)), store.revision, scope) };
        },
        .defaults => |value| result: {
            if (!observer and value.creator != caller.role) return error.Forbidden;
            const scope = try a.cursorScope(query, engine.genesis.realm, identity.grant.subject, caller.role);
            break :result .{ .defaults = readPage(a.DefaultGrant, try records(&store, a.DefaultGrant, .authorization_creator_default, value.creator, try cursor(value.cursor, store.revision, scope)), store.revision, scope) };
        },
        inline .change, .operation => |id, tag| result: {
            var state = try engine.state();
            const recorded = (try state.get(RecordedChange, growth.address(.authorization_change, id))) orelse return error.Forbidden;
            const change = recorded.change;
            if (change.outcome.principal != identity.grant.subject and caller.role != a.root_role) return error.Forbidden;
            break :result if (comptime tag == .change) .{ .change = change.outcome } else .{ .operation = .{ .outcome = change.outcome, .action = change.action, .begin = recorded.begin } };
        },
    };
    return .{ .revision = store.revision, .role = caller.role, .body = body };
}
