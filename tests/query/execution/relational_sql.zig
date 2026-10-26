//! Production relational parser consumer for independent three-parser checks.
const std = @import("std");
const f = @import("transit_fuze");
const Column = [2]?[]const u8;
fn column(value: f.RelationalSql.Reference) Column {
    return .{ value.qualifier, value.name };
}
const Output = struct { kind: []const u8, column: ?Column, name: []const u8 };
const Join = struct { kind: []const u8, left: Column, right: Column };
const Instruction = struct { op: []const u8, column: ?Column = null, value: ?i64 = null };
fn emit(allocator: std.mem.Allocator, writer: *std.Io.Writer, text: []const u8) !void {
    var syntax = try f.RelationalSql.parse(allocator, text, null);
    defer syntax.deinit();
    var outputs: [128]Output = undefined;
    for (syntax.selections, 0..) |selection, i| outputs[i] = .{ .kind = @tagName(selection.expression), .column = switch (selection.expression) {
        .count_all => null,
        inline else => |ref| column(ref),
    }, .name = selection.name };
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
                    if (value.value != .literal) return error.UnboundParameters;
                    const cell = try value.value.literal.bind(syntax.arena.allocator(), .int64, null);
                    if (cell != .value or cell.value != .atom or cell.value.atom != .signed) return error.UnsupportedRelationalType;
                    break :result .{ .op = @tagName(value.op), .column = column(value.column), .value = @intCast(cell.value.atom.signed) };
                },
            },
        };
        count += 1;
    };
    const join: ?Join = if (syntax.join) |j| .{ .kind = @tagName(j.kind), .left = column(j.left), .right = column(j.right) } else null;
    try std.json.Stringify.value(.{ .sources = syntax.targets, .outputs = outputs[0..syntax.selections.len], .join = join, .groups = groups[0..syntax.groups.len], .predicate = instructions[0..count] }, .{}, writer);
}
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
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
