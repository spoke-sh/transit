//! Bounded control flow over a retained program. Advancing this cursor grants
//! no authority and accepts no work. The execution owner checkpoints it with
//! the original operation outcome, and settles an atomic decision before exit.
const std = @import("std");
const a = @import("ApplicationProgram.zig");
const Self = @This();
pub const Branch = enum { body, failure, atomic, yes, no, iteration };
pub const Frame = struct {
    owner: a.Id,
    branch: Branch,
    index: u16,
    /// Bindings present on scope entry. Terminal completion releases all locals.
    environment: u16,
    // These remain mandatory when a snapshot is embedded in a native candidate.
    ordinal: u8,
    length: u8,
};
pub const Phase = enum { body, failure, complete };
pub const Checkpoint = struct { phase: Phase, step: u32, frames: []const Frame };
pub const Event = union(enum) {
    instruction: *const a.Instruction,
    enter_atomic: *const a.Instruction,
    leave_atomic: Frame,
    leave_scope: Frame,
    page,
    complete,
};
pub const Advance = union(enum) {
    instruction: a.Id,
    enter_atomic: a.Id,
    branch: struct { id: a.Id, yes: bool },
    iteration: struct { id: a.Id, length: u8 },
    leave: a.Id,
    page,
};
pub const Index = struct {
    allocator: std.mem.Allocator,
    program: *const a.Program,
    instructions: []?*const a.Instruction,
    execution_limit: u32,

    pub fn init(allocator: std.mem.Allocator, program: *const a.Program) !Index {
        try a.Codec.validate(program.*);
        const execution_limit = try a.Codec.executionLimit(program.*);
        const instructions = try allocator.alloc(?*const a.Instruction, @as(usize, program.nodes) + 1);
        @memset(instructions, null);
        var result: Index = .{ .allocator = allocator, .program = program, .instructions = instructions, .execution_limit = execution_limit };
        if (program.body == .instructions) result.collect(program.body.instructions);
        if (program.failure) |failure| result.collect(failure.instructions);
        return result;
    }
    pub fn deinit(self: *Index) void {
        self.allocator.free(self.instructions);
        self.* = undefined;
    }
    fn collect(self: *Index, body: []const a.Instruction) void {
        for (body) |*entry| {
            self.instructions[entry.id] = entry;
            switch (entry.value) {
                .atomic => |nested| self.collect(nested),
                .iteration => |loop| self.collect(loop.body),
                .conditional => |choice| {
                    self.collect(choice.yes);
                    self.collect(choice.no);
                },
                else => {},
            }
        }
    }
    pub fn instruction(self: Index, id: a.Id) !*const a.Instruction {
        if (id == 0 or id >= self.instructions.len) return error.InvalidProgramNode;
        return self.instructions[id] orelse error.InvalidProgramNode;
    }
    pub fn block(self: Index, frame: Frame) ![]const a.Instruction {
        if (frame.owner == 0) return switch (frame.branch) {
            .body => if (self.program.body == .instructions) self.program.body.instructions else error.InvalidProgramNode,
            .failure => if (self.program.failure) |failure| failure.instructions else error.InvalidProgramNode,
            else => error.InvalidProgramNode,
        };
        const selected = try self.instruction(frame.owner);
        return switch (frame.branch) {
            .atomic => if (selected.value == .atomic) selected.value.atomic else error.InvalidProgramNode,
            .yes => if (selected.value == .conditional) selected.value.conditional.yes else error.InvalidProgramNode,
            .no => if (selected.value == .conditional) selected.value.conditional.no else error.InvalidProgramNode,
            .iteration => if (selected.value == .iteration) selected.value.iteration.body else error.InvalidProgramNode,
            else => error.InvalidProgramNode,
        };
    }
    fn bindings(self: Index, frame: Frame) !u16 {
        const body = try self.block(frame);
        if (frame.index > body.len) return error.InvalidProgramNode;
        var count = frame.environment;
        for (body[0..frame.index]) |entry| if (entry.value == .let) {
            count += 1;
        };
        return count;
    }
};

frames: [a.max_depth + 1]Frame = undefined,
count: u8,
phase: Phase,
step: u32,

pub fn initial() Self {
    var result: Self = .{ .count = 1, .phase = .body, .step = 0 };
    result.frames[0] = .{ .owner = 0, .branch = .body, .index = 0, .environment = 1, .ordinal = 0, .length = 0 };
    return result;
}
pub fn checkpoint(self: *const Self) Checkpoint {
    return .{ .phase = self.phase, .step = self.step, .frames = self.frames[0..self.count] };
}
pub fn restore(index: Index, value: Checkpoint) !Self {
    if (value.frames.len > a.max_depth + 1 or value.step > index.execution_limit or
        (value.phase == .complete) != (value.frames.len == 0)) return error.InvalidProgramNode;
    var result: Self = .{ .phase = value.phase, .step = value.step, .count = @intCast(value.frames.len) };
    var atomic_seen = false;
    var iteration_seen = false;
    for (value.frames, 0..) |frame, at| {
        if (frame.branch != .iteration and (frame.ordinal != 0 or frame.length != 0)) return error.InvalidProgramNode;
        if (frame.environment == 0 or frame.environment > index.program.nodes + 2) return error.InvalidProgramNode;
        if (at == 0) {
            if (frame.owner != 0 or frame.branch != (if (value.phase == .body) Branch.body else Branch.failure) or
                frame.environment != (if (value.phase == .body) @as(u16, 1) else 2)) return error.InvalidProgramNode;
            if (frame.branch == .body and index.program.body == .page) {
                if (value.frames.len != 1 or frame.index != 0) return error.InvalidProgramNode;
                result.frames[at] = frame;
                continue;
            }
        } else {
            const parent = value.frames[at - 1];
            const body = try index.block(parent);
            if (parent.index == 0 or parent.index > body.len or body[parent.index - 1].id != frame.owner or frame.environment != try index.bindings(parent)) return error.InvalidProgramNode;
        }
        const body = try index.block(frame);
        if (frame.index > body.len) return error.InvalidProgramNode;
        if (frame.branch == .atomic) {
            if (atomic_seen) return error.NestedAtomicProgram;
            atomic_seen = true;
        }
        if (frame.branch == .iteration) {
            if (!atomic_seen or iteration_seen or frame.length == 0 or frame.length > a.max_collection_rows or frame.ordinal >= frame.length) return error.InvalidProgramNode;
            iteration_seen = true;
        } else if (frame.ordinal != 0 or frame.length != 0) return error.InvalidProgramNode;
        result.frames[at] = frame;
    }
    return result;
}
pub fn next(self: *const Self, index: Index) !Event {
    if (self.phase == .complete) return .complete;
    if (self.count == 0 or self.count > self.frames.len) return error.InvalidProgramNode;
    const frame = self.frames[self.count - 1];
    if (self.phase == .body and self.count == 1 and index.program.body == .page) return .page;
    const body = try index.block(frame);
    if (frame.index > body.len) return error.InvalidProgramNode;
    if (frame.index == body.len) return if (frame.branch == .atomic) .{ .leave_atomic = frame } else .{ .leave_scope = frame };
    const selected = &body[frame.index];
    return if (selected.value == .atomic) .{ .enter_atomic = selected } else .{ .instruction = selected };
}
pub fn atomic(self: *const Self) ?a.Id {
    for (self.frames[0..self.count]) |frame| if (frame.branch == .atomic) return frame.owner;
    return null;
}
pub fn bindings(self: *const Self, index: Index) !u16 {
    if (self.phase == .complete) return 0;
    if (self.count == 0 or self.count > self.frames.len) return error.InvalidProgramNode;
    if (self.phase == .body and index.program.body == .page) return 1;
    return index.bindings(self.frames[self.count - 1]);
}
/// expected_step fences a stale local completion. The durable owner must also
/// compare its accepted checkpoint revision when publishing the successor.
pub fn advance(self: *Self, index: Index, expected_step: u32, action: Advance) !void {
    if (self.step != expected_step or self.step >= index.execution_limit) return error.InvalidProgramNode;
    const event = try self.next(index);
    switch (action) {
        .instruction => |id| {
            if (event != .instruction or event.instruction.id != id or event.instruction.value == .conditional or event.instruction.value == .iteration) return error.InvalidProgramNode;
            self.frames[self.count - 1].index += 1;
        },
        .enter_atomic => |id| {
            if (event != .enter_atomic or event.enter_atomic.id != id or self.atomic() != null) return error.InvalidProgramNode;
            try self.enter(index, id, .atomic);
        },
        .branch => |choice| {
            if (event != .instruction or event.instruction.value != .conditional or event.instruction.id != choice.id) return error.InvalidProgramNode;
            try self.enter(index, choice.id, if (choice.yes) .yes else .no);
        },
        .iteration => |loop| {
            if (event != .instruction or event.instruction.value != .iteration or event.instruction.id != loop.id or
                self.atomic() == null or loop.length > a.max_collection_rows) return error.InvalidProgramNode;
            for (self.frames[0..self.count]) |frame| if (frame.branch == .iteration) return error.InvalidProgramNode;
            if (loop.length == 0) {
                self.frames[self.count - 1].index += 1;
            } else {
                try self.enter(index, loop.id, .iteration);
                self.frames[self.count - 1].length = loop.length;
            }
        },
        .leave => |id| {
            const frame = switch (event) {
                .leave_atomic, .leave_scope => |frame| frame,
                else => return error.InvalidProgramNode,
            };
            if (frame.owner != id) return error.InvalidProgramNode;
            if (frame.branch == .iteration and frame.ordinal + 1 < frame.length) {
                self.frames[self.count - 1].ordinal += 1;
                self.frames[self.count - 1].index = 0;
            } else {
                self.count -= 1;
                if (self.count == 0) self.phase = .complete;
            }
        },
        .page => {
            if (event != .page) return error.InvalidProgramNode;
            self.count = 0;
            self.phase = .complete;
        },
    }
    self.step += 1;
}
fn enter(self: *Self, index: Index, id: a.Id, branch: Branch) !void {
    if (self.count == self.frames.len) return error.InvalidProgramNode;
    const environment = try self.bindings(index);
    self.frames[self.count - 1].index += 1;
    self.frames[self.count] = .{ .owner = id, .branch = branch, .index = 0, .environment = environment, .ordinal = 0, .length = 0 };
    self.count += 1;
}
/// The caller must first resolve pending native work, including any common
/// decision, and restore its entry checkpoint after an abort. Partial body locals
/// are replaced by original input + typed failure.
pub fn fail(self: *Self, index: Index, expected_step: u32) !void {
    if (self.phase != .body) return error.InvalidProgramNode;
    try self.refuse(index, expected_step, false);
}
/// The native owner passes atomic_aborted only after verifying the original
/// transaction's abort decision. Preserve the monotone instruction step while
/// discarding the failed block's frames. A failing failure handler terminates;
/// it does not recursively enter ON FAILURE again.
pub fn refuse(self: *Self, index: Index, expected_step: u32, atomic_aborted: bool) !void {
    if (self.step != expected_step or self.phase == .complete or
        (self.atomic() != null) != atomic_aborted or self.step >= index.execution_limit) return error.InvalidProgramNode;
    const handler = self.phase == .body and index.program.failure != null;
    self.step += 1;
    self.count = if (handler) 1 else 0;
    self.phase = if (handler) .failure else .complete;
    if (handler) self.frames[0] = .{ .owner = 0, .branch = .failure, .index = 0, .environment = 2, .ordinal = 0, .length = 0 };
}

test "application cursor restores exact branches and refuses early atomic exit or stale completions" {
    const t = std.testing;
    var program = try a.parse(t.allocator, "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN IF TRUE THEN BEGIN ATOMIC LET x = 1; END; ELSE LET y = 2; END IF; LET z = 3; END;", null);
    defer program.deinit();
    var index = try Index.init(t.allocator, &program.program);
    defer index.deinit();
    var cursor = initial();
    const branch = (try cursor.next(index)).instruction.id;
    try cursor.advance(index, 0, .{ .branch = .{ .id = branch, .yes = true } });
    const atomic_id = (try cursor.next(index)).enter_atomic.id;
    try cursor.advance(index, 1, .{ .enter_atomic = atomic_id });
    try t.expectEqual(atomic_id, cursor.atomic().?);
    const before = cursor.checkpoint();
    const encoded = try @import("transit_protocol").Json.valueAlloc(t.allocator, before);
    defer t.allocator.free(encoded);
    const loaded = try std.json.parseFromSlice(Checkpoint, t.allocator, encoded, .{});
    defer loaded.deinit();
    cursor = try restore(index, loaded.value);
    try t.expectError(error.InvalidProgramNode, cursor.advance(index, cursor.step, .{ .leave = atomic_id }));
    try t.expectError(error.InvalidProgramNode, cursor.fail(index, cursor.step));
    const assignment = (try cursor.next(index)).instruction.id;
    try cursor.advance(index, cursor.step, .{ .instruction = assignment });
    try t.expectError(error.InvalidProgramNode, cursor.advance(index, 2, .{ .instruction = assignment }));
    try t.expectEqual(atomic_id, (try cursor.next(index)).leave_atomic.owner);
    try cursor.advance(index, cursor.step, .{ .leave = atomic_id });
    try t.expect(cursor.atomic() == null);
    try cursor.advance(index, cursor.step, .{ .leave = branch });
    const final = (try cursor.next(index)).instruction;
    try t.expectEqualStrings("z", final.value.let.name);
    try cursor.advance(index, cursor.step, .{ .instruction = final.id });
    try cursor.advance(index, cursor.step, .{ .leave = 0 });
    try t.expect(try cursor.next(index) == .complete);
    var forged = loaded.value;
    const bad = try t.allocator.dupe(Frame, forged.frames);
    defer t.allocator.free(bad);
    bad[1].owner = atomic_id;
    forged.frames = bad;
    try t.expectError(error.InvalidProgramNode, restore(index, forged));
}

test "application cursor failure starts with only original input and cannot restart its handler" {
    const t = std.testing;
    var program = try a.parse(t.allocator, "CREATE DATAFLOW act FROM QUEUE jobs AS request AS BEGIN LET local = 1; ON FAILURE failure REQUIRE FALSE ELSE 'Refused'; END;", null);
    defer program.deinit();
    var index = try Index.init(t.allocator, &program.program);
    defer index.deinit();
    var cursor = initial();
    try cursor.fail(index, 0);
    try t.expectEqual(@as(u16, 2), cursor.checkpoint().frames[0].environment);
    cursor = try restore(index, cursor.checkpoint());
    try t.expectEqualStrings("Refused", (try cursor.next(index)).instruction.value.require.refusal);
    try t.expectError(error.InvalidProgramNode, cursor.fail(index, cursor.step));
}

test "application iterator frames cannot omit their persisted position" {
    const t = std.testing;
    const p = @import("transit_protocol");
    const frame: Frame = .{ .owner = 7, .branch = .iteration, .index = 0, .environment = 2, .ordinal = 1, .length = 3 };
    const encoded = try p.Json.valueAlloc(t.allocator, frame);
    defer t.allocator.free(encoded);
    const restored = try p.Json.parseFromSliceOwned(Frame, t.allocator, encoded);
    defer restored.deinit();
    try t.expectEqualDeep(frame, restored.value);
    for ([_][]const u8{ "ordinal", "length" }) |field| {
        var tree = try std.json.parseFromSlice(std.json.Value, t.allocator, encoded, .{});
        defer tree.deinit();
        try t.expect(tree.value.object.swapRemove(field));
        const missing = try p.Json.valueAlloc(t.allocator, tree.value);
        defer t.allocator.free(missing);
        try t.expectError(error.MissingField, p.Json.parseFromSliceOwned(Frame, t.allocator, missing));
    }
}
