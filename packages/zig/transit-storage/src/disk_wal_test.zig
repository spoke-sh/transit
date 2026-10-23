const std = @import("std");
const t = std.testing;
const Wal = @import("LocalWal.zig").LocalWal;
const Log = @import("TransitLog.zig");

fn open(dir: std.Io.Dir) !Wal {
    return Wal.openDiskWithOptions(t.allocator, t.io, dir, "wal", .{ .segment_bytes = 256, .batch_frames = 2 });
}

test "disk log rolls segments and pages beyond its partition cache through restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    {
        var wal = try open(tmp.dir);
        defer wal.deinit();
        try t.expectError(error.WalInUse, open(tmp.dir));
        // More than the former total-partition limit, with only eight cached
        // descriptors. Every payload is read from its actual disk segment.
        for (0..73) |partition| {
            for (0..5) |lsn| {
                var bytes: [32]u8 = undefined;
                const payload = try std.fmt.bufPrint(&bytes, "{d}:{d}", .{ partition, lsn });
                _ = try wal.log().append(partition, lsn, 2, 3, .row_delta, payload);
            }
        }
        try t.expect(wal.disk.?.cache.len < 73);
    }
    var resident: [32 * 1024]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(&resident);
    var wal = try Wal.openDiskWithOptions(fixed.allocator(), t.io, tmp.dir, "wal", .{ .segment_bytes = 256, .batch_frames = 2 });
    defer wal.deinit();
    for (0..73) |partition| {
        try t.expectEqual(@as(u64, 5), try wal.log().tail(partition));
        var next: u64 = 0;
        while (next < 5) {
            var batch = try wal.log().read(t.allocator, partition, next, 1000);
            defer batch.deinit();
            try t.expect(batch.frames.len > 0 and batch.frames.len <= 2);
            for (batch.frames) |frame| {
                var bytes: [32]u8 = undefined;
                try t.expectEqualStrings(try std.fmt.bufPrint(&bytes, "{d}:{d}", .{ partition, next }), frame.payload);
                try t.expectEqual(next, frame.header.lsn);
                next += 1;
            }
        }
    }
}

test "disk fence without append and complete trim preserve epochs and LSN identity" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    {
        var wal = try open(tmp.dir);
        defer wal.deinit();
        try wal.log().fence(1, 8, 9);
        _ = try wal.log().append(2, 0, 3, 4, .row_delta, "accepted");
        try wal.log().trim(2, 1);
        try t.expectError(error.WalHistoryTrimmed, wal.log().read(t.allocator, 2, 0, 1));
        try t.expectError(error.InvalidWalTrimBoundary, wal.log().trim(2, 2));
    }
    {
        var wal = try open(tmp.dir);
        defer wal.deinit();
        try t.expectError(error.StaleWriterEpoch, wal.log().append(1, 0, 7, 9, .row_delta, "old"));
        try t.expectError(error.StalePolicyEpoch, wal.log().append(1, 0, 8, 8, .row_delta, "old"));
        try t.expectError(error.WalEpochRegression, wal.log().fence(1, 7, 9));
        try t.expectEqual(@as(u64, 1), try wal.log().tail(2));
        try t.expectError(error.WalLsnConflict, wal.log().append(2, 0, 3, 4, .row_delta, "reset"));
        _ = try wal.log().append(2, 1, 3, 4, .row_delta, "successor");
    }
    var wal = try open(tmp.dir);
    defer wal.deinit();
    var batch = try wal.log().read(t.allocator, 2, 1, 8);
    defer batch.deinit();
    try t.expectEqualStrings("successor", batch.frames[0].payload);
}

fn appendRaw(dir: std.Io.Dir, name: []const u8, bytes: []const u8) !void {
    const file = try dir.openFile(t.io, name, .{ .mode = .read_write });
    defer file.close(t.io);
    try file.writePositionalAll(t.io, bytes, try file.length(t.io));
    try file.sync(t.io);
}

test "recovery truncates only an incomplete unacknowledged final frame" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    {
        var wal = try open(tmp.dir);
        defer wal.deinit();
        _ = try wal.log().append(1, 0, 1, 1, .row_delta, "first");
    }
    var bytes: [256]u8 = undefined;
    const encoded = try Log.encodeFrame(1, 1, 1, 1, 0, .row_delta, "second", &bytes);
    try appendRaw(tmp.dir, "wal/part-1-0.twal", encoded[0 .. encoded.len - 7]);
    {
        var wal = try open(tmp.dir);
        defer wal.deinit();
        try t.expectEqual(@as(u64, 1), try wal.log().tail(1));
        try t.expectEqual(encoded.len - 7, wal.truncated_tail_bytes);
        _ = try wal.log().append(1, 1, 1, 1, .row_delta, "replacement");
        _ = try wal.log().append(1, 2, 1, 1, .row_delta, "third");
    }
    // A damaged nonfinal segment cannot be repaired by dropping later history.
    const file = try tmp.dir.openFile(t.io, "wal/part-1-0.twal", .{ .mode = .read_write });
    defer file.close(t.io);
    try file.setLength(t.io, (try file.length(t.io)) - 9);
    try t.expectError(error.WalHistoryMissing, open(tmp.dir));
}

test "missing acknowledged tail and corruption fail without resetting the partition" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    {
        var wal = try open(tmp.dir);
        defer wal.deinit();
        for (0..3) |lsn| _ = try wal.log().append(1, lsn, 1, 1, .row_delta, "data");
    }
    try tmp.dir.deleteFile(t.io, "wal/part-1-2.twal");
    try t.expectError(error.WalHistoryMissing, open(tmp.dir));
    const file = try tmp.dir.openFile(t.io, "wal/part-1-0.twal", .{ .mode = .read_write });
    defer file.close(t.io);
    try file.writePositionalAll(t.io, "x", Log.header_bytes);
    try t.expectError(error.CorruptWalFrame, open(tmp.dir));
}

test "missing and foreign local definitions reject without modifying retained files" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    {
        var wal = try open(tmp.dir);
        defer wal.deinit();
        _ = try wal.log().append(1, 0, 1, 1, .row_delta, "preserve");
    }
    const marker = try tmp.dir.openFile(t.io, "wal/.definition", .{ .mode = .read_write });
    defer marker.close(t.io);
    try marker.writePositionalAll(t.io, &@as([32]u8, @splat(0)), 0);
    try t.expectError(error.IncompatibleDefinition, open(tmp.dir));
    try tmp.dir.deleteFile(t.io, "wal/.definition");
    try t.expectError(error.IncompatibleDefinition, open(tmp.dir));
    const retained = try tmp.dir.readFileAlloc(t.io, "wal/part-1-0.twal", t.allocator, .limited(256));
    defer t.allocator.free(retained);
    try t.expectEqualStrings("preserve", (try Log.decodeFrame(retained)).frame.payload);
}

test "a failed sync poisons the owner and recovery preserves complete uncertain work" {
    const Fault = struct {
        var real: *const std.Io.VTable = undefined;
        var fail: bool = false;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            if (fail) {
                fail = false;
                return error.InputOutput;
            }
            return real.fileSync(context, file);
        }
    };
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    Fault.real = t.io.vtable;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Fault.sync;
    var io = t.io;
    io.vtable = &vtable;
    {
        var wal = try Wal.openDiskWithOptions(t.allocator, io, tmp.dir, "wal", .{});
        defer wal.deinit();
        _ = try wal.log().append(1, 0, 1, 1, .row_delta, "known");
        Fault.fail = true;
        try t.expectError(error.InputOutput, wal.log().append(1, 1, 1, 1, .row_delta, "uncertain"));
        try t.expectError(error.WalRecoveryRequired, wal.log().append(1, 1, 1, 1, .row_delta, "wrong-retry"));
        try t.expectError(error.WalRecoveryRequired, wal.log().tail(1));
    }
    var wal = try open(tmp.dir);
    defer wal.deinit();
    try t.expectEqual(@as(u64, 2), try wal.log().tail(1));
    var batch = try wal.log().read(t.allocator, 1, 1, 1);
    defer batch.deinit();
    try t.expectEqualStrings("uncertain", batch.frames[0].payload);
}

test "disk recovery exceeds the former 64 MiB whole-partition ceiling" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const payload = try t.allocator.alloc(u8, 1024 * 1024);
    defer t.allocator.free(payload);
    @memset(payload, 37);
    {
        var wal = try Wal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{ .segment_bytes = 8 * 1024 * 1024 });
        defer wal.deinit();
        for (0..65) |lsn| _ = try wal.log().append(1, lsn, 1, 1, .row_delta, payload);
        try t.expect(wal.bytes_written > 64 * 1024 * 1024);
    }
    const resident = try t.allocator.alloc(u8, 2 * 1024 * 1024);
    defer t.allocator.free(resident);
    var fixed: std.heap.FixedBufferAllocator = .init(resident);
    var wal = try Wal.openDiskWithOptions(fixed.allocator(), t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    try t.expectEqual(@as(u64, 65), try wal.log().tail(1));
    var batch = try wal.log().read(t.allocator, 1, 64, 1);
    defer batch.deinit();
    try t.expectEqualSlices(u8, payload, batch.frames[0].payload);
}
