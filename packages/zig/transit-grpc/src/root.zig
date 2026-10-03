//! Finite HTTP/2 gRPC transport. No Transit authority, persistence or retry.
const std = @import("std");
const http = @import("http");
const wire = @import("grpc");
const tls = @import("transit_tls");
pub const Descriptor = @import("Descriptor.zig");
pub const Server = @import("Server.zig");
pub const protobuf = @import("protobuf");
pub const Entry = wire.Entry;
pub const Shape = enum(u8) { unary = 1, server_streaming = 2, client_streaming = 3, bidi = 4 };
pub const Limits = struct {
    message_bytes: u32 = 16384,
    request_bytes: u32 = 65536,
    response_bytes: u32 = 262144,
    request_messages: u32 = 64,
    response_messages: u32 = 64,
    metadata_bytes: u32 = 8192,
    pub fn validate(self: Limits) !void {
        if (self.message_bytes == 0 or self.message_bytes > 16384 or self.request_bytes > 65536 or self.response_bytes > 262144 or
            self.request_messages > 64 or self.response_messages > 64 or self.metadata_bytes == 0 or self.metadata_bytes > 8192) return error.InvalidGrpcLimits;
    }
};
pub const Endpoint = struct {
    host: []const u8,
    address: []const u8,
    port: u16,
    tls: bool = true,
    ca_file: ?[]const u8 = null,
    timeout_ms: u32 = 10000,
    limits: Limits = .{},
    pub fn validate(self: Endpoint) !void {
        try self.limits.validate();
        _ = try std.Io.net.HostName.init(self.host);
        _ = try std.Io.net.Ip4Address.parse(self.address, self.port);
        if (self.port == 0 or self.timeout_ms == 0 or self.timeout_ms > 300000) return error.InvalidGrpcEndpoint;
    }
};
pub const Request = struct {
    method: []const u8,
    shape: Shape,
    messages: []const []const u8,
    metadata: []const Entry = &.{},
    pub fn validate(self: Request, limits: Limits) !void {
        try limits.validate();
        if (self.method.len < 4 or self.method.len > 512 or self.method[0] != '/' or self.metadata.len > 64) return error.InvalidGrpcRequest;
        const slash = std.mem.indexOfScalarPos(u8, self.method, 1, '/') orelse return error.InvalidGrpcRequest;
        if (slash == 1 or slash == self.method.len - 1 or std.mem.indexOfScalarPos(u8, self.method, slash + 1, '/') != null) return error.InvalidGrpcRequest;
        for (self.method[1..], 1..) |byte, index| if (index != slash and !std.ascii.isAlphanumeric(byte) and byte != '_' and byte != '.') return error.InvalidGrpcRequest;
        if (self.messages.len > limits.request_messages) return error.GrpcBudgetExceeded;
        if ((self.shape == .unary or self.shape == .server_streaming) and self.messages.len != 1) return error.InvalidGrpcShape;
        var total: u64 = 0;
        for (self.messages) |message| {
            if (message.len > limits.message_bytes) return error.GrpcBudgetExceeded;
            total += message.len + wire.frame.header_len;
        }
        if (total > limits.request_bytes) return error.GrpcBudgetExceeded;
        total = 0;
        for (self.metadata) |field| {
            if (field.name.len == 0 or wire.metadata.isReserved(field.name)) return error.InvalidGrpcMetadata;
            for (field.name) |byte| if (!(byte >= 'a' and byte <= 'z') and !std.ascii.isDigit(byte) and byte != '_' and byte != '-' and byte != '.') return error.InvalidGrpcMetadata;
            if (!std.mem.endsWith(u8, field.name, "-bin")) for (field.value) |byte| if (byte < 32 or byte > 126) return error.InvalidGrpcMetadata;
            total += field.name.len + field.value.len * 2 + 32;
        }
        if (total > limits.metadata_bytes) return error.GrpcBudgetExceeded;
    }
};
pub const Field = http.hpack.Field;
pub const Event = union(enum) {
    initial_metadata: []const Field,
    message: []const u8,
    trailers: []const Field,
    half_close,
};
pub const Capture = struct {
    context: *anyopaque,
    /// Borrowed bytes. Return only when the adapter has durably captured its
    /// allowlisted representation. This low-level transport does not redact.
    emit: *const fn (*anyopaque, Event) anyerror!void,
};
pub const Result = struct {
    status: u32,
    sent_messages: u32,
    received_messages: u32,
    sent_bytes: u32,
    received_bytes: u32,
    half_closed: bool,
};
pub const allocation_bytes = 2 * 1024 * 1024;
const FlushWriter = struct {
    target: *std.Io.Writer,
    raw: *std.Io.Writer,
    interface: std.Io.Writer = .{ .buffer = &.{}, .vtable = &.{ .drain = drain, .flush = flush } },
    fn drain(writer: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const self: *FlushWriter = @fieldParentPtr("interface", writer);
        return self.target.writeSplat(data, splat);
    }
    fn flush(writer: *std.Io.Writer) std.Io.Writer.Error!void {
        const self: *FlushWriter = @fieldParentPtr("interface", writer);
        try self.target.flush();
        try self.raw.flush();
    }
};
fn ioCause(err: anyerror, reader: *const std.Io.net.Stream.Reader, writer: *const std.Io.net.Stream.Writer, secure: ?*const tls.Client) anyerror {
    // The pinned HTTP/2 session wraps reader failure and EOF as ConnectionClosed.
    if (err == error.ReadFailed or err == error.ConnectionClosed) {
        if (secure) |client| if (client.read_err) |cause| return cause;
        return reader.err orelse err;
    }
    return if (err == error.WriteFailed) writer.err orelse err else err;
}
fn run(gpa: std.mem.Allocator, io: std.Io, endpoint: Endpoint, request: Request, capture: Capture) !Result {
    try endpoint.validate();
    try request.validate(endpoint.limits);
    // One finite arena budgets HPACK, connection state, metadata and deframing.
    const memory = try gpa.alloc(u8, allocation_bytes);
    defer gpa.free(memory);
    defer std.crypto.secureZero(u8, memory);
    var allocator: std.heap.FixedBufferAllocator = .init(memory);
    const bounded = allocator.allocator();
    var trust: std.crypto.Certificate.Bundle = .empty;
    defer trust.deinit(bounded);
    const now = std.Io.Clock.real.now(io);
    if (endpoint.tls) {
        const path = endpoint.ca_file orelse return error.MissingGrpcTrust;
        try trust.addCertsFromFilePath(bounded, io, now, std.Io.Dir.cwd(), path);
    }
    const address = try std.Io.net.IpAddress.parseIp4(endpoint.address, endpoint.port);
    const socket = try address.connect(io, .{ .mode = .stream });
    defer socket.close(io);
    var buffers: [4][tls.Client.min_buffer_len]u8 = undefined;
    defer std.crypto.secureZero(u8, std.mem.asBytes(&buffers));
    var reader = socket.reader(io, &buffers[0]);
    var writer = socket.writer(io, &buffers[1]);
    var secure: tls.Client = undefined;
    var lock: std.Io.RwLock = .init;
    if (endpoint.tls) {
        var entropy: [tls.Client.Options.entropy_len]u8 = undefined;
        defer std.crypto.secureZero(u8, &entropy);
        try io.randomSecure(&entropy);
        secure = tls.Client.init(&reader.interface, &writer.interface, .{
            .host = .{ .explicit = endpoint.host },
            .ca = .{ .bundle = .{ .gpa = bounded, .io = io, .lock = &lock, .bundle = &trust } },
            .read_buffer = &buffers[2],
            .write_buffer = &buffers[3],
            .entropy = &entropy,
            .realtime_now = now,
            .required_alpn = "h2",
        }) catch |err| return ioCause(err, &reader, &writer, null);
    }
    defer if (endpoint.tls) std.crypto.secureZero(u8, std.mem.asBytes(&secure));
    var output: FlushWriter = .{ .target = if (endpoint.tls) &secure.writer else &writer.interface, .raw = &writer.interface };
    var session = http.h2_client.Session.init(bounded, if (endpoint.tls) &secure.reader else &reader.interface, &output.interface, .{
        .settings = .{ .enable_push = false, .max_concurrent_streams = 1, .initial_window_size = 16384, .max_header_list_size = endpoint.limits.metadata_bytes, .header_table_size = 4096 },
        .max_header_block = endpoint.limits.metadata_bytes,
        .max_unproductive_frames = 64,
        .max_reset_streams = 4,
        .max_continuation_frames = 8,
    }) catch |err| return ioCause(err, &reader, &writer, if (endpoint.tls) &secure else null);
    defer session.deinit();
    // Consume the server's initial settings before the first request so a
    // smaller receive window constrains every outgoing message from the start.
    session.advance() catch |err| return ioCause(err, &reader, &writer, if (endpoint.tls) &secure else null);
    var channel = wire.Channel.init(bounded, &session, .{ .max_recv_message_size = endpoint.limits.message_bytes, .max_send_message_size = endpoint.limits.message_bytes, .scheme = if (endpoint.tls) "https" else "http", .read_chunk = 4096, .user_agent = null });
    var authority_buffer: [280]u8 = undefined;
    channel.authority = try std.fmt.bufPrint(&authority_buffer, "{s}:{d}", .{ endpoint.host, endpoint.port });
    var call = channel.start(request.method, .{ .metadata = request.metadata, .timeout = .fromMillis(endpoint.timeout_ms) }) catch |err| return ioCause(err, &reader, &writer, if (endpoint.tls) &secure else null);
    defer call.deinit();
    var result: Result = .{ .status = 0, .sent_messages = 0, .received_messages = 0, .sent_bytes = 0, .received_bytes = 0, .half_closed = false };
    var frame_buffer: [16384 + wire.frame.header_len]u8 = undefined;
    defer std.crypto.secureZero(u8, &frame_buffer);
    var frame: []const u8 = "";
    var sent: usize = 0;
    var head_captured = false;
    while (true) {
        var progress = false;
        if (result.sent_messages < request.messages.len) {
            if (frame.len == 0) {
                const message = request.messages[result.sent_messages];
                wire.frame.writeHeader(frame_buffer[0..5], false, @intCast(message.len));
                @memcpy(frame_buffer[5..][0..message.len], message);
                frame = frame_buffer[0 .. 5 + message.len];
                sent = 0;
            }
            const count = session.sendDataPartial(call.sid, frame[sent..]) catch |err| return ioCause(err, &reader, &writer, if (endpoint.tls) &secure else null);
            sent += count;
            result.sent_bytes += @intCast(count);
            progress = count != 0;
            if (sent == frame.len) {
                result.sent_messages += 1;
                frame = "";
            }
        } else if (!result.half_closed) {
            call.closeSend() catch |err| return ioCause(err, &reader, &writer, if (endpoint.tls) &secure else null);
            try capture.emit(capture.context, .half_close);
            result.half_closed = true;
            progress = true;
        }
        const event = call.pollReceive() catch |err| return ioCause(err, &reader, &writer, if (endpoint.tls) &secure else null);
        if (!head_captured and call.head != null) {
            if (call.initialMetadata().?.fields.len > 64) return error.GrpcBudgetExceeded;
            try capture.emit(capture.context, .{ .initial_metadata = call.initialMetadata().?.fields });
            head_captured = true;
        }
        switch (event) {
            .pending => {},
            .message => |message| {
                if (result.received_messages == endpoint.limits.response_messages or message.len + 5 > endpoint.limits.response_bytes -| result.received_bytes) return error.GrpcBudgetExceeded;
                result.received_messages += 1;
                result.received_bytes += @intCast(message.len + 5);
                if ((request.shape == .unary or request.shape == .client_streaming) and result.received_messages > 1) return error.InvalidGrpcShape;
                try capture.emit(capture.context, .{ .message = message });
                progress = true;
            },
            .finished => {
                if (call.trailingMetadata()) |trailers| {
                    if (trailers.fields.len > 64) return error.GrpcBudgetExceeded;
                    try capture.emit(capture.context, .{ .trailers = trailers.fields });
                }
                const status = call.status orelse return error.MissingGrpcStatus;
                if (status == .ok and (request.shape == .unary or request.shape == .client_streaming) and result.received_messages != 1) return error.InvalidGrpcShape;
                result.status = @backingInt(status);
                return result;
            },
        }
        if (!progress) session.advance() catch |err| return ioCause(err, &reader, &writer, if (endpoint.tls) &secure else null);
    }
}
fn timeout(io: std.Io, milliseconds: u32) !void {
    try io.sleep(.fromMilliseconds(milliseconds), .awake);
}
pub fn execute(gpa: std.mem.Allocator, io: std.Io, endpoint: Endpoint, request: Request, capture: Capture) !Result {
    try endpoint.validate();
    try request.validate(endpoint.limits);
    const Choice = union(enum) { response: anyerror!Result, timeout: anyerror!void };
    var choices: [2]Choice = undefined;
    var select: std.Io.Select(Choice) = .init(io, &choices);
    defer select.cancelDiscard();
    try select.concurrent(.timeout, timeout, .{ io, endpoint.timeout_ms });
    try select.concurrent(.response, run, .{ gpa, io, endpoint, request, capture });
    return switch (try select.await()) {
        .response => |value| value,
        .timeout => error.GrpcOutcomeUnknown,
    };
}
test "finite requests reject shape, framing and metadata errors before transport" {
    const t = std.testing;
    try t.expectError(error.InvalidGrpcShape, (Request{ .method = "/test.Service/Method", .shape = .unary, .messages = &.{} }).validate(.{}));
    try t.expectError(error.InvalidGrpcRequest, (Request{ .method = "/test.Service/Method\r\n", .shape = .bidi, .messages = &.{} }).validate(.{}));
    try t.expectError(error.GrpcBudgetExceeded, (Request{ .method = "/test.Service/Method", .shape = .bidi, .messages = &.{"one"} }).validate(.{ .request_bytes = 7 }));
}

test {
    _ = Descriptor;
    _ = Server;
}
