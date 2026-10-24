//! Real direct retention and watch cuts. Complete captured-query publication
//! and verification are exercised by the public direct query integration proof.
const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const q = root.query;
const support = @import("table_watch_test_support.zig");
test "direct pin acquisition and closure do not self-invalidate a watch and a newer commit escapes coverage" {
    var store: support.Store = .{};
    defer store.deinit();
    const declaration = try support.create(&store, "CREATE TABLE items (id INT64 PRIMARY KEY, value INT64)");
    for (0..12) |index| {
        var sql: [128]u8 = undefined;
        try support.mutate(&store, try std.fmt.bufPrint(&sql, "INSERT INTO items VALUES ({d}, {d})", .{ index, index }));
    }
    var reader = try support.Reader.open(&store);
    const initial = try root.TableWatch.snapshot(t.allocator, &reader, support.principal, declaration);
    try t.expect(initial.more);
    try t.expect(initial.rows[7] != null);
    var table_source = try support.declaration(&store);
    defer table_source.deinit();
    const object = declaration.interpretation().object;
    const pin = try store.catalog.pinRows(object, .{ .scope = support.scope, .principal = support.principal, .operation = store.next() }, .{ .partition = initial.observation.basis.partition.value, .next_lsn = initial.observation.basis.accepted.value }, store.policy());
    var retained = try store.catalog.snapshotDefinition(t.allocator, object, pin, store.policy());
    defer retained.deinit();
    const basis: q.TableSource.Basis = .{ .declaration = try table_source.source.fingerprint(), .schema = try table_source.source.row_type.fingerprint(), .retained = .{ .snapshot = .{ .object = object, .handle = pin }, .interpretation = retained.root.declared(), .accepted = .{ .partition = retained.root.partition, .next_lsn = retained.root.next_lsn }, .changed_lsn = retained.root.changed_lsn, .row_count = retained.root.live_rows, .authority = try store.catalog.readAuthority(object, pin.owner, store.policy(), false) } };
    const captured = try q.TablePosition.captured(basis);
    const admitted = try root.TableWatch.observe(t.allocator, &reader, support.principal, declaration);
    try t.expectEqualDeep(initial.observation.data_revision, admitted.data_revision);
    try t.expect(root.TableWatch.covered(admitted, captured));
    try support.mutate(&store, "INSERT INTO items VALUES (12, 12)");
    const changed = try root.TableWatch.observe(t.allocator, &reader, support.principal, declaration);
    try t.expect(!root.TableWatch.covered(changed, captured));
    var count: usize = 0;
    var after: ?q.catalog.storage.TablePartition.SnapshotCursor = null;
    while (true) {
        var page = try store.catalog.scanRows(t.allocator, object, pin, after, .{}, store.policy());
        defer page.deinit();
        count += page.count;
        if (page.next == null) break;
        after = page.next;
    }
    try t.expectEqual(@as(usize, 12), count);
    try store.catalog.releaseRows(object, pin, store.policy());
    try t.expectEqualDeep(changed.data_revision, (try root.TableWatch.observe(t.allocator, &reader, support.principal, declaration)).data_revision);
    try t.expect(!root.TableWatch.covered(changed, captured));
    try t.expect(root.TableWatch.covered(changed, (try root.TableWatch.snapshot(t.allocator, &reader, support.principal, declaration)).observation.basis));
}
