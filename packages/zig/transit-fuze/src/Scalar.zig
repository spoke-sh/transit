//! Specialized six-scalar execution profile of the shared Fuze type model.
const std = @import("std");
pub const max_cell_bytes = 4096;
pub const max_conflicts = 8;
pub const Type = enum(u8) { int64 = 1, uint64 = 2, float64 = 3, boolean = 4, utf8 = 5, binary = 6 };
pub const Kind = enum(u8) { unknown = 0, int64 = 1, uint64 = 2, float64 = 3, boolean = 4, utf8 = 5, binary = 6, null_value = 7, map = 8, list = 9, text = 10, character = 11 };
pub const Scalar = union(Type) {
    int64: i64,
    uint64: u64,
    float64: f64,
    boolean: bool,
    utf8: []const u8,
    binary: []const u8,
    pub fn validate(self: Scalar, expected: Type) !void {
        if (std.meta.activeTag(self) != expected) return error.TypeMismatch;
        switch (self) {
            .float64 => |value| if (!std.math.isFinite(value)) return error.NonFiniteValue,
            .utf8, .binary => |bytes| {
                if (bytes.len > max_cell_bytes) return error.CellTooLarge;
                if (self == .utf8 and !std.unicode.utf8ValidateSlice(bytes)) return error.InvalidUtf8;
            },
            else => {},
        }
    }
    pub fn kind(self: Scalar) Kind {
        return @fromBackingInt(@intCast(@backingInt(std.meta.activeTag(self))));
    }
    pub fn order(left: Scalar, right: Scalar) !std.math.Order {
        try left.validate(std.meta.activeTag(right));
        try right.validate(std.meta.activeTag(left));
        return switch (left) {
            .int64 => |value| std.math.order(value, right.int64),
            .uint64 => |value| std.math.order(value, right.uint64),
            .float64 => |value| std.math.order(value, right.float64),
            .boolean => |value| std.math.order(@intFromBool(value), @intFromBool(right.boolean)),
            .utf8 => |value| std.mem.order(u8, value, right.utf8),
            .binary => |value| std.mem.order(u8, value, right.binary),
        };
    }
};
pub const Alternative = struct {
    counter: u64,
    replica: u64,
    value: union(enum) { null, type_error: Kind, value: Scalar },
};
pub const State = enum(u8) { missing = 0, null = 1, type_error = 2, value = 3, conflict = 4 };
pub const Cell = union(State) {
    missing,
    null,
    type_error: Kind,
    value: Scalar,
    conflict: []const Alternative,
    pub fn validate(self: Cell, expected: Type) !void {
        switch (self) {
            .value => |value| try value.validate(expected),
            .conflict => |values| {
                if (values.len < 2 or values.len > max_conflicts) return error.InvalidConflict;
                for (values, 0..) |value, index| {
                    if (value.counter == 0 or value.replica == 0) return error.InvalidConflict;
                    if (index > 0) {
                        const previous = values[index - 1];
                        if (value.counter < previous.counter or (value.counter == previous.counter and value.replica <= previous.replica)) return error.InvalidConflict;
                    }
                    switch (value.value) {
                        .value => |scalar| try scalar.validate(expected),
                        else => {},
                    }
                }
            },
            else => {},
        }
    }
};
