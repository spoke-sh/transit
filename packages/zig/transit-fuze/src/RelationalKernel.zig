//! Private bound operators for the relational one-pair work quantum. Stable
//! column IDs resolve once; restore rebinds from the same validated saved plan.
//! Constant one-lane views share the typed kernels without speculative reads.
const std = @import("std");
const r = @import("Relational.zig");
const k = @import("VectorKernel.zig");
const Truth = @import("PredicateTruth.zig").Truth;
const Row = @import("RelationalExecution.zig").Row;
const Self = @This();
const Predicate = struct {
    instructions: [r.max_instructions]k.Instruction = undefined,
    len: u8 = 0,
    fn bind(plan: r.Plan, predicate: r.Predicate) Predicate {
        var result: Predicate = .{ .len = @intCast(predicate.instructions.len) };
        for (predicate.instructions, result.instructions[0..result.len]) |input, *out| out.* = switch (input) {
            .compare => |v| .{ .atom = k.Atom.bindType(.{ .compare = .{ .column = bindColumn(plan, v.column), .op = switch (v.op) {
                .equal => .eq,
                .not_equal => .ne,
                .less => .lt,
                .less_equal => .le,
                .greater => .gt,
                .greater_equal => .ge,
            }, .value = .{ .signed = v.value } } }, .int64) },
            .is_null, .is_not_null => |column| .{ .atom = k.Atom.bindType(.{ .state = .{ .column = bindColumn(plan, column), .value = if (input == .is_null) .null else .value } }, .int64) },
            .negate => .negate,
            .conjunction => .conjunction,
            .disjunction => .disjunction,
        };
        return result;
    }
    pub fn matches(self: *const Predicate, left: ?Row, right: ?Row) bool {
        if (self.len == 0) return true;
        var stack: [r.max_instructions]Truth = undefined;
        var depth: usize = 0;
        for (self.instructions[0..self.len]) |instruction| switch (instruction) {
            .atom => |atom| {
                const value = cell(atom.column, left, right);
                var outcome: [1]k.Outcome = undefined;
                atom.run(atom, .{ .constant = .{ .value = if (value) |v| .{ .value = .{ .atom = .{ .signed = v } } } else .null, .len = 1 } }, 0, &outcome);
                stack[depth] = outcome[0].truth;
                depth += 1;
            },
            .negate => stack[depth - 1] = stack[depth - 1].negate(),
            .conjunction, .disjunction => {
                depth -= 1;
                stack[depth - 1] = if (instruction == .conjunction) stack[depth - 1].conjunction(stack[depth]) else stack[depth - 1].disjunction(stack[depth]);
            },
        };
        return stack[0].selects();
    }
};
filters: [2]Predicate,
predicate: Predicate,
join: [2]u8 = undefined,
outputs: [r.max_outputs]u8 = undefined,
groups: [r.max_groups]u8 = undefined,
pub fn bind(plan: r.Plan) Self {
    var self: Self = .{ .filters = .{ Predicate.bind(plan, plan.source_filters[0]), Predicate.bind(plan, plan.source_filters[1]) }, .predicate = Predicate.bind(plan, plan.filter) };
    if (plan.join) |join| self.join = .{ bindColumn(plan, join.left), bindColumn(plan, join.right) };
    for (plan.outputs, self.outputs[0..plan.outputs.len]) |field, *out| out.* = switch (field.expression) {
        .column, .count, .sum => |column| bindColumn(plan, column),
        .count_all => 0,
    };
    for (plan.group_by, self.groups[0..plan.group_by.len]) |column, *out| out.* = bindColumn(plan, column);
    return self;
}
fn bindColumn(plan: r.Plan, column: r.Column) u8 {
    return @as(u8, @intCast(plan.sources[column.source].schema.index(column.id) catch unreachable)) | (column.source << 7);
}
pub fn cell(column: u8, left: ?Row, right: ?Row) ?i64 {
    const row = (if (column < 128) left else right) orelse return null;
    return row.values[column & 127];
}
