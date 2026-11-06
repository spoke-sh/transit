//! Relational SELECT lowering through the shared SQL lexer, names, literals and
//! predicate grammar. Binding consumes explicitly acquired Table declarations.
const std = @import("std");
const r = @import("Relational.zig");
const sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
pub const Reference = @import("SqlReference.zig");
const Predicate = @import("SqlLogicalPredicate.zig");
const types = @import("Types.zig");
const Scalar = @import("SqlScalar.zig");
const Values = @import("RelationalValues.zig");
pub const Parameters = struct {
    pub const max = 128;
    types: [max]types.Type = undefined,
    sites: [max]?sql.Parameter = @splat(null),
    count: u8 = 0,
    pub fn slice(self: *const Parameters) []const types.Type {
        return self.types[0..self.count];
    }
    fn operand(self: *Parameters, site: sql.Parameter, kind: types.Type, values: ?[]const ?types.Values.Atom, location: ?*sql.Location) !?types.Values.Atom {
        if (location) |at| at.* = .{ .offset = site.offset };
        if (site.index == 0 or site.index > max) return error.InvalidParameterIndex;
        const index = site.index - 1;
        if (self.sites[index] != null and !try self.types[index].eql(kind)) return error.ParameterTypeConflict;
        self.sites[index] = site;
        self.types[index] = kind;
        self.count = @max(self.count, @as(u8, @intCast(site.index)));
        const supplied = values orelse return try @import("LogicalPrepared.zig").witness(kind);
        if (index >= supplied.len) return error.ParameterCountMismatch;
        const value = supplied[index] orelse return null;
        try @import("LogicalPrepared.zig").validate(value, kind);
        return value;
    }
    fn finish(self: *const Parameters, values: ?[]const ?types.Values.Atom) !void {
        for (self.sites[0..self.count]) |site| if (site == null) return error.ParameterGap;
        if (values) |supplied| if (supplied.len != self.count) return error.ParameterCountMismatch;
    }
};
pub const Target = struct { name: []const u8, alias: []const u8 };
/// Classifies syntax before any source is opened. This is routing, not parsing
/// acceptance: malformed/unsupported relational input still goes to parse.
pub fn required(text: []const u8) !bool {
    return requiredDialect(text, .transit);
}
pub fn requiredDialect(text: []const u8, dialect: sql.Dialect) !bool {
    try sql.validateText(text);
    var lexer: sql.Lexer = .{ .text = text, .dialect = dialect, .parameters_enabled = true };
    var selection = true;
    var aggregate = false;
    var comma = false;
    var depth: usize = 0;
    var source: enum { none, target, tail, alias, done } = .none;
    while (true) {
        const token = try lexer.next();
        if (token.tag == .eof) return aggregate and comma;
        if (token.tag == .left) depth += 1;
        if (token.tag == .right and depth != 0) depth -= 1;
        if (selection and token.tag == .comma and depth == 0) comma = true;
        if (token.tag != .word) {
            if (source == .target or source == .alias) source = if (token.tag == .quoted) .tail else .done;
            continue;
        }
        if (depth == 0) {
            if (selection and std.ascii.eqlIgnoreCase(token.text, "FROM")) {
                selection = false;
                source = .target;
                continue;
            }
            if (source == .target or source == .alias) {
                source = .tail;
                continue;
            }
            if (source == .tail) {
                if (std.ascii.eqlIgnoreCase(token.text, "AS")) {
                    source = .alias;
                    continue;
                }
                for ([_][]const u8{ "JOIN", "INNER", "LEFT", "RIGHT", "FULL", "CROSS", "NATURAL" }) |word| if (std.ascii.eqlIgnoreCase(token.text, word)) return true;
                if (std.ascii.eqlIgnoreCase(token.text, "WHERE") or std.ascii.eqlIgnoreCase(token.text, "LIMIT")) source = .done;
            }
            if (!selection and (std.ascii.eqlIgnoreCase(token.text, "GROUP") or std.ascii.eqlIgnoreCase(token.text, "ORDER"))) {
                var lookahead = lexer;
                const next = try lookahead.next();
                if (next.tag == .word and std.ascii.eqlIgnoreCase(next.text, "BY")) return true;
            }
            if (!selection and std.ascii.eqlIgnoreCase(token.text, "HAVING")) {
                var lookahead = lexer;
                const next = try lookahead.next();
                if (next.tag == .word or next.tag == .quoted or next.tag == .left) return true;
            }
        }
        if (selection and (std.ascii.eqlIgnoreCase(token.text, "COUNT") or std.ascii.eqlIgnoreCase(token.text, "SUM")) and (try lexer.peek()).tag == .left) aggregate = true;
    }
}
const ScalarExpression = struct { syntax: Scalar.Syntax, name: []const u8 };
pub const Expression = union(enum) { column: Reference, count_all, count: Reference, sum: Reference, scalar: ScalarExpression, sum_scalar: ScalarExpression, count_scalar: ScalarExpression };
const Selection = struct {
    expression: Expression,
    name: []const u8,
    explicit_alias: bool = false,
};
pub const HavingAtom = union(enum) {
    state: struct { expression: Expression, value: @import("Types.zig").State },
    compare: struct { expression: Expression, op: @import("Finite.zig").Comparison, value: union(enum) { literal: Parser.Literal, parameter: sql.Parameter } },
};
pub const HavingInstruction = @import("PredicateMachine.zig").Instruction(HavingAtom);
pub const OrderBy = struct {
    expression: Expression,
    direction: r.Direction = .asc,
    nulls: r.NullOrder = .first,
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    targets: []const Target,
    selections: []const Selection,
    star: bool = false,
    join: ?struct { kind: @FieldType(r.Join, "kind"), left: Reference, right: Reference },
    predicate: ?Predicate.Syntax,
    groups: []const Reference,
    having: []const HavingInstruction = &.{},
    order_by: []const OrderBy = &.{},
    limit: ?u64 = null,
    limit_parameter: ?sql.Parameter = null,

    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
    /// Returned plan borrows this syntax owner and the supplied immutable source
    /// descriptors. The caller must have resolved targets in their listed order.
    pub fn bind(self: *Owned, sources: []const r.Source, lifetime: r.Lifetime, budgets: r.Budgets, location: ?*sql.Location) !r.Plan {
        var parameters: Parameters = .{};
        return self.bindParameters(self.arena.allocator(), sources, lifetime, budgets, location, &parameters, &.{});
    }
    /// A null value slice describes parameter types using witnesses. Execution
    /// always supplies an exact slice; all bound operands belong to allocator.
    pub fn bindParameters(self: *const Owned, allocator: std.mem.Allocator, sources: []const r.Source, lifetime: r.Lifetime, budgets: r.Budgets, location: ?*sql.Location, parameters: *Parameters, values: ?[]const ?types.Values.Atom) !r.Plan {
        if (sources.len != self.targets.len) return error.InvalidRelationalSources;
        for (sources, self.targets) |source, input| if (!std.mem.eql(u8, source.alias, input.alias)) return error.RelationalSourceChanged;
        var scalars: Scalar.Builder = .{};
        const outputs = if (self.star) try expandStar(allocator, sources) else try allocator.alloc(r.Output, self.selections.len);
        if (!self.star) {
            for (self.selections, outputs) |selection, *output| output.* = .{
                .name = selection.name,
                .expression = try self.resolveExpression(selection.expression, sources, location, allocator, &scalars, &.{}),
            };
        }
        const groups = try allocator.alloc(r.Column, self.groups.len);
        for (self.groups, groups) |column, *bound| bound.* = try resolve(column, sources, location);
        const order_by = try allocator.alloc(r.OrderBy, self.order_by.len);
        for (self.order_by, order_by) |item, *bound| bound.* = .{
            .expression = try self.resolveExpression(item.expression, sources, location, allocator, &scalars, outputs),
            .direction = item.direction,
            .nulls = item.nulls,
        };
        var plan: r.Plan = .{ .sources = sources, .scalars = .{ .instructions = scalars.instructions[0..scalars.len] }, .outputs = outputs, .group_by = groups, .order_by = order_by, .limit = self.limit, .lifetime = lifetime, .budgets = budgets };
        if (self.limit_parameter) |site| {
            const value = (try parameters.operand(site, .uint64, values, location)) orelse return error.NullLimitParameter;
            plan.limit = @intCast(value.unsigned);
        }
        if (self.join) |join| {
            const left = try resolve(join.left, sources, location);
            const right = try resolve(join.right, sources, location);
            plan.join = .{ .kind = join.kind, .left = if (left.source == 0) left else right, .right = if (left.source == 0) right else left };
        }
        if (self.predicate) |syntax| {
            const instructions = try allocator.alloc(r.Instruction, syntax.instructions.len);
            for (syntax.instructions, instructions) |input, *output| output.* = switch (input) {
                .conjunction => .conjunction,
                .disjunction => .disjunction,
                .negate => .negate,
                .atom => |atom| switch (atom) {
                    .state => |state| if (state.value == .null) .{ .is_null = try resolve(state.column, sources, location) } else return error.UnsupportedRelationalPredicate,
                    .compare => |compare| result: {
                        const column = try resolve(compare.column, sources, location);
                        const descriptor = try plan.resolveColumn(column);
                        const literal = try bindOperand(allocator, compare.value, descriptor, parameters, values, location);
                        break :result .{ .compare = .{ .column = column, .op = switch (compare.op) {
                            .eq => .equal,
                            .ne => .not_equal,
                            .lt => .less,
                            .le => .less_equal,
                            .gt => .greater,
                            .ge => .greater_equal,
                        }, .value = literal } };
                    },
                },
            };
            plan.filter = .{ .instructions = instructions };
        }
        if (self.having.len != 0) {
            const instructions = try allocator.alloc(r.HavingInstruction, self.having.len);
            for (self.having, instructions) |input, *output| output.* = switch (input) {
                .conjunction => .conjunction,
                .disjunction => .disjunction,
                .negate => .negate,
                .atom => |atom| switch (atom) {
                    .state => |state| if (state.value == .null) .{ .is_null = try self.resolveExpression(state.expression, sources, location, allocator, &scalars, outputs) } else return error.UnsupportedRelationalPredicate,
                    .compare => |compare| result: {
                        const expression = try self.resolveExpression(compare.expression, sources, location, allocator, &scalars, outputs);
                        plan.scalars.instructions = scalars.instructions[0..scalars.len];
                        const descriptor: @import("TableSchema.zig").Column = switch (expression) {
                            .column => |column| try plan.resolveColumn(column),
                            .count_all => .{ .id = 1, .name = "count", .type = .int64 },
                            .count => |column| blk: {
                                _ = try plan.resolveColumn(column);
                                break :blk .{ .id = 1, .name = "count", .type = .int64 };
                            },
                            .sum => |column| blk: {
                                const col = try plan.resolveColumn(column);
                                if (!r.sumType(col.type)) return error.UnsupportedRelationalType;
                                break :blk .{ .id = 1, .name = "sum", .type = col.type };
                            },
                        };
                        const literal = try bindOperand(allocator, compare.value, descriptor, parameters, values, location);
                        break :result .{ .compare = .{ .expression = expression, .op = switch (compare.op) {
                            .eq => .equal,
                            .ne => .not_equal,
                            .lt => .less,
                            .le => .less_equal,
                            .gt => .greater,
                            .ge => .greater_equal,
                        }, .value = literal } };
                    },
                },
            };
            plan.having = .{ .instructions = instructions };
        }
        plan.scalars = try scalars.finish(allocator);
        try parameters.finish(values);
        try plan.validate();
        return plan;
    }

    fn expandStar(allocator: std.mem.Allocator, sources: []const r.Source) ![]r.Output {
        var count: usize = 0;
        for (sources) |source| {
            if (source.schema.columns.len > r.max_outputs - count) return error.InvalidRelationalOutputs;
            count += source.schema.columns.len;
        }
        const outputs = try allocator.alloc(r.Output, count);
        var index: usize = 0;
        for (sources, 0..) |source, source_index| {
            for (source.schema.columns) |column| {
                outputs[index] = .{
                    // Joined schemas commonly repeat names, including the join
                    // key. Keep every column and qualify the result labels.
                    .name = if (sources.len == 1) column.name else try std.fmt.allocPrint(allocator, "{s}.{s}", .{ source.alias, column.name }),
                    .expression = .{ .column = .{ .source = @intCast(source_index), .id = column.id } },
                };
                index += 1;
            }
        }
        return outputs;
    }

    fn resolveExpression(self: *const Owned, expr: Expression, sources: []const r.Source, location: ?*sql.Location, allocator: std.mem.Allocator, scalars: *Scalar.Builder, outputs: []const r.Output) !r.Expression {
        return switch (expr) {
            .count_all => .count_all,
            .count => |column| .{ .count = try resolve(column, sources, location) },
            .sum => |column| .{ .sum = try resolve(column, sources, location) },
            inline .scalar, .sum_scalar, .count_scalar => |value, tag| blk: {
                if (sources.len != 1) return error.UnsupportedRelationalType;
                var fields: [r.max_outputs]types.Field = undefined;
                const schema = try sources[0].schema.rowType(&fields);
                var semantics: [r.max_outputs]@import("ColumnSemantics.zig") = undefined;
                for (sources[0].schema.columns, 0..) |column, i| semantics[i] = column.semantics;
                const ordinal = try scalars.bind(value.syntax, allocator, schema.structure, sources[0].alias, semantics[0..schema.structure.len], location);
                const column: r.Column = .{ .source = r.computed_source, .id = ordinal - schema.structure.len + 1 };
                break :blk switch (tag) {
                    .scalar => .{ .column = column },
                    .sum_scalar => .{ .sum = column },
                    .count_scalar => .{ .count = column },
                    else => unreachable,
                };
            },
            .column => |column| blk: {
                if (column.qualifier == null and outputs.len != 0 and !self.star) {
                    for (self.selections, outputs) |selection, output| {
                        if (selection.explicit_alias and std.mem.eql(u8, selection.name, column.name)) break :blk output.expression;
                    }
                }
                break :blk .{ .column = try resolve(column, sources, location) };
            },
        };
    }
};
pub fn parse(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location) !Owned {
    return parseWithContext(allocator, text, location, .{});
}
pub fn parseDialect(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location, dialect: sql.Dialect) !Owned {
    return parseWithContext(allocator, text, location, .{ .dialect = dialect });
}
pub const Context = struct { editor: ?*Parser.Editor = null, roles: ?[]sql.TokenRole = null, lookup: ?Predicate.Lookup = null, dialect: sql.Dialect = .transit };
fn bindOperand(allocator: std.mem.Allocator, operand: anytype, descriptor: @import("TableSchema.zig").Column, parameters: *Parameters, values: ?[]const ?types.Values.Atom, location: ?*sql.Location) !Values.Value {
    var nullable = descriptor;
    nullable.nullable = true;
    const cell: types.Values.Cell = switch (operand) {
        .parameter => |site| if (try parameters.operand(site, descriptor.type, values, location)) |value| .{ .value = .{ .atom = value } } else .null,
        .literal => |literal| blk: {
            var failure: ?Parser.Literal.Span = null;
            break :blk literal.bind(allocator, descriptor.type, &failure) catch |err| {
                if (location) |at| at.* = .{ .offset = (failure orelse literal.span).start };
                return err;
            };
        },
    };
    const value = (try Values.fromCell(cell, nullable)) orelse return null;
    return switch (value) {
        .text => |bytes| .{ .text = try allocator.dupe(u8, bytes) },
        .binary => |bytes| .{ .binary = try allocator.dupe(u8, bytes) },
        else => value,
    };
}
/// Completion and presentation consume the same parser as executable SQL.
/// Editor expectations and token roles do not establish semantic acceptance.
pub fn parseWithContext(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location, context: Context) !Owned {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const owned_text = try arena.allocator().dupe(u8, text);
    var parser = try Parser.initDialect(arena.allocator(), owned_text, location, true, context.dialect);
    parser.editor = context.editor;
    parser.roles = context.roles;
    try parser.requireWord("SELECT");
    var selections: [r.max_outputs]Selection = undefined;
    var count: usize = 0;
    const star = try parser.take(.star);
    while (!star) {
        if (count == selections.len) return error.InvalidRelationalOutputs;
        const expression = try parseExpression(&parser);
        var selection: Selection = .{
            .expression = expression,
            .name = switch (expression) {
                .column => |column| column.name,
                .scalar => |value| value.name,
                .sum_scalar => "sum",
                .count_scalar => "count",
                .sum => "sum",
                .count_all, .count => "count",
            },
        };
        if (try parser.takeWord("AS")) {
            selection.name = try parser.name();
            selection.explicit_alias = true;
        }
        selections[count] = selection;
        count += 1;
        if (!try parser.take(.comma)) break;
    }
    try parser.requireWord("FROM");
    var targets: [r.max_sources]Target = undefined;
    targets[0] = try target(&parser);
    var target_count: usize = 1;
    var join: @FieldType(Owned, "join") = null;
    const left = try parser.takeWord("LEFT");
    if (left) _ = try parser.takeWord("OUTER");
    const inner = if (!left) try parser.takeWord("INNER") else false;
    if (left or inner or parser.word("JOIN")) {
        try parser.requireWord("JOIN");
        targets[1] = try target(&parser);
        target_count = 2;
        try parser.requireWord("ON");
        const lhs = try Reference.parse(&parser);
        try parser.require(.eq);
        const rhs = try Reference.parse(&parser);
        join = .{ .kind = if (left) .left else .inner, .left = lhs, .right = rhs };
    }
    const predicate = if (try parser.takeWord("WHERE")) try Predicate.syntaxWithLookup(&parser, null, "", error.UnsupportedRelationalPredicate, context.lookup) else null;
    var groups: [r.max_groups]Reference = undefined;
    var group_count: usize = 0;
    if (try parser.takeWord("GROUP")) {
        try parser.requireWord("BY");
        while (true) {
            if (group_count == groups.len) return error.InvalidRelationalGroups;
            groups[group_count] = try Reference.parse(&parser);
            group_count += 1;
            if (!try parser.take(.comma)) break;
        }
    }
    var having: HavingParser = .{ .parser = &parser };
    if (try parser.takeWord("HAVING")) try having.parse();
    var order_by: [r.max_order_by]OrderBy = undefined;
    var order_count: usize = 0;
    if (try parser.takeWord("ORDER")) {
        try parser.requireWord("BY");
        while (true) {
            if (order_count == order_by.len) return error.InvalidRelationalGroups;
            const expression = try parseExpression(&parser);
            const direction: r.Direction = if (try parser.takeWord("DESC")) .desc else blk: {
                _ = try parser.takeWord("ASC");
                break :blk .asc;
            };
            const nulls: r.NullOrder = if (try parser.takeWord("NULLS")) blk: {
                if (try parser.takeWord("FIRST")) break :blk .first;
                if (try parser.takeWord("LAST")) break :blk .last;
                return error.InvalidSqlSyntax;
            } else switch (direction) {
                .asc => .first,
                .desc => .last,
            };
            order_by[order_count] = .{ .expression = expression, .direction = direction, .nulls = nulls };
            order_count += 1;
            if (!try parser.take(.comma)) break;
        }
    }
    var limit_parameter: ?sql.Parameter = null;
    const limit: ?u64 = if (try parser.takeWord("LIMIT")) blk: {
        if (try parser.parameter()) |site| {
            limit_parameter = site;
            break :blk null;
        }
        if (parser.token.tag != .integer) return error.InvalidSqlSyntax;
        parser.annotate(.number);
        const value = std.fmt.parseInt(u64, parser.token.text, 10) catch return error.LiteralOutOfRange;
        try parser.advance();
        break :blk value;
    } else null;
    try parser.finish();
    const inputs = try arena.allocator().dupe(Target, targets[0..target_count]);
    const outputs = try arena.allocator().dupe(Selection, selections[0..count]);
    const keys = try arena.allocator().dupe(Reference, groups[0..group_count]);
    const having_instructions = try arena.allocator().dupe(HavingInstruction, having.instructions[0..having.count]);
    const orders = try arena.allocator().dupe(OrderBy, order_by[0..order_count]);
    return .{
        .arena = arena,
        .targets = inputs,
        .selections = outputs,
        .star = star,
        .join = join,
        .predicate = predicate,
        .groups = keys,
        .having = having_instructions,
        .order_by = orders,
        .limit = limit,
        .limit_parameter = limit_parameter,
    };
}
fn parseExpression(parser: *Parser) !Expression {
    const is_count = parser.word("COUNT");
    const is_sum = parser.word("SUM");
    if ((is_count or is_sum) and (try parser.lexer.peek()).tag == .left) {
        parser.annotate(.function);
        try parser.advance();
        try parser.require(.left);
        const result: Expression = if (try parser.take(.star)) blk: {
            if (is_sum) return error.UnsupportedAggregate;
            break :blk .count_all;
        } else blk: {
            if (parser.boundary()) |at| at.sum_only = is_sum;
            const column = try Reference.parse(parser);
            if (try Scalar.parse(parser, column)) |scalar| {
                const value: ScalarExpression = .{ .syntax = scalar, .name = column.name };
                break :blk if (is_sum) .{ .sum_scalar = value } else .{ .count_scalar = value };
            }
            break :blk if (is_sum) .{ .sum = column } else .{ .count = column };
        };
        try parser.require(.right);
        return result;
    }
    if (parser.token.tag == .star) return error.UnsupportedConstruct;
    const column = try Reference.parse(parser);
    if (try Scalar.parse(parser, column)) |scalar| return .{ .scalar = .{ .syntax = scalar, .name = column.name } };
    return .{ .column = column };
}
const HavingParser = struct {
    const Operator = enum { group, disjunction, conjunction, negate };
    parser: *Parser,
    instructions: [r.max_instructions]HavingInstruction = undefined,
    count: usize = 0,
    operators: [r.max_instructions]Operator = undefined,
    pending: usize = 0,
    fn append(self: *HavingParser, instruction: HavingInstruction) !void {
        if (self.count == self.instructions.len) return error.PredicateTooComplex;
        self.instructions[self.count] = instruction;
        self.count += 1;
    }
    fn push(self: *HavingParser, operator: Operator) !void {
        if (self.pending == self.operators.len) return error.PredicateTooDeep;
        self.operators[self.pending] = operator;
        self.pending += 1;
    }
    fn emit(self: *HavingParser) !void {
        self.pending -= 1;
        try self.append(switch (self.operators[self.pending]) {
            .group => unreachable,
            .disjunction => .disjunction,
            .conjunction => .conjunction,
            .negate => .negate,
        });
    }
    fn parse(self: *HavingParser) !void {
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
    fn atom(self: *HavingParser) !void {
        const expression = try parseExpression(self.parser);
        if (try self.parser.takeWord("IS")) {
            const negate = try self.parser.takeWord("NOT");
            const state: @import("Types.zig").State = if (try self.parser.takeWord("NULL")) .null else if (try self.parser.takeWord("MISSING")) .missing else if (try self.parser.takeWord("TYPE_ERROR")) .type_error else if (try self.parser.takeWord("VALUE")) .value else if (try self.parser.takeWord("CONFLICT")) .conflict else return error.InvalidSqlSyntax;
            try self.append(.{ .atom = .{ .state = .{ .expression = expression, .value = state } } });
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
            else => return error.UnsupportedRelationalPredicate,
        };
        try self.parser.advance();
        const value: @FieldType(@FieldType(HavingAtom, "compare"), "value") = if (try self.parser.parameter()) |site| .{ .parameter = site } else .{ .literal = try self.parser.literal(null) };
        try self.append(.{ .atom = .{ .compare = .{ .expression = expression, .op = op, .value = value } } });
    }
};
/// Header discovery for authorized editor metadata, including an unfinished
/// projection. Returned names borrow allocator-owned strings. This does not
/// validate expressions, authorize a Table or create an execution plan.
pub fn discoverTargets(allocator: std.mem.Allocator, text: []const u8, output: *[r.max_sources]Target) !usize {
    var parser = try Parser.init(allocator, text, null);
    try parser.requireWord("SELECT");
    var depth: usize = 0;
    while (parser.token.tag != .eof) {
        if (depth == 0 and parser.word("FROM")) break;
        if (parser.token.tag == .left) depth += 1;
        if (parser.token.tag == .right) {
            if (depth == 0) return error.InvalidSqlSyntax;
            depth -= 1;
        }
        try parser.advance();
    }
    try parser.requireWord("FROM");
    output[0] = try target(&parser);
    const left = try parser.takeWord("LEFT");
    if (left) _ = try parser.takeWord("OUTER");
    const inner = if (!left) try parser.takeWord("INNER") else false;
    if (left or inner or parser.word("JOIN")) {
        try parser.requireWord("JOIN");
        output[1] = try target(&parser);
        return 2;
    }
    return 1;
}
fn target(parser: *Parser) !Target {
    const name = try parser.named(.source);
    const alias = if (try parser.takeWord("AS")) try parser.name() else if (parser.token.tag == .quoted or (parser.token.tag == .word and !sql.isReserved(parser.token.text) and !clauseWord(parser.token.text))) try parser.name() else name;
    return .{ .name = name, .alias = alias };
}
fn clauseWord(word: []const u8) bool {
    inline for (.{ "JOIN", "INNER", "LEFT", "OUTER", "RIGHT", "FULL", "CROSS", "NATURAL", "GROUP", "HAVING", "ORDER" }) |keyword| {
        if (std.ascii.eqlIgnoreCase(word, keyword)) return true;
    }
    return false;
}
fn resolve(reference: Reference, sources: []const r.Source, location: ?*sql.Location) !r.Column {
    return r.resolve(sources, reference.qualifier, reference.name) catch |err| {
        if (location) |at| at.* = .{ .offset = if (err == error.UnknownRelationalSource) (reference.qualifier_span orelse reference.span).start else reference.span.start };
        return err;
    };
}

test {
    _ = @import("relational_sql_test.zig");
}
