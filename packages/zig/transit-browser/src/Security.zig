//! Pure browser boundary decisions. Transport headers never create identity.
const std = @import("std");
const Sha256 = std.crypto.hash.sha2.Sha256;
const Hmac = std.crypto.auth.hmac.sha2.HmacSha256;
pub const Provider = enum { google, facebook, github };
pub const Token = [64]u8;
pub fn digest(bytes: []const u8) Token {
    var out: [32]u8 = undefined;
    Sha256.hash(bytes, &out, .{});
    return std.fmt.bytesToHex(out, .lower);
}
pub fn random(io: std.Io) !Token {
    var bytes: [32]u8 = undefined;
    try io.randomSecure(&bytes);
    return std.fmt.bytesToHex(bytes, .lower);
}
pub fn validToken(token: []const u8) bool {
    if (token.len != 64) return false;
    for (token) |c| if (!(c >= '0' and c <= '9') and !(c >= 'a' and c <= 'f')) return false;
    return true;
}
/// Provider/client scope prevents Facebook app-scoped subjects and providers
/// from colliding. Emails and mutable usernames never establish identity.
pub fn subject(provider: Provider, client_id: []const u8, external_id: []const u8) Token {
    var hash = Sha256.init(.{});
    hash.update("transit.browser.identity.v1\x00");
    hash.update(@tagName(provider));
    hash.update("\x00");
    hash.update(client_id);
    hash.update("\x00");
    hash.update(external_id);
    return std.fmt.bytesToHex(hash.finalResult(), .lower);
}
pub fn verifier(key: *const [32]u8, state: []const u8) [43]u8 {
    var value: [32]u8 = undefined;
    Hmac.create(&value, state, key);
    var out: [43]u8 = undefined;
    _ = std.base64.url_safe_no_pad.Encoder.encode(&out, &value);
    return out;
}
pub fn challenge(value: []const u8) [43]u8 {
    var hash: [32]u8 = undefined;
    Sha256.hash(value, &hash, .{});
    var out: [43]u8 = undefined;
    _ = std.base64.url_safe_no_pad.Encoder.encode(&out, &hash);
    return out;
}
pub const Boundary = struct {
    origin: []const u8,
    authority: []const u8,
    development: bool = false,
    pub fn init(origin: []const u8, development: bool) !Boundary {
        const scheme = if (development) "http://" else "https://";
        if (!std.mem.startsWith(u8, origin, scheme)) return error.InvalidBrowserOrigin;
        const authority = origin[scheme.len..];
        if (authority.len == 0 or authority.len > 200 or std.mem.indexOfAny(u8, authority, "/@?#\\ \t\r\n") != null) return error.InvalidBrowserOrigin;
        const uri = std.Uri.parse(origin) catch return error.InvalidBrowserOrigin;
        const host = uri.host orelse return error.InvalidBrowserOrigin;
        if (development and !(std.mem.eql(u8, host.percent_encoded, "127.0.0.1") or std.mem.eql(u8, host.percent_encoded, "localhost"))) return error.InvalidBrowserOrigin;
        return .{ .origin = origin, .authority = authority, .development = development };
    }
    pub fn check(self: Boundary, host: []const u8, origin: ?[]const u8, required: bool, fetch_site: ?[]const u8) !void {
        if (!std.ascii.eqlIgnoreCase(host, self.authority)) return error.BrowserHostDenied;
        if (origin) |value| {
            if (!std.mem.eql(u8, value, self.origin)) return error.BrowserOriginDenied;
        } else if (required) return error.BrowserOriginRequired;
        if (fetch_site) |value| if (!std.mem.eql(u8, value, "same-origin") and !std.mem.eql(u8, value, "none")) return error.BrowserOriginDenied;
    }
};
/// Duplicate target cookies reject instead of selecting a shadowed credential.
pub fn cookie(header: ?[]const u8, name: []const u8) !?[]const u8 {
    var value: ?[]const u8 = null;
    var parts = std.mem.splitScalar(u8, header orelse return null, ';');
    while (parts.next()) |part| {
        const item = std.mem.trim(u8, part, " \t");
        const equal = std.mem.indexOfScalar(u8, item, '=') orelse return error.InvalidCookie;
        if (std.mem.eql(u8, item[0..equal], name)) {
            if (value != null) return error.DuplicateCookie;
            const candidate = item[equal + 1 ..];
            if (!validToken(candidate)) return error.InvalidCookie;
            value = candidate;
        }
    }
    return value;
}
test "HTTP and WS require exact origin, never suffix or forwarded authority" {
    const b = try Boundary.init("https://www.spoke.sh", false);
    try b.check("www.spoke.sh", "https://www.spoke.sh", true, "same-origin");
    try b.check("www.spoke.sh", null, false, "same-origin");
    try std.testing.expectError(error.BrowserOriginRequired, b.check("www.spoke.sh", null, true, null));
    for ([_][]const u8{ "null", "https://www.spoke.sh.evil.test", "http://www.spoke.sh", "https://www.spoke.sh/", "https://evil.test" }) |origin| try std.testing.expectError(error.BrowserOriginDenied, b.check("www.spoke.sh", origin, true, null));
    try std.testing.expectError(error.BrowserHostDenied, b.check("internal.alb", b.origin, true, null));
    try std.testing.expectError(error.BrowserOriginDenied, b.check(b.authority, null, false, "cross-site"));
    try std.testing.expectError(error.InvalidBrowserOrigin, Boundary.init("http://0.0.0.0:8080", true));
}
test "identities are provider and client scoped; cookies cannot be shadowed" {
    const google = subject(.google, "client", "123");
    try std.testing.expect(!std.mem.eql(u8, &google, &subject(.github, "client", "123")));
    try std.testing.expect(!std.mem.eql(u8, &google, &subject(.google, "other", "123")));
    const token = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    try std.testing.expectEqualStrings(token, (try cookie("session=" ++ token, "session")).?);
    try std.testing.expectError(error.DuplicateCookie, cookie("session=" ++ token ++ "; session=" ++ token, "session"));
    try std.testing.expectError(error.InvalidCookie, cookie("session=bad", "session"));
}
test "PKCE uses the RFC 7636 S256 vector" {
    try std.testing.expectEqualStrings("E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", &challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"));
}
