//! Source-independent lowering of the shared SQL AST into column ordinals.
//! Logical type admission belongs to the selected typed plan profile.
const std = @import("std");
const sql = @import("Sql.zig");
const finite = @import("Finite.zig");
pub const Atom = union(enum) {
    all,
    state: struct { column: u8, value: @import("Scalar.zig").State },
    compare: struct { column: u8, op: finite.Comparison, literal: sql.Literal },
};
pub const OutputNames = [@import("Unified.zig").max_columns]?@import("model.zig").Name;
pub const Projection = struct {
    columns: []const u8,
    names: OutputNames = @splat(null),
    pub fn name(self: *const Projection, index: usize, source_columns: []const []const u8) []const u8 {
        if (index < self.names.len) if (self.names[index]) |*alias| return alias.slice();
        return source_columns[self.columns[index]];
    }
};
pub const Shape = struct {
    projection: []const u8,
    output_names: OutputNames,
    input: ?Projection,
    aggregate: finite.Aggregate,
    limit: ?u64,
    predicate: union(enum) {
        all,
        state: @FieldType(Atom, "state"),
        compare: @FieldType(Atom, "compare"),
        // Borrows the caller-owned AST until typed lowering finishes.
        program: *const sql.PredicateProgram,
    },
};
pub fn lower(ast: *const sql.Ast, source: []const u8, columns: []const []const u8, input: []u8, output: []u8) !Shape {
    if (!std.mem.eql(u8, ast.source.slice(), source)) return error.UnknownSource;
    if (ast.selection != .rows and ast.limit != null) return error.UnsupportedAggregateLimit;
    if (ast.input != null and ast.selection == .rows) return error.UnsupportedConstruct;
    if (ast.selection == .rows and ast.output_alias != null) return error.InvalidOutputNames;
    if (columns.len == 0 or columns.len > input.len or columns.len > 128) return error.InvalidColumnCount;
    const source_name = ast.source_alias orelse ast.source;
    const source_qualifier = source_name.slice();
    const input_projection: ?Projection = if (ast.input) |value| try project(value.projection, source_qualifier, columns, input) else null;
    var input_names: [128][]const u8 = undefined;
    const input_columns = if (input_projection) |*projected| blk: {
        for (0..projected.columns.len) |i| input_names[i] = projected.name(i, columns);
        break :blk input_names[0..projected.columns.len];
    } else columns;
    const qualifier_name = if (ast.input) |value| value.alias else source_name;
    const qualifier = qualifier_name.slice();
    var aggregate: finite.Aggregate = .rows;
    var projection: Projection = switch (ast.selection) {
        .rows => |value| try project(value, qualifier, columns, output),
        .count => blk: {
            aggregate = .count;
            if (output.len == 0) return error.InvalidProjection;
            output[0] = if (input_projection) |projected| projected.columns[0] else 0;
            break :blk .{ .columns = output[0..1] };
        },
        .sum => |column| blk: {
            aggregate = .sum;
            if (output.len == 0) return error.InvalidProjection;
            const index = try resolve(column, qualifier, input_columns);
            output[0] = if (input_projection) |projected| projected.columns[index] else index;
            break :blk .{ .columns = output[0..1] };
        },
    };
    if (ast.output_alias) |alias| projection.names[0] = try validName(alias);
    return .{
        .projection = projection.columns,
        .output_names = projection.names,
        .input = input_projection,
        .aggregate = aggregate,
        .limit = if (ast.input) |value| value.limit else ast.limit,
        .predicate = switch (ast.predicate) {
            .program => |*program| .{ .program = program },
            inline else => |value, tag| blk: {
                const atom = try lowerAtom(@unionInit(sql.PredicateAtom, @tagName(tag), value), source_qualifier, columns);
                break :blk switch (atom) {
                    inline else => |item, kind| @unionInit(@FieldType(Shape, "predicate"), @tagName(kind), item),
                };
            },
        },
    };
}
/// Shared column scope and operator binding for native and local file profiles.
/// The selected plan owns literal conversion and type admission.
pub fn lowerAtom(atom: sql.PredicateAtom, source: []const u8, columns: []const []const u8) !Atom {
    return switch (atom) {
        .all => .all,
        .state => |state| .{ .state = .{ .column = try resolve(state.column, source, columns), .value = state.value } },
        .compare => |value| .{ .compare = .{ .column = try resolve(value.column, source, columns), .op = value.op, .literal = value.literal } },
    };
}

fn resolve(column: sql.Column, source: []const u8, columns: []const []const u8) !u8 {
    if (column.qualifier) |qualifier| if (!std.mem.eql(u8, qualifier.slice(), source)) return error.UnknownQualifier;
    for (columns, 0..) |name, i| if (std.mem.eql(u8, name, column.name.slice())) return @intCast(i);
    return error.UnknownColumn;
}
fn validName(name: @import("model.zig").Name) !@import("model.zig").Name {
    if (name.len > name.bytes.len or !std.meta.eql(name, try @import("model.zig").Name.init(name.slice()))) return error.InvalidColumnName;
    return name;
}
fn project(value: sql.Projection, source: []const u8, columns: []const []const u8, output: []u8) !Projection {
    if (columns.len == 0 or columns.len > output.len or columns.len > 255) return error.InvalidColumnCount;
    if (value[0] == null) {
        for (value[1..]) |column| if (column != null) return error.InvalidProjection;
        for (0..columns.len) |i| output[i] = @intCast(i);
        return .{ .columns = output[0..columns.len] };
    }
    var count: usize = 0;
    var result: Projection = .{ .columns = output };
    for (value) |column| {
        if (column) |selected| {
            if (count == output.len) return error.InvalidProjection;
            const index = try resolve(selected.column, source, columns);
            output[count] = index;
            if (selected.alias) |alias| result.names[count] = try validName(alias);
            for (0..count) |previous| {
                if (index == output[previous] and std.meta.eql(result.names[count], result.names[previous])) return error.DuplicateProjection;
                if (std.mem.eql(u8, result.name(count, columns), result.name(previous, columns))) return error.DuplicateColumn;
            }
            count += 1;
        } else {
            for (value[count..]) |remaining| if (remaining != null) return error.InvalidProjection;
            break;
        }
    }
    result.columns = output[0..count];
    return result;
}
