//! Immutable `.tdel` (`"TDEL"` v1) deletion vectors for `.tseg` segments.
//! Tracks deleted or superseded row offsets without rewriting immutable `.tseg` files.
const std = @import("std");
const definition = @import("transit_protocol").Growth.definition_bytes;

pub const max_encoded_bytes: usize = 512 * 1024;
pub const header_bytes: usize = 4 + 1 + 32 + 8 + 4 + 4;

pub const DeletionVector = struct {
    allocator: std.mem.Allocator,
    segment_id: u64,
    total_rows: u32,
    deleted: std.DynamicBitSetUnmanaged,
    deleted_count: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, segment_id: u64, total_rows: u32) !DeletionVector {
        if (segment_id == 0) return error.InvalidDeletionVector;
        const bitset = try std.DynamicBitSetUnmanaged.initEmpty(allocator, total_rows);
        return .{
            .allocator = allocator,
            .segment_id = segment_id,
            .total_rows = total_rows,
            .deleted = bitset,
            .deleted_count = 0,
        };
    }

    pub fn deinit(self: *DeletionVector) void {
        self.deleted.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn markDeleted(self: *DeletionVector, row_offset: u32) !bool {
        if (row_offset >= self.total_rows) return error.RowOffsetOutOfBounds;
        if (self.deleted.isSet(row_offset)) return false;
        self.deleted.set(row_offset);
        self.deleted_count += 1;
        return true;
    }

    pub fn isDeleted(self: *const DeletionVector, row_offset: u32) bool {
        if (row_offset >= self.total_rows) return false;
        return self.deleted.isSet(row_offset);
    }

    pub fn unionWith(self: *DeletionVector, other: *const DeletionVector) !void {
        if (self.segment_id != other.segment_id or self.total_rows != other.total_rows) return error.IncompatibleDeletionVector;
        var it = other.deleted.iterator(.{});
        while (it.next()) |idx| {
            _ = try self.markDeleted(@intCast(idx));
        }
    }

    /// Encode into canonical `"TDEL"` v1 binary format with sorted run/offset container
    /// and trailing SHA-256 integrity digest.
    pub fn encode(self: *const DeletionVector, out: []u8) ![]const u8 {
        var writer: std.Io.Writer = .fixed(out[0..@min(out.len, max_encoded_bytes)]);
        try writer.writeAll("TDEL");
        try writer.writeByte(1); // version 1
        try writer.writeAll(&definition);
        try writer.writeInt(u64, self.segment_id, .little);
        try writer.writeInt(u32, self.total_rows, .little);
        try writer.writeInt(u32, self.deleted_count, .little);

        var written: u32 = 0;
        var it = self.deleted.iterator(.{});
        while (it.next()) |idx| {
            try writer.writeInt(u32, @intCast(idx), .little);
            written += 1;
        }
        if (written != self.deleted_count) return error.InvalidDeletionVector;

        const body = writer.buffered();
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(body, &digest, .{});
        try writer.writeAll(&digest);
        return writer.buffered();
    }

    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !DeletionVector {
        if (bytes.len < header_bytes + 32 or bytes.len > max_encoded_bytes) return error.InvalidDeletionVector;
        if (!std.mem.eql(u8, bytes[0..4], "TDEL") or bytes[4] != 1) return error.InvalidDeletionVector;
        if (!std.mem.eql(u8, bytes[5..37], &definition)) return error.IncompatibleDefinition;

        const payload = bytes[0 .. bytes.len - 32];
        const expected_digest = bytes[bytes.len - 32 ..][0..32];
        var actual_digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(payload, &actual_digest, .{});
        if (!std.mem.eql(u8, &actual_digest, expected_digest)) return error.CorruptDeletionVector;

        var reader: std.Io.Reader = .fixed(payload[37..]);
        const segment_id = try reader.takeInt(u64, .little);
        const total_rows = try reader.takeInt(u32, .little);
        const deleted_count = try reader.takeInt(u32, .little);
        if (deleted_count > total_rows) return error.InvalidDeletionVector;

        var vec = try DeletionVector.init(allocator, segment_id, total_rows);
        errdefer vec.deinit();

        var prev: ?u32 = null;
        for (0..deleted_count) |_| {
            const offset = try reader.takeInt(u32, .little);
            if (offset >= total_rows) return error.InvalidDeletionVector;
            if (prev) |p| if (offset <= p) return error.InvalidDeletionVector;
            prev = offset;
            _ = try vec.markDeleted(offset);
        }
        if (reader.bufferedLen() != 0) return error.InvalidDeletionVector;
        return vec;
    }
};
