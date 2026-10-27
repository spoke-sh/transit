//! Relational SELECT lowering through the shared SQL lexer, names, literals and
//! predicate grammar. Binding consumes explicitly acquired Table declarations.
const std = @import("std");
const r = @import("Relational.zig");
const sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
pub const Reference = @import("SqlReference.zig");
const Predicate = @import("SqlLogicalPredicate.zig");
pub const Target = struct { name: []const u8, alias: []const u8 };
/// Classifies syntax before any source is opened. This is routing, not parsing
/// acceptance: malformed/unsupported relational input still goes to parse.
pub fn required(text: []const u8) !bool {
    return requiredDialect(text, .transit);
}
pub fn requiredDialect(text: []const u8, dialect: sql.Dialect) !bool {
    try sql.validateText(text);
    var lexer: sql.Lexer = .{ .text = text, .dialect = dialect };
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
                if (std.ascii.eqlIgnoreCase(token.text, "WHERE")) source = .done;
            }
            if (!selection and std.ascii.eqlIgnoreCase(token.text, "GROUP")) {
                var lookahead = lexer;
                const next = try lookahead.next();
                if (next.tag == .word and std.ascii.eqlIgnoreCase(next.text, "BY")) return true;
            }
        }
        if (selection and (std.ascii.eqlIgnoreCase(token.text, "COUNT") or std.ascii.eqlIgnoreCase(token.text, "SUM"))) aggregate = true;
    }
}
const Selection = struct {
    expression: union(enum) { column: Reference, count_all, count: Reference, sum: Reference },
    name: []const u8,
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    targets: []const Target,
    selections: []const Selection,
    join: ?struct { kind: @FieldType(r.Join, "kind"), left: Reference, right: Reference },
    predicate: ?Predicate.Syntax,
    groups: []const Reference,

    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
    /// Returned plan borrows this syntax owner and the supplied immutable source
    /// descriptors. The caller must have resolved targets in their listed order.
    pub fn bind(self: *Owned, sources: []const r.Source, lifetime: r.Lifetime, budgets: r.Budgets, location: ?*sql.Location) !r.Plan {
        if (sources.len != self.targets.len) return error.InvalidRelationalSources;
        for (sources, self.targets) |source, input| if (!std.mem.eql(u8, source.alias, input.alias)) return error.RelationalSourceChanged;
        const allocator = self.arena.allocator();
        const outputs = try allocator.alloc(r.Output, self.selections.len);
        for (self.selections, outputs) |selection, *output| output.* = .{ .name = selection.name, .expression = switch (selection.expression) {
            .count_all => .count_all,
            .column => |column| .{ .column = try resolve(column, sources, location) },
            .count => |column| .{ .count = try resolve(column, sources, location) },
            .sum => |column| .{ .sum = try resolve(column, sources, location) },
        } };
        const groups = try allocator.alloc(r.Column, self.groups.len);
        for (self.groups, groups) |column, *bound| bound.* = try resolve(column, sources, location);
        var plan: r.Plan = .{ .sources = sources, .outputs = outputs, .group_by = groups, .lifetime = lifetime, .budgets = budgets };
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
                        if (compare.value != .literal) return error.UnboundParameters;
                        var failure: ?Parser.Literal.Span = null;
                        const descriptor = try plan.resolveColumn(column);
                        const value = compare.value.literal.bind(allocator, descriptor.type, &failure) catch |err| {
                            if (location) |at| at.* = .{ .offset = (failure orelse compare.value.literal.span).start };
                            return err;
                        };
                        if (value == .null) return error.UnsupportedNullComparison;
                        const literal = (try @import("RelationalValues.zig").fromCell(value, descriptor)).?;
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
        try plan.validate();
        return plan;
    }
};
pub fn parse(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location) !Owned {
    return parseWithContext(allocator, text, location, .{});
}
pub fn parseDialect(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location, dialect: sql.Dialect) !Owned {
    return parseWithContext(allocator, text, location, .{ .dialect = dialect });
}
pub const Context = struct { editor: ?*Parser.Editor = null, roles: ?[]sql.TokenRole = null, lookup: ?Predicate.Lookup = null, dialect: sql.Dialect = .transit };
/// Completion and presentation consume the same parser as executable SQL.
/// Editor expectations and token roles do not establish semantic acceptance.
pub fn parseWithContext(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location, context: Context) !Owned {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    var parser = try Parser.initDialect(arena.allocator(), text, location, false, context.dialect);
    parser.editor = context.editor;
    parser.roles = context.roles;
    try parser.requireWord("SELECT");
    var selections: [r.max_outputs]Selection = undefined;
    var count: usize = 0;
    while (true) {
        if (count == selections.len) return error.InvalidRelationalOutputs;
        const is_count = parser.word("COUNT");
        const is_sum = parser.word("SUM");
        var selection: Selection = undefined;
        if (is_count or is_sum) {
            parser.annotate(.function);
            try parser.advance();
            try parser.require(.left);
            if (try parser.take(.star)) {
                if (is_sum) return error.UnsupportedAggregate;
                selection.expression = .count_all;
            } else {
                if (parser.boundary()) |at| at.sum_only = is_sum;
                const column = try Reference.parse(&parser);
                selection.expression = if (is_sum) .{ .sum = column } else .{ .count = column };
            }
            try parser.require(.right);
            selection.name = if (is_sum) "sum" else "count";
        } else {
            const column = try Reference.parse(&parser);
            selection = .{ .expression = .{ .column = column }, .name = column.name };
        }
        if (try parser.takeWord("AS")) selection.name = try parser.name();
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
    try parser.finish();
    const inputs = try arena.allocator().dupe(Target, targets[0..target_count]);
    const outputs = try arena.allocator().dupe(Selection, selections[0..count]);
    const keys = try arena.allocator().dupe(Reference, groups[0..group_count]);
    return .{ .arena = arena, .targets = inputs, .selections = outputs, .join = join, .predicate = predicate, .groups = keys };
}
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
