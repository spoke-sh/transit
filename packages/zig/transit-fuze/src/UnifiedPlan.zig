//! One ordered semantics for all v1 source adapters. No rewrites are enabled.
const std = @import("std");
const m = @import("Unified.zig");
const Self = @This();
version: u8 = 1,
predicate: Predicate = .all,
projection: []const u8,
limit: ?u64 = null,
aggregate: Aggregate = .rows,
pub const Aggregate = enum(u8) { rows = 0, count = 1, sum = 2 };
pub const Comparison = enum(u8) { eq = 0, ne = 1, lt = 2, le = 3, gt = 4, ge = 5 };
pub const Predicate = union(enum) {
    all,
    state: struct { column: u8, value: m.State },
    compare: struct { column: u8, op: Comparison, value: m.Scalar },
};
pub fn validate(self: Self, schema: m.Schema) !void {
    try schema.validate();
    if (self.version != 1) return error.UnsupportedPlan;
    if (self.projection.len == 0 or self.projection.len > m.max_columns) return error.InvalidProjection;
    for (self.projection, 0..) |column, index| {
        _ = try schema.column(column);
        for (self.projection[0..index]) |previous| if (column == previous) return error.DuplicateProjection;
    }
    if (self.aggregate != .rows and self.projection.len != 1) return error.UnsupportedAggregate;
    if (self.aggregate == .sum and (try schema.column(self.projection[0])).type != .int64) return error.UnsupportedAggregate;
    switch (self.predicate) {
        .all => {},
        .state => |state| _ = try schema.column(state.column),
        .compare => |comparison| try comparison.value.validate((try schema.column(comparison.column)).type),
    }
}
/// The same validated output schema is used by execution, inspection and result
/// verification. The returned slice borrows columns, never the source schema.
pub fn outputSchema(self: Self, schema: m.Schema, columns: *[m.max_columns]m.Column) !m.Schema {
    try self.validate(schema);
    if (self.aggregate != .rows) {
        columns[0] = .{ .name = try m.Name.init(@tagName(self.aggregate)), .type = if (self.aggregate == .count) .uint64 else .int64 };
        return .{ .columns = columns[0..1] };
    }
    for (self.projection, 0..) |index, offset| columns[offset] = try schema.column(index);
    return .{ .columns = columns[0..self.projection.len] };
}
pub const Bound = struct {
    plan: Self,
    basis: m.Basis,
    schema: m.Schema,
    fingerprint: [32]u8,
};
pub fn bind(self: Self, basis: m.Basis, schema: m.Schema) !Bound {
    try self.validate(schema);
    try basis.validate(schema);
    var bytes: [m.Codec.max_plan_bytes]u8 = undefined;
    const encoded = try m.Codec.encode(self, &bytes);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.fuze.plan.v1\x00");
    hash.update(encoded);
    return .{ .plan = self, .basis = basis, .schema = schema, .fingerprint = hash.finalResult() };
}
pub fn matches(self: Self, row: m.Row) !bool {
    return switch (self.predicate) {
        .all => true,
        .state => |state| if (state.column < row.cells.len) std.meta.activeTag(row.cells[state.column]) == state.value else error.UnknownColumn,
        .compare => |comparison| blk: {
            if (comparison.column >= row.cells.len) return error.UnknownColumn;
            const cell = row.cells[comparison.column];
            switch (cell) {
                .missing, .null => break :blk false,
                .type_error => return error.QueryTypeError,
                .conflict => return error.QueryConflict,
                .value => |value| {
                    const order = try value.order(comparison.value);
                    break :blk switch (comparison.op) {
                        .eq => order == .eq,
                        .ne => order != .eq,
                        .lt => order == .lt,
                        .le => order != .gt,
                        .gt => order == .gt,
                        .ge => order != .lt,
                    };
                },
            }
        },
    };
}
