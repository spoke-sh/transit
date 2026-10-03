//! Bounded inbound HTTP/2 gRPC. One unary request per live stream, with
//! unary/server-streaming replies. No identity, persistence or retry policy.
const std = @import("std");
const http = @import("http");
const wire = @import("grpc");
const neutral = @import("transit_http_server");
const root = @import("root.zig");
const Io = std.Io;

pub const Options = struct {
    connections: u8 = 16,
    requests: u8 = 4,
    control_requests: u8 = 2,
    header_timeout_ms: u32 = 5000,
    request_timeout_ms: u32 = 180000,
    write_timeout_ms: u32 = 5000,
    connection_timeout_ms: u32 = 300000,
    calls_per_connection: u16 = 64,
    limits: root.Limits = .{},
    pub fn validate(self: Options) !void {
        try self.limits.validate();
        if (self.connections < 2 or self.connections > 64 or self.requests == 0 or self.control_requests == 0 or self.limits.request_messages == 0 or
            @as(u16, self.requests) + self.control_requests > self.connections or self.header_timeout_ms == 0 or
            self.write_timeout_ms == 0 or self.header_timeout_ms > self.request_timeout_ms or
            self.write_timeout_ms > self.request_timeout_ms or self.request_timeout_ms > self.connection_timeout_ms or
            self.connection_timeout_ms > 300000 or self.calls_per_connection == 0 or self.calls_per_connection > 256)
            return error.InvalidGrpcServerLimits;
    }
};

pub const Request = struct {
    fields: []const http.hpack.Field,
    message: []const u8,
    /// Authentication and framing headers never have first/last-wins semantics.
    pub fn header(self: Request, name: []const u8) !?[]const u8 {
        var found: ?[]const u8 = null;
        for (self.fields) |field| if (std.mem.eql(u8, field.name, name)) {
            if (found != null) return error.DuplicateGrpcHeader;
            found = field.value;
        };
        return found;
    }
    pub fn method(self: Request) ![]const u8 {
        return (try self.header(":path")) orelse error.InvalidGrpcRequest;
    }
    fn validate(self: Request) !void {
        if (!std.mem.eql(u8, (try self.header(":method")) orelse "", "POST")) return error.InvalidGrpcRequest;
        const content = (try self.header("content-type")) orelse return error.InvalidGrpcRequest;
        if (!std.mem.eql(u8, content, "application/grpc") and !std.mem.eql(u8, content, "application/grpc+proto")) return error.InvalidGrpcRequest;
        if (try self.header("grpc-encoding")) |encoding| if (!std.mem.eql(u8, encoding, "identity")) return error.CompressedUnsupported;
        _ = try self.header("authorization");
        const path = try self.method();
        try (root.Request{ .method = path, .shape = .unary, .messages = &.{self.message} }).validate(.{});
    }
    fn timeout(self: Request, maximum: u32) !u32 {
        const value = (try self.header("grpc-timeout")) orelse return maximum;
        if (value.len < 2 or value.len > 9) return error.InvalidGrpcTimeout;
        const digits = value[0 .. value.len - 1];
        for (digits) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidGrpcTimeout;
        const amount = try std.fmt.parseInt(u64, digits, 10);
        const nanos = @as(u128, amount) * switch (value[value.len - 1]) {
            'H' => @as(u64, 3600000000000),
            'M' => @as(u64, 60000000000),
            'S' => @as(u64, 1000000000),
            'm' => @as(u64, 1000000),
            'u' => @as(u64, 1000),
            'n' => @as(u64, 1),
            else => return error.InvalidGrpcTimeout,
        };
        return @intCast(@max(1, @min(maximum, (nanos + 999999) / 1000000)));
    }
};

const ReadEvent = union(enum) { bytes: anyerror!usize };
const Connection = struct {
    io: Io,
    allocator: std.mem.Allocator,
    options: Options,
    codec: http.h2.Connection,
    reader: *Io.Reader,
    writer: *Io.Writer,
    select: *Io.Select(ReadEvent),
    input: [8192]u8 = undefined,
    output: std.ArrayList(u8) = .empty,
    events: std.ArrayList(http.h2.Event) = .empty,
    head: ?http.hpack.HeaderList = null,
    stream: u31 = 0,
    body: [16384 + 5]u8 = undefined,
    length: usize = 0,
    ended: bool = false,
    cancelled: bool = false,
    writing: bool = false,
    started: Io.Timestamp = .zero,

    fn read(reader: *Io.Reader, buffer: []u8) anyerror!usize {
        var slices = [_][]u8{buffer};
        return reader.readVec(&slices);
    }
    fn arm(self: *Connection) !void {
        try self.select.concurrent(.bytes, read, .{ self.reader, &self.input });
    }
    fn write(writer: *Io.Writer, bytes: []const u8) anyerror!void {
        try writer.writeAll(bytes);
        try writer.flush();
    }
    fn flush(self: *Connection) !void {
        if (self.output.items.len == 0) return;
        // A timeout may interrupt a partial frame. The caller closes this
        // connection; it must never append a trailer to an unknown byte offset.
        self.writing = true;
        try neutral.deadline(self.io, self.options.write_timeout_ms, write, .{ self.writer, self.output.items });
        self.writing = false;
        self.output.clearRetainingCapacity();
    }
    fn pump(self: *Connection, wait: bool) !void {
        var ready: [1]ReadEvent = undefined;
        if (try self.select.awaitMany(&ready, @intFromBool(wait)) == 0) return;
        const count = try ready[0].bytes;
        defer {
            for (self.events.items) |*event| event.deinit(self.allocator);
            self.events.clearRetainingCapacity();
        }
        try self.codec.recv(self.input[0..count], &self.output, &self.events);
        for (self.events.items) |*event| switch (event.*) {
            .headers => |head| {
                if (self.head != null or self.codec.remote_streams_total > self.options.calls_per_connection) {
                    try self.codec.sendRstStream(&self.output, head.stream_id, .refused_stream);
                    continue;
                }
                if (head.headers.fields.len > 64) return error.GrpcBudgetExceeded;
                self.head = head.headers;
                event.* = .settings_ack; // ownership transferred until this RPC joins
                self.stream = head.stream_id;
                self.ended = head.end_stream;
                self.started = Io.Clock.awake.now(self.io);
            },
            .data => |data| {
                if (data.stream_id != self.stream or self.cancelled or self.ended) return error.InvalidGrpcRequest;
                if (data.data.len > self.body.len - self.length) return error.GrpcBudgetExceeded;
                @memcpy(self.body[self.length..][0..data.data.len], data.data);
                self.length += data.data.len;
                if (self.length >= 5) {
                    if (self.body[0] != 0) return error.CompressedUnsupported;
                    const size = std.mem.readInt(u32, self.body[1..5], .big);
                    if (size > self.options.limits.message_bytes or size + 5 > self.options.limits.request_bytes) return error.GrpcBudgetExceeded;
                    if (self.length > @as(usize, size) + 5) return error.InvalidGrpcShape;
                }
                self.ended = data.end_stream;
                if (data.data.len > 0) {
                    try self.codec.sendWindowUpdate(&self.output, 0, @intCast(data.data.len));
                    try self.codec.sendWindowUpdate(&self.output, data.stream_id, @intCast(data.data.len));
                }
            },
            .stream_reset => |reset_event| if (reset_event.stream_id == self.stream) {
                self.cancelled = true;
            },
            .goaway => return error.GrpcConnectionClosing,
            else => {},
        };
        try self.flush();
        try self.arm();
    }
    fn receive(self: *Connection) anyerror!void {
        while (!self.ended) {
            try self.pump(true);
            if (self.cancelled) return error.GrpcCancelled;
        }
    }
    fn reset(self: *Connection) void {
        if (self.head) |*head| head.deinit(self.allocator);
        self.head = null;
        self.stream = 0;
        self.length = 0;
        self.ended = false;
        self.cancelled = false;
        std.crypto.secureZero(u8, &self.body);
    }
};

pub const Response = struct {
    connection: *Connection,
    begun: bool = false,
    finished: bool = false,
    messages: u32 = 0,
    bytes: u32 = 0,
    /// Poll the already outstanding read; never cancel a speculative read and
    /// discard bytes. Call before/after bounded upstream operations as well.
    pub fn check(self: *Response) !void {
        try self.connection.pump(false);
        if (self.connection.cancelled) return error.GrpcCancelled;
    }
    fn begin(self: *Response) !void {
        if (self.begun) return;
        const c = self.connection;
        try c.codec.sendHeaders(&c.output, c.stream, &.{
            .{ .name = ":status", .value = "200" },
            .{ .name = "content-type", .value = "application/grpc" },
            .{ .name = "grpc-accept-encoding", .value = "identity" },
        }, false);
        try c.flush();
        self.begun = true;
    }
    pub fn send(self: *Response, message: []const u8) !void {
        if (self.finished) return error.GrpcResponseFinished;
        const c = self.connection;
        const limits = c.options.limits;
        if (message.len > limits.message_bytes or self.messages >= limits.response_messages or message.len + 5 > limits.response_bytes -| self.bytes) return error.GrpcBudgetExceeded;
        try self.check();
        try self.begin();
        var framed: [16384 + 5]u8 = undefined;
        defer std.crypto.secureZero(u8, &framed);
        wire.frame.encodeInto(framed[0 .. 5 + message.len], message);
        var sent: usize = 0;
        while (sent < message.len + 5) {
            try self.check();
            const stream = c.codec.stream(c.stream) orelse return error.GrpcCancelled;
            const credit = @min(c.codec.conn_send_window, stream.send_window);
            if (credit <= 0) {
                try neutral.deadline(c.io, c.options.write_timeout_ms, waitCredit, .{self});
                continue;
            }
            const size: usize = @min(@as(usize, @intCast(credit)), @as(usize, message.len + 5 - sent), 16384);
            try c.codec.sendData(&c.output, c.stream, framed[sent..][0..size], false);
            try c.flush();
            sent += size;
        }
        self.messages += 1;
        self.bytes += @intCast(message.len + 5);
    }
    fn waitCredit(self: *Response) anyerror!void {
        const c = self.connection;
        while (true) {
            try c.pump(true);
            if (c.cancelled) return error.GrpcCancelled;
            const stream = c.codec.stream(c.stream) orelse return error.GrpcCancelled;
            if (@min(c.codec.conn_send_window, stream.send_window) > 0) return;
        }
    }
    pub fn finish(self: *Response, status: u8, message: []const u8) !void {
        if (self.finished or status > 16 or message.len > 128) return error.InvalidGrpcStatus;
        // Callers own diagnostic authorization and disclosure. Accept bounded
        // printable ASCII only; percent is encoded per the gRPC message field.
        // Raw credentials, control bytes and unbounded upstream text are invalid.
        var encoded: [128 * 3]u8 = undefined;
        var diagnostic: std.Io.Writer = .fixed(&encoded);
        for (message) |byte| {
            if (byte < 32 or byte > 126) return error.InvalidGrpcStatus;
            if (byte == '%') try diagnostic.writeAll("%25") else try diagnostic.writeByte(byte);
        }
        try self.check();
        try self.begin();
        var number: [2]u8 = undefined;
        const c = self.connection;
        try c.codec.sendHeaders(&c.output, c.stream, &.{
            .{ .name = "grpc-status", .value = try std.fmt.bufPrint(&number, "{d}", .{status}) },
            .{ .name = "grpc-message", .value = diagnostic.buffered() },
        }, true);
        try c.flush();
        self.finished = true;
    }
};

/// context.handle(io, allocator, request, response) owns all application
/// authorization. isControl(request) reserves capacity only, never authority.
/// connectionError(error, handler_started) must log no request/credential bytes.
/// The listener is a private cleartext HTTP/2 socket behind an explicit TLS edge.
pub fn serve(io: Io, allocator: std.mem.Allocator, listener: *Io.net.Server, options: Options, context: anytype) !void {
    try options.validate();
    const Worker = struct {
        done: std.atomic.Value(bool) = .init(true),
        future: ?Io.Future(void) = null,
        fn run(slot: *@This(), worker_io: Io, alloc: std.mem.Allocator, socket: Io.net.Stream, limits: Options, admission: *neutral.Admission, ctx: @TypeOf(context)) void {
            defer slot.done.store(true, .release);
            defer socket.close(worker_io);
            var started = false;
            neutral.deadline(worker_io, limits.connection_timeout_ms, connection, .{ worker_io, alloc, socket, limits, admission, ctx, &started }) catch |err| ctx.connectionError(err, started);
        }
        fn connection(worker_io: Io, alloc: std.mem.Allocator, socket: Io.net.Stream, limits: Options, admission: *neutral.Admission, ctx: @TypeOf(context), started: *bool) anyerror!void {
            const memory = try alloc.alloc(u8, root.allocation_bytes);
            defer alloc.free(memory);
            defer std.crypto.secureZero(u8, memory);
            var bounded: std.heap.FixedBufferAllocator = .init(memory);
            var input: [8192]u8 = undefined;
            var output: [8192]u8 = undefined;
            var reader = socket.reader(worker_io, &input);
            var writer = socket.writer(worker_io, &output);
            var events: [1]ReadEvent = undefined;
            var selection: Io.Select(ReadEvent) = .init(worker_io, &events);
            var c: Connection = .{ .io = worker_io, .allocator = bounded.allocator(), .options = limits, .codec = .init(bounded.allocator(), .server, .{ .settings = .{ .max_concurrent_streams = 1, .initial_window_size = 16384, .max_header_list_size = limits.limits.metadata_bytes, .header_table_size = 4096 }, .max_header_block = limits.limits.metadata_bytes, .max_unproductive_frames = 64, .max_reset_streams = 4, .max_continuation_frames = 8 }), .reader = &reader.interface, .writer = &writer.interface, .select = &selection };
            defer c.reset();
            defer c.codec.deinit();
            defer c.output.deinit(c.allocator);
            defer c.events.deinit(c.allocator);
            // Join the sole network reader before freeing its buffers/codec.
            defer selection.cancelDiscard();
            try c.codec.sendPreface(&c.output);
            try c.flush();
            try c.arm();
            while (true) {
                neutral.deadline(worker_io, limits.header_timeout_ms, Connection.receive, .{&c}) catch |err| {
                    const status: u8 = switch (err) {
                        error.CompressedUnsupported => 12,
                        error.GrpcBudgetExceeded => 8,
                        error.InvalidGrpcShape, error.InvalidGrpcRequest => 3,
                        else => 0,
                    };
                    if (status != 0 and c.head != null and !c.writing) {
                        var rejected: Response = .{ .connection = &c };
                        try rejected.finish(status, "request framing rejected");
                        return;
                    }
                    if (err != error.GrpcCancelled) return err;
                    c.reset();
                    continue;
                };
                var response: Response = .{ .connection = &c };
                if (c.head == null) return error.InvalidGrpcShape;
                if (c.length < 5 or std.mem.readInt(u32, c.body[1..5], .big) != c.length - 5) {
                    try response.finish(3, "request framing rejected");
                    return;
                }
                const request: Request = .{ .fields = c.head.?.fields, .message = c.body[5..c.length] };
                request.validate() catch {
                    try response.finish(3, "invalid request");
                    c.reset();
                    continue;
                };
                const budget = request.timeout(limits.request_timeout_ms) catch {
                    try response.finish(3, "invalid timeout");
                    c.reset();
                    continue;
                };
                const elapsed = c.started.durationTo(Io.Clock.awake.now(worker_io)).toMilliseconds();
                const remaining: u32 = @intCast(@max(1, @as(i64, budget) - elapsed));
                const control = ctx.isControl(request);
                if (admission.acquire(control, if (control) limits.control_requests else limits.requests)) {
                    defer admission.release(control);
                    started.* = true;
                    neutral.deadline(worker_io, remaining, dispatch, .{ worker_io, alloc, ctx, request, &response }) catch |err| {
                        // The handler has joined. Only a known frame boundary
                        // permits deadline trailers; an interrupted write closes
                        // the connection with its partial prefix unresolved.
                        if (err != error.HttpDeadline or c.writing or c.cancelled or response.finished) return err;
                        try response.finish(4, "deadline exceeded");
                    };
                } else try response.finish(8, "capacity exhausted");
                c.reset();
                if (c.codec.remote_streams_total >= limits.calls_per_connection) {
                    try c.codec.sendGoaway(&c.output, .no_error, "");
                    try c.flush();
                    return;
                }
            }
        }
        fn dispatch(worker_io: Io, alloc: std.mem.Allocator, ctx: @TypeOf(context), request: Request, response: *Response) anyerror!void {
            try ctx.handle(worker_io, alloc, request, response);
            if (!response.finished) try response.finish(0, "");
        }
    };
    const slots = try allocator.alloc(Worker, options.connections);
    defer allocator.free(slots);
    for (slots) |*slot| slot.* = .{};
    defer for (slots) |*slot| if (slot.future) |*future| future.cancel(io);
    var admission: neutral.Admission = .{};
    while (true) {
        const socket = try listener.accept(io);
        const slot = for (slots) |*candidate| {
            if (candidate.done.load(.acquire)) break candidate;
        } else {
            socket.close(io);
            context.connectionError(error.GrpcCapacity, false);
            continue;
        };
        if (slot.future) |*future| future.await(io);
        slot.done.store(false, .release);
        slot.future = Io.concurrent(io, Worker.run, .{ slot, io, allocator, socket, options, &admission, context }) catch |err| {
            slot.done.store(true, .release);
            slot.future = null;
            socket.close(io);
            context.connectionError(err, false);
            continue;
        };
    }
}

test "server bounds and exact timeout/header interpretation" {
    try (Options{}).validate();
    try std.testing.expectError(error.InvalidGrpcServerLimits, (Options{ .connections = 2 }).validate());
    const request: Request = .{ .message = "", .fields = &.{.{ .name = "grpc-timeout", .value = "99999999H" }} };
    try std.testing.expectEqual(@as(u32, 180000), try request.timeout(180000));
    const duplicate: Request = .{ .message = "", .fields = &.{ .{ .name = "authorization", .value = "a" }, .{ .name = "authorization", .value = "b" } } };
    try std.testing.expectError(error.DuplicateGrpcHeader, duplicate.header("authorization"));
}
