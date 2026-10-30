//! Immutable index pages for data manifests, row locators and operation records.
//! Reuses the generic ordered tree; only the owning log can publish its root.
const std = @import("std");
const p = @import("transit_protocol");
pub const pages = @import("transit_core").pages;
const objects = @import("TransitObjectStore.zig");
const Self = @This();
const header_bytes = 40;
pub const max_resident_pages = 4096;
pub const max_batch_object_bytes = header_bytes + pages.max_encoded_bytes;
const Cached = struct { reference: pages.Reference, page: pages.Page };

pub const Batch = struct {
    keys: [objects.max_put_batch][96]u8 = undefined,
    key_lengths: [objects.max_put_batch]u8 = undefined,
    sha256s: [objects.max_put_batch][32]u8 = undefined,
    references: [objects.max_put_batch]?pages.Reference = @splat(null),
    buffers: [objects.max_put_batch][max_batch_object_bytes]u8 = undefined,
    lengths: [objects.max_put_batch]usize = undefined,
    count: usize = 0,
};

allocator: std.mem.Allocator,
store: objects.ObjectStore,
cache: []?Cached,
used: [max_resident_pages / 64]u64 = @splat(0),
next_slot: usize = 0,
hits: u64 = 0,
misses: u64 = 0,
/// Acknowledged staging calls and encoded payload bytes, including immutable
/// deduplication. Provider/device writes and failed attempts are separate.
staged_pages: u64 = 0,
staged_bytes: u64 = 0,
candidate: ?struct { limit: usize, staged: usize = 0, batch: ?*Batch = null } = null,

pub fn init(allocator: std.mem.Allocator, store: objects.ObjectStore, resident_pages: usize) !Self {
    if (resident_pages > max_resident_pages) return error.InvalidPageCacheBudget;
    const cache = try allocator.alloc(?Cached, resident_pages);
    @memset(cache, null);
    return .{ .allocator = allocator, .store = store, .cache = cache };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.cache);
    self.* = undefined;
}

/// Bounds a private mutation's encoded index work. This is independent of the
/// provider's physical quota, which also includes retained roots and orphans.
pub fn begin(self: *Self, byte_limit: usize) !void {
    if (self.candidate != null) return error.ActiveStorageCandidate;
    if (byte_limit == 0) return error.InvalidStorageBudget;
    self.candidate = .{ .limit = byte_limit };
}

pub fn beginBatch(self: *Self, byte_limit: usize, batch: *Batch) !void {
    if (self.candidate != null) return error.ActiveStorageCandidate;
    if (byte_limit == 0) return error.InvalidStorageBudget;
    batch.count = 0;
    self.candidate = .{ .limit = byte_limit, .batch = batch };
}

pub fn flush(self: *Self) !void {
    const candidate = if (self.candidate) |*value| value else return error.NoStorageCandidate;
    const batch = candidate.batch orelse return;
    if (batch.count == 0) return;
    const count = batch.count;
    var puts: [objects.max_put_batch]objects.ImmutablePut = undefined;
    var metas: [objects.max_put_batch]objects.ObjectMeta = undefined;
    for (0..count) |i| {
        puts[i] = .{
            .key = batch.keys[i][0..batch.key_lengths[i]],
            .bytes = batch.buffers[i][0..batch.lengths[i]],
            .sha256 = batch.sha256s[i],
        };
    }
    try self.store.putImmutableBatch(puts[0..count], metas[0..count]);
    for (puts[0..count], metas[0..count]) |put, meta| {
        if (meta.size != put.bytes.len or !std.mem.eql(u8, &meta.sha256, &put.sha256)) return error.InvalidDataIndexObject;
    }
    batch.count = 0;
}

pub fn stageObject(self: *Self, object_key: []const u8, bytes: []const u8, sha256: [32]u8) !objects.ObjectMeta {
    if (self.candidate) |*candidate| if (candidate.batch) |batch| {
        if (object_key.len <= 96 and bytes.len <= max_batch_object_bytes) {
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
            if (!std.mem.eql(u8, &digest, &sha256)) return error.ObjectDigestMismatch;
            const duplicate = for (0..batch.count) |i| {
                if (std.mem.eql(u8, batch.keys[i][0..batch.key_lengths[i]], object_key)) {
                    if (batch.lengths[i] != bytes.len or !std.mem.eql(u8, &batch.sha256s[i], &sha256)) return error.ImmutableObjectConflict;
                    break true;
                }
            } else false;
            if (!duplicate) {
                if (batch.count == objects.max_put_batch) try self.flush();
                const slot = batch.count;
                @memcpy(batch.keys[slot][0..object_key.len], object_key);
                batch.key_lengths[slot] = @intCast(object_key.len);
                batch.sha256s[slot] = sha256;
                batch.references[slot] = null;
                @memcpy(batch.buffers[slot][0..bytes.len], bytes);
                batch.lengths[slot] = bytes.len;
                batch.count += 1;
                if (batch.count == objects.max_put_batch) try self.flush();
            }
            return .{ .size = bytes.len, .sha256 = sha256 };
        }
    };
    return self.store.putImmutable(object_key, bytes, sha256);
}

/// Discarding private work never deletes objects or changes a published root.
pub fn end(self: *Self) void {
    if (self.candidate) |candidate| if (candidate.batch) |batch| {
        batch.count = 0;
    };
    self.candidate = null;
}

pub fn key(address: [32]u8, output: *[96]u8) ![]const u8 {
    if (std.mem.allEqual(u8, &address, 0)) return error.InvalidDataIndexReference;
    return std.fmt.bufPrint(output, "data-index/{x}.data", .{&address});
}

pub fn stage(self: *Self, reference: pages.Reference, page: *const pages.Page) !pages.Reference {
    if (!std.mem.allEqual(u8, &reference.location, 0)) return error.InvalidDataIndexReference;
    try reference.verify(page);
    var bytes: [header_bytes + pages.max_encoded_bytes]u8 = undefined;
    bytes[0..8].* = "TDIX\x01\x00\x00\x00".*;
    bytes[8..header_bytes].* = p.Growth.definition_bytes;
    const body = try page.encode(bytes[header_bytes..]);
    const encoded = bytes[0 .. header_bytes + body.len];
    const candidate = if (self.candidate) |*value| value else return error.NoStorageCandidate;
    if (encoded.len > candidate.limit - candidate.staged) return error.StorageCandidateTooLarge;
    // An uncertain creation retains its charge for this attempt.
    candidate.staged += encoded.len;
    var result = reference;
    std.crypto.hash.sha2.Sha256.hash(encoded, &result.location, .{});
    if (candidate.batch) |batch| {
        var name: [96]u8 = undefined;
        const object_key = try key(result.location, &name);
        const duplicate = for (0..batch.count) |i| {
            if (std.mem.eql(u8, batch.keys[i][0..batch.key_lengths[i]], object_key)) break true;
        } else false;
        if (!duplicate) {
            if (batch.count == objects.max_put_batch) try self.flush();
            const slot = batch.count;
            @memcpy(batch.keys[slot][0..object_key.len], object_key);
            batch.key_lengths[slot] = @intCast(object_key.len);
            batch.sha256s[slot] = result.location;
            batch.references[slot] = result;
            @memcpy(batch.buffers[slot][0..encoded.len], encoded);
            batch.lengths[slot] = encoded.len;
            batch.count += 1;
            if (batch.count == objects.max_put_batch) try self.flush();
        }
        self.staged_pages +|= 1;
        self.staged_bytes +|= encoded.len;
        self.remember(result, page.*, false);
        return result;
    }
    var name: [96]u8 = undefined;
    const accepted = try self.store.putImmutable(try key(result.location, &name), encoded, result.location);
    if (accepted.size != encoded.len or !std.mem.eql(u8, &accepted.sha256, &result.location)) return error.InvalidDataIndexObject;
    self.staged_pages +|= 1;
    self.staged_bytes +|= encoded.len;
    self.remember(result, page.*, false);
    return result;
}

pub noinline fn stageMany(self: *Self, batch: []const pages.Page, output: []pages.Reference) !void {
    if (batch.len != output.len or batch.len > pages.mutation_batch) return error.InvalidPageBatch;
    if (batch.len == 0) return;
    var buffers: [pages.mutation_batch][header_bytes + pages.max_encoded_bytes]u8 = undefined;
    var names: [pages.mutation_batch][96]u8 = undefined;
    var references: [pages.mutation_batch]pages.Reference = undefined;
    var puts: [pages.mutation_batch]objects.ImmutablePut = undefined;
    var metas: [pages.mutation_batch]objects.ObjectMeta = undefined;
    var lengths: [pages.mutation_batch]usize = undefined;
    var count: usize = 0;
    const candidate = if (self.candidate) |*value| value else return error.NoStorageCandidate;
    for (batch, buffers[0..batch.len], names[0..batch.len], references[0..batch.len], lengths[0..batch.len]) |*page, *bytes, *name, *reference, *length| {
        reference.* = try page.reference();
        bytes[0..8].* = "TDIX\x01\x00\x00\x00".*;
        bytes[8..header_bytes].* = p.Growth.definition_bytes;
        const body = try page.encode(bytes[header_bytes..]);
        const encoded = bytes[0 .. header_bytes + body.len];
        length.* = encoded.len;
        if (encoded.len > candidate.limit - candidate.staged) return error.StorageCandidateTooLarge;
        candidate.staged += encoded.len;
        std.crypto.hash.sha2.Sha256.hash(encoded, &reference.location, .{});
        const duplicate = for (puts[0..count]) |put| {
            if (std.mem.eql(u8, &put.sha256, &reference.location)) break true;
        } else false;
        if (!duplicate) {
            puts[count] = .{ .key = try key(reference.location, name), .bytes = encoded, .sha256 = reference.location };
            count += 1;
        }
    }
    if (candidate.batch) |staged_batch| {
        for (references[0..batch.len], buffers[0..batch.len], lengths[0..batch.len], names[0..batch.len]) |reference, *bytes, length, *name| {
            const object_key = try key(reference.location, name);
            const duplicate = for (0..staged_batch.count) |i| {
                if (std.mem.eql(u8, staged_batch.keys[i][0..staged_batch.key_lengths[i]], object_key)) break true;
            } else false;
            if (!duplicate) {
                if (staged_batch.count == objects.max_put_batch) try self.flush();
                const slot = staged_batch.count;
                @memcpy(staged_batch.keys[slot][0..object_key.len], object_key);
                staged_batch.key_lengths[slot] = @intCast(object_key.len);
                staged_batch.sha256s[slot] = reference.location;
                staged_batch.references[slot] = reference;
                @memcpy(staged_batch.buffers[slot][0..length], bytes[0..length]);
                staged_batch.lengths[slot] = length;
                staged_batch.count += 1;
                if (staged_batch.count == objects.max_put_batch) try self.flush();
            }
        }
    } else {
        try self.store.putImmutableBatch(puts[0..count], metas[0..count]);
        for (puts[0..count], metas[0..count]) |put, meta| {
            if (meta.size != put.bytes.len or !std.mem.eql(u8, &meta.sha256, &put.sha256)) return error.InvalidDataIndexObject;
        }
    }
    for (batch, references[0..batch.len], lengths[0..batch.len]) |*page, reference, length| {
        self.staged_pages +|= 1;
        self.staged_bytes +|= length;
        self.remember(reference, page.*, false);
    }
    @memcpy(output, references[0..batch.len]);
}

pub fn load(self: *Self, reference: pages.Reference) !pages.Page {
    for (self.cache, 0..) |slot, index| if (slot) |cached| {
        if (std.meta.eql(cached.reference, reference)) {
            self.hits +|= 1;
            self.markUsed(index);
            return cached.page;
        }
    };
    if (self.candidate) |candidate| if (candidate.batch) |batch| {
        for (batch.references[0..batch.count], 0..) |maybe_ref, i| if (maybe_ref) |staged_ref| {
            if (std.meta.eql(staged_ref, reference)) {
                self.misses +|= 1;
                const encoded = batch.buffers[i][0..batch.lengths[i]];
                const page = try pages.Page.decode(self.allocator, encoded[header_bytes..]);
                try reference.verify(&page);
                self.remember(reference, page, true);
                return page;
            }
        };
    };
    self.misses +|= 1;
    var name: [96]u8 = undefined;
    const object_key = try key(reference.location, &name);
    const metadata = try self.store.head(object_key) orelse return error.MissingDataIndexObject;
    var bytes: [header_bytes + pages.max_encoded_bytes]u8 = undefined;
    if (metadata.size < header_bytes or metadata.size > bytes.len or !std.mem.eql(u8, &metadata.sha256, &reference.location)) return error.InvalidDataIndexObject;
    const encoded = try self.store.getRange(object_key, 0, @intCast(metadata.size), &bytes);
    if (encoded.len != metadata.size) return error.InvalidDataIndexObject;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(encoded, &digest, .{});
    if (!std.mem.eql(u8, &digest, &reference.location)) return error.InvalidDataIndexObject;
    if (!std.mem.eql(u8, encoded[0..8], "TDIX\x01\x00\x00\x00")) return error.InvalidDataIndexObject;
    if (!std.mem.eql(u8, encoded[8..header_bytes], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const page = try pages.Page.decode(self.allocator, encoded[header_bytes..]);
    try reference.verify(&page);
    self.remember(reference, page, true);
    return page;
}

fn remember(self: *Self, reference: pages.Reference, page: pages.Page, accessed: bool) void {
    if (self.cache.len == 0) return;
    for (self.cache, 0..) |slot, index| if (slot) |cached| {
        if (std.meta.eql(cached.reference, reference)) {
            if (accessed) self.markUsed(index);
            return;
        }
    };
    for (0..self.cache.len * 2) |_| {
        const index = self.next_slot;
        self.next_slot = (self.next_slot + 1) % self.cache.len;
        if (self.cache[index] != null and self.isUsed(index)) {
            self.clearUsed(index);
            continue;
        }
        self.cache[index] = .{ .reference = reference, .page = page };
        if (accessed) self.markUsed(index) else self.clearUsed(index);
        return;
    }
}

fn markUsed(self: *Self, index: usize) void {
    self.used[index / 64] |= @as(u64, 1) << @intCast(index % 64);
}

fn clearUsed(self: *Self, index: usize) void {
    self.used[index / 64] &= ~(@as(u64, 1) << @intCast(index % 64));
}

fn isUsed(self: *const Self, index: usize) bool {
    return (self.used[index / 64] & (@as(u64, 1) << @intCast(index % 64))) != 0;
}

pub fn clearCache(self: *Self) void {
    @memset(self.cache, null);
    self.used = @splat(0);
    self.next_slot = 0;
}

pub fn residentBytes(self: *const Self) usize {
    return self.cache.len * @sizeOf(?Cached);
}
