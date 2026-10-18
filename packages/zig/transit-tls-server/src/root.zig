//! Server-side TLS over bounded Zig I/O. OpenSSL owns cryptography; callers own
//! socket lifetime, protocol negotiation, authentication and current authority.
const std = @import("std");
const c = @import("OpenSsl.zig");
pub const LocalTrust = @import("LocalTrust.zig");
test {
    _ = LocalTrust;
}
pub const max_record_bytes = 18432;
pub const max_handshake_bytes = 65536;
pub const Context = struct {
    raw: *c.SSL_CTX,
    /// PEM paths are explicit private configuration. Contexts are immutable
    /// after construction; rotation constructs a replacement for new sessions.
    pub fn init(certificate: [:0]const u8, key: [:0]const u8) !Context {
        if (c.OpenSSL_version_num() != 0x30600040) return error.UnsupportedTlsLibrary;
        const raw = c.SSL_CTX_new(c.TLS_server_method()) orelse return error.TlsAllocationFailed;
        errdefer c.SSL_CTX_free(raw);
        if (c.SSL_CTX_ctrl(raw, c.SSL_CTRL_SET_MIN_PROTO_VERSION, c.TLS1_2_VERSION, null) != 1 or
            c.SSL_CTX_ctrl(raw, c.SSL_CTRL_SET_MAX_PROTO_VERSION, c.TLS1_3_VERSION, null) != 1) return error.TlsConfiguration;
        _ = c.SSL_CTX_set_options(raw, c.SSL_OP_NO_COMPRESSION | c.SSL_OP_NO_RENEGOTIATION);
        _ = c.SSL_CTX_ctrl(raw, c.SSL_CTRL_SET_SESS_CACHE_MODE, c.SSL_SESS_CACHE_OFF, null);
        if (c.SSL_CTX_set_num_tickets(raw, 0) != 1) return error.TlsConfiguration;
        if (c.SSL_CTX_use_certificate_chain_file(raw, certificate.ptr) != 1 or
            c.SSL_CTX_use_PrivateKey_file(raw, key.ptr, c.SSL_FILETYPE_PEM) != 1 or
            c.SSL_CTX_check_private_key(raw) != 1) return error.InvalidTlsCredentials;
        const leaf = c.SSL_CTX_get0_certificate(raw) orelse return error.InvalidTlsCredentials;
        if (c.X509_cmp_current_time(c.X509_getm_notBefore(leaf)) >= 0 or c.X509_cmp_current_time(c.X509_getm_notAfter(leaf)) <= 0) return error.InvalidTlsCredentials;
        return .{ .raw = raw };
    }
    pub fn deinit(self: *Context) void {
        c.SSL_CTX_free(self.raw);
        self.* = undefined;
    }
    /// Verify the advertised local CA and both supported loopback identities.
    /// This does not configure client-certificate authentication.
    pub fn verifyLocalTrust(self: *const Context, ca_file: [:0]const u8) !void {
        const leaf = c.SSL_CTX_get0_certificate(self.raw) orelse return error.InvalidTlsCredentials;
        const store = c.X509_STORE_new() orelse return error.TlsAllocationFailed;
        defer c.X509_STORE_free(store);
        if (c.X509_STORE_load_file(store, ca_file.ptr) != 1) return error.InvalidTlsTrust;
        const verification = c.X509_STORE_CTX_new() orelse return error.TlsAllocationFailed;
        defer c.X509_STORE_CTX_free(verification);
        var chain: ?*c.STACK_X509 = null;
        if (c.SSL_CTX_ctrl(self.raw, c.SSL_CTRL_GET_CHAIN_CERTS, 0, @ptrCast(&chain)) != 1 or
            c.X509_STORE_CTX_init(verification, store, leaf, chain) != 1 or
            c.X509_STORE_CTX_set_purpose(verification, c.X509_PURPOSE_SSL_SERVER) != 1 or
            c.X509_verify_cert(verification) != 1 or
            c.X509_check_host(leaf, "localhost", 9, c.X509_CHECK_FLAG_NEVER_CHECK_SUBJECT, null) != 1 or
            c.X509_check_ip_asc(leaf, "127.0.0.1", 0) != 1) return error.InvalidTlsTrust;
    }
};

/// Absolute per-operation deadlines bound partial framing and slow peers.
/// No socket is handed to OpenSSL, so its BIO never bypasses Zig cancellation.
pub const Transport = struct {
    io: std.Io,
    stream: std.Io.net.Stream,
    deadline: std.Io.Timeout,
    pub fn resetDeadline(self: *Transport, milliseconds: u32) !void {
        if (milliseconds == 0 or milliseconds > 300000) return error.InvalidTimeout;
        self.deadline = (std.Io.Timeout{ .duration = .{ .clock = .awake, .raw = .fromMilliseconds(milliseconds) } }).toDeadline(self.io);
    }
    pub fn read(self: *Transport, bytes: []u8) !usize {
        var vectors = [_][]u8{bytes};
        return (try self.io.operateTimeout(.{ .net_read = .{ .socket_handle = self.stream.socket.handle, .data = &vectors } }, self.deadline)).net_read;
    }
    pub fn readExact(self: *Transport, bytes: []u8) !void {
        var offset: usize = 0;
        while (offset < bytes.len) {
            const count = try self.read(bytes[offset..]);
            if (count == 0) return error.EndOfStream;
            offset += count;
        }
    }
    pub fn writeAll(self: *Transport, bytes: []const u8) !void {
        var offset: usize = 0;
        while (offset < bytes.len) {
            const vectors = [_][]const u8{bytes[offset..]};
            const count = try (try self.io.operateTimeout(.{ .net_write = .{ .socket_handle = self.stream.socket.handle, .header = &.{}, .data = &vectors, .splat = 1 } }, self.deadline)).net_write;
            if (count == 0) return error.EndOfStream;
            offset += count;
        }
    }
};
pub const Session = struct {
    raw: *c.SSL,
    input: *c.BIO,
    output: *c.BIO,
    transport: *Transport,
    closed: bool = false,
    pub fn accept(context: *const Context, transport: *Transport) !Session {
        const raw = c.SSL_new(context.raw) orelse return error.TlsAllocationFailed;
        errdefer c.SSL_free(raw);
        const input = c.BIO_new(c.BIO_s_mem()) orelse return error.TlsAllocationFailed;
        const output = c.BIO_new(c.BIO_s_mem()) orelse {
            _ = c.BIO_free(input);
            return error.TlsAllocationFailed;
        };
        c.SSL_set_bio(raw, input, output); // Ownership transfers to SSL.
        c.SSL_set_accept_state(raw);
        var self: Session = .{ .raw = raw, .input = input, .output = output, .transport = transport };
        var received: usize = 0;
        while (true) {
            c.ERR_clear_error();
            const result = c.SSL_accept(raw);
            const failure = if (result == 1) 0 else c.SSL_get_error(raw, result);
            try self.flush();
            if (result == 1) return self;
            if (failure != c.SSL_ERROR_WANT_READ) return error.TlsHandshakeFailed;
            received += try self.feed();
            if (received > max_handshake_bytes) return error.TlsHandshakeTooLarge;
        }
    }
    fn feed(self: *Session) !usize {
        var buffer: [max_record_bytes]u8 = undefined;
        const count = try self.transport.read(&buffer);
        if (count == 0) return error.TruncatedTlsStream;
        if (c.BIO_write(self.input, &buffer, @intCast(count)) != count) return error.TlsIoFailed;
        return count;
    }
    fn flush(self: *Session) !void {
        var buffer: [max_record_bytes]u8 = undefined;
        while (c.BIO_ctrl_pending(self.output) != 0) {
            const count = c.BIO_read(self.output, &buffer, buffer.len);
            if (count <= 0) return error.TlsIoFailed;
            try self.transport.writeAll(buffer[0..@intCast(count)]);
        }
    }
    pub fn read(self: *Session, bytes: []u8) !usize {
        if (bytes.len == 0 or self.closed) return 0;
        var received: usize = 0;
        while (true) {
            c.ERR_clear_error();
            const count = c.SSL_read(self.raw, bytes.ptr, @intCast(@min(bytes.len, 16384)));
            const failure = if (count > 0) 0 else c.SSL_get_error(self.raw, count);
            try self.flush();
            if (count > 0) return @intCast(count);
            if (failure == c.SSL_ERROR_ZERO_RETURN) {
                self.closed = true;
                return 0;
            }
            if (failure != c.SSL_ERROR_WANT_READ) return error.TlsIoFailed;
            received += try self.feed();
            if (received > max_handshake_bytes) return error.TlsControlBudget;
        }
    }
    pub fn readExact(self: *Session, bytes: []u8) !void {
        var offset: usize = 0;
        while (offset < bytes.len) {
            const count = try self.read(bytes[offset..]);
            if (count == 0) return error.EndOfStream;
            offset += count;
        }
    }
    pub fn writeAll(self: *Session, bytes: []const u8) !void {
        if (self.closed) return error.EndOfStream;
        var offset: usize = 0;
        var received: usize = 0;
        while (offset < bytes.len) {
            c.ERR_clear_error();
            const count = c.SSL_write(self.raw, bytes[offset..].ptr, @intCast(@min(bytes.len - offset, 16384)));
            const failure = if (count > 0) 0 else c.SSL_get_error(self.raw, count);
            try self.flush();
            if (count > 0) {
                offset += @intCast(count);
            } else if (failure == c.SSL_ERROR_WANT_READ) {
                received += try self.feed();
                if (received > max_handshake_bytes) return error.TlsControlBudget;
            } else return error.TlsIoFailed;
        }
    }
    /// Sends close_notify without waiting for the peer. The caller always owns
    /// socket shutdown/close and may abandon this on an expired deadline.
    pub fn finish(self: *Session) !void {
        c.ERR_clear_error();
        _ = c.SSL_shutdown(self.raw);
        try self.flush();
        self.closed = true;
    }
    pub fn deinit(self: *Session) void {
        c.SSL_free(self.raw);
        self.* = undefined;
    }
};

test "pinned OpenSSL server API rejects missing credential files" {
    try std.testing.expectEqual(@as(c_ulong, 0x30600040), c.OpenSSL_version_num());
    try std.testing.expectError(error.InvalidTlsCredentials, Context.init("/nonexistent/transit-certificate.pem", "/nonexistent/transit-key.pem"));
}
