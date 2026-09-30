//! M12 syntax lowered to the v1 plan. Source resolution never performs I/O;
//! returned projection/literal slices belong to the supplied allocator.
const std = @import("std");
const f = @import("root.zig");
const m = f.Unified;
const sql = f.Sql;
pub const Source = struct { name: m.Name, schema: m.Schema };
pub fn plan(allocator: std.mem.Allocator, text: []const u8, source: Source) !m.Plan {
    return compile(allocator, try sql.parse(text), source);
}
pub fn compile(allocator: std.mem.Allocator, ast: sql.Ast, source: Source) !m.Plan {
    try source.schema.validate();
    if (!sameName(ast.source, source.name)) return error.UnknownSource;
    if (ast.selection != .rows and ast.limit != null) return error.UnsupportedAggregateLimit;
    if (ast.input != null and ast.selection == .rows) return error.UnsupportedConstruct;
    var input: [m.max_columns]u8 = undefined;
    const input_projection = try projection(if (ast.input) |value| value.projection else .{ null, null }, source.name, source.schema, &input);
    const qualifier = if (ast.input) |value| try m.Name.init(value.alias.slice()) else source.name;
    var selected: [m.max_columns]u8 = undefined;
    var aggregate: m.Plan.Aggregate = .rows;
    const projected = switch (ast.selection) {
        .rows => |value| try projection(value, qualifier, source.schema, &selected),
        .count => blk: {
            aggregate = .count;
            // Count consumes rows; a single validated input column carries the
            // required plan shape without inspecting its value or state.
            selected[0] = input_projection[0];
            break :blk selected[0..1];
        },
        .sum => |column| blk: {
            aggregate = .sum;
            selected[0] = try resolve(column, qualifier, source.schema);
            if (std.mem.indexOfScalar(u8, input_projection, selected[0]) == null) return error.UnknownColumn;
            break :blk selected[0..1];
        },
    };
    const owned_projection = try allocator.dupe(u8, projected);
    errdefer allocator.free(owned_projection);
    var result: m.Plan = .{ .projection = owned_projection, .aggregate = aggregate, .limit = if (ast.input) |value| value.limit else ast.limit };
    result.predicate = switch (ast.predicate) {
        .all => .all,
        .is_null => |column| .{ .state = .{ .column = try resolve(column, source.name, source.schema), .value = .null } },
        .compare => |value| .{ .compare = .{
            .column = try resolve(value.column, source.name, source.schema),
            .op = switch (value.op) {
                .eq => .eq,
                .ne => .ne,
                .lt => .lt,
                .le => .le,
                .gt => .gt,
                .ge => .ge,
            },
            .value = try scalar(allocator, value.literal),
        } },
    };
    errdefer if (result.predicate == .compare) switch (result.predicate.compare.value) {
        .utf8, .binary => |bytes| allocator.free(bytes),
        else => {},
    };
    try result.validate(source.schema);
    return result;
}
fn sameName(a: anytype, b: anytype) bool {
    return std.mem.eql(u8, a.slice(), b.slice());
}
fn resolve(column: sql.Column, qualifier: m.Name, schema: m.Schema) !u8 {
    if (column.qualifier) |name| if (!sameName(name, qualifier)) return error.UnknownQualifier;
    for (schema.columns, 0..) |item, index| if (sameName(item.name, column.name)) return @intCast(index);
    return error.UnknownColumn;
}
fn projection(value: sql.Projection, qualifier: m.Name, schema: m.Schema, output: *[m.max_columns]u8) ![]const u8 {
    if (value[0] == null) {
        if (value[1] != null) return error.InvalidProjection;
        for (0..schema.columns.len) |i| output[i] = @intCast(i);
        return output[0..schema.columns.len];
    }
    output[0] = try resolve(value[0].?, qualifier, schema);
    if (value[1]) |column| {
        output[1] = try resolve(column, qualifier, schema);
        if (output[0] == output[1]) return error.DuplicateProjection;
        return output[0..2];
    }
    return output[0..1];
}
fn scalar(allocator: std.mem.Allocator, literal: sql.Literal) !m.Scalar {
    const value = try sql.literalCell(literal);
    return switch (value) {
        .null => error.UnsupportedNullComparison,
        .int64 => |v| .{ .int64 = v },
        .boolean => |v| .{ .boolean = v },
        .utf8 => |v| .{ .utf8 = try allocator.dupe(u8, v.slice()) },
        .binary => |v| .{ .binary = try allocator.dupe(u8, v.slice()) },
    };
}
