//! Pure native-field descriptions for ordered program binding. No catalog,
//! values, transport or authority is consulted while describing a schema.
const std = @import("std");
const a = @import("ApplicationProgram.zig");
const types = @import("Types.zig");

pub fn bindField(output: std.mem.Allocator, field: types.Field) !a.Types.Value {
    try field.type.validate(.{});
    try requireType(field.type, 0);
    return bindType(output, field, 0);
}
pub fn requireType(type_: types.Type, depth: usize) anyerror!void {
    if (depth > a.max_depth) return error.ProgramTooDeep;
    switch (type_) {
        .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .boolean, .utf8, .binary, .uuid, .json, .capability => {},
        .timestamp => |zone| if (zone != .utc) return error.ProgramTypeMismatch,
        .structure => |fields| {
            if (fields.len > a.max_arguments) return error.ProgramTooComplex;
            for (fields) |field| try requireType(field.type, depth + 1);
        },
        else => return error.ProgramTypeMismatch,
    }
}
fn bindType(output: std.mem.Allocator, field: types.Field, depth: usize) anyerror!a.Types.Value {
    if (depth > a.max_depth) return error.ProgramTooDeep;
    var value: a.Types.Value = .{ .kind = undefined, .nullable = field.nullable };
    value.kind = switch (field.type) {
        .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32 => .integer,
        .boolean => .boolean,
        .utf8 => .text,
        .binary => .binary,
        .uuid => .uuid,
        .capability => .capability,
        .timestamp => |zone| if (zone == .utc) .timestamp else return error.ProgramTypeMismatch,
        .json => .json,
        .structure => |fields| blk: {
            if (fields.len > a.max_arguments) return error.ProgramTooComplex;
            const bound = try output.alloc(a.Types.Field, fields.len);
            for (fields, bound) |source, *target| target.* = .{ .name = try output.dupe(u8, source.name), .value = try bindType(output, source, depth + 1) };
            value.fields = bound;
            break :blk .record;
        },
        else => return error.ProgramTypeMismatch,
    };
    return value;
}
