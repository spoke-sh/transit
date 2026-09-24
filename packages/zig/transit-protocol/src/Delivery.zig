//! Minimal courier observation. No application payloads or general inspection.
const std = @import("std");
const p = @import("root.zig");
pub const Query = struct { version: u32 = 1, realm: u64, principal: u8 };
pub const SignedQuery = struct { query: Query, signature: [64]u8 };
pub const Status = struct { version: u32 = 1, realm: u64, position: u64, principal_sequence: u64, pending: u16 };
pub fn digest(query: Query) [32]u8 {
    var bytes: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    std.json.Stringify.value(query, .{}, &writer) catch unreachable;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("rey.transit.delivery.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}
pub fn validate(query: Query) !void {
    if (query.version != 1 or query.realm == 0 or query.realm > p.max_counter or query.principal >= p.max_principals) return error.InvalidRead;
}
pub fn sign(query: Query, key: p.Ed25519.KeyPair) !SignedQuery {
    try validate(query);
    return .{ .query = query, .signature = (try key.sign(&digest(query), null)).toBytes() };
}
