const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const support = @import("table_watch_test_support.zig");
const r = root.ReactiveModel;
const watch = root.TableWatch;
const p = root.protocol;
test "catalog snapshot acquisition cannot mix concurrent cuts or follow renamed metadata" {
    var store: support.Store = .{};
    defer store.deinit();
    const declaration = try support.create(&store, "CREATE TABLE items (id INT64 PRIMARY KEY, \"count\" INT64)");
    try support.mutate(&store, "INSERT INTO items VALUES (7, 1)");
    var reader = try support.Reader.open(&store);
    var reads: usize = 0;
    reader.reads = &reads;
    const initial = try watch.snapshot(t.allocator, &reader, support.principal, declaration);
    try t.expectEqual(@as(i64, 1), initial.rows[0].?.value.?.value);
    try t.expectEqual(store.revisions.get(root.station.TableHead.key(100)).?, initial.observation.data_revision);
    const acquisitions = reads;
    for (1..acquisitions + 1) |step| {
        reads = 0;
        reader = try support.Reader.open(&store);
        reader.reads = &reads;
        reader.mutate_at = step;
        try t.expectError(error.StaleStateResource, watch.snapshot(t.allocator, &reader, support.principal, declaration));
        reader = try support.Reader.open(&store);
        const retried = try watch.snapshot(t.allocator, &reader, support.principal, declaration);
        try t.expectEqual(initial.observation.data_revision, retried.observation.data_revision);
    }
    for (0..64) |_| {
        store.revision += 1; // query/retention/status bookkeeping only
        reader = try support.Reader.open(&store);
        try t.expectEqual(initial.observation.data_revision, (try watch.observe(t.allocator, &reader, support.principal, declaration)).data_revision);
    }
    try support.mutate(&store, "DELETE FROM items");
    reader = try support.Reader.open(&store);
    const empty = try watch.snapshot(t.allocator, &reader, support.principal, declaration);
    for (empty.rows) |row| try t.expect(row == null);
    try t.expect(!empty.more);
    try t.expect(empty.observation.data_revision > initial.observation.data_revision);
    var changed = declaration;
    changed.metadata_digest[0] ^= 1;
    try t.expectError(error.ReactiveResetRequired, watch.snapshot(t.allocator, &reader, support.principal, changed));
    // The service's own catalog grant is insufficient for another caller.
    try t.expectError(error.CatalogDenied, watch.snapshot(t.allocator, &reader, 18, declaration));
    store.denied = true;
    try t.expectError(error.AccessDenied, watch.snapshot(t.allocator, &reader, support.principal, declaration));
}
test "query coverage and resume compare exact contracts rather than unrelated numeric revisions" {
    var store: support.Store = .{};
    defer store.deinit();
    const declaration = try support.create(&store, "CREATE TABLE items (id INT64 PRIMARY KEY, \"count\" INT64)");
    var reader = try support.Reader.open(&store);
    const initial = try watch.observe(t.allocator, &reader, support.principal, declaration);
    try t.expect(watch.covered(initial, initial.basis));
    var captured = initial.basis;
    captured.cut.resource += 1;
    captured.cut.revision = 999;
    try t.expect(!watch.covered(initial, captured));
    captured = initial.basis;
    captured.contract[0] ^= 1;
    try t.expect(!watch.covered(initial, captured));
    captured = initial.basis;
    captured.schema[0] ^= 1;
    try t.expect(!watch.covered(initial, captured));
    try support.mutate(&store, "INSERT INTO items VALUES (1, 2)");
    reader = try support.Reader.open(&store);
    const newer = try watch.observe(t.allocator, &reader, support.principal, declaration);
    try t.expect(!watch.covered(newer, initial.basis));
    const scope: r.Scope = .{ .realm = 49, .principal = 65536, .service = 1, .ingress = 9, .session = 7, .generation = 10, .subscription = 3, .subscription_generation = 12 };
    var position: r.Position = .{ .scope = scope, .watch_revision = 1, .resource = 7, .schema = initial.basis.schema, .data_revision = initial.data_revision };
    try watch.validateResume(position, scope, declaration, newer, 0);
    position.data_revision = newer.data_revision + 1;
    try t.expectError(error.InvalidReactiveCursor, watch.validateResume(position, scope, declaration, newer, 0));
    position.data_revision = 1;
    position.scope.session += 1;
    try t.expectError(error.InvalidReactiveCursor, watch.validateResume(position, scope, declaration, newer, 0));
    position.scope = scope;
    position.watch_revision += 1;
    try t.expectError(error.ReactiveResetRequired, watch.validateResume(position, scope, declaration, newer, 0));
}
test "watch transport admits its explicit shape and preserves full column names" {
    const schemas = [_][]const u8{
        "CREATE TABLE items (id INT64, \"count\" INT64)",
        "CREATE TABLE items (id INT64 PRIMARY KEY, \"count\" UTF8)",
        "CREATE TABLE items (id INT64 PRIMARY KEY, \"count\" INT64, extra INT64)",
        "CREATE TABLE items (id INT64, \"count\" INT64, PRIMARY KEY(\"count\"))",
    };
    for (schemas) |sql| {
        var store: support.Store = .{};
        defer store.deinit();
        const declaration = try support.create(&store, sql);
        var reader = try support.Reader.open(&store);
        try t.expectError(error.UnsupportedReactiveSource, watch.snapshot(t.allocator, &reader, support.principal, declaration));
    }
    var store: support.Store = .{};
    defer store.deinit();
    const name: [255]u8 = @splat('x');
    var sql: [512]u8 = undefined;
    const declaration = try support.create(&store, try std.fmt.bufPrint(&sql, "CREATE TABLE items (id INT64 PRIMARY KEY, \"{s}\" INT64)", .{name}));
    var reader = try support.Reader.open(&store);
    const observed = try watch.observe(t.allocator, &reader, support.principal, declaration);
    try t.expectEqualStrings(&name, observed.schema.names[1].slice());
}

test "staged mutation notifications retain old rows until publication and current catalog denial wins over metadata drift" {
    const c = root.query.catalog;
    var store: support.Store = .{};
    defer store.deinit();
    const source = try support.create(&store, "CREATE TABLE items (id INT64 PRIMARY KEY, value INT64)");
    try support.mutate(&store, "INSERT INTO items VALUES (1, 10)");
    var reader = try support.Reader.open(&store);
    var definition = (try support.catalog.lookup(t.allocator, &reader, 17, try .init("items"))).?;
    defer definition.deinit();
    var statement = try root.query.fuze.TableDml.compile(t.allocator, "INSERT INTO items VALUES (2, 20), (3, 30)", "items", definition.schema.schema, null);
    defer statement.deinit();
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = store.input, .metadata = source.metadata(), .plan = statement.plan };
    const original = try watch.snapshot(t.allocator, &reader, support.principal, source);
    var previous = original.observation;
    var reserved = false;
    for (0..4000) |_| {
        var turn = try store.capture();
        turn.delivery.input.origin = .{ .external = .{ .principal = 17, .policy_revision = 1 } };
        const result = try support.catalog.mutate(t.allocator, &turn, request);
        try store.commit(turn);
        reader = try support.Reader.open(&store);
        const snapshot = try watch.snapshot(t.allocator, &reader, support.principal, source);
        try t.expect(snapshot.observation.data_revision >= previous.data_revision);
        try t.expectEqual(@as(i64, 10), snapshot.rows[0].?.value.?.value);
        if (result.state == .building) {
            // No successful statement prefix, even when the head reservation
            // itself emits a possible-change notification.
            try t.expect(snapshot.rows[1] == null);
            reserved = reserved or snapshot.observation.data_revision > original.observation.data_revision;
            previous = snapshot.observation;
            continue;
        }
        try t.expectEqual(.applied, result.state);
        try t.expectEqual(@as(i64, 20), snapshot.rows[1].?.value.?.value);
        try t.expectEqual(@as(i64, 30), snapshot.rows[2].?.value.?.value);
        try t.expect(snapshot.rows[3] == null);
        try t.expect(!watch.covered(snapshot.observation, previous.basis));
        break;
    } else return error.UnfinishedTestDml;
    try t.expect(reserved);
    try support.ddl(&store, .{ .principal = 17, .operation = store.input, .object = source.object.value, .expected_revision = source.metadata_revision.value, .name = try .init("items"), .action = .{ .alter = .{ .schema = definition.schema.schema, .change = .{ .rename = .{ .column = 2, .name = "renamed" } } } } });
    reader = try support.Reader.open(&store);
    try t.expectError(error.ReactiveResetRequired, watch.snapshot(t.allocator, &reader, support.principal, source));
    // The original refresh's stop diagnostic can still be read after ALTER.
    _ = try watch.authorize(&reader, support.principal, source);
    var policy = try c.TableCatalogRecords.Policy.administrator(support.configuration.scope, support.principal);
    policy.revision = 2;
    policy.read = false;
    var turn = try store.capture();
    turn.delivery.input.origin = .{ .external = .{ .principal = 17, .policy_revision = 1 } };
    try support.catalog.setPolicy(&turn, 1, policy);
    try store.commit(turn);
    reader = try support.Reader.open(&store);
    var context: root.ServingFailure.Context = .{};
    try t.expectError(error.CatalogDenied, watch.observeDiagnostic(t.allocator, &reader, support.principal, source, &context));
    try t.expectError(error.CatalogDenied, watch.authorize(&reader, support.principal, source));
    try t.expectEqual(.none, context.witness);
    // The administrator can inspect the new source, but cannot lend this right
    // to the denied viewer. Already copied snapshot bytes remain self-contained.
    var latest = try support.declaration(&store);
    defer latest.deinit();
    const changed = try r.Source.from(2, latest.source);
    _ = try watch.observe(t.allocator, &reader, 17, changed);
    try t.expectEqualStrings("value", original.observation.schema.names[1].slice());
}
