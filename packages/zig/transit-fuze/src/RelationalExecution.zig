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
    values: [table.max_columns]v.Value = @splat(null),
    buffer: v.Buffer = .{},
    pub fn fromCells(allocator: std.mem.Allocator, identity: r.RowIdentity, columns: []const table.Column, cells: []const Cell) !Row {
        if (columns.len != cells.len or columns.len > table.max_columns) return error.InvalidRelationalSourceRow;
        var result: Row = .{ .identity = identity };
        for (columns, cells, 0..) |column, value, i| {
            if (column.type != .int64 and column.type != .utf8) continue;
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
pub const Pair = struct { left: r.RowIdentity, right: ?r.RowIdentity };
pub const Key = struct {
    pair: ?Pair = null,
    values: [r.max_groups]v.Value = @splat(null),
    len: u8 = 0,
    buffer: v.Buffer = .{},
    pub fn clone(self: Key, allocator: std.mem.Allocator) !Key {
        var result = self;
        result.buffer = try v.Buffer.copy(allocator, result.values[0..result.len]);
        return result;
    }
    pub fn borrow(self: Key) Key {
        var result = self;
        result.buffer = .{};
        return result;
    }
    pub fn deinit(self: *Key) void {
        self.buffer.deinit();
        self.* = undefined;
    }
    pub fn order(a: Key, b: Key, plan: r.Plan) !std.math.Order {
        var columns_buf: [r.max_groups]r.Column = undefined;
        const columns = plan.keyColumns(&columns_buf);
        if (a.len != columns.len or b.len != columns.len) return error.InvalidRelationalGroup;
        if (plan.isGrouped() != (a.pair == null) or plan.isGrouped() != (b.pair == null)) return error.InvalidRelationalGroup;
        for (plan.order_by) |item| {
            if (item.expression != .column) continue;
            const index = findColumnIndex(columns, item.expression.column) orelse return error.InvalidRelationalGroup;
            const result = try orderValue(a.values[index], b.values[index], try plan.resolveColumn(item.expression.column), item.direction, item.nulls);
            if (result != .eq) return result;
        }
        if (plan.isGrouped()) {
            for (columns, 0..) |column, index| {
                if (plan.ordersByColumn(column)) continue;
                const result = try v.order(a.values[index], b.values[index], try plan.resolveColumn(column));
                if (result != .eq) return result;
            }
            return .eq;
        }
        return pairOrder(a.pair.?, b.pair.?);
    }
};
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
    cells: [r.max_outputs]Cell = @splat(.null),
    len: u8,
    buffer: v.Buffer = .{},
    pub fn clone(self: Output, allocator: std.mem.Allocator) !Output {
        var result = self;
        result.buffer = .{};
        if (self.identity == .group) result.identity.group = try self.identity.group.clone(allocator);
        errdefer if (result.identity == .group) result.identity.group.deinit();
        result.buffer = try v.Buffer.copyCells(allocator, result.cells[0..result.len]);
        return result;
    }
    pub fn deinit(self: *Output) void {
        self.buffer.deinit();
        self.identity.deinit();
        self.* = undefined;
    }
    pub fn canonicalBytes(self: Output) !u64 {
        var total: u64 = 0;
        for (self.cells[0..self.len]) |cell| total = try std.math.add(u64, total, 5 + @as(u64, switch (cell) {
            .null => 0,
            .value => |value| switch (value) {
                .atom => |atom| switch (atom) {
                    .signed, .unsigned => 8,
                    .bytes => |bytes| bytes.len,
                    else => return error.InvalidRelationalOutput,
                },
                else => return error.InvalidRelationalOutput,
            },
            else => return error.InvalidRelationalOutput,
        }));
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
                if (column.type == .int64 or column.type == .utf8) try v.validate(row.values[i], column) else if (row.values[i] != null) return error.InvalidRelationalSourceRow;
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
            self.phase = .output;
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
                        .sum => group.states[i].observe(.sum, if (Kernel.cell(self.kernel.outputs[i], left, right)) |value| value.integer else null),
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
                if (plan.having.instructions.len == 0 and plan.limit == null and self.result_rows != self.group_count) return error.IncompleteRelationalGroups;
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
            if (self.grouped and !try self.matchesHaving(group)) return .progress;
            var result: Output = .{
                .identity = if (self.grouped) .{ .group = group.key } else .{ .pair = group.key.pair.? },
                .len = @intCast(plan.outputs.len),
            };
            for (plan.outputs, 0..) |field, i| result.cells[i] = switch (field.expression) {
                .column => |column| value: {
                    for (keys, 0..) |key, j| if (key.eql(column)) break :value v.cell(group.key.values[j]);
                    unreachable;
                },
                .count_all => .{ .value = .{ .atom = .{ .unsigned = group.states[i].rows } } },
                .count => .{ .value = .{ .atom = .{ .unsigned = group.states[i].values } } },
                .sum => integer(group.states[i].sum),
            };
            const emitted = try self.emit(result);
            if (plan.limit) |limit| if (self.result_rows >= limit) {
                self.phase = .complete;
            };
            return emitted;
        }
        fn nextGroup(self: *Self) !?Group {
            if (!self.bound.plan.hasAggregateOrder()) {
                var group = (try self.groups.next(self.after_group)) orelse return null;
                errdefer group.deinit();
                if (self.after_group) |after| if (try group.key.order(after, self.bound.plan) != .gt) return error.InvalidRelationalGroupOrder;
                return group;
            }
            var after_group: ?Group = null;
            defer if (after_group) |*g| g.deinit();
            if (self.after_group) |after_key| {
                after_group = (try self.groups.get(after_key)) orelse return error.InvalidRelationalGroupOrder;
            }
            var cursor: ?Key = null;
            defer if (cursor) |*k| k.deinit();
            var selected: ?Group = null;
            errdefer if (selected) |*g| g.deinit();
            var visited: u64 = 0;
            while (try self.groups.next(cursor)) |candidate| {
                var current = candidate;
                errdefer current.deinit();
                if (cursor) |prev_cursor| if (try current.key.order(prev_cursor, self.bound.plan) != .gt) return error.InvalidRelationalGroupOrder;
                visited = try std.math.add(u64, visited, 1);
                const next_cursor = try current.key.clone(self.allocator);
                if (cursor) |*prev_cursor| prev_cursor.deinit();
                cursor = next_cursor;
                if (!try self.matchesHaving(current)) {
                    current.deinit();
                    continue;
                }
                if (after_group) |prev| if (try self.compareGroups(current, prev) != .gt) {
                    current.deinit();
                    continue;
                };
                if (selected == null or try self.compareGroups(current, selected.?) == .lt) {
                    if (selected) |*prev_selected| prev_selected.deinit();
                    selected = current;
                } else {
                    current.deinit();
                }
            }
            if (visited != self.group_count) return error.IncompleteRelationalGroups;
            return selected;
        }
        fn matchesHaving(self: *Self, group: Group) !bool {
            const instructions = self.bound.plan.having.instructions;
            if (instructions.len == 0) return true;
            var stack: [r.max_instructions]Truth = undefined;
            var depth: usize = 0;
            for (instructions) |instruction| switch (instruction) {
                .compare => |item| {
                    const truth: Truth = switch (item.expression) {
                        .column => |column| blk: {
                            const index = findColumnIndex(self.bound.plan.group_by, column) orelse return error.InvalidRelationalGroup;
                            const val = group.key.values[index] orelse break :blk .unknown;
                            const cmp = try v.order(val, item.value, try self.bound.plan.resolveColumn(column));
                            break :blk Truth.fromBool(matchesComparison(cmp, item.op));
                        },
                        .count_all, .count => blk: {
                            const slot = self.bound.plan.findStateSlot(item.expression) orelse return error.InvalidRelationalGroup;
                            const count_val: u64 = if (item.expression == .count_all) group.states[slot].rows else group.states[slot].values;
                            const rhs = item.value.integer;
                            const cmp: std.math.Order = if (rhs < 0) .gt else std.math.order(count_val, @as(u64, @intCast(rhs)));
                            break :blk Truth.fromBool(matchesComparison(cmp, item.op));
                        },
                        .sum => blk: {
                            const slot = self.bound.plan.findStateSlot(item.expression) orelse return error.InvalidRelationalGroup;
                            const sum_val = group.states[slot].sum orelse break :blk .unknown;
                            const cmp = std.math.order(sum_val, item.value.integer);
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
        fn compareGroups(self: *Self, a: Group, b: Group) !std.math.Order {
            const plan = self.bound.plan;
            for (plan.order_by) |item| {
                const cmp: std.math.Order = switch (item.expression) {
                    .column => |column| blk: {
                        const index = findColumnIndex(plan.group_by, column) orelse return error.InvalidRelationalGroup;
                        break :blk try orderValue(a.key.values[index], b.key.values[index], try plan.resolveColumn(column), item.direction, item.nulls);
                    },
                    .count_all, .count => blk: {
                        const slot = plan.findStateSlot(item.expression) orelse return error.InvalidRelationalGroup;
                        const va: u64 = if (item.expression == .count_all) a.states[slot].rows else a.states[slot].values;
                        const vb: u64 = if (item.expression == .count_all) b.states[slot].rows else b.states[slot].values;
                        const raw = std.math.order(va, vb);
                        break :blk if (item.direction == .asc or raw == .eq) raw else if (raw == .lt) .gt else .lt;
                    },
                    .sum => blk: {
                        const slot = plan.findStateSlot(item.expression) orelse return error.InvalidRelationalGroup;
                        const va: v.Value = if (a.states[slot].sum) |s| .{ .integer = s } else null;
                        const vb: v.Value = if (b.states[slot].sum) |s| .{ .integer = s } else null;
                        break :blk try orderValue(va, vb, .{ .id = 1, .name = "sum", .type = .int64 }, item.direction, item.nulls);
                    },
                };
                if (cmp != .eq) return cmp;
            }
            return a.key.order(b.key, plan);
        }
        fn emit(self: *Self, result: Output) !Event {
            if (self.result_rows == self.bound.plan.budgets.output_rows) return error.RelationalResultBudget;
            var bytes = self.result_bytes;
            for (result.cells[0..result.len]) |value| bytes = std.math.add(u64, bytes, 5 + @as(u64, if (value == .null) 0 else if (value.value.atom == .bytes) value.value.atom.bytes.len else 8)) catch return error.RelationalResultBudget;
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
