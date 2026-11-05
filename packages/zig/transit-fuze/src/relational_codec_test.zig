const std = @import("std");
const t = std.testing;
const r = @import("Relational.zig");
const codec = @import("RelationalCodec.zig");
const columns = [_]@import("TableSchema.zig").Column{ .{ .id = 1, .name = "key", .type = .int64 }, .{ .id = 2, .name = "value", .type = .int64 } };
const sources = [_]r.Source{
    .{ .alias = "l", .realm = 1, .resource = 101, .catalog = 9, .owner = 7, .schema = .{ .object = 11, .revision = 1, .next_column = 3, .columns = &columns } },
    .{ .alias = "r", .realm = 1, .resource = 202, .catalog = 9, .owner = 7, .schema = .{ .object = 22, .revision = 1, .next_column = 3, .columns = &columns } },
};
const plan: r.Plan = .{ .sources = &sources, .join = .{ .kind = .left, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } }, .group_by = &.{.{ .source = 0, .id = 1 }}, .outputs = &.{
    .{ .name = "key", .expression = .{ .column = .{ .source = 0, .id = 1 } } },
    .{ .name = "rows", .expression = .count_all },
    .{ .name = "values", .expression = .{ .count = .{ .source = 1, .id = 2 } } },
    .{ .name = "total", .expression = .{ .sum = .{ .source = 1, .id = 2 } } },
}, .lifetime = .captured, .budgets = .{ .resident_bytes = 4096, .spill_bytes = 8192, .result_bytes = 16384, .output_rows = 1000, .work_steps = 10000, .source_pins = 2 } };
fn roundtrip(allocator: std.mem.Allocator) !void {
    var bytes: [codec.max_bytes]u8 = undefined;
    const encoded = try codec.encode(plan, &bytes);
    var decoded = try codec.decode(allocator, encoded);
    defer decoded.deinit();
    const parsed = try std.json.parseFromSlice(struct { identity: struct { prepared: []const u8 } }, allocator, @embedFile("fixtures/relational.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try t.expectEqualStrings(parsed.value.identity.prepared, &std.fmt.bytesToHex(&try decoded.plan.fingerprint(), .lower));
    // Decoded names and schema do not borrow a mutable caller buffer.
    @memset(bytes[0..encoded.len], 0);
    try t.expectEqualSlices(u8, &try plan.fingerprint(), &try decoded.plan.fingerprint());
}
test "relational artifact owns schemas and preserves the independent prepared identity" {
    try roundtrip(t.allocator);
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), roundtrip, .{});
}
test "relational artifact rejects truncation foreign definitions and trailing bytes" {
    var bytes: [codec.max_bytes]u8 = undefined;
    const encoded = try codec.encode(plan, &bytes);
    for (0..encoded.len) |size| {
        if (codec.decode(t.allocator, encoded[0..size])) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.AcceptedIncompletePlan;
        } else |_| {}
    }
    bytes[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, codec.decode(t.allocator, encoded));
    bytes[4] ^= 1;
    bytes[encoded.len] = 0;
    try t.expectError(error.InvalidRelationalEncoding, codec.decode(t.allocator, bytes[0 .. encoded.len + 1]));
    // The canonical prepared preimage cannot name a different source schema.
    var prepared: [r.max_plan_bytes]u8 = undefined;
    const identity = try plan.encodePrepared(&prepared);
    const start = encoded.len - identity.len;
    const schema_hash = start + (r.definition ++ "\x00prepared\x00").len + 1 + 2 + 32;
    bytes[schema_hash] ^= 1;
    try t.expectError(error.RelationalSourceChanged, codec.decode(t.allocator, encoded));
}
test "relational artifact round-trips HAVING ORDER BY and LIMIT" {
    const having_instructions = [_]r.HavingInstruction{
        .{ .compare = .{ .expression = .count_all, .op = .greater_equal, .value = .{ .integer = 2 } } },
        .{ .is_not_null = .{ .sum = .{ .source = 1, .id = 2 } } },
        .conjunction,
    };
    const order_items = [_]r.OrderBy{
        .{ .expression = .{ .sum = .{ .source = 1, .id = 2 } }, .direction = .desc, .nulls = .last },
        .{ .expression = .{ .column = .{ .source = 0, .id = 1 } }, .direction = .asc, .nulls = .first },
    };
    var extended = plan;
    extended.having = .{ .instructions = &having_instructions };
    extended.order_by = &order_items;
    extended.limit = 25;
    var bytes: [codec.max_bytes]u8 = undefined;
    const encoded = try codec.encode(extended, &bytes);
    var decoded = try codec.decode(t.allocator, encoded);
    defer decoded.deinit();
    try t.expectEqualSlices(u8, &try extended.fingerprint(), &try decoded.plan.fingerprint());
    try t.expectEqual(@as(?u64, 25), decoded.plan.limit);
    try t.expectEqual(@as(usize, 2), decoded.plan.order_by.len);
    try t.expectEqual(r.Direction.desc, decoded.plan.order_by[0].direction);
    try t.expectEqual(r.NullOrder.last, decoded.plan.order_by[0].nulls);
}
