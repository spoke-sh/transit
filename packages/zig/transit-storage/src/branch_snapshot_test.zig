const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const B = s.BranchSnapshot;
const d = p.DataLifecycle;
const scope: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
const identity: p.Branch.Identity = .{ .scope = scope, .branch = 2 };
const owner: d.Operation = .{ .scope = scope, .principal = 4, .operation = 91 };

fn entry(object: u64) B.Entry {
    return .{
        .source = .{
            .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = object }, .revision = 1, .digest = @splat(7) },
            .manifest = null,
            .checkpoint_lsn = 0,
            .accepted = .{ .partition = object, .next_lsn = 5 },
        },
        .pin = .{ .owner = owner, .content = .{ .bytes = 256, .sha256 = @splat(8) } },
    };
}

test "branch snapshot pages frozen directories beyond cache and former table bound on disk" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var original: p.Branch.Directory = undefined;
    var full: p.Branch.Directory = undefined;
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var directory = try B.init(t.allocator, objects.objectStore(), identity, owner, 1000, 1, 1024 * 1024);
        defer directory.deinit();
        for (1..138) |i| {
            try directory.put(entry(i));
            if (i == 8) original = try directory.seal();
        }
        full = try directory.seal();
        try t.expectEqualDeep(full, try directory.commitment());
        try t.expectEqual(@as(usize, 1), directory.index.cache.len);
        const puts = objects.puts;
        try directory.put(entry(1));
        try t.expectEqual(puts, objects.puts);
        var conflict = entry(1);
        conflict.source.accepted.next_lsn += 1;
        try t.expectError(error.BranchIdentityConflict, directory.put(conflict));
        try t.expectEqualDeep(full, try directory.commitment());
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var directory = try B.init(t.allocator, objects.objectStore(), identity, owner, 1000, 0, 1024 * 1024);
    defer directory.deinit();
    for ([_]p.Branch.Directory{ original, full }) |selected| {
        try directory.restore(selected);
        var cursor = try directory.cursor();
        var count: u64 = 0;
        while (!cursor.complete) {
            const page = try directory.page(cursor);
            for (page.entries) |slot| if (slot) |value| {
                count += 1;
                try t.expectEqualDeep(entry(count), value);
            };
            cursor = page.cursor;
        }
        try t.expectEqual(selected.objects, count);
        const terminal = try directory.page(cursor);
        for (terminal.entries) |slot| try t.expect(slot == null);
        try t.expectEqualDeep(cursor, terminal.cursor);
    }
    const cursor = try directory.cursor();
    try directory.restore(original);
    try t.expectError(error.BranchIdentityConflict, directory.page(cursor));
    var forged = full;
    forged.objects -= 1;
    try t.expectError(error.BranchIdentityConflict, directory.restore(forged));
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try B.objectKey(full.content, &name));
    try t.expectError(error.BranchArtifactMissing, directory.restore(full));
    try t.expectEqualDeep(original, try directory.commitment());
}

test "branch snapshot refuses quota work incomplete cursor and wrong retention owner" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var directory = try B.init(t.allocator, objects.objectStore(), identity, owner, 1, 1, 1024 * 1024);
    defer directory.deinit();
    const empty = try directory.page(try directory.cursor());
    try t.expect(empty.cursor.complete);
    try t.expectEqual(@as(u64, 0), empty.cursor.seen);
    try directory.put(entry(1));
    const original = try directory.seal();
    try t.expectError(error.BranchObjectLimit, directory.put(entry(2)));
    directory.object_limit = 2;
    directory.index_work_bytes = 1;
    try t.expectError(error.StorageCandidateTooLarge, directory.put(entry(2)));
    try t.expectEqualDeep(original, try directory.commitment());
    try t.expect((try directory.get(2)) == null);
    var wrong = entry(2);
    wrong.pin.owner.operation += 1;
    try t.expectError(error.BranchIdentityConflict, directory.put(wrong));
    var cursor = try directory.cursor();
    cursor.complete = true;
    try t.expectError(error.InvalidBranchCursor, directory.page(cursor));
    cursor.complete = false;
    cursor.after = 1;
    try t.expectError(error.InvalidBranchCursor, directory.page(cursor));
}

test "branch snapshot manifest reopens exact ancestry without publishing a branch" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var directory = try B.init(t.allocator, objects.objectStore(), identity, owner, 10, 1, 1024 * 1024);
    defer directory.deinit();
    try directory.put(entry(7));
    const manifest: p.Branch.Manifest = .{
        .definition = p.Growth.current_definition,
        .identity = identity,
        .version = 1,
        .kind = .fork,
        .mode = .full_data,
        .catalog = .{ .partition = 17, .next_lsn = 5 },
        .objects = try directory.commitment(),
        .retention_owner = owner,
        .parent = .{ .identity = .{ .scope = scope, .branch = 1 }, .version = 99, .content = .{ .bytes = 256, .sha256 = @splat(1) } },
        .merge_parent = null,
        .restored_from = null,
    };
    const ref = try directory.stageManifest(manifest);
    try t.expectEqualDeep(manifest, try B.loadManifest(objects.objectStore(), ref));
    var wrong = ref;
    wrong.version += 1;
    try t.expectError(error.BranchIdentityConflict, B.loadManifest(objects.objectStore(), wrong));
    wrong = ref;
    wrong.identity.branch += 1;
    try t.expectError(error.BranchIdentityConflict, B.loadManifest(objects.objectStore(), wrong));
    try t.expectError(error.TableSnapshotMissing, directory.verifyEntry(t.allocator, entry(7)));
}

const Access = struct {
    fn acquire(_: *anyopaque) !s.TablePartition.Guard.Fence {
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn guard(self: *Access) s.TablePartition.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
};

test "branch snapshot verifies actual pinned unflushed Table root after disk reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var frozen: p.Branch.Directory = undefined;
    var actual: B.Entry = undefined;
    const object: d.Object = .{ .scope = scope, .branch = 1, .object = 7 };
    const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var table = try s.TablePartition.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
        defer table.deinit();
        try table.recover();
        var access: Access = .{};
        const binding: d.Binding = .{ .definition = p.Growth.current_definition, .identity = owner, .target = object, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(7) };
        const changes = [_]s.TablePartition.Change{.{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 91, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 42 } } }} }, .expect = .absent } }};
        _ = try table.apply(binding, &changes, .point, access.guard());
        const position: d.Position = .{ .partition = 17, .next_lsn = table.root.next_lsn };
        actual = .{ .source = .{ .interpretation = table.root.interpretation, .manifest = null, .checkpoint_lsn = 0, .accepted = position }, .pin = try table.pin(owner, position, access.guard()) };
        var directory = try B.init(t.allocator, objects.objectStore(), identity, owner, 10, 1, 1024 * 1024);
        defer directory.deinit();
        try directory.verifyEntry(t.allocator, actual);
        try directory.put(actual);
        frozen = try directory.seal();
        var later = binding;
        later.identity.operation = 92;
        later.action = .insert;
        later.expected_definition = table.root.interpretation;
        const later_changes = [_]s.TablePartition.Change{.{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 92, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 43 } } }} }, .expect = .absent } }};
        _ = try table.apply(later, &later_changes, .point, access.guard());
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var directory = try B.init(t.allocator, objects.objectStore(), identity, owner, 10, 0, 1024 * 1024);
    defer directory.deinit();
    try directory.restore(frozen);
    try t.expectEqualDeep(actual, (try directory.get(7)).?);
    try directory.verifyEntry(t.allocator, actual);
    var wrong = actual;
    wrong.source.accepted.next_lsn += 1;
    try t.expectError(error.BranchIdentityConflict, directory.verifyEntry(t.allocator, wrong));
    wrong = actual;
    wrong.source.interpretation.digest[0] ^= 1;
    try t.expectError(error.BranchIdentityConflict, directory.verifyEntry(t.allocator, wrong));
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var table = try s.TablePartition.init(t.allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, wal.log(), objects.objectStore(), .{ .resident_pages = 0 });
    defer table.deinit();
    try table.recover();
    var access: Access = .{};
    var key_bytes: [128]u8 = undefined;
    const before_key = try f.Collation.encodePrimaryKeySortKey(schema, &.{.{ .value = .{ .atom = .{ .signed = 42 } } }}, false, &key_bytes);
    var row = (try table.readSnapshot(t.allocator, actual.pin, before_key, access.guard())).?;
    defer row.deinit();
    try t.expectEqual(@as(i128, 42), row.row().cells[0].value.atom.signed);
    const after_key = try f.Collation.encodePrimaryKeySortKey(schema, &.{.{ .value = .{ .atom = .{ .signed = 43 } } }}, false, &key_bytes);
    try t.expect((try table.readSnapshot(t.allocator, actual.pin, after_key, access.guard())) == null);
    var later_row = (try table.get(t.allocator, after_key, access.guard())).?;
    defer later_row.deinit();
    try t.expectEqual(@as(i128, 43), later_row.row().cells[0].value.atom.signed);
}
