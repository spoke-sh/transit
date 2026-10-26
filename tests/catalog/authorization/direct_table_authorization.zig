//! Selected Table roles do not confer native process or resource access.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const p = q.protocol;
const t = std.testing;
const support = @import("fixture_direct_captured_query");

/// Installed ABI/SDK consumers must select their non-inherited data role. They
/// receive no native process/resource rights and use a distinct login/key.
pub fn installed(owner: c.DirectTableClient, admin: anytype, owner_role: u64) !u64 {
    const principal = 941002;
    const credential = try support.key(123);
    const login = (try admin.change(.{ .create_role = .{ .name = try p.Value.init("installed-selected-login"), .login = true } })).?;
    _ = try admin.change(.{ .bind_credential = .{ .principal = principal, .role = login, .public_key = credential.public_key.toBytes() } });
    try selection(admin, login, owner_role, true);
    var caller = owner;
    caller.connection.principal = principal;
    caller.connection.role = null;
    caller.key = credential;
    try t.expectError(error.AccessDenied, caller.call(.describe));
    caller.connection.role = owner_role;
    const description = try caller.call(.describe);
    defer description.deinit();
    try t.expectEqual(owner_role, description.value.subject.role);
    const native: q.station.client.ResourceReader = .{ .wire = caller.authority, .realm = caller.connection.scope.realm, .principal = principal, .key = credential };
    try t.expectError(error.AccessDenied, native.open(caller.connection.scope.resource));
    return login;
}

pub fn selection(admin: anytype, login: u64, role: u64, allow: bool) !void {
    _ = try admin.change(if (allow) .{ .membership = .{ .member = login, .role = role, .inherit = false, .set = true } } else .{ .revoke_role = .{ .member = login, .role = role, .option = .set, .behavior = .cascade } });
}

pub fn run(init: std.process.Init, owner: c.DirectTableClient, admin: anytype, owner_role: u64) !void {
    const principal = 941000;
    const credential = try support.key(121);
    const login = (try admin.change(.{ .create_role = .{ .name = try p.Value.init("selected-table-login"), .login = true } })).?;
    _ = try admin.change(.{ .bind_credential = .{ .principal = principal, .role = login, .public_key = credential.public_key.toBytes() } });
    _ = try admin.change(.{ .membership = .{ .member = login, .role = owner_role, .inherit = false, .set = true } });
    try support.table(init.arena.allocator(), owner, owner_role, 904, "selected_rows", 94000, 1);
    var caller = owner;
    caller.connection.principal = principal;
    caller.key = credential;
    const lookup: c.DirectTableProtocol.Action = .{ .lookup = .{ .namespace = 1, .name = "selected_rows" } };
    try t.expectError(error.AccessDenied, caller.call(lookup));
    caller.connection.role = owner_role;
    const metadata = try caller.call(lookup);
    defer metadata.deinit();
    const definition = metadata.value.result.lookup.?;
    const pinned = try caller.call(.{ .pin = .{
        .object = definition.interpretation.interpretation.object,
        .owner = .{ .scope = caller.connection.scope, .principal = principal, .operation = 94003 },
        .expected = definition.position,
    } });
    defer pinned.deinit();
    const snapshot: c.DirectTableProtocol.Snapshot = .{ .object = definition.interpretation.interpretation.object, .handle = pinned.value.result.pin };
    var reader = try c.DirectTableReader.open(init.gpa, caller, snapshot);
    defer reader.deinit();
    var page = (try reader.next(caller, .{})).?;
    defer page.deinit();
    try t.expect(page.complete);
    try t.expectEqual(@as(usize, 1), page.count);

    const native: q.station.client.ResourceReader = .{ .wire = caller.authority, .realm = 42, .principal = principal, .key = credential };
    try t.expectError(error.AccessDenied, native.open(caller.connection.scope.resource));
    const unrelated_process = try admin.submit(.{ .spawn = .{} });
    try t.expectError(error.AccessDenied, caller.authority.query(.{ .realm = 42, .principal = principal, .kind = .{ .process = unrelated_process } }, credential));

    // Current role selection is checked again even for an already accepted pin
    // and a reader which previously reached its terminal page.
    _ = try admin.change(.{ .revoke_role = .{ .member = login, .role = owner_role, .option = .set, .behavior = .cascade } });
    try t.expectError(error.AccessDenied, caller.call(lookup));
    try t.expectError(error.AccessDenied, c.DirectTableReader.open(init.gpa, caller, snapshot));
    try t.expectError(error.AccessDenied, caller.call(.{ .release = snapshot }));
    _ = try admin.change(.{ .membership = .{ .member = login, .role = owner_role, .inherit = false, .set = true } });
    var restored = try c.DirectTableReader.open(init.gpa, caller, snapshot);
    defer restored.deinit();
    try t.expectEqualDeep(reader.basis, restored.basis);
    var repeated = (try restored.next(caller, .{})).?;
    defer repeated.deinit();
    try t.expect(repeated.complete);
    try t.expectEqual(@as(usize, 1), repeated.count);
    (try caller.call(.{ .release = snapshot })).deinit();
    caller.connection.role = null;
    try t.expectError(error.AccessDenied, caller.call(lookup));
    try defaults(init, owner, admin, owner_role);
}

/// Publish the SQL-resolved native change as the database owner, preserving its
/// observed revision. Root creates the login only; it does not grant data rights.
fn policy(owner: c.DirectTableClient, sql: []const u8) !void {
    const plan = try c.DirectAuthorizationSql.compile(owner, 1, sql, .{}, null);
    const authority: q.station.client.AuthorizationClient = .{ .transport = owner.authority, .realm = owner.connection.scope.realm, .principal = owner.connection.principal, .role = owner.connection.role, .key = owner.key };
    var command: p.Authorization.Command = .{ .begin = .{ .role = plan.role, .expected_revision = plan.expected_revision, .action = plan.action.authorization } };
    var change: ?u64 = null;
    for (0..256) |_| {
        const observation = try authority.read(.identity);
        const response = try owner.authority.submit(try p.Growth.sign(.{ .realm = owner.connection.scope.realm, .principal = plan.principal, .sequence = observation.principal_sequence + 1, .command = .{ .authorization = command } }, owner.key));
        if (change == null) change = response.position;
        const outcome = (try authority.read(.{ .change = change.? })).body.authorization.body.change;
        command = switch (outcome.status) {
            .preparing => .{ .advance = change.? },
            .ready => .{ .publish = change.? },
            .published => return,
            .abandoned => return error.UnexpectedAbandonedChange,
        };
    }
    return error.AuthorizationStepBudget;
}

fn listing(caller: c.DirectTableClient, expected: ?[]const u8) !void {
    var after: ?u64 = null;
    var count: usize = 0;
    for (0..128) |_| {
        const response = try caller.call(.{ .list = .{ .namespace = 1, .after = after } });
        defer response.deinit();
        const page = response.value.result.list;
        for (page.entries) |entry| if (entry) |found| {
            try t.expectEqualStrings(expected orelse return error.UnexpectedVisibleTable, found.name.slice());
            count += 1;
        };
        after = page.next orelse {
            try t.expectEqual(@as(usize, if (expected != null) 1 else 0), count);
            return;
        };
    }
    return error.CatalogPageBudget;
}

fn defaults(init: std.process.Init, owner: c.DirectTableClient, admin: anytype, owner_role: u64) !void {
    const principal = 941001;
    const credential = try support.key(122);
    const login = (try admin.change(.{ .create_role = .{ .name = try p.Value.init("future_table_reader"), .login = true } })).?;
    _ = try admin.change(.{ .bind_credential = .{ .principal = principal, .role = login, .public_key = credential.public_key.toBytes() } });
    var caller = owner;
    caller.connection.principal = principal;
    caller.connection.role = null;
    caller.key = credential;
    try policy(owner, "GRANT CONNECT ON DATABASE transit TO future_table_reader");
    try t.expectError(error.AccessDenied, caller.call(.{ .list = .{ .namespace = 1, .after = null } }));
    try policy(owner, "GRANT USAGE ON SCHEMA public TO future_table_reader");
    try support.table(init.arena.allocator(), owner, owner_role, 905, "before_default", 95000, 1);
    try listing(caller, null);
    try policy(owner, "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO future_table_reader");
    try support.table(init.arena.allocator(), owner, owner_role, 906, "after_default", 95010, 1);
    try t.expectError(error.AccessDenied, caller.call(.{ .lookup = .{ .namespace = 1, .name = "before_default" } }));
    try listing(caller, "after_default");
    const metadata = try caller.call(.{ .lookup = .{ .namespace = 1, .name = "after_default" } });
    defer metadata.deinit();
    const definition = metadata.value.result.lookup.?;
    const acquisition: c.DirectTableProtocol.Acquisition = .{ .object = definition.interpretation.interpretation.object, .owner = .{ .scope = caller.connection.scope, .principal = principal, .operation = 95020 }, .expected = definition.position };
    const pinned = try caller.call(.{ .pin = acquisition });
    defer pinned.deinit();
    const snapshot: c.DirectTableProtocol.Snapshot = .{ .object = acquisition.object, .handle = pinned.value.result.pin };
    var reader = try c.DirectTableReader.open(init.gpa, caller, snapshot);
    defer reader.deinit();
    var page = (try reader.next(caller, .{})).?;
    defer page.deinit();
    try t.expect(page.complete);
    try t.expectEqual(@as(usize, 1), page.count);
    try t.expectError(error.AccessDenied, c.DirectTablePreparedDml.prepare(init.gpa, caller, 1, "DELETE FROM after_default", .transit, null));
    try t.expectError(error.AccessDenied, c.DirectTablePreparedDdl.prepare(init.gpa, caller, 1, "DROP TABLE after_default", .transit, null));
    // Default changes affect future registrations, never existing permissions.
    try policy(owner, "ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON TABLES FROM future_table_reader");
    try support.table(init.arena.allocator(), owner, owner_role, 907, "after_default_revoke", 95030, 1);
    try listing(caller, "after_default");
    try policy(owner, "REVOKE SELECT ON TABLE after_default FROM future_table_reader CASCADE");
    try listing(caller, null);
    try t.expectError(error.AccessDenied, c.DirectTableReader.open(init.gpa, caller, snapshot));
    try policy(owner, "GRANT SELECT ON TABLE after_default TO future_table_reader");
    var restored = try c.DirectTableReader.open(init.gpa, caller, snapshot);
    defer restored.deinit();
    try t.expectEqualDeep(reader.basis, restored.basis);
    (try caller.call(.{ .release = snapshot })).deinit();
}
