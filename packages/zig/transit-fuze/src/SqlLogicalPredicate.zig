//! Typed predicate lowering shared by Table SELECT, UPDATE and DELETE.
const std = @import("std");
const Parser = @import("SqlTyped.zig");
const t = @import("Types.zig");
const Predicate = @import("LogicalPredicate.zig");
const Reference = @import("SqlReference.zig");
const sql = @import("Sql.zig");
pub const Syntax = struct {
    const Atom = union(enum) {
        state: struct { column: Reference, value: t.State },
        compare: struct { column: Reference, op: @import("Finite.zig").Comparison, value: union(enum) { literal: Parser.Literal, parameter: sql.Parameter } },
    };
    const Instruction = @import("PredicateMachine.zig").Instruction(Atom);
    instructions: []const Instruction,
    pub fn bind(self: Syntax, allocator: std.mem.Allocator, schema: t.Type, name: []const u8, location: ?*sql.Location) !Predicate.Program {
        return self.bindParameters(allocator, schema, name, location, null);
    }
    pub fn bindParameters(self: Syntax, allocator: std.mem.Allocator, schema: t.Type, name: []const u8, location: ?*sql.Location, parameters: ?[]const ?t.Values.Atom) !Predicate.Program {
        return self.bindParametersDiagnostic(allocator, schema, name, location, parameters, null);
    }
    pub fn bindParametersDiagnostic(self: Syntax, allocator: std.mem.Allocator, schema: t.Type, name: []const u8, location: ?*sql.Location, parameters: ?[]const ?t.Values.Atom, diagnostic: ?*sql.Binding) !Predicate.Program {
        if (schema != .structure or schema.structure.len == 0 or schema.structure.len > 128) return error.InvalidQuerySchema;
        if (self.instructions.len > Predicate.Program.max_instructions) return error.PredicateTooComplex;
        const instructions = try allocator.alloc(Predicate.Program.Instruction, self.instructions.len);
        for (self.instructions, instructions) |input, *output| {
            output.* = switch (input) {
                .conjunction => .conjunction,
                .disjunction => .disjunction,
                .negate => .negate,
                .atom => |atom| .{ .atom = switch (atom) {
                    .state => |state| .{ .state = .{ .column = @intCast(try state.column.resolve(name, schema.structure, location)), .value = state.value } },
                    .compare => |compare| blk: {
                        const index = try compare.column.resolve(name, schema.structure, location);
                        const value: ?t.Values.Atom = switch (compare.value) {
                            .parameter => |site| try parameterValue(site, parameters, schema.structure[index].type, location),
                            .literal => |literal| literal_blk: {
                                var failure: ?Parser.Literal.Span = null;
                                const cell = literal.bind(allocator, schema.structure[index].type, &failure) catch |err| {
                                    const offset = (failure orelse literal.span).start;
                                    if (location) |at| at.* = .{ .offset = offset };
                                    if (diagnostic) |detail| {
                                        detail.subject = sql.Binding.Name.init(schema.structure[index].name) catch null;
                                        detail.location = .{ .offset = offset };
                                        detail.scope_len = @min(name.len, detail.scope.len);
                                        @memcpy(detail.scope[0..detail.scope_len], name[0..detail.scope_len]);
                                        detail.expected = @tagName(schema.structure[index].type);
                                        detail.actual = if (literal.value == .string) "utf8" else @tagName(literal.value);
                                        switch (literal.value) {
                                            .string => |text| sql.Binding.supplied(detail, @import("Scalar.zig").Scalar{ .utf8 = text }),
                                            .boolean => |boolean| sql.Binding.supplied(detail, @import("Scalar.zig").Scalar{ .boolean = boolean }),
                                            else => detail.actual = @tagName(literal.value),
                                        }
                                    }
                                    if ((err == error.InvalidSqlSyntax or err == error.InvalidLiteral) and !literalShape(literal, schema.structure[index].type)) return error.TypeMismatch;
                                    return err;
                                };
                                if (location) |at| at.* = .{ .offset = literal.span.start };
                                if (cell == .null) return error.UnsupportedNullComparison;
                                if (cell != .value or cell.value != .atom) return error.UnsupportedComparison;
                                break :literal_blk cell.value.atom;
                            },
                        };
                        const bound: Predicate.Atom = if (value) |scalar| .{ .compare = .{ .column = @intCast(index), .op = compare.op, .value = scalar } } else .{ .null_compare = .{ .column = @intCast(index), .op = compare.op } };
                        try bound.validate(schema);
                        break :blk bound;
                    },
                } },
            };
        }
        const result: Predicate.Program = .{ .instructions = instructions };
        try result.validate(schema);
        return result;
    }
};
// Only classify a mismatch at the literal root. Range, malformed scalar text
// and nested-child failures retain their original causes and source spans.
fn literalShape(literal: Parser.Literal, expected: t.Type) bool {
    if (literal.value == .null or literal.value == .missing) return true;
    return switch (expected) {
        .int8, .int16, .int32, .int64, .int128, .uint8, .uint16, .uint32, .uint64, .uint128, .float32, .float64, .decimal => literal.value == .number,
        .utf8 => literal.value == .string,
        .boolean => literal.value == .boolean,
        .binary => literal.value == .binary,
        .date => literal.value == .date or literal.value == .string,
        .time => literal.value == .time or literal.value == .string,
        .timestamp => literal.value == .timestamp or literal.value == .string,
        .uuid => literal.value == .uuid or literal.value == .string,
        .json => literal.value == .json or literal.value == .string,
        .structure => literal.value == .structure,
        .list => literal.value == .list,
        .array => literal.value == .array,
        .map => literal.value == .map,
        .tagged_union => literal.value == .tagged_union,
        .interval => literal.value == .interval,
        .range, .multirange, .vector => literal.value == .string,
    };
}
/// The exact expected descriptor controls parameter width and representation.
/// No literal parse, implicit cast or source error/conflict state is introduced.
pub fn validateParameter(value: t.Values.Atom, expected: t.Type) !void {
    if (value == .bytes and value.bytes.len > t.Query.max_cell_bytes) return error.CellTooLarge;
    try expected.validate(.{});
    try t.Semantics.validate(value, expected);
}
pub fn parameterValue(site: sql.Parameter, parameters: ?[]const ?t.Values.Atom, expected: t.Type, location: ?*sql.Location) !?t.Values.Atom {
    if (location) |at| at.* = .{ .offset = site.offset };
    if (site.index == 0) return error.InvalidParameterIndex;
    const values = parameters orelse return error.UnboundParameters;
    if (site.index > values.len) return error.ParameterCountMismatch;
    const value = values[site.index - 1];
    if (value) |atom| try validateParameter(atom, expected);
    return value;
}
pub fn syntax(parser: *Parser, hints: ?t.Type, name: []const u8, unsupported: anyerror) !Syntax {
    return syntaxWithLookup(parser, hints, name, unsupported, null);
}
/// Editor-only type lookup over the caller's authorized declarations. Parsing
/// and later binding keep their ordinary ownership and acceptance semantics.
pub const Lookup = struct {
    context: ?*const anyopaque,
    resolve: *const fn (?*const anyopaque, Reference) ?t.Type,
};
pub fn syntaxWithLookup(parser: *Parser, hints: ?t.Type, name: []const u8, unsupported: anyerror, lookup: ?Lookup) !Syntax {
    var expression: Expression = .{ .parser = parser, .hints = hints, .name = name, .unsupported = unsupported, .lookup = lookup };
    try expression.parse();
    return .{ .instructions = try parser.allocator.dupe(Syntax.Instruction, expression.instructions[0..expression.count]) };
}
pub fn parse(parser: *Parser, schema: t.Type, name: []const u8, unsupported: anyerror) !Predicate.Program {
    return (try syntax(parser, schema, name, unsupported)).bind(parser.allocator, schema, name, parser.location);
}
const Expression = struct {
    const Operator = enum { group, disjunction, conjunction, negate };
    parser: *Parser,
    hints: ?t.Type,
    name: []const u8,
    lookup: ?Lookup,
    instructions: [Predicate.Program.max_instructions]Syntax.Instruction = undefined,
    count: usize = 0,
    operators: [Predicate.Program.max_instructions]Operator = undefined,
    pending: usize = 0,
    unsupported: anyerror,
    fn append(self: *Expression, instruction: Syntax.Instruction) !void {
        if (self.count == self.instructions.len) return error.PredicateTooComplex;
        self.instructions[self.count] = instruction;
        self.count += 1;
    }
    fn push(self: *Expression, operator: Operator) !void {
        if (self.pending == self.operators.len) return error.PredicateTooDeep;
        self.operators[self.pending] = operator;
        self.pending += 1;
    }
    fn emit(self: *Expression) !void {
        self.pending -= 1;
        try self.append(switch (self.operators[self.pending]) {
            .group => unreachable,
            .disjunction => .disjunction,
            .conjunction => .conjunction,
            .negate => .negate,
        });
    }
    fn parse(self: *Expression) !void {
        var operand = true;
        var groups: usize = 0;
        while (true) {
            if (operand) {
                if (try self.parser.takeWord("NOT")) {
                    try self.push(.negate);
                    continue;
                }
                if (try self.parser.take(.left)) {
                    try self.push(.group);
                    groups += 1;
                    continue;
                }
                try self.atom();
                operand = false;
                continue;
            }
            const operator: ?Operator = if (try self.parser.takeWord("AND")) .conjunction else if (try self.parser.takeWord("OR")) .disjunction else null;
            if (operator) |next| {
                while (self.pending > 0 and @backingInt(self.operators[self.pending - 1]) >= @backingInt(next)) try self.emit();
                try self.push(next);
                operand = true;
                continue;
            }
            if (groups > 0) {
                try self.parser.require(.right);
                while (self.operators[self.pending - 1] != .group) try self.emit();
                self.pending -= 1;
                groups -= 1;
                continue;
            }
            while (self.pending > 0) try self.emit();
            return;
        }
    }
    fn atom(self: *Expression) !void {
        const column = try Reference.parse(self.parser);
        var expected: ?t.Type = null;
        if (self.hints) |schema| if (schema == .structure) {
            if (column.resolve(self.name, schema.structure, null)) |index| expected = schema.structure[index].type else |_| {}
        };
        if (self.parser.editor != null) if (self.lookup) |lookup| {
            expected = lookup.resolve(lookup.context, column);
        };
        // Parser acceptance remains independent of binding. Editor guidance is
        // scoped to the supplied schema, including a bare qualifier/column
        // collision, and must not offer operators on an unresolved reference.
        if (self.parser.editor != null) {
            if (self.parser.boundary()) |editor| {
                const qualifier = column.qualifier == null and std.mem.eql(u8, column.name, self.name);
                editor.* = .{};
                if (qualifier) editor.symbol(.dot);
                if (expected == null) return error.UnknownColumn;
            } else if (expected == null) {
                self.parser.editor.?.* = .{};
                return error.UnknownColumn;
            }
        }
        if (try self.parser.takeWord("IS")) {
            const negate = try self.parser.takeWord("NOT");
            const state: t.State = if (try self.parser.takeWord("NULL")) .null else if (try self.parser.takeWord("MISSING")) .missing else if (try self.parser.takeWord("TYPE_ERROR")) .type_error else if (try self.parser.takeWord("VALUE")) .value else if (try self.parser.takeWord("CONFLICT")) .conflict else return error.InvalidSqlSyntax;
            try self.append(.{ .atom = .{ .state = .{ .column = column, .value = state } } });
            if (negate) try self.append(.negate);
            return;
        }
        if (self.parser.boundary()) |editor| {
            const comparison = if (expected) |kind| switch (kind) {
                .interval, .structure, .list, .array, .map, .tagged_union, .json => false,
                else => true,
            } else false;
            if (comparison) for ([_]@import("Sql.zig").Tag{ .eq, .ne, .lt, .le, .gt, .ge }) |tag| editor.symbol(tag);
        }
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
        const value: @FieldType(@FieldType(Syntax.Atom, "compare"), "value") = if (try self.parser.parameter()) |site| .{ .parameter = site } else .{ .literal = try self.parser.literal(expected) };
        try self.append(.{ .atom = .{ .compare = .{ .column = column, .op = op, .value = value } } });
    }
};
