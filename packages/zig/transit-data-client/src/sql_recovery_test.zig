const std = @import("std");
const data = @import("root.zig");
const sql = data.sql;
const api = sql.protocol;
const t = std.testing;
const instance: api.Instance = @splat(7);
const session: api.Id = @splat(8);
const account: api.Account = @splat(9);
const text = "INSERT INTO items VALUES (17)";
const Mode = enum { success, lost_reply, refuse_store, receipt_failure };
const Fault = struct {
    var real: *const std.Io.VTable = undefined;
    var refuse: bool = false;
    var fail_sync: std.atomic.Value(bool) = .init(false);
    fn create(context: ?*anyopaque, dir: std.Io.Dir, path: []const u8, options: std.Io.Dir.CreateFileAtomicOptions) std.Io.Dir.CreateFileAtomicError!std.Io.File.Atomic {
        if (refuse) return error.NoSpaceLeft;
        return real.dirCreateFileAtomic(context, dir, path, options);
    }
    fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
        if (fail_sync.load(.acquire)) return error.InputOutput;
        return real.fileSync(context, file);
    }
};
const Peer = struct {
    io: std.Io,
    listener: *std.Io.net.Server,
    store: *data.LocalRecoveryStore,
    mode: Mode,
    executes: usize = 0,
    statuses: usize = 0,
    fn run(self: *Peer) !void {
        const count: usize = 2 + @as(usize, switch (self.mode) {
            .refuse_store => 1,
            .lost_reply => 3,
            else => 2,
        });
        var token: ?api.Token = null;
        for (0..count) |index| {
            const stream = try self.listener.accept(self.io);
            defer stream.close(self.io);
            var input: [8192]u8 = undefined;
            var output: [8192]u8 = undefined;
            var reader = stream.reader(self.io, &input);
            var writer = stream.writer(self.io, &output);
            var http = std.http.Server.init(&reader.interface, &writer.interface);
            var request = try http.receiveHead();
            const bytes = try request.readerExpectNone(&.{}).allocRemaining(t.allocator, .limited(65536));
            defer t.allocator.free(bytes);
            const parsed = try api.Json.parseFromSliceOwned(api.Request, t.allocator, bytes);
            defer parsed.deinit();
            try parsed.value.validate();
            var response: api.JsonResponse = .{ .version = 1, .definition = api.native.current_definition, .instance = instance, .result = undefined };
            if (index == 0) {
                try t.expect(parsed.value.action == .hello);
                response.result = .{ .hello = .{ .encoding = api.encoding, .session_lease_ms = 30000, .maximum_message = api.max_message_bytes, .maximum_batch = api.max_batch_bytes, .maximum_rows = api.max_rows, .capabilities = &.{} } };
            } else if (index == 1) {
                try t.expect(parsed.value.action == .open);
                response.result = .{ .opened = .{ .session = session, .account = account, .database = "transit" } };
            } else if (index == 2) {
                try t.expect(parsed.value.action == .context);
                response.result = .{ .context = .{ .account = account, .database = "transit", .source = null, .transaction = null, .sources = &.{} } };
            } else if (index == 3) {
                try t.expect(parsed.value.action == .execute);
                self.executes += 1;
                token = parsed.value.action.execute.token;
                var keys: [2]data.LocalRecoveryStore.Key = undefined;
                try t.expectEqual(1, (try self.store.listPage(null, &keys)).count);
                var saved: [8192]u8 = undefined;
                const record = (try self.store.get(keys[0], &saved)).?;
                const original = try api.Json.parseFromSliceOwned(sql.Executor.Submission, t.allocator, record.original);
                defer original.deinit();
                try original.value.validate();
                try t.expectEqual(token.?, original.value.execute.token.?);
                try t.expectEqualStrings(text, original.value.execute.sql.?);
                try t.expectEqual(0, record.evidence.len);
                if (self.mode == .lost_reply) continue;
                if (self.mode == .receipt_failure) Fault.fail_sync.store(true, .release);
                response.result = .{ .completion = .{ .kind = .insert, .outcome = .applied, .counts = .{ .matched = 1, .changed = 1 }, .operation = .{ .account = account, .id = 43 }, .pending_restart = false, .diagnostic = null } };
            } else {
                try t.expect(parsed.value.action == .status);
                self.statuses += 1;
                try t.expectEqual(token.?, parsed.value.action.status.token);
                response.result = .{ .operation = .{ .identity = .{ .account = account, .id = 43 }, .command = .insert, .token = token.?, .phase = .terminal, .outcome = .applied, .matched = 1, .changed = 1 } };
            }
            const reply = try api.Json.valueAlloc(t.allocator, response);
            defer t.allocator.free(reply);
            try request.respond(reply, .{ .keep_alive = false, .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }} });
        }
    }
};

test "SQL disk persistence orders sends and keeps known commitment on receipt-store failure" {
    var threaded: std.Io.Threaded = .init(t.allocator, .{ .concurrent_limit = .limited(8) });
    defer threaded.deinit();
    const io = threaded.io();
    Fault.real = io.vtable;
    var table = io.vtable.*;
    table.fileSync = Fault.sync;
    table.dirCreateFileAtomic = Fault.create;
    var store_io = io;
    store_io.vtable = &table;
    for (std.enums.values(Mode)) |mode| {
        Fault.refuse = false;
        Fault.fail_sync.store(false, .release);
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var store = try data.LocalRecoveryStore.open(t.allocator, store_io, tmp.dir, "recovery", .{ .record_bytes = 8192 });
        defer store.deinit();
        var recovery = try data.SqlRecovery.init(t.allocator, &store, .{ .parse_bytes = 128 * 1024 });
        defer recovery.deinit();
        var listener = try (try std.Io.net.IpAddress.parseIp4("127.0.0.1", 0)).listen(io, .{ .reuse_address = true });
        defer listener.deinit(io);
        const endpoint = try std.fmt.allocPrint(t.allocator, "http://127.0.0.1:{d}", .{listener.socket.address.getPort()});
        defer t.allocator.free(endpoint);
        const config: sql.Client.Config = .{ .endpoint = endpoint, .authentication = .trust, .request_timeout_ms = 1000 };
        var context = try data.Context.init(t.allocator, io, .{ .catalogs = 1, .sqls = 1, .active = .{ .data = 1, .control = 1 } });
        defer context.deinit() catch unreachable;
        defer context.close(.none) catch unreachable;
        const handle = try context.openSql(config, null);
        const lease = try context.borrowSql(handle);
        defer lease.release() catch unreachable;
        var peer: Peer = .{ .io = io, .listener = &listener, .store = &store, .mode = mode };
        var task = try io.concurrent(Peer.run, .{&peer});
        defer task.cancel(io) catch {};
        try lease.connect();
        Fault.refuse = mode == .refuse_store;
        const result = recovery.execute(try lease.executor(), text, null, .{});
        if (mode == .refuse_store) {
            try t.expectError(error.NoSpaceLeft, result);
        } else {
            const execution = try result;
            defer execution.deinit();
            try t.expectEqual(.applied, execution.outcome.value.command.outcome);
            try t.expectEqual(@as(?anyerror, if (mode == .receipt_failure) error.InputOutput else null), execution.persistence_failure);
            var loaded = try recovery.load(t.allocator, execution.attempt.?.key);
            defer loaded.deinit();
            try t.expectEqualStrings(text, loaded.submission.value.execute.sql.?);
            try t.expectEqual(mode != .receipt_failure, loaded.completion != null);
        }
        try task.await(io);
        try t.expectEqual(@as(usize, if (mode == .refuse_store) 0 else 1), peer.executes);
        try t.expectEqual(@as(usize, if (mode == .lost_reply) 1 else 0), peer.statuses);
    }
}
