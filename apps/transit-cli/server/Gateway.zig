//! Separate credential-free process forwarding the native signed protocol.
const std = @import("std");
const http = @import("transit_http_server");
const wire = @import("transit_query").wire;
const Hosts = @import("Hosts.zig");
pub const Config = struct { port: u16, upstream: []const u8, allowed_hosts: []const []const u8 = &.{} };
pub fn run(init: std.process.Init, path: []const u8) !void {
    const config = try @import("Files.zig").read(Config, init.io, init.arena.allocator(), path);
    var context: Context = .{ .config = config, .hosts = try Hosts.list(init.arena.allocator(), config.port, config.allowed_hosts) };
    for (&context.upstream) |*slot| slot.* = .{ .client = wire.Client.init(init.gpa, init.io, config.upstream) };
    defer for (&context.upstream) |*slot| slot.client.deinit();
    var listener = try (try std.Io.net.IpAddress.parseIp4("127.0.0.1", config.port)).listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    try http.serve(init.io, init.gpa, &listener, .{ .connections = 16, .requests = 4, .control_requests = 2, .wait_requests = 4, .request_timeout_ms = 4000, .header_timeout_ms = 1000, .requests_per_connection = 64 }, &context);
}
const Context = struct {
    config: Config,
    hosts: []const []const u8,
    upstream: [10]Slot = undefined,
    const Slot = struct { client: wire.Client, busy: std.atomic.Value(bool) = .init(false) };
    pub fn connectionError(_: *Context, err: anyerror, started: bool) void {
        const name = transportFailure(err, started) orelse return;
        std.debug.print("gateway transport: {s}\n", .{name});
    }
    pub fn isWait(_: *Context, request: *std.http.Server.Request) bool {
        return (http.header(request, "x-transit-wait") catch null) != null;
    }
    pub fn isControl(_: *Context, request: *std.http.Server.Request) bool {
        return std.mem.eql(u8, request.head.target, "/v1/command") or
            (if (http.header(request, "x-transit-control") catch null) |value| std.mem.eql(u8, value, "snapshot") else false);
    }
    pub fn handle(self: *Context, _: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
        if (!Hosts.allows(self.hosts, (try http.header(request, "host")).?)) return http.respond(request, .forbidden, "{\"err\":\"InvalidHost\"}");
        var headers = request.iterateHeaders();
        while (headers.next()) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "origin") or std.ascii.eqlIgnoreCase(header.name, "authorization") or
                std.ascii.eqlIgnoreCase(header.name, "forwarded") or std.ascii.startsWithIgnoreCase(header.name, "x-forwarded-") or
                std.ascii.eqlIgnoreCase(header.name, "x-real-ip")) return http.respond(request, .forbidden, "{\"err\":\"InvalidIdentityHeader\"}");
        }
        const control = if (try http.header(request, "x-transit-control")) |value| control: {
            if (!std.mem.eql(u8, value, "snapshot")) return http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}");
            break :control true;
        } else false;
        var wait_buffer: [32]u8 = undefined;
        const wait_value: ?[]const u8 = if (try http.header(request, "x-transit-wait")) |value| hint: {
            const parsed = wire.WaitHint.parse(value) catch return http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}");
            break :hint try parsed.format(&wait_buffer);
        } else null;
        if (wait_value != null and (control or !std.mem.eql(u8, request.head.target, "/v1/query"))) return http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}");
        const health = request.head.method == .GET and std.mem.eql(u8, request.head.target, "/health");
        if (!health and !(request.head.method == .POST and (std.mem.eql(u8, request.head.target, "/v1/command") or std.mem.eql(u8, request.head.target, "/v1/query"))))
            return http.respond(request, .not_found, "{\"err\":\"NotFound\"}");
        // Reading a request body invalidates Head string slices. Own the target
        // before that boundary, including for a bodyless health request.
        const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ self.config.upstream, request.head.target });
        defer allocator.free(url);
        const body = request.readerExpectNone(&.{}).allocRemaining(allocator, .limited(if (health) 1 else wire.max_body + 1)) catch return http.respond(request, .payload_too_large, "{\"err\":\"InvalidBody\"}");
        defer allocator.free(body);
        if (body.len > (if (health) @as(usize, 0) else wire.max_body)) return http.respond(request, .payload_too_large, "{\"err\":\"InvalidBody\"}");
        const slots = if (wait_value != null) self.upstream[6..10] else self.upstream[0..6];
        const slot = for (slots) |*candidate| {
            if (candidate.busy.cmpxchgStrong(false, true, .acquire, .monotonic) == null) break candidate;
        } else return http.respond(request, .service_unavailable, "{\"err\":\"HttpCapacity\"}");
        defer slot.busy.store(false, .release);
        slot.client.beginExchange();
        const output = try allocator.alloc(u8, wire.max_body);
        defer allocator.free(output);
        var writer: std.Io.Writer = .fixed(output);
        var forwarded: [1]std.http.Header = undefined;
        var forwarded_count: usize = 0;
        if (control) {
            forwarded[0] = .{ .name = "x-transit-control", .value = "snapshot" };
            forwarded_count = 1;
        } else if (wait_value) |value| {
            forwarded[0] = .{ .name = "x-transit-wait", .value = value };
            forwarded_count = 1;
        }
        const response = slot.client.http.fetch(.{ .location = .{ .url = url }, .method = if (health) .GET else .POST, .payload = if (health) null else body, .headers = .{ .content_type = .{ .override = "application/json" } }, .redirect_behavior = .not_allowed, .extra_headers = forwarded[0..forwarded_count], .keep_alive = true, .response_writer = &writer }) catch return http.respond(request, .service_unavailable, "{\"err\":\"AuthorityUnavailable\"}");
        try request.respond(writer.buffered(), .{ .status = response.status, .keep_alive = true, .extra_headers = &.{
            .{ .name = "content-type", .value = "application/json" },
            .{ .name = "cache-control", .value = "no-store" },
            .{ .name = "x-content-type-options", .value = "nosniff" },
        } });
    }
};

fn transportFailure(err: anyerror, started: bool) ?[]const u8 {
    // An idle peer's orderly close is normal. Once dispatch starts, a deadline
    // can interrupt an upstream request and must not disappear as idle expiry.
    if (!started and (err == error.EndOfStream or err == error.HttpConnectionClosing or err == error.HttpDeadline)) return null;
    return if (err == error.HttpDeadline) "HttpRequestDeadline" else @errorName(err);
}

test "gateway diagnostics distinguish idle expiry from an interrupted request" {
    const t = std.testing;
    try t.expect(transportFailure(error.HttpConnectionClosing, false) == null);
    try t.expect(transportFailure(error.HttpDeadline, false) == null);
    try t.expectEqualStrings("HttpRequestDeadline", transportFailure(error.HttpDeadline, true).?);
    try t.expectEqualStrings("HttpConnectionClosing", transportFailure(error.HttpConnectionClosing, true).?);
    try t.expectEqualStrings("HttpCapacity", transportFailure(error.HttpCapacity, false).?);
}
