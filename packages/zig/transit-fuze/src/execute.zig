const std = @import("std");
const root = @import("root.zig");
const a = root.arrow;
const m = @import("model.zig");
const Plan = @import("Plan.zig");
pub const Cancellation = std.atomic.Value(bool);
pub const Result = struct { bytes: []const u8, rows: u8, basis: m.Basis, digest: [32]u8 };
pub const working_bytes = 1024 * 1024;

/// One pull consumes a finite source. No retained worker or source pointers.
/// The caller may pause indefinitely before pulling without queued work here.
pub fn run(physical: Plan.Physical, source: m.Source, workspace: []u8, output: []u8, cancellation: *const Cancellation) !Result {
    try source.validate();
    if (!std.meta.eql(physical.basis, source.basis) or !std.meta.eql(physical.schema, source.schema)) return error.SourceChanged;
    _ = try physical.logical.bind(source);
    try cancelled(cancellation);
    var arena = std.heap.FixedBufferAllocator.init(workspace);
    const allocator = arena.allocator();
    var selected: [m.max_rows]m.Row = undefined;
    var count: usize = 0;
    for (source.rows) |row| {
        try cancelled(cancellation);
        if (count == physical.logical.limit) break;
        if (try physical.logical.matches(row)) {
            selected[count] = row;
            count += 1;
        }
    }
    var types: [2]a.DataType = undefined;
    var fields: [2]a.Field = undefined;
    var columns: [2]a.ArrayRef = undefined;
    var num_columns: usize = 0;
    defer for (columns[0..num_columns]) |*column| column.release();
    if (physical.logical.aggregate == .rows) {
        for (physical.logical.projection) |slot| if (slot) |column| {
            types[num_columns] = arrowType(try source.schema.columnType(column));
            fields[num_columns] = .{ .name = source.schema.names[column].slice(), .data_type = &types[num_columns], .nullable = column == 1 };
            columns[num_columns] = try makeColumn(allocator, selected[0..count], column, try source.schema.columnType(column));
            num_columns += 1;
        };
    } else {
        types[0] = .{ .int64 = {} };
        fields[0] = .{ .name = @tagName(physical.logical.aggregate), .data_type = &types[0], .nullable = physical.logical.aggregate == .sum };
        var builder = try a.Int64Builder.init(allocator, 1);
        defer builder.deinit();
        if (physical.logical.aggregate == .count) {
            try builder.append(@intCast(count));
        } else {
            var values = try makeColumn(allocator, selected[0..count], physical.logical.projection[0].?, .int64);
            defer values.release();
            var registry = a.compute.FunctionRegistry.init(allocator);
            defer registry.deinit();
            try root.compute.registerBaseKernels(&registry);
            var context = a.compute.ExecContext.init(allocator, &registry);
            var sum = try context.invokeAggregate("sum", &.{.fromArray(values)}, .noneValue());
            defer sum.release();
            switch (sum.scalar.value) {
                .null => try builder.appendNull(),
                .i64 => |value| try builder.append(value),
                else => return error.InvalidComputeResult,
            }
        }
        columns[0] = try builder.finish();
        num_columns = 1;
        count = 1;
    }
    try cancelled(cancellation);
    var batch = try a.RecordBatch.initBorrowed(allocator, .{ .fields = fields[0..num_columns] }, columns[0..num_columns]);
    defer batch.deinit();
    const bytes = try root.encode(allocator, batch, output);
    try cancelled(cancellation);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{ .bytes = bytes, .rows = @intCast(count), .basis = source.basis, .digest = digest };
}
fn cancelled(flag: *const Cancellation) !void {
    if (flag.load(.acquire)) return error.Cancelled;
}
fn arrowType(data_type: m.Type) a.DataType {
    return switch (data_type) {
        .int64 => .{ .int64 = {} },
        .boolean => .{ .bool = {} },
        .utf8 => .{ .string = {} },
        .binary => .{ .binary = {} },
    };
}
fn makeColumn(allocator: std.mem.Allocator, rows: []const m.Row, column: u8, data_type: m.Type) !a.ArrayRef {
    switch (data_type) {
        .int64 => {
            var builder = try a.Int64Builder.init(allocator, rows.len);
            defer builder.deinit();
            for (rows) |row| {
                const cell = try row.cell(column);
                if (cell == .null) try builder.appendNull() else try builder.append(cell.int64);
            }
            return builder.finish();
        },
        .boolean => {
            var builder = try a.BooleanBuilder.init(allocator, rows.len);
            defer builder.deinit();
            for (rows) |row| {
                const cell = try row.cell(column);
                if (cell == .null) try builder.appendNull() else try builder.append(cell.boolean);
            }
            return builder.finish();
        },
        .utf8, .binary => {
            if (data_type == .utf8) {
                var builder = try a.StringBuilder.init(allocator, rows.len, rows.len * m.max_cell_bytes);
                defer builder.deinit();
                for (rows) |row| {
                    const cell = try row.cell(column);
                    if (cell == .null) try builder.appendNull() else try builder.append(cell.utf8.slice());
                }
                return builder.finish();
            }
            var builder = try a.BinaryBuilder.init(allocator, rows.len, rows.len * m.max_cell_bytes);
            defer builder.deinit();
            for (rows) |row| {
                const cell = try row.cell(column);
                if (cell == .null) try builder.appendNull() else try builder.append(cell.binary.slice());
            }
            return builder.finish();
        },
    }
}
