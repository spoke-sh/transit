//! Certified determinant signs for bounded binary64 inputs. An outward-rounded
//! interval filter handles separated cases; ambiguous signs use Shewchuk-style
//! error-free transforms and zero-eliminating expansions. No allocator or epsilon.
const std = @import("std");

pub const Point2 = [2]f64;
pub const Point3 = [3]f64;
pub const Sign = enum(i8) { negative = -1, zero = 0, positive = 1 };
pub const Path = enum { interval, exact };
pub const Result = struct { sign: Sign, path: Path };
pub const min_coordinate: f64 = 0x1p-100;
pub const max_coordinate: f64 = 0x1p100;

pub fn validateCoordinate(value: f64) !void {
    if (!std.math.isFinite(value)) return error.InvalidSpatialCoordinate;
    const magnitude = @abs(value);
    if (magnitude > max_coordinate or (magnitude != 0 and magnitude < min_coordinate)) return error.SpatialCoordinateRange;
}

/// Exact integer coefficient at a common 2^-152 scale, for validated inputs.
/// The 53-bit significand shifts by 0..200; signed differences fit 255 bits.
pub fn coefficient(value: f64) i256 {
    std.debug.assert(std.math.isFinite(value) and @abs(value) <= max_coordinate and (value == 0 or @abs(value) >= min_coordinate));
    if (value == 0) return 0;
    const bits: u64 = @bitCast(value);
    const exponent: i32 = @as(i32, @intCast((bits >> 52) & 0x7ff)) - 1023;
    const mantissa = (bits & 0x000f_ffff_ffff_ffff) | 0x0010_0000_0000_0000;
    const magnitude = @as(i256, mantissa) << @intCast(exponent + 100);
    return if (bits >> 63 == 0) magnitude else -magnitude;
}

const Interval = struct {
    low: f64,
    high: f64,
    fn from(value: f64) Interval {
        return .{ .low = value, .high = value };
    }
    fn down(value: f64) f64 {
        return std.math.nextAfter(f64, value, -std.math.inf(f64));
    }
    fn up(value: f64) f64 {
        return std.math.nextAfter(f64, value, std.math.inf(f64));
    }
    fn add(a: Interval, b: Interval) !Interval {
        @setFloatMode(.strict);
        return .{ .low = down(a.low + b.low), .high = up(a.high + b.high) };
    }
    fn sub(a: Interval, b: Interval) !Interval {
        @setFloatMode(.strict);
        return .{ .low = down(a.low - b.high), .high = up(a.high - b.low) };
    }
    fn mul(a: Interval, b: Interval) !Interval {
        @setFloatMode(.strict);
        const products = [4]f64{ a.low * b.low, a.low * b.high, a.high * b.low, a.high * b.high };
        var low = products[0];
        var high = products[0];
        for (products[1..]) |product| {
            low = @min(low, product);
            high = @max(high, product);
        }
        return .{ .low = down(low), .high = up(high) };
    }
};

// Error-free Two_Sum, Split, Two_Product and grow_expansion_zeroelim from
// Jonathan Richard Shewchuk, Adaptive Precision Floating-Point Arithmetic and
// Fast Robust Geometric Predicates (1997). His reference code is public domain:
// https://www.cs.cmu.edu/~quake/robust.html
// This is a bounded Zig composition, not the upstream specialized adaptive C
// routines. Strict binary64 operations are required, including ReleaseFast.
const Exact = struct {
    terms: [64]f64 = undefined,
    len: usize = 0,

    fn from(value: f64) Exact {
        var result: Exact = .{};
        if (value != 0) {
            result.terms[0] = value;
            result.len = 1;
        }
        return result;
    }
    fn twoSum(a: f64, b: f64) [2]f64 {
        @setFloatMode(.strict);
        const sum = a + b;
        const bv = sum - a;
        const av = sum - bv;
        return .{ (a - av) + (b - bv), sum };
    }
    fn split(value: f64) [2]f64 {
        @setFloatMode(.strict);
        const c = 134217729.0 * value;
        const high = c - (c - value);
        return .{ value - high, high };
    }
    fn twoProduct(a: f64, b: f64) [2]f64 {
        @setFloatMode(.strict);
        const product = a * b;
        const aa = split(a);
        const bb = split(b);
        const err1 = product - aa[1] * bb[1];
        const err2 = err1 - aa[0] * bb[1];
        const err3 = err2 - aa[1] * bb[0];
        return .{ aa[0] * bb[0] - err3, product };
    }
    fn append(self: *Exact, value: f64) !void {
        if (value == 0) return;
        if (self.len == self.terms.len) return error.SpatialPredicateWorkspaceExceeded;
        self.terms[self.len] = value;
        self.len += 1;
    }
    // Shewchuk's two-pass compression removes redundant components after every
    // grow. Without it, repeated products can fill the workspace with sparse
    // fragments even though the represented exact number fits comfortably.
    fn compress(self: *Exact) !void {
        if (self.len == 0) return;
        var temporary: Exact = .{};
        var bottom = self.len - 1;
        var carry = self.terms[bottom];
        var index = bottom;
        while (index > 0) {
            index -= 1;
            const pair = twoSum(carry, self.terms[index]);
            if (pair[0] != 0) {
                temporary.terms[bottom] = pair[1];
                bottom -= 1;
                carry = pair[0];
            } else carry = pair[1];
        }
        var result: Exact = .{};
        for (bottom + 1..self.len) |i| {
            const pair = twoSum(temporary.terms[i], carry);
            try result.append(pair[0]);
            carry = pair[1];
        }
        try result.append(carry);
        self.* = result;
    }
    fn grow(self: *Exact, value: f64) !void {
        var result: Exact = .{};
        var carry = value;
        for (self.terms[0..self.len]) |term| {
            const pair = twoSum(carry, term);
            try result.append(pair[0]);
            carry = pair[1];
        }
        try result.append(carry);
        try result.compress();
        self.* = result;
    }
    fn add(a: Exact, b: Exact) !Exact {
        var result = a;
        for (b.terms[0..b.len]) |term| try result.grow(term);
        return result;
    }
    fn sub(a: Exact, b: Exact) !Exact {
        var result = a;
        for (b.terms[0..b.len]) |term| try result.grow(-term);
        return result;
    }
    fn mul(a: Exact, b: Exact) !Exact {
        var result: Exact = .{};
        for (a.terms[0..a.len]) |x| for (b.terms[0..b.len]) |y| {
            const product = twoProduct(x, y);
            try result.grow(product[0]);
            try result.grow(product[1]);
        };
        return result;
    }
    fn sign(self: Exact) Sign {
        if (self.len == 0) return .zero;
        return if (self.terms[self.len - 1] > 0) .positive else .negative;
    }
};

fn determinant(comptime N: type, comptime size: usize, matrix: [size][size]N) error{SpatialPredicateWorkspaceExceeded}!N {
    if (size == 1) return matrix[0][0];
    var result = N.from(0);
    inline for (0..size) |column| {
        var minor: [size - 1][size - 1]N = undefined;
        inline for (1..size) |row| {
            var to: usize = 0;
            inline for (0..size) |source| {
                if (source != column) {
                    minor[row - 1][to] = matrix[row][source];
                    to += 1;
                }
            }
        }
        const term = try N.mul(matrix[0][column], try determinant(N, size - 1, minor));
        result = if (column % 2 == 0) try N.add(result, term) else try N.sub(result, term);
    }
    return result;
}

fn matrixFor(comptime N: type, comptime dimension: usize, comptime lifted: bool, points: [dimension + 1 + @intFromBool(lifted)][dimension]f64) ![dimension + @intFromBool(lifted)][dimension + @intFromBool(lifted)]N {
    const size = dimension + @intFromBool(lifted);
    var matrix: [size][size]N = undefined;
    inline for (0..size) |row| {
        inline for (0..dimension) |axis| matrix[row][axis] = try N.sub(N.from(points[row][axis]), N.from(points[size][axis]));
        if (lifted) {
            var lift = N.from(0);
            inline for (0..dimension) |axis| lift = try N.add(lift, try N.mul(matrix[row][axis], matrix[row][axis]));
            matrix[row][dimension] = lift;
        }
    }
    return matrix;
}

fn evaluate(comptime dimension: usize, comptime lifted: bool, points: [dimension + 1 + @intFromBool(lifted)][dimension]f64) !Result {
    for (points) |point| for (point) |coordinate| try validateCoordinate(coordinate);
    const size = dimension + @intFromBool(lifted);
    const bound = try determinant(Interval, size, try matrixFor(Interval, dimension, lifted, points));
    if (bound.low > 0) return .{ .sign = .positive, .path = .interval };
    if (bound.high < 0) return .{ .sign = .negative, .path = .interval };
    const exact = try determinant(Exact, size, try matrixFor(Exact, dimension, lifted, points));
    return .{ .sign = exact.sign(), .path = .exact };
}

/// Positive for a counterclockwise a,b,c; zero for collinear points.
pub fn orient2d(a: Point2, b: Point2, c: Point2) !Result {
    return evaluate(2, false, .{ a, b, c });
}
/// Sign of det(a-d,b-d,c-d); positive when d lies below oriented a,b,c.
pub fn orient3d(a: Point3, b: Point3, c: Point3, d: Point3) !Result {
    return evaluate(3, false, .{ a, b, c, d });
}
/// For counterclockwise a,b,c, positive when d is inside the circumcircle.
/// Reversing orientation reverses the sign; degenerate inputs are not repaired.
pub fn incircle(a: Point2, b: Point2, c: Point2, d: Point2) !Result {
    return evaluate(2, true, .{ a, b, c, d });
}
/// For positively oriented a,b,c,d, positive when e is inside the sphere.
pub fn insphere(a: Point3, b: Point3, c: Point3, d: Point3, e: Point3) !Result {
    return evaluate(3, true, .{ a, b, c, d, e });
}

test "spatial determinant signs distinguish interior boundary and orientation" {
    const t = std.testing;
    try t.expectEqual(Sign.positive, (try orient2d(.{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 })).sign);
    try t.expectEqual(Sign.negative, (try orient2d(.{ 0, 0 }, .{ 0, 1 }, .{ 1, 0 })).sign);
    try t.expectEqualDeep(Result{ .sign = .zero, .path = .exact }, try orient2d(.{ 0, 0 }, .{ 1, 1 }, .{ 2, 2 }));
    try t.expectEqual(Sign.negative, (try orient3d(.{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 }, .{ 0, 0, 1 })).sign);
    try t.expectEqual(Sign.positive, (try incircle(.{ 1, 0 }, .{ 0, 1 }, .{ -1, 0 }, .{ 0, 0 })).sign);
    try t.expectEqual(Sign.zero, (try incircle(.{ 1, 0 }, .{ 0, 1 }, .{ -1, 0 }, .{ 0, -1 })).sign);
    try t.expectEqual(Sign.negative, (try incircle(.{ 1, 0 }, .{ 0, 1 }, .{ -1, 0 }, .{ 0, -2 })).sign);
    try t.expectEqual(Sign.positive, (try insphere(.{ 1, 0, 0 }, .{ 0, 1, 0 }, .{ 0, 0, 1 }, .{ 0, 0, 0 }, .{ 0.5, 0.5, 0.5 })).sign);
}

test "spatial exact fallback resolves cancellation and bounded exponents" {
    const t = std.testing;
    const one_up = std.math.nextAfter(f64, 1, 2);
    const result = try orient2d(.{ 1, 1 }, .{ one_up, 1 }, .{ 0, 0 });
    try t.expectEqual(Sign.negative, result.sign);
    try t.expectEqual(Path.exact, result.path);
    try t.expectEqual(Sign.positive, (try orient2d(.{ 0, 0 }, .{ max_coordinate, min_coordinate }, .{ min_coordinate, max_coordinate })).sign);
    try t.expectError(error.InvalidSpatialCoordinate, orient2d(.{ std.math.nan(f64), 0 }, .{ 0, 0 }, .{ 1, 1 }));
    try t.expectError(error.SpatialCoordinateRange, orient2d(.{ 0x1p-101, 0 }, .{ 0, 0 }, .{ 1, 1 }));
    try t.expectError(error.SpatialCoordinateRange, orient3d(.{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 }, .{ 0, 0, 0x1p101 }));
    try t.expectEqual(@as(i256, 0), coefficient(-0.0));
}
