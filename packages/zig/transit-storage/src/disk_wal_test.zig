const std = @import("std");
const t = std.testing;
const Wal = @import("LocalWal.zig").LocalWal;
const Log = @import("TransitLog.zig");

fn open(dir: std.Io.Dir) !Wal {
    return Wal.openDiskWithOptions(t.allocator, t.io, dir, "wal", .{ .segment_bytes = 256, .batch_frames = 2 });
}

test "disk WAL opening validates every partition across directory pages" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const options: Wal.DiskOptions = .{ .segment_bytes = Log.alignedFrameSize(8), .batch_frames = 8 };
    {
        var wal = try Wal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", options);
        defer wal.deinit();
        for (1..4) |partition| for (0..128) |lsn| {
            var bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &bytes, partition * 1000 + lsn, .little);
            _ = try wal.log().append(partition, lsn, 3, 5, .row_delta, &bytes);
        };
    }
    {
        var wal = try Wal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", options);
        defer wal.deinit();
        // Opening must verify all retained frames before any caller chooses a
        // partition. On-demand reads cannot substitute for this startup gate.
        try t.expectEqual(@as(u64, 384), wal.disk.?.recovered_frames);
        try t.expectEqual(@as(u64, 3), wal.disk.?.directory_scans);
        for (1..4) |partition| {
            try t.expectEqual(@as(u64, 128), try wal.log().tail(partition));
            var page = try wal.log().read(t.allocator, partition, 127, 1);
            defer page.deinit();
            try t.expectEqual(@as(u64, partition * 1000 + 127), std.mem.readInt(u64, page.frames[0].payload[0..8], .little));
        }
        try t.expectEqual(@as(u64, 384), wal.disk.?.recovered_frames);
        const before_scans = wal.disk.?.directory_scans;
        const before_frames = wal.disk.?.read_frames;
        for (1..4) |partition| {
            var next: u64 = 0;
            while (next < 128) {
                var page = try wal.log().read(t.allocator, partition, next, 8);
                defer page.deinit();
                try t.expectEqual(@as(usize, 8), page.frames.len);
                for (page.frames) |frame| {
                    try t.expectEqual(next, frame.header.lsn);
                    try t.expectEqual(@as(u64, partition * 1000 + next), std.mem.readInt(u64, frame.payload[0..8], .little));
                    next += 1;
                }
            }
        }
        try t.expectEqual(@as(u64, 3), wal.disk.?.directory_scans - before_scans);
        try t.expectEqual(@as(u64, 384), wal.disk.?.read_frames - before_frames);
    }
    {
        const file = try tmp.dir.openFile(t.io, "wal/part-3-127.twal", .{ .mode = .read_write });
        defer file.close(t.io);
        try file.writePositionalAll(t.io, "x", Log.header_bytes);
        try file.sync(t.io);
    }
    try t.expectError(error.CorruptWalFrame, Wal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", options));
}

test "disk WAL direct recovery rejects gaps overlaps and noncanonical segment names" {
    for (0..3) |scenario| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        const options: Wal.DiskOptions = .{ .segment_bytes = 3 * Log.alignedFrameSize(8) };
        {
            var wal = try Wal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", options);
            defer wal.deinit();
            for (0..9) |lsn| {
                var bytes: [8]u8 = undefined;
                std.mem.writeInt(u64, &bytes, lsn, .little);
                _ = try wal.log().append(1, lsn, 3, 5, .row_delta, &bytes);
            }
        }
        if (scenario == 0) {
            try tmp.dir.deleteFile(t.io, "wal/part-1-3.twal");
        } else {
            // An interior overlapping name must not be skipped by a traversal
            // following only decoded successor positions. Aliases also reject.
            const extra = try tmp.dir.createFile(t.io, if (scenario == 1) "wal/part-1-1.twal" else "wal/part-01-0.twal", .{});
            extra.close(t.io);
        }
        try t.expectError(if (scenario == 2) error.InvalidWalDirectory else error.CorruptWalFrame, Wal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", options));
    }
}

test "disk WAL bounded seek hints keep one-frame replay linear and verify cached reads" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    {
        var wal = try Wal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
        defer wal.deinit();
        for (0..256) |lsn| {
            var payload: [8]u8 = undefined;
            std.mem.writeInt(u64, &payload, lsn * 17 + 3, .little);
            _ = try wal.log().append(1, lsn, 1, 1, .row_delta, &payload);
        }
    }
    var wal = try Wal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    const before_frames = wal.disk.?.read_frames;
    const before_scans = wal.disk.?.directory_scans;
    for (0..256) |lsn| {
        var batch = try wal.log().read(t.allocator, 1, lsn, 1);
        defer batch.deinit();
        try t.expectEqual(@as(usize, 1), batch.frames.len);
        try t.expectEqual(lsn, batch.frames[0].header.lsn);
        try t.expectEqual(@as(u64, lsn * 17 + 3), std.mem.readInt(u64, batch.frames[0].payload[0..8], .little));
    }
    try t.expectEqual(@as(u64, 256), wal.disk.?.read_frames - before_frames);
    try t.expectEqual(@as(u64, 1), wal.disk.?.directory_scans - before_scans);
    // Repeated latest reads verify the selected on-disk frame each time.
    const before_latest = wal.disk.?.read_frames;
    for (0..5) |_| {
        var batch = try wal.log().read(t.allocator, 1, 255, 1);
        defer batch.deinit();
        try t.expectEqual(@as(u64, 255), batch.frames[0].header.lsn);
    }
    try t.expectEqual(@as(u64, 5), wal.disk.?.read_frames - before_latest);
    const file = try tmp.dir.openFile(t.io, "wal/part-1-0.twal", .{ .mode = .read_write });
    defer file.close(t.io);
    try file.writePositionalAll(t.io, "x", 255 * Log.alignedFrameSize(8) + Log.header_bytes);
    try t.expectError(error.CorruptWalFrame, wal.log().read(t.allocator, 1, 255, 1));
}

test "disk WAL seek hints survive rollover backward reads eviction and trim" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try Wal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{ .segment_bytes = 512 });
    defer wal.deinit();
    for (0..7) |lsn| _ = try wal.log().append(1, lsn, 1, 1, .row_delta, "data");
    // Reading 0..2 leaves a continuation at the first segment's EOF. Jumping
    // to 5 must traverse the physical successor at 2, then the segment at 4.
    for ([_]u64{ 0, 5, 0, 1, 2, 6, 1, 5, 0 }) |from| {
        var batch = try wal.log().read(t.allocator, 1, from, 2);
        defer batch.deinit();
        try t.expectEqual(@min(2, 7 - from), batch.frames.len);
        for (batch.frames, 0..) |frame, i| try t.expectEqual(from + i, frame.header.lsn);
    }
    // More partitions than descriptor slots evict all derived seek hints.
    for (2..12) |partition| _ = try wal.log().append(partition, 0, 1, 1, .row_delta, "other");
    var recovered = try wal.log().read(t.allocator, 1, 5, 2);
    defer recovered.deinit();
    try t.expectEqual(@as(u64, 5), recovered.frames[0].header.lsn);
    try wal.log().trim(1, 5);
    try t.expectError(error.WalHistoryTrimmed, wal.log().read(t.allocator, 1, 4, 1));
    var retained = try wal.log().read(t.allocator, 1, 5, 2);
    defer retained.deinit();
    try t.expectEqual(@as(usize, 2), retained.frames.len);
    try wal.log().trim(1, 7);
    _ = try wal.log().append(1, 7, 2, 3, .row_delta, "successor");
    var successor = try wal.log().read(t.allocator, 1, 7, 1);
    defer successor.deinit();
    try t.expectEqualStrings("successor", successor.frames[0].payload);
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

test "retired Table definition rejects at each disk WAL gate without resetting history" {
    const current = @import("transit_protocol").Growth.definition_bytes;
    var previous: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&previous, "cd12a1e21afce782c2926a900dfe473fe96bcee962a98cb8670d06dfbed3aa89");
    try t.expect(!std.mem.eql(u8, &previous, &current));
    // Exercise each gate independently, including a copied old frame under
    // current directory/partition markers. Definition bytes are outside the
    // frame CRC/SHA ranges; metadata gets a fresh digest after substitution.
    for (0..3) |gate| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        {
            var wal = try open(tmp.dir);
            defer wal.deinit();
            _ = try wal.log().append(1, 0, 1, 1, .row_delta, "preserve accepted payload");
        }
        const names = [_][]const u8{ "wal/.definition", "wal/part-1.meta", "wal/part-1-0.twal" };
        var originals: [3][]u8 = undefined;
        var owned: usize = 0;
        defer for (originals[0..owned]) |bytes| t.allocator.free(bytes);
        for (names, 0..) |name, i| {
            const bytes = try tmp.dir.readFileAlloc(t.io, name, t.allocator, .limited(256));
            originals[i] = bytes;
            owned += 1;
            if (i != gate) continue;
            const offset: usize = switch (gate) {
                0 => 0,
                1 => 8,
                else => 64,
            };
            @memcpy(bytes[offset..][0..32], &previous);
            if (gate == 1) std.crypto.hash.sha2.Sha256.hash(bytes[0..96], bytes[96..128], .{});
            const file = try tmp.dir.openFile(t.io, name, .{ .mode = .read_write });
            defer file.close(t.io);
            try file.writePositionalAll(t.io, bytes, 0);
            try file.sync(t.io);
            if (gate == 2) try t.expectError(error.IncompatibleDefinition, Log.decodeFrame(bytes));
        }
        // Repeated opens must remain refusals, never fresh initialization or
        // torn-tail repair. Compare complete markers, metadata and payload bytes.
        for (0..2) |_| try t.expectError(error.IncompatibleDefinition, open(tmp.dir));
        for (names, originals) |name, original| {
            const retained = try tmp.dir.readFileAlloc(t.io, name, t.allocator, .limited(256));
            defer t.allocator.free(retained);
            try t.expectEqualSlices(u8, original, retained);
        }
    }
}

test "canceling a cold read before mutation preserves the local log owner" {
    const Fault = struct {
        var real: *const std.Io.VTable = undefined;
        var cancel: bool = false;
        fn openFile(context: ?*anyopaque, dir: std.Io.Dir, name: []const u8, options: std.Io.Dir.OpenFileOptions) std.Io.File.OpenError!std.Io.File {
            if (cancel and std.mem.eql(u8, name, "part-0.meta")) {
                cancel = false;
                return error.Canceled;
            }
            return real.dirOpenFile(context, dir, name, options);
        }
    };
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    Fault.real = t.io.vtable;
    var vtable = t.io.vtable.*;
    vtable.dirOpenFile = Fault.openFile;
    var io = t.io;
    io.vtable = &vtable;
    var wal = try Wal.openDiskWithOptions(t.allocator, io, tmp.dir, "wal", .{});
    defer wal.deinit();
    // Evict the first partition through the real bounded descriptor cache.
    for (0..9) |partition| _ = try wal.log().append(partition, 0, 1, 1, .row_delta, "accepted");
    Fault.cancel = true;
    try t.expectError(error.Canceled, wal.log().tail(0));
    try t.expectEqual(@as(u64, 1), try wal.log().tail(8));
    var batch = try wal.log().read(t.allocator, 0, 0, 1);
    defer batch.deinit();
    try t.expectEqualStrings("accepted", batch.frames[0].payload);
    _ = try wal.log().append(0, 1, 1, 1, .row_delta, "successor");
}

test "disk sync errors poison WAL owners and preserve complete uncertain work" {
    const Fault = struct {
        var real: *const std.Io.VTable = undefined;
        var remaining: usize = 0;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            if (remaining != 0) {
                remaining -= 1;
                if (remaining == 0) return error.InputOutput;
            }
            return real.fileSync(context, file);
        }
    };
    Fault.real = t.io.vtable;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Fault.sync;
    var io = t.io;
    io.vtable = &vtable;
    // Three syncs for append, four when publishing a new segment directory entry.
    for ([_]usize{ 192, 4096 }) |segment_bytes| {
        const sync_count: usize = if (segment_bytes == 192) 4 else 3;
        for (1..sync_count + 1) |failure| {
            var tmp = t.tmpDir(.{});
            defer tmp.cleanup();
            {
                var wal = try Wal.openDiskWithOptions(t.allocator, io, tmp.dir, "wal", .{ .segment_bytes = segment_bytes });
                defer wal.deinit();
                _ = try wal.log().append(1, 0, 1, 1, .row_delta, "known");
                Fault.remaining = failure;
                try t.expectError(error.InputOutput, wal.log().append(1, 1, 1, 1, .row_delta, "uncertain"));
                try t.expectEqual(@as(usize, 0), Fault.remaining);
                try t.expectError(error.WalRecoveryRequired, wal.log().append(1, 1, 1, 1, .row_delta, "wrong-retry"));
                try t.expectError(error.WalRecoveryRequired, wal.log().tail(1));
            }
            var wal = try open(tmp.dir);
            defer wal.deinit();
            try t.expectEqual(@as(u64, 2), try wal.log().tail(1));
            var batch = try wal.log().read(t.allocator, 1, 0, 8);
            defer batch.deinit();
            try t.expectEqual(@as(usize, 2), batch.frames.len);
            try t.expectEqualStrings("known", batch.frames[0].payload);
            try t.expectEqualStrings("uncertain", batch.frames[1].payload);
            _ = try wal.log().append(1, 2, 1, 1, .row_delta, "successor");
        }
    }
}

test "disk recovery syncs complete uncertain frames before publishing a usable frontier" {
    const Fault = struct {
        var real: std.Io = undefined;
        var remaining: usize = 0;
        var seen_frame: bool = false;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            if (remaining != 0) {
                var magic: [4]u8 = undefined;
                const length = file.readPositionalAll(real, &magic, 0) catch 0;
                if (length == magic.len and std.mem.eql(u8, &magic, "TWAL")) seen_frame = true;
                if (seen_frame) {
                    remaining -= 1;
                    if (remaining == 0) return error.InputOutput;
                }
            }
            return real.vtable.fileSync(context, file);
        }
        fn arm(count: usize) void {
            remaining = count;
            seen_frame = false;
        }
    };
    Fault.real = t.io;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Fault.sync;
    var io = t.io;
    io.vtable = &vtable;
    for ([_]usize{ 192, 4096 }) |segment_bytes| for (1..3) |failure| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        const options: Wal.DiskOptions = .{ .segment_bytes = segment_bytes };
        {
            var wal = try Wal.openDiskWithOptions(t.allocator, io, tmp.dir, "wal", options);
            defer wal.deinit();
            _ = try wal.log().append(1, 0, 1, 1, .row_delta, "accepted");
            Fault.arm(1);
            try t.expectError(error.InputOutput, wal.log().append(1, 1, 2, 3, .row_delta, "uncertain"));
        }
        // The complete second frame is visible but its sync failed. Reopening
        // must sync its file and directory before a fence or later append can
        // make metadata depend on it. This checks ordering, not host power loss.
        Fault.arm(failure);
        if (Wal.openDiskWithOptions(t.allocator, io, tmp.dir, "wal", options)) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.TestExpectedError;
        } else |err| try t.expectEqual(error.InputOutput, err);
        try t.expectEqual(@as(usize, 0), Fault.remaining);
        var wal = try Wal.openDiskWithOptions(t.allocator, io, tmp.dir, "wal", options);
        defer wal.deinit();
        try t.expectEqual(@as(u64, 2), try wal.log().tail(1));
        try wal.log().fence(1, 4, 5);
        _ = try wal.log().append(1, 2, 4, 5, .row_delta, "successor");
        var batch = try wal.log().read(t.allocator, 1, 0, 8);
        defer batch.deinit();
        try t.expectEqual(@as(usize, 3), batch.frames.len);
        try t.expectEqualStrings("uncertain", batch.frames[1].payload);
        try t.expectEqualStrings("successor", batch.frames[2].payload);
    };
}

test "disk opening syncs observed metadata before resumed prefix deletion" {
    const Fault = struct {
        var real: std.Io = undefined;
        var directory_inode: std.Io.File.INode = 0;
        var reject_directory: bool = false;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            if (reject_directory) {
                const stat = file.stat(real) catch return error.InputOutput;
                if (stat.kind == .directory and stat.inode == directory_inode) {
                    reject_directory = false;
                    return error.InputOutput;
                }
            }
            return real.vtable.fileSync(context, file);
        }
    };
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    Fault.real = t.io;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Fault.sync;
    var io = t.io;
    io.vtable = &vtable;
    const options: Wal.DiskOptions = .{ .segment_bytes = Log.alignedFrameSize(8) };
    {
        var wal = try Wal.openDiskWithOptions(t.allocator, io, tmp.dir, "wal", options);
        defer wal.deinit();
        _ = try wal.log().append(1, 0, 1, 1, .row_delta, "first");
        _ = try wal.log().append(1, 1, 1, 1, .row_delta, "retained");
        const dir = try tmp.dir.openDir(t.io, "wal", .{ .iterate = true });
        defer dir.close(t.io);
        const file: std.Io.File = .{ .handle = dir.handle, .flags = .{ .nonblocking = false } };
        Fault.directory_inode = (try file.stat(t.io)).inode;
        Fault.reject_directory = true;
        // The new floor is visible after rename; its directory sync fails.
        try t.expectError(error.InputOutput, wal.log().trim(1, 1));
        try t.expect(!Fault.reject_directory);
    }
    Fault.reject_directory = true;
    if (Wal.openDiskWithOptions(t.allocator, io, tmp.dir, "wal", options)) |value| {
        var unexpected = value;
        unexpected.deinit();
        return error.TestExpectedError;
    } else |err| try t.expectEqual(error.InputOutput, err);
    try t.expect(!Fault.reject_directory);
    var wal = try Wal.openDiskWithOptions(t.allocator, io, tmp.dir, "wal", options);
    defer wal.deinit();
    try wal.log().trim(1, 1);
    try t.expectError(error.FileNotFound, tmp.dir.openFile(t.io, "wal/part-1-0.twal", .{}));
    var retained = try wal.log().read(t.allocator, 1, 1, 1);
    defer retained.deinit();
    try t.expectEqualStrings("retained", retained.frames[0].payload);
}

test "disk space errors preserve accepted WAL bytes and uncertain complete frames" {
    const Fault = struct {
        var real: std.Io = undefined;
        var prefix: ?usize = null;
        fn write(context: ?*anyopaque, file: std.Io.File, header: []const u8, data: []const []const u8, splat: usize, offset: u64) std.Io.File.WritePositionalError!usize {
            if (prefix) |count| {
                prefix = null;
                std.debug.assert(header.len == 0 and data.len == 1 and splat == 1);
                try file.writePositionalAll(real, data[0][0..@min(count, data[0].len)], offset);
                return error.NoSpaceLeft;
            }
            return real.vtable.fileWritePositional(context, file, header, data, splat, offset);
        }
    };
    Fault.real = t.io;
    var vtable = t.io.vtable.*;
    vtable.fileWritePositional = Fault.write;
    var io = t.io;
    io.vtable = &vtable;
    // Exercise both an existing segment and rollover. The injected syscall
    // error occurs before any bytes, after a torn header, or after a full frame.
    // It models ENOSPC propagation; it does not fill the host filesystem.
    for ([_]usize{ 192, 4096 }) |segment_bytes| {
        for ([_]usize{ 0, 13, std.math.maxInt(usize) }) |prefix| {
            var tmp = t.tmpDir(.{});
            defer tmp.cleanup();
            {
                var wal = try Wal.openDiskWithOptions(t.allocator, io, tmp.dir, "wal", .{ .segment_bytes = segment_bytes });
                defer wal.deinit();
                _ = try wal.log().append(1, 0, 3, 5, .row_delta, "accepted");
                Fault.prefix = prefix;
                try t.expectError(error.NoSpaceLeft, wal.log().append(1, 1, 7, 9, .row_delta, "uncertain"));
                try t.expectEqual(null, Fault.prefix);
                try t.expectError(error.WalRecoveryRequired, wal.log().tail(1));
                try t.expectError(error.WalRecoveryRequired, wal.log().read(t.allocator, 1, 0, 1));
                try t.expectError(error.WalRecoveryRequired, wal.log().append(1, 1, 3, 5, .row_delta, "wrong-retry"));
            }
            var wal = try open(tmp.dir);
            defer wal.deinit();
            const complete = prefix == std.math.maxInt(usize);
            const tail: u64 = if (complete) 2 else 1;
            try t.expectEqual(tail, try wal.log().tail(1));
            var batch = try wal.log().read(t.allocator, 1, 0, 8);
            defer batch.deinit();
            try t.expectEqual(tail, batch.frames.len);
            try t.expectEqualStrings("accepted", batch.frames[0].payload);
            try t.expectEqual(@as(u64, 0), batch.frames[0].header.lsn);
            try t.expectEqual(@as(u64, 3), batch.frames[0].header.writer_epoch);
            if (complete) {
                try t.expectEqualStrings("uncertain", batch.frames[1].payload);
                try t.expectEqual(@as(u64, 1), batch.frames[1].header.lsn);
                try t.expectEqual(@as(u64, 7), batch.frames[1].header.writer_epoch);
                try t.expectEqual(@as(u64, 9), batch.frames[1].header.policy_epoch);
                try t.expectError(error.StaleWriterEpoch, wal.log().append(1, tail, 3, 9, .row_delta, "stale"));
                try t.expectError(error.StalePolicyEpoch, wal.log().append(1, tail, 7, 5, .row_delta, "stale"));
            }
            _ = try wal.log().append(1, tail, 7, 9, .row_delta, "successor");
            var successor = try wal.log().read(t.allocator, 1, tail, 1);
            defer successor.deinit();
            try t.expectEqualStrings("successor", successor.frames[0].payload);
        }
    }
}

test "canceling recovery after truncation still requires reopening the log owner" {
    const Fault = struct {
        var real: *const std.Io.VTable = undefined;
        var cancel: bool = false;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            if (cancel) {
                cancel = false;
                return error.Canceled;
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
        for (0..9) |partition| _ = try wal.log().append(partition, 0, 1, 1, .row_delta, "accepted");
        var bytes: [256]u8 = undefined;
        const encoded = try Log.encodeFrame(0, 1, 1, 1, 0, .row_delta, "unacknowledged", &bytes);
        try appendRaw(tmp.dir, "wal/part-0-0.twal", encoded[0 .. encoded.len - 7]);
        Fault.cancel = true;
        try t.expectError(error.Canceled, wal.log().tail(0));
        try t.expectError(error.WalRecoveryRequired, wal.log().tail(8));
    }
    var recovered = try open(tmp.dir);
    defer recovered.deinit();
    try t.expectEqual(@as(u64, 1), try recovered.log().tail(0));
    _ = try recovered.log().append(0, 1, 1, 1, .row_delta, "successor");
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
