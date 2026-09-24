const std = @import("std");
const f = @import("root.zig");
const m = f.model;
const schema: m.Schema = .{ .names = .{ m.Name.init("id") catch unreachable, m.Name.init("value") catch unreachable }, .value_type = .int64 };
fn source(rows: []const m.Row) !m.Source {
    return .{ .basis = .{ .resource = 1, .revision = 3, .schema = try schema.fingerprint() }, .schema = schema, .rows = rows };
}
test "bounded plans preserve nulls and key order; sum rejects overflow and cancellation" {
    var workspace: [f.execution.working_bytes]u8 = undefined;
    var output: [768]u8 = undefined;
    var cancel = f.execution.Cancellation.init(false);
    const rows = [_]m.Row{ .{ .key = 1, .value = .{ .int64 = 4 } }, .{ .key = 2, .value = .null }, .{ .key = 3, .value = .{ .int64 = -1 } } };
    const input = try source(&rows);
    const plan: f.Plan = .{ .projection = .{ 1, null }, .aggregate = .sum };
    const physical = try plan.bind(input);
    const result = try f.execution.run(physical, input, &workspace, &output, &cancel);
    var reader_buffer = std.Io.Reader.fixed(result.bytes);
    var reader = f.arrow.IpcStreamReader(*std.Io.Reader).init(std.testing.allocator, &reader_buffer);
    defer reader.deinit();
    _ = try reader.readSchema();
    var batch = (try reader.nextRecordBatch()).?;
    defer batch.deinit();
    const values: f.arrow.Int64Array = .{ .data = batch.column(0).data() };
    try std.testing.expectEqual(@as(i64, 3), try values.value(0));
    try std.testing.expect((try reader.nextRecordBatch()) == null);
    var changed = input;
    changed.basis.revision += 1;
    try std.testing.expectError(error.SourceChanged, f.execution.run(physical, changed, &workspace, &output, &cancel));
    const overflow = try source(&.{ .{ .key = 1, .value = .{ .int64 = std.math.maxInt(i64) } }, .{ .key = 2, .value = .{ .int64 = 1 } } });
    try std.testing.expectError(error.Overflow, f.execution.run(try plan.bind(overflow), overflow, &workspace, &output, &cancel));
    try std.testing.expectError(error.OutOfMemory, f.execution.run(physical, input, workspace[0..1], &output, &cancel));
    try std.testing.expectError(error.WriteFailed, f.execution.run(physical, input, &workspace, output[0..1], &cancel));
    cancel.store(true, .release);
    try std.testing.expectError(error.Cancelled, f.execution.run(physical, input, &workspace, &output, &cancel));
    const selected: f.Plan = .{ .predicate = .{ .is_null = 1 }, .limit = 1 };
    try std.testing.expect(!try selected.matches(rows[0]));
    try std.testing.expect(try selected.matches(rows[1]));
}
test "each admitted type constructs an Arrow result and rejects mismatched predicates" {
    var workspace: [f.execution.working_bytes]u8 = undefined;
    var output: [768]u8 = undefined;
    const cancel = f.execution.Cancellation.init(false);
    const cells = [_]m.Cell{ .{ .int64 = 9007199254740993 }, .{ .boolean = true }, .{ .utf8 = try m.Bytes.init("東京") }, .{ .binary = try m.Bytes.init(&.{ 0, 255 }) } };
    inline for (.{ m.Type.int64, m.Type.boolean, m.Type.utf8, m.Type.binary }, 0..) |data_type, i| {
        var typed_schema = schema;
        typed_schema.value_type = data_type;
        const rows = [_]m.Row{ .{ .key = 1, .value = cells[i] }, .{ .key = 2, .value = .null } };
        const input: m.Source = .{ .basis = .{ .resource = 1, .revision = 0, .schema = try typed_schema.fingerprint() }, .schema = typed_schema, .rows = &rows };
        const plan: f.Plan = .{};
        const result = try f.execution.run(try plan.bind(input), input, &workspace, &output, &cancel);
        try std.testing.expectEqual(@as(u8, 2), result.rows);
        var invalid = plan;
        invalid.predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .boolean = true } } };
        try std.testing.expectError(error.TypeMismatch, invalid.bind(input));
        var empty = plan;
        empty.limit = 0;
        try std.testing.expectEqual(@as(u8, 0), (try f.execution.run(try empty.bind(input), input, &workspace, &output, &cancel)).rows);
    }
}
