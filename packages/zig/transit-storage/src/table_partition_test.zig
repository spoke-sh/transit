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
    var value = try P.init(t.allocator, object, 17, schema, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    errdefer value.deinit();
    try value.recover();
    return value;
}
fn binding(partition: *P, operation: u64) p.DataLifecycle.Binding {
    return .{ .definition = p.Growth.current_definition, .identity = .{ .scope = object.scope, .principal = 4, .operation = operation }, .target = object, .action = .insert, .expected_definition = partition.root.interpretation, .expected_data = null, .intent = @splat(7) };
}
fn change(value: *const f.Types.Values.Cell, operation: u64) P.Change {
    return .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = operation, .ordinal = 0 }, .cells = @as(*const [1]f.Types.Values.Cell, @ptrCast(value)) }, .expect = .absent } };
}
fn key(value: i128, buffer: []u8) ![]const u8 {
    return f.Collation.encodePrimaryKeySortKey(schema, &.{.{ .value = .{ .atom = .{ .signed = value } } }}, false, buffer);
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
    {
        var table = try owner(&wal, &objects);
        defer table.deinit();
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
    for (0..129) |i| try t.expectEqual(@as(u64, 1), (try table.observe(binding(&table, i + 1), access.guard())).?.affected);
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
    var table = try P.init(t.allocator, object, 17, wide, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
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
    var access: Access = .{ .deny_at = 2 };
    const identity: p.DataLifecycle.Operation = .{ .scope = object.scope, .principal = 4, .operation = 1 };
    const empty: p.DataLifecycle.Position = .{ .partition = 17, .next_lsn = 0 };
    try t.expectError(error.PermissionDenied, table.pin(identity, empty, access.guard()));
    try t.expectEqual(@as(u64, 0), table.root.next_lsn);
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
    try t.expectEqual(@as(u64, 0), table.root.changed_lsn);
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
    var table = try P.init(t.allocator, object, 17, schema, uncertain.log(), objects.objectStore(), .{ .resident_pages = 1 });
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
    var second = try owner(&wal, &objects);
    defer second.deinit();
    var access: Access = .{};
    const cell: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    const first_request = binding(&first, 1);
    var second_request = binding(&second, 2);
    second_request.expected_data = .{ .partition = 17, .next_lsn = 0 };
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
    var table = try P.init(allocator, object, 17, schema, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
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
