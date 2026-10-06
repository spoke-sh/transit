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
const Reference = struct {
    name: []const u8,
    qualifier: ?[]const u8 = null,
    fn parse(parser: *Parser) !Reference {
        const first = try parser.named(.column);
        if (try parser.take(.dot)) {
            if (parser.boundary()) |editor| editor.qualifier = .init(first);
            return .{ .qualifier = first, .name = try parser.named(.column) };
        }
        return .{ .name = first };
    }
    fn resolve(self: Reference, qualifier: []const u8, fields: []const t.Field) !u8 {
        if (self.qualifier) |value| if (!std.mem.eql(u8, value, qualifier)) return error.UnknownQualifier;
        for (fields, 0..) |field, i| if (std.mem.eql(u8, self.name, field.name)) return @intCast(i);
        return error.UnknownColumn;
    }
};
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
    fn lower(self: Selection, allocator: std.mem.Allocator, schema: t.Type, qualifier: []const u8, basis: [32]u8) !logical.Plan {
        const count = if (self.star and self.aggregate == .rows) schema.structure.len else self.count;
        const columns = try allocator.alloc(u8, count);
        const names = try allocator.alloc(?[]const u8, count);
        for (columns, names, 0..) |*column, *name, i| {
            column.* = if (self.star) (if (self.aggregate == .count) 0 else @intCast(i)) else try self.items[i].column.resolve(qualifier, schema.structure);
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
    var parser = try Parser.init(allocator, text, null);
    parser.editor = editor;
    const selection = try Selection.parse(&parser);
    if (try parser.take(.left)) {
        if (selection.aggregate == .rows) return error.UnsupportedConstruct;
        const inner = try Selection.parse(&parser);
        if (inner.aggregate != .rows) return error.UnsupportedConstruct;
    }
    return parser.named(.source);
}
/// Header-only qualifier discovery for authorized editor metadata.
pub fn targetQualifier(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    var parser = try Parser.init(allocator, text, null);
    const selection = try Selection.parse(&parser);
    if (try parser.take(.left)) {
        if (selection.aggregate == .rows) return error.UnsupportedConstruct;
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
fn tail(parser: *Parser, plan: *logical.Plan, qualifier: []const u8) !void {
    if (try parser.takeWord("WHERE")) plan.predicate = .{ .program = try predicate.parse(parser, plan.schema, qualifier, error.UnsupportedConstruct) };
    if (try parser.takeWord("LIMIT")) {
        if (plan.aggregate != .rows) return error.UnsupportedAggregateLimit;
        if (parser.token.tag != .integer) return error.InvalidSqlSyntax;
        plan.limit = std.fmt.parseInt(u64, parser.token.text, 10) catch return error.LiteralOutOfRange;
        try parser.advance();
    }
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
    const outer = try Selection.parse(&parser);
    const derived = try parser.take(.left);
    if (derived and outer.aggregate == .rows) return error.UnsupportedConstruct;
    const selection = if (derived) try Selection.parse(&parser) else outer;
    if (derived and selection.aggregate != .rows) return error.UnsupportedConstruct;
    const subject = try parser.named(.source);
    if (!std.mem.eql(u8, subject, name)) return error.UnknownSource;
    const qualifier = try alias(&parser, subject);
    var plan = try selection.lower(alloc, descriptor.type, qualifier, basis);
    try tail(&parser, &plan, qualifier);
    if (derived) {
        try parser.require(.right);
        try parser.requireWord("AS");
        const input_name = try parser.name();
        var fields: [max_columns]t.Field = undefined;
        const input_type = try plan.outputSchema(&fields);
        const output = try outer.lower(alloc, input_type, input_name, basis);
        const projection = try alloc.dupe(u8, output.projection);
        for (projection) |*index| index.* = plan.projection[index.*];
        plan.projection = projection;
        plan.output_names = output.output_names;
        plan.aggregate = output.aggregate;
        if (parser.word("LIMIT")) return error.UnsupportedAggregateLimit;
    }
    try parser.finish();
    try plan.validateShape();
    _ = try plan.fingerprint();
    return .{ .arena = arena, .descriptor = descriptor, .name = subject, .plan = plan };
}

test {
    _ = @import("table_select_test.zig");
}
