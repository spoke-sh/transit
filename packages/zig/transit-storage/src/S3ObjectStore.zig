//! Real, bounded S3 HTTP/TLS operations. Local WAL acceptance and upload policy
//! belong to the native backend; this adapter never substitutes memory storage.
const std = @import("std");
const protocol = @import("transit_protocol");
const object = @import("TransitObjectStore.zig");
const signing = @import("S3Signing.zig");
pub const Credentials = signing.Credentials;
pub const signAwsV4Request = signing.signAwsV4Request;
pub const SignedHeaders = signing.SignedHeaders;

pub const chunk_bytes = 64 * 1024;
const header_bytes = 512;
const max_checks = object.max_object_bytes / chunk_bytes * 32;
const max_envelope = header_bytes + max_checks + object.max_object_bytes;
const Kind = enum(u8) { immutable = 1, conditional = 2, retired = 3 };

pub const Options = struct {
    endpoint: []const u8,
    region: []const u8,
    bucket: []const u8,
    prefix: []const u8,
    /// JSON file reopened for each request, including after credential rotation.
    /// Only its path is installation configuration; secret values are ephemeral.
    credentials_file: []const u8,
    ca_file: ?[]const u8 = null,
    request_timeout_ms: u32 = 10000,
    allow_loopback_http: bool = false,

    pub fn validate(self: Options) !void {
        try (protocol.Storage.ObjectStorage{ .endpoint = self.endpoint, .region = self.region, .bucket = self.bucket, .prefix = self.prefix, .credentials_file = self.credentials_file, .ca_file = self.ca_file, .request_timeout_ms = self.request_timeout_ms, .allow_loopback_http = self.allow_loopback_http }).validate();
    }
};

fn digest(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}
fn definition() [32]u8 {
    var result: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&result, @tagName(protocol.Growth.current_definition)) catch unreachable;
    return result;
}
fn checksSize(size: u64) usize {
    return @intCast((size + chunk_bytes - 1) / chunk_bytes * 32);
}
fn encode(key: []const u8, kind: Kind, bytes: []const u8, out: []u8) []const u8 {
    const checks_len = checksSize(bytes.len);
    const header = out[0..header_bytes];
    @memset(header, 0);
    header[0..8].* = "TS3O\x01\x00\x00\x00".*;
    header[8..40].* = definition();
    header[40] = @backingInt(kind);
    std.mem.writeInt(u16, header[41..43], @intCast(key.len), .little);
    std.mem.writeInt(u64, header[48..56], bytes.len, .little);
    header[56..88].* = digest(bytes);
    const checks = out[header_bytes..][0..checks_len];
    var offset: usize = 0;
    while (offset < bytes.len) : (offset += chunk_bytes) {
        checks[offset / chunk_bytes * 32 ..][0..32].* = digest(bytes[offset..@min(bytes.len, offset + chunk_bytes)]);
    }
    header[88..120].* = digest(checks);
    @memcpy(header[120..][0..key.len], key);
    header[480..512].* = digest(header[0..480]);
    @memcpy(out[header_bytes + checks_len ..][0..bytes.len], bytes);
    return out[0 .. header_bytes + checks_len + bytes.len];
}
const Descriptor = struct {
    kind: Kind,
    meta: object.ObjectMeta,
    checks: [max_checks]u8,
    etag: [256]u8,
    etag_len: usize,

    fn tag(self: *const Descriptor) []const u8 {
        return self.etag[0..self.etag_len];
    }
};
fn decode(key: []const u8, bytes: []const u8, total: u64, response: Response) !Descriptor {
    if (bytes.len < header_bytes) return error.CorruptObjectDescriptor;
    const header = bytes[0..header_bytes];
    if (!std.mem.eql(u8, header[8..40], &definition())) return error.IncompatibleDefinition;
    if (!std.mem.eql(u8, header[0..8], "TS3O\x01\x00\x00\x00") or !std.mem.eql(u8, header[480..512], &digest(header[0..480]))) return error.CorruptObjectDescriptor;
    const kind = std.enums.fromInt(Kind, header[40]) orelse return error.CorruptObjectDescriptor;
    const key_len = std.mem.readInt(u16, header[41..43], .little);
    if (key_len != key.len or !std.mem.eql(u8, header[120..][0..key_len], key)) return error.ObjectKeyConflict;
    for (header[43..48]) |c| if (c != 0) return error.CorruptObjectDescriptor;
    for (header[120 + key_len .. 480]) |c| if (c != 0) return error.CorruptObjectDescriptor;
    const size = std.mem.readInt(u64, header[48..56], .little);
    if (size > object.max_object_bytes) return error.ObjectTooLarge;
    if (kind == .retired and (size != 0 or !std.mem.eql(u8, header[56..88], &digest("")))) return error.CorruptObjectDescriptor;
    const checks_len = checksSize(size);
    if (total != header_bytes + checks_len + size or bytes.len < header_bytes + checks_len) return error.ObjectSizeMismatch;
    const checks = bytes[header_bytes..][0..checks_len];
    if (!std.mem.eql(u8, header[88..120], &digest(checks))) return error.ObjectDigestMismatch;
    var result: Descriptor = .{ .kind = kind, .meta = .{ .size = size, .sha256 = header[56..88].* }, .checks = undefined, .etag = response.etag, .etag_len = response.etag_len };
    @memcpy(result.checks[0..checks_len], checks);
    return result;
}
const Response = struct {
    status: std.http.Status,
    length: u64,
    read: usize = 0,
    etag: [256]u8 = undefined,
    etag_len: usize = 0,
    range: [128]u8 = undefined,
    range_len: usize = 0,
};

pub const S3ObjectStore = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    options: Options,
    http: std.http.Client,
    mutex: std.Io.Mutex = .init,
    /// One reusable bounded transfer slab; retained data never grows residency.
    transfer: []u8,
    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: Options) !S3ObjectStore {
        return initWithAccess(allocator, io, options, false);
    }
    /// Bounded read clients own their HTTP/TLS state but need no PUT slab.
    pub fn initReadOnly(allocator: std.mem.Allocator, io: std.Io, options: Options) !S3ObjectStore {
        return initWithAccess(allocator, io, options, true);
    }
    fn initWithAccess(allocator: std.mem.Allocator, io: std.Io, options: Options, read_only: bool) !S3ObjectStore {
        try options.validate();
        var http: std.http.Client = .{ .allocator = allocator, .io = io };
        errdefer http.deinit();
        if (options.ca_file) |path| {
            const file = try std.Io.Dir.cwd().openFile(io, path, .{});
            defer file.close(io);
            if (try file.length(io) > 1024 * 1024) return error.CertificateAuthorityBundleTooBig;
            var reader = file.reader(io, &.{});
            const now = std.Io.Clock.real.now(io);
            try http.ca_bundle.addCertsFromFile(allocator, &reader, now.toSeconds());
            if (http.ca_bundle.map.count() == 0) return error.EmptyCertificateAuthorityBundle;
            http.now = now;
        }
        return .{ .allocator = allocator, .io = io, .options = options, .http = http, .transfer = try allocator.alloc(u8, if (read_only) 0 else max_envelope) };
    }
    pub fn deinit(self: *S3ObjectStore) void {
        self.http.deinit();
        self.allocator.free(self.transfer);
        self.* = undefined;
    }
    pub fn objectStore(self: *S3ObjectStore) object.ObjectStore {
        return .{ .context = self, .vtable = &.{ .putImmutable = putImmutable, .putConditional = putConditional, .getRange = getRange, .getObject = getObject, .head = head, .delete = delete } };
    }
    /// Permanently fence a generation's create-only PUTs while removing its
    /// payload. A raw DELETE cannot fence a timed-out request still in flight
    /// at the provider. Keep the empty retirement envelope at this key forever.
    /// This is physical lifecycle authority, separate from mutable manifests.
    pub fn retireImmutable(self: *S3ObjectStore, key: []const u8, expected: object.ObjectMeta) !void {
        try object.validateKey(key);
        if (self.transfer.len == 0) return error.ReadOnlyObjectStore;
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        for (0..3) |_| {
            const existing = self.descriptor(key) catch |err| switch (err) {
                error.ObjectChanged => continue,
                else => return err,
            };
            if (existing) |found| {
                if (found.kind == .retired) return;
                if (found.kind != .immutable or !std.meta.eql(found.meta, expected)) return error.ImmutableObjectConflict;
            }
            const condition: signing.Condition = if (existing) |*found| .{ .if_match = found.tag() } else .if_none_match;
            const encoded = encode(key, .retired, "", self.transfer);
            var response_bytes: [4096]u8 = undefined;
            const response = try self.request(.PUT, key, condition, null, encoded, &response_bytes);
            if (response.status == .precondition_failed) continue;
            try require(response.status);
            if (response.status != .ok) return error.InvalidObjectResponse;
            const verified = (try self.descriptor(key)) orelse return error.ObjectNotFound;
            if (verified.kind != .retired) return error.ImmutableObjectConflict;
            return;
        }
        return error.ObjectChanged;
    }
    fn request(self: *S3ObjectStore, method: std.http.Method, key: []const u8, condition: ?signing.Condition, range: ?signing.Range, body: []const u8, out: []u8) !Response {
        const Result = union(enum) { response: anyerror!Response, timeout: anyerror!void };
        var results: [2]Result = undefined;
        var selected: std.Io.Select(Result) = .init(self.io, &results);
        defer selected.cancelDiscard();
        try selected.concurrent(.timeout, sleep, .{ self.io, self.options.request_timeout_ms });
        try selected.concurrent(.response, exchange, .{ self, method, key, condition, range, body, out });
        return switch (try selected.await()) {
            .response => |response| try response,
            .timeout => |result| {
                try result;
                return error.ObjectRequestTimeout;
            },
        };
    }
    fn sleep(io: std.Io, ms: u32) !void {
        try io.sleep(.fromMilliseconds(ms), .awake);
    }
    fn exchange(self: *S3ObjectStore, method: std.http.Method, key: []const u8, condition: ?signing.Condition, range: ?signing.Range, payload: []const u8, out: []u8) !Response {
        const raw = try std.Io.Dir.cwd().readFileAlloc(self.io, self.options.credentials_file, self.allocator, .limited(16384));
        defer {
            std.crypto.secureZero(u8, raw);
            self.allocator.free(raw);
        }
        const Secrets = struct { access_key_id: []const u8, secret_access_key: []const u8, session_token: ?[]const u8 = null };
        const secrets = try std.json.parseFromSlice(Secrets, self.allocator, raw, .{ .allocate = .alloc_if_needed });
        defer secrets.deinit();
        defer {
            // Escaped JSON strings may live in the parser arena, independently
            // of raw. Wipe them before freeing either allocation owner.
            std.crypto.secureZero(u8, @constCast(secrets.value.secret_access_key));
            std.crypto.secureZero(u8, @constCast(secrets.value.access_key_id));
            if (secrets.value.session_token) |token| std.crypto.secureZero(u8, @constCast(token));
        }
        if (secrets.value.access_key_id.len == 0 or secrets.value.access_key_id.len > 128 or secrets.value.secret_access_key.len == 0 or secrets.value.secret_access_key.len > 100) return error.InvalidCredentials;
        for (secrets.value.access_key_id) |c| if (!std.ascii.isAlphanumeric(c) and c != '-') return error.InvalidCredentials;
        var key_buffer: [768]u8 = undefined;
        const remote_key = try std.fmt.bufPrint(&key_buffer, "{s}/{s}", .{ self.options.prefix, key });
        const endpoint = std.mem.trimEnd(u8, self.options.endpoint, "/");
        const host = endpoint[(std.mem.indexOf(u8, endpoint, "://") orelse return error.InvalidObjectEndpoint) + 3 ..];
        const clock = std.Io.Clock.real.now(self.io);
        if (self.http.now != null) self.http.now = clock;
        const timestamp = clock.toSeconds();
        if (timestamp < 0) return error.InvalidObjectClock;
        const epoch: std.time.epoch.EpochSeconds = .{ .secs = @intCast(timestamp) };
        const yd = epoch.getEpochDay().calculateYearDay();
        const md = yd.calculateMonthDay();
        const day = epoch.getDaySeconds();
        var date: [16]u8 = undefined;
        _ = try std.fmt.bufPrint(&date, "{d:0>4}{d:0>2}{d:0>2}T{d:0>2}{d:0>2}{d:0>2}Z", .{ yd.year, md.month.numeric(), md.day_index + 1, day.getHoursIntoDay(), day.getMinutesIntoHour(), day.getSecondsIntoMinute() });
        const signed = try signing.signAwsV4Request(.{ .access_key_id = secrets.value.access_key_id, .secret_access_key = secrets.value.secret_access_key, .session_token = secrets.value.session_token, .region = self.options.region }, @tagName(method), host, self.options.bucket, remote_key, date, payload, condition, range);
        var headers: [8]std.http.Header = undefined;
        headers[0] = .{ .name = "x-amz-date", .value = &signed.amz_date };
        headers[1] = .{ .name = "x-amz-content-sha256", .value = &signed.payload_sha256_hex };
        headers[2] = .{ .name = "Authorization", .value = signed.authorization() };
        var count: usize = 3;
        if (signed.if_none_match) |value| {
            headers[count] = .{ .name = "If-None-Match", .value = value };
            count += 1;
        }
        if (signed.ifMatchHeader()) |value| {
            headers[count] = .{ .name = "If-Match", .value = value };
            count += 1;
        }
        if (signed.rangeHeader()) |value| {
            headers[count] = .{ .name = "Range", .value = value };
            count += 1;
        }
        if (secrets.value.session_token) |value| {
            headers[count] = .{ .name = "x-amz-security-token", .value = value };
            count += 1;
        }
        var url_buffer: [2048]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buffer, "{s}/{s}/{s}", .{ endpoint, self.options.bucket, remote_key });
        var req = try self.http.request(method, try std.Uri.parse(url), .{ .extra_headers = headers[0..count], .redirect_behavior = .not_allowed, .keep_alive = false, .headers = .{ .accept_encoding = .{ .override = "identity" } } });
        defer req.deinit();
        if (method == .PUT) {
            req.transfer_encoding = .{ .content_length = payload.len };
            var body = try req.sendBodyUnflushed(&.{});
            try body.writer.writeAll(payload);
            try body.end();
            try req.connection.?.flush();
        } else try req.sendBodiless();
        var response = try req.receiveHead(&.{});
        var result: Response = .{ .status = response.head.status, .length = response.head.content_length orelse 0 };
        if (result.status != .ok and result.status != .partial_content and result.status != .no_content) return result;
        if (response.head.content_encoding != .identity) return error.InvalidObjectResponse;
        var it = response.head.iterateHeaders();
        while (it.next()) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "etag")) {
                if (result.etag_len != 0 or header.value.len > result.etag.len) return error.InvalidProviderETag;
                @memcpy(result.etag[0..header.value.len], header.value);
                result.etag_len = header.value.len;
            } else if (std.ascii.eqlIgnoreCase(header.name, "content-range")) {
                if (result.range_len != 0 or header.value.len > result.range.len) return error.InvalidObjectRange;
                @memcpy(result.range[0..header.value.len], header.value);
                result.range_len = header.value.len;
            }
        }
        if (method == .HEAD) {
            if (response.head.content_length == null) return error.InvalidObjectResponse;
            return result;
        }
        if (result.length > out.len) return error.ObjectResponseTooLarge;
        var writer: std.Io.Writer = .fixed(out);
        _ = response.reader(&.{}).streamRemaining(&writer) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr() orelse error.ReadFailed,
            else => return err,
        };
        if (req.reader.state != .ready and req.reader.state != .body_none) return error.EndOfStream;
        result.read = writer.buffered().len;
        if (response.head.content_length != null and result.read != result.length) return error.ObjectSizeMismatch;
        return result;
    }
    fn require(status: std.http.Status) !void {
        return switch (status) {
            .ok, .partial_content, .no_content => {},
            .not_found => error.ObjectNotFound,
            .unauthorized, .forbidden => error.ObjectAccessDenied,
            .precondition_failed => error.ObjectChanged,
            .conflict => error.ObjectConditionalConflict,
            .too_many_requests, .service_unavailable => error.ObjectThrottled,
            else => error.ObjectProviderFailure,
        };
    }
    fn readRange(self: *S3ObjectStore, key: []const u8, etag: []const u8, total: u64, offset: u64, out: []u8) !void {
        if (out.len == 0) return;
        const response = try self.request(.GET, key, .{ .if_match = etag }, .{ .offset = offset, .len = @intCast(out.len) }, "", out);
        try require(response.status);
        if (response.status != .partial_content or response.read != out.len or response.length != out.len) return error.InvalidObjectRange;
        var expected: [128]u8 = undefined;
        const text = try std.fmt.bufPrint(&expected, "bytes {d}-{d}/{d}", .{ offset, offset + out.len - 1, total });
        if (!std.mem.eql(u8, response.range[0..response.range_len], text) or !std.mem.eql(u8, response.etag[0..response.etag_len], etag)) return error.InvalidObjectRange;
    }
    fn descriptor(self: *S3ObjectStore, key: []const u8) !?Descriptor {
        const response = try self.request(.HEAD, key, null, null, "", &.{});
        if (response.status == .not_found) return null;
        try require(response.status);
        if (response.status != .ok or response.length < header_bytes or response.length > max_envelope or response.etag_len == 0) return error.InvalidObjectResponse;
        var raw: [header_bytes + max_checks]u8 = undefined;
        const bytes = raw[0..@min(response.length, raw.len)];
        try self.readRange(key, response.etag[0..response.etag_len], response.length, 0, bytes);
        return try decode(key, bytes, response.length, response);
    }
    fn putImmutable(ctx: *anyopaque, key: []const u8, bytes: []const u8, expected: [32]u8) !object.ObjectMeta {
        const self: *S3ObjectStore = @ptrCast(@alignCast(ctx));
        if (self.transfer.len == 0) return error.ReadOnlyObjectStore;
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        const encoded = encode(key, .immutable, bytes, self.transfer);
        var response_bytes: [4096]u8 = undefined;
        const response = try self.request(.PUT, key, .if_none_match, null, encoded, &response_bytes);
        if (response.status == .precondition_failed) {
            const existing = (try self.descriptor(key)) orelse return error.ObjectChanged;
            if (existing.kind != .immutable or existing.meta.size != bytes.len or !std.mem.eql(u8, &existing.meta.sha256, &expected)) return error.ImmutableObjectConflict;
            try self.readPayload(key, &existing, 0, self.transfer[0..bytes.len]);
        } else {
            try require(response.status);
            if (response.status != .ok) return error.InvalidObjectResponse;
        }
        return .{ .size = bytes.len, .sha256 = expected };
    }
    fn putConditional(ctx: *anyopaque, key: []const u8, condition: object.Condition, bytes: []const u8) !bool {
        const self: *S3ObjectStore = @ptrCast(@alignCast(ctx));
        if (self.transfer.len == 0) return error.ReadOnlyObjectStore;
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        var existing: Descriptor = undefined;
        const provider: signing.Condition = switch (condition) {
            .if_none_match => .if_none_match,
            .if_match => |hash| blk: {
                existing = (self.descriptor(key) catch |err| switch (err) {
                    // A competing writer changed the ETag between HEAD and
                    // descriptor GET. The requested original comparison lost;
                    // no mutation was sent and no transport failure is hidden.
                    error.ObjectChanged => return false,
                    else => return err,
                }) orelse return false;
                if (existing.kind != .conditional) return error.ImmutableObjectConflict;
                if (!std.mem.eql(u8, &existing.meta.sha256, &hash)) return false;
                break :blk .{ .if_match = existing.tag() };
            },
        };
        const encoded = encode(key, .conditional, bytes, self.transfer);
        var response_bytes: [4096]u8 = undefined;
        const response = try self.request(.PUT, key, provider, null, encoded, &response_bytes);
        if (response.status == .precondition_failed) {
            if (self.descriptor(key) catch |err| switch (err) {
                error.ObjectChanged => return false,
                else => return err,
            }) |found| if (found.kind == .immutable) return error.ImmutableObjectConflict;
            return false;
        }
        try require(response.status);
        if (response.status != .ok) return error.InvalidObjectResponse;
        return true;
    }
    fn readPayload(self: *S3ObjectStore, key: []const u8, desc: *const Descriptor, offset: u64, out: []u8) !void {
        if (offset > desc.meta.size or out.len > desc.meta.size - offset) return error.InvalidObjectRange;
        if (out.len == 0) {
            if (desc.meta.size == 0 and !std.mem.eql(u8, &desc.meta.sha256, &digest(""))) return error.ObjectDigestMismatch;
            return;
        }
        const end = offset + out.len;
        const base = header_bytes + checksSize(desc.meta.size);
        const total = base + desc.meta.size;
        var raw: [chunk_bytes]u8 = undefined;
        var start = offset / chunk_bytes * chunk_bytes;
        while (start < end) : (start += chunk_bytes) {
            const chunk = raw[0..@min(chunk_bytes, desc.meta.size - start)];
            try self.readRange(key, desc.tag(), total, base + start, chunk);
            if (!std.mem.eql(u8, desc.checks[start / chunk_bytes * 32 ..][0..32], &digest(chunk))) return error.ObjectDigestMismatch;
            const from = @max(start, offset);
            const to = @min(start + chunk.len, end);
            @memcpy(out[from - offset ..][0 .. to - from], chunk[from - start ..][0 .. to - from]);
        }
        if (offset == 0 and out.len == desc.meta.size and !std.mem.eql(u8, &desc.meta.sha256, &digest(out))) return error.ObjectDigestMismatch;
    }
    fn getRange(ctx: *anyopaque, key: []const u8, offset: u64, length: u32, out: []u8) ![]const u8 {
        const self: *S3ObjectStore = @ptrCast(@alignCast(ctx));
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        const desc = (try self.descriptor(key)) orelse return error.ObjectNotFound;
        if (desc.kind == .retired) return error.ObjectNotFound;
        if (offset > desc.meta.size) return error.RangeOutOfBounds;
        const wanted: usize = @intCast(@min(length, desc.meta.size - offset));
        try self.readPayload(key, &desc, offset, out[0..wanted]);
        return out[0..wanted];
    }
    fn getObject(ctx: *anyopaque, key: []const u8, out: []u8) !?object.ObjectMeta {
        const self: *S3ObjectStore = @ptrCast(@alignCast(ctx));
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        const desc = (try self.descriptor(key)) orelse return null;
        if (desc.kind == .retired) return null;
        if (desc.meta.size > out.len) return error.BufferTooSmall;
        try self.readPayload(key, &desc, 0, out[0..@intCast(desc.meta.size)]);
        return desc.meta;
    }
    fn head(ctx: *anyopaque, key: []const u8) !?object.ObjectMeta {
        const self: *S3ObjectStore = @ptrCast(@alignCast(ctx));
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        return if (try self.descriptor(key)) |value| if (value.kind == .retired) null else value.meta else null;
    }
    fn delete(ctx: *anyopaque, key: []const u8) !void {
        const self: *S3ObjectStore = @ptrCast(@alignCast(ctx));
        if (self.transfer.len == 0) return error.ReadOnlyObjectStore;
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        var bytes: [4096]u8 = undefined;
        const response = try self.request(.DELETE, key, null, null, "", &bytes);
        try require(response.status);
        if (response.status != .no_content) return error.InvalidObjectResponse;
    }
};

test "S3 envelopes bind keys, definitions, descriptors and chunk digests" {
    var bytes: [header_bytes + max_checks + 100]u8 = undefined;
    const encoded = encode("proof/one", .immutable, "payload", &bytes);
    const desc = try decode("proof/one", encoded, encoded.len, .{ .status = .ok, .length = encoded.len });
    try std.testing.expectEqual(@as(u64, 7), desc.meta.size);
    try std.testing.expectError(error.ObjectKeyConflict, decode("proof/two", encoded, encoded.len, .{ .status = .ok, .length = encoded.len }));
    bytes[header_bytes] ^= 1;
    try std.testing.expectError(error.ObjectDigestMismatch, decode("proof/one", encoded, encoded.len, .{ .status = .ok, .length = encoded.len }));
}

test "S3 retirement envelopes retain no original payload" {
    var bytes: [header_bytes + 64]u8 = undefined;
    const retired = encode("proof/retired", .retired, "", &bytes);
    const descriptor = try decode("proof/retired", retired, retired.len, .{ .status = .ok, .length = retired.len });
    try std.testing.expectEqual(Kind.retired, descriptor.kind);
    try std.testing.expectEqual(@as(usize, 512), retired.len);
    try std.testing.expectEqual(@as(u64, 0), descriptor.meta.size);
    const nonempty = encode("proof/retired", .retired, "payload", &bytes);
    try std.testing.expectError(error.CorruptObjectDescriptor, decode("proof/retired", nonempty, nonempty.len, .{ .status = .ok, .length = nonempty.len }));
}
