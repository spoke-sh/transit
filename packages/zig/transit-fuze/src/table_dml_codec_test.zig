const std = @import("std");
const t = std.testing;
const d = @import("TableDml.zig");
const c = @import("TableDmlCodec.zig");
const s = @import("TableSchema.zig");
const schema: s.Schema = .{ .object = 10, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64, .nullable = false }, .{ .id = 2, .name = "value", .type = .int64 } }, .primary_key = &.{1} };
fn roundtrip(allocator: std.mem.Allocator, bytes: []const u8, fingerprint: [32]u8) !void {
    var decoded = try c.decode(allocator, schema, bytes);
    defer decoded.deinit();
    try t.expectEqualSlices(u8, &fingerprint, &try decoded.plan.fingerprint(allocator));
    var output: [8192]u8 = undefined;
    try t.expectEqualSlices(u8, bytes, try c.encode(allocator, decoded.plan, &output));
}
test "compact DML preserves exact typed intent predicates defaults and ownership" {
    for ([_][]const u8{
        "INSERT INTO items VALUES (1, 100)",
        "INSERT INTO items VALUES (1, 100), (2, NULL)",
        "UPDATE items SET value = 101 WHERE id = 1",
        "UPDATE items SET value = DEFAULT WHERE id >= 1 AND NOT (value = 3 OR value IS NULL)",
        "DELETE FROM items WHERE id = 1 AND value = 100",
        "DELETE FROM items",
    }) |sql| {
        var plan = try d.compile(t.allocator, sql, "items", schema, null);
        defer plan.deinit();
        var output: [8192]u8 = undefined;
        const encoded = try c.encode(t.allocator, plan.plan, &output);
        // Leave room for the intended native scope/owner/object/metadata header.
        if (std.mem.eql(u8, sql, "INSERT INTO items VALUES (1, 100)") or std.mem.eql(u8, sql, "UPDATE items SET value = 101 WHERE id = 1")) try t.expect(encoded.len + 141 <= 243);
        try t.checkAllAllocationFailures(t.allocator, roundtrip, .{ encoded, try plan.plan.fingerprint(t.allocator) });
        var payload_buffer: [8192]u8 = undefined;
        const payload = try c.encodePayload(t.allocator, plan.plan, &payload_buffer);
        try t.expectEqualSlices(u8, encoded[37 + plan.plan.name.len ..], payload);
        var bound = try c.decodePayload(t.allocator, schema, plan.plan.name, payload);
        defer bound.deinit();
        try t.expectEqualSlices(u8, &try plan.plan.fingerprint(t.allocator), &try bound.plan.fingerprint(t.allocator));
        for (0..encoded.len) |len| {
            if (c.decode(t.allocator, schema, encoded[0..len])) |value| {
                var owned = value;
                owned.deinit();
                return error.AcceptedTruncation;
            } else |_| {}
        }
        output[encoded.len] = 0;
        try t.expectError(error.InvalidMutationPlan, c.decode(t.allocator, schema, output[0 .. encoded.len + 1]));
        var changed = schema;
        changed.revision += 1;
        try t.expectError(error.TableSchemaChanged, c.decode(t.allocator, changed, encoded));
    }
}
test "compact DML validates altered tags lengths and row states before admission" {
    var plan = try d.compile(t.allocator, "INSERT INTO items VALUES (1, 100)", "items", schema, null);
    defer plan.deinit();
    var output: [512]u8 = undefined;
    const bytes = try c.encode(t.allocator, plan.plan, &output);
    const pristine = output;
    // Header ends after FDM1, 32-byte fingerprint and length-prefixed name.
    const action = 37 + "items".len;
    output[action] = 99;
    try t.expectError(error.InvalidMutationPlan, c.decode(t.allocator, schema, bytes));
    output = pristine;
    output[action + 1] = 0;
    output[action + 2] = 0;
    try t.expectError(error.MutationBatchTooLarge, c.decode(t.allocator, schema, bytes));
    output = pristine;
    // The entire row cannot be NULL. Individual nullable cells may be.
    output[action + 7] = 1;
    if (c.decode(t.allocator, schema, bytes)) |value| {
        var owned = value;
        owned.deinit();
        return error.AcceptedInvalidRow;
    } else |_| {}
    output = pristine;
    @memset(output[action + 3 .. action + 7], 255);
    try t.expectError(error.ValueBudgetExceeded, c.decode(t.allocator, schema, bytes));
}

test "independent compact DML bytes bind defaults Unicode and original schema" {
    const Fixture = struct { schema_hex: []const u8, dml_hex: []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/table-schema.json"), .{ .ignore_unknown_fields = true });
    defer fixture.deinit();
    var schema_bytes: [s.max_bytes]u8 = undefined;
    var expected: [4096]u8 = undefined;
    var owner = try s.decode(t.allocator, try std.fmt.hexToBytes(&schema_bytes, fixture.value.schema_hex));
    defer owner.deinit();
    const bytes = try std.fmt.hexToBytes(&expected, fixture.value.dml_hex);
    var plan = try c.decode(t.allocator, owner.schema, bytes);
    defer plan.deinit();
    var output: [4096]u8 = undefined;
    try t.expectEqualSlices(u8, bytes, try c.encode(t.allocator, plan.plan, &output));
    var payload_output: [4096]u8 = undefined;
    const payload = try c.encodePayload(t.allocator, plan.plan, &payload_output);
    // The independently generated FDM1 bytes supply this body's oracle too.
    try t.expectEqualSlices(u8, bytes[37 + plan.plan.name.len ..], payload);
    @memset(&expected, 0);
    @memset(&schema_bytes, 0);
    try t.expectEqualStrings("people", plan.plan.name);
    const row = plan.plan.action.insert[0];
    try t.expectEqualStrings("東京é", row[1].value.atom.bytes);
    try t.expectEqual(@as(i128, 12), row[0].value.atom.signed);
    try t.expect(row[2].value.atom.boolean);
    try t.expectEqual(.null, row[3]);
}
test "compact DML recursively owns schema payloads and quoted names" {
    var created = try @import("TableDdl.zig").compile(t.allocator, "CREATE TABLE \"人\" (\"識別\" INT PRIMARY KEY, payload STRUCT(n INT32 NOT NULL, xs LIST(TEXT)), amount DECIMAL(18,2), date DATE)", null, null);
    defer created.deinit();
    var plan = try d.compile(t.allocator, "INSERT INTO \"人\" VALUES (1, STRUCT(2, LIST('one',NULL)), 12.50, DATE '2000-02-29')", "人", try created.statement.create.bind(31), null);
    defer plan.deinit();
    var buffer: [4096]u8 = undefined;
    const bytes = try c.encode(t.allocator, plan.plan, &buffer);
    var owned = try c.decode(t.allocator, plan.plan.schema, bytes);
    defer owned.deinit();
    @memset(&buffer, 0);
    try t.expectEqualStrings("人", owned.plan.name);
    try t.expectEqualStrings("one", owned.plan.action.insert[0][1].value.structure[1].value.list[0].value.atom.bytes);
    try t.expectEqualSlices(u8, &try plan.plan.fingerprint(t.allocator), &try owned.plan.fingerprint(t.allocator));
}
