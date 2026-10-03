//! One bounded HTTP/1.1 exchange. Only a trusted, freshly authorized executor
//! calls this module. Replay never calls it. There are no retries or redirects.
const std = @import("std");
const http = @import("root.zig");
const tls = @import("transit_tls");
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
// The std I/O interfaces deliberately return wrapper errors. Unwrap only
// their own populated cause slots; never substitute a later request or capture
// failure, and never log response bytes or TLS material for explanation.
fn readCause(err: anyerror, raw: *const std.Io.net.Stream.Reader, secure: ?*const tls.Client) anyerror {
    if (err != error.ReadFailed) return err;
    if (secure) |client| if (client.read_err) |cause| return cause;
    return raw.err orelse err;
}
fn writeCause(err: anyerror, raw: *const std.Io.net.Stream.Writer) anyerror {
    return if (err == error.WriteFailed) raw.err orelse err else err;
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
    var trust: std.crypto.Certificate.Bundle = .empty;
    defer trust.deinit(gpa);
    const now = std.Io.Clock.real.now(io);
    if (endpoint.tls) {
        if (endpoint.ca_file) |path| try trust.addCertsFromFilePath(gpa, io, now, std.Io.Dir.cwd(), path) else try trust.rescan(gpa, io, now);
    }
    // Numeric dial target and authenticated virtual host are deliberately separate.
    const address = try std.Io.net.IpAddress.parseIp4(endpoint.address, endpoint.port);
    const connection = try address.connect(io, .{ .mode = .stream });
    defer connection.close(io);
    var input_buffer: [tls.Client.min_buffer_len]u8 = undefined;
    var output_buffer: [tls.Client.min_buffer_len]u8 = undefined;
    var tls_input: [tls.Client.min_buffer_len]u8 = undefined;
    var tls_output: [tls.Client.min_buffer_len]u8 = undefined;
    defer std.crypto.secureZero(u8, &output_buffer);
    defer std.crypto.secureZero(u8, &tls_output);
    var raw_reader = connection.reader(io, &input_buffer);
    var raw_writer = connection.writer(io, &output_buffer);
    var secure: tls.Client = undefined;
    var lock: std.Io.RwLock = .init;
    if (endpoint.tls) {
        var entropy: [tls.Client.Options.entropy_len]u8 = undefined;
        defer std.crypto.secureZero(u8, &entropy);
        try io.randomSecure(&entropy);
        secure = tls.Client.init(&raw_reader.interface, &raw_writer.interface, .{
            .host = .{ .explicit = endpoint.host },
            .ca = .{ .bundle = .{ .gpa = gpa, .io = io, .lock = &lock, .bundle = &trust } },
            .read_buffer = &tls_input,
            .write_buffer = &tls_output,
            .entropy = &entropy,
            .realtime_now = now,
        }) catch |err| return writeCause(readCause(err, &raw_reader, null), &raw_writer);
    }
    defer if (endpoint.tls) std.crypto.secureZero(u8, std.mem.asBytes(&secure));
    const writer = if (endpoint.tls) &secure.writer else &raw_writer.interface;
    writer.writeAll(head) catch |err| return writeCause(err, &raw_writer);
    var buffer: [segment_bytes]u8 = undefined;
    var remaining = request.body_bytes;
    while (remaining != 0) {
        const count: usize = @intCast(@min(remaining, buffer.len));
        body.readSliceAll(buffer[0..count]) catch |err| return switch (err) {
            error.EndOfStream => error.HttpRequestBodyTruncated,
            error.ReadFailed => error.HttpRequestBodyReadFailed,
        };
        writer.writeAll(buffer[0..count]) catch |err| return writeCause(err, &raw_writer);
        remaining -= count;
    }
    writer.flush() catch |err| return writeCause(err, &raw_writer);
    if (endpoint.tls) raw_writer.interface.flush() catch |err| return writeCause(err, &raw_writer);
    var reader: std.http.Reader = .{ .in = if (endpoint.tls) &secure.reader else &raw_reader.interface, .interface = undefined, .state = .ready, .max_head_len = http.Request.maximum_head_bytes };
    var interim: u8 = 0;
    var omitted: u32 = 0;
    const response = while (true) {
        const bytes = reader.receiveHead() catch |err| return switch (err) {
            error.HttpRequestTruncated => error.HttpResponseHeadTruncated,
            error.HttpConnectionClosing => error.HttpResponseMissing,
            else => readCause(err, &raw_reader, if (endpoint.tls) &secure else null),
        };
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
            const count = stream.readSliceShort(&buffer) catch |err| return if (err == error.ReadFailed and reader.body_err != null) reader.body_err.? else readCause(err, &raw_reader, if (endpoint.tls) &secure else null);
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
