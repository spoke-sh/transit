//! Provider-specific HTTPS effects. No redirects, ambient bearer headers or
//! provider tokens in browser responses, durable SQL or diagnostics.
const std = @import("std");
const Security = @import("Security.zig");
const Oidc = @import("Oidc.zig");
pub const Config = struct {
    provider: Security.Provider,
    client_id: []const u8,
    client_secret_file: []const u8,
    facebook_version: []const u8 = "v23.0",
    /// Explicit loopback fixture only; forbidden outside development mode.
    test_endpoint: ?[]const u8 = null,
};
pub const Endpoints = struct { authorize: []const u8, token: []const u8, identity: []const u8, jwks: ?[]const u8 = null, debug: ?[]const u8 = null };
pub fn endpoints(a: std.mem.Allocator, config: Config, development: bool) !Endpoints {
    if (config.client_id.len == 0 or config.client_id.len > 256 or config.client_secret_file.len == 0) return error.InvalidProviderConfiguration;
    if (config.test_endpoint) |base| {
        if (!development) return error.InvalidProviderConfiguration;
        _ = try Security.Boundary.init(base, true);
        return .{ .authorize = try std.fmt.allocPrint(a, "{s}/{s}/authorize", .{ base, @tagName(config.provider) }), .token = try std.fmt.allocPrint(a, "{s}/{s}/token", .{ base, @tagName(config.provider) }), .identity = try std.fmt.allocPrint(a, "{s}/{s}/user", .{ base, @tagName(config.provider) }), .jwks = try std.fmt.allocPrint(a, "{s}/google/jwks", .{base}), .debug = try std.fmt.allocPrint(a, "{s}/facebook/debug", .{base}) };
    }
    return switch (config.provider) {
        .google => .{ .authorize = "https://accounts.google.com/o/oauth2/v2/auth", .token = "https://oauth2.googleapis.com/token", .identity = "https://openidconnect.googleapis.com/v1/userinfo", .jwks = "https://www.googleapis.com/oauth2/v3/certs" },
        .github => .{ .authorize = "https://github.com/login/oauth/authorize", .token = "https://github.com/login/oauth/access_token", .identity = "https://api.github.com/user" },
        .facebook => blk: {
            const version = config.facebook_version;
            if (version.len < 4 or version.len > 8 or version[0] != 'v') return error.InvalidProviderConfiguration;
            var dot: usize = 0;
            for (version[1..]) |c| if (c == '.') {
                dot += 1;
            } else if (!std.ascii.isDigit(c)) return error.InvalidProviderConfiguration;
            if (dot != 1) return error.InvalidProviderConfiguration;
            break :blk .{ .authorize = try std.fmt.allocPrint(a, "https://www.facebook.com/{s}/dialog/oauth", .{version}), .token = try std.fmt.allocPrint(a, "https://graph.facebook.com/{s}/oauth/access_token", .{version}), .identity = try std.fmt.allocPrint(a, "https://graph.facebook.com/{s}/me", .{version}), .debug = try std.fmt.allocPrint(a, "https://graph.facebook.com/{s}/debug_token", .{version}) };
        },
    };
}
pub fn encode(a: std.mem.Allocator, value: []const u8) ![]const u8 {
    const out = try a.alloc(u8, value.len * 3);
    var len: usize = 0;
    const hex = "0123456789ABCDEF";
    for (value) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~') {
            out[len] = c;
            len += 1;
        } else {
            out[len] = '%';
            out[len + 1] = hex[c >> 4];
            out[len + 2] = hex[c & 15];
            len += 3;
        }
    }
    return out[0..len];
}
pub fn authorization(a: std.mem.Allocator, config: Config, selected: Endpoints, callback: []const u8, state: []const u8, pkce: []const u8, nonce: []const u8) ![]const u8 {
    const base = try std.fmt.allocPrint(a, "{s}?response_type=code&client_id={s}&redirect_uri={s}&state={s}", .{ selected.authorize, try encode(a, config.client_id), try encode(a, callback), try encode(a, state) });
    return switch (config.provider) {
        .google => std.fmt.allocPrint(a, "{s}&scope=openid&code_challenge_method=S256&code_challenge={s}&nonce={s}", .{ base, try encode(a, pkce), try encode(a, nonce) }),
        .github => std.fmt.allocPrint(a, "{s}&scope=&code_challenge_method=S256&code_challenge={s}", .{ base, try encode(a, pkce) }),
        .facebook => std.fmt.allocPrint(a, "{s}&scope=public_profile", .{base}),
    };
}
fn request(a: std.mem.Allocator, io: std.Io, method: std.http.Method, url: []const u8, body: ?[]const u8, bearer: ?[]const u8) ![]const u8 {
    var client: std.http.Client = .{ .allocator = a, .io = io };
    defer client.deinit();
    const token = if (bearer) |value| try std.fmt.allocPrint(a, "Bearer {s}", .{value}) else "";
    const headers: []const std.http.Header = if (bearer != null) &.{ .{ .name = "accept", .value = "application/json" }, .{ .name = "authorization", .value = token } } else &.{.{ .name = "accept", .value = "application/json" }};
    var req = try client.request(method, try std.Uri.parse(url), .{ .redirect_behavior = .not_allowed, .keep_alive = false, .headers = .{ .accept_encoding = .{ .override = "identity" }, .content_type = .{ .override = "application/x-www-form-urlencoded" }, .user_agent = .{ .override = "Transit" } }, .extra_headers = headers });
    defer req.deinit();
    if (body) |bytes| {
        req.transfer_encoding = .{ .content_length = bytes.len };
        var writer = try req.sendBodyUnflushed(&.{});
        try writer.writer.writeAll(bytes);
        try writer.end();
        try req.connection.?.flush();
    } else try req.sendBodiless();
    var head: [16384]u8 = undefined;
    var response = try req.receiveHead(&head);
    if (response.head.status != .ok or response.head.content_encoding != .identity) return error.ProviderRequestFailed;
    var output: std.Io.Writer = .fixed(try a.alloc(u8, 131072));
    _ = response.reader(&.{}).streamRemaining(&output) catch return error.ProviderResponseInvalid;
    return output.buffered();
}
fn json(a: std.mem.Allocator, bytes: []const u8) !std.json.Value {
    return std.json.parseFromSliceLeaky(std.json.Value, a, bytes, .{});
}
pub fn exchange(a: std.mem.Allocator, io: std.Io, config: Config, selected: Endpoints, callback: []const u8, code: []const u8, verifier_value: []const u8, nonce: []const u8, now: i64) !Security.Token {
    if (code.len == 0 or code.len > 2048) return error.InvalidAuthorizationCode;
    const raw_secret = try std.Io.Dir.cwd().readFileAlloc(io, config.client_secret_file, a, .limited(4096));
    defer std.crypto.secureZero(u8, raw_secret);
    const secret = std.mem.trim(u8, raw_secret, "\r\n");
    if (secret.len == 0) return error.InvalidProviderConfiguration;
    const form = try std.fmt.allocPrint(a, "grant_type=authorization_code&client_id={s}&client_secret={s}&code={s}&redirect_uri={s}{s}", .{ try encode(a, config.client_id), try encode(a, secret), try encode(a, code), try encode(a, callback), if (config.provider != .facebook) try std.fmt.allocPrint(a, "&code_verifier={s}", .{try encode(a, verifier_value)}) else "" });
    const response = try request(a, io, .POST, selected.token, form, null);
    const tokens = try json(a, response);
    const access = try Oidc.string(tokens, "access_token");
    if (access.len == 0 or access.len > 8192 or std.mem.indexOfAny(u8, access, "\r\n") != null) return error.ProviderResponseInvalid;
    const external = switch (config.provider) {
        .google => blk: {
            const id_token = try Oidc.string(tokens, "id_token");
            const keys = try request(a, io, .GET, selected.jwks.?, null, null);
            break :blk try Oidc.verify(a, id_token, keys, "https://accounts.google.com", config.client_id, nonce, now);
        },
        .github => blk: {
            const profile = try json(a, try request(a, io, .GET, selected.identity, null, access));
            if (profile != .object) return error.ProviderResponseInvalid;
            const id = profile.object.get("id") orelse return error.ProviderResponseInvalid;
            if (id != .integer or id.integer <= 0) return error.ProviderResponseInvalid;
            break :blk try std.fmt.allocPrint(a, "{d}", .{id.integer});
        },
        .facebook => blk: {
            const app_token = try std.fmt.allocPrint(a, "{s}|{s}", .{ config.client_id, secret });
            const debug_url = try std.fmt.allocPrint(a, "{s}?input_token={s}", .{ selected.debug.?, try encode(a, access) });
            const debug = try json(a, try request(a, io, .GET, debug_url, null, app_token));
            if (debug != .object) return error.ProviderResponseInvalid;
            const data = debug.object.get("data") orelse return error.ProviderResponseInvalid;
            if (data != .object) return error.ProviderResponseInvalid;
            const valid = data.object.get("is_valid") orelse return error.ProviderResponseInvalid;
            if (valid != .bool or !valid.bool or !std.mem.eql(u8, try Oidc.string(data, "app_id"), config.client_id)) return error.ProviderResponseInvalid;
            const expected = try Oidc.string(data, "user_id");
            var proof: [32]u8 = undefined;
            std.crypto.auth.hmac.sha2.HmacSha256.create(&proof, access, secret);
            const proof_hex = std.fmt.bytesToHex(proof, .lower);
            const profile_url = try std.fmt.allocPrint(a, "{s}?fields=id&appsecret_proof={s}", .{ selected.identity, proof_hex });
            const profile = try json(a, try request(a, io, .GET, profile_url, null, access));
            const actual = try Oidc.string(profile, "id");
            if (actual.len == 0 or actual.len > 255 or !std.mem.eql(u8, expected, actual)) return error.ProviderResponseInvalid;
            break :blk actual;
        },
    };
    return Security.subject(config.provider, config.client_id, external);
}
