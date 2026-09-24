const std = @import("std");
const m = @import("model.zig");
const Plan = @This();
version: u8 = 1,
predicate: Predicate = .all,
projection: [2]?u8 = .{ 0, 1 },
limit: u8 = m.max_rows,
aggregate: enum { rows, count, sum } = .rows,

pub const Comparison = enum { eq, ne, lt, le, gt, ge };
pub const Predicate = union(enum) {
    all,
    is_null: u8,
    compare: struct { column: u8, op: Comparison, value: m.Cell },
};
pub const Physical = struct {
    logical: Plan,
    basis: m.Basis,
    schema: m.Schema,
    pub fn explain(self: Physical) Explanation {
        return .{ .basis = self.basis, .filter = self.logical.predicate != .all, .projection = self.logical.projection, .limit = self.logical.limit, .aggregate = @tagName(self.logical.aggregate) };
    }
};
pub const Explanation = struct {
    version: u8 = 1,
    source: []const u8 = "ordered_snapshot",
    basis: m.Basis,
    filter: bool,
    projection: [2]?u8,
    limit: u8,
    aggregate: []const u8,
    rewrites: [0]u8 = .{},
    max_batches: u8 = 1,
};
pub fn bind(self: Plan, source: m.Source) !Physical {
    try source.validate();
    if (self.version != 1) return error.UnsupportedPlan;
    if (self.limit > m.max_rows) return error.QueryBudgetExceeded;
    const first = self.projection[0] orelse return error.EmptyProjection;
    _ = try source.schema.columnType(first);
    if (self.projection[1]) |second| {
        _ = try source.schema.columnType(second);
        if (second == first) return error.DuplicateProjection;
    }
    if (self.aggregate == .sum and (self.projection[1] != null or try source.schema.columnType(first) != .int64)) return error.UnsupportedAggregate;
    switch (self.predicate) {
        .all => {},
        .is_null => |column| _ = try source.schema.columnType(column),
        .compare => |comparison| {
            const data_type = try source.schema.columnType(comparison.column);
            try comparison.value.validate(data_type);
            if (comparison.op != .eq and comparison.op != .ne and data_type != .int64) return error.UnsupportedComparison;
        },
    }
    return .{ .logical = self, .basis = source.basis, .schema = source.schema };
}
pub fn matches(self: Plan, row: m.Row) !bool {
    return switch (self.predicate) {
        .all => true,
        .is_null => |column| (try row.cell(column)) == .null,
        .compare => |comparison| blk: {
            const value = try row.cell(comparison.column);
            if (value == .null or comparison.value == .null) break :blk false;
            const order: std.math.Order = switch (value) {
                .int64 => |v| std.math.order(v, comparison.value.int64),
                .boolean => |v| std.math.order(@intFromBool(v), @intFromBool(comparison.value.boolean)),
                .utf8 => |v| std.mem.order(u8, v.slice(), comparison.value.utf8.slice()),
                .binary => |v| std.mem.order(u8, v.slice(), comparison.value.binary.slice()),
                .null => unreachable,
            };
            break :blk switch (comparison.op) {
                .eq => order == .eq,
                .ne => order != .eq,
                .lt => order == .lt,
                .le => order != .gt,
                .gt => order == .gt,
                .ge => order != .lt,
            };
        },
    };
}
