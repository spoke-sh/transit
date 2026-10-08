//! Adapt verified current query cells to Flight's published primitive Table
//! schema. Missing, conflicted and mistyped cells are never coerced to null.
const std = @import("std");
const root = @import("root.zig");
const f = root.query.fuze;
const types = f.Types;
const max_columns = f.TableSchema.max_columns;
const a = f.arrow;
const Self = @This();
const Column = struct { name: f.Sql.Binding.Name, type: types.Type, nullable: bool };
columns: [max_columns]Column = undefined,
len: u8,
fingerprint: [32]u8,

/// The bounded primitive transport profile admits int64 outputs and the uint64
/// COUNT result after checked narrowing. Other input types may be filtered or
/// counted, but cannot be advertised as primitive int64 output.
pub fn init(plan: f.LogicalQuery.Plan) !Self {
    var fields: [max_columns]types.Field = undefined;
    const schema = try plan.outputSchema(&fields);
    var result: Self = .{ .len = @intCast(schema.structure.len), .fingerprint = try schema.fingerprint() };
    for (schema.structure, 0..) |field, index| {
        if (field.optional or (field.type != .int64 and !(field.type == .uint64 and (plan.aggregate == .count or plan.aggregate == .count_values)))) return error.UnsupportedFlightType;
        result.columns[index] = .{ .name = try .init(field.name), .type = field.type, .nullable = field.nullable };
    }
    return result;
}

pub fn checkSchema(self: *const Self, schema: types.Type) !void {
    if (!std.mem.eql(u8, &try schema.fingerprint(), &self.fingerprint)) return error.InvalidArrowResult;
}

pub fn encode(self: *const Self, rows: []const f.LogicalArrow.Row, output: []u8, workspace: []u8) ![]const u8 {
    return self.encodeDiagnostic(rows, output, workspace, null);
}

pub fn encodeDiagnostic(self: *const Self, rows: []const f.LogicalArrow.Row, output: []u8, workspace: []u8, diagnostic: ?*?root.query.protocol.Diagnostic) ![]const u8 {
    if (rows.len > f.Unified.max_rows) return error.InvalidArrowResult;
    for (rows) |row| if (row.cells.len != self.len) return error.InvalidArrowResult;
    var fixed: std.heap.FixedBufferAllocator = .init(workspace);
    const allocator = fixed.allocator();
    const kind: a.DataType = .{ .int64 = {} };
    var fields: [max_columns]a.Field = undefined;
    var arrays: [max_columns]a.ArrayRef = undefined;
    var built: usize = 0;
    defer for (arrays[0..built]) |*array| array.release();
    for (self.columns[0..self.len], 0..) |*column, index| {
        fields[index] = .{ .name = column.name.slice(), .data_type = &kind, .nullable = column.nullable };
        var builder = try a.Int64Builder.init(allocator, rows.len);
        defer builder.deinit();
        for (rows) |row| {
            const cell = row.cells[index];
            switch (cell) {
                .null => if (column.nullable) try builder.appendNull() else return error.InvalidArrowResult,
                .value => |value| {
                    if (value != .atom) return error.InvalidArrowResult;
                    try cell.validate(.{ .name = column.name.slice(), .type = column.type, .nullable = column.nullable }, .{});
                    switch (value.atom) {
                        .signed => |number| try builder.append(std.math.cast(i64, number) orelse return error.InvalidArrowResult),
                        .unsigned => |number| {
                            const full = std.math.cast(u64, number) orelse return error.InvalidArrowResult;
                            const narrowed = std.math.cast(i64, full) orelse {
                                if (diagnostic) |detail| detail.* = integerRange(column.name.slice(), full) catch null;
                                return error.FlightIntegerOutOfRange;
                            };
                            try builder.append(narrowed);
                        },
                        else => return error.UnsupportedFlightType,
                    }
                },
                else => return error.InvalidArrowResult,
            }
        }
        arrays[index] = try builder.finish();
        built += 1;
    }
    var batch = try a.RecordBatch.initBorrowed(allocator, .{ .fields = fields[0..self.len] }, arrays[0..self.len]);
    defer batch.deinit();
    return f.encode(allocator, batch, output);
}

fn integerRange(column: []const u8, number: u64) !root.query.protocol.Diagnostic {
    var result = try root.DiagnosticDetail.attempt(error.FlightIntegerOutOfRange, 12);
    try result.text(.column, .schema, column);
    try result.text(.expected_type, .owner, "int64");
    try result.text(.actual_type, .execution, "uint64");
    try result.fact(.supplied_value, .execution, .{ .unsigned = .init(number) });
    try result.fact(.limit, .owner, .{ .unsigned = .init(std.math.maxInt(i64)) });
    try result.fact(.completion, .execution, .{ .boolean = false });
    return result;
}

test "Table Flight conversion preserves full-width cells, projection nullability and aggregate types" {
    const t = std.testing;
    const table: types.Type = .{ .structure = &.{ .{ .name = "sum", .type = .int64 }, .{ .name = "value", .type = .int64, .nullable = true } } };
    const layout = try init(.{ .schema = table, .source_basis = @splat(1), .projection = &.{ 1, 0 } });
    try t.expect(layout.columns[0].nullable and !layout.columns[1].nullable);
    var cells = [_]types.Values.Cell{ .null, .{ .value = .{ .atom = .{ .signed = std.math.minInt(i64) } } } };
    var rows = [_]f.LogicalArrow.Row{.{ .cells = &cells }};
    const workspace = try t.allocator.alloc(u8, root.Metadata.working_bytes);
    defer t.allocator.free(workspace);
    var output: [8192]u8 = undefined;
    const bytes = try layout.encode(&rows, &output, workspace);
    try t.expectEqual(@as(u64, 1), (try root.Ipc.parts(bytes, workspace)).rows);
    var input: std.Io.Reader = .fixed(bytes);
    var reader = a.IpcStreamReader(*std.Io.Reader).init(t.allocator, &input);
    defer reader.deinit();
    const schema = try reader.readSchema();
    try t.expect(schema.fields[0].nullable and !schema.fields[1].nullable);
    var decoded = (try reader.nextRecordBatch()).?;
    defer decoded.deinit();
    try t.expect(decoded.column(0).data().isNull(0));
    try t.expectEqual(std.math.minInt(i64), try (a.Int64Array{ .data = decoded.column(1).data() }).value(0));
    cells[1] = .null;
    try t.expectError(error.InvalidArrowResult, layout.encode(&rows, &output, workspace));
    cells[1] = .missing;
    try t.expectError(error.InvalidArrowResult, layout.encode(&rows, &output, workspace));
    rows[0].cells = cells[0..1];
    inline for (.{ .count, .count_values }) |aggregate| {
        const plan: f.LogicalQuery.Plan = .{ .schema = table, .source_basis = @splat(1), .projection = &.{1}, .aggregate = aggregate, .output_names = &.{"present"} };
        const count = try init(plan);
        try count.checkSchema(.{ .structure = &.{.{ .name = "present", .type = .uint64 }} });
        cells[0] = .{ .value = .{ .atom = .{ .unsigned = 41 } } };
        _ = try count.encode(&rows, &output, workspace);
        try t.expect(!count.columns[0].nullable);
        cells[0] = .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u64) } } };
        var detail: ?root.query.protocol.Diagnostic = null;
        try t.expectError(error.FlightIntegerOutOfRange, count.encodeDiagnostic(&rows, &output, workspace, &detail));
        try t.expectEqualStrings("flight.integer_out_of_range", detail.?.code.slice());
        try t.expectEqual(.output, detail.?.stage);
        try t.expectEqual(.not_applicable, detail.?.outcome);
        try t.expectEqualStrings("present", detail.?.facts[0].?.value.?.text.slice());
        try t.expectEqual(std.math.maxInt(u64), try detail.?.facts[3].?.value.?.unsigned.value());
        try t.expectEqual(std.math.maxInt(i64), try detail.?.facts[4].?.value.?.unsigned.value());
        try t.expect(!detail.?.facts[5].?.value.?.boolean);
    }
    const plan: f.LogicalQuery.Plan = .{ .schema = table, .source_basis = @splat(1), .projection = &.{ 1, 1 }, .output_names = &.{ "first", "second" } };
    const renamed = try init(plan);
    try renamed.checkSchema(.{ .structure = &.{
        .{ .name = "first", .type = .int64, .nullable = true },
        .{ .name = "second", .type = .int64, .nullable = true },
    } });
    try t.expect(renamed.columns[0].nullable and renamed.columns[1].nullable);
}

test "wide logical layouts preserve schema nullability and reject unqualified output types" {
    const e = std.testing;
    var fields: [max_columns]types.Field = undefined;
    var names: [max_columns][16]u8 = undefined;
    var projection: [max_columns]u8 = undefined;
    for (&fields, &names, &projection, 0..) |*field, *name, *index, i| {
        field.* = .{ .name = try std.fmt.bufPrint(name, "column_{d}", .{i}), .type = .int64, .nullable = i % 3 == 0 };
        index.* = @intCast(i);
    }
    const schema: types.Type = .{ .structure = &fields };
    const plan: f.LogicalQuery.Plan = .{ .schema = schema, .source_basis = @splat(1), .projection = &projection };
    const layout = try init(plan);
    try layout.checkSchema(schema);
    fields[1].nullable = true;
    try e.expectError(error.InvalidArrowResult, layout.checkSchema(schema));
    @memset(std.mem.asBytes(&names), 'x');
    try e.expectEqualStrings("column_127", layout.columns[127].name.slice());
    const mixed: types.Type = .{ .structure = &.{
        .{ .name = "optional id", .type = .int64, .nullable = true },
        .{ .name = "東京", .type = .utf8 },
        .{ .name = "unsigned", .type = .uint64 },
    } };
    var selected: f.LogicalQuery.Plan = .{ .schema = mixed, .source_basis = @splat(1), .projection = &.{0} };
    try e.expect((try init(selected)).columns[0].nullable);
    selected.projection = &.{1};
    try e.expectError(error.UnsupportedFlightType, init(selected));
    selected.projection = &.{2};
    try e.expectError(error.UnsupportedFlightType, init(selected));
    selected.aggregate = .count_values;
    _ = try init(selected);
}
