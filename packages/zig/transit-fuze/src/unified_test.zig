const std = @import("std");
const t = std.testing;
const m = @import("Unified.zig");
const columns = [_]m.Column{
    .{ .name = m.Name.init("key") catch unreachable, .type = .uint64 },
    .{ .name = m.Name.init("value") catch unreachable, .type = .utf8 },
};
const schema: m.Schema = .{ .columns = &columns };
fn basis(kind: m.SourceKind) !m.Basis {
    return .{ .kind = kind, .resource = 17, .revision = 29, .contract = @splat(7), .schema = try schema.fingerprint() };
}
test "unified model keeps absent null type-error value and conflict distinct" {
    const alternatives = [_]m.Alternative{
        .{ .counter = 5, .replica = 1, .value = .{ .value = .{ .utf8 = "left🙂" } } },
        .{ .counter = 5, .replica = 2, .value = .null },
        .{ .counter = 6, .replica = 1, .value = .{ .type_error = .list } },
    };
    const cells = [_]m.Cell{ .missing, .null, .{ .type_error = .map }, .{ .value = .{ .utf8 = "" } }, .{ .conflict = &alternatives } };
    for (cells, 0..) |cell, index| {
        try cell.validate(.utf8);
        const plan: m.Plan = .{ .projection = &.{0}, .predicate = .{ .state = .{ .column = 0, .value = @fromBackingInt(@intCast(index)) } } };
        for (cells, 0..) |candidate, other| try t.expectEqual(index == other, try plan.matches(.{ .cells = &.{candidate} }));
    }
    const comparison: m.Plan = .{ .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .utf8 = "" } } } };
    try t.expect(!try comparison.matches(.{ .cells = &.{.missing} }));
    try t.expect(!try comparison.matches(.{ .cells = &.{.null} }));
    try t.expectError(error.QueryTypeError, comparison.matches(.{ .cells = &.{cells[2]} }));
    try t.expectError(error.QueryConflict, comparison.matches(.{ .cells = &.{cells[4]} }));
    try t.expectError(error.InvalidConflict, (m.Cell{ .conflict = alternatives[0..1] }).validate(.utf8));
    const reversed = [_]m.Alternative{ alternatives[1], alternatives[0] };
    try t.expectError(error.InvalidConflict, (m.Cell{ .conflict = &reversed }).validate(.utf8));
}
test "one typed plan binds all source kinds and exact contract and schema evidence" {
    const plan: m.Plan = .{ .projection = &.{ 1, 0 }, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .uint64 = std.math.maxInt(u64) } } } };
    for ([_]m.SourceKind{ .kv, .table, .document }) |kind| {
        const bound = try plan.bind(try basis(kind), schema);
        try t.expectEqual(kind, bound.basis.kind);
        const cells = [_]m.Cell{ .{ .value = .{ .uint64 = std.math.maxInt(u64) } }, .{ .value = .{ .utf8 = "🙂" } } };
        try (m.Page{ .basis = bound.basis, .ordinal = 0, .rows = &.{.{ .cells = &cells }}, .end = true }).validate(schema);
        try t.expect(try bound.plan.matches(.{ .cells = &cells }));
    }
    var invalid = try basis(.kv);
    invalid.schema[0] ^= 1;
    try t.expectError(error.SourceChanged, plan.bind(invalid, schema));
    try t.expectError(error.TypeMismatch, (m.Plan{ .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .int64 = -1 } } } }).bind(try basis(.kv), schema));
    try t.expectError(error.UnsupportedAggregate, (m.Plan{ .projection = &.{0}, .aggregate = .sum }).bind(try basis(.kv), schema));
    try t.expectError(error.DuplicateProjection, (m.Plan{ .projection = &.{ 0, 0 } }).bind(try basis(.kv), schema));
}
test "canonical FZP2 preserves wide literals negative zero binary and larger plans" {
    const long: [512]u8 = @splat('x');
    const values = [_]m.Scalar{ .{ .int64 = std.math.minInt(i64) }, .{ .uint64 = std.math.maxInt(u64) }, .{ .float64 = -0.0 }, .{ .boolean = false }, .{ .utf8 = "🙂" }, .{ .binary = &.{ 0, 255 } }, .{ .utf8 = &long } };
    for (values) |value| {
        const plan: m.Plan = .{ .projection = &.{ 0, 1 }, .limit = std.math.maxInt(u64), .predicate = .{ .compare = .{ .column = 1, .op = .ne, .value = value } } };
        var output: [m.Codec.max_plan_bytes]u8 = undefined;
        const encoded = try m.Codec.encode(plan, &output);
        const decoded = try m.Codec.decode(encoded);
        try t.expectEqual(plan.limit, decoded.limit);
        const scalar = decoded.predicate.compare.value;
        try t.expectEqual(std.math.Order.eq, try value.order(scalar));
        if (value == .float64) try t.expectEqual(@as(u64, 1 << 63), @as(u64, @bitCast(scalar.float64)));
        if (value == .utf8 and value.utf8.len == long.len) try t.expect(encoded.len > 207);
        for (0..encoded.len) |length| {
            if (m.Codec.decode(encoded[0..length])) |_| return error.AcceptedTruncatedPlan else |_| {}
        }
        output[encoded.len] = 0;
        try t.expectError(error.InvalidPlanEncoding, m.Codec.decode(output[0 .. encoded.len + 1]));
    }
    try t.expectError(error.NonFiniteValue, (m.Scalar{ .float64 = std.math.inf(f64) }).validate(.float64));
    try t.expectError(error.InvalidUtf8, (m.Scalar{ .utf8 = "\xff" }).validate(.utf8));
}

test "independent canonical query fixtures bind exact schema and plan digests" {
    const Fixture = struct { plans: []const struct { name: []const u8, type: u8, wire_hex: []const u8, digest: []const u8 }, schema: []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/unified.json"), .{});
    defer fixture.deinit();
    var digest: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&digest, fixture.value.schema);
    try t.expectEqualSlices(u8, &digest, &try schema.fingerprint());
    for (fixture.value.plans) |item| {
        var bytes: [m.Codec.max_plan_bytes]u8 = undefined;
        const encoded = try std.fmt.hexToBytes(&bytes, item.wire_hex);
        const plan = try m.Codec.decode(encoded);
        try t.expectEqual(item.type, @backingInt(std.meta.activeTag(plan.predicate.compare.value)));
        try t.expectEqual(@as(?u64, std.math.maxInt(u64)), plan.limit);
        var matching_columns = columns;
        matching_columns[1].type = @fromBackingInt(@intCast(item.type));
        const matching: m.Schema = .{ .columns = &matching_columns };
        var cut = try basis(.kv);
        cut.schema = try matching.fingerprint();
        const bound = try plan.bind(cut, matching);
        _ = try std.fmt.hexToBytes(&digest, item.digest);
        try t.expectEqualSlices(u8, &digest, &bound.fingerprint);
    }
}
