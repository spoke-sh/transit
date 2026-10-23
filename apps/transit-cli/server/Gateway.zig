//! Separate credential-free process forwarding the native signed protocol.
const std = @import("std");
const http = @import("transit_http_server");
const wire = @import("transit_query").wire;
const table = @import("transit_query").catalog.DirectTableProtocol;
const Configuration = @import("Configuration.zig");
const C = @import("transit_query").settings.Contract;
const Hosts = @import("Hosts.zig");
const telemetry = wire.observability.telemetry;
pub const Config = struct { port: u16, upstream: []const u8, allowed_hosts: []const []const u8 = &.{}, configuration: ?Configuration.Deployment = null };
pub fn run(init: std.process.Init, path: []const u8) !void {
    const config = try @import("Files.zig").read(Config, init.io, init.arena.allocator(), path);
    var diagnostics = telemetry.Runtime.init(init.io, "transit-gateway", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    var context: Context = .{ .diagnostics = &diagnostics, .config = config, .hosts = try Hosts.list(init.arena.allocator(), config.port, config.allowed_hosts) };
    if (config.configuration) |deployment| context.configuration = .{ .init = init, .deployment = deployment };
    for (&context.upstream) |*slot| slot.* = .{ .client = wire.Client.init(init.gpa, init.io, config.upstream) };
    defer for (&context.upstream) |*slot| slot.client.deinit();
    var listener = try (try std.Io.net.IpAddress.parseIp4("127.0.0.1", config.port)).listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    try http.serve(init.io, init.gpa, &listener, .{ .connections = 16, .requests = 4, .control_requests = 2, .wait_requests = 4, .request_timeout_ms = 4000, .header_timeout_ms = 1000, .requests_per_connection = 64 }, &context);
}
const Context = struct {
    config: Config,
    diagnostics: ?*telemetry.Runtime = null,
    configuration: ?Configuration = null,
    hosts: []const []const u8,
    upstream: [10]Slot = undefined,
    const Slot = struct { client: wire.Client, busy: std.atomic.Value(bool) = .init(false) };
    pub fn connectionError(self: *Context, err: anyerror, started: bool) void {
        const name = transportFailure(err, started) orelse return;
        if (self.diagnostics) |diagnostics| diagnostics.event(.{ .name = "gateway.transport", .level = .warn, .outcome = .failed, .error_type = name });
    }
    pub fn isWait(_: *Context, request: *std.http.Server.Request) bool {
        return (http.header(request, "x-transit-wait") catch null) != null;
    }
    pub fn isControl(_: *Context, request: *std.http.Server.Request) bool {
        return std.mem.eql(u8, request.head.target, C.route) or std.mem.eql(u8, request.head.target, "/v1/command") or
            (if (http.header(request, "x-transit-control") catch null) |value| (std.mem.eql(u8, value, "snapshot") or (std.mem.eql(u8, value, "table") and std.mem.eql(u8, request.head.target, "/table/v1"))) else false);
    }
    pub fn handle(self: *Context, _: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
        var arena: std.heap.ArenaAllocator = .init(allocator);
        defer arena.deinit();
        const host = (try http.header(request, "host")).?;
        const allowed = if (self.configuration) |*manager| try manager.allows(arena.allocator(), host) else Hosts.allows(self.hosts, host);
        if (!allowed) return http.respond(request, .forbidden, "{\"err\":\"InvalidHost\"}");
        var headers = request.iterateHeaders();
        while (headers.next()) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "origin") or std.ascii.eqlIgnoreCase(header.name, "authorization") or
                std.ascii.eqlIgnoreCase(header.name, "forwarded") or std.ascii.startsWithIgnoreCase(header.name, "x-forwarded-") or
                std.ascii.eqlIgnoreCase(header.name, "x-real-ip")) return http.respond(request, .forbidden, "{\"err\":\"InvalidIdentityHeader\"}");
        }
        const direct = std.mem.eql(u8, request.head.target, "/table/v1");
        const control: ?[]const u8 = if (try http.header(request, "x-transit-control")) |value| control: {
            const expected = if (direct) "table" else "snapshot";
            if (!std.mem.eql(u8, value, expected)) return http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}");
            break :control expected;
        } else null;
        var wait_buffer: [32]u8 = undefined;
        const wait_value: ?[]const u8 = if (try http.header(request, "x-transit-wait")) |value| hint: {
            const parsed = wire.WaitHint.parse(value) catch return http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}");
            break :hint try parsed.format(&wait_buffer);
        } else null;
        if (wait_value != null and (control != null or !std.mem.eql(u8, request.head.target, "/v1/query"))) return http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}");
        const configuration = self.configuration != null and std.mem.eql(u8, request.head.target, C.route);
        const health = request.head.method == .GET and std.mem.eql(u8, request.head.target, "/health");
        if (!health and !(request.head.method == .POST and (std.mem.eql(u8, request.head.target, "/v1/command") or std.mem.eql(u8, request.head.target, "/v1/query") or std.mem.eql(u8, request.head.target, "/v1/blocks") or configuration or direct)))
            return http.respond(request, .not_found, "{\"err\":\"NotFound\"}");
        // Reading a request body invalidates Head string slices. Own the target
        // before that boundary, including for a bodyless health request.
        const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ self.config.upstream, request.head.target });
        defer allocator.free(url);
        const request_limit: usize = if (direct) table.max_request_bytes else wire.max_body;
        const response_limit: usize = if (direct) table.max_response_bytes else wire.max_body;
        const body = request.readerExpectNone(&.{}).allocRemaining(allocator, .limited(if (health) 1 else request_limit + 1)) catch return http.respond(request, .payload_too_large, "{\"err\":\"InvalidBody\"}");
        defer allocator.free(body);
        if (body.len > (if (health) @as(usize, 0) else request_limit)) return http.respond(request, .payload_too_large, "{\"err\":\"InvalidBody\"}");
        if (direct) {
            const parsed = table.Request.parse(allocator, body) catch return http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}");
            defer parsed.deinit();
            if (control != null and parsed.value.transport().control == null) return http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}");
        }
        const slots = if (wait_value != null) self.upstream[6..10] else self.upstream[0..6];
        const slot = for (slots) |*candidate| {
            if (candidate.busy.cmpxchgStrong(false, true, .acquire, .monotonic) == null) break candidate;
        } else return http.respond(request, .service_unavailable, "{\"err\":\"HttpCapacity\"}");
        defer slot.busy.store(false, .release);
        if (configuration) {
            const signed = std.json.parseFromSliceLeaky(C.Signed, arena.allocator(), body, .{ .allocate = .alloc_always }) catch return http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}");
            const response = self.configuration.?.execute(arena.allocator(), &slot.client, signed) catch |err| {
                const status: std.http.Status = switch (err) {
                    error.AccessDenied, error.ConfigurationDenied => .forbidden,
                    error.ConfigurationSnapshotChanged, error.ConfigurationOperationConflict => .conflict,
                    error.AuthorityUnavailable, error.AuthorityTimeout, error.ConfigurationUnavailable => .service_unavailable,
                    else => .bad_request,
                };
                const code = if (status == .forbidden) @import("transit_query").protocol.ErrorCode.AccessDenied else std.meta.stringToEnum(@import("transit_query").protocol.ErrorCode, @errorName(err)) orelse .InvalidRequest;
                return http.respond(request, status, try std.fmt.allocPrint(arena.allocator(), "{{\"err\":\"{s}\"}}", .{@tagName(code)}));
            };
            return http.respond(request, .ok, try @import("transit_query").protocol.Json.valueAlloc(arena.allocator(), response));
        }
        slot.client.beginExchange();
        const output = try allocator.alloc(u8, response_limit);
        defer allocator.free(output);
        var writer: std.Io.Writer = .fixed(output);
        var forwarded: [1]std.http.Header = undefined;
        var forwarded_count: usize = 0;
        if (control) |value| {
            forwarded[0] = .{ .name = "x-transit-control", .value = value };
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
