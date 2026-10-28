//! Domain-separated identities for bounded database recovery metadata.
const std = @import("std");
pub fn internal(account: [32]u8, purpose: []const u8, source: []const u8) [32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.sql.internal.v1\x00");
    hash.update(&account);
    hash.update(purpose);
    hash.update(source);
    return hash.finalResult();
}
