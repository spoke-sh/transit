const std = @import("std");
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const table = @import("TableSchema.zig");
const t = std.testing;
const columns = [_]table.Column{
    .{ .id = 1, .name = "key", .type = .int64 },
    .{ .id = 2, .name = "value", .type = .int64 },
};
const sources = [_]r.Source{
    .{ .alias = "l", .realm = 1, .resource = 101, .catalog = 9, .owner = 7, .schema = .{ .object = 11, .revision = 1, .next_column = 3, .columns = &columns } },
    .{ .alias = "r", .realm = 1, .resource = 202, .catalog = 9, .owner = 7, .schema = .{ .object = 22, .revision = 1, .next_column = 3, .columns = &columns } },
};
const Fixture = struct { cases: []const Case };
const Predicate = struct { column: []const u8, op: []const u8, value: i64 = 0 };
const Case = struct {
    name: []const u8,
    join: []const u8,
    left: []const [3]?i64,
    right: []const [3]?i64,
    outputs: []const []const []const u8,
    group_by: []const []const u8 = &.{},
    left_filter: ?Predicate = null,
    right_filter: ?Predicate = null,
    filter: ?Predicate = null,
    expected: struct {
        rows: []const struct { identity: []const ?i64, values: []const ?i64 },
        @"error": ?struct { code: []const u8, identity: [2]?i64, output: u8, group: []const ?i64 },
    },
};
const Input = struct {
    rows: [2][]const [3]?i64,
    denied: bool = false,
    reads: u64 = 0,
    fail_at: ?u64 = null,
    validations: u64 = 0,
    pub fn validate(self: *Input, bound: r.Bound) !void {
        try bound.validate();
        self.validations += 1;
        if (self.denied) return error.AccessDenied;
    }
    pub fn next(self: *Input, source: u8, after: ?r.RowIdentity) !?e.Row {
        if (self.fail_at == self.reads) return error.SourceUnavailable;
        self.reads += 1;
        var selected: ?[3]?i64 = null;
        for (self.rows[source]) |row| {
            if (after) |id| if (row[0].? <= id.operation) continue;
            if (selected == null or row[0].? < selected.?[0].?) selected = row;
        }
        if (selected) |row| {
            var result: e.Row = .{ .identity = .{ .origin = 1, .operation = @intCast(row[0].?), .ordinal = 0 } };
            result.values[0] = row[1];
            result.values[1] = row[2];
            return result;
        }
        return null;
    }
};
// Deliberately materialized reference storage for small semantic fixtures only.
const Groups = struct {
    items: std.ArrayList(e.Group) = .empty,
    writes: u64 = 0,
    fail_at: ?u64 = null,
    pub fn get(self: *Groups, key: e.Key) !?e.Group {
        for (self.items.items) |group| if (group.key.order(key) == .eq) return group;
        return null;
    }
    pub fn put(self: *Groups, group: e.Group) !void {
        if (self.fail_at == self.writes) return error.StoreUnavailable;
        self.writes += 1;
        for (self.items.items) |*existing| if (existing.key.order(group.key) == .eq) {
            existing.* = group;
            return;
        };
        try self.items.append(t.allocator, group);
    }
    pub fn next(self: *Groups, after: ?e.Key) !?e.Group {
        var result: ?e.Group = null;
        for (self.items.items) |group| {
            if (after) |key| if (group.key.order(key) != .gt) continue;
            if (result == null or group.key.order(result.?.key) == .lt) result = group;
        }
        return result;
    }
    fn deinit(self: *Groups) void {
        self.items.deinit(t.allocator);
    }
};
const Run = e.Execution(*Input, *Groups);
fn column(name: []const u8) r.Column {
    return .{ .source = if (name[0] == 'l') 0 else 1, .id = if (std.mem.endsWith(u8, name, ".key")) 1 else 2 };
}
fn predicate(value: ?Predicate, instruction: *[1]r.Instruction) r.Predicate {
    const pred = value orelse return .{};
    instruction[0] = if (std.mem.eql(u8, pred.op, "is_null")) .{ .is_null = column(pred.column) } else if (std.mem.eql(u8, pred.op, "is_not_null")) .{ .is_not_null = column(pred.column) } else .{ .compare = .{ .column = column(pred.column), .op = if (std.mem.eql(u8, pred.op, "gt")) .greater else if (std.mem.eql(u8, pred.op, "lt")) .less else .equal, .value = pred.value } };
    return .{ .instructions = instruction };
}
fn cuts() ![2]r.Cut {
    return .{
        .{ .resource = 101, .revision = 7, .commitment = @splat(17), .schema = try sources[0].schema.fingerprint() },
        .{ .resource = 202, .revision = 12, .commitment = @splat(34), .schema = try sources[1].schema.fingerprint() },
    };
}
fn base() r.Plan {
    return .{ .sources = sources[0..1], .outputs = &.{.{ .name = "n", .expression = .count_all }}, .lifetime = .interactive, .budgets = .{ .resident_bytes = Run.residentBytes, .spill_bytes = 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 100000, .source_pins = 2 } };
}
test "bounded relational executor agrees with independent bags groups nulls and first errors" {
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/relational.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    inline for (.{ false, true }) |durable| {
        const GroupStore = if (durable) ImmutableGroups else Groups;
        const Engine = e.Execution(*Input, *GroupStore);
        for (parsed.value.cases) |case| {
            var plan = base();
            if (durable) {
                plan.lifetime = .captured;
                plan.budgets.resident_bytes = 4 * 1024 * 1024;
            }
            if (!std.mem.eql(u8, case.join, "none")) {
                plan.sources = &sources;
                plan.join = .{ .kind = if (std.mem.eql(u8, case.join, "left")) .left else .inner, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } };
            }
            var outputs: [r.max_outputs]r.Output = undefined;
            for (case.outputs, 0..) |output, i| outputs[i] = .{ .name = output[0], .expression = if (std.mem.eql(u8, output[1], "count_all")) .count_all else if (std.mem.eql(u8, output[1], "count")) .{ .count = column(output[2]) } else if (std.mem.eql(u8, output[1], "sum")) .{ .sum = column(output[2]) } else .{ .column = column(output[2]) } };
            plan.outputs = outputs[0..case.outputs.len];
            var keys: [r.max_groups]r.Column = undefined;
            for (case.group_by, 0..) |key, i| keys[i] = column(key);
            plan.group_by = keys[0..case.group_by.len];
            var instructions: [3][1]r.Instruction = undefined;
            plan.source_filters[0] = predicate(case.left_filter, &instructions[0]);
            plan.source_filters[1] = predicate(case.right_filter, &instructions[1]);
            plan.filter = predicate(case.filter, &instructions[2]);
            const basis = try cuts();
            var input: Input = .{ .rows = .{ case.left, case.right } };
            const bound: r.Bound = .{ .plan = plan, .cuts = basis[0..plan.sources.len] };
            var groups: GroupStore = if (durable) .{ .tree = try Index.init(bound, null) } else .{};
            defer groups.deinit();
            var run = try Engine.init(bound, &input, &groups);
            var rows: usize = 0;
            while (true) {
                if (durable) try restart(Engine, &run, &input, &groups);
                const event = run.step() catch |err| {
                    const expected = case.expected.@"error" orelse return err;
                    try t.expectEqualStrings(expected.code, @errorName(err));
                    const failure = run.failure.?;
                    try t.expectEqual(@as(u64, @intCast(expected.identity[0].?)), failure.pair.left.operation);
                    try t.expectEqual(expected.identity[1], if (failure.pair.right) |right| @as(?i64, @intCast(right.operation)) else null);
                    try t.expectEqual(expected.output, failure.output);
                    try t.expectEqualSlices(?i64, expected.group, failure.group.values[0..failure.group.len]);
                    try t.expectEqual(@as(usize, 0), rows);
                    if (durable) try restart(Engine, &run, &input, &groups);
                    try t.expectError(error.FailedRelationalQuery, run.step());
                    break;
                };
                switch (event) {
                    .progress => {},
                    .complete => {
                        try t.expect(case.expected.@"error" == null);
                        try t.expectEqual(case.expected.rows.len, rows);
                        if (durable) {
                            try restart(Engine, &run, &input, &groups);
                            try t.expectEqual(.complete, try run.step());
                        }
                        break;
                    },
                    .row => |row| {
                        try t.expect(rows < case.expected.rows.len);
                        const expected = case.expected.rows[rows];
                        switch (row.identity) {
                            .pair => |pair| {
                                try t.expectEqual(@as(u64, @intCast(expected.identity[0].?)), pair.left.operation);
                                try t.expectEqual(expected.identity[1], if (pair.right) |right| @as(?i64, @intCast(right.operation)) else null);
                            },
                            .group => |key| try t.expectEqualSlices(?i64, expected.identity, key.values[0..key.len]),
                        }
                        try t.expectEqual(expected.values.len, row.len);
                        for (expected.values, row.cells[0..row.len]) |value, actual| {
                            const integer: ?i64 = if (actual == .null) null else switch (actual.value.atom) {
                                .signed => |v| @intCast(v),
                                .unsigned => |v| @intCast(v),
                                else => return error.UnexpectedCell,
                            };
                            try t.expectEqual(value, integer);
                        }
                        rows += 1;
                    },
                }
            }
        }
    }
}

test "source and store failure terminally reject without complete publication" {
    const basis = try cuts();
    for (0..5) |fail| {
        var input: Input = .{ .rows = .{ &.{ .{ 1, 7, 3 }, .{ 2, 7, 4 } }, &.{} }, .fail_at = if (fail < 3) fail else null };
        var groups: Groups = .{ .fail_at = if (fail >= 3) fail - 3 else null };
        defer groups.deinit();
        var run = try Run.init(.{ .plan = base(), .cuts = basis[0..1] }, &input, &groups);
        var failed = false;
        for (0..20) |_| {
            const event = run.step() catch |err| {
                try t.expect(err == error.SourceUnavailable or err == error.StoreUnavailable);
                failed = true;
                break;
            };
            try t.expect(event != .complete and event != .row);
        }
        try t.expect(failed);
        try t.expectError(error.FailedRelationalQuery, run.step());
    }
}

test "empty and completed relations still validate all source rights and budgets" {
    const basis = try cuts();
    var input: Input = .{ .rows = .{ &.{}, &.{} } };
    var groups: Groups = .{};
    defer groups.deinit();
    var plan = base();
    plan.budgets.resident_bytes = Run.residentBytes - 1;
    try t.expectError(error.RelationalResidentBudget, Run.init(.{ .plan = plan, .cuts = basis[0..1] }, &input, &groups));
    plan = base();
    plan.budgets.work_steps = 1;
    var run = try Run.init(.{ .plan = plan, .cuts = basis[0..1] }, &input, &groups);
    _ = try run.step();
    try t.expectError(error.RelationalWorkBudget, run.step());
    plan = base();
    plan.budgets.output_rows = 0;
    run = try Run.init(.{ .plan = plan, .cuts = basis[0..1] }, &input, &groups);
    _ = try run.step();
    try t.expectError(error.RelationalResultBudget, run.step());
    run = try Run.init(.{ .plan = base(), .cuts = basis[0..1] }, &input, &groups);
    input.denied = true;
    try t.expectError(error.AccessDenied, run.step());
    input.denied = false;
    run = try Run.init(.{ .plan = base(), .cuts = basis[0..1] }, &input, &groups);
    while (try run.step() != .complete) {}
    input.denied = true;
    try t.expectError(error.AccessDenied, run.step());
}

const Index = @import("RelationalIndex.zig");
const Checkpoint = @import("RelationalCheckpoint.zig");
const ImmutableGroups = struct {
    tree: Index,
    store: @import("relational_index_test.zig").Store = .{},
    pub fn get(self: *ImmutableGroups, key: e.Key) !?e.Group {
        return self.tree.get(&self.store, key);
    }
    pub fn put(self: *ImmutableGroups, group: e.Group) !void {
        return self.tree.put(&self.store, group);
    }
    pub fn next(self: *ImmutableGroups, after: ?e.Key) !?e.Group {
        return self.tree.next(&self.store, after);
    }
    fn deinit(self: *ImmutableGroups) void {
        self.store.deinit();
    }
};
fn restart(comptime Engine: type, run: *Engine, input: *Input, groups: *ImmutableGroups) !void {
    var bytes: [Checkpoint.max_bytes]u8 = undefined;
    const saved = try run.checkpoint(groups.tree.root);
    const decoded = try Checkpoint.decode(run.bound, try saved.encode(run.bound, &bytes));
    try t.expect(std.meta.eql(saved, decoded));
    groups.tree = try Index.init(run.bound, decoded.root);
    run.* = try Engine.restore(run.bound, input, groups, decoded);
}

test "checkpoint admission rejects changed cuts corrupt counters truncation and revoked sources" {
    var basis = try cuts();
    var plan = base();
    plan.lifetime = .captured;
    plan.budgets.resident_bytes = 4 * 1024 * 1024;
    const bound: r.Bound = .{ .plan = plan, .cuts = basis[0..1] };
    var input: Input = .{ .rows = .{ &.{}, &.{} } };
    var groups: ImmutableGroups = .{ .tree = try Index.init(bound, null) };
    defer groups.deinit();
    const Engine = e.Execution(*Input, *ImmutableGroups);
    var run = try Engine.init(bound, &input, &groups);
    _ = try run.step();
    const saved = try run.checkpoint(groups.tree.root);
    var bytes: [Checkpoint.max_bytes]u8 = undefined;
    const encoded = try saved.encode(bound, &bytes);
    for (0..encoded.len) |size| {
        if (Checkpoint.decode(bound, encoded[0..size])) |_| return error.AcceptedIncompleteCheckpoint else |_| {}
    }
    bytes[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Checkpoint.decode(bound, encoded));
    bytes[4] ^= 1;
    basis[0].revision += 1;
    try t.expectError(error.RelationalSourceChanged, Checkpoint.decode(bound, encoded));
    basis[0].revision -= 1;
    var invalid = saved;
    invalid.group_count += 1;
    try t.expectError(error.InvalidRelationalCheckpoint, invalid.validate(bound));
    invalid = saved;
    invalid.result_bytes = 0;
    try t.expectError(error.InvalidRelationalCheckpoint, invalid.validate(bound));
    input.denied = true;
    try t.expectError(error.AccessDenied, Engine.restore(bound, &input, &groups, saved));
}
