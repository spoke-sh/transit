//! Typed predicate atoms and bounded Boolean programs shared by finite file
//! queries and Table statements. Sources/admission do not belong to this layer.
const std = @import("std");
const types = @import("Types.zig");
const finite = @import("Finite.zig");
const values = types.Values;
const Collations = @import("QueryCollations.zig");
const Collation = @import("Collation.zig");
const machine = @import("PredicateMachine.zig");

/// Instructions and variable-width atoms borrow immutable caller storage.
/// Compiled statements own both through their arena.
pub const Program = struct {
    pub const max_instructions = machine.max_instructions;
    pub const Instruction = machine.Instruction(Atom);
    instructions: []const Instruction,

    pub fn validate(self: Program, schema: types.Type) !void {
        return self.validateCollations(schema, .{});
    }
    pub fn validateCollations(self: Program, schema: types.Type, collations: Collations) !void {
        try collations.validate(schema);
        try machine.validateShape(self.instructions);
        for (self.instructions) |instruction| {
            if (instruction == .atom) try instruction.atom.validateCollations(schema, collations);
        }
    }
    pub fn truth(self: Program, schema: types.Type, cells: []const values.Cell) !finite.Truth {
        return machine.truth(self.instructions, Row{ .schema = schema, .cells = cells });
    }
};
pub const Row = struct { schema: types.Type, cells: []const values.Cell, collations: Collations = .{} };
const CompareContext = struct {
    type: types.Type,
    collation: Collation.Collation,
    fn order(self: CompareContext, left: values.Value, right: types.Semantics.Atom) !std.math.Order {
        if (left != .atom) return error.UnsupportedComparison;
        return if (self.collation == .none) values.atomOrder(left.atom, right, self.type) else Collation.compareAtom(left.atom, right, self.type, self.collation);
    }
};
pub const Atom = union(enum) {
    all,
    state: struct { column: u8, value: types.State },
    compare: struct { column: u8, op: finite.Comparison, value: types.Semantics.Atom },
    /// A bound SQL NULL operand. Preserve the selected column and operation in
    /// intent bytes; source errors remain eager even though truth is unknown.
    null_compare: struct { column: u8, op: finite.Comparison },

    pub fn validateShape(self: Atom) !void {
        switch (self) {
            .all => {},
            .state => |state| if (state.column >= 128) return error.UnknownColumn,
            .null_compare => |comparison| if (comparison.column >= 128) return error.UnknownColumn,
            .compare => |comparison| {
                if (comparison.column >= 128) return error.UnknownColumn;
                if (comparison.value == .bytes and comparison.value.bytes.len > types.Query.max_cell_bytes) return error.CellTooLarge;
            },
        }
    }
    pub fn validate(self: Atom, schema: types.Type) !void {
        return self.validateCollations(schema, .{});
    }
    pub fn validateCollations(self: Atom, schema: types.Type, collations: Collations) !void {
        try self.validateShape();
        if (schema != .structure) return error.InvalidQuerySchema;
        switch (self) {
            .all => {},
            .state => |state| if (state.column >= schema.structure.len) return error.UnknownColumn,
            .null_compare => |comparison| {
                if (comparison.column >= schema.structure.len) return error.UnknownColumn;
                switch (schema.structure[comparison.column].type) {
                    .interval, .json, .structure, .list, .array, .map, .tagged_union => return error.UnsupportedComparison,
                    else => {},
                }
            },
            .compare => |comparison| {
                if (comparison.column >= schema.structure.len) return error.UnknownColumn;
                const expected = schema.structure[comparison.column].type;
                try types.Semantics.validate(comparison.value, expected);
                if (comparison.value == .bytes) try Collation.validateBytes(comparison.value.bytes, collations.columns[comparison.column]);
                if (expected == .interval) return error.UnsupportedComparison;
            },
        }
    }
    pub fn truth(self: Atom, row: Row) !finite.Truth {
        return switch (self) {
            .all => .true_value,
            .state => |state| if (state.column < row.cells.len) finite.Truth.fromBool(std.meta.activeTag(row.cells[state.column]) == state.value) else error.UnknownColumn,
            .null_compare => |comparison| blk: {
                if (row.schema != .structure) return error.InvalidQuerySchema;
                if (comparison.column >= row.cells.len or comparison.column >= row.schema.structure.len) return error.UnknownColumn;
                break :blk switch (row.cells[comparison.column]) {
                    .type_error => error.QueryTypeError,
                    .conflict => error.QueryConflict,
                    else => finite.Truth.unknown,
                };
            },
            .compare => |comparison| blk: {
                if (row.schema != .structure) return error.InvalidQuerySchema;
                if (comparison.column >= row.cells.len or comparison.column >= row.schema.structure.len) return error.UnknownColumn;
                break :blk try finite.compareTruth(comparison.op, row.cells[comparison.column], comparison.value, CompareContext{ .type = row.schema.structure[comparison.column].type, .collation = row.collations.columns[comparison.column] }, CompareContext.order);
            },
        };
    }
    pub fn write(self: Atom, schema: types.Type, writer: *std.Io.Writer) !void {
        switch (self) {
            .all => try writer.writeByte(0),
            .state => |state| try writer.writeAll(&.{ 1, state.column, @backingInt(state.value) }),
            .null_compare => |comparison| try writer.writeAll(&.{ 4, comparison.column, @backingInt(comparison.op) }),
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
