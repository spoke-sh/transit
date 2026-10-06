//! General typed Table DML compilation. The owner freezes selection and accepts
//! one complete successor; this model never publishes individual SQL row prefixes.
const std = @import("std");
const sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
const s = @import("TableSchema.zig");
const t = @import("Types.zig");
const Predicate = @import("LogicalPredicate.zig");
const Cell = t.Values.Cell;
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
            try program.validate(try self.schema.rowType(&fields));
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
        return (try program.truth(try self.schema.rowType(&fields), row)).selects();
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
            break :blk try t.Codec.encode(value, field, large.?);
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
pub const Target = struct { kind: std.meta.Tag(Action), name: []const u8 };
fn header(parser: *Parser) !Target {
    const kind: std.meta.Tag(Action) = if (try parser.takeWord("INSERT")) blk: {
        try parser.requireWord("INTO");
        break :blk .insert;
    } else if (try parser.takeWord("UPDATE")) .update else if (try parser.takeWord("DELETE")) blk: {
        try parser.requireWord("FROM");
        break :blk .delete;
    } else return error.UnsupportedStatement;
    return .{ .kind = kind, .name = try parser.name() };
}
/// Header inspection supplies a name for authorized resolution, not admission.
pub fn target(allocator: std.mem.Allocator, text: []const u8) !Target {
    var parser = try Parser.init(allocator, text, null);
    return header(&parser);
}
pub fn compile(allocator: std.mem.Allocator, text: []const u8, name: []const u8, basis: s.Schema, location: ?*sql.Location) !Owned {
    var schema = try basis.clone(allocator);
    errdefer schema.deinit();
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    var parser = try Parser.init(arena.allocator(), text, location);
    const subject = try header(&parser);
    if (!std.mem.eql(u8, subject.name, name)) return error.UnknownSource;
    var plan: Plan = .{ .name = subject.name, .schema = schema.schema, .action = undefined };
    plan.action = switch (subject.kind) {
        .insert => .{ .insert = try insert(&parser, schema.schema) },
        .update => .{ .update = try update(&parser, schema.schema, name) },
        .delete => .delete,
    };
    if (subject.kind != .insert and try parser.takeWord("WHERE")) {
        var program: Expression = .{ .parser = &parser, .schema = schema.schema, .name = name };
        try program.disjunction(0);
        plan.predicate = .{ .instructions = try parser.allocator.dupe(Predicate.Program.Instruction, program.instructions[0..program.count]) };
    }
    try parser.finish();
    try plan.validate();
    return .{ .arena = arena, .schema = schema, .plan = plan };
}
fn parseAssignment(parser: *Parser, column: s.Column) !s.Assignment {
    return .{ .column = column.id, .value = if (try parser.takeWord("DEFAULT")) .default else .{ .cell = try parser.value(column.type) } };
}
fn insert(parser: *Parser, schema: s.Schema) ![]const []const Cell {
    var rows: std.ArrayList([]const Cell) = .empty;
    if (try parser.takeWord("DEFAULT")) {
        try parser.requireWord("VALUES");
        const row = try parser.allocator.alloc(Cell, schema.columns.len);
        _ = try schema.insert(&.{}, row);
        try rows.append(parser.allocator, row);
        return rows.toOwnedSlice(parser.allocator);
    }
    var columns: [s.max_columns]usize = undefined;
    var count: usize = 0;
    if (try parser.take(.left)) {
        while (true) {
            if (count == columns.len) return error.InvalidMutationColumns;
            const index = try schema.named(try parser.name());
            for (columns[0..count]) |prior| if (prior == index) return error.DuplicateAssignment;
            columns[count] = index;
            count += 1;
            if (!try parser.take(.comma)) break;
        }
        try parser.require(.right);
    } else {
        count = schema.columns.len;
        for (columns[0..count], 0..) |*column, i| column.* = i;
    }
    try parser.requireWord("VALUES");
    while (true) {
        if (rows.items.len == max_rows) return error.MutationBatchTooLarge;
        try parser.require(.left);
        var assignments: [s.max_columns]s.Assignment = undefined;
        for (columns[0..count], 0..) |column, i| {
            if (i != 0) try parser.require(.comma);
            assignments[i] = try parseAssignment(parser, schema.columns[column]);
        }
        try parser.require(.right);
        const row = try parser.allocator.alloc(Cell, schema.columns.len);
        _ = try schema.insert(assignments[0..count], row);
        try rows.append(parser.allocator, row);
        if (!try parser.take(.comma)) break;
    }
    return rows.toOwnedSlice(parser.allocator);
}
fn columnIndex(parser: *Parser, schema: s.Schema, name: []const u8) !usize {
    var column = try parser.name();
    if (try parser.take(.dot)) {
        if (!std.mem.eql(u8, column, name)) return error.UnknownQualifier;
        column = try parser.name();
    }
    return schema.named(column);
}
fn update(parser: *Parser, schema: s.Schema, name: []const u8) ![]const s.Assignment {
    try parser.requireWord("SET");
    var assignments: std.ArrayList(s.Assignment) = .empty;
    while (true) {
        if (assignments.items.len == schema.columns.len) return error.InvalidMutationColumns;
        const i = try columnIndex(parser, schema, name);
        try parser.require(.eq);
        try assignments.append(parser.allocator, try parseAssignment(parser, schema.columns[i]));
        if (!try parser.take(.comma)) break;
    }
    return assignments.toOwnedSlice(parser.allocator);
}
const Expression = struct {
    parser: *Parser,
    schema: s.Schema,
    name: []const u8,
    instructions: [Predicate.Program.max_instructions]Predicate.Program.Instruction = undefined,
    count: usize = 0,
    fn append(self: *Expression, instruction: Predicate.Program.Instruction) !void {
        if (self.count == self.instructions.len) return error.PredicateTooComplex;
        self.instructions[self.count] = instruction;
        self.count += 1;
    }
    fn disjunction(self: *Expression, depth: usize) anyerror!void {
        if (depth == 16) return error.PredicateTooDeep;
        try self.conjunction(depth);
        while (try self.parser.takeWord("OR")) {
            try self.conjunction(depth);
            try self.append(.disjunction);
        }
    }
    fn conjunction(self: *Expression, depth: usize) anyerror!void {
        try self.unary(depth);
        while (try self.parser.takeWord("AND")) {
            try self.unary(depth);
            try self.append(.conjunction);
        }
    }
    fn unary(self: *Expression, depth: usize) anyerror!void {
        if (depth == 16) return error.PredicateTooDeep;
        if (try self.parser.takeWord("NOT")) {
            try self.unary(depth + 1);
            return self.append(.negate);
        }
        if (try self.parser.take(.left)) {
            try self.disjunction(depth + 1);
            return self.parser.require(.right);
        }
        const index = try columnIndex(self.parser, self.schema, self.name);
        if (try self.parser.takeWord("IS")) {
            const negate = try self.parser.takeWord("NOT");
            const state: t.State = if (try self.parser.takeWord("NULL")) .null else if (try self.parser.takeWord("MISSING")) .missing else if (try self.parser.takeWord("ERROR")) .type_error else if (try self.parser.takeWord("CONFLICT")) .conflict else return error.InvalidSqlSyntax;
            try self.append(.{ .atom = .{ .state = .{ .column = @intCast(index), .value = state } } });
            if (negate) try self.append(.negate);
            return;
        }
        const op: @import("Finite.zig").Comparison = switch (self.parser.token.tag) {
            .eq => .eq,
            .ne => .ne,
            .lt => .lt,
            .le => .le,
            .gt => .gt,
            .ge => .ge,
            else => return error.UnsupportedMutationPredicate,
        };
        try self.parser.advance();
        const cell = try self.parser.value(self.schema.columns[index].type);
        if (cell == .null) return error.UnsupportedNullComparison;
        if (cell != .value or cell.value != .atom) return error.UnsupportedComparison;
        try self.append(.{ .atom = .{ .compare = .{ .column = @intCast(index), .op = op, .value = cell.value.atom } } });
    }
};

test {
    _ = @import("table_dml_test.zig");
}
