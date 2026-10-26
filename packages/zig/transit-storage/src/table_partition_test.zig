const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const P = s.TablePartition;
const r = @import("TablePartitionRecord.zig");
const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
const object: p.DataLifecycle.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };

test "Table history retention refuses required WAL coverage lost below its owner" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try P.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    var access: Access = .{};
    try table.recover();
    const one: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    _ = try table.apply(binding(&table, 1), &.{change(&one, 1)}, .point, access.guard());
    const basis: p.DataLifecycle.Position = .{ .partition = 17, .next_lsn = table.root.next_lsn };
    const pin_owner: p.DataLifecycle.Operation = .{ .scope = object.scope, .principal = 4, .operation = 1001 };
    const lease = try table.retainHistory(pin_owner, basis, access.guard());
    var initial = try table.historyStart(t.allocator, lease, access.guard());
    defer initial.deinit();
    const accepted = table.root;
    // Deliberately violate the Table retention authority through the lower
    // storage test interface. Normal Table operations never perform this trim.
    try wal.log().trim(17, table.root.next_lsn);
    try t.expectError(error.WalHistoryTrimmed, table.historyAt(t.allocator, initial.point, access.guard()));
    try t.expectError(error.WalHistoryTrimmed, table.retainedHistory(lease, basis, .{ .partition = 17, .next_lsn = table.root.next_lsn }, 1, access.guard()));
    try t.expectEqualDeep(accepted, table.root);
    try t.expect(!(try table.pinState(pin_owner, access.guard())).released);
}

test "Table history retention preserves exact logical successors and historical reads across restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const definition: s.TableDeclaration.Definition = .{ .object = object, .revision = 1, .schema = schema, .properties = "" };
    var access: Access = .{};
    var lease: P.SnapshotHandle = undefined;
    var point_pin: P.SnapshotHandle = undefined;
    var initial: P.HistoryPoint = undefined;
    var upper: p.DataLifecycle.Position = undefined;
    var selected: [3]P.HistoryPoint = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try P.init(t.allocator, 17, definition, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
        defer table.deinit();
        try table.recover();
        const one: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
        _ = try table.apply(binding(&table, 1), &.{change(&one, 1)}, .point, access.guard());
        const pin_owner: p.DataLifecycle.Operation = .{ .scope = object.scope, .principal = 4, .operation = 1001 };
        point_pin = try table.pin(pin_owner, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
        const history_owner: p.DataLifecycle.Operation = .{ .scope = object.scope, .principal = 4, .operation = 1002 };
        const beginning: p.DataLifecycle.Position = .{ .partition = 17, .next_lsn = table.root.next_lsn };
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.retainHistory(history_owner, beginning, access.guard()));
        table.lose_reply = false;
        lease = (try table.pinState(history_owner, access.guard())).handle.?;
        try t.expectEqualDeep(lease, try table.retainHistory(history_owner, beginning, access.guard()));
        try t.expectError(error.DataIdentityConflict, table.pin(history_owner, beginning, access.guard()));
        try t.expectError(error.TableHistoryRetentionRequired, table.historyStart(t.allocator, point_pin, access.guard()));
        var start = try table.historyStart(t.allocator, lease, access.guard());
        defer start.deinit();
        initial = start.point;
        try t.expectEqualDeep(beginning, initial.position);
        try t.expectEqual(@as(u64, 1), start.root.live_rows);
        const two: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 2 } } };
        _ = try table.apply(binding(&table, 2), &.{change(&two, 2)}, .point, access.guard());
        _ = try table.flush(access.guard());
        var key_bytes: [4096]u8 = undefined;
        var deletion = binding(&table, 3);
        deletion.action = .delete;
        _ = try table.apply(deletion, &.{.{ .remove = try key(1, &key_bytes) }}, .point, access.guard());
        deletion = binding(&table, 4);
        deletion.action = .delete;
        const no_op = try table.apply(deletion, &.{.{ .remove = try key(99, &key_bytes) }}, .point, access.guard());
        try t.expectEqual(@as(u64, 0), no_op.affected);
        upper = .{ .partition = 17, .next_lsn = table.root.next_lsn };
        const three: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 3 } } };
        _ = try table.apply(binding(&table, 5), &.{change(&three, 5)}, .bulk, access.guard());
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try P.init(t.allocator, 17, definition, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    var position = initial.position;
    var count: usize = 0;
    var empty: usize = 0;
    while (position.next_lsn < upper.next_lsn) {
        const page = try table.retainedHistory(lease, position, upper, 1, access.guard());
        try t.expectEqual(@as(u8, 1), page.scanned);
        try t.expect(page.next.next_lsn > position.next_lsn);
        if (page.count == 0) empty += 1;
        for (page.entries[0..page.count]) |entry| {
            try t.expect(count < selected.len);
            try t.expectEqual(@as(u64, @intCast(count + 2)), entry.?.receipt.binding.identity.operation);
            selected[count] = .{ .lease = lease, .position = .{ .partition = 17, .next_lsn = entry.?.root.next_lsn }, .commitment = entry.?.commitment };
            count += 1;
        }
        position = page.next;
    }
    try t.expectEqual(@as(usize, 3), count);
    try t.expectEqual(@as(usize, 2), empty); // Lease acquisition and flush.
    try t.expectError(error.TableHistoryRetentionRequired, table.retainedHistory(point_pin, initial.position, upper, 1, access.guard()));
    var initial_rows = try table.scanHistory(t.allocator, initial, null, .{}, access.guard());
    defer initial_rows.deinit();
    try t.expectEqual(@as(u8, 1), initial_rows.page.count);
    try t.expectEqual(@as(i128, 1), initial_rows.page.rows[0].?.row().cells[0].value.atom.signed);
    var inserted = try table.scanHistory(t.allocator, selected[0], null, .{ .rows = 1 }, access.guard());
    defer inserted.deinit();
    try t.expectEqual(@as(u64, 2), inserted.page.total_rows);
    try t.expect(inserted.page.next != null);
    var remainder = try table.scanHistory(t.allocator, selected[0], inserted.page.next, .{}, access.guard());
    defer remainder.deinit();
    try t.expectEqual(@as(i128, 2), remainder.page.rows[0].?.row().cells[0].value.atom.signed);
    try t.expectError(error.InvalidTableSnapshotCursor, table.scanHistory(t.allocator, selected[1], inserted.page.next, .{}, access.guard()));
    var removed = try table.historyAt(t.allocator, selected[1], access.guard());
    defer removed.deinit();
    var unchanged = try table.historyAt(t.allocator, selected[2], access.guard());
    defer unchanged.deinit();
    try t.expectEqual(removed.root.changed_lsn, unchanged.root.changed_lsn);
    try t.expect(removed.point.position.next_lsn < unchanged.point.position.next_lsn);
    try t.expect(!std.mem.eql(u8, &removed.point.commitment, &unchanged.point.commitment));
    var corrupt = selected[0];
    corrupt.commitment[0] ^= 1;
    try t.expectError(error.TableHistoryConflict, table.historyAt(t.allocator, corrupt, access.guard()));
    corrupt = initial;
    corrupt.position.next_lsn -= 1;
    try t.expectError(error.InvalidTableBasis, table.historyAt(t.allocator, corrupt, access.guard()));
    access.deny_at = access.calls + 4;
    try t.expectError(error.PermissionDenied, table.scanHistory(t.allocator, initial, null, .{}, access.guard()));
    access.deny_at = std.math.maxInt(usize);
    try table.releaseSnapshot(lease, access.guard());
    try t.expectError(error.TableSnapshotReleased, table.historyAt(t.allocator, initial, access.guard()));
    try t.expectError(error.TableSnapshotReleased, table.retainedHistory(lease, initial.position, upper, 1, access.guard()));
    var still_pinned = try table.inspectSnapshot(t.allocator, point_pin, access.guard());
    defer still_pinned.deinit();
    try t.expectEqual(.snapshot, still_pinned.retention);
    try table.releaseSnapshot(point_pin, access.guard());
}

test "physical value constraints precede WAL acceptance and exact values survive flush and reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const fields = [_]f.TableSchema.Column{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false, .encoding = .bitpacked },
        .{ .id = 2, .name = "text", .type = .utf8, .nullable = false, .encoding = .ebcdic },
        .{ .id = 3, .name = "rate", .type = .float64, .encoding = .ibm_hfp },
        .{ .id = 4, .name = "rle", .type = .float64, .encoding = .rle },
        .{ .id = 5, .name = "dictionary", .type = .float64, .encoding = .dictionary },
        .{ .id = 6, .name = "packed", .type = .int64, .encoding = .comp_3 },
        .{ .id = 7, .name = "zoned", .type = .{ .decimal = .{ .precision = 31, .scale = 2 } }, .encoding = .zoned },
        .{ .id = 8, .name = "binary", .type = .int64, .encoding = .comp },
    };
    const definition: s.TableDeclaration.Definition = .{ .object = object, .revision = 1, .schema = .{ .object = 7, .revision = 1, .next_column = 9, .columns = &fields, .primary_key = &.{1} }, .properties = "" };
    const cells = [_]f.Types.Values.Cell{
        .{ .value = .{ .atom = .{ .signed = 1 } } },
        .{ .value = .{ .atom = .{ .bytes = "é£¬^\x00\u{0085}ÿ" } } },
        .{ .value = .{ .atom = .{ .float = -0.0 } } },
        .{ .value = .{ .atom = .{ .float = -0.0 } } },
        .{ .value = .{ .atom = .{ .float = -0.0 } } },
        .{ .value = .{ .atom = .{ .signed = std.math.minInt(i64) } } },
        .{ .value = .{ .atom = .{ .decimal = -9999999999999999999999999999999 } } },
        .{ .value = .{ .atom = .{ .signed = std.math.maxInt(i64) } } },
    };
    var access: Access = .{};
    var retained: P.Root = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try P.init(t.allocator, 17, definition, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
        defer table.deinit();
        try table.recover();
        const row: f.TableRow.Row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = 0 }, .cells = &cells };
        _ = try table.apply(binding(&table, 1), &.{.{ .put = .{ .row = row, .expect = .absent } }}, .point, access.guard());
        retained = table.root;
        const tail = try wal.log().tail(17);
        var invalid = cells;
        invalid[0].value.atom.signed = 2;
        invalid[1].value.atom.bytes = "€";
        const bad: f.TableRow.Row = .{ .identity = .{ .origin = 7, .operation = 2, .ordinal = 0 }, .cells = &invalid };
        try t.expectError(error.UnrepresentableEbcdic037, table.apply(binding(&table, 2), &.{.{ .put = .{ .row = bad, .expect = .absent } }}, .point, access.guard()));
        invalid[1] = cells[1];
        invalid[2].value.atom.float = 0x1p-261;
        try t.expectError(error.IbmHfpUnderflow, table.apply(binding(&table, 2), &.{.{ .put = .{ .row = bad, .expect = .absent } }}, .bulk, access.guard()));
        try t.expectEqual(tail, try wal.log().tail(17));
        try t.expectEqualDeep(retained, table.root);
        try t.expectEqual(@as(usize, 1), try table.flush(access.guard()));
        try t.expectEqual(retained.changed_lsn, table.root.changed_lsn);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try P.init(t.allocator, 17, definition, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    var key_buffer: [f.Collation.max_sort_key_bytes]u8 = undefined;
    const row_key = try f.Collation.encodePrimaryKeySortKey(definition.schema, &cells, true, &key_buffer);
    var before = (try table.getAt(t.allocator, retained, row_key)).?;
    defer before.deinit();
    var after = (try table.get(t.allocator, row_key, access.guard())).?;
    defer after.deinit();
    try t.expect(before == .wal and after == .segment);
    for ([_]f.TableRow.Row{ before.row(), after.row() }) |actual| {
        try t.expectEqualDeep(@as([]const f.Types.Values.Cell, &cells), actual.cells);
        for (actual.cells[2..5]) |cell| try t.expectEqual(@as(u64, 1) << 63, @as(u64, @bitCast(cell.value.atom.float)));
    }
}

const Access = struct {
    calls: usize = 0,
    released: usize = 0,
    deny_at: usize = std.math.maxInt(usize),
    fn acquire(context: *anyopaque) !P.Guard.Fence {
        const self: *Access = @ptrCast(@alignCast(context));
        self.calls += 1;
        if (self.calls >= self.deny_at) return error.PermissionDenied;
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(context: *anyopaque) void {
        const self: *Access = @ptrCast(@alignCast(context));
        self.released += 1;
    }
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
fn binding(partition: *P, operation: u64) p.DataLifecycle.Binding {
    return .{ .definition = p.Growth.current_definition, .identity = .{ .scope = object.scope, .principal = 4, .operation = operation }, .target = object, .action = if (partition.root.next_lsn == 0) .create else .insert, .expected_definition = if (partition.root.next_lsn == 0) null else partition.root.interpretation, .expected_data = null, .intent = @splat(7) };
}
fn change(value: *const f.Types.Values.Cell, operation: u64) P.Change {
    return .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = operation, .ordinal = 0 }, .cells = @as(*const [1]f.Types.Values.Cell, @ptrCast(value)) }, .expect = .absent } };
}
fn key(value: i128, buffer: []u8) ![]const u8 {
    return f.Collation.encodePrimaryKeySortKey(schema, &.{.{ .value = .{ .atom = .{ .signed = value } } }}, false, buffer);
}

test "logical Table history is bounded, separates physical work and preserves accepted no-ops across restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var upper: p.DataLifecycle.Position = undefined;
    var changed: u64 = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        for (0..19) |i| {
            const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = @intCast(i) } } };
            _ = try table.apply(binding(&table, i + 1), &.{change(&cell, i + 1)}, .point, access.guard());
            if (i % 3 == 0) _ = try table.flush(access.guard());
            if (i == 5) {
                const handle = try table.pin(.{ .scope = object.scope, .principal = 4, .operation = 1000 }, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
                try table.releaseSnapshot(handle, access.guard());
            }
        }
        changed = table.root.changed_lsn;
        _ = try table.apply(binding(&table, 20), &.{}, .point, access.guard());
        try t.expectEqual(changed, table.root.changed_lsn);
        upper = .{ .partition = 17, .next_lsn = table.root.next_lsn };
        // A later accepted mutation must not expand this inspection interval.
        const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 100 } } };
        _ = try table.apply(binding(&table, 21), &.{change(&cell, 21)}, .point, access.guard());
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    const before = table.root;
    var cursor: p.DataLifecycle.Position = .{ .partition = 17, .next_lsn = 0 };
    var count: u64 = 0;
    var empty: usize = 0;
    while (cursor.next_lsn < upper.next_lsn) {
        const page = try table.history(cursor, upper, 1, access.guard());
        try t.expectEqual(@as(u8, 1), page.scanned);
        try t.expectEqualDeep(object, page.object);
        try t.expectEqualDeep(upper, page.through);
        if (page.count == 0) empty += 1;
        for (page.entries[0..page.count]) |slot| {
            const entry = slot.?;
            count += 1;
            try t.expectEqual(count, entry.receipt.binding.identity.operation);
            try t.expectEqual(@min(count, 19), entry.root.live_rows);
            try t.expectEqual(entry.root.next_lsn, entry.receipt.outcome.position.next_lsn);
            try t.expect(!std.mem.allEqual(u8, &entry.commitment, 0));
            if (count == 20) {
                try t.expectEqual(@as(u64, 0), entry.receipt.outcome.affected);
                try t.expectEqual(changed, entry.root.changed_lsn);
            }
        }
        cursor = page.next;
    }
    try t.expectEqual(@as(u64, 20), count);
    try t.expect(empty >= 9); // seven flushes and two pin transitions
    try t.expectEqual(@as(u8, 0), (try table.history(upper, upper, 8, access.guard())).scanned);
    access.deny_at = access.calls + 2;
    try t.expectError(error.PermissionDenied, table.history(.{ .partition = 17, .next_lsn = 0 }, upper, 8, access.guard()));
    try t.expectEqualDeep(before, table.root);
    try t.expectError(error.InvalidTableReadBudget, table.history(upper, upper, 9, access.guard()));
    try t.expectError(error.InvalidTableBasis, table.history(.{ .partition = 18, .next_lsn = 0 }, upper, 1, access.guard()));
}

test "Table no-op receipts preserve logical data and report original matched and changed rows after restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const fields = [_]f.TableSchema.Column{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
        .{ .id = 2, .name = "value", .type = .int64, .nullable = false },
    };
    const definition: s.TableDeclaration.Definition = .{ .object = object, .revision = 1, .schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &fields, .primary_key = &.{1} }, .properties = "" };
    const first = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .signed = 10 } } } };
    const second = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 2 } } }, .{ .value = .{ .atom = .{ .signed = 20 } } } };
    const changed_second = [_]f.Types.Values.Cell{ second[0], .{ .value = .{ .atom = .{ .signed = 21 } } } };
    const first_row: f.TableRow.Row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = 0 }, .cells = &first };
    const second_row: f.TableRow.Row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = 1 }, .cells = &second };
    var access: Access = .{};
    var saved: p.DataLifecycle.Binding = undefined;
    var original: P.Root = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try P.init(t.allocator, 17, definition, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
        defer table.deinit();
        try table.recover();
        _ = try table.apply(binding(&table, 1), &.{ .{ .put = .{ .row = first_row, .expect = .absent } }, .{ .put = .{ .row = second_row, .expect = .absent } } }, .point, access.guard());
        original = table.root;
        saved = binding(&table, 2);
        saved.action = .update;
        saved.expected_data = .{ .partition = 17, .next_lsn = table.root.next_lsn };
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.apply(saved, &.{.{ .put = .{ .row = first_row, .expect = .present } }}, .point, access.guard()));
        try t.expectEqualDeep(original.rows, table.root.rows);
        try t.expectEqualDeep(original.scan_rows, table.root.scan_rows);
        try t.expectEqual(original.changed_lsn, table.root.changed_lsn);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try P.init(t.allocator, 17, definition, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    const repeated = try table.apply(saved, &.{.{ .put = .{ .row = first_row, .expect = .present } }}, .point, access.guard());
    try t.expectEqual(@as(u64, 1), repeated.matched);
    try t.expectEqual(@as(u64, 0), repeated.affected);
    try t.expectEqual(@as(u64, 2), repeated.position.next_lsn);
    var accepted = try wal.log().read(t.allocator, 17, 1, 1);
    defer accepted.deinit();
    try t.expectEqual(@as(usize, 0), (try r.decode(t.allocator, accepted.frames[0].payload, 1)).rows.len);
    var bulk = binding(&table, 3);
    bulk.action = .update;
    const unchanged = try table.apply(bulk, &.{.{ .put = .{ .row = second_row, .expect = .present } }}, .bulk, access.guard());
    try t.expectEqual(@as(u64, 1), unchanged.matched);
    try t.expectEqual(@as(u64, 0), unchanged.affected);
    try t.expectEqual(original.next_segment, table.root.next_segment);
    try t.expectEqual(original.changed_lsn, table.root.changed_lsn);
    var mixed = binding(&table, 4);
    mixed.action = .update;
    const updated: f.TableRow.Row = .{ .identity = second_row.identity, .cells = &changed_second };
    const result = try table.apply(mixed, &.{ .{ .put = .{ .row = first_row, .expect = .present } }, .{ .put = .{ .row = updated, .expect = .present } } }, .point, access.guard());
    try t.expectEqual(@as(u64, 2), result.matched);
    try t.expectEqual(@as(u64, 1), result.affected);
    try t.expectEqual(result.position.next_lsn, table.root.changed_lsn);
    var bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
    var row = (try table.get(t.allocator, try key(2, &bytes), access.guard())).?;
    defer row.deinit();
    try t.expectEqual(@as(i128, 21), row.row().cells[1].value.atom.signed);
    var old = (try table.getAt(t.allocator, original, try key(2, &bytes))).?;
    defer old.deinit();
    try t.expectEqual(@as(i128, 20), old.row().cells[1].value.atom.signed);
    try t.expectEqualDeep(repeated, (try table.observe(saved, access.guard())).?);
    var missing = binding(&table, 5);
    missing.action = .delete;
    const missed = try table.apply(missing, &.{.{ .remove = try key(99, &bytes) }}, .point, access.guard());
    try t.expectEqual(@as(u64, 0), missed.matched);
    try t.expectEqual(@as(u64, 0), missed.affected);
    try t.expectEqual(result.position.next_lsn, table.root.changed_lsn);
}

test "Table acceptance recovers the exact point and bulk result after a lost reply" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var saved: p.DataLifecycle.Binding = undefined;
    var first: P.Root = undefined;
    var access: Access = .{};
    const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        saved = binding(&table, 1);
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.apply(saved, &.{change(&cell, 1)}, .point, access.guard()));
        first = table.root;
        try t.expectEqual(@as(u64, 1), try wal.log().tail(17));
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    const recovered = (try table.observe(saved, access.guard())).?;
    try t.expectEqual(@as(u64, 1), recovered.affected);
    try t.expectEqualDeep(recovered, try table.apply(saved, &.{change(&cell, 1)}, .point, access.guard()));
    try t.expectEqual(@as(u64, 1), try wal.log().tail(17));
    const different: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 2 } } };
    try t.expectError(error.DataIdentityConflict, table.apply(saved, &.{change(&different, 1)}, .point, access.guard()));
    const second = binding(&table, 2);
    _ = try table.apply(second, &.{change(&different, 2)}, .bulk, access.guard());
    var storage_key: [f.Collation.max_sort_key_bytes]u8 = undefined;
    var row = (try table.get(t.allocator, try key(2, &storage_key), access.guard())).?;
    defer row.deinit();
    try t.expect(row == .segment);
    try t.expectEqual(@as(i128, 2), row.row().cells[0].value.atom.signed);
    try t.expect((try table.getAt(t.allocator, first, try key(2, &storage_key))) == null);
    const logical = table.root.changed_lsn;
    try t.expectEqual(@as(usize, 1), try table.flush(access.guard()));
    try t.expectEqual(logical, table.root.changed_lsn);
    var older = (try table.getAt(t.allocator, first, try key(1, &storage_key))).?;
    defer older.deinit();
    try t.expect(older == .wal);
    try table.recover();
    var flushed = (try table.get(t.allocator, try key(1, &storage_key), access.guard())).?;
    defer flushed.deinit();
    try t.expect(flushed == .segment);
    try t.expectEqualDeep(recovered, (try table.observe(saved, access.guard())).?);
    try t.expectEqual(@as(usize, 0), try table.flush(access.guard()));
    access.deny_at = access.calls + 1;
    try t.expectError(error.PermissionDenied, table.observe(saved, access.guard()));
    try t.expectError(error.PermissionDenied, table.get(t.allocator, try key(1, &storage_key), access.guard()));
}

test "all Table changes and their receipt stay invisible when the final policy fence denies" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{ .deny_at = 2 };
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .signed = 2 } } } };
    const changes = [_]P.Change{ change(&cells[0], 1), change(&cells[1], 2) };
    const original = table.root;
    const request = binding(&table, 1);
    try t.expectError(error.PermissionDenied, table.apply(request, &changes, .bulk, access.guard()));
    try t.expect(objects.puts > 0);
    try t.expectEqual(@as(u64, 0), try wal.log().tail(17));
    try t.expectEqualDeep(original, table.root);
    access.deny_at = std.math.maxInt(usize);
    try t.expect((try table.observe(request, access.guard())) == null);
    const result = try table.apply(request, &changes, .bulk, access.guard());
    try t.expectEqual(@as(u64, 2), result.affected);
    try t.expectEqual(@as(u64, 1), try wal.log().tail(17));
    try t.expectEqual(@as(u64, 2), table.root.live_rows);
    try table.recover();
    try t.expectEqualDeep(result, (try table.observe(request, access.guard())).?);
}

test "Table rows and exact receipts exceed the resident cache and retain deletes on restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var access: Access = .{};
    var creation: p.DataLifecycle.Binding = undefined;
    {
        var table = try owner(&wal, &objects);
        defer table.deinit();
        creation = binding(&table, 1);
        for (0..129) |i| {
            const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = @intCast(i) } } };
            _ = try table.apply(binding(&table, i + 1), &.{change(&cell, i + 1)}, .point, access.guard());
        }
        try t.expect(table.index.misses > 129);
        try t.expectEqual(@as(usize, 1), table.index.cache.len);
        try t.expectEqual(@as(usize, 129), try table.flush(access.guard()));
        var storage_key: [f.Collation.max_sort_key_bytes]u8 = undefined;
        var deletion = binding(&table, 130);
        deletion.action = .delete;
        _ = try table.apply(deletion, &.{.{ .remove = try key(64, &storage_key) }}, .point, access.guard());
    }
    var table = try owner(&wal, &objects);
    defer table.deinit();
    try t.expectEqual(@as(u64, 128), table.root.live_rows);
    var after: ?s.TreeStore.pages.Key = null;
    var count: usize = 0;
    while (true) {
        const batch = try table.scan(table.root, after);
        for (batch.entries) |slot| if (slot) |entry| {
            var row = try table.readRow(t.allocator, table.root, entry.key, entry.value);
            defer row.deinit();
            try t.expect(row.row().cells[0].value.atom.signed != 64);
            count += 1;
        };
        after = batch.next orelse break;
    }
    try t.expectEqual(@as(usize, 128), count);
    try t.expectEqual(@as(u64, 1), table.segment_reads);
    try t.expectEqual(@as(u64, 1), table.row_groups_decoded);
    for (0..129) |i| try t.expectEqual(@as(u64, 1), (try table.observe(if (i == 0) creation else binding(&table, i + 1), access.guard())).?.affected);
}

test "one accepted Table batch exceeds native turn blocks and flushes large values without unsafe pruning" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const wide_columns = [_]f.TableSchema.Column{
        columns[0], .{ .id = 2, .name = "body", .type = .utf8, .nullable = false, .collation = .utf8_binary },
    };
    var wide = schema;
    wide.columns = &wide_columns;
    wide.next_column = 3;
    var table = try P.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = wide, .properties = "" }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    var access: Access = .{};
    const body: [8192]u8 = @splat('z');
    var cells: [64][2]f.Types.Values.Cell = undefined;
    var changes: [64]P.Change = undefined;
    for (&cells, &changes, 0..) |*values, *mutation, i| {
        values.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(i) } } }, .{ .value = .{ .atom = .{ .bytes = if (i == 0) "a" else &body } } } };
        mutation.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = @intCast(i) }, .cells = values }, .expect = .absent } };
    }
    const result = try table.apply(binding(&table, 1), &changes, .point, access.guard());
    try t.expectEqual(@as(u64, 64), result.affected);
    try t.expectEqual(@as(u64, 1), try wal.log().tail(17));
    try t.expect(wal.bytes_written > 512 * 1024);
    try t.expectEqual(@as(usize, 64), try table.flush(access.guard()));
    var storage_key: [f.Collation.max_sort_key_bytes]u8 = undefined;
    var row = (try table.get(t.allocator, try key(63, &storage_key), access.guard())).?;
    defer row.deinit();
    try t.expect(row == .segment);
    try t.expectEqualStrings(&body, row.row().cells[1].value.atom.bytes);
    var found = false;
    for (objects.objects.items) |stored| {
        if (!std.mem.endsWith(u8, stored.key, ".tseg")) continue;
        var footer = try f.TSeg.readFooter(t.allocator, stored.bytes);
        defer footer.deinit();
        var target: [64]u8 = undefined;
        const sort_key = try f.Collation.encodeSortKey(.{ .value = .{ .atom = .{ .bytes = "b" } } }, .utf8, .utf8_binary, &target);
        try t.expect(footer.row_groups[0].zone_maps[1].mayMatch(.gt, sort_key));
        try t.expect(footer.row_groups[0].pages[1].length > 256 * 1024);
        found = true;
    }
    try t.expect(found);
}

test "Table segment ranges bound cold point IO and preserve owned rows across eviction and restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    const wide_columns = [_]f.TableSchema.Column{
        columns[0], .{ .id = 2, .name = "body", .type = .utf8, .nullable = false },
    };
    var wide = schema;
    wide.columns = &wide_columns;
    wide.next_column = 3;
    const definition: s.TableDeclaration.Definition = .{ .object = object, .revision = 1, .schema = wide, .properties = "" };
    var access: Access = .{};
    const body: [2048]u8 = @splat('q');
    var creation: p.DataLifecycle.Binding = undefined;
    {
        var table = try P.init(t.allocator, 17, definition, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
        defer table.deinit();
        try table.recover();
        var cells: [512][2]f.Types.Values.Cell = undefined;
        var changes: [512]P.Change = undefined;
        for (&cells, &changes, 0..) |*values, *mutation, i| {
            values.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(i) } } }, .{ .value = .{ .atom = .{ .bytes = &body } } } };
            mutation.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = @intCast(i) }, .cells = values }, .expect = .absent } };
        }
        creation = binding(&table, 1);
        _ = try table.apply(creation, &changes, .bulk, access.guard());
    }
    var table = try P.init(t.allocator, 17, definition, wal.log(), objects.objectStore(), .{ .resident_pages = 1, .segment_decode_bytes = 16 * 1024 });
    defer table.deinit();
    try table.recover();
    var key_buffer: [4096]u8 = undefined;
    var first = (try table.get(t.allocator, try key(0, &key_buffer), access.guard())).?;
    defer first.deinit();
    const cold_bytes = table.segment_bytes_read;
    const full_bytes = table.segment_cache.?.length;
    try t.expect(full_bytes > 1024 * 1024);
    try t.expectEqual(@as(u64, 5), table.segment_range_reads); // header/trailer/footer + two columns
    try t.expect(cold_bytes * 10 < @as(u64, full_bytes) * 6);
    const point_resident = table.segment_cache.?.decoded.?.allocatedBytes();
    const point_peak = table.segment_cache.?.decoded.?.peakAllocatedBytes();
    const encoded_resident = table.segment_cache.?.encoded.?.allocatedBytes();
    try t.expect(point_peak <= 16 * 1024);
    try t.expectEqual(@as(usize, 1), table.segment_cache.?.decoded.?.columns[0].len);
    var adjacent = (try table.get(t.allocator, try key(1, &key_buffer), access.guard())).?;
    defer adjacent.deinit();
    try t.expectEqual(cold_bytes, table.segment_bytes_read);
    try t.expectEqual(@as(u64, 2), table.row_groups_decoded);
    var distant = (try table.get(t.allocator, try key(511, &key_buffer), access.guard())).?;
    defer distant.deinit();
    try t.expectEqual(@as(u64, 7), table.segment_range_reads);
    try t.expectEqual(@as(u64, 3), table.row_groups_decoded);
    try t.expectEqual(@as(i128, 511), distant.row().cells[0].value.atom.signed);
    try t.expectEqualStrings(&body, first.row().cells[1].value.atom.bytes);
    try table.recover(); // destroys both caches
    try t.expectEqualStrings(&body, adjacent.row().cells[1].value.atom.bytes);

    // A complete group needs more memory than a singleton. Failure leaves
    // the accepted root untouched and does not invalidate earlier owned rows.
    const accepted_before_scan = table.root;
    const one_page = try table.scan(table.root, null);
    const one_entry = one_page.entries[0].?;
    try t.expectError(error.SegmentReadBudgetExceeded, table.readRow(t.allocator, table.root, one_entry.key, one_entry.value));
    try t.expectEqualDeep(accepted_before_scan, table.root);
    try t.expectEqualStrings(&body, first.row().cells[1].value.atom.bytes);
    table.options.segment_decode_bytes = 64 * 1024 * 1024;
    try table.recover();

    // A complete same-root physical scan is the value/count control. Each row
    // is checked against the independent ordinal and payload, not just a count.
    var after: ?s.TreeStore.pages.Key = null;
    var count: usize = 0;
    const scan_index_before = table.index.misses;
    const ranges_before = table.segment_range_reads;
    const bytes_before = table.segment_bytes_read;
    while (true) {
        const batch = try table.scan(table.root, after);
        for (batch.entries) |slot| if (slot) |entry| {
            var row = try table.readRow(t.allocator, table.root, entry.key, entry.value);
            defer row.deinit();
            try t.expectEqual(@as(i128, @intCast(count)), row.row().cells[0].value.atom.signed);
            try t.expectEqualStrings(&body, row.row().cells[1].value.atom.bytes);
            count += 1;
        };
        after = batch.next orelse break;
    }
    try t.expectEqual(@as(usize, 512), count);
    try t.expectEqual(@as(u64, 7), table.segment_range_reads - ranges_before);
    const scan_bytes = table.segment_bytes_read - bytes_before;
    const scan_resident = table.segment_cache.?.decoded.?.allocatedBytes();
    try t.expect(point_resident * 20 < scan_resident);
    std.debug.print("Table selected decoding: point={d} retained/{d} peak decoded bytes, encoded cache={d}; full group={d} retained decoded bytes\n", .{ point_resident, point_peak, encoded_resident, scan_resident });
    try t.expect(scan_bytes <= full_bytes);
    std.debug.print("Table segment ranges: segment={d} cold_point={d} warm_point=0 same_cut_scan={d} bytes; point_ranges=5 scan_ranges=7 rows={d}\n", .{ full_bytes, cold_bytes, scan_bytes, count });
    const scan_index_misses = table.index.misses - scan_index_before;
    const snapshot = try table.pin(.{ .scope = object.scope, .principal = 4, .operation = 90 }, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
    table.options.segment_decode_bytes = 16 * 1024;
    try table.recover();
    var retained_point = (try table.readSnapshot(t.allocator, snapshot, try key(255, &key_buffer), access.guard())).?;
    defer retained_point.deinit();
    const retained_point_bytes = table.segment_bytes_read;
    var current_point = (try table.readCurrent(t.allocator, .{ .partition = 17, .next_lsn = table.root.next_lsn }, try key(254, &key_buffer), access.guard())).?;
    defer current_point.deinit();
    try t.expectEqual(retained_point_bytes, table.segment_bytes_read);
    try t.expectEqual(@as(i128, 255), retained_point.row().cells[0].value.atom.signed);
    try t.expectEqual(@as(i128, 254), current_point.row().cells[0].value.atom.signed);
    try t.expectEqualStrings(&body, retained_point.row().cells[1].value.atom.bytes);
    table.options.segment_decode_bytes = 64 * 1024 * 1024;
    try table.recover();
    try t.expectEqualStrings(&body, current_point.row().cells[1].value.atom.bytes);
    const key_bytes_before = table.segment_bytes_read;
    const key_index_before = table.index.misses;
    var upper_key: [4096]u8 = undefined;
    var selected = try table.rangeSnapshot(t.allocator, snapshot, .{
        .lower = .{ .key = try key(3, &key_buffer) },
        .upper = .{ .key = try key(7, &upper_key), .inclusive = false },
    }, null, .{}, access.guard());
    defer selected.deinit();
    try t.expectEqual(@as(u8, 4), selected.count);
    try t.expect(selected.next == null);
    for (selected.rows[0..selected.count], 3..) |slot, expected| {
        try t.expectEqual(@as(i128, @intCast(expected)), slot.?.row().cells[0].value.atom.signed);
        try t.expectEqualStrings(&body, slot.?.row().cells[1].value.atom.bytes);
    }
    const key_bytes = table.segment_bytes_read - key_bytes_before;
    const key_index_misses = table.index.misses - key_index_before;
    try t.expectEqual(cold_bytes, key_bytes);
    try t.expect(key_index_misses < scan_index_misses);
    std.debug.print("Table ordered interval: 4/512 rows, segment_bytes={d}/{d}, index_misses={d}/{d} versus same-cut scan; one resident index page\n", .{ key_bytes, scan_bytes, key_index_misses, scan_index_misses });
    // Budget exhaustion preserves the accepted state and original receipt.
    const accepted = table.root;
    table.options.segment_decode_bytes = 1;
    try table.recover();
    try t.expectError(error.SegmentReadBudgetExceeded, table.get(t.allocator, try key(0, &key_buffer), access.guard()));
    try t.expectEqualDeep(accepted, table.root);
    try t.expectEqual(@as(u64, 512), (try table.observe(creation, access.guard())).?.affected);
    table.options.segment_decode_bytes = 64 * 1024 * 1024;
    table.options.segment_cache_bytes = 0;
    try table.recover();
    var uncached = (try table.get(t.allocator, try key(511, &key_buffer), access.guard())).?;
    defer uncached.deinit();
    try t.expect(table.segment_cache == null);
    try t.expectEqualStrings(&body, uncached.row().cells[1].value.atom.bytes);
}

test "durable Table pins recover lost acquisition replies and preserve the unflushed cut through flush and delete" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const pin_owner: p.DataLifecycle.Operation = .{ .scope = object.scope, .principal = 4, .operation = 91 };
    const expected: p.DataLifecycle.Position = .{ .partition = 17, .next_lsn = 1 };
    var access: Access = .{};
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 42 } } };
        _ = try table.apply(binding(&table, 1), &.{change(&cell, 1)}, .point, access.guard());
        const before = try table.pinState(pin_owner, access.guard());
        try t.expect(before.handle == null and !before.released and !before.retired);
        try t.expectEqualDeep(expected, before.position);
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.pin(pin_owner, expected, access.guard()));
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    const recovered = try table.pinState(pin_owner, access.guard());
    try t.expect(recovered.handle != null and !recovered.released);
    const handle = try table.pin(pin_owner, expected, access.guard());
    try t.expectEqualDeep(handle, recovered.handle.?);
    try t.expectEqual(@as(u64, 2), table.root.next_lsn);
    try t.expectEqual(@as(u64, 1), table.root.changed_lsn);
    try t.expectEqual(@as(usize, 1), try table.flush(access.guard()));
    var storage_key: [f.Collation.max_sort_key_bytes]u8 = undefined;
    const row_key = try key(42, &storage_key);
    var deletion = binding(&table, 2);
    deletion.action = .delete;
    _ = try table.apply(deletion, &.{.{ .remove = row_key }}, .point, access.guard());
    try table.recover();
    try t.expect((try table.get(t.allocator, row_key, access.guard())) == null);
    var old = (try table.readSnapshot(t.allocator, handle, row_key, access.guard())).?;
    defer old.deinit();
    try t.expect(old == .wal);
    try t.expectEqual(@as(i128, 42), old.row().cells[0].value.atom.signed);
    var changed = expected;
    changed.next_lsn = 2;
    try t.expectError(error.DataIdentityConflict, table.pin(pin_owner, changed, access.guard()));
    access.deny_at = access.calls + 1;
    try t.expectError(error.PermissionDenied, table.pinState(pin_owner, access.guard()));
    try t.expectError(error.PermissionDenied, table.readSnapshot(t.allocator, handle, row_key, access.guard()));
    try t.expectError(error.PermissionDenied, table.releaseSnapshot(handle, access.guard()));
    access.deny_at = std.math.maxInt(usize);
    try table.releaseSnapshot(handle, access.guard());
    const released_at = table.root.next_lsn;
    try table.recover();
    try table.releaseSnapshot(handle, access.guard());
    try t.expectEqual(released_at, table.root.next_lsn);
    const released = try table.pinState(pin_owner, access.guard());
    try t.expect(released.released);
    try t.expectEqualDeep(handle, released.handle.?);
    var missing_owner = pin_owner;
    missing_owner.operation += 1;
    const missing = try table.pinState(missing_owner, access.guard());
    try t.expect(missing.handle == null and !missing.released);
    try t.expect(missing.position.next_lsn > expected.next_lsn);
    try t.expectEqual(released_at, table.root.next_lsn);
    try t.expectError(error.TableSnapshotReleased, table.readSnapshot(t.allocator, handle, row_key, access.guard()));
    try t.expectError(error.TableSnapshotReleased, table.pin(pin_owner, expected, access.guard()));
}

test "interrupted Table pin staging never publishes a snapshot and pin counts exceed the cache" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    _ = try table.apply(binding(&table, 1000), &.{}, .point, access.guard());
    access = .{ .deny_at = 2 };
    const identity: p.DataLifecycle.Operation = .{ .scope = object.scope, .principal = 4, .operation = 1 };
    const empty: p.DataLifecycle.Position = .{ .partition = 17, .next_lsn = 1 };
    try t.expectError(error.PermissionDenied, table.pin(identity, empty, access.guard()));
    try t.expectEqual(@as(u64, 1), table.root.next_lsn);
    try t.expect(table.root.pins == null);
    try t.expect(objects.puts > 0);
    access.deny_at = std.math.maxInt(usize);
    const first = try table.pin(identity, empty, access.guard());
    for (2..130) |i| {
        var owner_id = identity;
        owner_id.operation = i;
        _ = try table.pin(owner_id, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
    }
    try t.expectEqual(@as(usize, 1), table.index.cache.len);
    try table.recover();
    try t.expectEqualDeep(first, try table.pin(identity, empty, access.guard()));
    var forged = first;
    forged.content.sha256[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, table.releaseSnapshot(forged, access.guard()));
    try t.expectEqual(@as(u64, 1), table.root.changed_lsn);
}

const UncertainLog = struct {
    base: s.TransitLog.Log,
    lose_next: bool = true,
    fn erased(context: *anyopaque) *UncertainLog {
        return @ptrCast(@alignCast(context));
    }
    fn append(context: *anyopaque, partition: u64, expected: ?u64, writer: u64, policy: u64, kind: s.TransitLog.FrameKind, payload: []const u8) !s.TransitLog.AppendReceipt {
        const self = erased(context);
        const receipt = try self.base.append(partition, expected, writer, policy, kind, payload);
        if (self.lose_next) {
            self.lose_next = false;
            return error.StorageOutcomeUnknown;
        }
        return receipt;
    }
    fn read(context: *anyopaque, allocator: std.mem.Allocator, partition: u64, from: u64, count: usize) !s.TransitLog.Log.OwnedBatch {
        return erased(context).base.read(allocator, partition, from, count);
    }
    fn tail(context: *anyopaque, partition: u64) !u64 {
        return erased(context).base.tail(partition);
    }
    fn trim(context: *anyopaque, partition: u64, to: u64) !void {
        return erased(context).base.trim(partition, to);
    }
    fn fence(context: *anyopaque, partition: u64, writer: u64, policy: u64) !void {
        return erased(context).base.fence(partition, writer, policy);
    }
    fn log(self: *UncertainLog) s.TransitLog.Log {
        return .{ .context = self, .vtable = &.{ .append = append, .read = read, .tail = tail, .trim = trim, .fence = fence } };
    }
};

test "an uncertain storage append blocks Table observations until recovery and exact retry" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var uncertain: UncertainLog = .{ .base = wal.log() };
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try P.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, uncertain.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    var access: Access = .{};
    const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    const original = binding(&table, 1);
    try t.expectError(error.StorageOutcomeUnknown, table.apply(original, &.{change(&cell, 1)}, .point, access.guard()));
    try t.expectError(error.TableRecoveryRequired, table.observe(original, access.guard()));
    try t.expectError(error.TableRecoveryRequired, table.flush(access.guard()));
    try table.recover();
    try t.expectEqual(@as(u64, 1), (try table.apply(original, &.{change(&cell, 1)}, .point, access.guard())).affected);
    try t.expectEqual(@as(u64, 1), try wal.log().tail(17));
}

test "competing Table roots cannot publish a partial statement or replace the winner" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var first = try owner(&wal, &objects);
    defer first.deinit();
    var access: Access = .{};
    _ = try first.apply(binding(&first, 9), &.{}, .point, access.guard());
    var second = try owner(&wal, &objects);
    defer second.deinit();
    const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    const first_request = binding(&first, 1);
    var second_request = binding(&second, 2);
    second_request.expected_data = .{ .partition = 17, .next_lsn = 1 };
    _ = try first.apply(first_request, &.{change(&cell, 1)}, .point, access.guard());
    try t.expectError(error.WalLsnConflict, second.apply(second_request, &.{change(&cell, 2)}, .bulk, access.guard()));
    try second.recover();
    try t.expect((try second.observe(second_request, access.guard())) == null);
    try t.expectEqual(@as(u64, 1), (try second.observe(first_request, access.guard())).?.affected);
    try t.expectError(error.TableDataChanged, second.apply(second_request, &.{change(&cell, 2)}, .point, access.guard()));
    try t.expectEqual(@as(u64, 1), second.root.live_rows);
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try P.init(allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    var access: Access = .{};
    const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    _ = table.apply(binding(&table, 1), &.{change(&cell, 1)}, .point, access.guard()) catch |err| {
        try t.expectEqual(@as(u64, 0), try wal.log().tail(17));
        try t.expectEqual(@as(u64, 0), table.root.live_rows);
        return err;
    };
    try t.expectEqual(@as(u64, 1), try wal.log().tail(17));
    try t.expectEqual(@as(u64, 1), table.root.live_rows);
}

test "disk checkpoint races preserve original pins and cannot resurrect a released owner" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    const first_owner: p.DataLifecycle.Operation = .{ .scope = object.scope, .principal = 4, .operation = 100 };
    var second_owner = first_owner;
    second_owner.operation = 101;
    var first_pin: P.SnapshotHandle = undefined;
    var second_pin: P.SnapshotHandle = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        const one: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
        _ = try table.apply(binding(&table, 1), &.{change(&one, 1)}, .point, access.guard());
        var maintenance = try owner(&wal, &objects);
        defer maintenance.deinit();
        const original: p.DataLifecycle.Position = .{ .partition = 17, .next_lsn = table.root.next_lsn };

        // Acquisition wins, but the caller loses its acknowledgement. A stale
        // checkpoint must not publish the root that predates this obligation.
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.pin(first_owner, original, access.guard()));
        table.lose_reply = false;
        first_pin = (try table.pinState(first_owner, access.guard())).handle.?;
        try t.expectError(error.WalLsnConflict, maintenance.flush(access.guard()));
        try maintenance.recover();
        try t.expectEqual(@as(usize, 1), try maintenance.flush(access.guard()));
        try table.recover();
        try t.expectEqualDeep(first_pin, try table.pin(first_owner, original, access.guard()));
        var bytes: [4096]u8 = undefined;
        var retained = (try table.readSnapshot(t.allocator, first_pin, try key(1, &bytes), access.guard())).?;
        defer retained.deinit();
        try t.expect(retained == .wal);
        try t.expectEqual(@as(i128, 1), retained.row().cells[0].value.atom.signed);

        // Reverse the order. Staged snapshot bytes are not an accepted pin,
        // and exact recovery cannot silently substitute the checkpoint's cut.
        const two: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 2 } } };
        _ = try table.apply(binding(&table, 2), &.{change(&two, 2)}, .point, access.guard());
        const before_flush: p.DataLifecycle.Position = .{ .partition = 17, .next_lsn = table.root.next_lsn };
        try maintenance.recover();
        try t.expectEqual(@as(usize, 1), try maintenance.flush(access.guard()));
        try t.expectError(error.WalLsnConflict, table.pin(second_owner, before_flush, access.guard()));
        try table.recover();
        try t.expect((try table.pinState(second_owner, access.guard())).handle == null);
        try t.expectError(error.TableDataChanged, table.pin(second_owner, before_flush, access.guard()));

        // A stale checkpoint cannot resurrect a released pin either.
        const three: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 3 } } };
        _ = try table.apply(binding(&table, 3), &.{change(&three, 3)}, .point, access.guard());
        try maintenance.recover();
        try table.releaseSnapshot(first_pin, access.guard());
        try t.expectError(error.WalLsnConflict, maintenance.flush(access.guard()));
        try maintenance.recover();
        _ = try maintenance.flush(access.guard());
        try table.recover();
        try t.expect((try table.pinState(first_owner, access.guard())).released);

        // If the checkpoint wins, release remains recoverable under the same
        // owner. Losing that release reply must not resurrect it on disk reopen.
        second_pin = try table.pin(second_owner, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
        const four: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 4 } } };
        _ = try table.apply(binding(&table, 4), &.{change(&four, 4)}, .point, access.guard());
        try maintenance.recover();
        _ = try maintenance.flush(access.guard());
        try t.expectError(error.WalLsnConflict, table.releaseSnapshot(second_pin, access.guard()));
        try table.recover();
        try t.expect(!(try table.pinState(second_owner, access.guard())).released);
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.releaseSnapshot(second_pin, access.guard()));
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var recovered = try owner(&wal, &objects);
    defer recovered.deinit();
    const position = recovered.root.next_lsn;
    for ([_]P.SnapshotHandle{ first_pin, second_pin }) |handle| {
        try t.expect((try recovered.pinState(handle.owner, access.guard())).released);
        try recovered.releaseSnapshot(handle, access.guard());
        var bytes: [4096]u8 = undefined;
        try t.expectError(error.TableSnapshotReleased, recovered.readSnapshot(t.allocator, handle, try key(1, &bytes), access.guard()));
    }
    try t.expectEqual(position, recovered.root.next_lsn);
    try t.expectEqual(@as(u64, 4), recovered.root.live_rows);
}

test "Table acceptance has no fallible visibility allocation after its durable append" {
    try t.checkAllAllocationFailures(t.allocator, allocationCase, .{});
}

fn ddlBinding(table: *P, operation: u64, action: p.DataLifecycle.Action) p.DataLifecycle.Binding {
    var result = binding(table, operation);
    result.action = action;
    result.expected_data = .{ .partition = 17, .next_lsn = table.root.next_lsn };
    return result;
}

test "Table rename ALTER and DROP preserve exact receipts and pinned original interpretation on disk" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var original: p.DataLifecycle.Binding = undefined;
    var rename: p.DataLifecycle.Binding = undefined;
    var alter: p.DataLifecycle.Binding = undefined;
    var drop: p.DataLifecycle.Binding = undefined;
    var old_pin: P.SnapshotHandle = undefined;
    var renamed_pin: P.SnapshotHandle = undefined;
    const edit: P.Edit = .{ .alter = .{ .change = .{ .add = .{ .name = "quantity", .type = .int64, .nullable = false, .default = .{ .value = .{ .atom = .{ .signed = 42 } } } } }, .properties = "renamed" } };
    const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    var storage_key: [f.Collation.max_sort_key_bytes]u8 = undefined;
    const row_key = try key(1, &storage_key);
    var access: Access = .{};
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        original = binding(&table, 1);
        _ = try table.apply(original, &.{change(&cell, 1)}, .point, access.guard());
        old_pin = try table.pin(.{ .scope = object.scope, .principal = 4, .operation = 90 }, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
        rename = ddlBinding(&table, 2, .rename);
        const prior_rows = table.root.rows;
        const prior_schema = table.root.schema_fingerprint;
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.changeDefinition(rename, .{ .rename = "renamed" }, access.guard()));
        try t.expectEqualDeep(prior_rows, table.root.rows);
        try t.expectEqualDeep(prior_schema, table.root.schema_fingerprint);
        try t.expectEqualStrings("renamed", table.declaration.definition.properties);
        try t.expectEqual(@as(u64, 2), table.root.interpretation.revision);
        try t.expectEqual(@as(u64, 1), table.declaration.schema.schema.revision);
        table.lose_reply = false;
        const renamed_at = table.root.next_lsn;
        _ = try table.changeDefinition(rename, .{ .rename = "renamed" }, access.guard());
        try t.expectEqual(renamed_at, table.root.next_lsn);
        try t.expectError(error.DataIdentityConflict, table.changeDefinition(rename, .{ .rename = "different" }, access.guard()));
        var renamed_row = (try table.get(t.allocator, row_key, access.guard())).?;
        defer renamed_row.deinit();
        try t.expect(renamed_row == .wal);
        renamed_pin = try table.pin(.{ .scope = object.scope, .principal = 4, .operation = 91 }, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
        alter = ddlBinding(&table, 3, .alter);
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.changeDefinition(alter, edit, access.guard()));
        try t.expectEqual(@as(u64, 3), table.root.interpretation.revision);
        try t.expectEqual(@as(u64, 2), table.declaration.schema.schema.revision);
        table.lose_reply = false;
        var rewritten = (try table.get(t.allocator, row_key, access.guard())).?;
        defer rewritten.deinit();
        try t.expect(rewritten == .segment);
        try t.expectEqual(@as(i128, 42), rewritten.row().cells[1].value.atom.signed);
        _ = try table.changeDefinition(alter, edit, access.guard());
        // Retrying accepted data uses its original schema even after a rewrite.
        try t.expectEqual(@as(u64, 1), (try table.apply(original, &.{change(&cell, 1)}, .point, access.guard())).affected);
        drop = ddlBinding(&table, 4, .drop);
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.changeDefinition(drop, .{ .drop = "renamed" }, access.guard()));
        try t.expect(table.root.retired);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    // The opening template cannot substitute for the persisted declaration.
    var table = try owner(&wal, &objects);
    defer table.deinit();
    try t.expect(table.root.retired);
    try t.expectEqual(@as(u64, 4), table.root.interpretation.revision);
    try t.expectEqual(@as(u64, 2), table.declaration.schema.schema.revision);
    try t.expectEqualStrings("renamed", table.declaration.definition.properties);
    const end = table.root.next_lsn;
    _ = try table.changeDefinition(rename, .{ .rename = "renamed" }, access.guard());
    _ = try table.changeDefinition(alter, edit, access.guard());
    _ = try table.changeDefinition(drop, .{ .drop = "renamed" }, access.guard());
    _ = try table.apply(original, &.{change(&cell, 1)}, .point, access.guard());
    try t.expectEqual(end, table.root.next_lsn);
    const history = try table.history(.{ .partition = 17, .next_lsn = 0 }, .{ .partition = 17, .next_lsn = end }, 8, access.guard());
    try t.expectEqual(@as(u8, 4), history.count);
    try t.expectEqual(end, history.next.next_lsn);
    for (history.entries[0..history.count], 0..) |slot, i| {
        const entry = slot.?;
        try t.expectEqual(i + 1, entry.receipt.binding.identity.operation);
        try t.expectEqual(i + 1, entry.root.interpretation.revision);
        try t.expectEqual(i == 3, entry.root.retired);
        try t.expectEqual(entry.root.next_lsn, entry.root.changed_lsn);
    }
    try t.expectEqualDeep(history.entries[0].?.root.schema_fingerprint, history.entries[1].?.root.schema_fingerprint);
    try t.expect(!std.meta.eql(history.entries[1].?.root.schema_fingerprint, history.entries[2].?.root.schema_fingerprint));
    const accepted_rename = (try table.observeEvidence(rename, access.guard())).?;
    try t.expectEqual(@as(u64, 2), accepted_rename.resulting.interpretation.revision);
    try t.expect(!accepted_rename.resulting.retired);
    try t.expectEqualDeep(rename, accepted_rename.binding);
    try t.expectEqual(@as(u64, 1), (try table.observeEvidence(original, access.guard())).?.resulting.interpretation.revision);
    try t.expectError(error.TableRetired, table.get(t.allocator, row_key, access.guard()));
    try t.expectError(error.TableRetired, table.apply(binding(&table, 20), &.{change(&cell, 20)}, .point, access.guard()));
    for ([_]P.SnapshotHandle{ old_pin, renamed_pin }) |handle| {
        var pinned = (try table.readSnapshot(t.allocator, handle, row_key, access.guard())).?;
        defer pinned.deinit();
        try t.expectEqual(@as(usize, 1), pinned.row().cells.len);
        try t.expectEqual(@as(i128, 1), pinned.row().cells[0].value.atom.signed);
        try table.releaseSnapshot(handle, access.guard());
    }
    try table.recover();
    try t.expectError(error.TableSnapshotReleased, table.readSnapshot(t.allocator, old_pin, row_key, access.guard()));
}

test "Table ALTER streams more rows than a rewrite group and publishes no prefix on denial" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    var cells: [257]f.Types.Values.Cell = undefined;
    var changes: [257]P.Change = undefined;
    for (0..4) |batch| {
        for (&cells, &changes, 0..) |*cell, *mutation, i| {
            cell.* = .{ .value = .{ .atom = .{ .signed = @intCast(batch * cells.len + i) } } };
            mutation.* = change(cell, batch + 1);
            mutation.put.row.identity.ordinal = @intCast(i);
        }
        _ = try table.apply(binding(&table, batch + 1), &changes, .bulk, access.guard());
    }
    const before = table.root;
    const request = ddlBinding(&table, 10, .alter);
    const edit: P.Edit = .{ .alter = .{ .change = .{ .add = .{ .name = "note", .type = .utf8, .nullable = true } }, .properties = "expanded" } };
    access.deny_at = access.calls + 2;
    try t.expectError(error.PermissionDenied, table.changeDefinition(request, edit, access.guard()));
    try t.expectEqualDeep(before, table.root);
    access.deny_at = std.math.maxInt(usize);
    try t.expect((try table.observe(request, access.guard())) == null);
    _ = try table.changeDefinition(request, edit, access.guard());
    try t.expectEqual(before.next_lsn + 1, table.root.next_lsn);
    try t.expectEqual(before.next_segment + 2, table.root.next_segment);
    try t.expectEqual(@as(usize, 1), table.index.cache.len);
    try table.recover();
    var cursor: ?s.TreeStore.pages.Key = null;
    var count: usize = 0;
    while (true) {
        const batch = try table.scan(table.root, cursor);
        for (batch.entries) |slot| if (slot) |entry| {
            var row = try table.readRow(t.allocator, table.root, entry.key, entry.value);
            defer row.deinit();
            try t.expectEqual(@as(usize, 2), row.row().cells.len);
            try t.expect(row.row().cells[1] == .null);
            count += 1;
        };
        cursor = batch.next orelse break;
    }
    try t.expectEqual(@as(usize, 1028), count);
}

test "Table ALTER rejects duplicate collation keys without publishing schema or rows" {
    const text_schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "key", .type = .utf8, .nullable = false, .collation = .utf8_binary }}, .primary_key = &.{1} };
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try P.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = text_schema, .properties = "names" }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    var access: Access = .{};
    const values = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "A" } } }, .{ .value = .{ .atom = .{ .bytes = "a" } } } };
    var second = change(&values[1], 1);
    second.put.row.identity.ordinal = 1;
    _ = try table.apply(binding(&table, 1), &.{ change(&values[0], 1), second }, .point, access.guard());
    const before = table.root;
    const request = ddlBinding(&table, 2, .alter);
    try t.expectError(error.DuplicatePrimaryKey, table.changeDefinition(request, .{ .alter = .{ .change = .{ .physical = .{ .column = 1, .collation = .ascii_ci } }, .properties = "names" } }, access.guard()));
    try t.expectEqualDeep(before, table.root);
    try t.expect((try table.observe(request, access.guard())) == null);
    try table.recover();
    try t.expectEqualDeep(before, table.root);
}

test "Table recovery never substitutes its opening template for missing or incompatible declarations" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    _ = try table.apply(binding(&table, 1), &.{}, .point, access.guard());
    const stored = table.root.declared();
    const bytes = try t.allocator.dupe(u8, table.declaration.bytes);
    defer t.allocator.free(bytes);
    bytes[8] ^= 1;
    var foreign = stored;
    foreign.content.sha256 = r.hash(bytes);
    foreign.interpretation.digest = foreign.content.sha256;
    var name: [96]u8 = undefined;
    _ = try objects.objectStore().putImmutable(try s.TableDeclaration.key(foreign.content, &name), bytes, foreign.content.sha256);
    try t.expectError(error.IncompatibleDefinition, s.TableDeclaration.load(t.allocator, objects.objectStore(), foreign));
    const missing_fields = try std.json.Stringify.valueAlloc(t.allocator, .{ .interpretation = table.root.interpretation, .partition = table.root.partition }, .{});
    defer t.allocator.free(missing_fields);
    try t.expectError(error.MissingField, std.json.parseFromSlice(P.Root, t.allocator, missing_fields, .{}));
    const complete_root = try std.json.Stringify.valueAlloc(t.allocator, table.root, .{});
    defer t.allocator.free(complete_root);
    var fields = try std.json.parseFromSlice(std.json.Value, t.allocator, complete_root, .{});
    defer fields.deinit();
    try t.expect(fields.value.object.swapRemove("ordered_rows"));
    const without_ordered = try std.json.Stringify.valueAlloc(t.allocator, fields.value, .{});
    defer t.allocator.free(without_ordered);
    try t.expectError(error.MissingField, std.json.parseFromSlice(P.Root, t.allocator, without_ordered, .{}));
    try objects.objectStore().delete(try s.TableDeclaration.key(stored.content, &name));
    const before = table.root;
    try t.expectError(error.TableDeclarationMissing, table.recover());
    try t.expectEqualDeep(before, table.root);
    try t.expectEqual(@as(u64, 1), try wal.log().tail(17));
    try t.expectError(error.TableRecoveryRequired, table.observe(binding(&table, 2), access.guard()));
}

fn declarationAllocationCase(allocator: std.mem.Allocator) !void {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try P.init(allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "before" }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    var access: Access = .{};
    _ = try table.apply(binding(&table, 1), &.{}, .point, access.guard());
    const before = table.root;
    const request = ddlBinding(&table, 2, .rename);
    _ = table.changeDefinition(request, .{ .rename = "after" }, access.guard()) catch |err| {
        try t.expectEqualDeep(before, table.root);
        try t.expectEqual(@as(u64, 1), try wal.log().tail(17));
        try t.expectEqualStrings("before", table.declaration.definition.properties);
        return err;
    };
    try t.expectEqual(@as(u64, 2), try wal.log().tail(17));
    try t.expectEqualStrings("after", table.declaration.definition.properties);
}

test "Table definition acceptance makes no fallible visibility allocation after append" {
    try t.checkAllAllocationFailures(t.allocator, declarationAllocationCase, .{});
}

test "Table identity index rejects aliases without publishing partial rows" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    const cells = [_]f.Types.Values.Cell{
        .{ .value = .{ .atom = .{ .signed = 1 } } },
        .{ .value = .{ .atom = .{ .signed = 2 } } },
    };
    const before = table.root;
    for ([_]P.Ingestion{ .point, .bulk }) |ingestion| {
        try t.expectError(error.DuplicateTableRowIdentity, table.apply(binding(&table, 1), &.{ change(&cells[0], 1), change(&cells[1], 1) }, ingestion, access.guard()));
        try t.expectEqualDeep(before, table.root);
        try t.expectEqual(@as(u64, 0), try wal.log().tail(17));
    }
    _ = try table.apply(binding(&table, 1), &.{change(&cells[0], 1)}, .point, access.guard());
    const accepted = table.root;
    try t.expectError(error.DuplicateTableRowIdentity, table.apply(binding(&table, 2), &.{change(&cells[1], 1)}, .bulk, access.guard()));
    try t.expectEqualDeep(accepted, table.root);
    var unique = change(&cells[1], 1);
    unique.put.row.identity.ordinal = 1;
    _ = try table.apply(binding(&table, 2), &.{unique}, .bulk, access.guard());
    try table.recover();
    try t.expectEqual(@as(u64, 2), table.root.live_rows);
}

test "Table recovery refuses a missing ordered root before exposing accepted rows" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    _ = try table.apply(binding(&table, 1), &.{change(&cell, 1)}, .point, access.guard());
    const before = table.root;
    var name: [96]u8 = undefined;
    const address = try std.fmt.bufPrint(&name, "data-index/{x}.data", .{&before.ordered_rows.?.location});
    try objects.objectStore().delete(address);
    try t.expectError(error.MissingDataIndexObject, table.recover());
    try t.expectEqualDeep(before, table.root);
    var key_bytes: [4096]u8 = undefined;
    try t.expectError(error.TableRecoveryRequired, table.get(t.allocator, try key(1, &key_bytes), access.guard()));
    try t.expectEqual(@as(u64, 1), try wal.log().tail(17));
}

test "Table index batches share paths and reject duplicate identities across private flushes" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    var values: [64]f.Types.Values.Cell = undefined;
    var changes: [64]P.Change = undefined;
    for (&values, &changes, 0..) |*cell, *mutation, i| {
        cell.* = .{ .value = .{ .atom = .{ .signed = @intCast(i) } } };
        mutation.* = change(cell, i + 1);
    }
    const create = binding(&table, 1);
    table.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, table.apply(create, &changes, .point, access.guard()));
    const accepted = table.root;
    const batch_pages = table.index.staged_pages;
    const batch_bytes = table.index.staged_bytes;
    const receipt = (try table.observe(create, access.guard())).?;
    try t.expectEqual(@as(u64, 64), receipt.affected);
    try t.expectEqualDeep(receipt, try table.apply(create, &changes, .point, access.guard()));
    try t.expectEqual(batch_pages, table.index.staged_pages);
    try t.expectEqual(@as(u64, 1), try wal.log().tail(17));
    // Independent scalar staging control for the same accepted key/locator set.
    // Counters describe logical acknowledged index payloads, not physical writes.
    var control = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer control.deinit();
    try control.begin(16 * 1024 * 1024);
    defer control.end();
    const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &control };
    const ordered: s.OrderedKeyIndex = .{ .store = &control };
    var rows: ?s.TreeStore.pages.Reference = null;
    var identities: ?s.TreeStore.pages.Reference = null;
    var physical: ?s.TreeStore.pages.Reference = null;
    var keys: ?s.TreeStore.pages.Reference = null;
    var bytes: [4096]u8 = undefined;
    for (0..64) |i| {
        const storage_key = try key(@intCast(i), &bytes);
        var row = (try table.get(t.allocator, storage_key, access.guard())).?;
        defer row.deinit();
        try t.expectEqual(@as(i128, @intCast(i)), row.row().cells[0].value.atom.signed);
        try t.expectEqual(@as(u64, i + 1), row.row().identity.operation);
        const hash = try r.rowKey(storage_key);
        const locator_bytes = (try tree.get(accepted.rows, hash)).?;
        const locator = try r.Locator.decode(locator_bytes);
        rows = try tree.put(rows, hash, locator_bytes);
        identities = try tree.put(identities, try .init(&try row.row().identity.encode()), try .init(hash.data[0..32]));
        physical = try tree.put(physical, try locator.scanKey(), try locator.scanValue(hash));
        keys = try ordered.put(keys, storage_key, hash.data[0..32].*);
    }
    try t.expect(batch_pages * 2 < control.staged_pages);
    try t.expect(batch_bytes * 2 < control.staged_bytes);
    std.debug.print("Table index staging: {d}/{d} pages, {d}/{d} encoded bytes for one 64-row batch versus scalar index control (batch includes receipt)\n", .{ batch_pages, control.staged_pages, batch_bytes, control.staged_bytes });
    // Both a duplicate inside a buffer and one after its first flush must leave
    // all accepted roots, the WAL boundary and the original receipt unchanged.
    for ([_]usize{ 1, 9 }) |duplicate| {
        for (&values, &changes, 0..) |*cell, *mutation, i| {
            cell.* = .{ .value = .{ .atom = .{ .signed = @intCast(i + 1000) } } };
            mutation.* = change(cell, 1000 + if (i == duplicate) @as(usize, 0) else i);
        }
        try t.expectError(error.DuplicateTableRowIdentity, table.apply(binding(&table, 2), &changes, .point, access.guard()));
        try t.expectEqualDeep(accepted, table.root);
        try t.expectEqual(@as(u64, 1), try wal.log().tail(17));
        try table.recover();
        try t.expectEqualDeep(accepted, table.root);
        try t.expectEqualDeep(receipt, (try table.observe(create, access.guard())).?);
        try t.expect((try table.get(t.allocator, try key(1000, &bytes), access.guard())) == null);
    }
}
