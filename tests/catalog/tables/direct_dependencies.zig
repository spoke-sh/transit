//! Public dependency lifecycle across separate caller and node processes.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const dep = c.DirectDependency;
const host = c.DirectCatalogDependencies;
const t = std.testing;

pub const State = struct {
    registration: dep.Binding,
    removal: dep.Binding,
    host_registration: host.Binding,
    host_removal: host.Binding,
    blocked_drop: d.Binding,
    drop: d.Binding,
    owner_role: u64,
};
const name = "dependency_source";
const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
pub const GrowthState = struct { original: dep.Outcome, blocked_drop: d.Binding };
const growth_count = 139;

pub fn growthWrite(client: c.DirectTableClient, admin: anytype, role: u64) !GrowthState {
    var arena = std.heap.ArenaAllocator.init(client.allocator);
    defer arena.deinit();
    var preparing = client;
    preparing.allocator = arena.allocator();
    const plan = try prepare(preparing, admin, role);
    const original = (try operation(client, plan.registration, .accept)).outcome;
    try t.expect(original.phase == .applied and original.changed);
    for (1..growth_count) |i| {
        var binding = plan.registration;
        binding.operation = 900000 + i;
        binding.edge.dependent.interpretation.object.object += i;
        const result = (try operation(client, binding, .accept)).outcome;
        try t.expect(result.phase == .applied and result.changed);
        try t.expectEqualDeep(binding, result.binding);
    }
    const state: GrowthState = .{ .original = original, .blocked_drop = plan.blocked_drop };
    try growthRecover(client, admin, state);
    return state;
}

pub fn growthRecover(client: c.DirectTableClient, admin: anytype, state: GrowthState) !void {
    const registration = state.original.binding;
    const expected = registration.edge;
    var cursor: ?dep.Cursor = null;
    var position: ?d.Position = null;
    var previous: ?[32]u8 = null;
    var seen: usize = 0;
    // Keep one four-edge page and one reverse lookup resident. Strict digest
    // ordering plus the exact identity range proves completeness without a set.
    for (0..256) |_| {
        const current = try pageAt(client, .{ .dependents = expected.source.object }, cursor);
        if (position) |first| try t.expectEqualDeep(first, current.position);
        position = current.position;
        for (current.entries) |slot| if (slot) |edge| {
            try t.expectEqualDeep(expected.source, edge.source);
            const object = edge.dependent.interpretation.object.object;
            const first = expected.dependent.interpretation.object.object;
            try t.expect(object >= first and object - first < growth_count);
            var exact = expected;
            exact.dependent.interpretation.object.object = object;
            try t.expectEqualDeep(exact, edge);
            const digest = try edge.digest();
            if (previous) |prior| try t.expect(std.mem.order(u8, &prior, &digest) == .lt);
            previous = digest;
            const reverse = try page(client, .{ .dependencies = edge.dependent.interpretation.object });
            try t.expectEqualDeep(edge, reverse.entries[0].?);
            try t.expectEqual(null, reverse.entries[1]);
            try t.expectEqual(null, reverse.next);
            seen += 1;
        };
        cursor = current.next orelse break;
    } else return error.DependencyPageBudget;
    try t.expectEqual(@as(usize, growth_count), seen);
    try t.expectEqualDeep(state.original, (try operation(client, registration, .inspect)).outcome);
    try t.expectEqualDeep(state.original, (try operation(client, registration, .accept)).outcome);
    try restrictedBinding(client, state.blocked_drop);
    const resource = expected.dependent.interpretation.object.scope.resource;
    _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = client.connection.principal, .permissions = 0 } });
    try t.expectError(error.AccessDenied, operation(client, registration, .inspect));
    cursor = null;
    for (0..256) |_| {
        const hidden = try pageAt(client, .{ .dependents = expected.source.object }, cursor);
        for (hidden.entries) |entry| try t.expectEqual(null, entry);
        cursor = hidden.next orelse break;
    } else return error.DependencyPageBudget;
    try restrictedBinding(client, state.blocked_drop);
    _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = client.connection.principal, .permissions = 5 } });
    try t.expectEqualDeep(state.original, (try operation(client, registration, .inspect)).outcome);
}

fn create(client: c.DirectTableClient, role: u64, object: u64, operation_id: u64) !d.Definition {
    const schema: c.fuze.TableSchema.Schema = .{ .object = object, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    const intent: c.DirectCatalog.Intent = .{ .kind = .table, .namespace = 1, .name = try .init(name), .action = .{ .create = .{ .schema = schema, .owner = role } } };
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
    const intent: c.DirectCatalog.Intent = .{ .kind = .table, .namespace = 1, .name = try .init(name), .action = .drop };
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
    return .{ .registration = registration, .removal = removal, .host_registration = try host.Binding.foreign(client.allocator, registration), .host_removal = try host.Binding.foreign(client.allocator, removal), .blocked_drop = blocked_drop, .drop = drop, .owner_role = role };
}

fn operation(client: c.DirectTableClient, binding: dep.Binding, command: dep.Command) !dep.Observation {
    var arena = std.heap.ArenaAllocator.init(client.allocator);
    defer arena.deinit();
    return operationHost(client, try host.Binding.foreign(arena.allocator(), binding), command);
}
fn operationHost(client: c.DirectTableClient, binding: host.Binding, command: dep.Command) !dep.Observation {
    var arena = std.heap.ArenaAllocator.init(client.allocator);
    defer arena.deinit();
    var session: c.DirectTableBridge.Session = .{ .allocator = client.allocator };
    defer session.deinit();
    const bytes = try p.Json.valueAlloc(arena.allocator(), c.DirectTableBridge.Action{ .dependencies = .{ .operation = .{ .binding = binding, .command = command } } });
    const parsed = try c.DirectTableBridge.parse(arena.allocator(), bytes);
    defer parsed.deinit();
    const result = (try session.apply(&arena, client, parsed.value, null)).dependencies.observation;
    return switch (result) {
        .not_observed => .not_observed,
        .outcome => |value| .{ .outcome = try value.native() },
    };
}

pub fn uncertain(client: c.DirectTableClient, binding: host.Binding) !void {
    // The independent HTTP proxy corrupts the accepted reply's context digest.
    var attempt: c.DirectTableClient.Attempt = .{};
    var observed = client;
    observed.attempt = &attempt;
    try t.expectError(error.InvalidTableResponse, operationHost(observed, binding, .accept));
    const diagnostic = (try attempt.failure(error.InvalidTableResponse, client.service.last_rejection)).?;
    try t.expectEqual(.unknown, diagnostic.outcome);
    try t.expectEqual((try binding.native()).operation, try diagnostic.identity.?.id.value());
}

fn page(client: c.DirectTableClient, selection: dep.Selection) !dep.Page {
    return pageAt(client, selection, null);
}
fn pageAt(client: c.DirectTableClient, selection: dep.Selection, cursor: ?dep.Cursor) !dep.Page {
    var arena = std.heap.ArenaAllocator.init(client.allocator);
    defer arena.deinit();
    const saved_cursor: ?host.Cursor = if (cursor) |value| .{
        .definition = p.Growth.current_definition,
        .connection = try c.DirectTableValues.Connection.foreign(arena.allocator(), client.connection),
        .selection = try host.Selection.foreign(arena.allocator(), value.selection),
        .authority = value.authority,
        .position = try c.DirectTableValues.Position.foreign(arena.allocator(), value.position),
        .after = try c.TableValues.hex(arena.allocator(), value.after.slice()),
    } else null;
    const value = (try host.apply(arena.allocator(), client, .{ .page = .{ .selection = try host.Selection.foreign(arena.allocator(), selection), .cursor = saved_cursor, .authority = .dependent } })).page;
    var result: dep.Page = .{ .position = try value.position.native(), .next = if (value.next) |next| try next.native(client.connection) else null };
    for (value.entries, &result.entries) |slot, *entry| if (slot) |edge| {
        entry.* = try edge.native();
    };
    return result;
}
fn present(client: c.DirectTableClient, edge: dep.Edge) !bool {
    var arena = std.heap.ArenaAllocator.init(client.allocator);
    defer arena.deinit();
    const result = (try host.apply(arena.allocator(), client, .{ .state = try host.Edge.foreign(arena.allocator(), edge) })).state;
    try t.expectEqualDeep(edge, try result.edge.native());
    return result.present;
}

fn restricted(client: c.DirectTableClient, state: State) !void {
    return restrictedBinding(client, state.blocked_drop);
}
fn restrictedBinding(client: c.DirectTableClient, binding: d.Binding) !void {
    const preview = try client.call(.{ .preview = .{ .binding = binding, .namespace = 1, .name = name, .action = .drop } });
    defer preview.deinit();
    try t.expectEqual(.dependency, preview.value.result.preview.reason);
    const rejected = try client.call(.{ .admit_ddl = .{ .binding = binding, .namespace = 1, .name = name, .action = .drop } });
    defer rejected.deinit();
    try t.expectEqual(.dependency, rejected.value.result.ddl.rejected.reason);
}

pub fn recover(client: c.DirectTableClient, admin: anytype, state: State) !void {
    try state.registration.requireSame(try state.host_registration.native());
    const receipt = (try operationHost(client, state.host_registration, .inspect)).outcome;
    try t.expect(receipt.phase == .applied and receipt.changed);
    try t.expectEqualDeep(state.registration, receipt.binding);
    try t.expectEqualDeep(receipt, (try operation(client, state.registration, .accept)).outcome);
    var altered = state.registration;
    altered.edge.dependent.interpretation.revision += 1;
    try t.expectError(error.Conflict, operation(client, altered, .accept));
    const edge = state.registration.edge;
    try t.expect(try present(client, edge));
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
    try state.removal.requireSame(try state.host_removal.native());
    const removed = (try operationHost(client, state.host_removal, .inspect)).outcome;
    try t.expect(removed.phase == .applied and removed.changed);
    try t.expectEqualDeep(state.removal, removed.binding);
    try t.expectEqualDeep(removed, (try operation(client, state.removal, .accept)).outcome);
    // Replaying an old registration returns its old receipt, never a new edge.
    const original = (try operation(client, state.registration, .accept)).outcome;
    try t.expect(original.phase == .applied and original.changed);
    try t.expect(original.position.next_lsn < removed.position.next_lsn);
    try t.expect(!try present(client, state.registration.edge));
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
