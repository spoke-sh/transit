const std = @import("std");
const t = std.testing;
const f = @import("root.zig");

test "current IPC inspection validates complete streams and fingerprints logical schema" {
    const m = f.Unified;
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    var output: [8192]u8 = undefined;
    const schema: m.Schema = .{ .columns = &.{
        .{ .name = try m.Name.init("id"), .type = .int64 },
        .{ .name = try m.Name.init("value"), .type = .int64 },
    } };
    const bytes = try m.Arrow.encode(schema, &.{.{ .cells = &.{ .{ .value = .{ .int64 = 1 } }, .null } }}, workspace, &output);
    const fingerprint = try m.Inspect.segment(bytes, 1, workspace);
    try t.expectEqualSlices(u8, &try schema.fingerprint(), &fingerprint);
    try t.expectError(error.OutOfMemory, m.Inspect.segment(bytes, 1, workspace[0..1]));
    try t.expectError(error.InvalidArrowResult, m.Inspect.segment(bytes, 2, workspace));
    try t.expectError(error.InvalidArrowResult, m.Inspect.segment(bytes, 9, workspace));
    try t.expectError(error.InvalidArrowResult, m.Inspect.segment(bytes[0 .. bytes.len - 1], 1, workspace));
    var concatenated: [16384]u8 = undefined;
    @memcpy(concatenated[0..bytes.len], bytes);
    @memcpy(concatenated[bytes.len..][0..bytes.len], bytes);
    try t.expectError(error.InvalidArrowResult, m.Inspect.segment(concatenated[0 .. bytes.len * 2], 1, workspace));
    const changed = try m.Arrow.encode(schema, &.{.{ .cells = &.{ .{ .value = .{ .int64 = std.math.maxInt(i64) } }, .{ .value = .{ .int64 = std.math.minInt(i64) } } } }}, workspace, &output);
    try t.expectEqualSlices(u8, &fingerprint, &try m.Inspect.segment(changed, 1, workspace));
    const count = try m.Arrow.encode(.{ .columns = &.{.{ .name = try m.Name.init("count"), .type = .uint64 }} }, &.{.{ .cells = &.{.{ .value = .{ .uint64 = std.math.maxInt(u64) } }} }}, workspace, &output);
    try t.expect(!std.mem.eql(u8, &fingerprint, &try m.Inspect.segment(count, 1, workspace)));
    const empty = try m.Arrow.encode(schema, &.{}, workspace, &output);
    try t.expectEqualSlices(u8, &fingerprint, &try m.Inspect.segment(empty, 0, workspace));
}

test "current IPC inspection rejects primitive legacy result streams" {
    var workspace: [f.execution.working_bytes]u8 = undefined;
    var output: [8192]u8 = undefined;
    const data_type: f.arrow.DataType = .{ .string = {} };
    for ([_]bool{ false, true }) |nullable| {
        const fields = [_]f.arrow.Field{.{ .name = "value", .data_type = &data_type, .nullable = true }};
        var builder = try f.arrow.StringBuilder.init(t.allocator, 1, 256);
        defer builder.deinit();
        if (nullable) try builder.append(&@as([221]u8, @splat('x'))) else try builder.appendNull();
        var column = try builder.finish();
        defer column.release();
        var batch = try f.arrow.RecordBatch.initBorrowed(t.allocator, .{ .fields = &fields }, &.{column});
        defer batch.deinit();
        // Deliberately publish a stricter schema than the batch when testing
        // malformed nullability; normal RecordBatch construction rejects it.
        var wire_fields = fields;
        wire_fields[0].nullable = nullable;
        var buffer: std.Io.Writer = .fixed(&output);
        var writer = f.arrow.IpcStreamWriter(*std.Io.Writer).init(t.allocator, &buffer);
        defer writer.deinit();
        try writer.writeSchema(.{ .fields = &wire_fields });
        try writer.writeRecordBatch(batch);
        try writer.writeEnd();
        try t.expectError(error.InvalidArrowResult, f.Unified.Inspect.segment(buffer.buffered(), 1, &workspace));
    }
}
