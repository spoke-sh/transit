const std = @import("std");
const e = std.testing;
const j = @import("TableSchemaJson.zig");
const s = @import("TableSchema.zig");
const ddl = @import("TableDdl.zig");
const p = @import("transit_protocol");

test "neutral schema refuses physical attributes it cannot preserve" {
    var arena = std.heap.ArenaAllocator.init(e.allocator);
    defer arena.deinit();
    for ([_]s.Column{
        .{ .id = 1, .name = "v", .type = .utf8, .encoding = .ebcdic },
        .{ .id = 1, .name = "v", .type = .utf8, .collation = .ascii_ci },
    }) |column| {
        const schema: s.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &.{column} };
        try e.expectError(error.UnsupportedNeutralColumnRepresentation, j.foreign(&arena, schema));
    }
}

test "neutral Table schema matches independently encoded JSON and FTS1" {
    const Fixture = struct { schema_hex: []const u8, schema_json: []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, e.allocator, @embedFile("fixtures/table-schema.json"), .{ .ignore_unknown_fields = true });
    defer fixture.deinit();
    var decoded = try j.decode(e.allocator, fixture.value.schema_json);
    defer decoded.deinit();
    var buffer: [s.max_bytes]u8 = undefined;
    var expected: [s.max_bytes]u8 = undefined;
    try e.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, fixture.value.schema_hex), try decoded.schema.encode(&buffer));
    const encoded = try j.encode(e.allocator, decoded.schema);
    defer e.allocator.free(encoded);
    try e.expectEqualStrings(fixture.value.schema_json, encoded);
}

test "neutral Table schema owns full-width identities recursive descriptors and exact defaults" {
    var source = try ddl.compile(e.allocator, "CREATE TABLE people (id UINT128 PRIMARY KEY DEFAULT 340282366920938463463374607431768211455, amount DECIMAL(38,2) DEFAULT -123.45, payload STRUCT(name TEXT, data BINARY, tags LIST(TEXT), choice UNION(left INT8,right UTF8)) DEFAULT STRUCT('Ada',X'00ff',LIST('one',NULL),UNION(right,'chosen')), signed FLOAT64 DEFAULT -0.0)", null, null);
    var schema = try source.statement.create.bind(std.math.maxInt(u64));
    schema.revision = std.math.maxInt(u64);
    schema.next_column = std.math.maxInt(u64);
    var columns: [4]s.Column = undefined;
    @memcpy(&columns, schema.columns);
    columns[3].id = std.math.maxInt(u64) - 1;
    schema.columns = &columns;
    const fingerprint = try schema.fingerprint();
    var neutral_arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer neutral_arena.deinit();
    const wire = try j.foreign(&neutral_arena, schema);
    source.deinit();
    @memset(std.mem.asBytes(&columns), 0);
    try e.expectEqualStrings("18446744073709551615", wire.object);
    try e.expectEqualStrings("18446744073709551614", wire.columns[3].id);
    try e.expectEqualStrings("340282366920938463463374607431768211455", wire.columns[0].default.?.value.atom.unsigned);
    try e.expectEqualStrings("-12345", wire.columns[1].default.?.value.atom.decimal);
    try e.expectEqualStrings("0000000000000080", wire.columns[3].default.?.value.atom.float_bits);
    var native_arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer native_arena.deinit();
    const owned = try j.native(&native_arena, wire);
    _ = neutral_arena.reset(.free_all);
    try e.expectEqualDeep(fingerprint, try owned.fingerprint());
    try e.expectEqualStrings("chosen", owned.columns[2].default.?.value.structure[3].value.tagged_union.value.value.atom.bytes);
}

test "neutral Table schema rejects foreign missing ambiguous and noncanonical identities" {
    const Fixture = struct { schema_json: []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, e.allocator, @embedFile("fixtures/table-schema.json"), .{ .ignore_unknown_fields = true });
    defer fixture.deinit();
    const valid = fixture.value.schema_json;
    const substitutions = .{
        .{ @tagName(p.Growth.current_definition), "foreign", error.InvalidJsonShape },
        .{ "\"object\":\"7\"", "\"object\":7", error.InvalidJsonShape },
        .{ "\"object\":\"7\"", "\"object\":\"07\"", error.InvalidIntegerEncoding },
        .{ "\"object\":\"7\"", "\"object\":\"18446744073709551616\"", error.InvalidIntegerEncoding },
        .{ "\"id\":\"27\"", "\"id\":\"11\"", error.DuplicateColumnIdentity },
        .{ "\"primary_key\":[\"11\"]", "\"primary_key\":[\"27\"]", error.NullablePrimaryKey },
        .{ "\"boolean\":true", "\"boolean\":\"true\"", error.InvalidJsonShape },
    };
    inline for (substitutions) |case| {
        const changed = try std.mem.replaceOwned(u8, e.allocator, valid, case[0], case[1]);
        defer e.allocator.free(changed);
        try e.expectError(case[2], j.decode(e.allocator, changed));
    }
    const missing = try std.mem.replaceOwned(u8, e.allocator, valid, "\"definition\":\"" ++ @tagName(p.Growth.current_definition) ++ "\",", "");
    defer e.allocator.free(missing);
    try e.expectError(error.MissingField, j.decode(e.allocator, missing));
}

test "neutral schema conversions release every partial recursive allocation" {
    var source = try ddl.compile(e.allocator, "CREATE TABLE t (payload STRUCT(n INT128, xs LIST(TEXT)) DEFAULT STRUCT(-123,LIST('one','two')))", null, null);
    defer source.deinit();
    var no_resize = e.FailingAllocator.init(e.allocator, .{ .resize_fail_index = 0 });
    try e.checkAllAllocationFailures(no_resize.allocator(), ownership, .{try source.statement.create.bind(1)});
}
test "neutral schema conversion rejects large shared defaults before whole schema allocation" {
    var inputs: std.heap.ArenaAllocator = .init(e.allocator);
    defer inputs.deinit();
    const hex = try inputs.allocator().alloc(u8, 1024 * 1024);
    @memset(hex, 'a');
    var columns: [s.max_columns]j.Column = undefined;
    for (&columns, 0..) |*column, i| {
        const name = try std.fmt.allocPrint(inputs.allocator(), "column_{d}", .{i});
        const id = try std.fmt.allocPrint(inputs.allocator(), "{d}", .{i + 1});
        column.* = .{ .id = id, .name = name, .type = .binary, .nullable = true, .default = .{ .value = .{ .atom = .{ .binary = hex } } }, .max_characters = null };
    }
    const source: j.Schema = .{ .definition = p.Growth.current_definition, .object = "1", .revision = "1", .next_column = "129", .columns = &columns, .primary_key = &.{} };
    var tracker: e.FailingAllocator = .init(e.allocator, .{ .resize_fail_index = 0 });
    var arena: std.heap.ArenaAllocator = .init(tracker.allocator());
    defer arena.deinit();
    // The shared input describes 64 MiB of defaults; stop after one bounded
    // conversion exceeds the 64-KiB schema record allowance.
    try e.expectError(error.TableSchemaTooLarge, j.native(&arena, source));
    try e.expect(tracker.allocated_bytes < 4 * 1024 * 1024);
    _ = arena.reset(.free_all);
    try e.expectEqual(tracker.allocated_bytes, tracker.freed_bytes);
}
test "neutral schemas preserve large legal nested defaults within their separate wire budget" {
    const types = @import("Types.zig");
    const cells = try e.allocator.alloc(types.Values.Cell, 60000);
    defer e.allocator.free(cells);
    @memset(cells, .null);
    const schema: s.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &.{.{
        .id = 1,
        .name = "values",
        .type = .{ .array = .{ .element = .{ .type = &.boolean, .nullable = true }, .length = 60000 } },
        .default = .{ .value = .{ .array = cells } },
    }}, .primary_key = &.{} };
    try schema.validate();
    const encoded = try j.encode(e.allocator, schema);
    defer e.allocator.free(encoded);
    try e.expect(encoded.len > @import("LogicalJson.zig").max_input_bytes);
    try e.expect(encoded.len < j.max_input_bytes);
    var decoded = try j.decode(e.allocator, encoded);
    defer decoded.deinit();
    try e.expectEqual(@as(usize, 60000), decoded.schema.columns[0].default.?.value.array.len);
    try e.expectEqualDeep(try schema.fingerprint(), try decoded.schema.fingerprint());
    const oversized = try e.allocator.alloc(u8, j.max_input_bytes + 1);
    defer e.allocator.free(oversized);
    @memset(oversized, ' ');
    try e.expectError(error.JsonByteBudgetExceeded, j.decode(e.failing_allocator, oversized));
}
fn ownership(allocator: std.mem.Allocator, schema: s.Schema) !void {
    const encoded = try j.encode(allocator, schema);
    defer allocator.free(encoded);
    var decoded = try j.decode(allocator, encoded);
    defer decoded.deinit();
    try e.expectEqualDeep(try schema.fingerprint(), try decoded.schema.fingerprint());
}
