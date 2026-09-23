const std = @import("std");
const transit = @import("transit");
const adapter = @import("transit_ursula");
const wire = @import("transit_client");
const Engine = transit.Engine(adapter.Store, @import("counter").reduce);
const Maintenance = @import("Maintenance.zig");
const Config = struct {
    genesis: transit.Genesis,
    ursula_url: []const u8,
    bucket: []const u8,
    journal: []const u8,
    listen: []const u8 = "127.0.0.1",
    port: u16 = 8080,
    request_timeout_ms: u32 = 2000,
    maintenance: ?Maintenance.Config = null,
};
fn processView(p: transit.Process) wire.protocol.ProcessView {
    var view: wire.protocol.ProcessView = undefined;
    inline for (@typeInfo(wire.protocol.ProcessView).@"struct".field_names) |name| @field(view, name) = @field(p, name);
    return view;
}
const Server = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    engine: *Engine,

    fn json(self: *Server, req: *std.http.Server.Request, status: std.http.Status, value: anytype) !void {
        const body = try std.json.Stringify.valueAlloc(self.allocator, value, .{});
        defer self.allocator.free(body);
        try req.respond(body, .{ .status = status, .keep_alive = false, .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }} });
    }

    fn handle(self: *Server, stream: std.Io.net.Stream) anyerror!void {
        var rbuf: [8192]u8 = undefined;
        var wbuf: [4096]u8 = undefined;
        var reader = stream.reader(self.io, &rbuf);
        var writer = stream.writer(self.io, &wbuf);
        var http = std.http.Server.init(&reader.interface, &writer.interface);
        var request = try http.receiveHead();
        if (request.head.method == .GET and std.mem.eql(u8, request.head.target, "/health")) {
            try self.engine.refresh();
            return self.json(&request, .ok, .{ .ready = true });
        }
        const is_view = std.mem.eql(u8, request.head.target, "/v1/view");
        if (request.head.method != .POST or (!is_view and !std.mem.eql(u8, request.head.target, "/v1/command")))
            return self.json(&request, .not_found, .{ .err = "NotFound" });
        const bytes = request.readerExpectNone(&.{}).allocRemaining(self.allocator, .limited(wire.max_body)) catch
            return self.json(&request, .bad_request, .{ .err = "InvalidBody" });
        defer self.allocator.free(bytes);
        var parsed = std.json.parseFromSlice(transit.SignedRequest, self.allocator, bytes, .{}) catch
            return self.json(&request, .bad_request, .{ .err = "InvalidRequest" });
        defer parsed.deinit();
        self.execute(&request, parsed.value, is_view) catch |err| {
            const status: std.http.Status = switch (err) {
                error.AdmissionClosed, error.ControlCapacity => .service_unavailable,
                error.ControlAlreadyRecorded => .unprocessable_entity,
                error.UnknownPayload, error.InvalidPayload, error.PayloadCapacity, error.PayloadPhase, error.PayloadInUse, error.UnsupportedPayloadLifetime => .unprocessable_entity,
                error.BlockedProcess, error.InvalidFailure => .unprocessable_entity,
                error.Unauthorized, error.Forbidden, error.WrongProtocolRealm, error.SignatureVerificationFailed, error.IdentityElement, error.NonCanonical, error.InvalidEncoding => .forbidden,
                error.Conflict => .conflict,
                error.RuntimeActivationRequired, error.StaleBinding, error.PendingProviderOperation, error.BindingReplacementUnsupported, error.InvalidBinding, error.ResourceAlreadyBound, error.ProviderOperationClosed, error.ProviderIncarnationMismatch, error.ProviderNotReady, error.AlreadyActivated, error.StaleWorkerIncarnation, error.FreshKeyRequired => .unprocessable_entity,
                error.InvalidRead, error.ConflictingRetry, error.InvalidSequence, error.SequenceGap, error.RetryHorizonExceeded, error.InvalidGrant, error.UnknownPrincipal, error.UnknownProcess, error.UnknownEffect, error.UnknownOutput, error.InvalidLifetime, error.UnsupportedDeadline, error.UnsupportedWorkload, error.StaleGeneration, error.RetiredProcess, error.InvalidInput, error.MissingInput, error.InvalidResult, error.InvalidTurnPermit, error.MissingTurnPermit, error.TurnAlreadyAuthorized, error.InvalidOutput, error.InvalidOutputs, error.OutputAlreadyResolved, error.RouteBlocked, error.InvalidEffectIntent, error.InvalidEffect, error.InvalidAttempt, error.AttemptAlreadyAuthorized, error.InvalidBudget, error.ReconciliationClosed, error.DeadlineExpired, error.NoDeadline, error.DeadlineNotReached, error.HistoryPinned, error.PendingWork, error.RetentionNotEnabled, error.ProcessCapacity, error.EffectCapacity, error.OutputCapacity, error.Overflow => .unprocessable_entity,
                else => .service_unavailable,
            };
            // Never disclose resource existence on authentication/permission failure.
            try self.json(&request, status, .{ .err = if (status == .forbidden) "AccessDenied" else @errorName(err) });
        };
    }

    fn execute(self: *Server, request: *std.http.Server.Request, signed: transit.SignedRequest, is_view: bool) !void {
        const e = self.engine;
        try e.refresh();
        e.state.authenticate(signed) catch return error.Unauthorized;
        try e.state.authorize(signed.request);
        if (is_view) {
            if (signed.request.sequence != 0 or signed.request.command != .inspect) return error.InvalidRead;
            const pid = signed.request.command.inspect;
            const input = try e.nextInput(pid, e.state.position);
            var view: wire.View = .{
                .position = e.state.position,
                .principal_sequence = (try e.state.principal(signed.request.principal)).sequence,
                .process = processView((try e.state.process(pid)).*),
                .input = if (input) |r| .{ .position = r.position, .value = transit.messageOf(r).?.value } else null,
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
            return self.json(request, .ok, view);
        }
        const receipt = try e.submit(signed);
        return self.json(request, .ok, wire.Receipt{ .position = receipt });
    }
};
fn timeout(io: std.Io, milliseconds: u32) anyerror!void {
    try io.sleep(.fromMilliseconds(milliseconds), .awake);
}
pub fn main(init: std.process.Init) !void {
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
    var store: adapter.Store = .{ .journal = .{ .client = &client, .stream = .{ .bucket = config.bucket, .name = config.journal } } };
    if (initialize or bootstrap) try store.journal.create();
    var engine = if (initialize or bootstrap) try Engine.bootstrap(&store, config.genesis) else try Engine.open(&store, config.genesis);
    if (initialize) return;
    var clock_context: u8 = 0;
    if (config.genesis.max_clock_error_ms != null) engine.clock = .{ .context = &clock_context, .read = @import("Clock.zig").read };
    if (maintain) return Maintenance.run(init, &engine, config.maintenance orelse return error.MissingMaintenanceConfig);
    const address = try std.Io.net.IpAddress.parseIp4(config.listen, config.port);
    var listener = try address.listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    var server: Server = .{ .io = init.io, .allocator = init.gpa, .engine = &engine };
    while (true) {
        const stream = try listener.accept(init.io);
        defer stream.close(init.io);
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
            .handled => |value| value catch {},
            .timeout => {},
        }
    }
}
