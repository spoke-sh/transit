//! Pure typed DDL/DML lowering over an explicit schema. No catalog lookup,
//! intent admission, storage access or execution authority belongs here.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const v = c.TableValues;
const s = f.TableSchema;
const Cell = f.LogicalJson.Cell;
pub const Assignment = struct { column: []const u8, value: union(enum) { default, cell: Cell } };
pub const Instruction = union(enum) {
    atom: union(enum) {
        all,
        state: struct { column: []const u8, value: f.Types.State },
        compare: struct { column: []const u8, op: @FieldType(@FieldType(f.LogicalPredicate.Atom, "compare"), "op"), value: f.LogicalJson.Atom },
    },
    negate,
    conjunction,
    disjunction,
};
pub const Mutation = struct {
    pub const json_schema_sequence_bounds = .{ .predicate = f.LogicalPredicate.Program.max_instructions };
    action: union(enum) {
        insert: []const []const Assignment,
        update: []const Assignment,
        delete,
        pub const json_schema_sequence_bounds = .{ .insert = s.max_columns, .update = s.max_columns };
        pub const json_schema_outer_sequence_bounds = .{ .insert = f.TableDml.max_rows };
    },
    predicate: ?[]const Instruction,
};
pub const Change = union(enum) {
    add: struct { name: []const u8, type: f.Types.Type, nullable: bool, default: ?Cell, max_characters: ?u32, encoding: s.Encoding, collation: s.Collation, semantics: s.Semantics.Neutral },
    drop: []const u8,
    rename: struct { column: []const u8, name: []const u8 },
    default: struct { column: []const u8, value: ?Cell },
    nullable: struct { column: []const u8, value: bool },
    type: struct { column: []const u8, type: f.Types.Type, max_characters: ?u32 },
    physical: struct { column: []const u8, encoding: s.Encoding, collation: s.Collation, semantics: ?s.Semantics.Neutral },
    integrity: f.TableSchemaJson.Schema,
};
/// Converted payloads are a lower bound on the final canonical intent size.
/// Charge each cell immediately, before converting the next one. At most one
/// individually bounded cell can exceed the remaining conversion allowance;
/// final fingerprint admission still counts descriptors, defaults and framing.
const Conversion = struct {
    bytes: usize = 0,
    fn cell(self: *Conversion, value: f.Types.Values.Cell, field: f.Types.Field) !void {
        var scratch: [256]u8 = undefined;
        var count: std.Io.Writer.Discarding = .init(&scratch);
        try f.Types.Codec.writeBound(value, field, &count.writer);
        const size = count.fullCount();
        if (size > f.TableDml.max_intent_bytes - self.bytes) return error.MutationBatchTooLarge;
        self.bytes += @intCast(size);
    }
};
fn convert(allocator: std.mem.Allocator, cell: Cell, field: f.Types.Field, budget: *Conversion) !f.Types.Values.Cell {
    const result = try f.LogicalJson.fromForeign(allocator, cell, field);
    try budget.cell(result, field);
    return result;
}
fn assignments(allocator: std.mem.Allocator, schema: s.Schema, values: []const Assignment, budget: *Conversion) ![]const s.Assignment {
    if (values.len > schema.columns.len) return error.InvalidMutationColumns;
    const result = try allocator.alloc(s.Assignment, values.len);
    for (values, result) |value, *output| {
        const id = try v.unsigned(value.column);
        const column = schema.columns[try schema.index(id)];
        output.* = .{ .column = id, .value = switch (value.value) {
            .default => .default,
            .cell => |cell| .{ .cell = try convert(allocator, cell, column.field(), budget) },
        } };
    }
    try schema.validateAssignments(result);
    return result;
}
fn predicate(allocator: std.mem.Allocator, schema: s.Schema, values: ?[]const Instruction, budget: *Conversion) !?f.LogicalPredicate.Program {
    const source = values orelse return null;
    if (source.len > f.LogicalPredicate.Program.max_instructions) return error.PredicateTooLarge;
    const result = try allocator.alloc(f.LogicalPredicate.Program.Instruction, source.len);
    for (source, result) |instruction, *output| output.* = switch (instruction) {
        .negate => .negate,
        .conjunction => .conjunction,
        .disjunction => .disjunction,
        .atom => |atom| .{ .atom = switch (atom) {
            .all => .all,
            .state => |state| .{ .state = .{ .column = @intCast(try schema.index(try v.unsigned(state.column))), .value = state.value } },
            .compare => |value| blk: {
                const index = try schema.index(try v.unsigned(value.column));
                const cell = try convert(allocator, .{ .value = .{ .atom = value.value } }, schema.columns[index].field(), budget);
                break :blk .{ .compare = .{ .column = @intCast(index), .op = value.op, .value = cell.value.atom } };
            },
        } },
    };
    const program: f.LogicalPredicate.Program = .{ .instructions = result };
    var fields: [s.max_columns]f.Types.Field = undefined;
    try program.validate(try schema.rowType(&fields));
    return program;
}
/// Borrows the supplied schema and neutral input. The enclosing intent encoder
/// owns the final copy; this arena contains only bounded conversion workspace.
pub fn plan(arena: *std.heap.ArenaAllocator, schema: s.Schema, name: []const u8, mutation: Mutation) !f.TableDml.Plan {
    try schema.validate();
    _ = try c.TableMetadata.Name.init(name);
    const allocator = arena.allocator();
    var budget: Conversion = .{};
    const action: f.TableDml.Action = switch (mutation.action) {
        .insert => |rows| blk: {
            if (rows.len == 0 or rows.len > f.TableDml.max_rows) return error.MutationBatchTooLarge;
            if (mutation.predicate != null) return error.InvalidMutationPlan;
            const result = try allocator.alloc([]const f.Types.Values.Cell, rows.len);
            for (rows, result) |row, *output| {
                const cells = try allocator.alloc(f.Types.Values.Cell, schema.columns.len);
                output.* = try schema.insert(try assignments(allocator, schema, row, &budget), cells);
            }
            break :blk .{ .insert = result };
        },
        .update => |values| .{ .update = try assignments(allocator, schema, values, &budget) },
        .delete => .delete,
    };
    const result: f.TableDml.Plan = .{ .name = name, .schema = schema, .action = action, .predicate = try predicate(allocator, schema, mutation.predicate, &budget) };
    _ = try result.fingerprint(allocator);
    return result;
}
pub fn change(arena: *std.heap.ArenaAllocator, schema: s.Schema, value: Change) !f.TableEvolution.Change {
    const allocator = arena.allocator();
    const result: f.TableEvolution.Change = switch (value) {
        .add => |add| .{ .add = .{ .name = add.name, .type = add.type, .nullable = add.nullable, .default = if (add.default) |cell| try f.LogicalJson.fromForeign(allocator, cell, .{ .name = add.name, .type = add.type, .nullable = add.nullable }) else null, .max_characters = add.max_characters, .encoding = add.encoding, .collation = add.collation, .semantics = try s.Semantics.native(add.semantics, allocator) } },
        .drop => |id| .{ .drop = try v.unsigned(id) },
        .rename => |rename| .{ .rename = .{ .column = try v.unsigned(rename.column), .name = rename.name } },
        .default => |default| blk: {
            const id = try v.unsigned(default.column);
            const column = schema.columns[try schema.index(id)];
            break :blk .{ .default = .{ .column = id, .value = if (default.value) |cell| try f.LogicalJson.fromForeign(allocator, cell, column.field()) else null } };
        },
        .nullable => |nullable| .{ .nullable = .{ .column = try v.unsigned(nullable.column), .value = nullable.value } },
        .type => |typed| .{ .type = .{ .column = try v.unsigned(typed.column), .type = typed.type, .max_characters = typed.max_characters } },
        .physical => |physical| .{ .physical = .{ .column = try v.unsigned(physical.column), .encoding = physical.encoding, .collation = physical.collation, .semantics = if (physical.semantics) |rules| try s.Semantics.native(rules, allocator) else null } },
        .integrity => |value_| .{ .integrity = try f.TableSchemaJson.native(arena, value_) },
    };
    var columns: [s.max_columns]s.Column = undefined;
    _ = try f.TableEvolution.apply(schema, result, &columns);
    return result;
}
