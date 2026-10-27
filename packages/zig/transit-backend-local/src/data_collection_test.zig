const std = @import("std");
const t = std.testing;
const storage = @import("transit_storage");
const local = @import("root.zig");
const Fixture = @import("collection_test.zig").Fixture;
const Graph = struct {
    pub const Work = struct { key: storage.TreeStore.pages.Bytes(256), meta: storage.TransitObjectStore.ObjectMeta };
    pub fn fromFrame(allocator: std.mem.Allocator, frame: storage.TransitLog.Frame) !Work {
        const parsed = try std.json.parseFromSlice(Work, allocator, frame.payload, .{});
        defer parsed.deinit();
        return parsed.value;
    }
    pub fn step(_: std.mem.Allocator, _: *storage.TreeStore, _: storage.TransitLog.Log, work: *Work, workspace: anytype) !bool {
        try workspace.mark(work.key.slice(), work.meta);
        return true;
    }
    pub fn collectible(key: []const u8) bool {
        return std.mem.startsWith(u8, key, "fixture/") or std.mem.startsWith(u8, key, "data-index/") or std.mem.startsWith(u8, key, "data-maintenance/");
    }
};
const Collection = local.DataCollection.Collector(Graph);
const SyncFault = struct {
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

fn until(f: *Fixture, collection: *Collection, phase: @FieldType(Collection.State, "phase")) !void {
    for (0..1000) |_| {
        if ((try collection.current()).?.phase == phase) return;
        if (!try collection.step(&f.engine, .{ .unix_ms = f.now })) return error.CollectionStopped;
    }
    return error.FixtureBudget;
}

fn cleanup(f: *Fixture, collection: *Collection) !void {
    try t.expectEqual(.complete, (try collection.current()).?.phase);
    for (0..1000) |_| {
        const disk = f.owner.data_allocations.queue.disk.?;
        const entries = disk.trim_entries;
        const frames = disk.trim_frames;
        const segments = disk.trim_segments;
        const progressed = try collection.step(&f.engine, .{ .unix_ms = f.now });
        try t.expect(disk.trim_entries - entries <= 32);
        try t.expect(disk.trim_frames - frames <= 1);
        try t.expect(disk.trim_segments - segments <= 1);
        if (!progressed) return;
    }
    return error.FixtureBudget;
}

test "direct collection resumes deletion while preserving accepted and newer reused content" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.open(tmp.dir, true);
    defer f.close();
    var collection: Collection = .{ .backend = &f.owner };
    for ([_][]const u8{ "fixture/live", "fixture/reused", "fixture/orphan", "external/keep" }) |key| try f.owner.put(key, key, false);
    const live_meta = (try f.owner.objects.objectStore().head("fixture/live")).?;
    const encoded = try std.json.Stringify.valueAlloc(t.allocator, Graph.Work{ .key = try .init("fixture/live"), .meta = live_meta }, .{});
    defer t.allocator.free(encoded);
    var data: local.DataStore = .{ .backend = &f.owner };
    _ = try data.log().append(1, 0, 1, f.engine.head.authorization.revision + 1, .row_delta, encoded);
    const fence = try f.submit(.{ .storage_fence = {} });
    try collection.start(&f.engine, fence);
    try t.expectError(error.ActiveStorageCollection, collection.start(&f.engine, fence));
    try until(&f, &collection, .wait);
    try t.expect(!try collection.step(&f.engine, .{ .unix_ms = f.now }));
    try t.expect(try f.owner.objects.objectStore().head("fixture/orphan") != null);
    f.now = (try collection.current()).?.grace_until_ms + 1;
    try t.expectError(error.CollectionTimeFenceRequired, collection.step(&f.engine, .{ .unix_ms = f.now }));
    _ = try f.submit(.{ .storage_fence = {} });
    try until(&f, &collection, .deleting);
    const pending = (try collection.current()).?.pending.?;
    try t.expectEqualStrings("fixture/reused", pending.allocation.object_key.slice());
    // A paused deletion's candidate cannot remove a newer creator's marker.
    try f.owner.put("fixture/reused", "fixture/reused", false);
    f.close();
    try f.open(tmp.dir, false);
    try until(&f, &collection, .complete);
    const completed = (try collection.current()).?;
    try t.expect(!completed.aborted);
    try t.expect(completed.reclaimed_objects != 0);
    try t.expect(try f.owner.objects.objectStore().head("fixture/orphan") == null);
    for ([_][]const u8{ "fixture/live", "fixture/reused", "external/keep" }) |key| {
        var output: [64]u8 = undefined;
        try t.expectEqualStrings(key, try f.owner.read(key, &output));
    }
    try t.expectEqual(@as(u64, 1), try data.log().tail(1));
    try cleanup(&f, &collection);
    f.close();
    try f.open(tmp.dir, false);
    try t.expectEqualDeep(completed, (try collection.current()).?);
    try t.expect(try f.owner.objects.objectStore().head("fixture/orphan") == null);
}

test "direct collection aborts incomplete owner cuts before physical sweep" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.open(tmp.dir, true);
    defer f.close();
    var collection: Collection = .{ .backend = &f.owner };
    try f.owner.put("fixture/orphan", "unaccepted", false);
    var data: local.DataStore = .{ .backend = &f.owner };
    _ = try data.log().append(1, 0, 1, f.engine.head.authorization.revision + 1, .row_delta, "never decoded");
    const fence = try f.submit(.{ .storage_fence = {} });
    try collection.start(&f.engine, fence);
    // Removing required history cannot make discovery treat this owner as empty.
    try f.owner.wal.trimUpTo(1, 1);
    try t.expect(try collection.step(&f.engine, .{ .unix_ms = f.now }));
    const state = (try collection.current()).?;
    try t.expect(state.aborted and state.phase == .complete);
    try t.expectEqual(@as(u64, 0), state.reclaimed_objects);
    try t.expect(try f.owner.objects.objectStore().head("fixture/orphan") != null);
}

test "direct collection resumes every deletion sync failure without losing other ownership" {
    const Fault = SyncFault;
    Fault.real = t.io.vtable;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Fault.sync;
    var io = t.io;
    io.vtable = &vtable;
    var schedules: usize = 0;
    var failure: usize = 0;
    while (failure <= schedules) : (failure += 1) {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var f: Fixture = .{};
        try f.openWithIo(tmp.dir, true, io);
        var collection: Collection = .{ .backend = &f.owner };
        {
            defer f.close();
            try f.owner.put("fixture/remove", "retired private bytes", false);
            try f.owner.put("external/keep", "separate owner", false);
            const fence = try f.submit(.{ .storage_fence = {} });
            try collection.start(&f.engine, fence);
            try until(&f, &collection, .wait);
            f.now = (try collection.current()).?.grace_until_ms + 1;
            _ = try f.submit(.{ .storage_fence = {} });
            try until(&f, &collection, .deleting);
            Fault.calls = 0;
            Fault.remaining = failure;
            if (failure == 0) {
                try t.expect(try collection.step(&f.engine, .{ .unix_ms = f.now }));
                schedules = Fault.calls;
                try t.expect(schedules > 0 and schedules < 32);
            } else {
                try t.expectError(error.InputOutput, collection.step(&f.engine, .{ .unix_ms = f.now }));
                try t.expectEqual(@as(usize, 0), Fault.remaining);
            }
        }
        try f.open(tmp.dir, false);
        defer f.close();
        const head = f.engine.head;
        try until(&f, &collection, .complete);
        try t.expect(try f.owner.objects.objectStore().head("fixture/remove") == null);
        var buffer: [64]u8 = undefined;
        try t.expectEqualStrings("separate owner", try f.owner.read("external/keep", &buffer));
        try t.expectEqualDeep(head, f.engine.head);
        try cleanup(&f, &collection);
        try t.expectEqualDeep(head, f.engine.head);
    }
    std.debug.print("Direct collection deletion: {d} sync failures recovered.\n", .{schedules});
}

test "direct collection resumes every mark checkpoint sync failure with complete live ownership" {
    const Fault = SyncFault;
    Fault.real = t.io.vtable;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Fault.sync;
    var io = t.io;
    io.vtable = &vtable;
    var schedules: usize = 0;
    var failure: usize = 0;
    while (failure <= schedules) : (failure += 1) {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var f: Fixture = .{};
        try f.openWithIo(tmp.dir, true, io);
        var collection: Collection = .{ .backend = &f.owner };
        {
            defer f.close();
            try f.owner.put("fixture/live", "accepted", false);
            try f.owner.put("fixture/remove", "private", false);
            const meta = (try f.owner.objects.objectStore().head("fixture/live")).?;
            const bytes = try std.json.Stringify.valueAlloc(t.allocator, Graph.Work{ .key = try .init("fixture/live"), .meta = meta }, .{});
            defer t.allocator.free(bytes);
            var data: local.DataStore = .{ .backend = &f.owner };
            _ = try data.log().append(1, 0, 1, f.engine.head.authorization.revision + 1, .row_delta, bytes);
            try collection.start(&f.engine, try f.submit(.{ .storage_fence = {} }));
            Fault.calls = 0;
            Fault.remaining = failure;
            if (failure == 0) {
                try t.expect(try collection.step(&f.engine, .{ .unix_ms = f.now }));
                schedules = Fault.calls;
                try t.expect(schedules > 2 and schedules < 100);
            } else {
                try t.expectError(error.InputOutput, collection.step(&f.engine, .{ .unix_ms = f.now }));
                try t.expectEqual(@as(usize, 0), Fault.remaining);
            }
            try t.expect(try f.owner.objects.objectStore().head("fixture/live") != null);
            try t.expect(try f.owner.objects.objectStore().head("fixture/remove") != null);
        }
        try f.open(tmp.dir, false);
        defer f.close();
        try until(&f, &collection, .wait);
        f.now = (try collection.current()).?.grace_until_ms + 1;
        _ = try f.submit(.{ .storage_fence = {} });
        try until(&f, &collection, .complete);
        var bytes: [64]u8 = undefined;
        try t.expectEqualStrings("accepted", try f.owner.read("fixture/live", &bytes));
        try t.expect(try f.owner.objects.objectStore().head("fixture/remove") == null);
    }
    std.debug.print("Direct collection marking: {d} sync failures recovered.\n", .{schedules});
}

test "direct collection drops an unpublished newer intent without deleting its older owner" {
    const Allocations = @import("DataAllocations.zig");
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
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    var original: Allocations.Allocation = undefined;
    try f.openWithIo(tmp.dir, true, io);
    {
        defer f.close();
        try f.owner.put("fixture/reuse", "old publication", false);
        const meta = (try f.owner.objects.objectStore().head("fixture/reuse")).?;
        original = try Allocations.Allocation.init(1, "fixture/reuse", meta);
        _ = try f.submit(.{ .storage_fence = {} });
        var attempted = original;
        attempted.epoch = 2;
        // Three WAL syncs publish the reuse intent. Fail the following marker
        // file sync, leaving the old marker and a newer uncompleted intent.
        Fault.remaining = 4;
        try t.expectError(error.InputOutput, f.owner.data_allocations.record(attempted));
        try t.expectEqual(@as(usize, 0), Fault.remaining);
        try t.expectEqualDeep(original, (try f.owner.data_allocations.latest(original.name())).?);
        try t.expectEqual(@as(u64, 2), (try f.owner.data_allocations.current()).tail);
        // A previous retained pass can move the old owning allocation behind
        // that unsuccessful reuse intent in the FIFO.
        try f.owner.data_allocations.consume(0, original, true);
    }
    try f.open(tmp.dir, false);
    defer f.close();
    var collection: Collection = .{ .backend = &f.owner };
    const fence = try f.submit(.{ .storage_fence = {} });
    try collection.start(&f.engine, fence);
    try until(&f, &collection, .wait);
    f.now = (try collection.current()).?.grace_until_ms + 1;
    _ = try f.submit(.{ .storage_fence = {} });
    try until(&f, &collection, .deleting);
    try t.expectEqual(@as(u64, 2), (try collection.current()).?.pending.?.allocation.epoch);
    try t.expect(try collection.step(&f.engine, .{ .unix_ms = f.now }));
    try t.expectEqualDeep(original, (try f.owner.data_allocations.latest(original.name())).?);
    try t.expect(try f.owner.objects.objectStore().head("fixture/reuse") != null);
    try until(&f, &collection, .complete);
    try t.expect(try f.owner.data_allocations.latest(original.name()) == null);
    try t.expect(try f.owner.objects.objectStore().head("fixture/reuse") == null);
}

test "direct collection quota and corrupted progress cannot authorize deletion" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.open(tmp.dir, true);
    defer f.close();
    var collection: Collection = .{ .backend = &f.owner };
    try f.owner.put("fixture/orphan", "unaccepted", false);
    try collection.start(&f.engine, try f.submit(.{ .storage_fence = {} }));
    const before = (try collection.current()).?;
    const limits = f.owner.limits;
    f.owner.limits.bytes = f.owner.allocated;
    f.owner.limits.control_bytes = 0;
    try t.expectError(error.StorageQuota, collection.step(&f.engine, .{ .unix_ms = f.now }));
    try t.expectEqualDeep(before, (try collection.current()).?);
    try t.expect(try f.owner.objects.objectStore().head("fixture/orphan") != null);
    f.owner.limits = limits;
    const file = try f.owner.directory.openFile(t.io, ".data-collection", .{ .mode = .read_write });
    defer file.close(t.io);
    var original: [1]u8 = undefined;
    try t.expectEqual(@as(usize, 1), try file.readPositionalAll(t.io, &original, 0));
    try file.writePositionalAll(t.io, "!", 0);
    try t.expectError(error.InvalidStorageCollection, collection.step(&f.engine, .{ .unix_ms = f.now }));
    try t.expect(try f.owner.objects.objectStore().head("fixture/orphan") != null);
    try file.writePositionalAll(t.io, &original, 0);
    try until(&f, &collection, .wait);
    f.now = (try collection.current()).?.grace_until_ms + 1;
    _ = try f.submit(.{ .storage_fence = {} });
    try until(&f, &collection, .deleting);
    const pending = (try collection.current()).?.pending.?.allocation;
    const marker = try f.owner.data_allocations.directory.openFile(t.io, &pending.name(), .{ .mode = .read_write });
    defer marker.close(t.io);
    try t.expectEqual(@as(usize, 1), try marker.readPositionalAll(t.io, &original, 0));
    try marker.writePositionalAll(t.io, "!", 0);
    try t.expectError(error.InvalidDataAllocation, collection.step(&f.engine, .{ .unix_ms = f.now }));
    try t.expect(try f.owner.objects.objectStore().head("fixture/orphan") != null);
    try marker.writePositionalAll(t.io, &original, 0);
    try until(&f, &collection, .complete);
    try t.expect(try f.owner.objects.objectStore().head("fixture/orphan") == null);
}
