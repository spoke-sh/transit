//! Frozen operands for one ordered effect. These values contain no AST pointers
//! or credential bytes. Recovery reattaches the original immutable guard without
//! evaluating the request expressions a second time.
const std = @import("std");
const q = @import("root.zig");
const a = q.fuze.ApplicationProgram;
const Self = @This();

sink: []const u8,
operation: [16]u8,
kind: enum { form, headers },
fields: []const a.Values.Field,

/// Borrows the prepared values until the owning continuation is encoded.
pub fn freeze(index: a.Cursor.Index, bound: a.Types.Bound, step: a.Step.Prepared) !Self {
    if (step.action != .effect or step.action.effect.identity != .uuid) return error.InvalidApplicationEffect;
    const effect = step.action.effect;
    const result: Self = .{ .sink = effect.sink, .operation = effect.identity.uuid, .kind = if (effect.kind == .form) .form else .headers, .fields = effect.fields };
    const original = try result.expression(index, bound, step.instruction);
    if (effect.guard != original.guard) return error.InvalidApplicationEffect;
    return result;
}

pub fn expression(self: Self, index: a.Cursor.Index, bound: a.Types.Bound, instruction: a.Id) !a.Effect {
    const entry = try index.instruction(instruction);
    if (entry.value != .let or entry.value.let.value != .effect or
        std.mem.allEqual(u8, &self.operation, 0)) return error.InvalidApplicationEffect;
    const original = entry.value.let.value.effect;
    if (!std.mem.eql(u8, self.sink, original.sink) or
        (self.kind == .form) != (original.request == .form)) return error.InvalidApplicationEffect;
    const fields = switch (original.request) {
        .form, .headers => |fields| fields,
    };
    if (self.fields.len != fields.len or fields.len > a.max_arguments) return error.InvalidApplicationEffect;
    for (self.fields, fields) |frozen, declared| {
        if (!std.mem.eql(u8, frozen.name, declared.name) or declared.value.id >= bound.values.len) return error.InvalidApplicationEffect;
        try frozen.value.validate(bound.values[declared.value.id] orelse return error.InvalidApplicationEffect);
    }
    return original;
}

/// Only the caller's verified original terminal outcome may complete this step.
/// Reconstructing the typed operand does not evaluate its guard or authorize I/O.
pub fn prepared(self: Self, index: a.Cursor.Index, bound: a.Types.Bound, step: u32, instruction: a.Id) !a.Step.Prepared {
    const original = try self.expression(index, bound, instruction);
    return .{ .step = step, .instruction = instruction, .action = .{ .effect = .{
        .sink = self.sink,
        .identity = .{ .uuid = self.operation },
        .guard = original.guard,
        .kind = if (self.kind == .form) .form else .headers,
        .fields = self.fields,
    } } };
}

test "application effect requests restore frozen operands without reevaluating observations" {
    const t = std.testing;
    var parsed = try a.parse(t.allocator,
        \\CREATE DATAFLOW effect FROM QUEUE jobs AS job AS BEGIN
        \\  LET result = EXECUTE SINK target EFFECT job.id GUARD TRUE
        \\    FORM (nonce = RANDOM_TOKEN(16)) ON REPLAY OBSERVE ONLY;
        \\  REQUIRE result.status = 200 ELSE 'UnexpectedStatus';
        \\ON FAILURE failure
        \\  REQUIRE failure.effect_outcome = 'unknown' OR failure.effect_outcome = 'not_dispatched' ELSE 'LostOriginalOutcome';
        \\END;
    , null);
    defer parsed.deinit();
    var bound = try a.Types.bind(t.allocator, parsed.program, &.{
        .{ .name = "jobs", .kind = .queue, .fields = &.{.{ .name = "id", .value = .{ .kind = .uuid } }} },
        .{ .name = "target", .kind = .sink, .fields = &.{} },
    }, null);
    defer bound.deinit();
    var index = try a.Cursor.Index.init(t.allocator, &parsed.program);
    defer index.deinit();
    var env = try a.Environment.init(t.allocator, index, bound, .{ .record = &.{.{ .name = "id", .value = .{ .uuid = @splat(1) } }} });
    defer env.deinit();
    const Native = struct {
        calls: usize = 0,
        fn lookup(_: *anyopaque, _: []const u8) anyerror!a.Values.Value {
            return error.UnknownProgramVariable;
        }
        fn condition(_: *anyopaque, _: a.Values.Value) anyerror!bool {
            return error.ProtectedProgramValue;
        }
        fn evaluate(context: *anyopaque, _: a.Id, operation: a.Evaluation.Operation, _: []const a.Values.Value) anyerror!a.Values.Value {
            const self: *@This() = @ptrCast(@alignCast(context));
            if (operation != .function or operation.function != .random_token) return error.ProgramArgumentMismatch;
            self.calls += 1;
            return .{ .text = if (self.calls == 1) "original" else "replacement" };
        }
    };
    var native: Native = .{};
    var scratch: std.heap.ArenaAllocator = .init(t.allocator);
    defer scratch.deinit();
    var driver: a.Step = .{ .index = index, .bound = bound, .environment = &env, .scratch = scratch.allocator(), .native = .{ .context = &native, .lookup = Native.lookup, .condition = Native.condition, .evaluate = Native.evaluate } };
    const prepared_step = try driver.prepare();
    const frozen = try Self.freeze(index, bound, prepared_step);
    const encoded = try q.protocol.Json.valueAlloc(t.allocator, frozen);
    defer t.allocator.free(encoded);
    const restored = try q.protocol.Json.parseFromSliceOwned(Self, t.allocator, encoded);
    defer restored.deinit();
    const replay = try restored.value.prepared(index, bound, prepared_step.step, prepared_step.instruction);
    try t.expectEqualStrings("original", replay.action.effect.fields[0].value.text);
    try t.expectEqual(@as(usize, 1), native.calls);
    var proposed = try driver.propose(t.allocator, replay, .{ .value = .{ .record = &.{
        .{ .name = "status", .value = .{ .integer = 200 } },
        .{ .name = "body", .value = .{ .protected_json = .{ .id = @splat(2) } } },
    } } });
    defer proposed.deinit();
    try t.expectEqual(prepared_step.step + 1, proposed.cursor.step);
    try t.expectEqual(@as(usize, 1), native.calls);
    try proposed.refuse(index, proposed.cursor.step, .{ .failure = .{ .code = "UnknownEffect", .effect_outcome = "unknown" } }, false);
    try a.Environment.validate(index, bound, @splat(1), proposed.snapshot(@splat(1)));
    var invalid = restored.value;
    invalid.operation = @splat(0);
    try t.expectError(error.InvalidApplicationEffect, invalid.prepared(index, bound, 0, prepared_step.instruction));
    invalid = restored.value;
    invalid.sink = "replacement";
    try t.expectError(error.InvalidApplicationEffect, invalid.prepared(index, bound, 0, prepared_step.instruction));
    invalid = restored.value;
    invalid.kind = .headers;
    try t.expectError(error.InvalidApplicationEffect, invalid.prepared(index, bound, 0, prepared_step.instruction));
    invalid = restored.value;
    invalid.fields = &.{.{ .name = "other", .value = .{ .text = "original" } }};
    try t.expectError(error.InvalidApplicationEffect, invalid.prepared(index, bound, 0, prepared_step.instruction));
    invalid.fields = &.{.{ .name = "nonce", .value = .{ .integer = 7 } }};
    try t.expectError(error.ProgramTypeMismatch, invalid.prepared(index, bound, 0, prepared_step.instruction));
}
