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

/// A bounded group of individually immutable objects. Success establishes all
/// publications; failure can leave any subset visible and must be retried with
/// the original keys/content. This is not an atomic multi-object visibility API.
pub const max_put_batch = 8;
pub const ImmutablePut = struct { key: []const u8, bytes: []const u8, sha256: [32]u8 };

pub fn validateBatch(batch: []const ImmutablePut, output: []ObjectMeta) !void {
    if (batch.len == 0 or batch.len > max_put_batch or batch.len != output.len) return error.InvalidObjectBatch;
    for (batch, 0..) |item, i| {
        try validateKey(item.key);
        if (item.bytes.len > max_object_bytes) return error.ObjectTooLarge;
        var actual: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(item.bytes, &actual, .{});
        if (!std.mem.eql(u8, &actual, &item.sha256)) return error.ObjectDigestMismatch;
        for (batch[0..i]) |previous| if (std.mem.eql(u8, item.key, previous.key)) return error.DuplicateObjectKey;
    }
}

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
    var components = std.mem.splitScalar(u8, key, '/');
    while (components.next()) |component| if (component.len == 0 or std.mem.eql(u8, component, ".")) return error.InvalidObjectKey;
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
        putImmutableBatch: ?*const fn (ctx: *anyopaque, batch: []const ImmutablePut, output: []ObjectMeta) anyerror!void = null,
        putConditional: *const fn (ctx: *anyopaque, key: []const u8, condition: Condition, bytes: []const u8) anyerror!bool,
        getRange: *const fn (ctx: *anyopaque, key: []const u8, offset: u64, length: u32, out: []u8) anyerror![]const u8,
        head: *const fn (ctx: *anyopaque, key: []const u8) anyerror!?ObjectMeta,
        delete: *const fn (ctx: *anyopaque, key: []const u8) anyerror!void,
    };

    pub fn putImmutable(self: ObjectStore, key: []const u8, bytes: []const u8, expected_sha256: [32]u8) !ObjectMeta {
        try validateKey(key);
        if (bytes.len > max_object_bytes) return error.ObjectTooLarge;
        var actual: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
        if (!std.mem.eql(u8, &actual, &expected_sha256)) return error.ObjectDigestMismatch;
        return self.vtable.putImmutable(self.context, key, bytes, expected_sha256);
    }

    /// Input slices are borrowed until return. Output is written only after all
    /// puts succeed, including for providers that implement individual puts.
    pub fn putImmutableBatch(self: ObjectStore, batch: []const ImmutablePut, output: []ObjectMeta) !void {
        try validateBatch(batch, output);
        var completed: [max_put_batch]ObjectMeta = undefined;
        if (self.vtable.putImmutableBatch) |put| {
            try put(self.context, batch, completed[0..batch.len]);
        } else {
            for (batch, completed[0..batch.len]) |item, *meta| meta.* = try self.putImmutable(item.key, item.bytes, item.sha256);
        }
        @memcpy(output, completed[0..batch.len]);
    }

    pub fn putConditional(self: ObjectStore, key: []const u8, condition: Condition, bytes: []const u8) !bool {
        try validateKey(key);
        if (bytes.len > max_object_bytes) return error.ObjectTooLarge;
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
