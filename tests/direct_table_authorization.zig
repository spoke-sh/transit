//! Selected Table roles do not confer native process or resource access.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const p = q.protocol;
const t = std.testing;
const support = @import("direct_captured_query.zig");

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
}
