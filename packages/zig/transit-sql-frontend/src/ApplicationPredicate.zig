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
        .bytes => |value| if (expected == .binary) .{ .bytes = value.bytes } else error.ProgramTypeMismatch,
        .uuid => |value| if (expected == .uuid) .{ .uuid = value } else error.ProgramTypeMismatch,
        .timestamp => |value| if (expected == .timestamp and expected.timestamp == .utc) .{ .timestamp = value } else error.ProgramTypeMismatch,
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

/// Check the acquisition profile without fabricating a catalog identity. This
/// uses the same lowering and schema/collation validation as native encoding.
pub fn validate(program: a.Program, schema: f.TableSchema.Schema) !void {
    try a.Codec.validate(program);
    try schema.validate();
    const predicate = program.predicate orelse return;
    var builder: Self = .{ .schema = schema, .alias = program.input };
    try builder.lower(predicate, 0);
    var fields: [f.TableSchema.max_columns]f.WorkloadProjection.Field = undefined;
    for (schema.columns, fields[0..schema.columns.len]) |field, *slot| slot.* = .{ .column = field.id };
    const layout = try f.WorkloadProjection.schemaLayout(schema, fields[0..schema.columns.len], .claim);
    try (Program{ .instructions = builder.instructions[0..builder.count] }).validateCollations(layout.typeOf(), layout.collations);
}
/// Validate an offline specialization without inventing Queue columns or scalar
/// values. Call Types.bindForAnalysis first: it owns parameter scope/type checks.
/// Concrete atoms use the native validator; symbolic atoms retain its scalar
/// and literal restrictions and consume the same bounded instruction budget.
/// This produces no predicate bytes. Selected programs still use validate/compile.
pub fn validateForAnalysis(program: a.Program, schema: f.TableSchema.Schema, parameters: []const a.Types.Field) !void {
    if (parameters.len == 0) return validate(program, schema);
    try a.Codec.validate(program);
    try schema.validate();
    if (parameters.len > a.max_arguments) return error.ProgramTooComplex;
    var analysis: Analysis = .{ .program = program, .schema = schema, .parameters = parameters };
    if (program.predicate) |predicate| try analysis.check(predicate, 0);
}
const Analysis = struct {
    program: a.Program,
    schema: f.TableSchema.Schema,
    parameters: []const a.Types.Field,
    count: usize = 0,

    fn parameter(self: Analysis, expression: *const a.Expression) !?f.Types.Type {
        if (expression.value != .name) return null;
        for (self.parameters) |entry| if (std.mem.eql(u8, entry.name, expression.value.name)) {
            if (entry.value.protected or entry.value.fields.len != 0) return error.ProgramTypeMismatch;
            return switch (entry.value.kind) {
                .boolean => .boolean,
                .integer => .int64,
                .text => .utf8,
                .binary => .binary,
                .uuid => .uuid,
                .timestamp => .{ .timestamp = .utc },
                .duration => .interval,
                .json => .json,
                else => error.ProgramTypeMismatch,
            };
        };
        return null;
    }
    fn add(self: *Analysis, count: usize) !void {
        if (count > Program.max_instructions - self.count) return error.PredicateTooLarge;
        self.count += count;
    }
    fn check(self: *Analysis, expression: *const a.Expression, depth: usize) anyerror!void {
        if (depth > a.max_depth) return error.ProgramTooDeep;
        switch (expression.value) {
            .name => if (try self.parameter(expression)) |type_| {
                if (type_ != .boolean) return error.ProgramTypeMismatch;
                return self.add(1);
            },
            .unary => |value| switch (value.operator) {
                .not_ => {
                    try self.check(value.operand, depth + 1);
                    return self.add(1);
                },
                .is_null, .is_not_null => if (try self.parameter(value.operand) != null)
                    return self.add(if (value.operator == .is_null) 1 else 2),
                else => {},
            },
            .binary => |value| {
                if (value.operator == .and_ or value.operator == .or_) {
                    try self.check(value.left, depth + 1);
                    try self.check(value.right, depth + 1);
                    return self.add(1);
                }
                switch (value.operator) {
                    .equal, .not_equal, .less, .less_equal, .greater, .greater_equal => {
                        const reversed = value.left.value != .name and value.left.value != .field;
                        if (try self.parameter(if (reversed) value.right else value.left)) |type_| {
                            const constant = try literal(if (reversed) value.left else value.right, type_);
                            if (constant) |atom| {
                                try f.Types.Semantics.validate(atom, type_);
                                if (atom == .bytes and atom.bytes.len > f.Types.Query.max_cell_bytes) return error.CellTooLarge;
                                if (type_ == .interval) return error.UnsupportedComparison;
                            } else switch (type_) {
                                .interval, .json => return error.UnsupportedComparison,
                                else => {},
                            }
                            return self.add(1);
                        }
                    },
                    else => {},
                }
            },
            else => {},
        }
        // Validate the original concrete atom, including native collation and
        // operand restrictions. No parameter is substituted with a sample value.
        var builder: Self = .{ .schema = self.schema, .alias = self.program.input };
        try builder.lower(expression, depth);
        var fields: [f.TableSchema.max_columns]f.WorkloadProjection.Field = undefined;
        for (self.schema.columns, fields[0..self.schema.columns.len]) |field, *slot| slot.* = .{ .column = field.id };
        const layout = try f.WorkloadProjection.schemaLayout(self.schema, fields[0..self.schema.columns.len], .claim);
        try (Program{ .instructions = builder.instructions[0..builder.count] }).validateCollations(layout.typeOf(), layout.collations);
        try self.add(builder.count);
    }
};

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
        try validate(parsed.program, schema);
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
    try t.expectError(error.InvalidQueuePredicate, validate(invalid.program, schema));
}

test "analysis predicates keep scalar parameters separate and native forms bounded" {
    const t = std.testing;
    const schema: f.TableSchema.Schema = .{ .object = 4, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64 }} };
    const parameters: []const a.Types.Field = &.{
        .{ .name = "enabled", .value = .public(.boolean) },
        .{ .name = "limit", .value = .public(.integer) },
    };
    for ([_][]const u8{ "enabled", "id = 7 AND enabled", "NOT enabled OR id > 2", "enabled IS NOT NULL", "limit > 4", "4 < limit" }) |predicate| {
        const source = try std.fmt.allocPrint(t.allocator, "CREATE DATAFLOW x FROM QUEUE jobs AS event WHERE {s} AS BEGIN REQUIRE TRUE ELSE 'Refused'; END;", .{predicate});
        defer t.allocator.free(source);
        var parsed = try a.parse(t.allocator, source, null);
        defer parsed.deinit();
        var bound = try a.Types.bindForAnalysis(t.allocator, parsed.program, &.{.{ .name = "jobs", .kind = .queue, .fields = &.{.{ .name = "id", .value = .public(.integer) }} }}, parameters, null);
        defer bound.deinit();
        try validateForAnalysis(parsed.program, schema, parameters);
        try t.expectError(error.UnknownColumn, validate(parsed.program, schema));
    }
    for ([_][]const u8{ "id = limit", "limit = id", "NOW() > 0", "id + 1 = 7", "TRUE = TRUE" }) |predicate| {
        const source = try std.fmt.allocPrint(t.allocator, "CREATE DATAFLOW x FROM QUEUE jobs AS event WHERE {s} AS BEGIN REQUIRE TRUE ELSE 'Refused'; END;", .{predicate});
        defer t.allocator.free(source);
        var parsed = try a.parse(t.allocator, source, null);
        defer parsed.deinit();
        try t.expectError(error.InvalidQueuePredicate, validateForAnalysis(parsed.program, schema, parameters));
    }
    // 16 doubly negated leaves plus 15 conjunctions fit; two more NOTs exceed 64 even
    // though parameter leaves never become native predicate instructions.
    var leaves: [16][]const u8 = @splat("NOT NOT enabled");
    const predicate = try std.mem.join(t.allocator, " AND ", &leaves);
    defer t.allocator.free(predicate);
    const source = try std.fmt.allocPrint(t.allocator, "CREATE DATAFLOW x FROM QUEUE jobs AS event WHERE NOT NOT ({s}) AS BEGIN REQUIRE TRUE ELSE 'Refused'; END;", .{predicate});
    defer t.allocator.free(source);
    var parsed = try a.parse(t.allocator, source, null);
    defer parsed.deinit();
    try t.expectError(error.PredicateTooLarge, validateForAnalysis(parsed.program, schema, parameters));
}
