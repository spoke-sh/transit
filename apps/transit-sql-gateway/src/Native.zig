//! HTTP carriage for shared logical SQL sessions. It asserts no native identity;
//! account authentication and every protected operation remain in the registry.
const std = @import("std");
const builtin = @import("builtin");
const g = @import("transit_sql");
const api = g.session_protocol;
const http = @import("transit_http_server");
const tls = @import("transit_tls_server");
const Self = @This();
registry: *g.Registry,
tls_context: ?*const tls.Context,
local: bool,
loopback: bool,
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
pub fn handleConnection(self: *Self, _: std.Io, allocator: std.mem.Allocator, connection: *Connection, request: *std.http.Server.Request) !void {
    var memory: g.query.QueryMemory = .{ .parent = allocator, .limit = 16 * 1024 * 1024 };
    var arena: std.heap.ArenaAllocator = .init(memory.allocator());
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
    const response = self.registry.request(a, parsed.value, connection.peer) catch |err| try self.registry.failure(a, err);
    try respond(request, response);
}
fn respond(request: *std.http.Server.Request, body: []const u8) !void {
    try request.respond(body, .{ .keep_alive = request.head.keep_alive, .extra_headers = &.{ .{ .name = "content-type", .value = "application/json" }, .{ .name = "cache-control", .value = "no-store" }, .{ .name = "x-content-type-options", .value = "nosniff" } } });
}
pub fn serve(self: *Self, io: std.Io, allocator: std.mem.Allocator, listener: *std.Io.net.Server) !void {
    return http.serve(io, allocator, listener, .{ .connections = 16, .requests = 8, .control_requests = 4, .header_timeout_ms = 1000, .request_timeout_ms = self.registry.configuration.limits.command_ms + 1000, .requests_per_connection = 256 }, self);
}
