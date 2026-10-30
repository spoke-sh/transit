const std = @import("std");
const testing = std.testing;
const f = @import("root.zig");
const Range = f.Range;
const VectorMetric = f.VectorMetric;
const DecimalArithmetic = f.DecimalArithmetic;
const Collation = f.Collation;

test "canonical RANGE<T> and MULTIRANGE<T> discrete half-open canonicalization and Allen predicates" {
    const r1 = try Range.Int64Range.closed(10, 20);
    const r2 = try Range.Int64Range.halfOpen(10, 21);
    try testing.expect(r1.eql(r2));
    try testing.expectEqual(@as(i64, 10), r1.lower.?.value);
    try testing.expect(r1.lower.?.inclusive);
    try testing.expectEqual(@as(i64, 21), r1.upper.?.value);
    try testing.expect(!r1.upper.?.inclusive);

    const empty = try Range.Int64Range.halfOpen(15, 15);
    try testing.expect(empty.is_empty);

    const r3 = try Range.Int64Range.closed(21, 30);
    try testing.expect(!r1.overlaps(r3));
    try testing.expect(r1.adjacent(r3));
    try testing.expect(r1.strictlyLeft(r3));
    try testing.expect(r3.strictlyRight(r1));

    const r4 = try Range.Int64Range.closed(15, 25);
    try testing.expect(r1.overlaps(r4));
    try testing.expect(!r1.adjacent(r4));
    const inter = r1.intersection(r4);
    try testing.expect(inter.eql(try Range.Int64Range.closed(15, 20)));

    try testing.expect(r1.containsElement(10));
    try testing.expect(r1.containsElement(20));
    try testing.expect(!r1.containsElement(21));
    try testing.expect(r1.containsRange(inter));
    try testing.expect(inter.containedBy(r1));

    // MultiRange coalesces overlapping and adjacent discrete intervals and drops empty ones
    const inputs = [_]Range.Int64Range{
        try Range.Int64Range.closed(30, 40),
        Range.Int64Range.empty,
        try Range.Int64Range.closed(1, 5),
        try Range.Int64Range.closed(6, 10), // adjacent to [1, 5] -> [1, 11)
        try Range.Int64Range.closed(8, 12), // overlaps [1, 11) -> [1, 13)
    };
    var scratch: [5]Range.Int64Range = undefined;
    const mr = try Range.Int64MultiRange.normalizeInto(&inputs, &scratch);
    try testing.expectEqual(@as(usize, 2), mr.runs.len);
    try testing.expect(mr.runs[0].eql(try Range.Int64Range.closed(1, 12)));
    try testing.expect(mr.runs[1].eql(try Range.Int64Range.closed(30, 40)));
    try testing.expect(mr.containsElement(6));
    try testing.expect(!mr.containsElement(20));
    try testing.expect(mr.containsRange(try Range.Int64Range.closed(2, 11)));
}

test "unboxed VECTOR(dim, elem_type) 64B slab alignment and L2, cosine, dot, hamming metrics" {
    const slab_a align(VectorMetric.slab_alignment) = [_]f32{ 3.0, 4.0, 0.0, 0.0 };
    const slab_b align(VectorMetric.slab_alignment) = [_]f32{ 3.0, 0.0, 4.0, 0.0 };
    const bytes_a = std.mem.sliceAsBytes(&slab_a);
    const bytes_b = std.mem.sliceAsBytes(&slab_b);
    try testing.expect(VectorMetric.isSlabAligned(bytes_a));
    try testing.expect(VectorMetric.isSlabAligned(bytes_b));

    const l2 = try VectorMetric.l2SquaredF32(&slab_a, &slab_b);
    try testing.expectApproxEqAbs(@as(f64, 32.0), l2, 1e-9);

    const dot = try VectorMetric.dotProductF32(&slab_a, &slab_b);
    try testing.expectApproxEqAbs(@as(f64, 9.0), dot, 1e-9);

    const cos = try VectorMetric.cosineDistanceF32(&slab_a, &slab_b);
    // 1 - 9 / (5 * 5) = 1 - 0.36 = 0.64
    try testing.expectApproxEqAbs(@as(f64, 0.64), cos, 1e-9);

    // Binary Hamming distance
    const bin_desc: VectorMetric.Descriptor = .{
        .dimensions = 16,
        .element = .binary,
        .metric = .hamming,
    };
    const ham = try VectorMetric.evaluateBytes(bin_desc, &.{ 0b1010_1010, 0b1111_0000 }, &.{ 0b0101_1010, 0b0000_0000 });
    try testing.expectApproxEqAbs(@as(f64, 8.0), ham, 1e-9);

    // Reject NaN and zero-magnitude cosine
    const nan_vec = [_]f32{ std.math.nan(f32), 1.0, 0.0, 0.0 };
    try testing.expectError(error.InvalidVectorValue, VectorMetric.l2SquaredF32(&nan_vec, &slab_a));
    const zero_vec = [_]f32{ 0.0, 0.0, 0.0, 0.0 };
    try testing.expectError(error.ZeroMagnitudeCosineVector, VectorMetric.cosineDistanceF32(&zero_vec, &slab_a));
}

test "deterministic DECIMAL(p, s) arithmetic rounding rules, pinned tzdb version, and spatial descriptor" {
    const a: DecimalArithmetic.DecimalValue = .{ .coefficient = 12345, .precision = 10, .scale = 3 }; // 12.345
    // Exact half-way tie: 12.345 -> scale 2 is 12.34 under HALF_EVEN (4 is even)
    const r_even = try DecimalArithmetic.rescale(a, 10, 2, .half_even);
    try testing.expectEqual(@as(i128, 1234), r_even.coefficient);

    // 12.355 -> scale 2 is 12.36 under HALF_EVEN (5 is odd -> rounds to 6)
    const b: DecimalArithmetic.DecimalValue = .{ .coefficient = 12355, .precision = 10, .scale = 3 };
    const r_odd = try DecimalArithmetic.rescale(b, 10, 2, .half_even);
    try testing.expectEqual(@as(i128, 1236), r_odd.coefficient);

    // TOWARD_ZERO truncates 12.355 -> 12.35 and -12.355 -> -12.35
    const r_trunc = try DecimalArithmetic.rescale(b, 10, 2, .toward_zero);
    try testing.expectEqual(@as(i128, 1235), r_trunc.coefficient);

    // REJECT refuses inexact rounding
    try testing.expectError(error.InexactDecimalRounding, DecimalArithmetic.rescale(a, 10, 2, .reject));

    // Scale-promoted addition: 12.345 (scale 3) + 1.5 (scale 1) = 13.845 (scale 3)
    const c: DecimalArithmetic.DecimalValue = .{ .coefficient = 15, .precision = 4, .scale = 1 };
    const sum = try DecimalArithmetic.add(a, c);
    try testing.expectEqual(@as(u8, 3), sum.scale);
    try testing.expectEqual(@as(i128, 13845), sum.coefficient);

    // Spatial descriptor validation
    const spatial: DecimalArithmetic.SpatialDescriptor = .{
        .srid = 4326,
        .manifold = .geodesic_wgs84,
        .axis_orientation = .right_handed_z_up,
        .snap_grid_scale = 1e-7,
        .curve_order = .s2_hilbert,
    };
    try spatial.validate();
    const bad_geodesic: DecimalArithmetic.SpatialDescriptor = .{
        .srid = 3857,
        .manifold = .geodesic_wgs84,
    };
    try testing.expectError(error.IncompatibleGeodesicSrid, bad_geodesic.validate());
}

test "EBCDIC_037_PAD and EBCDIC_1047_NOPAD collation comparisons and order-preserving sort keys" {
    // EBCDIC_037_PAD ignores trailing spaces while preserving EBCDIC 'a' < 'A' < '0' order
    try testing.expectEqual(
        std.math.Order.eq,
        try Collation.compareBytesProfile("ACCT01", "ACCT01   ", .ebcdic_037_pad),
    );
    try testing.expectEqual(
        std.math.Order.lt,
        try Collation.compareBytesProfile("ACCT01", "ACCT01   ", .ebcdic_cp037),
    );
    var key1_buf: [64]u8 = undefined;
    var key2_buf: [64]u8 = undefined;
    const cell1: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .bytes = "ACCT01" } } };
    const cell2: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .bytes = "ACCT01   " } } };
    const k1 = try Collation.encodeSortKeyProfile(cell1, .utf8, .ebcdic_037_pad, &key1_buf);
    const k2 = try Collation.encodeSortKeyProfile(cell2, .utf8, .ebcdic_037_pad, &key2_buf);
    try testing.expectEqualSlices(u8, k1, k2);

    // EBCDIC_1047_NOPAD vs EBCDIC_CP037 on '[' (0x5B) and '^' (0x5E)
    // In CP037: '^' is 0xB0, '[' is 0xBA ('^' < '[')
    // In CP1047: '^' is 0x5F, '[' is 0xAD ('^' < '[', but vs '¬' (0xAC): in CP037 '¬' is 0x5F < '^' 0xB0, in CP1047 '^' 0x5F < '¬' 0xB0)
    try testing.expectEqual(
        std.math.Order.lt,
        try Collation.compareBytesProfile("¬", "^", .ebcdic_cp037),
    );
    try testing.expectEqual(
        std.math.Order.gt,
        try Collation.compareBytesProfile("¬", "^", .ebcdic_1047_nopad),
    );
}

test "decimal extreme scale multiplication and division return typed overflow" {
    const large: DecimalArithmetic.DecimalValue = .{
        .coefficient = 10_000_000_000_000_000_000_000_000_000_000_000_000,
        .precision = 38,
        .scale = 0,
    };
    const small: DecimalArithmetic.DecimalValue = .{ .coefficient = large.coefficient, .precision = 38, .scale = 38 };
    for ([_]DecimalArithmetic.RoundingMode{ .reject, .half_even, .toward_zero }) |mode| {
        try testing.expectError(error.DecimalOverflow, DecimalArithmetic.mul(large, large, 38, 38, mode));
        try testing.expectError(error.DecimalOverflow, DecimalArithmetic.div(large, small, 38, 38, mode));
    }
    const tenth = try DecimalArithmetic.div(small, large, 38, 38, .reject);
    try testing.expectEqual(@as(i128, 1), tenth.coefficient);
    const square = try DecimalArithmetic.mul(small, small, 38, 38, .reject);
    try testing.expectEqual(@divExact(large.coefficient, 10), square.coefficient);
    const negative: DecimalArithmetic.DecimalValue = .{ .coefficient = -small.coefficient, .precision = 38, .scale = 38 };
    try testing.expectEqual(-square.coefficient, (try DecimalArithmetic.mul(small, negative, 38, 38, .reject)).coefficient);
}
