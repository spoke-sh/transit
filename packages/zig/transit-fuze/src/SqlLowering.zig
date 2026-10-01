//! Source-independent lowering of the shared SQL AST into column ordinals.
//! Logical type admission belongs to the selected typed plan profile.
const std = @import("std");
const sql = @import("Sql.zig");
const finite = @import("Finite.zig");
pub const Shape = struct {
    projection: []const u8,
    aggregate: finite.Aggregate,
    limit: ?u64,
    predicate: union(enum) {
        all,
        state: struct { column: u8, value: @import("Scalar.zig").State },
        compare: struct { column: u8, op: finite.Comparison, literal: sql.Literal },
    },
};
pub fn lower(ast: sql.Ast, source: []const u8, columns: []const []const u8, input: []u8, output: []u8) !Shape {
    if (!std.mem.eql(u8, ast.source.slice(), source)) return error.UnknownSource;
    if (ast.selection != .rows and ast.limit != null) return error.UnsupportedAggregateLimit;
    if (ast.input != null and ast.selection == .rows) return error.UnsupportedConstruct;
    if (ast.output_alias != null) return error.UnsupportedOutputAlias;
    const source_name = ast.source_alias orelse ast.source;
    const source_qualifier = source_name.slice();
    const input_projection = try project(if (ast.input) |value| value.projection else @splat(null), source_qualifier, columns, input);
    const qualifier_name = if (ast.input) |value| value.alias else source_name;
    const qualifier = qualifier_name.slice();
    var aggregate: finite.Aggregate = .rows;
    const projection = switch (ast.selection) {
        .rows => |value| try project(value, qualifier, columns, output),
        .count => blk: {
            aggregate = .count;
            output[0] = input_projection[0];
            break :blk output[0..1];
        },
        .sum => |column| blk: {
            aggregate = .sum;
            output[0] = try resolve(column, qualifier, columns);
            if (std.mem.indexOfScalar(u8, input_projection, output[0]) == null) return error.UnknownColumn;
            break :blk output[0..1];
        },
    };
    return .{
        .projection = projection,
        .aggregate = aggregate,
        .limit = if (ast.input) |value| value.limit else ast.limit,
        .predicate = switch (ast.predicate) {
            .program => return error.UnsupportedCompoundPredicate,
            inline else => |value, tag| try lowerAtom(@unionInit(sql.PredicateAtom, @tagName(tag), value), source_qualifier, columns),
        },
    };
}
/// Shared column scope and operator binding for native and local file profiles.
/// The selected plan owns literal conversion and type admission.
pub fn lowerAtom(atom: sql.PredicateAtom, source: []const u8, columns: []const []const u8) !@FieldType(Shape, "predicate") {
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
fn project(value: sql.Projection, source: []const u8, columns: []const []const u8, output: []u8) ![]const u8 {
    if (columns.len == 0 or columns.len > output.len or columns.len > 255) return error.InvalidColumnCount;
    if (value[0] == null) {
        for (value[1..]) |column| if (column != null) return error.InvalidProjection;
        for (0..columns.len) |i| output[i] = @intCast(i);
        return output[0..columns.len];
    }
    var count: usize = 0;
    for (value) |column| {
        if (column) |selected| {
            if (count == output.len) return error.InvalidProjection;
            if (selected.alias != null) return error.UnsupportedOutputAlias;
            const index = try resolve(selected.column, source, columns);
            if (std.mem.indexOfScalar(u8, output[0..count], index) != null) return error.DuplicateProjection;
            output[count] = index;
            count += 1;
        } else {
            for (value[count..]) |remaining| if (remaining != null) return error.InvalidProjection;
            break;
        }
    }
    return output[0..count];
}
