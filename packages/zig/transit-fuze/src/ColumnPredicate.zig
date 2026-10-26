//! One typed column predicate, evaluated without retaining decoded rows.
//! Outcomes keep unknown and eager source failures distinct for later Boolean
//! composition. The caller owns the immutable literal for the entire operation.
const std = @import("std");
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const TableSchema = @import("TableSchema.zig");
const Collation = @import("Collation.zig");
const Finite = @import("Finite.zig");

pub const Outcome = enum(u8) {
    yes,
    no,
    unknown,
    type_error,
    conflict,

    pub fn truth(self: Outcome) !Finite.Truth {
        return switch (self) {
            .yes => .true_value,
            .no => .false_value,
            .unknown => .unknown,
            .type_error => error.QueryTypeError,
            .conflict => error.QueryConflict,
        };
    }
};

pub const Predicate = union(enum) {
    all,
    state: Types.State,
    compare: struct { op: Finite.Comparison, value: Values.Atom },
    null_compare,

    pub fn validate(self: Predicate, column: TableSchema.Column) !void {
        try column.validateEncodingAndCollation();
        switch (self) {
            .all, .state => {},
            .compare => |comparison| {
                try Types.Semantics.validate(comparison.value, column.type);
                if (column.type == .interval) return error.UnsupportedComparison;
                if (comparison.value == .bytes) try Collation.validateBytes(comparison.value.bytes, column.collation);
            },
            .null_compare => switch (column.type) {
                .interval, .json, .structure, .list, .array, .map, .tagged_union => return error.UnsupportedComparison,
                else => {},
            },
        }
    }

    pub fn evaluate(self: Predicate, column: TableSchema.Column, cell: Values.Cell) !Outcome {
        switch (self) {
            .all => return .yes,
            .state => |state| return if (std.meta.activeTag(cell) == state) .yes else .no,
            .compare, .null_compare => {},
        }
        return switch (cell) {
            .type_error => .type_error,
            .conflict => .conflict,
            .null, .missing => .unknown,
            .value => |value| blk: {
                if (self == .null_compare) break :blk .unknown;
                if (value != .atom) return error.UnsupportedComparison;
                const comparison = self.compare;
                const truth = try Finite.compareTruth(comparison.op, cell, comparison.value, column, struct {
                    fn order(descriptor: TableSchema.Column, left: Values.Value, right: Values.Atom) !std.math.Order {
                        return Collation.compareAtom(left.atom, right, descriptor.type, descriptor.collation);
                    }
                }.order);
                break :blk if (truth.selects()) .yes else .no;
            },
        };
    }
};
