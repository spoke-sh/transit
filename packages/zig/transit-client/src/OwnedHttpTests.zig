const std = @import("std");
const wire = @import("root.zig");
const Io = std.Io;
const Payload = struct { text: []const u8, rows: []const []const []const u8 };
const body = "{\"text\":\"owned text\",\"rows\":[[\"first\",\"second\"],[\"third\"]]}";
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
    for ([_]u32{ 1024, 16 }) |bound| {
        var listener = try (try Io.net.IpAddress.parseIp4("127.0.0.1", 0)).listen(io, .{ .reuse_address = true });
        defer listener.deinit(io);
        const url = try std.fmt.allocPrint(t.allocator, "http://127.0.0.1:{d}", .{listener.socket.address.getPort()});
        defer t.allocator.free(url);
        var task = try io.concurrent(Peer.run, .{ io, &listener, @as(u32, 0) });
        defer _ = task.cancel(io) catch {};
        var client = wire.Client.init(t.allocator, io, url);
        var alive = true;
        defer if (alive) client.deinit();
        client.timeout_ms = 1000;
        if (bound == 16) {
            try t.expectError(error.WriteFailed, client.callOwned(Payload, "/table/v1", .{ .nonce = [_]u8{ 97, 97 } }, .{ .response_bytes = bound }));
        } else {
            const parsed = try client.callOwned(Payload, "/table/v1", .{ .nonce = [_]u8{ 97, 97 } }, .{ .response_bytes = bound });
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
