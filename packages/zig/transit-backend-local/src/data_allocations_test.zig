const std = @import("std");
const t = std.testing;
const Allocations = @import("DataAllocations.zig");
const Files = @import("LocalFiles.zig");
const Budget = @import("transit_fuze").MemoryBudget;

fn allocation(epoch: u64, key: []const u8) !Allocations.Allocation {
    return .init(epoch, key, .{ .size = 7, .sha256 = @splat(37) });
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
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
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
