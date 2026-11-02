//! A real HTTP peer exercises original-operation settlement and result opening.
//! Native receipt construction here supplies no installed storage proof.
const std = @import("std");
const sdk = @import("root.zig");
const api = sdk.protocol;
const r = sdk.results;
const p = r.protocol;
const t = std.testing;
const instance: api.Instance = @splat(7);
const session: api.Id = @splat(8);
const account: api.Account = @splat(9);
const Mode = enum { direct, lost_reply, lost_session, foreign_result, denied_disclosure };

fn selection() p.StreamQueue.ClaimReceipt {
    const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    return .{ .claim = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(5) }, .partition = 0 }, .operation = .{ .scope = scope, .principal = 6, .operation = 7 }, .maximum = 2, .lease_ms = 1000 }, .accepted = .{ .partition = 8, .next_lsn = 9 }, .observed_ms = 100, .expires_ms = 1100, .rows = 0, .leases = null };
}
const Peer = struct {
    io: std.Io,
    listener: *std.Io.net.Server,
    mode: Mode,
    executes: usize = 0,
    statuses: usize = 0,
    results: usize = 0,
    fetches: usize = 0,
    closes: usize = 0,
    opens: u8 = 0,
    current_session: api.Id = session,
    token: ?api.Token = null,
    fn evidence() !r.Workload.Evidence {
        return .{ .intent = .{ .sha256 = @splat(10), .bytes = 11 }, .binding = try (p.LogWorkloadResult.Selection{ .claim = selection() }).binding(t.allocator), .receipt = .{ .claim = selection() } };
    }
    fn frame(self: *Peer) ![]align(64) u8 {
        const receipt = selection();
        const fields = [_]r.Types.Field{.{ .name = "payload", .type = .utf8 }};
        const schema: r.Types.Type = .{ .structure = &fields };
        var buffer: [256]u8 = undefined;
        const saved = try evidence();
        var observation: r.Observation.Value = .{ .data = .{ .workload = .{ .intent = saved.intent, .schema = @splat(12), .projection = @splat(13), .limit = null, .selection = .{ .claim = receipt } } } };
        if (self.mode == .foreign_result) observation.data.workload.intent.sha256[0] ^= 1;
        return api.ResultFrame.encode(t.allocator, .{ .instance = instance, .cursor = @splat(14), .ordinal = 0, .rows = 0, .schema = try schema.fingerprint(), .observation = try r.Observation.fingerprint(t.allocator, observation), .description = .{ .schema = try schema.encode(&buffer), .observation = observation }, .columns = &.{}, .completion = .{ .rows = 0, .workload = .{ .intent = observation.data.workload.intent, .position = .{ .claim = .{ .receipt = receipt, .next = 0 } } } } });
    }
    fn run(self: *Peer) !void {
        for (0..16) |_| {
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
            if (parsed.value.action != .hello and parsed.value.action != .open) try t.expectEqual(self.current_session, parsed.value.session.?);
            var response: api.JsonResponse = .{ .version = 1, .definition = api.native.current_definition, .instance = instance, .result = undefined };
            var control_response = false;
            switch (parsed.value.action) {
                .hello => {
                    control_response = true;
                    response.result = .{ .hello = .{ .encoding = api.encoding, .session_lease_ms = 1000, .maximum_message = api.max_message_bytes, .maximum_batch = api.max_batch_bytes, .maximum_rows = api.max_rows, .capabilities = &.{} } };
                },
                .open => |value| {
                    self.opens += 1;
                    self.current_session = @splat(32 + self.opens);
                    control_response = true;
                    response.result = .{ .opened = .{ .session = self.current_session, .account = account, .database = value.database } };
                },
                .close => {
                    control_response = true;
                    response.result = .closed;
                },
                .execute => |value| {
                    self.executes += 1;
                    try t.expectEqual(1, self.executes);
                    self.token = value.token.?;
                    if (self.mode == .lost_reply or self.mode == .lost_session) continue;
                },
                .status => |target| {
                    self.statuses += 1;
                    try t.expectEqual(self.token.?, target.token);
                    if (self.mode == .lost_session and self.statuses == 1) {
                        control_response = true;
                        response.result = .{ .err = .{ .code = "SqlSessionExpired", .sqlstate = "55000".*, .message = "expired", .retry = .control } };
                    }
                },
                .result => |operation| {
                    self.results += 1;
                    try t.expectEqualDeep(r.Operation{ .account = account, .id = 15, .kind = .workload }, operation);
                },
                .fetch => |value| {
                    self.fetches += 1;
                    try t.expectEqual(@as(api.Id, @splat(14)), value.cursor);
                    try t.expectEqual(0, value.batch);
                },
                .close_result => |cursor| {
                    try t.expectEqual(@as(api.Id, @splat(14)), cursor);
                    self.closes += 1;
                    response.result = .closed;
                    const reply = try api.Json.valueAlloc(t.allocator, response);
                    defer t.allocator.free(reply);
                    try request.respond(reply, .{ .keep_alive = false, .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }} });
                    return;
                },
                else => return error.UnexpectedWorkloadClientRequest,
            }
            if (control_response) {
                // hello/open/expiry/close already supplied their exact result.
            } else if (parsed.value.action == .result or parsed.value.action == .fetch) {
                if (self.mode == .denied_disclosure and parsed.value.action == .fetch) {
                    response.result = .{ .err = .{ .code = "AccessDenied", .sqlstate = "42501".*, .message = "revoked", .retry = .never } };
                } else {
                    const frame_bytes = try self.frame();
                    defer t.allocator.free(frame_bytes);
                    try request.respond(frame_bytes, .{ .keep_alive = false, .extra_headers = &.{.{ .name = "content-type", .value = api.ResultFrame.content_type }} });
                    continue;
                }
            } else response.result = .{ .operation = .{ .identity = .{ .account = account, .id = 15, .kind = .workload }, .command = .claim, .token = self.token.?, .phase = .terminal, .outcome = .applied, .result_kind = .rows, .workload = try evidence() } };
            const reply = try api.Json.valueAlloc(t.allocator, response);
            defer t.allocator.free(reply);
            try request.respond(reply, .{ .keep_alive = false, .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }} });
        }
        return error.WorkloadClientRequestBudget;
    }
};

test "workload settlement opens only original rows after lost execute and checks terminal disclosure" {
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
        var peer: Peer = .{ .io = io, .listener = &listener, .mode = mode };
        var task = try io.concurrent(Peer.run, .{&peer});
        defer task.cancel(io) catch {};
        var executor: sdk.Executor = .{ .client = &client, .control = &control, .config = config };
        const result = executor.execute("CLAIM * FROM work WITH LEASE '1s'", null, .{});
        if (mode == .foreign_result) {
            try t.expectError(error.WorkloadResultConflict, result);
        } else {
            const outcome = try result;
            defer outcome.deinit();
            try t.expect(outcome.value == .rows);
            try t.expectEqual(0, outcome.value.rows.completion().?.rows);
            if (mode == .denied_disclosure) {
                try t.expectError(error.SqlObservationDenied, outcome.value.rows.validateDisclosure());
            } else try outcome.value.rows.validateDisclosure();
            try outcome.value.rows.close();
        }
        try task.await(io);
        try t.expectEqual(1, peer.executes);
        try t.expectEqual(1, peer.results);
        try t.expectEqual(1, peer.closes);
        try t.expectEqual(@as(usize, if (mode == .lost_session) 2 else if (mode == .lost_reply) 1 else 0), peer.statuses);
        try t.expectEqual(@as(u8, if (mode == .lost_session) 2 else 0), peer.opens);
        try t.expectEqual(mode == .lost_session, executor.session_lost);
        try t.expectEqual(client.session, control.session);
    }
}
