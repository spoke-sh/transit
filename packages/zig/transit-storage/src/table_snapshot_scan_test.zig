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
}
