//! Owned physical batches for admitted logical plans. No I/O, authority or published progress.
//! Flat values and five-state sidecars retain source order and conflict payloads.
test {
    _ = @import("batch_program_test.zig");
}
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
    implementation: kernels.cpu.Implementation = .automatic,
    pub fn validate(self: Limits) !void {
        if (self.rows == 0 or self.rows > 1024 or self.bytes < 4096 or self.bytes > 1024 * 1024) return error.InvalidBatchBudget;
    }
};
pub const Provenance = @import("BatchProvenance.zig");
pub const kernels = @import("VectorKernel.zig");
pub const Detail = kernels.Detail;
pub const Column = kernels.Column;
pub const View = kernels.View;
pub const Outcome = kernels.Outcome;
/// Host-owned execution resource. The callback must join all work before return;
/// it may not retain the batch or publish results. Null keeps local execution.
pub const Runner = struct {
    context: *anyopaque,
    evaluate: *const fn (*anyopaque, *Self, ?*const std.atomic.Value(bool)) anyerror!void,
    cancellation: ?*const std.atomic.Value(bool) = null,
};
allocator: std.mem.Allocator,
backing: []u8,
memory: std.heap.FixedBufferAllocator,
/// Independently owned, validated snapshot. Treat as immutable until deinit.
plan: logical.Plan,
fingerprint: [32]u8,
kernel: kernels.Program,
views: []View,
sites: []u8,
scratch: []finite.Truth,
temporary: []Outcome,
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
    const implementation = try kernels.cpu.resolve(limits.implementation);
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
    const instruction_count = if (owned.predicate == .program) owned.predicate.program.instructions.len else 1;
    const instructions = a.alloc(kernels.Instruction, instruction_count) catch return error.BatchBudgetExceeded;
    const kernel = kernels.Program.bind(owned, instructions);
    for (instructions) |*instruction| if (instruction.* == .atom) {
        instruction.atom.implementation = implementation;
    };
    const columns = a.alloc(Column, owned.schema.structure.len) catch return error.BatchBudgetExceeded;
    const views = a.alloc(View, columns.len) catch return error.BatchBudgetExceeded;
    var row_bytes: usize = @sizeOf(Provenance) + 2 * @sizeOf(Outcome) + @sizeOf(usize) + 1 + kernel.depth * @sizeOf(finite.Truth);
    var retained: [128]bool = @splat(false);
    if (owned.aggregate == .rows or owned.aggregate == .sum) for (owned.projection) |column| {
        retained[column] = true;
    };
    for (kernel.instructions) |instruction| if (instruction == .atom) {
        const atom = instruction.atom;
        // A comparison carries a typed literal; state/all kernels never read values.
        if (atom.uses_values) retained[atom.column] = true;
    };
    for (owned.schema.structure, 0..) |field, i| row_bytes += Column.rowBytes(field.type, retained[i]);
    // Half of the remaining arena is reserved for conflict alternatives. Width
    // reduces the compute target; it never raises the caller's byte allowance.
    const capacity = @min(limits.rows, (backing.len - memory.end_index) / (2 * row_bytes));
    if (capacity == 0) return error.BatchBudgetExceeded;
    for (columns, owned.schema.structure, 0..) |*column, field, i| column.* = Column.init(a, field.type, capacity, retained[i]) catch return error.BatchBudgetExceeded;
    const sites = a.alloc(u8, capacity) catch return error.BatchBudgetExceeded;
    const scratch = a.alloc(finite.Truth, capacity * kernel.depth) catch return error.BatchBudgetExceeded;
    const temporary = a.alloc(Outcome, capacity) catch return error.BatchBudgetExceeded;
    const provenance = a.alloc(Provenance, capacity) catch return error.BatchBudgetExceeded;
    const outcomes = a.alloc(Outcome, capacity) catch return error.BatchBudgetExceeded;
    const selection = a.alloc(usize, capacity) catch return error.BatchBudgetExceeded;
    return .{ .allocator = allocator, .backing = backing, .memory = memory, .plan = owned, .fingerprint = fingerprint, .kernel = kernel, .views = views, .sites = sites, .scratch = scratch, .temporary = temporary, .columns = columns, .provenance = provenance, .outcomes = outcomes, .selection = selection, .capacity = capacity, .payload_start = memory.end_index };
}
pub fn predicateFailure(self: *const Self, row: usize) logical.Plan.PredicateFailure {
    const index = self.sites[row];
    return .{ .column = self.kernel.instructions[index].atom.column, .instruction = index };
}
fn copyPlan(a: std.mem.Allocator, source: logical.Plan) !logical.Plan {
    var result = source;
    result.schema = try source.schema.cloneInto(a);
    result.projection = try a.dupe(u8, source.projection);
    const names = try a.dupe(?[]const u8, source.output_names);
    for (names) |*name| if (name.*) |text| {
        name.* = try a.dupe(u8, text);
    };
    result.output_names = names;
    switch (source.predicate) {
        .program => |program| {
            const instructions = try a.dupe(logical.Program.Instruction, program.instructions);
            for (instructions) |*instruction| if (instruction.* == .atom and instruction.atom == .compare) {
                instruction.atom.compare.value = try types.Values.cloneAtom(a, instruction.atom.compare.value);
            };
            result.predicate.program.instructions = instructions;
        },
        .compare => |atom| result.predicate.compare.value = try types.Values.cloneAtom(a, atom.value),
        else => {},
    }
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
    try self.plan.collations.validateCells(cells);
    if (self.len == self.capacity) return error.BatchFull;
    if (cells.len != self.columns.len) return error.InvalidColumnCount;
    if (provenance.row == 0 or provenance.boundary == 0) return error.InvalidProvenance;
    if (self.len > 0 and provenance.row <= self.provenance[self.len - 1].row) return error.InvalidProvenance;
    if (provenance.identity) |identity| try identity.validate();
    const previous = self.memory.end_index;
    errdefer self.memory.end_index = previous;
    for (cells, self.columns) |cell, column| column.append(self.memory.allocator(), self.len, cell) catch return error.BatchFull;
    self.provenance[self.len] = provenance;
    self.len += 1;
}
/// Computes outcomes without committing progress or arbitrating later failures.
/// The ordered consumer applies LIMIT and aggregate errors at each source row.
pub fn evaluate(self: *Self) void {
    self.prepareViews();
    self.evaluateRange(0, self.len);
}
pub fn prepareViews(self: *Self) void {
    for (self.views, self.columns) |*view, column| view.* = column.view(self.len);
}
/// Disjoint ranges may run concurrently after prepareViews. Every writable slice
/// is partitioned by original lane, including the Boolean stack workspace.
pub fn evaluateRange(self: *Self, start: usize, end: usize) void {
    std.debug.assert(start <= end and end <= self.len);
    self.kernel.evaluate(self.views, start, self.outcomes[start..end], self.sites[start..end], self.scratch[start * self.kernel.depth .. end * self.kernel.depth], self.temporary[start..end]);
}
/// Allocation-free int64 comparison; the general program uses this same kernel.
pub fn compare(column: View, literal: i64, op: finite.Comparison, output: []Outcome) void {
    const atom = kernels.Atom.bind(.{ .compare = .{ .column = 0, .op = op, .value = .{ .signed = literal } } }, .{ .structure = &.{.{ .name = "value", .type = .int64 }} });
    atom.run(atom, column, 0, output);
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
    invalid.projection = &.{127};
    try t.expectError(error.UnknownColumn, init(t.allocator, invalid, .{}));
}

test "comparison constants and extreme signed values retain all six operator answers" {
    const t = std.testing;
    const values = [_]i64{ std.math.minInt(i64), -1, 0, 1, std.math.maxInt(i64) };
    const states = [_]types.State{ .value, .value, .value, .value, .value };
    const details: [5]Detail = @splat(.none);
    const column: View = .{ .flat = .{ .type = .int64, .data = .{ .words = std.mem.bytesAsSlice(u64, std.mem.sliceAsBytes(&values)) }, .states = &states, .details = &details } };
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
