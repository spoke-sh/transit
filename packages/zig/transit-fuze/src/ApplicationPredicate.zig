//! Lower a frozen Queue program's input predicate to the native acquisition
//! predicate. No source reparsing, row disclosure, lease or host effects occur.
const std = @import("std");
const f = @import("root.zig");
const p = @import("transit_protocol");
const a = f.ApplicationProgram;
const Program = f.LogicalQuery.Program;
const Self = @This();

schema: f.TableSchema.Schema,
alias: []const u8,
instructions: [Program.max_instructions]Program.Instruction = undefined,
count: usize = 0,

fn emit(self: *Self, instruction: Program.Instruction) !void {
    if (self.count == self.instructions.len) return error.PredicateTooLarge;
    self.instructions[self.count] = instruction;
    self.count += 1;
}
fn column(self: Self, expression: *const a.Expression) !u8 {
    const name = switch (expression.value) {
        .name => |name| name,
        .field => |field| blk: {
            if (field.base.value != .name or !std.mem.eql(u8, field.base.value.name, self.alias)) return error.UnknownColumn;
            break :blk field.name;
        },
        else => return error.InvalidQueuePredicate,
    };
    for (self.schema.columns, 0..) |field, i| if (std.mem.eql(u8, name, field.name)) return @intCast(i);
    return error.UnknownColumn;
}
fn literal(expression: *const a.Expression, expected: f.Types.Type) !?f.Types.Semantics.Atom {
    return switch (expression.value) {
        .null => null,
        .boolean => |value| .{ .boolean = value },
        .text => |value| .{ .bytes = value },
        .integer => |value| try integer(value, expected),
        .unary => |value| if (value.operator == .negate and value.operand.value == .integer)
            try integer(try std.math.negate(value.operand.value.integer), expected)
        else
            error.InvalidQueuePredicate,
        else => error.InvalidQueuePredicate,
    };
}
fn integer(value: i64, expected: f.Types.Type) !f.Types.Semantics.Atom {
    return switch (expected) {
        .uint8, .uint16, .uint32, .uint64 => .{ .unsigned = std.math.cast(u64, value) orelse return error.ProgramTypeMismatch },
        .int8, .int16, .int32, .int64 => .{ .signed = value },
        else => error.ProgramTypeMismatch,
    };
}
fn lower(self: *Self, expression: *const a.Expression, depth: usize) anyerror!void {
    if (depth > a.max_depth) return error.ProgramTooDeep;
    switch (expression.value) {
        .boolean => |value| {
            try self.emit(.{ .atom = .all });
            if (!value) try self.emit(.negate);
        },
        .name, .field => try self.emit(.{ .atom = .{ .compare = .{ .column = try self.column(expression), .op = .eq, .value = .{ .boolean = true } } } }),
        .unary => |value| switch (value.operator) {
            .not_ => {
                try self.lower(value.operand, depth + 1);
                try self.emit(.negate);
            },
            .is_null, .is_not_null => {
                try self.emit(.{ .atom = .{ .state = .{ .column = try self.column(value.operand), .value = .null } } });
                if (value.operator == .is_not_null) try self.emit(.negate);
            },
            else => return error.InvalidQueuePredicate,
        },
        .binary => |value| {
            if (value.operator == .and_ or value.operator == .or_) {
                try self.lower(value.left, depth + 1);
                try self.lower(value.right, depth + 1);
                return self.emit(if (value.operator == .and_) .conjunction else .disjunction);
            }
            var op: @import("Finite.zig").Comparison = switch (value.operator) {
                .equal => .eq,
                .not_equal => .ne,
                .less => .lt,
                .less_equal => .le,
                .greater => .gt,
                .greater_equal => .ge,
                else => return error.InvalidQueuePredicate,
            };
            const reversed = value.left.value != .name and value.left.value != .field;
            const ordinal = try self.column(if (reversed) value.right else value.left);
            if (reversed) op = switch (op) {
                .eq, .ne => op,
                .lt => .gt,
                .le => .ge,
                .gt => .lt,
                .ge => .le,
            };
            const constant = try literal(if (reversed) value.left else value.right, self.schema.columns[ordinal].type);
            try self.emit(.{ .atom = if (constant) |item| .{ .compare = .{ .column = ordinal, .op = op, .value = item } } else .{ .null_compare = .{ .column = ordinal, .op = op } } });
        },
        else => return error.InvalidQueuePredicate,
    }
}

pub fn compile(allocator: std.mem.Allocator, program: a.Program, target: p.StreamQueue.Partition, schema: f.TableSchema.Schema) !?p.QueuePredicate {
    try a.Codec.validate(program);
    try target.validate();
    try schema.validate();
    if (schema.object != target.interpretation.object.object) return error.SourceChanged;
    const predicate = program.predicate orelse return null;
    var builder: Self = .{ .schema = schema, .alias = program.input };
    try builder.lower(predicate, 0);
    var fields: [f.TableSchema.max_columns]f.WorkloadProjection.Field = undefined;
    for (schema.columns, fields[0..schema.columns.len]) |field, *slot| slot.* = .{ .column = field.id };
    const layout = try f.WorkloadProjection.schemaLayout(schema, fields[0..schema.columns.len], .claim);
    return try f.QueuePredicate.encode(allocator, target, schema, fields[0..schema.columns.len], .{
        .schema = layout.typeOf(),
        .source_basis = @splat(0),
        .collations = layout.collations,
        .projection = &.{0},
        .predicate = .{ .program = .{ .instructions = builder.instructions[0..builder.count] } },
    });
}

test "application acquisition predicates retain native schema target and SQL null truth" {
    const t = std.testing;
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(7) }, .partition = 0 };
    const schema: f.TableSchema.Schema = .{ .object = 4, .revision = 1, .next_column = 4, .columns = &.{
        .{ .id = 1, .name = "route", .type = .utf8, .collation = .ascii_ci },
        .{ .id = 2, .name = "count", .type = .int64 },
        .{ .id = 3, .name = "enabled", .type = .boolean },
    } };
    const cases = [_]struct { predicate: []const u8, accepted: bool }{
        .{ .predicate = "event.route = 'LOGIN' AND 2 < count", .accepted = true },
        .{ .predicate = "route = 'logout' OR count > 10", .accepted = false },
        .{ .predicate = "NOT (count = NULL)", .accepted = false },
        .{ .predicate = "enabled IS NULL AND NOT FALSE", .accepted = true },
        .{ .predicate = "enabled", .accepted = false },
        .{ .predicate = "count > -4", .accepted = true },
    };
    for (cases) |case| {
        const source = try std.fmt.allocPrint(t.allocator, "CREATE DATAFLOW x FROM QUEUE jobs AS event WHERE {s} AS BEGIN REQUIRE TRUE ELSE 'Refused'; END;", .{case.predicate});
        defer t.allocator.free(source);
        var parsed = try a.parse(t.allocator, source, null);
        defer parsed.deinit();
        const predicate = (try compile(t.allocator, parsed.program, target, schema)).?;
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        var evaluator = try f.QueuePredicate.Evaluator.init(arena.allocator(), target, schema, predicate);
        try t.expectEqual(case.accepted, try evaluator.matches(&.{ .{ .value = .{ .atom = .{ .bytes = "login" } } }, .{ .value = .{ .atom = .{ .signed = 3 } } }, .null }, 0));
        var foreign = target;
        foreign.partition = 1;
        try t.expectError(error.SourceChanged, f.QueuePredicate.Evaluator.init(arena.allocator(), foreign, schema, predicate));
        var changed = schema;
        changed.revision += 1;
        try t.expectError(error.SourceChanged, f.QueuePredicate.Evaluator.init(arena.allocator(), target, changed, predicate));
    }
    var invalid = try a.parse(t.allocator, "CREATE DATAFLOW x FROM QUEUE jobs AS event WHERE NOW() > 0 AS BEGIN REQUIRE TRUE ELSE 'Refused'; END;", null);
    defer invalid.deinit();
    try t.expectError(error.InvalidQueuePredicate, compile(t.allocator, invalid.program, target, schema));
}
