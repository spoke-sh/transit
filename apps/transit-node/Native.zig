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
const Notifications = @import("Notifications.zig");
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
    request_metrics: bool = false,
    maintenance: ?Maintenance.Config = null,
};

pub fn run(init: std.process.Init, bytes: []const u8, mode: anytype, diagnostics: *telemetry.Runtime) !void {
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidTimeout;
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = config.ursula_url, .max_response_bytes = 256 * 1024 });
    defer client.deinit();
    var metrics: adapter.Metrics = .{};
    var journal: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = config.bucket, .name = config.journal }, .observer = diagnostics, .metrics = if (config.request_metrics) &metrics else null } };
    var pages = try adapter.PackedPageStore.init(init.gpa, journal.journal, config.resident_pages);
    defer pages.deinit();
    if (mode.initialize or mode.bootstrap) {
        try journal.journal.create();
        try pages.create();
    }
    var recovery = observations.begin(diagnostics, .recovery, if (mode.initialize or mode.bootstrap) "bootstrap" else "open", null);
    journal.journal.parent_context = recovery.span.context;
    pages.authority.parent_context = recovery.span.context;
    var engine = (if (mode.initialize or mode.bootstrap) Engine.bootstrap(&journal, &pages, config.genesis) else openRetained(init.io, &journal, &pages, config.genesis)) catch |err| {
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
    try http.serve(init.io, init.gpa, &listener, .{ .connections = 16, .requests = 4, .control_requests = 2, .wait_requests = 4, .header_timeout_ms = @min(1000, config.request_timeout_ms), .request_timeout_ms = config.request_timeout_ms, .requests_per_connection = 64 }, &context);
}

fn openRetained(io: std.Io, journal: *adapter.Store, pages: *adapter.PackedPageStore, genesis: core.growing.Genesis) !Engine {
    // Ordinary recovery only reads published history. A transient provider
    // failure can be retried without creating a realm or replaying effects.
    // Corrupt, missing, denied or incompatible history remains a hard failure.
    for (0..3) |attempt| {
        return Engine.open(journal, pages, genesis) catch |err| {
            const temporary = switch (err) {
                error.ServiceUnavailable,
                error.NameServerFailure,
                error.ConnectionRefused,
                error.ConnectionTimedOut,
                error.NetworkUnreachable,
                error.HostUnreachable,
                error.ConnectionResetByPeer,
                error.HttpConnectionClosing,
                error.EndOfStream,
                error.ReadFailed,
                error.WriteFailed,
                => true,
                else => false,
            };
            if (!temporary or attempt == 2) return err;
            try io.sleep(.fromMilliseconds(100), .awake);
            continue;
        };
    }
    unreachable;
}

const Server = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    engine: *Engine,
    observation: telemetry.Http = .{},
    accept_trace_parent: bool,
    mutex: *std.Io.Mutex = undefined,
    locked: bool = false,
    changed: *Notifications = undefined,
    lock_wait_ns: u64 = 0,
    work_started: ?std.Io.Clock.Timestamp = null,
    cache_hits: u64 = 0,
    cache_misses: u64 = 0,
    before_metrics: adapter.Metrics = .{},
    before_pages: u64 = 0,
    before_bytes: u64 = 0,
    metrics: ?Work = null,
    work_failure: ?[]const u8 = null,

    const Work = struct {
        wait_ns: u64,
        work_ns: u64,
        cache_hits: u64,
        cache_misses: u64,
        staged_pages: u64,
        staged_bytes: u64,
        provider: adapter.Metrics,
        failure: ?[]const u8 = null,
    };

    fn acquire(self: *Server) !void {
        const waiting = std.Io.Clock.Timestamp.now(self.io, .awake);
        defer {
            self.lock_wait_ns = @intCast(@max(0, waiting.durationTo(.now(self.io, .awake)).raw.toNanoseconds()));
            self.observation.wait_ns = (self.observation.wait_ns orelse 0) +| self.lock_wait_ns;
        }
        try self.mutex.lock(self.io);
        self.locked = true;
        self.work_started = .now(self.io, .awake);
        self.cache_hits = self.engine.page_store.hits;
        self.cache_misses = self.engine.page_store.misses;
        if (self.engine.journal.journal.metrics) |metrics| {
            self.before_metrics = metrics.*;
            self.before_pages = self.engine.page_store.created;
            self.before_bytes = self.engine.page_store.create_payload_bytes_attempted;
        }
        self.engine.journal.journal.parent_context = self.observation.span.context;
        self.engine.page_store.authority.parent_context = self.observation.span.context;
    }
    fn release(self: *Server) void {
        if (!self.locked) return;
        const work_ns: u64 = @intCast(@max(0, self.work_started.?.durationTo(.now(self.io, .awake)).raw.toNanoseconds()));
        self.observation.work_ns = (self.observation.work_ns orelse 0) +| work_ns;
        self.observation.cache_hits = self.engine.page_store.hits - self.cache_hits;
        self.observation.cache_misses = self.engine.page_store.misses - self.cache_misses;
        if (self.engine.journal.journal.metrics) |metrics| {
            var delta: adapter.Metrics = undefined;
            inline for (@typeInfo(adapter.Metrics).@"struct".field_names) |field|
                @field(delta, field) = @field(metrics.*, field) - @field(self.before_metrics, field);
            const previous = self.metrics;
            self.metrics = .{
                .wait_ns = self.lock_wait_ns,
                .work_ns = work_ns,
                .cache_hits = self.observation.cache_hits.?,
                .cache_misses = self.observation.cache_misses.?,
                .staged_pages = self.engine.page_store.created - self.before_pages,
                .staged_bytes = self.engine.page_store.create_payload_bytes_attempted - self.before_bytes,
                .provider = delta,
                .failure = self.work_failure,
            };
            if (previous) |prior| {
                inline for (.{ "wait_ns", "work_ns", "cache_hits", "cache_misses", "staged_pages", "staged_bytes" }) |field|
                    @field(self.metrics.?, field) +|= @field(prior, field);
                inline for (@typeInfo(adapter.Metrics).@"struct".field_names) |field|
                    @field(self.metrics.?.provider, field) +|= @field(prior.provider, field);
            }
        }
        self.engine.journal.journal.parent_context = null;
        self.engine.page_store.authority.parent_context = null;
        self.locked = false;
        self.mutex.unlock(self.io);
    }
    fn json(self: *Server, request: *std.http.Server.Request, status: std.http.Status, value: anytype) !void {
        // The response owns its bytes. Slow peers must not hold authority access.
        self.release();
        const bytes = try wire.protocol.Json.valueAlloc(self.allocator, value);
        defer self.allocator.free(bytes);
        self.observation.status = @backingInt(status);
        if (@hasField(@TypeOf(value), "err")) {
            self.observation.error_type = @tagName(value.err);
            self.observation.protocol_outcome = if (status == .service_unavailable) .uncertain else .rejected;
        }
        var metric_buffer: [512]u8 = undefined;
        var metric_writer: std.Io.Writer = .fixed(&metric_buffer);
        var headers: [2]std.http.Header = undefined;
        headers[0] = .{ .name = "content-type", .value = "application/json" };
        var count: usize = 1;
        if (self.metrics) |metrics| {
            // Diagnostics are optional and never change the authority result.
            if (std.json.Stringify.value(metrics, .{}, &metric_writer)) |_| {
                headers[1] = .{ .name = "x-transit-work", .value = metric_writer.buffered() };
                count += 1;
            } else |_| {}
        }
        try request.respond(bytes, .{ .status = status, .keep_alive = true, .extra_headers = headers[0..count] });
        self.observation.written = true;
    }
    fn failure(self: *Server, request: *std.http.Server.Request, err: anyerror) !void {
        const denied = switch (err) {
            error.Unauthorized, error.Forbidden, error.WrongProtocolRealm, error.SignatureVerificationFailed, error.IdentityElement, error.NonCanonical, error.InvalidEncoding => true,
            error.UnknownAuthorizationRole, error.UnknownAuthorizationObject, error.UnknownAuthorizationGrant, error.UnknownAuthorizationChange, error.UnknownRoleMembership, error.RetiredAuthorizationRole, error.RetiredAuthorizationObject, error.InvalidAuthorizationDomain => true,
            else => false,
        };
        if (denied) return self.json(request, .forbidden, wire.protocol.ErrorResponse{ .err = .AccessDenied });
        // Opt-in work diagnostics retain a compiler-defined cause category.
        // No arbitrary provider text, keys, payloads or authorization details.
        self.work_failure = @errorName(err);
        const code = std.meta.stringToEnum(wire.protocol.ErrorCode, @errorName(err)) orelse .AuthorityUnavailable;
        const status: std.http.Status = switch (code) {
            .Conflict, .QueryExpired, .HistoryReclaimed, .StaleAuthorizationRevision, .StaleAuthorizationCredential => .conflict,
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
        const hint: ?wire.WaitHint = if (try http.header(request, "x-transit-wait")) |value|
            wire.WaitHint.parse(value) catch return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest })
        else
            null;
        const mutation = std.mem.eql(u8, route, "/v1/command");
        if (hint != null and (mutation or control)) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
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
            // Coalesced local hints only. Reconciliation can also discover a
            // commit by another node; every waiter still revalidates its query.
            self.changed.publish(self.io, parsed.value.request.command);
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
        if (hint != null and !wire.WaitHint.allows(parsed.value.query)) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
        var response = self.engine.query(parsed.value) catch |err| return self.failure(request, err);
        if (hint) |wait| {
            if (wait.after > response.position) return self.json(request, .bad_request, wire.protocol.ErrorResponse{ .err = .InvalidRequest });
            if (wait.after == response.position) {
                self.release();
                // Compare and register under the same lock used by publication;
                // a commit between the read and registration cannot be missed.
                {
                    try self.mutex.lock(self.io);
                    defer self.mutex.unlock(self.io);
                    if (self.engine.head.position == wait.after) {
                        try self.changed.wait(self.io, self.mutex, parsed.value.query, wait.milliseconds);
                    }
                }
                try self.acquire();
                // Recheck signature, grants, scope, lifecycle and authority tail
                // after every wake/timeout, including remote commits and revoke.
                response = self.engine.query(parsed.value) catch |err| return self.failure(request, err);
            }
        }
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
    changed: Notifications = .{},
    pub fn isWait(_: *@This(), request: *std.http.Server.Request) bool {
        return (http.header(request, "x-transit-wait") catch null) != null;
    }
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
        server.changed = &self.changed;
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
