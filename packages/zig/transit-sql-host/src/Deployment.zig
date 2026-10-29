//! Private local lifecycle control. The installation supervisor retains account
//! generations; this host owns only joined tasks and their current configuration.
const std = @import("std");
const host = @import("root.zig");
const g = @import("transit_sql_service");
const p = g.wire.protocol;
const tls = @import("transit_tls_server");
const Discovery = @import("transit_sql_client").Discovery;
const Placement = @import("Placement.zig");
const maximum = g.wire.max_body + 1024; // Full standalone configuration plus lifecycle envelope.
pub const Config = struct { socket: []const u8, crypto_capacity: usize = 0 };
pub const Action = union(enum) {
    start: struct { expected: ?[32]u8, configuration: g.Configuration },
    stop: [32]u8,
    status: void,
};
const Request = struct { definition: p.Growth.Definition, action: Action };
pub const Status = struct { definition: p.Growth.Definition, fingerprint: ?[32]u8, state: enum { stopped, running, failed }, failure: ?[]const u8 = null, local_requests: Placement.Snapshot = .{} };

pub fn socketPath(allocator: std.mem.Allocator, io: std.Io, runtime: ?[]const u8, installation: []const u8) ![]const u8 {
    const location = try Discovery.locate(allocator, io, runtime, installation, true);
    defer allocator.free(location.directory);
    defer allocator.free(location.socket);
    defer allocator.free(location.rendezvous);
    // Match the validated console socket's length even near sockaddr_un's
    // limit; the lifecycle channel has a distinct same-length suffix.
    const socket = try allocator.dupe(u8, location.socket);
    @memcpy(socket[socket.len - 5 ..], ".host");
    return socket;
}
pub fn fingerprint(allocator: std.mem.Allocator, configuration: g.Configuration) ![32]u8 {
    const bytes = try p.Json.valueAllocBounded(allocator, configuration, g.wire.max_body);
    defer allocator.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}
fn peer(stream: std.Io.net.Stream) !void {
    const Credentials = extern struct { pid: i32, uid: u32, gid: u32 };
    var credentials: Credentials = undefined;
    var length: std.os.linux.socklen_t = @sizeOf(Credentials);
    const result = std.os.linux.getsockopt(stream.socket.handle, std.os.linux.SOL.SOCKET, std.os.linux.SO.PEERCRED, std.mem.asBytes(&credentials), &length);
    if (std.os.linux.errno(result) != .SUCCESS or length != @sizeOf(Credentials) or credentials.uid != try Discovery.uid()) return error.InvalidSqlPeer;
}
fn receive(allocator: std.mem.Allocator, transport: *tls.Transport) ![]u8 {
    var header: [4]u8 = undefined;
    try transport.readExact(&header);
    const length = std.mem.readInt(u32, &header, .little);
    if (length == 0 or length > maximum) return error.InvalidSqlDeploymentFrame;
    const bytes = try allocator.alloc(u8, length);
    errdefer allocator.free(bytes);
    try transport.readExact(bytes);
    return bytes;
}
fn send(allocator: std.mem.Allocator, transport: *tls.Transport, value: anytype) !void {
    const bytes = try p.Json.valueAllocBounded(allocator, value, maximum);
    defer allocator.free(bytes);
    var header: [4]u8 = undefined;
    std.mem.writeInt(u32, &header, @intCast(bytes.len), .little);
    try transport.writeAll(&header);
    try transport.writeAll(bytes);
}
/// No retry. A lost start reply is resolved by status or repeating that exact
/// configuration/expected fingerprint, never by minting another generation.
pub fn call(allocator: std.mem.Allocator, io: std.Io, socket: []const u8, action: Action, timeout_ms: u32) !std.json.Parsed(Status) {
    try Discovery.verify(io, std.fs.path.dirname(socket) orelse return error.UnsafeSqlRuntimeDirectory);
    const stream = try (try std.Io.net.UnixAddress.init(socket)).connect(io);
    defer stream.close(io);
    try peer(stream);
    var transport: tls.Transport = .{ .io = io, .stream = stream, .deadline = .none };
    try transport.resetDeadline(timeout_ms);
    try send(allocator, &transport, Request{ .definition = p.Growth.current_definition, .action = action });
    const bytes = try receive(allocator, &transport);
    defer allocator.free(bytes);
    const result = try p.Json.parseFromSliceOwned(Status, allocator, bytes);
    errdefer result.deinit();
    if (result.value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    return result;
}

const Running = struct {
    init: std.process.Init,
    diagnostics: *g.wire.observability.telemetry.Runtime,
    config: std.json.Parsed(g.Configuration),
    endpoint: host.LocalEndpoint,
    shutdown: host.Shutdown = .{},
    done: std.atomic.Value(bool) = .init(false),
    failure: ?anyerror = null,
    future: ?std.Io.Future(void) = null,
    fingerprint: [32]u8,
    crypto_capacity: usize,
    fn run(self: *Running) void {
        defer self.done.store(true, .release);
        host.run(self.init, self.diagnostics, &self.config.value, self.endpoint, &self.shutdown, self.crypto_capacity) catch |err| {
            self.failure = err;
            self.diagnostics.event(.{ .name = "sql.host.failed", .level = .err, .error_type = @errorName(err) });
        };
    }
    fn destroy(self: *Running) void {
        self.shutdown.request(self.init.io);
        const protection = self.init.io.swapCancelProtection(.blocked);
        defer _ = self.init.io.swapCancelProtection(protection);
        const start = std.Io.Clock.awake.now(self.init.io);
        while (!self.done.load(.acquire) and start.durationTo(std.Io.Clock.awake.now(self.init.io)).toMilliseconds() < self.config.value.drain_ms + 1000) {
            self.init.io.sleep(.fromMilliseconds(10), .awake) catch {};
        }
        if (self.future) |*future| future.cancel(self.init.io);
        self.config.deinit();
        self.init.gpa.destroy(self);
    }
};

pub fn serve(init: std.process.Init, config: Config, endpoint: host.LocalEndpoint, diagnostics: *g.wire.observability.telemetry.Runtime) !void {
    const lock = try Discovery.lockSocket(init.gpa, init.io, config.socket);
    defer lock.close(init.io);
    var listener = try (try std.Io.net.UnixAddress.init(config.socket)).listen(init.io, .{});
    defer {
        listener.deinit(init.io);
        std.Io.Dir.cwd().deleteFile(init.io, config.socket) catch {};
    }
    var placement: Placement = .{ .base = endpoint };
    var running: ?*Running = null;
    defer if (running) |value| value.destroy();
    while (true) {
        const stream = try listener.accept(init.io);
        defer stream.close(init.io);
        peer(stream) catch continue;
        var transport: tls.Transport = .{ .io = init.io, .stream = stream, .deadline = .none };
        try transport.resetDeadline(5000);
        const bytes = receive(init.gpa, &transport) catch |err| {
            if (err == error.Canceled) return err;
            continue;
        };
        defer init.gpa.free(bytes);
        const request = p.Json.parseFromSlice(Request, init.gpa, bytes) catch continue;
        defer request.deinit();
        if (request.value.definition != p.Growth.current_definition) continue;
        apply(init, config, placement.endpoint(), diagnostics, &running, request.value.action) catch |err| {
            if (err == error.Canceled) return err;
            try transport.resetDeadline(5000);
            send(init.gpa, &transport, Status{ .definition = p.Growth.current_definition, .local_requests = placement.snapshot(), .fingerprint = if (running) |value| value.fingerprint else null, .state = .failed, .failure = @errorName(err) }) catch |failure| {
                if (failure == error.Canceled) return failure;
            };
            continue;
        };
        const done = if (running) |value| value.done.load(.acquire) else false;
        try transport.resetDeadline(5000);
        send(init.gpa, &transport, Status{ .definition = p.Growth.current_definition, .local_requests = placement.snapshot(), .fingerprint = if (running) |value| value.fingerprint else null, .state = if (running == null) .stopped else if (done) .failed else .running, .failure = if (done and running.?.failure != null) @errorName(running.?.failure.?) else null }) catch |failure| {
            if (failure == error.Canceled) return failure;
        };
    }
}
fn apply(init: std.process.Init, config: Config, endpoint: host.LocalEndpoint, diagnostics: *g.wire.observability.telemetry.Runtime, running: *?*Running, action: Action) !void {
    switch (action) {
        .status => {},
        .stop => |expected| if (running.*) |value| {
            if (!std.mem.eql(u8, &expected, &value.fingerprint)) return error.SqlDeploymentChanged;
            value.destroy();
            running.* = null;
        },
        .start => |start| {
            try start.configuration.validate();
            if (host.cryptoCapacity(&start.configuration) > config.crypto_capacity) return error.TlsMemoryCapacity;
            const digest = try fingerprint(init.gpa, start.configuration);
            if (running.*) |value| {
                if (std.mem.eql(u8, &digest, &value.fingerprint)) return;
                if (start.expected == null or !std.mem.eql(u8, &start.expected.?, &value.fingerprint)) return error.SqlDeploymentChanged;
            } else if (start.expected != null) return error.SqlDeploymentChanged;
            // Validate and own the full replacement before withdrawing admission.
            const encoded = try p.Json.valueAllocBounded(init.gpa, start.configuration, g.wire.max_body);
            defer init.gpa.free(encoded);
            const parsed = try p.Json.parseFromSliceOwned(g.Configuration, init.gpa, encoded);
            errdefer parsed.deinit();
            const next = try init.gpa.create(Running);
            errdefer init.gpa.destroy(next);
            next.* = .{ .init = init, .diagnostics = diagnostics, .config = parsed, .endpoint = endpoint, .fingerprint = digest, .crypto_capacity = config.crypto_capacity };
            if (running.*) |value| value.destroy();
            running.* = null;
            // Retain this activation even if task creation fails. Repeating a
            // lost start reply must observe the same failed owner, not activate
            // the same account generation a second time.
            next.future = init.io.concurrent(Running.run, .{next}) catch |err| blk: {
                next.failure = err;
                next.done.store(true, .release);
                break :blk null;
            };
            running.* = next;
        },
    }
}
