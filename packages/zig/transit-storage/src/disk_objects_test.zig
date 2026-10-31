const std = @import("std");
const t = std.testing;
const Store = @import("LocalSegmentStore.zig").LocalSegmentStore;
const Disk = @import("DiskObjects.zig");

fn hash(bytes: []const u8) [32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}
fn open(dir: std.Io.Dir) !Store {
    return Store.openDiskAt(t.allocator, t.io, dir, "objects");
}
test "independent disk handles cannot publish using a stale cached precondition" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var first = try open(tmp.dir);
    defer first.deinit();
    var second = try open(tmp.dir);
    defer second.deinit();
    const key = "manifest/17/head.tman";
    try t.expect(try first.objectStore().putConditional(key, .if_none_match, "initial"));
    const a = (try first.objectStore().head(key)).?;
    const b = (try second.objectStore().head(key)).?;
    try t.expectEqualDeep(a, b);
    try t.expect(try first.objectStore().putConditional(key, .{ .if_match = a.sha256 }, "winner"));
    try t.expect(!try second.objectStore().putConditional(key, .{ .if_match = b.sha256 }, "lost-update"));
    try t.expect(!try second.objectStore().putConditional(key, .if_none_match, "duplicate"));
    var out: [64]u8 = undefined;
    try t.expectEqualStrings("winner", try second.objectStore().getRange(key, 0, out.len, &out));
    try t.expectEqual(@as(usize, 0), first.objects.items.len);
    try t.expectEqual(@as(usize, 0), second.objects.items.len);
}

test "concurrent local publishers have exactly one winner for each precondition" {
    const Writer = struct {
        fn run(store: *Store, value: []const u8) !bool {
            return store.objectStore().putConditional("manifest/race", .if_none_match, value);
        }
    };
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var a = try open(tmp.dir);
    defer a.deinit();
    var b = try open(tmp.dir);
    defer b.deinit();
    var first = try t.io.concurrent(Writer.run, .{ &a, "first" });
    defer _ = first.cancel(t.io) catch {};
    var second = try t.io.concurrent(Writer.run, .{ &b, "second" });
    defer _ = second.cancel(t.io) catch {};
    const left = try first.await(t.io);
    const right = try second.await(t.io);
    try t.expect(left != right);
    var out: [64]u8 = undefined;
    try t.expectEqualStrings(if (left) "first" else "second", try a.objectStore().getRange("manifest/race", 0, out.len, &out));
}

test "one disk facade supports concurrent publishers and counts completed reads" {
    const Worker = struct {
        fn run(store: *Store, start: *std.Io.Event, id: usize) anyerror!bool {
            try start.wait(t.io);
            var key: [32]u8 = undefined;
            const path = try std.fmt.bufPrint(&key, "independent/{d}", .{id});
            _ = try store.objectStore().putImmutable(path, "bytes", hash("bytes"));
            // Same-key immutable retries retain one value; conditional writers
            // still have one winner even when they share a facade and counters.
            _ = try store.objectStore().putImmutable("shared", "bytes", hash("bytes"));
            const won = try store.objectStore().putConditional("head", .if_none_match, "bytes");
            try store.confirmImmutableObject(path, .{ .size = 5, .sha256 = hash("bytes") });
            try store.confirmImmutableObject("shared", .{ .size = 5, .sha256 = hash("bytes") });
            var out: [5]u8 = undefined;
            try t.expectEqualStrings("bytes", try store.objectStore().getRange(path, 0, out.len, &out));
            try t.expectEqualStrings("bytes", try store.objectStore().getRange("shared", 0, out.len, &out));
            return won;
        }
    };
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var store = try open(tmp.dir);
    defer store.deinit();
    var start: std.Io.Event = .unset;
    var workers: [8]std.Io.Future(anyerror!bool) = undefined;
    var count: usize = 0;
    defer for (workers[0..count]) |*worker| {
        _ = worker.cancel(t.io) catch {};
    };
    defer start.set(t.io);
    for (&workers, 0..) |*worker, id| {
        worker.* = try t.io.concurrent(Worker.run, .{ &store, &start, id });
        count += 1;
    }
    start.set(t.io);
    var winners: usize = 0;
    for (&workers) |*worker| winners += @intFromBool(try worker.await(t.io));
    try t.expectEqual(@as(usize, 1), winners);
    try t.expectEqual(@as(u64, 16), store.puts);
    try t.expectEqual(@as(u64, 1), store.conditional_puts);
    try t.expectEqual(@as(u64, 7), store.conditional_conflicts);
    try t.expectEqual(@as(u64, 32), store.range_reads);
    try t.expectEqual(@as(u64, 85), store.bytes_written);
    try t.expectEqual(@as(u64, 160), store.bytes_read);
}

test "immutable identity and conditional kind survive restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const key = "segments/1/seg-1.tseg";
    {
        var store = try open(tmp.dir);
        defer store.deinit();
        _ = try store.objectStore().putImmutable(key, "TSEG bytes", hash("TSEG bytes"));
        _ = try store.objectStore().putImmutable(key, "TSEG bytes", hash("TSEG bytes"));
    }
    var store = try open(tmp.dir);
    defer store.deinit();
    try t.expectError(error.ImmutableObjectConflict, store.objectStore().putImmutable(key, "different", hash("different")));
    try t.expectError(error.ImmutableObjectConflict, store.objectStore().putConditional(key, .{ .if_match = hash("TSEG bytes") }, "different"));
    try t.expectError(error.ObjectDigestMismatch, store.objectStore().putImmutable("bad", "bytes", hash("other")));
    try t.expect(try store.objectStore().head("bad") == null);
    var out: [64]u8 = undefined;
    try t.expectEqualStrings("TSEG bytes", try store.objectStore().getRange(key, 0, out.len, &out));
}

test "bounded range reads cross chunks and detect touched data and checksum corruption" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const bytes = try t.allocator.alloc(u8, 3 * Disk.chunk_bytes + 73);
    defer t.allocator.free(bytes);
    for (bytes, 0..) |*byte, i| byte.* = @truncate(i * 137);
    var store = try open(tmp.dir);
    defer store.deinit();
    const key = "segments/1/big.tseg";
    _ = try store.objectStore().putImmutable(key, bytes, hash(bytes));
    var out: [1024]u8 = undefined;
    const offset = Disk.chunk_bytes - 13;
    try t.expectEqualSlices(u8, bytes[offset..][0..out.len], try store.objectStore().getRange(key, offset, out.len, &out));
    try t.expectEqualSlices(u8, bytes[bytes.len - 5 ..], try store.objectStore().getRange(key, bytes.len - 5, out.len, &out));
    try t.expectError(error.RangeOutOfBounds, store.objectStore().getRange(key, bytes.len + 1, 1, &out));
    const key_hex = std.fmt.bytesToHex(hash(key), .lower);
    const data_hex = std.fmt.bytesToHex(hash(bytes), .lower);
    var path: [200]u8 = undefined;
    const data = try tmp.dir.openFile(t.io, try std.fmt.bufPrint(&path, "objects/objects/{s}-{s}.tseg", .{ key_hex, data_hex }), .{ .mode = .read_write });
    defer data.close(t.io);
    try data.writePositionalAll(t.io, "bad", offset);
    try t.expectError(error.ObjectDigestMismatch, store.objectStore().getRange(key, offset, out.len, &out));
    try data.writePositionalAll(t.io, bytes[offset..][0..3], offset);
    const checks = try tmp.dir.openFile(t.io, try std.fmt.bufPrint(&path, "objects/objects/{s}-{s}.checks", .{ key_hex, data_hex }), .{ .mode = .read_write });
    defer checks.close(t.io);
    try checks.writePositionalAll(t.io, "bad", 0);
    try t.expectError(error.ObjectDigestMismatch, store.objectStore().getRange(key, offset, out.len, &out));
}

test "object count and total bytes do not populate the disk owner's allocator" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var resident: [16 * 1024]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(&resident);
    var store = try Store.openDiskAt(fixed.allocator(), t.io, tmp.dir, "objects");
    defer store.deinit();
    var bytes: [8192]u8 = @splat(42);
    for (0..513) |i| {
        var key: [64]u8 = undefined;
        const name = try std.fmt.bufPrint(&key, "segments/{d}.tseg", .{i});
        _ = try store.objectStore().putImmutable(name, &bytes, hash(&bytes));
        try t.expectEqualStrings(&bytes, try store.objectStore().getRange(name, 0, bytes.len, &bytes));
    }
    try t.expectEqual(@as(usize, 0), store.objects.items.len);
    try store.objectStore().delete("segments/0.tseg");
    try t.expect(try store.objectStore().head("segments/0.tseg") == null);
    try t.expectError(error.ObjectNotFound, store.objectStore().getRange("segments/0.tseg", 0, 1, &bytes));
}

test "missing and foreign object store definitions do not reinitialize retained data" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    {
        var store = try open(tmp.dir);
        defer store.deinit();
        _ = try store.objectStore().putImmutable("retained", "value", hash("value"));
    }
    const marker = try tmp.dir.openFile(t.io, "objects/.definition", .{ .mode = .read_write });
    defer marker.close(t.io);
    try marker.writePositionalAll(t.io, &@as([32]u8, @splat(0)), 0);
    try t.expectError(error.IncompatibleDefinition, open(tmp.dir));
    try tmp.dir.deleteFile(t.io, "objects/.definition");
    try t.expectError(error.IncompatibleDefinition, open(tmp.dir));
}

test "object write errors leave private partial files unpublished and exact retries usable" {
    const Fault = struct {
        var real: std.Io = undefined;
        var remaining: usize = 0;
        var prefix: usize = 0;
        fn operate(context: ?*anyopaque, operation: std.Io.Operation) std.Io.Cancelable!std.Io.Operation.Result {
            if (operation == .file_write_streaming and remaining != 0) {
                remaining -= 1;
                if (remaining == 0) {
                    const write = operation.file_write_streaming;
                    std.debug.assert(write.header.len == 0 and write.data.len == 1 and write.splat == 1);
                    write.file.writeStreamingAll(real, write.data[0][0..@min(prefix, write.data[0].len)]) catch |err| switch (err) {
                        error.Canceled => return error.Canceled,
                        else => |write_err| return .{ .file_write_streaming = write_err },
                    };
                    return .{ .file_write_streaming = error.NoSpaceLeft };
                }
            }
            return real.vtable.operate(context, operation);
        }
    };
    Fault.real = t.io;
    var vtable = t.io.vtable.*;
    vtable.operate = Fault.operate;
    var io = t.io;
    io.vtable = &vtable;
    for ([_]bool{ false, true }) |immutable| {
        for (1..3) |failure| {
            for ([_]usize{ 0, 1, std.math.maxInt(usize) }) |prefix| {
                var tmp = t.tmpDir(.{});
                defer tmp.cleanup();
                var owner = try Store.openDiskAt(t.allocator, io, tmp.dir, "objects");
                defer owner.deinit();
                try t.expect(try owner.objectStore().putConditional("head", .if_none_match, "before"));
                const key = if (immutable) "new" else "head";
                Fault.prefix = prefix;
                Fault.remaining = failure; // raw payload, descriptor
                if (immutable) {
                    try t.expectError(error.NoSpaceLeft, owner.objectStore().putImmutable(key, "after", hash("after")));
                } else {
                    try t.expectError(error.NoSpaceLeft, owner.objectStore().putConditional(key, .{ .if_match = hash("before") }, "after"));
                }
                try t.expectEqual(@as(usize, 0), Fault.remaining);
                var reopened = try open(tmp.dir);
                defer reopened.deinit();
                var bytes: [16]u8 = undefined;
                if (immutable) {
                    try t.expectEqual(null, try reopened.objectStore().head(key));
                    _ = try reopened.objectStore().putImmutable(key, "after", hash("after"));
                    try t.expectError(error.ImmutableObjectConflict, reopened.objectStore().putImmutable(key, "other", hash("other")));
                } else {
                    try t.expectEqualStrings("before", try reopened.objectStore().getRange(key, 0, bytes.len, &bytes));
                    try t.expect(try reopened.objectStore().putConditional(key, .{ .if_match = hash("before") }, "after"));
                    try t.expect(!try reopened.objectStore().putConditional(key, .{ .if_match = hash("before") }, "other"));
                }
                try t.expectEqualStrings("after", try owner.objectStore().getRange(key, 0, bytes.len, &bytes));
                try t.expectEqualDeep(hash("after"), (try owner.objectStore().head(key)).?.sha256);
            }
        }
    }
}

test "object publication probe accounts for every file and directory barrier" {
    const Probe = struct {
        const Event = enum { payload, checks, content_names, descriptor, descriptor_name, unknown };
        var real: std.Io = undefined;
        var enabled: bool = false;
        var content_dir: @FieldType(std.Io.Dir, "handle") = undefined;
        var keys_dir: @FieldType(std.Io.Dir, "handle") = undefined;
        var events: [8]Event = undefined;
        var count: usize = 0;
        var omitted: usize = 0;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            try real.vtable.fileSync(context, file);
            if (!enabled) return;
            const stat = file.stat(real) catch return error.InputOutput;
            const event: Event = if (stat.kind == .directory)
                (if (file.handle == content_dir) .content_names else if (file.handle == keys_dir) .descriptor_name else .unknown)
            else if (stat.kind == .file)
                (switch (stat.size) {
                    65537 => .payload,
                    64 => .checks,
                    512 => .descriptor,
                    else => .unknown,
                })
            else
                .unknown;
            if (count == events.len) {
                omitted += 1;
            } else {
                events[count] = event;
                count += 1;
            }
        }
    };
    Probe.real = t.io;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Probe.sync;
    var io = t.io;
    io.vtable = &vtable;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try Store.openDiskAt(t.allocator, io, tmp.dir, "objects");
    defer owner.deinit();
    Probe.content_dir = owner.disk.?.objects_dir.handle;
    Probe.keys_dir = owner.disk.?.keys_dir.handle;
    const payload: [65537]u8 = @splat(0xa5); // Two chunks; distinct file sizes.
    Probe.enabled = true;
    defer Probe.enabled = false;
    for ([_]bool{ true, false }) |immutable| {
        Probe.count = 0;
        Probe.omitted = 0;
        if (immutable) {
            _ = try owner.objectStore().putImmutable("new", &payload, hash(&payload));
        } else {
            try t.expect(try owner.objectStore().putConditional("head", .if_none_match, &payload));
        }
        try t.expectEqual(@as(usize, 0), Probe.omitted);
        try t.expectEqualSlices(Probe.Event, &.{ .payload, .checks, .content_names, .descriptor, .descriptor_name }, Probe.events[0..Probe.count]);
    }
    Probe.enabled = false;
    // Read through an independent owner, including the second payload chunk.
    var reader = try open(tmp.dir);
    defer reader.deinit();
    var bytes: [2]u8 = undefined;
    try t.expectEqualSlices(u8, payload[65535..], try reader.objectStore().getRange("new", 65535, 2, &bytes));
}

test "object publication sync failures leave a complete old or complete new descriptor" {
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
    for ([_]bool{ false, true }) |immutable| {
        for (1..5) |failure| {
            var tmp = t.tmpDir(.{});
            defer tmp.cleanup();
            var owner = try Store.openDiskAt(t.allocator, io, tmp.dir, "objects");
            defer owner.deinit();
            try t.expect(try owner.objectStore().putConditional("head", .if_none_match, "before"));
            Fault.remaining = failure;
            if (immutable) {
                try t.expectError(error.InputOutput, owner.objectStore().putImmutable("new", "after", hash("after")));
            } else {
                try t.expectError(error.InputOutput, owner.objectStore().putConditional("head", .{ .if_match = hash("before") }, "after"));
            }
            try t.expectEqual(@as(usize, 0), Fault.remaining);
            var reopened = try open(tmp.dir);
            defer reopened.deinit();
            if (immutable) {
                const observed = try reopened.objectStore().head("new");
                if (failure == 4) {
                    try t.expectEqualDeep(hash("after"), observed.?.sha256);
                } else try t.expectEqual(null, observed);
                _ = try reopened.objectStore().putImmutable("new", "after", hash("after"));
                var bytes: [16]u8 = undefined;
                try t.expectEqualStrings("after", try reopened.objectStore().getRange("new", 0, bytes.len, &bytes));
                try t.expectError(error.ImmutableObjectConflict, reopened.objectStore().putImmutable("new", "different", hash("different")));
                continue;
            }
            const expected: []const u8 = if (failure == 4) "after" else "before";
            var bytes: [16]u8 = undefined;
            try t.expectEqualStrings(expected, try reopened.objectStore().getRange("head", 0, bytes.len, &bytes));
            try t.expectEqualDeep(hash(expected), (try owner.objectStore().head("head")).?.sha256);
            try t.expect(try reopened.objectStore().putConditional("head", .{ .if_match = hash(expected) }, "reconciled"));
        }
    }
}

test "exclusive immutable reclamation validates identity and resumes every deletion sync failure" {
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
    for (1..3) |failure| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var owner = try Store.openDiskAt(t.allocator, io, tmp.dir, "objects");
        defer owner.deinit();
        const expected = try owner.objectStore().putImmutable("retired", "immutable bytes", hash("immutable bytes"));
        const keep = try owner.objectStore().putImmutable("live", "same independent bytes", hash("same independent bytes"));
        var wrong = expected;
        wrong.sha256[0] ^= 1;
        try t.expectError(error.ImmutableObjectConflict, owner.reclaimImmutableObject("retired", wrong));
        try t.expect(try owner.objectStore().putConditional("head", .if_none_match, "conditional"));
        try t.expectError(error.ImmutableObjectConflict, owner.reclaimImmutableObject("head", (try owner.objectStore().head("head")).?));
        Fault.remaining = failure;
        try t.expectError(error.InputOutput, owner.reclaimImmutableObject("retired", expected));
        try t.expectEqual(@as(usize, 0), Fault.remaining);
        var reopened = try open(tmp.dir);
        defer reopened.deinit();
        _ = try reopened.reclaimImmutableObject("retired", expected);
        try t.expectEqual(@as(u64, 0), try reopened.reclaimImmutableObject("retired", expected));
        try t.expectEqual(null, try reopened.objectStore().head("retired"));
        try t.expectEqualDeep(keep, (try reopened.objectStore().head("live")).?);
        var bytes: [32]u8 = undefined;
        try t.expectEqualStrings("same independent bytes", try reopened.objectStore().getRange("live", 0, bytes.len, &bytes));
        try t.expectEqualStrings("conditional", try reopened.objectStore().getRange("head", 0, bytes.len, &bytes));
    }
}

test "immutable confirmation verifies content and syncs observed publications without a PUT" {
    const Fault = struct {
        var real: std.Io = undefined;
        var remaining: usize = 0;
        var kinds: [8]bool = undefined;
        var calls: usize = 0;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            if (calls < kinds.len) kinds[calls] = (file.stat(real) catch return error.InputOutput).kind == .directory;
            calls += 1;
            if (remaining != 0) {
                remaining -= 1;
                if (remaining == 0) return error.InputOutput;
            }
            return real.vtable.fileSync(context, file);
        }
    };
    Fault.real = t.io;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Fault.sync;
    var io = t.io;
    io.vtable = &vtable;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try Store.openDiskAt(t.allocator, io, tmp.dir, "objects");
    defer owner.deinit();
    const meta = try owner.objectStore().putImmutable("observed", "original bytes", hash("original bytes"));
    const puts = owner.puts;
    Fault.calls = 0;
    try owner.confirmImmutableObject("observed", meta);
    try t.expectEqual(@as(usize, 4), Fault.calls);
    try t.expectEqualSlices(bool, &.{ false, true, false, true }, Fault.kinds[0..4]);
    for (1..5) |failure| {
        Fault.calls = 0;
        Fault.remaining = failure;
        try t.expectError(error.InputOutput, owner.confirmImmutableObject("observed", meta));
        try t.expectEqual(failure, Fault.calls);
        try owner.confirmImmutableObject("observed", meta);
    }
    try t.expectEqual(puts, owner.puts);
    try t.expectError(error.ObjectNotFound, owner.confirmImmutableObject("absent", meta));
    try t.expect(try owner.objectStore().putConditional("conditional", .if_none_match, "original bytes"));
    try t.expectError(error.ImmutableObjectConflict, owner.confirmImmutableObject("conditional", meta));
    const empty = try owner.objectStore().putImmutable("empty", "", hash(""));
    try owner.confirmImmutableObject("empty", empty);
    var path: [200]u8 = undefined;
    const file = try tmp.dir.openFile(t.io, try std.fmt.bufPrint(&path, "objects/objects/{x}-{x}.data", .{ &hash("empty"), &hash("") }), .{ .mode = .read_write });
    defer file.close(t.io);
    try file.writePositionalAll(t.io, "unexpected", 0);
    try t.expectError(error.ObjectDigestMismatch, owner.confirmImmutableObject("empty", empty));
    var memory = Store.initMemory(t.allocator);
    defer memory.deinit();
    const volatile_meta = try memory.objectStore().putImmutable("memory", "original bytes", hash("original bytes"));
    try memory.confirmImmutableObject("memory", volatile_meta);
    memory.objects.items[0].bytes[0] ^= 1;
    try t.expectError(error.ObjectDigestMismatch, memory.confirmImmutableObject("memory", volatile_meta));
}

test "immutable object batches share directory barriers and retain exact per-object bytes" {
    const Objects = @import("TransitObjectStore.zig");
    const Probe = struct {
        var real: std.Io = undefined;
        var enabled = false;
        var files: std.atomic.Value(usize) = .init(0);
        var directories: std.atomic.Value(usize) = .init(0);
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            try real.vtable.fileSync(context, file);
            if (!enabled) return;
            const stat = file.stat(real) catch return error.InputOutput;
            if (stat.kind == .directory) {
                _ = directories.fetchAdd(1, .monotonic);
            } else {
                _ = files.fetchAdd(1, .monotonic);
            }
        }
    };
    Probe.real = t.io;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Probe.sync;
    var io = t.io;
    io.vtable = &vtable;
    for ([_]usize{ 1, 2, Objects.max_put_batch }) |count| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var owner = try Store.openDiskAt(t.allocator, io, tmp.dir, "objects");
        defer owner.deinit();
        var names: [Objects.max_put_batch][24]u8 = undefined;
        var batch: [Objects.max_put_batch]Objects.ImmutablePut = undefined;
        var output: [Objects.max_put_batch]Objects.ObjectMeta = undefined;
        for (batch[0..count], names[0..count], 0..) |*item, *name, i| {
            const key = try std.fmt.bufPrint(name, "batch/{d}", .{i});
            item.* = .{ .key = key, .bytes = key, .sha256 = hash(key) };
        }
        Probe.files.store(0, .monotonic);
        Probe.directories.store(0, .monotonic);
        Probe.enabled = true;
        defer Probe.enabled = false;
        try owner.objectStore().putImmutableBatch(batch[0..count], output[0..count]);
        Probe.enabled = false;
        try t.expectEqual(2 * count, Probe.files.load(.monotonic));
        try t.expectEqual(@as(usize, 2), Probe.directories.load(.monotonic));
        try t.expectEqual(count, owner.puts);
        var reader = try open(tmp.dir);
        defer reader.deinit();
        for (batch[0..count], output[0..count]) |item, meta| {
            var bytes: [24]u8 = undefined;
            try t.expectEqualStrings(item.bytes, try reader.objectStore().getRange(item.key, 0, bytes.len, &bytes));
            try t.expectEqualDeep(meta, (try reader.objectStore().head(item.key)).?);
        }
        try reader.objectStore().putImmutableBatch(batch[0..count], output[0..count]);
        const original = batch[0];
        batch[0].bytes = "conflicting";
        batch[0].sha256 = hash("conflicting");
        try t.expectError(error.ImmutableObjectConflict, reader.objectStore().putImmutableBatch(batch[0..count], output[0..count]));
        batch[0] = original;
        try t.expectError(error.InvalidObjectBatch, owner.objectStore().putImmutableBatch(&.{}, &.{}));
        try t.expectError(error.DuplicateObjectKey, owner.objectStore().putImmutableBatch(&.{ original, original }, output[0..2]));
    }
}

test "immutable object batch failure never returns partial output and exact retry recovers" {
    const Objects = @import("TransitObjectStore.zig");
    const Fault = struct {
        var real: std.Io = undefined;
        var sync_remaining: std.atomic.Value(usize) = .init(0);
        var write_remaining: usize = 0;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            var remaining = sync_remaining.load(.monotonic);
            while (remaining != 0) {
                if (sync_remaining.cmpxchgWeak(remaining, remaining - 1, .monotonic, .monotonic)) |observed| {
                    remaining = observed;
                } else {
                    if (remaining == 1) return error.InputOutput;
                    break;
                }
            }
            return real.vtable.fileSync(context, file);
        }
        fn operate(context: ?*anyopaque, operation: std.Io.Operation) std.Io.Cancelable!std.Io.Operation.Result {
            if (operation == .file_write_streaming and write_remaining != 0) {
                write_remaining -= 1;
                if (write_remaining == 0) {
                    const write = operation.file_write_streaming;
                    write.file.writeStreamingAll(real, write.data[0][0..1]) catch return .{ .file_write_streaming = error.InputOutput };
                    return .{ .file_write_streaming = error.NoSpaceLeft };
                }
            }
            return real.vtable.operate(context, operation);
        }
    };
    Fault.real = t.io;
    var vtable = t.io.vtable.*;
    vtable.fileSync = Fault.sync;
    vtable.operate = Fault.operate;
    var io = t.io;
    io.vtable = &vtable;
    const batch = [_]Objects.ImmutablePut{
        .{ .key = "a", .bytes = "first", .sha256 = hash("first") },
        .{ .key = "b", .bytes = "second", .sha256 = hash("second") },
    };
    const sentinel: Objects.ObjectMeta = .{ .size = 999, .sha256 = @splat(9) };
    for ([_]bool{ false, true }) |write_failure| {
        for (1..(if (write_failure) @as(usize, 5) else 7)) |failure| {
            var tmp = t.tmpDir(.{});
            defer tmp.cleanup();
            var owner = try Store.openDiskAt(t.allocator, io, tmp.dir, "objects");
            defer owner.deinit();
            var output: [2]Objects.ObjectMeta = @splat(sentinel);
            if (write_failure) Fault.write_remaining = failure else Fault.sync_remaining.store(failure, .monotonic);
            try t.expectError(if (write_failure) error.NoSpaceLeft else error.InputOutput, owner.objectStore().putImmutableBatch(&batch, &output));
            try t.expectEqual(@as(usize, 0), Fault.write_remaining + Fault.sync_remaining.load(.monotonic));
            try t.expectEqualDeep([2]Objects.ObjectMeta{ sentinel, sentinel }, output);
            var reader = try open(tmp.dir);
            defer reader.deinit();
            for (batch) |item| if (try reader.objectStore().head(item.key)) |_| {
                var bytes: [16]u8 = undefined;
                try t.expectEqualStrings(item.bytes, try reader.objectStore().getRange(item.key, 0, bytes.len, &bytes));
            };
            try reader.objectStore().putImmutableBatch(&batch, &output);
            for (batch, output) |item, meta| {
                var bytes: [16]u8 = undefined;
                try t.expectEqual(item.bytes.len, meta.size);
                try t.expectEqualStrings(item.bytes, try owner.objectStore().getRange(item.key, 0, bytes.len, &bytes));
            }
        }
    }
}

test "overlapping immutable object batches lock keys in one order" {
    const Objects = @import("TransitObjectStore.zig");
    const Writer = struct {
        fn run(owner: *Store, reversed: bool) !void {
            var batch = [_]Objects.ImmutablePut{
                .{ .key = "a", .bytes = "a", .sha256 = hash("a") },
                .{ .key = "b", .bytes = "b", .sha256 = hash("b") },
            };
            if (reversed) std.mem.swap(Objects.ImmutablePut, &batch[0], &batch[1]);
            var output: [2]Objects.ObjectMeta = undefined;
            try owner.objectStore().putImmutableBatch(&batch, &output);
        }
    };
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var a = try open(tmp.dir);
    defer a.deinit();
    var b = try open(tmp.dir);
    defer b.deinit();
    var first = try t.io.concurrent(Writer.run, .{ &a, false });
    defer _ = first.cancel(t.io) catch {};
    var second = try t.io.concurrent(Writer.run, .{ &b, true });
    defer _ = second.cancel(t.io) catch {};
    try first.await(t.io);
    try second.await(t.io);
}
