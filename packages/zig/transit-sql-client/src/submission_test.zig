const std = @import("std");
const sdk = @import("root.zig");
const api = sdk.protocol;
const t = std.testing;
const instance: api.Instance = @splat(7);
const session: api.Id = @splat(8);
const account: api.Account = @splat(9);
const statement = "INSERT INTO items VALUES (17)";
const Mode = enum { success, lost_reply, store_failure, cancelled_store, changed_scope, denied_context };

const Store = struct {
    mode: Mode,
    original_text: []u8,
    control: *sdk.Client,
    record: ?[]u8 = null,
    calls: usize = 0,
    persisted: std.atomic.Value(bool) = .init(false),

    fn persist(raw: *anyopaque, submission: sdk.Executor.Submission) !void {
        const self: *Store = @ptrCast(@alignCast(raw));
        self.calls += 1;
        try submission.validate();
        try t.expectEqual(account, submission.account);
        try t.expectEqualStrings("selected", submission.database);
        try t.expectEqualStrings("events", submission.source.?);
        try t.expectEqualStrings(statement, submission.execute.sql.?);
        try t.expect(submission.execute.token != null);
        if (self.mode == .store_failure) return error.StoreUnavailable;
        if (self.mode == .cancelled_store) return error.Canceled;
        self.record = try api.Json.valueAlloc(t.allocator, submission);
        // Once persisted, releasing/changing caller input cannot change the send.
        @memset(self.original_text, 'x');
        if (self.mode == .changed_scope) self.control.session = @splat(33);
        self.persisted.store(true, .release);
    }
};

const Peer = struct {
    io: std.Io,
    listener: *std.Io.net.Server,
    store: *Store,
    executes: usize = 0,
    statuses: usize = 0,

    fn run(self: *Peer) !void {
        const total: usize = switch (self.store.mode) {
            .success => 2,
            .lost_reply => 3,
            else => 1,
        };
        var token: ?api.Token = null;
        for (0..total) |index| {
            var stream = try self.listener.accept(self.io);
            defer stream.close(self.io);
            var input: [8192]u8 = undefined;
            var output: [8192]u8 = undefined;
            var reader = stream.reader(self.io, &input);
            var writer = stream.writer(self.io, &output);
            var server = std.http.Server.init(&reader.interface, &writer.interface);
            var request = try server.receiveHead();
            const bytes = try request.readerExpectNone(&.{}).allocRemaining(t.allocator, .limited(65536));
            defer t.allocator.free(bytes);
            const parsed = try api.Json.parseFromSliceOwned(api.Request, t.allocator, bytes);
            defer parsed.deinit();
            try parsed.value.validate();
            try t.expectEqual(instance, parsed.value.instance.?);
            try t.expectEqual(session, parsed.value.session.?);
            var response: api.JsonResponse = .{
                .version = 1,
                .definition = api.native.current_definition,
                .instance = instance,
                .result = undefined,
            };
            if (index == 0) {
                try t.expect(parsed.value.action == .context);
                response.result = if (self.store.mode == .denied_context)
                    .{ .err = .{ .code = "AccessDenied", .sqlstate = "42501".*, .message = "denied", .retry = .never } }
                else
                    .{ .context = .{ .account = account, .database = "selected", .source = "events", .transaction = null, .sources = &.{} } };
            } else if (index == 1) {
                try t.expect(self.store.persisted.load(.acquire));
                try t.expect(parsed.value.action == .execute);
                self.executes += 1;
                const record = try api.Json.parseFromSliceOwned(sdk.Executor.Submission, t.allocator, self.store.record.?);
                defer record.deinit();
                // Compare every accepting request field while supplying the
                // current session credential independently of the saved value.
                const expected = try api.Json.valueAlloc(t.allocator, api.Request{
                    .version = record.value.version,
                    .definition = record.value.definition,
                    .instance = record.value.instance,
                    .session = session,
                    .action = .{ .execute = record.value.execute },
                });
                defer t.allocator.free(expected);
                try t.expectEqualStrings(expected, bytes);
                try t.expectEqualStrings(statement, parsed.value.action.execute.sql.?);
                token = parsed.value.action.execute.token.?;
                if (self.store.mode == .lost_reply) continue;
                response.result = .{ .completion = .{
                    .kind = .insert,
                    .outcome = .applied,
                    .counts = .{ .matched = 1, .changed = 1 },
                    .operation = .{ .account = account, .id = 43 },
                    .pending_restart = false,
                    .diagnostic = null,
                } };
            } else {
                try t.expect(parsed.value.action == .status);
                self.statuses += 1;
                try t.expectEqual(token.?, parsed.value.action.status.token);
                response.result = .{ .operation = .{
                    .identity = .{ .account = account, .id = 43 },
                    .command = .insert,
                    .token = token.?,
                    .phase = .terminal,
                    .outcome = .applied,
                    .matched = 1,
                    .changed = 1,
                } };
            }
            const reply = try api.Json.valueAlloc(t.allocator, response);
            defer t.allocator.free(reply);
            try request.respond(reply, .{ .keep_alive = false, .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }} });
        }
    }
};

test "SQL persistence precedes execute and lost replies settle only the saved token" {
    var threaded: std.Io.Threaded = .init(t.allocator, .{ .concurrent_limit = .limited(8) });
    defer threaded.deinit();
    const io = threaded.io();
    for (std.enums.values(Mode)) |mode| {
        var listener = try (try std.Io.net.IpAddress.parseIp4("127.0.0.1", 0)).listen(io, .{ .reuse_address = true });
        defer listener.deinit(io);
        const endpoint = try std.fmt.allocPrint(t.allocator, "http://127.0.0.1:{d}", .{listener.socket.address.getPort()});
        defer t.allocator.free(endpoint);
        const config: sdk.Client.Config = .{ .endpoint = endpoint, .authentication = .trust, .request_timeout_ms = 1000 };
        var client = try sdk.Client.init(t.allocator, io, config);
        defer client.deinit();
        var control = try sdk.Client.init(t.allocator, io, config);
        defer control.deinit();
        for ([_]*sdk.Client{ &client, &control }) |value| {
            value.instance = instance;
            value.session = session;
            value.account = account;
        }
        var original = statement.*;
        var store: Store = .{ .mode = mode, .original_text = &original, .control = &control };
        defer if (store.record) |record| t.allocator.free(record);
        var peer: Peer = .{ .io = io, .listener = &listener, .store = &store };
        var task = try io.concurrent(Peer.run, .{&peer});
        defer task.cancel(io) catch {};
        var executor: sdk.Executor = .{ .client = &client, .control = &control, .config = config };
        const result = executor.execute(&original, null, .{ .before_submit = .{ .context = &store, .persist = Store.persist } });
        switch (mode) {
            .store_failure => try t.expectError(error.StoreUnavailable, result),
            .cancelled_store => try t.expectError(error.Canceled, result),
            .changed_scope => try t.expectError(error.SqlSubmissionScopeChanged, result),
            .success, .lost_reply, .denied_context => {
                const outcome = try result;
                defer outcome.deinit();
                if (mode == .denied_context) {
                    try t.expectEqualStrings("AccessDenied", outcome.value.failure.code);
                } else {
                    try t.expectEqual(.applied, outcome.value.command.outcome);
                    try t.expectEqual(43, outcome.value.command.operation.?.id);
                }
            },
        }
        try task.await(io);
        try t.expectEqual(@as(usize, if (mode == .denied_context) 0 else 1), store.calls);
        try t.expectEqual(@as(usize, if (mode == .success or mode == .lost_reply) 1 else 0), peer.executes);
        try t.expectEqual(@as(usize, if (mode == .lost_reply) 1 else 0), peer.statuses);
        if (store.record) |bytes| {
            try t.expect(std.mem.indexOf(u8, bytes, "\"session\"") == null);
            const saved = try api.Json.parseFromSliceOwned(sdk.Executor.Submission, t.allocator, bytes);
            defer saved.deinit();
            // A replacement authenticated session can observe the same token.
            control.session = @splat(55);
            const pending = try saved.value.pending(&control);
            try t.expectEqual(saved.value.execute.token.?, pending.token);
            try t.expectEqual(account, pending.account);
            control.instance = @splat(56);
            try t.expectError(error.SqlInstanceChanged, saved.value.pending(&control));
            control.instance = instance;
            control.account = @splat(57);
            try t.expectError(error.SqlObservationDenied, saved.value.pending(&control));
            control.account = account;
            control.session = null;
            try t.expectError(error.SqlSessionRequired, saved.value.pending(&control));
            var foreign = saved.value;
            foreign.version = 0;
            try t.expectError(error.IncompatibleSqlDefinition, foreign.validate());
            const changed = try t.allocator.dupe(u8, bytes);
            defer t.allocator.free(changed);
            const offset = std.mem.indexOf(u8, changed, @tagName(api.native.current_definition)).?;
            changed[offset] = if (changed[offset] == '0') '1' else '0';
            try t.expectError(error.InvalidJsonShape, api.Json.parseFromSliceOwned(sdk.Executor.Submission, t.allocator, changed));
            const missing = try api.Json.valueAlloc(t.allocator, .{
                .version = saved.value.version,
                .instance = saved.value.instance,
                .account = saved.value.account,
                .database = saved.value.database,
                .source = saved.value.source,
                .transaction = saved.value.transaction,
                .execute = saved.value.execute,
            });
            defer t.allocator.free(missing);
            try t.expectError(error.MissingField, api.Json.parseFromSliceOwned(sdk.Executor.Submission, t.allocator, missing));
            foreign = saved.value;
            foreign.execute.token = null;
            try t.expectError(error.InvalidSqlSubmission, foreign.validate());
        }
    }
}
