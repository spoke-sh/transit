//! Explicit v1 KV decoders. Invalid application bytes become a typed error cell;
//! unsupported decoder declarations reject before any source row is consumed.
const std = @import("std");
const q = @import("root.zig");
const m = q.fuze.Unified;
pub fn decode(decoder: q.SourceDefinition.Decoder, allocator: std.mem.Allocator, bytes: []const u8) !m.Cell {
    try decoder.validate();
    if (bytes.len > q.protocol.Value.max_bytes) return error.CellTooLarge;
    const invalid: m.Cell = .{ .type_error = .unknown };
    const value: m.Scalar = switch (decoder.type) {
        .binary => .{ .binary = try allocator.dupe(u8, bytes) },
        .utf8 => if (std.unicode.utf8ValidateSlice(bytes)) .{ .utf8 = try allocator.dupe(u8, bytes) } else return invalid,
        .boolean => if (bytes.len == 1 and bytes[0] <= 1) .{ .boolean = bytes[0] == 1 } else return invalid,
        .int64 => if (bytes.len == 8) .{ .int64 = std.mem.readInt(i64, bytes[0..8], .little) } else return invalid,
        .uint64 => if (bytes.len == 8) .{ .uint64 = std.mem.readInt(u64, bytes[0..8], .little) } else return invalid,
        .float64 => blk: {
            if (bytes.len != 8) return invalid;
            const number: f64 = @bitCast(std.mem.readInt(u64, bytes[0..8], .little));
            if (!std.math.isFinite(number)) return invalid;
            break :blk .{ .float64 = number };
        },
    };
    return .{ .value = value };
}
