const std = @import("std");
const observations = @import("transit_observability");
const telemetry = observations.telemetry;
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const wire = @import("transit_client");
const Engine = core.Engine(adapter.Store);
const Maintenance = @import("Maintenance.zig");
const Config = struct {
    genesis: core.Genesis,
    ursula_url: []const u8,
    bucket: []const u8,
    journal: []const u8,
    listen: []const u8 = "127.0.0.1",
    port: u16 = 8080,
    request_timeout_ms: u32 = 2000,
    maintenance: ?Maintenance.Config = null,
    accept_trace_parent: bool = false,
};
fn processView(p: core.Process) wire.protocol.ProcessView {
    var view: wire.protocol.ProcessView = undefined;
    inline for (@typeInfo(wire.protocol.ProcessView).@"struct".field_names) |name| @field(view, name) = @field(p, name);
    return view;
}
const Server = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    engine: *Engine,
    observation: telemetry.Http = .{},
    accept_trace_parent: bool = false,

    fn json(self: *Server, req: *std.http.Server.Request, status: std.http.Status, value: anytype) !void {
        const body = try std.json.Stringify.valueAlloc(self.allocator, value, .{});
        defer self.allocator.free(body);
        self.observation.status = @backingInt(status);
        if (@hasField(@TypeOf(value), "err")) {
            self.observation.error_type = if (@typeInfo(@TypeOf(value.err)) == .@"enum") @tagName(value.err) else value.err;
            if (self.observation.protocol_outcome != .receipt and self.observation.protocol_outcome != .read)
                self.observation.protocol_outcome = if (status == .service_unavailable) .uncertain else .rejected;
        }
        try req.respond(body, .{ .status = status, .keep_alive = false, .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }} });
        self.observation.written = true;
    }

    fn handle(self: *Server, stream: std.Io.net.Stream) anyerror!void {
        var rbuf: [8192]u8 = undefined;
        var wbuf: [4096]u8 = undefined;
        var reader = stream.reader(self.io, &rbuf);
        var writer = stream.writer(self.io, &wbuf);
        var http = std.http.Server.init(&reader.interface, &writer.interface);
        var request = try http.receiveHead();
        const route: []const u8 = route: {
            inline for (.{ "/health", "/v2/command", "/v2/view", "/v2/inspect", "/v2/state", "/v2/delivery" }) |known| if (std.mem.eql(u8, request.head.target, known)) break :route known;
            break :route "unmatched";
        };
        self.observation.received(&request, route, self.accept_trace_parent);
        self.engine.store.journal.parent_context = self.observation.span.context;
        defer self.engine.store.journal.parent_context = null;
        if (request.head.method == .GET and std.mem.eql(u8, request.head.target, "/health")) {
            try self.engine.refresh();
            return self.json(&request, .ok, .{ .ready = true });
        }
        const is_delivery = std.mem.eql(u8, request.head.target, "/v2/delivery");
        const is_state = std.mem.eql(u8, request.head.target, "/v2/state");
        const is_inspection = std.mem.eql(u8, request.head.target, "/v2/inspect");
        const is_view = std.mem.eql(u8, request.head.target, "/v2/view");
        if (request.head.method != .POST or (!is_view and !is_inspection and !is_state and !is_delivery and !std.mem.eql(u8, request.head.target, "/v2/command")))
            return self.json(&request, .not_found, .{ .err = "NotFound" });
        const bytes = request.readerExpectNone(&.{}).allocRemaining(self.allocator, .limited(wire.max_body)) catch
            return self.json(&request, .bad_request, .{ .err = "InvalidBody" });
        defer self.allocator.free(bytes);
        if (is_delivery) {
            var query = std.json.parseFromSlice(wire.protocol.Delivery.SignedQuery, self.allocator, bytes, .{}) catch
                return self.json(&request, .bad_request, .{ .err = "InvalidRequest" });
            defer query.deinit();
            const status = core.delivery_read.read(self.engine, query.value) catch |err| {
                const code: std.http.Status = switch (err) {
                    error.Unauthorized, error.Forbidden => .forbidden,
                    error.Conflict => .conflict,
                    error.InvalidRead => .unprocessable_entity,
                    else => .service_unavailable,
                };
                return self.json(&request, code, .{ .err = if (code == .forbidden) wire.protocol.ErrorCode.AccessDenied else std.meta.stringToEnum(wire.protocol.ErrorCode, @errorName(err)) orelse .AuthorityUnavailable });
            };
            self.observation.protocol_outcome = .read;
            self.observation.realm = status.realm;
            self.observation.position = status.position;
            self.observation.operation = "delivery";
            return self.json(&request, .ok, status);
        }
        if (is_state) {
            var query = std.json.parseFromSlice(wire.protocol.State.SignedQuery, self.allocator, bytes, .{}) catch
                return self.json(&request, .bad_request, .{ .err = "InvalidRequest" });
            defer query.deinit();
            const page = core.resource_read.read(self.engine, query.value) catch |err| {
                const status: std.http.Status = switch (err) {
                    error.Unauthorized, error.Forbidden => .forbidden,
                    error.QueryExpired, error.HistoryReclaimed, error.Conflict => .conflict,
                    error.InvalidRead, error.InvalidStateKey, error.StateViewExpired, error.StateResourceExpired, error.UnknownProcess => .unprocessable_entity,
                    else => .service_unavailable,
                };
                return self.json(&request, status, .{ .err = if (status == .forbidden) wire.protocol.ErrorCode.AccessDenied else std.meta.stringToEnum(wire.protocol.ErrorCode, @errorName(err)) orelse .AuthorityUnavailable });
            };
            self.observation.protocol_outcome = .read;
            self.observation.realm = page.realm;
            self.observation.pid = query.value.query.pid;
            self.observation.position = page.cut.position;
            self.observation.operation = "state_read";
            return self.json(&request, .ok, page);
        }
        if (is_inspection) {
            var query = std.json.parseFromSlice(wire.protocol.Inspection.SignedQuery, self.allocator, bytes, .{}) catch
                return self.json(&request, .bad_request, .{ .err = "InvalidRequest" });
            defer query.deinit();
            const page = core.inspection.read(self.engine, query.value) catch |err| {
                const status: std.http.Status = switch (err) {
                    error.Unauthorized, error.Forbidden => .forbidden,
                    error.QueryExpired, error.HistoryReclaimed, error.Conflict => .conflict,
                    error.InvalidRead, error.UnknownProcess => .unprocessable_entity,
                    else => .service_unavailable,
                };
                return self.json(&request, status, .{ .err = if (status == .forbidden) wire.protocol.ErrorCode.AccessDenied else std.meta.stringToEnum(wire.protocol.ErrorCode, @errorName(err)) orelse .AuthorityUnavailable });
            };
            self.observation.protocol_outcome = .read;
            self.observation.realm = page.realm;
            self.observation.pid = page.pid;
            self.observation.position = page.cut.position;
            self.observation.operation = "inspect";
            return self.json(&request, .ok, page);
        }
        var parsed = std.json.parseFromSlice(core.SignedRequest, self.allocator, bytes, .{}) catch
            return self.json(&request, .bad_request, .{ .err = "InvalidRequest" });
        defer parsed.deinit();
        self.execute(&request, parsed.value, is_view) catch |err| {
            const status: std.http.Status = switch (err) {
                error.AdmissionClosed, error.ControlCapacity => .service_unavailable,
                error.ControlAlreadyRecorded => .unprocessable_entity,
                error.InvalidStateKey, error.InvalidStateMutation, error.InvalidStateView, error.StaleAssociation, error.StaleStateResource, error.StateAssociationCapacity, error.StateEntryCapacity, error.StateResourceCapacity, error.StateResourceExpired, error.StateResourceInUse, error.StateViewCapacity, error.StateViewExpired, error.StateViewInUse, error.UnknownStateResource => .unprocessable_entity,
                error.UnknownPayload, error.InvalidPayload, error.PayloadCapacity, error.PayloadPhase, error.PayloadInUse, error.UnsupportedPayloadLifetime => .unprocessable_entity,
                error.InvalidLifecycle, error.MissingRequiredAssociation, error.NotInitialized, error.SuspendedProcess, error.InvalidValue, error.StaleState, error.BlockedProcess, error.InvalidFailure => .unprocessable_entity,
                error.Unauthorized, error.Forbidden, error.WrongProtocolRealm, error.SignatureVerificationFailed, error.IdentityElement, error.NonCanonical, error.InvalidEncoding => .forbidden,
                error.Conflict => .conflict,
                error.RuntimeActivationRequired, error.StaleBinding, error.PendingProviderOperation, error.BindingReplacementUnsupported, error.InvalidBinding, error.ResourceAlreadyBound, error.ProviderOperationClosed, error.ProviderIncarnationMismatch, error.ProviderNotReady, error.AlreadyActivated, error.StaleWorkerIncarnation, error.FreshKeyRequired => .unprocessable_entity,
                error.NoPendingOutput, error.InvalidRead, error.ConflictingRetry, error.InvalidSequence, error.SequenceGap, error.RetryHorizonExceeded, error.InvalidGrant, error.UnknownPrincipal, error.UnknownProcess, error.UnknownEffect, error.UnknownOutput, error.InvalidLifetime, error.UnsupportedDeadline, error.UnsupportedWorkload, error.StaleGeneration, error.RetiredProcess, error.InvalidInput, error.MissingInput, error.InvalidTurnPermit, error.MissingTurnPermit, error.TurnAlreadyAuthorized, error.InvalidOutput, error.OutputAlreadyResolved, error.RouteBlocked, error.InvalidEffect, error.InvalidAttempt, error.AttemptAlreadyAuthorized, error.InvalidBudget, error.ReconciliationClosed, error.DeadlineExpired, error.NoDeadline, error.DeadlineNotReached, error.HistoryPinned, error.PendingWork, error.RetentionNotEnabled, error.ProcessCapacity, error.EffectCapacity, error.OutputCapacity, error.Overflow => .unprocessable_entity,
                else => .service_unavailable,
            };
            // Never disclose resource existence on authentication/permission failure.
            try self.json(&request, status, .{ .err = if (status == .forbidden) wire.protocol.ErrorCode.AccessDenied else std.meta.stringToEnum(wire.protocol.ErrorCode, @errorName(err)) orelse .AuthorityUnavailable });
        };
    }

    fn execute(self: *Server, request: *std.http.Server.Request, signed: core.SignedRequest, is_view: bool) !void {
        const e = self.engine;
        try e.refresh();
        e.state.authenticate(signed) catch return error.Unauthorized;
        try e.state.authorize(signed.request);
        self.observation.realm = signed.request.realm;
        self.observation.pid = observations.pid(signed.request.command);
        self.observation.sequence = signed.request.sequence;
        self.observation.operation = @tagName(signed.request.command);
        if (is_view) {
            if (signed.request.sequence != 0 or signed.request.command != .inspect) return error.InvalidRead;
            const pid = signed.request.command.inspect;
            const input = try e.nextInput(pid, e.state.position);
            var view: wire.View = .{
                .position = e.state.position,
                .principal_sequence = (try e.state.principal(signed.request.principal)).sequence,
                .process = processView((try e.state.process(pid)).*),
                .input = if (input) |r| try e.state.inputOf(r) else null,
            };
            var index: usize = 0;
            for (e.state.effects) |slot| if (slot) |effect| {
                if (effect.pid == pid) {
                    view.effects[index] = effect;
                    index += 1;
                }
            };
            index = 0;
            for (e.state.payloads) |slot| if (slot) |payload| {
                if (payload.pid == pid) {
                    view.payloads[index] = payload;
                    index += 1;
                }
            };
            // This HEAD is the read authorization point. A concurrent revocation
            // forces retry; this bounded batch can finish after a later revoke.
            if (try e.store.tail() != e.state.position) return error.Conflict;
            self.observation.protocol_outcome = .read;
            self.observation.position = view.position;
            return self.json(request, .ok, view);
        }
        self.observation.protocol_outcome = .uncertain;
        const receipt = try e.submit(signed);
        self.observation.protocol_outcome = .receipt;
        self.observation.position = receipt;
        return self.json(request, .ok, wire.Receipt{ .position = receipt });
    }
};
fn timeout(io: std.Io, milliseconds: u32) anyerror!void {
    try io.sleep(.fromMilliseconds(milliseconds), .awake);
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const config = try telemetry.Config.environment(init.environ_map);
    var diagnostics = if (args.len == 3 and std.mem.eql(u8, args[2], "--maintain")) telemetry.Runtime.init(init.io, "transit-maintenance", config) else telemetry.Runtime.init(init.io, "transit-node", config);
    diagnostics.start();
    defer diagnostics.stop();
    defer diagnostics.event(.{ .name = "service.stopped" });
    diagnostics.event(.{ .name = "service.starting" });
    run(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const initialize = args.len == 3 and std.mem.eql(u8, args[2], "--initialize");
    const maintain = args.len == 3 and std.mem.eql(u8, args[2], "--maintain");
    const bootstrap = args.len == 3 and std.mem.eql(u8, args[2], "--bootstrap");
    if (args.len < 2 or args.len > 3 or (args.len == 3 and !initialize and !maintain and !bootstrap)) return error.ExpectedConfigAndMode;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(wire.max_body));
    defer init.gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidTimeout;
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = config.ursula_url, .max_response_bytes = 2 * 1024 * 1024 });
    defer client.deinit();
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = config.bucket, .name = config.journal }, .observer = diagnostics } };
    if (initialize or bootstrap) try store.journal.create();
    var recovery = observations.begin(diagnostics, .recovery, if (initialize or bootstrap) "bootstrap" else "open", null);
    store.journal.parent_context = recovery.span.context;
    var engine = (if (initialize or bootstrap) Engine.bootstrap(&store, config.genesis) else Engine.open(&store, config.genesis)) catch |err| {
        recovery.fail(err);
        recovery.finish();
        return err;
    };
    recovery.event.position = engine.state.position;
    recovery.event.realm = engine.state.realm;
    recovery.finish();
    store.journal.parent_context = null;
    if (initialize) return;
    var clock_context: u8 = 0;
    if (config.genesis.max_clock_error_ms != null) engine.clock = .{ .context = &clock_context, .read = @import("Clock.zig").read };
    if (maintain) return Maintenance.run(init, &engine, config.maintenance orelse return error.MissingMaintenanceConfig, diagnostics);
    const address = try std.Io.net.IpAddress.parseIp4(config.listen, config.port);
    var listener = try address.listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    var server: Server = .{ .io = init.io, .allocator = init.gpa, .engine = &engine, .accept_trace_parent = config.accept_trace_parent };
    diagnostics.event(.{ .name = "service.ready" });
    while (true) {
        const stream = try listener.accept(init.io);
        defer stream.close(init.io);
        server.observation = .{ .span = diagnostics.begin(.server, null) };
        var request_error: ?anyerror = null;
        var timed_out = false;
        defer server.observation.finish("transit.http.request", request_error, timed_out, !std.mem.eql(u8, server.observation.route, "/v2/command"));
        const Result = union(enum) { handled: anyerror!void, timeout: anyerror!void };
        var results: [2]Result = undefined;
        var select: std.Io.Select(Result) = .init(init.io, &results);
        defer select.cancelDiscard();
        try select.concurrent(.timeout, timeout, .{ init.io, config.request_timeout_ms });
        // async may run inline when its worker budget is exhausted, preventing
        // await from observing the deadline while a request blocks on I/O.
        try select.concurrent(.handled, Server.handle, .{ &server, stream });
        const result = try select.await();
        switch (result) {
            .handled => |value| value catch |err| {
                request_error = err;
            },
            .timeout => {
                timed_out = true;
            },
        }
    }
}
