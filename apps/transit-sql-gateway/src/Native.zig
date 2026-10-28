//! HTTP carriage for shared logical SQL sessions. It asserts no native identity;
//! account authentication and every protected operation remain in the registry.
const std = @import("std");
const builtin = @import("builtin");
const g = @import("transit_sql");
const api = g.session_protocol;
const http = @import("transit_http_server");
const tls = @import("transit_tls_server");
const memory = @import("transit_memory");
const Self = @This();
registry: *g.Registry,
tls_context: ?*const tls.Context,
local: bool,
loopback: bool,
storage: *RequestStorage = undefined,
pub const RequestStorage = struct {
    pub const request_bytes = 16 * 1024 * 1024;
    pub const data_slots = 8;
    pub const control_slots = 4;
    data: memory.Pool,
    control: memory.Pool,
    control_bytes: usize,
    pub fn init(allocator: std.mem.Allocator, session_bytes: usize) !RequestStorage {
        const control_bytes = try std.math.add(usize, request_bytes, session_bytes);
        var data = try memory.Pool.init(allocator, &@as([data_slots]usize, @splat(request_bytes)));
        errdefer data.deinit();
        return .{ .data = data, .control = try .init(allocator, &@as([control_slots]usize, @splat(control_bytes))), .control_bytes = control_bytes };
    }
    pub fn deinit(self: *RequestStorage) void {
        self.control.deinit();
        self.data.deinit();
    }
    pub fn acquire(self: *RequestStorage, control: bool) !memory.Pool.Lease {
        return if (control) self.control.acquire(self.control_bytes) else self.data.acquire(request_bytes);
    }
    pub fn reservedBytes(self: *const RequestStorage) usize {
        return self.data.reservedBytes() + self.control.reservedBytes();
    }
};
pub const Connection = struct {
    transport: tls.Transport,
    secure: ?tls.Session = null,
    input: std.Io.Reader,
    output: std.Io.Writer,
    peer: g.Registry.Peer,
    pub fn init(self: *Connection, context: *Self, io: std.Io, _: std.mem.Allocator, stream: std.Io.net.Stream, input: []u8, output: []u8) !void {
        self.* = .{ .transport = .{ .io = io, .stream = stream, .deadline = .none }, .input = .{ .buffer = input, .seek = 0, .end = 0, .vtable = &.{ .stream = read } }, .output = .{ .buffer = output, .end = 0, .vtable = &.{ .drain = write } }, .peer = .{ .loopback = context.loopback } };
        try self.transport.resetDeadline(context.registry.configuration.limits.handshake_ms);
        if (context.local) {
            if (builtin.os.tag != .linux) return error.UnsupportedSqlPeerPlatform;
            const Credentials = extern struct { pid: i32, uid: u32, gid: u32 };
            var credentials: Credentials = undefined;
            var length: std.os.linux.socklen_t = @sizeOf(Credentials);
            const result = std.os.linux.getsockopt(stream.socket.handle, std.os.linux.SOL.SOCKET, std.os.linux.SO.PEERCRED, std.mem.asBytes(&credentials), &length);
            if (std.os.linux.errno(result) != .SUCCESS or length != @sizeOf(Credentials)) return error.InvalidSqlPeer;
            self.peer.uid = credentials.uid;
        } else if (context.tls_context) |selected| {
            if (!context.registry.acquireAuthentication()) return error.GatewayConnectionCapacity;
            defer context.registry.releaseAuthentication();
            self.secure = try tls.Session.accept(selected, &self.transport);
            self.peer.tls = true;
        }
        // The HTTP owner joins/cancels a request at its absolute deadline.
        // A successful connection can be reused beyond its handshake deadline.
        self.transport.deadline = .none;
    }
    pub fn deinit(self: *Connection) void {
        if (self.secure) |*secure| secure.deinit();
    }
    pub fn reader(self: *Connection) *std.Io.Reader {
        return &self.input;
    }
    pub fn writer(self: *Connection) *std.Io.Writer {
        return &self.output;
    }
    fn read(reader_: *std.Io.Reader, out: *std.Io.Writer, limit: std.Io.Limit) std.Io.Reader.StreamError!usize {
        const self: *Connection = @alignCast(@fieldParentPtr("input", reader_));
        var buffer: [8192]u8 = undefined;
        const bytes = buffer[0..limit.minInt(buffer.len)];
        const count = (if (self.secure) |*secure| secure.read(bytes) else self.transport.read(bytes)) catch return error.ReadFailed;
        if (count == 0) return error.EndOfStream;
        try out.writeAll(bytes[0..count]);
        return count;
    }
    fn send(self: *Connection, bytes: []const u8) std.Io.Writer.Error!void {
        (if (self.secure) |*secure| secure.writeAll(bytes) else self.transport.writeAll(bytes)) catch return error.WriteFailed;
    }
    fn write(writer_: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const self: *Connection = @alignCast(@fieldParentPtr("output", writer_));
        try self.send(writer_.buffered());
        writer_.end = 0;
        var count: usize = 0;
        for (data[0 .. data.len - 1]) |bytes| {
            try self.send(bytes);
            count += bytes.len;
        }
        for (0..splat) |_| {
            try self.send(data[data.len - 1]);
            count += data[data.len - 1].len;
        }
        return count;
    }
};
pub fn isControl(_: *Self, request: *std.http.Server.Request) bool {
    return std.mem.eql(u8, request.head.target, api.control_path);
}
pub fn connectionError(_: *Self, _: anyerror, _: bool) void {}
pub fn handleConnection(self: *Self, _: std.Io, _: std.mem.Allocator, connection: *Connection, request: *std.http.Server.Request) !void {
    const lease = try self.storage.acquire(isControl(self, request));
    defer lease.release(true) catch unreachable;
    // Control execution frees and reuses temporary objects independently of the
    // request arena. Neither domain can consume the other's configured budget.
    const backing = lease.value.owner.buffer;
    var scratch = memory.Workspace.fromBuffer(backing[0..RequestStorage.request_bytes]);
    const scratch_lease = try scratch.acquire();
    defer scratch_lease.release(false) catch unreachable;
    var working: ?memory.Slab = if (isControl(self, request)) try .fromBuffer(@alignCast(backing[RequestStorage.request_bytes..])) else null;
    defer if (working) |*slab| slab.deinit();
    var budget: g.query.QueryMemory = .{ .parent = try scratch_lease.allocator(), .limit = RequestStorage.request_bytes };
    var arena: std.heap.ArenaAllocator = .init(budget.allocator());
    defer arena.deinit();
    const a = arena.allocator();
    if (request.head.method != .POST or (!std.mem.eql(u8, request.head.target, api.data_path) and !isControl(self, request))) return http.respond(request, .not_found, "{\"err\":\"UnknownSqlRoute\"}");
    for ([_][]const u8{ "origin", "authorization", "cookie", "forwarded", "x-forwarded-for", "x-forwarded-user", "x-transit-uid", "transfer-encoding", "content-encoding" }) |name| if (try http.header(request, name) != null) return http.respond(request, .bad_request, "{\"err\":\"InvalidSqlHeaders\"}");
    if (!std.mem.eql(u8, (try http.header(request, "content-type")) orelse "", "application/json") or request.head.content_length == null or request.head.content_length.? > api.max_message_bytes) return http.respond(request, .bad_request, "{\"err\":\"InvalidSqlBody\"}");
    const control = isControl(self, request);
    const body = try request.readerExpectNone(&.{}).allocRemaining(a, .limited(api.max_message_bytes));
    const parsed = api.parse(api.Request, a, body) catch |err| return respond(request, try self.registry.failure(a, err));
    defer parsed.deinit();
    if (parsed.value.control() != control) return respond(request, try self.registry.failure(a, error.InvalidSqlLane));
    const response = self.registry.request(a, if (working) |*slab| slab.allocator() else a, parsed.value, connection.peer) catch |err| try self.registry.failure(a, err);
    try respond(request, response);
}
fn respond(request: *std.http.Server.Request, body: []const u8) !void {
    const content_type = if (std.mem.startsWith(u8, body, "TSR1")) api.ResultFrame.content_type else "application/json";
    try request.respond(body, .{ .keep_alive = request.head.keep_alive, .extra_headers = &.{ .{ .name = "content-type", .value = content_type }, .{ .name = "cache-control", .value = "no-store" }, .{ .name = "x-content-type-options", .value = "nosniff" } } });
}
pub fn serve(self: *Self, io: std.Io, allocator: std.mem.Allocator, listener: *std.Io.net.Server) !void {
    var storage = try RequestStorage.init(allocator, self.registry.configuration.limits.session_bytes);
    defer storage.deinit();
    self.storage = &storage;
    // HTTP teardown joins every request before returning the reserved bytes.
    return http.serve(io, allocator, listener, .{ .connections = 16, .requests = RequestStorage.data_slots, .control_requests = RequestStorage.control_slots, .header_timeout_ms = 1000, .request_timeout_ms = self.registry.configuration.limits.command_ms + 1000, .requests_per_connection = 256 }, self);
}

test "full native data slots leave separate erased control capacity available" {
    const t = std.testing;
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var storage = try RequestStorage.init(probe.allocator(), 4096);
    defer storage.deinit();
    try t.expectEqual(storage.reservedBytes(), probe.live_bytes);
    var leases: [RequestStorage.data_slots]memory.Pool.Lease = undefined;
    var acquired: usize = 0;
    defer for (leases[0..acquired]) |lease| lease.release(true) catch unreachable;
    probe.begin(true);
    for (&leases) |*lease| {
        lease.* = try storage.acquire(false);
        acquired += 1;
        _ = try (try lease.allocator()).dupe(u8, "account payload");
    }
    try t.expectError(error.MemoryPoolExhausted, storage.acquire(false));
    const control = try storage.acquire(true);
    _ = try (try control.allocator()).dupe(u8, "cancellation request");
    try control.release(true);
    const next = try storage.acquire(true);
    defer next.release(true) catch unreachable;
    try t.expect(std.mem.allEqual(u8, next.value.owner.buffer, 0));
    try probe.verify();
}
