const std = @import("std");
const t = std.testing;
const core = @import("transit_core");
const local = @import("root.zig");
const Fixture = @import("collection_test.zig").Fixture;
const g = core.protocol.Growth;

fn hash(bytes: []const u8) [32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}
fn current(f: *Fixture, id: u64) !g.Payload {
    var state = try f.engine.state();
    return (try state.get(g.Payload, core.growing.address(.payload, id))).?;
}

test "local standalone payload acceptance, lost receipt, retirement and permanent creation fence" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.open(tmp.dir, true);
    defer f.close();
    var store: local.PayloadStore = .{ .engine = &f.engine };
    const pid = try f.submit(.{ .spawn = .{} });
    const bytes = "complete independently retained payload";
    const id = try f.submit(.{ .declare_payload = .{ .pid = pid, .sha256 = hash(bytes), .bytes = bytes.len, .allow_delete = true } });
    const ref: core.protocol.PayloadRef = .{ .pid = pid, .payload = id };
    const creating = try current(&f, id);
    try t.expectError(error.PayloadUnavailable, store.verifyPayload(creating));
    try t.expectError(error.PayloadPhase, store.reclaimPayload(creating));
    try t.expectError(error.InvalidPayload, store.createPayloadOnce(creating, "different"));
    var forged = creating;
    forged.pid += 1;
    try t.expectError(error.PayloadIdentityMismatch, store.createPayloadOnce(forged, bytes));
    try store.createPayloadOnce(creating, bytes);
    try t.expectError(error.PayloadCreationAttempted, store.createPayloadOnce(creating, bytes));
    // The application loses its create reply. Reopen verifies the original
    // bytes and native intent without another creation attempt or acceptance.
    const before = f.engine.head;
    f.close();
    try f.open(tmp.dir, false);
    try store.verifyPayload(creating);
    try t.expectEqualDeep(before, f.engine.head);
    _ = try f.submit(.{ .payload_ready = ref });
    const ready = try current(&f, id);
    try store.verifyPayload(ready);
    var read_buffer: [core.protocol.max_payload_bytes]u8 = undefined;
    try t.expectEqualStrings(bytes, try store.readPayload(ready, &read_buffer));
    const Denied = struct {
        fn check(_: *anyopaque, _: *local.PayloadStore.Engine) !void {
            return error.Forbidden;
        }
    };
    var context: u8 = 0;
    store.guard = .{ .context = &context, .check = Denied.check };
    try t.expectError(error.Forbidden, store.readPayload(ready, &read_buffer));
    try t.expectError(error.Forbidden, store.verifyPayload(ready));
    store.guard = null;
    try t.expectError(error.PayloadInUse, f.submit(.{ .retire_payload = ref }));
    try t.expectError(error.PayloadPhase, store.reclaimPayload(ready));
    _ = try f.submit(.{ .terminate = pid });
    _ = try f.submit(.{ .retire_payload = ref });
    const retiring = try current(&f, id);
    const allocated = f.owner.allocated;
    try store.reclaimPayload(retiring);
    try t.expect(f.owner.allocated < allocated);
    const reclaimed = f.owner.allocated;
    try store.reclaimPayload(retiring);
    try t.expectEqual(reclaimed, f.owner.allocated);
    try t.expectError(error.PayloadIdentityMismatch, store.createPayloadOnce(creating, bytes));
    try t.expectEqual(.retiring, (try current(&f, id)).phase);
    _ = try f.submit(.{ .payload_deleted = ref });
    _ = try f.submit(.{ .checkpoint = {} });
    try f.journal.maintain(f.engine.head);
    f.close();
    try f.open(tmp.dir, false);
    try t.expectEqual(.deleted, (try current(&f, id)).phase);
    try t.expectError(error.PayloadUnavailable, store.verifyPayload(try current(&f, id)));
    var name: [64]u8 = undefined;
    const marker = try f.owner.directory.openFile(t.io, try std.fmt.bufPrint(&name, ".payload-{x:0>16}", .{id}), .{});
    defer marker.close(t.io);
    try t.expectEqual(@as(u64, 136), try marker.length(t.io));
}

test "local payload retention and current identity remain independent of quota and process ownership" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.open(tmp.dir, true);
    defer f.close();
    var store: local.PayloadStore = .{ .engine = &f.engine };
    const pid = try f.submit(.{ .spawn = .{} });
    const bytes: [core.protocol.max_payload_bytes]u8 = @splat(63);
    const id = try f.submit(.{ .declare_payload = .{ .pid = pid, .sha256 = hash(&bytes), .bytes = bytes.len } });
    const ref: core.protocol.PayloadRef = .{ .pid = pid, .payload = id };
    const creating = try current(&f, id);
    const quota = f.owner.limits.bytes;
    f.owner.limits.bytes = f.owner.allocated;
    try t.expectError(error.StorageQuota, store.createPayloadOnce(creating, &bytes));
    try t.expectError(error.PayloadUnavailable, store.verifyPayload(creating));
    f.owner.limits.bytes = quota;
    try store.createPayloadOnce(creating, &bytes);
    _ = try f.submit(.{ .payload_ready = ref });
    _ = try f.submit(.{ .terminate = pid });
    try t.expectError(error.RetentionNotEnabled, f.submit(.{ .retire_payload = ref }));
    const ready = try current(&f, id);
    var forged = ready;
    forged.phase = .retiring;
    forged.allow_delete = true;
    forged.retired_at = f.engine.head.position;
    try t.expectError(error.PayloadIdentityMismatch, store.reclaimPayload(forged));
    try store.verifyPayload(ready);
    var name: [64]u8 = undefined;
    var data: local.DataStore = .{ .backend = &f.owner };
    try t.expectError(error.NativeObjectReserved, data.objects().head(try std.fmt.bufPrint(&name, "native/u/{x:0>16}", .{id})));
    // Metadata and all bytes remain available after restart despite PID closure.
    f.close();
    try f.open(tmp.dir, false);
    try store.verifyPayload(try current(&f, id));
}

test "local payload creation sync uncertainty resolves by verification without recreation" {
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
    var schedules: usize = 0;
    var failure: usize = 0;
    while (failure <= schedules) : (failure += 1) {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var value: g.Payload = undefined;
        {
            var f: Fixture = .{};
            try f.openWithIo(tmp.dir, true, io);
            defer f.close();
            const pid = try f.submit(.{ .spawn = .{} });
            const id = try f.submit(.{ .declare_payload = .{ .pid = pid, .sha256 = hash("payload"), .bytes = 7 } });
            value = try current(&f, id);
            var store: local.PayloadStore = .{ .engine = &f.engine };
            Fault.calls = 0;
            Fault.remaining = failure;
            if (failure == 0) {
                try store.createPayloadOnce(value, "payload");
                schedules = Fault.calls;
                // Marker file + directory, single-chunk payload + objects
                // directory, then descriptor file + directory.
                try t.expectEqual(@as(usize, 6), schedules);
            } else try t.expectError(error.InputOutput, store.createPayloadOnce(value, "payload"));
        }
        var reopened: Fixture = .{};
        try reopened.open(tmp.dir, false);
        defer reopened.close();
        var store: local.PayloadStore = .{ .engine = &reopened.engine };
        const puts = reopened.owner.objects.puts;
        if (failure == 0 or failure == schedules) {
            try store.verifyPayload(value);
        } else try t.expectError(error.PayloadUnavailable, store.verifyPayload(value));
        try t.expectEqual(puts, reopened.owner.objects.puts);
        try t.expectEqualDeep(value, try current(&reopened, value.id));
    }
}

test "local payload current intent serializes creators and rejects corrupt marker or bytes" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.open(tmp.dir, true);
    defer f.close();
    const pid = try f.submit(.{ .spawn = .{} });
    const id = try f.submit(.{ .declare_payload = .{ .pid = pid, .sha256 = hash("payload"), .bytes = 7 } });
    const value = try current(&f, id);
    var second_pages = try local.PageStore.init(&f.owner, 1);
    defer second_pages.deinit();
    var second_journal: local.Store = .{ .backend = &f.owner };
    var second_engine = try local.PayloadStore.Engine.open(&second_journal, &second_pages, f.engine.genesis);
    var first: local.PayloadStore = .{ .engine = &f.engine };
    var second: local.PayloadStore = .{ .engine = &second_engine };
    const Attempt = struct {
        fn run(store: *local.PayloadStore, intent: g.Payload) !bool {
            store.createPayloadOnce(intent, "payload") catch |err| switch (err) {
                error.PayloadCreationAttempted => return false,
                else => return err,
            };
            return true;
        }
    };
    var a = try t.io.concurrent(Attempt.run, .{ &first, value });
    defer _ = a.cancel(t.io) catch {};
    var b = try t.io.concurrent(Attempt.run, .{ &second, value });
    defer _ = b.cancel(t.io) catch {};
    try t.expect(try a.await(t.io) != try b.await(t.io));
    try first.verifyPayload(value);
    var path: [180]u8 = undefined;
    const marker = try f.owner.directory.openFile(t.io, try std.fmt.bufPrint(&path, ".payload-{x:0>16}", .{id}), .{ .mode = .read_write });
    defer marker.close(t.io);
    try marker.writePositionalAll(t.io, "!", 0);
    try t.expectError(error.PayloadIntegrity, first.verifyPayload(value));
    try marker.writePositionalAll(t.io, "T", 0);
    const object_key = try std.fmt.bufPrint(&path, "native/u/{x:0>16}", .{id});
    const key_hash = hash(object_key);
    const data = try f.owner.directory.openFile(t.io, try std.fmt.bufPrint(&path, "objects/{x}-{x}.data", .{ &key_hash, &value.sha256 }), .{ .mode = .read_write });
    defer data.close(t.io);
    try data.writePositionalAll(t.io, "!", 0);
    try t.expectError(error.ObjectDigestMismatch, first.verifyPayload(value));
    try data.writePositionalAll(t.io, "p", 0);
    try first.verifyPayload(value);
}

test "local payload deletion sync uncertainty preserves retirement and the creation fence" {
    const Fault = struct {
        var real: *const std.Io.VTable = undefined;
        var remaining: usize = 0;
        var mutex: std.Io.Mutex = .init;
        fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
            try mutex.lock(t.io);
            defer mutex.unlock(t.io);
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
        var retiring: g.Payload = undefined;
        var original: g.Payload = undefined;
        {
            var f: Fixture = .{};
            try f.openWithIo(tmp.dir, true, io);
            defer f.close();
            var store: local.PayloadStore = .{ .engine = &f.engine };
            const pid = try f.submit(.{ .spawn = .{} });
            const id = try f.submit(.{ .declare_payload = .{ .pid = pid, .sha256 = hash("payload"), .bytes = 7, .allow_delete = true } });
            original = try current(&f, id);
            const ref: core.protocol.PayloadRef = .{ .pid = pid, .payload = id };
            try store.createPayloadOnce(original, "payload");
            _ = try f.submit(.{ .payload_ready = ref });
            _ = try f.submit(.{ .terminate = pid });
            _ = try f.submit(.{ .retire_payload = ref });
            retiring = try current(&f, id);
            Fault.remaining = failure;
            try t.expectError(error.InputOutput, store.reclaimPayload(retiring));
            try t.expectEqual(@as(usize, 0), Fault.remaining);
        }
        var reopened: Fixture = .{};
        try reopened.open(tmp.dir, false);
        defer reopened.close();
        var store: local.PayloadStore = .{ .engine = &reopened.engine };
        try t.expectEqualDeep(retiring, try current(&reopened, retiring.id));
        try store.reclaimPayload(retiring);
        try store.reclaimPayload(retiring);
        try t.expectError(error.PayloadIdentityMismatch, store.createPayloadOnce(original, "payload"));
        try t.expectEqual(.retiring, (try current(&reopened, retiring.id)).phase);
    }
}

test "local payload verification propagates every recovery barrier without publishing readiness" {
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
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var f: Fixture = .{};
    try f.openWithIo(tmp.dir, true, io);
    defer f.close();
    var store: local.PayloadStore = .{ .engine = &f.engine };
    const pid = try f.submit(.{ .spawn = .{} });
    const id = try f.submit(.{ .declare_payload = .{ .pid = pid, .sha256 = hash("payload"), .bytes = 7 } });
    const value = try current(&f, id);
    try store.createPayloadOnce(value, "payload");
    const head = f.engine.head;
    const puts = f.owner.objects.puts;
    Fault.calls = 0;
    try store.verifyPayload(value);
    try t.expectEqual(@as(usize, 6), Fault.calls);
    for (1..7) |failure| {
        Fault.calls = 0;
        Fault.remaining = failure;
        try t.expectError(error.InputOutput, store.verifyPayload(value));
        try t.expectEqual(failure, Fault.calls);
        try t.expectEqualDeep(head, f.engine.head);
        try t.expectEqualDeep(value, try current(&f, id));
    }
    try store.verifyPayload(value);
    try t.expectEqual(puts, f.owner.objects.puts);
}
