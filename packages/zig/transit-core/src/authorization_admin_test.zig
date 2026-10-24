const std = @import("std");
const t = std.testing;
const core = @import("root.zig");
const a = core.protocol.Authorization;
const admin = core.authorization_admin;
const Store = core.authorization_store.Store(@import("pages_test.zig").Store);
const root: admin.Actor = .{ .principal = 0, .role = 0 };
const resource: a.ObjectRef = .{ .kind = .resource, .id = 42 };

const Fixture = struct {
    pages: @import("pages_test.zig").Store = .{},
    published: core.authorization_store.Snapshot = undefined,
    serial: u64 = 1,
    fn init(self: *Fixture) !void {
        var store = try Store.open(&self.pages, .{ .catalog = .{}, .revision = 1, .next_id = 1 });
        try store.putRole(.{ .id = 0, .name = try core.Value.init("root"), .owner = 0, .revision = 1, .login = true, .create_role = true });
        try store.putObject(.{ .reference = resource, .owner = 0, .registrar = 0, .actions = 3, .revision = 1 });
        self.published = store.snapshot();
    }
    fn deinit(self: *Fixture) void {
        self.pages.deinit();
    }
    fn begin(self: *Fixture, actor: admin.Actor, action: a.Action) !admin.Change {
        var store = try Store.open(&self.pages, self.published);
        self.serial += 1;
        return admin.begin(&store, actor, self.serial, action, .{}, .{});
    }
    fn finish(self: *Fixture, change: *admin.Change) !void {
        while (change.outcome.status == .preparing) {
            // Reopening between every step exercises the retained candidate.
            var store = try Store.open(&self.pages, change.candidate);
            try admin.advance(&store, change, .{});
        }
        try t.expectEqual(a.Status.ready, change.outcome.status);
        try t.expectEqual(self.published.revision, change.outcome.basis);
        self.published = change.candidate;
    }
    fn apply(self: *Fixture, actor: admin.Actor, action: a.Action) !?u64 {
        var change = try self.begin(actor, action);
        try self.finish(&change);
        return change.outcome.created_id;
    }
    fn role(self: *Fixture, name: []const u8) !u64 {
        return (try self.apply(root, .{ .create_role = .{ .name = try core.Value.init(name), .login = true } })).?;
    }
    fn decision(self: *Fixture, subject: u64, reference: a.ObjectRef) !a.Decision {
        var store = try Store.open(&self.pages, self.published);
        var check = try core.authorization.Evaluator(Store).init(&store, store.revision, .{});
        return check.evaluate(subject, reference, 3);
    }
};

test "administration restrict preserves publication and cascade removes only unsupported paths" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const first = try f.role("first");
    const second = try f.role("second");
    const third = try f.role("third");
    const first_grant = (try f.apply(root, .{ .grant = .{ .object = resource, .grantee = first, .privileges = 3, .grant_options = 3 } })).?;
    _ = try f.apply(.{ .principal = 10, .role = first }, .{ .grant = .{ .object = resource, .grantee = second, .privileges = 3, .grant_options = 3 } });
    _ = try f.apply(.{ .principal = 11, .role = second }, .{ .grant = .{ .object = resource, .grantee = third, .privileges = 3 } });
    _ = try f.apply(root, .{ .grant = .{ .object = resource, .grantee = second, .privileges = 2, .grant_options = 2 } });
    const before = f.published;
    var restricted = try f.begin(root, .{ .revoke = .{ .id = first_grant, .privileges = 3 } });
    try t.expectError(error.AuthorizationDependencies, f.finish(&restricted));
    try t.expect(std.meta.eql(before, f.published));
    try t.expectEqual(@as(u64, 3), (try f.decision(third, resource)).allowed);
    _ = try f.apply(root, .{ .revoke = .{ .id = first_grant, .privileges = 3, .behavior = .cascade } });
    try t.expectEqual(@as(u64, 2), (try f.decision(second, resource)).allowed);
    try t.expectEqual(@as(u64, 2), (try f.decision(third, resource)).allowed);
    // A later independent grant to the old grantor must not revive cascaded work.
    _ = try f.apply(root, .{ .grant = .{ .object = resource, .grantee = first, .privileges = 3, .grant_options = 3 } });
    try t.expectEqual(@as(u64, 2), (try f.decision(third, resource)).allowed);
}

test "ADMIN OPTION cascade closes delegated memberships without revoking independent membership" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const group = try f.role("group");
    const first = try f.role("first");
    const second = try f.role("second");
    const third = try f.role("third");
    _ = try f.apply(root, .{ .grant = .{ .object = resource, .grantee = group, .privileges = 1 } });
    const delegation = (try f.apply(root, .{ .membership = .{ .member = first, .role = group, .admin = true } })).?;
    _ = try f.apply(.{ .principal = 1, .role = first }, .{ .membership = .{ .member = second, .role = group } });
    _ = try f.apply(.{ .principal = 1, .role = first }, .{ .membership = .{ .member = third, .role = group } });
    _ = try f.apply(root, .{ .membership = .{ .member = third, .role = group } });
    _ = try f.apply(root, .{ .revoke_membership = .{ .id = delegation, .option = .admin, .behavior = .cascade } });
    try t.expectEqual(@as(u64, 1), (try f.decision(first, resource)).allowed);
    try t.expectEqual(@as(u64, 0), (try f.decision(second, resource)).allowed);
    try t.expectEqual(@as(u64, 1), (try f.decision(third, resource)).allowed);
    try t.expectError(error.Forbidden, f.begin(.{ .principal = 1, .role = first }, .{ .membership = .{ .member = second, .role = group } }));
    try t.expectError(error.RoleMembershipCycle, f.begin(root, .{ .membership = .{ .member = group, .role = first } }));
}

test "default privileges page into new objects and do not modify existing objects" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const reader = try f.role("reader");
    const class = (try f.apply(root, .{ .register_domain = .{ .registrar = 0, .actions = 3 } })).?;
    const schema_id = (try f.apply(root, .{ .register_object = .{ .domain = class, .owner = 0 } })).?;
    const schema: a.ObjectRef = .{ .kind = .domain, .id = schema_id };
    const old_id = (try f.apply(root, .{ .register_object = .{ .domain = class, .owner = 0, .schema = schema } })).?;
    var defaults: [10]u64 = undefined;
    for (&defaults, 0..) |*id, index| {
        var name: [32]u8 = undefined;
        const grantee = if (index == 9) reader else try f.role(try std.fmt.bufPrint(&name, "other-{d}", .{index}));
        id.* = (try f.apply(root, .{ .default_grant = .{ .creator = 0, .schema = schema, .domain = class, .grantee = grantee, .privileges = 1 } })).?;
    }
    var creation = try f.begin(root, .{ .register_object = .{ .domain = class, .owner = 0, .schema = schema } });
    var published = try Store.open(&f.pages, f.published);
    try t.expectEqual(@as(?a.Object, null), try published.object(.{ .kind = .domain, .id = creation.outcome.created_id.? }));
    try f.finish(&creation);
    try t.expect(creation.outcome.steps >= 3);
    const new_object: a.ObjectRef = .{ .kind = .domain, .id = creation.outcome.created_id.? };
    try t.expectEqual(@as(u64, 0), (try f.decision(reader, .{ .kind = .domain, .id = old_id })).allowed);
    try t.expectEqual(@as(u64, 1), (try f.decision(reader, new_object)).allowed);
    _ = try f.apply(root, .{ .revoke_default = defaults[9] });
    const later = (try f.apply(root, .{ .register_object = .{ .domain = class, .owner = 0, .schema = schema } })).?;
    try t.expectEqual(@as(u64, 0), (try f.decision(reader, .{ .kind = .domain, .id = later })).allowed);
    try t.expectEqual(@as(u64, 1), (try f.decision(reader, new_object)).allowed);
}

test "temporary role disable is distinct from cascading grant removal" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const grantor = try f.role("grantor");
    const reader = try f.role("reader");
    _ = try f.apply(root, .{ .grant = .{ .object = resource, .grantee = grantor, .privileges = 1, .grant_options = 1 } });
    _ = try f.apply(.{ .principal = 1, .role = grantor }, .{ .grant = .{ .object = resource, .grantee = reader, .privileges = 1 } });
    const unrelated = (try f.apply(root, .{ .grant = .{ .object = resource, .grantee = 0, .privileges = 2 } })).?;
    _ = try f.apply(root, .{ .alter_role = .{ .id = grantor, .enabled = false } });
    try t.expectEqual(@as(u64, 0), (try f.decision(reader, resource)).allowed);
    _ = try f.apply(root, .{ .revoke = .{ .id = unrelated, .privileges = 2, .behavior = .cascade } });
    _ = try f.apply(root, .{ .alter_role = .{ .id = grantor, .enabled = true } });
    try t.expectEqual(@as(u64, 1), (try f.decision(reader, resource)).allowed);
}

test "credential rotation preserves role privileges and rejects stale epochs and impersonation" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const reader = try f.role("reader");
    const key = core.Ed25519.KeyPair.generateDeterministic(@splat(21)) catch unreachable;
    const replacement = core.Ed25519.KeyPair.generateDeterministic(@splat(22)) catch unreachable;
    _ = try f.apply(root, .{ .grant = .{ .object = resource, .grantee = reader, .privileges = 1 } });
    _ = try f.apply(root, .{ .bind_credential = .{ .principal = 55, .role = reader, .public_key = key.public_key.toBytes() } });
    var store = try Store.open(&f.pages, f.published);
    const epoch = (try store.credential(55)).?.epoch;
    try t.expectError(error.Forbidden, f.begin(.{ .principal = 56, .role = reader }, .{ .rotate_credential = .{ .principal = 55, .expected_epoch = epoch, .public_key = replacement.public_key.toBytes() } }));
    _ = try f.apply(.{ .principal = 55, .role = reader }, .{ .rotate_credential = .{ .principal = 55, .expected_epoch = epoch, .public_key = replacement.public_key.toBytes() } });
    try t.expectEqual(@as(u64, 1), (try f.decision(reader, resource)).allowed);
    try t.expectError(error.StaleAuthorizationCredential, f.begin(root, .{ .disable_credential = .{ .principal = 55, .expected_epoch = epoch } }));
    store = try Store.open(&f.pages, f.published);
    try t.expectEqual(reader, (try store.credential(55)).?.role);
    try t.expect(!std.mem.eql(u8, &key.public_key.toBytes(), &(try store.credential(55)).?.public_key));
}

test "administration change quota fails before publication" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const reader = try f.role("reader");
    const edge = (try f.apply(root, .{ .grant = .{ .object = resource, .grantee = reader, .privileges = 1 } })).?;
    const before = f.published;
    var change = try f.begin(root, .{ .revoke = .{ .id = edge, .privileges = 1 } });
    change.quota.steps = 1;
    try t.expectError(error.AuthorizationChangeQuota, f.finish(&change));
    try t.expect(std.meta.eql(before, f.published));
}

test "ownership transfer preserves delegated grants and role retirement checks owned objects" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const next_owner = try f.role("next-owner");
    const reader = try f.role("reader");
    _ = try f.apply(root, .{ .grant = .{ .object = resource, .grantee = reader, .privileges = 1, .grant_options = 1 } });
    _ = try f.apply(root, .{ .transfer_object = .{ .object = resource, .owner = next_owner } });
    try t.expectEqual(@as(u64, 1), (try f.decision(reader, resource)).allowed);
    try t.expectEqual(@as(u64, 3), (try f.decision(next_owner, resource)).grantable);
    var retirement = try f.begin(root, .{ .retire_role = .{ .id = next_owner, .behavior = .cascade } });
    try t.expectError(error.AuthorizationDependencies, f.finish(&retirement));
    _ = try f.apply(root, .{ .transfer_object = .{ .object = resource, .owner = 0 } });
    _ = try f.apply(root, .{ .retire_role = .{ .id = next_owner, .behavior = .cascade } });
    try t.expectEqual(@as(u64, 1), (try f.decision(reader, resource)).allowed);
}

test "retiring a role cascades credential and default dependencies without resurrecting names" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const reader = try f.role("reader");
    const class = (try f.apply(root, .{ .register_domain = .{ .registrar = 0, .actions = 3 } })).?;
    const key = core.Ed25519.KeyPair.generateDeterministic(@splat(32)) catch unreachable;
    _ = try f.apply(root, .{ .bind_credential = .{ .principal = 7, .role = reader, .public_key = key.public_key.toBytes() } });
    _ = try f.apply(root, .{ .default_grant = .{ .creator = 0, .schema = resource, .domain = class, .grantee = reader, .privileges = 1 } });
    var restricted = try f.begin(root, .{ .retire_role = .{ .id = reader } });
    try t.expectError(error.AuthorizationDependencies, f.finish(&restricted));
    _ = try f.apply(root, .{ .retire_role = .{ .id = reader, .behavior = .cascade } });
    var store = try Store.open(&f.pages, f.published);
    try t.expect(!(try store.credential(7)).?.enabled);
    const replacement = try f.role("reader");
    try t.expect(replacement != reader);
    const object_id = (try f.apply(root, .{ .register_object = .{ .domain = class, .owner = 0, .schema = resource } })).?;
    try t.expectEqual(@as(u64, 0), (try f.decision(replacement, .{ .kind = .domain, .id = object_id })).allowed);
}

test "revoking INHERIT retains SET until separately revoked" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const group = try f.role("group");
    const member = try f.role("member");
    _ = try f.apply(root, .{ .grant = .{ .object = resource, .grantee = group, .privileges = 1 } });
    const membership = (try f.apply(root, .{ .membership = .{ .member = member, .role = group } })).?;
    _ = try f.apply(root, .{ .revoke_membership = .{ .id = membership, .option = .inherit } });
    try t.expectEqual(@as(u64, 0), (try f.decision(member, resource)).allowed);
    var store = try Store.open(&f.pages, f.published);
    var check = try core.authorization.Evaluator(Store).init(&store, store.revision, .{});
    try t.expect(try check.canSet(member, group));
    _ = try f.apply(root, .{ .revoke_membership = .{ .id = membership, .option = .set } });
    store = try Store.open(&f.pages, f.published);
    check = try core.authorization.Evaluator(Store).init(&store, store.revision, .{});
    try t.expect(!try check.canSet(member, group));
}

test "repeated grants reconcile one author's edge and target revocation preserves independent grantors" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const first = try f.role("first");
    const second = try f.role("second");
    const reader = try f.role("reader");
    _ = try f.apply(root, .{ .grant = .{ .object = resource, .grantee = first, .privileges = 3, .grant_options = 3 } });
    _ = try f.apply(root, .{ .grant = .{ .object = resource, .grantee = second, .privileges = 3, .grant_options = 3 } });
    const actor: admin.Actor = .{ .principal = 10, .role = first };
    const edge = try f.apply(actor, .{ .grant = .{ .object = resource, .grantee = reader, .privileges = 1, .grant_options = 1 } });
    try t.expectEqual(edge, try f.apply(actor, .{ .grant = .{ .object = resource, .grantee = reader, .privileges = 2 } }));
    _ = try f.apply(.{ .principal = 11, .role = second }, .{ .grant = .{ .object = resource, .grantee = reader, .privileges = 2 } });
    _ = try f.apply(actor, .{ .revoke_privileges = .{ .object = resource, .grantee = reader, .privileges = 3 } });
    try t.expectEqual(@as(u64, 2), (try f.decision(reader, resource)).allowed);
    var store = try Store.open(&f.pages, f.published);
    try t.expectEqual(@as(u64, 0), (try store.grant(edge.?)).?.privileges);
    _ = try f.apply(actor, .{ .revoke_privileges = .{ .object = resource, .grantee = reader, .privileges = 3 } });
    try t.expectEqual(@as(u64, 2), (try f.decision(reader, resource)).allowed);
}

test "new SET-only membership and unchanged options preserve unrelated inactive grants" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const issuer = try f.role("issuer");
    const consumer = try f.role("consumer");
    const member = try f.role("member");
    const group = try f.role("group");
    _ = try f.apply(root, .{ .grant = .{ .object = resource, .grantee = issuer, .privileges = 1, .grant_options = 1 } });
    _ = try f.apply(.{ .principal = 10, .role = issuer }, .{ .grant = .{ .object = resource, .grantee = consumer, .privileges = 1 } });
    _ = try f.apply(root, .{ .alter_role = .{ .id = issuer, .enabled = false } });
    try t.expectEqual(0, (try f.decision(consumer, resource)).allowed);

    const action: a.Action = .{ .membership = .{ .member = member, .role = group, .inherit = false, .set = true } };
    const edge = try f.apply(root, action);
    try t.expectEqual(edge, try f.apply(root, action));
    var store = try Store.open(&f.pages, f.published);
    var check = try core.authorization.Evaluator(Store).init(&store, store.revision, .{});
    try t.expect(try check.canSet(member, group));
    try t.expect(!try check.inherits(member, group));
    try t.expectEqual(0, (try f.decision(consumer, resource)).allowed);
    _ = try f.apply(root, .{ .alter_role = .{ .id = issuer, .enabled = true } });
    try t.expectEqual(1, (try f.decision(consumer, resource)).allowed);
}

test "membership reconciliation preserves omitted options and target revocation checks dependencies" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const group = try f.role("group");
    const member = try f.role("member");
    const delegate = try f.role("delegate");
    const edge = try f.apply(root, .{ .membership = .{ .member = member, .role = group, .admin = true, .inherit = false } });
    try t.expectEqual(edge, try f.apply(root, .{ .membership = .{ .member = member, .role = group, .set = false } }));
    var store = try Store.open(&f.pages, f.published);
    const membership = (try store.membership(edge.?)).?;
    try t.expect(membership.admin and !membership.inherit and !membership.set);
    _ = try f.apply(.{ .principal = 10, .role = member }, .{ .membership = .{ .member = delegate, .role = group } });
    const before = f.published;
    var reduced = try f.begin(root, .{ .membership = .{ .member = member, .role = group, .admin = false } });
    try t.expectError(error.AuthorizationDependencies, f.finish(&reduced));
    try t.expect(std.meta.eql(before, f.published));
    var restricted = try f.begin(root, .{ .revoke_role = .{ .member = member, .role = group, .option = .admin } });
    try t.expectError(error.AuthorizationDependencies, f.finish(&restricted));
    _ = try f.apply(root, .{ .revoke_role = .{ .member = member, .role = group, .option = .admin, .behavior = .cascade } });
    store = try Store.open(&f.pages, f.published);
    try t.expect((try store.memberships(delegate, null)).records[0] == null);
}

test "default privilege reconciliation and partial revoke affect only future objects" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const reader = try f.role("reader");
    const class = (try f.apply(root, .{ .register_domain = .{ .registrar = 0, .actions = 3 } })).?;
    const first = try f.apply(root, .{ .default_grant = .{ .creator = 0, .schema = resource, .domain = class, .grantee = reader, .privileges = 1, .grant_options = 1 } });
    try t.expectEqual(first, try f.apply(root, .{ .default_grant = .{ .creator = 0, .schema = resource, .domain = class, .grantee = reader, .privileges = 2 } }));
    const old = (try f.apply(root, .{ .register_object = .{ .domain = class, .owner = 0, .schema = resource } })).?;
    _ = try f.apply(root, .{ .revoke_defaults = .{ .creator = 0, .schema = resource, .domain = class, .grantee = reader, .privileges = 1 } });
    const fresh = (try f.apply(root, .{ .register_object = .{ .domain = class, .owner = 0, .schema = resource } })).?;
    try t.expectEqual(@as(u64, 3), (try f.decision(reader, .{ .kind = .domain, .id = old })).allowed);
    try t.expectEqual(@as(u64, 2), (try f.decision(reader, .{ .kind = .domain, .id = fresh })).allowed);
}

test "ownership transfer uses login SET eligibility independently of active role INHERIT" {
    var f: Fixture = .{};
    defer f.deinit();
    try f.init();
    const owner_role = try f.role("owner");
    const login = try f.role("login");
    const next_owner = try f.role("next-owner");
    _ = try f.apply(root, .{ .transfer_object = .{ .object = resource, .owner = owner_role } });
    _ = try f.apply(root, .{ .membership = .{ .member = owner_role, .role = next_owner, .inherit = true, .set = false } });
    const actor: admin.Actor = .{ .principal = 42, .role = owner_role, .login_role = login };
    try t.expectError(error.Forbidden, f.begin(actor, .{ .transfer_object = .{ .object = resource, .owner = next_owner } }));
    _ = try f.apply(root, .{ .membership = .{ .member = login, .role = next_owner, .inherit = false, .set = true } });
    _ = try f.apply(actor, .{ .transfer_object = .{ .object = resource, .owner = next_owner } });
    var store = try Store.open(&f.pages, f.published);
    try t.expectEqual(next_owner, (try store.object(resource)).?.owner);
}
