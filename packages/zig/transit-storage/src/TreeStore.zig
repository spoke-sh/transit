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
candidate: ?struct { limit: usize, staged: usize = 0 } = null,

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

/// Discarding private work never deletes objects or changes a published root.
pub fn end(self: *Self) void {
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
    var name: [96]u8 = undefined;
    const accepted = try self.store.putImmutable(try key(result.location, &name), encoded, result.location);
    if (accepted.size != encoded.len or !std.mem.eql(u8, &accepted.sha256, &result.location)) return error.InvalidDataIndexObject;
    self.staged_pages +|= 1;
    self.staged_bytes +|= encoded.len;
    self.remember(result, page.*, false);
    return result;
}

pub fn stageMany(self: *Self, batch: []const pages.Page, output: []pages.Reference) !void {
    if (batch.len != output.len or batch.len > pages.mutation_batch) return error.InvalidPageBatch;
    for (batch, output) |page, *reference| reference.* = try self.stage(try page.reference(), &page);
}

pub fn load(self: *Self, reference: pages.Reference) !pages.Page {
    for (self.cache, 0..) |slot, index| if (slot) |cached| {
        if (std.meta.eql(cached.reference, reference)) {
            self.hits +|= 1;
            self.markUsed(index);
            return cached.page;
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
