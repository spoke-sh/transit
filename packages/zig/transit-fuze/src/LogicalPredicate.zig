//! Typed predicate atoms and bounded Boolean programs shared by finite file
//! queries and Table statements. Sources/admission do not belong to this layer.
const std = @import("std");
const types = @import("Types.zig");
const finite = @import("Finite.zig");
const values = types.Values;
const machine = @import("PredicateMachine.zig");

/// Instructions and variable-width atoms borrow immutable caller storage.
/// Compiled statements own both through their arena.
pub const Program = struct {
    pub const max_instructions = machine.max_instructions;
    pub const Instruction = machine.Instruction(Atom);
    instructions: []const Instruction,

    pub fn validate(self: Program, schema: types.Type) !void {
        try machine.validateShape(self.instructions);
        for (self.instructions) |instruction| {
            if (instruction == .atom) try instruction.atom.validate(schema);
        }
    }
    pub fn truth(self: Program, schema: types.Type, cells: []const values.Cell) !finite.Truth {
        return machine.truth(self.instructions, Row{ .schema = schema, .cells = cells });
    }
};
pub const Row = struct { schema: types.Type, cells: []const values.Cell };
pub const Atom = union(enum) {
    all,
    state: struct { column: u8, value: types.State },
    compare: struct { column: u8, op: finite.Comparison, value: types.Semantics.Atom },

    pub fn validateShape(self: Atom) !void {
        switch (self) {
            .all => {},
            .state => |state| if (state.column >= 128) return error.UnknownColumn,
            .compare => |comparison| {
                if (comparison.column >= 128) return error.UnknownColumn;
                if (comparison.value == .bytes and comparison.value.bytes.len > types.Query.max_cell_bytes) return error.CellTooLarge;
            },
        }
    }
    pub fn validate(self: Atom, schema: types.Type) !void {
        try self.validateShape();
        if (schema != .structure) return error.InvalidQuerySchema;
        switch (self) {
            .all => {},
            .state => |state| if (state.column >= schema.structure.len) return error.UnknownColumn,
            .compare => |comparison| {
                if (comparison.column >= schema.structure.len) return error.UnknownColumn;
                const expected = schema.structure[comparison.column].type;
                try types.Semantics.validate(comparison.value, expected);
                if (expected == .interval) return error.UnsupportedComparison;
            },
        }
    }
    pub fn truth(self: Atom, row: Row) !finite.Truth {
        return switch (self) {
            .all => .true_value,
            .state => |state| if (state.column < row.cells.len) finite.Truth.fromBool(std.meta.activeTag(row.cells[state.column]) == state.value) else error.UnknownColumn,
            .compare => |comparison| blk: {
                if (row.schema != .structure) return error.InvalidQuerySchema;
                if (comparison.column >= row.cells.len or comparison.column >= row.schema.structure.len) return error.UnknownColumn;
                break :blk try finite.compareTruth(comparison.op, row.cells[comparison.column], comparison.value, row.schema.structure[comparison.column].type, struct {
                    fn order(expected: types.Type, left: values.Value, right: types.Semantics.Atom) !std.math.Order {
                        if (left != .atom) return error.UnsupportedComparison;
                        return values.atomOrder(left.atom, right, expected);
                    }
                }.order);
            },
        };
    }
    pub fn write(self: Atom, schema: types.Type, writer: *std.Io.Writer) !void {
        switch (self) {
            .all => try writer.writeByte(0),
            .state => |state| try writer.writeAll(&.{ 1, state.column, @backingInt(state.value) }),
            .compare => |comparison| {
                try writer.writeAll(&.{ 2, comparison.column, @backingInt(comparison.op) });
                var value: [6144]u8 = undefined;
                const encoded = try types.Codec.encode(.{ .value = .{ .atom = comparison.value } }, .{ .name = "literal", .type = schema.structure[comparison.column].type }, &value);
                try writer.writeInt(u16, @intCast(encoded.len), .little);
                try writer.writeAll(encoded);
            },
        }
    }
};
