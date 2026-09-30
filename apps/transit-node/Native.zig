//! Native v1 service over the paged authority. Incompatible histories reject.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const wire = @import("transit_client");
const observations = @import("transit_observability");
const telemetry = observations.telemetry;
const g = wire.protocol.Growth;
const http = @import("transit_http_server");
const Engine = core.growing.Engine(adapter.Store, adapter.PackedPageStore);
const Maintenance = @import("GrowingMaintenance.zig");
const Config = struct {
    profile: enum { native_v1 } = .native_v1,
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

pub fn run(init: std.process.Init, bytes: []const u8, mode: anytype, diagnostics: *telemetry.Runtime) !void {
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidTimeout;
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = config.ursula_url, .max_response_bytes = 256 * 1024 });
    defer client.deinit();
    var journal: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = config.bucket, .name = config.journal }, .observer = diagnostics } };
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
    var snapshot_epoch: [16]u8 = undefined;
    try init.io.randomSecure(&snapshot_epoch);
    engine.snapshot_epoch = snapshot_epoch;
    var server: Server = .{ .io = init.io, .allocator = init.gpa, .engine = &engine, .accept_trace_parent = config.accept_trace_parent };
    var listener = try (try std.Io.net.IpAddress.parseIp4(config.listen, config.port)).listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    var context: Context = .{ .server = &server, .diagnostics = diagnostics };
    diagnostics.event(.{ .name = "service.ready" });
    try http.serve(init.io, init.gpa, &listener, .{ .connections = 16, .requests = 4, .control_requests = 2, .header_timeout_ms = @min(1000, config.request_timeout_ms), .request_timeout_ms = config.request_timeout_ms, .requests_per_connection = 64 }, &context);
}

const Server = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    engine: *Engine,
    observation: telemetry.Http = .{},
    accept_trace_parent: bool,
    mutex: *std.Io.Mutex = undefined,
    locked: bool = false,
    work_started: ?std.Io.Clock.Timestamp = null,
    cache_hits: u64 = 0,
    cache_misses: u64 = 0,

    fn acquire(self: *Server) !void {
        const waiting = std.Io.Clock.Timestamp.now(self.io, .awake);
        defer self.observation.wait_ns = @intCast(@max(0, waiting.durationTo(.now(self.io, .awake)).raw.toNanoseconds()));
        try self.mutex.lock(self.io);
        self.locked = true;
        self.work_started = .now(self.io, .awake);
        self.cache_hits = self.engine.page_store.hits;
        self.cache_misses = self.engine.page_store.misses;
        self.engine.journal.journal.parent_context = self.observation.span.context;
        self.engine.page_store.authority.parent_context = self.observation.span.context;
    }
    fn release(self: *Server) void {
        if (!self.locked) return;
        self.observation.work_ns = @intCast(@max(0, self.work_started.?.durationTo(.now(self.io, .awake)).raw.toNanoseconds()));
        self.observation.cache_hits = self.engine.page_store.hits - self.cache_hits;
        self.observation.cache_misses = self.engine.page_store.misses - self.cache_misses;
        self.engine.journal.journal.parent_context = null;
        self.engine.page_store.authority.parent_context = null;
        self.locked = false;
        self.mutex.unlock(self.io);
    }
    fn json(self: *Server, request: *std.http.Server.Request, status: std.http.Status, value: anytype) !void {
        // The response owns its bytes. Slow peers must not hold authority access.
        self.release();
        const bytes = try std.json.Stringify.valueAlloc(self.allocator, value, .{});
        defer self.allocator.free(bytes);
        self.observation.status = @backingInt(status);
        if (@hasField(@TypeOf(value), "err")) {
            self.observation.error_type = @tagName(value.err);
            self.observation.protocol_outcome = if (status == .service_unavailable) .uncertain else .rejected;
        }
        try request.respond(bytes, .{ .status = status, .keep_alive = true, .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }} });
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
    pub fn handle(self: *Server, request: *std.http.Server.Request) !void {
        defer self.release();
        const route: []const u8 = route: {
            inline for (.{ "/health", "/v1/command", "/v1/query" }) |known| if (std.mem.eql(u8, request.head.target, known)) break :route known;
            break :route "unmatched";
        };
        self.observation.received(request, route, self.accept_trace_parent);
        const control = if (try http.header(request, "x-transit-control")) |value| control: {
            if (!std.mem.eql(u8, value, "snapshot")) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
            break :control true;
        } else false;
        if (request.head.method == .GET and std.mem.eql(u8, route, "/health")) {
            try self.acquire();
            try self.engine.refresh();
            return self.json(request, .ok, .{ .ready = true, .profile = "native_v1" });
        }
        const mutation = std.mem.eql(u8, route, "/v1/command");
        if (request.head.method != .POST or (!mutation and !std.mem.eql(u8, route, "/v1/query"))) return self.json(request, .not_found, wire.protocol.ErrorResponse{ .err = .NotFound });
        const bytes = request.readerExpectNone(&.{}).allocRemaining(self.allocator, .limited(wire.max_body)) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidBody });
        defer self.allocator.free(bytes);
        if (mutation) {
            const parsed = std.json.parseFromSlice(g.SignedRequest, self.allocator, bytes, .{}) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
            defer parsed.deinit();
            g.validate(parsed.value.request) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
            try self.acquire();
            self.observation.protocol_outcome = .uncertain;
            const position = self.engine.submit(parsed.value) catch |err| return self.failure(request, err);
            self.observation.protocol_outcome = .receipt;
            self.observation.realm = parsed.value.request.realm;
            self.observation.sequence = parsed.value.request.sequence;
            self.observation.pid = g.commandPid(parsed.value.request.command);
            self.observation.operation = @tagName(parsed.value.request.command);
            self.observation.position = position;
            return self.json(request, .ok, wire.Receipt{ .position = position });
        }
        const parsed = std.json.parseFromSlice(g.SignedQuery, self.allocator, bytes, .{}) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
        defer parsed.deinit();
        if (control and parsed.value.query.kind != .close_snapshot and !(parsed.value.query.kind == .snapshot_read and parsed.value.query.kind.snapshot_read.finish)) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
        g.validateQuery(parsed.value.query) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
        try self.acquire();
        const response = self.engine.query(parsed.value) catch |err| return self.failure(request, err);
        self.observation.protocol_outcome = .read;
        self.observation.realm = response.realm;
        self.observation.operation = @tagName(parsed.value.query.kind);
        self.observation.position = response.position;
        return self.json(request, .ok, response);
    }
};

/// Network parsing/writes are concurrent; mutable authority and backend clients
/// have one cancelable owner at a time. Every request owns its observation.
const Context = struct {
    server: *Server,
    diagnostics: *telemetry.Runtime,
    mutex: std.Io.Mutex = .init,
    pub fn isControl(_: *@This(), request: *std.http.Server.Request) bool {
        return std.mem.eql(u8, request.head.target, "/v1/command") or
            (if (http.header(request, "x-transit-control") catch null) |value| std.mem.eql(u8, value, "snapshot") else false);
    }
    pub fn connectionError(self: *@This(), err: anyerror, started: bool) void {
        if (!started and err != error.EndOfStream) self.diagnostics.event(.{ .name = "transit.http.connection", .level = .debug, .error_type = @errorName(err) });
    }
    pub fn handle(self: *@This(), io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
        var server = self.server.*;
        server.io = io;
        server.allocator = allocator;
        server.mutex = &self.mutex;
        server.observation = .{ .span = self.diagnostics.begin(.server, null) };
        var failure: ?anyerror = null;
        const read_only = !std.mem.eql(u8, request.head.target, "/v1/command");
        defer server.observation.finish("transit.http.request", failure, if (failure) |err| err == error.Canceled else false, read_only);
        server.handle(request) catch |err| {
            failure = err;
            return err;
        };
    }
};
