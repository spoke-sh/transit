const std = @import("std");
const t = std.testing;
const c = @import("LogicalPlanCodec.zig");
const q = @import("LogicalQuery.zig");
const types = @import("Types.zig");
const ddl = @import("TableDdl.zig");
const select = @import("TableSelect.zig");
const basis: [32]u8 = @splat(7);
fn roundtrip(allocator: std.mem.Allocator, schema: types.Type, bytes: []const u8, fingerprint: [32]u8) !void {
    var owned = try c.decode(allocator, schema, basis, bytes);
    defer owned.deinit();
    try t.expectEqualSlices(u8, &fingerprint, &try owned.plan.fingerprint());
    var output: [c.max_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, bytes, try c.encode(owned.plan, &output));
}
test "logical plans preserve typed predicates projections output names and aggregate identity" {
    var table = try ddl.compile(t.allocator, "CREATE TABLE people (id INT, name TEXT, amount INT64, detail STRUCT(x INT128, list LIST(TEXT)))", null, null);
    defer table.deinit();
    var fields: [128]types.Field = undefined;
    const schema = try (try table.statement.create.bind(1)).rowType(&fields);
    for ([_][]const u8{
        "SELECT * FROM people",
        "SELECT id, name FROM people WHERE id >= -12 AND NOT (name = '東京' OR name IS NULL) LIMIT 3",
        "SELECT id AS x, id AS y FROM people LIMIT 0",
        "SELECT COUNT(detail) FROM people",
        "SELECT COUNT(*) AS total FROM people",
        "SELECT SUM(amount) FROM people WHERE amount IS NOT NULL",
        "SELECT SUM(x) FROM (SELECT amount AS x FROM people LIMIT 4) AS p",
    }) |text| {
        var compiled = try select.compile(t.allocator, text, "people", schema, basis, null);
        defer compiled.deinit();
        var bytes: [c.max_bytes + 1]u8 = undefined;
        const encoded = try c.encode(compiled.plan, &bytes);
        try t.checkAllAllocationFailures(t.allocator, roundtrip, .{ schema, encoded, try compiled.plan.fingerprint() });
        for (0..encoded.len) |length| {
            if (c.decode(t.allocator, schema, basis, encoded[0..length])) |value| {
                var owner = value;
                owner.deinit();
                return error.AcceptedTruncatedPlan;
            } else |_| {}
        }
        bytes[encoded.len] = 0;
        try t.expectError(error.InvalidPlanEncoding, c.decode(t.allocator, schema, basis, bytes[0 .. encoded.len + 1]));
        var owned = try c.decode(t.allocator, schema, basis, encoded);
        defer owned.deinit();
        @memset(&bytes, 0);
        try t.expectEqualSlices(u8, &try compiled.plan.fingerprint(), &try owned.plan.fingerprint());
        try t.expect(owned.plan.schema.structure.ptr != schema.structure.ptr);
        try t.expectEqualStrings("list", owned.plan.schema.structure[3].type.structure[1].name);
    }
}
test "logical plan binding rejects foreign definitions sources and schemas before allocation" {
    const schema: types.Type = .{ .structure = &.{.{ .name = "id", .type = .int32 }} };
    const plan: q.Plan = .{ .schema = schema, .source_basis = basis, .projection = &.{0} };
    var bytes: [c.max_bytes]u8 = undefined;
    const encoded = try c.encode(plan, &bytes);
    var empty: std.heap.FixedBufferAllocator = .init(&.{});
    const a = empty.allocator();
    try t.expectError(error.UnsupportedPlanDefinition, c.decode(a, schema, basis, encoded[0..4]));
    bytes[4] ^= 1;
    try t.expectError(error.UnsupportedPlanDefinition, c.decode(a, schema, basis, encoded));
    bytes[4] ^= 1;
    try t.expectError(error.SourceChanged, c.decode(a, schema, @splat(8), encoded));
    const changed: types.Type = .{ .structure = &.{.{ .name = "id", .type = .int64 }} };
    try t.expectError(error.SourceChanged, c.decode(a, changed, basis, encoded));
    bytes[100] = 255; // invalid aggregate
    try t.expectError(error.InvalidPlanEncoding, c.decode(t.allocator, schema, basis, encoded));
    bytes[100] = 0;
    bytes[101] = 0; // empty projection
    try t.expectError(error.InvalidProjection, c.decode(t.allocator, schema, basis, encoded));
    _ = try c.encode(plan, &bytes);
    bytes[102] = 128;
    try t.expectError(error.UnknownColumn, c.decode(t.allocator, schema, basis, encoded));
    _ = try c.encode(plan, &bytes);
    bytes[105] = 1; // absent LIMIT must have a zero payload
    try t.expectError(error.InvalidPlanEncoding, c.decode(t.allocator, schema, basis, encoded));
}
test "independent logical plan bytes bind the full row schema and exact query identity" {
    const Fixture = struct { schema_hex: []const u8, select_hex: []const u8, select_fingerprint: []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/table-schema.json"), .{ .ignore_unknown_fields = true });
    defer fixture.deinit();
    var schema_bytes: [@import("TableSchema.zig").max_bytes]u8 = undefined;
    var table = try @import("TableSchema.zig").decode(t.allocator, try std.fmt.hexToBytes(&schema_bytes, fixture.value.schema_hex));
    defer table.deinit();
    var fields: [128]types.Field = undefined;
    const schema = try table.schema.rowType(&fields);
    var expected: [c.max_bytes]u8 = undefined;
    const bytes = try std.fmt.hexToBytes(&expected, fixture.value.select_hex);
    var owned = try c.decode(t.allocator, schema, basis, bytes);
    defer owned.deinit();
    var fingerprint: [32]u8 = undefined;
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&fingerprint, fixture.value.select_fingerprint), &try owned.plan.fingerprint());
    var compiled = try select.compile(t.allocator, "SELECT name AS chosen, id FROM people WHERE id = 12 OR name IS NULL LIMIT 3", "people", schema, basis, null);
    defer compiled.deinit();
    var output: [c.max_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, bytes, try c.encode(compiled.plan, &output));
}

test "logical plan codec preserves every scalar comparison family without narrowing" {
    const Case = struct { type: types.Type, atom: types.Semantics.Atom };
    for ([_]Case{
        .{ .type = .int8, .atom = .{ .signed = -128 } },
        .{ .type = .int16, .atom = .{ .signed = -32768 } },
        .{ .type = .int32, .atom = .{ .signed = std.math.minInt(i32) } },
        .{ .type = .int64, .atom = .{ .signed = std.math.minInt(i64) } },
        .{ .type = .int128, .atom = .{ .signed = std.math.minInt(i128) } },
        .{ .type = .uint8, .atom = .{ .unsigned = 255 } },
        .{ .type = .uint16, .atom = .{ .unsigned = 65535 } },
        .{ .type = .uint32, .atom = .{ .unsigned = std.math.maxInt(u32) } },
        .{ .type = .uint64, .atom = .{ .unsigned = std.math.maxInt(u64) } },
        .{ .type = .uint128, .atom = .{ .unsigned = std.math.maxInt(u128) } },
        .{ .type = .float32, .atom = .{ .float = -0.0 } },
        .{ .type = .float64, .atom = .{ .float = -0.0 } },
        .{ .type = .{ .decimal = .{ .precision = 38, .scale = 2 } }, .atom = .{ .decimal = -12345678901234567890123456789012345678 } },
        .{ .type = .boolean, .atom = .{ .boolean = true } },
        .{ .type = .utf8, .atom = .{ .bytes = "東京" } },
        .{ .type = .binary, .atom = .{ .bytes = "\x00\xff" } },
        .{ .type = .date, .atom = .{ .date = -1 } },
        .{ .type = .time, .atom = .{ .time = 86399999999999 } },
        .{ .type = .{ .timestamp = .civil }, .atom = .{ .timestamp = -1 } },
        .{ .type = .{ .timestamp = .utc }, .atom = .{ .timestamp = 1 } },
        .{ .type = .uuid, .atom = .{ .uuid = @splat(255) } },
    }) |value| {
        const schema: types.Type = .{ .structure = &.{.{ .name = "x", .type = value.type }} };
        const plan: q.Plan = .{ .schema = schema, .source_basis = basis, .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = value.atom } } };
        var output: [c.max_bytes]u8 = undefined;
        try roundtrip(t.allocator, schema, try c.encode(plan, &output), try plan.fingerprint());
    }
    const oversized: [c.max_bytes + 1]u8 = @splat(0);
    try t.expectError(error.PlanTooLarge, c.decode(t.allocator, .int64, basis, &oversized));
}
