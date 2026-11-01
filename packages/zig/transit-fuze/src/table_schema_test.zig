const std = @import("std");
const expect = std.testing;
const s = @import("TableSchema.zig");
const t = @import("Types.zig");
const Cell = t.Values.Cell;
fn integer(value: i128) Cell {
    return .{ .value = .{ .atom = .{ .signed = value } } };
}
fn text(value: []const u8) Cell {
    return .{ .value = .{ .atom = .{ .bytes = value } } };
}
const columns = [_]s.Column{
    .{ .id = 11, .name = "id", .type = .int32, .nullable = false },
    .{ .id = 27, .name = "name", .type = .utf8, .max_characters = 3 },
    .{ .id = 39, .name = "active", .type = .boolean, .nullable = false, .default = .{ .value = .{ .atom = .{ .boolean = true } } } },
    .{ .id = 40, .name = "amount", .type = .{ .decimal = .{ .precision = 18, .scale = 2 } } },
};
const schema: s.Schema = .{ .object = 7, .revision = 2, .next_column = 50, .columns = &columns, .primary_key = &.{11} };

test "column identity, nullable omission and defaults are independent of order" {
    var output: [4]Cell = undefined;
    const row = try schema.insert(&.{
        .{ .column = 27, .value = .{ .cell = text("東京é") } },
        .{ .column = 11, .value = .{ .cell = integer(12) } },
    }, &output);
    try expect.expectEqualDeep(integer(12), row[0]);
    try expect.expectEqualDeep(text("東京é"), row[1]);
    try expect.expectEqual(true, row[2].value.atom.boolean);
    try expect.expect(row[3] == .null);
    try expect.expectError(error.CharacterLimitExceeded, schema.insert(&.{
        .{ .column = 11, .value = .{ .cell = integer(12) } },
        .{ .column = 27, .value = .{ .cell = text("東京éX") } },
    }, &output));
    try expect.expectError(error.MissingRequiredField, schema.insert(&.{}, &output));
    try expect.expectError(error.NullNotAllowed, schema.insert(&.{.{ .column = 11, .value = .{ .cell = .null } }}, &output));
    try expect.expectError(error.DuplicateAssignment, schema.insert(&.{
        .{ .column = 11, .value = .{ .cell = integer(1) } },
        .{ .column = 11, .value = .{ .cell = integer(2) } },
    }, &output));
    try expect.expectError(error.UnknownColumn, schema.insert(&.{.{ .column = 99, .value = .default }}, &output));
    try expect.expectError(error.Overflow, schema.insert(&.{.{ .column = 11, .value = .{ .cell = integer(2147483648) } }}, &output));
}

test "updating a default affects only selected assignments, not earlier rows" {
    const before = [_]Cell{ integer(1), text("Ada"), .{ .value = .{ .atom = .{ .boolean = false } } }, .null };
    var output: [4]Cell = undefined;
    const after = try schema.update(&before, &.{.{ .column = 39, .value = .default }}, &output);
    try expect.expectEqual(true, after[2].value.atom.boolean);
    try expect.expectEqual(false, before[2].value.atom.boolean);
    try expect.expectEqualDeep(before[1], after[1]);
    try expect.expectEqualDeep(before[3], after[3]);
}

test "Tables without a declared key retain a nullable first column" {
    const value: s.Schema = .{ .object = 1, .revision = 1, .next_column = 3, .columns = &.{
        .{ .id = 1, .name = "id", .type = .int64 },
        .{ .id = 2, .name = "name", .type = .utf8 },
    } };
    var output: [2]Cell = undefined;
    const row = try value.insert(&.{}, &output);
    try expect.expect(row[0] == .null and row[1] == .null);
    var keyed = value;
    keyed.primary_key = &.{1};
    try expect.expectError(error.NullablePrimaryKey, keyed.validate());
    keyed = schema;
    keyed.primary_key = &.{ 11, 11 };
    try expect.expectError(error.DuplicatePrimaryKeyColumn, keyed.validate());
    var copied = columns;
    copied[0].type = .json;
    keyed = schema;
    keyed.columns = &copied;
    try expect.expectError(error.UnsupportedPrimaryKeyType, keyed.validate());
}

test "schema codec owns every name, descriptor and default and rejects all truncated prefixes" {
    var buffer: [s.max_bytes]u8 = undefined;
    const bytes = try schema.encode(&buffer);
    const original = try schema.fingerprint();
    for (0..bytes.len) |size| {
        if (s.decode(expect.allocator, bytes[0..size])) |result| {
            var owned = result;
            owned.deinit();
            return error.AcceptedTruncatedSchema;
        } else |_| {}
    }
    var decoded = try s.decode(expect.allocator, bytes);
    defer decoded.deinit();
    @memset(&buffer, 0);
    try expect.expectEqualStrings("name", decoded.schema.columns[1].name);
    try expect.expectEqualSlices(u8, &original, &try decoded.schema.fingerprint());
    try expect.expectEqual(@as(u64, 50), decoded.schema.next_column);
    try expect.expect(decoded.schema.columns[2].default.?.value.atom.boolean);
    try expect.checkAllAllocationFailures(expect.allocator, clone, .{});
}
fn clone(allocator: std.mem.Allocator) !void {
    var owned = try schema.clone(allocator);
    defer owned.deinit();
    try expect.expectEqualStrings("amount", owned.schema.columns[3].name);
}

test "independent Python oracle fixes schema bytes and row/default/constraint results" {
    const Input = struct { column: u64, kind: enum { integer, text, null, default }, integer: i64 = 0, text: []const u8 = "" };
    const Case = struct { name: []const u8, assignments: []Input, expected: [][]const u8, @"error": ?[]const u8 };
    const Fixture = struct { definition: []const u8, oracle: []const u8, schema_hex: []const u8, fingerprint: []const u8, cases: []Case };
    const parsed = try std.json.parseFromSlice(Fixture, expect.allocator, @embedFile("fixtures/table-schema.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try expect.expectEqualStrings(s.definition, parsed.value.definition);
    var expected: [s.max_bytes]u8 = undefined;
    var actual: [s.max_bytes]u8 = undefined;
    try expect.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, parsed.value.schema_hex), try schema.encode(&actual));
    var digest: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&digest, parsed.value.fingerprint);
    try expect.expectEqualSlices(u8, &digest, &try schema.fingerprint());
    for (parsed.value.cases) |case| {
        var assignments: [4]s.Assignment = undefined;
        for (case.assignments, 0..) |input, i| assignments[i] = .{ .column = input.column, .value = switch (input.kind) {
            .integer => .{ .cell = integer(input.integer) },
            .text => .{ .cell = text(input.text) },
            .null => .{ .cell = .null },
            .default => .default,
        } };
        var output: [4]Cell = undefined;
        if (schema.insert(assignments[0..case.assignments.len], &output)) |row| {
            try expect.expect(case.@"error" == null);
            for (row, case.expected) |cell, wanted| {
                var bytes: [256]u8 = undefined;
                const rendered = switch (cell) {
                    .null => "null",
                    .value => |value| switch (value.atom) {
                        .signed => |number| try std.fmt.bufPrint(&bytes, "int:{d}", .{number}),
                        .bytes => |string| try std.fmt.bufPrint(&bytes, "text:{s}", .{string}),
                        .boolean => |boolean| if (boolean) "bool:true" else "bool:false",
                        else => return error.UnexpectedOracleValue,
                    },
                    else => return error.UnexpectedOracleState,
                };
                try expect.expectEqualStrings(wanted, rendered);
            }
        } else |err| {
            try expect.expectEqualStrings(case.@"error" orelse return err, @errorName(err));
        }
    }
}

test "schema codec requires the exact definition and canonical flags" {
    var buffer: [s.max_bytes]u8 = undefined;
    const encoded = try schema.encode(&buffer);
    buffer[5] ^= 1;
    try expect.expectError(error.UnsupportedTableSchemaDefinition, s.decode(expect.allocator, encoded));
    _ = try schema.encode(&buffer);
    @memcpy(buffer[5..][0..s.definition.len], "transit.table.schema.v1.2026-10-23");
    try expect.expectError(error.UnsupportedTableSchemaDefinition, s.decode(expect.allocator, encoded));
    _ = try schema.encode(&buffer);
    buffer[encoded.len] = 0;
    try expect.expectError(error.InvalidTableSchemaEncoding, s.decode(expect.allocator, buffer[0 .. encoded.len + 1]));
    // Locate the first nullable flag independently of the decoder.
    const name_at = 5 + s.definition.len + 24 + 2 + 8;
    const descriptor_at = name_at + 1 + columns[0].name.len;
    const length = std.mem.readInt(u16, buffer[descriptor_at..][0..2], .little);
    buffer[descriptor_at + 2 + length] = 2;
    try expect.expectError(error.InvalidTableSchemaEncoding, s.decode(expect.allocator, encoded));
}

test "all logical type families fit Table columns without implying key traits" {
    const signed: t.Type = .int64;
    const choices = [_]t.Type{
        .int8,     .int16,   .int32,                                                                   .int64,                            .int128,                                                         .uint8,                                                         .uint16,                                                   .uint32, .uint64,                  .uint128,
        .float32,  .float64, .boolean,                                                                 .utf8,                             .binary,                                                         .{ .decimal = .{ .precision = 38, .scale = 2 } },               .date,                                                     .time,   .{ .timestamp = .civil }, .{ .timestamp = .utc },
        .interval, .uuid,    .{ .structure = &.{.{ .name = "n", .type = .int64, .nullable = true }} }, .{ .list = .{ .type = &signed } }, .{ .array = .{ .element = .{ .type = &signed }, .length = 3 } }, .{ .map = .{ .key = &signed, .value = .{ .type = &signed } } }, .{ .tagged_union = &.{.{ .name = "n", .type = .int64 }} }, .json,
    };
    for (choices) |data_type| {
        const value: s.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "v", .type = data_type }} };
        try value.validate();
        var owned = try value.clone(expect.allocator);
        defer owned.deinit();
        try expect.expect(try data_type.eql(owned.schema.columns[0].type));
        try value.validateRow(&.{.null});
        const cell: Cell = switch (data_type) {
            .int8, .int16, .int32, .int64, .int128 => integer(-12),
            .uint8, .uint16, .uint32, .uint64, .uint128 => .{ .value = .{ .atom = .{ .unsigned = 123 } } },
            .float32, .float64 => .{ .value = .{ .atom = .{ .float = -0.5 } } },
            .boolean => .{ .value = .{ .atom = .{ .boolean = true } } },
            .utf8, .binary => text("東京"),
            .decimal => .{ .value = .{ .atom = .{ .decimal = -12345 } } },
            .date => .{ .value = .{ .atom = .{ .date = -1 } } },
            .time => .{ .value = .{ .atom = .{ .time = 86399999999999 } } },
            .timestamp => .{ .value = .{ .atom = .{ .timestamp = -1 } } },
            .interval => .{ .value = .{ .atom = .{ .interval = .{ .months = -1, .days = 2, .nanos = 3 } } } },
            .uuid => .{ .value = .{ .atom = .{ .uuid = @splat(0xff) } } },
            .structure => .{ .value = .{ .structure = &.{integer(42)} } },
            .list => .{ .value = .{ .list = &.{ integer(1), integer(2) } } },
            .array => .{ .value = .{ .array = &.{ integer(1), integer(2), integer(3) } } },
            .map => .{ .value = .{ .map = &.{.{ .key = .{ .signed = 1 }, .value = integer(2) }} } },
            .tagged_union => .{ .value = .{ .tagged_union = .{ .index = 0, .value = &integer(42) } } },
            .json => .{ .value = .{ .json = "{\"exact\":18446744073709551615}" } },
        };
        try value.validateRow(&.{cell});
        var with_default = value.columns[0];
        with_default.default = cell;
        var default_schema = value;
        default_schema.columns = &.{with_default};
        var default_copy = try default_schema.clone(expect.allocator);
        defer default_copy.deinit();
        try default_copy.schema.validateRow(&.{default_copy.schema.columns[0].default.?});
        var expected_bytes: [4096]u8 = undefined;
        var actual_bytes: [4096]u8 = undefined;
        try expect.expectEqualSlices(u8, try t.Codec.encode(cell, with_default.field(), &expected_bytes), try t.Codec.encode(default_copy.schema.columns[0].default.?, with_default.field(), &actual_bytes));
    }
}

test "ordinary Table rows reject nested source errors while retaining optional missing" {
    const value: s.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &.{.{
        .id = 1,
        .name = "payload",
        .type = .{ .structure = &.{.{ .name = "n", .type = .int64, .optional = true }} },
    }} };
    try value.validateRow(&.{.{ .value = .{ .structure = &.{.missing} } }});
    try expect.expectError(error.TableTypeError, value.validateRow(&.{.{ .value = .{ .structure = &.{.{ .type_error = .utf8 }} } }}));
    try expect.expectError(error.TableConflict, value.validateRow(&.{.{ .value = .{ .structure = &.{.{ .conflict = &.{
        .{ .counter = 1, .replica = 1, .value = .{ .value = .{ .atom = .{ .signed = 1 } } } },
        .{ .counter = 2, .replica = 1, .value = .{ .value = .{ .atom = .{ .signed = 2 } } } },
    } }} } }}));
}

test "column IDs are nonzero, unique and below the retained allocation floor" {
    var copied = columns;
    var changed = schema;
    changed.columns = &copied;
    copied[1].id = copied[0].id;
    try expect.expectError(error.DuplicateColumnIdentity, changed.validate());
    copied = columns;
    copied[1].id = 0;
    try expect.expectError(error.InvalidColumnIdentity, changed.validate());
    copied = columns;
    changed.next_column = 40;
    try expect.expectError(error.InvalidColumnIdentity, changed.validate());
}

test "oversized typed defaults report the schema limit before encoding" {
    const bytes = try expect.allocator.alloc(u8, s.max_bytes);
    defer expect.allocator.free(bytes);
    @memset(bytes, 'x');
    const oversized: s.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &.{.{
        .id = 1,
        .name = "payload",
        .type = .binary,
        .default = text(bytes),
    }} };
    try expect.expectError(error.TableSchemaTooLarge, oversized.validate());
}

test "insert and patch validation reject an oversized schema before indexing columns" {
    var excessive: [s.max_columns + 1]s.Column = @splat(columns[0]);
    excessive[s.max_columns].id = 129;
    var invalid = schema;
    invalid.columns = &excessive;
    invalid.next_column = 130;
    var output: [s.max_columns + 1]Cell = undefined;
    const assignments = [_]s.Assignment{.{ .column = 129, .value = .{ .cell = integer(1) } }};
    try expect.expectError(error.InvalidColumnCount, invalid.insert(&assignments, &output));
    try expect.expectError(error.InvalidColumnCount, invalid.validateAssignments(&assignments));
}

test "orthogonal column encoding and collation descriptors validate compatibility and round-trip" {
    const mainframe_columns = [_]s.Column{
        .{ .id = 1, .name = "acct_id", .type = .int64, .nullable = false, .encoding = .comp },
        .{ .id = 2, .name = "branch_code", .type = .utf8, .nullable = false, .encoding = .ebcdic, .collation = .ebcdic_cp037 },
        .{ .id = 3, .name = "balance", .type = .{ .decimal = .{ .precision = 18, .scale = 2 } }, .encoding = .comp_3 },
        .{ .id = 4, .name = "rate", .type = .float64, .encoding = .ibm_hfp },
    };
    const physical_schema: s.Schema = .{
        .object = 42,
        .revision = 1,
        .next_column = 5,
        .columns = &mainframe_columns,
        .primary_key = &.{ 1, 2 },
    };
    try physical_schema.validate();
    try expect.expect(physical_schema.hasPhysicalAttributes());
    var buffer: [s.max_bytes]u8 = undefined;
    const encoded = try physical_schema.encode(&buffer);
    var decoded = try s.decode(expect.allocator, encoded);
    defer decoded.deinit();
    try expect.expectEqual(s.Encoding.comp, decoded.schema.columns[0].encoding);
    try expect.expectEqual(s.Encoding.ebcdic, decoded.schema.columns[1].encoding);
    try expect.expectEqual(s.Collation.ebcdic_cp037, decoded.schema.columns[1].collation);
    try expect.expectEqual(s.Encoding.comp_3, decoded.schema.columns[2].encoding);
    try expect.expectEqual(s.Encoding.ibm_hfp, decoded.schema.columns[3].encoding);
    try expect.expectEqualSlices(u8, &try physical_schema.fingerprint(), &try decoded.schema.fingerprint());
    try expect.expectEqualSlices(u8, &try physical_schema.layoutFingerprint(), &try decoded.schema.layoutFingerprint());

    var plain_columns = mainframe_columns;
    for (&plain_columns) |*col| {
        col.encoding = .plain;
        col.collation = .none;
    }
    const plain_schema: s.Schema = .{
        .object = 42,
        .revision = 1,
        .next_column = 5,
        .columns = &plain_columns,
        .primary_key = &.{ 1, 2 },
    };
    try expect.expect(!plain_schema.hasPhysicalAttributes());
    try expect.expect(!std.mem.eql(u8, &try plain_schema.layoutFingerprint(), &try physical_schema.layoutFingerprint()));

    // Reject redundant FTP1 trailer when all columns use default plain/none attributes.
    const plain_bytes = try plain_schema.encode(&buffer);
    var non_canonical: [512]u8 = undefined;
    @memcpy(non_canonical[0..plain_bytes.len], plain_bytes);
    @memcpy(non_canonical[plain_bytes.len .. plain_bytes.len + 4], "FTP1");
    @memset(non_canonical[plain_bytes.len + 4 .. plain_bytes.len + 4 + plain_columns.len * 2], 0);
    try expect.expectError(error.InvalidTableSchemaEncoding, s.decode(expect.allocator, non_canonical[0 .. plain_bytes.len + 4 + plain_columns.len * 2]));

    // Reject incompatible (tau, epsilon, kappa) combinations.
    var bad_encoding = mainframe_columns;
    bad_encoding[0].encoding = .ibm_hfp; // int64 cannot use ibm_hfp
    var bad_schema = physical_schema;
    bad_schema.columns = &bad_encoding;
    try expect.expectError(error.IncompatibleColumnEncoding, bad_schema.validate());

    var bad_collation = mainframe_columns;
    bad_collation[0].collation = .ascii_ci; // int64 cannot use text collation
    bad_schema.columns = &bad_collation;
    try expect.expectError(error.IncompatibleColumnCollation, bad_schema.validate());
}
