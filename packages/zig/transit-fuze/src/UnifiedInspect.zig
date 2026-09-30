//! Finite v1 IPC decoding. All Arrow allocations use fixed workspace. Returned
//! scalar bytes are copied into caller-owned result storage, never that workspace.
const std = @import("std");
const f = @import("root.zig");
const m = f.Unified;
const a = f.arrow;
pub const Batch = struct {
    cells: [m.max_rows][m.max_columns]m.Cell = undefined,
    alternatives: [m.max_rows][m.max_columns][m.max_conflicts]m.Alternative = undefined,
    count: u8 = 0,
    columns: u8 = 0,
    pub fn row(self: *const Batch, index: usize) !m.Row {
        if (index >= self.count) return error.InvalidQueryOrdinal;
        return .{ .cells = self.cells[index][0..self.columns] };
    }
};
fn byte(data: *const a.ArrayData, index: usize) !u8 {
    if (data.isNull(index)) return error.InvalidArrowResult;
    return (a.UInt8Array{ .data = data }).value(index);
}
fn integer(data: *const a.ArrayData, index: usize) !u64 {
    if (data.isNull(index)) return error.InvalidArrowResult;
    return (a.UInt64Array{ .data = data }).value(index);
}
fn scalar(data_type: m.Type, data: *const a.ArrayData, index: usize, allocator: std.mem.Allocator) !m.Scalar {
    if (data.isNull(index)) return error.InvalidArrowResult;
    const value: m.Scalar = switch (data_type) {
        .int64 => .{ .int64 = try (a.Int64Array{ .data = data }).value(index) },
        .uint64 => .{ .uint64 = try (a.UInt64Array{ .data = data }).value(index) },
        .float64 => .{ .float64 = try (a.Float64Array{ .data = data }).value(index) },
        .boolean => .{ .boolean = try (a.BooleanArray{ .data = data }).value(index) },
        .utf8 => .{ .utf8 = try (a.StringArray{ .data = data }).value(index) },
        .binary => .{ .binary = try (a.BinaryArray{ .data = data }).value(index) },
    };
    try value.validate(data_type);
    return switch (value) {
        .utf8 => |bytes| .{ .utf8 = try allocator.dupe(u8, bytes) },
        .binary => |bytes| .{ .binary = try allocator.dupe(u8, bytes) },
        else => value,
    };
}
fn valueCell(data_type: m.Type, state: m.State, kind: m.Kind, data: *const a.ArrayData, index: usize, allocator: std.mem.Allocator) !m.Cell {
    if (state != .value and !data.isNull(index)) return error.InvalidArrowResult;
    return switch (state) {
        .missing => if (kind == .unknown) .missing else error.InvalidArrowResult,
        .null => if (kind == .null_value) .null else error.InvalidArrowResult,
        .type_error => .{ .type_error = kind },
        .value => blk: {
            const value = try scalar(data_type, data, index, allocator);
            if (kind != value.kind()) return error.InvalidArrowResult;
            break :blk .{ .value = value };
        },
        .conflict => error.InvalidArrowResult,
    };
}
fn alternatives(data_type: m.Type, values: a.ArrayRef, allocator: std.mem.Allocator, output: []m.Alternative) ![]const m.Alternative {
    const data = values.data();
    if (data.length < 2 or data.length > output.len) return error.InvalidArrowResult;
    const structure: a.StructArray = .{ .data = data };
    var counters = try structure.field(0);
    defer counters.release();
    var replicas = try structure.field(1);
    defer replicas.release();
    var states = try structure.field(2);
    defer states.release();
    var kinds = try structure.field(3);
    defer kinds.release();
    var content = try structure.field(4);
    defer content.release();
    for (0..data.length) |index| {
        if (data.isNull(index)) return error.InvalidArrowResult;
        const state = std.enums.fromInt(m.State, try byte(states.data(), index)) orelse return error.InvalidArrowResult;
        const kind = std.enums.fromInt(m.Kind, try byte(kinds.data(), index)) orelse return error.InvalidArrowResult;
        const cell = try valueCell(data_type, state, kind, content.data(), index, allocator);
        output[index] = .{
            .counter = try integer(counters.data(), index),
            .replica = try integer(replicas.data(), index),
            .value = switch (cell) {
                .null => .null,
                .value => |value| .{ .value = value },
                .type_error => |value| .{ .type_error = value },
                else => return error.InvalidArrowResult,
            },
        };
    }
    return output[0..data.length];
}
/// output must be at its final address: conflict slices borrow its fixed arrays.
/// Strings/binary belong to allocator. On error discard output and its arena.
pub fn decode(schema: m.Schema, bytes: []const u8, expected_rows: u8, workspace: []u8, allocator: std.mem.Allocator, output: *Batch) !void {
    try schema.validate();
    if (expected_rows > m.max_rows or bytes.len > m.Arrow.segment_bytes or bytes.len < 8 or !std.mem.eql(u8, bytes[bytes.len - 8 ..], &.{ 255, 255, 255, 255, 0, 0, 0, 0 })) return error.InvalidArrowResult;
    var fixed = std.heap.FixedBufferAllocator.init(workspace);
    var source: std.Io.Reader = .fixed(bytes);
    var reader = a.IpcStreamReader(*std.Io.Reader).init(fixed.allocator(), &source);
    defer reader.deinit();
    try m.Arrow.validateSchema(schema, try reader.readSchema());
    var batch = (try reader.nextRecordBatch()) orelse return error.InvalidArrowResult;
    defer batch.deinit();
    if (batch.numRows() != expected_rows or batch.numColumns() != schema.columns.len) return error.InvalidArrowResult;
    output.* = .{ .count = expected_rows, .columns = @intCast(schema.columns.len) };
    for (schema.columns, 0..) |column, column_index| {
        const data = batch.column(column_index).data();
        try data.validateFull();
        const structure: a.StructArray = .{ .data = data };
        var states = try structure.field(0);
        defer states.release();
        var kinds = try structure.field(1);
        defer kinds.release();
        var content = try structure.field(2);
        defer content.release();
        var lists = try structure.field(3);
        defer lists.release();
        for (0..expected_rows) |index| {
            if (data.isNull(index) or lists.data().isNull(index)) return error.InvalidArrowResult;
            const state = std.enums.fromInt(m.State, try byte(states.data(), index)) orelse return error.InvalidArrowResult;
            const kind = std.enums.fromInt(m.Kind, try byte(kinds.data(), index)) orelse return error.InvalidArrowResult;
            var values = try (a.ListArray{ .data = lists.data() }).value(index);
            defer values.release();
            const cell: m.Cell = if (state == .conflict) blk: {
                if (kind != .unknown or !content.data().isNull(index)) return error.InvalidArrowResult;
                break :blk .{ .conflict = try alternatives(column.type, values, allocator, &output.alternatives[index][column_index]) };
            } else blk: {
                if (values.data().length != 0) return error.InvalidArrowResult;
                break :blk try valueCell(column.type, state, kind, content.data(), index, allocator);
            };
            try cell.validate(column.type);
            output.cells[index][column_index] = cell;
        }
    }
    if (try reader.nextRecordBatch()) |extra| {
        var unexpected = extra;
        unexpected.deinit();
        return error.InvalidArrowResult;
    }
    if (source.bufferedLen() != 0) return error.InvalidArrowResult;
}

/// Infer the logical schema only from the current nested cell layout. The full
/// decoder below validates every field, state, scalar and stream boundary.
pub fn infer(bytes: []const u8, workspace: []u8, columns: *[m.max_columns]m.Column) !struct { schema: m.Schema, rows: u8 } {
    if (bytes.len > m.Arrow.segment_bytes or bytes.len < 8 or !std.mem.eql(u8, bytes[bytes.len - 8 ..], &.{ 255, 255, 255, 255, 0, 0, 0, 0 })) return error.InvalidArrowResult;
    var fixed = std.heap.FixedBufferAllocator.init(workspace);
    var source: std.Io.Reader = .fixed(bytes);
    var reader = a.IpcStreamReader(*std.Io.Reader).init(fixed.allocator(), &source);
    defer reader.deinit();
    const schema = try reader.readSchema();
    if (schema.fields.len == 0 or schema.fields.len > m.max_columns) return error.InvalidArrowResult;
    for (schema.fields, 0..) |field, index| {
        if (field.data_type.* != .struct_ or field.data_type.struct_.fields.len != 4) return error.InvalidArrowResult;
        columns[index] = .{ .name = try m.Name.init(field.name), .type = switch (field.data_type.struct_.fields[2].data_type.*) {
            .int64 => .int64,
            .uint64 => .uint64,
            .double => .float64,
            .bool => .boolean,
            .string => .utf8,
            .binary => .binary,
            else => return error.InvalidArrowResult,
        } };
    }
    const logical: m.Schema = .{ .columns = columns[0..schema.fields.len] };
    try m.Arrow.validateSchema(logical, schema);
    var batch = (try reader.nextRecordBatch()) orelse return error.InvalidArrowResult;
    defer batch.deinit();
    if (batch.numRows() > m.max_rows) return error.InvalidArrowResult;
    return .{ .schema = logical, .rows = @intCast(batch.numRows()) };
}
/// Validate a self-describing segment before sealing it for durable delivery.
/// No decoded cells escape this bounded operation.
pub fn segment(bytes: []const u8, expected_rows: u8, workspace: []u8) ![32]u8 {
    var columns: [m.max_columns]m.Column = undefined;
    const metadata = try infer(bytes, workspace, &columns);
    if (metadata.rows != expected_rows) return error.InvalidArrowResult;
    var owned: [m.Arrow.segment_bytes]u8 = undefined;
    var allocator = std.heap.FixedBufferAllocator.init(&owned);
    var batch: Batch = undefined;
    try decode(metadata.schema, bytes, expected_rows, workspace, allocator.allocator(), &batch);
    return metadata.schema.fingerprint();
}
