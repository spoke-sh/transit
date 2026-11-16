//! S3-compatible `TransitObjectStore` adapter with AWS Signature Version 4
//! (`AWS4-HMAC-SHA256`), conditional CAS (`If-None-Match` / `If-Match`), and
//! partial byte-range requests (`Range: bytes=start-end`).
const std = @import("std");

const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const Credentials = struct {
    access_key_id: []const u8,
    secret_access_key: []const u8,
    region: []const u8 = "us-east-1",
    service: []const u8 = "s3",
    session_token: ?[]const u8 = null,
};

/// Provider concurrency tokens are opaque; they are never content digests.
pub const Condition = union(enum) { if_none_match, if_match: []const u8 };
pub const Range = struct { offset: u64, len: u32 };

pub const SignedHeaders = struct {
    host: [256]u8 = undefined,
    host_len: usize = 0,
    amz_date: [16]u8 = undefined,
    payload_sha256_hex: [64]u8 = undefined,
    if_none_match: ?[]const u8 = null,
    if_match_buf: [256]u8 = undefined,
    if_match_len: usize = 0,
    range_buf: [64]u8 = undefined,
    range_len: usize = 0,
    authorization_buf: [512]u8 = undefined,
    authorization_len: usize = 0,

    pub fn authorization(self: *const SignedHeaders) []const u8 {
        return self.authorization_buf[0..self.authorization_len];
    }

    pub fn rangeHeader(self: *const SignedHeaders) ?[]const u8 {
        return if (self.range_len > 0) self.range_buf[0..self.range_len] else null;
    }

    pub fn ifMatchHeader(self: *const SignedHeaders) ?[]const u8 {
        return if (self.if_match_len > 0) self.if_match_buf[0..self.if_match_len] else null;
    }
};

pub fn signAwsV4Request(
    creds: Credentials,
    method: []const u8,
    host: []const u8,
    bucket: []const u8,
    key: []const u8,
    amz_date: [16]u8, // e.g. "20261022T160000Z"
    payload: []const u8,
    condition: ?Condition,
    range: ?Range,
) !SignedHeaders {
    if (key.len > 768) return error.InvalidObjectKey;
    for (key) |c| if (!std.ascii.isAlphanumeric(c) and std.mem.indexOfScalar(u8, "-_./", c) == null) return error.InvalidObjectKey;
    if (host.len == 0 or host.len > 256 or bucket.len == 0) return error.InvalidObjectKey;

    var out: SignedHeaders = .{ .amz_date = amz_date, .host_len = host.len };
    @memcpy(out.host[0..host.len], host);

    var payload_digest: [32]u8 = undefined;
    Sha256.hash(payload, &payload_digest, .{});
    out.payload_sha256_hex = std.fmt.bytesToHex(payload_digest, .lower);

    if (condition) |cond| switch (cond) {
        .if_none_match => out.if_none_match = "*",
        .if_match => |etag| {
            if (etag.len < 2 or etag.len > out.if_match_buf.len or etag[0] != '"' or etag[etag.len - 1] != '"') return error.InvalidProviderETag;
            for (etag) |c| if (c < 0x21 or c > 0x7e) return error.InvalidProviderETag;
            @memcpy(out.if_match_buf[0..etag.len], etag);
            out.if_match_len = etag.len;
        },
    };

    if (range) |r| {
        if (r.len > 0) {
            const end_inclusive = r.offset + r.len - 1;
            const formatted = try std.fmt.bufPrint(&out.range_buf, "bytes={d}-{d}", .{ r.offset, end_inclusive });
            out.range_len = formatted.len;
        }
    }

    var canonical_buf: [8192]u8 = undefined;
    var canonical_writer: std.Io.Writer = .fixed(&canonical_buf);
    try canonical_writer.print("{s}\n/{s}/{s}\n\n", .{ method, bucket, key });
    try canonical_writer.print("host:{s}\n", .{host});
    if (out.ifMatchHeader()) |im| {
        try canonical_writer.print("if-match:{s}\n", .{im});
    }
    if (out.if_none_match) |inm| {
        try canonical_writer.print("if-none-match:{s}\n", .{inm});
    }
    if (out.rangeHeader()) |rh| {
        try canonical_writer.print("range:{s}\n", .{rh});
    }
    try canonical_writer.print("x-amz-content-sha256:{s}\nx-amz-date:{s}\n", .{
        out.payload_sha256_hex,
        amz_date,
    });

    if (creds.session_token) |token| {
        if (token.len == 0 or token.len > 4096) return error.InvalidCredentials;
        for (token) |c| if (c < 0x21 or c > 0x7e) return error.InvalidCredentials;
        try canonical_writer.print("x-amz-security-token:{s}\n", .{token});
    }
    try canonical_writer.writeByte('\n');

    var signed_headers_buf: [256]u8 = undefined;
    var sh_writer: std.Io.Writer = .fixed(&signed_headers_buf);
    try sh_writer.writeAll("host");
    if (out.ifMatchHeader() != null) try sh_writer.writeAll(";if-match");
    if (out.if_none_match != null) try sh_writer.writeAll(";if-none-match");
    if (out.rangeHeader() != null) try sh_writer.writeAll(";range");
    try sh_writer.writeAll(";x-amz-content-sha256;x-amz-date");
    if (creds.session_token != null) try sh_writer.writeAll(";x-amz-security-token");
    const signed_headers = sh_writer.buffered();

    try canonical_writer.print("{s}\n{s}", .{ signed_headers, out.payload_sha256_hex });
    const canonical_request = canonical_writer.buffered();

    var canonical_digest: [32]u8 = undefined;
    Sha256.hash(canonical_request, &canonical_digest, .{});
    const canonical_hex = std.fmt.bytesToHex(canonical_digest, .lower);

    const date_stamp = amz_date[0..8];
    var string_to_sign_buf: [512]u8 = undefined;
    const string_to_sign = try std.fmt.bufPrint(
        &string_to_sign_buf,
        "AWS4-HMAC-SHA256\n{s}\n{s}/{s}/{s}/aws4_request\n{s}",
        .{ amz_date, date_stamp, creds.region, creds.service, canonical_hex },
    );

    var k_secret_buf: [128]u8 = undefined;
    const k_secret = try std.fmt.bufPrint(&k_secret_buf, "AWS4{s}", .{creds.secret_access_key});
    var k_date: [32]u8 = undefined;
    HmacSha256.create(&k_date, date_stamp, k_secret);
    var k_region: [32]u8 = undefined;
    HmacSha256.create(&k_region, creds.region, &k_date);
    var k_service: [32]u8 = undefined;
    HmacSha256.create(&k_service, creds.service, &k_region);
    var k_signing: [32]u8 = undefined;
    HmacSha256.create(&k_signing, "aws4_request", &k_service);
    var sig_bytes: [32]u8 = undefined;
    HmacSha256.create(&sig_bytes, string_to_sign, &k_signing);
    const sig_hex = std.fmt.bytesToHex(sig_bytes, .lower);

    const auth = try std.fmt.bufPrint(
        &out.authorization_buf,
        "AWS4-HMAC-SHA256 Credential={s}/{s}/{s}/{s}/aws4_request, SignedHeaders={s}, Signature={s}",
        .{ creds.access_key_id, date_stamp, creds.region, creds.service, signed_headers, sig_hex },
    );
    out.authorization_len = auth.len;
    return out;
}
