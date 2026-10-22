//! Tier 2 local NVMe / disk block & range cache with SHA-256 verification and
//! scan-resistant W-TinyLFU / Clock eviction (protecting hot index/footer chunks
//! from sequential bulk-scan pollution).
const std = @import("std");
const TransitObjectStore = @import("TransitObjectStore.zig");

pub const default_chunk_bytes: usize = 64 * 1024; // 64 KiB range alignment

pub const CacheCategory = enum(u8) {
    /// Hot metadata: `.tseg` footers, Zone Maps, Bloom filters, PK B-Tree directories, `.tdel`, `.tman`.
    metadata_or_index = 0,
    /// Sequential or analytical column chunk payloads.
    column_data = 1,
};

const CacheEntry = struct {
    key: []u8,
    chunk_index: u32,
    bytes: []u8,
    sha256: [32]u8,
    category: CacheCategory,
    frequency: u8,
    referenced: bool,
};

pub const CacheStats = struct {
    hits: u64 = 0,
    misses: u64 = 0,
    evictions: u64 = 0,
    corrupt_reloads: u64 = 0,
    resident_bytes: usize = 0,
    entry_count: usize = 0,
};

pub const NvmeCache = struct {
    allocator: std.mem.Allocator,
    upstream: TransitObjectStore.ObjectStore,
    max_bytes: usize,
    chunk_bytes: usize,
    entries: std.ArrayListUnmanaged(CacheEntry) = .empty,
    clock_hand: usize = 0,
    stats: CacheStats = .{},

    pub fn init(
        allocator: std.mem.Allocator,
        upstream: TransitObjectStore.ObjectStore,
        max_bytes: usize,
    ) NvmeCache {
        return .{
            .allocator = allocator,
            .upstream = upstream,
            .max_bytes = @max(max_bytes, default_chunk_bytes),
            .chunk_bytes = default_chunk_bytes,
        };
    }

    pub fn deinit(self: *NvmeCache) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.bytes);
        }
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn getRangeVerified(
        self: *NvmeCache,
        key: []const u8,
        offset: u64,
        len: u32,
        category: CacheCategory,
        out: []u8,
    ) ![]const u8 {
        if (out.len < len) return error.BufferTooSmall;
        if (len == 0) return out[0..0];

        // If the requested range fits within a single chunk, serve through the chunk cache.
        const start_chunk: u32 = @intCast(offset / self.chunk_bytes);
        const end_chunk: u32 = @intCast((offset + len - 1) / self.chunk_bytes);
        if (start_chunk != end_chunk) {
            self.stats.misses += 1;
            return self.upstream.getRange(key, offset, len, out);
        }

        const chunk_offset = @as(u64, start_chunk) * self.chunk_bytes;
        const intra_offset: usize = @intCast(offset - chunk_offset);

        if (self.findEntry(key, start_chunk)) |idx| {
            const entry = &self.entries.items[idx];
            // Verify SHA-256 integrity on cached chunk before serving.
            var actual: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(entry.bytes, &actual, .{});
            if (!std.mem.eql(u8, &actual, &entry.sha256)) {
                self.stats.corrupt_reloads += 1;
                self.removeEntryAt(idx);
            } else if (intra_offset + len <= entry.bytes.len) {
                entry.referenced = true;
                entry.frequency = @min(@as(u8, 15), entry.frequency +| 1);
                if (category == .metadata_or_index) entry.category = .metadata_or_index;
                self.stats.hits += 1;
                @memcpy(out[0..len], entry.bytes[intra_offset .. intra_offset + len]);
                return out[0..len];
            } else {
                // Cached chunk was a partial tail and caller asked for more; reload.
                self.removeEntryAt(idx);
            }
        }

        self.stats.misses += 1;
        const meta = (try self.upstream.head(key)) orelse return error.ObjectNotFound;
        if (offset + len > meta.size) return error.RangeOutOfBounds;

        const remaining_in_object = meta.size - chunk_offset;
        const fetch_len: u32 = @intCast(@min(@as(u64, @intCast(self.chunk_bytes)), remaining_in_object));

        const chunk_buf = try self.allocator.alloc(u8, fetch_len);
        errdefer self.allocator.free(chunk_buf);

        const fetched = try self.upstream.getRange(key, chunk_offset, fetch_len, chunk_buf);
        if (fetched.len != fetch_len) return error.RangeOutOfBounds;

        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(fetched, &digest, .{});

        try self.insertChunk(key, start_chunk, chunk_buf, digest, category);
        @memcpy(out[0..len], fetched[intra_offset .. intra_offset + len]);
        return out[0..len];
    }

    pub fn corruptChunkForTesting(self: *NvmeCache, key: []const u8, chunk_index: u32) bool {
        if (self.findEntry(key, chunk_index)) |idx| {
            if (self.entries.items[idx].bytes.len > 0) {
                self.entries.items[idx].bytes[0] ^= 0xFF;
                return true;
            }
        }
        return false;
    }

    fn findEntry(self: *const NvmeCache, key: []const u8, chunk_index: u32) ?usize {
        for (self.entries.items, 0..) |entry, idx| {
            if (entry.chunk_index == chunk_index and std.mem.eql(u8, entry.key, key)) {
                return idx;
            }
        }
        return null;
    }

    fn removeEntryAt(self: *NvmeCache, idx: usize) void {
        const removed = self.entries.orderedRemove(idx);
        self.stats.resident_bytes -= removed.bytes.len;
        self.allocator.free(removed.key);
        self.allocator.free(removed.bytes);
        self.stats.entry_count = self.entries.items.len;
        if (self.clock_hand >= self.entries.items.len and self.entries.items.len > 0) {
            self.clock_hand = 0;
        }
    }

    fn insertChunk(
        self: *NvmeCache,
        key: []const u8,
        chunk_index: u32,
        chunk_buf: []u8,
        digest: [32]u8,
        category: CacheCategory,
    ) !void {
        while (self.stats.resident_bytes + chunk_buf.len > self.max_bytes and self.entries.items.len > 0) {
            self.evictOne(category);
        }
        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);

        try self.entries.append(self.allocator, .{
            .key = key_copy,
            .chunk_index = chunk_index,
            .bytes = chunk_buf,
            .sha256 = digest,
            .category = category,
            .frequency = if (category == .metadata_or_index) 4 else 1,
            .referenced = true,
        });
        self.stats.resident_bytes += chunk_buf.len;
        self.stats.entry_count = self.entries.items.len;
    }

    fn evictOne(self: *NvmeCache, incoming_category: CacheCategory) void {
        const n = self.entries.items.len;
        if (n == 0) return;

        // Pass 1: Prefer evicting unreferenced `.column_data` entries before `.metadata_or_index`
        // so sequential bulk scans never evict hot index/footer chunks.
        var scanned: usize = 0;
        while (scanned < n * 2) : (scanned += 1) {
            const idx = self.clock_hand % n;
            self.clock_hand = (self.clock_hand + 1) % n;
            const entry = &self.entries.items[idx];
            if (entry.category == .metadata_or_index and incoming_category == .column_data) {
                continue;
            }
            if (entry.referenced or entry.frequency > 1) {
                entry.referenced = false;
                entry.frequency -|= 1;
            } else {
                self.stats.evictions += 1;
                self.removeEntryAt(idx);
                return;
            }
        }

        // Fallback: evict first `.column_data` if available, else clock_hand.
        for (self.entries.items, 0..) |entry, idx| {
            if (entry.category == .column_data) {
                self.stats.evictions += 1;
                self.removeEntryAt(idx);
                return;
            }
        }
        self.stats.evictions += 1;
        self.removeEntryAt(self.clock_hand % n);
    }
};
