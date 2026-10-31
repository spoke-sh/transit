//! Joined browser socket tasks with one bounded snapshot buffer. Native metadata
//! watermarks suppress rescans; current rights/session checks run even while idle.
const std = @import("std");
const http = @import("transit_http_server");
const runtime = @import("BrowserRuntime.zig");
const Request = @import("BrowserRequest.zig");
const snapshot = @import("BrowserSnapshot.zig");
const c = runtime.catalog;
const Socket = struct {
    request: *Request,
    ws: *std.http.Server.WebSocket,
    name: []const u8,
    cookie: ?[]const u8,
    write_lock: std.Io.Mutex = .init,
    fn write(ws: *std.http.Server.WebSocket, bytes: []const u8, opcode: std.http.Server.WebSocket.Opcode) anyerror!void {
        try ws.writeMessage(bytes, opcode);
    }
    fn receive(self: *Socket) anyerror!void {
        var decoder: http.WebSocket.Decoder = .{};
        while (true) {
            const message = try decoder.next(self.ws.input);
            switch (message.opcode) {
                .text => return error.WebSocketProtocol,
                .pong => {},
                .ping, .close => {
                    try self.write_lock.lock(self.request.io);
                    defer self.write_lock.unlock(self.request.io);
                    try http.deadline(self.request.io, 1000, write, .{ self.ws, message.bytes, if (message.opcode == .ping) .pong else .connection_close });
                    if (message.opcode == .close) return;
                },
            }
        }
    }
    fn events(self: *Socket) anyerror!void {
        const io = self.request.io;
        const memory = try self.request.host.allocator.alloc(u8, 16 * 1024 * 1024);
        defer self.request.host.allocator.free(memory);
        defer std.crypto.secureZero(u8, memory);
        var scratch: std.heap.FixedBufferAllocator = .init(memory);
        var cursor: ?snapshot.Cursor = null;
        const start = std.Io.Clock.awake.now(io);
        while (start.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() < 50_000) {
            std.crypto.secureZero(u8, memory[0..scratch.end_index]);
            scratch.reset();
            var wire = c.client.Client.init(scratch.allocator(), io, "http://127.0.0.1:1");
            defer wire.deinit();
            wire.local = self.request.host.endpoint;
            wire.timeout_ms = 5000;
            var request = self.request.*;
            request.allocator = scratch.allocator();
            request.wire = &wire;
            {
                // Authorization and response preparation stay inside the write
                // interval, so queueing behind a slow control write cannot age
                // a previously authorized buffered snapshot.
                try self.write_lock.lock(io);
                defer self.write_lock.unlock(io);
                // No bytes of a racing cut were disclosed. Discard the whole
                // attempt and observe a fresh cut at the next bounded poll.
                const next = snapshot.read(request, self.name, self.cookie, cursor) catch |err| switch (err) {
                    error.PublishedSourceChanged, error.TableDataChanged => null,
                    else => return err,
                };
                if (next) |value| {
                    try http.deadline(io, 1000, write, .{ self.ws, value.bytes, .text });
                    cursor = value.cursor;
                }
            }
            try io.sleep(.fromMilliseconds(500), .awake);
        }
        try self.close(1000);
    }
    fn close(self: *Socket, code: u16) !void {
        try self.closeReason(code, "");
    }
    fn closeReason(self: *Socket, code: u16, reason: []const u8) !void {
        var bytes: [125]u8 = undefined;
        std.mem.writeInt(u16, bytes[0..2], code, .big);
        const length = @min(reason.len, 123);
        @memcpy(bytes[2..][0..length], reason[0..length]);
        try self.write_lock.lock(self.request.io);
        defer self.write_lock.unlock(self.request.io);
        try http.deadline(self.request.io, 1000, write, .{ self.ws, bytes[0 .. length + 2], .connection_close });
    }
    fn joined(self: *Socket) !void {
        const Result = union(enum) { input: anyerror!void, events: anyerror!void };
        var results: [2]Result = undefined;
        var tasks: std.Io.Select(Result) = .init(self.request.io, &results);
        defer tasks.cancelDiscard();
        try tasks.concurrent(.input, receive, .{self});
        try tasks.concurrent(.events, events, .{self});
        return switch (try tasks.await()) {
            inline else => |result| result,
        };
    }
};
pub fn run(request: *Request, name: []const u8) !void {
    const key = try http.WebSocket.handshake(request.request, runtime.subprotocol);
    const cookie = try request.cookie();
    // Admit session and publication before switching protocols. The event task
    // repeats this and current native source authorization before every frame.
    var session = try request.session(cookie);
    defer if (session) |*value| value.deinit();
    var publication = try request.declaration(.publication, c.BrowserRecordStore.digest(name));
    defer publication.deinit();
    if (publication.value().publication.descriptor.state != .published) return error.PublishedResourceWithdrawn;
    // Upgrade reuses the HTTP reader storage. Socket tasks must own their route
    // and credential bytes independently of that mutable transport buffer.
    const owned_name = try request.allocator.dupe(u8, name);
    const owned_cookie = if (cookie) |value| try request.allocator.dupe(u8, value) else null;
    request.response_started = true;
    var ws = try request.request.respondWebSocket(.{ .key = key, .extra_headers = &.{ .{ .name = "sec-websocket-protocol", .value = runtime.subprotocol }, .{ .name = "cache-control", .value = "no-store" } } });
    var socket: Socket = .{ .request = request, .ws = &ws, .name = owned_name, .cookie = owned_cookie };
    socket.joined() catch |err| {
        const code: u16 = switch (err) {
            error.PublishedResourceReset, error.TableDefinitionChanged => 1012,
            error.IdentityRestricted, error.IdentityBindingChanged, error.BindingRequired, error.SessionExpired, error.InvalidSession, error.SessionProviderChanged, error.ProviderDisabled, error.SecretDisabled, error.AccessDenied, error.CatalogDenied, error.PublishedResourceWithdrawn => 1008,
            else => http.WebSocket.closeCode(err),
        };
        socket.closeReason(code, @errorName(err)) catch {};
    };
}
