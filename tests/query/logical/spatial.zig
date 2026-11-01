//! Test-only adapter: Python owns the exact rational oracle, Zig the real kernels.
const std = @import("std");
const s = @import("transit_spatial");
const p = @import("transit_protocol");
const Case = struct {
    op: enum { orient2d, orient3d, incircle, insphere, ring, segment, reference },
    // Raw IEEE bits preserve signed zero, adjacent values and non-finite refusals.
    points: []const []const u64 = &.{},
    query: [2]u64 = .{ 0, 0 },
    budget: usize = 100000,
};
const Output = struct {
    sign: ?i8 = null,
    path: ?s.Predicates.Path = null,
    location: ?s.Planar.Location = null,
    area: ?f64 = null,
    relation: ?s.Planar.SegmentRelation = null,
    error_name: ?[]const u8 = null,
    witness: ?s.Planar.Invalid = null,
    encoded: ?[s.Reference.encoded_bytes]u8 = null,
    fingerprint: ?[32]u8 = null,
};
const reference: s.Reference = .{
    .definition = p.Growth.current_definition,
    .srid = 0,
    .local_frame = @splat(1),
    .axes = .xy,
    .manifold = .planar,
    .linear_unit_nm = 1_000_000_000,
    .vertical_datum = .none,
    .precision = .exact,
};

fn point(comptime dimensions: usize, bits: []const u64) ![dimensions]f64 {
    if (bits.len != dimensions) return error.InvalidFixture;
    var result: [dimensions]f64 = undefined;
    for (&result, bits) |*value, raw| value.* = @bitCast(raw);
    return result;
}
fn determinant(case: Case) !s.Predicates.Result {
    const pts = case.points;
    return switch (case.op) {
        .orient2d => if (pts.len == 3) s.Predicates.orient2d(try point(2, pts[0]), try point(2, pts[1]), try point(2, pts[2])) else error.InvalidFixture,
        .orient3d => if (pts.len == 4) s.Predicates.orient3d(try point(3, pts[0]), try point(3, pts[1]), try point(3, pts[2]), try point(3, pts[3])) else error.InvalidFixture,
        .incircle => if (pts.len == 4) s.Predicates.incircle(try point(2, pts[0]), try point(2, pts[1]), try point(2, pts[2]), try point(2, pts[3])) else error.InvalidFixture,
        .insphere => if (pts.len == 5) s.Predicates.insphere(try point(3, pts[0]), try point(3, pts[1]), try point(3, pts[2]), try point(3, pts[3]), try point(3, pts[4])) else error.InvalidFixture,
        else => error.InvalidFixture,
    };
}
fn evaluate(case: Case, points: []s.Planar.Point, result: *Output) !void {
    switch (case.op) {
        .reference => {
            var bytes: [s.Reference.encoded_bytes]u8 = undefined;
            _ = try reference.encode(&bytes);
            const restored = try s.Reference.decode(&bytes);
            try reference.requireSame(restored);
            result.encoded = bytes;
            result.fingerprint = try restored.fingerprint();
        },
        .ring => {
            for (points, case.points) |*out, bits| out.* = try point(2, bits);
            var budget: s.Planar.Budget = .{ .remaining = case.budget };
            const ring = try s.Planar.Ring.init(reference, points, &budget, &result.witness);
            result.location = try ring.locate(try point(2, &case.query), &budget);
            result.area = try ring.signedArea(&budget);
        },
        .segment => {
            if (case.points.len != 4) return error.InvalidFixture;
            result.relation = try s.Planar.segmentRelation(try point(2, case.points[0]), try point(2, case.points[1]), try point(2, case.points[2]), try point(2, case.points[3]));
        },
        else => {
            const value = try determinant(case);
            result.sign = @backingInt(value.sign);
            result.path = value.path;
        },
    }
}
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 2) return error.InvalidFixture;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(8 * 1024 * 1024));
    const cases = try std.json.parseFromSlice([]const Case, allocator, bytes, .{});
    var max_points: usize = 0;
    for (cases.value) |case| max_points = @max(max_points, case.points.len);
    // Reusable fixture storage; no allocations inside any geometry operation.
    const scratch = try allocator.alloc(s.Planar.Point, max_points);
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (cases.value) |case| {
        var output: Output = .{};
        evaluate(case, scratch[0..case.points.len], &output) catch |err| {
            output.error_name = @errorName(err);
        };
        try std.json.Stringify.value(output, .{}, &stdout.interface);
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}
