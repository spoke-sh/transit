//! Compact typed DML payload under an exact full Table schema fingerprint.
//! Enclosing native commands own current-definition, identity and authorization.
const std = @import("std");
const d = @import("TableDml.zig");
const s = @import("TableSchema.zig");
const t = @import("Types.zig");
const Predicate = @import("LogicalPredicate.zig");
const Cell = t.Values.Cell;
pub const max_bytes = d.max_intent_bytes + 512;
fn nameCheck(name: []const u8) !void {
    if (name.len == 0 or name.len > 255 or !std.unicode.utf8ValidateSlice(name) or std.mem.indexOfScalar(u8, name, 0) != null) return error.InvalidTableName;
}
fn cellWrite(writer: *std.Io.Writer, value: Cell, field: t.Field) !void {
    var scratch: [256]u8 = undefined;
    var counter: std.Io.Writer.Discarding = .init(&scratch);
    try t.Codec.writeBound(value, field, &counter.writer);
    const size = counter.fullCount();
    if (size > t.Codec.max_bytes) return error.ValueBudgetExceeded;
    try writer.writeInt(u32, @intCast(size), .little);
    try t.Codec.writeBound(value, field, writer);
}
pub fn encode(allocator: std.mem.Allocator, plan: d.Plan, output: []u8) ![]const u8 {
    try nameCheck(plan.name);
    _ = try plan.fingerprint(allocator);
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll("FDM1");
    try writer.writeAll(&try plan.schema.fingerprint());
    try writer.writeByte(@intCast(plan.name.len));
    try writer.writeAll(plan.name);
    try writePayload(plan, &writer);
    return writer.buffered();
}
/// Schema/name-free composition for an enclosing command that has already bound
/// both to exact immutable metadata. This is not a standalone plan envelope.
pub fn encodePayload(allocator: std.mem.Allocator, plan: d.Plan, output: []u8) ![]const u8 {
    try nameCheck(plan.name);
    _ = try plan.fingerprint(allocator);
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writePayload(plan, &writer);
    return writer.buffered();
}
fn writePayload(plan: d.Plan, writer: *std.Io.Writer) !void {
    switch (plan.action) {
        .insert => |rows| {
            try writer.writeByte(1);
            try writer.writeInt(u16, @intCast(rows.len), .little);
            var fields: [s.max_columns]t.Field = undefined;
            const field: t.Field = .{ .name = "row", .type = try plan.schema.rowType(&fields) };
            for (rows) |row| try cellWrite(writer, .{ .value = .{ .structure = row } }, field);
        },
        .update => |assignments| {
            try writer.writeByte(2);
            try writer.writeInt(u16, @intCast(assignments.len), .little);
            for (assignments) |assignment| {
                try writer.writeInt(u64, assignment.column, .little);
                switch (assignment.value) {
                    .default => try writer.writeByte(0),
                    .cell => |cell| {
                        try writer.writeByte(1);
                        try cellWrite(writer, cell, plan.schema.columns[try plan.schema.index(assignment.column)].field());
                    },
                }
            }
        },
        .delete => try writer.writeByte(3),
    }
    if (plan.predicate) |program| {
        try writer.writeByte(1);
        try writer.writeByte(@intCast(program.instructions.len));
        for (program.instructions) |instruction| switch (instruction) {
            .negate => try writer.writeByte(1),
            .conjunction => try writer.writeByte(2),
            .disjunction => try writer.writeByte(3),
            .atom => |atom| {
                try writer.writeByte(0);
                switch (atom) {
                    .all => try writer.writeByte(0),
                    .state => |state| try writer.writeAll(&.{ 1, state.column, @backingInt(state.value) }),
                    .null_compare => |comparison| try writer.writeAll(&.{ 4, comparison.column, @backingInt(comparison.op) }),
                    .compare => |compare| {
                        try writer.writeAll(&.{ 2, compare.column, @backingInt(compare.op) });
                        try cellWrite(writer, .{ .value = .{ .atom = compare.value } }, .{ .name = "literal", .type = plan.schema.columns[compare.column].type });
                    },
                }
            },
        };
    } else try writer.writeByte(0);
}
fn cellRead(arena: *std.heap.ArenaAllocator, reader: *std.Io.Reader, field: t.Field) !Cell {
    const size = try reader.takeInt(u32, .little);
    if (size > t.Codec.max_bytes) return error.ValueBudgetExceeded;
    return t.Codec.decodeBound(arena, field, try reader.take(size));
}
fn atomRead(arena: *std.heap.ArenaAllocator, reader: *std.Io.Reader, schema: s.Schema) !Predicate.Atom {
    return switch (try reader.takeByte()) {
        0 => .all,
        1 => .{ .state = .{ .column = try reader.takeByte(), .value = std.enums.fromInt(t.State, try reader.takeByte()) orelse return error.InvalidMutationPlan } },
        4 => .{ .null_compare = .{ .column = try reader.takeByte(), .op = std.enums.fromInt(@import("Finite.zig").Comparison, try reader.takeByte()) orelse return error.InvalidMutationPlan } },
        2 => blk: {
            const column = try reader.takeByte();
            if (column >= schema.columns.len) return error.UnknownColumn;
            const op = std.enums.fromInt(@import("Finite.zig").Comparison, try reader.takeByte()) orelse return error.InvalidMutationPlan;
            const cell = try cellRead(arena, reader, .{ .name = "literal", .type = schema.columns[column].type });
            if (cell != .value or cell.value != .atom) return error.InvalidMutationPlan;
            break :blk .{ .compare = .{ .column = column, .op = op, .value = cell.value.atom } };
        },
        else => error.InvalidMutationPlan,
    };
}
/// The caller supplies the original immutable schema. Fingerprint mismatch is
/// checked before allocating or interpreting any schema-dependent value bytes.
/// The result owns names, schema, cells, defaults and predicate literals.
pub fn decode(allocator: std.mem.Allocator, schema: s.Schema, bytes: []const u8) !d.Owned {
    if (bytes.len > max_bytes) return error.MutationBatchTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FDM1")) return error.InvalidMutationPlan;
    if (!std.mem.eql(u8, try reader.take(32), &try schema.fingerprint())) return error.TableSchemaChanged;
    const name = try reader.take(try reader.takeByte());
    return decodePayload(allocator, schema, name, try reader.take(reader.bufferedLen()));
}
/// The enclosing contract must verify its exact immutable schema/name binding
/// before calling. The result owns both, including every schema-dependent cell.
pub fn decodePayload(allocator: std.mem.Allocator, schema: s.Schema, name: []const u8, bytes: []const u8) !d.Owned {
    if (bytes.len > max_bytes) return error.MutationBatchTooLarge;
    try nameCheck(name);
    try schema.validate();
    var reader: std.Io.Reader = .fixed(bytes);
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    var owned_schema = try schema.clone(allocator);
    errdefer owned_schema.deinit();
    var plan: d.Plan = .{ .name = try a.dupe(u8, name), .schema = owned_schema.schema, .action = undefined };
    plan.action = switch (try reader.takeByte()) {
        1 => blk: {
            const count = try reader.takeInt(u16, .little);
            if (count == 0 or count > d.max_rows) return error.MutationBatchTooLarge;
            const rows = try a.alloc([]const Cell, count);
            var fields: [s.max_columns]t.Field = undefined;
            const field: t.Field = .{ .name = "row", .type = try plan.schema.rowType(&fields) };
            for (rows) |*row| {
                const cell = try cellRead(&arena, &reader, field);
                if (cell != .value or cell.value != .structure) return error.InvalidMutationPlan;
                row.* = cell.value.structure;
            }
            break :blk .{ .insert = rows };
        },
        2 => blk: {
            const count = try reader.takeInt(u16, .little);
            if (count == 0 or count > plan.schema.columns.len) return error.InvalidMutationColumns;
            const assignments = try a.alloc(s.Assignment, count);
            for (assignments) |*assignment| {
                const id = try reader.takeInt(u64, .little);
                const column = plan.schema.columns[try plan.schema.index(id)];
                assignment.* = .{ .column = id, .value = switch (try reader.takeByte()) {
                    0 => .default,
                    1 => .{ .cell = try cellRead(&arena, &reader, column.field()) },
                    else => return error.InvalidMutationPlan,
                } };
            }
            break :blk .{ .update = assignments };
        },
        3 => .delete,
        else => return error.InvalidMutationPlan,
    };
    switch (try reader.takeByte()) {
        0 => {},
        1 => {
            const count = try reader.takeByte();
            if (count == 0 or count > Predicate.Program.max_instructions) return error.InvalidMutationPlan;
            const instructions = try a.alloc(Predicate.Program.Instruction, count);
            for (instructions) |*instruction| instruction.* = switch (try reader.takeByte()) {
                0 => .{ .atom = try atomRead(&arena, &reader, plan.schema) },
                1 => .negate,
                2 => .conjunction,
                3 => .disjunction,
                else => return error.InvalidMutationPlan,
            };
            plan.predicate = .{ .instructions = instructions };
        },
        else => return error.InvalidMutationPlan,
    }
    if (reader.bufferedLen() != 0) return error.InvalidMutationPlan;
    _ = try plan.fingerprint(allocator);
    return .{ .arena = arena, .schema = owned_schema, .plan = plan };
}
