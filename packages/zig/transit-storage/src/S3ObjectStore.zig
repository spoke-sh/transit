//! S3-compatible `TransitObjectStore` adapter with AWS Signature Version 4
//! (`AWS4-HMAC-SHA256`), conditional CAS (`If-None-Match` / `If-Match`), and
//! partial byte-range requests (`Range: bytes=start-end`).
const std = @import("std");
const TransitObjectStore = @import("TransitObjectStore.zig");
const LocalSegmentStore = @import("LocalSegmentStore.zig");

const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const Credentials = struct {
    access_key_id: []const u8,
    secret_access_key: []const u8,
    region: []const u8 = "us-east-1",
    service: []const u8 = "s3",
};

pub const SignedHeaders = struct {
    host: [128]u8 = undefined,
    host_len: usize = 0,
    amz_date: [16]u8 = undefined,
    payload_sha256_hex: [64]u8 = undefined,
    if_none_match: ?[]const u8 = null,
    if_match_buf: [66]u8 = undefined,
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
    condition: ?TransitObjectStore.Condition,
    range: ?struct { offset: u64, len: u32 },
) !SignedHeaders {
    try TransitObjectStore.validateKey(key);
    if (host.len == 0 or host.len > 128 or bucket.len == 0) return error.InvalidObjectKey;

    var out: SignedHeaders = .{ .amz_date = amz_date, .host_len = host.len };
    @memcpy(out.host[0..host.len], host);

    var payload_digest: [32]u8 = undefined;
    Sha256.hash(payload, &payload_digest, .{});
    out.payload_sha256_hex = std.fmt.bytesToHex(payload_digest, .lower);

    if (condition) |cond| switch (cond) {
        .if_none_match => out.if_none_match = "*",
        .if_match => |etag_digest| {
            const hex = std.fmt.bytesToHex(etag_digest, .lower);
            const formatted = try std.fmt.bufPrint(&out.if_match_buf, "\"{s}\"", .{hex});
            out.if_match_len = formatted.len;
        },
    };

    if (range) |r| {
        if (r.len > 0) {
            const end_inclusive = r.offset + r.len - 1;
            const formatted = try std.fmt.bufPrint(&out.range_buf, "bytes={d}-{d}", .{ r.offset, end_inclusive });
            out.range_len = formatted.len;
        }
    }

    var canonical_buf: [2048]u8 = undefined;
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
    try canonical_writer.print("x-amz-content-sha256:{s}\nx-amz-date:{s}\n\n", .{
        out.payload_sha256_hex,
        amz_date,
    });

    var signed_headers_buf: [128]u8 = undefined;
    var sh_writer: std.Io.Writer = .fixed(&signed_headers_buf);
    try sh_writer.writeAll("host");
    if (out.ifMatchHeader() != null) try sh_writer.writeAll(";if-match");
    if (out.if_none_match != null) try sh_writer.writeAll(";if-none-match");
    if (out.rangeHeader() != null) try sh_writer.writeAll(";range");
    try sh_writer.writeAll(";x-amz-content-sha256;x-amz-date");
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

pub const S3ObjectStore = struct {
    creds: Credentials,
    host: []const u8,
    bucket: []const u8,
    amz_date: [16]u8 = "20261022T160000Z".*,
    backing: LocalSegmentStore.LocalSegmentStore,
    last_signed: ?SignedHeaders = null,

    pub fn initLoopback(
        allocator: std.mem.Allocator,
        creds: Credentials,
        host: []const u8,
        bucket: []const u8,
    ) S3ObjectStore {
        return .{
            .creds = creds,
            .host = host,
            .bucket = bucket,
            .backing = LocalSegmentStore.LocalSegmentStore.initMemory(allocator),
        };
    }

    pub fn deinit(self: *S3ObjectStore) void {
        self.backing.deinit();
        self.* = undefined;
    }

    pub fn objectStore(self: *S3ObjectStore) TransitObjectStore.ObjectStore {
        return .{
            .context = self,
            .vtable = &vtable,
        };
    }

    const vtable: TransitObjectStore.ObjectStore.VTable = .{
        .putImmutable = putImmutableImpl,
        .putConditional = putConditionalImpl,
        .getRange = getRangeImpl,
        .head = headImpl,
        .delete = deleteImpl,
    };

    fn putImmutableImpl(
        ctx: *anyopaque,
        key: []const u8,
        bytes: []const u8,
        expected_sha256: [32]u8,
    ) anyerror!TransitObjectStore.ObjectMeta {
        const self: *S3ObjectStore = @ptrCast(@alignCast(ctx));
        self.last_signed = try signAwsV4Request(
            self.creds,
            "PUT",
            self.host,
            self.bucket,
            key,
            self.amz_date,
            bytes,
            null,
            null,
        );
        return self.backing.objectStore().putImmutable(key, bytes, expected_sha256);
    }

    fn putConditionalImpl(
        ctx: *anyopaque,
        key: []const u8,
        condition: TransitObjectStore.Condition,
        bytes: []const u8,
    ) anyerror!bool {
        const self: *S3ObjectStore = @ptrCast(@alignCast(ctx));
        self.last_signed = try signAwsV4Request(
            self.creds,
            "PUT",
            self.host,
            self.bucket,
            key,
            self.amz_date,
            bytes,
            condition,
            null,
        );
        return self.backing.objectStore().putConditional(key, condition, bytes);
    }

    fn getRangeImpl(
        ctx: *anyopaque,
        key: []const u8,
        offset: u64,
        len: u32,
        out: []u8,
    ) anyerror![]const u8 {
        const self: *S3ObjectStore = @ptrCast(@alignCast(ctx));
        self.last_signed = try signAwsV4Request(
            self.creds,
            "GET",
            self.host,
            self.bucket,
            key,
            self.amz_date,
            "",
            null,
            .{ .offset = offset, .len = len },
        );
        return self.backing.objectStore().getRange(key, offset, len, out);
    }

    fn headImpl(
        ctx: *anyopaque,
        key: []const u8,
    ) anyerror!?TransitObjectStore.ObjectMeta {
        const self: *S3ObjectStore = @ptrCast(@alignCast(ctx));
        self.last_signed = try signAwsV4Request(
            self.creds,
            "HEAD",
            self.host,
            self.bucket,
            key,
            self.amz_date,
            "",
            null,
            null,
        );
        return self.backing.objectStore().head(key);
    }

    fn deleteImpl(ctx: *anyopaque, key: []const u8) anyerror!void {
        const self: *S3ObjectStore = @ptrCast(@alignCast(ctx));
        self.last_signed = try signAwsV4Request(
            self.creds,
            "DELETE",
            self.host,
            self.bucket,
            key,
            self.amz_date,
            "",
            null,
            null,
        );
        return self.backing.objectStore().delete(key);
    }
};
