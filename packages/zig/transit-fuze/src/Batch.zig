//! Experimental physical int64 batches. No I/O, authority or published progress.
//! Flat values and five-state sidecars retain source order and conflict payloads.
const std = @import("std");
const types = @import("Types.zig");
const logical = @import("LogicalQuery.zig");
const finite = @import("Finite.zig");
const Cell = types.Values.Cell;
const Alternative = types.Values.Alternative;
const Self = @This();

pub const Limits = struct {
    rows: usize = 256,
    bytes: usize = 256 * 1024,
    pub fn validate(self: Limits) !void {
        if (self.rows == 0 or self.rows > 1024 or self.bytes < 4096 or self.bytes > 1024 * 1024) return error.InvalidBatchBudget;
    }
};
pub const Provenance = struct {
    /// One-based original source row, independent of selection/output positions.
    row: u64,
    /// Original validation boundary; this prototype's pull adapters validate rows.
    boundary: u64,
    identity: ?@import("TableRow.zig").Identity = null,
};
pub const Detail = union(enum) { none, type_error: types.Kind, conflict: []const Alternative };
pub const Column = struct {
    values: []i64,
    states: []types.State,
    details: []Detail,
    pub fn view(self: Column, len: usize) View {
        std.debug.assert(len <= self.values.len);
        return .{ .flat = .{ .values = self.values[0..len], .states = self.states[0..len], .details = self.details[0..len] } };
    }
};
/// Borrows its owner. A constant owns neither its conflict alternatives nor rows.
/// Callers validate cells and equal flat-slice lengths before constructing views.
pub const View = union(enum) {
    flat: struct { values: []const i64, states: []const types.State, details: []const Detail },
    constant: struct { value: Cell, len: usize },
    pub fn len(self: View) usize {
        return switch (self) {
            .flat => |v| v.values.len,
            .constant => |v| v.len,
        };
    }
    pub fn state(self: View, row: usize) types.State {
        std.debug.assert(row < self.len());
        return switch (self) {
            .flat => |v| v.states[row],
            .constant => |v| std.meta.activeTag(v.value),
        };
    }
    pub fn integer(self: View, row: usize) i64 {
        std.debug.assert(self.state(row) == .value);
        return switch (self) {
            .flat => |v| v.values[row],
            .constant => |v| @intCast(v.value.value.atom.signed),
        };
    }
    pub fn cell(self: View, row: usize) Cell {
        if (self == .constant) return self.constant.value;
        return switch (self.state(row)) {
            .value => .{ .value = .{ .atom = .{ .signed = self.integer(row) } } },
            .null => .null,
            .missing => .missing,
            .type_error => .{ .type_error = self.flat.details[row].type_error },
            .conflict => .{ .conflict = self.flat.details[row].conflict },
        };
    }
};
pub const Outcome = union(enum) { truth: finite.Truth, type_error, conflict };
const Compare = *const fn (View, i64, []Outcome) void;
const Kernel = union(enum) {
    all,
    state: struct { column: u8, state: types.State },
    compare: struct { column: u8, literal: i64, run: Compare },
};
allocator: std.mem.Allocator,
backing: []u8,
memory: std.heap.FixedBufferAllocator,
/// Independently owned, validated snapshot. Treat as immutable until deinit.
plan: logical.Plan,
fingerprint: [32]u8,
kernel: Kernel,
columns: []Column,
provenance: []Provenance,
outcomes: []Outcome,
selection: []usize,
capacity: usize,
len: usize = 0,
selected: usize = 0,
payload_start: usize,

pub fn init(allocator: std.mem.Allocator, plan: logical.Plan, limits: Limits) !Self {
    try limits.validate();
    const fingerprint = try plan.fingerprint();
    for (plan.schema.structure) |field| if (field.type != .int64) return error.UnsupportedBatchPlan;
    if (plan.aggregate == .sum) return error.UnsupportedBatchPlan;
    if (plan.predicate == .program and (plan.predicate.program.instructions.len != 1 or plan.predicate.program.instructions[0] != .atom)) return error.UnsupportedBatchPlan;
    if (limits.bytes <= @sizeOf(Self)) return error.BatchBudgetExceeded;
    const byte_count = limits.bytes - @sizeOf(Self);
    // This allocation is an arena reservation, not a live byte array. Avoid
    // touching every reserved conflict-payload page before the first output.
    // FBA allocations initialize metadata; append initializes every active lane
    // before len advances. No kernel/export may read the unused arena tail.
    const pointer = allocator.rawAlloc(byte_count, .of(u8), @returnAddress()) orelse return error.OutOfMemory;
    const backing = pointer[0..byte_count];
    errdefer allocator.free(backing);
    var memory: std.heap.FixedBufferAllocator = .init(backing);
    const a = memory.allocator();
    const owned = copyPlan(a, plan) catch return error.BatchBudgetExceeded;
    const atom: logical.Plan.Atom = switch (owned.predicate) {
        .program => |program| program.instructions[0].atom,
        inline else => |value, tag| @unionInit(logical.Plan.Atom, @tagName(tag), value),
    };
    const kernel: Kernel = switch (atom) {
        .all => .all,
        .state => |v| .{ .state = .{ .column = v.column, .state = v.value } },
        .compare => |v| .{ .compare = .{ .column = v.column, .literal = @intCast(v.value.signed), .run = switch (v.op) {
            inline else => |op| &CompareKernel(op).run,
        } } },
    };
    const columns = a.alloc(Column, owned.schema.structure.len) catch return error.BatchBudgetExceeded;
    const row_bytes = columns.len * (@sizeOf(i64) + @sizeOf(types.State) + @sizeOf(Detail)) + @sizeOf(Provenance) + @sizeOf(Outcome) + @sizeOf(usize);
    // Half of the remaining arena is reserved for conflict alternatives. Width
    // reduces the compute target; it never raises the caller's byte allowance.
    const capacity = @min(limits.rows, (backing.len - memory.end_index) / (2 * row_bytes));
    if (capacity == 0) return error.BatchBudgetExceeded;
    for (columns) |*column| column.* = .{
        .values = a.alloc(i64, capacity) catch return error.BatchBudgetExceeded,
        .states = a.alloc(types.State, capacity) catch return error.BatchBudgetExceeded,
        .details = a.alloc(Detail, capacity) catch return error.BatchBudgetExceeded,
    };
    const provenance = a.alloc(Provenance, capacity) catch return error.BatchBudgetExceeded;
    const outcomes = a.alloc(Outcome, capacity) catch return error.BatchBudgetExceeded;
    const selection = a.alloc(usize, capacity) catch return error.BatchBudgetExceeded;
    return .{ .allocator = allocator, .backing = backing, .memory = memory, .plan = owned, .fingerprint = fingerprint, .kernel = kernel, .columns = columns, .provenance = provenance, .outcomes = outcomes, .selection = selection, .capacity = capacity, .payload_start = memory.end_index };
}
pub fn predicateColumn(self: *const Self) u8 {
    return switch (self.kernel) {
        .all => unreachable,
        .state => |v| v.column,
        .compare => |v| v.column,
    };
}
// Admission has established an all-int64 descriptor and at most one atom.
// Copy precisely its borrowed storage, without serializing and revalidating a
// saved-plan envelope. There are no recursive fields or variable-width literals.
fn copyPlan(a: std.mem.Allocator, source: logical.Plan) !logical.Plan {
    var result = source;
    const fields = try a.dupe(types.Field, source.schema.structure);
    for (fields) |*field| field.name = try a.dupe(u8, field.name);
    result.schema = .{ .structure = fields };
    result.projection = try a.dupe(u8, source.projection);
    const names = try a.dupe(?[]const u8, source.output_names);
    for (names) |*name| if (name.*) |text| {
        name.* = try a.dupe(u8, text);
    };
    result.output_names = names;
    if (source.predicate == .program) result.predicate.program.instructions = try a.dupe(logical.Program.Instruction, source.predicate.program.instructions);
    return result;
}
pub fn deinit(self: *Self) void {
    self.allocator.free(self.backing);
    self.* = undefined;
}
pub fn reset(self: *Self) void {
    self.len = 0;
    self.selected = 0;
    self.memory.end_index = self.payload_start;
}
pub fn residentBytes(self: *const Self) usize {
    return @sizeOf(Self) + self.backing.len;
}
/// Validates and copies a complete row atomically. Failed append retains the
/// previous prefix. Row and plan inputs may be released immediately afterwards.
pub fn append(self: *Self, cells: []const Cell, provenance: Provenance) !void {
    if (cells.len != self.columns.len) return error.InvalidColumnCount;
    for (cells, self.plan.schema.structure) |cell, field| try cell.validate(field, .{});
    return self.appendValidated(cells, provenance);
}
/// Copies cells already validated against this immutable plan's exact schema.
/// Native Table and frozen file decoders establish this precondition. This is
/// not a replacement for a source's original whole-row validation boundary.
pub fn appendValidated(self: *Self, cells: []const Cell, provenance: Provenance) !void {
    if (self.len == self.capacity) return error.BatchFull;
    if (cells.len != self.columns.len) return error.InvalidColumnCount;
    if (provenance.row == 0 or provenance.boundary == 0) return error.InvalidProvenance;
    if (self.len > 0 and provenance.row <= self.provenance[self.len - 1].row) return error.InvalidProvenance;
    if (provenance.identity) |identity| try identity.validate();
    const previous = self.memory.end_index;
    errdefer self.memory.end_index = previous;
    for (cells, self.columns) |cell, column| {
        column.states[self.len] = std.meta.activeTag(cell);
        column.values[self.len] = if (cell == .value) @intCast(cell.value.atom.signed) else 0;
        column.details[self.len] = switch (cell) {
            .type_error => |kind| .{ .type_error = kind },
            .conflict => |alternatives| .{ .conflict = self.memory.allocator().dupe(Alternative, alternatives) catch return error.BatchFull },
            else => .none,
        };
    }
    self.provenance[self.len] = provenance;
    self.len += 1;
}
/// Computes outcomes without committing progress or arbitrating later failures.
/// The ordered consumer applies LIMIT and aggregate errors at each source row.
pub fn evaluate(self: *Self) void {
    const output = self.outcomes[0..self.len];
    switch (self.kernel) {
        .all => @memset(output, .{ .truth = .true_value }),
        .state => |v| for (output, self.columns[v.column].states[0..self.len]) |*out, state| {
            out.* = .{ .truth = finite.Truth.fromBool(state == v.state) };
        },
        .compare => |v| v.run(self.columns[v.column].view(self.len), v.literal, output),
    }
}
/// Allocation-free comparison of validated borrowed flat/constant columns.
/// Dispatch happens once per vector; output preserves every input position.
pub fn compare(column: View, literal: i64, op: finite.Comparison, output: []Outcome) void {
    switch (op) {
        inline else => |selected| CompareKernel(selected).run(column, literal, output),
    }
}
fn CompareKernel(comptime op: finite.Comparison) type {
    return struct {
        fn run(column: View, literal: i64, output: []Outcome) void {
            std.debug.assert(column.len() == output.len);
            for (output, 0..) |*out, i| {
                out.* = switch (column.state(i)) {
                    .missing, .null => .{ .truth = .unknown },
                    .type_error => .type_error,
                    .conflict => .conflict,
                    .value => .{ .truth = finite.Truth.fromBool(switch (op) {
                        .eq => column.integer(i) == literal,
                        .ne => column.integer(i) != literal,
                        .lt => column.integer(i) < literal,
                        .le => column.integer(i) <= literal,
                        .gt => column.integer(i) > literal,
                        .ge => column.integer(i) >= literal,
                    }) },
                };
            }
        }
    };
}

// Keep adversarial fixtures independent from the dispatch implementation.
test "owned int64 columns preserve all states, conflicts and selection provenance" {
    const t = std.testing;
    const schema: types.Type = .{ .structure = &.{.{ .name = "n", .type = .int64, .nullable = true, .optional = true }} };
    const plan: logical.Plan = .{ .schema = schema, .source_basis = @splat(71), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 0 } } } };
    var batch = try init(t.allocator, plan, .{ .rows = 8, .bytes = 65536 });
    defer batch.deinit();
    var alternatives = [_]Alternative{ .{ .counter = 1, .replica = 1, .value = .null }, .{ .counter = 2, .replica = 1, .value = .{ .value = .{ .atom = .{ .signed = 37 } } } } };
    const input = [_]Cell{ .{ .value = .{ .atom = .{ .signed = -1 } } }, .null, .missing, .{ .type_error = .utf8 }, .{ .conflict = &alternatives }, .{ .value = .{ .atom = .{ .signed = 9 } } } };
    for (input, 0..) |cell, i| try batch.append(&.{cell}, .{ .row = i + 11, .boundary = i + 11 });
    alternatives[1].value = .null;
    batch.evaluate();
    try t.expectEqualSlices(Outcome, &.{ .{ .truth = .false_value }, .{ .truth = .unknown }, .{ .truth = .unknown }, .type_error, .conflict, .{ .truth = .true_value } }, batch.outcomes[0..batch.len]);
    try t.expectEqual(@as(i128, 37), batch.columns[0].view(batch.len).cell(4).conflict[1].value.value.atom.signed);
    try t.expectEqual(@as(u64, 16), batch.provenance[5].row);
    try t.expectEqual(@as(usize, 65536), batch.residentBytes());
    try t.expectError(error.TypeMismatch, batch.append(&.{.{ .value = .{ .atom = .{ .unsigned = 1 } } }}, .{ .row = 17, .boundary = 17 }));
    try t.expectEqual(@as(usize, 6), batch.len);
    batch.reset();
    try t.expectEqual(@as(usize, 0), batch.len);
}
test "batch owns its plan and rejects unsupported semantics before allocation" {
    const t = std.testing;
    var projection = [_]u8{0};
    var fields = [_]types.Field{.{ .name = "n", .type = .int64 }};
    const plan: logical.Plan = .{ .schema = .{ .structure = &fields }, .source_basis = @splat(71), .projection = &projection };
    var batch = try init(t.allocator, plan, .{});
    defer batch.deinit();
    projection[0] = 127;
    fields[0].type = .utf8;
    try t.expectEqual(@as(u8, 0), batch.plan.projection[0]);
    try t.expect(batch.plan.schema.structure[0].type == .int64);
    try t.expectError(error.InvalidBatchBudget, init(t.allocator, batch.plan, .{ .bytes = 0 }));
    var invalid = batch.plan;
    invalid.aggregate = .sum;
    try t.expectError(error.UnsupportedBatchPlan, init(t.allocator, invalid, .{}));
}

test "comparison constants and extreme signed values retain all six operator answers" {
    const t = std.testing;
    const values = [_]i64{ std.math.minInt(i64), -1, 0, 1, std.math.maxInt(i64) };
    const states = [_]types.State{ .value, .value, .value, .value, .value };
    const details: [5]Detail = @splat(.none);
    const column: View = .{ .flat = .{ .values = &values, .states = &states, .details = &details } };
    const expected = [_][5]bool{ .{ false, false, true, false, false }, .{ true, true, false, true, true }, .{ true, true, false, false, false }, .{ true, true, true, false, false }, .{ false, false, false, true, true }, .{ false, false, true, true, true } };
    for (std.enums.values(finite.Comparison), expected) |op, answers| {
        var output: [5]Outcome = undefined;
        compare(column, 0, op, &output);
        for (output, answers) |actual, answer| try t.expectEqual(answer, actual.truth.selects());
        compare(.{ .constant = .{ .value = .{ .value = .{ .atom = .{ .signed = 0 } } }, .len = 5 } }, 0, op, &output);
        for (output) |actual| try t.expectEqual(answers[2], actual.truth.selects());
    }
}
test "conflict payload exhaustion preserves prefix and releases on reset" {
    const t = std.testing;
    const plan: logical.Plan = .{ .schema = .{ .structure = &.{.{ .name = "n", .type = .int64, .nullable = true }} }, .source_basis = @splat(71), .projection = &.{0} };
    var physical = try init(t.allocator, plan, .{ .rows = 64, .bytes = 4096 });
    defer physical.deinit();
    var alternatives: [8]Alternative = undefined;
    for (&alternatives, 0..) |*item, i| item.* = .{ .counter = i + 1, .replica = 1, .value = .null };
    while (true) {
        physical.append(&.{.{ .conflict = &alternatives }}, .{ .row = physical.len + 1, .boundary = physical.len + 1 }) catch |err| {
            try t.expectEqual(error.BatchFull, err);
            break;
        };
    }
    try t.expect(physical.len > 0 and physical.len < physical.capacity);
    try t.expectEqual(@as(usize, 8), physical.columns[0].view(physical.len).cell(0).conflict.len);
    physical.reset();
    try physical.append(&.{.{ .conflict = &alternatives }}, .{ .row = 1, .boundary = 1 });
}
