//! Sparse physical views retain original encoded identities and offsets. This
//! format is internal placement, never a new append or an ingestion decoder.
//! Caller-owned buffers bound both encoding and iteration; no allocation occurs.
const std = @import("std");
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const Batch = @import("LogBatch.zig");
pub const header_bytes = 77;
pub const row_header_bytes = 17;

pub const Encoder = struct {
    output: []u8,
    original_rows: u32,
    count: u32,
    emitted: u32 = 0,
    previous: ?u32 = null,
    at: usize = header_bytes,

    pub fn init(schema: f.TableSchema.Schema, original_rows: u32, count: u32, output: []u8) !Encoder {
        try schema.validate();
        if (original_rows == 0 or count > original_rows or output.len < header_bytes) return error.InvalidLogSegment;
        output[0..8].* = "LOGVIEW1".*;
        output[8..40].* = p.Growth.definition_bytes;
        output[40..72].* = try schema.layoutFingerprint();
        output[72] = 1; // Stream views only. Queue settlement has its own owner.
        std.mem.writeInt(u32, output[73..77], count, .big);
        return .{ .output = output, .original_rows = original_rows, .count = count };
    }
    pub fn append(self: *Encoder, row: Batch.EncodedRow) !void {
        if (self.emitted == self.count or row.ordinal >= self.original_rows or
            (self.previous != null and row.ordinal <= self.previous.?) or
            row.bytes.len < f.TableRow.header_bytes or row.bytes.len > f.TableRow.max_bytes or row.visible_ms != 0)
            return error.InvalidLogSegment;
        if (row_header_bytes + row.bytes.len > self.output.len - self.at) return error.LogSegmentBudgetExceeded;
        const out = self.output[self.at..];
        std.mem.writeInt(u32, out[0..4], row.ordinal, .big);
        std.mem.writeInt(u32, out[4..8], @intCast(row.bytes.len), .big);
        std.mem.writeInt(u64, out[8..16], row.visible_ms, .big);
        out[16] = @intFromBool(row.tombstone);
        @memcpy(out[row_header_bytes..][0..row.bytes.len], row.bytes);
        self.at += row_header_bytes + row.bytes.len;
        self.previous = row.ordinal;
        self.emitted += 1;
    }
    pub fn finish(self: Encoder) ![]const u8 {
        if (self.emitted != self.count) return error.InvalidLogSegment;
        return self.output[0..self.at];
    }
};

pub const Iterator = struct {
    bytes: []const u8,
    original_rows: u32,
    count: u32,
    emitted: u32 = 0,
    previous: ?u32 = null,
    at: usize = header_bytes,

    pub fn init(bytes: []const u8, schema: f.TableSchema.Schema, original_rows: u64) !Iterator {
        if (bytes.len < header_bytes or original_rows == 0 or original_rows > std.math.maxInt(u32) or
            !std.mem.eql(u8, bytes[0..8], "LOGVIEW1") or bytes[72] != 1) return error.InvalidLogSegment;
        if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
        if (!std.mem.eql(u8, bytes[40..72], &try schema.layoutFingerprint())) return error.TableSchemaChanged;
        const count = std.mem.readInt(u32, bytes[73..77], .big);
        if (count > original_rows or count > (bytes.len - header_bytes) / (row_header_bytes + f.TableRow.header_bytes) or
            (count == 0 and bytes.len != header_bytes)) return error.InvalidLogSegment;
        return .{ .bytes = bytes, .original_rows = @intCast(original_rows), .count = count };
    }
    pub fn next(self: *Iterator) !?Batch.EncodedRow {
        if (self.emitted == self.count) {
            if (self.at != self.bytes.len) return error.InvalidLogSegment;
            return null;
        }
        if (self.bytes.len - self.at < row_header_bytes) return error.InvalidLogSegment;
        const bytes = self.bytes[self.at..];
        const ordinal = std.mem.readInt(u32, bytes[0..4], .big);
        const length = std.mem.readInt(u32, bytes[4..8], .big);
        if (ordinal >= self.original_rows or (self.previous != null and ordinal <= self.previous.?) or
            length < f.TableRow.header_bytes or length > f.TableRow.max_bytes or length > bytes.len - row_header_bytes or
            std.mem.readInt(u64, bytes[8..16], .big) != 0 or bytes[16] > 1) return error.InvalidLogSegment;
        self.at += row_header_bytes + length;
        self.previous = ordinal;
        self.emitted += 1;
        if (self.emitted == self.count and self.at != self.bytes.len) return error.InvalidLogSegment;
        return .{ .ordinal = ordinal, .visible_ms = 0, .tombstone = bytes[16] != 0, .bytes = bytes[row_header_bytes..][0..length] };
    }
};

/// Placement chooses its format explicitly; malformed dense data cannot fall
/// through to another decoder. Both alternatives retain original row identity.
pub const Rows = union(enum) {
    complete: Batch.Iterator,
    sparse: Iterator,
    pub fn next(self: *Rows) !?Batch.EncodedRow {
        return switch (self.*) {
            inline else => |*iterator| iterator.next(),
        };
    }
};
