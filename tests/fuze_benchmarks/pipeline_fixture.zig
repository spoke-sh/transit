//! Deterministic inputs shared by the measurement executable, not its oracle.
const std = @import("std");
const f = @import("transit_fuze");
const Cell = f.Types.Values.Cell;
pub const Case = enum { int64, uint64, float64, boolean, eager, sum, utf8, nested };
pub fn schema(case: Case, fields: *[2]f.Types.Field) f.Types.Type {
    fields.* = .{
        .{ .name = "key", .type = switch (case) {
            .uint64 => .uint64,
            .float64 => .float64,
            .boolean => .boolean,
            .utf8 => .utf8,
            .nested => .{ .list = .{ .type = &.int64, .nullable = true } },
            else => .int64,
        }, .nullable = true, .optional = true },
        .{ .name = "payload", .type = .int64 },
    };
    return .{ .structure = fields };
}
pub fn cells(case: Case, i: usize) [2]Cell {
    const n: i64 = @as(i64, @intCast(i % 101)) - 50;
    return .{
        if (i % 13 == 0) .null else if (i % 17 == 0) .missing else .{ .value = switch (case) {
            .uint64 => .{ .atom = .{ .unsigned = std.math.maxInt(u64) - @as(u64, @intCast(i % 101)) } },
            .float64 => .{ .atom = .{ .float = if (n == 0) -0.0 else @as(f64, @floatFromInt(n)) / 2 } },
            .boolean => .{ .atom = .{ .boolean = i % 2 == 0 } },
            .utf8 => .{ .atom = .{ .bytes = if (i % 2 == 0) "λ" else "a" } },
            .nested => .{ .list = &.{ .null, .{ .value = .{ .atom = .{ .signed = std.math.minInt(i64) } } } } },
            else => .{ .atom = .{ .signed = n } },
        } },
        .{ .value = .{ .atom = .{ .signed = @as(i64, @intCast(i)) * 3 - 7 } } },
    };
}
pub fn plan(case: Case, descriptor: f.Types.Type) f.LogicalQuery.Plan {
    return .{ .schema = descriptor, .source_basis = @splat(71), .projection = if (case == .nested) &.{0} else &.{1}, .aggregate = if (case == .sum) .sum else if (case == .nested) .count_values else .rows, .predicate = switch (case) {
        .int64, .sum => .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 0 } } },
        .uint64 => .{ .compare = .{ .column = 0, .op = .le, .value = .{ .unsigned = std.math.maxInt(u64) - 50 } } },
        .float64 => .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .float = 0 } } },
        .boolean => .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .boolean = true } } },
        .utf8 => .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .bytes = "λ" } } },
        .nested => .all,
        .eager => .{ .program = .{ .instructions = &.{
            .{ .atom = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 0 } } } },
            .{ .atom = .{ .compare = .{ .column = 1, .op = .lt, .value = .{ .signed = 6000 } } } },
            .conjunction,
        } } },
    } };
}
