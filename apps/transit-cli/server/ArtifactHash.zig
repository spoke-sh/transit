//! Streaming executable identity, using the pinned crypto library's CPU dispatch.
//! The digest remains SHA-256 over every byte; this is not an identity cache.
const std = @import("std");
// Opaque public EVP declarations from the pinned openssl/evp.h. No library
// structure layout or provider implementation crosses this boundary.
const c = struct {
    const EVP_MD_CTX = opaque {};
    const EVP_MD = opaque {};
    extern fn EVP_MD_CTX_new() ?*EVP_MD_CTX;
    extern fn EVP_MD_CTX_free(context: *EVP_MD_CTX) void;
    extern fn EVP_sha256() ?*const EVP_MD;
    extern fn EVP_DigestInit_ex(context: *EVP_MD_CTX, algorithm: ?*const EVP_MD, engine: ?*anyopaque) c_int;
    extern fn EVP_DigestUpdate(context: *EVP_MD_CTX, bytes: [*]const u8, length: usize) c_int;
    extern fn EVP_DigestFinal_ex(context: *EVP_MD_CTX, bytes: [*]u8, length: *c_uint) c_int;
};
const Self = @This();

context: *c.EVP_MD_CTX,

pub fn init() !Self {
    const context = c.EVP_MD_CTX_new() orelse return error.OutOfMemory;
    errdefer c.EVP_MD_CTX_free(context);
    if (c.EVP_DigestInit_ex(context, c.EVP_sha256(), null) != 1) return error.ArtifactHashFailed;
    return .{ .context = context };
}

pub fn deinit(self: *Self) void {
    c.EVP_MD_CTX_free(self.context);
    self.* = undefined;
}

pub fn update(self: *Self, bytes: []const u8) !void {
    if (c.EVP_DigestUpdate(self.context, bytes.ptr, bytes.len) != 1) return error.ArtifactHashFailed;
}

pub fn final(self: *Self) ![32]u8 {
    var result: [32]u8 = undefined;
    var length: c_uint = 0;
    if (c.EVP_DigestFinal_ex(self.context, &result, &length) != 1 or length != result.len) return error.ArtifactHashFailed;
    return result;
}

test "artifact SHA-256 preserves known identities and arbitrary streaming boundaries" {
    const t = std.testing;
    for ([_]struct { bytes: []const u8, expected: []const u8 }{
        .{ .bytes = "", .expected = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" },
        .{ .bytes = "abc", .expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" },
    }) |fixture| {
        var hash = try Self.init();
        defer hash.deinit();
        for (fixture.bytes) |byte| try hash.update(&.{byte});
        try t.expectEqualStrings(fixture.expected, &std.fmt.bytesToHex(try hash.final(), .lower));
    }
    var bytes: [131101]u8 = undefined;
    for (&bytes, 0..) |*byte, i| byte.* = @truncate(i *% 73 +% 17);
    var expected: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&bytes, &expected, .{});
    for ([_]usize{ 1, 63, 64, 65, 65536 }) |chunk| {
        var hash = try Self.init();
        defer hash.deinit();
        var offset: usize = 0;
        while (offset < bytes.len) {
            const end = @min(bytes.len, offset + chunk);
            try hash.update(bytes[offset..end]);
            offset = end;
        }
        try t.expectEqual(expected, try hash.final());
    }
}
