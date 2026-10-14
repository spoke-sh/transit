//! Revision-bound private policy changes. The native owner authenticates Actor,
//! persists each Change with its exact request receipt and publishes only ready
//! candidates whose basis still matches. No routine here publishes authority.
const std = @import("std");
const core = @import("root.zig");
const a = core.protocol.Authorization;
const c = core.catalog;
const policy = core.authorization_store;

pub const Actor = struct { principal: u64, role: u64 };
pub const Quota = struct { steps: u64 = 65_536, changed_records: u64 = 1_000_000 };
pub const Change = struct {
    outcome: a.Outcome,
    candidate: policy.Snapshot,
    action: a.Action,
    phase: enum { defaults, memberships, grants, role_dependencies, role_owners, role_credentials, role_defaults, transfer_grants, ready },
    previous_owner: ?u64 = null,
    after: ?core.pages.Key = null,
    quota: Quota,
};

fn evaluator(store: anytype, limits: a.Limits) !core.authorization.Evaluator(@TypeOf(store.*)) {
    return core.authorization.Evaluator(@TypeOf(store.*)).init(store, store.revision, limits);
}
fn liveRole(store: anytype, id: u64) !a.Role {
    const value = (try store.role(id)) orelse return error.UnknownAuthorizationRole;
    if (value.retired) return error.RetiredAuthorizationRole;
    return value;
}
fn grantee(store: anytype, id: u64) !void {
    if (id != a.public_role) _ = try liveRole(store, id);
}
fn logicalOwner(store: anytype, id: u64) !void {
    const value = try liveRole(store, id);
    if (value.native and id != a.root_role) return error.InvalidAuthorizationRole;
}
fn roleName(value: core.Value) !void {
    try a.name(value);
    if (std.ascii.eqlIgnoreCase(value.slice(), "public") or std.mem.startsWith(u8, value.slice(), "native/")) return error.InvalidAuthorizationName;
}
fn object(store: anytype, reference: a.ObjectRef) !a.Object {
    const value = (try store.object(reference)) orelse return error.UnknownAuthorizationObject;
    if (value.retired) return error.RetiredAuthorizationObject;
    return value;
}
fn owner(store: anytype, actor: Actor, role: u64, limits: a.Limits) !void {
    var check = try evaluator(store, limits);
    if (actor.role != a.root_role and !try check.inherits(actor.role, role)) return error.Forbidden;
}
fn domain(store: anytype, id: u64) !a.Domain {
    const value = (try store.domain(id)) orelse return error.InvalidAuthorizationDomain;
    if (!value.enabled) return error.InvalidAuthorizationDomain;
    return value;
}
fn credentialOwner(store: anytype, actor: Actor, principal: u64) !a.Credential {
    // A role owner cannot impersonate an existing credential's principal.
    if (actor.role != a.root_role and actor.principal != principal) return error.Forbidden;
    if (principal == 0) return error.Forbidden;
    const value = (try store.credential(principal)) orelse return error.UnknownPrincipal;
    return value;
}
fn changed(change: *Change) !void {
    if (change.outcome.changed_records == change.quota.changed_records) return error.AuthorizationChangeQuota;
    change.outcome.changed_records += 1;
}
fn behavior(action: a.Action) a.RevokeBehavior {
    return switch (action) {
        inline .revoke, .revoke_membership, .retire_role => |value| value.behavior,
        else => .cascade,
    };
}

pub fn begin(store: anytype, actor: Actor, id: u64, action: a.Action, limits: a.Limits, quota: Quota) !Change {
    try a.revision(id);
    if (id <= store.revision or quota.steps == 0 or quota.changed_records == 0) return error.InvalidAuthorizationRevision;
    const caller = try liveRole(store, actor.role);
    if (!caller.enabled) return error.Forbidden;
    const basis = store.revision;
    store.revision = id;
    var change: Change = .{ .outcome = .{ .id = id, .principal = actor.principal, .role = actor.role, .basis = basis, .revision = id, .status = .preparing, .created_id = null, .changed_records = 0, .steps = 1 }, .candidate = store.snapshot(), .action = action, .phase = .ready, .quota = quota };
    switch (action) {
        .create_role => |value| {
            try roleName(value.name);
            if (!caller.create_role and actor.role != a.root_role) return error.Forbidden;
            if (value.create_role and actor.role != a.root_role) return error.Forbidden;
            const created = try store.allocate();
            try store.putRole(.{ .id = created, .name = value.name, .owner = actor.role, .revision = id, .login = value.login, .create_role = value.create_role });
            change.outcome.created_id = created;
        },
        .alter_role => |value| {
            var target = try liveRole(store, value.id);
            if (value.id == a.root_role or target.native) return error.Forbidden;
            try owner(store, actor, target.owner, limits);
            if (value.create_role != null and actor.role != a.root_role) return error.Forbidden;
            if (value.name) |name| {
                try roleName(name);
                target.name = name;
            }
            if (value.owner) |new_owner| {
                try logicalOwner(store, new_owner);
                try owner(store, actor, new_owner, limits);
                target.owner = new_owner;
            }
            if (value.login) |login| target.login = login;
            if (value.enabled) |enabled| target.enabled = enabled;
            if (value.create_role) |create_role| target.create_role = create_role;
            target.revision = id;
            try store.putRole(target);
        },
        .retire_role => |value| {
            var target = try liveRole(store, value.id);
            if (value.id == a.root_role or value.id == actor.role or target.native) return error.Forbidden;
            try owner(store, actor, target.owner, limits);
            target.retired = true;
            target.enabled = false;
            target.revision = id;
            try store.putRole(target);
            change.phase = .role_dependencies;
        },
        .membership => |value| {
            _ = try liveRole(store, value.member);
            _ = try liveRole(store, value.role);
            var check = try evaluator(store, limits);
            if (!try check.admin(actor.role, value.role)) return error.Forbidden;
            if (try check.wouldCycle(value.member, value.role)) return error.RoleMembershipCycle;
            const created = try store.allocate();
            try store.putMembership(.{ .id = created, .member = value.member, .role = value.role, .grantor = actor.role, .revision = id, .admin = value.admin, .inherit = value.inherit, .set = value.set });
            change.outcome.created_id = created;
        },
        .revoke_membership => |value| {
            var edge = (try store.membership(value.id)) orelse return error.UnknownRoleMembership;
            var check = try evaluator(store, limits);
            if (actor.role != edge.grantor and !try check.admin(actor.role, edge.role)) return error.Forbidden;
            if (value.option) |option| switch (option) {
                .admin => edge.admin = false,
                .inherit => edge.inherit = false,
                .set => edge.set = false,
            } else edge.enabled = false;
            edge.revision = id;
            try store.putMembership(edge);
            change.phase = .memberships;
        },
        .register_domain => |value| {
            if (actor.role != a.root_role) return error.Forbidden;
            const created = try store.allocate();
            try store.putDomain(.{ .id = created, .registrar = value.registrar, .actions = value.actions, .revision = id });
            change.outcome.created_id = created;
        },
        .register_object => |value| {
            const class = try domain(store, value.domain);
            if (class.registrar != actor.principal) return error.Forbidden;
            if (value.binding) |binding| if (try store.bound(value.domain, binding) != null) return error.AuthorizationNameExists;
            try logicalOwner(store, value.owner);
            if (value.schema) |schema| _ = try object(store, schema);
            const created = try store.allocate();
            const reference: a.ObjectRef = .{ .kind = .domain, .id = created };
            try store.putObject(.{ .reference = reference, .owner = value.owner, .registrar = actor.principal, .domain = class.id, .binding = value.binding, .parent = value.schema, .actions = class.actions, .revision = id });
            try store.putGrant(.{ .id = try store.allocate(), .object = reference, .grantee = value.owner, .grantor = value.owner, .privileges = class.actions, .revision = id });
            try changed(&change);
            change.outcome.created_id = created;
            if (value.schema != null) change.phase = .defaults;
        },
        .transfer_object => |value| {
            var target = try object(store, value.object);
            try owner(store, actor, target.owner, limits);
            try logicalOwner(store, value.owner);
            // Transfer may only assign a role that the actor can exercise;
            // registrars can perform an explicitly attributed domain transfer.
            if (actor.principal != target.registrar) try owner(store, actor, value.owner, limits);
            change.previous_owner = target.owner;
            target.owner = value.owner;
            target.revision = id;
            try store.putObject(target);
            change.phase = .transfer_grants;
        },
        .retire_object => |reference| {
            var target = try object(store, reference);
            if (target.registrar != actor.principal) return error.Forbidden;
            target.retired = true;
            target.revision = id;
            try store.putObject(target);
            change.phase = .grants;
        },
        .grant => |value| {
            const target = try object(store, value.object);
            try grantee(store, value.grantee);
            var check = try evaluator(store, limits);
            const grantor = if (actor.role == a.root_role or try check.inherits(actor.role, target.owner)) target.owner else actor.role;
            if (actor.role == a.root_role) check.include_disabled = true;
            const decision = try check.evaluate(grantor, value.object, value.privileges);
            if (decision.grantable & value.privileges != value.privileges) return error.Forbidden;
            const created = try store.allocate();
            try store.putGrant(.{ .id = created, .object = value.object, .grantee = value.grantee, .grantor = grantor, .privileges = value.privileges, .grant_options = value.grant_options, .revision = id });
            change.outcome.created_id = created;
        },
        .revoke => |value| {
            var edge = (try store.grant(value.id)) orelse return error.UnknownAuthorizationGrant;
            const target = try object(store, edge.object);
            var check = try evaluator(store, limits);
            if (actor.role == a.root_role) {
                if (edge.grantor != target.owner) return error.Forbidden;
            } else if (!try check.inherits(actor.role, edge.grantor)) return error.Forbidden;
            try a.mask(value.privileges);
            if (value.privileges & ~target.actions != 0) return error.InvalidAuthorizationPrivilege;
            edge.grant_options &= ~value.privileges;
            if (!value.grant_option_only) edge.privileges &= ~value.privileges;
            edge.revision = id;
            try store.putGrant(edge);
            change.phase = .grants;
        },
        .default_grant => |value| {
            try owner(store, actor, value.creator, limits);
            try logicalOwner(store, value.creator);
            _ = try object(store, value.schema);
            const class = try domain(store, value.domain);
            try grantee(store, value.grantee);
            if (value.privileges & ~class.actions != 0) return error.InvalidAuthorizationPrivilege;
            const created = try store.allocate();
            try store.putDefault(.{ .id = created, .creator = value.creator, .schema = value.schema, .domain = value.domain, .grantee = value.grantee, .privileges = value.privileges, .grant_options = value.grant_options, .revision = id });
            change.outcome.created_id = created;
        },
        .revoke_default => |target| {
            var value = (try store.defaultGrant(target)) orelse return error.UnknownAuthorizationGrant;
            try owner(store, actor, value.creator, limits);
            value.enabled = false;
            value.revision = id;
            try store.putDefault(value);
        },
        .bind_credential => |value| {
            if (actor.role != a.root_role or value.principal == 0) return error.Forbidden;
            if (try store.credential(value.principal) != null) return error.AuthorizationCredentialExists;
            const target = try liveRole(store, value.role);
            if (!target.login or !target.enabled or target.native) return error.Forbidden;
            try store.putCredential(.{ .principal = value.principal, .public_key = value.public_key, .role = value.role, .pid = value.pid, .epoch = id, .revision = id, .enabled = true });
        },
        .rotate_credential => |value| {
            var credential = try credentialOwner(store, actor, value.principal);
            if (!credential.enabled or credential.epoch != value.expected_epoch) return error.StaleAuthorizationCredential;
            if (std.mem.eql(u8, &credential.public_key, &value.public_key)) return error.InvalidAuthorizationCredential;
            credential.public_key = value.public_key;
            credential.epoch = id;
            credential.revision = id;
            try store.putCredential(credential);
        },
        .disable_credential => |value| {
            var credential = try credentialOwner(store, actor, value.principal);
            if (credential.epoch != value.expected_epoch) return error.StaleAuthorizationCredential;
            credential.enabled = false;
            credential.epoch = id;
            credential.revision = id;
            try store.putCredential(credential);
        },
    }
    try changed(&change);
    if (change.phase == .ready) change.outcome.status = .ready;
    change.candidate = store.snapshot();
    return change;
}

/// At most one eight-record catalog page is processed per step. Every dependent
/// edge decision has its own fixed evaluator budget. The candidate is invisible
/// throughout; RESTRICT errors must preserve the previously persisted Change.
pub fn advance(store: anytype, change: *Change, limits: a.Limits) !void {
    if (change.outcome.status != .preparing or !std.meta.eql(store.snapshot(), change.candidate)) return error.InvalidAuthorizationChange;
    if (change.outcome.steps == change.quota.steps) return error.AuthorizationChangeQuota;
    switch (change.phase) {
        .ready => return error.InvalidAuthorizationChange,
        .defaults => {
            const create = change.action.register_object;
            const batch = try store.catalog.scan(a.DefaultGrant, .{ .namespace = .authorization_creator_default, .major = create.owner }, change.after);
            for (batch.records) |slot| if (slot) |record| {
                const value = record.value;
                if (!value.enabled or value.domain != create.domain or !value.schema.eql(create.schema.?)) continue;
                try value.validate();
                try grantee(store, value.grantee);
                try changed(change);
                try store.putGrant(.{ .id = try store.allocate(), .object = .{ .kind = .domain, .id = change.outcome.created_id.? }, .grantee = value.grantee, .grantor = create.owner, .privileges = value.privileges, .grant_options = value.grant_options, .revision = store.revision });
            };
            change.after = batch.next;
            if (change.after == null) change.phase = .ready;
        },
        .role_dependencies => {
            const retired = change.action.retire_role.id;
            const batch = try store.catalog.scan(a.Object, .{ .namespace = .authorization_object }, change.after);
            for (batch.records) |slot| if (slot) |record| {
                // Ownership must be explicitly transferred or objects retired.
                if (!record.value.retired and record.value.owner == retired) return error.AuthorizationDependencies;
            };
            change.after = batch.next;
            if (change.after == null) change.phase = .role_owners;
        },
        .role_owners => {
            const retired = change.action.retire_role.id;
            const batch = try store.catalog.scan(a.Role, .{ .namespace = .authorization_role }, change.after);
            for (batch.records) |slot| if (slot) |record| {
                if (!record.value.retired and record.value.owner == retired) return error.AuthorizationDependencies;
            };
            change.after = batch.next;
            if (change.after == null) change.phase = .role_credentials;
        },
        .role_credentials => {
            const retired = change.action.retire_role.id;
            const batch = try store.catalog.scan(a.Credential, .{ .namespace = .authorization_credential }, change.after);
            for (batch.records) |slot| if (slot) |record| {
                var value = record.value;
                if (!value.enabled or value.role != retired) continue;
                if (behavior(change.action) == .restrict) return error.AuthorizationDependencies;
                try changed(change);
                value.enabled = false;
                value.epoch = store.revision;
                value.revision = store.revision;
                try store.putCredential(value);
            };
            change.after = batch.next;
            if (change.after == null) change.phase = .role_defaults;
        },
        .role_defaults => {
            const retired = change.action.retire_role.id;
            const batch = try store.catalog.scan(a.DefaultGrant, .{ .namespace = .authorization_default }, change.after);
            for (batch.records) |slot| if (slot) |record| {
                var value = record.value;
                if (!value.enabled or (value.creator != retired and value.grantee != retired)) continue;
                if (behavior(change.action) == .restrict) return error.AuthorizationDependencies;
                try changed(change);
                value.enabled = false;
                value.revision = store.revision;
                try store.putDefault(value);
            };
            change.after = batch.next;
            if (change.after == null) change.phase = .memberships;
        },
        .transfer_grants => {
            const transfer = change.action.transfer_object;
            const batch = try store.catalog.scan(a.Grant, .{ .namespace = .authorization_grant }, change.after);
            for (batch.records) |slot| if (slot) |record| {
                const value = record.value;
                if (!value.object.eql(transfer.object) or (value.grantor != change.previous_owner.? and value.grantee != change.previous_owner.?)) continue;
                try changed(change);
                try store.transferGrant(value, change.previous_owner.?, transfer.owner);
            };
            change.after = batch.next;
            if (change.after == null) change.phase = .ready;
        },
        .memberships => {
            const batch = try store.catalog.scan(a.Membership, .{ .namespace = .authorization_membership }, change.after);
            for (batch.records) |slot| if (slot) |record| {
                var edge = record.value;
                if (!edge.enabled) continue;
                var check = try evaluator(store, limits);
                check.include_disabled = true;
                if (try check.validMembership(edge)) continue;
                if (behavior(change.action) == .restrict) return error.AuthorizationDependencies;
                try changed(change);
                edge.enabled = false;
                edge.revision = store.revision;
                try store.putMembership(edge);
            };
            change.after = batch.next;
            if (change.after == null) change.phase = .grants;
        },
        .grants => {
            const batch = try store.catalog.scan(a.Grant, .{ .namespace = .authorization_grant }, change.after);
            for (batch.records) |slot| if (slot) |record| {
                var edge = record.value;
                if (!edge.enabled or edge.privileges == 0) continue;
                var check = try evaluator(store, limits);
                check.include_disabled = true;
                const decision = try check.evaluate(edge.grantor, edge.object, edge.privileges);
                const target = if (edge.grantee == a.public_role) null else try store.role(edge.grantee);
                const valid = if (edge.grantee != a.public_role and (target == null or target.?.retired)) 0 else decision.grantable;
                const unsupported = edge.privileges & ~valid;
                if (unsupported == 0) continue;
                if (behavior(change.action) == .restrict) return error.AuthorizationDependencies;
                try changed(change);
                edge.privileges &= ~unsupported;
                edge.grant_options &= ~unsupported;
                edge.revision = store.revision;
                try store.putGrant(edge);
            };
            change.after = batch.next;
            if (change.after == null) change.phase = .ready;
        },
    }
    change.outcome.steps += 1;
    if (change.phase == .ready) change.outcome.status = .ready;
    change.candidate = store.snapshot();
}
