const std = @import("std");
const t = std.testing;
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const x = @import("RelationalExchange.zig");
const columns = [_]@import("TableSchema.zig").Column{ .{ .id = 1, .name = "k", .type = .int64, .nullable = true }, .{ .id = 2, .name = "v", .type = .int64, .nullable = true } };
const sources = [_]r.Source{
    .{ .alias = "l", .realm = 1, .resource = 101, .catalog = 9, .owner = 7, .schema = .{ .object = 11, .revision = 1, .next_column = 3, .columns = &columns } },
    .{ .alias = "r", .realm = 1, .resource = 202, .catalog = 9, .owner = 8, .schema = .{ .object = 22, .revision = 1, .next_column = 3, .columns = &columns } },
};
const plan: r.Plan = .{ .sources = &sources, .join = .{ .kind = .left, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } }, .outputs = &.{.{ .name = "v", .expression = .{ .column = .{ .source = 1, .id = 2 } } }}, .lifetime = .captured, .budgets = .{ .resident_bytes = 1024 * 1024, .spill_bytes = 1024 * 1024, .result_bytes = 16384, .output_rows = 100, .work_steps = 10000, .source_pins = 2 } };
fn cuts() ![2]r.Cut {
    var result: [2]r.Cut = undefined;
    for (sources, 0..) |source, i| result[i] = .{ .domain = .native_resource, .resource = source.resource, .revision = 1, .commitment = @splat(1), .schema = try source.schema.fingerprint() };
    return result;
}
fn row(id: u64, key: ?i64) e.Row {
    var result: e.Row = .{ .identity = .{ .origin = 1, .operation = id, .ordinal = 0 } };
    result.values[0] = key;
    result.values[1] = 9;
    return result;
}
test "routing colocates equal join keys independent of aliases identities values and worker count" {
    for ([_]u64{ 1, 2, 7, 257, std.math.maxInt(u64) }) |partitions| for ([_]?i64{ null, 0, -1, std.math.minInt(i64), std.math.maxInt(i64) }) |value| {
        var right = row(100, value);
        right.values[1] = -8;
        try t.expectEqual(try x.route(plan, 0, partitions, row(1, value)), try x.route(plan, 1, partitions, right));
    };
    // Independently calculated SHA-256(domain || join-tag || null/int64 key).
    try t.expectEqual(@as(u64, 0), try x.route(plan, 0, 1, row(1, 7)));
    try t.expectError(error.InvalidRelationalExchange, x.route(plan, 0, 0, row(1, 7)));
    var invalid = row(1, 7);
    invalid.values[2] = 1;
    try t.expectError(error.InvalidRelationalSourceRow, x.route(plan, 0, 2, invalid));
}
test "exchange bytes and routing agree with the independent Python contract fixtures" {
    const Fixture = struct { segment: []const u8, routing: []const struct { key: ?i64, partitions: u64, partition: u64 } };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/relational-exchange.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    for (parsed.value.routing) |sample| try t.expectEqual(sample.partition, try x.route(plan, 0, sample.partitions, row(1, sample.key)));
    var fixture_columns = columns;
    fixture_columns[0].name = "key";
    fixture_columns[1].name = "value";
    var fixture_sources = sources;
    for (&fixture_sources) |*source| {
        source.owner = 7;
        source.schema.columns = &fixture_columns;
    }
    var fixture_plan = plan;
    fixture_plan.sources = &fixture_sources;
    fixture_plan.group_by = &.{.{ .source = 0, .id = 1 }};
    fixture_plan.outputs = &.{
        .{ .name = "key", .expression = .{ .column = .{ .source = 0, .id = 1 } } },
        .{ .name = "rows", .expression = .count_all },
        .{ .name = "values", .expression = .{ .count = .{ .source = 1, .id = 2 } } },
        .{ .name = "total", .expression = .{ .sum = .{ .source = 1, .id = 2 } } },
    };
    fixture_plan.budgets = .{ .resident_bytes = 4096, .spill_bytes = 8192, .result_bytes = 16384, .output_rows = 1000, .work_steps = 10000, .source_pins = 2 };
    const basis = [_]r.Cut{
        .{ .domain = .native_resource, .resource = 101, .revision = 7, .commitment = @splat(17), .schema = try fixture_sources[0].schema.fingerprint() },
        .{ .domain = .native_resource, .resource = 202, .revision = 12, .commitment = @splat(34), .schema = try fixture_sources[1].schema.fingerprint() },
    };
    const bound: r.Bound = .{ .plan = fixture_plan, .cuts = &basis };
    var bytes: [x.max_bytes]u8 = undefined;
    const encoded = try std.fmt.hexToBytes(&bytes, parsed.value.segment);
    const segment = try x.Segment.decode(bound, encoded);
    try t.expectEqual(@as(u8, 2), segment.len);
    try t.expectEqual(@as(?i64, 9), segment.rows[0].values[1]);
    try t.expectEqual(@as(?i64, null), segment.rows[1].values[1]);
    try t.expectEqual(@as(u64, 3), segment.epoch);
    var rewritten: [x.max_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, encoded, try segment.encode(bound, &rewritten));
}
test "exchange segments bind exact cuts and require canonical rows routing and explicit empty completion" {
    const basis = try cuts();
    const bound: r.Bound = .{ .plan = plan, .cuts = &basis };
    var segment: x.Segment = .{ .exchange = 88, .source = 0, .partitions = 7, .partition = try x.route(plan, 0, 7, row(1, 7)), .epoch = 1, .sequence = 0, .terminal = true, .len = 2 };
    segment.rows[0] = row(1, 7);
    segment.rows[1] = row(2, 7);
    var bytes: [x.max_bytes + 1]u8 = undefined;
    const encoded = try segment.encode(bound, &bytes);
    const decoded = try x.Segment.decode(bound, encoded);
    try t.expectEqualDeep(segment.rows[0..2], decoded.rows[0..2]);
    try t.expectEqual(segment.partition, decoded.partition);
    for (0..encoded.len) |length| {
        if (x.Segment.decode(bound, encoded[0..length])) |_| return error.AcceptedTruncatedExchange else |_| {}
    }
    bytes[encoded.len] = 0;
    try t.expectError(error.InvalidRelationalExchange, x.Segment.decode(bound, bytes[0 .. encoded.len + 1]));
    bytes[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, x.Segment.decode(bound, encoded));
    bytes[4] ^= 1;
    var changed = basis;
    changed[0].revision += 1;
    try t.expectError(error.RelationalSourceChanged, x.Segment.decode(.{ .plan = plan, .cuts = &changed }, encoded));
    segment.rows[1] = segment.rows[0];
    try t.expectError(error.InvalidRelationalSourceOrder, segment.encode(bound, &bytes));
    segment.len = 0;
    segment.terminal = false;
    try t.expectError(error.InvalidRelationalExchange, segment.encode(bound, &bytes));
    segment.terminal = true;
    try t.expectEqual(@as(u8, 0), (try x.Segment.decode(bound, try segment.encode(bound, &bytes))).len);
    segment.len = 5;
    try t.expectError(error.InvalidRelationalExchange, segment.encode(bound, &bytes));
}
