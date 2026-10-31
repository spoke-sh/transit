const std = @import("std");
const runtime = @import("BrowserRuntime.zig");
const c = runtime.catalog;
const b = c.BrowserDeclarations;
const p = c.protocol;
const http = @import("transit_http_server");
const ingress = c.DeclarativeIngress;
const providers = @import("BrowserProviders.zig");
const Self = @This();
host: *runtime.Host,
io: std.Io,
allocator: std.mem.Allocator,
wire: *c.client.Client,
request: *std.http.Server.Request,
response_started: bool = false,
headers: [64]ingress.HeaderPair = undefined,
header_count: usize = 0,

pub fn now(self: Self) !u64 {
    const value = std.Io.Clock.real.now(self.io).toMilliseconds();
    return std.math.cast(u64, value) orelse error.ClockUnavailable;
}
pub fn store(self: Self) b.Store {
    return .{ .client = .{ .allocator = self.allocator, .authority = self.wire, .service = self.wire, .connection = self.host.config.connection, .key = self.host.key }, .namespace = self.host.config.namespace };
}
fn mutation(self: Self) !b.Mutation {
    var value: b.Mutation = undefined;
    try self.io.randomSecure(&value);
    return value;
}
fn token(self: Self) ![43]u8 {
    var bytes: [32]u8 = undefined;
    try self.io.randomSecure(&bytes);
    var encoded: [43]u8 = undefined;
    _ = std.base64.url_safe_no_pad.Encoder.encode(&encoded, &bytes);
    return encoded;
}
fn secretCommitment(self: Self, bytes: []const u8) b.Digest {
    var mac: b.Digest = undefined;
    std.crypto.auth.hmac.sha2.HmacSha256.create(&mac, bytes, &self.host.cookie_key);
    return mac;
}
fn derive(self: Self, state: []const u8, label: []const u8) ![43]u8 {
    var input: [128]u8 = undefined;
    const bytes = try std.fmt.bufPrint(&input, "transit.browser.{s}\x00{s}", .{ label, state });
    var digest: [32]u8 = undefined;
    std.crypto.auth.hmac.sha2.HmacSha256.create(&digest, bytes, &self.host.cookie_key);
    var encoded: [43]u8 = undefined;
    _ = std.base64.url_safe_no_pad.Encoder.encode(&encoded, &digest);
    return encoded;
}
pub fn declaration(self: Self, kind: b.Store.Kind, key: b.Digest) !b.Owned(b.Declaration) {
    var value = try b.read(b.Declaration, self.store(), kind, key) orelse return error.BrowserNotFound;
    errdefer value.deinit();
    if (value.value().kind() != kind) return error.InvalidBrowserRecord;
    try value.value().validate(self.host.config.development_loopback);
    return value;
}
fn provider(self: Self, name: []const u8) !b.Owned(b.Declaration) {
    try b.name(name);
    var result = try self.declaration(.provider, b.Store.digest(name));
    errdefer result.deinit();
    if (!result.value().provider.enabled) return error.ProviderDisabled;
    return result;
}
pub fn secret(self: Self, name: []const u8) !struct { bytes: []u8, revision: b.Store.Revision } {
    var ref = try self.declaration(.secret, b.Store.digest(name));
    defer ref.deinit();
    const value = ref.value().secret;
    if (!value.enabled) return error.SecretDisabled;
    const path = try std.fs.path.join(self.allocator, &.{ self.host.config.secret_directory, value.file });
    defer self.allocator.free(path);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(self.io, path, self.allocator, .limited(8192));
    if (bytes.len == 0) return error.EmptyBrowserSecret;
    return .{ .bytes = bytes, .revision = ref.record.revision };
}
pub fn reader(self: Self, credential: b.Credential) !c.DirectTableClient {
    try credential.validate();
    const material = try self.secret(credential.secret);
    defer {
        std.crypto.secureZero(u8, material.bytes);
        self.allocator.free(material.bytes);
    }
    var seed: [32]u8 = undefined;
    defer std.crypto.secureZero(u8, &seed);
    const bytes = std.mem.trim(u8, material.bytes, " \r\n\t");
    if (bytes.len != 64) return error.InvalidBrowserReaderKey;
    _ = try std.fmt.hexToBytes(&seed, bytes);
    var client = self.store().client;
    client.connection.principal = credential.principal;
    client.connection.role = credential.role;
    client.key = try p.Ed25519.KeyPair.generateDeterministic(seed);
    return client;
}
pub fn session(self: Self, session_cookie: ?[]const u8) !?b.Owned(b.Session) {
    const raw = session_cookie orelse return null;
    if (raw.len != 43) return error.InvalidSession;
    var result = try b.read(b.Session, self.store(), .session, b.Store.digest(raw)) orelse return error.InvalidSession;
    errdefer result.deinit();
    try result.value().requireLive(try self.now());
    var current_provider = try self.provider(result.value().provider);
    defer current_provider.deinit();
    if (!std.meta.eql(current_provider.record.revision, result.value().provider_revision)) return error.SessionProviderChanged;
    if (try b.read(b.Declaration, self.store(), .binding, result.value().identity)) |owned| {
        var binding = owned;
        defer binding.deinit();
        if (binding.value() != .binding or binding.value().binding.restricted or !binding.value().binding.enabled) return error.IdentityRestricted;
    }
    return result;
}
pub fn cookie(self: Self) !?[]const u8 {
    const boundary = try self.host.config.boundary();
    return ingress.InboundBoundaryPolicy.extractUniqueCookie(self.headers[0..self.header_count], boundary.sessionCookieName());
}
fn respond(self: *Self, response_status: std.http.Status, bytes: []const u8, extra: []const std.http.Header) !void {
    var headers: [8]std.http.Header = undefined;
    headers[0] = .{ .name = "content-type", .value = "application/json" };
    headers[1] = .{ .name = "cache-control", .value = "no-store" };
    headers[2] = .{ .name = "x-content-type-options", .value = "nosniff" };
    headers[3] = .{ .name = "referrer-policy", .value = "no-referrer" };
    if (extra.len > 4) return error.InvalidBrowserResponse;
    @memcpy(headers[4..][0..extra.len], extra);
    self.response_started = true;
    self.request.head.keep_alive = false;
    try self.request.respond(bytes, .{ .status = response_status, .keep_alive = false, .extra_headers = headers[0 .. 4 + extra.len] });
}
pub fn run(self: *Self) !void {
    const boundary = try self.host.config.boundary();
    var it = self.request.iterateHeaders();
    while (it.next()) |entry| {
        if (self.header_count == self.headers.len) return error.TooManyBrowserHeaders;
        self.headers[self.header_count] = .{ .name = entry.name, .value = entry.value };
        self.header_count += 1;
    }
    const method = switch (self.request.head.method) {
        .GET => ingress.HttpMethod.get,
        .POST => ingress.HttpMethod.post,
        else => return error.InvalidBrowserMethod,
    };
    const target = self.request.head.target;
    const end = std.mem.indexOfScalar(u8, target, '?') orelse target.len;
    const path = target[0..end];
    const is_callback = std.mem.startsWith(u8, path, "/auth/") and std.mem.endsWith(u8, path, "/callback");
    const watch = std.mem.startsWith(u8, path, "/published/") and std.mem.endsWith(u8, path, "/watch");
    for ([_][]const u8{ "forwarded", "x-forwarded-host", "x-transit-principal", "proxy-authorization" }) |name| if (try http.header(self.request, name) != null) return error.AmbientAuthHeaderForbidden;
    if (self.host.config.development_loopback) {
        for ([_][]const u8{ "x-forwarded-proto", "x-forwarded-for", "x-forwarded-port" }) |name| if (try http.header(self.request, name) != null) return error.UntrustedTlsTermination;
    } else {
        // The ALB may append client addresses; they never establish identity or
        // trust. Reject duplicates and forwarding chains for authority fields.
        _ = try http.header(self.request, "x-forwarded-for");
        if (try http.header(self.request, "x-forwarded-port")) |port| if (!std.mem.eql(u8, port, "443")) return error.InsecureForwardedProto;
    }
    try boundary.verifyBrowserRequest(method, self.headers[0..self.header_count], watch, is_callback);
    // Even anonymous routes reject duplicate credentials rather than picking one.
    _ = try self.cookie();
    _ = try ingress.InboundBoundaryPolicy.extractUniqueCookie(self.headers[0..self.header_count], boundary.loginCookieName());
    if (std.mem.eql(u8, path, "/auth/providers") and method == .get) return self.discovery();
    if (std.mem.eql(u8, path, "/auth/session") and method == .get) return self.status();
    if (std.mem.eql(u8, path, "/auth/logout") and method == .post) return self.logout();
    if (std.mem.startsWith(u8, path, "/auth/") and std.mem.endsWith(u8, path, "/login") and method == .post) {
        if (path.len <= 12) return error.BrowserNotFound;
        return self.login(path[6 .. path.len - 6]);
    }
    if (is_callback and method == .get) {
        if (path.len <= 15) return error.BrowserNotFound;
        return self.callback(path[6 .. path.len - 9], if (end < target.len) target[end + 1 ..] else "");
    }
    if (std.mem.startsWith(u8, path, "/published/") and method == .get) {
        const suffix: []const u8 = if (watch) "/watch" else "/snapshot";
        if (!std.mem.endsWith(u8, path, suffix) or path.len <= 11 + suffix.len) return error.BrowserNotFound;
        const name = path[11 .. path.len - suffix.len];
        try b.name(name);
        if (watch) return @import("BrowserWatch.zig").run(self, name);
        const snapshot = try @import("BrowserSnapshot.zig").read(self.*, name, try self.cookie(), null);
        return self.respond(.ok, snapshot.?.bytes, &.{});
    }
    return error.BrowserNotFound;
}
fn discovery(self: *Self) !void {
    // Page the durable provider population; no unbounded browser discovery list.
    const target = self.request.head.target;
    var after: ?u64 = null;
    if (std.mem.indexOfScalar(u8, target, '?')) |start| if (try parameter(self.allocator, target[start + 1 ..], "after")) |value| {
        after = try std.fmt.parseInt(u64, value, 10);
    };
    const page = try self.store().page(.provider, after);
    var names: [8][]const u8 = undefined;
    var count: usize = 0;
    for (page.entries) |slot| if (slot) |progress| {
        const ref = progress.record orelse progress.receipt.binding.intent.external.record;
        const record = try self.store().load(ref);
        defer record.deinit();
        const decl = try std.json.parseFromSlice(b.Declaration, self.allocator, record.value.payload, .{});
        defer decl.deinit();
        if (decl.value != .provider) return error.InvalidBrowserRecord;
        if (!decl.value.provider.enabled) continue;
        names[count] = try self.allocator.dupe(u8, decl.value.provider.profile.provider_name);
        count += 1;
    };
    const next = if (page.next) |value| try std.fmt.allocPrint(self.allocator, "{d}", .{value}) else null;
    return self.respond(.ok, try p.Json.valueAlloc(self.allocator, .{ .providers = names[0..count], .next = next }), &.{});
}
fn status(self: *Self) !void {
    var current = try self.session(try self.cookie());
    defer if (current) |*value| value.deinit();
    if (current) |value| {
        var binding = try b.read(b.Declaration, self.store(), .binding, value.value().identity);
        defer if (binding) |*entry| entry.deinit();
        const bound = if (binding) |entry| entry.value().binding.enabled and !entry.value().binding.restricted and entry.value().binding.reader != null else false;
        const identity = std.fmt.bytesToHex(&value.value().identity, .lower);
        return self.respond(.ok, try p.Json.valueAlloc(self.allocator, .{ .authenticated = true, .provider = value.value().provider, .identity = &identity, .bound = bound }), &.{});
    }
    return self.respond(.ok, "{\"authenticated\":false,\"provider\":null,\"identity\":null,\"bound\":false}", &.{});
}
fn login(self: *Self, name: []const u8) !void {
    var declared = try self.provider(name);
    defer declared.deinit();
    const selected = declared.value().provider;
    const secret_ref = try self.secret(selected.secret);
    defer std.crypto.secureZero(u8, secret_ref.bytes);
    const state = try self.token();
    const cookie_token = try self.derive(&state, "cookie");
    const verifier = try self.derive(&state, "pkce");
    const nonce = try self.derive(&state, "nonce");
    const challenge: b.Challenge = .{ .provider = name, .provider_revision = declared.record.revision, .secret_revision = secret_ref.revision, .secret_commitment = self.secretCommitment(secret_ref.bytes), .cookie_digest = b.Store.digest(&cookie_token), .pkce_digest = b.Store.digest(&verifier), .nonce_digest = b.Store.digest(&nonce), .expires_ms = try self.now() + self.host.config.challenge_ttl_ms, .state = .issued };
    _ = try b.save(self.store(), .challenge, b.Store.digest(&state), try self.mutation(), null, challenge);
    const boundary = try self.host.config.boundary();
    const location = try providers.authorize(self.allocator, selected, self.host.config.public_origin, &state, &verifier, &nonce);
    const set_cookie = try boundary.formatSetCookieHeader(self.allocator, boundary.loginCookieName(), &cookie_token, self.host.config.challenge_ttl_ms / 1000);
    return self.respond(.see_other, "{}", &.{ .{ .name = "location", .value = location }, .{ .name = "set-cookie", .value = set_cookie } });
}
fn callback(self: *Self, name: []const u8, query: []const u8) !void {
    const state = try parameter(self.allocator, query, "state") orelse return error.MissingCallbackState;
    const code = try parameter(self.allocator, query, "code") orelse return error.MissingCallbackCode;
    if (try parameter(self.allocator, query, "error") != null) return error.ProviderExchangeRejected;
    if (state.len != 43) return error.InvalidCallback;
    const boundary = try self.host.config.boundary();
    const cookie_token = try ingress.InboundBoundaryPolicy.extractUniqueCookie(self.headers[0..self.header_count], boundary.loginCookieName()) orelse return error.MissingLoginCookie;
    var challenge = try b.read(b.Challenge, self.store(), .challenge, b.Store.digest(state)) orelse return error.InvalidCallback;
    defer challenge.deinit();
    if (!std.mem.eql(u8, challenge.value().provider, name)) return error.InvalidCallback;
    var declared = try self.provider(name);
    defer declared.deinit();
    const selected = declared.value().provider;
    const material = try self.secret(selected.secret);
    defer std.crypto.secureZero(u8, material.bytes);
    if (!std.meta.eql(declared.record.revision, challenge.value().provider_revision) or !std.meta.eql(material.revision, challenge.value().secret_revision) or !std.crypto.timing_safe.eql(b.Digest, self.secretCommitment(material.bytes), challenge.value().secret_commitment)) return error.LoginDeclarationChanged;
    const verifier = try self.derive(state, "pkce");
    const nonce = try self.derive(state, "nonce");
    const effect = try self.mutation();
    var claimed = try challenge.value().claim(cookie_token, &verifier, &nonce, code, try self.now(), effect);
    const accepted = try b.save(self.store(), .challenge, b.Store.digest(state), effect, challenge.record.revision, claimed);
    if (!accepted.changed) return error.CallbackAlreadyClaimed;
    // A failure from here leaves a consumed claim/effect identity. Never resend
    // an uncertain code exchange, even after restart or duplicate callbacks.
    const subject = try providers.exchange(self.allocator, self.host.allocator, self.io, &self.host.jwks, selected, declared.record.revision, self.host.config.public_origin, std.mem.trim(u8, material.bytes, "\r\n"), code, &verifier, &nonce, try self.now(), self.host.config.provider_ca_file);
    var current = try self.provider(name);
    defer current.deinit();
    var current_secret = try self.declaration(.secret, b.Store.digest(selected.secret));
    defer current_secret.deinit();
    if (!std.meta.eql(current.record.revision, declared.record.revision) or !current_secret.value().secret.enabled or !std.meta.eql(current_secret.record.revision, material.revision)) return error.LoginDeclarationChanged;
    const identity = b.Identity.digest(selected.profile.issuer_profile.issuer_uri, selected.profile.client_id, subject);
    var existing = try b.read(b.Identity, self.store(), .identity, identity);
    defer if (existing) |*value| value.deinit();
    if (existing == null) {
        // Stable creation mutation permits racing logins for the same identity.
        const created = b.Identity{ .provider = name, .subject = subject };
        _ = try b.save(self.store(), .identity, identity, identity[0..16].*, null, created);
    }
    claimed.state = .{ .complete = .{ .effect = effect, .identity = identity } };
    _ = try b.save(self.store(), .challenge, b.Store.digest(state), try self.mutation(), accepted.revision, claimed);
    const session_token = try self.token();
    const now_ms = try self.now();
    const session_record: b.Session = .{ .identity = identity, .provider = name, .provider_revision = declared.record.revision, .created_ms = now_ms, .expires_ms = now_ms + self.host.config.session_ttl_ms, .revoked = false };
    _ = try b.save(self.store(), .session, b.Store.digest(&session_token), try self.mutation(), null, session_record);
    // Local restriction may have arrived while the provider was responding.
    var live = try self.session(&session_token);
    defer if (live) |*value| value.deinit();
    const session_cookie = try boundary.formatSetCookieHeader(self.allocator, boundary.sessionCookieName(), &session_token, self.host.config.session_ttl_ms / 1000);
    const clear = try boundary.formatSetCookieHeader(self.allocator, boundary.loginCookieName(), "", 0);
    return self.respond(.see_other, "{}", &.{ .{ .name = "location", .value = "/" }, .{ .name = "set-cookie", .value = session_cookie }, .{ .name = "set-cookie", .value = clear } });
}
fn logout(self: *Self) !void {
    if (try self.cookie()) |raw| {
        var current = try b.read(b.Session, self.store(), .session, b.Store.digest(raw));
        defer if (current) |*value| value.deinit();
        if (current) |value| if (!value.value().revoked) {
            var revoked = value.value();
            revoked.revoked = true;
            _ = try b.save(self.store(), .session, b.Store.digest(raw), try self.mutation(), value.record.revision, revoked);
        };
    }
    const boundary = try self.host.config.boundary();
    const clear = try boundary.formatSetCookieHeader(self.allocator, boundary.sessionCookieName(), "", 0);
    return self.respond(.ok, "{\"authenticated\":false}", &.{.{ .name = "set-cookie", .value = clear }});
}
pub fn parameter(allocator: std.mem.Allocator, query: []const u8, key: []const u8) !?[]const u8 {
    var found: ?[]const u8 = null;
    var parts = std.mem.splitScalar(u8, query, '&');
    while (parts.next()) |part| {
        const eq = std.mem.indexOfScalar(u8, part, '=') orelse return error.InvalidBrowserQuery;
        const name = try decode(allocator, part[0..eq]);
        if (!std.mem.eql(u8, key, name)) continue;
        if (found != null) return error.DuplicateBrowserParameter;
        found = try decode(allocator, part[eq + 1 ..]);
    }
    return found;
}
fn decode(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    const output = try allocator.alloc(u8, input.len);
    var used: usize = 0;
    var index: usize = 0;
    while (index < input.len) : (index += 1) {
        const ch = input[index];
        output[used] = if (ch == '%') blk: {
            if (input.len - index < 3) return error.InvalidBrowserQuery;
            const value = try std.fmt.parseInt(u8, input[index + 1 ..][0..2], 16);
            index += 2;
            break :blk value;
        } else if (ch == '+') ' ' else ch;
        if (output[used] == 0 or output[used] == '\r' or output[used] == '\n') return error.InvalidBrowserQuery;
        used += 1;
    }
    return output[0..used];
}
