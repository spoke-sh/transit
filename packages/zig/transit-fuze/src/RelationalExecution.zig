//! Bounded finite relational execution. Sources supply immutable, ordered rows;
//! Groups owns external keyed state. Neither interface grants disclosure rights.
//! The owner validates every source on every step and publishes only completion.
const std = @import("std");
const r = @import("Relational.zig");
const Checkpoint = @import("RelationalCheckpoint.zig");
const table = @import("TableSchema.zig");
const Kernel = @import("RelationalKernel.zig");
const Truth = @import("PredicateTruth.zig").Truth;
const v = @import("RelationalValues.zig");
pub const Cell = @import("Types.zig").Values.Cell;

/// Positions are schema ordinals. Text views borrow buffer unless constructed
/// over immutable caller data. Move an owned row or clone it; never release two
/// copies of the same buffer.
pub const Row = struct {
    identity: r.RowIdentity,
    values: [r.row_columns]v.Value = @splat(null),
    buffer: v.Buffer = .{},
    pub fn fromCells(allocator: std.mem.Allocator, identity: r.RowIdentity, columns: []const table.Column, cells: []const Cell) !Row {
        if (columns.len != cells.len or columns.len > table.max_columns) return error.InvalidRelationalSourceRow;
        var result: Row = .{ .identity = identity };
        for (columns, cells, 0..) |column, value, i| {
            if (!v.supported(column.type)) continue;
            result.values[i] = try v.fromCell(value, column);
        }
        result.buffer = try v.Buffer.copy(allocator, &result.values);
        return result;
    }
    pub fn clone(self: Row, allocator: std.mem.Allocator) !Row {
        var result = self;
        result.buffer = try v.Buffer.copy(allocator, &result.values);
        return result;
    }
    pub fn borrow(self: Row) Row {
        var result = self;
        result.buffer = .{};
        return result;
    }
    pub fn deinit(self: *Row) void {
        self.buffer.deinit();
        self.* = undefined;
    }
};
/// Source adapters prepare the shared scalar program once, while they still
/// have full typed cells (including ranges and vectors). Only computed scalar
/// values cross the relational row/exchange boundary.
pub const Projection = struct {
    plan: ?r.Plan = null,
    workspace: r.ScalarProgram.Workspace = .{},
    pub fn init(plan: r.Plan) !Projection {
        var result: Projection = .{ .plan = plan };
        if (plan.scalars.instructions.len != 0) {
            var fields: [table.max_columns]@import("Types.zig").Field = undefined;
            try plan.scalars.prepare((try plan.sources[0].schema.rowType(&fields)).structure, &result.workspace);
        }
        return result;
    }
    pub fn row(self: *Projection, allocator: std.mem.Allocator, identity: r.RowIdentity, source: u8, columns: []const table.Column, cells: []const Cell) !Row {
        var result = try Row.fromCells(allocator, identity, columns, cells);
        errdefer result.deinit();
        const plan = self.plan orelse return result;
        if (source != 0 or plan.scalars.instructions.len == 0) return result;
        const kernel = Kernel.bind(plan);
        // Preserve the existing filter-before-projection scalar failure frontier.
        if (!kernel.filters[0].matches(result, null) or !kernel.predicate.matches(result, null)) return result;
        const computed = try plan.scalars.evaluate(cells, &self.workspace);
        for (computed, self.workspace.fields[0..computed.len], 0..) |cell, field, i| {
            if (!v.supported(field.type)) continue;
            result.values[table.max_columns + i] = try v.fromCell(cell, .{ .id = i + 1, .name = field.name, .type = field.type, .nullable = field.nullable });
        }
        const buffer = try v.Buffer.copy(allocator, &result.values);
        result.buffer.deinit();
        result.buffer = buffer;
        return result;
    }
};
pub const Key = @import("RelationalKey.zig");
pub const Pair = Key.Pair;
pub const Group = struct {
    key: Key,
    states: [r.max_outputs]r.AggregateState = @splat(.{}),
    pub fn deinit(self: *Group) void {
        self.key.deinit();
        self.* = undefined;
    }
};
pub const Identity = union(enum) {
    pair: Pair,
    group: Key,
    pub fn clone(self: Identity, allocator: std.mem.Allocator) !Identity {
        return switch (self) {
            .pair => self,
            .group => |key| .{ .group = try key.clone(allocator) },
        };
    }
    pub fn deinit(self: *Identity) void {
        if (self.* == .group) self.group.deinit();
        self.* = undefined;
    }
};
pub const Output = struct {
    identity: Identity,
    ordering: ?Key = null,
    cells: [r.max_outputs]Cell = @splat(.null),
    len: u8,
    buffer: v.Buffer = .{},
    pub fn clone(self: Output, allocator: std.mem.Allocator) !Output {
        var result = self;
        result.buffer = .{};
        result.ordering = null;
        if (self.identity == .group) result.identity.group = try self.identity.group.clone(allocator);
        errdefer if (result.identity == .group) result.identity.group.deinit();
        if (self.ordering) |key| result.ordering = try key.clone(allocator);
        errdefer if (result.ordering) |*key| key.deinit();
        result.buffer = try v.Buffer.copyCells(allocator, result.cells[0..result.len]);
        return result;
    }
    pub fn deinit(self: *Output) void {
        self.buffer.deinit();
        self.identity.deinit();
        if (self.ordering) |*key| key.deinit();
        self.* = undefined;
    }
    pub fn canonicalBytes(self: Output) !u64 {
        var total: u64 = 0;
        for (self.cells[0..self.len]) |cell| total = try std.math.add(u64, total, try v.cellBytes(cell));
        return total;
    }
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
        allocator: std.mem.Allocator,
        bound: r.Bound,
        kernel: Kernel,
        sources: Sources,
        groups: Groups,
        phase: Checkpoint.Phase = .input,
        left: ?Row = null,
        after_left: ?r.RowIdentity = null,
        after_right: ?r.RowIdentity = null,
        matched: bool = false,
        right_covered: bool = false,
        grouped: bool,
        group_count: u64 = 0,
        sorted_count: u64 = 0,
        visited_groups: u64 = 0,
        after_group: ?Key = null,
        work: u64 = 0,
        result_rows: u64 = 0,
        result_bytes: u64 = 0,
        failure: ?Failure = null,

        // Includes the retained cursor, one source row, candidate group/output
        // and eager predicate stack. It is independent of rows/groups retained.
        pub const residentBytes = @sizeOf(Self) + @sizeOf(Row) + 2 * @sizeOf(Group) + @sizeOf(Output) + r.max_instructions * @sizeOf(Truth);

        pub fn init(allocator: std.mem.Allocator, bound: r.Bound, sources: Sources, groups: Groups) !Self {
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
            return .{ .allocator = allocator, .bound = bound, .kernel = Kernel.bind(bound.plan), .sources = sources, .groups = groups, .grouped = grouped, .result_bytes = encoded.len };
        }

        pub fn deinit(self: *Self) void {
            if (self.left) |*row| row.deinit();
            if (self.after_group) |*key| key.deinit();
            if (self.failure) |*failure| failure.group.deinit();
            self.* = undefined;
        }

        /// The host must bind this root and cursor to the same atomic publication.
        pub fn checkpoint(self: Self, root: ?@import("RelationalIndex.zig").Reference) !Checkpoint {
            var result: Checkpoint = .{ .binding = try self.bound.fingerprint(), .root = root };
            inline for (comptime std.meta.fieldNames(Checkpoint)) |field| {
                if (comptime !std.mem.eql(u8, field, "binding") and !std.mem.eql(u8, field, "root")) @field(result, field) = @field(self, field);
            }
            // Checkpoint is an encoding view until the next executor mutation.
            if (result.left) |*row| row.* = row.borrow();
            if (result.after_group) |*key| key.* = key.borrow();
            if (result.failure) |*failure| failure.group = failure.group.borrow();
            try result.validate(self.bound);
            return result;
        }
        /// Adapters reopen exactly the checkpoint's group root and retained cuts.
        /// Current authorization is checked before accepting any saved progress.
        pub fn restore(allocator: std.mem.Allocator, bound: r.Bound, sources: Sources, groups: Groups, saved: Checkpoint) !Self {
            try saved.validate(bound);
            var result = try Self.init(allocator, bound, sources, groups);
            errdefer result.deinit();
            inline for (comptime std.meta.fieldNames(Checkpoint)) |field| {
                if (comptime !std.mem.eql(u8, field, "binding") and !std.mem.eql(u8, field, "root") and !std.mem.eql(u8, field, "left") and !std.mem.eql(u8, field, "after_group") and !std.mem.eql(u8, field, "failure")) @field(result, field) = @field(saved, field);
            }
            if (saved.left) |row| result.left = try row.clone(allocator);
            if (saved.after_group) |key| result.after_group = try key.clone(allocator);
            if (saved.failure) |failure| result.failure = .{ .pair = failure.pair, .output = failure.output, .group = try failure.group.clone(allocator) };
            return result;
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
                .sorting => self.sorting(),
                .output => self.output(),
                else => unreachable,
            };
        }

        fn charge(self: *Self) !void {
            if (self.work == self.bound.plan.budgets.work_steps) return error.RelationalWorkBudget;
            self.work += 1;
        }
        fn read(self: *Self, source: u8, after: ?r.RowIdentity) !?Row {
            var row = (try self.sources.next(source, after)) orelse return null;
            errdefer row.deinit();
            _ = try v.payloadLength(&row.values);
            try row.identity.validate();
            if (after) |id| if (identityOrder(row.identity, id) != .gt) return error.InvalidRelationalSourceOrder;
            // Validate referenced nonnullable cells even when a filter discards
            // this row. Storage's general schema validation remains its owner.
            const schema = self.bound.plan.sources[source].schema;
            for (schema.columns, 0..) |column, i| {
                if (v.supported(column.type)) try v.validate(row.values[i], column) else if (row.values[i] != null) return error.InvalidRelationalSourceRow;
            }
            return row;
        }
        fn input(self: *Self) !Event {
            const plan = self.bound.plan;
            if (self.left == null) {
                var row = (try self.read(0, self.after_left)) orelse {
                    if (plan.join != null and !self.right_covered) {
                        self.phase = .empty_right;
                        return .progress;
                    }
                    return self.endInput();
                };
                defer row.deinit();
                self.after_left = row.identity;
                if (!self.kernel.filters[0].matches(row, null)) return .progress;
                self.after_right = null;
                self.matched = false;
                if (plan.join != null) {
                    self.left = row;
                    row.buffer = .{};
                    return .progress;
                }
                return self.contribute(row, null);
            }
            const left = self.left.?;
            if (try self.read(1, self.after_right)) |owned_right| {
                var right = owned_right;
                defer right.deinit();
                self.after_right = right.identity;
                if (!self.kernel.filters[1].matches(null, right)) return .progress;
                const a = Kernel.cell(self.kernel.join[0], left, right);
                const b = Kernel.cell(self.kernel.join[1], left, right);
                if (!try r.joinMatches(a, b, try plan.resolveColumn(plan.join.?.left))) return .progress;
                self.matched = true;
                return self.contribute(left, right);
            }
            self.right_covered = true;
            self.left = null;
            var owned_left = left;
            defer owned_left.deinit();
            if (!self.matched and plan.join.?.kind == .left) return self.contribute(left, null);
            return .progress;
        }
        fn coverEmptyRight(self: *Self) !Event {
            if (try self.read(1, self.after_right)) |owned| {
                var row = owned;
                defer row.deinit();
                self.after_right = row.identity;
                return .progress;
            }
            return self.endInput();
        }
        fn endInput(self: *Self) !Event {
            if (!self.bound.plan.usesGroups()) {
                try self.sources.validate(self.bound);
                self.phase = .complete;
                return .complete;
            }
            if (self.grouped and self.group_count == 0 and self.bound.plan.group_by.len == 0) {
                try self.groups.put(.{ .key = .{} });
                self.group_count = 1;
            }
            self.phase = if (self.bound.plan.hasAggregateOrder()) .sorting else .output;
            return .progress;
        }
        fn contribute(self: *Self, left: Row, right: ?Row) !Event {
            const plan = self.bound.plan;
            if (!self.kernel.predicate.matches(left, right)) return .progress;
            const pair: Pair = .{ .left = left.identity, .right = if (right) |row| row.identity else null };
            if (!plan.usesGroups()) {
                if (plan.limit) |limit| if (self.result_rows >= limit) {
                    try self.sources.validate(self.bound);
                    self.phase = .complete;
                    return .complete;
                };
                var result: Output = .{ .identity = .{ .pair = pair }, .len = @intCast(plan.outputs.len) };
                for (self.kernel.outputs[0..plan.outputs.len], 0..) |column, i| result.cells[i] = v.cell(Kernel.cell(column, left, right));
                const emitted = try self.emit(result);
                if (plan.limit) |limit| if (self.result_rows >= limit) {
                    self.phase = .complete;
                };
                return emitted;
            }
            var keys_buf: [r.max_groups]r.Column = undefined;
            const keys = plan.keyColumns(&keys_buf);
            var key: Key = .{ .pair = if (self.grouped) null else pair, .len = @intCast(keys.len) };
            for (self.kernel.groups[0..keys.len], 0..) |column, i| key.values[i] = Kernel.cell(column, left, right);
            const previous = if (self.grouped) try self.groups.get(key) else null;
            var group = previous orelse Group{ .key = try key.clone(self.allocator) };
            defer group.deinit();
            if (self.grouped) {
                var states_buf: [r.max_outputs]r.Expression = undefined;
                const states = plan.stateExpressions(&states_buf) catch unreachable;
                // Preserve first failure by contributor then output position. The
                // store sees nothing until every candidate aggregate succeeds.
                for (states, 0..) |expr, i| {
                    const observed: error{Overflow}!void = switch (expr) {
                        .column => {},
                        .count_all => group.states[i].observe(.count_all, null),
                        .count => group.states[i].observe(.count, if (Kernel.cell(self.kernel.outputs[i], left, right) != null) 0 else null),
                        .sum => |column| blk: {
                            const kind = (plan.resolveColumn(column) catch unreachable).type;
                            const value = Kernel.cell(self.kernel.outputs[i], left, right);
                            break :blk if (kind == .decimal)
                                group.states[i].observeDecimal(if (value) |present| present.decimal else null, kind)
                            else
                                group.states[i].observe(.sum, if (value) |present| present.integer else null);
                        },
                    };
                    observed catch |err| {
                        // Preserve an observed arithmetic witness without making
                        // another allocation after that failure. The candidate
                        // already owns the group's canonical representative.
                        self.failure = .{ .pair = pair, .output = @intCast(i), .group = group.key };
                        group.key = .{};
                        return err;
                    };
                }
            }
            try self.groups.put(group);
            if (previous == null) self.group_count = try std.math.add(u64, self.group_count, 1);
            return .progress;
        }
        fn output(self: *Self) !Event {
            const plan = self.bound.plan;
            if (plan.limit) |limit| if (self.result_rows >= limit) {
                try self.sources.validate(self.bound);
                self.phase = .complete;
                return .complete;
            };
            var group = (try self.nextGroup()) orelse {
                if (self.visited_groups != (if (plan.hasAggregateOrder()) self.sorted_count else self.group_count)) return error.IncompleteRelationalGroups;
                try self.sources.validate(self.bound);
                self.phase = .complete;
                return .complete;
            };
            defer group.deinit();
            var keys_buf: [r.max_groups]r.Column = undefined;
            const keys = plan.keyColumns(&keys_buf);
            if (group.key.len != keys.len or self.grouped != (group.key.pair == null)) return error.InvalidRelationalGroup;
            const next = try group.key.clone(self.allocator);
            if (self.after_group) |*after| after.deinit();
            self.after_group = next;
            self.visited_groups = try std.math.add(u64, self.visited_groups, 1);
            if (self.grouped and !try self.matchesHaving(group)) return .progress;
            var result: Output = .{
                .identity = if (self.grouped) .{ .group = group.key } else .{ .pair = group.key.pair.? },
                .len = @intCast(plan.outputs.len),
                .ordering = if (plan.order_by.len != 0) group.key.borrow() else null,
            };
            if (result.identity == .group) {
                result.identity.group = group.key.borrow();
                result.identity.group.sorted = false;
                result.identity.group.sort_len = 0;
                result.identity.group.sort_values = @splat(null);
            }
            for (plan.outputs, 0..) |field, i| result.cells[i] = switch (field.expression) {
                .column => |column| value: {
                    for (keys, 0..) |key, j| if (key.eql(column)) break :value v.cell(group.key.values[j]);
                    unreachable;
                },
                .count_all => .{ .value = .{ .atom = .{ .unsigned = group.states[i].rows } } },
                .count => .{ .value = .{ .atom = .{ .unsigned = group.states[i].values } } },
                .sum => |column| sumCell(group.states[i].sum, (try plan.resolveColumn(column)).type),
            };
            const emitted = try self.emit(result);
            if (plan.limit) |limit| if (self.result_rows >= limit) {
                self.phase = .complete;
            };
            return emitted;
        }
        /// One finalized group per step, with one bounded external-tree insert.
        fn sorting(self: *Self) !Event {
            var group = (try self.groups.next(self.after_group)) orelse {
                if (self.visited_groups != self.group_count) return error.IncompleteRelationalGroups;
                if (self.after_group) |*key| key.deinit();
                self.after_group = null;
                self.visited_groups = 0;
                self.phase = .output;
                return .progress;
            };
            defer group.deinit();
            if (self.after_group) |after| if (try group.key.order(after, self.bound.plan) != .gt) return error.InvalidRelationalGroupOrder;
            const cursor = try group.key.clone(self.allocator);
            if (self.after_group) |*after| after.deinit();
            self.after_group = cursor;
            self.visited_groups = try std.math.add(u64, self.visited_groups, 1);
            if (!try self.matchesHaving(group)) return .progress;
            group.key.sorted = true;
            group.key.sort_len = @intCast(self.bound.plan.order_by.len);
            for (self.bound.plan.order_by, 0..) |item, i| {
                group.key.sort_values[i] = try self.expressionValue(group, item.expression);
            }
            try self.groups.put(group);
            self.sorted_count = try std.math.add(u64, self.sorted_count, 1);
            return .progress;
        }
        fn expressionValue(self: *Self, group: Group, expression: r.Expression) !v.Value {
            return switch (expression) {
                .column => |column| group.key.values[findColumnIndex(self.bound.plan.group_by, column) orelse return error.InvalidRelationalGroup],
                .count_all, .count => blk: {
                    const slot = self.bound.plan.findStateSlot(expression) orelse return error.InvalidRelationalGroup;
                    break :blk .{ .unsigned = if (expression == .count_all) group.states[slot].rows else group.states[slot].values };
                },
                .sum => |column| blk: {
                    const slot = self.bound.plan.findStateSlot(expression) orelse return error.InvalidRelationalGroup;
                    var descriptor = try self.bound.plan.resolveColumn(column);
                    descriptor.nullable = true;
                    break :blk try v.fromCell(sumCell(group.states[slot].sum, descriptor.type), descriptor);
                },
            };
        }
        fn nextGroup(self: *Self) !?Group {
            var group = (if (self.bound.plan.hasAggregateOrder()) try self.groups.nextSorted(self.after_group) else try self.groups.next(self.after_group)) orelse return null;
            errdefer group.deinit();
            if (self.after_group) |after| if (try group.key.order(after, self.bound.plan) != .gt) return error.InvalidRelationalGroupOrder;
            return group;
        }
        fn matchesHaving(self: *Self, group: Group) !bool {
            const instructions = self.bound.plan.having.instructions;
            if (instructions.len == 0) return true;
            var stack: [r.max_instructions]Truth = undefined;
            var depth: usize = 0;
            for (instructions) |instruction| switch (instruction) {
                .compare => |item| {
                    const truth: Truth = if (item.value == null) .unknown else switch (item.expression) {
                        .column => |column| blk: {
                            const index = findColumnIndex(self.bound.plan.group_by, column) orelse return error.InvalidRelationalGroup;
                            const val = group.key.values[index] orelse break :blk .unknown;
                            const cmp = try v.order(val, item.value, try self.bound.plan.resolveColumn(column));
                            break :blk Truth.fromBool(matchesComparison(cmp, item.op));
                        },
                        .count_all, .count => blk: {
                            const slot = self.bound.plan.findStateSlot(item.expression) orelse return error.InvalidRelationalGroup;
                            const count_val: u64 = if (item.expression == .count_all) group.states[slot].rows else group.states[slot].values;
                            const rhs = item.value.?.integer;
                            const cmp: std.math.Order = if (rhs < 0) .gt else std.math.order(count_val, @as(u64, @intCast(rhs)));
                            break :blk Truth.fromBool(matchesComparison(cmp, item.op));
                        },
                        .sum => blk: {
                            const slot = self.bound.plan.findStateSlot(item.expression) orelse return error.InvalidRelationalGroup;
                            const sum_val = group.states[slot].sum orelse break :blk .unknown;
                            const cmp = std.math.order(sum_val, if (item.value.? == .decimal) item.value.?.decimal else @as(i128, item.value.?.integer));
                            break :blk Truth.fromBool(matchesComparison(cmp, item.op));
                        },
                    };
                    stack[depth] = truth;
                    depth += 1;
                },
                .is_null, .is_not_null => |expr| {
                    const is_null: bool = switch (expr) {
                        .column => |column| blk: {
                            const index = findColumnIndex(self.bound.plan.group_by, column) orelse return error.InvalidRelationalGroup;
                            break :blk group.key.values[index] == null;
                        },
                        .count_all, .count => false,
                        .sum => blk: {
                            const slot = self.bound.plan.findStateSlot(expr) orelse return error.InvalidRelationalGroup;
                            break :blk group.states[slot].sum == null;
                        },
                    };
                    const matched = if (instruction == .is_null) is_null else !is_null;
                    stack[depth] = Truth.fromBool(matched);
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
        fn emit(self: *Self, result: Output) !Event {
            if (self.result_rows == self.bound.plan.budgets.output_rows) return error.RelationalResultBudget;
            var bytes = self.result_bytes;
            for (result.cells[0..result.len]) |value| bytes = std.math.add(u64, bytes, try v.cellBytes(value)) catch return error.RelationalResultBudget;
            if (bytes > self.bound.plan.budgets.result_bytes) return error.RelationalResultBudget;
            try self.sources.validate(self.bound);
            const owned = try result.clone(self.allocator);
            self.result_rows += 1;
            self.result_bytes = bytes;
            return .{ .row = owned };
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
pub fn pairOrder(a: Pair, b: Pair) std.math.Order {
    const left_cmp = identityOrder(a.left, b.left);
    if (left_cmp != .eq) return left_cmp;
    if (a.right == null and b.right == null) return .eq;
    if (a.right == null) return .lt;
    if (b.right == null) return .gt;
    return identityOrder(a.right.?, b.right.?);
}
pub fn orderValue(left: v.Value, right: v.Value, descriptor: table.Column, direction: r.Direction, nulls: r.NullOrder) !std.math.Order {
    if (left == null and right == null) return .eq;
    if (left == null) return if (nulls == .first) .lt else .gt;
    if (right == null) return if (nulls == .first) .gt else .lt;
    const cmp = try v.order(left, right, descriptor);
    return if (direction == .asc or cmp == .eq) cmp else if (cmp == .lt) .gt else .lt;
}
fn findColumnIndex(columns: []const r.Column, target: r.Column) ?usize {
    for (columns, 0..) |column, i| if (column.eql(target)) return i;
    return null;
}
fn matchesComparison(cmp: std.math.Order, op: r.Comparison) bool {
    return switch (op) {
        .equal => cmp == .eq,
        .not_equal => cmp != .eq,
        .less => cmp == .lt,
        .less_equal => cmp != .gt,
        .greater => cmp == .gt,
        .greater_equal => cmp != .lt,
    };
}
fn integer(value: ?i64) Cell {
    return if (value) |number| .{ .value = .{ .atom = .{ .signed = number } } } else .null;
}

test {
    _ = @import("relational_execution_test.zig");
    _ = @import("relational_text_test.zig");
}

fn sumCell(value: ?i128, kind: @import("Types.zig").Type) Cell {
    const number = value orelse return .null;
    return .{ .value = .{ .atom = if (kind == .decimal) .{ .decimal = number } else .{ .signed = number } } };
}
