//! Adapt verified current query cells to Flight's published primitive Table
//! schema. Missing, conflicted and mistyped cells are never coerced to null.
const std = @import("std");
const root = @import("root.zig");
const f = root.query.fuze;
const m = f.Unified;
const a = f.arrow;
const Self = @This();
columns: [2]m.Column = undefined,
nullable: [2]bool = undefined,
len: u8,

pub fn init(table: f.model.Schema, plan: m.Plan) !Self {
    if (table.value_type != .int64) return error.UnsupportedFlightType;
    try table.validate();
    const input = [_]m.Column{
        .{ .name = try .init(table.names[0].slice()), .type = .int64 },
        .{ .name = try .init(table.names[1].slice()), .type = .int64 },
    };
    var output: [m.max_columns]m.Column = undefined;
    const schema = try plan.outputSchema(.{ .columns = &input }, &output);
    var result: Self = .{ .len = @intCast(schema.columns.len) };
    if (result.len > result.columns.len) return error.UnsupportedFlightType;
    for (schema.columns, 0..) |column, index| {
        result.columns[index] = column;
        result.nullable[index] = if (plan.aggregate == .rows) plan.projection[index] != 0 else plan.aggregate == .sum;
    }
    return result;
}

pub fn checkSchema(self: *const Self, schema: m.Schema) !void {
    try schema.validate();
    if (schema.columns.len != self.len) return error.InvalidArrowResult;
    for (schema.columns, self.columns[0..self.len]) |actual, expected| if (!std.meta.eql(actual, expected)) return error.InvalidArrowResult;
}

pub fn encode(self: *const Self, rows: *const m.Inspect.Batch, output: []u8, workspace: []u8) ![]const u8 {
    if (rows.columns != self.len or rows.count > m.max_rows) return error.InvalidArrowResult;
    var fixed: std.heap.FixedBufferAllocator = .init(workspace);
    const allocator = fixed.allocator();
    const kind: a.DataType = .{ .int64 = {} };
    var fields: [2]a.Field = undefined;
    var arrays: [2]a.ArrayRef = undefined;
    var built: usize = 0;
    defer for (arrays[0..built]) |*array| array.release();
    for (self.columns[0..self.len], 0..) |*column, index| {
        fields[index] = .{ .name = column.name.slice(), .data_type = &kind, .nullable = self.nullable[index] };
        var builder = try a.Int64Builder.init(allocator, rows.count);
        defer builder.deinit();
        for (0..rows.count) |row| {
            const cell = rows.cells[row][index];
            try cell.validate(column.type);
            switch (cell) {
                .null => if (self.nullable[index]) try builder.appendNull() else return error.InvalidArrowResult,
                .value => |value| switch (value) {
                    .int64 => |number| try builder.append(number),
                    .uint64 => |number| try builder.append(std.math.cast(i64, number) orelse return error.Overflow),
                    else => return error.UnsupportedFlightType,
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

test "Table Flight conversion preserves full-width cells, projection nullability and aggregate types" {
    const t = std.testing;
    const table: f.model.Schema = .{ .names = .{ try .init("sum"), try .init("value") }, .value_type = .int64 };
    const layout = try init(table, .{ .projection = &.{ 1, 0 } });
    try t.expect(layout.nullable[0] and !layout.nullable[1]);
    var rows: m.Inspect.Batch = .{ .count = 1, .columns = 2 };
    rows.cells[0][0] = .null;
    rows.cells[0][1] = .{ .value = .{ .int64 = std.math.minInt(i64) } };
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
    rows.cells[0][1] = .null;
    try t.expectError(error.InvalidArrowResult, layout.encode(&rows, &output, workspace));
    rows.cells[0][1] = .missing;
    try t.expectError(error.InvalidArrowResult, layout.encode(&rows, &output, workspace));
    rows.columns = 1;
    inline for (.{ .count, .count_values }) |aggregate| {
        var plan: m.Plan = .{ .projection = &.{1}, .aggregate = aggregate };
        plan.output_names[0] = try .init("present");
        const count = try init(table, plan);
        try count.checkSchema(.{ .columns = &.{.{ .name = try .init("present"), .type = .uint64 }} });
        rows.cells[0][0] = .{ .value = .{ .uint64 = 41 } };
        _ = try count.encode(&rows, &output, workspace);
        try t.expect(!count.nullable[0]);
        rows.cells[0][0] = .{ .value = .{ .uint64 = std.math.maxInt(u64) } };
        try t.expectError(error.Overflow, count.encode(&rows, &output, workspace));
    }
    var plan: m.Plan = .{ .projection = &.{ 1, 1 } };
    plan.output_names[0] = try .init("first");
    plan.output_names[1] = try .init("second");
    const renamed = try init(table, plan);
    try renamed.checkSchema(.{ .columns = &.{
        .{ .name = try .init("first"), .type = .int64 },
        .{ .name = try .init("second"), .type = .int64 },
    } });
    try t.expect(renamed.nullable[0] and renamed.nullable[1]);
}
