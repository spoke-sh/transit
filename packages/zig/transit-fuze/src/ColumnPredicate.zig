//! One typed column predicate, evaluated without retaining decoded rows.
//! Outcomes keep unknown and eager source failures distinct for later Boolean
//! composition. The caller owns the immutable literal for the entire operation.
const std = @import("std");
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const TableSchema = @import("TableSchema.zig");
const Collation = @import("Collation.zig");
const Finite = @import("Finite.zig");
const Machine = @import("PredicateMachine.zig");
const LogicalPredicate = @import("LogicalPredicate.zig");

pub const Atom = struct {
    column: u8,
    predicate: Predicate,
    pub fn validateShape(self: Atom) !void {
        if (self.column >= TableSchema.max_columns) return error.UnknownColumn;
    }
    pub fn truth(self: Atom, row: Row) !Finite.Truth {
        if (self.column >= row.schema.columns.len or self.column >= row.cells.len) return error.UnknownColumn;
        return (try self.predicate.evaluate(row.schema.columns[self.column], row.cells[self.column])).truth();
    }
};
const Row = struct { schema: TableSchema.Schema, cells: []const Values.Cell };

/// An execution-only program over a complete Table interpretation. Instructions
/// and literal bytes borrow their owner; this adds no saved-plan/wire format.
pub const Program = struct {
    pub const max_instructions = Machine.max_instructions;
    pub const Instruction = Machine.Instruction(Atom);
    instructions: []const Instruction,

    pub fn validate(self: Program, schema: TableSchema.Schema) !void {
        try schema.validate();
        try Machine.validateShape(self.instructions);
        for (self.instructions) |instruction| if (instruction == .atom) {
            const atom = instruction.atom;
            if (atom.column >= schema.columns.len) return error.UnknownColumn;
            try atom.predicate.validate(schema.columns[atom.column]);
        };
    }
    pub fn truth(self: Program, schema: TableSchema.Schema, cells: []const Values.Cell, failure: *?u8) !Finite.Truth {
        return Machine.truthDiagnostic(self.instructions, Row{ .schema = schema, .cells = cells }, failure);
    }
    /// Conservative abstract truth over trusted state counts and zone keys.
    /// Boolean composition uses the same three-valued truth operations as the
    /// row machine. Any possible eager failure prevents pruning the group.
    pub fn mayMatch(self: Program, schema: TableSchema.Schema, zones: anytype) !bool {
        try self.validate(schema);
        if (zones.len != schema.columns.len) return error.InvalidSegmentCoordinate;
        var stack: [max_instructions]Possibilities = undefined;
        var depth: usize = 0;
        for (self.instructions) |instruction| switch (instruction) {
            .atom => |atom| {
                stack[depth] = try atom.predicate.possibilities(schema.columns[atom.column], zones[atom.column]);
                depth += 1;
            },
            .negate => stack[depth - 1] = stack[depth - 1].negate(),
            .conjunction, .disjunction => {
                const right = stack[depth - 1];
                depth -= 1;
                stack[depth - 1] = stack[depth - 1].combine(right, instruction == .conjunction);
            },
        };
        return stack[0].fails or stack[0].truths & 1 != 0;
    }
    /// Preserve instruction order and unknown/NULL atoms while binding the
    /// physical execution to the host's exact column collations. The host must
    /// establish that this interpretation belongs to the source/accepted plan.
    pub fn fromLogical(program: LogicalPredicate.Program, output: *[max_instructions]Instruction) !Program {
        try Machine.validateShape(program.instructions);
        for (program.instructions, 0..) |instruction, i| output[i] = switch (instruction) {
            .atom => |atom| .{ .atom = switch (atom) {
                .all => .{ .column = 0, .predicate = .all },
                .state => |state| .{ .column = state.column, .predicate = .{ .state = state.value } },
                .compare => |comparison| .{ .column = comparison.column, .predicate = .{ .compare = .{ .op = comparison.op, .value = comparison.value } } },
                .null_compare => |comparison| .{ .column = comparison.column, .predicate = .null_compare },
            } },
            .negate => .negate,
            .conjunction => .conjunction,
            .disjunction => .disjunction,
        };
        return .{ .instructions = output[0..program.instructions.len] };
    }
};

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

    fn possibilities(self: Predicate, column: TableSchema.Column, zone: anytype) !Possibilities {
        const count = @as(u64, zone.value_count) + zone.null_count + zone.missing_count + zone.error_count + zone.conflict_count;
        if (count == 0) return .{};
        switch (self) {
            .all => return .{ .truths = 1 },
            .state => |state| {
                const selected = switch (state) {
                    .value => zone.value_count,
                    .null => zone.null_count,
                    .missing => zone.missing_count,
                    .type_error => zone.error_count,
                    .conflict => zone.conflict_count,
                };
                return .{ .truths = if (selected == 0) 2 else if (selected == count) 1 else 3 };
            },
            .compare, .null_compare => {},
        }
        var result: Possibilities = .{
            .fails = zone.error_count != 0 or zone.conflict_count != 0,
            .truths = if (zone.null_count != 0 or zone.missing_count != 0) 4 else 0,
        };
        if (zone.value_count == 0) return result;
        if (self == .null_compare) {
            result.truths |= 4;
            return result;
        }
        const comparison = self.compare;
        const candidate = candidate: {
            if (comparison.op == .ne) break :candidate true;
            var buffer: [Collation.max_sort_key_bytes]u8 = undefined;
            const key = Collation.encodeSortKey(.{ .value = .{ .atom = comparison.value } }, column.type, column.collation, &buffer) catch |err| switch (err) {
                error.WriteFailed => break :candidate true,
                else => return err,
            };
            break :candidate switch (comparison.op) {
                .eq => zone.mayMatch(.eq, key),
                .lt => zone.mayMatch(.lt, key),
                .le => zone.mayMatch(.le, key),
                .gt => zone.mayMatch(.gt, key),
                .ge => zone.mayMatch(.ge, key),
                .ne => unreachable,
            };
        };
        result.truths |= if (candidate) @as(u3, 3) else 2;
        return result;
    }
};

const Possibilities = struct {
    // Bits denote true, false and unknown in PredicateTruth declaration order.
    truths: u3 = 0,
    fails: bool = false,
    const values = [_]Finite.Truth{ .true_value, .false_value, .unknown };
    fn bit(value: Finite.Truth) u3 {
        return @as(u3, 1) << @intCast(@backingInt(value));
    }
    fn negate(self: Possibilities) Possibilities {
        var result: Possibilities = .{ .fails = self.fails };
        for (values) |value| if (self.truths & bit(value) != 0) {
            result.truths |= bit(value.negate());
        };
        return result;
    }
    fn combine(self: Possibilities, other: Possibilities, conjunction: bool) Possibilities {
        var result: Possibilities = .{ .fails = self.fails or other.fails };
        for (values) |left| {
            if (self.truths & bit(left) == 0) continue;
            for (values) |right| {
                if (other.truths & bit(right) == 0) continue;
                result.truths |= bit(if (conjunction) left.conjunction(right) else left.disjunction(right));
            }
        }
        return result;
    }
};
