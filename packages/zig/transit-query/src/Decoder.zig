//! Explicit v1 KV decoders. Invalid application bytes become a typed error cell;
//! unsupported decoder declarations reject before any source row is consumed.
const std = @import("std");
const q = @import("root.zig");
const m = q.fuze.Unified;
pub const Failure = struct {
    reason: enum { invalid_utf8, invalid_length, invalid_boolean, nonfinite_float },
    expected_bytes: ?u16 = null,
    actual_bytes: u16,
};
pub fn decode(decoder: q.SourceDefinition.Decoder, allocator: std.mem.Allocator, bytes: []const u8) !m.Cell {
    return decodeDiagnostic(decoder, allocator, bytes, null);
}
pub fn decodeDiagnostic(decoder: q.SourceDefinition.Decoder, allocator: std.mem.Allocator, bytes: []const u8, diagnostic: ?*?Failure) !m.Cell {
    if (diagnostic) |detail| detail.* = null;
    try decoder.validate();
    if (bytes.len > q.protocol.Value.max_bytes) return error.CellTooLarge;
    const failed = struct {
        fn cell(detail: ?*?Failure, reason: @FieldType(Failure, "reason"), expected: ?u16, actual: usize) m.Cell {
            if (detail) |value| value.* = .{ .reason = reason, .expected_bytes = expected, .actual_bytes = @intCast(actual) };
            return .{ .type_error = .unknown };
        }
    }.cell;
    const value: m.Scalar = switch (decoder.type) {
        .binary => .{ .binary = try allocator.dupe(u8, bytes) },
        .utf8 => if (std.unicode.utf8ValidateSlice(bytes)) .{ .utf8 = try allocator.dupe(u8, bytes) } else return failed(diagnostic, .invalid_utf8, null, bytes.len),
        .boolean => if (bytes.len == 1 and bytes[0] <= 1) .{ .boolean = bytes[0] == 1 } else return failed(diagnostic, if (bytes.len != 1) .invalid_length else .invalid_boolean, 1, bytes.len),
        .int64 => if (bytes.len == 8) .{ .int64 = std.mem.readInt(i64, bytes[0..8], .little) } else return failed(diagnostic, .invalid_length, 8, bytes.len),
        .uint64 => if (bytes.len == 8) .{ .uint64 = std.mem.readInt(u64, bytes[0..8], .little) } else return failed(diagnostic, .invalid_length, 8, bytes.len),
        .float64 => blk: {
            if (bytes.len != 8) return failed(diagnostic, .invalid_length, 8, bytes.len);
            const number: f64 = @bitCast(std.mem.readInt(u64, bytes[0..8], .little));
            if (!std.math.isFinite(number)) return failed(diagnostic, .nonfinite_float, 8, bytes.len);
            break :blk .{ .float64 = number };
        },
    };
    return .{ .value = value };
}
