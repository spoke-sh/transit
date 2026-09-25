//! Bounded IPC validation shared by finite and segmented Station receivers.
const std = @import("std");
const f = @import("root.zig");

/// Validate one complete admitted IPC segment and return its output schema hash.
/// The caller bounds input bytes and owns workspace. No allocation escapes.
pub fn segment(bytes: []const u8, expected_rows: u8, workspace: []u8) ![32]u8 {
    if (expected_rows > f.model.max_rows or bytes.len < 8 or !std.mem.eql(u8, bytes[bytes.len - 8 ..], &.{ 255, 255, 255, 255, 0, 0, 0, 0 })) return error.InvalidArrowResult;
    var arena = std.heap.FixedBufferAllocator.init(workspace);
    var source: std.Io.Reader = .fixed(bytes);
    var reader = f.arrow.IpcStreamReader(*std.Io.Reader).init(arena.allocator(), &source);
    defer reader.deinit();
    const schema = try reader.readSchema();
    if (schema.fields.len == 0 or schema.fields.len > 2) return error.InvalidArrowResult;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.fuze.ipc.schema.v1\x00");
    hash.update(&.{@intCast(schema.fields.len)});
    for (schema.fields, 0..) |field, index| {
        _ = try f.model.Name.init(field.name);
        for (schema.fields[0..index]) |previous| if (std.mem.eql(u8, previous.name, field.name)) return error.DuplicateColumn;
        const data_type: f.model.Type = switch (field.data_type.*) {
            .int64 => .int64,
            .bool => .boolean,
            .string => .utf8,
            .binary => .binary,
            else => return error.InvalidArrowResult,
        };
        hash.update(&.{@intCast(field.name.len)});
        hash.update(field.name);
        hash.update(&.{ @backingInt(data_type), @intFromBool(field.nullable) });
    }
    var batch = (try reader.nextRecordBatch()) orelse return error.InvalidArrowResult;
    defer batch.deinit();
    if (batch.numRows() != expected_rows or batch.numColumns() != schema.fields.len) return error.InvalidArrowResult;
    for (schema.fields, 0..) |field, index| {
        const data = batch.column(index).data();
        try data.validateFull();
        for (0..expected_rows) |row| {
            if (data.isNull(row)) {
                if (!field.nullable) return error.InvalidArrowResult;
                continue;
            }
            switch (field.data_type.*) {
                .int64 => _ = try (f.arrow.Int64Array{ .data = data }).value(row),
                .bool => _ = try (f.arrow.BooleanArray{ .data = data }).value(row),
                .string => {
                    const value = try (f.arrow.StringArray{ .data = data }).value(row);
                    if (value.len > f.model.max_cell_bytes or !std.unicode.utf8ValidateSlice(value)) return error.InvalidArrowResult;
                },
                .binary => if ((try (f.arrow.BinaryArray{ .data = data }).value(row)).len > f.model.max_cell_bytes) return error.InvalidArrowResult,
                else => unreachable,
            }
        }
    }
    if (try reader.nextRecordBatch()) |extra| {
        var unexpected = extra;
        unexpected.deinit();
        return error.InvalidArrowResult;
    }
    if (source.bufferedLen() != 0) return error.InvalidArrowResult;
    return hash.finalResult();
}
