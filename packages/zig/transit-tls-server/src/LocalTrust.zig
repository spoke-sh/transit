//! Bounded local-only certificate issuance through the pinned TLS provider.
//! The installation owner persists the returned bundle atomically before use.
const std = @import("std");
const c = @import("OpenSsl.zig");
const Self = @This();
ca: []u8,
ca_key: []u8,
certificate: []u8,
key: []u8,
pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    inline for (@typeInfo(Self).@"struct".field_names) |name| {
        std.crypto.secureZero(u8, @field(self, name));
        allocator.free(@field(self, name));
    }
    self.* = undefined;
}
pub fn issue(allocator: std.mem.Allocator, io: std.Io) !Self {
    if (c.OpenSSL_version_num() != 0x30600040) return error.UnsupportedTlsLibrary;
    const ca_key = c.EVP_PKEY_Q_keygen(null, null, "EC", @as([*:0]const u8, "prime256v1")) orelse return error.TlsKeyGenerationFailed;
    defer c.EVP_PKEY_free(ca_key);
    const key = c.EVP_PKEY_Q_keygen(null, null, "EC", @as([*:0]const u8, "prime256v1")) orelse return error.TlsKeyGenerationFailed;
    defer c.EVP_PKEY_free(key);
    const ca = try issueCertificate(io, ca_key, "Transit local CA", 3650);
    defer c.X509_free(ca);
    try check(c.X509_set_issuer_name(ca, c.X509_get_subject_name(ca)));
    try extension(ca, "basicConstraints", "critical,CA:TRUE,pathlen:0");
    try extension(ca, "keyUsage", "critical,keyCertSign,cRLSign");
    if (c.X509_sign(ca, ca_key, c.EVP_sha256()) <= 0) return error.TlsCertificateGenerationFailed;
    const leaf = try issueCertificate(io, key, "localhost", 365);
    defer c.X509_free(leaf);
    try check(c.X509_set_issuer_name(leaf, c.X509_get_subject_name(ca)));
    try extension(leaf, "basicConstraints", "critical,CA:FALSE");
    try extension(leaf, "keyUsage", "critical,digitalSignature");
    try extension(leaf, "extendedKeyUsage", "serverAuth");
    try extension(leaf, "subjectAltName", "DNS:localhost,IP:127.0.0.1");
    if (c.X509_sign(leaf, ca_key, c.EVP_sha256()) <= 0) return error.TlsCertificateGenerationFailed;
    const ca_pem = try pem(allocator, ca);
    errdefer allocator.free(ca_pem);
    const ca_key_pem = try pem(allocator, ca_key);
    errdefer {
        std.crypto.secureZero(u8, ca_key_pem);
        allocator.free(ca_key_pem);
    }
    const leaf_pem = try pem(allocator, leaf);
    errdefer allocator.free(leaf_pem);
    return .{ .ca = ca_pem, .ca_key = ca_key_pem, .certificate = leaf_pem, .key = try pem(allocator, key) };
}
fn check(result: c_int) !void {
    if (result != 1) return error.TlsCertificateGenerationFailed;
}
fn issueCertificate(io: std.Io, key: *c.EVP_PKEY, name: []const u8, days: c_long) !*c.X509 {
    const result = c.X509_new() orelse return error.TlsAllocationFailed;
    errdefer c.X509_free(result);
    var serial: [8]u8 = undefined;
    try io.randomSecure(&serial);
    try check(c.X509_set_version(result, 2));
    try check(c.ASN1_INTEGER_set_uint64(c.X509_get_serialNumber(result), std.mem.readInt(u64, &serial, .little) | 1));
    // Allow five minutes of local clock skew; validity is never an execution grant.
    if (c.X509_gmtime_adj(c.X509_getm_notBefore(result), -300) == null or c.X509_gmtime_adj(c.X509_getm_notAfter(result), days * 86400) == null) return error.TlsCertificateGenerationFailed;
    try check(c.X509_set_pubkey(result, key));
    try check(c.X509_NAME_add_entry_by_txt(c.X509_get_subject_name(result), "CN", 0x1000, name.ptr, @intCast(name.len), -1, 0));
    return result;
}
fn extension(cert: *c.X509, name: [:0]const u8, value: [:0]const u8) !void {
    const nid = c.OBJ_txt2nid(name);
    if (nid == 0) return error.TlsCertificateGenerationFailed;
    const ext = c.X509V3_EXT_nconf_nid(null, null, nid, value) orelse return error.TlsCertificateGenerationFailed;
    defer c.X509_EXTENSION_free(ext);
    try check(c.X509_add_ext(cert, ext, -1));
}
fn pem(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    const bio = c.BIO_new(c.BIO_s_mem()) orelse return error.TlsAllocationFailed;
    defer _ = c.BIO_free(bio);
    const result = if (@TypeOf(value) == *c.X509) c.PEM_write_bio_X509(bio, value) else c.PEM_write_bio_PrivateKey(bio, value, null, null, 0, null, null);
    try check(result);
    const length = c.BIO_ctrl_pending(bio);
    if (length == 0 or length > 8192) return error.TlsCertificateGenerationFailed;
    const bytes = try allocator.alloc(u8, length);
    errdefer {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    }
    if (c.BIO_read(bio, bytes.ptr, @intCast(bytes.len)) != bytes.len) return error.TlsCertificateGenerationFailed;
    return bytes;
}
test "managed trust issues distinct bounded public certificates and private keys" {
    var trust = try issue(std.testing.allocator, std.testing.io);
    defer trust.deinit(std.testing.allocator);
    try std.testing.expect(std.mem.startsWith(u8, trust.ca, "-----BEGIN CERTIFICATE-----"));
    try std.testing.expect(std.mem.startsWith(u8, trust.key, "-----BEGIN PRIVATE KEY-----"));
    try std.testing.expect(!std.mem.eql(u8, trust.ca, trust.certificate));
    try std.testing.expect(!std.mem.eql(u8, trust.ca_key, trust.key));
}
