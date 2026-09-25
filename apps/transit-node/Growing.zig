//! Explicit development profile. It does not reinterpret a v2 installation.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const wire = @import("transit_client");
const observations = @import("transit_observability");
const telemetry = observations.telemetry;
const g = wire.protocol.Growth;
const Engine = core.growing.Engine(adapter.GrowingStore, adapter.PackedPageStore);
const Maintenance = @import("GrowingMaintenance.zig");
const Config = struct {
    profile: enum { growing_v3 },
    genesis: core.growing.Genesis,
    ursula_url: []const u8,
    bucket: []const u8,
    journal: []const u8,
    listen: []const u8 = "127.0.0.1",
    port: u16 = 8080,
    request_timeout_ms: u32 = 2000,
    resident_pages: u16 = 16,
    accept_trace_parent: bool = false,
    maintenance: ?Maintenance.Config = null,
};

pub fn run(init: std.process.Init, bytes: []const u8, mode: anytype, diagnostics: *telemetry.Runtime, comptime serve: anytype) !void {
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidTimeout;
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = config.ursula_url, .max_response_bytes = 256 * 1024 });
    defer client.deinit();
    var journal: adapter.GrowingStore = .{ .journal = .{ .client = &client, .stream = .{ .bucket = config.bucket, .name = config.journal }, .observer = diagnostics } };
    var pages = try adapter.PackedPageStore.init(init.gpa, journal.journal, config.resident_pages);
    defer pages.deinit();
    if (mode.initialize or mode.bootstrap) {
        try journal.journal.create();
        try pages.create();
    }
    var recovery = observations.begin(diagnostics, .recovery, if (mode.initialize or mode.bootstrap) "bootstrap" else "open", null);
    journal.journal.parent_context = recovery.span.context;
    pages.authority.parent_context = recovery.span.context;
    var engine = (if (mode.initialize or mode.bootstrap) Engine.bootstrap(&journal, &pages, config.genesis) else Engine.open(&journal, &pages, config.genesis)) catch |err| {
        recovery.fail(err);
        recovery.finish();
        return err;
    };
    recovery.event.realm = config.genesis.realm;
    recovery.event.position = engine.head.position;
    recovery.finish();
    journal.journal.parent_context = null;
    pages.authority.parent_context = null;
    if (mode.initialize) return;
    var clock_context: u8 = 0;
    if (config.genesis.max_clock_error_ms != null) engine.clock = .{ .context = &clock_context, .read = @import("Clock.zig").read };
    if (mode.maintain) return Maintenance.run(init, &engine, config.maintenance orelse return error.MissingMaintenanceConfig, diagnostics);
    var server: Server = .{ .io = init.io, .allocator = init.gpa, .engine = &engine, .accept_trace_parent = config.accept_trace_parent };
    return serve(init, &server, config.listen, config.port, config.request_timeout_ms, diagnostics);
}

const Server = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    engine: *Engine,
    observation: telemetry.Http = .{},
    accept_trace_parent: bool,

    fn json(self: *Server, request: *std.http.Server.Request, status: std.http.Status, value: anytype) !void {
        const bytes = try std.json.Stringify.valueAlloc(self.allocator, value, .{});
        defer self.allocator.free(bytes);
        self.observation.status = @backingInt(status);
        if (@hasField(@TypeOf(value), "err")) {
            self.observation.error_type = @tagName(value.err);
            self.observation.protocol_outcome = if (status == .service_unavailable) .uncertain else .rejected;
        }
        try request.respond(bytes, .{ .status = status, .keep_alive = false, .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }} });
        self.observation.written = true;
    }
    fn failure(self: *Server, request: *std.http.Server.Request, err: anyerror) !void {
        const denied = switch (err) {
            error.Unauthorized, error.Forbidden, error.WrongProtocolRealm, error.SignatureVerificationFailed, error.IdentityElement, error.NonCanonical, error.InvalidEncoding => true,
            else => false,
        };
        if (denied) return self.json(request, .forbidden, wire.protocol.ErrorResponse{ .err = .AccessDenied });
        const code = std.meta.stringToEnum(wire.protocol.ErrorCode, @errorName(err)) orelse .AuthorityUnavailable;
        const status: std.http.Status = switch (code) {
            .Conflict, .QueryExpired, .HistoryReclaimed => .conflict,
            .AuthorityUnavailable, .ClockRollback, .ClockUnavailable, .DeadlineUncertain, .UntrustedTime, .AdmissionClosed, .ControlCapacity => .service_unavailable,
            else => .unprocessable_entity,
        };
        return self.json(request, status, wire.protocol.ErrorResponse{ .err = code });
    }
    pub fn handle(self: *Server, stream: std.Io.net.Stream) !void {
        var input: [8192]u8 = undefined;
        var output: [4096]u8 = undefined;
        var reader = stream.reader(self.io, &input);
        var writer = stream.writer(self.io, &output);
        var http = std.http.Server.init(&reader.interface, &writer.interface);
        var request = try http.receiveHead();
        const route: []const u8 = route: {
            inline for (.{ "/health", "/v3/command", "/v3/query" }) |known| if (std.mem.eql(u8, request.head.target, known)) break :route known;
            break :route "unmatched";
        };
        self.observation.received(&request, route, self.accept_trace_parent);
        self.engine.journal.journal.parent_context = self.observation.span.context;
        self.engine.page_store.authority.parent_context = self.observation.span.context;
        defer self.engine.journal.journal.parent_context = null;
        defer self.engine.page_store.authority.parent_context = null;
        if (request.head.method == .GET and std.mem.eql(u8, route, "/health")) {
            try self.engine.refresh();
            return self.json(&request, .ok, .{ .ready = true, .profile = "growing_v3" });
        }
        const mutation = std.mem.eql(u8, route, "/v3/command");
        if (request.head.method != .POST or (!mutation and !std.mem.eql(u8, route, "/v3/query"))) return self.json(&request, .not_found, wire.protocol.ErrorResponse{ .err = .NotFound });
        const bytes = request.readerExpectNone(&.{}).allocRemaining(self.allocator, .limited(wire.max_body)) catch return self.json(&request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidBody });
        defer self.allocator.free(bytes);
        if (mutation) {
            const parsed = std.json.parseFromSlice(g.SignedRequest, self.allocator, bytes, .{}) catch return self.json(&request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
            defer parsed.deinit();
            g.validate(parsed.value.request) catch return self.json(&request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
            self.observation.protocol_outcome = .uncertain;
            const position = self.engine.submit(parsed.value) catch |err| return self.failure(&request, err);
            self.observation.protocol_outcome = .receipt;
            self.observation.realm = parsed.value.request.realm;
            self.observation.sequence = parsed.value.request.sequence;
            self.observation.pid = g.commandPid(parsed.value.request.command);
            self.observation.operation = @tagName(parsed.value.request.command);
            self.observation.position = position;
            return self.json(&request, .ok, wire.Receipt{ .position = position });
        }
        const parsed = std.json.parseFromSlice(g.SignedQuery, self.allocator, bytes, .{}) catch return self.json(&request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
        defer parsed.deinit();
        g.validateQuery(parsed.value.query) catch return self.json(&request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
        const response = self.engine.query(parsed.value) catch |err| return self.failure(&request, err);
        self.observation.protocol_outcome = .read;
        self.observation.realm = response.realm;
        self.observation.operation = @tagName(parsed.value.query.kind);
        self.observation.position = response.position;
        return self.json(&request, .ok, response);
    }
};
