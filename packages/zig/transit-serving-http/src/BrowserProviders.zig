//! Finite provider exchanges through the shared HTTP connector transport. The
//! caller must hold a freshly accepted durable challenge claim. No retries,
//! redirects, response-body logging or external effects occur during recovery.
const std = @import("std");
const c = @import("transit_catalog");
const b = c.BrowserDeclarations;
const connector = @import("transit_station_http");
const transport = connector.Transport;

pub fn encode(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    for (bytes) |ch| {
        if (std.ascii.isAlphanumeric(ch) or std.mem.indexOfScalar(u8, "-._~", ch) != null) try out.writer.writeByte(ch) else try out.writer.print("%{X:0>2}", .{ch});
    }
    return out.toOwnedSlice();
}
pub fn authorize(allocator: std.mem.Allocator, provider: b.Provider, origin: []const u8, state: []const u8, verifier: []const u8, nonce: []const u8) ![]u8 {
    const profile = provider.profile;
    const callback = try std.fmt.allocPrint(allocator, "{s}/auth/{s}/callback", .{ origin, profile.provider_name });
    const digest = b.Store.digest(verifier);
    var challenge: [43]u8 = undefined;
    _ = std.base64.url_safe_no_pad.Encoder.encode(&challenge, &digest);
    const pkce = if (provider.pkce == .s256) try std.fmt.allocPrint(allocator, "&code_challenge={s}&code_challenge_method=S256", .{challenge}) else "";
    const oidc = if (profile.verification_mode == .oidc_rs256_id_token) try std.fmt.allocPrint(allocator, "&nonce={s}", .{try encode(allocator, nonce)}) else "";
    return std.fmt.allocPrint(allocator, "{s}{s}response_type=code&client_id={s}&redirect_uri={s}&scope={s}&state={s}{s}{s}", .{ profile.authorize_endpoint, if (std.mem.indexOfScalar(u8, profile.authorize_endpoint, '?') == null) "?" else "&", try encode(allocator, profile.client_id), try encode(allocator, callback), try encode(allocator, profile.scopes_space_separated), try encode(allocator, state), pkce, oidc });
}
const Capture = struct {
    out: std.Io.Writer.Allocating,
    fn segment(raw: *anyopaque, kind: connector.Kind, bytes: []const u8) !void {
        const self: *Capture = @ptrCast(@alignCast(raw));
        if (kind != .response_body) return;
        if (self.out.written().len + bytes.len > 65536) return error.ProviderResponseTooLarge;
        try self.out.writer.writeAll(bytes);
    }
};
fn component(value: std.Uri.Component) []const u8 {
    return switch (value) {
        inline else => |bytes| bytes,
    };
}
fn address4(io: std.Io, host: []const u8, port: u16, buffer: []u8) ![]const u8 {
    if (std.Io.net.Ip4Address.parse(host, port)) |_| return host else |_| {}
    var canonical: [std.Io.net.HostName.max_len]u8 = undefined;
    var entries: [32]std.Io.net.HostName.LookupResult = undefined;
    var queue: std.Io.Queue(std.Io.net.HostName.LookupResult) = .init(&entries);
    var future = io.async(std.Io.net.HostName.lookup, .{ try std.Io.net.HostName.init(host), io, &queue, .{ .port = port, .canonical_name_buffer = &canonical } });
    defer future.cancel(io) catch {};
    while (queue.getOne(io)) |entry| {
        if (entry == .address and entry.address == .ip4) {
            const bytes = entry.address.ip4.bytes;
            return std.fmt.bufPrint(buffer, "{d}.{d}.{d}.{d}", .{ bytes[0], bytes[1], bytes[2], bytes[3] });
        }
    } else |err| {
        if (err == error.Canceled) return err;
        try future.await(io);
    }
    return error.ProviderAddressUnavailable;
}
/// The surrounding request owns an overall deadline including DNS. Transport
/// additionally bounds the exchange; responses are private transient memory.
pub fn fetch(allocator: std.mem.Allocator, io: std.Io, url: []const u8, body: ?[]const u8, bearer: ?[]const u8, ca_file: ?[]const u8) ![]u8 {
    const uri = try std.Uri.parse(url);
    if (uri.user != null or uri.password != null or uri.fragment != null) return error.InvalidProviderEndpoint;
    const host = component(uri.host orelse return error.InvalidProviderEndpoint);
    const secure = std.mem.eql(u8, uri.scheme, "https");
    if (!secure and !(std.mem.eql(u8, uri.scheme, "http") and std.mem.eql(u8, host, "127.0.0.1"))) return error.InvalidProviderEndpoint;
    const port: u16 = uri.port orelse if (secure) 443 else 80;
    var addr: [16]u8 = undefined;
    const address = try address4(io, host, port, &addr);
    const path = component(uri.path);
    const target = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ if (path.len == 0) "/" else path, if (uri.query != null) "?" else "", if (uri.query) |query| component(query) else "" });
    defer allocator.free(target);
    const authorization = if (bearer) |token| try std.fmt.allocPrint(allocator, "Bearer {s}", .{token}) else null;
    defer if (authorization) |bytes| {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    };
    const header_values = [_][1]connector.Request.Piece{ .{.{ .literal = "application/json" }}, .{.{ .literal = "transit" }}, .{.{ .literal = "application/x-www-form-urlencoded" }}, .{.{ .literal = authorization orelse "" }} };
    var headers: [4]connector.Request.Header = .{ .{ .name = "accept", .value = &header_values[0] }, .{ .name = "user-agent", .value = &header_values[1] }, .{ .name = "content-type", .value = &header_values[2] }, .{ .name = "authorization", .value = &header_values[3] } };
    var capture: Capture = .{ .out = .init(allocator) };
    defer capture.out.deinit();
    var reader: std.Io.Reader = .fixed(body orelse "");
    const result = try transport.execute(allocator, io, .{ .host = host, .address = address, .port = port, .tls = secure, .ca_file = ca_file, .timeout_ms = 5000 }, .{ .method = if (body != null) .POST else .GET, .target = &.{.{ .literal = target }}, .headers = headers[0..if (bearer != null) 4 else 3], .body_bytes = if (body) |bytes| bytes.len else 0 }, &reader, null, .{ .context = &capture, .segment = Capture.segment });
    if (result.status < 200 or result.status >= 300) return error.ProviderExchangeRejected;
    return capture.out.toOwnedSlice();
}
pub const JwksCache = struct {
    // Capacity bounds resident cache, not the durable provider population.
    entries: [16]?struct { key: [32]u8, bytes: []u8, expires: u64, refreshed: u64 } = @splat(null),
    mutex: std.Io.Mutex = .init,
    pub fn deinit(self: *JwksCache, allocator: std.mem.Allocator) void {
        for (self.entries) |entry| if (entry) |value| allocator.free(value.bytes);
    }
    pub fn get(self: *JwksCache, allocator: std.mem.Allocator, io: std.Io, provider: b.Provider, revision: b.Store.Revision, force: bool, ca: ?[]const u8) ![]u8 {
        const canonical = try c.protocol.Json.valueAlloc(allocator, .{ provider, revision });
        defer allocator.free(canonical);
        const key = b.Store.digest(canonical);
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        // Another provider's acquisition may have held the cache lock. Its
        // wait cannot preserve freshness from before that acquisition.
        const now = try timeMillis(io);
        var slot: usize = 0;
        for (self.entries, 0..) |entry, index| {
            if (entry) |value| {
                if (std.mem.eql(u8, &key, &value.key)) {
                    slot = index;
                    if (!force and now >= value.refreshed and now < value.expires) return allocator.dupe(u8, value.bytes);
                    if (force and now < value.refreshed + 1000) return error.JwksRefreshThrottled;
                    break;
                }
                if (self.entries[slot] != null and value.refreshed < self.entries[slot].?.refreshed) slot = index;
            } else slot = index;
        }
        // A failed refresh never extends the old keyset's TTL.
        const bytes = try fetch(allocator, io, provider.jwks_endpoint.?, null, null, ca);
        errdefer allocator.free(bytes);
        const refreshed = try timeMillis(io);
        const copy = try allocator.dupe(u8, bytes);
        if (self.entries[slot]) |old| allocator.free(old.bytes);
        self.entries[slot] = .{ .key = key, .bytes = copy, .refreshed = refreshed, .expires = refreshed + provider.jwks_ttl_ms };
        return bytes;
    }
};
fn requireKid(allocator: std.mem.Allocator, token: []const u8, retired: []const []const u8) !void {
    const dot = std.mem.indexOfScalar(u8, token, '.') orelse return error.InvalidOidcToken;
    if (dot > 4096) return error.InvalidOidcToken;
    const decoder = std.base64.url_safe_no_pad.Decoder;
    const bytes = try allocator.alloc(u8, try decoder.calcSizeForSlice(token[0..dot]));
    defer allocator.free(bytes);
    try decoder.decode(bytes, token[0..dot]);
    const header = try std.json.parseFromSlice(struct { kid: []const u8 }, allocator, bytes, .{ .ignore_unknown_fields = true, .duplicate_field_behavior = .@"error" });
    defer header.deinit();
    for (retired) |kid| if (std.mem.eql(u8, kid, header.value.kid)) return error.RetiredJwksKey;
}
fn keyRecords(allocator: std.mem.Allocator, provider: b.Provider, revision: b.Store.Revision, jwks: []const u8, now: u64) ![]const c.AccessAndIdentity.JwksKeyRecord {
    const document = try std.json.parseFromSlice(struct { keys: []const struct { kid: []const u8 } }, allocator, jwks, .{ .ignore_unknown_fields = true, .duplicate_field_behavior = .@"error" });
    defer document.deinit();
    if (document.value.keys.len == 0 or document.value.keys.len > 32) return error.InvalidJwksDocument;
    const keys = try allocator.alloc(c.AccessAndIdentity.JwksKeyRecord, document.value.keys.len);
    for (keys, document.value.keys) |*record, key| {
        if (key.kid.len == 0 or key.kid.len > 128) return error.InvalidJwksDocument;
        record.* = .{ .issuer_id = provider.profile.issuer_profile.issuer_id, .kid = try allocator.dupe(u8, key.kid), .key_epoch = revision.next_lsn, .state = .active, .expires_at_ns = @intCast((now + provider.jwks_ttl_ms) * std.time.ns_per_ms) };
    }
    return keys;
}
fn timeMillis(io: std.Io) !u64 {
    return std.math.cast(u64, std.Io.Clock.real.now(io).toMilliseconds()) orelse error.ClockUnavailable;
}
pub fn exchange(allocator: std.mem.Allocator, cache_allocator: std.mem.Allocator, io: std.Io, cache: *JwksCache, provider: b.Provider, revision: b.Store.Revision, origin: []const u8, secret: []const u8, code: []const u8, verifier: []const u8, nonce: []const u8, now: u64, ca: ?[]const u8) ![]u8 {
    const callback = try std.fmt.allocPrint(allocator, "{s}/auth/{s}/callback", .{ origin, provider.profile.provider_name });
    const pkce = if (provider.pkce == .s256) try std.fmt.allocPrint(allocator, "&code_verifier={s}", .{try encode(allocator, verifier)}) else "";
    const form = try std.fmt.allocPrint(allocator, "grant_type=authorization_code&client_id={s}&client_secret={s}&code={s}&redirect_uri={s}{s}", .{ try encode(allocator, provider.profile.client_id), try encode(allocator, secret), try encode(allocator, code), try encode(allocator, callback), pkce });
    defer std.crypto.secureZero(u8, form);
    const tokens = try fetch(allocator, io, provider.profile.token_endpoint, form, null, ca);
    defer std.crypto.secureZero(u8, tokens);
    const parsed = try std.json.parseFromSlice(struct { access_token: ?[]const u8 = null, id_token: ?[]const u8 = null, @"error": ?[]const u8 = null }, allocator, tokens, .{ .ignore_unknown_fields = true, .duplicate_field_behavior = .@"error" });
    defer parsed.deinit();
    if (parsed.value.@"error" != null) return error.ProviderExchangeRejected;
    if (provider.profile.verification_mode == .oidc_rs256_id_token) {
        const token = parsed.value.id_token orelse return error.MissingOidcIdToken;
        try requireKid(allocator, token, provider.retired_kids);
        var profile = provider.profile;
        const jwks = try cache.get(cache_allocator, io, provider, revision, false, ca);
        defer cache_allocator.free(jwks);
        profile.cached_jwks_json = jwks;
        profile.issuer_profile.jwks_keys = try keyRecords(allocator, provider, revision, jwks, try timeMillis(io));
        return profile.verifyProviderExchangePayloads(allocator, tokens, null, null, nonce, @intCast(try timeMillis(io) / 1000)) catch |err| {
            if (err != error.UnknownOrRevokedJwksKey and err != error.UnknownJwksKey) return err;
            const refreshed = try cache.get(cache_allocator, io, provider, revision, true, ca);
            defer cache_allocator.free(refreshed);
            profile.cached_jwks_json = refreshed;
            profile.issuer_profile.jwks_keys = try keyRecords(allocator, provider, revision, refreshed, try timeMillis(io));
            return profile.verifyProviderExchangePayloads(allocator, tokens, null, null, nonce, @intCast(try timeMillis(io) / 1000));
        };
    }
    const token = parsed.value.access_token orelse return error.MissingProviderAccessToken;
    if (token.len == 0 or token.len > 8192) return error.InvalidProviderAccessToken;
    var debug: ?[]const u8 = null;
    var userinfo = provider.profile.userinfo_endpoint;
    if (provider.profile.verification_mode == .oauth2_appsecret_proof_debug) {
        var mac: [32]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&mac, token, secret);
        const proof = std.fmt.bytesToHex(&mac, .lower);
        userinfo = try std.fmt.allocPrint(allocator, "{s}{s}appsecret_proof={s}", .{ userinfo, if (std.mem.indexOfScalar(u8, userinfo, '?') == null) "?" else "&", proof });
        const app_token = try std.fmt.allocPrint(allocator, "{s}|{s}", .{ provider.profile.client_id, secret });
        const debug_url = try std.fmt.allocPrint(allocator, "{s}?input_token={s}&access_token={s}", .{ provider.profile.debug_token_endpoint.?, try encode(allocator, token), try encode(allocator, app_token) });
        debug = try fetch(allocator, io, debug_url, null, null, ca);
    }
    const profile = try fetch(allocator, io, userinfo, null, token, ca);
    return provider.profile.verifyProviderExchangePayloads(allocator, tokens, profile, debug, nonce, @intCast(now / 1000));
}

test "browser provider form encoding and PKCE output are exact" {
    const encoded = try encode(std.testing.allocator, "a+ /&?é");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualStrings("a%2B%20%2F%26%3F%C3%A9", encoded);
}
