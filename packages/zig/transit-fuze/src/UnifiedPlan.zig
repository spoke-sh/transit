//! One ordered semantics for all v1 source adapters. No rewrites are enabled.
const std = @import("std");
const m = @import("Unified.zig");
const Self = @This();
version: u8 = 1,
predicate: Predicate = .all,
projection: []const u8,
output_names: [m.max_columns]?m.Name = @splat(null),
limit: ?u64 = null,
aggregate: Aggregate = .rows,
pub const Aggregate = @import("Finite.zig").Aggregate;
pub const Comparison = @import("Finite.zig").Comparison;
pub const Atom = union(enum) {
    all,
    state: struct { column: u8, value: m.State },
    compare: struct { column: u8, op: Comparison, value: m.Scalar },

    pub fn validateShape(self: Atom) !void {
        switch (self) {
            .all => {},
            .state => |state| if (state.column >= m.max_columns) return error.UnknownColumn,
            .compare => |comparison| {
                if (comparison.column >= m.max_columns) return error.UnknownColumn;
                try comparison.value.validate(std.meta.activeTag(comparison.value));
            },
        }
    }
    pub fn validate(self: Atom, schema: m.Schema) !void {
        try self.validateShape();
        try self.validateSchema(schema);
    }
    // Shape validation has already checked scalar representation and bounds.
    // Resolve the column and its declared type without validating bytes again.
    fn validateSchema(self: Atom, schema: m.Schema) !void {
        switch (self) {
            .all => {},
            .state => |state| _ = try schema.column(state.column),
            .compare => |comparison| if (std.meta.activeTag(comparison.value) != (try schema.column(comparison.column)).type) return error.TypeMismatch,
        }
    }
    /// Caller validates the schema and predicate before evaluating source rows.
    pub fn truth(self: Atom, row: m.Row) !m.Truth {
        return switch (self) {
            .all => .true_value,
            .state => |state| if (state.column < row.cells.len) m.Truth.fromBool(std.meta.activeTag(row.cells[state.column]) == state.value) else error.UnknownColumn,
            .compare => |comparison| blk: {
                if (comparison.column >= row.cells.len) return error.UnknownColumn;
                const cell = row.cells[comparison.column];
                break :blk try @import("Finite.zig").compareTruth(comparison.op, cell, comparison.value, {}, struct {
                    fn order(_: void, left: m.Scalar, right: m.Scalar) !std.math.Order {
                        return left.order(right);
                    }
                }.order);
            },
        };
    }
};
pub const Predicate = union(enum) {
    all,
    state: @FieldType(Atom, "state"),
    compare: @FieldType(Atom, "compare"),
    program: m.PredicateProgram.Owned,

    pub fn validateShape(self: *const Predicate) !void {
        switch (self.*) {
            .program => |*program| try (try program.view()).validateShape(),
            inline else => |value, tag| try @as(Atom, @unionInit(Atom, @tagName(tag), value)).validateShape(),
        }
    }
    pub fn validate(self: *const Predicate, schema: m.Schema) !void {
        switch (self.*) {
            .program => |*program| try (try program.view()).validate(schema),
            inline else => |value, tag| try @as(Atom, @unionInit(Atom, @tagName(tag), value)).validate(schema),
        }
    }
    // Called only after the enclosing plan has validated every atom's shape.
    fn validateSchema(self: *const Predicate, schema: m.Schema) !void {
        switch (self.*) {
            .program => |*program| for ((try program.view()).instructions) |instruction| {
                if (instruction == .atom) try instruction.atom.validateSchema(schema);
            },
            inline else => |value, tag| try @as(Atom, @unionInit(Atom, @tagName(tag), value)).validateSchema(schema),
        }
    }
    pub fn truth(self: *const Predicate, row: m.Row) !m.Truth {
        return switch (self.*) {
            .program => |*program| (try program.view()).truth(row),
            inline else => |value, tag| @as(Atom, @unionInit(Atom, @tagName(tag), value)).truth(row),
        };
    }
};
/// Schema-independent shape checks also protect canonical encoding/decoding.
pub fn validateShape(self: *const Self) !void {
    if (self.version != 1) return error.UnsupportedPlan;
    if (self.projection.len == 0 or self.projection.len > m.max_columns) return error.InvalidProjection;
    for (self.projection, 0..) |column, index| {
        if (column >= m.max_columns) return error.UnknownColumn;
        for (self.projection[0..index], 0..) |previous, prior| {
            if (column == previous and std.meta.eql(self.output_names[index], self.output_names[prior])) return error.DuplicateProjection;
        }
    }
    for (self.output_names, 0..) |name, index| if (name) |value| {
        if (index >= self.projection.len) return error.InvalidOutputNames;
        if (value.len > value.bytes.len or !std.meta.eql(value, try m.Name.init(value.slice()))) return error.InvalidColumnName;
    };
    if (self.aggregate != .rows and self.projection.len != 1) return error.UnsupportedAggregate;
    try self.predicate.validateShape();
}
pub fn validate(self: *const Self, schema: m.Schema) !void {
    try schema.validate();
    try self.validateShape();
    for (self.projection) |column| _ = try schema.column(column);
    const renamed = for (self.output_names[0..self.projection.len]) |name| {
        if (name != null) break true;
    } else false;
    // With no output aliases, validated source names and unique projections
    // already prove the row schema; aggregate names/types are fixed constants.
    // Renamed outputs still need the combined schema collision check.
    if (renamed) {
        var output: [m.max_columns]m.Column = undefined;
        for (0..self.projection.len) |index| output[index] = try self.outputColumn(schema, index);
        try (m.Schema{ .columns = output[0..self.projection.len] }).validate();
    }
    if (self.aggregate == .sum and (try schema.column(self.projection[0])).type != .int64) return error.UnsupportedAggregate;
    try self.predicate.validateSchema(schema);
}
/// The same validated output schema is used by execution, inspection and result
/// verification. The returned slice borrows columns, never the source schema.
pub fn outputSchema(self: *const Self, schema: m.Schema, columns: *[m.max_columns]m.Column) !m.Schema {
    try self.validate(schema);
    for (0..self.projection.len) |index| columns[index] = try self.outputColumn(schema, index);
    return .{ .columns = columns[0..self.projection.len] };
}
fn outputColumn(self: *const Self, schema: m.Schema, index: usize) !m.Column {
    var column = if (self.aggregate == .rows) try schema.column(self.projection[index]) else m.Column{
        .name = try m.Name.init(if (self.aggregate == .count_values) "count" else @tagName(self.aggregate)),
        .type = if (self.aggregate == .sum) .int64 else .uint64,
    };
    if (self.output_names[index]) |name| column.name = name;
    return column;
}
pub const Bound = struct {
    plan: Self,
    basis: m.Basis,
    schema: m.Schema,
    fingerprint: [32]u8,

    /// Revalidate the same source/schema/plan evidence without copying the plan.
    pub fn validate(self: *const Bound) !void {
        if (!std.mem.eql(u8, &try m.Codec.boundFingerprint(&self.plan, self.basis, self.schema), &self.fingerprint)) return error.SourceChanged;
    }
};
pub fn bind(self: *const Self, basis: m.Basis, schema: m.Schema) !Bound {
    return .{ .plan = self.*, .basis = basis, .schema = schema, .fingerprint = try m.Codec.boundFingerprint(self, basis, schema) };
}
pub fn matches(self: *const Self, row: m.Row) !bool {
    return (try self.predicateTruth(row)).selects();
}
/// Evaluate an already validated predicate without losing null/missing truth.
/// Only matches() reduces unknown to a nonmatching filter result.
pub fn predicateTruth(self: *const Self, row: m.Row) !m.Truth {
    return self.predicate.truth(row);
}
