//! Bounded ordered-program expressions over validated native values. No clocks,
//! entropy, secrets, HTTP, database access or durable effects live in Fuze.
//! The host records observations under the instruction's original identity.
const std = @import("std");
const a = @import("ApplicationProgram.zig");
pub const Value = @import("ApplicationValue.zig").Value;
const Self = @This();
pub const Operation = union(enum) {
    function: a.Function,
    unary: a.Unary,
    binary: a.Binary,
    protect,
};
pub const Host = struct {
    context: *anyopaque,
    lookup: *const fn (*anyopaque, []const u8) anyerror!Value,
    evaluate: *const fn (*anyopaque, a.Id, Operation, []const Value) anyerror!Value,
    /// A protected condition may guide control flow, never ordinary output.
    condition: *const fn (*anyopaque, Value) anyerror!bool,
};
/// Reusable turn arena. Results borrow it, the program, or native input owners;
/// the execution owner retains a checkpoint before resetting scratch memory.
scratch: std.mem.Allocator,
bound: []const ?a.Types.Value,
host: Host,

pub fn evaluate(self: Self, node: *const a.Expression) !Value {
    return self.expression(node, 0);
}
pub fn condition(self: Self, value: Value) !bool {
    if (value == .null) return false;
    if (value == .boolean) return value.boolean;
    if (value == .sealed and value.sealed.kind == .boolean) return self.host.condition(self.host.context, value);
    return error.ProgramTypeMismatch;
}
fn expression(self: Self, node: *const a.Expression, depth: usize) anyerror!Value {
    if (depth > a.max_depth) return error.ProgramTooDeep;
    if (node.id == 0 or node.id >= self.bound.len) return error.InvalidProgramNode;
    const expected = self.bound[node.id] orelse return error.InvalidProgramNode;
    var result: Value = switch (node.value) {
        .null => .null,
        .boolean => |value| .{ .boolean = value },
        .integer => |value| .{ .integer = value },
        .text => |value| .{ .text = value },
        .name => |name| try self.host.lookup(self.host.context, name),
        .field => |field| try (try self.expression(field.base, depth + 1)).field(field.name),
        .call => |call| blk: {
            if (call.arguments.len > a.max_arguments) return error.ProgramArgumentMismatch;
            var arguments: [a.max_arguments]Value = undefined;
            for (call.arguments, arguments[0..call.arguments.len], 0..) |argument, *value, index| {
                // This operand names an exact bound resource, not a LET value.
                value.* = if (call.function == .current_revision and index == 0 and argument.value == .name)
                    .{ .text = argument.value.name }
                else
                    try self.expression(argument, depth + 1);
            }
            break :blk try self.host.evaluate(self.host.context, node.id, .{ .function = call.function }, arguments[0..call.arguments.len]);
        },
        .unary => |unary| blk: {
            const operand = try self.expression(unary.operand, depth + 1);
            if (operand.protected()) break :blk try self.host.evaluate(self.host.context, node.id, .{ .unary = unary.operator }, &.{operand});
            break :blk try applyUnary(unary.operator, operand);
        },
        .binary => |binary| blk: {
            const left = try self.expression(binary.left, depth + 1);
            if (left.kind() == .boolean and ((binary.operator == .and_ and !try self.condition(left)) or
                (binary.operator == .or_ and try self.condition(left)))) break :blk left;
            const right = try self.expression(binary.right, depth + 1);
            if (left.protected() or right.protected())
                break :blk try self.host.evaluate(self.host.context, node.id, .{ .binary = binary.operator }, &.{ left, right });
            break :blk try self.applyBinary(binary.operator, left, right);
        },
        .case => |choice| if (try self.condition(try self.expression(choice.condition, depth + 1)))
            try self.expression(choice.yes, depth + 1)
        else
            try self.expression(choice.no, depth + 1),
        .text_cast => |operand| blk: {
            const value = try self.expression(operand, depth + 1);
            try value.public();
            break :blk switch (value) {
                .null => .null,
                .text => value,
                .integer => |integer| .{ .text = try std.fmt.allocPrint(self.scratch, "{d}", .{integer}) },
                .uuid => |uuid| .{ .text = try std.fmt.allocPrint(self.scratch, "{x}-{x}-{x}-{x}-{x}", .{ uuid[0..4], uuid[4..6], uuid[6..8], uuid[8..10], uuid[10..16] }) },
                else => return error.ProgramTypeMismatch,
            };
        },
        .row => |values| blk: {
            if (values.len > a.max_arguments) return error.ProgramTooComplex;
            const fields = try self.scratch.alloc(@import("ApplicationValue.zig").Field, values.len);
            for (values, fields) |value, *field| field.* = .{ .name = "", .value = try self.expression(value, depth + 1) };
            break :blk .{ .record = fields };
        },
    };
    // Short-circuiting and CASE can choose a public literal under a protected
    // condition. Preserve its classification as a native transient reference.
    if (expected.protected and !result.protected() and result != .null)
        result = try self.host.evaluate(self.host.context, node.id, .protect, &.{result});
    try result.validate(expected);
    return result;
}

/// Shared scalar semantics for an authorized host that resolves a protected
/// scalar privately and seals the result again. This boundary never redeems a
/// reference and refuses protected values supplied directly.
pub fn applyUnary(operator: a.Unary, operand: Value) !Value {
    try operand.public();
    return switch (operator) {
        .is_null => .{ .boolean = operand == .null },
        .is_not_null => .{ .boolean = operand != .null },
        .not_ => if (operand == .null) .null else if (operand == .boolean) .{ .boolean = !operand.boolean } else return error.ProgramTypeMismatch,
        .negate => if (operand == .null) .null else if (operand == .integer) .{ .integer = try std.math.negate(operand.integer) } else return error.ProgramTypeMismatch,
    };
}
pub fn applyBinary(self: Self, operator: a.Binary, left: Value, right: Value) !Value {
    try left.public();
    try right.public();
    if (operator == .and_ or operator == .or_) {
        if ((left != .null and left != .boolean) or (right != .null and right != .boolean)) return error.ProgramTypeMismatch;
        if (operator == .and_) {
            if ((left == .boolean and !left.boolean) or (right == .boolean and !right.boolean)) return .{ .boolean = false };
            return if (left == .null or right == .null) .null else .{ .boolean = true };
        }
        if ((left == .boolean and left.boolean) or (right == .boolean and right.boolean)) return .{ .boolean = true };
        return if (left == .null or right == .null) .null else .{ .boolean = false };
    }
    if (left == .null or right == .null) return .null;
    if (operator == .concatenate) {
        if (left != .text or right != .text) return error.ProgramTypeMismatch;
        if (try std.math.add(usize, left.text.len, right.text.len) > 1024 * 1024) return error.ProgramTooComplex;
        return .{ .text = try std.mem.concat(self.scratch, u8, &.{ left.text, right.text }) };
    }
    if (operator == .add or operator == .subtract) {
        const first = if (left == .integer) left.integer else if (left == .timestamp) left.timestamp else return error.ProgramTypeMismatch;
        const second = if (left == .integer and right == .integer) right.integer else if (left == .timestamp and right == .duration) right.duration else return error.ProgramTypeMismatch;
        const value = if (operator == .add) try std.math.add(i64, first, second) else try std.math.sub(i64, first, second);
        return if (left == .timestamp) .{ .timestamp = value } else .{ .integer = value };
    }
    if (left.kind() != right.kind()) return error.ProgramTypeMismatch;
    const order: std.math.Order = switch (left) {
        .boolean => |value| std.math.order(@intFromBool(value), @intFromBool(right.boolean)),
        .integer => |value| std.math.order(value, right.integer),
        .timestamp => |value| std.math.order(value, right.timestamp),
        .duration => |value| std.math.order(value, right.duration),
        .text => |value| std.mem.order(u8, value, right.text),
        .binary => |value| std.mem.order(u8, value, right.binary),
        .uuid => |value| std.mem.order(u8, &value, &right.uuid),
        else => return error.ProgramTypeMismatch,
    };
    return .{ .boolean = switch (operator) {
        .equal => order == .eq,
        .not_equal => order != .eq,
        .less => order == .lt,
        .less_equal => order != .gt,
        .greater => order == .gt,
        .greater_equal => order != .lt,
        else => return error.ProgramTypeMismatch,
    } };
}

const Fixture = struct {
    fn lookup(_: *anyopaque, _: []const u8) !Value {
        return error.UnknownProgramVariable;
    }
    fn evaluate(_: *anyopaque, _: a.Id, _: Operation, _: []const Value) !Value {
        return error.UnexpectedNativeObservation;
    }
    fn condition(_: *anyopaque, _: Value) !bool {
        return error.UnexpectedNativeObservation;
    }
    fn run(allocator: std.mem.Allocator, sql: []const u8) !Value {
        var program = try a.parse(allocator, sql, null);
        defer program.deinit();
        var bound = try a.Types.bind(allocator, program.program, &.{.{ .name = "jobs", .kind = .queue, .fields = &.{} }}, null);
        defer bound.deinit();
        var context: u8 = 0;
        const evaluator: Self = .{
            .scratch = allocator,
            .bound = bound.values,
            .host = .{ .context = &context, .lookup = Fixture.lookup, .evaluate = Fixture.evaluate, .condition = Fixture.condition },
        };
        // Test cases return fixed values. Production evaluation borrows the
        // definition/environment and uses the caller's reusable scratch arena.
        return evaluator.evaluate(program.program.body.instructions[0].value.let.value.expression);
    }
};

test "application expressions implement NULL control flow and checked integer arithmetic" {
    const t = std.testing;
    const cases = .{
        .{ "NULL AND FALSE", Value{ .boolean = false } },
        .{ "NULL AND TRUE", @as(Value, .null) },
        .{ "NULL OR TRUE", Value{ .boolean = true } },
        .{ "NULL OR FALSE", @as(Value, .null) },
        .{ "NOT NULL", @as(Value, .null) },
        .{ "NULL = NULL", @as(Value, .null) },
        .{ "NULL IS NULL", Value{ .boolean = true } },
        .{ "NULL IS NOT NULL", Value{ .boolean = false } },
        .{ "CASE WHEN TRUE THEN NULL ELSE 1 END", @as(Value, .null) },
        .{ "CASE WHEN NULL THEN 2 ELSE 1 END", Value{ .integer = 1 } },
        .{ "FALSE AND SECRET_CURRENT(SECRET('must-not-run'))", Value{ .boolean = false } },
        .{ "TRUE OR SECRET_CURRENT(SECRET('must-not-run'))", Value{ .boolean = true } },
        .{ "(1 + 2) - 3", Value{ .integer = 0 } },
    };
    inline for (cases) |entry| {
        try t.expectEqualDeep(entry[1], try Fixture.run(t.allocator, "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN LET result = " ++ entry[0] ++ "; END;"));
    }
    try t.expectError(error.Overflow, Fixture.run(t.allocator, "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN LET result = 9223372036854775807 + 1; END;"));
    try t.expectError(error.UnexpectedNativeObservation, Fixture.run(t.allocator, "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN LET result = NOW(); END;"));
}

test "application expression results cannot strip a protected native classification" {
    const BadHost = struct {
        fn evaluate(_: *anyopaque, _: a.Id, _: Operation, _: []const Value) !Value {
            return .{ .text = "unsealed" };
        }
    };
    const t = std.testing;
    var program = try a.parse(t.allocator, "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN LET secret = SECRET('key'); END;", null);
    defer program.deinit();
    var bound = try a.Types.bind(t.allocator, program.program, &.{.{ .name = "jobs", .kind = .queue, .fields = &.{} }}, null);
    defer bound.deinit();
    var context: u8 = 0;
    const evaluator: Self = .{ .scratch = t.allocator, .bound = bound.values, .host = .{ .context = &context, .lookup = Fixture.lookup, .evaluate = BadHost.evaluate, .condition = Fixture.condition } };
    try t.expectError(error.ProgramTypeMismatch, evaluator.evaluate(program.program.body.instructions[0].value.let.value.expression));
}

test "application protected conditions short circuit and seal their selected public values" {
    const Native = struct {
        calls: usize = 0,
        fn evaluate(context: *anyopaque, _: a.Id, operation: Operation, args: []const Value) !Value {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.calls += 1;
            switch (operation) {
                .function => |function| {
                    if (function != .secret or args.len != 1 or args[0] != .text or !std.mem.eql(u8, args[0].text, "key")) return error.UnexpectedNativeObservation;
                    return .{ .secret = .{ .reference = .{ .id = @splat(9) }, .revision = "revision" } };
                },
                .unary => |operator| {
                    if (args.len != 1 or args[0] != .secret or (operator != .is_null and operator != .is_not_null)) return error.UnexpectedNativeObservation;
                    return .{ .sealed = .{ .kind = .boolean, .reference = .{ .id = @splat(if (operator == .is_null) 1 else 2) } } };
                },
                .protect => {
                    if (args.len != 1 or args[0] != .text or !std.mem.eql(u8, args[0].text, "selected")) return error.UnexpectedNativeObservation;
                    return .{ .sealed = .{ .kind = .text, .reference = .{ .id = @splat(3) } } };
                },
                else => return error.UnexpectedNativeObservation,
            }
        }
        fn condition(context: *anyopaque, value: Value) !bool {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.calls += 1;
            if (value != .sealed or value.sealed.kind != .boolean) return error.UnexpectedNativeObservation;
            return value.sealed.reference.id[0] == 2;
        }
    };
    const t = std.testing;
    inline for (.{ "(SECRET('key') IS NULL) AND (SECRET('must-not-run') IS NOT NULL)", "CASE WHEN SECRET('key') IS NOT NULL THEN 'selected' ELSE 'other' END" }, 0..) |sql, index| {
        var program = try a.parse(t.allocator, "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN LET value = " ++ sql ++ "; END;", null);
        defer program.deinit();
        var bound = try a.Types.bind(t.allocator, program.program, &.{.{ .name = "jobs", .kind = .queue, .fields = &.{} }}, null);
        defer bound.deinit();
        var native: Native = .{};
        const evaluator: Self = .{ .scratch = t.allocator, .bound = bound.values, .host = .{ .context = &native, .lookup = Fixture.lookup, .evaluate = Native.evaluate, .condition = Native.condition } };
        const result = try evaluator.evaluate(program.program.body.instructions[0].value.let.value.expression);
        try t.expectEqual(@as(usize, if (index == 0) 3 else 4), native.calls);
        try t.expect(result == .sealed);
        try t.expectEqual(@as(a.Types.Kind, if (index == 0) .boolean else .text), result.kind());
        try t.expectError(error.ProtectedProgramValue, result.public());
    }
}
