//! Lossless common scalar matrix. NULL is a cell state, never a logical type.
const std = @import("std");
const f = @import("root.zig").fuze;
const Self = @This();
pub const Kind = enum { int64, uint64, float64, boolean, utf8, binary };
kind: Kind,
nullable: bool,
pub fn from(field: f.Types.Field) !Self {
    return .{ .kind = switch (field.type) {
        .int64 => .int64,
        .uint64 => .uint64,
        .float64 => .float64,
        .boolean => .boolean,
        .utf8 => .utf8,
        .binary => .binary,
        else => return error.UnsupportedWireType,
    }, .nullable = field.nullable };
}
pub fn logical(self: Self) f.Types.Type {
    return switch (self.kind) {
        inline else => |tag| @unionInit(f.Types.Type, @tagName(tag), {}),
    };
}
pub fn value(self: Self, cell: f.Types.Values.Cell) !?f.Types.Values.Atom {
    return switch (cell) {
        .null => if (self.nullable) null else error.NullNotAllowed,
        .missing => error.MissingWireValue,
        .type_error => error.QueryTypeError,
        .conflict => error.QueryConflict,
        .value => |v| blk: {
            if (v != .atom) return error.UnsupportedWireType;
            try f.LogicalPrepared.validate(v.atom, self.logical());
            break :blk v.atom;
        },
    };
}
test "wire admission refuses unsupported descriptors and non-SQL states" {
    const t = std.testing;
    try t.expectError(error.UnsupportedWireType, from(.{ .name = "x", .type = .int32, .nullable = true }));
    const column = try from(.{ .name = "x", .type = .uint64, .nullable = true });
    try t.expectEqual(@as(?f.Types.Values.Atom, null), try column.value(.null));
    try t.expectError(error.MissingWireValue, column.value(.missing));
    try t.expectError(error.QueryTypeError, column.value(.{ .type_error = .uint64 }));
    try t.expectEqual(@as(u128, std.math.maxInt(u64)), (try column.value(.{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u64) } } })).?.unsigned);
}
