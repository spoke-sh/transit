//! `TransitObjectStore`: The immutable segment (`.tseg`, `.tdel`) and versioned
//! manifest (`TMAN1`) storage primitive.
//! Supports content-verified immutable puts, atomic `If-None-Match` / `If-Match`
//! conditional manifest publication, and byte-range reads.
const std = @import("std");

pub const max_key_bytes: usize = 256;
pub const max_object_bytes: usize = 32 * 1024 * 1024;

pub const ObjectMeta = struct {
    size: u64,
    sha256: [32]u8,
};

pub const Condition = union(enum) {
    if_none_match,
    if_match: [32]u8,
};

pub fn validateKey(key: []const u8) !void {
    if (key.len == 0 or key.len > max_key_bytes) return error.InvalidObjectKey;
    if (key[0] == '/' or key[key.len - 1] == '/') return error.InvalidObjectKey;
    if (std.mem.indexOf(u8, key, "..") != null or std.mem.indexOfScalar(u8, key, 0) != null) {
        return error.InvalidObjectKey;
    }
    for (key) |ch| {
        const ok = (ch >= 'a' and ch <= 'z') or
            (ch >= 'A' and ch <= 'Z') or
            (ch >= '0' and ch <= '9') or
            ch == '-' or ch == '_' or ch == '.' or ch == '/';
        if (!ok) return error.InvalidObjectKey;
    }
}

/// Pluggable `TransitObjectStore` backend interface (`LocalSegmentStore`, `S3ObjectStore`, `NvmeCache`).
pub const ObjectStore = struct {
    context: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        putImmutable: *const fn (ctx: *anyopaque, key: []const u8, bytes: []const u8, expected_sha256: [32]u8) anyerror!ObjectMeta,
        putConditional: *const fn (ctx: *anyopaque, key: []const u8, condition: Condition, bytes: []const u8) anyerror!bool,
        getRange: *const fn (ctx: *anyopaque, key: []const u8, offset: u64, length: u32, out: []u8) anyerror![]const u8,
        head: *const fn (ctx: *anyopaque, key: []const u8) anyerror!?ObjectMeta,
        delete: *const fn (ctx: *anyopaque, key: []const u8) anyerror!void,
    };

    pub fn putImmutable(self: ObjectStore, key: []const u8, bytes: []const u8, expected_sha256: [32]u8) !ObjectMeta {
        try validateKey(key);
        var actual: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
        if (!std.mem.eql(u8, &actual, &expected_sha256)) return error.ObjectDigestMismatch;
        return self.vtable.putImmutable(self.context, key, bytes, expected_sha256);
    }

    pub fn putConditional(self: ObjectStore, key: []const u8, condition: Condition, bytes: []const u8) !bool {
        try validateKey(key);
        return self.vtable.putConditional(self.context, key, condition, bytes);
    }

    pub fn getRange(self: ObjectStore, key: []const u8, offset: u64, length: u32, out: []u8) ![]const u8 {
        try validateKey(key);
        if (out.len < length) return error.BufferTooSmall;
        return self.vtable.getRange(self.context, key, offset, length, out);
    }

    pub fn head(self: ObjectStore, key: []const u8) !?ObjectMeta {
        try validateKey(key);
        return self.vtable.head(self.context, key);
    }

    pub fn delete(self: ObjectStore, key: []const u8) !void {
        try validateKey(key);
        return self.vtable.delete(self.context, key);
    }
};
