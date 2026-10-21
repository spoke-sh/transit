const std = @import("std");
const g = @import("transit_sql");
const pg = @import("transit_postgres");
const mysql = @import("transit_mysql");
const tls = @import("transit_tls_server");
const Host = g.Session;
const Native = @import("Native.zig");
const Control = @import("Control.zig");
const Stop = @import("Stop.zig");
const Connection = @import("Connection.zig");
const http = @import("transit_http_server");
const Memory = g.query.QueryMemory;
const telemetry = g.query.wire.observability.telemetry;
test {
    _ = g.Session;
}
const Worker = struct {
    done: std.atomic.Value(bool) = .init(true),
    active: std.atomic.Value(bool) = .init(false),
    cancelled: std.atomic.Value(bool) = .init(false),
    authenticated: std.atomic.Value(bool) = .init(false),
    future: ?std.Io.Future(void) = null,
    id: u32 = 0,
    secret: u32 = 0,
};
const Protocol = enum { postgres, mysql };
const Server = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    config: *const g.Configuration,
    tls_context: ?*tls.Context,
    runtimes: []*g.AccountRuntime,
    registry: *g.Registry,
    diagnostics: *telemetry.Runtime,
    workers: []Worker,
    mutex: std.Io.Mutex = .init,
    accounts: [g.Limits.max_accounts]u16 = @splat(0),
    authenticating: u16 = 0,
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
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        self.authenticating -= 1;
    }
    fn connection(self: *Server, slot: *Worker, stream: std.Io.net.Stream, cancellation_only: bool, protocol: Protocol) void {
        defer slot.done.store(true, .release);
        defer slot.active.store(false, .release);
        defer stream.close(self.io);
        var budget: Memory = .{ .parent = self.allocator, .limit = self.config.limits.session_bytes };
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
        var upgrade = try pg.Startup.read(allocator, &transport);
        defer upgrade.deinit();
        if (upgrade.code == pg.Frame.gss_request) {
            try transport.writeAll("N");
            const next = try pg.Startup.read(allocator, &transport);
            upgrade.deinit();
            upgrade = next;
        }
        var channel: Connection = .{ .transport = &transport };
        defer channel.deinit();
        if (upgrade.code == pg.Frame.ssl_request) {
            if (self.config.tls_mode == .disabled) {
                try transport.writeAll("N");
            } else {
                try transport.writeAll("S");
                try channel.upgrade(self.tls_context orelse return error.TlsRequired);
            }
            const next = try pg.Startup.read(allocator, &channel);
            upgrade.deinit();
            upgrade = next;
        }
        var tx: Output = .{ .session = &channel, .write_ms = self.config.limits.write_ms };
        if (self.config.tls_mode == .required and channel.secure == null) {
            var failure: pg.Backend = .{ .allocator = allocator, .maximum = self.config.limits.frame_bytes };
            defer failure.deinit();
            try tx.writeAll(try failure.failure(true, "28000".*, "TLS is required", null));
            return error.TlsRequired;
        }
        const startup_frame = upgrade;
        if (startup_frame.code == pg.Frame.cancel_request) return self.cancel(startup_frame.payload);
        if (cancellation_only) return error.GatewayConnectionCapacity;
        const startup = try pg.Startup.decode(startup_frame.code, startup_frame.payload);
        var backend: pg.Backend = .{ .allocator = allocator, .maximum = self.config.limits.frame_bytes };
        defer backend.deinit();
        var unsupported: [pg.Startup.max_parameters][]const u8 = undefined;
        var unsupported_count: usize = 0;
        for (startup.parameters[0..startup.count]) |parameter| {
            if (std.mem.startsWith(u8, parameter.name, "_pq_.")) {
                unsupported[unsupported_count] = parameter.name;
                unsupported_count += 1;
            } else if (std.mem.eql(u8, parameter.name, "user") or std.mem.eql(u8, parameter.name, "database") or std.mem.eql(u8, parameter.name, "application_name")) {} else if (std.mem.eql(u8, parameter.name, "client_encoding") and std.ascii.eqlIgnoreCase(parameter.value, "UTF8")) {} else return error.UnsupportedStartupSetting;
        }
        if (startup.minor != 0 or unsupported_count != 0) try tx.writeAll(try backend.negotiate(unsupported[0..unsupported_count]));
        const index = self.config.account(startup.get("user").?) catch {
            try tx.writeAll(try backend.failure(true, "28P01".*, "Authentication failed", null));
            return error.InvalidAuthentication;
        };
        const account = &self.config.accounts[index];
        if (account.authentication == .peer) return error.InvalidAuthentication;
        _ = try account.database(startup.database());
        var credential = Host.loadCredential(allocator, self.io, account) catch |err| {
            try tx.writeAll(try backend.failure(true, "28P01".*, "Authentication failed", null));
            return err;
        };
        defer std.crypto.secureZero(u8, std.mem.asBytes(&credential));
        var proof: [46]u8 = undefined;
        if (account.authentication == .password) {
            try tx.writeAll(try backend.authenticate(.mechanisms, ""));
            var initial = try pg.Frame.read(allocator, &channel, 1024);
            defer initial.deinit();
            defer std.crypto.secureZero(u8, initial.payload);
            if (initial.tag != 'p') return error.InvalidAuthentication;
            var random: [18]u8 = undefined;
            try self.io.randomSecure(&random);
            var scram = try g.Authentication.Scram.init(credential.verifier.?, try pg.Frontend.saslInitial(initial.payload), random);
            defer scram.deinit();
            try tx.writeAll(try backend.authenticate(.challenge, scram.challenge()));
            var final = try pg.Frame.read(allocator, &channel, 1024);
            defer final.deinit();
            defer std.crypto.secureZero(u8, final.payload);
            if (final.tag != 'p') return error.InvalidAuthentication;
            proof = scram.finish(final.payload) catch {
                try tx.writeAll(try backend.failure(true, "28P01".*, "Authentication failed", null));
                return error.InvalidAuthentication;
            };
        }
        if (!std.meta.eql(credential, try Host.loadCredential(allocator, self.io, account))) return error.GatewayCredentialChanged;
        try self.acquire(index);
        defer self.release(index);
        const registered = self.registry.create(index, credential, startup.database(), .transit, false) catch |err| {
            try tx.writeAll(try backend.failure(true, "28000".*, "Account or database access denied", null));
            return err;
        };
        defer {
            self.registry.remove(registered);
            registered.mutex.unlock(self.io);
        }
        const host = registered.host.?;
        host.cancellation = &slot.cancelled;
        host.deadline.cancellation = &slot.cancelled;
        host.active = &slot.active;
        host.diagnostics = self.diagnostics;
        host.wire.observer = self.diagnostics;
        if (account.authentication == .password) try tx.writeAll(try backend.authenticate(.final, &proof));
        try tx.writeAll(try backend.authenticate(.ok, ""));
        self.authenticated();
        authentication_pending = false;
        slot.authenticated.store(true, .release);
        for ([_][2][]const u8{ .{ "server_version", "18.0-Transit" }, .{ "server_encoding", "UTF8" }, .{ "client_encoding", "UTF8" }, .{ "standard_conforming_strings", "on" }, .{ "integer_datetimes", "on" }, .{ "application_name", startup.get("application_name") orelse "" } }) |parameter| try tx.writeAll(try backend.parameter(parameter[0], parameter[1]));
        try tx.writeAll(try backend.key(slot.id, slot.secret));
        try tx.writeAll(try backend.ready());
        var engine = try pg.Session.Engine(Host, Output).init(allocator, host, &tx, self.config.limits);
        defer engine.deinit();
        while (true) {
            const idle = engine.cycle.state == .idle;
            if (idle) try transport.resetDeadline(self.config.limits.idle_ms) else {
                const elapsed = host.deadline.start.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds();
                if (elapsed >= host.deadline.milliseconds) return error.GatewayDeadline;
                try transport.resetDeadline(@intCast(host.deadline.milliseconds - elapsed));
            }
            var frame = try pg.Frame.read(allocator, &channel, self.config.limits.frame_bytes);
            defer frame.deinit();
            if (idle and self.draining.load(.acquire)) return error.GatewayDraining;
            if (idle) try transport.resetDeadline(host.commandMilliseconds());
            if (!try boundedHandle(self.io, transport.deadline, @TypeOf(engine).handle, .{ &engine, frame.tag, frame.payload })) break;
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
        var backend: mysql.Backend = .{ .allocator = allocator, .maximum = self.config.limits.frame_bytes };
        defer backend.deinit();
        var nonce: [20]u8 = undefined;
        try self.io.randomSecure(&nonce);
        for (&nonce) |*byte| while (byte.* == 0) try self.io.randomSecure(std.mem.asBytes(byte));
        const capabilities = if (self.config.tls_mode == .disabled) mysql.Handshake.capabilities & ~mysql.Handshake.ssl else mysql.Handshake.capabilities;
        try transport.writeAll(try backend.greeting(slot.id, nonce, capabilities));
        var response = try mysql.Frame.read(allocator, &transport, 1, 8192);
        defer response.deinit();
        defer std.crypto.secureZero(u8, response.payload);
        var channel: Connection = .{ .transport = &transport };
        defer channel.deinit();
        var tx: Output = .{ .session = &channel, .write_ms = self.config.limits.write_ms };
        const prefix = if (response.payload.len == 32) blk: {
            const request = try mysql.Handshake.upgrade(response.payload);
            if (self.config.tls_mode == .disabled) return error.TlsRequired;
            try channel.upgrade(self.tls_context orelse return error.TlsRequired);
            const next = try mysql.Frame.read(allocator, &channel, 2, 8192);
            response.deinit();
            response = next;
            backend.sequence = 3;
            break :blk request;
        } else blk: {
            backend.sequence = 2;
            if (self.config.tls_mode == .required) {
                try tx.writeAll(try backend.failure(1045, "28000".*, "TLS is required"));
                return error.TlsRequired;
            }
            break :blk try mysql.Handshake.plaintext(response.payload);
        };
        const handshake = try mysql.Handshake.response(response.payload, prefix);
        const index = self.config.account(handshake.account) catch {
            try tx.writeAll(try backend.failure(1045, "28000".*, "Authentication failed"));
            return error.InvalidAuthentication;
        };
        const account = &self.config.accounts[index];
        if (account.authentication == .peer) return error.InvalidAuthentication;
        const database = handshake.database orelse return error.GatewayDatabaseDenied;
        _ = try account.database(database);
        var credential = Host.loadCredential(allocator, self.io, account) catch |err| {
            try tx.writeAll(try backend.failure(1045, "28000".*, "Authentication failed"));
            return err;
        };
        defer std.crypto.secureZero(u8, std.mem.asBytes(&credential));
        if (account.authentication == .password) {
            // Full caching_sha2_password is never requested over plaintext.
            if (channel.secure == null) {
                try tx.writeAll(try backend.failure(1045, "28000".*, "Password authentication requires TLS"));
                return error.TlsRequired;
            }
            try tx.writeAll(try backend.fullAuthentication());
            var password = try mysql.Frame.read(allocator, &channel, backend.sequence, g.Authentication.max_password_bytes + 1);
            defer password.deinit();
            defer std.crypto.secureZero(u8, password.payload);
            backend.sequence += 1;
            credential.verifier.?.verifyPassword(try mysql.Handshake.password(password.payload)) catch {
                try tx.writeAll(try backend.failure(1045, "28000".*, "Authentication failed"));
                return error.InvalidAuthentication;
            };
        }
        if (!std.meta.eql(credential, try Host.loadCredential(allocator, self.io, account))) return error.GatewayCredentialChanged;
        try self.acquire(index);
        defer self.release(index);
        const registered = self.registry.create(index, credential, database, .mysql, false) catch |err| {
            try tx.writeAll(try backend.failure(1045, "28000".*, "Account or database access denied"));
            return err;
        };
        defer {
            self.registry.remove(registered);
            registered.mutex.unlock(self.io);
        }
        const host = registered.host.?;
        host.cancellation = &slot.cancelled;
        host.deadline.cancellation = &slot.cancelled;
        host.active = &slot.active;
        host.diagnostics = self.diagnostics;
        host.wire.observer = self.diagnostics;
        std.crypto.secureZero(u8, response.payload);
        var limits = self.config.limits;
        if (prefix.maximum_packet != 0) limits.frame_bytes = @min(limits.frame_bytes, prefix.maximum_packet);
        try limits.validate();
        var engine = try mysql.Session.Engine(Host, Output).init(allocator, host, &tx, limits, prefix.negotiated());
        defer engine.deinit();
        try tx.writeAll(try backend.ok(0, false));
        self.authenticated();
        authentication_pending = false;
        slot.authenticated.store(true, .release);
        while (true) {
            try transport.resetDeadline(limits.idle_ms);
            var frame = try mysql.Frame.read(allocator, &channel, 0, limits.frame_bytes);
            defer frame.deinit();
            if (self.draining.load(.acquire)) return error.GatewayDraining;
            try transport.resetDeadline(host.commandMilliseconds());
            if (!try boundedHandle(self.io, transport.deadline, @TypeOf(engine).handle, .{ &engine, frame.payload })) break;
        }
        try transport.resetDeadline(limits.write_ms);
        try channel.finish();
    }
    fn serve(self: *Server, listener: *std.Io.net.Server, protocol: Protocol) !void {
        while (true) {
            const stream = try listener.accept(self.io);
            try self.mutex.lock(self.io);
            const first: usize = if (self.authenticating >= self.config.limits.authentications) self.config.limits.connections else 0;
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
            if (index < self.config.limits.connections) self.authenticating += 1;
            slot.future = self.io.concurrent(Server.connection, .{ self, slot, stream, index >= self.config.limits.connections, protocol }) catch |err| {
                slot.done.store(true, .release);
                slot.future = null;
                if (index < self.config.limits.connections) self.authenticating -= 1;
                self.mutex.unlock(self.io);
                stream.close(self.io);
                self.diagnostics.event(.{ .name = "sql.connection.refused", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
                continue;
            };
            self.mutex.unlock(self.io);
        }
    }
};
// Cancellation joins the command before its frame/host/allocator can be freed.
// An accepted write's pending controls belong to AccountRuntime, not this task.
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
fn runAccount(runtime: *g.AccountRuntime, diagnostics: *telemetry.Runtime) void {
    var interval_ms: u32 = 5;
    while (true) {
        const progressed = runtime.tick() catch |err| blk: {
            if (!g.station.client.Client.unavailable(err)) {
                runtime.ready.store(false, .release);
                diagnostics.event(.{ .name = "sql.account.stopped", .level = .err, .outcome = .failed, .error_type = if (runtime.background.last_rejection) |cause| @tagName(cause) else @errorName(err) });
                return;
            }
            break :blk false;
        };
        // Idle accounts share the same bounded native request admission with
        // active work and caller validation. Back off idle polling; a completed
        // step restores the short interval without retaining a work queue.
        interval_ms = if (progressed) 5 else @min(interval_ms * 2, 1000);
        runtime.io.sleep(.fromMilliseconds(interval_ms), .awake) catch return;
    }
}
pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "transit-sql-gateway", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    try run(init, &diagnostics);
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and std.mem.eql(u8, args[1], "--help")) {
        return std.Io.File.stdout().writeStreamingAll(init.io, "transit-sql-gateway CONFIG.json\n" ++
            "transit-sql-gateway --initialize CONFIG.json\n" ++
            "transit-sql-gateway control CONTROL.json list|status|pending|prepare|submit|credential [arguments]\n" ++
            "Database access and signed account recovery; see the configuration guide.\n");
    }
    if (args.len >= 2 and std.mem.eql(u8, args[1], "control")) return Control.run(init, args[2..]);
    const stop = try Stop.init();
    defer stop.deinit();
    const initialize = args.len == 3 and std.mem.eql(u8, args[1], "--initialize");
    if (args.len != 2 and !initialize) return error.ExpectedPrivateConfiguration;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[if (initialize) 2 else 1], init.gpa, .limited(65536));
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSlice(g.Configuration, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = &parsed.value;
    try config.validate();
    // Bootstrap and retained-operation recovery have no dependency on listener
    // credentials. In particular, expired or removed PEM files cannot prevent
    // a disabled listener's workers from resuming accepted operations.
    var context: ?tls.Context = if (!initialize and config.wireListening() and config.tls_mode != .disabled) blk: {
        const certificate = try init.gpa.dupeSentinel(u8, config.certificate_file, 0);
        defer init.gpa.free(certificate);
        const certificate_key = try init.gpa.dupeSentinel(u8, config.certificate_key_file, 0);
        defer init.gpa.free(certificate_key);
        break :blk try tls.Context.init(certificate, certificate_key);
    } else null;
    defer if (context) |*value| value.deinit();
    var runtimes: std.ArrayList(*g.AccountRuntime) = .empty;
    defer runtimes.deinit(init.gpa);
    defer for (runtimes.items) |runtime| runtime.deinit();
    for (config.accounts) |account| {
        var keys: g.AccountRuntime.Keys = undefined;
        defer std.crypto.secureZero(u8, std.mem.asBytes(&keys));
        inline for (@typeInfo(g.Configuration.KeyFiles).@"struct".field_names) |field| @field(keys, field) = try g.query.wire.readKey(init.gpa, init.io, @field(account.keys, field));
        const runtime = if (initialize) try g.AccountRuntime.bootstrap(init.gpa, init.io, config.native_url, .{ .configuration = account.ledger }, account.generation, account.association, keys, config.request_timeout_ms) else try g.AccountRuntime.init(init.gpa, init.io, config.native_url, .{ .configuration = account.ledger }, account.generation, account.association, keys, config.request_timeout_ms);
        errdefer runtime.deinit();
        try runtimes.append(init.gpa, runtime);
    }
    var activation = try std.Io.Dir.cwd().openDir(init.io, config.activation_directory, .{ .iterate = true });
    defer activation.close(init.io);
    for (config.accounts) |account| {
        var name: [96]u8 = undefined;
        const marker = try std.fmt.bufPrint(&name, "{d}-{d}-{d}.activation", .{ account.ledger.realm, account.ledger.owner, account.generation });
        const file = activation.createFile(init.io, marker, .{ .exclusive = true, .permissions = .fromMode(0o600) }) catch |err| if (err == error.PathAlreadyExists) return error.FreshOwnershipRequired else return err;
        defer file.close(init.io);
        try file.sync(init.io);
        if (std.c.fsync(activation.handle) != 0) return error.GatewayActivationSyncFailed;
    }
    var tasks: [g.Limits.max_accounts]?std.Io.Future(void) = @splat(null);
    defer for (&tasks) |*task| if (task.*) |*future| future.cancel(init.io);
    for (runtimes.items, 0..) |runtime, i| tasks[i] = try init.io.concurrent(runAccount, .{ runtime, diagnostics });
    const started = std.Io.Clock.awake.now(init.io);
    while (true) {
        if (Stop.stopping()) return;
        var ready = true;
        for (runtimes.items) |runtime| ready = ready and runtime.ready.load(.acquire);
        if (ready) break;
        if (started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() >= (if (initialize) @as(i64, 120000) else 30000)) return error.GatewayOwnerUnavailable;
        try init.io.sleep(.fromMilliseconds(5), .awake);
    }
    if (initialize) {
        diagnostics.event(.{ .name = "sql.account.initialized", .operation = "sql" });
        return;
    }
    var registry = try g.Registry.init(init.gpa, init.io, config, runtimes.items, if (config.native) |native| native.instance else config.accounts[0].ledger.account[0..16].*);
    defer registry.deinit();
    var native_context: ?tls.Context = if (config.native) |native| if (native.tls) |selected| try tls.Context.init(try init.arena.allocator().dupeSentinel(u8, selected.certificate_file, 0), try init.arena.allocator().dupeSentinel(u8, selected.key_file, 0)) else null else null;
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
    const workers = try init.gpa.alloc(Worker, @as(usize, config.limits.connections) + 2);
    defer init.gpa.free(workers);
    for (workers) |*worker| worker.* = .{};
    defer for (workers) |*worker| if (worker.future) |*future| future.cancel(init.io);
    var server: Server = .{ .allocator = init.gpa, .io = init.io, .config = config, .tls_context = if (context) |*value| value else null, .runtimes = runtimes.items, .diagnostics = diagnostics, .workers = workers, .registry = &registry };
    var health_listener: ?std.Io.net.Server = if (config.health_port) |port| try (try std.Io.net.IpAddress.parseIp4(config.health_address, port)).listen(init.io, .{ .reuse_address = true }) else null;
    defer if (health_listener) |*listener| listener.deinit(init.io);
    var health: ?std.Io.Future(anyerror!void) = if (health_listener) |*listener| try init.io.concurrent(Server.serveHealth, .{ &server, listener }) else null;
    defer if (health) |*future| {
        _ = future.cancel(init.io) catch {};
    };
    const Result = union(enum) { postgres: anyerror!void, mysql: anyerror!void, native: anyerror!void, local: anyerror!void, expiry: anyerror!void, stop: anyerror!void };
    var results: [6]Result = undefined;
    var listeners: std.Io.Select(Result) = .init(init.io, &results);
    defer listeners.cancelDiscard();
    if (postgres_listener) |*listener| try listeners.concurrent(.postgres, Server.serve, .{ &server, listener, .postgres });
    if (mysql_listener) |*listener| try listeners.concurrent(.mysql, Server.serve, .{ &server, listener, .mysql });
    if (native_listener) |*listener| try listeners.concurrent(.native, Native.serve, .{ &native_api, init.io, init.gpa, listener });
    if (local_listener) |*listener| try listeners.concurrent(.local, Native.serve, .{ &local_api, init.io, init.gpa, listener });
    try listeners.concurrent(.expiry, expireSessions, .{ &registry, init.io });
    try listeners.concurrent(.stop, Stop.wait, .{init.io});
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
    while (true) {
        try io.sleep(.fromMilliseconds(100), .awake);
        registry.sweep();
    }
}
