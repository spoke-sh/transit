const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const support = @import("table_watch_test_support.zig");
const r = root.ReactiveModel;
const watch = root.TableWatch;
const p = root.protocol;
test "direct snapshot acquisition is read-only and checks current caller rights after buffering" {
    var store: support.Store = .{};
    defer store.deinit();
    const declaration = try support.create(&store, "CREATE TABLE items (id INT64 PRIMARY KEY, \"count\" INT64)");
    try support.mutate(&store, "INSERT INTO items VALUES (7, 1)");
    var reader = try support.Reader.open(&store);
    const initial = try watch.snapshot(t.allocator, &reader, support.principal, declaration);
    try t.expectEqual(@as(i64, 1), initial.rows[0].?.value.?.value);
    var view = try store.resolve();
    defer view.deinit();
    try t.expectEqual(view.table.root.changed_lsn, initial.observation.data_revision.value);
    const root_before = store.catalog.store.root;
    const tail_before = try store.wal.log().tail(view.table.root.partition);
    const puts_before = store.objects.puts;
    // Deny at every subject check, including after buffering owned rows.
    for (1..4) |step| {
        store.checks = 0;
        store.deny_at = step;
        reader = try support.Reader.open(&store);
        try t.expectError(error.CatalogDenied, watch.snapshot(t.allocator, &reader, support.principal, declaration));
    }
    store.deny_at = std.math.maxInt(usize);
    for (0..64) |_| {
        reader = try support.Reader.open(&store);
        try t.expectEqualDeep(initial.observation, try watch.observe(t.allocator, &reader, support.principal, declaration));
    }
    try t.expectEqualDeep(root_before, store.catalog.store.root);
    try t.expectEqual(tail_before, try store.wal.log().tail(view.table.root.partition));
    try t.expectEqual(puts_before, store.objects.puts);
    try support.mutate(&store, "DELETE FROM items");
    reader = try support.Reader.open(&store);
    const empty = try watch.snapshot(t.allocator, &reader, support.principal, declaration);
    for (empty.rows) |row| try t.expect(row == null);
    try t.expect(!empty.more);
    try t.expect(empty.observation.data_revision.value > initial.observation.data_revision.value);
    var changed = declaration;
    changed.interpretation_digest[0] ^= 1;
    try t.expectError(error.ReactiveResetRequired, watch.snapshot(t.allocator, &reader, support.principal, changed));
    // The service's own catalog grant is insufficient for another caller.
    try t.expectError(error.CatalogDenied, watch.snapshot(t.allocator, &reader, 18, declaration));
    store.denied = true;
    try t.expectError(error.CatalogDenied, watch.snapshot(t.allocator, &reader, support.principal, declaration));
}
test "query coverage and resume compare exact contracts rather than unrelated numeric revisions" {
    var store: support.Store = .{};
    defer store.deinit();
    const declaration = try support.create(&store, "CREATE TABLE items (id INT64 PRIMARY KEY, \"count\" INT64)");
    var reader = try support.Reader.open(&store);
    const initial = try watch.observe(t.allocator, &reader, support.principal, declaration);
    try t.expect(watch.covered(initial, initial.basis));
    var captured = initial.basis;
    captured.resource += 1;
    captured.accepted.value = 999;
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
    position.data_revision.value = newer.data_revision.value + 1;
    try t.expectError(error.InvalidReactiveCursor, watch.validateResume(position, scope, declaration, newer, 0));
    position.data_revision.value = 1;
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

test "direct DML admission and pin bookkeeping do not notify before atomic row publication" {
    var store: support.Store = .{};
    defer store.deinit();
    const source = try support.create(&store, "CREATE TABLE items (id INT64 PRIMARY KEY, value INT64)");
    try support.mutate(&store, "INSERT INTO items VALUES (1, 10)");
    var reader = try support.Reader.open(&store);
    const original = try watch.snapshot(t.allocator, &reader, support.principal, source);
    var intent = try support.prepare(&store, "INSERT INTO items VALUES (2, 20), (3, 30)");
    defer intent.deinit();
    const binding = try support.admit(&store, intent);
    const admitted = try watch.snapshot(t.allocator, &reader, support.principal, source);
    try t.expectEqual(original.observation.data_revision.value, admitted.observation.data_revision.value);
    try t.expect(admitted.observation.basis.accepted.value > original.observation.basis.accepted.value);
    try t.expect(admitted.rows[1] == null);
    _ = try store.catalog.performRows(binding, store.policy());
    const published = try watch.snapshot(t.allocator, &reader, support.principal, source);
    try t.expectEqual(@as(i64, 20), published.rows[1].?.value.?.value);
    try t.expectEqual(@as(i64, 30), published.rows[2].?.value.?.value);
    try t.expect(!watch.covered(published.observation, admitted.observation.basis));
    try support.mutate(&store, "UPDATE items SET value = 10 WHERE id = 1");
    const noop = try watch.observe(t.allocator, &reader, support.principal, source);
    try t.expectEqual(published.observation.data_revision.value, noop.data_revision.value);
    try t.expect(watch.covered(noop, published.observation.basis));
    try support.alter(&store, .{ .alter = .{ .rename = .{ .column = 2, .name = "renamed" } } });
    try t.expectError(error.ReactiveResetRequired, watch.snapshot(t.allocator, &reader, support.principal, source));
    // Rights to inspect an original stop survive interpretation changes.
    _ = try watch.authorize(&reader, support.principal, source);
    store.denied = true;
    var context: root.ServingFailure.Context = .{};
    try t.expectError(error.CatalogDenied, watch.observeDiagnostic(t.allocator, &reader, support.principal, source, &context));
    try t.expectEqual(.none, context.witness);
    store.denied = false;
    var latest = try support.declaration(&store);
    defer latest.deinit();
    const changed = try r.Source.from(2, latest.source);
    _ = try watch.observe(t.allocator, &reader, 17, changed);
    try t.expectEqualStrings("value", original.observation.schema.names[1].slice());
    try support.alter(&store, .drop);
    try t.expectError(error.ReactiveResetRequired, watch.snapshot(t.allocator, &reader, support.principal, changed));
    _ = try watch.authorize(&reader, support.principal, changed);
}
