//! Bounded nested IPC. Source values borrow input; arrays/schema live only until
//! encoding finishes. The returned stream borrows output, never workspace.
const std = @import("std");
const f = @import("root.zig");
const m = f.Unified;
const a = f.arrow;
pub const working_bytes = 4 * 1024 * 1024;
pub const segment_bytes = 64 * 1024;
const u8_type: a.DataType = .{ .uint8 = {} };
const u64_type: a.DataType = .{ .uint64 = {} };
const Layout = struct {
    primitive: a.DataType,
    alternatives: [5]a.Field,
    alternative_type: a.DataType,
    list_type: a.DataType,
    fields: [4]a.Field,
    data_type: a.DataType,
    fn init(self: *Layout, data_type: m.Type) void {
        self.primitive = switch (data_type) {
            .int64 => .{ .int64 = {} },
            .uint64 => .{ .uint64 = {} },
            .float64 => .{ .double = {} },
            .boolean => .{ .bool = {} },
            .utf8 => .{ .string = {} },
            .binary => .{ .binary = {} },
        };
        self.alternatives = .{
            .{ .name = "counter", .data_type = &u64_type, .nullable = false },
            .{ .name = "replica", .data_type = &u64_type, .nullable = false },
            .{ .name = "state", .data_type = &u8_type, .nullable = false },
            .{ .name = "kind", .data_type = &u8_type, .nullable = false },
            .{ .name = "value", .data_type = &self.primitive, .nullable = true },
        };
        self.alternative_type = .{ .struct_ = .{ .fields = &self.alternatives } };
        self.list_type = .{ .list = .{ .value_field = .{ .name = "item", .data_type = &self.alternative_type, .nullable = false } } };
        self.fields = .{
            .{ .name = "state", .data_type = &u8_type, .nullable = false },
            .{ .name = "kind", .data_type = &u8_type, .nullable = false },
            .{ .name = "value", .data_type = &self.primitive, .nullable = true },
            .{ .name = "alternatives", .data_type = &self.list_type, .nullable = false },
        };
        self.data_type = .{ .struct_ = .{ .fields = &self.fields } };
    }
};
fn primitive(comptime data_type: m.Type, allocator: std.mem.Allocator, values: []const ?m.Scalar) !a.ArrayRef {
    const Builder = switch (data_type) {
        .int64 => a.Int64Builder,
        .uint64 => a.UInt64Builder,
        .float64 => a.Float64Builder,
        .boolean => a.BooleanBuilder,
        .utf8 => a.StringBuilder,
        .binary => a.BinaryBuilder,
    };
    var builder = if (comptime data_type == .utf8 or data_type == .binary) try Builder.init(allocator, values.len, 0) else try Builder.init(allocator, values.len);
    defer builder.deinit();
    for (values) |value| {
        if (value) |scalar| {
            try scalar.validate(data_type);
            try builder.append(@field(scalar, @tagName(data_type)));
        } else try builder.appendNull();
    }
    return builder.finish();
}
fn scalarArray(data_type: m.Type, allocator: std.mem.Allocator, values: []const ?m.Scalar) !a.ArrayRef {
    return switch (data_type) {
        inline else => |tag| primitive(tag, allocator, values),
    };
}
fn integerArray(comptime Builder: type, allocator: std.mem.Allocator, values: anytype) !a.ArrayRef {
    var builder = try Builder.init(allocator, values.len);
    defer builder.deinit();
    for (values) |value| try builder.append(value);
    return builder.finish();
}
fn structure(allocator: std.mem.Allocator, fields: []const a.Field, children: []const a.ArrayRef, count: usize) !a.ArrayRef {
    var builder = a.StructBuilder.init(allocator, fields);
    defer builder.deinit();
    for (0..count) |_| try builder.appendValid();
    return builder.finish(children);
}
fn columnArray(allocator: std.mem.Allocator, layout: *Layout, data_type: m.Type, rows: []const m.Row, column: usize) !a.ArrayRef {
    var states: [m.max_rows]u8 = undefined;
    var kinds: [m.max_rows]u8 = undefined;
    var values: [m.max_rows]?m.Scalar = @splat(null);
    var lengths: [m.max_rows]usize = @splat(0);
    var counters: [m.max_rows * m.max_conflicts]u64 = undefined;
    var replicas: [m.max_rows * m.max_conflicts]u64 = undefined;
    var alt_states: [m.max_rows * m.max_conflicts]u8 = undefined;
    var alt_kinds: [m.max_rows * m.max_conflicts]u8 = undefined;
    var alt_values: [m.max_rows * m.max_conflicts]?m.Scalar = @splat(null);
    var count: usize = 0;
    for (rows, 0..) |row, index| {
        const cell = row.cells[column];
        try cell.validate(data_type);
        states[index] = @backingInt(std.meta.activeTag(cell));
        kinds[index] = @backingInt(switch (cell) {
            .null => m.Kind.null_value,
            .type_error => |kind| kind,
            .value => |value| value.kind(),
            else => m.Kind.unknown,
        });
        switch (cell) {
            .value => |value| values[index] = value,
            .conflict => |alternatives| {
                lengths[index] = alternatives.len;
                for (alternatives) |alternative| {
                    counters[count] = alternative.counter;
                    replicas[count] = alternative.replica;
                    alt_states[count] = @backingInt(switch (alternative.value) {
                        .null => m.State.null,
                        .value => m.State.value,
                        .type_error => m.State.type_error,
                    });
                    alt_kinds[count] = @backingInt(switch (alternative.value) {
                        .null => m.Kind.null_value,
                        .value => |value| value.kind(),
                        .type_error => |kind| kind,
                    });
                    if (alternative.value == .value) alt_values[count] = alternative.value.value;
                    count += 1;
                }
            },
            else => {},
        }
    }
    var state_array = try integerArray(a.UInt8Builder, allocator, states[0..rows.len]);
    defer state_array.release();
    var kind_array = try integerArray(a.UInt8Builder, allocator, kinds[0..rows.len]);
    defer kind_array.release();
    var value_array = try scalarArray(data_type, allocator, values[0..rows.len]);
    defer value_array.release();
    var counter_array = try integerArray(a.UInt64Builder, allocator, counters[0..count]);
    defer counter_array.release();
    var replica_array = try integerArray(a.UInt64Builder, allocator, replicas[0..count]);
    defer replica_array.release();
    var alt_state_array = try integerArray(a.UInt8Builder, allocator, alt_states[0..count]);
    defer alt_state_array.release();
    var alt_kind_array = try integerArray(a.UInt8Builder, allocator, alt_kinds[0..count]);
    defer alt_kind_array.release();
    var alt_value_array = try scalarArray(data_type, allocator, alt_values[0..count]);
    defer alt_value_array.release();
    var alternatives = try structure(allocator, &layout.alternatives, &.{ counter_array, replica_array, alt_state_array, alt_kind_array, alt_value_array }, count);
    defer alternatives.release();
    var list_builder = try a.ListBuilder.init(allocator, rows.len, layout.list_type.list.value_field);
    defer list_builder.deinit();
    for (lengths[0..rows.len]) |length| try list_builder.appendLen(length);
    var list = try list_builder.finish(alternatives);
    defer list.release();
    return structure(allocator, &layout.fields, &.{ state_array, kind_array, value_array, list }, rows.len);
}
/// No partial stream is a result. On any error discard output. Workspace bounds
/// every Arrow allocation independently of the caller's output buffer size.
pub fn encode(schema: m.Schema, rows: []const m.Row, workspace: []u8, output: []u8) ![]const u8 {
    try schema.validate();
    if (rows.len > m.max_rows) return error.SourceBudgetExceeded;
    for (rows) |row| if (row.cells.len != schema.columns.len) return error.InvalidColumnCount;
    var fixed = std.heap.FixedBufferAllocator.init(workspace);
    const allocator = fixed.allocator();
    var layouts: [m.max_columns]Layout = undefined;
    var fields: [m.max_columns]a.Field = undefined;
    var arrays: [m.max_columns]a.ArrayRef = undefined;
    var created: usize = 0;
    defer for (arrays[0..created]) |*array| array.release();
    for (schema.columns, 0..) |*column, index| {
        layouts[index].init(column.type);
        fields[index] = .{ .name = column.name.slice(), .data_type = &layouts[index].data_type, .nullable = false };
        arrays[index] = try columnArray(allocator, &layouts[index], column.type, rows, index);
        created += 1;
    }
    var batch = try a.RecordBatch.initBorrowed(allocator, .{ .fields = fields[0..created] }, arrays[0..created]);
    defer batch.deinit();
    return f.encode(allocator, batch, output[0..@min(output.len, segment_bytes)]);
}
