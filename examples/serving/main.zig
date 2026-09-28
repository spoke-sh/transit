const std = @import("std");
const serving = @import("transit_serving");
const http = @import("transit_http_server");
const s = serving.station;
const p = s.protocol;
const telemetry = s.client.observability.telemetry;
const Application = @import("Application.zig");
const Caller = struct { principal: u64, public_key: [32]u8 };
const Gateway = struct {
    service: u64,
    ingress: u64,
    resource: u64,
    port: u16,
    host: []const u8,
    public_origin: []const u8,
    callers: []const Caller,
    listen: []const u8 = "127.0.0.1",
    options: http.Options = .{ .requests = 4 },
};
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    seed_file: ?[]const u8 = null,
    pid: u64 = 0,
    generation: u64 = 0,
    activation_directory: ?[]const u8 = null,
    request_timeout_ms: u32 = 3000,
    role: union(enum) { gateway: Gateway, ingress: serving.Model.Configuration, application: Application },
};
pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "transit-serving-example", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    run(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const bootstrap = args.len == 3 and std.mem.eql(u8, args[1], "--bootstrap-json");
    if (args.len != 2 and !bootstrap) return error.ExpectedConfiguration;
    const bytes = if (bootstrap) args[2] else try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.arena.allocator(), .limited(16384));
    if (bytes.len > 16384) return error.ConfigurationTooLarge;
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    var config = parsed.value;
    if (config.realm == 0 or config.principal == 0 or config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidConfiguration;
    var key = if (bootstrap) key: {
        if (config.seed_file != null or config.role == .gateway) return error.InvalidBootstrap;
        var seed: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &seed);
        try init.io.randomSecure(&seed);
        break :key try p.Ed25519.KeyPair.generateDeterministic(seed);
    } else try s.client.readKey(init.gpa, init.io, config.seed_file orelse return error.MissingSeedFile);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    if (config.role == .gateway) {
        const gateway = config.role.gateway;
        try gateway.options.validate();
        if (gateway.callers.len == 0 or gateway.callers.len > 32 or !std.mem.startsWith(u8, gateway.public_origin, "https://")) return error.InvalidGatewayConfiguration;
        if (!std.mem.eql(u8, gateway.host, gateway.public_origin[8..])) return error.InvalidGatewayOrigin;
        for (gateway.callers, 0..) |caller, index| {
            try serving.Model.identity(caller.principal);
            for (gateway.callers[0..index]) |previous| if (caller.principal == previous.principal) return error.DuplicateCaller;
        }
        var context: Context = .{ .config = config, .key = key, .diagnostics = diagnostics };
        var listener = try (try std.Io.net.IpAddress.parseIp4(gateway.listen, gateway.port)).listen(init.io, .{ .reuse_address = true });
        defer listener.deinit(init.io);
        diagnostics.event(.{ .name = "service.ready", .operation = "http" });
        return http.serve(init.io, init.gpa, &listener, gateway.options, &context);
    }
    if (config.pid == 0 or config.generation == 0) return error.MissingActivation;
    var wire = s.client.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    wire.observer = diagnostics;
    wire.timeout_ms = config.request_timeout_ms;
    if (bootstrap) try s.client.bootstrap.awaitGrowingOwnership(&wire, .{ .realm = config.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .public_key = key.public_key.toBytes() }, key, 120000);
    var host = try s.GrowingGenServer.init(.{ .client = &wire, .realm = config.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .key = key }, "state");
    _ = try host.session.receive();
    const marker = try std.fmt.allocPrint(init.gpa, "{s}/{d}-{d}-{d}.activation", .{ config.activation_directory orelse return error.MissingActivationDirectory, config.realm, config.pid, config.generation });
    defer init.gpa.free(marker);
    const file = std.Io.Dir.cwd().createFile(init.io, marker, .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) return error.FreshOwnershipRequired;
        return err;
    };
    file.close(init.io);
    host.failure_policy = .stop;
    var service: serving.Service = .{ .configuration = if (config.role == .ingress) config.role.ingress else undefined };
    const handler = switch (config.role) {
        .ingress => blk: {
            host.input_guard = service.guard();
            break :blk service.interface();
        },
        .application => |*app| app.interface(),
        .gateway => unreachable,
    };
    diagnostics.event(.{ .name = "service.ready", .operation = @tagName(config.role), .pid = config.pid, .generation = config.generation });
    while (true) {
        const now: u64 = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds());
        const step = host.step(handler, now + 30000) catch |err| {
            diagnostics.event(.{ .name = "serving.worker.step", .operation = @tagName(config.role), .level = .warn, .outcome = if (host.pending != null) .uncertain else .failed, .error_type = @errorName(err) });
            if (err == error.AuthorityTimeout) {
                if (host.pending == null and host.ready != null) try host.discard();
            } else if (host.pending == null and (err == error.Conflict or err == error.Rejected) and (wire.last_rejection == .StaleStateResource or wire.last_rejection == .QueryExpired or wire.last_rejection == .StateViewExpired)) {
                if (wire.last_rejection == .StateViewExpired) host.view_id = null;
            } else if (host.pending == null or err == error.AccessDenied or err == error.StaleActivation or err == error.Rejected or err == error.Conflict) return err;
            try init.io.sleep(.fromMilliseconds(20), .awake);
            continue;
        };
        if (step == .blocked) return host.handler_error orelse error.ServingBlocked;
        if (step == .idle) try init.io.sleep(.fromMilliseconds(20), .awake);
    }
}
const Context = struct {
    config: Config,
    key: p.Ed25519.KeyPair,
    diagnostics: *telemetry.Runtime,
    pub fn connectionError(self: *@This(), err: anyerror, _: bool) void {
        self.diagnostics.event(.{ .name = "serving.http.request", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
    }
    pub fn handle(self: *@This(), io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) anyerror!void {
        self.dispatch(io, allocator, request) catch |err| {
            self.diagnostics.event(.{ .name = "serving.http.request", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
            const status: std.http.Status = switch (err) {
                error.ServingDenied, error.AccessDenied, error.SignatureVerificationFailed => .forbidden,
                error.ServingOperationNotFound => .not_found,
                error.ServiceReadConflict, error.ServingResultPending, error.ServingSequenceConflict, error.Conflict => .conflict,
                error.ResourceUnavailable => .gone,
                error.AuthorityTimeout => .gateway_timeout,
                error.StreamTooLong => .payload_too_large,
                error.InvalidServingCommand, error.InvalidServingRead, error.InvalidFrame, error.SyntaxError, error.UnexpectedToken, error.UnknownField, error.MissingField, error.InvalidEnumTag => .bad_request,
                else => .service_unavailable,
            };
            return http.respond(request, status, "{\"err\":\"ServingRequestFailed\"}");
        };
    }
    fn dispatch(self: *@This(), io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
        const config = self.config.role.gateway;
        if (!std.mem.eql(u8, (try http.header(request, "host")) orelse "", config.host)) return error.ServingDenied;
        if (try http.header(request, "origin")) |origin| if (!std.mem.eql(u8, origin, config.public_origin)) return error.ServingDenied;
        for ([_][]const u8{ "forwarded", "x-forwarded-host", "x-forwarded-proto", "x-forwarded-for", "x-transit-principal" }) |name| if (try http.header(request, name) != null) return error.ServingDenied;
        if (request.head.method == .GET and std.mem.eql(u8, request.head.target, "/health")) return http.respond(request, .ok, "{\"ready\":true}");
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
            const parsed = try std.json.parseFromSlice(p.Growth.SignedRequest, alloc, body, .{});
            const result = try adapter.submit(parsed.value, try self.publicKey(parsed.value.request.principal));
            return http.respond(request, .accepted, try std.json.Stringify.valueAlloc(alloc, result, .{}));
        }
        const parsed = try std.json.parseFromSlice(serving.Model.SignedRead, alloc, body, .{});
        const result = try adapter.read(parsed.value, try self.publicKey(parsed.value.read.principal));
        return http.respond(request, .ok, try std.json.Stringify.valueAlloc(alloc, result, .{}));
    }
    fn publicKey(self: *@This(), principal: u64) ![32]u8 {
        for (self.config.role.gateway.callers) |caller| if (caller.principal == principal) return caller.public_key;
        return error.ServingDenied;
    }
};
