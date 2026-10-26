const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const f = @import("transit_fuze");
const P = s.TablePartition;
const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
const object: d.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };
const Access = struct {
    denied: bool = false,
    fn acquire(context: *anyopaque) !P.Guard.Fence {
        const self: *Access = @ptrCast(@alignCast(context));
        if (self.denied) return error.PermissionDenied;
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
fn binding(table: *P, id: u64) d.Binding {
    return .{ .definition = p.Growth.current_definition, .identity = .{ .scope = object.scope, .principal = 4, .operation = id }, .target = object, .action = if (table.root.next_lsn == 0) .create else .insert, .expected_definition = if (table.root.next_lsn == 0) null else table.root.interpretation, .expected_data = null, .intent = @splat(7) };
}
fn request(table: *P, exact: d.Binding, changes: []const P.Change) s.TableDmlIntent.Request {
    return .{ .binding = exact, .interpretation = table.root.declared(), .changes = changes, .ingestion = .point };
}
fn change(cell: *const f.Types.Values.Cell, id: u64) P.Change {
    return changeAt(cell, id, 0);
}
fn changeAt(cell: *const f.Types.Values.Cell, id: u64, ordinal: u32) P.Change {
    return .{ .put = .{ .row = .{ .identity = .{ .origin = 5, .operation = id, .ordinal = ordinal }, .cells = @as(*const [1]f.Types.Values.Cell, @ptrCast(cell)) }, .expect = .absent } };
}

test "Table admitted work survives lost replies and disk restart; inspection cannot execute and cancellation cannot undo a commit" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    var access: Access = .{};
    var exact: d.Binding = undefined;
    var intent: s.TableDmlIntent.Request = undefined;
    const changes = [_]P.Change{change(&cell, 2)};
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        _ = try table.apply(binding(&table, 1), &.{}, .point, access.guard());
        exact = binding(&table, 2);
        exact.expected_data = .{ .partition = 17, .next_lsn = table.root.next_lsn };
        intent = request(&table, exact, &changes);
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.admit(intent, access.guard()));
        try t.expectEqual(@as(u64, 0), table.root.live_rows);
    }
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        const before = table.root;
        try t.expect((try table.operationState(exact, access.guard())) == .admitted);
        try t.expect((try table.admit(intent, access.guard())) == .admitted);
        try t.expectEqualDeep(before, table.root);
        const pending = try table.pendingOperations(null, access.guard());
        try t.expectEqual(@as(usize, 1), pending.len);
        try t.expectEqualDeep(exact, pending.items[0].binding);
        access.denied = true;
        try t.expectError(error.PermissionDenied, table.perform(exact, access.guard()));
        try t.expectError(error.PermissionDenied, table.operationState(exact, access.guard()));
        access.denied = false;
        // Physical relocation and pin acquisition do not stale admitted work.
        _ = try table.flush(access.guard());
        _ = try table.pin(.{ .scope = object.scope, .principal = 4, .operation = 50 }, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
        const through: d.Position = .{ .partition = 17, .next_lsn = table.root.next_lsn };
        while (!(try table.archive(through, .{ .frames = 1 }, access.guard())).complete) {}
        _ = try table.trimArchived(access.guard());
        _ = try table.checkpoint(.{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
        try table.recover();
        try t.expectEqual(@as(u64, 1), table.recovery_work.replayed_frames);
        try t.expect((try table.operationState(exact, access.guard())) == .admitted);
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.perform(exact, access.guard()));
        try t.expectEqual(@as(u64, 1), table.root.live_rows);
        try t.expect(table.root.pending == null);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    const committed = (try table.operationState(exact, access.guard())).committed;
    try t.expectEqual(@as(u64, 1), committed.outcome.matched);
    try t.expectEqual(@as(u64, 1), committed.outcome.affected);
    try t.expectEqualDeep(committed, (try table.cancel(exact, access.guard())).committed);
    try t.expectEqualDeep(committed, (try table.perform(exact, access.guard())).committed);
    try t.expectEqualDeep(committed, (try table.admit(intent, access.guard())).committed);
    var altered = intent;
    altered.ingestion = .bulk;
    try t.expectError(error.DataIdentityConflict, table.admit(altered, access.guard()));
    try t.expect((try table.cancel(binding(&table, 999), access.guard())) == .not_observed);
    try t.expectEqual(@as(usize, 0), (try table.pendingOperations(null, access.guard())).len);
}

test "Table cancellation and late constraint rejection are terminal across restart with no partial rows" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    const first: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    const second: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 2 } } };
    _ = try table.apply(binding(&table, 1), &.{change(&first, 1)}, .point, access.guard());
    const cancelled = binding(&table, 2);
    const cancelled_request = request(&table, cancelled, &.{change(&second, 2)});
    _ = try table.admit(cancelled_request, access.guard());
    var ddl = binding(&table, 100);
    ddl.action = .rename;
    try t.expectError(error.TableOperationsPending, table.changeDefinition(ddl, .{ .rename = "other" }, access.guard()));
    table.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, table.cancel(cancelled, access.guard()));
    table.lose_reply = false;
    try table.recover();
    try t.expect((try table.perform(cancelled, access.guard())) == .cancelled);
    try t.expect((try table.admit(cancelled_request, access.guard())) == .cancelled);
    try t.expectError(error.TableOperationTerminal, table.apply(cancelled, cancelled_request.changes, .point, access.guard()));
    const rejected = binding(&table, 3);
    _ = try table.admit(request(&table, rejected, &.{ change(&second, 3), changeAt(&first, 3, 1) }), access.guard());
    const rows_before = table.root.rows;
    const result = (try table.perform(rejected, access.guard())).rejected;
    try t.expectEqual(.duplicate_key, result.reason);
    try t.expectEqualDeep(rows_before, table.root.rows);
    try t.expectEqual(@as(u64, 1), table.root.live_rows);
    try t.expect(table.root.pending == null);
    try table.recover();
    try t.expectEqualDeep(result, (try table.perform(rejected, access.guard())).rejected);
    _ = try table.changeDefinition(ddl, .{ .rename = "other" }, access.guard());
    try t.expectEqualDeep(result, (try table.operationState(rejected, access.guard())).rejected);
}

test "Table conditional admission distinguishes control progress from changed rows and retains rejection" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    _ = try table.apply(binding(&table, 1), &.{}, .point, access.guard());
    const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    var conditional = binding(&table, 2);
    conditional.expected_data = .{ .partition = 17, .next_lsn = table.root.next_lsn };
    const exact = request(&table, conditional, &.{});
    _ = try table.admit(exact, access.guard());
    const independent = binding(&table, 3);
    _ = try table.admit(request(&table, independent, &.{change(&cell, 3)}), access.guard());
    try t.expect((try table.perform(independent, access.guard())) == .committed);
    try t.expectEqual(.data_changed, (try table.perform(conditional, access.guard())).rejected.reason);
    var stale = conditional;
    stale.identity.operation = 4;
    try t.expectEqual(.data_changed, (try table.admit(request(&table, stale, &.{}), access.guard())).rejected.reason);
    try table.recover();
    try t.expectEqual(.data_changed, (try table.admit(exact, access.guard())).rejected.reason);
}

test "pinned data bases survive pre-admission controls and flushes but reject later logical changes on disk" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    const first: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    const second: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 2 } } };
    var exact: d.Binding = undefined;
    var source: d.Position = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        source = (try table.apply(binding(&table, 1), &.{change(&first, 1)}, .point, access.guard())).position;
        _ = try table.pin(.{ .scope = object.scope, .principal = 4, .operation = 90 }, source, access.guard());
        try t.expectEqual(@as(usize, 1), try table.flush(access.guard()));
        var noop = binding(&table, 2);
        noop.action = .update;
        noop.expected_data = source;
        const same: P.Change = .{ .put = .{ .row = change(&first, 1).put.row, .expect = .present } };
        try t.expectEqual(@as(u64, 0), (try table.apply(noop, &.{same}, .point, access.guard())).affected);
        exact = binding(&table, 3);
        exact.expected_data = source;
        const admitted = (try table.admit(request(&table, exact, &.{change(&second, 3)}), access.guard())).admitted;
        try t.expect(admitted.basis.position.next_lsn > source.next_lsn);
        try t.expectEqual(source.next_lsn, admitted.basis.changed_lsn);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    const accepted = (try table.perform(exact, access.guard())).committed;
    try t.expectEqual(@as(u64, 2), accepted.outcome.live_rows);
    var rejected = exact;
    rejected.identity.operation = 4;
    try t.expectEqual(.data_changed, (try table.admit(request(&table, rejected, &.{}), access.guard())).rejected.reason);
    rejected.identity.operation = 5;
    rejected.expected_data = .{ .partition = 18, .next_lsn = table.root.next_lsn };
    try t.expectEqual(.data_changed, (try table.admit(request(&table, rejected, &.{}), access.guard())).rejected.reason);
    rejected.identity.operation = 6;
    rejected.expected_data = .{ .partition = 17, .next_lsn = table.root.next_lsn + 2 };
    try t.expectEqual(.data_changed, (try table.admit(request(&table, rejected, &.{}), access.guard())).rejected.reason);
    _ = try table.pin(.{ .scope = object.scope, .principal = 4, .operation = 91 }, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
    _ = try table.flush(access.guard());
    var rename = binding(&table, 7);
    rename.action = .rename;
    rename.expected_data = accepted.outcome.position;
    _ = try table.changeDefinition(rename, .{ .rename = "renamed" }, access.guard());
    try table.recover();
    try t.expectEqualDeep(accepted, (try table.operationState(exact, access.guard())).committed);
    try t.expectEqual(@as(u64, 2), table.root.interpretation.revision);
}

test "admitted point and bulk UPDATE exchange primary keys while preserving row identity and rejecting survivors" {
    for ([_]P.Ingestion{ .point, .bulk }) |ingestion| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        var access: Access = .{};
        const first: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
        const second: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 2 } } };
        const first_row = change(&first, 1).put.row;
        const second_row = change(&second, 2).put.row;
        _ = try table.apply(binding(&table, 1), &.{ change(&first, 1), change(&second, 2) }, .point, access.guard());
        var first_buffer: [f.Collation.max_sort_key_bytes]u8 = undefined;
        var second_buffer: [f.Collation.max_sort_key_bytes]u8 = undefined;
        const first_key = try first_row.storageKey(schema, &first_buffer);
        const second_key = try second_row.storageKey(schema, &second_buffer);
        const moved_first: f.TableRow.Row = .{ .identity = first_row.identity, .cells = second_row.cells };
        const moved_second: f.TableRow.Row = .{ .identity = second_row.identity, .cells = first_row.cells };
        var collision = binding(&table, 2);
        collision.action = .update;
        _ = try table.admit(request(&table, collision, &.{.{ .replace = .{ .key = first_key, .row = moved_first } }}), access.guard());
        const unchanged = table.root.rows;
        try t.expectEqual(.duplicate_key, (try table.perform(collision, access.guard())).rejected.reason);
        try t.expectEqualDeep(unchanged, table.root.rows);
        var bad_identity = binding(&table, 3);
        bad_identity.action = .update;
        _ = try table.admit(request(&table, bad_identity, &.{.{ .replace = .{ .key = first_key, .row = second_row } }}), access.guard());
        try t.expectEqual(.invalid_rows, (try table.perform(bad_identity, access.guard())).rejected.reason);
        var exact = binding(&table, 4);
        exact.action = .update;
        exact.expected_data = .{ .partition = 17, .next_lsn = table.root.next_lsn };
        var intent = request(&table, exact, &.{ .{ .replace = .{ .key = first_key, .row = moved_first } }, .{ .replace = .{ .key = second_key, .row = moved_second } } });
        intent.ingestion = ingestion;
        _ = try table.admit(intent, access.guard());
        const result = (try table.perform(exact, access.guard())).committed;
        try t.expectEqual(@as(u64, 2), result.outcome.matched);
        try t.expectEqual(@as(u64, 2), result.outcome.affected);
        try t.expectEqual(@as(u64, 2), result.outcome.live_rows);
        try table.recover();
        var one = (try table.get(t.allocator, first_key, access.guard())).?;
        defer one.deinit();
        var two = (try table.get(t.allocator, second_key, access.guard())).?;
        defer two.deinit();
        try t.expectEqualDeep(second_row.identity, one.row().identity);
        try t.expectEqualDeep(first_row.identity, two.row().identity);
        try t.expectEqualDeep(result, (try table.perform(exact, access.guard())).committed);
        const other = change(&first, 99);
        var changed = intent;
        changed.changes = &.{other};
        try t.expectError(error.UnsupportedTableMutationShape, table.admit(changed, access.guard()));
    }
}

test "Table pending work grows beyond one disk cache page and missing frozen work cannot execute" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var last: d.Binding = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        _ = try table.apply(binding(&table, 1), &.{}, .point, access.guard());
        for (2..131) |id| {
            last = binding(&table, id);
            _ = try table.admit(request(&table, last, &.{}), access.guard());
        }
        try t.expectEqual(@as(usize, 1), table.index.cache.len);
        try t.expectEqual(@as(u64, 0), table.root.live_rows);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    const before = table.root;
    var count: usize = 0;
    var after: ?s.TreeStore.pages.Key = null;
    while (true) {
        const page = try table.pendingOperations(after, access.guard());
        count += page.len;
        after = page.after orelse break;
    }
    try t.expectEqual(@as(usize, 129), count);
    try t.expectEqualDeep(before, table.root);
    const pending = (try table.operationState(last, access.guard())).admitted;
    var name: [96]u8 = undefined;
    try objects.deleteObject(try s.TableDmlIntent.key(pending.intent, &name));
    try t.expectError(error.TableMutationIntentMissing, table.perform(last, access.guard()));
    try t.expectEqualDeep(before, table.root);
    try t.expect((try table.cancel(last, access.guard())) == .cancelled);
    try table.recover();
    try t.expect((try table.perform(last, access.guard())) == .cancelled);
}

test "Table recovery rejects a terminal operation forged back into admitted work" {
    const r = @import("TablePartitionRecord.zig");
    const pages = s.TreeStore.pages;
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    _ = try table.apply(binding(&table, 1), &.{}, .point, access.guard());
    const exact = binding(&table, 2);
    const admission = (try table.admit(request(&table, exact, &.{}), access.guard())).admitted;
    _ = try table.cancel(exact, access.guard());
    var root = table.root;
    root.next_lsn += 1;
    try table.index.begin(1024 * 1024);
    defer table.index.end();
    const tree: pages.Tree(s.TreeStore) = .{ .store = &table.index };
    var pointer: [8]u8 = undefined;
    std.mem.writeInt(u64, &pointer, table.root.next_lsn, .little);
    const key = try r.operationKey(exact.identity);
    root.operations = try tree.put(root.operations, key, try pages.Value.init(&pointer));
    root.pending = try tree.put(root.pending, key, try pages.Value.init(&pointer));
    const record: r.Record = .{ .definition = p.Growth.current_definition, .previous = table.chain, .root = root, .action = .{ .operation = admission } };
    var bytes: [r.max_metadata_bytes + r.header_bytes]u8 = undefined;
    _ = try wal.log().append(17, table.root.next_lsn, 1, 1, .manifest_checkpoint, try r.encode(record, &.{}, &bytes));
    try t.expectError(error.InvalidTableOperation, table.recover());
    try t.expectError(error.TableRecoveryRequired, table.operationState(exact, access.guard()));
}
