const std = @import("std");
const t = std.testing;
const f = @import("root.zig");

test "IPC inspection has bounded allocation and fingerprints schema independently of values and source identity" {
    var workspace: [f.execution.working_bytes]u8 = undefined;
    var output: [8192]u8 = undefined;
    const cancel = f.execution.Cancellation.init(false);
    const schema: f.model.Schema = .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 };
    const source: f.model.Source = .{ .basis = .{ .resource = 7, .revision = 1, .schema = try schema.fingerprint() }, .schema = schema, .rows = &.{.{ .key = 1, .value = .null }} };
    const plan: f.Plan = .{};
    const result = try f.execution.run(try plan.bind(source), source, &workspace, &output, &cancel);
    const fingerprint = try f.Inspect.segment(result.bytes, result.rows, &workspace);
    try t.expectError(error.OutOfMemory, f.Inspect.segment(result.bytes, result.rows, workspace[0..1]));
    try t.expectError(error.InvalidArrowResult, f.Inspect.segment(result.bytes, 2, &workspace));
    try t.expectError(error.InvalidArrowResult, f.Inspect.segment(result.bytes, 33, &workspace));
    try t.expectError(error.InvalidArrowResult, f.Inspect.segment(result.bytes[0 .. result.bytes.len - 1], 1, &workspace));
    var concatenated: [16384]u8 = undefined;
    @memcpy(concatenated[0..result.bytes.len], result.bytes);
    @memcpy(concatenated[result.bytes.len..][0..result.bytes.len], result.bytes);
    try t.expectError(error.InvalidArrowResult, f.Inspect.segment(concatenated[0 .. result.bytes.len * 2], 1, &workspace));
    var other = source;
    other.basis.resource = 9;
    other.basis.revision = 7;
    other.rows = &.{ .{ .key = 2, .value = .{ .int64 = std.math.maxInt(i64) } }, .{ .key = 3, .value = .{ .int64 = std.math.minInt(i64) } } };
    const changed = try f.execution.run(try plan.bind(other), other, &workspace, &output, &cancel);
    try t.expectEqualSlices(u8, &fingerprint, &try f.Inspect.segment(changed.bytes, changed.rows, &workspace));
    const count: f.Plan = .{ .aggregate = .count };
    const aggregate = try f.execution.run(try count.bind(other), other, &workspace, &output, &cancel);
    try t.expect(!std.mem.eql(u8, &fingerprint, &try f.Inspect.segment(aggregate.bytes, aggregate.rows, &workspace)));
}

test "IPC inspection rejects nullability violations and cells beyond the qualified encoding" {
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
        try t.expectError(if (nullable) error.InvalidArrowResult else error.NullInNonNullableField, f.Inspect.segment(buffer.buffered(), 1, &workspace));
    }
}
