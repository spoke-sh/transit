//! Bounded SCRAM-SHA-256 verifier and full-password TLS authentication.
//! The transport/account owner supplies secure nonces, verified TLS, admission
//! limits and current credential identity. This module performs no I/O.
const std = @import("std");
const g = @import("root.zig").native;
const Sha = std.crypto.hash.sha2.Sha256;
const Hmac = std.crypto.auth.hmac.sha2.HmacSha256;
const b64 = std.base64.standard;
pub const default_iterations = 65536;
pub const max_password_bytes = 128;
fn password(bytes: []const u8) !void {
    if (bytes.len == 0 or bytes.len > max_password_bytes) return error.InvalidPasswordProfile;
    // SASLprep is the identity for this explicitly selected printable-ASCII
    // credential profile. Do not normalize or silently accept other codepoints.
    for (bytes) |byte| if (byte < 0x20 or byte > 0x7e) return error.InvalidPasswordProfile;
}
pub const Verifier = struct {
    version: u8,
    definition: g.Definition,
    iterations: u32,
    salt: [16]u8,
    stored_key: [32]u8,
    server_key: [32]u8,
    pub fn validate(self: Verifier) !void {
        if (self.version != 1 or self.definition != g.current_definition) return error.IncompatibleCredentialDefinition;
        if (self.iterations < 4096 or self.iterations > 262144) return error.InvalidCredentialCost;
    }
    pub fn create(bytes: []const u8, salt: [16]u8, iterations: u32) !Verifier {
        try password(bytes);
        var result: Verifier = .{ .version = 1, .definition = g.current_definition, .iterations = iterations, .salt = salt, .stored_key = undefined, .server_key = undefined };
        try result.validate();
        var salted: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &salted);
        try std.crypto.pwhash.pbkdf2(&salted, bytes, &salt, iterations, Hmac);
        var client_key: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &client_key);
        Hmac.create(&client_key, "Client Key", &salted);
        Sha.hash(&client_key, &result.stored_key, .{});
        Hmac.create(&result.server_key, "Server Key", &salted);
        return result;
    }
    /// MySQL caching_sha2_password full-authentication path. The caller must
    /// require TLS before accepting the NUL-terminated password and erase it.
    pub fn verifyPassword(self: Verifier, bytes: []const u8) !void {
        try self.validate();
        var actual = try create(bytes, self.salt, self.iterations);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&actual));
        if (!std.crypto.timing_safe.eql([32]u8, actual.stored_key, self.stored_key)) return error.AuthenticationFailed;
    }
};
pub const Scram = struct {
    verifier: Verifier,
    gs2: [3]u8,
    client: [512]u8 = undefined,
    client_len: u16,
    server: [512]u8 = undefined,
    server_len: u16,
    nonce: [320]u8 = undefined,
    nonce_len: u16,
    finished: bool = false,
    pub fn init(verifier: Verifier, first: []const u8, random: [18]u8) !Scram {
        try verifier.validate();
        if (first.len < 3 or first.len > 512 or (!std.mem.startsWith(u8, first, "n,,") and !std.mem.startsWith(u8, first, "y,,"))) return error.InvalidScramMessage;
        const bare = first[3..];
        if (!std.mem.startsWith(u8, bare, "n=")) return error.InvalidScramMessage;
        const comma = std.mem.indexOf(u8, bare, ",r=") orelse return error.InvalidScramMessage;
        const user = bare[2..comma];
        if (user.len > 63 or std.mem.indexOfScalar(u8, user, ',') != null) return error.InvalidScramMessage;
        for (user) |byte| if (byte < 0x21 or byte > 0x7e) return error.InvalidScramMessage;
        const nonce = bare[comma + 3 ..];
        if (nonce.len < 16 or nonce.len > 256) return error.InvalidScramMessage;
        for (nonce) |byte| if (byte < 0x21 or byte > 0x7e or byte == ',') return error.InvalidScramMessage;
        var result: Scram = .{ .verifier = verifier, .gs2 = first[0..3].*, .client_len = @intCast(bare.len), .server_len = 0, .nonce_len = @intCast(nonce.len + 24) };
        @memcpy(result.client[0..bare.len], bare);
        @memcpy(result.nonce[0..nonce.len], nonce);
        _ = b64.Encoder.encode(result.nonce[nonce.len..][0..24], &random);
        var salt: [24]u8 = undefined;
        const encoded_challenge = try std.fmt.bufPrint(&result.server, "r={s},s={s},i={d}", .{ result.nonce[0..result.nonce_len], b64.Encoder.encode(&salt, &verifier.salt), verifier.iterations });
        result.server_len = @intCast(encoded_challenge.len);
        return result;
    }
    /// Native sessions bind the authenticated transcript to the destination,
    /// selected account/database/source and current contract definition.
    pub fn initBound(verifier: Verifier, first: []const u8, random: [18]u8, binding: [32]u8) !Scram {
        var result = try init(verifier, first, random);
        const suffix = try std.fmt.bufPrint(result.server[result.server_len..], ",b={s}", .{std.fmt.bytesToHex(binding, .lower)});
        result.server_len += @intCast(suffix.len);
        return result;
    }
    pub fn challenge(self: *const Scram) []const u8 {
        return self.server[0..self.server_len];
    }
    pub fn deinit(self: *Scram) void {
        std.crypto.secureZero(u8, std.mem.asBytes(self));
        self.finished = true;
    }
    /// Consumes the attempt on either success or failure. The returned server
    /// proof owns its bytes; no password or proof is logged or retained.
    pub fn finish(self: *Scram, final: []const u8) ![46]u8 {
        if (self.finished) return error.AuthenticationFailed;
        defer self.deinit();
        var channel: [4]u8 = undefined;
        var prefix: [512]u8 = undefined;
        const without_proof = try std.fmt.bufPrint(&prefix, "c={s},r={s}", .{ b64.Encoder.encode(&channel, &self.gs2), self.nonce[0..self.nonce_len] });
        if (final.len != without_proof.len + 3 + 44 or !std.mem.startsWith(u8, final, without_proof) or !std.mem.eql(u8, final[without_proof.len..][0..3], ",p=")) return error.InvalidScramMessage;
        var proof: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &proof);
        b64.Decoder.decode(&proof, final[without_proof.len + 3 ..]) catch return error.InvalidScramMessage;
        var canonical: [44]u8 = undefined;
        if (!std.mem.eql(u8, b64.Encoder.encode(&canonical, &proof), final[without_proof.len + 3 ..])) return error.InvalidScramMessage;
        var message: [1536]u8 = undefined;
        const auth = try std.fmt.bufPrint(&message, "{s},{s},{s}", .{ self.client[0..self.client_len], self.challenge(), without_proof });
        var signature: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &signature);
        Hmac.create(&signature, auth, &self.verifier.stored_key);
        for (&proof, signature) |*byte, mask| byte.* ^= mask;
        var actual: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &actual);
        Sha.hash(&proof, &actual, .{});
        if (!std.crypto.timing_safe.eql([32]u8, actual, self.verifier.stored_key)) return error.AuthenticationFailed;
        Hmac.create(&signature, auth, &self.verifier.server_key);
        var result: [46]u8 = undefined;
        result[0..2].* = "v=".*;
        _ = b64.Encoder.encode(result[2..46], &signature);
        return result;
    }
};
test "SCRAM matches independent hashlib and consumes invalid and rotated attempts" {
    const t = std.testing;
    const Fixture = struct { password: []const u8, salt: [16]u8, iterations: u32, stored_key: [32]u8, server_key: [32]u8, random: [18]u8, first: []const u8, challenge: []const u8, final: []const u8, server_final: []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/auth.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    const verifier = try Verifier.create(fixture.password, fixture.salt, fixture.iterations);
    try t.expectEqualSlices(u8, &fixture.stored_key, &verifier.stored_key);
    try t.expectEqualSlices(u8, &fixture.server_key, &verifier.server_key);
    try verifier.verifyPassword(fixture.password);
    try t.expectError(error.AuthenticationFailed, verifier.verifyPassword("wrong"));
    try t.expectError(error.InvalidPasswordProfile, verifier.verifyPassword("non-ASCII-東京"));
    var session = try Scram.init(verifier, fixture.first, fixture.random);
    try t.expectEqualStrings(fixture.challenge, session.challenge());
    try t.expectEqualStrings(fixture.server_final, &try session.finish(fixture.final));
    try t.expectError(error.AuthenticationFailed, session.finish(fixture.final));
    var rotated = try Scram.init(try Verifier.create("replacement", fixture.salt, fixture.iterations), fixture.first, fixture.random);
    try t.expectError(error.AuthenticationFailed, rotated.finish(fixture.final));
    var broken = try Scram.init(verifier, fixture.first, fixture.random);
    try t.expectError(error.InvalidScramMessage, broken.finish("c=biws,r=foreign,p=bad"));
    try t.expectError(error.AuthenticationFailed, broken.finish(fixture.final));
    try t.expectError(error.InvalidScramMessage, Scram.init(verifier, "p=tls-server-end-point,,n=,r=1234567890123456", fixture.random));
    try t.expectError(error.InvalidCredentialCost, Verifier.create("password", fixture.salt, 1));
}

/// One client exchange. Password-derived bytes are wiped before returning;
/// retain only the expected server signature until it is verified once.
pub const ClientProof = struct {
    final: [512]u8,
    length: u16,
    expected: [32]u8,
    pub fn message(self: *const ClientProof) []const u8 {
        return self.final[0..self.length];
    }
    pub fn deinit(self: *ClientProof) void {
        std.crypto.secureZero(u8, std.mem.asBytes(self));
    }
    pub fn verify(self: *ClientProof, final: []const u8) !void {
        defer self.deinit();
        if (final.len != 46 or !std.mem.startsWith(u8, final, "v=")) return error.AuthenticationFailed;
        var actual: [32]u8 = undefined;
        b64.Decoder.decode(&actual, final[2..]) catch return error.AuthenticationFailed;
        if (!std.crypto.timing_safe.eql([32]u8, actual, self.expected)) return error.AuthenticationFailed;
    }
    pub fn create(secret: []const u8, first: []const u8, challenge: []const u8, binding: ?[32]u8) !ClientProof {
        try password(secret);
        if (first.len > 512 or !std.mem.startsWith(u8, first, "n,,n=")) return error.InvalidScramMessage;
        const comma = std.mem.indexOf(u8, first, ",r=") orelse return error.InvalidScramMessage;
        const client_nonce = first[comma + 3 ..];
        var parts = std.mem.splitScalar(u8, challenge, ',');
        const nonce = parts.next() orelse return error.InvalidScramMessage;
        const salt = parts.next() orelse return error.InvalidScramMessage;
        const iterations = parts.next() orelse return error.InvalidScramMessage;
        if (!std.mem.startsWith(u8, nonce, "r=") or !std.mem.startsWith(u8, salt, "s=") or !std.mem.startsWith(u8, iterations, "i=") or !std.mem.startsWith(u8, nonce[2..], client_nonce) or nonce.len != client_nonce.len + 26) return error.InvalidScramMessage;
        if (binding) |expected| {
            const selected = parts.next() orelse return error.InvalidScramMessage;
            var bound: [66]u8 = undefined;
            if (!std.mem.eql(u8, selected, try std.fmt.bufPrint(&bound, "b={s}", .{std.fmt.bytesToHex(expected, .lower)}))) return error.AuthenticationFailed;
        }
        if (parts.next() != null or salt.len != 26) return error.InvalidScramMessage;
        var raw_salt: [16]u8 = undefined;
        b64.Decoder.decode(&raw_salt, salt[2..]) catch return error.InvalidScramMessage;
        const cost = std.fmt.parseInt(u32, iterations[2..], 10) catch return error.InvalidCredentialCost;
        if (cost < 4096 or cost > 262144) return error.InvalidCredentialCost;
        var salted: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &salted);
        try std.crypto.pwhash.pbkdf2(&salted, secret, &raw_salt, cost, Hmac);
        var client_key: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &client_key);
        Hmac.create(&client_key, "Client Key", &salted);
        var stored: [32]u8 = undefined;
        Sha.hash(&client_key, &stored, .{});
        var server_key: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &server_key);
        Hmac.create(&server_key, "Server Key", &salted);
        var result: ClientProof = .{ .final = undefined, .length = 0, .expected = undefined };
        const bare = try std.fmt.bufPrint(&result.final, "c=biws,{s}", .{nonce});
        var scratch: [1536]u8 = undefined;
        const transcript = try std.fmt.bufPrint(&scratch, "{s},{s},{s}", .{ first[3..], challenge, bare });
        var proof: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &proof);
        Hmac.create(&proof, transcript, &stored);
        for (&proof, client_key) |*byte, mask| byte.* ^= mask;
        Hmac.create(&result.expected, transcript, &server_key);
        var encoded: [44]u8 = undefined;
        const suffix = try std.fmt.bufPrint(result.final[bare.len..], ",p={s}", .{b64.Encoder.encode(&encoded, &proof)});
        result.length = @intCast(bare.len + suffix.len);
        return result;
    }
};
test "native SCRAM verifies server proof and destination transcript binding" {
    const t = std.testing;
    const verifier = try Verifier.create("local secret", @splat(1), 4096);
    const first = "n,,n=owner,r=123456789012345678901234";
    var server = try Scram.initBound(verifier, first, @splat(2), @splat(3));
    defer server.deinit();
    try t.expectError(error.AuthenticationFailed, ClientProof.create("local secret", first, server.challenge(), @splat(4)));
    var client = try ClientProof.create("local secret", first, server.challenge(), @splat(3));
    defer client.deinit();
    try client.verify(&try server.finish(client.message()));
    var unbound = try Scram.init(verifier, first, @splat(2));
    defer unbound.deinit();
    try t.expectError(error.InvalidScramMessage, ClientProof.create("local secret", first, unbound.challenge(), @splat(3)));
}
