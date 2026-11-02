//! Bounded SQL string payloads for schema-bound ranges and dense vectors.
//! SQL quoting belongs to SqlTyped; this module interprets only the unquoted
//! payload against its declared logical domain, with no I/O or implicit type.
const std = @import("std");
const types = @import("Types.zig");
const ranges = @import("RangeValue.zig");
const vectors = @import("VectorValue.zig");
const metrics = @import("VectorMetric.zig");

fn trim(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \t\r\n");
}
pub fn range(subtype: types.Type, input: []const u8) !ranges.Value {
    try ranges.validateSubtype(subtype);
    const text = trim(input);
    if (std.ascii.eqlIgnoreCase(text, "empty")) return .{ .is_empty = true };
    if (text.len < 3 or (text[0] != '[' and text[0] != '(') or (text[text.len - 1] != ']' and text[text.len - 1] != ')')) return error.InvalidRangeLiteral;
    var parts = std.mem.splitScalar(u8, text[1 .. text.len - 1], ',');
    const lower = trim(parts.next() orelse return error.InvalidRangeLiteral);
    const upper = trim(parts.next() orelse return error.InvalidRangeLiteral);
    if (parts.next() != null) return error.InvalidRangeLiteral;
    return ranges.canonical(subtype, .{
        .lower = if (lower.len == 0) null else .{ .value = try types.Semantics.bind(lower, subtype), .inclusive = text[0] == '[' },
        .upper = if (upper.len == 0) null else .{ .value = try types.Semantics.bind(upper, subtype), .inclusive = text[text.len - 1] == ']' },
    });
}
/// The caller owns scratch and normalized output. Runs may coalesce, so the
/// returned slice is the exact resulting count, never the input capacity.
pub fn multirange(subtype: types.Type, input: []const u8, output: []ranges.Value) ![]const ranges.Value {
    const text = trim(input);
    if (text.len < 2 or text[0] != '{' or text[text.len - 1] != '}') return error.InvalidRangeLiteral;
    var remaining = trim(text[1 .. text.len - 1]);
    var count: usize = 0;
    while (remaining.len != 0) {
        if (count == output.len or count == (types.Limits{}).children) return error.MultiRangeBufferTooSmall;
        const end = std.mem.indexOfAny(u8, remaining, ")]") orelse return error.InvalidRangeLiteral;
        output[count] = try range(subtype, remaining[0 .. end + 1]);
        count += 1;
        remaining = trim(remaining[end + 1 ..]);
        if (remaining.len != 0) {
            if (remaining[0] != ',') return error.InvalidRangeLiteral;
            remaining = trim(remaining[1..]);
            if (remaining.len == 0) return error.InvalidRangeLiteral;
        }
    }
    return ranges.normalizeMulti(subtype, output[0..count], output);
}
/// Numeric vectors use [a,b,...]. BINARY vectors use exact hexadecimal bytes.
/// Output is caller-owned and cache-line aligned, independent of wire alignment.
pub fn vector(descriptor: vectors.Descriptor, input: []const u8, output: []align(vectors.alignment) u8) !vectors.Bytes {
    const required = try descriptor.byteLen();
    if (output.len < required) return error.VectorBufferTooSmall;
    const text = trim(input);
    if (descriptor.element == .binary) {
        if (text.len != required * 2) return error.VectorDimensionMismatch;
        _ = std.fmt.hexToBytes(output[0..required], text) catch return error.InvalidVectorLiteral;
        return output[0..required];
    }
    if (text.len < 2 or text[0] != '[' or text[text.len - 1] != ']') return error.InvalidVectorLiteral;
    var parts = std.mem.splitScalar(u8, text[1 .. text.len - 1], ',');
    for (0..descriptor.dimensions) |i| {
        const literal = trim(parts.next() orelse return error.VectorDimensionMismatch);
        if (literal.len == 0) return error.InvalidVectorLiteral;
        switch (descriptor.element) {
            .int8 => output[i] = @bitCast(std.fmt.parseInt(i8, literal, 10) catch return error.InvalidVectorLiteral),
            .float32, .float16, .bfloat16 => {
                const atom = try types.Semantics.bind(literal, .float32);
                const value: f32 = @floatCast(atom.float);
                switch (descriptor.element) {
                    .float32 => std.mem.writeInt(u32, output[i * 4 ..][0..4], @bitCast(value), .little),
                    .float16 => std.mem.writeInt(u16, output[i * 2 ..][0..2], @bitCast(@as(f16, @floatCast(value))), .little),
                    .bfloat16 => std.mem.writeInt(u16, output[i * 2 ..][0..2], metrics.f32ToBfloat16(value), .little),
                    else => unreachable,
                }
            },
            .binary => unreachable,
        }
    }
    if (parts.next() != null) return error.VectorDimensionMismatch;
    try vectors.validate(descriptor, output[0..required]);
    return output[0..required];
}

test "companion literals normalize declared ranges and preserve unboxed vector bytes" {
    const t = std.testing;
    const discrete = try range(.int64, "[1,3]");
    try t.expectEqual(@as(i128, 4), discrete.upper.?.value.signed);
    const continuous = try range(.{ .decimal = .{ .precision = 5, .scale = 2 } }, "(1.25,3.50]");
    try t.expectEqual(@as(i128, 125), continuous.lower.?.value.decimal);
    try t.expect(!continuous.lower.?.inclusive and continuous.upper.?.inclusive);
    var runs: [3]ranges.Value = undefined;
    const combined = try multirange(.int64, "{[3,5),[1,3),[9,10)}", &runs);
    try t.expectEqual(@as(usize, 2), combined.len);
    try t.expectEqual(@as(i128, 1), combined[0].lower.?.value.signed);
    try t.expectEqual(@as(i128, 5), combined[0].upper.?.value.signed);
    try t.expectError(error.InvalidRangeLiteral, multirange(.int64, "{[1,2),}", &runs));
    var bytes: [64]u8 align(vectors.alignment) = undefined;
    const float = try vector(.{ .dimensions = 2, .element = .float32 }, "[1.25,-0.0]", &bytes);
    try t.expectEqualSlices(u8, &.{ 0, 0, 0xa0, 0x3f, 0, 0, 0, 0x80 }, float);
    try t.expectError(error.VectorDimensionMismatch, vector(.{ .dimensions = 2, .element = .float32 }, "[1.25]", &bytes));
    try t.expectError(error.InvalidVectorValue, vector(.{ .dimensions = 1, .element = .float16 }, "[70000]", &bytes));
    try t.expectEqualSlices(u8, &.{ 0xaa, 0x55 }, try vector(.{ .dimensions = 16, .element = .binary }, "aa55", &bytes));
}
