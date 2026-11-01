const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const f = @import("transit_fuze");
const P = s.TablePartition;
const columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "body", .type = .utf8, .nullable = false, .collation = .utf8_binary },
};
const object: d.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };
const definition: s.TableDeclaration.Definition = .{ .object = object, .revision = 1, .schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &columns, .primary_key = &.{1} }, .properties = "" };
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
    var result = try P.init(t.allocator, 17, definition, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    errdefer result.deinit();
    try result.recover();
    return result;
}
fn binding(table: *P, id: u64, action: d.Action) d.Binding {
    return .{ .definition = p.Growth.current_definition, .identity = .{ .scope = object.scope, .principal = 4, .operation = id }, .target = object, .action = action, .expected_definition = if (action == .create) null else table.root.interpretation, .expected_data = null, .intent = @splat(7) };
}
fn pin(table: *P, id: u64, access: *Access) !P.SnapshotHandle {
    return table.pin(.{ .scope = object.scope, .principal = 4, .operation = id }, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
}

test "projected Table snapshots skip segment payloads and bind cursors without changing row coverage" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    const payload: [16 * 1024]u8 = @splat('x');
    var cells: [16][2]f.Types.Values.Cell = undefined;
    var changes: [16]P.Change = undefined;
    for (&cells, &changes, 0..) |*values, *change, i| {
        values.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(i) } } }, .{ .value = .{ .atom = .{ .bytes = &payload } } } };
        change.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = @intCast(i) }, .cells = values } } };
    }
    _ = try table.apply(binding(&table, 1, .create), &changes, .bulk, access.guard());
    const last = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 16 } } }, .{ .value = .{ .atom = .{ .bytes = &payload } } } };
    _ = try table.apply(binding(&table, 2, .insert), &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 2, .ordinal = 0 }, .cells = &last } } }}, .point, access.guard());
    const handle = try pin(&table, 80, &access);
    const accepted = table.root;
    table.options.segment_decode_bytes = 8 * 1024;
    var first = try table.scanSnapshotColumns(t.allocator, handle, &.{0}, null, .{ .rows = 2 }, access.guard());
    defer first.deinit();
    try t.expectEqual(@as(u8, 2), first.count);
    try t.expectEqual(@as(u64, 17), first.total_rows);
    try t.expect(first.next != null);
    try t.expectEqual(@as(usize, 1), first.rows[0].?.row().cells.len);
    try t.expectEqual(@as(i128, 0), first.rows[0].?.row().cells[0].value.atom.signed);
    const projected_bytes = table.segment_bytes_read;
    try t.expect(projected_bytes < payload.len);
    try t.expectError(error.InvalidProjection, table.scanSnapshotColumns(t.allocator, handle, &.{1}, null, .{}, access.guard()));
    try t.expectError(error.InvalidTableSnapshotCursor, table.scanSnapshotColumns(t.allocator, handle, &.{ 0, 1 }, first.next, .{}, access.guard()));
    try t.expectError(error.InvalidTableSnapshotCursor, table.scanSnapshot(t.allocator, handle, first.next, .{}, access.guard()));
    // Switching projection cannot reuse incomplete metadata. Failed construction
    // must leave no published cache owner; retry can borrow the wide payloads.
    table.options.segment_decode_bytes = 1;
    try t.expectError(error.SegmentReadBudgetExceeded, table.scanSnapshot(t.allocator, handle, null, .{}, access.guard()));
    try t.expect(table.segment_cache.?.decoded == null);
    table.options.segment_decode_bytes = 8 * 1024;
    var full = try table.scanSnapshot(t.allocator, handle, null, .{ .rows = 1 }, access.guard());
    defer full.deinit();
    try t.expectEqualStrings(&payload, full.rows[0].?.row().cells[1].value.atom.bytes);
    try t.expect(table.segment_cache.?.decoded.? == .buffered);
    try t.expect(table.segment_cache.?.decoded.?.view().peakAllocatedBytes() <= 8 * 1024);
    try t.expect(table.segment_cache.?.decoded.?.buffered.encoded.allocatedBytes() > payload.len);
    var after = first.next;
    var count: u64 = first.count;
    while (after != null) {
        var page = try table.scanSnapshotColumns(t.allocator, handle, &.{0}, after, .{}, access.guard());
        defer page.deinit();
        for (page.rows[0..page.count]) |slot| {
            try t.expectEqual(@as(usize, 1), slot.?.row().cells.len);
            try t.expectEqual(@as(i128, @intCast(count)), slot.?.row().cells[0].value.atom.signed);
            count += 1;
        }
        after = page.next;
    }
    try t.expectEqual(@as(u64, 17), count);
    try t.expectEqualDeep(accepted, table.root);
    // Output owns its cells independently of all later cache replacement.
    try t.expectEqual(@as(i128, 1), first.rows[1].?.row().cells[0].value.atom.signed);
    access.deny_at = access.calls + 3;
    try t.expectError(error.PermissionDenied, table.scanSnapshotColumns(t.allocator, handle, &.{0}, null, .{}, access.guard()));
    access.deny_at = std.math.maxInt(usize);
    // The wide output also survives replacement by the narrow projected cache.
    try t.expectEqualStrings(&payload, full.rows[0].?.row().cells[1].value.atom.bytes);
}

test "retained Table key ranges preserve exact intervals through writes flush rewrite and restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var handle: P.SnapshotHandle = undefined;
    var retained: P.KeyRangePage = undefined;
    var lower_bytes: [4096]u8 = undefined;
    var upper_bytes: [4096]u8 = undefined;
    const range: P.KeyRange = .{
        .lower = .{ .key = try f.Collation.encodePrimaryKeySortKey(definition.schema, &.{.{ .value = .{ .atom = .{ .signed = 5 } } }}, false, &lower_bytes) },
        .upper = .{ .key = try f.Collation.encodePrimaryKeySortKey(definition.schema, &.{.{ .value = .{ .atom = .{ .signed = 21 } } }}, false, &upper_bytes), .inclusive = false },
    };
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        var cells: [25][2]f.Types.Values.Cell = undefined;
        var changes: [25]P.Change = undefined;
        for (&cells, &changes, 0..) |*values, *change, i| {
            values.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(24 - i) } } }, .{ .value = .{ .atom = .{ .bytes = "original" } } } };
            change.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = @intCast(i) }, .cells = values }, .expect = .absent } };
        }
        _ = try table.apply(binding(&table, 1, .create), changes[0..12], .bulk, access.guard());
        _ = try table.apply(binding(&table, 2, .insert), changes[12..], .point, access.guard());
        handle = try pin(&table, 80, &access);
        retained = try table.rangeSnapshot(t.allocator, handle, range, null, .{ .rows = 3 }, access.guard());
        errdefer retained.deinit();
        try t.expectEqual(@as(u8, 3), retained.count);
        for (retained.rows[0..retained.count], 0..) |row, i| try t.expectEqual(@as(i128, @intCast(5 + i)), row.?.row().cells[0].value.atom.signed);
        try t.expect(retained.next != null);
        var changed_range = range;
        changed_range.lower.?.inclusive = false;
        try t.expectError(error.InvalidTableSnapshotCursor, table.rangeSnapshot(t.allocator, handle, changed_range, retained.next, .{}, access.guard()));
        try t.expectError(error.TableReadBudgetTooSmall, table.rangeSnapshot(t.allocator, handle, range, null, .{ .encoded_bytes = 1 }, access.guard()));
        access.deny_at = access.calls + 3;
        try t.expectError(error.PermissionDenied, table.rangeSnapshot(t.allocator, handle, range, null, .{}, access.guard()));
        access.deny_at = std.math.maxInt(usize);
        const ordered_root = table.root.ordered_rows;
        _ = try table.flush(access.guard());
        try t.expectEqualDeep(ordered_root, table.root.ordered_rows);
        const later = try pin(&table, 81, &access);
        try t.expectError(error.InvalidTableSnapshotCursor, table.rangeSnapshot(t.allocator, later, range, retained.next, .{}, access.guard()));
        var deleted_key: [4096]u8 = undefined;
        const key = try f.Collation.encodePrimaryKeySortKey(definition.schema, &.{.{ .value = .{ .atom = .{ .signed = 10 } } }}, false, &deleted_key);
        _ = try table.apply(binding(&table, 3, .delete), &.{.{ .remove = key }}, .point, access.guard());
        _ = try table.changeDefinition(binding(&table, 4, .alter), .{ .alter = .{ .change = .{ .add = .{ .name = "extra", .type = .int64, .nullable = false, .default = .{ .value = .{ .atom = .{ .signed = 42 } } } } }, .properties = "" } }, access.guard());
        const current = try pin(&table, 82, &access);
        var page = try table.rangeSnapshot(t.allocator, current, range, null, .{}, access.guard());
        defer page.deinit();
        for (page.rows[0..page.count]) |row| {
            try t.expect(row.?.row().cells[0].value.atom.signed != 10);
            try t.expectEqual(@as(usize, 3), row.?.row().cells.len);
        }
        _ = try table.changeDefinition(binding(&table, 5, .drop), .{ .drop = "" }, access.guard());
    }
    defer retained.deinit();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var after = retained.next;
    var count: usize = retained.count;
    while (after != null) {
        var page = try table.rangeSnapshot(t.allocator, handle, range, after, .{ .rows = 2 }, access.guard());
        defer page.deinit();
        try t.expectEqualDeep(retained.accepted, page.accepted);
        for (page.rows[0..page.count]) |row| {
            try t.expectEqual(@as(i128, @intCast(5 + count)), row.?.row().cells[0].value.atom.signed);
            try t.expectEqual(@as(usize, 2), row.?.row().cells.len);
            try t.expectEqualStrings("original", row.?.row().cells[1].value.atom.bytes);
            count += 1;
        }
        after = page.next;
    }
    try t.expectEqual(@as(usize, 16), count);
    const empty: P.KeyRange = .{ .lower = range.upper, .upper = range.lower };
    access.deny_at = access.calls + 3;
    try t.expectError(error.PermissionDenied, table.rangeSnapshot(t.allocator, handle, empty, null, .{}, access.guard()));
    access.deny_at = std.math.maxInt(usize);
    var zero = try table.rangeSnapshot(t.allocator, handle, empty, null, .{}, access.guard());
    defer zero.deinit();
    try t.expectEqual(@as(u8, 0), zero.count);
    try t.expect(zero.next == null);
    try table.releaseSnapshot(handle, access.guard());
    try t.expectError(error.TableSnapshotReleased, table.rangeSnapshot(t.allocator, handle, range, null, .{}, access.guard()));
}

test "retained Table key ranges skip unrelated disk segments against a complete same-cut scan" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var handle: P.SnapshotHandle = undefined;
    const body: [2048]u8 = @splat('s');
    const segments = 8;
    const rows_per_segment = 64;
    const first = 4 * rows_per_segment - 2;
    const end = first + 4;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        var cells: [rows_per_segment][2]f.Types.Values.Cell = undefined;
        var changes: [rows_per_segment]P.Change = undefined;
        for (0..segments) |segment| {
            for (&cells, &changes, 0..) |*values, *change, i| {
                values.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(segment * rows_per_segment + i) } } }, .{ .value = .{ .atom = .{ .bytes = &body } } } };
                // Identity order deliberately disagrees with key order within
                // each segment. The scan control must establish values itself.
                change.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = segment + 1, .ordinal = @intCast(rows_per_segment - i - 1) }, .cells = values }, .expect = .absent } };
            }
            _ = try table.apply(binding(&table, segment + 1, if (segment == 0) .create else .insert), &changes, .bulk, access.guard());
        }
        handle = try pin(&table, 80, &access);
    }

    var range_bytes: u64 = 0;
    var range_reads: u64 = 0;
    var range_index: u64 = 0;
    var scan_bytes: u64 = 0;
    var scan_reads: u64 = 0;
    var scan_index: u64 = 0;
    // Each arm starts with newly opened disk owners, one resident index page,
    // and an empty segment cache. The durable source is exactly the same pin.
    for ([_]bool{ true, false }) |ordered| {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        table.index.clearCache();
        try t.expect(table.segment_cache == null);
        try t.expectEqual(@as(usize, 1), table.index.cache.len);
        const index_before = table.index.misses;
        var selected: [4]bool = @splat(false);
        var count: usize = 0;
        if (ordered) {
            var lower: [4096]u8 = undefined;
            var upper: [4096]u8 = undefined;
            const interval: P.KeyRange = .{
                .lower = .{ .key = try f.Collation.encodePrimaryKeySortKey(definition.schema, &.{.{ .value = .{ .atom = .{ .signed = first } } }}, false, &lower) },
                .upper = .{ .key = try f.Collation.encodePrimaryKeySortKey(definition.schema, &.{.{ .value = .{ .atom = .{ .signed = end } } }}, false, &upper), .inclusive = false },
            };
            var after: ?P.KeyRange.Cursor = null;
            while (true) {
                var page = try table.rangeSnapshot(t.allocator, handle, interval, after, .{ .rows = 2 }, access.guard());
                defer page.deinit();
                try t.expectEqual(@as(u8, 2), page.count);
                for (page.rows[0..page.count]) |slot| {
                    const row = slot.?.row();
                    try t.expectEqual(@as(i128, @intCast(first + count)), row.cells[0].value.atom.signed);
                    try t.expectEqualStrings(&body, row.cells[1].value.atom.bytes);
                    selected[count] = true;
                    count += 1;
                }
                after = page.next orelse break;
            }
            try t.expectEqual(@as(usize, 4), count);
            try t.expectEqual(@as(u64, 2), table.segment_reads);
            try t.expectEqual(@as(u64, 2), table.row_groups_decoded);
            range_bytes = table.segment_bytes_read;
            range_reads = table.segment_range_reads;
            range_index = table.index.misses - index_before;
        } else {
            var after: ?P.SnapshotCursor = null;
            while (true) {
                var page = try table.scanSnapshot(t.allocator, handle, after, .{}, access.guard());
                defer page.deinit();
                for (page.rows[0..page.count]) |slot| {
                    const row = slot.?.row();
                    const expected = (row.identity.operation - 1) * rows_per_segment + rows_per_segment - row.identity.ordinal - 1;
                    try t.expectEqual(@as(i128, @intCast(expected)), row.cells[0].value.atom.signed);
                    try t.expectEqualStrings(&body, row.cells[1].value.atom.bytes);
                    if (expected >= first and expected < end) {
                        try t.expect(!selected[expected - first]);
                        selected[expected - first] = true;
                    }
                    count += 1;
                }
                after = page.next orelse break;
            }
            try t.expectEqual(@as(usize, segments * rows_per_segment), count);
            try t.expectEqual(@as(u64, segments), table.segment_reads);
            try t.expectEqual(@as(u64, segments), table.row_groups_decoded);
            scan_bytes = table.segment_bytes_read;
            scan_reads = table.segment_range_reads;
            scan_index = table.index.misses - index_before;
        }
        try t.expect(std.mem.allEqual(bool, &selected, true));
        try t.expect(table.segment_cache.?.decoded.?.view().allocatedBytes() < 1024 * 1024);
    }
    try t.expect(range_bytes * 3 < scan_bytes);
    try t.expect(range_reads * 3 < scan_reads);
    try t.expect(range_index * 3 < scan_index);
    std.debug.print("Retained cross-segment interval: 4/512 rows, 2/8 segments, range/scan bytes={d}/{d}, ranges={d}/{d}, index_misses={d}/{d}; separate cold owners, one index page\n", .{ range_bytes, scan_bytes, range_reads, scan_reads, range_index, scan_index });
}

test "pinned Table pages retain mixed WAL and segment rows across schema rewrite DROP and disk reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var handle: P.SnapshotHandle = undefined;
    var retained: P.SnapshotPage = undefined;
    const body: [2048]u8 = @splat('a');
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        var cells: [13][2]f.Types.Values.Cell = undefined;
        var changes: [13]P.Change = undefined;
        for (&cells, &changes, 0..) |*values, *change, i| {
            values.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(i) } } }, .{ .value = .{ .atom = .{ .bytes = &body } } } };
            change.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = @intCast(i) }, .cells = values }, .expect = .absent } };
        }
        _ = try table.apply(binding(&table, 1, .create), changes[0..7], .bulk, access.guard());
        _ = try table.apply(binding(&table, 2, .insert), changes[7..], .point, access.guard());
        handle = try pin(&table, 80, &access);
        retained = try table.scanSnapshot(t.allocator, handle, null, .{ .rows = 3 }, access.guard());
        errdefer retained.deinit();
        try t.expectEqual(@as(u8, 3), retained.count);
        try t.expectEqual(@as(u64, 13), retained.total_rows);
        try t.expect(retained.next != null);
        for (retained.rows[0..retained.count], 0..) |row, i| try t.expectEqual(i, row.?.row().identity.ordinal);
        // A new pin over later physical state cannot consume this cursor.
        const identity_root = table.root.identities;
        _ = try table.flush(access.guard());
        try t.expectEqualDeep(identity_root, table.root.identities);
        const later = try pin(&table, 81, &access);
        var ordered = try table.scanSnapshot(t.allocator, later, null, .{}, access.guard());
        defer ordered.deinit();
        for (ordered.rows[0..ordered.count], 0..) |row, i| try t.expectEqual(i, row.?.row().identity.ordinal);
        try t.expectError(error.InvalidTableSnapshotCursor, table.scanSnapshot(t.allocator, later, retained.next, .{}, access.guard()));
        _ = try table.changeDefinition(binding(&table, 3, .alter), .{ .alter = .{ .change = .{ .add = .{ .name = "extra", .type = .int64, .nullable = false, .default = .{ .value = .{ .atom = .{ .signed = 42 } } } } }, .properties = "" } }, access.guard());
        const rewritten = try pin(&table, 82, &access);
        var reshaped = try table.scanSnapshot(t.allocator, rewritten, null, .{}, access.guard());
        defer reshaped.deinit();
        for (reshaped.rows[0..reshaped.count], 0..) |row, i| {
            try t.expectEqual(i, row.?.row().identity.ordinal);
            try t.expectEqual(@as(usize, 3), row.?.row().cells.len);
        }
        _ = try table.changeDefinition(binding(&table, 4, .drop), .{ .drop = "" }, access.guard());
    }
    defer retained.deinit();
    // Returned variable-length cells own their memory beyond owner/cache lifetime.
    for (retained.rows[0..retained.count]) |row| try t.expectEqualStrings(&body, row.?.row().cells[1].value.atom.bytes);
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var description = try table.inspectSnapshot(t.allocator, handle, access.guard());
    defer description.deinit();
    try t.expectEqual(@as(usize, 2), description.schema.schema.columns.len);
    try t.expectEqualDeep(retained.interpretation, description.root.declared());
    var after = retained.next;
    var count: u64 = retained.count;
    var seen: [13]bool = @splat(false);
    for (retained.rows[0..retained.count]) |row| seen[@intCast(row.?.row().cells[0].value.atom.signed)] = true;
    while (after != null) {
        var page = try table.scanSnapshot(t.allocator, handle, after, .{ .rows = 2, .encoded_bytes = 4096 }, access.guard());
        defer page.deinit();
        try t.expectEqual(@as(u8, 1), page.count);
        try t.expectEqualDeep(retained.accepted, page.accepted);
        for (page.rows[0..page.count]) |row| {
            try t.expectEqual(count, row.?.row().identity.ordinal);
            const id: usize = @intCast(row.?.row().cells[0].value.atom.signed);
            try t.expect(!seen[id]);
            seen[id] = true;
            try t.expectEqual(@as(usize, 2), row.?.row().cells.len);
            try t.expectEqualStrings(&body, row.?.row().cells[1].value.atom.bytes);
        }
        count += page.count;
        after = page.next;
    }
    try t.expectEqual(@as(u64, 13), count);
    try t.expect(std.mem.allEqual(bool, &seen, true));
    try table.releaseSnapshot(handle, access.guard());
    try t.expectError(error.TableSnapshotReleased, table.scanSnapshot(t.allocator, handle, null, .{}, access.guard()));
}

test "Table snapshot pages enforce byte budgets and recheck rights after buffering and empty completion" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    _ = try table.apply(binding(&table, 1, .create), &.{}, .point, access.guard());
    const empty = try pin(&table, 80, &access);
    const before = table.root;
    access.deny_at = access.calls + 3;
    try t.expectError(error.PermissionDenied, table.scanSnapshot(t.allocator, empty, null, .{}, access.guard()));
    access.deny_at = std.math.maxInt(usize);
    var zero = try table.scanSnapshot(t.allocator, empty, null, .{}, access.guard());
    defer zero.deinit();
    try t.expectEqual(@as(u8, 0), zero.count);
    try t.expect(zero.next == null);
    try t.expectEqual(@as(u64, 0), zero.total_rows);
    try t.expectEqualDeep(before, table.root);
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .bytes = "retained" } } } };
    _ = try table.apply(binding(&table, 2, .insert), &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 2, .ordinal = 0 }, .cells = &cells }, .expect = .absent } }}, .point, access.guard());
    const handle = try pin(&table, 81, &access);
    try t.expectError(error.TableReadBudgetTooSmall, table.scanSnapshot(t.allocator, handle, null, .{ .encoded_bytes = 1 }, access.guard()));
    access.deny_at = access.calls + 3;
    try t.expectError(error.PermissionDenied, table.scanSnapshot(t.allocator, handle, null, .{}, access.guard()));
    access.deny_at = std.math.maxInt(usize);
    var forged: P.SnapshotCursor = .{ .source = handle.content, .after = @splat(0) };
    try t.expectError(error.InvalidTableSnapshotCursor, table.scanSnapshot(t.allocator, handle, forged, .{}, access.guard()));
    forged.source = empty.content;
    try t.expectError(error.InvalidTableSnapshotCursor, table.scanSnapshot(t.allocator, handle, forged, .{}, access.guard()));
    // The caller's page allocation budget is independent of the maximum wire
    // row size. Counting bytes must not reserve a maximum-sized row buffer.
    var output: f.MemoryBudget = .{ .parent = t.allocator, .limit = 128 * 1024 };
    var page = try table.scanSnapshot(output.allocator(), handle, null, .{}, access.guard());
    defer page.deinit();
    var encoded: [4096]u8 = undefined;
    const exact_bytes = (try page.rows[0].?.row().encode(definition.schema, &encoded)).len;
    try t.expectEqual(exact_bytes, page.encoded_bytes);
    var ranged = try table.rangeSnapshot(output.allocator(), handle, .{}, null, .{ .encoded_bytes = @intCast(exact_bytes) }, access.guard());
    defer ranged.deinit();
    try t.expectEqual(1, ranged.count);
    try t.expectEqual(exact_bytes, ranged.encoded_bytes);
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const plan: f.LogicalQuery.Plan = .{ .schema = try definition.schema.rowType(&fields), .source_basis = @splat(3), .collations = .fromTable(definition.schema), .projection = &.{ 0, 1 } };
    var filtered = try table.scanSnapshotFiltered(output.allocator(), handle, plan, null, .{ .encoded_bytes = @intCast(exact_bytes) }, access.guard());
    defer filtered.deinit();
    try t.expectEqual(1, filtered.page.count);
    try t.expectEqual(exact_bytes, filtered.page.encoded_bytes);
}

test "Table page rows survive independent release scratch reuse cache eviction and owner close" {
    // Exercise both cached views and temporary groups, followed by WAL rows.
    for ([_]usize{ 0, 128 * 1024 }) |cache_bytes| {
        var output: f.memory.AllocationProbe = .{ .parent = t.allocator };
        var retained: ?P.OwnedRow = null;
        defer if (retained) |*row| row.deinit();
        {
            var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
            defer wal.deinit();
            var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
            defer objects.deinit();
            var table = try owner(&wal, &objects);
            defer table.deinit();
            table.options.segment_cache_bytes = cache_bytes;
            var access: Access = .{};
            var payloads: [16][64]u8 = undefined;
            var cells: [16][2]f.Types.Values.Cell = undefined;
            var changes: [16]P.Change = undefined;
            for (&payloads, &cells, &changes, 0..) |*payload, *values, *change, i| {
                @memset(payload, @as(u8, @intCast('a' + i)));
                values.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(i) } } }, .{ .value = .{ .atom = .{ .bytes = payload } } } };
                change.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1 + i / 8, .ordinal = @intCast(i % 8) }, .cells = values } } };
            }
            _ = try table.apply(binding(&table, 1, .create), changes[0..8], .bulk, access.guard());
            _ = try table.apply(binding(&table, 2, .insert), changes[8..16], .point, access.guard());
            const handle = try pin(&table, 80, &access);
            const Case = struct {
                fn failures(allocator: std.mem.Allocator, source: *P, snapshot: P.SnapshotHandle) !void {
                    // Stable failure ordinals even when the heap can otherwise
                    // grow a scratch/output arena in place.
                    var vtable = allocator.vtable.*;
                    vtable.resize = std.mem.Allocator.noResize;
                    vtable.remap = std.mem.Allocator.noRemap;
                    const a: std.mem.Allocator = .{ .ptr = allocator.ptr, .vtable = &vtable };
                    var allow: Access = .{};
                    const before = source.root;
                    defer t.expectEqualDeep(before, source.root) catch unreachable;
                    var first = try source.scanSnapshot(a, snapshot, null, .{}, allow.guard());
                    defer first.deinit();
                    var last = try source.scanSnapshot(a, snapshot, first.next, .{}, allow.guard());
                    defer last.deinit();
                    var range = try source.rangeSnapshot(a, snapshot, .{}, null, .{}, allow.guard());
                    defer range.deinit();
                    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
                    const plan: f.LogicalQuery.Plan = .{ .schema = try definition.schema.rowType(&fields), .source_basis = @splat(3), .collations = .fromTable(definition.schema), .projection = &.{ 0, 1 } };
                    var filtered = try source.scanSnapshotFiltered(a, snapshot, plan, null, .{}, allow.guard());
                    defer filtered.deinit();
                    try t.expectEqual(@as(u8, 8), first.count);
                    try t.expectEqual(@as(u8, 8), last.count);
                    try t.expectEqual(@as(u8, 8), range.count);
                    try t.expectEqual(@as(u8, 8), filtered.page.count);
                }
            };
            try t.checkAllAllocationFailures(t.allocator, Case.failures, .{ &table, handle });
            const next = blk: {
                var first = try table.scanSnapshot(output.allocator(), handle, null, .{}, access.guard());
                defer first.deinit();
                try t.expectEqual(@as(u8, 8), first.count);
                retained = first.rows[0];
                first.rows[0] = null;
                var sibling = first.rows[1].?;
                first.rows[1] = null;
                // Deinit a sibling before the page container; the retained row
                // must remain independently owned after both are released.
                sibling.deinit();
                break :blk first.next;
            };
            var second = try table.scanSnapshot(output.allocator(), handle, next, .{}, access.guard());
            defer second.deinit();
            try t.expectEqual(@as(u8, 8), second.count);
            for (second.rows[0..second.count], 8..) |value, i| {
                try t.expectEqual(@as(i128, @intCast(i)), value.?.row().cells[0].value.atom.signed);
                try t.expectEqualSlices(u8, &payloads[i], value.?.row().cells[1].value.atom.bytes);
            }
            // Changing the selected projection replaces the cached group. The
            // output owner cannot borrow that group or this new page's scratch.
            var projected = try table.scanSnapshotColumns(output.allocator(), handle, &.{0}, null, .{}, access.guard());
            defer projected.deinit();
            try t.expectEqual(@as(u8, 8), projected.count);
            @memset(std.mem.asBytes(&payloads), 0);
        }
        const expected: [64]u8 = @splat('a');
        try t.expectEqual(@as(i128, 0), retained.?.row().cells[0].value.atom.signed);
        try t.expectEqualSlices(u8, &expected, retained.?.row().cells[1].value.atom.bytes);
        try t.expect(output.live_bytes > 0);
        retained.?.deinit();
        retained = null;
        try t.expectEqual(@as(usize, 0), output.live_bytes);
    }
}

test "lazy point reads release discarded physical values before returning" {
    for ([_]P.Ingestion{ .point, .bulk }) |ingest| {
        var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
        defer wal.deinit();
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        var access: Access = .{};
        const payload: [16 * 1024]u8 = @splat('x');
        const values = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .bytes = &payload } } } };
        _ = try table.apply(binding(&table, 1, .create), &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = 0 }, .cells = &values } } }}, ingest, access.guard());
        _ = try table.changeDefinition(binding(&table, 2, .alter), .{ .alter = .{ .change = .{ .drop = 2 }, .properties = "" } }, access.guard());
        var key_buffer: [4096]u8 = undefined;
        const key = try f.Collation.encodePrimaryKeySortKey(table.declaration.schema.schema, values[0..1], false, &key_buffer);
        const Case = struct {
            fn read(allocator: std.mem.Allocator, source: *P, row_key: []const u8) !void {
                var vtable = allocator.vtable.*;
                vtable.resize = std.mem.Allocator.noResize;
                vtable.remap = std.mem.Allocator.noRemap;
                const a: std.mem.Allocator = .{ .ptr = allocator.ptr, .vtable = &vtable };
                var allow: Access = .{};
                var row = (try source.get(a, row_key, allow.guard())).?;
                defer row.deinit();
                try t.expectEqual(@as(usize, 1), row.row().cells.len);
                try t.expectEqual(@as(i128, 1), row.row().cells[0].value.atom.signed);
            }
        };
        try t.checkAllAllocationFailures(t.allocator, Case.read, .{ &table, key });
        var output: f.memory.AllocationProbe = .{ .parent = t.allocator };
        {
            var row = (try table.get(output.allocator(), key, access.guard())).?;
            defer row.deinit();
            try t.expect(output.live_bytes < 4 * 1024);
        }
        try t.expectEqual(@as(usize, 0), output.live_bytes);
    }
}

test "current Table observations are bounded owned read-only pages with final authorization" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    _ = try table.apply(binding(&table, 1, .create), &.{}, .point, access.guard());
    const empty_root = table.root;
    access.deny_at = access.calls + 2;
    try t.expectError(error.PermissionDenied, table.observeRows(t.allocator, .{}, access.guard()));
    access.deny_at = std.math.maxInt(usize);
    var empty = try table.observeRows(t.allocator, .{}, access.guard());
    defer empty.deinit();
    try t.expectEqual(@as(u8, 0), empty.count);
    try t.expect(!empty.more);
    try t.expectEqualDeep(empty_root, table.root);
    var cells: [9][2]f.Types.Values.Cell = undefined;
    var changes: [9]P.Change = undefined;
    for (&cells, &changes, 0..) |*values, *change, i| {
        values.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(i) } } }, .{ .value = .{ .atom = .{ .bytes = "observed bytes" } } } };
        change.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 2, .ordinal = @intCast(i) }, .cells = values }, .expect = .absent } };
    }
    _ = try table.apply(binding(&table, 2, .insert), changes[0..5], .bulk, access.guard());
    _ = try table.apply(binding(&table, 3, .insert), changes[5..], .point, access.guard());
    const before = table.root;
    const puts = objects.puts;
    var observed = try table.observeRows(t.allocator, .{ .rows = 3 }, access.guard());
    defer observed.deinit();
    try t.expectEqual(@as(u8, 3), observed.count);
    try t.expectEqual(@as(u64, 9), observed.total_rows);
    try t.expect(observed.more);
    try t.expectEqualDeep(before.declared(), observed.interpretation);
    try t.expectEqual(before.next_lsn, observed.accepted.next_lsn);
    try t.expectEqual(before.changed_lsn, observed.changed_lsn);
    try t.expectError(error.TableReadBudgetTooSmall, table.observeRows(t.allocator, .{ .encoded_bytes = 1 }, access.guard()));
    access.deny_at = access.calls + 2;
    try t.expectError(error.PermissionDenied, table.observeRows(t.allocator, .{}, access.guard()));
    access.deny_at = std.math.maxInt(usize);
    try t.expectEqualDeep(before, table.root);
    try t.expectEqual(puts, objects.puts);
    try t.expectEqual(before.next_lsn, try wal.log().tail(before.partition));
    _ = try table.changeDefinition(binding(&table, 4, .drop), .{ .drop = "" }, access.guard());
    try t.expectError(error.TableRetired, table.observeRows(t.allocator, .{}, access.guard()));
    for (observed.rows[0..observed.count], 0..) |row, i| {
        try t.expectEqual(i, row.?.row().identity.ordinal);
        try t.expectEqualStrings("observed bytes", row.?.row().cells[1].value.atom.bytes);
    }
}

test "current Table point and suffix reads keep a logical basis across physical progress and disk reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var expected: d.Position = undefined;
    var first: P.RowPage = undefined;
    const body: [2048]u8 = @splat('b');
    var key_bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
    var key_len: usize = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        var cells: [33][2]f.Types.Values.Cell = undefined;
        var changes: [33]P.Change = undefined;
        for (&cells, &changes, 0..) |*values, *change, i| {
            values.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(i) } } }, .{ .value = .{ .atom = .{ .bytes = &body } } } };
            change.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = @intCast(i) }, .cells = values }, .expect = .absent } };
        }
        _ = try table.apply(binding(&table, 1, .create), changes[0..17], .bulk, access.guard());
        _ = try table.apply(binding(&table, 2, .insert), changes[17..], .point, access.guard());
        expected = .{ .partition = 17, .next_lsn = table.root.next_lsn };
        key_len = (try changes[32].put.row.storageKey(definition.schema, &key_bytes)).len;
        const before = table.root;
        const puts = objects.puts;
        var found = (try table.readCurrent(t.allocator, expected, key_bytes[0..key_len], access.guard())).?;
        defer found.deinit();
        try t.expectEqual(@as(u32, 32), found.row().identity.ordinal);
        first = try table.scanCurrent(t.allocator, expected, null, .{ .rows = 3 }, access.guard());
        errdefer first.deinit();
        try t.expectEqual(@as(u8, 3), first.count);
        try t.expectEqualDeep(before, table.root);
        try t.expectEqual(puts, objects.puts);
        // No-op acceptance, read retention and physical flush do not invalidate
        // the logical basis or stable identity order.
        _ = try table.apply(binding(&table, 3, .insert), &.{}, .point, access.guard());
        const temporary = try pin(&table, 80, &access);
        try table.releaseSnapshot(temporary, access.guard());
        _ = try table.flush(access.guard());
        try t.expectEqual(before.changed_lsn, table.root.changed_lsn);
        try t.expect(table.root.next_lsn > expected.next_lsn);
    }
    defer first.deinit();
    var after = try f.TableRow.Identity.decode(&first.next.?);
    var count: usize = first.count;
    while (true) {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        var page = try table.scanCurrent(t.allocator, expected, after, .{ .rows = 8, .encoded_bytes = 4096 }, access.guard());
        defer page.deinit();
        try t.expectEqual(@as(u8, 1), page.count);
        try t.expectEqual(count, page.rows[0].?.row().identity.ordinal);
        try t.expectEqualStrings(&body, page.rows[0].?.row().cells[1].value.atom.bytes);
        count += page.count;
        if (page.next) |next| {
            after = try f.TableRow.Identity.decode(&next);
            continue;
        }
        try t.expectEqual(@as(usize, 33), count);
        const before = table.root;
        try t.expectError(error.InvalidTableSnapshotCursor, table.scanCurrent(t.allocator, expected, .{ .origin = 7, .operation = 1, .ordinal = 99 }, .{}, access.guard()));
        try t.expectError(error.TableReadBudgetTooSmall, table.scanCurrent(t.allocator, expected, null, .{ .encoded_bytes = 1 }, access.guard()));
        try t.expectError(error.TableDataChanged, table.readCurrent(t.allocator, .{ .partition = 18, .next_lsn = expected.next_lsn }, key_bytes[0..key_len], access.guard()));
        try t.expectError(error.TableDataChanged, table.readCurrent(t.allocator, .{ .partition = 17, .next_lsn = before.next_lsn + 1 }, key_bytes[0..key_len], access.guard()));
        try t.expectEqualDeep(before, table.root);
        _ = try table.apply(binding(&table, 4, .delete), &.{.{ .remove = key_bytes[0..key_len] }}, .point, access.guard());
        try t.expectError(error.TableDataChanged, table.readCurrent(t.allocator, expected, key_bytes[0..key_len], access.guard()));
        try t.expectError(error.TableDataChanged, table.scanCurrent(t.allocator, expected, after, .{}, access.guard()));
        const newer: d.Position = .{ .partition = 17, .next_lsn = table.root.next_lsn };
        try t.expect(try table.readCurrent(t.allocator, newer, key_bytes[0..key_len], access.guard()) == null);
        break;
    }
    // Earlier owned bytes remain valid despite owner replacement and deletion.
    for (first.rows[0..first.count]) |row| try t.expectEqualStrings(&body, row.?.row().cells[1].value.atom.bytes);
}

test "current Table reads recheck disclosure for buffered rows absence and empty suffixes" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var table = try owner(&wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .bytes = "current" } } } };
    const row: f.TableRow.Row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = 0 }, .cells = &cells };
    var key_bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
    const key = try row.storageKey(definition.schema, &key_bytes);
    _ = try table.apply(binding(&table, 1, .create), &.{}, .point, access.guard());
    const empty: d.Position = .{ .partition = 17, .next_lsn = table.root.next_lsn };
    access.deny_at = access.calls + 2;
    try t.expectError(error.PermissionDenied, table.readCurrent(t.allocator, empty, key, access.guard()));
    access.deny_at = access.calls + 2;
    try t.expectError(error.PermissionDenied, table.scanCurrent(t.allocator, empty, null, .{}, access.guard()));
    access.deny_at = std.math.maxInt(usize);
    _ = try table.apply(binding(&table, 2, .insert), &.{.{ .put = .{ .row = row, .expect = .absent } }}, .point, access.guard());
    const expected: d.Position = .{ .partition = 17, .next_lsn = table.root.next_lsn };
    const before = table.root;
    const puts = objects.puts;
    access.deny_at = access.calls + 2;
    try t.expectError(error.PermissionDenied, table.readCurrent(t.allocator, expected, key, access.guard()));
    access.deny_at = access.calls + 2;
    try t.expectError(error.PermissionDenied, table.scanCurrent(t.allocator, expected, null, .{}, access.guard()));
    access.deny_at = access.calls + 2;
    try t.expectError(error.PermissionDenied, table.scanCurrent(t.allocator, expected, row.identity, .{}, access.guard()));
    access.deny_at = std.math.maxInt(usize);
    try t.expectEqualDeep(before, table.root);
    try t.expectEqual(puts, objects.puts);
    _ = try table.changeDefinition(binding(&table, 3, .drop), .{ .drop = "" }, access.guard());
    try t.expectError(error.TableRetired, table.readCurrent(t.allocator, expected, key, access.guard()));
    try t.expectError(error.TableRetired, table.scanCurrent(t.allocator, expected, null, .{}, access.guard()));
}

test "retained Table key ranges follow binary ASCII CI and CP037 composite order" {
    const cases = [_]struct { collation: f.TableSchema.Collation, order: [5]usize }{
        .{ .collation = .utf8_binary, .order = .{ 3, 2, 0, 4, 1 } },
        .{ .collation = .ascii_ci, .order = .{ 3, 4, 2, 1, 0 } },
        .{ .collation = .ebcdic_cp037, .order = .{ 4, 1, 2, 0, 3 } },
        .{ .collation = .ebcdic_037_pad, .order = .{ 4, 1, 2, 0, 3 } },
        .{ .collation = .ebcdic_1047_nopad, .order = .{ 4, 1, 2, 0, 3 } },
    };
    const names = [_][]const u8{ "Z", "a", "A", "0", "a" };
    const numbers = [_]i128{ 0, 2, -1, 0, -2 };
    for (cases) |case| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var schema_columns = [_]f.TableSchema.Column{
            .{ .id = 1, .name = "name", .type = .utf8, .nullable = false, .collation = case.collation },
            .{ .id = 2, .name = "number", .type = .int64, .nullable = false },
        };
        var declaration = definition;
        declaration.schema.columns = &schema_columns;
        declaration.schema.primary_key = &.{ 1, 2 };
        var access: Access = .{};
        var handle: P.SnapshotHandle = undefined;
        var cells: [5][2]f.Types.Values.Cell = undefined;
        var changes: [5]P.Change = undefined;
        for (&cells, &changes, names, numbers, 0..) |*values, *change, name, number, i| {
            values.* = .{ .{ .value = .{ .atom = .{ .bytes = name } } }, .{ .value = .{ .atom = .{ .signed = number } } } };
            change.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = @intCast(i) }, .cells = values }, .expect = .absent } };
        }
        {
            var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
            defer wal.deinit();
            var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
            defer objects.deinit();
            var table = try P.init(t.allocator, 17, declaration, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
            defer table.deinit();
            try table.recover();
            _ = try table.apply(binding(&table, 1, .create), &changes, .point, access.guard());
            _ = try table.flush(access.guard());
            handle = try pin(&table, 80, &access);
        }
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try P.init(t.allocator, 17, declaration, wal.log(), objects.objectStore(), .{ .resident_pages = 0, .segment_cache_bytes = 0 });
        defer table.deinit();
        try table.recover();
        var page = try table.rangeSnapshot(t.allocator, handle, .{}, null, .{}, access.guard());
        defer page.deinit();
        try t.expectEqual(@as(u8, 5), page.count);
        try t.expect(page.next == null);
        for (page.rows[0..page.count], case.order) |row, expected| {
            try t.expectEqualStrings(names[expected], row.?.row().cells[0].value.atom.bytes);
            try t.expectEqual(numbers[expected], row.?.row().cells[1].value.atom.signed);
        }
        var lower: [4096]u8 = undefined;
        var upper: [4096]u8 = undefined;
        const interval: P.KeyRange = .{
            .lower = .{ .key = try f.Collation.encodePrimaryKeySortKey(declaration.schema, &cells[case.order[1]], false, &lower) },
            .upper = .{ .key = try f.Collation.encodePrimaryKeySortKey(declaration.schema, &cells[case.order[3]], false, &upper), .inclusive = false },
        };
        var selected = try table.rangeSnapshot(t.allocator, handle, interval, null, .{}, access.guard());
        defer selected.deinit();
        try t.expectEqual(@as(u8, 2), selected.count);
        try t.expect(selected.next == null);
        for (selected.rows[0..selected.count], case.order[1..3]) |row, expected| try t.expectEqual(@as(u32, @intCast(expected)), row.?.row().identity.ordinal);
    }
}

fn checkFiltered(table: *P, handle: P.SnapshotHandle, access: *Access, ceiling: i128, expected_count: u64) !void {
    var fields: [128]f.Types.Field = undefined;
    const plan: f.LogicalQuery.Plan = .{ .schema = try definition.schema.rowType(&fields), .source_basis = @splat(3), .collations = .fromTable(definition.schema), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .le, .value = .{ .signed = ceiling } } } };
    var after: ?P.SnapshotCursor = null;
    var examined: u64 = 0;
    var found: u64 = 0;
    var last_identity: ?f.TableRow.Identity = null;
    while (true) {
        var page = try table.scanSnapshotFiltered(t.allocator, handle, plan, after, .{ .rows = 2 }, access.guard());
        defer page.deinit();
        try t.expect(page.failure == null);
        try t.expect(page.examined <= 8);
        try t.expect(page.page.count <= page.examined);
        var offset: u8 = 0;
        for (page.page.rows[0..page.page.count], page.offsets[0..page.page.count]) |slot, at| {
            const row = slot.?.row();
            try t.expect(at > offset and at <= page.examined);
            offset = at;
            try t.expectEqual(@as(usize, 1), row.cells.len);
            try t.expect(row.cells[0].value.atom.signed <= ceiling);
            if (last_identity) |previous| try t.expect(f.RelationalExecution.identityOrder(previous, row.identity) == .lt);
            last_identity = row.identity;
            found += 1;
        }
        examined += page.examined;
        after = page.page.next;
        if (after == null) {
            try t.expectEqual(page.page.total_rows, examined);
            break;
        }
        try t.expect(page.examined > 0);
    }
    try t.expectEqual(expected_count, found);
}

test "filtered Table snapshots retain live identity order empty coverage and plan bound decisions" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var access: Access = .{};
    var retained: P.SnapshotHandle = undefined;
    var current: P.SnapshotHandle = undefined;
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try owner(&wal, &objects);
        defer table.deinit();
        const payload: [16 * 1024]u8 = @splat('x');
        var cells: [12][2]f.Types.Values.Cell = undefined;
        var changes: [12]P.Change = undefined;
        // Identity order interleaves two physical segments, and key order is
        // reversed within each. No segment-wide result may reorder the source.
        for (0..2) |segment| {
            for (&cells, &changes, 0..) |*values, *change, i| {
                const ordinal = i * 2 + segment;
                values.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(23 - ordinal) } } }, .{ .value = .{ .atom = .{ .bytes = &payload } } } };
                change.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = @intCast(ordinal) }, .cells = values } } };
            }
            _ = try table.apply(binding(&table, segment + 1, if (segment == 0) .create else .insert), &changes, .bulk, access.guard());
        }
        const wal_cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 24 } } }, .{ .value = .{ .atom = .{ .bytes = &payload } } } };
        _ = try table.apply(binding(&table, 3, .insert), &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 2, .ordinal = 0 }, .cells = &wal_cells } } }}, .point, access.guard());
        retained = try pin(&table, 80, &access);
        table.options.segment_decode_bytes = 8 * 1024;
        try checkFiltered(&table, retained, &access, 3, 4);
        try checkFiltered(&table, retained, &access, -1, 0);
        try checkFiltered(&table, retained, &access, 24, 25);
        var fields: [128]f.Types.Field = undefined;
        var plan: f.LogicalQuery.Plan = .{ .schema = try definition.schema.rowType(&fields), .source_basis = @splat(3), .collations = .fromTable(definition.schema), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .le, .value = .{ .signed = 3 } } } };
        var empty = try table.scanSnapshotFiltered(t.allocator, retained, plan, null, .{}, access.guard());
        defer empty.deinit();
        try t.expectEqual(@as(u8, 0), empty.page.count);
        try t.expectEqual(@as(u8, 8), empty.examined);
        try t.expect(empty.page.next != null);
        plan.predicate.compare.value.signed = 24;
        try t.expectError(error.InvalidTableSnapshotCursor, table.scanSnapshotFiltered(t.allocator, retained, plan, empty.page.next, .{}, access.guard()));
        try t.expectError(error.InvalidTableSnapshotCursor, table.scanSnapshotColumns(t.allocator, retained, &.{0}, empty.page.next, .{}, access.guard()));
        var first = try table.scanSnapshotFiltered(t.allocator, retained, plan, null, .{ .rows = 1 }, access.guard());
        defer first.deinit();
        try t.expectEqual(@as(u8, 1), first.examined);
        try t.expectEqual(@as(i128, 23), first.page.rows[0].?.row().cells[0].value.atom.signed);
        try t.expectError(error.TableReadBudgetTooSmall, table.scanSnapshotFiltered(t.allocator, retained, plan, null, .{ .encoded_bytes = 1 }, access.guard()));
        access.deny_at = access.calls + 3;
        try t.expectError(error.PermissionDenied, table.scanSnapshotFiltered(t.allocator, retained, plan, null, .{}, access.guard()));
        access.deny_at = std.math.maxInt(usize);
        plan.predicate.compare.value.signed = -1;
        access.deny_at = access.calls + 3;
        try t.expectError(error.PermissionDenied, table.scanSnapshotFiltered(t.allocator, retained, plan, null, .{}, access.guard()));
        access.deny_at = std.math.maxInt(usize);
        var key_buffer: [4096]u8 = undefined;
        const key = try f.Collation.encodePrimaryKeySortKey(definition.schema, &.{.{ .value = .{ .atom = .{ .signed = 2 } } }}, false, &key_buffer);
        table.options.segment_decode_bytes = 64 * 1024 * 1024;
        _ = try table.apply(binding(&table, 4, .delete), &.{.{ .remove = key }}, .point, access.guard());
        table.options.segment_decode_bytes = 8 * 1024;
        current = try pin(&table, 81, &access);
        try checkFiltered(&table, retained, &access, 3, 4);
        try checkFiltered(&table, current, &access, 3, 3);
        // The row owns its cells after unrelated decisions and caches disappear.
        try t.expectEqual(@as(i128, 23), first.page.rows[0].?.row().cells[0].value.atom.signed);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var reopened = try owner(&wal, &objects);
    defer reopened.deinit();
    reopened.options.segment_decode_bytes = 8 * 1024;
    try checkFiltered(&reopened, retained, &access, 3, 4);
    try checkFiltered(&reopened, current, &access, 3, 3);
    try reopened.releaseSnapshot(retained, access.guard());
    try t.expectError(error.TableSnapshotReleased, checkFiltered(&reopened, retained, &access, 3, 4));
}

test "filtered Table encoded collation decisions reuse one group and preserve NULL and byte bounds" {
    const texts = [_][]const u8{ "A", "a", "0", "é", "\x00", "AA", "aA" };
    const cases = [_]struct { collation: f.TableSchema.Collation, mask: [8]bool }{
        .{ .collation = .utf8_binary, .mask = .{ true, false, true, false, true, true, false, false } },
        .{ .collation = .ascii_ci, .mask = .{ false, false, true, false, true, false, false, false } },
        .{ .collation = .ebcdic_cp037, .mask = .{ false, false, false, true, true, false, false, false } },
        .{ .collation = .ebcdic_037_pad, .mask = .{ false, false, false, true, true, false, false, false } },
        .{ .collation = .ebcdic_1047_nopad, .mask = .{ false, false, false, true, true, false, false, false } },
    };
    for (cases) |case| {
        var fields = columns;
        fields[0].encoding = .bitpacked;
        fields[1].encoding = .dictionary;
        fields[1].collation = case.collation;
        fields[1].nullable = true;
        var declaration = definition;
        declaration.schema.columns = &fields;
        var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
        defer wal.deinit();
        var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
        defer objects.deinit();
        var table = try P.init(t.allocator, 17, declaration, wal.log(), objects.objectStore(), .{});
        defer table.deinit();
        try table.recover();
        var access: Access = .{};
        var cells: [8][2]f.Types.Values.Cell = undefined;
        var changes: [8]P.Change = undefined;
        for (&cells, &changes, 0..) |*values, *change, i| {
            values.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(i) } } }, if (i == 7) .null else .{ .value = .{ .atom = .{ .bytes = texts[i] } } } };
            change.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = @intCast(i) }, .cells = values } } };
        }
        _ = try table.apply(binding(&table, 1, .create), &changes, .bulk, access.guard());
        const handle = try pin(&table, 80, &access);
        var types: [128]f.Types.Field = undefined;
        var plan: f.LogicalQuery.Plan = .{ .schema = try declaration.schema.rowType(&types), .source_basis = @splat(3), .collations = .fromTable(declaration.schema), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 1, .op = .lt, .value = .{ .bytes = "a" } } } };
        const accepted = table.root;
        var after: ?P.SnapshotCursor = null;
        var mask: [8]bool = @splat(false);
        var examined: usize = 0;
        while (true) {
            var page = try table.scanSnapshotFiltered(t.allocator, handle, plan, after, .{ .rows = 1 }, access.guard());
            defer page.deinit();
            examined += page.examined;
            for (page.page.rows[0..page.page.count]) |slot| {
                const row = slot.?.row();
                const index: usize = @intCast(row.cells[0].value.atom.signed);
                try t.expect(!mask[index]);
                mask[index] = true;
                // Required predicate inputs are retained alongside the key.
                try t.expectEqualStrings(texts[index], row.cells[1].value.atom.bytes);
            }
            after = page.page.next;
            if (after == null) break;
        }
        try t.expectEqual(@as(usize, 8), examined);
        try t.expectEqualSlices(bool, &case.mask, &mask);
        try t.expectEqual(@as(u64, 1), table.row_groups_filtered);
        var repeated = try table.scanSnapshotFiltered(t.allocator, handle, plan, null, .{}, access.guard());
        defer repeated.deinit();
        try t.expectEqual(@as(u64, 1), table.row_groups_filtered);
        // A valid small byte budget makes progress up to the preceding identity.
        if (repeated.page.count > 1) {
            var row_buffer: [4096]u8 = undefined;
            const first_bytes = (try repeated.page.rows[0].?.row().encode(declaration.schema, &row_buffer)).len;
            var bounded = try table.scanSnapshotFiltered(t.allocator, handle, plan, null, .{ .encoded_bytes = @intCast(first_bytes) }, access.guard());
            defer bounded.deinit();
            try t.expectEqual(@as(u8, 1), bounded.page.count);
            try t.expect(bounded.page.next != null);
            var rest = try table.scanSnapshotFiltered(t.allocator, handle, plan, bounded.page.next, .{}, access.guard());
            defer rest.deinit();
            try t.expectEqual(repeated.page.count - 1, rest.page.count);
            try t.expectEqual(@as(u8, 8), bounded.examined + rest.examined);
        }
        plan.predicate.compare.value.bytes = "A";
        var changed = try table.scanSnapshotFiltered(t.allocator, handle, plan, null, .{}, access.guard());
        defer changed.deinit();
        try t.expectEqual(@as(u64, 2), table.row_groups_filtered);
        table.options.segment_predicate_bytes = 1;
        plan.predicate.compare.value.bytes = "a";
        try t.expectError(error.SegmentReadBudgetExceeded, table.scanSnapshotFiltered(t.allocator, handle, plan, null, .{}, access.guard()));
        try t.expectEqualDeep(accepted, table.root);
        const Case = struct {
            fn run(allocator: std.mem.Allocator, log: s.TransitLog.Log, store: s.TransitObjectStore.ObjectStore, declared: s.TableDeclaration.Definition, retained: P.SnapshotHandle, query: f.LogicalQuery.Plan) !void {
                var reopened = try P.init(allocator, 17, declared, log, store, .{});
                defer reopened.deinit();
                try reopened.recover();
                var allow: Access = .{};
                var result = try reopened.scanSnapshotFiltered(allocator, retained, query, null, .{}, allow.guard());
                defer result.deinit();
                try t.expect(result.page.count > 0 and result.failure == null);
            }
        };
        try t.checkAllAllocationFailures(t.allocator, Case.run, .{ wal.log(), objects.objectStore(), declaration, handle, plan });
    }
}
