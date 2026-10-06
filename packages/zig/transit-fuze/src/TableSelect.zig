//! Owned finite SELECT over a supplied general logical Table schema. The caller
//! owns source resolution/capture and must validate its basis before disclosure.
const std = @import("std");
const t = @import("Types.zig");
const sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
const logical = @import("LogicalQuery.zig");
const predicate = @import("SqlLogicalPredicate.zig");
const Aggregate = @import("Finite.zig").Aggregate;
const max_columns = @import("TableSchema.zig").max_columns;
const Reference = @import("SqlReference.zig");
const Item = struct { column: Reference, alias: ?[]const u8 };
const Selection = struct {
    aggregate: Aggregate = .rows,
    star: bool = false,
    items: [max_columns]Item = undefined,
    count: usize = 0,
    fn parse(parser: *Parser) !Selection {
        try parser.requireWord("SELECT");
        var result: Selection = .{};
        const is_count = parser.word("COUNT");
        const is_sum = parser.word("SUM");
        if (is_count or is_sum) {
            result.aggregate = if (parser.word("COUNT")) .count_values else .sum;
            parser.annotate(.function);
            try parser.advance();
            try parser.require(.left);
            if (try parser.take(.star)) {
                if (result.aggregate != .count_values) return error.UnsupportedAggregate;
                result.aggregate = .count;
                result.star = true;
            } else {
                if (parser.boundary()) |editor| editor.sum_only = result.aggregate == .sum;
                result.items[0].column = try Reference.parse(parser);
            }
            try parser.require(.right);
            result.items[0].alias = if (try parser.takeWord("AS")) try parser.name() else null;
            result.count = 1;
        } else if (try parser.take(.star)) {
            result.star = true;
        } else while (true) {
            if (result.count == max_columns) return error.InvalidProjection;
            const column = try Reference.parse(parser);
            result.items[result.count] = .{ .column = column, .alias = if (try parser.takeWord("AS")) try parser.name() else null };
            result.count += 1;
            if (!try parser.take(.comma)) break;
        }
        try parser.requireWord("FROM");
        return result;
    }
    fn lower(self: Selection, allocator: std.mem.Allocator, schema: t.Type, qualifier: []const u8, basis: [32]u8, location: ?*sql.Location) !logical.Plan {
        const count = if (self.star and self.aggregate == .rows) schema.structure.len else self.count;
        const columns = try allocator.alloc(u8, count);
        const names = try allocator.alloc(?[]const u8, count);
        for (columns, names, 0..) |*column, *name, i| {
            column.* = if (self.star) (if (self.aggregate == .count) 0 else @intCast(i)) else @intCast(try self.items[i].column.resolve(qualifier, schema.structure, location));
            name.* = if (self.star and self.aggregate == .rows) null else self.items[i].alias;
        }
        const plan: logical.Plan = .{ .schema = schema, .source_basis = basis, .projection = columns, .output_names = names, .aggregate = self.aggregate };
        try plan.validateShape();
        return plan;
    }
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    descriptor: t.Decoded,
    name: []const u8,
    plan: logical.Plan,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.descriptor.deinit();
        self.* = undefined;
    }
};
/// Resolves only the input name. Complete acceptance still requires compile.
pub fn target(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    return targetWithEditor(allocator, text, null);
}
pub fn targetWithEditor(allocator: std.mem.Allocator, text: []const u8, editor: ?*Parser.Editor) ![]const u8 {
    return targetContext(allocator, text, null, editor);
}
pub fn targetDiagnostic(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location) ![]const u8 {
    return targetContext(allocator, text, location, null);
}
fn targetContext(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location, editor: ?*Parser.Editor) ![]const u8 {
    var parser = try Parser.init(allocator, text, location);
    parser.editor = editor;
    const selection = try Selection.parse(&parser);
    if (selection.aggregate == .rows and parser.token.tag == .left) return error.UnsupportedConstruct;
    if (selection.aggregate != .rows and try parser.take(.left)) {
        const inner = try Selection.parse(&parser);
        if (inner.aggregate != .rows) return error.UnsupportedConstruct;
    }
    return parser.named(.source);
}
/// Header-only qualifier discovery for authorized editor metadata.
pub fn targetQualifier(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    var parser = try Parser.init(allocator, text, null);
    const selection = try Selection.parse(&parser);
    if (selection.aggregate == .rows and parser.token.tag == .left) return error.UnsupportedConstruct;
    if (selection.aggregate != .rows and try parser.take(.left)) {
        _ = try Selection.parse(&parser);
    }
    const name = try parser.name();
    return alias(&parser, name);
}
fn alias(parser: *Parser, name: []const u8) ![]const u8 {
    if (try parser.takeWord("AS")) return parser.name();
    if (parser.token.tag == .quoted or (parser.token.tag == .word and !sql.isReserved(parser.token.text))) return parser.name();
    return name;
}
pub const Syntax = struct {
    selection: Selection,
    subject: Reference,
    qualifier: []const u8,
    predicate: ?predicate.Syntax = null,
    limit: ?u64 = null,
    limit_parameter: ?sql.Parameter = null,
    outer: ?struct { selection: Selection, qualifier: []const u8 } = null,
    pub fn bind(self: Syntax, allocator: std.mem.Allocator, name: []const u8, schema: t.Type, basis: [32]u8, location: ?*sql.Location) !logical.Plan {
        return self.bindParameters(allocator, name, schema, basis, location, null);
    }
    pub fn bindParameters(self: Syntax, allocator: std.mem.Allocator, name: []const u8, schema: t.Type, basis: [32]u8, location: ?*sql.Location, parameters: ?[]const t.Values.Atom) !logical.Plan {
        if (schema != .structure or schema.structure.len == 0 or schema.structure.len > max_columns) return error.InvalidQuerySchema;
        if (!std.mem.eql(u8, self.subject.name, name)) {
            if (location) |at| at.* = .{ .offset = self.subject.span.start };
            return error.UnknownSource;
        }
        var plan = try self.selection.lower(allocator, schema, self.qualifier, basis, location);
        if (self.predicate) |expression| plan.predicate = .{ .program = try expression.bindParameters(allocator, schema, self.qualifier, location, parameters) };
        plan.limit = self.limit;
        if (self.limit_parameter) |site| {
            if (self.limit != null) return error.InvalidParameterSite;
            plan.limit = @intCast((try predicate.parameterValue(site, parameters, .uint64, location)).unsigned);
        }
        if (self.outer) |outer| {
            var fields: [max_columns]t.Field = undefined;
            const input_type = try plan.outputSchema(&fields);
            const output = try outer.selection.lower(allocator, input_type, outer.qualifier, basis, location);
            const projection = try allocator.dupe(u8, output.projection);
            for (projection) |*index| index.* = plan.projection[index.*];
            plan.projection = projection;
            plan.output_names = output.output_names;
            plan.aggregate = output.aggregate;
        }
        try plan.validateShape();
        _ = try plan.fingerprint();
        return plan;
    }
};
pub fn syntax(parser: *Parser, hints: ?t.Type) !Syntax {
    const outer = try Selection.parse(parser);
    const derived = try parser.take(.left);
    if (derived and outer.aggregate == .rows) return error.UnsupportedConstruct;
    const selection = if (derived) try Selection.parse(parser) else outer;
    if (derived and selection.aggregate != .rows) return error.UnsupportedConstruct;
    const subject = try Reference.unqualified(parser, .source);
    const qualifier = try alias(parser, subject.name);
    var result: Syntax = .{ .selection = selection, .subject = subject, .qualifier = qualifier };
    if (try parser.takeWord("WHERE")) result.predicate = try predicate.syntax(parser, hints, qualifier, error.UnsupportedConstruct);
    if (try parser.takeWord("LIMIT")) {
        if (selection.aggregate != .rows) return error.UnsupportedAggregateLimit;
        if (try parser.parameter()) |site| {
            result.limit_parameter = site;
        } else {
            if (parser.token.tag != .integer) return error.InvalidSqlSyntax;
            result.limit = std.fmt.parseInt(u64, parser.token.text, 10) catch return error.LiteralOutOfRange;
            try parser.advance();
        }
    }
    if (derived) {
        try parser.require(.right);
        try parser.requireWord("AS");
        result.outer = .{ .selection = outer, .qualifier = try parser.name() };
        if (parser.word("LIMIT")) return error.UnsupportedAggregateLimit;
    }
    return result;
}
pub fn compile(allocator: std.mem.Allocator, text: []const u8, name: []const u8, schema: t.Type, basis: [32]u8, location: ?*sql.Location) !Owned {
    return compileWithEditor(allocator, text, name, schema, basis, location, null);
}
pub fn compileWithEditor(allocator: std.mem.Allocator, text: []const u8, name: []const u8, schema: t.Type, basis: [32]u8, location: ?*sql.Location, editor: ?*Parser.Editor) !Owned {
    if (schema != .structure or schema.structure.len == 0 or schema.structure.len > max_columns) return error.InvalidQuerySchema;
    var descriptor = try schema.clone(allocator);
    errdefer descriptor.deinit();
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const alloc = arena.allocator();
    var parser = try Parser.init(alloc, text, location);
    parser.editor = editor;
    const input = try syntax(&parser, schema);
    try parser.finish();
    const plan = try input.bind(alloc, name, descriptor.type, basis, location);
    return .{ .arena = arena, .descriptor = descriptor, .name = input.subject.name, .plan = plan };
}

test {
    _ = @import("table_select_test.zig");
}
