//! Shared finite predicate and ordered aggregate semantics. Storage/source
//! profiles own binding and layouts; missing/null/error/conflict rules are one.
const std = @import("std");
pub const Truth = @import("PredicateTruth.zig").Truth;
pub const Aggregate = enum(u8) { rows = 0, count = 1, sum = 2, count_values = 3 };
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
/// COUNT(column) consumes the cell state, independently of the value's type.
/// Filtering and an input LIMIT precede this operation; their row-progress
/// counter must remain separate from the number of contributing value cells.
pub fn countValue(previous: u64, cell: anytype) !u64 {
    return countState(previous, std.meta.activeTag(cell));
}
pub fn countState(previous: u64, state: anytype) !u64 {
    return switch (state) {
        .missing, .null => previous,
        .type_error => error.QueryTypeError,
        .conflict => error.QueryConflict,
        .value => try std.math.add(u64, previous, 1),
    };
}

test "value count preserves five-state errors and the full unsigned range" {
    const t = std.testing;
    const m = @import("Unified.zig");
    const scalar_cells = [_]m.Cell{
        .{ .value = .{ .int64 = -4 } },
        .{ .value = .{ .uint64 = std.math.maxInt(u64) } },
        .{ .value = .{ .float64 = -0.0 } },
        .{ .value = .{ .boolean = false } },
        .{ .value = .{ .utf8 = "" } },
        .{ .value = .{ .binary = "\x00\xff" } },
    };
    for (scalar_cells) |cell| try t.expectEqual(@as(u64, 13), try countValue(12, cell));
    const maximum = std.math.maxInt(u64);
    try t.expectEqual(maximum, try countValue(maximum - 1, scalar_cells[0]));
    try t.expectError(error.Overflow, countValue(maximum, scalar_cells[0]));
    try t.expectEqual(maximum, try countValue(maximum, @as(m.Cell, .null)));
    try t.expectEqual(@as(u64, 0), try countValue(0, @as(m.Cell, .missing)));
    try t.expectError(error.QueryTypeError, countValue(0, @as(m.Cell, .{ .type_error = .int64 })));
    const alternatives = [_]m.Alternative{.{ .counter = 1, .replica = 1, .value = .null }};
    try t.expectError(error.QueryConflict, countValue(0, @as(m.Cell, .{ .conflict = &alternatives })));

    // File plans use the logical cell representation; a structured top-level
    // value still contributes exactly one, without inspecting its children.
    const logical = @import("Types.zig").Values;
    try t.expectEqual(@as(u64, 1), try countValue(0, @as(logical.Cell, .{ .value = .{ .list = &.{} } })));
    try t.expectEqual(@as(u64, 0), try countValue(0, @as(logical.Cell, .null)));
}
