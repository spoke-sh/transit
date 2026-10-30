//! Immutable index pages for data manifests, row locators and operation records.
//! Reuses the generic ordered tree; only the owning log can publish its root.
const std = @import("std");
const p = @import("transit_protocol");
pub const pages = @import("transit_core").pages;
const objects = @import("TransitObjectStore.zig");
const Self = @This();
const header_bytes = 40;
pub const max_resident_pages = 4096;
const Cached = struct { reference: pages.Reference, page: pages.Page };

pub const Batch = struct {
    references: [objects.max_put_batch]pages.Reference = undefined,
    buffers: [objects.max_put_batch][header_bytes + pages.max_encoded_bytes]u8 = undefined,
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
    var names: [objects.max_put_batch][96]u8 = undefined;
    var puts: [objects.max_put_batch]objects.ImmutablePut = undefined;
    var metas: [objects.max_put_batch]objects.ObjectMeta = undefined;
    for (0..count) |i| {
        const reference = batch.references[i];
        const encoded = batch.buffers[i][0..batch.lengths[i]];
        puts[i] = .{
            .key = try key(reference.location, &names[i]),
            .bytes = encoded,
            .sha256 = reference.location,
        };
    }
    try self.store.putImmutableBatch(puts[0..count], metas[0..count]);
    for (puts[0..count], metas[0..count]) |put, meta| {
        if (meta.size != put.bytes.len or !std.mem.eql(u8, &meta.sha256, &put.sha256)) return error.InvalidDataIndexObject;
    }
    batch.count = 0;
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
        const duplicate = for (batch.references[0..batch.count]) |existing| {
            if (std.mem.eql(u8, &existing.location, &result.location)) break true;
        } else false;
        if (!duplicate) {
            if (batch.count == objects.max_put_batch) try self.flush();
            batch.references[batch.count] = result;
            @memcpy(batch.buffers[batch.count][0..encoded.len], encoded);
            batch.lengths[batch.count] = encoded.len;
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
        for (references[0..batch.len], buffers[0..batch.len], lengths[0..batch.len]) |reference, *bytes, length| {
            const duplicate = for (staged_batch.references[0..staged_batch.count]) |existing| {
                if (std.mem.eql(u8, &existing.location, &reference.location)) break true;
            } else false;
            if (!duplicate) {
                if (staged_batch.count == objects.max_put_batch) try self.flush();
                staged_batch.references[staged_batch.count] = reference;
                @memcpy(staged_batch.buffers[staged_batch.count][0..length], bytes[0..length]);
                staged_batch.lengths[staged_batch.count] = length;
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
        for (batch.references[0..batch.count], 0..) |staged_ref, i| {
            if (std.meta.eql(staged_ref, reference)) {
                self.misses +|= 1;
                const encoded = batch.buffers[i][0..batch.lengths[i]];
                const page = try pages.Page.decode(self.allocator, encoded[header_bytes..]);
                try reference.verify(&page);
                self.remember(reference, page, true);
                return page;
            }
        }
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
