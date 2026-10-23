const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const f = @import("transit_fuze");
const Memtable = s.TableMemtable.TableMemtable;
const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
const lease: s.PartitionLease.PartitionLease = .{ .object_id = 7, .partition_id = 2, .holder_id = 3, .writer_epoch = 1, .policy_epoch = 1, .lease_until_ms = 10000 };

fn table(allocator: std.mem.Allocator, wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore) !Memtable {
    return Memtable.init(allocator, 1, 7, 2, schema, lease, wal.log(), objects.objectStore(), null);
}
fn insert(owner: *Memtable, i: u64) !u64 {
    return owner.upsertRow(.{ .identity = .{ .origin = 1, .operation = i + 1, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = @intCast(i) } } }} }, 100);
}

test "Table replay crosses every WAL page and cannot serve a failed recovery prefix" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    {
        var writer = try table(t.allocator, &wal, &objects);
        defer writer.deinit();
        for (0..5001) |i| _ = try insert(&writer, i);
    }
    var recovered = try table(t.allocator, &wal, &objects);
    defer recovered.deinit();
    try t.expectEqual(@as(u64, 5001), try recovered.recoverFromWal());
    try t.expectEqual(@as(u64, 5001), try recovered.recoverFromWal());
    try t.expectEqual(@as(usize, 5001), recovered.entries.items.len);
    var last = (try recovered.getByPrimaryKey(t.allocator, &.{.{ .value = .{ .atom = .{ .signed = 5000 } } }}, 5000)).?;
    defer last.deinit();
    try t.expectEqual(@as(u64, 5001), last.identity.operation);
    // Remove one otherwise valid frame to model a missing accepted prefix.
    const retained = &wal.partitions.items[0].bytes;
    const size = (try s.TransitLog.decodeFrame(retained.items)).consumed_bytes;
    std.mem.copyForwards(u8, retained.items[0 .. retained.items.len - size], retained.items[size..]);
    retained.shrinkRetainingCapacity(retained.items.len - size);
    try t.expectError(error.WalHistoryMissing, recovered.recoverFromWal());
    try t.expectError(error.MemtableRecoveryRequired, recovered.getByPrimaryKey(t.allocator, &.{.{ .value = .{ .atom = .{ .signed = 5000 } } }}, 5000));
    try t.expectError(error.MemtableRecoveryRequired, insert(&recovered, 5001));
    try t.expectError(error.MemtableRecoveryRequired, recovered.flushToSegment(100));
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var writer = try table(allocator, &wal, &objects);
    defer writer.deinit();
    _ = insert(&writer, 0) catch |err| {
        try t.expectEqual(@as(u64, 0), try wal.log().tail(2));
        return err;
    };
    try t.expectEqual(@as(u64, 1), try wal.log().tail(2));
    try t.expectEqual(@as(usize, 1), writer.entries.items.len);
}
test "all row visibility allocation failures occur before durable append" {
    try t.checkAllAllocationFailures(t.allocator, allocationCase, .{});
}

test "real disk Table flush retains a raw tseg and replays the unflushed suffix on restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    {
        var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{ .batch_frames = 1 });
        defer wal.deinit();
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "segments");
        defer objects.deinit();
        var writer = try table(t.allocator, &wal, &objects);
        defer writer.deinit();
        _ = try insert(&writer, 0);
        _ = try insert(&writer, 1);
        _ = try writer.flushToSegment(100);
        _ = try insert(&writer, 2);
        _ = try insert(&writer, 3);
        _ = try insert(&writer, 4);
    }
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{ .batch_frames = 1 });
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "segments");
    defer objects.deinit();
    var recovered = try table(t.allocator, &wal, &objects);
    defer recovered.deinit();
    try t.expectEqual(@as(u64, 3), try recovered.recoverFromWal());
    for (0..5) |i| {
        var row = (try recovered.getByPrimaryKey(t.allocator, &.{.{ .value = .{ .atom = .{ .signed = @intCast(i) } } }}, 4)).?;
        defer row.deinit();
        try t.expectEqual(i + 1, row.identity.operation);
    }
    const directory = try tmp.dir.openDir(t.io, "segments/objects", .{ .iterate = true });
    defer directory.close(t.io);
    var iterator = directory.iterate();
    var found = false;
    while (try iterator.next(t.io)) |entry| {
        if (!std.mem.endsWith(u8, entry.name, ".tseg")) continue;
        const file = try directory.openFile(t.io, entry.name, .{});
        defer file.close(t.io);
        var magic: [4]u8 = undefined;
        try t.expectEqual(@as(usize, 4), try file.readPositionalAll(t.io, &magic, 0));
        try t.expectEqualStrings("TSEG", &magic);
        found = true;
    }
    try t.expect(found);
}

test "keyless rows keep stable identities across flush, delete and recovery" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var keyless = schema;
    keyless.primary_key = &.{};
    var owner = try Memtable.init(t.allocator, 1, 7, 2, keyless, lease, wal.log(), objects.objectStore(), null);
    defer owner.deinit();
    const value: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 11 } } };
    for (0..3) |i| _ = try owner.upsertRow(.{ .identity = .{ .origin = 1, .operation = 10, .ordinal = @intCast(i) }, .cells = &.{value} }, 100);
    try t.expectEqual(@as(u64, 3), (try owner.flushToSegment(100)).?.live_row_count);
    try t.expectError(error.MissingPrimaryKey, owner.getByPrimaryKey(t.allocator, &.{}, 2));
    try t.expectError(error.MissingPrimaryKey, owner.deleteByPrimaryKey(&.{}, 100));
    for (0..3) |i| {
        var row = (try owner.getByIdentity(t.allocator, .{ .origin = 1, .operation = 10, .ordinal = @intCast(i) }, 2)).?;
        defer row.deinit();
        try t.expectEqual(@as(i128, 11), row.cells[0].value.atom.signed);
        try t.expectEqual(i, row.identity.ordinal);
    }
    _ = try owner.deleteByIdentity(.{ .origin = 1, .operation = 10, .ordinal = 1 }, 100);
    try t.expectEqual(@as(u64, 2), (try owner.flushToSegment(100)).?.live_row_count);
    try t.expectEqual(@as(u64, 0), try owner.recoverFromWal());
    try t.expect((try owner.getByIdentity(t.allocator, .{ .origin = 1, .operation = 10, .ordinal = 1 }, 3)) == null);
    var retained = (try owner.getByIdentity(t.allocator, .{ .origin = 1, .operation = 10, .ordinal = 2 }, 3)).?;
    defer retained.deinit();
    try t.expectEqual(@as(u32, 2), retained.identity.ordinal);
}

test "a point read never substitutes a newer flush for an unavailable old snapshot" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var owner = try table(t.allocator, &wal, &objects);
    defer owner.deinit();
    _ = try insert(&owner, 0);
    _ = try owner.deleteByPrimaryKey(&.{.{ .value = .{ .atom = .{ .signed = 0 } } }}, 100);
    _ = try owner.flushToSegment(100);
    try t.expectError(error.SnapshotNotRetained, owner.getByPrimaryKey(t.allocator, &.{.{ .value = .{ .atom = .{ .signed = 0 } } }}, 0));
    try t.expect((try owner.getByPrimaryKey(t.allocator, &.{.{ .value = .{ .atom = .{ .signed = 0 } } }}, 1)) == null);
}
