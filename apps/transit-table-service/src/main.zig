//! Explicit loopback Table service. A TLS ingress may proxy this private hop.
const std = @import("std");
const q = @import("transit_query");
const http = @import("transit_http_server");
const p = q.protocol;
const Service = q.TableService;
const telemetry = q.wire.observability.telemetry;
const Configuration = struct {
    upstream: []const u8,
    realm: u64,
    principal: u64,
    seed_file: []const u8,
    scope: q.catalog.TableValues.Scope,
    owner: u64,
    port: u16,
    limits: Service.Limits = .{},
    http: http.Options = .{ .connections = 4, .requests = 2, .control_requests = 1, .request_timeout_ms = 30000 },
    upstream_timeout_ms: u32 = 5000,
    fn validate(self: Configuration) !void {
        const scope = try self.scope.native();
        if (self.realm != scope.realm or self.principal == 0 or self.principal > p.max_counter or self.owner == 0 or self.owner > p.max_counter or self.port == 0 or self.upstream_timeout_ms == 0 or self.upstream_timeout_ms > 30000) return error.InvalidTableServiceConfiguration;
        try self.limits.validate();
        try self.http.validate();
    }
};
const Shared = struct {
    config: Configuration,
    key: p.Ed25519.KeyPair,
    diagnostics: *telemetry.Runtime,
    pub fn handle(self: *@This(), io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) anyerror!void {
        if (request.head.method == .GET and std.mem.eql(u8, request.head.target, "/health")) return http.respond(request, .ok, "{\"service\":\"transit-table-service\"}");
        if (request.head.method != .POST or !std.mem.eql(u8, request.head.target, "/table/v1")) return http.respond(request, .not_found, "{\"err\":\"InvalidRequest\"}");
        if (try http.header(request, "origin") != null) return http.respond(request, .forbidden, "{\"err\":\"AccessDenied\"}");
        const content_type = (try http.header(request, "content-type")) orelse return http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}");
        if (!std.mem.eql(u8, content_type, "application/json")) return http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}");
        var observation = self.diagnostics.begin(.server, null);
        defer observation.finish(.{ .name = "table.request", .outcome = .failed });
        const buffer = try allocator.alloc(u8, self.config.limits.resident_bytes);
        defer allocator.free(buffer);
        var fixed: std.heap.FixedBufferAllocator = .init(buffer);
        var arena: std.heap.ArenaAllocator = .init(fixed.allocator());
        defer arena.deinit();
        const bytes = self.execute(io, &arena, request) catch |err| {
            observation.finish(.{ .name = "table.request", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
            return switch (err) {
                error.CatalogDenied, error.AccessDenied => http.respond(request, .forbidden, "{\"err\":\"AccessDenied\"}"),
                error.StaleStateResource => http.respond(request, .conflict, "{\"err\":\"StaleStateResource\"}"),
                error.QueryExpired => http.respond(request, .conflict, "{\"err\":\"QueryExpired\"}"),
                error.AuthorizationChanged, error.Conflict => http.respond(request, .conflict, "{\"err\":\"StaleAuthorizationRevision\"}"),
                error.OutOfMemory, error.WriteFailed, error.QueryResultBudget, error.QueryPageBudget => http.respond(request, .unprocessable_entity, "{\"err\":\"QueryBudgetExceeded\"}"),
                else => if (q.wire.Client.unavailable(err)) http.respond(request, .service_unavailable, "{\"err\":\"HttpCapacity\"}") else http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}"),
            };
        };
        observation.finish(.{ .name = "table.request", .outcome = .ok });
        try http.respond(request, .ok, bytes);
    }
    pub fn connectionError(self: *@This(), err: anyerror, started: bool) void {
        if (!started) self.diagnostics.event(.{ .name = "table.connection", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
    }
    fn execute(self: *@This(), io: std.Io, arena: *std.heap.ArenaAllocator, request: *std.http.Server.Request) ![]const u8 {
        const alloc = arena.allocator();
        const body = try request.readerExpectNone(&.{}).allocRemaining(alloc, .limited(self.config.limits.request_bytes));
        try q.fuze.Types.Json.preflight(body, .{ .bytes = self.config.limits.request_bytes, .depth = 96, .tokens = self.config.limits.request_bytes + 1 });
        const parsed = try p.Json.parseFromSlice(Service.Request, alloc, body);
        defer parsed.deinit();
        var wire = q.wire.Client.init(alloc, io, self.config.upstream);
        defer wire.deinit();
        wire.timeout_ms = self.config.upstream_timeout_ms;
        wire.observer = self.diagnostics;
        const service: Service = .{ .resources = .{ .wire = &wire, .realm = self.config.realm, .principal = self.config.principal, .key = self.key }, .scope = try self.config.scope.native(), .owner = self.config.owner, .limits = self.config.limits };
        const output = try alloc.alloc(u8, self.config.limits.response_bytes);
        return service.execute(arena, parsed.value, output) catch |err| {
            if (err == error.Rejected or err == error.Conflict) {
                if (wire.last_rejection == .StaleStateResource) return error.StaleStateResource;
                if (wire.last_rejection == .QueryExpired) return error.QueryExpired;
            }
            return err;
        };
    }
};
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedConfiguration;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.arena.allocator(), .limited(16384));
    const configuration = (try p.Json.parseFromSlice(Configuration, init.arena.allocator(), bytes)).value;
    try configuration.validate();
    var diagnostics = telemetry.Runtime.init(init.io, "transit-table-service", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    var shared: Shared = .{ .config = configuration, .key = try q.wire.readKey(init.gpa, init.io, configuration.seed_file), .diagnostics = &diagnostics };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&shared.key));
    var listener = try (try std.Io.net.IpAddress.parseIp4("127.0.0.1", configuration.port)).listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    diagnostics.event(.{ .name = "service.ready" });
    try http.serve(init.io, init.gpa, &listener, configuration.http, &shared);
}
