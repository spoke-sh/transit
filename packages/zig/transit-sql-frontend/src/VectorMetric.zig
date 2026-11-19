//! Unboxed dense numeric vectors `VECTOR(dim, elem_type)` and distance metric
//! descriptors ($\kappa_{\text{metric}}$: L2_SQUARED, COSINE, DOT_PRODUCT, HAMMING).
//! Helpers over caller-owned numeric slices; slab alignment is a descriptor
//! property, not an implemented Table storage or SQL type.
const std = @import("std");

pub const slab_alignment: usize = 64;
pub const max_dimensions: u32 = 65536;

pub const ElementType = enum(u8) {
    float32 = 1,
    float16 = 2,
    bfloat16 = 3,
    int8 = 4,
    binary = 5,

    pub fn byteSizeForDimensions(self: ElementType, dimensions: u32) !usize {
        if (dimensions == 0 or dimensions > max_dimensions) return error.InvalidVectorDimensions;
        return switch (self) {
            .float32 => @as(usize, dimensions) * 4,
            .float16, .bfloat16 => @as(usize, dimensions) * 2,
            .int8 => @as(usize, dimensions),
            .binary => blk: {
                if (dimensions % 8 != 0) return error.InvalidBinaryVectorDimensions;
                break :blk @as(usize, dimensions / 8);
            },
        };
    }
};

pub const Metric = enum(u8) {
    l2_squared = 1,
    cosine = 2,
    dot_product = 3,
    hamming = 4,

    pub fn validateForElement(self: Metric, element: ElementType) !void {
        switch (element) {
            .binary => if (self != .hamming) return error.IncompatibleVectorMetric,
            .float32, .float16, .bfloat16, .int8 => if (self == .hamming) return error.IncompatibleVectorMetric,
        }
    }
};

pub const Descriptor = struct {
    dimensions: u32,
    element: ElementType,
    metric: Metric,

    pub fn validate(self: Descriptor) !void {
        _ = try self.element.byteSizeForDimensions(self.dimensions);
        try self.metric.validateForElement(self.element);
    }
};

pub inline fn isSlabAligned(bytes: []const u8) bool {
    return (@intFromPtr(bytes.ptr) % slab_alignment) == 0;
}

pub inline fn bfloat16ToF32(bits: u16) f32 {
    return @bitCast(@as(u32, bits) << 16);
}

pub inline fn f32ToBfloat16(val: f32) u16 {
    const bits: u32 = @bitCast(val);
    // Round-to-nearest-even on bit 15
    const rounding_bias: u32 = 0x7FFF + ((bits >> 16) & 1);
    return @truncate((bits + rounding_bias) >> 16);
}

pub fn validateF32Slice(values: []const f32) !void {
    if (values.len == 0 or values.len > max_dimensions) return error.InvalidVectorDimensions;
    for (values) |v| {
        if (std.math.isNan(v) or std.math.isInf(v)) return error.InvalidVectorValue;
    }
}

pub fn l2SquaredF32(a: []const f32, b: []const f32) !f64 {
    if (a.len != b.len) return error.VectorDimensionMismatch;
    try validateF32Slice(a);
    try validateF32Slice(b);
    var sum: f64 = 0.0;
    for (a, b) |va, vb| {
        const diff = @as(f64, va) - @as(f64, vb);
        sum += diff * diff;
    }
    return sum;
}

pub fn dotProductF32(a: []const f32, b: []const f32) !f64 {
    if (a.len != b.len) return error.VectorDimensionMismatch;
    try validateF32Slice(a);
    try validateF32Slice(b);
    var sum: f64 = 0.0;
    for (a, b) |va, vb| {
        sum += @as(f64, va) * @as(f64, vb);
    }
    return sum;
}

/// Cosine distance `1.0 - (a . b) / (||a|| * ||b||)` in `[0.0, 2.0]`.
/// Rejects zero-magnitude vectors with `error.ZeroMagnitudeCosineVector`.
pub fn cosineDistanceF32(a: []const f32, b: []const f32) !f64 {
    if (a.len != b.len) return error.VectorDimensionMismatch;
    try validateF32Slice(a);
    try validateF32Slice(b);
    var dot: f64 = 0.0;
    var norm_a: f64 = 0.0;
    var norm_b: f64 = 0.0;
    for (a, b) |va, vb| {
        const fa: f64 = va;
        const fb: f64 = vb;
        dot += fa * fb;
        norm_a += fa * fa;
        norm_b += fb * fb;
    }
    if (norm_a == 0.0 or norm_b == 0.0) return error.ZeroMagnitudeCosineVector;
    const denom = @sqrt(norm_a) * @sqrt(norm_b);
    const similarity = std.math.clamp(dot / denom, -1.0, 1.0);
    return 1.0 - similarity;
}

pub fn l2SquaredI8(a: []const i8, b: []const i8) !u64 {
    if (a.len != b.len) return error.VectorDimensionMismatch;
    if (a.len == 0 or a.len > max_dimensions) return error.InvalidVectorDimensions;
    var sum: u64 = 0;
    for (a, b) |va, vb| {
        const diff: i32 = @as(i32, va) - @as(i32, vb);
        sum += @intCast(diff * diff);
    }
    return sum;
}

pub fn dotProductI8(a: []const i8, b: []const i8) !i64 {
    if (a.len != b.len) return error.VectorDimensionMismatch;
    if (a.len == 0 or a.len > max_dimensions) return error.InvalidVectorDimensions;
    var sum: i64 = 0;
    for (a, b) |va, vb| {
        sum += @as(i64, va) * @as(i64, vb);
    }
    return sum;
}

pub fn hammingDistanceBinary(a: []const u8, b: []const u8) !u32 {
    if (a.len != b.len) return error.VectorDimensionMismatch;
    if (a.len == 0 or a.len * 8 > max_dimensions) return error.InvalidVectorDimensions;
    var bits: u32 = 0;
    for (a, b) |ba, bb| {
        bits += @popCount(ba ^ bb);
    }
    return bits;
}

pub fn evaluateBytes(desc: Descriptor, a_bytes: []const u8, b_bytes: []const u8) !f64 {
    try desc.validate();
    const expected_bytes = try desc.element.byteSizeForDimensions(desc.dimensions);
    if (a_bytes.len != expected_bytes or b_bytes.len != expected_bytes) return error.VectorDimensionMismatch;

    switch (desc.element) {
        .binary => {
            const dist = try hammingDistanceBinary(a_bytes, b_bytes);
            return @floatFromInt(dist);
        },
        .int8 => {
            const a_i8: []const i8 = @ptrCast(a_bytes);
            const b_i8: []const i8 = @ptrCast(b_bytes);
            return switch (desc.metric) {
                .l2_squared => @floatFromInt(try l2SquaredI8(a_i8, b_i8)),
                .dot_product => @floatFromInt(try dotProductI8(a_i8, b_i8)),
                .cosine => blk: {
                    var dot: f64 = 0.0;
                    var na: f64 = 0.0;
                    var nb: f64 = 0.0;
                    for (a_i8, b_i8) |va, vb| {
                        const fa: f64 = @floatFromInt(va);
                        const fb: f64 = @floatFromInt(vb);
                        dot += fa * fb;
                        na += fa * fa;
                        nb += fb * fb;
                    }
                    if (na == 0.0 or nb == 0.0) return error.ZeroMagnitudeCosineVector;
                    break :blk 1.0 - std.math.clamp(dot / (@sqrt(na) * @sqrt(nb)), -1.0, 1.0);
                },
                .hamming => error.IncompatibleVectorMetric,
            };
        },
        .float32, .float16, .bfloat16 => {
            var dot: f64 = 0.0;
            var l2: f64 = 0.0;
            var na: f64 = 0.0;
            var nb: f64 = 0.0;
            for (0..desc.dimensions) |i| {
                const va: f32 = decodeFloatElement(desc.element, a_bytes, i);
                const vb: f32 = decodeFloatElement(desc.element, b_bytes, i);
                if (std.math.isNan(va) or std.math.isInf(va) or std.math.isNan(vb) or std.math.isInf(vb)) {
                    return error.InvalidVectorValue;
                }
                const fa: f64 = va;
                const fb: f64 = vb;
                const diff = fa - fb;
                l2 += diff * diff;
                dot += fa * fb;
                na += fa * fa;
                nb += fb * fb;
            }
            return switch (desc.metric) {
                .l2_squared => l2,
                .dot_product => dot,
                .cosine => blk: {
                    if (na == 0.0 or nb == 0.0) return error.ZeroMagnitudeCosineVector;
                    break :blk 1.0 - std.math.clamp(dot / (@sqrt(na) * @sqrt(nb)), -1.0, 1.0);
                },
                .hamming => error.IncompatibleVectorMetric,
            };
        },
    }
}

fn decodeFloatElement(elem: ElementType, bytes: []const u8, index: usize) f32 {
    return switch (elem) {
        .float32 => @bitCast(std.mem.readInt(u32, bytes[index * 4 ..][0..4], .little)),
        .float16 => @floatCast(@as(f16, @bitCast(std.mem.readInt(u16, bytes[index * 2 ..][0..2], .little)))),
        .bfloat16 => bfloat16ToF32(std.mem.readInt(u16, bytes[index * 2 ..][0..2], .little)),
        else => unreachable,
    };
}
