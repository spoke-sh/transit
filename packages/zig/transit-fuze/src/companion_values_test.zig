const std = @import("std");
const types = @import("Types.zig");
const json = @import("LogicalJson.zig");
const t = std.testing;

test "companion declaration failures retain structured binding diagnostics" {
    const cases = .{
        .{ "CREATE TABLE bad (span RANGE<BOOLEAN>)", "sql.unsupported_range_subtype", error.UnsupportedRangeSubtype },
        .{ "CREATE TABLE bad (v VECTOR(7,BINARY))", "sql.invalid_binary_vector_dimensions", error.InvalidBinaryVectorDimensions },
        .{ "CREATE TABLE bad (v VECTOR(3,FLOAT32) METRIC HAMMING)", "sql.incompatible_vector_metric", error.IncompatibleVectorMetric },
        .{ "CREATE TABLE bad (ts TIMESTAMPTZ TIMEZONE NULL TZDB 'x' TZIF X'00')", "sql.invalid_column_semantics", error.InvalidColumnSemantics },
        .{ "CREATE TABLE bad (v VECTOR(1,FLOAT16) DEFAULT '[70000]')", "sql.invalid_vector_value", error.InvalidVectorValue },
    };
    inline for (cases) |case| {
        var location: @import("Sql.zig").Location = .{};
        try t.expectError(case[2], @import("TableDdl.zig").compile(t.allocator, case[0], null, &location));
        const diagnostic = @import("SqlDiagnostic.zig").tableDdl(case[0], case[2], location) orelse return error.MissingDiagnostic;
        const structured = try diagnostic.structured();
        try t.expectEqualStrings(case[1], structured.code.slice());
        try t.expectEqual(.not_submitted, structured.outcome);
    }
}

test "companion values agree with independent canonical range and vector fixtures" {
    const Case = struct {
        name: []const u8,
        field: types.Field,
        cell: json.Cell,
        type_hex: []const u8,
        fingerprint: []const u8,
        value_hex: []const u8,
        @"error": ?[]const u8,
    };
    const Fixture = struct { definition: []const u8, oracle: []const u8, cases: []const Case };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/companion-values.json"), .{});
    defer parsed.deinit();
    try t.expectEqualStrings(types.definition, parsed.value.definition);
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    const arrow = @import("LogicalArrow.zig");
    const workspace = try t.allocator.alloc(u8, arrow.working_bytes);
    defer t.allocator.free(workspace);
    const ipc_buffer = try t.allocator.alloc(u8, arrow.segment_bytes);
    defer t.allocator.free(ipc_buffer);
    for (parsed.value.cases) |case| {
        _ = output.reset(.retain_capacity);
        const allocator = output.allocator();
        var descriptor_buffer: [types.max_encoding_bytes]u8 = undefined;
        const descriptor = try case.field.type.encode(&descriptor_buffer);
        const oracle_type = try allocator.alloc(u8, case.type_hex.len / 2);
        _ = try std.fmt.hexToBytes(oracle_type, case.type_hex);
        try t.expectEqualSlices(u8, oracle_type, descriptor);
        try t.expectEqualStrings(case.fingerprint, &std.fmt.bytesToHex(&try case.field.type.fingerprint(), .lower));
        const oracle = try allocator.alloc(u8, case.value_hex.len / 2);
        _ = try std.fmt.hexToBytes(oracle, case.value_hex);
        if (case.@"error") |expected| {
            if (types.Codec.decodeInto(allocator, oracle)) |_| return error.ExpectedCompanionRefusal else |err| try t.expectEqualStrings(expected, @errorName(err));
            if (json.fromForeign(allocator, case.cell, case.field)) |_| return error.ExpectedCompanionRefusal else |err| try t.expectEqualStrings(expected, @errorName(err));
            continue;
        }
        const decoded = try types.Codec.decodeInto(allocator, oracle);
        const neutral = try json.fromForeign(allocator, case.cell, case.field);
        try t.expect(try types.Operations.eql(case.field, decoded.cell, neutral));
        var bytes: [4096]u8 = undefined;
        try t.expectEqualSlices(u8, oracle, try types.Codec.encode(decoded.cell, case.field, &bytes));
        try t.expectEqualSlices(u8, oracle, try types.Codec.encode(neutral, case.field, &bytes));
        const copied = try types.Values.cloneValidated(allocator, neutral);
        try t.expect(try types.Operations.eql(case.field, copied, neutral));
        const internal_json = try std.json.Stringify.valueAlloc(allocator, neutral, .{});
        var recovered = try std.json.parseFromSlice(types.Values.Cell, t.allocator, internal_json, .{ .allocate = .alloc_always });
        defer recovered.deinit();
        @memset(internal_json, 0);
        try t.expect(try types.Operations.eql(case.field, recovered.value, neutral));
        if (case.field.type == .vector) try t.expect(@intFromPtr(recovered.value.value.vector.ptr) % 64 == 0);
        try t.expectEqual(try types.Operations.hash(case.field, decoded.cell), try types.Operations.hash(case.field, copied));
        const roundtrip = try json.foreignCell(allocator, decoded.cell, case.field.type);
        try t.expectEqualStrings(try std.json.Stringify.valueAlloc(allocator, case.cell, .{}), try std.json.Stringify.valueAlloc(allocator, roundtrip, .{}));
        const column: @import("TableSchema.zig").Column = .{ .id = 1, .name = "value", .type = case.field.type, .nullable = false };
        const schema: @import("TableSchema.zig").Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &.{column} };
        const row: @import("TableRow.zig").Row = .{ .identity = .{ .origin = 1, .operation = 2, .ordinal = 0 }, .cells = &.{neutral} };
        const stored = try @import("TableRow.zig").decodeInto(allocator, schema, try row.encode(schema, &bytes));
        try t.expect(try types.Operations.eql(case.field, neutral, stored.row().cells[0]));
        const page = try @import("PhysicalCodecs.zig").encodeColumnPage(allocator, column, &.{neutral}, &bytes);
        const read = try @import("PhysicalCodecs.zig").decodeColumnPage(allocator, column, page);
        try t.expectEqual(@as(usize, 1), read.len);
        try t.expect(try types.Operations.eql(case.field, neutral, read[0]));
        const arrow_field: types.Field = .{ .name = case.field.name, .type = case.field.type, .nullable = true, .optional = true };
        const states = [_]types.Values.Cell{ neutral, .null, .missing, .{ .type_error = .utf8 }, .{ .conflict = &.{
            .{ .counter = 1, .replica = 1, .value = .{ .value = neutral.value } },
            .{ .counter = 2, .replica = 1, .value = .null },
        } } };
        var rows: [states.len]arrow.Row = undefined;
        for (&states, &rows) |*cell, *r| r.* = .{ .cells = @as(*const [1]types.Values.Cell, cell) };
        const ipc = try arrow.encode(.{ .structure = &.{arrow_field} }, &rows, workspace, ipc_buffer);
        var imported = try @import("LogicalInspect.zig").decode(allocator, .{ .structure = &.{arrow_field} }, ipc, states.len, workspace);
        defer imported.deinit();
        @memset(ipc_buffer, 0);
        @memset(workspace, 0);
        for (states, imported.rows) |cell, r| {
            var expected_bytes: [4096]u8 = undefined;
            try t.expectEqualSlices(u8, try types.Codec.encode(cell, arrow_field, &expected_bytes), try types.Codec.encode(r.cells[0], arrow_field, &bytes));
        }
        if (case.field.type == .vector) {
            try t.expect(@intFromPtr(decoded.cell.value.vector.ptr) % 64 == 0);
            try t.expect(@intFromPtr(copied.value.vector.ptr) % 64 == 0);
        }
        if (types.Codec.decodeInto(allocator, oracle[0 .. oracle.len - 1])) |_| return error.ExpectedCompanionRefusal else |_| {}
    }
}

test "companion SQL declarations bind normalized stored values and reject incompatible layouts" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const Parser = @import("SqlTyped.zig");
    const cases = .{
        .{ "RANGE<BIGINT>", "'[1,3]'", "[1,4)" },
        .{ "MULTIRANGE<DECIMAL(5,2)>", "'{[1.00,2.00),[2.00,3.00]}'", "{[1.00,3.00]}" },
        .{ "VECTOR(2,FLOAT32)", "'[1.25,-2.5]'", "[1.25,-2.5]" },
        .{ "VECTOR(16,BINARY)", "'aa55'", "0xaa55" },
    };
    inline for (cases) |case| {
        var parser = try Parser.init(arena.allocator(), case[0], null);
        const descriptor = (try parser.dataType()).type;
        try parser.finish();
        parser = try Parser.init(arena.allocator(), case[1], null);
        const value = try parser.value(descriptor);
        try parser.finish();
        try value.validate(.{ .name = "value", .type = descriptor }, .{});
        var display: [128]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&display);
        try @import("LogicalDisplay.zig").cell(&writer, value, descriptor);
        try t.expectEqualStrings(case[2], writer.buffered());
    }
    var parser = try Parser.init(arena.allocator(), "RANGE<FLOAT64>", null);
    try t.expectError(error.UnsupportedRangeSubtype, parser.dataType());
    parser = try Parser.init(arena.allocator(), "VECTOR(7,BINARY)", null);
    try t.expectError(error.InvalidBinaryVectorDimensions, parser.dataType());
    parser = try Parser.init(arena.allocator(), "'[1,2,3]'", null);
    try t.expectError(error.VectorDimensionMismatch, parser.value(.{ .vector = .{ .dimensions = 2, .element = .float32 } }));
}

test "companion vector equality hashes nested signed zero and borrowing decode owns aligned bytes" {
    const field: types.Field = .{ .name = "vector", .type = .{ .vector = .{ .dimensions = 2, .element = .float32 } } };
    const a = [_]u8{ 0, 0, 0, 128, 0, 0, 128, 63 };
    const b = [_]u8{ 0, 0, 0, 0, 0, 0, 128, 63 };
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const left: types.Values.Cell = .{ .value = .{ .vector = try types.Vectors.cloneInto(arena.allocator(), field.type.vector, &a) } };
    const right: types.Values.Cell = .{ .value = .{ .vector = try types.Vectors.cloneInto(arena.allocator(), field.type.vector, &b) } };
    const nested: types.Field = .{ .name = "list", .type = .{ .list = .{ .type = &field.type } } };
    const first: types.Values.Cell = .{ .value = .{ .list = &.{left} } };
    const second: types.Values.Cell = .{ .value = .{ .list = &.{right} } };
    try t.expect(try types.Operations.eql(nested, first, second));
    try t.expectEqual(try types.Operations.hash(nested, first), try types.Operations.hash(nested, second));
    var storage: [64]u8 = undefined;
    const encoded = try types.Codec.encodeBound(left, field, storage[1..]);
    const decoded = try types.Codec.decodeBoundBorrowingBytes(arena.allocator(), field, encoded);
    @memset(&storage, 0);
    try t.expectEqualSlices(u8, &a, decoded.value.vector);
    try t.expectError(error.ValueBudgetExceeded, left.validate(field, .{ .value_bytes = 7 }));
}
