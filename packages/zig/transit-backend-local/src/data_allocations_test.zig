const std = @import("std");
const t = std.testing;
const Allocations = @import("DataAllocations.zig");
const Files = @import("LocalFiles.zig");
const Budget = @import("transit_fuze").MemoryBudget;

fn allocation(epoch: u64, key: []const u8) !Allocations.Allocation {
    return .init(epoch, key, .{ .size = 7, .sha256 = @splat(37) });
}

test "allocation source activity survives carry, maintenance allocations, trim and reopen" {
    inline for (.{ Allocations, @import("NativeAllocations.zig") }) |Queue| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        const native = Queue != Allocations;
        try tmp.dir.createDirPath(t.io, if (native) "native-allocations" else "data-allocations");
        const source: Queue.Allocation = if (native)
            .{ .epoch = 1, .kind = .block, .address = @splat(17), .meta = .{ .size = 7, .sha256 = @splat(37) } }
        else
            try allocation(1, "segments/source.data");
        const bookkeeping: Queue.Allocation = if (native)
            .{ .epoch = 1, .kind = .page, .address = @splat(18), .meta = .{ .size = 7, .sha256 = @splat(38) } }
        else
            try allocation(1, "data-maintenance/marks.data");
        {
            var queue = try Queue.open(t.allocator, t.io, tmp.dir);
            defer queue.deinit();
            try t.expectEqual(@as(u64, 0), (try queue.current()).source_activity);
            try t.expect(try queue.record(source));
            try t.expect(!try queue.record(source));
            try t.expect(try queue.recordTracked(bookkeeping, false));
            try t.expectEqual(@as(u64, 1), (try queue.current()).source_activity);
            try queue.consume(0, source, true);
            try queue.consume(1, bookkeeping, false);
            try queue.consume(2, source, false);
            try queue.consumeEmpty(5);
            try queue.trim();
            try t.expectEqualDeep(Queue.QueueHead{ .tail = 6, .cursor = 5, .source_activity = 1 }, try queue.current());
        }
        var reopened = try Queue.open(t.allocator, t.io, tmp.dir);
        defer reopened.deinit();
        try t.expectEqualDeep(Queue.QueueHead{ .tail = 6, .cursor = 5, .source_activity = 1 }, try reopened.current());
        var reused = source;
        reused.epoch = 2;
        try t.expect(try reopened.record(reused));
        try t.expectEqual(@as(u64, 2), (try reopened.current()).source_activity);
        try t.expectEqual(@as(u64, 2), (try reopened.at(6)).source_activity);
        try t.expect(!try reopened.record(reused));
        try t.expectEqual(@as(u64, 2), (try reopened.current()).source_activity);
    }
}

test "direct allocation FIFO protects a reused key from older removal across reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(t.io, "data-allocations");
    const first = try allocation(1, "segments/shared.data");
    const reused = try allocation(2, first.object_key.slice());
    {
        var queue = try Allocations.open(t.allocator, t.io, tmp.dir);
        defer queue.deinit();
        try t.expect(try queue.record(first));
        try t.expect(!try queue.record(first));
        try t.expectEqual(@as(u64, 1), (try queue.current()).tail);
        try t.expect(try queue.record(reused));
        try t.expectEqualDeep(reused, (try queue.latest(first.name())).?);
        try t.expectError(error.AllocationConflict, queue.remove(first));
        try t.expectError(error.StaleStorageEpoch, queue.record(first));
        var conflicting = reused;
        conflicting.meta.sha256[0] ^= 1;
        try t.expectError(error.ImmutableObjectConflict, queue.record(conflicting));
        try t.expectEqual(@as(u64, 2), (try queue.current()).tail);
        try queue.consume(0, first, false);
        try t.expectError(error.AllocationConflict, queue.consume(0, first, false));
        try queue.trim();
    }
    var queue = try Allocations.open(t.allocator, t.io, tmp.dir);
    defer queue.deinit();
    try t.expectEqualDeep(reused, (try queue.latest(first.name())).?);
    try t.expectEqualDeep(reused, (try queue.at(1)).item.?);
    try t.expectEqual(@as(u64, 1), (try queue.current()).cursor);
    try queue.consume(1, reused, true);
    try t.expectEqualDeep(reused, (try queue.at(3)).item.?);
    try queue.consumeEmpty(3);
    try t.expectEqual(@as(u64, 3), (try queue.current()).cursor);
    try queue.remove(reused);
    try queue.remove(reused);
    try queue.consume(3, reused, false);
    try queue.trim();
    try t.expectEqual(null, try queue.latest(reused.name()));
}

test "direct allocation inventory grows on disk within a fixed allocation budget" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(t.io, "data-allocations");
    var budget: Budget = .{ .parent = t.allocator, .limit = 128 * 1024 };
    {
        var queue = try Allocations.open(budget.allocator(), t.io, tmp.dir);
        defer queue.deinit();
        const count = 193;
        for (0..count) |i| {
            var key: [64]u8 = undefined;
            const item = try allocation(1, try std.fmt.bufPrint(&key, "pages/{d}.data", .{i}));
            try t.expect(try queue.record(item));
        }
        try t.expectEqual(@as(u64, count), (try queue.current()).tail);
        for (0..count) |i| {
            const item = (try queue.at(i)).item.?;
            try t.expectEqualDeep(item, (try queue.latest(item.name())).?);
            try queue.remove(item);
            try queue.consume(i, item, false);
        }
        const end = (try queue.current()).tail;
        try t.expectEqual(@as(u64, count * 2), end);
        while ((try queue.current()).cursor < end) {
            const before = (try queue.current()).cursor;
            try queue.consumeEmpty(end);
            try t.expectEqual(@min(before + 64, end), (try queue.current()).cursor);
            try queue.trim();
        }
        try t.expect(budget.peak < budget.limit);
    }
    try t.expectEqual(@as(usize, 0), budget.used);
    var reopened = try Allocations.open(budget.allocator(), t.io, tmp.dir);
    defer reopened.deinit();
    try t.expectEqual(@as(u64, 386), (try reopened.current()).cursor);
    try t.expect((try reopened.current()).tail > 386);
}

test "direct allocation cleanup resumes bounded units through its original consumed prefix" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(t.io, "data-allocations");
    const kept = try allocation(1, "pages/retained.data");
    {
        var queue = try Allocations.open(t.allocator, t.io, tmp.dir);
        defer queue.deinit();
        queue.queue.disk.?.options.segment_bytes = 2048;
        for (0..40) |i| {
            var key: [64]u8 = undefined;
            const item = try allocation(1, try std.fmt.bufPrint(&key, "pages/consumed-{d}.data", .{i}));
            _ = try queue.record(item);
            if ((try queue.at((try queue.current()).cursor)).item == null) try queue.consumeEmpty((try queue.current()).tail);
            try queue.remove(item);
            try queue.consume((try queue.current()).cursor, item, false);
        }
        _ = try queue.record(kept);
        try t.expect(!try queue.trimUnit());
        // The floor survived, but directory enumeration has not finished.
    }
    var queue = try Allocations.open(t.allocator, t.io, tmp.dir);
    defer queue.deinit();
    const cursor = (try queue.current()).cursor;
    const disk = queue.queue.disk.?;
    var units: usize = 0;
    while (true) {
        const entries = disk.trim_entries;
        const frames = disk.trim_frames;
        const segments = disk.trim_segments;
        const complete = try queue.trimUnit();
        try t.expect(disk.trim_entries - entries <= 32);
        try t.expect(disk.trim_frames - frames <= 1);
        try t.expect(disk.trim_segments - segments <= 1);
        if (complete) break;
        units += 1;
        try t.expect(units < 300);
    }
    try t.expect(disk.trim_segments > 1 and units > 1);
    try t.expectEqual(cursor, (try queue.current()).cursor);
    try t.expectEqualDeep(kept, (try queue.latest(kept.name())).?);
    try t.expectEqualDeep(kept, (try queue.at((try queue.current()).tail - 1)).item.?);
}

fn rehash(bytes: *[Allocations.record_bytes]u8) void {
    std.crypto.hash.sha2.Sha256.hash(bytes[0..480], bytes[480..512], .{});
}

test "direct allocation markers reject malformed bytes foreign definitions and wrong key names" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(t.io, "data-allocations");
    var queue = try Allocations.open(t.allocator, t.io, tmp.dir);
    defer queue.deinit();
    const item = try allocation(1, "pages/original.data");
    try t.expect(try queue.record(item));
    var bytes: [Allocations.record_bytes]u8 = undefined;
    _ = (try Files.read(t.io, queue.directory, &item.name(), &bytes)).?;
    const original = bytes;
    bytes[8] ^= 1;
    try Files.save(t.io, queue.directory, &item.name(), &bytes, true);
    try t.expectError(error.IncompatibleDefinition, queue.latest(item.name()));
    bytes = original;
    bytes[56] ^= 1;
    try Files.save(t.io, queue.directory, &item.name(), &bytes, true);
    try t.expectError(error.InvalidDataAllocation, queue.latest(item.name()));
    bytes = original;
    bytes[50] = 1;
    rehash(&bytes);
    try Files.save(t.io, queue.directory, &item.name(), &bytes, true);
    try t.expectError(error.InvalidDataAllocation, queue.latest(item.name()));
    bytes = original;
    bytes[351] = 1;
    rehash(&bytes);
    try Files.save(t.io, queue.directory, &item.name(), &bytes, true);
    try t.expectError(error.InvalidPageValue, queue.latest(item.name()));
    try Files.save(t.io, queue.directory, &item.name(), &original, true);
    const wrong = try allocation(1, "pages/different.data");
    try Files.save(t.io, queue.directory, &wrong.name(), &original, false);
    try t.expectError(error.InvalidDataAllocation, queue.latest(wrong.name()));
    try t.expectEqualDeep(item, (try queue.latest(item.name())).?);
    try t.expectEqual(@as(u64, 1), (try queue.current()).tail);
    try t.expectError(error.InvalidDataAllocation, allocation(0, "pages/invalid.data"));
    try t.expectError(error.InvalidDataAllocation, allocation(1, "native/p/reserved"));
}

test "direct allocation reopen refuses lost inventory instead of resetting latest markers" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(t.io, "data-allocations");
    const item = try allocation(1, "pages/retained.data");
    {
        var queue = try Allocations.open(t.allocator, t.io, tmp.dir);
        defer queue.deinit();
        try t.expect(try queue.record(item));
    }
    try tmp.dir.deleteTree(t.io, "data-allocations/queue");
    try t.expectError(error.MissingAllocationHistory, Allocations.open(t.allocator, t.io, tmp.dir));
    try t.expectError(error.FileNotFound, tmp.dir.openDir(t.io, "data-allocations/queue", .{}));
    const directory = try tmp.dir.openDir(t.io, "data-allocations", .{});
    defer directory.close(t.io);
    var bytes: [Allocations.record_bytes]u8 = undefined;
    try t.expect(try Files.read(t.io, directory, &item.name(), &bytes) != null);
}

test "direct allocation intents and newer reuse survive every publication sync uncertainty" {
    const Fault = struct {
        var real: *const std.Io.VTable = undefined;
        var remaining: usize = 0;
        var calls: usize = 0;
        var mutex: std.Io.Mutex = .init;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            try mutex.lock(t.io);
            defer mutex.unlock(t.io);
            calls += 1;
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
    for ([_]bool{ false, true }) |reuse| {
        const first = try allocation(1, "segments/sync.data");
        const wanted = try allocation(if (reuse) 2 else 1, first.object_key.slice());
        var schedules: usize = 0;
        var failure: usize = 0;
        while (failure <= schedules) : (failure += 1) {
            var tmp = t.tmpDir(.{});
            defer tmp.cleanup();
            try tmp.dir.createDirPath(t.io, "data-allocations");
            {
                var queue = try Allocations.open(t.allocator, io, tmp.dir);
                defer queue.deinit();
                if (reuse) try t.expect(try queue.record(first));
                Fault.calls = 0;
                Fault.remaining = failure;
                if (failure == 0) {
                    try t.expect(try queue.record(wanted));
                    schedules = Fault.calls;
                    try t.expect(schedules > 0 and schedules < 24);
                } else {
                    try t.expectError(error.InputOutput, queue.record(wanted));
                    try t.expectEqual(@as(usize, 0), Fault.remaining);
                }
            }
            var queue = try Allocations.open(t.allocator, t.io, tmp.dir);
            defer queue.deinit();
            _ = try queue.record(wanted);
            try t.expectEqualDeep(wanted, (try queue.latest(wanted.name())).?);
            const head = try queue.current();
            try t.expectEqual(@as(u64, 0), head.cursor);
            try t.expectEqualDeep(wanted, (try queue.at(head.tail - 1)).item.?);
            try t.expect(!try queue.record(wanted));
            try t.expectEqualDeep(head, try queue.current());
            if (reuse) try t.expectError(error.AllocationConflict, queue.remove(first));
        }
    }
}
