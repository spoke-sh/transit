//! Immutable, definition-bound `.tdel` sidecars using shared Roaring containers.
//! Resident capacity is bounded by one sidecar's byte budget, not row cardinality.
const std = @import("std");
const bitmap = @import("transit_bitmap");
const definition = @import("transit_protocol").Growth.definition_bytes;

pub const max_encoded_bytes: usize = 512 * 1024;
pub const header_bytes: usize = 4 + 1 + 32 + 8 + 4 + 4 + 4;
const Entry = struct { prefix: u16, offset: u32, length: u16, kind: bitmap.Kind, cardinality: u32 };

pub const DeletionVector = struct {
    allocator: std.mem.Allocator,
    segment_id: u64,
    total_rows: u32,
    deleted_count: u32 = 0,
    entries: []Entry,
    count: usize = 0,
    payload: []u8,
    used: usize = 0,

    pub fn init(allocator: std.mem.Allocator, segment_id: u64, total_rows: u32) !DeletionVector {
        return initBounded(allocator, segment_id, total_rows, max_encoded_bytes);
    }

    /// Reserve an explicit per-sidecar workspace once. Mutation never allocates.
    /// A full workspace refuses the mutation; it does not discard deletion bits.
    pub fn initBounded(allocator: std.mem.Allocator, segment_id: u64, total_rows: u32, byte_limit: usize) !DeletionVector {
        if (segment_id == 0 or byte_limit < header_bytes + 32 or byte_limit > max_encoded_bytes) return error.InvalidDeletionVector;
        const groups = (@as(u64, total_rows) + 65535) / 65536;
        const capacity: usize = @intCast(@min(byte_limit - header_bytes - 32, groups * (bitmap.max_encoded_bytes + 4), @as(u64, total_rows) * 2 + groups * 16));
        const entries = try allocator.alloc(Entry, @intCast(@min(groups, capacity / 18)));
        errdefer allocator.free(entries);
        const payload = try allocator.alloc(u8, capacity);
        return .{ .allocator = allocator, .segment_id = segment_id, .total_rows = total_rows, .entries = entries, .payload = payload };
    }

    pub fn deinit(self: *DeletionVector) void {
        self.allocator.free(self.entries);
        self.allocator.free(self.payload);
        self.* = undefined;
    }

    fn locate(self: *const DeletionVector, prefix: u16) usize {
        var lo: usize = 0;
        var hi = self.count;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (self.entries[mid].prefix < prefix) lo = mid + 1 else hi = mid;
        }
        return lo;
    }

    fn view(self: *const DeletionVector, entry: Entry) bitmap.View {
        return .{ .bytes = self.payload[entry.offset..][0..entry.length], .kind = entry.kind, .cardinality = entry.cardinality };
    }

    fn merge(self: *const DeletionVector, prefix: u16, scratch: *bitmap.Container) !void {
        scratch.clear();
        const index = self.locate(prefix);
        if (index < self.count and self.entries[index].prefix == prefix) try scratch.decode(self.view(self.entries[index]).bytes);
    }

    fn requireSpace(self: *const DeletionVector, count: usize, used: usize) !void {
        if (count > self.entries.len or used + count * 4 > self.payload.len) return error.DeletionVectorCapacityExceeded;
    }

    /// Input is canonical, nonempty, and disjoint from this workspace.
    fn replace(self: *DeletionVector, prefix: u16, bytes: []const u8) !void {
        const index = self.locate(prefix);
        const exists = index < self.count and self.entries[index].prefix == prefix;
        const old_len: usize = if (exists) self.entries[index].length else 0;
        const old_card: u32 = if (exists) self.entries[index].cardinality else 0;
        const offset: usize = if (index < self.count) self.entries[index].offset else self.used;
        const next_count = self.count + @intFromBool(!exists);
        const next_used = self.used - old_len + bytes.len;
        try self.requireSpace(next_count, next_used);
        const tail = self.used - offset - old_len;
        if (bytes.len > old_len) {
            std.mem.copyBackwards(u8, self.payload[offset + bytes.len ..][0..tail], self.payload[offset + old_len ..][0..tail]);
        } else {
            std.mem.copyForwards(u8, self.payload[offset + bytes.len ..][0..tail], self.payload[offset + old_len ..][0..tail]);
        }
        if (!exists) std.mem.copyBackwards(Entry, self.entries[index + 1 ..][0 .. self.count - index], self.entries[index..self.count]);
        for (self.entries[index + 1 .. next_count]) |*entry| entry.offset = @intCast(@as(usize, entry.offset) - old_len + bytes.len);
        @memcpy(self.payload[offset..][0..bytes.len], bytes);
        const cardinality = std.mem.readInt(u32, bytes[8..12], .little);
        self.entries[index] = .{ .prefix = prefix, .offset = @intCast(offset), .length = @intCast(bytes.len), .kind = @fromBackingInt(@intCast(bytes[4])), .cardinality = cardinality };
        self.count = next_count;
        self.used = next_used;
        self.deleted_count = self.deleted_count - old_card + cardinality;
    }

    pub fn markDeleted(self: *DeletionVector, row_offset: u32) !bool {
        if (row_offset >= self.total_rows) return error.RowOffsetOutOfBounds;
        if (self.isDeleted(row_offset)) return false;
        const prefix: u16 = @intCast(row_offset >> 16);
        var scratch: bitmap.Container = .{};
        try self.merge(prefix, &scratch);
        _ = scratch.set(@truncate(row_offset));
        var encoded: [bitmap.max_encoded_bytes]u8 = undefined;
        try self.replace(prefix, try scratch.encode(&encoded));
        return true;
    }

    pub fn isDeleted(self: *const DeletionVector, row_offset: u32) bool {
        if (row_offset >= self.total_rows) return false;
        const prefix: u16 = @intCast(row_offset >> 16);
        const index = self.locate(prefix);
        return index < self.count and self.entries[index].prefix == prefix and self.view(self.entries[index]).contains(@truncate(row_offset));
    }

    pub fn unionWith(self: *DeletionVector, other: *const DeletionVector) !void {
        if (self.segment_id != other.segment_id or self.total_rows != other.total_rows) return error.IncompatibleDeletionVector;
        if (self == other) return;
        var scratch: bitmap.Container = .{};
        var encoded: [bitmap.max_encoded_bytes]u8 = undefined;
        var next_count = self.count;
        var next_used = self.used;
        // Preflight the complete union, then shrink before growing. Failure
        // leaves every old bit intact, including when the final container grows.
        for (0..3) |pass| {
            for (other.entries[0..other.count]) |entry| {
                const index = self.locate(entry.prefix);
                const exists = index < self.count and self.entries[index].prefix == entry.prefix;
                const old_len: usize = if (exists) self.entries[index].length else 0;
                try self.merge(entry.prefix, &scratch);
                var it = other.view(entry).iterator();
                while (it.next()) |value| _ = scratch.set(value);
                const bytes = try scratch.encode(&encoded);
                if (pass == 0) {
                    next_count += @intFromBool(!exists);
                    next_used = next_used - old_len + bytes.len;
                } else if ((pass == 1 and bytes.len <= old_len) or (pass == 2 and bytes.len > old_len)) try self.replace(entry.prefix, bytes);
            }
            if (pass == 0) try self.requireSpace(next_count, next_used);
        }
    }

    pub fn encode(self: *const DeletionVector, out: []u8) ![]const u8 {
        var writer: std.Io.Writer = .fixed(out[0..@min(out.len, max_encoded_bytes)]);
        try writer.writeAll("TDEL");
        try writer.writeByte(1);
        try writer.writeAll(&definition);
        try writer.writeInt(u64, self.segment_id, .little);
        try writer.writeInt(u32, self.total_rows, .little);
        try writer.writeInt(u32, self.deleted_count, .little);
        try writer.writeInt(u32, @intCast(self.count), .little);
        for (self.entries[0..self.count]) |entry| {
            try writer.writeInt(u16, entry.prefix, .little);
            try writer.writeInt(u16, entry.length, .little);
            try writer.writeAll(self.view(entry).bytes);
        }
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(writer.buffered(), &digest, .{});
        try writer.writeAll(&digest);
        return writer.buffered();
    }

    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !DeletionVector {
        if (bytes.len < header_bytes + 32 or bytes.len > max_encoded_bytes) return error.InvalidDeletionVector;
        if (!std.mem.eql(u8, bytes[0..4], "TDEL") or bytes[4] != 1) return error.InvalidDeletionVector;
        if (!std.mem.eql(u8, bytes[5..37], &definition)) return error.IncompatibleDefinition;
        const payload = bytes[0 .. bytes.len - 32];
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(payload, &digest, .{});
        if (!std.mem.eql(u8, &digest, bytes[bytes.len - 32 ..])) return error.CorruptDeletionVector;
        const segment_id = std.mem.readInt(u64, bytes[37..45], .little);
        const total_rows = std.mem.readInt(u32, bytes[45..49], .little);
        const deleted_count = std.mem.readInt(u32, bytes[49..53], .little);
        const count = std.mem.readInt(u32, bytes[53..57], .little);
        if (segment_id == 0 or deleted_count > total_rows or count > (bytes.len - header_bytes - 32) / 18) return error.InvalidDeletionVector;
        // Validate before allocating; an untrusted row count cannot amplify
        // resident memory, and malformed containers never reach the read cache.
        var reader: std.Io.Reader = .fixed(payload[header_bytes..]);
        var previous: ?u16 = null;
        var cardinality: u64 = 0;
        for (0..count) |_| {
            const prefix = try reader.takeInt(u16, .little);
            const length = try reader.takeInt(u16, .little);
            if (previous) |prev| if (prefix <= prev) return error.InvalidDeletionVector;
            previous = prefix;
            const container = try bitmap.View.parse(try reader.take(length));
            if (container.cardinality == 0) return error.InvalidDeletionVector;
            const start = @as(u32, prefix) << 16;
            if (start >= total_rows) return error.InvalidDeletionVector;
            if (total_rows - start < 65536) {
                var it = container.iterator();
                while (it.next()) |offset| if (offset >= total_rows - start) return error.InvalidDeletionVector;
            }
            cardinality += container.cardinality;
        }
        if (cardinality != deleted_count or reader.bufferedLen() != 0) return error.InvalidDeletionVector;
        var vec = try init(allocator, segment_id, total_rows);
        errdefer vec.deinit();
        reader = .fixed(payload[header_bytes..]);
        for (0..count) |_| {
            const prefix = try reader.takeInt(u16, .little);
            const length = try reader.takeInt(u16, .little);
            try vec.replace(prefix, try reader.take(length));
        }
        return vec;
    }
};
