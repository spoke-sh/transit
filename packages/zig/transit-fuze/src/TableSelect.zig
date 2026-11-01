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
const Scalar = @import("SqlScalar.zig");
const Semantics = @import("ColumnSemantics.zig");
const Item = struct { column: Reference, alias: ?[]const u8, scalar: ?Scalar.Syntax = null };
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
                result.items[0].scalar = null;
            } else {
                if (parser.boundary()) |editor| editor.sum_only = result.aggregate == .sum;
                result.items[0].column = try Reference.parse(parser);
                result.items[0].scalar = try Scalar.parse(parser, result.items[0].column);
            }
            try parser.require(.right);
            result.items[0].alias = if (try parser.takeWord("AS")) try parser.name() else null;
            result.count = 1;
        } else if (try parser.take(.star)) {
            result.star = true;
        } else while (true) {
            if (result.count == max_columns) return error.InvalidProjection;
            const column = try Reference.parse(parser);
            const scalar = try Scalar.parse(parser, column);
            result.items[result.count] = .{ .column = column, .scalar = scalar, .alias = if (try parser.takeWord("AS")) try parser.name() else null };
            result.count += 1;
            if (!try parser.take(.comma)) break;
        }
        try parser.requireWord("FROM");
        return result;
    }
    fn lower(self: Selection, allocator: std.mem.Allocator, schema: t.Type, qualifier: []const u8, basis: [32]u8, location: ?*sql.Location, semantics: []const Semantics) !logical.Plan {
        var scalars: Scalar.Builder = .{};
        const count = if (self.star and self.aggregate == .rows) schema.structure.len else self.count;
        const columns = try allocator.alloc(u8, count);
        const names = try allocator.alloc(?[]const u8, count);
        for (columns, names, 0..) |*column, *name, i| {
            column.* = if (self.star) (if (self.aggregate == .count) 0 else @intCast(i)) else if (self.items[i].scalar) |expression| try scalars.bind(expression, allocator, schema.structure, qualifier, semantics, location) else @intCast(try self.items[i].column.resolve(qualifier, schema.structure, location));
            name.* = if (self.star and self.aggregate == .rows) null else self.items[i].alias orelse if (!self.star and self.items[i].scalar != null) self.items[i].column.name else null;
        }
        if (self.aggregate == .rows) for (columns, names, 0..) |column, name, i| {
            const output_name = name orelse schema.structure[column].name;
            for (columns[0..i], names[0..i]) |earlier, earlier_name| {
                if (std.mem.eql(u8, output_name, earlier_name orelse schema.structure[earlier].name)) {
                    if (!self.star) {
                        if (location) |at| at.* = .{ .offset = self.items[i].column.span.start };
                    }
                    return if (column == earlier) error.DuplicateProjection else error.DuplicateColumn;
                }
            }
        };
        const plan: logical.Plan = .{ .scalars = try scalars.finish(allocator), .schema = schema, .source_basis = basis, .projection = columns, .output_names = names, .aggregate = self.aggregate };
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
    return targetParsed(&parser);
}
pub fn targetDialect(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location, dialect: sql.Dialect) ![]const u8 {
    var parser = try Parser.initDialect(allocator, text, location, true, dialect);
    return targetParsed(&parser);
}
fn targetParsed(parser: *Parser) ![]const u8 {
    const selection = try Selection.parse(parser);
    if (selection.aggregate == .rows and parser.token.tag == .left) return error.UnsupportedConstruct;
    if (selection.aggregate != .rows and try parser.take(.left)) {
        const inner = try Selection.parse(parser);
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
fn clauseWord(word: []const u8) bool {
    inline for (.{ "JOIN", "INNER", "LEFT", "OUTER", "RIGHT", "FULL", "CROSS", "NATURAL", "GROUP", "HAVING", "ORDER" }) |reserved| {
        if (std.ascii.eqlIgnoreCase(word, reserved)) return true;
    }
    return false;
}
fn alias(parser: *Parser, name: []const u8) ![]const u8 {
    if (try parser.takeWord("AS")) return parser.name();
    if (parser.token.tag == .quoted or (parser.token.tag == .word and !sql.isReserved(parser.token.text) and !clauseWord(parser.token.text))) return parser.name();
    return name;
}
pub const Syntax = struct {
    selection: Selection,
    semantics: []const Semantics = &.{},
    subject: Reference,
    qualifier: []const u8,
    predicate: ?predicate.Syntax = null,
    limit: ?u64 = null,
    limit_parameter: ?sql.Parameter = null,
    outer: ?struct { selection: Selection, qualifier: []const u8 } = null,
    pub fn bind(self: Syntax, allocator: std.mem.Allocator, name: []const u8, schema: t.Type, basis: [32]u8, location: ?*sql.Location) !logical.Plan {
        return self.bindParameters(allocator, name, schema, basis, location, null);
    }
    pub fn bindParameters(self: Syntax, allocator: std.mem.Allocator, name: []const u8, schema: t.Type, basis: [32]u8, location: ?*sql.Location, parameters: ?[]const ?t.Values.Atom) !logical.Plan {
        return self.bindParametersDiagnostic(allocator, name, schema, basis, location, parameters, null);
    }
    pub fn bindParametersDiagnostic(self: Syntax, allocator: std.mem.Allocator, name: []const u8, schema: t.Type, basis: [32]u8, location: ?*sql.Location, parameters: ?[]const ?t.Values.Atom, diagnostic: ?*sql.Binding) !logical.Plan {
        if (schema != .structure or schema.structure.len == 0 or schema.structure.len > max_columns) return error.InvalidQuerySchema;
        if (!std.mem.eql(u8, self.subject.name, name)) {
            if (location) |at| at.* = .{ .offset = self.subject.span.start };
            return error.UnknownSource;
        }
        var plan = try self.selection.lower(allocator, schema, self.qualifier, basis, location, self.semantics);
        if (self.predicate) |expression| {
            const program = try expression.bindParametersDiagnostic(allocator, schema, self.qualifier, location, parameters, diagnostic);
            // Parentheses around one atom do not introduce a distinct plan or
            // signed request identity. Preserve every real Boolean instruction.
            plan.predicate = if (program.instructions.len == 1) switch (program.instructions[0].atom) {
                inline else => |value, tag| @unionInit(@FieldType(logical.Plan, "predicate"), @tagName(tag), value),
            } else .{ .program = program };
        }
        plan.limit = self.limit;
        if (self.limit_parameter) |site| {
            if (self.limit != null) return error.InvalidParameterSite;
            plan.limit = @intCast((try predicate.parameterValue(site, parameters, .uint64, location) orelse return error.NullLimitParameter).unsigned);
        }
        if (self.outer) |outer| {
            var fields: [max_columns]t.Field = undefined;
            const input_type = try plan.outputSchema(&fields);
            const output = try outer.selection.lower(allocator, input_type, outer.qualifier, basis, location, &.{});
            if (output.scalars.instructions.len != 0) return error.UnsupportedConstruct;
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
    if (!parser.word("SELECT")) return error.UnsupportedStatement;
    const outer = try Selection.parse(parser);
    const derived = try parser.take(.left);
    if (derived and outer.aggregate == .rows) return error.UnsupportedConstruct;
    const selection = if (derived) try Selection.parse(parser) else outer;
    if (derived and selection.aggregate != .rows) return error.UnsupportedConstruct;
    const subject = try Reference.unqualified(parser, .source);
    const qualifier = try alias(parser, subject.name);
    var result: Syntax = .{ .selection = selection, .subject = subject, .qualifier = qualifier };
    if (try parser.takeWord("WHERE")) result.predicate = try predicate.syntax(parser, hints, qualifier, error.UnsupportedConstruct);
    const limit = if (selection.aggregate == .rows or parser.token.tag != .eof) try parser.takeWord("LIMIT") else false;
    if (limit) {
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
        if (parser.token.tag != .eof and parser.word("LIMIT")) return error.UnsupportedAggregateLimit;
    }
    return result;
}
/// Compile a non-parameterized statement into the caller's bounded arena.
/// Schema slices retain their owner; parser and output-name slices use allocator.
/// Catalog identity and admission remain with the caller.
pub fn planDiagnostic(allocator: std.mem.Allocator, text: []const u8, name: []const u8, schema: t.Type, basis: [32]u8, diagnostic: ?*sql.Binding) !logical.Plan {
    return planSemantics(allocator, text, name, schema, basis, diagnostic, &.{});
}
pub fn planSemantics(allocator: std.mem.Allocator, text: []const u8, name: []const u8, schema: t.Type, basis: [32]u8, diagnostic: ?*sql.Binding, semantics: []const Semantics) !logical.Plan {
    if (diagnostic) |detail| detail.* = .{};
    var location: sql.Location = .{};
    errdefer if (diagnostic) |detail| {
        if (detail.location == null) detail.location = location;
    };
    try sql.validateText(text);
    var parser = try Parser.init(allocator, text, &location);
    var parsed = try syntax(&parser, schema);
    parsed.semantics = semantics;
    try parser.finish();
    return parsed.bindParametersDiagnostic(allocator, name, schema, basis, &location, null, diagnostic) catch |err| {
        sql.Binding.nameFailure(diagnostic, text, if (err == error.UnknownSource) name else parsed.qualifier, err, location);
        return err;
    };
}

pub fn compile(allocator: std.mem.Allocator, text: []const u8, name: []const u8, schema: t.Type, basis: [32]u8, location: ?*sql.Location) !Owned {
    return compileWithEditor(allocator, text, name, schema, basis, location, null);
}
pub fn compileWithEditor(allocator: std.mem.Allocator, text: []const u8, name: []const u8, schema: t.Type, basis: [32]u8, location: ?*sql.Location, editor: ?*Parser.Editor) !Owned {
    return compileSemantics(allocator, text, name, schema, basis, location, editor, &.{});
}
pub fn compileSemantics(allocator: std.mem.Allocator, text: []const u8, name: []const u8, schema: t.Type, basis: [32]u8, location: ?*sql.Location, editor: ?*Parser.Editor, semantics: []const Semantics) !Owned {
    if (schema != .structure or schema.structure.len == 0 or schema.structure.len > max_columns) return error.InvalidQuerySchema;
    var descriptor = try schema.clone(allocator);
    errdefer descriptor.deinit();
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const alloc = arena.allocator();
    var parser = try Parser.init(alloc, text, location);
    parser.editor = editor;
    var input = try syntax(&parser, schema);
    input.semantics = semantics;
    try parser.finish();
    const plan = try input.bind(alloc, name, descriptor.type, basis, location);
    return .{ .arena = arena, .descriptor = descriptor, .name = input.subject.name, .plan = plan };
}

test {
    _ = @import("table_select_test.zig");
    _ = @import("scalar_query_test.zig");
}
