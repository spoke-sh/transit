//! M12 syntax lowered to the v1 plan. Source resolution never performs I/O;
//! returned projection/literal slices belong to the supplied allocator.
const std = @import("std");
const f = @import("root.zig");
const m = f.Unified;
const sql = f.Sql;
pub const Source = struct { name: m.Name, schema: m.Schema };
pub fn plan(allocator: std.mem.Allocator, text: []const u8, source: Source) !m.Plan {
    var ast: sql.Ast = undefined;
    try sql.parseInto(text, &ast, null);
    return compileAst(allocator, &ast, source);
}
pub fn compile(allocator: std.mem.Allocator, ast: sql.Ast, source: Source) !m.Plan {
    return compileAst(allocator, &ast, source);
}
fn compileAst(allocator: std.mem.Allocator, ast: *const sql.Ast, source: Source) !m.Plan {
    var result: m.Plan = undefined;
    try compileInto(allocator, ast, source, &result);
    return result;
}
fn compileInto(allocator: std.mem.Allocator, ast: *const sql.Ast, source: Source, result: *m.Plan) !void {
    try source.schema.validate();
    if (!sameName(ast.source, source.name)) return error.UnknownSource;
    if (ast.selection != .rows and ast.limit != null) return error.UnsupportedAggregateLimit;
    if (ast.input != null and ast.selection == .rows) return error.UnsupportedConstruct;
    if (ast.selection == .rows and ast.output_alias != null) return error.InvalidOutputNames;
    const source_qualifier = if (ast.source_alias) |alias| try ownedName(alias) else source.name;
    var input: [m.max_columns]u8 = undefined;
    var input_columns: [m.max_columns]m.Column = undefined;
    var input_schema = source.schema;
    // Only a derived input introduces a projected scope. Direct queries already
    // have a validated source schema and use its column indices unchanged.
    var inner: m.Plan = .{ .projection = &.{} };
    if (ast.input) |value| {
        try projection(value.projection, source_qualifier, source.schema, &input, &inner);
        input_schema = try inner.outputSchema(source.schema, &input_columns);
    }
    const qualifier = if (ast.input) |value| try ownedName(value.alias) else source_qualifier;
    var selected: [m.max_columns]u8 = undefined;
    switch (ast.selection) {
        .rows => |value| try projection(value, qualifier, source.schema, &selected, result),
        .count => {
            // Count consumes rows; a single validated input column carries the
            // required plan shape without inspecting its value or state.
            selected[0] = if (ast.input != null) inner.projection[0] else 0;
            result.* = .{ .projection = selected[0..1], .aggregate = .count };
        },
        .sum => |column| {
            const index = try resolve(column, qualifier, input_schema);
            selected[0] = if (ast.input != null) inner.projection[index] else index;
            result.* = .{ .projection = selected[0..1], .aggregate = .sum };
        },
    }
    if (ast.output_alias) |alias| result.output_names[0] = try ownedName(alias);
    const owned_projection = try allocator.dupe(u8, result.projection);
    errdefer allocator.free(owned_projection);
    result.projection = owned_projection;
    result.limit = if (ast.input) |value| value.limit else ast.limit;
    var column_names: [m.max_columns][]const u8 = undefined;
    for (source.schema.columns, 0..) |*column, i| column_names[i] = column.name.slice();
    switch (ast.predicate) {
        .program => |*program| {
            try program.validate();
            result.predicate = .{ .program = .{} };
            const owned = &result.predicate.program;
            errdefer for (owned.instructions[0..owned.count]) |instruction| {
                if (instruction == .atom) freeAtom(allocator, instruction.atom);
            };
            for (program.instructions[0..program.count]) |instruction| {
                owned.instructions[owned.count] = switch (instruction) {
                    .atom => |value| .{ .atom = try lowerAtom(allocator, try program.expand(value), source_qualifier.slice(), column_names[0..source.schema.columns.len]) },
                    .negate => .negate,
                    .conjunction => .conjunction,
                    .disjunction => .disjunction,
                };
                owned.count += 1;
            }
        },
        inline else => |value, tag| {
            const atom = try lowerAtom(allocator, @unionInit(sql.PredicateAtom, @tagName(tag), value), source_qualifier.slice(), column_names[0..source.schema.columns.len]);
            switch (atom) {
                inline else => |item, kind| result.predicate = @unionInit(m.Plan.Predicate, @tagName(kind), item),
            }
        },
    }
    errdefer freePredicate(allocator, &result.predicate);
    try result.validate(source.schema);
}
/// Release only plans returned by this compiler with the same allocator.
/// Canonically decoded plans borrow their input and must not use this function.
pub fn deinit(allocator: std.mem.Allocator, compiled: *const m.Plan) void {
    allocator.free(compiled.projection);
    freePredicate(allocator, &compiled.predicate);
}
fn lowerAtom(allocator: std.mem.Allocator, atom: sql.PredicateAtom, source: []const u8, columns: []const []const u8) !m.Plan.Atom {
    return switch (try @import("SqlLowering.zig").lowerAtom(atom, source, columns)) {
        .all => .all,
        .state => |state| .{ .state = .{ .column = state.column, .value = state.value } },
        .compare => |value| .{ .compare = .{ .column = value.column, .op = value.op, .value = try scalar(allocator, value.literal) } },
    };
}
fn freeAtom(allocator: std.mem.Allocator, atom: m.Plan.Atom) void {
    if (atom == .compare) switch (atom.compare.value) {
        .utf8, .binary => |bytes| allocator.free(bytes),
        else => {},
    };
}
fn freePredicate(allocator: std.mem.Allocator, predicate: *const m.Plan.Predicate) void {
    switch (predicate.*) {
        .program => |*program| for (program.instructions[0..program.count]) |instruction| {
            if (instruction == .atom) freeAtom(allocator, instruction.atom);
        },
        inline else => |value, tag| freeAtom(allocator, @unionInit(m.Plan.Atom, @tagName(tag), value)),
    }
}

fn sameName(a: anytype, b: anytype) bool {
    return std.mem.eql(u8, a.slice(), b.slice());
}
fn ownedName(name: f.model.Name) !m.Name {
    if (name.len > name.bytes.len or !std.meta.eql(name, try f.model.Name.init(name.slice()))) return error.InvalidColumnName;
    return m.Name.init(name.slice());
}
fn resolve(column: sql.Column, qualifier: m.Name, schema: m.Schema) !u8 {
    if (column.qualifier) |name| if (!sameName(name, qualifier)) return error.UnknownQualifier;
    for (schema.columns, 0..) |item, index| if (sameName(item.name, column.name)) return @intCast(index);
    return error.UnknownColumn;
}
fn projection(value: sql.Projection, qualifier: m.Name, schema: m.Schema, output: *[m.max_columns]u8, result: *m.Plan) !void {
    if (value[0] == null) {
        for (value[1..]) |column| if (column != null) return error.InvalidProjection;
        for (0..schema.columns.len) |i| output[i] = @intCast(i);
        result.* = .{ .projection = output[0..schema.columns.len] };
        return;
    }
    var count: usize = 0;
    var names: [m.max_columns]?m.Name = @splat(null);
    for (value) |column| {
        if (column) |selected| {
            const index = try resolve(selected.column, qualifier, schema);
            output[count] = index;
            if (selected.alias) |alias| names[count] = try ownedName(alias);
            count += 1;
        } else {
            for (value[count..]) |remaining| if (remaining != null) return error.InvalidProjection;
            break;
        }
    }
    result.* = .{ .projection = output[0..count], .output_names = names };
    try result.validate(schema);
}
pub fn scalar(allocator: std.mem.Allocator, literal: sql.Literal) !m.Scalar {
    switch (literal) {
        .uint64 => |value| return .{ .uint64 = value },
        .float64 => |value| return .{ .float64 = value },
        else => {},
    }
    const value = try sql.literalCell(literal);
    return switch (value) {
        .null => error.UnsupportedNullComparison,
        .int64 => |v| .{ .int64 = v },
        .boolean => |v| .{ .boolean = v },
        .utf8 => |v| .{ .utf8 = try allocator.dupe(u8, v.slice()) },
        .binary => |v| .{ .binary = try allocator.dupe(u8, v.slice()) },
    };
}
