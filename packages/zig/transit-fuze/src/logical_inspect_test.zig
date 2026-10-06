const std = @import("std");
const e = std.testing;
const f = @import("root.zig");
const t = f.Types;
const ipc = f.LogicalArrow;
const inspect = f.LogicalInspect;
const Cell = t.Values.Cell;

test "logical Arrow decoding restores independent scalar bytes including exact width and sign" {
    const Fixture = struct { cases: []const struct { value_hex: []const u8 } };
    const fixture = try std.json.parseFromSlice(Fixture, e.allocator, @embedFile("fixtures/types.json"), .{ .ignore_unknown_fields = true });
    defer fixture.deinit();
    const workspace = try e.allocator.alloc(u8, ipc.working_bytes);
    defer e.allocator.free(workspace);
    var encoded: [ipc.segment_bytes]u8 = undefined;
    for (fixture.value.cases) |case| {
        var expected: [4096]u8 = undefined;
        const bytes = try std.fmt.hexToBytes(&expected, case.value_hex);
        var value = try t.Codec.decode(e.allocator, bytes);
        defer value.deinit();
        const scalar_schema: t.Type = .{ .structure = &.{value.field} };
        const arrow = try ipc.encode(scalar_schema, &.{.{ .cells = &.{value.cell} }}, workspace, &encoded);
        var restored = try inspect.decode(e.allocator, scalar_schema, arrow, 1, workspace);
        defer restored.deinit();
        @memset(&encoded, 0);
        @memset(workspace, 0);
        var actual: [4096]u8 = undefined;
        try e.expectEqualSlices(u8, bytes, try t.Codec.encode(restored.rows[0].cells[0], restored.descriptor.type.structure[0], &actual));
    }
}
const schema: t.Type = .{ .structure = &.{
    .{ .name = "items", .type = .{ .list = .{ .type = &.utf8, .nullable = true } }, .nullable = true, .optional = true },
    .{ .name = "variants", .type = .{ .tagged_union = &.{ .{ .name = "text", .type = .utf8, .nullable = true }, .{ .name = "wide", .type = .uint128 } } }, .nullable = true, .optional = true },
} };
const rows: []const ipc.Row = &.{
    .{ .cells = &.{ .{ .value = .{ .list = &.{ .{ .value = .{ .atom = .{ .bytes = "東京" } } }, .null } } }, .{ .value = .{ .tagged_union = .{ .index = 1, .value = &.{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u128) } } } } } } } },
    .{ .cells = &.{ .null, .{ .conflict = &.{ .{ .counter = 1, .replica = std.math.maxInt(u64), .value = .{ .value = .{ .tagged_union = .{ .index = 0, .value = &.{ .value = .{ .atom = .{ .bytes = "a" } } } } } } }, .{ .counter = std.math.maxInt(u64), .replica = 1, .value = .null } } } } },
    .{ .cells = &.{ .missing, .{ .type_error = .structure } } },
};
fn roundtrip(allocator: std.mem.Allocator, bytes: []const u8, workspace: []u8) !void {
    var owned = try inspect.decode(allocator, schema, bytes, rows.len, workspace);
    defer owned.deinit();
    try e.expectEqualDeep(rows, owned.rows);
    var output: [ipc.segment_bytes]u8 = undefined;
    try e.expectEqualSlices(u8, bytes, try ipc.encode(owned.descriptor.type, owned.rows, workspace, &output));
}
test "logical IPC rows own recursive states after every partial-allocation failure" {
    const workspace = try e.allocator.alloc(u8, ipc.working_bytes);
    defer e.allocator.free(workspace);
    var output: [ipc.segment_bytes]u8 = undefined;
    const bytes = try ipc.encode(schema, rows, workspace, &output);
    try e.checkAllAllocationFailures(e.allocator, roundtrip, .{ bytes, workspace });
    var owned = try inspect.decode(e.allocator, schema, bytes, rows.len, workspace);
    defer owned.deinit();
    @memset(&output, 0);
    @memset(workspace, 0);
    try e.expectEqualDeep(rows, owned.rows);
    const empty = try ipc.encode(schema, &.{}, workspace, &output);
    var zero = try inspect.decode(e.allocator, schema, empty, 0, workspace);
    defer zero.deinit();
    try e.expectEqual(@as(usize, 0), zero.rows.len);
}
test "logical IPC rejects incomplete extra and foreign-schema segments before disclosure" {
    const workspace = try e.allocator.alloc(u8, ipc.working_bytes);
    defer e.allocator.free(workspace);
    var output: [ipc.segment_bytes]u8 = undefined;
    const bytes = try ipc.encode(schema, rows, workspace, &output);
    try e.expectError(error.OutOfMemory, inspect.decode(e.allocator, schema, bytes, rows.len, workspace[0..1]));
    try e.expectError(error.InvalidArrowResult, inspect.decode(e.allocator, schema, bytes, rows.len - 1, workspace));
    try e.expectError(error.InvalidArrowResult, inspect.decode(e.allocator, schema, bytes, 9, workspace));
    for (0..bytes.len) |length| {
        if (inspect.decode(e.allocator, schema, bytes[0..length], rows.len, workspace)) |value| {
            var owned = value;
            owned.deinit();
            return error.AcceptedTruncatedArrow;
        } else |_| {}
    }
    var extra: [ipc.segment_bytes]u8 = undefined;
    @memcpy(extra[0..bytes.len], bytes);
    @memcpy(extra[bytes.len..][0..bytes.len], bytes);
    try e.expectError(error.InvalidArrowResult, inspect.decode(e.allocator, schema, extra[0 .. bytes.len * 2], rows.len, workspace));
    var fields = schema.structure[0..2].*;
    fields[0].name = "other";
    try e.expectError(error.InvalidArrowResult, inspect.decode(e.allocator, .{ .structure = &fields }, bytes, rows.len, workspace));
    const at = std.mem.indexOf(u8, bytes, ipc.definition).?;
    output[at] ^= 1;
    try e.expectError(error.InvalidArrowResult, inspect.decode(e.allocator, schema, bytes, rows.len, workspace));
    output[at] ^= 1;
    var buffer: std.Io.Writer = .fixed(&extra);
    var writer = f.arrow.IpcStreamWriter(*std.Io.Writer).init(e.allocator, &buffer);
    defer writer.deinit();
    var input: std.Io.Reader = .fixed(bytes);
    var reader = f.arrow.IpcStreamReader(*std.Io.Reader).init(e.allocator, &input);
    defer reader.deinit();
    const physical = try reader.readSchema();
    var batch = (try reader.nextRecordBatch()).?;
    defer batch.deinit();
    try writer.writeSchema(physical);
    try writer.writeRecordBatch(batch);
    try writer.writeRecordBatch(batch);
    try writer.writeEnd();
    try e.expectError(error.InvalidArrowResult, inspect.decode(e.allocator, schema, buffer.buffered(), rows.len, workspace));
}

test "logical IPC validates physical state and kind independently of Arrow structure" {
    const workspace = try e.allocator.alloc(u8, ipc.working_bytes);
    defer e.allocator.free(workspace);
    const scalar: t.Type = .{ .structure = &.{.{ .name = "x", .type = .int64, .nullable = true, .optional = true }} };
    for ([_]struct { field: usize, byte: u8 }{ .{ .field = 0, .byte = 255 }, .{ .field = 1, .byte = 0 }, .{ .field = 0, .byte = 0 } }) |mutation| {
        var output: [8192]u8 = undefined;
        const bytes = try ipc.encode(scalar, &.{.{ .cells = &.{.{ .value = .{ .atom = .{ .signed = 7 } } }} }}, workspace, &output);
        var input: std.Io.Reader = .fixed(bytes);
        var reader = f.arrow.IpcStreamReader(*std.Io.Reader).init(e.allocator, &input);
        defer reader.deinit();
        const physical = try reader.readSchema();
        var batch = (try reader.nextRecordBatch()).?;
        defer batch.deinit();
        var component = try (f.arrow.StructArray{ .data = batch.column(0).data() }).field(mutation.field);
        defer component.release();
        @constCast((try component.data().bufferAt(1)).data)[0] = mutation.byte;
        // The modified bytes still form a valid Arrow primitive array. The
        // logical state/kind/payload relationship must reject them separately.
        try batch.column(0).data().validateFull();
        var bad: [8192]u8 = undefined;
        var buffer: std.Io.Writer = .fixed(&bad);
        var writer = f.arrow.IpcStreamWriter(*std.Io.Writer).init(e.allocator, &buffer);
        defer writer.deinit();
        try writer.writeSchema(physical);
        try writer.writeRecordBatch(batch);
        try writer.writeEnd();
        try e.expectError(error.InvalidArrowResult, inspect.decode(e.allocator, scalar, buffer.buffered(), 1, workspace));
    }
}
