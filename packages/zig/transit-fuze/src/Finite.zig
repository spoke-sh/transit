//! Shared finite predicate and ordered aggregate semantics. Storage/source
//! profiles own binding and layouts; missing/null/error/conflict rules are one.
const std = @import("std");
pub const Truth = @import("PredicateTruth.zig").Truth;
pub const Aggregate = enum(u8) { rows = 0, count = 1, sum = 2 };
pub const Comparison = enum(u8) { eq = 0, ne = 1, lt = 2, le = 3, gt = 4, ge = 5 };
pub fn compare(op: Comparison, cell: anytype, literal: anytype, context: anytype, comptime order: anytype) !bool {
    return (try compareTruth(op, cell, literal, context, order)).selects();
}
pub fn compareTruth(op: Comparison, cell: anytype, literal: anytype, context: anytype, comptime order: anytype) !Truth {
    return switch (cell) {
        .missing, .null => .unknown,
        .type_error => error.QueryTypeError,
        .conflict => error.QueryConflict,
        .value => |value| Truth.fromBool(switch (try order(context, value, literal)) {
            .lt => op == .lt or op == .le or op == .ne,
            .eq => op == .eq or op == .le or op == .ge,
            .gt => op == .gt or op == .ge or op == .ne,
        }),
    };
}
pub fn sum(previous: ?i64, cell: anytype, comptime integer: anytype) !?i64 {
    return switch (cell) {
        .missing, .null => previous,
        .type_error => error.QueryTypeError,
        .conflict => error.QueryConflict,
        .value => |value| try std.math.add(i64, previous orelse 0, try integer(value)),
    };
}
