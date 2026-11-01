//! Validated borrowed planar rings/polygons. Callers retain immutable coordinates
//! and ring directories. Work counters bound loops; cardinality is not capped.
const std = @import("std");
const Reference = @import("Reference.zig");
const predicates = @import("Predicates.zig");
pub const Point = predicates.Point2;
pub const Location = enum { exterior, boundary, interior };
pub const SegmentRelation = enum { disjoint, touch, cross, overlap };
pub const Budget = struct {
    remaining: usize,
    pub fn charge(self: *Budget, count: usize) !void {
        if (count > self.remaining) return error.SpatialWorkExceeded;
        self.remaining -= count;
    }
};
pub const Invalid = struct {
    reason: enum { too_few_points, not_closed, repeated_vertex, self_intersection, zero_area, hole_outside, rings_intersect, nested_holes },
    /// Zero is the shell, 1..n are holes. Edges use original coordinate order.
    ring: usize = 0,
    edge: usize = 0,
    other_ring: ?usize = null,
    other_edge: ?usize = null,
};

fn invalid(witness: *?Invalid, value: Invalid) error{InvalidSpatialGeometry} {
    witness.* = value;
    return error.InvalidSpatialGeometry;
}
fn same(a: Point, b: Point) bool {
    return a[0] == b[0] and a[1] == b[1];
}

/// Explicit binary-grid normalization, nearest ties to even. Exact precision
/// returns the original bits. Normalization supplies no validity/repair claim.
pub fn normalizeCoordinate(reference: Reference, value: f64) !f64 {
    @setFloatMode(.strict);
    try reference.validate();
    try predicates.validateCoordinate(value);
    if (reference.precision == .exact) return value;
    const exponent = reference.precision.binary_grid;
    const scaled = std.math.ldexp(value, -@as(i32, exponent));
    const lower = @floor(scaled);
    const fraction = scaled - lower;
    const rounded = if (fraction < 0.5) lower else if (fraction > 0.5) lower + 1 else blk: {
        // A nonzero fraction implies |lower| <= 2^53: the conversion is safe.
        const integer: i64 = @intFromFloat(lower);
        break :blk if (@mod(integer, 2) == 0) lower else lower + 1;
    };
    const result = std.math.ldexp(rounded, exponent);
    return if (result == 0) 0 else result;
}

fn validatePoint(reference: Reference, point: Point) !void {
    for (point) |coordinate| {
        try predicates.validateCoordinate(coordinate);
        if (reference.precision == .binary_grid and try normalizeCoordinate(reference, coordinate) != coordinate) return error.SpatialPrecisionMismatch;
    }
}

pub const Box = struct {
    min: Point,
    max: Point,
    pub fn validate(self: Box) !void {
        for (self.min) |coordinate| try predicates.validateCoordinate(coordinate);
        for (self.max) |coordinate| try predicates.validateCoordinate(coordinate);
        if (self.min[0] > self.max[0] or self.min[1] > self.max[1]) return error.InvalidSpatialBounds;
    }
    pub fn contains(self: Box, point: Point) !bool {
        try self.validate();
        for (point) |coordinate| try predicates.validateCoordinate(coordinate);
        return point[0] >= self.min[0] and point[0] <= self.max[0] and point[1] >= self.min[1] and point[1] <= self.max[1];
    }
    pub fn intersects(self: Box, other: Box) !bool {
        try self.validate();
        try other.validate();
        return self.min[0] <= other.max[0] and other.min[0] <= self.max[0] and self.min[1] <= other.max[1] and other.min[1] <= self.max[1];
    }
};

fn inSegmentBox(point: Point, a: Point, b: Point) bool {
    return point[0] >= @min(a[0], b[0]) and point[0] <= @max(a[0], b[0]) and point[1] >= @min(a[1], b[1]) and point[1] <= @max(a[1], b[1]);
}

/// Exact classification of closed segments, including zero-length points.
pub fn segmentRelation(a: Point, b: Point, c: Point, d: Point) !SegmentRelation {
    const ab_c = (try predicates.orient2d(a, b, c)).sign;
    const ab_d = (try predicates.orient2d(a, b, d)).sign;
    const cd_a = (try predicates.orient2d(c, d, a)).sign;
    const cd_b = (try predicates.orient2d(c, d, b)).sign;
    if (ab_c == .zero and ab_d == .zero and cd_a == .zero and cd_b == .zero) {
        const axis: usize = if (a[0] != b[0] or c[0] != d[0]) 0 else 1;
        // Distinct degenerate points can share the selected coordinate.
        if (same(a, b) and same(c, d)) return if (same(a, c)) .touch else .disjoint;
        const low = @max(@min(a[axis], b[axis]), @min(c[axis], d[axis]));
        const high = @min(@max(a[axis], b[axis]), @max(c[axis], d[axis]));
        return if (low > high) .disjoint else if (low == high) .touch else .overlap;
    }
    if ((ab_c == .zero and inSegmentBox(c, a, b)) or (ab_d == .zero and inSegmentBox(d, a, b)) or
        (cd_a == .zero and inSegmentBox(a, c, d)) or (cd_b == .zero and inSegmentBox(b, c, d))) return .touch;
    if (ab_c != .zero and ab_d != .zero and cd_a != .zero and cd_b != .zero and ab_c != ab_d and cd_a != cd_b) return .cross;
    return .disjoint;
}

fn twiceArea(points: []const Point, budget: *Budget) !i640 {
    var result: i640 = 0;
    for (points[0 .. points.len - 1], points[1..]) |a, b| {
        try budget.charge(1);
        const ax: i640 = predicates.coefficient(a[0]);
        const ay: i640 = predicates.coefficient(a[1]);
        const bx: i640 = predicates.coefficient(b[0]);
        const by: i640 = predicates.coefficient(b[1]);
        // Each term < 2^507 and there are at most usize.max terms. i640
        // bounds even a 64-bit host's complete admitted slice without overflow.
        result += ax * by - ay * bx;
    }
    return result;
}

pub const Ring = struct {
    reference: Reference,
    points: []const Point,
    bounds: Box,

    /// Caller must keep points immutable until every borrowed Ring/Polygon is
    /// released. Structural failure supplies an original-index witness; budget,
    /// descriptor and coordinate refusal return no invented structural witness.
    pub fn init(reference: Reference, points: []const Point, budget: *Budget, witness: *?Invalid) !Ring {
        witness.* = null;
        try reference.requirePlanar(2);
        if (points.len < 4) return invalid(witness, .{ .reason = .too_few_points });
        var bounds: Box = .{ .min = points[0], .max = points[0] };
        for (points) |point| {
            try budget.charge(1);
            try validatePoint(reference, point);
            inline for (0..2) |axis| {
                bounds.min[axis] = @min(bounds.min[axis], point[axis]);
                bounds.max[axis] = @max(bounds.max[axis], point[axis]);
            }
        }
        if (!same(points[0], points[points.len - 1])) return invalid(witness, .{ .reason = .not_closed, .edge = points.len - 2 });
        const edges = points.len - 1;
        for (0..edges) |i| {
            if (same(points[i], points[i + 1])) return invalid(witness, .{ .reason = .repeated_vertex, .edge = i });
            for (i + 1..edges) |j| {
                try budget.charge(1);
                const relation = try segmentRelation(points[i], points[i + 1], points[j], points[j + 1]);
                const adjacent = j == i + 1 or (i == 0 and j == edges - 1);
                if (relation != .disjoint and !(adjacent and relation == .touch)) return invalid(witness, .{ .reason = .self_intersection, .edge = i, .other_edge = j });
            }
        }
        if (try twiceArea(points, budget) == 0) return invalid(witness, .{ .reason = .zero_area });
        return .{ .reference = reference, .points = points, .bounds = bounds };
    }

    /// Point is interpreted in this ring's exact coordinate reference.
    pub fn locate(self: Ring, point: Point, budget: *Budget) !Location {
        try validatePoint(self.reference, point);
        try budget.charge(1);
        if (!try self.bounds.contains(point)) return .exterior;
        var inside = false;
        for (self.points[0 .. self.points.len - 1], self.points[1..]) |a, b| {
            try budget.charge(1);
            const orientation = (try predicates.orient2d(a, b, point)).sign;
            if (orientation == .zero and inSegmentBox(point, a, b)) return .boundary;
            // Half-open y crossings count a shared vertex exactly once. Use
            // determinant signs rather than a rounded division for the ray.
            if ((a[1] > point[1]) != (b[1] > point[1])) {
                if ((b[1] > a[1] and orientation == .positive) or (b[1] < a[1] and orientation == .negative)) inside = !inside;
            }
        }
        return if (inside) .interior else .exterior;
    }

    /// Exact dyadic accumulation, followed by one binary64 conversion and scale.
    /// Coordinate-unit squared; signed by winding, with no geodesic meaning.
    pub fn signedArea(self: Ring, budget: *Budget) !f64 {
        @setFloatMode(.strict);
        const sum = try twiceArea(self.points, budget);
        return @as(f64, @floatFromInt(sum)) * 0x1p-305;
    }
};

fn intersectingEdges(a: Ring, b: Ring, budget: *Budget) !?struct { a: usize, b: usize } {
    try a.reference.requireSame(b.reference);
    try budget.charge(1);
    if (!try a.bounds.intersects(b.bounds)) return null;
    for (a.points[0 .. a.points.len - 1], a.points[1..], 0..) |p0, p1, i| {
        for (b.points[0 .. b.points.len - 1], b.points[1..], 0..) |q0, q1, j| {
            try budget.charge(1);
            if (try segmentRelation(p0, p1, q0, q1) != .disjoint) return .{ .a = i, .b = j };
        }
    }
    return null;
}

pub const Polygon = struct {
    shell: Ring,
    holes: []const Ring,

    /// Rings are validated Ring.init results. Touching, intersecting, nested or
    /// exterior holes reject; either winding direction is permitted.
    pub fn init(shell: Ring, holes: []const Ring, budget: *Budget, witness: *?Invalid) !Polygon {
        witness.* = null;
        for (holes, 0..) |hole, i| {
            try shell.reference.requireSame(hole.reference);
            if (try intersectingEdges(shell, hole, budget)) |pair| return invalid(witness, .{ .reason = .rings_intersect, .ring = i + 1, .edge = pair.b, .other_ring = 0, .other_edge = pair.a });
            if (try shell.locate(hole.points[0], budget) != .interior) return invalid(witness, .{ .reason = .hole_outside, .ring = i + 1 });
            for (holes[0..i], 0..) |previous, j| {
                if (try intersectingEdges(previous, hole, budget)) |pair| return invalid(witness, .{ .reason = .rings_intersect, .ring = i + 1, .edge = pair.b, .other_ring = j + 1, .other_edge = pair.a });
                if (try previous.locate(hole.points[0], budget) != .exterior or try hole.locate(previous.points[0], budget) != .exterior) return invalid(witness, .{ .reason = .nested_holes, .ring = i + 1, .other_ring = j + 1 });
            }
        }
        return .{ .shell = shell, .holes = holes };
    }

    pub fn locate(self: Polygon, point: Point, budget: *Budget) !Location {
        const shell_location = try self.shell.locate(point, budget);
        if (shell_location != .interior) return shell_location;
        for (self.holes) |hole| switch (try hole.locate(point, budget)) {
            .interior => return .exterior,
            .boundary => return .boundary,
            .exterior => {},
        };
        return .interior;
    }

    /// Exact common-scale subtraction before the single rounding. Caller owns
    /// the polygon, points, ring directory and operation budget throughout.
    pub fn area(self: Polygon, budget: *Budget) !f64 {
        @setFloatMode(.strict);
        var sum: i640 = @intCast(@abs(try twiceArea(self.shell.points, budget)));
        for (self.holes) |hole| sum -= @intCast(@abs(try twiceArea(hole.points, budget)));
        return @as(f64, @floatFromInt(sum)) * 0x1p-305;
    }
};

test "spatial planar rings preserve boundaries holes winding and exact area" {
    const t = std.testing;
    const p = @import("transit_protocol");
    const reference: Reference = .{ .definition = p.Growth.current_definition, .srid = 0, .axes = .xy, .manifold = .planar, .linear_unit_nm = 1_000_000_000, .vertical_datum = .none, .precision = .exact };
    var work: Budget = .{ .remaining = 10000 };
    var witness: ?Invalid = null;
    const shell = try Ring.init(reference, &.{ .{ 0, 0 }, .{ 10, 0 }, .{ 10, 10 }, .{ 0, 10 }, .{ 0, 0 } }, &work, &witness);
    const hole = try Ring.init(reference, &.{ .{ 2, 2 }, .{ 4, 2 }, .{ 4, 4 }, .{ 2, 4 }, .{ 2, 2 } }, &work, &witness);
    const polygon = try Polygon.init(shell, &.{hole}, &work, &witness);
    try t.expectEqual(@as(f64, 100), try shell.signedArea(&work));
    try t.expectEqual(@as(f64, 96), try polygon.area(&work));
    try t.expectEqual(Location.interior, try polygon.locate(.{ 1, 1 }, &work));
    try t.expectEqual(Location.exterior, try polygon.locate(.{ 3, 3 }, &work));
    try t.expectEqual(Location.boundary, try polygon.locate(.{ 2, 3 }, &work));
    try t.expectEqual(Location.boundary, try polygon.locate(.{ 10, 10 }, &work));
    try t.expectEqual(Location.exterior, try polygon.locate(.{ 11, 10 }, &work));
    work.remaining = 0;
    try t.expectError(error.SpatialWorkExceeded, polygon.locate(.{ 1, 1 }, &work));
    try t.expectEqual(@as(usize, 0), work.remaining);
}

test "spatial ring validation rejects self intersections and adjacent backtracking" {
    const t = std.testing;
    const p = @import("transit_protocol");
    const reference: Reference = .{ .definition = p.Growth.current_definition, .srid = 0, .axes = .xy, .manifold = .planar, .linear_unit_nm = 1, .vertical_datum = .none, .precision = .exact };
    var work: Budget = .{ .remaining = 1000 };
    var witness: ?Invalid = null;
    try t.expectError(error.InvalidSpatialGeometry, Ring.init(reference, &.{ .{ 0, 0 }, .{ 2, 2 }, .{ 0, 2 }, .{ 2, 0 }, .{ 0, 0 } }, &work, &witness));
    try t.expectEqual(Invalid{ .reason = .self_intersection, .edge = 0, .other_edge = 2 }, witness.?);
    try t.expectError(error.InvalidSpatialGeometry, Ring.init(reference, &.{ .{ 0, 0 }, .{ 2, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ 0, 0 } }, &work, &witness));
    try t.expectEqual(Invalid{ .reason = .self_intersection, .edge = 0, .other_edge = 1 }, witness.?);
    try t.expectEqual(SegmentRelation.disjoint, try segmentRelation(.{ 0, 0 }, .{ 0, 0 }, .{ 1, 0 }, .{ 1, 0 }));
    try t.expectEqual(SegmentRelation.overlap, try segmentRelation(.{ 0, 0 }, .{ 3, 0 }, .{ 1, 0 }, .{ 2, 0 }));
    try t.expectEqual(SegmentRelation.touch, try segmentRelation(.{ 0, 0 }, .{ 1, 0 }, .{ 1, 0 }, .{ 2, 0 }));
}

test "spatial grid normalization is explicit and uses ties to even" {
    const t = std.testing;
    const p = @import("transit_protocol");
    const reference: Reference = .{ .definition = p.Growth.current_definition, .srid = 0, .axes = .xy, .manifold = .planar, .linear_unit_nm = 1, .vertical_datum = .none, .precision = .{ .binary_grid = 0 } };
    for ([_]f64{ 0.5, 1.5, 2.5, -0.5, -1.5, -2.5 }, [_]f64{ 0, 2, 2, 0, -2, -2 }) |input, expected| try t.expectEqual(expected, try normalizeCoordinate(reference, input));
    var work: Budget = .{ .remaining = 1000 };
    var witness: ?Invalid = null;
    try t.expectError(error.SpatialPrecisionMismatch, Ring.init(reference, &.{ .{ 0, 0 }, .{ 1.5, 0 }, .{ 0, 1 }, .{ 0, 0 } }, &work, &witness));
    try t.expect(witness == null);
}

test "spatial polygon validation rejects exterior touching nested and mismatched holes" {
    const t = std.testing;
    const p = @import("transit_protocol");
    const reference: Reference = .{ .definition = p.Growth.current_definition, .srid = 0, .axes = .xy, .manifold = .planar, .linear_unit_nm = 1, .vertical_datum = .none, .precision = .exact };
    var work: Budget = .{ .remaining = 10000 };
    var witness: ?Invalid = null;
    const shell = try Ring.init(reference, &.{ .{ 0, 0 }, .{ 10, 0 }, .{ 10, 10 }, .{ 0, 10 }, .{ 0, 0 } }, &work, &witness);
    const outside = try Ring.init(reference, &.{ .{ 20, 0 }, .{ 21, 0 }, .{ 21, 1 }, .{ 20, 0 } }, &work, &witness);
    try t.expectError(error.InvalidSpatialGeometry, Polygon.init(shell, &.{outside}, &work, &witness));
    try t.expectEqual(Invalid{ .reason = .hole_outside, .ring = 1 }, witness.?);
    const touch = try Ring.init(reference, &.{ .{ 0, 0 }, .{ 2, 1 }, .{ 1, 2 }, .{ 0, 0 } }, &work, &witness);
    try t.expectError(error.InvalidSpatialGeometry, Polygon.init(shell, &.{touch}, &work, &witness));
    try t.expectEqual(Invalid{ .reason = .rings_intersect, .ring = 1, .edge = 0, .other_ring = 0, .other_edge = 0 }, witness.?);
    const inner = try Ring.init(reference, &.{ .{ 2, 2 }, .{ 8, 2 }, .{ 8, 8 }, .{ 2, 8 }, .{ 2, 2 } }, &work, &witness);
    const nested = try Ring.init(reference, &.{ .{ 3, 3 }, .{ 4, 3 }, .{ 4, 4 }, .{ 3, 3 } }, &work, &witness);
    try t.expectError(error.InvalidSpatialGeometry, Polygon.init(shell, &.{ inner, nested }, &work, &witness));
    try t.expectEqual(Invalid{ .reason = .nested_holes, .ring = 2, .other_ring = 1 }, witness.?);
    var other_reference = reference;
    other_reference.linear_unit_nm = 1000;
    const foreign = try Ring.init(other_reference, nested.points, &work, &witness);
    try t.expectError(error.SpatialReferenceMismatch, Polygon.init(shell, &.{foreign}, &work, &witness));
    try t.expect(witness == null);
}

test "spatial boxes reject invalid coordinates before pruning" {
    const t = std.testing;
    const valid: Box = .{ .min = .{ 0, 0 }, .max = .{ 1, 1 } };
    try t.expect(try valid.contains(.{ 1, 1 }));
    try t.expect(try valid.intersects(.{ .min = .{ 1, 1 }, .max = .{ 2, 2 } }));
    try t.expectError(error.InvalidSpatialBounds, valid.intersects(.{ .min = .{ 2, 1 }, .max = .{ 1, 2 } }));
    try t.expectError(error.InvalidSpatialCoordinate, valid.contains(.{ std.math.nan(f64), 0 }));
}
