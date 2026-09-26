//! One bounded HTTP/1.1 exchange. Only a trusted, freshly authorized executor
//! calls this module. Replay never calls it. There are no retries or redirects.
const std = @import("std");
const http = @import("root.zig");
pub const segment_bytes = 4096;
pub const Endpoint = struct {
    host: []const u8,
    /// An explicitly provisioned numeric IPv4 address. No ambient DNS/proxy is
    /// consulted; TLS still authenticates `host` and sends its SNI.
    address: []const u8,
    port: u16,
    tls: bool,
    ca_file: ?[]const u8 = null,
    timeout_ms: u32 = 10000,
    request_bytes: u64 = 65536,
    response_bytes: u64 = 65536,
    response_headers: []const []const u8 = &.{ "content-type", "content-length", "transfer-encoding", "trailer" },
    pub fn validate(self: Endpoint) !void {
        _ = try std.Io.net.HostName.init(self.host);
        _ = try std.Io.net.Ip4Address.parse(self.address, self.port);
        if (self.port == 0 or self.timeout_ms == 0 or self.timeout_ms > 300000 or self.response_headers.len > http.Request.maximum_headers) return error.InvalidHttpEndpoint;
        for (self.response_headers) |name| try http.validateHeader(name, "");
    }
};
pub const Capture = struct {
    context: *anyopaque,
    /// Return only after the bytes are durably sealed. A failed capture aborts
    /// transport; no completion is inferred and the remote outcome may be unknown.
    segment: *const fn (*anyopaque, http.Kind, []const u8) anyerror!void,
};
pub const Result = struct { status: u16, bytes: u64, omitted_headers: u32 };
fn secretHeader(name: []const u8) bool {
    for ([_][]const u8{ "set-cookie", "authorization", "proxy-authorization", "www-authenticate", "proxy-authenticate" }) |field| if (std.ascii.eqlIgnoreCase(name, field)) return true;
    return false;
}
/// Keep approved lines byte-exact and mark omissions at their original position.
pub fn captureHeaders(endpoint: Endpoint, bytes: []const u8, trailers: bool, buffer: []u8) !struct { bytes: []const u8, omitted: u32 } {
    var out: std.Io.Writer = .fixed(buffer);
    var lines = std.mem.splitSequence(u8, bytes, "\r\n");
    var omissions: u32 = 0;
    var count: usize = 0;
    if (!trailers) {
        try out.writeAll(lines.next() orelse return error.InvalidHttpFraming);
        try out.writeAll("\r\n");
    }
    while (lines.next()) |line| {
        if (line.len == 0) break;
        count += 1;
        if (count > http.Request.maximum_headers) return error.HttpHeadersOversize;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse return error.InvalidHttpHeader;
        const name = line[0..colon];
        try http.validateHeader(name, line[colon + 1 ..]);
        if (trailers and (std.ascii.eqlIgnoreCase(name, "content-length") or std.ascii.eqlIgnoreCase(name, "transfer-encoding") or std.ascii.eqlIgnoreCase(name, "trailer"))) return error.InvalidHttpFraming;
        var allowed = false;
        for (endpoint.response_headers) |candidate| if (std.ascii.eqlIgnoreCase(name, candidate)) {
            allowed = true;
            break;
        };
        if (allowed and !secretHeader(name)) try out.writeAll(line) else {
            try out.print("{s}: {{{{omitted}}}}", .{name});
            omissions += 1;
        }
        try out.writeAll("\r\n");
    }
    try out.writeAll("\r\n");
    return .{ .bytes = out.buffered(), .omitted = omissions };
}
fn emit(capture: Capture, kind: http.Kind, bytes: []const u8) !void {
    if (bytes.len == 0) return capture.segment(capture.context, kind, "");
    var offset: usize = 0;
    while (offset < bytes.len) {
        const end = offset + @min(segment_bytes, bytes.len - offset);
        try capture.segment(capture.context, kind, bytes[offset..end]);
        offset = end;
    }
}
fn run(gpa: std.mem.Allocator, io: std.Io, endpoint: Endpoint, request: http.Request, body: *std.Io.Reader, secrets: ?http.Request.Resolver, capture: Capture) !Result {
    const started = std.Io.Clock.awake.now(io);
    const started_ms: u64 = @intCast(std.Io.Clock.real.now(io).toMilliseconds());
    try endpoint.validate();
    if (request.body_bytes > endpoint.request_bytes) return error.HttpRequestTooLarge;
    var head_buffer: [http.Request.maximum_head_bytes]u8 = undefined;
    // This rendering buffer contains resolved secrets and is never captured.
    defer std.crypto.secureZero(u8, &head_buffer);
    const head = try request.render(endpoint.host, endpoint.port, &head_buffer, secrets, false);
    // A missing resolver must not send placeholder text as a real credential.
    for (request.headers) |field| for (field.value) |piece| if (piece == .secret and secrets == null) return error.MissingHttpCredential;
    var client: std.http.Client = .{ .allocator = gpa, .io = io, .read_buffer_size = http.Request.maximum_head_bytes, .write_buffer_size = segment_bytes };
    defer client.deinit();
    if (endpoint.tls) {
        const now = std.Io.Clock.real.now(io);
        client.now = now;
        if (endpoint.ca_file) |path| try client.ca_bundle.addCertsFromFilePath(gpa, io, now, std.Io.Dir.cwd(), path) else try client.ca_bundle.rescan(gpa, io, now);
    }
    // Numeric dial target and authenticated virtual host are deliberately separate.
    const connection = try client.connectTcpOptions(.{ .host = try std.Io.net.HostName.init(endpoint.address), .port = endpoint.port, .protocol = if (endpoint.tls) .tls else .plain, .proxied_host = try std.Io.net.HostName.init(endpoint.host), .proxied_port = endpoint.port });
    connection.closing = true;
    defer client.connection_pool.release(connection, io);
    const writer = connection.writer();
    try writer.writeAll(head);
    var buffer: [segment_bytes]u8 = undefined;
    var remaining = request.body_bytes;
    while (remaining != 0) {
        const count: usize = @intCast(@min(remaining, buffer.len));
        try body.readSliceAll(buffer[0..count]);
        try writer.writeAll(buffer[0..count]);
        remaining -= count;
    }
    try connection.flush();
    var reader: std.http.Reader = .{ .in = connection.reader(), .interface = undefined, .state = .ready, .max_head_len = http.Request.maximum_head_bytes };
    var interim: u8 = 0;
    var omitted: u32 = 0;
    const response = while (true) {
        const bytes = try reader.receiveHead();
        const parsed = try http.validateResponse(bytes);
        if (parsed.status.class() != .informational) break parsed;
        if (parsed.status == .switching_protocols or interim == 4) return error.UnsupportedHttpResponse;
        interim += 1;
        // Preserve informational evidence under the same bounded header policy.
        const safe = try captureHeaders(endpoint, bytes, false, &head_buffer);
        omitted += safe.omitted;
        try emit(capture, .response_head, safe.bytes);
    };
    const status: u16 = @intCast(@backingInt(response.status));
    const no_body = request.method == .HEAD or status == 204 or status == 304;
    if (!no_body and response.content_length != null and response.content_length.? > endpoint.response_bytes) return error.HttpResponseTooLarge;
    // The pinned TLS HTTP stack permits close-notify omission only when HTTP
    // framing detects truncation. Reject close-delimited TLS bodies accordingly.
    if (!no_body and endpoint.tls and response.content_length == null and response.transfer_encoding == .none) return error.UnframedTlsResponse;
    const safe = try captureHeaders(endpoint, response.bytes, false, &head_buffer);
    omitted += safe.omitted;
    try emit(capture, .response_head, safe.bytes);
    var total: u64 = 0;
    if (!no_body) {
        const stream = reader.bodyReader(&.{}, response.transfer_encoding, response.content_length);
        while (true) {
            const count = try stream.readSliceShort(&buffer);
            if (count > endpoint.response_bytes - total) return error.HttpResponseTooLarge;
            if (count != 0) try emit(capture, .response_body, buffer[0..count]);
            total += count;
            if (count < buffer.len) break;
        }
        if (response.content_length) |length| if (total != length) return error.IncompleteHttpBody;
    }
    if (total == 0) try emit(capture, .response_body, "");
    if (reader.trailers.len != 0) {
        const trailers = try captureHeaders(endpoint, reader.trailers, true, &head_buffer);
        omitted += trailers.omitted;
        try emit(capture, .response_trailers, trailers.bytes);
    }
    const timing = try http.exchange.codec.encode(http.Timing{ .started_ms = started_ms, .elapsed_ns = @intCast(started.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds()) });
    try emit(capture, .timing, timing.slice());
    var secret_count: u32 = 0;
    for (request.headers) |field| for (field.value) |piece| if (piece == .secret) {
        secret_count += 1;
    };
    const omissions = try http.exchange.codec.encode(http.Omission{ .response_headers = omitted, .request_secrets = secret_count });
    try emit(capture, .omission, omissions.slice());
    const completion = try http.exchange.codec.encode(http.Completion{ .status = status, .request_bytes = request.body_bytes, .response_bytes = total, .heads = interim + 1, .framing = if (no_body) .none else if (response.transfer_encoding != .none) .chunked else if (response.content_length != null) .length else .close });
    try emit(capture, .completion, completion.slice());
    return .{ .status = status, .bytes = total, .omitted_headers = omitted };
}
fn timeout(io: std.Io, milliseconds: u32) !void {
    try io.sleep(.fromMilliseconds(milliseconds), .awake);
}
/// Errors after authorization are uncertain remote outcomes, including capture
/// failure and timeout. They never authorize an automatic external retry.
pub fn execute(gpa: std.mem.Allocator, io: std.Io, endpoint: Endpoint, request: http.Request, body: *std.Io.Reader, secrets: ?http.Request.Resolver, capture: Capture) !Result {
    try endpoint.validate();
    const Choice = union(enum) { response: anyerror!Result, timeout: anyerror!void };
    var choices: [2]Choice = undefined;
    var select: std.Io.Select(Choice) = .init(io, &choices);
    defer select.cancelDiscard();
    try select.concurrent(.timeout, timeout, .{ io, endpoint.timeout_ms });
    try select.concurrent(.response, run, .{ gpa, io, endpoint, request, body, secrets, capture });
    return switch (try select.await()) {
        .response => |value| value,
        .timeout => error.HttpOutcomeUnknown,
    };
}
