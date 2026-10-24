//! Public dependency lifecycle across separate caller and node processes.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const dep = c.DirectDependency;
const t = std.testing;

pub const State = struct {
    registration: dep.Binding,
    removal: dep.Binding,
    blocked_drop: d.Binding,
    drop: d.Binding,
    owner_role: u64,
};
const name = "dependency_source";
const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};

fn create(client: c.DirectTableClient, role: u64, object: u64, operation_id: u64) !d.Definition {
    const schema: c.fuze.TableSchema.Schema = .{ .object = object, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    const intent: c.DirectCatalog.Intent = .{ .namespace = 1, .name = try .init(name), .action = .{ .create = .{ .schema = schema, .owner = role } } };
    const binding: d.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = operation_id }, .target = .{ .scope = client.connection.scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(client.allocator) };
    var bytes: [c.fuze.TableSchema.max_bytes]u8 = undefined;
    const encoded = try w.Binary.encode(client.allocator, try schema.encode(&bytes));
    defer client.allocator.free(encoded.base64);
    const admitted = try client.call(.{ .admit_ddl = .{ .binding = binding, .namespace = 1, .name = name, .action = .{ .create = .{ .owner = role, .schema = encoded } } } });
    defer admitted.deinit();
    const committed = try client.call(.{ .operation = .{ .binding = binding, .command = .execute, .steps = 32 } });
    defer committed.deinit();
    return committed.value.result.ddl.committed.resulting.interpretation;
}

pub fn prepare(client: c.DirectTableClient, admin: anytype, role: u64) !State {
    (try client.call(.initialize)).deinit();
    const source = try create(client, role, 700, 70000);
    const table = try client.call(.{ .lookup = .{ .namespace = 1, .name = name } });
    defer table.deinit();
    _ = try admin.change(.{ .grant = .{ .object = c.TableAuthority.reference(table.value.result.lookup.?.authorization), .grantee = role, .privileges = c.TableAuthority.select } });
    const pid = try admin.submit(.{ .spawn = .{} });
    const resource = try admin.submit(.{ .create_resource = .{ .writer = pid, .owned = false } });
    _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = client.connection.principal, .permissions = 5 } });
    const registration: dep.Binding = .{
        .definition = p.Growth.current_definition,
        .connection = client.connection,
        .operation = 70001,
        .edge = .{ .source = source, .dependent = .{ .kind = .captured, .interpretation = .{
            .object = .{ .scope = .{ .realm = 42, .resource = resource, .catalog = 19 }, .branch = 1, .object = 17 },
            .revision = 1,
            .digest = @splat(7),
        } }, .privileges = c.TableAuthority.select },
        .action = .register,
        .authority = .dependent,
    };
    var removal = registration;
    removal.operation = 70002;
    removal.action = .remove;
    const intent: c.DirectCatalog.Intent = .{ .namespace = 1, .name = try .init(name), .action = .drop };
    const blocked_drop: d.Binding = .{
        .definition = p.Growth.current_definition,
        .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 70003 },
        .target = source.object,
        .action = .drop,
        .expected_definition = source,
        .expected_data = null,
        .intent = try intent.digest(client.allocator),
    };
    var drop = blocked_drop;
    drop.identity.operation = 70005;
    return .{ .registration = registration, .removal = removal, .blocked_drop = blocked_drop, .drop = drop, .owner_role = role };
}

fn operation(client: c.DirectTableClient, binding: dep.Binding, command: dep.Command) !dep.Observation {
    const response = try client.call(.{ .dependency_operation = .{ .binding = binding, .command = command } });
    defer response.deinit();
    return response.value.result.dependency_operation;
}

pub fn uncertain(client: c.DirectTableClient, binding: dep.Binding) !void {
    // The independent HTTP proxy corrupts the accepted reply's context digest.
    try t.expectError(error.InvalidTableResponse, operation(client, binding, .accept));
}

fn page(client: c.DirectTableClient, selection: dep.Selection) !dep.Page {
    const response = try client.call(.{ .dependencies = .{ .selection = selection, .cursor = null, .authority = .dependent } });
    defer response.deinit();
    return response.value.result.dependencies;
}

fn restricted(client: c.DirectTableClient, state: State) !void {
    const preview = try client.call(.{ .preview = .{ .binding = state.blocked_drop, .namespace = 1, .name = name, .action = .drop } });
    defer preview.deinit();
    try t.expectEqual(.dependency, preview.value.result.preview.reason);
    const rejected = try client.call(.{ .admit_ddl = .{ .binding = state.blocked_drop, .namespace = 1, .name = name, .action = .drop } });
    defer rejected.deinit();
    try t.expectEqual(.dependency, rejected.value.result.ddl.rejected.reason);
}

pub fn recover(client: c.DirectTableClient, admin: anytype, state: State) !void {
    const receipt = (try operation(client, state.registration, .inspect)).outcome;
    try t.expect(receipt.phase == .applied and receipt.changed);
    try t.expectEqualDeep(state.registration, receipt.binding);
    try t.expectEqualDeep(receipt, (try operation(client, state.registration, .accept)).outcome);
    var altered = state.registration;
    altered.edge.dependent.interpretation.revision += 1;
    try t.expectError(error.Conflict, operation(client, altered, .accept));
    const edge = state.registration.edge;
    try t.expectEqualDeep(edge, (try page(client, .{ .dependents = edge.source.object })).entries[0].?);
    try t.expectEqualDeep(edge, (try page(client, .{ .dependencies = edge.dependent.interpretation.object })).entries[0].?);
    try restricted(client, state);
    const resource = edge.dependent.interpretation.object.scope.resource;
    _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = client.connection.principal, .permissions = 0 } });
    try t.expectError(error.AccessDenied, operation(client, state.registration, .inspect));
    try t.expect((try page(client, .{ .dependents = edge.source.object })).entries[0] == null);
    try restricted(client, state);
    // Inspect-only rights disclose metadata but do not authorize removal.
    _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = client.connection.principal, .permissions = 1 } });
    try t.expectEqualDeep(receipt, (try operation(client, state.registration, .inspect)).outcome);
    try t.expectError(error.AccessDenied, operation(client, state.removal, .accept));
    _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = client.connection.principal, .permissions = 5 } });
}

pub fn finish(client: c.DirectTableClient, state: State) !void {
    const removed = (try operation(client, state.removal, .inspect)).outcome;
    try t.expect(removed.phase == .applied and removed.changed);
    try t.expectEqualDeep(state.removal, removed.binding);
    try t.expectEqualDeep(removed, (try operation(client, state.removal, .accept)).outcome);
    // Replaying an old registration returns its old receipt, never a new edge.
    const original = (try operation(client, state.registration, .accept)).outcome;
    try t.expect(original.phase == .applied and original.changed);
    try t.expect(original.position.next_lsn < removed.position.next_lsn);
    try t.expect((try page(client, .{ .dependents = state.drop.target })).entries[0] == null);
    try t.expect((try page(client, .{ .dependencies = state.registration.edge.dependent.interpretation.object })).entries[0] == null);
    // A previously rejected DROP stays rejected after its blocker is removed.
    const previous_drop = try client.call(.{ .operation = .{ .binding = state.blocked_drop, .command = .execute, .steps = 32 } });
    defer previous_drop.deinit();
    try t.expectEqual(.dependency, previous_drop.value.result.ddl.rejected.reason);
    const admitted = try client.call(.{ .admit_ddl = .{ .binding = state.drop, .namespace = 1, .name = name, .action = .drop } });
    defer admitted.deinit();
    const dropped = try client.call(.{ .operation = .{ .binding = state.drop, .command = .execute, .steps = 32 } });
    defer dropped.deinit();
    try t.expect(dropped.value.result.ddl == .committed);
    const replacement = try create(client, state.owner_role, 701, 70004);
    try t.expect(replacement.object.object != original.binding.edge.source.object.object);
    try t.expectEqualDeep(original, (try operation(client, state.registration, .inspect)).outcome);
}
