//! Selected Protocol 4.1 negotiation. Parsing establishes framing only; the
//! caller enforces transport policy before requesting a password.
const std = @import("std");
const m = @import("root.zig");
const g = m.wire;
pub const found_rows: u32 = 1 << 1;
pub const connect_database: u32 = 1 << 3;
pub const protocol_41: u32 = 1 << 9;
pub const ssl: u32 = 1 << 11;
pub const secure_connection: u32 = 1 << 15;
pub const plugin_auth: u32 = 1 << 19;
pub const connect_attributes: u32 = 1 << 20;
pub const length_auth: u32 = 1 << 21;
pub const deprecate_eof: u32 = 1 << 24;
pub const capabilities: u32 = 1 | (1 << 2) | found_rows | connect_database | protocol_41 | ssl | secure_connection | plugin_auth | connect_attributes | length_auth | deprecate_eof;
pub const required: u32 = protocol_41 | secure_connection | plugin_auth;
// Clients offer capabilities, including features the server does not advertise.
// Only the intersection selects protocol behavior. In particular the pinned
// Connector/Python offers MULTI_STATEMENTS by default; that does not admit a
// multi-statement query. Reserved extension bits still fail closed.
const known_offers: u32 = 0xdfffbfff;
pub const Prefix = struct {
    flags: u32,
    maximum_packet: u32,
    charset: u8,
    pub fn negotiated(self: Prefix) u32 {
        return self.flags & capabilities;
    }
    fn read(reader: *g.Bytes) !Prefix {
        const result: Prefix = .{ .flags = try reader.int(u32, .little), .maximum_packet = try reader.int(u32, .little), .charset = try reader.byte() };
        if (result.flags & required != required or result.flags & ~known_offers != 0) return error.UnsupportedWireCapabilities;
        // UTF8MB4 encoding only. The session selects and reports NO PAD binary
        // comparison collation 309; the one-byte negotiation cannot carry it.
        if (result.charset != 45 and result.charset != 46 and result.charset != 255) return error.UnsupportedWireCharset;
        for (try reader.take(23)) |byte| if (byte != 0) return error.InvalidWireMessage;
        return result;
    }
};
pub fn upgrade(payload: []const u8) !Prefix {
    var reader: g.Bytes = .{ .bytes = payload };
    const prefix = try Prefix.read(&reader);
    try reader.finish();
    if (prefix.flags & ssl == 0) return error.UnsupportedWireCapabilities;
    return prefix;
}
pub fn plaintext(payload: []const u8) !Prefix {
    var reader: g.Bytes = .{ .bytes = payload };
    const prefix = try Prefix.read(&reader);
    if (prefix.flags & ssl != 0) return error.UnsupportedWireCapabilities;
    return prefix;
}
pub const Response = struct { prefix: Prefix, account: []const u8, database: ?[]const u8, proof: []const u8 };
fn name(reader: *g.Bytes) ![]const u8 {
    const value = try reader.cstring(g.Limits.max_name_bytes);
    if (value.len == 0 or !std.unicode.utf8ValidateSlice(value)) return error.InvalidAuthentication;
    return value;
}
pub fn response(payload: []const u8, request: Prefix) !Response {
    if (payload.len > 8192) return error.FrameTooLarge;
    var reader: g.Bytes = .{ .bytes = payload };
    const prefix = try Prefix.read(&reader);
    if (!std.meta.eql(prefix, request)) return error.WireNegotiationChanged;
    const account = try name(&reader);
    const proof = if (prefix.flags & length_auth != 0) try m.Codec.string(&reader, 32) else try reader.take(try reader.byte());
    // Oracle's client encodes an absent caching_sha2 password as a single NUL;
    // other peers use zero bytes. Neither form authenticates a password login.
    if (proof.len != 0 and proof.len != 32 and !std.mem.eql(u8, proof, "\x00")) return error.InvalidAuthentication;
    const database = if (prefix.flags & connect_database != 0) try name(&reader) else null;
    if (!std.mem.eql(u8, try reader.cstring(64), "caching_sha2_password")) return error.UnsupportedAuthentication;
    if (prefix.flags & connect_attributes != 0) {
        var attributes: g.Bytes = .{ .bytes = try m.Codec.string(&reader, 4096) };
        var count: usize = 0;
        while (attributes.offset < attributes.bytes.len) {
            if (count == 32) return error.TooManyWireAttributes;
            _ = try m.Codec.string(&attributes, 1024);
            _ = try m.Codec.string(&attributes, 1024);
            count += 1;
        }
    }
    try reader.finish();
    return .{ .prefix = prefix, .account = account, .database = database, .proof = proof };
}
/// Full authentication is accepted only inside the established TLS session.
/// The caller immediately verifies and erases the password-bearing frame.
pub fn password(payload: []const u8) ![]const u8 {
    var reader: g.Bytes = .{ .bytes = payload };
    const result = try reader.cstring(g.Authentication.max_password_bytes);
    try reader.finish();
    if (result.len == 0) return error.InvalidAuthentication;
    return result;
}
test "TLS negotiation is exact, bounded and cannot change capabilities after upgrade" {
    const t = std.testing;
    var header: [32]u8 = @splat(0);
    std.mem.writeInt(u32, header[0..4], required | ssl | connect_database, .little);
    std.mem.writeInt(u32, header[4..8], 16 * 1024 * 1024, .little);
    header[8] = 255;
    const prefix = try upgrade(&header);
    const body = try std.mem.concat(t.allocator, u8, &.{ &header, "user\x00\x00database\x00caching_sha2_password\x00" });
    defer t.allocator.free(body);
    const parsed = try response(body, prefix);
    try t.expectEqualStrings("user", parsed.account);
    try t.expectEqualStrings("database", parsed.database.?);
    body[8] = 45;
    try t.expectError(error.WireNegotiationChanged, response(body, prefix));
    body[8] = 255;
    body[9] = 1;
    try t.expectError(error.InvalidWireMessage, response(body, prefix));
    try t.expectError(error.InvalidWireMessage, upgrade(header[0..31]));
    std.mem.writeInt(u32, header[0..4], required | ssl | (1 << 16), .little);
    try t.expectEqual(required | ssl, (try upgrade(&header)).negotiated());
    std.mem.writeInt(u32, header[0..4], required | ssl | (1 << 29), .little);
    try t.expectError(error.UnsupportedWireCapabilities, upgrade(&header));
    try t.expectEqualStrings("secret", try password("secret\x00"));
    try t.expectError(error.InvalidWireMessage, password("secret\x00extra"));
}
test "plaintext handshake preserves negotiation and cannot masquerade as TLS" {
    const t = std.testing;
    var header: [32]u8 = @splat(0);
    std.mem.writeInt(u32, header[0..4], required | connect_database, .little);
    header[8] = 255;
    const prefix = try plaintext(&header);
    try t.expectError(error.UnsupportedWireCapabilities, upgrade(&header));
    const body = try std.mem.concat(t.allocator, u8, &.{ &header, "owner\x00\x01\x00transit\x00caching_sha2_password\x00" });
    defer t.allocator.free(body);
    const parsed = try response(body, prefix);
    try t.expectEqualStrings("owner", parsed.account);
    try t.expectEqualStrings("\x00", parsed.proof);
    body[39] = 1;
    try t.expectError(error.InvalidAuthentication, response(body, prefix));
    std.mem.writeInt(u32, header[0..4], required | ssl, .little);
    try t.expectError(error.UnsupportedWireCapabilities, plaintext(&header));
}
