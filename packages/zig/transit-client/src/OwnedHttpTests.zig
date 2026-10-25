const std = @import("std");
const wire = @import("root.zig");
const Io = std.Io;
const Payload = struct { text: []const u8, rows: []const []const []const u8 };
const body = "{\"text\":\"owned text\",\"rows\":[[\"first\",\"second\"],[\"third\"]]}";

test "upstream unavailability cannot become a receipt or an authority rejection" {
    const t = std.testing;
    const Case = struct { status: std.http.Status, bytes: []const u8, expected: anyerror, rejection: ?wire.protocol.ErrorCode = null };
    const cases = [_]Case{
        .{ .status = .service_unavailable, .bytes = "{\"err\":\"HttpCapacity\"}", .expected = error.AuthorityUnavailable, .rejection = .HttpCapacity },
        .{ .status = .service_unavailable, .bytes = "", .expected = error.AuthorityUnavailable },
        .{ .status = .service_unavailable, .bytes = "upstream connection unavailable", .expected = error.AuthorityUnavailable },
        .{ .status = .bad_gateway, .bytes = "<html>Upstream connection closed</html>", .expected = error.AuthorityUnavailable },
        .{ .status = .gateway_timeout, .bytes = "upstream timeout", .expected = error.AuthorityUnavailable },
        .{ .status = .ok, .bytes = "", .expected = error.InvalidAuthorityResponse },
        .{ .status = .forbidden, .bytes = "<html>Denied</html>", .expected = error.InvalidAuthorityResponse },
        .{ .status = .forbidden, .bytes = "{\"err\":\"AccessDenied\"}", .expected = error.AccessDenied, .rejection = .AccessDenied },
    };
    const Server = struct {
        fn run(io: Io, listener: *Io.net.Server, result: Case) !void {
            var stream = try listener.accept(io);
            defer stream.close(io);
            var input: [1024]u8 = undefined;
            var output: [1024]u8 = undefined;
            var reader = stream.reader(io, &input);
            var writer = stream.writer(io, &output);
            var server = std.http.Server.init(&reader.interface, &writer.interface);
            var request = try server.receiveHead();
            const received = try request.readerExpectNone(&.{}).allocRemaining(t.allocator, .limited(128));
            defer t.allocator.free(received);
            try t.expectEqualStrings("{\"nonce\":[97,97]}", received);
            try request.respond(result.bytes, .{ .status = result.status, .keep_alive = false });
        }
    };
    var threaded: Io.Threaded = .init(t.allocator, .{ .concurrent_limit = .limited(4) });
    defer threaded.deinit();
    const io = threaded.io();
    for (cases) |case| {
        var listener = try (try Io.net.IpAddress.parseIp4("127.0.0.1", 0)).listen(io, .{ .reuse_address = true });
        defer listener.deinit(io);
        const url = try std.fmt.allocPrint(t.allocator, "http://127.0.0.1:{d}", .{listener.socket.address.getPort()});
        defer t.allocator.free(url);
        var peer = try io.concurrent(Server.run, .{ io, &listener, case });
        defer _ = peer.cancel(io) catch {};
        var client = wire.Client.init(t.allocator, io, url);
        defer client.deinit();
        // A prior parsed rejection must not survive a later opaque upstream
        // response. No case permits the client to manufacture a native result.
        client.last_rejection = .AccessDenied;
        try t.expectError(case.expected, client.callOwned(Payload, "/v1/query", .{ .nonce = [_]u8{ 97, 97 } }, .{ .response_bytes = 1024 }));
        try t.expectEqual(case.rejection, client.last_rejection);
        try t.expectEqual(case.status, client.last_status);
        try peer.await(io);
    }
}

const Peer = struct {
    fn run(io: Io, listener: *Io.net.Server, delay: u32) !void {
        var stream = try listener.accept(io);
        defer stream.close(io);
        var input: [4096]u8 = undefined;
        var output: [4096]u8 = undefined;
        var reader = stream.reader(io, &input);
        var writer = stream.writer(io, &output);
        var server = std.http.Server.init(&reader.interface, &writer.interface);
        var request = try server.receiveHead();
        request.head.keep_alive = false;
        const bytes = try request.readerExpectNone(&.{}).allocRemaining(std.testing.allocator, .limited(1024));
        defer std.testing.allocator.free(bytes);
        try std.testing.expectEqualStrings("{\"nonce\":[97,97]}", bytes);
        if (delay > 0) try io.sleep(.fromMilliseconds(delay), .awake);
        try request.respond(body, .{ .status = .ok, .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }} });
    }
};
test "owned HTTP responses retain nested data after transport destruction and enforce bounds" {
    const t = std.testing;
    var threaded: Io.Threaded = .init(t.allocator, .{ .concurrent_limit = .limited(4) });
    defer threaded.deinit();
    const io = threaded.io();
    for ([_]u32{ 16 * 1024 * 1024, 16 }) |bound| {
        var listener = try (try Io.net.IpAddress.parseIp4("127.0.0.1", 0)).listen(io, .{ .reuse_address = true });
        defer listener.deinit(io);
        const url = try std.fmt.allocPrint(t.allocator, "http://127.0.0.1:{d}", .{listener.socket.address.getPort()});
        defer t.allocator.free(url);
        var task = try io.concurrent(Peer.run, .{ io, &listener, @as(u32, 0) });
        defer _ = task.cancel(io) catch {};
        // The wire ceiling is not an eager allocation requirement. This small
        // body must fit an allocator much smaller than either maximum buffer.
        const workspace = try t.allocator.alloc(u8, 1024 * 1024);
        defer t.allocator.free(workspace);
        var bounded: std.heap.FixedBufferAllocator = .init(workspace);
        var client = wire.Client.init(bounded.allocator(), io, url);
        var alive = true;
        defer if (alive) client.deinit();
        client.timeout_ms = 1000;
        if (bound == 16) {
            try t.expectError(error.WriteFailed, client.callOwned(Payload, "/table/v1", .{ .nonce = [_]u8{ 97, 97 } }, .{ .response_bytes = bound }));
        } else {
            const parsed = try client.callOwned(Payload, "/table/v1", .{ .nonce = [_]u8{ 97, 97 } }, .{ .request_bytes = 8 * 1024 * 1024, .response_bytes = bound });
            defer parsed.deinit();
            client.deinit();
            alive = false;
            try t.expectEqualStrings("owned text", parsed.value.text);
            try t.expectEqualStrings("second", parsed.value.rows[0][1]);
            try t.expectEqualStrings("third", parsed.value.rows[1][0]);
        }
        try task.await(io);
    }
}
test "owned HTTP deadlines cancel in-flight reads without retaining response allocations" {
    const t = std.testing;
    var threaded: Io.Threaded = .init(t.allocator, .{ .concurrent_limit = .limited(4) });
    defer threaded.deinit();
    const io = threaded.io();
    var listener = try (try Io.net.IpAddress.parseIp4("127.0.0.1", 0)).listen(io, .{ .reuse_address = true });
    defer listener.deinit(io);
    const url = try std.fmt.allocPrint(t.allocator, "http://127.0.0.1:{d}", .{listener.socket.address.getPort()});
    defer t.allocator.free(url);
    var task = try io.concurrent(Peer.run, .{ io, &listener, @as(u32, 1000) });
    defer _ = task.cancel(io) catch {};
    var client = wire.Client.init(t.allocator, io, url);
    defer client.deinit();
    client.timeout_ms = 30;
    try t.expectError(error.AuthorityTimeout, client.callOwned(Payload, "/table/v1", .{ .nonce = [_]u8{ 97, 97 } }, .{}));
    try t.expect(client.last_rejection == null);
}

test "owned HTTP rejects oversized serialization before contacting the endpoint" {
    const t = std.testing;
    var threaded: Io.Threaded = .init(t.allocator, .{ .concurrent_limit = .limited(4) });
    defer threaded.deinit();
    var client = wire.Client.init(t.allocator, threaded.io(), "http://127.0.0.1:1");
    defer client.deinit();
    try t.expectError(error.HttpRequestBudget, client.callOwned(Payload, "/table/v1", .{ .text = "too large for eight bytes" }, .{ .request_bytes = 8 }));
    try t.expect(client.last_rejection == null);
}

test "repeated maximum block responses fit a fixed workspace and eight MiB caller stack" {
    const t = std.testing;
    const p = wire.protocol;
    var threaded: Io.Threaded = .init(t.allocator, .{ .concurrent_limit = .limited(4) });
    defer threaded.deinit();
    const io = threaded.io();
    var listener = try (try Io.net.IpAddress.parseIp4("127.0.0.1", 0)).listen(io, .{ .reuse_address = true });
    defer listener.deinit(io);
    const url = try std.fmt.allocPrint(t.allocator, "http://127.0.0.1:{d}", .{listener.socket.address.getPort()});
    defer t.allocator.free(url);
    var query: p.Growth.Query = .{ .realm = 42, .principal = 0, .kind = .{ .block_entries = .{ .source = .{ .resource = .{ .id = 7, .revision = 2 } } } } };
    query.kind.block_entries.keys[0] = try .init("first");
    query.kind.block_entries.keys[1] = try .init("second");
    const response = try t.allocator.create(p.Growth.BlockRead.Response);
    defer t.allocator.destroy(response);
    response.* = .{ .response = .{
        .definition = p.Growth.current_definition,
        .realm = 42,
        .position = 3,
        .principal_sequence = 0,
        .body = .{ .block_entries = .{
            .resource = .{ .id = 7, .writer = 1, .owner = null, .revision = 2, .block_entries = 2, .deadline_ms = null },
            .entries = @splat(null),
        } },
    }, .blocks = .{ .len = p.Blocks.max_batch_bytes, .data = @splat(213) } };
    for (0..2) |i| response.response.body.block_entries.entries[i] = .{
        .key = query.kind.block_entries.keys[i].?,
        .revision = 2,
        .value = try p.Blocks.Spec.of(response.blocks.data[i * p.Blocks.max_block_bytes ..][0..p.Blocks.max_block_bytes]),
    };
    const valid = try std.json.Stringify.valueAlloc(t.allocator, response.*, .{});
    defer t.allocator.free(valid);
    response.blocks.data[p.Blocks.max_batch_bytes - 1] ^= 1;
    const corrupt = try std.json.Stringify.valueAlloc(t.allocator, response.*, .{});
    defer t.allocator.free(corrupt);
    const Server = struct {
        fn run(context: Io, server: *Io.net.Server, replies: [2][]const u8) !void {
            for (0..65) |index| {
                const reply = replies[@intFromBool(index == 64)];
                var stream = try server.accept(context);
                defer stream.close(context);
                var input: [4096]u8 = undefined;
                var output: [4096]u8 = undefined;
                var reader = stream.reader(context, &input);
                var writer = stream.writer(context, &output);
                var http = std.http.Server.init(&reader.interface, &writer.interface);
                var request = try http.receiveHead();
                request.head.keep_alive = index != 64;
                const bytes = try request.readerExpectNone(&.{}).allocRemaining(t.allocator, .limited(p.max_body));
                defer t.allocator.free(bytes);
                try request.respond(reply, .{ .status = .ok });
            }
        }
    };
    var server = try io.concurrent(Server.run, .{ io, &listener, [2][]const u8{ valid, corrupt } });
    defer _ = server.cancel(io) catch {};
    const Caller = struct {
        client: wire.Client,
        query: p.Growth.Query,
        result: anyerror!void = error.Unexpected,
        fn run(self: *@This()) void {
            self.result = self.read();
        }
        fn read(self: *@This()) !void {
            const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
            const acquired = try self.client.queryBlocks(self.query, key);
            try t.expectEqual(p.Blocks.max_batch_bytes, acquired.blocks.len);
            try t.expect(std.mem.allEqual(u8, acquired.blocks.slice(), 213));
            for (1..64) |_| {
                // Real native reads can outlast the idle reuse window. Exercise
                // connection replacement without adding a wall-clock delay.
                self.client.last_exchange_ms = 0;
                const repeated = try self.client.queryBlocks(self.query, key);
                try t.expect(std.mem.allEqual(u8, repeated.blocks.slice(), 213));
            }
            self.client.last_exchange_ms = 0;
            try t.expectError(error.InvalidAuthorityResponse, self.client.queryBlocks(self.query, key));
            // The first result survives the next exchange and parser destruction.
            try t.expect(std.mem.allEqual(u8, acquired.blocks.slice(), 213));
        }
    };
    const workspace = try t.allocator.alloc(u8, 8 * 1024 * 1024);
    defer t.allocator.free(workspace);
    var bounded: std.heap.FixedBufferAllocator = .init(workspace);
    var caller: Caller = .{ .client = .init(bounded.allocator(), io, url), .query = query };
    defer caller.client.deinit();
    const thread = try std.Thread.spawn(.{ .stack_size = 8 * 1024 * 1024 }, Caller.run, .{&caller});
    thread.join();
    try t.expectEqual(@as(anyerror!void, {}), caller.result);
    try server.await(io);
}
