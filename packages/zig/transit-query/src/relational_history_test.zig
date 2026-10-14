const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const s = q.station;
const f = q.fuze;
const r = f.Relational;
const tables = @import("catalog_store_test.zig");
const History = q.RelationalHistory;
const budgets: r.Budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 10000, .source_pins = 1 };
fn integer(value: i64) f.Types.Values.Cell {
    return .{ .value = .{ .atom = .{ .signed = value } } };
}
test "history vectors preserve consecutive transactions and one native cut across aliased Tables" {
    var store: q.testing.Store = .{};
    defer store.deinit();
    try tables.create(&store, "CREATE TABLE items (k BIGINT, v BIGINT)");
    try tables.mutate(&store, 2, .{ .insert = &.{&.{ integer(7), integer(10) }} });
    var first = try tables.definition(&store);
    defer first.deinit();
    var second_schema = first.schema.schema;
    second_schema.object = 200;
    _ = try tables.ddl(&store, .{ .principal = 17, .operation = 20, .object = 200, .expected_revision = 0, .name = try q.catalog.TableMetadata.Name.init("other"), .action = .{ .create = .{ .schema = second_schema } } });
    var turn = try tables.turn(&store);
    var second = (try tables.catalog.lookup(t.allocator, &turn, 17, try q.catalog.TableMetadata.Name.init("other"))).?;
    defer second.deinit();
    var left = try q.TableSource.from(t.allocator, tables.configuration, first);
    defer left.deinit();
    var right = try q.TableSource.from(t.allocator, tables.configuration, second);
    defer right.deinit();
    const declarations = [_]r.Source{
        .{ .alias = "l", .realm = 1, .resource = 7, .catalog = 9, .owner = 3, .schema = first.schema.schema },
        .{ .alias = "r", .realm = 1, .resource = 7, .catalog = 9, .owner = 3, .schema = second.schema.schema },
    };
    const sources = [_]q.TableSource{ left.source, right.source };
    const bundle: q.RelationalBundle = .{ .sources = &sources, .plan = .{ .sources = &declarations, .join = .{ .kind = .left, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } }, .outputs = &.{.{ .name = "n", .expression = .count_all }}, .lifetime = .maintained, .budgets = budgets } };
    const initial = try History.capture(&turn, t.allocator, bundle, 17);
    // A finite exchange freezes the same complete Table-history evidence.
    // Its distinct prepared lifetime cannot be advanced as a maintained job,
    // nor can its vector be reinterpreted under that other lifetime.
    var finite_bundle = bundle;
    finite_bundle.plan.lifetime = .captured;
    const finite_vector = try History.capture(&turn, t.allocator, finite_bundle, 17);
    try t.expectError(error.InvalidRelationalHistory, History.successor(&turn, finite_bundle, 17, finite_vector, 0));
    try t.expectError(error.InvalidRelationalHistory, finite_vector.validate(bundle));
    for (turn.decision.retain) |version| try t.expect(version == null);
    try t.expectEqual(turn.view.id, turn.decision.current_views[0].?);
    // Two Table heads can change in one native resource transaction. No vector
    // may expose only one side of this accepted four-write decision.
    for ([_]u64{ 100, 200 }) |object| {
        const before = try s.TableHead.load(&turn, object);
        var after = before;
        after.revision += 1;
        try before.replace(&turn, after);
    }
    try store.commit(turn);
    turn = try tables.turn(&store);
    const together = (try History.successor(&turn, bundle, 17, initial, 1)).?;
    for (together.entries[0..2], initial.entries[0..2]) |after, before| {
        try t.expectEqual(before.record.head.revision + 1, after.record.head.revision);
        try t.expectEqual(store.revision, after.position);
        try t.expectEqual(after.position, after.record.committed);
    }
    try t.expect(try History.successor(&turn, bundle, 17, together, 0) == null);
    var bytes: [History.Vector.max_bytes]u8 = undefined;
    const encoded = try together.encode(bundle, &bytes);
    const restored = try History.Vector.decode(bundle, encoded);
    try t.expectEqualSlices(History.Entry, together.entries[0..2], restored.entries[0..2]);
    for (0..encoded.len) |length| {
        if (History.Vector.decode(bundle, encoded[0..length])) |_| return error.AcceptedTruncatedHistory else |_| {}
    }
    bytes[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, History.Vector.decode(bundle, encoded));
    bytes[4] ^= 1;
    var shifted = together;
    shifted.entries[1].position -= 1;
    try t.expectError(error.InvalidRelationalHistory, shifted.validate(bundle));
    // Arrivals after capture do not replace the backfill basis or collapse
    // framework/no-op head revisions into the last observed mutation.
    try tables.mutate(&store, 3, .{ .insert = &.{&.{ integer(7), integer(20) }} });
    try tables.mutate(&store, 4, .{ .insert = &.{&.{ integer(8), integer(30) }} });
    turn = try tables.turn(&store);
    var backfill = try History.open(&turn, t.allocator, bundle, 17, initial, 10);
    try t.expectEqual(@as(?i64, 10), (try backfill.next(0, null)).?.values[1]);
    try t.expect(try backfill.next(1, null) == null);
    var finite_backfill = try History.open(&turn, t.allocator, finite_bundle, 17, finite_vector, 10);
    try t.expectEqualDeep((try backfill.next(0, null)).?, (try finite_backfill.next(0, null)).?);
    try t.expectEqualSlices(u8, &backfill.bound().cuts[0].commitment, &backfill.bound().cuts[1].commitment);
    var previous = together;
    var count: usize = 0;
    while (try History.successor(&turn, bundle, 17, previous, 0)) |after| {
        try t.expectEqual(previous.entries[0].record.head.revision + 1, after.entries[0].record.head.revision);
        try t.expect(after.entries[0].position > previous.entries[0].position);
        try t.expectEqualDeep(previous.entries[1].record, after.entries[1].record);
        try t.expectEqual(after.entries[0].position, after.entries[1].position);
        var data = try History.open(&turn, t.allocator, bundle, 17, after, 10);
        try data.validate(data.bound());
        try t.expectEqualDeep(after, (try History.successor(&turn, bundle, 17, previous, 0)).?);
        previous = after;
        count += 1;
    }
    try t.expect(count >= 4);
    const address = s.TableHistory.key(100, initial.entries[0].record.head.revision);
    const original = store.state.get(address).?;
    _ = store.state.remove(address);
    turn = try tables.turn(&store);
    try t.expectError(error.TableHistoryGap, History.open(&turn, t.allocator, bundle, 17, initial, 1));
    try store.state.put(t.allocator, address, original);
    // A cached data root never grants continuing read permission.
    var policy = try q.catalog.testing.Authority.Rights.administrator(tables.configuration.scope, 17);
    policy.revision = 2;
    policy.read = false;
    turn = try tables.turn(&store);
    try store.setRights(policy);
    try store.commit(turn);
    turn = try tables.turn(&store);
    try t.expectError(error.CatalogDenied, History.open(&turn, t.allocator, bundle, 17, initial, 1));
    try t.expectError(error.CatalogDenied, History.successor(&turn, bundle, 17, previous, 0));
}
