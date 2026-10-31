//! RS256 verification against an operator-selected issuer's HTTPS JWKS.
//! Untrusted JWT headers never choose an algorithm, URL or trust root.
const std = @import("std");
const rsa = std.crypto.Certificate.rsa;
const Sha256 = std.crypto.hash.sha2.Sha256;
const Value = std.json.Value;
pub fn decode(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    if (value.len == 0 or value.len > 32768 or std.mem.indexOfScalar(u8, value, '=') != null) return error.InvalidIdToken;
    const decoder = std.base64.url_safe_no_pad.Decoder;
    const out = try allocator.alloc(u8, try decoder.calcSizeForSlice(value));
    errdefer allocator.free(out);
    try decoder.decode(out, value);
    return out;
}
pub fn string(object: Value, key: []const u8) ![]const u8 {
    if (object != .object) return error.InvalidProviderResponse;
    const value = object.object.get(key) orelse return error.InvalidProviderResponse;
    return if (value == .string) value.string else error.InvalidProviderResponse;
}
fn integer(object: Value, key: []const u8) !i64 {
    if (object != .object) return error.InvalidIdToken;
    const value = object.object.get(key) orelse return error.InvalidIdToken;
    return if (value == .integer) value.integer else error.InvalidIdToken;
}
pub fn verify(allocator: std.mem.Allocator, token: []const u8, jwks: []const u8, issuer: []const u8, client_id: []const u8, nonce: []const u8, now: i64) ![]const u8 {
    if (token.len > 32768 or jwks.len > 131072 or now < 0) return error.InvalidIdToken;
    var parts = std.mem.splitScalar(u8, token, '.');
    const header_text = parts.next() orelse return error.InvalidIdToken;
    const claims_text = parts.next() orelse return error.InvalidIdToken;
    const signature_text = parts.next() orelse return error.InvalidIdToken;
    if (parts.next() != null) return error.InvalidIdToken;
    const header_bytes = try decode(allocator, header_text);
    defer allocator.free(header_bytes);
    const header = try std.json.parseFromSlice(Value, allocator, header_bytes, .{});
    defer header.deinit();
    if (!std.mem.eql(u8, try string(header.value, "alg"), "RS256") or header.value.object.contains("crit") or header.value.object.contains("b64")) return error.InvalidIdToken;
    const kid = try string(header.value, "kid");
    if (kid.len == 0 or kid.len > 256) return error.InvalidIdToken;
    const keys = try std.json.parseFromSlice(Value, allocator, jwks, .{});
    defer keys.deinit();
    if (keys.value != .object) return error.InvalidJwks;
    const list = keys.value.object.get("keys") orelse return error.InvalidJwks;
    if (list != .array or list.array.items.len > 32) return error.InvalidJwks;
    var selected: ?Value = null;
    for (list.array.items) |key| {
        if (!std.mem.eql(u8, try string(key, "kid"), kid)) continue;
        if (selected != null) return error.AmbiguousJwksKey;
        selected = key;
    }
    const key = selected orelse return error.UnknownJwksKey;
    if (!std.mem.eql(u8, try string(key, "kty"), "RSA")) return error.InvalidJwks;
    if (key.object.get("alg")) |alg| if (alg != .string or !std.mem.eql(u8, alg.string, "RS256")) return error.InvalidJwks;
    if (key.object.get("use")) |use| if (use != .string or !std.mem.eql(u8, use.string, "sig")) return error.InvalidJwks;
    const n = try decode(allocator, try string(key, "n"));
    defer allocator.free(n);
    const e = try decode(allocator, try string(key, "e"));
    defer allocator.free(e);
    const signature = try decode(allocator, signature_text);
    defer allocator.free(signature);
    if (n.len == 0 or n[0] & 0x80 == 0 or signature.len != n.len or e.len == 0 or e.len > 4) return error.InvalidJwks;
    const public_key = try rsa.PublicKey.fromBytes(e, n);
    const message = token[0 .. header_text.len + 1 + claims_text.len];
    switch (n.len) {
        inline 256, 384, 512 => |size| try rsa.PKCS1v1_5Signature.verify(size, signature[0..size], message, public_key, Sha256),
        else => return error.InvalidJwks,
    }
    const claims_bytes = try decode(allocator, claims_text);
    defer allocator.free(claims_bytes);
    const claims = try std.json.parseFromSlice(Value, allocator, claims_bytes, .{});
    defer claims.deinit();
    const value = claims.value;
    if (!std.mem.eql(u8, try string(value, "iss"), issuer) or !std.mem.eql(u8, try string(value, "nonce"), nonce)) return error.InvalidIdToken;
    const audience = value.object.get("aud") orelse return error.InvalidIdToken;
    var matches = false;
    var multiple = false;
    switch (audience) {
        .string => |aud| matches = std.mem.eql(u8, aud, client_id),
        .array => |audiences| {
            if (audiences.items.len == 0 or audiences.items.len > 16) return error.InvalidIdToken;
            multiple = audiences.items.len > 1;
            for (audiences.items) |aud| {
                if (aud != .string) return error.InvalidIdToken;
                matches = matches or std.mem.eql(u8, aud.string, client_id);
            }
        },
        else => return error.InvalidIdToken,
    }
    if (!matches) return error.InvalidIdToken;
    if (multiple or value.object.contains("azp")) if (!std.mem.eql(u8, try string(value, "azp"), client_id)) return error.InvalidIdToken;
    const issued = try integer(value, "iat");
    const expiry = try integer(value, "exp");
    if (issued < 0 or issued > now + 30 or expiry <= now or expiry <= issued) return error.ExpiredIdToken;
    if (value.object.contains("nbf") and try integer(value, "nbf") > now + 30) return error.InvalidIdToken;
    const sub = try string(value, "sub");
    if (sub.len == 0 or sub.len > 255 or std.mem.indexOfScalar(u8, sub, 0) != null) return error.InvalidIdToken;
    return allocator.dupe(u8, sub);
}

test "independent OpenSSL signatures bind issuer audience nonce time and algorithm" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const fixtures = try std.json.parseFromSlice(Value, a, @embedFile("fixtures/oidc.json"), .{});
    defer fixtures.deinit();
    const jwks = try string(fixtures.value, "jwks");
    const valid = try string(fixtures.value, "valid");
    try t.expectEqualStrings("stable-123", try verify(a, valid, jwks, "https://accounts.google.com", "client", "nonce", 1700000300));
    for ([_][]const u8{ "wrong_audience", "wrong_nonce", "wrong_issuer", "future", "expired", "azp", "unknown_kid", "algorithm" }) |name| {
        if (verify(a, try string(fixtures.value, name), jwks, "https://accounts.google.com", "client", "nonce", 1700000300)) |_| return error.InvalidTokenAccepted else |_| {}
    }
    const tampered = try a.dupe(u8, valid);
    tampered[tampered.len - 30] = if (tampered[tampered.len - 30] == 'A') 'B' else 'A';
    if (verify(a, tampered, jwks, "https://accounts.google.com", "client", "nonce", 1700000300)) |_| return error.BadSignatureAccepted else |_| {}
}
