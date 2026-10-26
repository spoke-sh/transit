//! General typed Table DML compilation. The owner freezes selection and accepts
//! one complete successor; this model never publishes individual SQL row prefixes.
const std = @import("std");
const sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
const s = @import("TableSchema.zig");
const t = @import("Types.zig");
const Predicate = @import("LogicalPredicate.zig");
const Cell = t.Values.Cell;
const Reference = @import("SqlReference.zig");
const SqlPredicate = @import("SqlLogicalPredicate.zig");
pub const max_rows = 1024;
pub const max_intent_bytes = 4 * 1024 * 1024;
pub const Action = union(enum) { insert: []const []const Cell, update: []const s.Assignment, delete };
pub const Plan = struct {
    name: []const u8,
    schema: s.Schema,
    action: Action,
    predicate: ?Predicate.Program = null,
    pub fn validate(self: Plan) !void {
        try self.schema.validate();
        switch (self.action) {
            .insert => |rows| {
                if (rows.len == 0 or rows.len > max_rows) return error.MutationBatchTooLarge;
                if (self.predicate != null) return error.InvalidMutationPlan;
                for (rows) |row| try self.schema.validateRow(row);
            },
            .update => |assignments| {
                if (assignments.len == 0 or assignments.len > self.schema.columns.len) return error.InvalidMutationColumns;
                try self.schema.validateAssignments(assignments);
            },
            .delete => {},
        }
        if (self.predicate) |program| {
            var fields: [s.max_columns]t.Field = undefined;
            try program.validateCollations(try self.schema.rowType(&fields), .fromTable(self.schema));
        }
    }
    /// Bind recovery to the complete typed intent, not data read during
    /// execution. Encoding workspace is bounded by one value or predicate atom.
    pub fn fingerprint(self: Plan, allocator: std.mem.Allocator) ![32]u8 {
        try self.validate();
        var intent: Intent = .{ .allocator = allocator };
        try intent.part("transit.table.dml.v1\x00");
        try intent.part(&try self.schema.fingerprint());
        switch (self.action) {
            .insert => |rows| {
                try intent.part(&.{1});
                try intent.number(u32, @intCast(rows.len));
                var fields: [s.max_columns]t.Field = undefined;
                var names: [s.max_columns][16]u8 = undefined;
                const field: t.Field = .{ .name = "row", .type = try self.schema.storageType(&fields, &names) };
                for (rows) |row| try intent.cell(field, .{ .value = .{ .structure = row } });
            },
            .update => |assignments| {
                try intent.part(&.{2});
                try intent.number(u16, @intCast(assignments.len));
                for (assignments) |assignment| {
                    try intent.number(u64, assignment.column);
                    switch (assignment.value) {
                        .default => try intent.part(&.{0}),
                        .cell => |cell| {
                            try intent.part(&.{1});
                            try intent.cell(self.schema.columns[try self.schema.index(assignment.column)].field(), cell);
                        },
                    }
                }
            },
            .delete => try intent.part(&.{3}),
        }
        try intent.part(&.{@intFromBool(self.predicate != null)});
        if (self.predicate) |program| {
            try intent.number(u16, @intCast(program.instructions.len));
            var fields: [s.max_columns]t.Field = undefined;
            const row_type = try self.schema.rowType(&fields);
            for (program.instructions) |instruction| switch (instruction) {
                .atom => |atom| {
                    try intent.part(&.{0});
                    var buffer: [8192]u8 = undefined;
                    var writer: std.Io.Writer = .fixed(&buffer);
                    try atom.write(row_type, &writer);
                    try intent.part(writer.buffered());
                },
                .negate => try intent.part(&.{1}),
                .conjunction => try intent.part(&.{2}),
                .disjunction => try intent.part(&.{3}),
            };
        }
        return intent.hash.finalResult();
    }
    /// Evaluate only against rows decoded with this exact bound schema. No
    /// source lookup or later schema/name rebinding is implicit.
    pub fn matches(self: Plan, row: []const Cell) !bool {
        try self.schema.validateRow(row);
        const program = self.predicate orelse return true;
        var fields: [s.max_columns]t.Field = undefined;
        return (try @import("PredicateMachine.zig").truth(program.instructions, Predicate.Row{ .schema = try self.schema.rowType(&fields), .cells = row, .collations = .fromTable(self.schema) })).selects();
    }
    /// Qualify only a conjunction of exactly one equality per declared key
    /// column. Extra conditions, duplicate atoms, OR and NOT keep scan semantics.
    pub fn primaryKeyEquality(self: Plan, output: *[s.max_columns]Cell) !?[]const Cell {
        try self.validate();
        if (self.schema.primary_key.len == 0 or self.action == .insert) return null;
        const program = self.predicate orelse return null;
        var seen: [s.max_columns]bool = @splat(false);
        var count: usize = 0;
        for (program.instructions) |instruction| switch (instruction) {
            .conjunction => {},
            .negate, .disjunction => return null,
            .atom => |atom| {
                if (atom != .compare or atom.compare.op != .eq) return null;
                const id = self.schema.columns[atom.compare.column].id;
                var key: ?usize = null;
                for (self.schema.primary_key, 0..) |column, i| if (column == id) {
                    key = i;
                    break;
                };
                const i = key orelse return null;
                if (seen[i]) return null;
                seen[i] = true;
                count += 1;
                output[i] = .{ .value = .{ .atom = atom.compare.value } };
            },
        };
        if (count != self.schema.primary_key.len) return null;
        const values = output[0..count];
        try self.schema.validateKey(values);
        return values;
    }
};
const Intent = struct {
    allocator: std.mem.Allocator,
    hash: std.crypto.hash.sha2.Sha256 = .init(.{}),
    bytes: usize = 0,
    fn part(self: *Intent, bytes: []const u8) !void {
        if (bytes.len > max_intent_bytes - 4 or self.bytes > max_intent_bytes - 4 - bytes.len) return error.MutationBatchTooLarge;
        self.bytes += 4 + bytes.len;
        var length: [4]u8 = undefined;
        std.mem.writeInt(u32, &length, @intCast(bytes.len), .little);
        self.hash.update(&length);
        self.hash.update(bytes);
    }
    fn number(self: *Intent, comptime T: type, value: T) !void {
        var bytes: [@sizeOf(T)]u8 = undefined;
        std.mem.writeInt(T, &bytes, value, .little);
        try self.part(&bytes);
    }
    fn cell(self: *Intent, field: t.Field, value: Cell) !void {
        var small: [4096]u8 = undefined;
        var large: ?[]u8 = null;
        defer if (large) |bytes| self.allocator.free(bytes);
        const bytes = t.Codec.encode(value, field, &small) catch |err| blk: {
            if (err != error.WriteFailed) return err;
            large = try self.allocator.alloc(u8, t.Codec.max_bytes);
            break :blk t.Codec.encode(value, field, large.?) catch |failure| return if (failure == error.WriteFailed) error.MutationBatchTooLarge else failure;
        };
        try self.part(bytes);
    }
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    schema: s.Owned,
    plan: Plan,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.schema.deinit();
        self.* = undefined;
    }
};
pub const Target = struct { kind: std.meta.Tag(Action), name: []const u8, span: Parser.Literal.Span };
fn header(parser: *Parser) !Target {
    const kind: std.meta.Tag(Action) = if (try parser.takeWord("INSERT")) blk: {
        try parser.requireWord("INTO");
        break :blk .insert;
    } else if (try parser.takeWord("UPDATE")) .update else if (try parser.takeWord("DELETE")) blk: {
        try parser.requireWord("FROM");
        break :blk .delete;
    } else return error.UnsupportedStatement;
    const source = try Reference.unqualified(parser, .source);
    return .{ .kind = kind, .name = source.name, .span = source.span };
}
/// Header inspection supplies a name for authorized resolution, not admission.
pub fn target(allocator: std.mem.Allocator, text: []const u8) !Target {
    return targetWithEditor(allocator, text, null);
}
pub fn targetWithEditor(allocator: std.mem.Allocator, text: []const u8, editor: ?*Parser.Editor) !Target {
    return targetContext(allocator, text, null, editor);
}
pub fn targetDiagnostic(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location) !Target {
    return targetContext(allocator, text, location, null);
}
pub fn targetDialect(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location, dialect: sql.Dialect) !Target {
    var parser = try Parser.initDialect(allocator, text, location, true, dialect);
    return header(&parser);
}
fn targetContext(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location, editor: ?*Parser.Editor) !Target {
    var parser = try Parser.init(allocator, text, location);
    parser.editor = editor;
    return header(&parser);
}
pub fn compile(allocator: std.mem.Allocator, text: []const u8, name: []const u8, basis: s.Schema, location: ?*sql.Location) !Owned {
    return compileWithEditor(allocator, text, name, basis, location, null);
}
pub fn compileWithEditor(allocator: std.mem.Allocator, text: []const u8, name: []const u8, basis: s.Schema, location: ?*sql.Location, editor: ?*Parser.Editor) !Owned {
    var schema = try basis.clone(allocator);
    errdefer schema.deinit();
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    var parser = try Parser.init(arena.allocator(), text, location);
    parser.editor = editor;
    const input = try syntax(&parser, schema.schema);
    try parser.finish();
    const plan = try input.bind(arena.allocator(), name, schema.schema, location);
    return .{ .arena = arena, .schema = schema, .plan = plan };
}
const Value = struct {
    span: Parser.Literal.Span,
    literal: ?Parser.Literal,
    parameter: ?sql.Parameter = null,
    fn parse(parser: *Parser, expected: ?t.Type) !Value {
        const start = parser.lexer.start;
        if (try parser.takeWord("DEFAULT")) return .{ .span = .{ .start = start, .end = parser.previous_end }, .literal = null };
        if (try parser.parameter()) |site| return .{ .span = .{ .start = start, .end = parser.previous_end }, .literal = null, .parameter = site };
        const value = try parser.literal(expected);
        return .{ .span = value.span, .literal = value };
    }
    fn bind(self: Value, allocator: std.mem.Allocator, column: s.Column, location: ?*sql.Location, parameters: ?[]const ?t.Values.Atom) !s.Assignment {
        var failure: ?Parser.Literal.Span = null;
        const cell: @FieldType(s.Assignment, "value") = if (self.parameter) |site| .{ .cell = if (try SqlPredicate.parameterValue(site, parameters, column.type, location)) |atom| .{ .value = .{ .atom = try t.Values.cloneAtom(allocator, atom) } } else .null } else if (self.literal) |literal| .{ .cell = literal.bind(allocator, column.type, &failure) catch |err| {
            if (location) |at| at.* = .{ .offset = (failure orelse self.span).start };
            return err;
        } } else .default;
        column.validateCell(switch (cell) {
            .default => column.initial(),
            .cell => |value| value,
        }) catch |err| {
            if (location) |at| at.* = .{ .offset = self.span.start };
            return err;
        };
        return .{ .column = column.id, .value = cell };
    }
};
const Row = struct { span: Parser.Literal.Span, values: []const Value };
const Assignment = struct { column: Reference, value: Value };
pub const Syntax = struct {
    subject: Target,
    subject_span: Parser.Literal.Span,
    action: union(enum) { insert: struct { columns: ?[]const Reference, rows: []const Row }, update: []const Assignment, delete },
    predicate: ?SqlPredicate.Syntax = null,
    pub fn bind(self: Syntax, allocator: std.mem.Allocator, name: []const u8, schema: s.Schema, location: ?*sql.Location) !Plan {
        return self.bindParameters(allocator, name, schema, location, null);
    }
    pub fn bindParameters(self: Syntax, allocator: std.mem.Allocator, name: []const u8, schema: s.Schema, location: ?*sql.Location, parameters: ?[]const ?t.Values.Atom) !Plan {
        try schema.validate();
        if (!std.mem.eql(u8, self.subject.name, name)) {
            if (location) |at| at.* = .{ .offset = self.subject_span.start };
            return error.UnknownSource;
        }
        var plan: Plan = .{ .name = self.subject.name, .schema = schema, .action = undefined };
        plan.action = switch (self.action) {
            .insert => |input| blk: {
                var columns: [s.max_columns]usize = undefined;
                const count = if (input.columns) |selected| selected.len else schema.columns.len;
                if (count > columns.len) return error.InvalidMutationColumns;
                for (columns[0..count], 0..) |*column, i| {
                    column.* = if (input.columns) |selected| try selected[i].resolve(name, schema.columns, location) else i;
                    for (columns[0..i]) |prior| if (prior == column.*) {
                        if (location) |at| at.* = .{ .offset = input.columns.?[i].span.start };
                        return error.DuplicateAssignment;
                    };
                }
                if (input.rows.len == 0 or input.rows.len > max_rows) return error.MutationBatchTooLarge;
                const rows = try allocator.alloc([]const Cell, input.rows.len);
                for (input.rows, rows) |row, *output| {
                    if (location) |at| at.* = .{ .offset = row.span.start };
                    if (row.values.len != count) return error.InvalidRowWidth;
                    var assignments: [s.max_columns]s.Assignment = undefined;
                    for (row.values, columns[0..count], 0..) |value, index, i| assignments[i] = try value.bind(allocator, schema.columns[index], location, parameters);
                    const cells = try allocator.alloc(Cell, schema.columns.len);
                    _ = try schema.insert(assignments[0..count], cells);
                    output.* = cells;
                }
                break :blk .{ .insert = rows };
            },
            .update => |input| blk: {
                if (input.len == 0 or input.len > s.max_columns) return error.InvalidMutationColumns;
                const assignments = try allocator.alloc(s.Assignment, input.len);
                var seen: [s.max_columns]bool = @splat(false);
                for (input, assignments) |assignment, *output| {
                    const index = try assignment.column.resolve(name, schema.columns, location);
                    if (seen[index]) {
                        if (location) |at| at.* = .{ .offset = assignment.column.span.start };
                        return error.DuplicateAssignment;
                    }
                    seen[index] = true;
                    output.* = try assignment.value.bind(allocator, schema.columns[index], location, parameters);
                }
                break :blk .{ .update = assignments };
            },
            .delete => .delete,
        };
        if (self.predicate) |predicate| {
            var fields: [s.max_columns]t.Field = undefined;
            plan.predicate = try predicate.bindParameters(allocator, try schema.rowType(&fields), name, location, parameters);
        }
        try plan.validate();
        return plan;
    }
};
/// Parse production DML without inventing a schema. Optional metadata affects
/// cursor suggestions only; all admission and identity binding happens in bind.
pub fn syntax(parser: *Parser, hints: ?s.Schema) !Syntax {
    const subject = try header(parser);
    const subject_span = subject.span;
    var result: Syntax = .{ .subject = subject, .subject_span = subject_span, .action = undefined };
    result.action = switch (subject.kind) {
        .insert => .{ .insert = try insert(parser, hints) },
        .update => .{ .update = try update(parser, hints, subject.name) },
        .delete => .delete,
    };
    if (subject.kind != .insert and try parser.takeWord("WHERE")) {
        var fields: [s.max_columns]t.Field = undefined;
        result.predicate = try SqlPredicate.syntax(parser, if (hints) |schema| try schema.rowType(&fields) else null, subject.name, error.UnsupportedMutationPredicate);
    }
    return result;
}
fn insert(parser: *Parser, hints: ?s.Schema) !@FieldType(@FieldType(Syntax, "action"), "insert") {
    var rows: std.ArrayList(Row) = .empty;
    const start = parser.lexer.start;
    if (try parser.takeWord("DEFAULT")) {
        try parser.requireWord("VALUES");
        const row = try parser.allocator.alloc(Row, 1);
        row[0] = .{ .span = .{ .start = start, .end = parser.previous_end }, .values = &.{} };
        return .{ .columns = &.{}, .rows = row };
    }
    var columns: ?[]const Reference = null;
    if (try parser.take(.left)) {
        var selected: std.ArrayList(Reference) = .empty;
        while (true) {
            if (selected.items.len == s.max_columns) return error.InvalidMutationColumns;
            try selected.append(parser.allocator, try Reference.unqualified(parser, .column));
            if (!try parser.take(.comma)) break;
        }
        try parser.require(.right);
        columns = try selected.toOwnedSlice(parser.allocator);
    }
    try parser.requireWord("VALUES");
    while (true) {
        if (rows.items.len == max_rows) return error.MutationBatchTooLarge;
        const row_start = parser.lexer.start;
        try parser.require(.left);
        var values: std.ArrayList(Value) = .empty;
        while (true) {
            if (values.items.len == s.max_columns) return error.InvalidMutationColumns;
            var expected: ?t.Type = null;
            if (hints) |schema| {
                const ordinal = values.items.len;
                const index = if (columns) |selected| (if (ordinal < selected.len) selected[ordinal].resolve("", schema.columns, null) catch null else null) else if (ordinal < schema.columns.len) ordinal else null;
                if (index) |i| expected = schema.columns[i].type;
            }
            try values.append(parser.allocator, try Value.parse(parser, expected));
            if (!try parser.take(.comma)) break;
        }
        try parser.require(.right);
        try rows.append(parser.allocator, .{ .span = .{ .start = row_start, .end = parser.previous_end }, .values = try values.toOwnedSlice(parser.allocator) });
        if (!try parser.take(.comma)) break;
    }
    return .{ .columns = columns, .rows = try rows.toOwnedSlice(parser.allocator) };
}
fn update(parser: *Parser, hints: ?s.Schema, name: []const u8) ![]const Assignment {
    try parser.requireWord("SET");
    var assignments: std.ArrayList(Assignment) = .empty;
    while (true) {
        if (assignments.items.len == s.max_columns) return error.InvalidMutationColumns;
        const column = try Reference.parse(parser);
        try parser.require(.eq);
        var expected: ?t.Type = null;
        if (hints) |schema| if (column.resolve(name, schema.columns, null)) |index| {
            expected = schema.columns[index].type;
        } else |_| {};
        try assignments.append(parser.allocator, .{ .column = column, .value = try Value.parse(parser, expected) });
        if (!try parser.take(.comma)) break;
    }
    return assignments.toOwnedSlice(parser.allocator);
}

test {
    _ = @import("table_dml_test.zig");
}
