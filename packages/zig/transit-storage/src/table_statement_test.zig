const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const f = @import("transit_fuze");
const P = s.TablePartition;
const columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "value", .type = .int64, .nullable = false },
};
const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &columns, .primary_key = &.{1} };
const object: d.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };
const Access = struct {
    calls: usize = 0,
    deny_at: usize = std.math.maxInt(usize),
    fn acquire(context: *anyopaque) !P.Guard.Fence {
        const self: *Access = @ptrCast(@alignCast(context));
        self.calls += 1;
        if (self.calls >= self.deny_at) return error.PermissionDenied;
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn guard(self: *Access) P.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
};
fn owner(wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore) !P {
    var value = try P.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    errdefer value.deinit();
    try value.recover();
    return value;
}
fn binding(table: *P, id: u64, action: d.Action) d.Binding {
    return .{ .definition = p.Growth.current_definition, .identity = .{ .scope = object.scope, .principal = 4, .operation = id }, .target = object, .action = action, .expected_definition = if (action == .create) null else table.root.interpretation, .expected_data = if (action == .create) null else .{ .partition = 17, .next_lsn = table.root.next_lsn }, .intent = @splat(7) };
}
fn fill(table: *P, access: *Access, first: i64, count: usize, operation: u64) !void {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const exact = binding(table, operation, .insert);
    const changes = try alloc.alloc(P.Change, count);
    for (changes, 0..) |*change, i| {
        const values = try alloc.alloc(f.Types.Values.Cell, 2);
        values[0] = .{ .value = .{ .atom = .{ .signed = first + @as(i64, @intCast(i)) } } };
        values[1] = .{ .value = .{ .atom = .{ .signed = 0 } } };
        change.* = .{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(exact.identity, @intCast(i)), .cells = values }, .expect = .absent } };
    }
    _ = try table.admit(.{ .binding = exact, .interpretation = table.root.declared(), .changes = changes, .ingestion = .bulk }, access.guard());
    try t.expect((try table.perform(exact, access.guard())) == .committed);
}
fn admit(table: *P, access: *Access, id: u64, text: []const u8) !d.Binding {
    var compiled = try f.TableDml.compile(t.allocator, text, "events", schema, null);
    defer compiled.deinit();
    var exact = binding(table, id, if (compiled.plan.action == .update) .update else .delete);
    exact.intent = try compiled.plan.fingerprint(t.allocator);
    const request: s.TableDmlIntent.Request = .{ .binding = exact, .interpretation = table.root.declared(), .changes = &.{}, .ingestion = .bulk, .statement = compiled.plan };
    _ = try table.admit(request, access.guard());
    return exact;
}
fn inspectRows(table: *P, value: i128, count: u64) !void {
    var after: ?s.TreeStore.pages.Key = null;
    var found: u64 = 0;
    while (true) {
        const batch = try table.scan(table.root, after);
        for (batch.entries) |slot| if (slot) |entry| {
            var row = try table.readRow(t.allocator, table.root, entry.key, entry.value);
            defer row.deinit();
            try t.expectEqual(value, row.row().cells[1].value.atom.signed);
            try t.expectEqual(@as(u64, 5), row.row().identity.origin);
            found += 1;
        };
        after = batch.next orelse break;
    }
    try t.expectEqual(count, found);
}

test "frozen SQL work updates beyond a row batch with one acceptance and survives disk reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var exact: d.Binding = undefined;
    var snapshot: P.SnapshotHandle = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        _ = try table.apply(binding(&table, 1, .create), &.{}, .point, access.guard());
        try fill(&table, &access, 0, 700, 2);
        try fill(&table, &access, 700, 700, 3);
        snapshot = try table.pin(.{ .scope = object.scope, .principal = 4, .operation = 90 }, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
        exact = try admit(&table, &access, 4, "UPDATE events SET value = 9 WHERE id >= 0");
        const before = table.root;
        try t.expect((try table.operationState(exact, access.guard())) == .admitted);
        try t.expectEqualDeep(before, table.root);
    }
    var accepted: P.Evidence = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        const before = table.root.next_lsn;
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.perform(exact, access.guard()));
        table.lose_reply = false;
        accepted = (try table.operationState(exact, access.guard())).committed;
        try t.expectEqual(before + 1, accepted.outcome.position.next_lsn);
        try t.expectEqual(@as(u64, 1400), accepted.outcome.matched);
        try t.expectEqual(@as(u64, 1400), accepted.outcome.affected);
        try t.expectEqualDeep(accepted, (try table.perform(exact, access.guard())).committed);
        try inspectRows(&table, 9, 1400);
        var old = try table.scanSnapshot(t.allocator, snapshot, null, .{}, access.guard());
        defer old.deinit();
        try t.expectEqual(@as(i128, 0), old.rows[0].?.row().cells[1].value.atom.signed);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    try t.expectEqualDeep(accepted, (try table.operationState(exact, access.guard())).committed);
    try inspectRows(&table, 9, 1400);
    const source = table.root.changed_lsn;
    const noop = try admit(&table, &access, 5, "UPDATE events SET value = 9 WHERE id >= 0");
    const same = (try table.perform(noop, access.guard())).committed;
    try t.expectEqual(@as(u64, 1400), same.outcome.matched);
    try t.expectEqual(@as(u64, 0), same.outcome.affected);
    try t.expectEqual(source, table.root.changed_lsn);
    const deletion = try admit(&table, &access, 6, "DELETE FROM events WHERE id >= 0");
    const removed = (try table.perform(deletion, access.guard())).committed;
    try t.expectEqual(@as(u64, 1400), removed.outcome.affected);
    try t.expectEqual(@as(u64, 0), table.root.live_rows);
    try table.recover();
    try t.expectEqualDeep(removed, (try table.perform(deletion, access.guard())).committed);
    var old = try table.scanSnapshot(t.allocator, snapshot, null, .{}, access.guard());
    defer old.deinit();
    try t.expectEqual(@as(u64, 1400), old.total_rows);
}

test "frozen SQL predicate work rejects stale data, late collisions, work exhaustion and revoked publication" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    _ = try table.apply(binding(&table, 1, .create), &.{}, .point, access.guard());
    try fill(&table, &access, 1, 3, 2);
    const collision = try admit(&table, &access, 3, "UPDATE events SET id = 3 WHERE id < 3");
    const original = table.root.rows;
    try t.expectEqual(.duplicate_key, (try table.perform(collision, access.guard())).rejected.reason);
    try t.expectEqualDeep(original, table.root.rows);
    const stale = try admit(&table, &access, 4, "DELETE FROM events WHERE id >= 0");
    try fill(&table, &access, 4, 1, 5);
    try t.expectEqual(.data_changed, (try table.perform(stale, access.guard())).rejected.reason);
    const budgeted = try admit(&table, &access, 6, "UPDATE events SET value = 7 WHERE id >= 0");
    const before = table.root.rows;
    table.options.statement_scan_rows = 2;
    try t.expectEqual(.work_limit, (try table.perform(budgeted, access.guard())).rejected.reason);
    try t.expectEqualDeep(before, table.root.rows);
    table.options.statement_scan_rows = 1_000_000;
    const bytes_limited = try admit(&table, &access, 7, "DELETE FROM events WHERE id >= 0");
    table.options.statement_scan_bytes = 1;
    try t.expectEqual(.work_limit, (try table.perform(bytes_limited, access.guard())).rejected.reason);
    try t.expectEqualDeep(before, table.root.rows);
    table.options.statement_scan_bytes = 64 * 1024 * 1024;
    const denied = try admit(&table, &access, 8, "UPDATE events SET value = 7 WHERE id >= 0");
    access.deny_at = access.calls + 3;
    try t.expectError(error.PermissionDenied, table.perform(denied, access.guard()));
    try t.expectEqualDeep(before, table.root.rows);
    access.deny_at = std.math.maxInt(usize);
    try t.expect((try table.operationState(denied, access.guard())) == .admitted);
    try t.expect((try table.cancel(denied, access.guard())) == .cancelled);
    try table.recover();
    try inspectRows(&table, 0, 4);
    try t.expectEqual(.duplicate_key, (try table.perform(collision, access.guard())).rejected.reason);
    try t.expectEqual(.work_limit, (try table.perform(budgeted, access.guard())).rejected.reason);
}
