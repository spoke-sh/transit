//! Typed predicate lowering shared by Table SELECT, UPDATE and DELETE.
const std = @import("std");
const Parser = @import("SqlTyped.zig");
const t = @import("Types.zig");
const Predicate = @import("LogicalPredicate.zig");
pub fn parse(parser: *Parser, schema: t.Type, name: []const u8, unsupported: anyerror) !Predicate.Program {
    if (schema != .structure or schema.structure.len == 0 or schema.structure.len > 128) return error.InvalidQuerySchema;
    var expression: Expression = .{ .parser = parser, .schema = schema, .name = name, .unsupported = unsupported };
    try expression.disjunction(0);
    const result: Predicate.Program = .{ .instructions = try parser.allocator.dupe(Predicate.Program.Instruction, expression.instructions[0..expression.count]) };
    try result.validate(schema);
    return result;
}
pub fn columnIndex(parser: *Parser, schema: t.Type, name: []const u8) !usize {
    var column = try parser.named(.column);
    if (try parser.take(.dot)) {
        if (!std.mem.eql(u8, column, name)) return error.UnknownQualifier;
        if (parser.boundary()) |editor| editor.qualifier = .init(column);
        column = try parser.named(.column);
    }
    for (schema.structure, 0..) |field, i| if (std.mem.eql(u8, field.name, column)) return i;
    return error.UnknownColumn;
}
const Expression = struct {
    parser: *Parser,
    schema: t.Type,
    name: []const u8,
    instructions: [Predicate.Program.max_instructions]Predicate.Program.Instruction = undefined,
    count: usize = 0,
    unsupported: anyerror,
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
        if (self.parser.boundary()) |editor| for ([_]@import("Sql.zig").Tag{ .eq, .ne, .lt, .le, .gt, .ge }) |tag| editor.symbol(tag);
        const op: @import("Finite.zig").Comparison = switch (self.parser.token.tag) {
            .eq => .eq,
            .ne => .ne,
            .lt => .lt,
            .le => .le,
            .gt => .gt,
            .ge => .ge,
            else => return self.unsupported,
        };
        try self.parser.advance();
        const cell = try self.parser.value(self.schema.structure[index].type);
        if (cell == .null) return error.UnsupportedNullComparison;
        if (cell != .value or cell.value != .atom) return error.UnsupportedComparison;
        try self.append(.{ .atom = .{ .compare = .{ .column = @intCast(index), .op = op, .value = cell.value.atom } } });
    }
};
