//! HTTP/SSE/WebSocket composition over the public serving contract.
const std = @import("std");
const serving = @import("transit_serving");
const http = @import("transit_http_server");
const s = serving.station;
const p = s.protocol;
const telemetry = s.client.observability.telemetry;
pub const Caller = struct { principal: u64, public_key: [32]u8 };
pub const Gateway = struct {
    service: u64,
    ingress: u64,
    resource: u64,
    port: u16,
    host: []const u8,
    public_origin: []const u8,
    development_allow_insecure_http: bool = false,
    callers: []const Caller,
    listen: []const u8 = "127.0.0.1",
    options: http.Options = .{ .requests = 4 },
    per_caller_requests: u8 = 2,
    reactive: bool = false,
    viewer: ?@import("PrivateClient.zig").Configuration = null,
    clock_error_ms: u32 = 1000,
    pub fn validate(gateway: Gateway) !void {
        try gateway.options.validate();
        if (gateway.reactive and (gateway.options.request_timeout_ms < 5000 or gateway.clock_error_ms > 10000)) return error.InvalidGatewayConfiguration;
        if (gateway.per_caller_requests == 0 or gateway.per_caller_requests > gateway.options.requests) return error.InvalidGatewayConfiguration;
        if (gateway.callers.len == 0 or gateway.callers.len > 32) return error.InvalidGatewayConfiguration;
        const secure = std.mem.startsWith(u8, gateway.public_origin, "https://");
        if (!secure and !(gateway.development_allow_insecure_http and std.mem.startsWith(u8, gateway.public_origin, "http://"))) return error.InvalidGatewayOrigin;
        const host = gateway.public_origin[if (secure) 8 else 7..];
        if (host.len == 0 or host.len > 200 or std.mem.indexOfAny(u8, host, "/@?#\\\r\n\t ,") != null or !std.mem.eql(u8, gateway.host, host)) return error.InvalidGatewayOrigin;
        for (gateway.callers, 0..) |caller, index| {
            try serving.Model.identity(caller.principal);
            for (gateway.callers[0..index]) |previous| if (caller.principal == previous.principal) return error.DuplicateCaller;
        }
    }
};
pub const Configuration = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    request_timeout_ms: u32 = 3000,
    gateway: Gateway,
};
pub const Context = struct {
    config: Configuration,
    key: p.Ed25519.KeyPair,
    diagnostics: *telemetry.Runtime,
    callers: [32]http.Admission = @splat(.{}),
    challenges: @import("ReactiveTransport.zig").Challenges = .{},
    viewer_key: ?p.Ed25519.KeyPair = null,
    pub fn loadViewer(self: *@This(), allocator: std.mem.Allocator, io: std.Io) !void {
        const viewer = self.config.gateway.viewer orelse return;
        if (!self.config.gateway.reactive) return error.InvalidGatewayConfiguration;
        const index = try self.callerIndex(viewer.principal);
        const key = try s.client.readKey(allocator, io, viewer.seed_file);
        if (!std.mem.eql(u8, &key.public_key.toBytes(), &self.config.gateway.callers[index].public_key)) return error.ServingDenied;
        self.viewer_key = key;
    }
    pub fn deinit(self: *@This()) void {
        if (self.viewer_key) |*key| std.crypto.secureZero(u8, std.mem.asBytes(key));
    }
    pub fn isControl(_: *@This(), request: *std.http.Server.Request) bool {
        return request.head.method == .POST and (std.mem.eql(u8, request.head.target, "/reactive/v1/control") or std.mem.eql(u8, request.head.target, "/reactive/v1/client/control"));
    }
    pub fn connectionError(self: *@This(), err: anyerror, _: bool) void {
        self.diagnostics.event(.{ .name = "serving.http.request", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
    }
    pub fn handle(self: *@This(), io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) anyerror!void {
        self.dispatch(io, allocator, request) catch |err| {
            self.diagnostics.event(.{ .name = "serving.http.request", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
            const status: std.http.Status = switch (err) {
                error.ServingDenied, error.AccessDenied, error.SignatureVerificationFailed => .forbidden,
                error.ServingOperationNotFound, error.ReactiveSessionNotFound, error.RefreshNotFound => .not_found,
                error.ReactiveResetRequired, error.ReactiveAttachmentConflict, error.ReactiveGenerationConflict, error.ReactiveSubscriptionConflict, error.RefreshGenerationConflict, error.ServingResultPending, error.ServingSequenceConflict, error.Conflict => .conflict,
                error.ResourceUnavailable, error.ReactiveSessionExpired => .gone,
                error.AuthorityTimeout => .gateway_timeout,
                error.StreamTooLong => .payload_too_large,
                error.ServingCallerCapacity => .too_many_requests,
                error.WebSocketHandshake, error.InvalidJsonShape, error.InvalidJsonConstant, error.InvalidReactiveScope, error.InvalidReactiveCursor, error.InvalidServingCommand, error.InvalidServingRead, error.InvalidServingIdentity, error.InvalidServingRecord, error.ServingPayloadTooLarge, error.InvalidFrame, error.UnsupportedFrame, error.InvalidCorrelation, error.MessageTooLarge, error.ValueTooLarge, error.InvalidValue, error.InvalidSequence, error.WrongProtocolRealm, error.InvalidCharacter, error.Overflow, error.DuplicateField, error.SyntaxError, error.UnexpectedToken, error.UnknownField, error.MissingField, error.InvalidEnumTag => .bad_request,
                else => .service_unavailable,
            };
            return http.respond(request, status, "{\"err\":\"ServingRequestFailed\"}");
        };
    }
    pub fn validateRequest(self: *@This(), request: *std.http.Server.Request) !void {
        const config = self.config.gateway;
        if (!std.mem.eql(u8, (try http.header(request, "host")) orelse "", config.host)) return error.ServingDenied;
        if (try http.header(request, "origin")) |origin| if (!std.mem.eql(u8, origin, config.public_origin)) return error.ServingDenied;
        for ([_][]const u8{ "forwarded", "x-forwarded-host", "x-forwarded-proto", "x-forwarded-for", "x-transit-principal" }) |name| if (try http.header(request, name) != null) return error.ServingDenied;
    }
    fn dispatch(self: *@This(), io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
        try self.validateRequest(request);
        const config = self.config.gateway;
        if (request.head.method == .GET and std.mem.eql(u8, request.head.target, "/health")) return http.respond(request, .ok, "{\"ready\":true}");
        if (config.reactive and (std.mem.eql(u8, request.head.target, "/reactive/v1/client") or std.mem.eql(u8, request.head.target, "/reactive/v1/client/control"))) return @import("PrivateClient.zig").handle(self, io, allocator, request);
        if (config.reactive and std.mem.startsWith(u8, request.head.target, "/reactive/v1/")) return @import("ReactiveTransport.zig").handle(self, io, allocator, request);
        if (request.head.method != .POST) return http.respond(request, .not_found, "{}");
        const submit = std.mem.eql(u8, request.head.target, "/serving/v1/command");
        const read = std.mem.eql(u8, request.head.target, "/serving/v1/read");
        if (!submit and !read) return http.respond(request, .not_found, "{}");
        if (!std.mem.eql(u8, (try http.header(request, "content-type")) orelse "", "application/json")) return error.InvalidServingCommand;
        // Bounded independent storage for all parsing, upstream clients and JSON.
        const memory = try allocator.alloc(u8, 2 * 1024 * 1024);
        defer allocator.free(memory);
        var fixed = std.heap.FixedBufferAllocator.init(memory);
        const alloc = fixed.allocator();
        const body = try request.readerExpectNone(&.{}).allocRemaining(alloc, .limited(8192));
        var wire = s.client.Client.init(alloc, io, self.config.url);
        defer wire.deinit();
        wire.observer = self.diagnostics;
        wire.timeout_ms = self.config.request_timeout_ms;
        const adapter: serving.Adapter = .{ .resources = .{ .wire = &wire, .realm = self.config.realm, .principal = self.config.principal, .key = self.key }, .service = config.service, .ingress = config.ingress, .resource = config.resource };
        if (submit) {
            const parsed = try p.Json.parseFromSlice(p.Growth.SignedRequest, alloc, body);
            const index = try self.callerIndex(parsed.value.request.principal);
            const public_key = config.callers[index].public_key;
            try p.Ed25519.Signature.fromBytes(parsed.value.signature).verify(&try p.Growth.digest(parsed.value.request), try p.Ed25519.PublicKey.fromBytes(public_key));
            if (!self.callers[index].acquire(false, config.per_caller_requests)) return error.ServingCallerCapacity;
            defer self.callers[index].release(false);
            const result = try adapter.submit(parsed.value, public_key);
            return http.respond(request, .accepted, try p.Json.valueAlloc(alloc, result));
        }
        const parsed = try p.Json.parseFromSlice(serving.Model.SignedRead, alloc, body);
        const index = try self.callerIndex(parsed.value.read.principal);
        const public_key = config.callers[index].public_key;
        try parsed.value.verify(public_key);
        if (!self.callers[index].acquire(false, config.per_caller_requests)) return error.ServingCallerCapacity;
        defer self.callers[index].release(false);
        const result = try adapter.read(parsed.value, public_key);
        return http.respond(request, .ok, try p.Json.valueAlloc(alloc, result));
    }
    pub fn callerIndex(self: *@This(), principal: u64) !usize {
        for (self.config.gateway.callers, 0..) |caller, index| if (caller.principal == principal) return index;
        return error.ServingDenied;
    }
};

test {
    std.testing.refAllDecls(@This());
}
