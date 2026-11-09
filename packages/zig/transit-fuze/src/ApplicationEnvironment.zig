//! Lexically scoped invocation values and bounded continuation encoding. Values
//! borrow their input/turn owners until encoded; decoding owns every byte. The
//! native owner binds this payload to its original input and common decision.
const std = @import("std");
const p = @import("transit_protocol");
const a = @import("ApplicationProgram.zig");
const Self = @This();
pub const Value = a.Values.Value;
pub const Binding = struct { instruction: a.Id, value: Value };
pub const failure_id = std.math.maxInt(a.Id);
pub const Snapshot = struct {
    definition: p.Growth.Definition,
    binding_digest: [32]u8,
    cursor: a.Cursor.Checkpoint,
    values: []const Binding,
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    snapshot: Snapshot,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
allocator: std.mem.Allocator,
cursor: a.Cursor,
values: std.ArrayList(Binding),

fn capacity(index: a.Cursor.Index) usize {
    var count: usize = 2;
    for (index.instructions) |entry| if (entry) |instruction| {
        if (instruction.value == .let) count += 1;
    };
    return count;
}
pub fn init(allocator: std.mem.Allocator, index: a.Cursor.Index, bound: a.Types.Bound, input: Value) !Self {
    try input.validate(bound.input);
    var values: std.ArrayList(Binding) = .empty;
    try values.ensureTotalCapacityPrecise(allocator, capacity(index));
    values.appendAssumeCapacity(.{ .instruction = 0, .value = input });
    return .{ .allocator = allocator, .cursor = .initial(), .values = values };
}
/// Copy the bounded binding array. Values still borrow their input/turn owners
/// until the invocation owner encodes its private successor candidate.
pub fn clone(self: *const Self, allocator: std.mem.Allocator) !Self {
    var values: std.ArrayList(Binding) = .empty;
    try values.ensureTotalCapacityPrecise(allocator, self.values.capacity);
    values.appendSliceAssumeCapacity(self.values.items);
    return .{ .allocator = allocator, .cursor = self.cursor, .values = values };
}
pub fn deinit(self: *Self) void {
    self.values.deinit(self.allocator);
    self.* = undefined;
}
pub fn snapshot(self: *const Self, binding_digest: [32]u8) Snapshot {
    return .{ .definition = p.Growth.current_definition, .binding_digest = binding_digest, .cursor = self.cursor.checkpoint(), .values = self.values.items };
}
pub fn validate(index: a.Cursor.Index, bound: a.Types.Bound, binding_digest: [32]u8, value: Snapshot) !void {
    if (value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    if (std.mem.allEqual(u8, &binding_digest, 0) or !std.mem.eql(u8, &binding_digest, &value.binding_digest)) return error.InvalidProgramNode;
    const cursor = try a.Cursor.restore(index, value.cursor);
    if (value.values.len != try cursor.bindings(index)) return error.InvalidProgramNode;
    if (cursor.phase == .complete) return;
    if (value.values[0].instruction != 0) return error.InvalidProgramNode;
    try value.values[0].value.validate(bound.input);
    var at: usize = 1;
    if (cursor.phase == .failure) {
        if (value.values[at].instruction != failure_id) return error.InvalidProgramNode;
        try value.values[at].value.validate(.{ .kind = .failure });
        at += 1;
    }
    if (cursor.phase == .body and index.program.body == .page) return;
    for (cursor.checkpoint().frames) |frame| {
        const block = try index.block(frame);
        for (block[0..frame.index]) |entry| if (entry.value == .let) {
            if (at >= value.values.len or value.values[at].instruction != entry.id) return error.InvalidProgramNode;
            try value.values[at].value.validate(bound.values[entry.id] orelse return error.InvalidProgramNode);
            at += 1;
        };
    }
    if (at != value.values.len) return error.InvalidProgramNode;
}
pub fn restore(allocator: std.mem.Allocator, index: a.Cursor.Index, bound: a.Types.Bound, binding_digest: [32]u8, value: Snapshot) !Self {
    try validate(index, bound, binding_digest, value);
    var values: std.ArrayList(Binding) = .empty;
    try values.ensureTotalCapacityPrecise(allocator, capacity(index));
    values.appendSliceAssumeCapacity(value.values);
    return .{ .allocator = allocator, .cursor = try a.Cursor.restore(index, value.cursor), .values = values };
}
pub fn encode(allocator: std.mem.Allocator, index: a.Cursor.Index, bound: a.Types.Bound, binding_digest: [32]u8, value: Snapshot) ![]u8 {
    try validate(index, bound, binding_digest, value);
    return p.Json.valueAllocBounded(allocator, value, a.Codec.max_bytes);
}
pub fn decode(allocator: std.mem.Allocator, index: a.Cursor.Index, bound: a.Types.Bound, binding_digest: [32]u8, bytes: []const u8) !Owned {
    try a.Codec.validateEncoding(bytes);
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const value = try std.json.parseFromSliceLeaky(Snapshot, arena.allocator(), bytes, .{ .allocate = .alloc_always, .max_value_len = a.Codec.max_bytes });
    const canonical = try encode(allocator, index, bound, binding_digest, value);
    defer allocator.free(canonical);
    if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidProgramNode;
    return .{ .arena = arena, .snapshot = value };
}
pub fn lookup(self: *const Self, index: a.Cursor.Index, name: []const u8) !Value {
    for (self.values.items) |entry| {
        const candidate = switch (entry.instruction) {
            0 => index.program.input,
            failure_id => (index.program.failure orelse return error.InvalidProgramNode).name,
            else => (try index.instruction(entry.instruction)).value.let.name,
        };
        if (std.mem.eql(u8, name, candidate)) return entry.value;
    }
    return error.UnknownProgramVariable;
}
pub fn bind(self: *Self, index: a.Cursor.Index, bound: a.Types.Bound, expected_step: u32, instruction: a.Id, value: Value) !void {
    const entry = try index.instruction(instruction);
    if (entry.value != .let or instruction >= bound.values.len) return error.InvalidProgramNode;
    try value.validate(bound.values[instruction] orelse return error.InvalidProgramNode);
    var next = self.cursor;
    try next.advance(index, expected_step, .{ .instruction = instruction });
    if (self.values.items.len == self.values.capacity or try next.bindings(index) != self.values.items.len + 1) return error.InvalidProgramNode;
    self.values.appendAssumeCapacity(.{ .instruction = instruction, .value = value });
    self.cursor = next;
}
/// A LET must use bind so an observation cannot advance without its value.
pub fn advance(self: *Self, index: a.Cursor.Index, expected_step: u32, action: a.Cursor.Advance) !void {
    var next = self.cursor;
    try next.advance(index, expected_step, action);
    const count = try next.bindings(index);
    if (count > self.values.items.len) return error.InvalidProgramNode;
    self.values.shrinkRetainingCapacity(count);
    self.cursor = next;
}
pub fn fail(self: *Self, index: a.Cursor.Index, expected_step: u32, failure: Value) !void {
    if (self.cursor.phase != .body) return error.InvalidProgramNode;
    try self.refuse(index, expected_step, failure, false);
}
pub fn refuse(self: *Self, index: a.Cursor.Index, expected_step: u32, failure: Value, atomic_aborted: bool) !void {
    try failure.validate(.{ .kind = .failure });
    var next = self.cursor;
    try next.refuse(index, expected_step, atomic_aborted);
    const count = try next.bindings(index);
    self.values.shrinkRetainingCapacity(if (count == 0) 0 else 1);
    if (count != 0) self.values.appendAssumeCapacity(.{ .instruction = failure_id, .value = failure });
    self.cursor = next;
}

test "application environment owns restored values and validates live scope and types" {
    const t = std.testing;
    var program = try a.parse(t.allocator, "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN LET outer = 'retained'; IF TRUE THEN LET inner = 42; END IF; ON FAILURE failure REQUIRE FALSE ELSE 'Refused'; END;", null);
    defer program.deinit();
    var bound = try a.Types.bind(t.allocator, program.program, &.{.{ .name = "jobs", .kind = .queue, .fields = &.{} }}, null);
    defer bound.deinit();
    var index = try a.Cursor.Index.init(t.allocator, &program.program);
    defer index.deinit();
    var env = try init(t.allocator, index, bound, .{ .record = &.{} });
    defer env.deinit();
    var text = "retained".*;
    const outer = (try env.cursor.next(index)).instruction.id;
    try t.expectError(error.InvalidProgramNode, env.advance(index, 0, .{ .instruction = outer }));
    try env.bind(index, bound, 0, outer, .{ .text = &text });
    const branch = (try env.cursor.next(index)).instruction.id;
    try env.advance(index, 1, .{ .branch = .{ .id = branch, .yes = true } });
    const inner = (try env.cursor.next(index)).instruction.id;
    try t.expectError(error.ProgramTypeMismatch, env.bind(index, bound, 2, inner, .{ .text = "wrong" }));
    try env.bind(index, bound, 2, inner, .{ .integer = 42 });
    const digest: [32]u8 = @splat(7);
    const bytes = try encode(t.allocator, index, bound, digest, env.snapshot(digest));
    defer t.allocator.free(bytes);
    var owned = try decode(t.allocator, index, bound, digest, bytes);
    defer owned.deinit();
    @memset(&text, 'x');
    var resumed = try restore(t.allocator, index, bound, digest, owned.snapshot);
    defer resumed.deinit();
    try t.expectEqualStrings("retained", (try resumed.lookup(index, "outer")).text);
    try t.expectEqual(@as(i64, 42), (try resumed.lookup(index, "inner")).integer);
    try t.expectError(error.InvalidProgramNode, restore(t.allocator, index, bound, @splat(8), owned.snapshot));
    try resumed.advance(index, 3, .{ .leave = branch });
    try t.expectError(error.UnknownProgramVariable, resumed.lookup(index, "inner"));
    try resumed.fail(index, 4, .{ .failure = .{ .code = "Refused", .effect_outcome = "not_dispatched" } });
    try t.expectError(error.UnknownProgramVariable, resumed.lookup(index, "outer"));
    try validate(index, bound, digest, resumed.snapshot(digest));
    try t.expectEqualStrings("not_dispatched", (try (try resumed.lookup(index, "failure")).field("effect_outcome")).text);
    var forged = owned.snapshot;
    forged.values = owned.snapshot.values[0..2];
    try t.expectError(error.InvalidProgramNode, validate(index, bound, digest, forged));
}

test "application environment decoding cleans up every allocation failure" {
    const t = std.testing;
    const Case = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var program = try a.parse(allocator, "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN LET x = 1; END;", null);
            defer program.deinit();
            var bound = try a.Types.bind(allocator, program.program, &.{.{ .name = "jobs", .kind = .queue, .fields = &.{} }}, null);
            defer bound.deinit();
            var index = try a.Cursor.Index.init(allocator, &program.program);
            defer index.deinit();
            var env = try init(allocator, index, bound, .{ .record = &.{} });
            defer env.deinit();
            const digest: [32]u8 = @splat(1);
            const bytes = try encode(allocator, index, bound, digest, env.snapshot(digest));
            defer allocator.free(bytes);
            var owned = try decode(allocator, index, bound, digest, bytes);
            defer owned.deinit();
            var resumed = try restore(allocator, index, bound, digest, owned.snapshot);
            defer resumed.deinit();
        }
    };
    try t.checkAllAllocationFailures(t.allocator, Case.run, .{});
}

test "application failure after verified abort drops locals without resetting instruction identity" {
    const t = std.testing;
    var program = try a.parse(t.allocator, "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN LET outer = 1; BEGIN ATOMIC LET inner = 2; REQUIRE FALSE ELSE 'Refused'; END; ON FAILURE failure REQUIRE FALSE ELSE 'HandlerFailed'; END;", null);
    defer program.deinit();
    var bound = try a.Types.bind(t.allocator, program.program, &.{.{ .name = "jobs", .kind = .queue, .fields = &.{} }}, null);
    defer bound.deinit();
    var index = try a.Cursor.Index.init(t.allocator, &program.program);
    defer index.deinit();
    var env = try init(t.allocator, index, bound, .{ .record = &.{} });
    defer env.deinit();
    const outer = (try env.cursor.next(index)).instruction.id;
    try env.bind(index, bound, 0, outer, .{ .integer = 1 });
    const block = (try env.cursor.next(index)).enter_atomic.id;
    try env.advance(index, 1, .{ .enter_atomic = block });
    const inner = (try env.cursor.next(index)).instruction.id;
    try env.bind(index, bound, 2, inner, .{ .integer = 2 });
    const failure: Value = .{ .failure = .{ .code = "Refused", .effect_outcome = "not_dispatched" } };
    try t.expectError(error.InvalidProgramNode, env.refuse(index, 3, failure, false));
    try env.refuse(index, 3, failure, true);
    try t.expectEqual(@as(u32, 4), env.cursor.step);
    try t.expectEqual(.failure, env.cursor.phase);
    try t.expectError(error.UnknownProgramVariable, env.lookup(index, "outer"));
    try t.expectError(error.UnknownProgramVariable, env.lookup(index, "inner"));
    try t.expectEqual(@as(usize, 0), (try env.lookup(index, "request")).record.len);
    try t.expectError(error.InvalidProgramNode, env.refuse(index, 3, failure, false));
    try t.expectError(error.InvalidProgramNode, env.refuse(index, 4, failure, true));
    try env.refuse(index, 4, failure, false);
    try t.expectEqual(.complete, env.cursor.phase);
    try t.expectEqual(@as(u32, 5), env.cursor.step);
    try t.expectEqual(@as(usize, 0), env.values.items.len);
    try validate(index, bound, @splat(1), env.snapshot(@splat(1)));
}
