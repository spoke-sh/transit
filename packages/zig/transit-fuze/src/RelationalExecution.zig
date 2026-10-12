//! Bounded finite relational execution. Sources supply immutable, ordered rows;
//! Groups owns external keyed state. Neither interface grants disclosure rights.
//! The owner validates every source on every step and publishes only completion.
const std = @import("std");
const r = @import("Relational.zig");
const table = @import("TableSchema.zig");
const Truth = @import("PredicateTruth.zig").Truth;
pub const Cell = @import("Types.zig").Values.Cell;

/// Only admitted int64 columns are decoded into this bounded operator vector.
/// Positions are schema ordinals. Other stored column types remain unreferenced.
pub const Row = struct {
    identity: r.RowIdentity,
    values: [table.max_columns]?i64 = @splat(null),
};
pub const Pair = struct { left: r.RowIdentity, right: ?r.RowIdentity };
pub const Key = struct {
    values: [r.max_groups]?i64 = @splat(null),
    len: u8 = 0,
    pub fn order(a: Key, b: Key) std.math.Order {
        for (a.values[0..@min(a.len, b.len)], b.values[0..@min(a.len, b.len)]) |left, right| {
            const result = r.groupOrder(left, right);
            if (result != .eq) return result;
        }
        return std.math.order(a.len, b.len);
    }
};
pub const Group = struct {
    key: Key,
    states: [r.max_outputs]r.AggregateState = @splat(.{}),
};
pub const Output = struct {
    identity: union(enum) { pair: Pair, group: Key },
    cells: [r.max_outputs]Cell = @splat(.null),
    len: u8,
};
pub const Failure = struct { pair: Pair, output: u8, group: Key };
pub const Event = union(enum) { progress, row: Output, complete };

/// Sources.next(source, after) returns one immutable row, strictly after the
/// identity, or null only with complete coverage. Sources.validate checks the
/// entire sealed basis and current rights, including noncontributing sources.
/// Groups.get/put/next operate on an execution-private external ordered map;
/// put atomically replaces one group. next uses exclusive lexicographic order.
/// Owners account their own bounded pages/caches in addition to residentBytes.
pub fn Execution(comptime Sources: type, comptime Groups: type) type {
    return struct {
        const Self = @This();
        bound: r.Bound,
        sources: Sources,
        groups: Groups,
        phase: enum { input, empty_right, output, complete, failed } = .input,
        left: ?Row = null,
        after_left: ?r.RowIdentity = null,
        after_right: ?r.RowIdentity = null,
        matched: bool = false,
        right_covered: bool = false,
        grouped: bool,
        group_count: u64 = 0,
        after_group: ?Key = null,
        work: u64 = 0,
        result_rows: u64 = 0,
        result_bytes: u64 = 0,
        failure: ?Failure = null,

        // Includes the retained cursor, one source row, candidate group/output
        // and eager predicate stack. It is independent of rows/groups retained.
        pub const residentBytes = @sizeOf(Self) + @sizeOf(Row) + 2 * @sizeOf(Group) + @sizeOf(Output) + r.max_instructions * @sizeOf(Truth);

        pub fn init(bound: r.Bound, sources: Sources, groups: Groups) !Self {
            try bound.validate();
            if (bound.plan.budgets.resident_bytes < residentBytes) return error.RelationalResidentBudget;
            var grouped = bound.plan.group_by.len != 0;
            for (bound.plan.outputs) |field| if (field.expression != .column) {
                grouped = true;
            };
            var fields: [r.max_outputs]@import("Types.zig").Field = undefined;
            var bytes: [@import("Types.zig").max_encoding_bytes]u8 = undefined;
            const encoded = try (try bound.plan.outputSchema(&fields)).encode(&bytes);
            if (encoded.len > bound.plan.budgets.result_bytes) return error.RelationalResultBudget;
            try sources.validate(bound);
            return .{ .bound = bound, .sources = sources, .groups = groups, .grouped = grouped, .result_bytes = encoded.len };
        }

        /// Each call performs at most one source read and one group update.
        /// A failed execution is terminal; its provisional state is not a result.
        pub fn step(self: *Self) !Event {
            if (self.phase == .failed) return error.FailedRelationalQuery;
            errdefer self.phase = .failed;
            try self.sources.validate(self.bound);
            if (self.phase == .complete) return .complete;
            try self.charge();
            return switch (self.phase) {
                .input => self.input(),
                .empty_right => self.coverEmptyRight(),
                .output => self.output(),
                else => unreachable,
            };
        }

        fn charge(self: *Self) !void {
            if (self.work == self.bound.plan.budgets.work_steps) return error.RelationalWorkBudget;
            self.work += 1;
        }
        fn read(self: *Self, source: u8, after: ?r.RowIdentity) !?Row {
            const row = (try self.sources.next(source, after)) orelse return null;
            try row.identity.validate();
            if (after) |id| if (identityOrder(row.identity, id) != .gt) return error.InvalidRelationalSourceOrder;
            // Validate referenced nonnullable cells even when a filter discards
            // this row. Storage's general schema validation remains its owner.
            const schema = self.bound.plan.sources[source].schema;
            for (schema.columns, 0..) |column, i| {
                if (column.type == .int64 and !column.nullable and row.values[i] == null) return error.InvalidRelationalSourceRow;
            }
            return row;
        }
        fn input(self: *Self) !Event {
            const plan = self.bound.plan;
            if (self.left == null) {
                const row = (try self.read(0, self.after_left)) orelse {
                    if (plan.join != null and !self.right_covered) {
                        self.phase = .empty_right;
                        return .progress;
                    }
                    return self.endInput();
                };
                self.after_left = row.identity;
                if (!matches(plan, plan.source_filters[0], row, null)) return .progress;
                self.left = row;
                self.after_right = null;
                self.matched = false;
                if (plan.join != null) return .progress;
                self.left = null;
                return self.contribute(row, null);
            }
            const left = self.left.?;
            if (try self.read(1, self.after_right)) |right| {
                self.after_right = right.identity;
                if (!matches(plan, plan.source_filters[1], null, right)) return .progress;
                const join = plan.join.?;
                if (!r.joinMatches(cell(plan, join.left, left, right), cell(plan, join.right, left, right))) return .progress;
                self.matched = true;
                return self.contribute(left, right);
            }
            self.right_covered = true;
            self.left = null;
            if (!self.matched and plan.join.?.kind == .left) return self.contribute(left, null);
            return .progress;
        }
        fn coverEmptyRight(self: *Self) !Event {
            if (try self.read(1, self.after_right)) |row| {
                self.after_right = row.identity;
                return .progress;
            }
            return self.endInput();
        }
        fn endInput(self: *Self) !Event {
            if (!self.grouped) {
                try self.sources.validate(self.bound);
                self.phase = .complete;
                return .complete;
            }
            if (self.group_count == 0 and self.bound.plan.group_by.len == 0) {
                try self.groups.put(.{ .key = .{} });
                self.group_count = 1;
            }
            self.phase = .output;
            return .progress;
        }
        fn contribute(self: *Self, left: Row, right: ?Row) !Event {
            const plan = self.bound.plan;
            if (!matches(plan, plan.filter, left, right)) return .progress;
            const pair: Pair = .{ .left = left.identity, .right = if (right) |row| row.identity else null };
            if (!self.grouped) {
                var result: Output = .{ .identity = .{ .pair = pair }, .len = @intCast(plan.outputs.len) };
                for (plan.outputs, 0..) |field, i| result.cells[i] = integer(cell(plan, field.expression.column, left, right));
                return self.emit(result);
            }
            var key: Key = .{ .len = @intCast(plan.group_by.len) };
            for (plan.group_by, 0..) |column, i| key.values[i] = cell(plan, column, left, right);
            const previous = try self.groups.get(key);
            var group = previous orelse Group{ .key = key };
            // Preserve first failure by contributor then output position. The
            // store sees nothing until every candidate aggregate succeeds.
            for (plan.outputs, 0..) |field, i| {
                const observed: error{Overflow}!void = switch (field.expression) {
                    .column => {},
                    .count_all => group.states[i].observe(.count_all, null),
                    .count => |column| group.states[i].observe(.count, cell(plan, column, left, right)),
                    .sum => |column| group.states[i].observe(.sum, cell(plan, column, left, right)),
                };
                observed catch |err| {
                    self.failure = .{ .pair = pair, .output = @intCast(i), .group = key };
                    return err;
                };
            }
            try self.groups.put(group);
            if (previous == null) self.group_count = try std.math.add(u64, self.group_count, 1);
            return .progress;
        }
        fn output(self: *Self) !Event {
            const group = (try self.groups.next(self.after_group)) orelse {
                if (self.result_rows != self.group_count) return error.IncompleteRelationalGroups;
                try self.sources.validate(self.bound);
                self.phase = .complete;
                return .complete;
            };
            if (self.after_group) |after| if (group.key.order(after) != .gt) return error.InvalidRelationalGroupOrder;
            if (group.key.len != self.bound.plan.group_by.len) return error.InvalidRelationalGroup;
            var result: Output = .{ .identity = .{ .group = group.key }, .len = @intCast(self.bound.plan.outputs.len) };
            for (self.bound.plan.outputs, 0..) |field, i| result.cells[i] = switch (field.expression) {
                .column => |column| value: {
                    for (self.bound.plan.group_by, 0..) |key, j| if (key.eql(column)) break :value integer(group.key.values[j]);
                    unreachable;
                },
                .count_all => .{ .value = .{ .atom = .{ .unsigned = group.states[i].rows } } },
                .count => .{ .value = .{ .atom = .{ .unsigned = group.states[i].values } } },
                .sum => integer(group.states[i].sum),
            };
            self.after_group = group.key;
            return self.emit(result);
        }
        fn emit(self: *Self, result: Output) !Event {
            if (self.result_rows == self.bound.plan.budgets.output_rows) return error.RelationalResultBudget;
            var bytes = self.result_bytes;
            for (result.cells[0..result.len]) |value| bytes = std.math.add(u64, bytes, 5 + @as(u64, if (value == .null) 0 else 8)) catch return error.RelationalResultBudget;
            if (bytes > self.bound.plan.budgets.result_bytes) return error.RelationalResultBudget;
            try self.sources.validate(self.bound);
            self.result_rows += 1;
            self.result_bytes = bytes;
            return .{ .row = result };
        }
    };
}

pub fn identityOrder(a: r.RowIdentity, b: r.RowIdentity) std.math.Order {
    inline for (.{ "origin", "operation", "ordinal" }) |field| {
        const order = std.math.order(@field(a, field), @field(b, field));
        if (order != .eq) return order;
    }
    return .eq;
}
fn integer(value: ?i64) Cell {
    return if (value) |v| .{ .value = .{ .atom = .{ .signed = v } } } else .null;
}
fn cell(plan: r.Plan, column: r.Column, left: ?Row, right: ?Row) ?i64 {
    const row = (if (column.source == 0) left else right) orelse return null;
    return row.values[plan.sources[column.source].schema.index(column.id) catch unreachable];
}
/// Plan admission establishes bounded stack shape and column capabilities.
fn matches(plan: r.Plan, predicate: r.Predicate, left: ?Row, right: ?Row) bool {
    if (predicate.instructions.len == 0) return true;
    var stack: [r.max_instructions]Truth = undefined;
    var depth: usize = 0;
    for (predicate.instructions) |instruction| switch (instruction) {
        .compare => |expression| {
            stack[depth] = if (cell(plan, expression.column, left, right)) |value| Truth.fromBool(switch (expression.op) {
                .equal => value == expression.value,
                .not_equal => value != expression.value,
                .less => value < expression.value,
                .less_equal => value <= expression.value,
                .greater => value > expression.value,
                .greater_equal => value >= expression.value,
            }) else .unknown;
            depth += 1;
        },
        .is_null, .is_not_null => |column| {
            stack[depth] = Truth.fromBool((cell(plan, column, left, right) == null) == (instruction == .is_null));
            depth += 1;
        },
        .negate => stack[depth - 1] = stack[depth - 1].negate(),
        .conjunction, .disjunction => {
            const right_value = stack[depth - 1];
            depth -= 1;
            stack[depth - 1] = if (instruction == .conjunction) stack[depth - 1].conjunction(right_value) else stack[depth - 1].disjunction(right_value);
        },
    };
    return stack[0].selects();
}

test {
    _ = @import("relational_execution_test.zig");
}
