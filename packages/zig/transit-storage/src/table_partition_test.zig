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
        table.lose_reply = true;
        try t.expectError(error.LostAcknowledgement, table.pin(pin_owner, expected, access.guard()));
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    const handle = try table.pin(pin_owner, expected, access.guard());
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
    try t.expectError(error.PermissionDenied, table.readSnapshot(t.allocator, handle, row_key, access.guard()));
    try t.expectError(error.PermissionDenied, table.releaseSnapshot(handle, access.guard()));
    access.deny_at = std.math.maxInt(usize);
    try table.releaseSnapshot(handle, access.guard());
    const released_at = table.root.next_lsn;
    try table.recover();
    try table.releaseSnapshot(handle, access.guard());
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
    _ = try table.apply(binding(&table, 1), &.{ change(&values[0], 1), change(&values[1], 1) }, .point, access.guard());
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
