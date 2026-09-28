//! Standard FlightData separates an IPC Message flatbuffer from its body.
//! Validate the selected finite stream with the existing Arrow reader before
//! returning bounded slices. No copied schema/array escapes the workspace.
const std = @import("std");
const root = @import("root.zig");
const a = root.query.fuze.arrow;
pub const Parts = struct {
    schema_message: []const u8,
    schema_header: []const u8,
    batch_header: []const u8,
    batch_body: []const u8,
    rows: u64,
};
fn allowed(kind: a.DataType, depth: u8) !void {
    if (depth > 8) return error.UnsupportedFlightType;
    switch (kind) {
        .int32, .int64, .uint32, .bool, .string, .binary => {},
        .list => |list| try allowed(list.value_field.data_type.*, depth + 1),
        .map => |map| {
            try allowed(map.key_field.data_type.*, depth + 1);
            try allowed(map.item_field.data_type.*, depth + 1);
        },
        .dense_union => |value| for (value.fields) |field| try allowed(field.data_type.*, depth + 1),
        else => return error.UnsupportedFlightType,
    }
}
fn headerEnd(bytes: []const u8, offset: usize) !usize {
    if (offset > bytes.len or bytes.len - offset < 8 or std.mem.readInt(u32, bytes[offset..][0..4], .little) != 0xffffffff) return error.InvalidFlightIpc;
    const size = std.mem.readInt(u32, bytes[offset + 4 ..][0..4], .little);
    if (size == 0 or size % 8 != 0 or size > bytes.len - offset - 8) return error.InvalidFlightIpc;
    return offset + 8 + size;
}
pub fn parts(bytes: []const u8, workspace: []u8) !Parts {
    if (bytes.len > 16384 or bytes.len < 24) return error.InvalidFlightIpc;
    const schema_end = try headerEnd(bytes, 0);
    var bounded: std.heap.FixedBufferAllocator = .init(workspace);
    var input: std.Io.Reader = .fixed(bytes);
    var reader = a.IpcStreamReader(*std.Io.Reader).init(bounded.allocator(), &input);
    defer reader.deinit();
    const schema = try reader.readSchema();
    for (schema.fields) |field| try allowed(field.data_type.*, 0);
    if (bytes.len - input.bufferedLen() != schema_end) return error.InvalidFlightIpc;
    const body_start = try headerEnd(bytes, schema_end);
    var batch = (try reader.nextRecordBatch()) orelse return error.InvalidFlightIpc;
    defer batch.deinit();
    if (input.bufferedLen() != 8) return error.InvalidFlightIpc;
    for (0..batch.numColumns()) |column| try batch.column(column).data().validateFull();
    const body_end = bytes.len - input.bufferedLen();
    if (body_start > body_end or !std.mem.eql(u8, bytes[body_end..], &.{ 255, 255, 255, 255, 0, 0, 0, 0 })) return error.InvalidFlightIpc;
    if (try reader.nextRecordBatch()) |extra| {
        var unexpected = extra;
        unexpected.deinit();
        return error.InvalidFlightIpc;
    }
    if (input.bufferedLen() != 0) return error.InvalidFlightIpc;
    return .{ .schema_message = bytes[0..schema_end], .schema_header = bytes[8..schema_end], .batch_header = bytes[schema_end + 8 .. body_start], .batch_body = bytes[body_start..body_end], .rows = batch.numRows() };
}

test "FlightData excludes IPC prefixes and EOS and preserves null/full-width rows" {
    const t = std.testing;
    var builder = try a.Int64Builder.init(t.allocator, 2);
    defer builder.deinit();
    try builder.append(std.math.minInt(i64));
    try builder.appendNull();
    var array = try builder.finish();
    defer array.release();
    const kind: a.DataType = .{ .int64 = {} };
    var batch = try a.RecordBatch.initBorrowed(t.allocator, .{ .fields = &.{.{ .name = "value", .data_type = &kind, .nullable = true }} }, &.{array});
    defer batch.deinit();
    var output: [8192]u8 = undefined;
    const stream = try root.query.fuze.encode(t.allocator, batch, &output);
    const workspace = try t.allocator.alloc(u8, 1024 * 1024);
    defer t.allocator.free(workspace);
    const framed = try parts(stream, workspace);
    try t.expectEqual(@as(u64, 2), framed.rows);
    try t.expectEqual(framed.schema_header.len + framed.batch_header.len + framed.batch_body.len + 24, stream.len);
    try t.expectError(error.InvalidFlightIpc, parts(stream[0 .. stream.len - 1], workspace));
    output[4..8].* = @splat(255);
    try t.expectError(error.InvalidFlightIpc, parts(stream, workspace));
}
