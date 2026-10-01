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
    if (ast.selection == .rows and ast.output_alias != null) return error.InvalidOutputNames;
    const source_qualifier = if (ast.source_alias) |alias| try ownedName(alias) else source.name;
    var input: [m.max_columns]u8 = undefined;
    const input_plan = try projection(if (ast.input) |value| value.projection else @splat(null), source_qualifier, source.schema, &input);
    var input_columns: [m.max_columns]m.Column = undefined;
    const input_schema = try input_plan.outputSchema(source.schema, &input_columns);
    const qualifier = if (ast.input) |value| try ownedName(value.alias) else source_qualifier;
    var selected: [m.max_columns]u8 = undefined;
    var result: m.Plan = switch (ast.selection) {
        .rows => |value| try projection(value, qualifier, source.schema, &selected),
        .count => blk: {
            // Count consumes rows; a single validated input column carries the
            // required plan shape without inspecting its value or state.
            selected[0] = input_plan.projection[0];
            break :blk .{ .projection = selected[0..1], .aggregate = .count };
        },
        .sum => |column| blk: {
            const index = try resolve(column, qualifier, input_schema);
            selected[0] = input_plan.projection[index];
            break :blk .{ .projection = selected[0..1], .aggregate = .sum };
        },
    };
    if (ast.output_alias) |alias| result.output_names[0] = try ownedName(alias);
    const owned_projection = try allocator.dupe(u8, result.projection);
    errdefer allocator.free(owned_projection);
    result.projection = owned_projection;
    result.limit = if (ast.input) |value| value.limit else ast.limit;
    result.predicate = switch (ast.predicate) {
        .all => .all,
        .state => |state| .{ .state = .{ .column = try resolve(state.column, source_qualifier, source.schema), .value = state.value } },
        .compare => |value| .{ .compare = .{
            .column = try resolve(value.column, source_qualifier, source.schema),
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
fn ownedName(name: f.model.Name) !m.Name {
    if (name.len > name.bytes.len or !std.meta.eql(name, try f.model.Name.init(name.slice()))) return error.InvalidColumnName;
    return m.Name.init(name.slice());
}
fn resolve(column: sql.Column, qualifier: m.Name, schema: m.Schema) !u8 {
    if (column.qualifier) |name| if (!sameName(name, qualifier)) return error.UnknownQualifier;
    for (schema.columns, 0..) |item, index| if (sameName(item.name, column.name)) return @intCast(index);
    return error.UnknownColumn;
}
fn projection(value: sql.Projection, qualifier: m.Name, schema: m.Schema, output: *[m.max_columns]u8) !m.Plan {
    if (value[0] == null) {
        for (value[1..]) |column| if (column != null) return error.InvalidProjection;
        for (0..schema.columns.len) |i| output[i] = @intCast(i);
        return .{ .projection = output[0..schema.columns.len] };
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
    const result: m.Plan = .{ .projection = output[0..count], .output_names = names };
    try result.validate(schema);
    return result;
}
fn scalar(allocator: std.mem.Allocator, literal: sql.Literal) !m.Scalar {
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
