const std = @import("std");
const g = @import("transit_sql_service");
const pg = @import("transit_postgres");
const mysql = @import("transit_mysql");
const tls = @import("transit_tls_server");
const Host = g.Session;
const Native = @import("Native.zig");
const Connection = @import("Connection.zig");
const FrameInput = @import("FrameInput.zig");
const http = @import("transit_http_server");
const Memory = g.query.QueryMemory;
const memory = @import("transit_memory");
const bounded_io = @import("transit_io");
const telemetry = g.query.wire.observability.telemetry;
test {
    std.testing.refAllDecls(@This());
    _ = @import("mysql_session_test.zig");
    _ = @import("postgres_session_test.zig");
    _ = g.Session;
    _ = Native;
    _ = @import("frame_input_test.zig");
}
const Worker = struct {
    reserve: memory.Slab,
    done: std.atomic.Value(bool) = .init(true),
    active: std.atomic.Value(bool) = .init(false),
    cancelled: std.atomic.Value(bool) = .init(false),
    authenticated: std.atomic.Value(bool) = .init(false),
    future: ?std.Io.Future(void) = null,
    id: u32 = 0,
    secret: u32 = 0,

    fn create(allocator: std.mem.Allocator, count: usize, capacity: usize) ![]Worker {
        const workers = try allocator.alloc(Worker, count);
        errdefer allocator.free(workers);
        var initialized: usize = 0;
        errdefer for (workers[0..initialized]) |*worker| worker.reserve.deinit();
        for (workers) |*worker| {
            worker.* = .{ .reserve = try .init(allocator, capacity) };
            initialized += 1;
        }
        return workers;
    }
    // The supervisor joins every future before releasing its stable slot.
    fn destroy(allocator: std.mem.Allocator, workers: []Worker) void {
        for (workers) |*worker| worker.reserve.deinit();
        allocator.free(workers);
    }
    fn reservedBytes(workers: []const Worker) usize {
        var bytes = workers.len * @sizeOf(Worker);
        for (workers) |worker| bytes += worker.reserve.buffer.len;
        return bytes;
    }
};
const Protocol = enum { postgres, mysql };
const Server = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    config: *const g.Configuration,
    tls_context: ?*tls.Context,
    runtimes: []*g.DatabaseRuntime,
    registry: *g.Registry,
    diagnostics: *telemetry.Runtime,
    workers: []Worker,
    mutex: std.Io.Mutex = .init,
    accounts: [g.Limits.max_accounts]u16 = @splat(0),
    next_id: u32 = 1,
    draining: std.atomic.Value(bool) = .init(false),
    pub fn handle(self: *Server, _: std.Io, _: std.mem.Allocator, request: *std.http.Server.Request) !void {
        if (request.head.method != .GET) return http.respond(request, .method_not_allowed, "{}");
        if (std.mem.eql(u8, request.head.target, "/live")) return http.respond(request, .ok, "{\"live\":true}");
        const recovery = std.mem.eql(u8, request.head.target, "/recovery");
        if (!recovery and !std.mem.eql(u8, request.head.target, "/health")) return http.respond(request, .not_found, "{}");
        var ready = !self.draining.load(.acquire);
        for (self.runtimes) |runtime| ready = ready and runtime.ready.load(.acquire);
        if (!recovery) ready = ready and self.config.listening();
        return http.respond(request, if (ready) .ok else .service_unavailable, if (ready) "{\"ready\":true}" else "{\"ready\":false}");
    }
    pub fn connectionError(_: *Server, _: anyerror, _: bool) void {}
    fn serveHealth(self: *Server, listener: *std.Io.net.Server) anyerror!void {
        return http.serve(self.io, self.allocator, listener, .{ .connections = 4, .requests = 2, .control_requests = 2, .header_timeout_ms = 1000, .request_timeout_ms = 2000 }, self);
    }
    fn cancel(self: *Server, payload: []const u8) !void {
        if (payload.len != 8) return error.InvalidCancelRequest;
        const id = std.mem.readInt(u32, payload[0..4], .big);
        const secret = payload[4..8];
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        for (self.workers) |*worker| {
            var expected: [4]u8 = undefined;
            std.mem.writeInt(u32, &expected, worker.secret, .big);
            if (!worker.done.load(.acquire) and worker.id == id and std.crypto.timing_safe.eql([4]u8, expected, secret[0..4].*) and worker.active.load(.acquire)) worker.cancelled.store(true, .release);
        }
    }
    fn acquire(self: *Server, account: usize) !void {
        if (self.draining.load(.acquire)) return error.GatewayDraining;
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        if (self.accounts[account] == self.config.limits.connections_per_account) return error.GatewayConnectionCapacity;
        self.accounts[account] += 1;
    }
    fn release(self: *Server, account: usize) void {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        self.accounts[account] -= 1;
    }
    fn authenticated(self: *Server) void {
        self.registry.releaseAuthentication();
    }
    fn connection(self: *Server, slot: *Worker, stream: std.Io.net.Stream, cancellation_only: bool, protocol: Protocol) void {
        defer slot.done.store(true, .release);
        defer slot.active.store(false, .release);
        defer stream.close(self.io);
        // connectionDeadline joins both the protocol and its deadline before
        // this slot is erased and published as reusable by done.store.
        defer slot.reserve.reset(true) catch unreachable;
        var budget: Memory = .{ .parent = slot.reserve.allocator(), .limit = self.config.limits.session_bytes };
        self.connectionDeadline(slot, stream, budget.allocator(), cancellation_only, protocol) catch |err| {
            self.diagnostics.event(.{ .name = "sql.connection.closed", .level = .debug, .outcome = .failed, .error_type = @errorName(err) });
        };
    }
    fn protocolTask(self: *Server, slot: *Worker, stream: std.Io.net.Stream, allocator: std.mem.Allocator, cancellation_only: bool, protocol: Protocol) anyerror!void {
        return switch (protocol) {
            .postgres => self.postgres(slot, stream, allocator, cancellation_only),
            .mysql => self.mysqlConnection(slot, stream, allocator, cancellation_only),
        };
    }
    fn authenticationDeadline(self: *Server, slot: *Worker) anyerror!void {
        const started = std.Io.Clock.awake.now(self.io);
        while (!slot.authenticated.load(.acquire)) {
            if (started.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds() >= self.config.limits.handshake_ms) return error.GatewayDeadline;
            try self.io.sleep(.fromMilliseconds(5), .awake);
        }
    }
    fn connectionDeadline(self: *Server, slot: *Worker, stream: std.Io.net.Stream, allocator: std.mem.Allocator, cancellation_only: bool, protocol: Protocol) !void {
        const Result = union(enum) { connection: anyerror!void, authentication: anyerror!void };
        var results: [2]Result = undefined;
        var select: std.Io.Select(Result) = .init(self.io, &results);
        defer select.cancelDiscard();
        // If scheduling fails before protocolTask starts, its auth reservation
        // has no owner/defer yet. The connection wrapper releases it exactly once.
        var started = false;
        errdefer if (!started and !cancellation_only) self.authenticated();
        try select.concurrent(.authentication, Server.authenticationDeadline, .{ self, slot });
        try select.concurrent(.connection, Server.protocolTask, .{ self, slot, stream, allocator, cancellation_only, protocol });
        started = true;
        switch (try select.await()) {
            .connection => |result| return result,
            .authentication => |result| try result,
        }
        switch (try select.await()) {
            .connection => |result| return result,
            .authentication => unreachable,
        }
    }
    fn postgres(self: *Server, slot: *Worker, stream: std.Io.net.Stream, allocator: std.mem.Allocator, cancellation_only: bool) !void {
        var authentication_pending = !cancellation_only;
        defer if (authentication_pending) self.authenticated();
        var transport: tls.Transport = .{ .io = self.io, .stream = stream, .deadline = .none };
        try transport.resetDeadline(self.config.limits.handshake_ms);
        var channel: Connection = .{ .transport = &transport };
        defer channel.deinit();
        var tx: Output = .{ .session = &channel, .write_ms = self.config.limits.write_ms };
        var startup = try pg.StartupSession.init(allocator, .{
            .tls = @fromBackingInt(@intCast(@backingInt(self.config.tls_mode))),
            .generation = slot.id,
            .id = slot.id,
            .secret = slot.secret,
            .cancellation_only = cancellation_only,
        });
        defer startup.deinit();
        var authentication: Authentication = .{ .server = self, .worker = slot, .allocator = allocator, .channel = &channel, .output = &tx };
        defer authentication.deinit();
        const admission = try authentication.drive(&startup) orelse return;
        const host = authentication.admit(startup.database.slice(), .transit) catch |err| return authentication.deny(&startup, admission, err);
        // Admit command state before acknowledging the pure startup's final
        // admission request. No successful login can precede these reserves.
        const session = pg.Session.init(allocator, self.config.limits, slot.id) catch |err| return authentication.deny(&startup, admission, err);
        var engine = @import("WireSessionDriver.zig").Driver(pg.Session, Host, Output).init(host, &tx, session);
        defer engine.deinit();
        var input = FrameInput.Reader(pg.Frame.Input).init(allocator, .{ .maximum = self.config.limits.frame_bytes }) catch |err| return authentication.deny(&startup, admission, err);
        defer input.deinit();
        try startup.complete(admission.token, .ok);
        _ = try authentication.drive(&startup);
        self.authenticated();
        authentication_pending = false;
        slot.authenticated.store(true, .release);
        const backend = &startup.backend;
        while (true) {
            const idle = engine.session.cycle.state == .idle;
            if (idle) try transport.idle(self.config.limits.idle_ms, host.commandMilliseconds()) else {
                const elapsed = host.deadline.start.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds();
                if (elapsed >= host.deadline.milliseconds) return error.GatewayDeadline;
                try transport.resetDeadline(@intCast(host.deadline.milliseconds - elapsed));
            }
            const bytes = input.read(&channel) catch |err| {
                if (err == error.Timeout and idle and transport.input_timeout_ms != null) {
                    try transport.resetDeadline(self.config.limits.write_ms);
                    try tx.writeAll(try backend.failure(true, "57P05".*, "Terminating connection due to idle-session timeout", null));
                }
                return err;
            };
            defer input.release();
            const frame = (try pg.Frame.decode(bytes, self.config.limits.frame_bytes)).?;
            if (idle and self.draining.load(.acquire)) return error.GatewayDraining;
            if (idle) try transport.resetDeadline(host.commandMilliseconds());
            if (!try boundedHandle(self.io, transport.deadline, @TypeOf(engine).run, .{ &engine, .{ frame.tag, frame.payload } })) break;
        }
        try transport.resetDeadline(self.config.limits.write_ms);
        try channel.finish();
    }
    fn mysqlConnection(self: *Server, slot: *Worker, stream: std.Io.net.Stream, allocator: std.mem.Allocator, cancellation_only: bool) !void {
        if (cancellation_only) return error.GatewayConnectionCapacity;
        var authentication_pending = true;
        defer if (authentication_pending) self.authenticated();
        var transport: tls.Transport = .{ .io = self.io, .stream = stream, .deadline = .none };
        try transport.resetDeadline(self.config.limits.handshake_ms);
        var nonce: [20]u8 = undefined;
        try self.io.randomSecure(&nonce);
        for (&nonce) |*byte| while (byte.* == 0) try self.io.randomSecure(std.mem.asBytes(byte));
        var channel: Connection = .{ .transport = &transport };
        defer channel.deinit();
        var tx: Output = .{ .session = &channel, .write_ms = self.config.limits.write_ms };
        var startup = try mysql.StartupSession.init(allocator, .{
            .tls = @fromBackingInt(@intCast(@backingInt(self.config.tls_mode))),
            .generation = slot.id,
            .id = slot.id,
            .nonce = nonce,
        });
        defer startup.deinit();
        var authentication: Authentication = .{ .server = self, .worker = slot, .allocator = allocator, .channel = &channel, .output = &tx };
        defer authentication.deinit();
        const admission = try authentication.drive(&startup) orelse return error.InvalidAuthentication;
        const host = authentication.admit(startup.database.slice(), .mysql) catch |err| return authentication.deny(&startup, admission, err);
        const prefix = startup.prefix.?;
        var limits = self.config.limits;
        if (prefix.maximum_packet != 0) limits.frame_bytes = @min(limits.frame_bytes, prefix.maximum_packet);
        limits.validate() catch |err| return authentication.deny(&startup, admission, err);
        const session = mysql.Session.init(allocator, limits, prefix.negotiated(), slot.id) catch |err| return authentication.deny(&startup, admission, err);
        var engine = @import("WireSessionDriver.zig").Driver(mysql.Session, Host, Output).init(host, &tx, session);
        defer engine.deinit();
        var input = FrameInput.Reader(mysql.Frame.Input).init(allocator, .{ .expected = 0, .maximum = limits.frame_bytes }) catch |err| return authentication.deny(&startup, admission, err);
        defer input.deinit();
        try startup.complete(admission.token, .ok);
        _ = try authentication.drive(&startup);
        self.authenticated();
        authentication_pending = false;
        slot.authenticated.store(true, .release);
        const backend = &startup.backend;
        while (true) {
            try transport.idle(limits.idle_ms, host.commandMilliseconds());
            const bytes = input.read(&channel) catch |err| {
                if (err == error.Timeout and transport.input_timeout_ms != null) {
                    try transport.resetDeadline(limits.write_ms);
                    backend.sequence = 0;
                    try tx.writeAll(try backend.failure(4031, "HY000".*, "Terminating connection due to idle-session timeout"));
                }
                return err;
            };
            defer input.release();
            const frame = (try mysql.Frame.decode(bytes, 0, limits.frame_bytes)).?;
            if (self.draining.load(.acquire)) return error.GatewayDraining;
            try transport.resetDeadline(host.commandMilliseconds());
            if (!try boundedHandle(self.io, transport.deadline, @TypeOf(engine).run, .{ &engine, .{frame.payload} })) break;
        }
        try transport.resetDeadline(limits.write_ms);
        try channel.finish();
    }
    fn serve(self: *Server, listener: *std.Io.net.Server, protocol: Protocol) !void {
        while (true) {
            const stream = try listener.accept(self.io);
            if (@import("builtin").os.tag != .windows) {
                const option: u32 = 1;
                const option_bytes = std.mem.asBytes(&option);
                _ = std.posix.system.setsockopt(stream.socket.handle, std.posix.IPPROTO.TCP, std.posix.TCP.NODELAY, option_bytes.ptr, @intCast(option_bytes.len));
            }
            try self.mutex.lock(self.io);
            const first: usize = if (self.registry.authenticating.load(.acquire) >= self.config.limits.authentications) self.config.limits.connections else 0;
            const index = for (self.workers[first..], first..) |*worker, i| {
                if (worker.done.load(.acquire)) break i;
            } else {
                self.mutex.unlock(self.io);
                stream.close(self.io);
                continue;
            };
            const slot = &self.workers[index];
            if (slot.future) |*future| future.await(self.io);
            if (self.next_id == std.math.maxInt(u32)) {
                self.mutex.unlock(self.io);
                stream.close(self.io);
                return error.WireSessionExhausted;
            }
            slot.id = self.next_id;
            self.next_id += 1;
            self.io.randomSecure(std.mem.asBytes(&slot.secret)) catch |err| {
                self.mutex.unlock(self.io);
                stream.close(self.io);
                return err;
            };
            slot.done.store(false, .release);
            slot.cancelled.store(false, .release);
            slot.authenticated.store(false, .release);
            if (index < self.config.limits.connections and !self.registry.acquireAuthentication()) {
                slot.done.store(true, .release);
                self.mutex.unlock(self.io);
                stream.close(self.io);
                continue;
            }
            slot.future = self.io.concurrent(Server.connection, .{ self, slot, stream, index >= self.config.limits.connections, protocol }) catch |err| {
                slot.done.store(true, .release);
                slot.future = null;
                if (index < self.config.limits.connections) self.registry.releaseAuthentication();
                self.mutex.unlock(self.io);
                stream.close(self.io);
                self.diagnostics.event(.{ .name = "sql.connection.refused", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
                continue;
            };
            self.mutex.unlock(self.io);
        }
    }
};
// Effect adapter for pure connection admission. The connection task owns and
// joins these effects before any startup buffer, credential or slot is freed.
const Authentication = struct {
    const w = pg.wire.Startup;
    server: *Server,
    worker: *Worker,
    allocator: std.mem.Allocator,
    channel: *Connection,
    output: *Output,
    index: ?usize = null,
    credential: ?g.Configuration.Credential = null,
    scram: ?g.Authentication.Scram = null,
    registered: ?*g.Registry.Slot = null,
    fn deinit(self: *Authentication) void {
        if (self.registered) |registered| {
            self.server.registry.remove(registered);
            registered.mutex.unlock(self.server.io);
            self.server.release(self.index.?);
        }
        if (self.scram) |*scram| scram.deinit();
        if (self.credential) |*credential| std.crypto.secureZero(u8, std.mem.asBytes(credential));
    }
    fn perform(self: *Authentication, request: w.Request) !w.Result {
        switch (request) {
            .input => |bytes| {
                try self.channel.readExact(bytes);
                return .{ .received = bytes.len };
            },
            .output => |bytes| {
                try self.output.writeAll(bytes);
                return .{ .written = bytes.len };
            },
            .upgrade => try self.channel.upgrade(self.server.tls_context orelse return error.TlsRequired),
            .lookup => |selection| {
                const index = self.server.config.account(selection.account) catch return error.InvalidAuthentication;
                const account = &self.server.config.accounts[index];
                if (account.authentication == .peer) return error.InvalidAuthentication;
                _ = try account.database(selection.database);
                self.credential = try Host.loadCredential(self.allocator, self.server.io, account);
                self.index = index;
                return .{ .method = if (account.authentication == .password) .password else .trust };
            },
            .scram_start => |initial| {
                var random: [18]u8 = undefined;
                try self.server.io.randomSecure(&random);
                self.scram = try g.Authentication.Scram.init(self.credential.?.verifier.?, initial, random);
                return .{ .challenge = self.scram.?.challenge() };
            },
            .scram_finish => |final| return .{ .proof = self.scram.?.finish(final) catch return error.InvalidAuthentication },
            .password => |password| self.credential.?.verifier.?.verifyPassword(password) catch return error.InvalidAuthentication,
            .cancel => |payload| try self.server.cancel(&payload),
            .admit => unreachable,
        }
        return .ok;
    }
    // Stop at final admission so the owner can reserve protocol-specific command
    // state before acknowledging it. Cancellation requests finish without it.
    fn drive(self: *Authentication, startup: anytype) !?w.Event {
        while (try startup.poll()) |event| {
            if (event.request == .admit) return event;
            const result = self.perform(event.request) catch |err| w.Result{ .failed = err };
            try startup.complete(event.token, result);
        }
        return null;
    }
    fn admit(self: *Authentication, database: []const u8, dialect: g.fuze.Sql.Dialect) !*Host {
        const index = self.index.?;
        var current = try Host.loadCredential(self.allocator, self.server.io, &self.server.config.accounts[index]);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&current));
        if (!std.meta.eql(self.credential.?, current)) return error.GatewayCredentialChanged;
        try self.server.acquire(index);
        errdefer self.server.release(index);
        const registered = try self.server.registry.create(index, current, database, dialect, false);
        self.registered = registered;
        const host = registered.host.?;
        host.cancellation = &self.worker.cancelled;
        host.deadline.cancellation = &self.worker.cancelled;
        host.active = &self.worker.active;
        host.diagnostics = self.server.diagnostics;
        host.wire.observer = self.server.diagnostics;
        return host;
    }
    fn deny(self: *Authentication, startup: anytype, admission: w.Event, err: anyerror) anyerror {
        startup.complete(admission.token, .{ .failed = err }) catch |failure| return failure;
        _ = self.drive(startup) catch |failure| return failure;
        return err;
    }
};
// Cancellation joins the command before its frame/host/allocator can be freed.
// An accepted write's pending controls belong to DatabaseRuntime, not this task.
fn boundedHandle(io: std.Io, deadline: std.Io.Timeout, comptime function: anytype, args: std.meta.ArgsTuple(@TypeOf(function))) !bool {
    const Result = union(enum) { command: anyerror!bool, timeout: anyerror!void };
    const Task = struct {
        fn command(arguments: std.meta.ArgsTuple(@TypeOf(function))) anyerror!bool {
            return @call(.auto, function, arguments);
        }
        fn timeout(inner_io: std.Io, until: std.Io.Timeout) anyerror!void {
            try until.sleep(inner_io);
        }
    };
    var results: [2]Result = undefined;
    var select: std.Io.Select(Result) = .init(io, &results);
    defer select.cancelDiscard();
    try select.concurrent(.timeout, Task.timeout, .{ io, deadline });
    try select.concurrent(.command, Task.command, .{args});
    return switch (try select.await()) {
        .command => |result| result,
        .timeout => error.GatewayDeadline,
    };
}
const Output = struct {
    session: *Connection,
    write_ms: u32,
    pub fn writeAll(self: *Output, bytes: []const u8) !void {
        // Never extend the active handshake/command deadline for slow output.
        const transport = self.session.transport;
        const saved = transport.deadline;
        defer transport.deadline = saved;
        const remaining = if (saved.toDurationFromNow(transport.io)) |duration| duration.raw.toMilliseconds() else self.write_ms;
        if (remaining <= 0) return error.GatewayDeadline;
        try transport.resetDeadline(@intCast(@min(remaining, self.write_ms)));
        try self.session.writeAll(bytes);
    }
};
fn runAccount(runtime: *g.DatabaseRuntime, diagnostics: *telemetry.Runtime) void {
    var interval_ms: u32 = 2;
    var cleanup_failure: u16 = 0;
    var direct_failure: u16 = 0;
    while (true) {
        const progressed = runtime.tick() catch |err| blk: {
            if (err == error.Canceled or err == error.Cancelled) return;
            // Revocation withdraws readiness without discarding the worker.
            // Restoration can resume the same accepted operations. A stale
            // activation is a permanent fence and still stops this generation.
            if (!g.wire.Client.unavailable(err) and !runtime.background.contended(err) and err != error.AccessDenied) {
                runtime.ready.store(false, .release);
                diagnostics.event(.{ .name = "sql.account.stopped", .level = .err, .outcome = .failed, .error_type = if (runtime.background.last_rejection) |cause| @tagName(cause) else @errorName(err) });
                return;
            }
            break :blk false;
        };
        const current_cleanup = runtime.read_cleanup_failure.load(.acquire);
        if (current_cleanup != cleanup_failure) {
            cleanup_failure = current_cleanup;
            if (current_cleanup != 0) diagnostics.event(.{ .name = "sql.read.cleanup_blocked", .level = .warn, .outcome = .failed, .error_type = @errorName(@as(anyerror, @errorFromInt(current_cleanup))) });
        }
        const current_direct = runtime.direct_work_failure.load(.acquire);
        if (current_direct != direct_failure) {
            direct_failure = current_direct;
            if (current_direct != 0) diagnostics.event(.{ .name = "sql.operation.recovery_blocked", .level = .warn, .outcome = .failed, .error_type = @errorName(@as(anyerror, @errorFromInt(current_direct))) });
        }
        if (progressed) {
            interval_ms = 2;
            continue;
        }
        // Settled accounts park without a timer or native request. Only an
        // unresolved obligation uses bounded backoff; notifications wake now.
        runtime.waitIdle(interval_ms) catch return;
        interval_ms = @min(interval_ms * 2, 100);
    }
}
pub const Shutdown = @import("Shutdown.zig");
pub const Deployment = @import("Deployment.zig");
pub const Configuration = g.Configuration;
pub const LocalEndpoint = g.wire.LocalEndpoint;
pub const Crypto = tls.Memory;

pub fn cryptoCapacity(config: *const g.Configuration) usize {
    const connections = @as(usize, if (config.wireListening() and config.tls_mode != .disabled) config.limits.connections else 0) +
        @as(usize, if (config.native != null and config.native.?.port != null and config.native.?.tls != null) 16 else 0);
    return if (connections == 0) 0 else (16 + connections) * 1024 * 1024;
}

/// The embedding process owns OpenSSL's one process-wide reserve. Replacement
/// joins all workers before reusing this service's configuration or endpoint.
pub fn run(init: std.process.Init, diagnostics: *telemetry.Runtime, config: *const g.Configuration, endpoint: ?LocalEndpoint, shutdown: *Shutdown, crypto_capacity: usize) !void {
    try config.validate();
    if (cryptoCapacity(config) > crypto_capacity) return error.TlsMemoryCapacity;
    const native_listeners: usize = if (config.native != null)
        @as(usize, @intFromBool(config.native.?.port != null)) + @intFromBool(config.native.?.socket != null)
    else
        0;
    const wire_connections: usize = if (config.wireListening()) @as(usize, config.limits.connections) + 2 else 0;
    // Supervisors/recovery, account transport/deadline work, wire protocol
    // nesting, and HTTP header/dispatch/authority work have finite independent
    // concurrency envelopes. No worker or task backing is added by a request.
    const worker_count = 16 + 4 * config.accounts.len + 8 * wire_connections +
        native_listeners * (3 * 16 + 4 * (Native.RequestStorage.data_slots + Native.RequestStorage.control_slots)) +
        @as(usize, if (config.health_port != null) 16 else 0);
    const io_runtime = try bounded_io.Threaded.create(init.gpa, .{
        .workers = worker_count,
        .task_bytes = worker_count * 16 * 1024,
        .environ = init.minimal.environ,
        .argv0 = .init(init.minimal.args),
        .worker_cleanup = if (crypto_capacity != 0) tls.Memory.stopThread else null,
    });
    // Every service future is joined by serve before destroying workers. The
    // cleanup barrier ends OpenSSL thread state before its reserve is freed.
    defer io_runtime.destroy();
    var host_init = init;
    host_init.io = io_runtime.io();
    return serve(host_init, diagnostics, config, endpoint, shutdown);
}
fn serve(init: std.process.Init, diagnostics: *telemetry.Runtime, config: *const g.Configuration, endpoint: ?LocalEndpoint, shutdown: *Shutdown) !void {
    // Bootstrap and retained-operation recovery have no dependency on listener
    // credentials. In particular, expired or removed PEM files cannot prevent
    // a disabled listener's workers from resuming accepted operations.
    var context: ?tls.Context = if (config.wireListening() and config.tls_mode != .disabled) blk: {
        const certificate = try init.gpa.dupeSentinel(u8, config.certificate_file, 0);
        defer init.gpa.free(certificate);
        const certificate_key = try init.gpa.dupeSentinel(u8, config.certificate_key_file, 0);
        defer init.gpa.free(certificate_key);
        break :blk try tls.Context.init(certificate, certificate_key);
    } else null;
    defer if (context) |*value| value.deinit();
    var runtimes: std.ArrayList(*g.DatabaseRuntime) = .empty;
    defer runtimes.deinit(init.gpa);
    defer for (runtimes.items) |runtime| runtime.deinit();
    for (config.accounts) |account| {
        var keys: g.DatabaseRuntime.Keys = undefined;
        defer std.crypto.secureZero(u8, std.mem.asBytes(&keys));
        inline for (@typeInfo(g.Configuration.KeyFiles).@"struct".field_names) |field| @field(keys, field) = try g.query.wire.readKey(init.gpa, init.io, @field(account.keys, field));
        const runtime = try g.DatabaseRuntime.initEndpoint(init.gpa, init.io, config.native_url, .{ .configuration = account.execution }, account.generation, keys, config.request_timeout_ms, endpoint);
        errdefer runtime.deinit();
        try runtimes.append(init.gpa, runtime);
    }
    var activation = try std.Io.Dir.cwd().openDir(init.io, config.activation_directory, .{ .iterate = true });
    defer activation.close(init.io);
    for (config.accounts) |account| {
        var name: [96]u8 = undefined;
        const marker = try std.fmt.bufPrint(&name, "{s}-{d}.activation", .{ std.fmt.bytesToHex(account.execution.account, .lower), account.generation });
        const file = activation.createFile(init.io, marker, .{ .exclusive = true, .permissions = .fromMode(0o600) }) catch |err| if (err == error.PathAlreadyExists) return error.FreshOwnershipRequired else return err;
        defer file.close(init.io);
        try file.sync(init.io);
        if (std.c.fsync(activation.handle) != 0) return error.GatewayActivationSyncFailed;
    }
    var tasks: [g.Limits.max_accounts]?std.Io.Future(void) = @splat(null);
    for (runtimes.items, config.accounts) |runtime, account| try g.ReadSources.attach(runtime, activation, account.sources);
    defer for (&tasks) |*task| if (task.*) |*future| future.cancel(init.io);
    for (runtimes.items, 0..) |runtime, i| tasks[i] = try init.io.concurrent(runAccount, .{ runtime, diagnostics });
    const started = std.Io.Clock.awake.now(init.io);
    while (true) {
        if (shutdown.stopping()) return;
        var ready = true;
        for (runtimes.items) |runtime| ready = ready and runtime.ready.load(.acquire);
        if (ready) break;
        if (started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() >= 30000) return error.GatewayOwnerUnavailable;
        try init.io.sleep(.fromMilliseconds(5), .awake);
    }
    var registry = try g.Registry.init(init.gpa, init.io, config, runtimes.items, if (config.native) |native| native.instance else config.accounts[0].execution.account[0..16].*);
    defer registry.deinit();
    registry.observer = if (diagnostics.config.level == .debug) diagnostics else null;
    var native_context: ?tls.Context = if (config.native) |native| if (native.tls) |selected| blk: {
        // OpenSSL loads these files during initialization. A replacement host
        // must not retain path copies in the embedding process's startup arena.
        const certificate = try init.gpa.dupeSentinel(u8, selected.certificate_file, 0);
        defer init.gpa.free(certificate);
        const certificate_key = try init.gpa.dupeSentinel(u8, selected.key_file, 0);
        defer init.gpa.free(certificate_key);
        break :blk try tls.Context.init(certificate, certificate_key);
    } else null else null;
    defer if (native_context) |*selected| selected.deinit();
    var native_listener: ?std.Io.net.Server = if (config.native) |native| if (native.port) |port| try (try std.Io.net.IpAddress.parseIp4(native.address, port)).listen(init.io, .{ .reuse_address = true }) else null else null;
    defer if (native_listener) |*listener| listener.deinit(init.io);
    const socket_lock = if (config.native) |native| if (native.socket) |socket| try @import("transit_sql_client").Discovery.lockSocket(init.gpa, init.io, socket) else null else null;
    defer if (socket_lock) |lock| lock.close(init.io);
    var local_listener: ?std.Io.net.Server = if (config.native) |native| if (native.socket) |socket| try (try std.Io.net.UnixAddress.init(socket)).listen(init.io, .{}) else null else null;
    defer if (local_listener) |*listener| {
        listener.deinit(init.io);
        std.Io.Dir.cwd().deleteFile(init.io, config.native.?.socket.?) catch {};
    };
    var native_api: Native = .{ .registry = &registry, .tls_context = if (native_context) |*selected| selected else null, .local = false, .loopback = if (config.native) |native| (try std.Io.net.IpAddress.parseIp4(native.address, 0)).ip4.bytes[0] == 127 else false };
    var local_api: Native = .{ .registry = &registry, .tls_context = null, .local = true, .loopback = false };
    var postgres_listener: ?std.Io.net.Server = if (config.postgres_port) |port| try (try std.Io.net.IpAddress.parseIp4(config.bind_address, port)).listen(init.io, .{ .reuse_address = true }) else null;
    defer if (postgres_listener) |*listener| listener.deinit(init.io);
    var mysql_listener: ?std.Io.net.Server = if (config.mysql_port) |port| try (try std.Io.net.IpAddress.parseIp4(config.bind_address, port)).listen(init.io, .{ .reuse_address = true }) else null;
    defer if (mysql_listener) |*listener| listener.deinit(init.io);
    const workers = try Worker.create(init.gpa, if (config.wireListening()) @as(usize, config.limits.connections) + 2 else 0, config.limits.session_bytes);
    defer Worker.destroy(init.gpa, workers);
    defer for (workers) |*worker| if (worker.future) |*future| future.cancel(init.io);
    var server: Server = .{ .allocator = init.gpa, .io = init.io, .config = config, .tls_context = if (context) |*value| value else null, .runtimes = runtimes.items, .diagnostics = diagnostics, .workers = workers, .registry = &registry };
    var health_listener: ?std.Io.net.Server = if (config.health_port) |port| try (try std.Io.net.IpAddress.parseIp4(config.health_address, port)).listen(init.io, .{ .reuse_address = true }) else null;
    defer if (health_listener) |*listener| listener.deinit(init.io);
    var health: ?std.Io.Future(anyerror!void) = if (health_listener) |*listener| try init.io.concurrent(Server.serveHealth, .{ &server, listener }) else null;
    defer if (health) |*future| {
        _ = future.cancel(init.io) catch {};
    };
    const Result = union(enum) { postgres: anyerror!void, mysql: anyerror!void, native: anyerror!void, local: anyerror!void, expiry: anyerror!void, recovery: anyerror!void, stop: anyerror!void };
    var results: [7]Result = undefined;
    var listeners: std.Io.Select(Result) = .init(init.io, &results);
    defer listeners.cancelDiscard();
    if (postgres_listener) |*listener| try listeners.concurrent(.postgres, Server.serve, .{ &server, listener, .postgres });
    if (mysql_listener) |*listener| try listeners.concurrent(.mysql, Server.serve, .{ &server, listener, .mysql });
    if (native_listener) |*listener| try listeners.concurrent(.native, Native.serve, .{ &native_api, init.io, init.gpa, listener });
    if (local_listener) |*listener| try listeners.concurrent(.local, Native.serve, .{ &local_api, init.io, init.gpa, listener });
    try listeners.concurrent(.expiry, expireSessions, .{ &registry, init.io });
    try listeners.concurrent(.recovery, recoverSessions, .{ &registry, init.io, diagnostics });
    try listeners.concurrent(.stop, Shutdown.wait, .{ shutdown, init.io });
    diagnostics.event(.{ .name = if (config.listening()) "service.ready" else "sql.recovery.ready", .operation = "sql" });
    switch (try listeners.await()) {
        .stop => |result| {
            try result;
            server.draining.store(true, .release);
            listeners.cancelDiscard();
            diagnostics.event(.{ .name = "sql.service.draining", .operation = "sql" });
            const draining = std.Io.Clock.awake.now(init.io);
            while (draining.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() < config.drain_ms) {
                var active = false;
                for (workers) |*worker| active = active or worker.active.load(.acquire);
                if (!active) break;
                try init.io.sleep(.fromMilliseconds(10), .awake);
            }
        },
        inline else => |result| try result,
    }
}

fn expireSessions(registry: *g.Registry, io: std.Io) !void {
    _ = io;
    while (true) {
        registry.sweep();
        try registry.waitExpiry();
    }
}

fn recoverSessions(registry: *g.Registry, io: std.Io, diagnostics: *telemetry.Runtime) !void {
    var previous: ?anyerror = null;
    var interval_ms: u32 = 2;
    while (true) {
        const more = registry.recover() catch |err| {
            if (err == error.Canceled or err == error.Cancelled) return err;
            if (previous == null or previous.? != err) diagnostics.event(.{ .name = "sql.operation.recovery", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
            previous = err;
            continue;
        };
        previous = null;
        if (more) continue;
        try registry.recovery.work.wait(io, interval_ms);
        interval_ms = @min(100, interval_ms * 2);
    }
}

fn workerReserveFailures(allocator: std.mem.Allocator) !void {
    const workers = try Worker.create(allocator, 3, 4096);
    defer Worker.destroy(allocator, workers);
}
test "wire worker admission rolls back partial reserves" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, workerReserveFailures, .{});
}
test "wire frame reserves reuse independently of cancellation capacity" {
    const t = std.testing;
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    const workers = try Worker.create(probe.allocator(), 3, 4096);
    defer Worker.destroy(probe.allocator(), workers);
    try t.expectEqual(Worker.reservedBytes(workers), probe.live_bytes);
    probe.begin(true);
    const retained = try workers[0].reserve.allocator().dupe(u8, "slow reader frame");
    defer workers[0].reserve.allocator().free(retained);
    for (0..100) |_| {
        const a = workers[1].reserve.allocator();
        const frame = try a.alloc(u8, 4096 - memory.Slab.granule);
        try t.expectError(error.OutOfMemory, a.alloc(u8, 1));
        const cancellation = try workers[2].reserve.allocator().dupe(u8, "cancel");
        workers[2].reserve.allocator().free(cancellation);
        try workers[2].reserve.reset(true);
        try t.expect(std.mem.allEqual(u8, workers[2].reserve.buffer[memory.Slab.granule..], 0));
        a.free(frame);
        try workers[1].reserve.reset(true);
        try t.expectEqualStrings("slow reader frame", retained);
    }
    try probe.verify();
}
