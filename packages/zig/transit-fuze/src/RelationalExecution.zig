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
        if (a.len != plan.group_by.len or b.len != plan.group_by.len) return error.InvalidRelationalGroup;
        for (a.values[0..a.len], b.values[0..b.len], plan.group_by) |left, right, column| {
            const result = try v.order(left, right, try plan.resolveColumn(column));
            if (result != .eq) return result;
        }
        return .eq;
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
            if (!self.kernel.predicate.matches(left, right)) return .progress;
            const pair: Pair = .{ .left = left.identity, .right = if (right) |row| row.identity else null };
            if (!self.grouped) {
                var result: Output = .{ .identity = .{ .pair = pair }, .len = @intCast(plan.outputs.len) };
                for (self.kernel.outputs[0..plan.outputs.len], 0..) |column, i| result.cells[i] = v.cell(Kernel.cell(column, left, right));
                return self.emit(result);
            }
            var key: Key = .{ .len = @intCast(plan.group_by.len) };
            for (self.kernel.groups[0..plan.group_by.len], 0..) |column, i| key.values[i] = Kernel.cell(column, left, right);
            const previous = try self.groups.get(key);
            var group = previous orelse Group{ .key = try key.clone(self.allocator) };
            defer group.deinit();
            // Preserve first failure by contributor then output position. The
            // store sees nothing until every candidate aggregate succeeds.
            for (plan.outputs, 0..) |field, i| {
                const observed: error{Overflow}!void = switch (field.expression) {
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
            try self.groups.put(group);
            if (previous == null) self.group_count = try std.math.add(u64, self.group_count, 1);
            return .progress;
        }
        fn output(self: *Self) !Event {
            var group = (try self.groups.next(self.after_group)) orelse {
                if (self.result_rows != self.group_count) return error.IncompleteRelationalGroups;
                try self.sources.validate(self.bound);
                self.phase = .complete;
                return .complete;
            };
            defer group.deinit();
            if (self.after_group) |after| if (try group.key.order(after, self.bound.plan) != .gt) return error.InvalidRelationalGroupOrder;
            if (group.key.len != self.bound.plan.group_by.len) return error.InvalidRelationalGroup;
            var result: Output = .{ .identity = .{ .group = group.key }, .len = @intCast(self.bound.plan.outputs.len) };
            for (self.bound.plan.outputs, 0..) |field, i| result.cells[i] = switch (field.expression) {
                .column => |column| value: {
                    for (self.bound.plan.group_by, 0..) |key, j| if (key.eql(column)) break :value v.cell(group.key.values[j]);
                    unreachable;
                },
                .count_all => .{ .value = .{ .atom = .{ .unsigned = group.states[i].rows } } },
                .count => .{ .value = .{ .atom = .{ .unsigned = group.states[i].values } } },
                .sum => integer(group.states[i].sum),
            };
            const next = try group.key.clone(self.allocator);
            if (self.after_group) |*after| after.deinit();
            self.after_group = next;
            return self.emit(result);
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
fn integer(value: ?i64) Cell {
    return if (value) |number| .{ .value = .{ .atom = .{ .signed = number } } } else .null;
}

test {
    _ = @import("relational_execution_test.zig");
    _ = @import("relational_text_test.zig");
}
