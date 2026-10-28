const std = @import("std");
const e = std.testing;
const r = @import("TableRow.zig");
const s = @import("TableSchema.zig");
const t = @import("Types.zig");
const Cell = t.Values.Cell;
const schema: s.Schema = .{ .object = 5, .revision = 1, .next_column = 5, .columns = &.{
    .{ .id = 1, .name = "tenant", .type = .utf8, .nullable = false },
    .{ .id = 2, .name = "key", .type = .float64, .nullable = false },
    .{ .id = 4, .name = "value", .type = .{ .list = .{ .type = &.int128 } } },
}, .primary_key = &.{ 1, 2 } };
const cells = [_]Cell{
    .{ .value = .{ .atom = .{ .bytes = "tenant A" } } },
    .{ .value = .{ .atom = .{ .float = -0.0 } } },
    .{ .value = .{ .list = &.{.{ .value = .{ .atom = .{ .signed = std.math.maxInt(i128) } } }} } },
};
const row: r.Row = .{ .identity = .{ .origin = 7, .operation = 12, .ordinal = 0 }, .cells = &cells };

test "row envelopes bind physical layouts, preserve IEEE signs and own decoded nested values" {
    var bytes: [4096]u8 = undefined;
    const encoded = try row.encode(schema, &bytes);
    try e.expectEqual(encoded.len, try row.encodedSize(schema));
    var decoded = try r.decode(e.allocator, schema, encoded);
    defer decoded.deinit();
    try e.expectEqualDeep(row.identity, decoded.identity);
    try e.expectEqualDeep(cells, decoded.row().cells[0..3].*);
    try e.expectEqual(@as(u64, 1) << 63, @as(u64, @bitCast(decoded.row().cells[1].value.atom.float)));
    var changed = schema;
    changed.revision += 1;
    var metadata = try r.decode(e.allocator, changed, encoded);
    metadata.deinit();
    try e.expect(!std.mem.eql(u8, &try changed.fingerprint(), &try schema.fingerprint()));
    changed = schema;
    changed.object += 1;
    try e.expectError(error.TableSchemaChanged, r.decode(e.allocator, changed, encoded));
    for (0..encoded.len) |size| {
        if (r.decode(e.allocator, schema, encoded[0..size])) |found| {
            var owned = found;
            owned.deinit();
            return error.AcceptedTruncation;
        } else |_| {}
    }
    bytes[encoded.len] = 0;
    try e.expectError(error.InvalidValueEncoding, r.decode(e.allocator, schema, bytes[0 .. encoded.len + 1]));
    try e.checkAllAllocationFailures(e.allocator, copy, .{encoded});
    @memset(&bytes, 0);
    try e.expectEqualStrings("tenant A", decoded.row().cells[0].value.atom.bytes);
}
test "metadata renames preserve row bytes while IDs and types change physical layout" {
    var bytes: [4096]u8 = undefined;
    const encoded = try row.encode(schema, &bytes);
    var renamed = schema.columns[0..3].*;
    renamed[0].name = "renamed";
    var changed = schema;
    changed.columns = &renamed;
    changed.revision += 1;
    var decoded = try r.decode(e.allocator, changed, encoded);
    decoded.deinit();
    var after: [4096]u8 = undefined;
    try e.expectEqualSlices(u8, encoded, try row.encode(changed, &after));
    renamed[2].id = 3;
    try e.expectError(error.TableSchemaChanged, r.decode(e.allocator, changed, encoded));
    renamed[2] = schema.columns[2];
    renamed[2].type = .utf8;
    try e.expectError(error.TableSchemaChanged, r.decode(e.allocator, changed, encoded));
}
fn copy(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var owned = try r.decode(allocator, schema, bytes);
    defer owned.deinit();
}
test "row decoding reuses caller scratch without backing allocations after warmup" {
    var bytes: [4096]u8 = undefined;
    const encoded = try row.encode(schema, &bytes);
    var probe: @import("transit_memory").AllocationProbe = .{ .parent = e.allocator };
    var arena = std.heap.ArenaAllocator.init(probe.allocator());
    defer arena.deinit();
    _ = try r.decodeInto(arena.allocator(), schema, encoded);
    _ = arena.reset(.retain_capacity);
    probe.begin(true);
    for (0..32) |_| {
        const decoded = try r.decodeInto(arena.allocator(), schema, encoded);
        try e.expectEqualDeep(row.identity, decoded.identity);
        try e.expectEqualDeep(cells, decoded.row().cells[0..3].*);
        _ = arena.reset(.retain_capacity);
    }
    try probe.verify();
    try e.expectEqual(@as(usize, 0), probe.counts.forbidden_attempts);
}
test "independent Python physical row and composite-key framing oracle" {
    const Fixture = struct { schema_hex: []const u8, row_hex: []const u8, layout: []const u8, key_hex: []const u8, key_digest: []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, e.allocator, @embedFile("fixtures/table-schema.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    var bytes: [s.max_bytes]u8 = undefined;
    var owned = try s.decode(e.allocator, try std.fmt.hexToBytes(&bytes, parsed.value.schema_hex));
    defer owned.deinit();
    const selected = owned.schema;
    var digest: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&digest, parsed.value.layout);
    try e.expectEqualSlices(u8, &digest, &try selected.layoutFingerprint());
    const values = [_]Cell{
        .{ .value = .{ .atom = .{ .signed = 12 } } },
        .{ .value = .{ .atom = .{ .bytes = "東京é" } } },
        .{ .value = .{ .atom = .{ .boolean = true } } },
        .null,
    };
    var expected: [4096]u8 = undefined;
    var actual: [4096]u8 = undefined;
    const oracle_row: r.Row = .{ .identity = row.identity, .cells = &values };
    try e.expectEqual(parsed.value.row_hex.len / 2, try oracle_row.encodedSize(selected));
    try e.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, parsed.value.row_hex), try oracle_row.encode(selected, &actual));
    try e.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, parsed.value.key_hex), try r.encodeKey(selected, &values, &actual));
    _ = try std.fmt.hexToBytes(&digest, parsed.value.key_digest);
    try e.expectEqualSlices(u8, &digest, &try r.keyDigest(selected, &values, &actual));
}
test "composite key equality normalizes floating zero and survives column rename" {
    var positive = cells;
    positive[1].value.atom.float = 0;
    positive[2] = .null;
    var first: [4096]u8 = undefined;
    var second: [4096]u8 = undefined;
    const before = try r.encodeKey(schema, &cells, &first);
    try e.expectEqualSlices(u8, before, try r.encodeKey(schema, &positive, &second));
    try e.expect(try r.sameKey(schema, &cells, &positive));
    var renamed = schema.columns[0..3].*;
    renamed[0].name = "renamed";
    var changed = schema;
    changed.columns = &renamed;
    changed.revision += 1;
    try e.expectEqualSlices(u8, before, try r.encodeKey(changed, &cells, &second));
    positive[0].value.atom.bytes = "tenant B";
    try e.expect(!try r.sameKey(schema, &cells, &positive));
    try e.expect(!std.mem.eql(u8, before, try r.encodeKey(schema, &positive, &second)));
    changed = schema;
    changed.primary_key = &.{ 2, 1 };
    try e.expect(!std.mem.eql(u8, before, try r.encodeKey(changed, &cells, &second)));
    changed.primary_key = &.{};
    try e.expectError(error.NoPrimaryKey, r.encodeKey(changed, &cells, &second));
}
test "row identity is independent of duplicate payloads and rejects unallocated identities" {
    var first: [4096]u8 = undefined;
    var second: [4096]u8 = undefined;
    var duplicate = row;
    duplicate.identity.ordinal = 1;
    try e.expect(!std.mem.eql(u8, try row.encode(schema, &first), try duplicate.encode(schema, &second)));
    try e.expectEqual(std.math.Order.lt, std.mem.order(u8, &try row.identity.encode(), &try duplicate.identity.encode()));
    duplicate.identity.origin = 0;
    try e.expectError(error.InvalidRowIdentity, duplicate.encode(schema, &second));
    try e.expectError(error.InvalidRowIdentity, duplicate.encodedSize(schema));
}

test "row size counting preserves wide binary values and validation bounds without output storage" {
    const large_schema: s.Schema = .{ .object = 5, .revision = 1, .next_column = 2, .columns = &.{
        .{ .id = 1, .name = "payload", .type = .binary, .nullable = false },
    }, .primary_key = &.{} };
    const payload = try e.allocator.alloc(u8, (t.Limits{}).value_bytes + 1);
    defer e.allocator.free(payload);
    @memset(payload, 0xa5);
    const output = try e.allocator.alloc(u8, r.max_bytes);
    defer e.allocator.free(output);
    for ([_]usize{ 0, 1, 255, 256, 257, 65536, (t.Limits{}).value_bytes }) |size| {
        const values = [_]Cell{.{ .value = .{ .atom = .{ .bytes = payload[0..size] } } }};
        const candidate: r.Row = .{ .identity = row.identity, .cells = &values };
        const encoded = try candidate.encode(large_schema, output);
        try e.expectEqual(encoded.len, try candidate.encodedSize(large_schema));
    }
    const too_wide = [_]Cell{.{ .value = .{ .atom = .{ .bytes = payload } } }};
    const invalid: r.Row = .{ .identity = row.identity, .cells = &too_wide };
    try e.expectError(error.ValueBudgetExceeded, invalid.encode(large_schema, output));
    try e.expectError(error.ValueBudgetExceeded, invalid.encodedSize(large_schema));
}
