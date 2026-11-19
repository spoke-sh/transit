//! Dense logical values use one 64-byte-aligned slab with no element tags.
//! The descriptor is logical shape only; the column/operation owns its metric.
const std = @import("std");
const metrics = @import("VectorMetric.zig");
pub const alignment = metrics.slab_alignment;
pub const Bytes = []align(alignment) const u8;
pub const Descriptor = struct {
    dimensions: u32,
    element: metrics.ElementType,

    pub fn byteLen(self: Descriptor) !usize {
        return self.element.byteSizeForDimensions(self.dimensions);
    }
    pub fn validate(self: Descriptor) !void {
        _ = try self.byteLen();
    }
};

/// Canonical little-endian element bytes; signed zero is preserved. Non-finite
/// floating elements reject independently of the chosen distance metric.
pub fn validate(descriptor: Descriptor, bytes: []const u8) !void {
    if (bytes.len != try descriptor.byteLen()) return error.VectorDimensionMismatch;
    switch (descriptor.element) {
        .binary, .int8 => {},
        .float32, .float16, .bfloat16 => for (0..descriptor.dimensions) |i| {
            const value: f32 = switch (descriptor.element) {
                .float32 => @bitCast(std.mem.readInt(u32, bytes[i * 4 ..][0..4], .little)),
                .float16 => @floatCast(@as(f16, @bitCast(std.mem.readInt(u16, bytes[i * 2 ..][0..2], .little)))),
                .bfloat16 => metrics.bfloat16ToF32(std.mem.readInt(u16, bytes[i * 2 ..][0..2], .little)),
                else => unreachable,
            };
            if (!std.math.isFinite(value)) return error.InvalidVectorValue;
        },
    }
}
/// Allocate only the result slab in the caller's output arena. Wire buffers may
/// have arbitrary alignment; owned values always have the execution alignment.
pub fn cloneInto(allocator: std.mem.Allocator, descriptor: Descriptor, bytes: []const u8) !Bytes {
    try validate(descriptor, bytes);
    const output = try allocator.alignedAlloc(u8, .fromByteUnits(alignment), bytes.len);
    @memcpy(output, bytes);
    return output;
}
/// Reusable caller-owned output is the allocation-free hot-path conversion.
pub fn copyInto(descriptor: Descriptor, bytes: []const u8, output: []align(alignment) u8) !Bytes {
    try validate(descriptor, bytes);
    if (output.len < bytes.len) return error.VectorBufferTooSmall;
    @memmove(output[0..bytes.len], bytes);
    return output[0..bytes.len];
}
pub fn evaluate(descriptor: Descriptor, metric: metrics.Metric, left: Bytes, right: Bytes) !f64 {
    return metrics.evaluateBytes(.{ .dimensions = descriptor.dimensions, .element = descriptor.element, .metric = metric }, left, right);
}

/// Structural lexicographic order. Distance metrics belong to explicit
/// operations; they cannot silently redefine equality of stored coordinates.
pub fn order(descriptor: Descriptor, left: []const u8, right: []const u8) !std.math.Order {
    try validate(descriptor, left);
    try validate(descriptor, right);
    if (descriptor.element == .binary) return std.mem.order(u8, left, right);
    for (0..descriptor.dimensions) |i| {
        const comparison = std.math.order(element(descriptor.element, left, i), element(descriptor.element, right, i));
        if (comparison != .eq) return comparison;
    }
    return .eq;
}
pub fn element(kind: metrics.ElementType, bytes: []const u8, index: usize) f64 {
    return switch (kind) {
        .int8 => @floatFromInt(@as(i8, @bitCast(bytes[index]))),
        .float32 => @as(f32, @bitCast(std.mem.readInt(u32, bytes[index * 4 ..][0..4], .little))),
        .float16 => @floatCast(@as(f16, @bitCast(std.mem.readInt(u16, bytes[index * 2 ..][0..2], .little)))),
        .bfloat16 => metrics.bfloat16ToF32(std.mem.readInt(u16, bytes[index * 2 ..][0..2], .little)),
        .binary => unreachable,
    };
}
/// Caller has validated the value and hashed its type. Normalize only floating
/// signed zero, matching structural order while the wire codec preserves bits.
pub fn hashValidated(hasher: anytype, descriptor: Descriptor, bytes: []const u8) void {
    var size: [8]u8 = undefined;
    std.mem.writeInt(u64, &size, bytes.len, .little);
    hasher.update(&size);
    switch (descriptor.element) {
        .int8, .binary => hasher.update(bytes),
        .float32 => for (0..descriptor.dimensions) |i| {
            const bits = std.mem.readInt(u32, bytes[i * 4 ..][0..4], .little);
            var normalized: [4]u8 = undefined;
            std.mem.writeInt(u32, &normalized, if (bits & 0x7fffffff == 0) 0 else bits, .little);
            hasher.update(&normalized);
        },
        .float16, .bfloat16 => for (0..descriptor.dimensions) |i| {
            const bits = std.mem.readInt(u16, bytes[i * 2 ..][0..2], .little);
            var normalized: [2]u8 = undefined;
            std.mem.writeInt(u16, &normalized, if (bits & 0x7fff == 0) 0 else bits, .little);
            hasher.update(&normalized);
        },
    }
}

test "dense vector values own aligned slabs and validate elements before metric evaluation" {
    const t = std.testing;
    const descriptor: Descriptor = .{ .dimensions = 2, .element = .float32 };
    const wire = [_]u8{ 0, 0, 0x80, 0x3f, 0, 0, 0, 0x40 };
    const owned = try cloneInto(t.allocator, descriptor, &wire);
    defer t.allocator.free(owned);
    try t.expect(metrics.isSlabAligned(owned));
    try t.expectEqualSlices(u8, &wire, owned);
    var output: [8]u8 align(alignment) = undefined;
    const copy = try copyInto(descriptor, owned, &output);
    try t.expectEqual(@as(f64, 0), try evaluate(descriptor, .l2_squared, owned, copy));
    try t.expectEqual(@as(f64, 5), try evaluate(descriptor, .dot_product, owned, copy));
    try t.expectError(error.IncompatibleVectorMetric, evaluate(descriptor, .hamming, owned, copy));
    try t.expectError(error.VectorDimensionMismatch, validate(descriptor, wire[0..4]));
    try t.expectError(error.InvalidVectorValue, validate(descriptor, &.{ 0, 0, 0x80, 0x7f, 0, 0, 0, 0 }));
    const zeros = try copyInto(descriptor, &@as([8]u8, @splat(0)), &output);
    try t.expectError(error.ZeroMagnitudeCosineVector, evaluate(descriptor, .cosine, zeros, owned));
    const negative_zero = [_]u8{ 0, 0, 0, 0x80, 0, 0, 0, 0 };
    try t.expectEqual(.eq, try order(descriptor, zeros, &negative_zero));
    var positive_hash = std.crypto.hash.sha2.Sha256.init(.{});
    var negative_hash = std.crypto.hash.sha2.Sha256.init(.{});
    hashValidated(&positive_hash, descriptor, zeros);
    hashValidated(&negative_hash, descriptor, &negative_zero);
    try t.expectEqual(positive_hash.finalResult(), negative_hash.finalResult());
}
