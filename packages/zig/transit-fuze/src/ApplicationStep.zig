//! Typed operands for one ordered instruction. Preparing a step performs no
//! native admission; its host records observations and settles original work
//! before applying a completion or retaining the successor environment.
const std = @import("std");
const a = @import("ApplicationProgram.zig");
const Self = @This();
pub const Value = a.Values.Value;
pub const Field = a.Values.Field;
pub const Cookie = struct { name: []const u8, value: ?Value, max_age: ?Value };
pub const Response = struct {
    request: Value,
    status: u16,
    guard: ?*const a.Expression,
    body: union(enum) { empty, json: Value, location: Value },
    cookies: []const Cookie,
};
pub const Action = union(enum) {
    bind: Value,
    advance: a.Cursor.Advance,
    begin: a.Id,
    commit: a.Id,
    get: struct { target: []const u8, key: Value },
    select: a.Select,
    effect: struct { sink: []const u8, identity: Value, guard: *const a.Expression, kind: enum { form, headers }, fields: []const Field },
    put: struct { target: []const u8, key: Value, value: Value, fields: []const Field, expected: union(enum) { absent, revision: Value } },
    insert: struct { target: []const u8, values: []const Value, conflict_columns: []const []const u8 },
    append: struct { kind: @FieldType(@FieldType(@FieldType(a.Instruction, "value"), "append"), "kind"), target: []const u8, values: []const Value },
    handoff: struct { request: Value, queue: []const u8, effect: Value },
    respond: Response,
    respond_error: struct { request: Value, failure: Value, profile: []const u8 },
    page: struct { select: a.Select, request: Value, profile: []const u8, size: u16 },
    refused: []const u8,
    complete,
};
pub const Prepared = struct { step: u32, instruction: a.Id, action: Action };
pub const Outcome = union(enum) { value: Value, applied };

index: a.Cursor.Index,
bound: a.Types.Bound,
environment: *a.Environment,
scratch: std.mem.Allocator,
native: a.Evaluation.Host,

fn lookup(context: *anyopaque, name: []const u8) !Value {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.environment.lookup(self.index, name) catch |err| switch (err) {
        // SELECT predicates may additionally name the host's current row.
        error.UnknownProgramVariable => self.native.lookup(self.native.context, name),
        else => err,
    };
}
fn evaluate(context: *anyopaque, node: a.Id, operation: a.Evaluation.Operation, arguments: []const Value) !Value {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.native.evaluate(self.native.context, node, operation, arguments);
}
fn condition(context: *anyopaque, value: Value) !bool {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.native.condition(self.native.context, value);
}
pub fn evaluator(self: *Self) a.Evaluation {
    return .{ .scratch = self.scratch, .bound = self.bound.values, .host = .{ .context = self, .lookup = lookup, .evaluate = evaluate, .condition = condition } };
}
fn values(self: *Self, expressions: []const *a.Expression) ![]const Value {
    const result = try self.scratch.alloc(Value, expressions.len);
    for (expressions, result) |expression, *value| value.* = try self.evaluator().evaluate(expression);
    return result;
}
fn fields(self: *Self, expressions: []const a.Field) ![]const Field {
    const result = try self.scratch.alloc(Field, expressions.len);
    for (expressions, result) |expression, *value| value.* = .{ .name = expression.name, .value = try self.evaluator().evaluate(expression.value) };
    return result;
}
pub fn prepare(self: *Self) !Prepared {
    const event = try self.environment.cursor.next(self.index);
    var result: Prepared = .{ .step = self.environment.cursor.step, .instruction = 0, .action = .complete };
    const evaluation = self.evaluator();
    switch (event) {
        .complete => {},
        .page => {
            const page = self.index.program.body.page;
            result.action = .{ .page = .{ .select = page.select, .request = try evaluation.evaluate(page.request), .profile = page.profile, .size = page.size } };
        },
        .enter_atomic => |entry| {
            result.instruction = entry.id;
            result.action = .{ .begin = entry.id };
        },
        .leave_atomic, .leave_scope => |frame| {
            result.instruction = frame.owner;
            result.action = if (event == .leave_atomic) .{ .commit = frame.owner } else .{ .advance = .{ .leave = frame.owner } };
        },
        .instruction => |entry| {
            result.instruction = entry.id;
            result.action = switch (entry.value) {
                .atomic => unreachable,
                .let => |binding| switch (binding.value) {
                    .expression => |expression| .{ .bind = try evaluation.evaluate(expression) },
                    .get => |get| .{ .get = .{ .target = get.target, .key = try evaluation.evaluate(get.key) } },
                    .select => |select| .{ .select = select },
                    .effect => |effect| blk: {
                        if (!try evaluation.condition(try evaluation.evaluate(effect.guard))) break :blk .{ .refused = "EffectGuardRefused" };
                        break :blk .{ .effect = .{ .sink = effect.sink, .identity = try evaluation.evaluate(effect.identity), .guard = effect.guard, .kind = if (effect.request == .form) .form else .headers, .fields = try self.fields(switch (effect.request) {
                            .form, .headers => |request| request,
                        }) } };
                    },
                },
                .require => |require| if (try evaluation.condition(try evaluation.evaluate(require.condition))) .{ .advance = .{ .instruction = entry.id } } else .{ .refused = require.refusal },
                .conditional => |choice| .{ .advance = .{ .branch = .{ .id = entry.id, .yes = try evaluation.condition(try evaluation.evaluate(choice.condition)) } } },
                .put => |put| .{ .put = .{ .target = put.target, .key = try evaluation.evaluate(put.key), .value = try evaluation.evaluate(put.value), .fields = try self.fields(put.fields), .expected = switch (put.expected) {
                    .absent => .absent,
                    .revision => |revision| .{ .revision = try evaluation.evaluate(revision) },
                } } },
                .insert => |insert| .{ .insert = .{ .target = insert.target, .values = try self.values(insert.values), .conflict_columns = insert.conflict_columns } },
                .append => |append| .{ .append = .{ .kind = append.kind, .target = append.target, .values = try self.values(append.values) } },
                .handoff => |handoff| .{ .handoff = .{ .request = try evaluation.evaluate(handoff.request), .queue = handoff.queue, .effect = try evaluation.evaluate(handoff.effect) } },
                .respond => |response| blk: {
                    if (response.guard) |guard| if (!try evaluation.condition(try evaluation.evaluate(guard))) break :blk .{ .refused = "ResponseGuardRefused" };
                    const cookies = try self.scratch.alloc(Cookie, response.cookies.len);
                    for (response.cookies, cookies) |cookie, *value| value.* = .{ .name = cookie.name, .value = if (cookie.value) |node| try evaluation.evaluate(node) else null, .max_age = if (cookie.max_age) |node| try evaluation.evaluate(node) else null };
                    break :blk .{ .respond = .{ .request = try evaluation.evaluate(response.request), .status = response.status, .guard = response.guard, .body = switch (response.body) {
                        .empty => .empty,
                        .json => |node| .{ .json = try evaluation.evaluate(node) },
                        .location => |node| .{ .location = try evaluation.evaluate(node) },
                    }, .cookies = cookies } };
                },
                .respond_error => |response| .{ .respond_error = .{ .request = try evaluation.evaluate(response.request), .failure = try self.environment.lookup(self.index, response.failure), .profile = response.profile } },
            };
        },
    }
    return result;
}
/// The native host calls this only after resolving the original operation. In
/// particular, .commit means a verified committed common decision, never EOF,
/// timeout, successful submission or local transaction preparation.
pub fn finish(self: *Self, step: Prepared, outcome: Outcome) !void {
    try self.transition(step, outcome);
}
/// Compute a private proposed successor without advancing the active cursor or
/// claiming a native outcome. The owner may retain it before a common decision;
/// publication/adoption still requires the original native completion. Values
/// borrow their existing owners until the proposal is encoded.
pub fn propose(self: *const Self, allocator: std.mem.Allocator, step: Prepared, outcome: Outcome) !a.Environment {
    var environment = try self.environment.clone(allocator);
    errdefer environment.deinit();
    var proposal = self.*;
    proposal.environment = &environment;
    try proposal.transition(step, outcome);
    return environment;
}
fn transition(self: *Self, step: Prepared, outcome: Outcome) !void {
    switch (step.action) {
        .get, .select, .effect => {
            if (outcome != .value) return error.ProgramTypeMismatch;
            try self.environment.bind(self.index, self.bound, step.step, step.instruction, outcome.value);
        },
        .bind => |value| {
            if (outcome != .applied) return error.ProgramTypeMismatch;
            try self.environment.bind(self.index, self.bound, step.step, step.instruction, value);
        },
        else => {
            if (outcome != .applied) return error.ProgramTypeMismatch;
            const action: a.Cursor.Advance = switch (step.action) {
                .advance => |action| action,
                .begin => |id| .{ .enter_atomic = id },
                .commit => |id| .{ .leave = id },
                .page => .page,
                .put, .insert, .append, .handoff, .respond, .respond_error => .{ .instruction = step.instruction },
                else => return error.InvalidProgramNode,
            };
            try self.environment.advance(self.index, step.step, action);
        },
    }
}

test "application steps evaluate declared operands and keep common decisions explicit" {
    const t = std.testing;
    var parsed = try a.parse(t.allocator,
        \\CREATE DATAFLOW x FROM QUEUE jobs AS request AS BEGIN
        \\  LET prefix = 'accepted: ';
        \\  IF request.enabled THEN
        \\    BEGIN ATOMIC
        \\      PRODUCE INTO outcomes VALUES (prefix || request.message);
        \\    END;
        \\  ELSE REQUIRE FALSE ELSE 'Disabled'; END IF;
        \\END;
    , null);
    defer parsed.deinit();
    var bound = try a.Types.bind(t.allocator, parsed.program, &.{
        .{ .name = "jobs", .kind = .queue, .fields = &.{ .{ .name = "enabled", .value = .{ .kind = .boolean } }, .{ .name = "message", .value = .{ .kind = .text } } } },
        .{ .name = "outcomes", .kind = .stream, .fields = &.{.{ .name = "message", .value = .{ .kind = .text } }} },
    }, null);
    defer bound.deinit();
    var index = try a.Cursor.Index.init(t.allocator, &parsed.program);
    defer index.deinit();
    var env = try a.Environment.init(t.allocator, index, bound, .{ .record = &.{ .{ .name = "enabled", .value = .{ .boolean = true } }, .{ .name = "message", .value = .{ .text = "hello" } } } });
    defer env.deinit();
    var scratch: std.heap.ArenaAllocator = .init(t.allocator);
    defer scratch.deinit();
    const Native = struct {
        fn lookup(_: *anyopaque, _: []const u8) anyerror!Value {
            return error.UnknownProgramVariable;
        }
        fn evaluate(_: *anyopaque, _: a.Id, _: a.Evaluation.Operation, _: []const Value) anyerror!Value {
            return error.UnexpectedNativeOperation;
        }
        fn condition(_: *anyopaque, _: Value) anyerror!bool {
            return error.UnexpectedNativeOperation;
        }
    };
    var driver: Self = .{ .index = index, .bound = bound, .environment = &env, .scratch = scratch.allocator(), .native = .{ .context = &env, .lookup = Native.lookup, .evaluate = Native.evaluate, .condition = Native.condition } };
    const assignment = try driver.prepare();
    try driver.finish(assignment, .applied);
    try t.expectError(error.InvalidProgramNode, driver.finish(assignment, .applied));
    try driver.finish(try driver.prepare(), .applied);
    const begin = try driver.prepare();
    try t.expect(begin.action == .begin);
    try driver.finish(begin, .applied);
    const append = try driver.prepare();
    try t.expectEqualStrings("accepted: hello", append.action.append.values[0].text);
    try driver.finish(append, .applied);
    const commit = try driver.prepare();
    try t.expect(commit.action == .commit);
    try t.expect(env.cursor.atomic() != null);
    var proposed = try driver.propose(t.allocator, commit, .applied);
    defer proposed.deinit();
    try t.expect(proposed.cursor.atomic() == null);
    try t.expect(env.cursor.atomic() != null);
    try t.expectEqual(env.cursor.step + 1, proposed.cursor.step);
    try driver.finish(commit, .applied);
    try t.expect(env.cursor.atomic() == null);
    try driver.finish(try driver.prepare(), .applied);
    try driver.finish(try driver.prepare(), .applied);
    try t.expect((try driver.prepare()).action == .complete);
}
