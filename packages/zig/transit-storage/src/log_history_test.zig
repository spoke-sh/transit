const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const H = s.LogHistory;

test "log history stages bounded immutable ranges using shared TWAL storage across disk reopen" {
    var temporary = t.tmpDir(.{});
    defer temporary.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, temporary.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, temporary.dir, "objects");
    defer objects.deinit();
    var index = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer index.deinit();
    for (0..20) |lsn| {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, lsn, .big);
        _ = try wal.log().append(91, lsn, 1, 1, if (lsn == 0) .genesis else .row_delta, &bytes);
    }
    var coverage: H.Coverage = .empty;
    const cut: @import("transit_protocol").DataLifecycle.Position = .{ .partition = 91, .next_lsn = 16 };
    var units: u64 = 0;
    while (true) {
        try index.begin(8 * 1024 * 1024);
        defer index.end();
        const candidate = try H.stage(t.allocator, &index, wal.log(), 91, coverage, cut, .{ .frames = 3 });
        try t.expect(candidate.frames <= 3);
        try t.expect(candidate.frames > 0);
        try H.verifyExtension(t.allocator, &index, coverage, candidate.coverage, 91, 20);
        coverage = candidate.coverage;
        units += 1;
        if (candidate.complete) break;
    }
    try t.expectEqual(@as(u64, 6), units);
    try t.expectEqual(@as(u64, 16), coverage.through);
    try t.expectEqual(@as(u64, 20), try wal.log().tail(91));
    try t.expectEqual(@as(usize, 1), index.cache.len);
    try index.begin(8 * 1024 * 1024);
    const already = try H.stage(t.allocator, &index, wal.log(), 91, coverage, cut, .{});
    index.end();
    try t.expectEqual(@as(u8, 0), already.frames);
    try t.expect(already.complete);
    // Only this codec fixture directly trims. Installed trimming must require a
    // published partition checkpoint/coverage; private staging grants no such right.
    try wal.log().trim(91, 16);
    index.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, temporary.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, temporary.dir, "objects");
    index = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    for (0..16) |lsn| {
        var batch = try H.read(t.allocator, &index, coverage, 91, lsn);
        defer batch.deinit();
        try t.expectEqual(@as(usize, 1), batch.frames.len);
        try t.expectEqual(@as(u64, lsn), std.mem.readInt(u64, batch.frames[0].payload[0..8], .big));
    }
    try t.expectError(error.LogHistoryUnavailable, H.read(t.allocator, &index, coverage, 91, 16));
    var newer = try wal.log().read(t.allocator, 91, 16, 1);
    defer newer.deinit();
    try t.expectEqual(@as(u64, 16), newer.frames[0].header.lsn);
    try t.expectError(error.InvalidTableArchive, H.read(t.allocator, &index, coverage, 92, 0));
    const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &index };
    const value = (try tree.get(coverage.directory, try s.TableArchive.key(0))).?;
    const content = try s.TableArchive.decodeReference(value);
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try s.TableArchive.objectKey(content.sha256, &name));
    try t.expectError(error.TableHistoryMissing, H.read(t.allocator, &index, coverage, 91, 0));
    try t.expectError(error.WalHistoryTrimmed, wal.log().read(t.allocator, 91, 0, 1));
}

test "log history refuses invented coverage jumps and insufficient staging budgets" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var index = try s.TreeStore.init(t.allocator, objects.objectStore(), 0);
    defer index.deinit();
    _ = try wal.log().append(91, 0, 1, 1, .genesis, "original");
    const cut: @import("transit_protocol").DataLifecycle.Position = .{ .partition = 91, .next_lsn = 1 };
    try index.begin(1);
    try t.expectError(error.StorageCandidateTooLarge, H.stage(t.allocator, &index, wal.log(), 91, .empty, cut, .{}));
    index.end();
    try index.begin(1024 * 1024);
    defer index.end();
    const candidate = try H.stage(t.allocator, &index, wal.log(), 91, .empty, cut, .{});
    try H.verifyExtension(t.allocator, &index, .empty, candidate.coverage, 91, 1);
    var invented = candidate.coverage;
    invented.through = 9;
    try t.expectError(error.InvalidLogArchive, H.verifyExtension(t.allocator, &index, .empty, invented, 91, 10));
    invented = candidate.coverage;
    invented.from = 1;
    try t.expectError(error.InvalidLogArchive, H.verifyExtension(t.allocator, &index, .empty, invented, 91, 10));
    try t.expectError(error.InvalidTableArchiveBudget, H.stage(t.allocator, &index, wal.log(), 91, .empty, cut, .{ .frames = 0 }));
    try t.expectEqual(@as(u64, 1), try wal.log().tail(91));
}
