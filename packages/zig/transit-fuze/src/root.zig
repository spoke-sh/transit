//! Bounded caller-side query execution. No authority, transport or credentials.
const std = @import("std");
pub const arrow = @import("zarrow");
pub const compute = @import("zarrow_compute");
pub const model = @import("model.zig");
pub const Plan = @import("Plan.zig");
pub const execution = @import("execute.zig");
pub const Stream = @import("Stream.zig");
pub const Sql = @import("Sql.zig");
pub const Inspect = @import("Inspect.zig");
test {
    _ = @import("tests.zig");
    _ = @import("sql_test.zig");
    _ = @import("stream_test.zig");
    _ = @import("inspect_test.zig");
}

/// Serialize a complete, finite result into a caller-owned bounded buffer.
/// Arrow allocations belong to allocator; the returned bytes borrow output.
pub fn encode(allocator: std.mem.Allocator, batch: arrow.RecordBatch, output: []u8) ![]const u8 {
    var buffer = std.Io.Writer.fixed(output);
    var writer = arrow.IpcStreamWriter(*std.Io.Writer).init(allocator, &buffer);
    defer writer.deinit();
    try writer.writeSchema(batch.schema().*);
    try writer.writeRecordBatch(batch);
    try writer.writeEnd();
    return buffer.buffered();
}

test "Arrow IPC and compute share the same arrays and release their ownership" {
    const allocator = std.testing.allocator;
    const data_type: arrow.DataType = .{ .int64 = {} };
    const fields = [_]arrow.Field{.{ .name = "value", .data_type = &data_type, .nullable = true }};
    const schema: arrow.Schema = .{ .fields = &fields };
    var builder = try arrow.Int64Builder.init(allocator, 3);
    defer builder.deinit();
    try builder.append(4);
    try builder.appendNull();
    try builder.append(-1);
    var column = try builder.finish();
    defer column.release();
    var batch = try arrow.RecordBatch.initBorrowed(allocator, schema, &.{column});
    defer batch.deinit();
    var c_stream = try arrow.exportRecordBatchStreamToC(allocator, schema, &.{batch});
    defer if (c_stream.release) |release| release(&c_stream);
    var stream_import = try arrow.importRecordBatchStreamFromC(allocator, &c_stream);
    defer stream_import.deinit();
    try std.testing.expect(c_stream.release == null);
    try std.testing.expectEqual(@as(usize, 1), stream_import.batches.len);
    try std.testing.expectEqual(@as(usize, 3), stream_import.batches[0].numRows());
    try std.testing.expectError(error.Released, arrow.importRecordBatchStreamFromC(allocator, &c_stream));
    var buffer: [4096]u8 = undefined;
    const bytes = try encode(allocator, batch, &buffer);
    var source = std.Io.Reader.fixed(bytes);
    var reader = arrow.IpcStreamReader(*std.Io.Reader).init(allocator, &source);
    defer reader.deinit();
    _ = try reader.readSchema();
    var recovered = (try reader.nextRecordBatch()).?;
    defer recovered.deinit();
    try std.testing.expectEqual(@as(usize, 3), recovered.numRows());
    try std.testing.expect((try reader.nextRecordBatch()) == null);

    var exported = try arrow.exportArrayToC(allocator, column);
    defer if (exported.release) |release| release(&exported);
    var imported = try arrow.importArrayFromC(allocator, &data_type, &exported);
    defer imported.release();
    try std.testing.expect(exported.release == null);
    try std.testing.expectError(error.Released, arrow.importArrayFromC(allocator, &data_type, &exported));
    const imported_array: arrow.Int64Array = .{ .data = imported.data() };
    try std.testing.expectEqual(@as(i64, -1), try imported_array.value(2));
    try std.testing.expect(imported_array.isNull(1));

    var registry = arrow.compute.FunctionRegistry.init(allocator);
    defer registry.deinit();
    try compute.registerBaseKernels(&registry);
    var context = arrow.compute.ExecContext.init(allocator, &registry);
    const args = [_]arrow.compute.Datum{.fromArray(column)};
    var result = try context.invokeAggregate("sum", &args, .noneValue());
    defer result.release();
    try std.testing.expectEqual(@as(i64, 3), result.scalar.value.i64);
    var too_small: [1]u8 = undefined;
    try std.testing.expectError(error.WriteFailed, encode(allocator, batch, &too_small));
}
