//! Production relational parser consumer for independent three-parser checks.
const std = @import("std");
const f = @import("transit_fuze");
const Column = [2]?[]const u8;
fn column(value: f.RelationalSql.Reference) Column {
    return .{ value.qualifier, value.name };
}
const ScalarSyntax = @FieldType(@FieldType(f.RelationalSql.Expression, "scalar"), "syntax");
const Node = std.meta.Elem(@FieldType(ScalarSyntax, "nodes"));
const ScalarNode = union(enum) {
    input: Column,
    decimal_binary: @FieldType(Node, "decimal_binary"),
    decimal_rescale: @FieldType(Node, "decimal_rescale"),
    range_binary: @FieldType(Node, "range_binary"),
    vector_distance: @FieldType(Node, "vector_distance"),
    temporal: @FieldType(Node, "temporal"),
};
const Expr = struct { kind: []const u8, column: ?Column = null, scalar: ?[]const ScalarNode = null };
fn expr(allocator: std.mem.Allocator, value: f.RelationalSql.Expression) !Expr {
    return switch (value) {
        .count_all => .{ .kind = "count_all" },
        inline .column, .sum, .count => |ref, tag| .{ .kind = @tagName(tag), .column = column(ref) },
        inline .scalar, .sum_scalar, .count_scalar => |scalar, tag| blk: {
            const nodes = try allocator.alloc(ScalarNode, scalar.syntax.nodes.len);
            for (scalar.syntax.nodes, nodes) |node, *out| out.* = switch (node) {
                .input => |ref| .{ .input = column(ref) },
                inline else => |payload, kind| @unionInit(ScalarNode, @tagName(kind), payload),
            };
            break :blk .{ .kind = @tagName(tag), .scalar = nodes };
        },
    };
}
const Output = struct { kind: []const u8, column: ?Column, scalar: ?[]const ScalarNode, name: []const u8 };
const Join = struct { kind: []const u8, left: Column, right: Column };
const Instruction = struct { op: []const u8, column: ?Column = null, value: std.json.Value = .null };
const HavingInstruction = struct { op: []const u8, expression: ?Expr = null, value: std.json.Value = .null };
const OrderBy = struct { expression: Expr, direction: []const u8, nulls: []const u8 };
fn emit(allocator: std.mem.Allocator, writer: *std.Io.Writer, text: []const u8) !void {
    var syntax = try f.RelationalSql.parse(allocator, text, null);
    defer syntax.deinit();
    var outputs: [128]Output = undefined;
    const arena = syntax.arena.allocator();
    for (syntax.selections, 0..) |selection, i| {
        const expression = try expr(arena, selection.expression);
        outputs[i] = .{ .kind = expression.kind, .column = expression.column, .scalar = expression.scalar, .name = selection.name };
    }
    if (syntax.star) outputs[0] = .{ .kind = "star", .column = if (syntax.star_qualifier) |qualifier| .{ qualifier.name, "*" } else null, .scalar = null, .name = "*" };
    var groups: [128]Column = undefined;
    for (syntax.groups, 0..) |ref, i| groups[i] = column(ref);
    var instructions: [64]Instruction = undefined;
    var count: usize = 0;
    if (syntax.predicate) |predicate| for (predicate.instructions) |instruction| {
        instructions[count] = switch (instruction) {
            .conjunction => .{ .op = "and" },
            .disjunction => .{ .op = "or" },
            .negate => .{ .op = "not" },
            .atom => |atom| switch (atom) {
                .state => |state| if (state.value == .null) .{ .op = "is_null", .column = column(state.column) } else return error.UnsupportedRelationalPredicate,
                .compare => |value| result: {
                    if (value.value == .parameter) break :result .{ .op = @tagName(value.op), .column = column(value.column), .value = .{ .string = try std.fmt.allocPrint(arena, "${d}", .{value.value.parameter.index}) } };
                    const cell = try value.value.literal.bind(syntax.arena.allocator(), .int64, null);
                    if (cell != .value or cell.value != .atom or cell.value.atom != .signed) return error.UnsupportedRelationalType;
                    break :result .{ .op = @tagName(value.op), .column = column(value.column), .value = .{ .integer = @intCast(cell.value.atom.signed) } };
                },
            },
        };
        count += 1;
    };
    var having: [64]HavingInstruction = undefined;
    var having_count: usize = 0;
    for (syntax.having) |instruction| {
        having[having_count] = switch (instruction) {
            .conjunction => .{ .op = "and" },
            .disjunction => .{ .op = "or" },
            .negate => .{ .op = "not" },
            .atom => |atom| switch (atom) {
                .state => |state| if (state.value == .null) .{ .op = "is_null", .expression = try expr(arena, state.expression) } else return error.UnsupportedRelationalPredicate,
                .compare => |value| result: {
                    if (value.value == .parameter) break :result .{ .op = @tagName(value.op), .expression = try expr(arena, value.expression), .value = .{ .string = try std.fmt.allocPrint(arena, "${d}", .{value.value.parameter.index}) } };
                    const cell = try value.value.literal.bind(syntax.arena.allocator(), .int64, null);
                    if (cell != .value or cell.value != .atom or cell.value.atom != .signed) return error.UnsupportedRelationalType;
                    break :result .{ .op = @tagName(value.op), .expression = try expr(arena, value.expression), .value = .{ .integer = @intCast(cell.value.atom.signed) } };
                },
            },
        };
        having_count += 1;
    }
    var order_by: [128]OrderBy = undefined;
    for (syntax.order_by, 0..) |item, i| order_by[i] = .{
        .expression = try expr(arena, item.expression),
        .direction = @tagName(item.direction),
        .nulls = @tagName(item.nulls),
    };
    const join: ?Join = if (syntax.join) |j| .{ .kind = @tagName(j.kind), .left = column(j.left), .right = column(j.right) } else null;
    try std.json.Stringify.value(.{
        .sources = syntax.targets,
        .outputs = outputs[0..if (syntax.star) 1 else syntax.selections.len],
        .join = join,
        .groups = groups[0..syntax.groups.len],
        .predicate = instructions[0..count],
        .having = having[0..having_count],
        .order_by = order_by[0..syntax.order_by.len],
        .limit = if (syntax.limit_parameter) |site| std.json.Value{ .string = try std.fmt.allocPrint(arena, "${d}", .{site.index}) } else if (syntax.limit) |value| std.json.Value{ .integer = @intCast(value) } else std.json.Value.null,
    }, .{}, writer);
}
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const raw_args = try init.minimal.args.toSlice(allocator);
    const args = if (raw_args.len == 3) raw_args[1..] else raw_args;
    if (args.len != 2) return error.Usage;
    const cases = try std.json.parseFromSlice([]const []const u8, allocator, try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(4 * 1024 * 1024)), .{});
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (cases.value) |text| {
        emit(init.gpa, &stdout.interface, text) catch |err| try std.json.Stringify.value(.{ .err = @errorName(err) }, .{}, &stdout.interface);
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}
