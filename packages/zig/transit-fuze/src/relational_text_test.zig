const std = @import("std");
const t = std.testing;
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const table = @import("TableSchema.zig");
const values = @import("RelationalValues.zig");

const Sources = struct {
    rows: [2][]const e.Row,
    pub fn validate(_: *Sources, _: r.Bound) !void {}
    pub fn next(self: *Sources, ordinal: u8, after: ?r.RowIdentity) !?e.Row {
        for (self.rows[ordinal]) |value| {
            if (after) |id| if (e.identityOrder(value.identity, id) != .gt) continue;
            return try value.clone(t.allocator);
        }
        return null;
    }
};
const Groups = struct {
    plan: r.Plan,
    rows: std.ArrayList(e.Group) = .empty,
    fn deinit(self: *Groups) void {
        for (self.rows.items) |*group| group.deinit();
        self.rows.deinit(t.allocator);
    }
    pub fn get(self: *Groups, key: e.Key) !?e.Group {
        for (self.rows.items) |group| if (try group.key.order(key, self.plan) == .eq) return .{ .key = try group.key.clone(t.allocator), .states = group.states };
        return null;
    }
    pub fn put(self: *Groups, value: e.Group) !void {
        var copied: e.Group = .{ .key = try value.key.clone(t.allocator), .states = value.states };
        errdefer copied.deinit();
        for (self.rows.items) |*group| if (try group.key.order(value.key, self.plan) == .eq) {
            group.deinit();
            group.* = copied;
            return;
        };
        try self.rows.append(t.allocator, copied);
    }
    pub fn next(self: *Groups, after: ?e.Key) !?e.Group {
        var selected: ?e.Group = null;
        for (self.rows.items) |group| {
            if (after) |key| if (try group.key.order(key, self.plan) != .gt) continue;
            if (selected == null or try group.key.order(selected.?.key, self.plan) == .lt) selected = group;
        }
        const group = selected orelse return null;
        return .{ .key = try group.key.clone(t.allocator), .states = group.states };
    }
};
const Engine = e.Execution(*Sources, *Groups);
fn row(id: u64, text: ?[]const u8, integer: i64) e.Row {
    var result: e.Row = .{ .identity = .{ .origin = 1, .operation = id, .ordinal = 0 } };
    result.values[0] = if (text) |bytes| .{ .text = bytes } else null;
    result.values[1] = .{ .integer = integer };
    return result;
}
const budgets: r.Budgets = .{ .resident_bytes = 2 * 1024 * 1024, .spill_bytes = 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 100, .work_steps = 1000, .source_pins = 2 };
fn source(columns: []const table.Column, ordinal: u8) r.Source {
    return .{ .alias = if (ordinal == 0) "a" else "b", .realm = 1, .resource = 7 + @as(u64, ordinal), .catalog = 9, .owner = 3, .schema = .{ .object = 11, .revision = 1, .next_column = 3, .columns = columns } };
}
fn cut(input: r.Source) !r.Cut {
    return .{ .domain = .native_resource, .resource = input.resource, .revision = 1, .commitment = @splat(17), .schema = try input.schema.fingerprint() };
}
test "relational text groups preserve first spelling null identity and output ownership" {
    const columns = [_]table.Column{ .{ .id = 1, .name = "k", .type = .utf8, .nullable = true, .collation = .ascii_ci }, .{ .id = 2, .name = "v", .type = .int64 } };
    const inputs = [_]r.Source{source(&columns, 0)};
    const cuts = [_]r.Cut{try cut(inputs[0])};
    const plan: r.Plan = .{ .sources = &inputs, .group_by = &.{.{ .source = 0, .id = 1 }}, .outputs = &.{ .{ .name = "k", .expression = .{ .column = .{ .source = 0, .id = 1 } } }, .{ .name = "n", .expression = .count_all }, .{ .name = "present", .expression = .{ .count = .{ .source = 0, .id = 1 } } }, .{ .name = "sum", .expression = .{ .sum = .{ .source = 0, .id = 2 } } } }, .lifetime = .interactive, .budgets = budgets };
    const rows = [_]e.Row{ row(1, "Alpha", 1), row(2, "alpha", 2), row(3, "ALPHA ", 3), row(4, "Beta", 4), row(5, null, 5) };
    var input: Sources = .{ .rows = .{ &rows, &.{} } };
    var groups: Groups = .{ .plan = plan };
    defer groups.deinit();
    var engine = try Engine.init(t.allocator, .{ .plan = plan, .cuts = &cuts }, &input, &groups);
    defer engine.deinit();
    var output: std.ArrayList(e.Output) = .empty;
    defer {
        for (output.items) |*value| value.deinit();
        output.deinit(t.allocator);
    }
    while (true) switch (try engine.step()) {
        .progress => {},
        .row => |value| try output.append(t.allocator, value),
        .complete => break,
    };
    try t.expectEqual(@as(usize, 4), output.items.len);
    try t.expect(output.items[0].cells[0] == .null);
    try t.expectEqualStrings("Alpha", output.items[1].cells[0].value.atom.bytes);
    try t.expectEqualStrings("ALPHA ", output.items[2].cells[0].value.atom.bytes);
    try t.expectEqualStrings("Beta", output.items[3].cells[0].value.atom.bytes);
    for (output.items, [_]u64{ 1, 2, 1, 1 }, [_]u64{ 0, 2, 1, 1 }, [_]i64{ 5, 3, 3, 4 }) |value, count, present, sum| {
        try t.expectEqual(count, value.cells[1].value.atom.unsigned);
        try t.expectEqual(present, value.cells[2].value.atom.unsigned);
        try t.expectEqual(sum, value.cells[3].value.atom.signed);
    }
    // Returned result payloads have independent lifetimes from the group map.
    for (groups.rows.items) |*group| if (group.key.buffer.bytes.len != 0) @memset(group.key.buffer.bytes, 'x');
    try t.expectEqualStrings("Alpha", output.items[1].cells[0].value.atom.bytes);
    try t.expectEqualStrings("Alpha", output.items[1].identity.group.values[0].?.text);
}

test "relational text join and predicates use source collation without null matches" {
    const columns = [_]table.Column{ .{ .id = 1, .name = "k", .type = .utf8, .nullable = true, .collation = .ascii_ci }, .{ .id = 2, .name = "v", .type = .int64 } };
    const inputs = [_]r.Source{ source(&columns, 0), source(&columns, 1) };
    const cuts = [_]r.Cut{ try cut(inputs[0]), try cut(inputs[1]) };
    const plan: r.Plan = .{ .sources = &inputs, .join = .{ .kind = .left, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } }, .source_filters = .{ .{ .instructions = &.{.{ .compare = .{ .column = .{ .source = 0, .id = 1 }, .op = .not_equal, .value = .{ .text = "skip" } } }} }, .{} }, .outputs = &.{ .{ .name = "left", .expression = .{ .column = .{ .source = 0, .id = 1 } } }, .{ .name = "right", .expression = .{ .column = .{ .source = 1, .id = 1 } } } }, .lifetime = .interactive, .budgets = budgets };
    const left = [_]e.Row{ row(1, "A", 1), row(2, "a", 2), row(3, "absent", 3), row(4, null, 4), row(5, "SKIP", 5) };
    const right = [_]e.Row{ row(1, "a", 1), row(2, "A", 2), row(3, null, 3) };
    var input: Sources = .{ .rows = .{ &left, &right } };
    var groups: Groups = .{ .plan = plan };
    defer groups.deinit();
    var engine = try Engine.init(t.allocator, .{ .plan = plan, .cuts = &cuts }, &input, &groups);
    defer engine.deinit();
    var count: usize = 0;
    while (true) switch (try engine.step()) {
        .progress => {},
        .row => |returned| {
            var value = returned;
            defer value.deinit();
            if (count < 4) {
                try t.expectEqual(std.math.Order.eq, try values.order(try values.fromCell(value.cells[0], columns[0]), try values.fromCell(value.cells[1], columns[0]), columns[0]));
            } else {
                try t.expectEqualStrings("absent", value.cells[0].value.atom.bytes);
                try t.expect(value.cells[1] == .null);
            }
            count += 1;
        },
        .complete => break,
    };
    try t.expectEqual(@as(usize, 5), count);
}

test "relational text checkpoint owns retained join input after executor and encoding release" {
    const checkpoint = @import("RelationalCheckpoint.zig");
    const columns = [_]table.Column{ .{ .id = 1, .name = "k", .type = .utf8, .nullable = true, .collation = .ascii_ci }, .{ .id = 2, .name = "v", .type = .int64 } };
    const inputs = [_]r.Source{ source(&columns, 0), source(&columns, 1) };
    const cuts = [_]r.Cut{ try cut(inputs[0]), try cut(inputs[1]) };
    const plan: r.Plan = .{ .sources = &inputs, .join = .{ .kind = .inner, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } }, .outputs = &.{.{ .name = "left", .expression = .{ .column = .{ .source = 0, .id = 1 } } }}, .lifetime = .captured, .budgets = budgets };
    const bound: r.Bound = .{ .plan = plan, .cuts = &cuts };
    const left = [_]e.Row{row(1, "First spelling", 1)};
    const right = [_]e.Row{row(1, "FIRST SPELLING", 1)};
    var input: Sources = .{ .rows = .{ &left, &right } };
    var groups: Groups = .{ .plan = plan };
    defer groups.deinit();
    var saved: checkpoint = undefined;
    {
        var engine = try Engine.init(t.allocator, bound, &input, &groups);
        defer engine.deinit();
        try t.expect(try engine.step() == .progress);
        const borrowed = try engine.checkpoint(null);
        const bytes = try borrowed.encodeAlloc(t.allocator, bound);
        defer t.allocator.free(bytes);
        saved = try checkpoint.decode(t.allocator, bound, bytes);
        @memset(bytes, 0);
    }
    defer saved.deinit();
    try t.expectEqualStrings("First spelling", saved.left.?.values[0].?.text);
    var engine = try Engine.restore(t.allocator, bound, &input, &groups, saved);
    defer engine.deinit();
    @memset(saved.left.?.buffer.bytes, 'x');
    var result = (try engine.step()).row;
    defer result.deinit();
    try t.expectEqualStrings("First spelling", result.cells[0].value.atom.bytes);
    while (true) switch (try engine.step()) {
        .progress => {},
        .row => return error.UnexpectedResult,
        .complete => break,
    };
}

test "relational text immutable index uses declared order and retains old group spellings" {
    const index = @import("RelationalIndex.zig");
    const Store = @import("relational_index_test.zig").Store;
    const columns = [_]table.Column{.{ .id = 1, .name = "k", .type = .utf8, .collation = .ebcdic_cp037 }};
    const inputs = [_]r.Source{source(&columns, 0)};
    const cuts = [_]r.Cut{try cut(inputs[0])};
    const plan: r.Plan = .{ .sources = &inputs, .group_by = &.{.{ .source = 0, .id = 1 }}, .outputs = &.{.{ .name = "n", .expression = .count_all }}, .lifetime = .captured, .budgets = budgets };
    const bound: r.Bound = .{ .plan = plan, .cuts = &cuts };
    var store: Store = .{};
    defer store.deinit();
    var tree = try index.init(t.allocator, bound, null);
    for ([_][]const u8{ "0", "A", "a" }, 0..) |text, i| {
        var group: e.Group = .{ .key = .{ .len = 1 } };
        group.key.values[0] = .{ .text = text };
        group.states[0].rows = i + 1;
        try tree.put(&store, group);
    }
    const old = tree;
    var key: e.Key = .{ .len = 1 };
    key.values[0] = .{ .text = "a" };
    var changed = (try tree.get(&store, key)).?;
    defer changed.deinit();
    changed.states[0].rows = 999;
    try tree.put(&store, changed);
    var original = (try old.get(&store, key)).?;
    defer original.deinit();
    try t.expectEqual(@as(u64, 3), original.states[0].rows);
    var after: ?e.Key = null;
    defer if (after) |*previous| previous.deinit();
    for ([_][]const u8{ "a", "A", "0" }) |expected| {
        var group = (try tree.next(&store, after)).?;
        defer group.deinit();
        try t.expectEqualStrings(expected, group.key.values[0].?.text);
        const next = try group.key.clone(t.allocator);
        if (after) |*previous| previous.deinit();
        after = next;
    }
    try t.expect(try tree.next(&store, after) == null);
}

fn ownedRecords(allocator: std.mem.Allocator) !void {
    const Output = @import("RelationalOutput.zig");
    const Exchange = @import("RelationalExchange.zig");
    const Delta = @import("RelationalDelta.zig");
    const columns = [_]table.Column{ .{ .id = 1, .name = "k", .type = .utf8, .collation = .ascii_ci }, .{ .id = 2, .name = "v", .type = .int64 } };
    const inputs = [_]r.Source{source(&columns, 0)};
    const cuts = [_]r.Cut{try cut(inputs[0])};
    var next_cuts = cuts;
    next_cuts[0].revision += 1;
    const plan: r.Plan = .{ .sources = &inputs, .group_by = &.{.{ .source = 0, .id = 1 }}, .outputs = &.{ .{ .name = "k", .expression = .{ .column = .{ .source = 0, .id = 1 } } }, .{ .name = "n", .expression = .count_all } }, .lifetime = .maintained, .budgets = budgets };
    const before: r.Bound = .{ .plan = plan, .cuts = &cuts };
    const after: r.Bound = .{ .plan = plan, .cuts = &next_cuts };
    var key: e.Key = .{ .len = 1 };
    key.values[0] = .{ .text = "AbC" };
    var output: e.Output = .{ .identity = .{ .group = key }, .len = 2 };
    output.cells[0] = .{ .value = .{ .atom = .{ .bytes = "AbC" } } };
    output.cells[1] = .{ .value = .{ .atom = .{ .unsigned = 9 } } };
    const old: Output = .{ .binding = try before.fingerprint(), .ordinal = 0, .row = output };
    const bytes = try old.encodeAlloc(allocator, before);
    defer allocator.free(bytes);
    var decoded = try Output.decode(allocator, before, bytes);
    defer decoded.deinit();
    @memset(bytes, 0);
    try t.expectEqualStrings("AbC", decoded.row.cells[0].value.atom.bytes);
    try t.expectEqualStrings("AbC", decoded.row.identity.group.values[0].?.text);
    try t.expect(Delta.sameValues(decoded.row, old.row));
    var changed = output;
    changed.cells[1] = .{ .value = .{ .atom = .{ .unsigned = 10 } } };
    // The identity remains equal even if the first contributor changes spelling.
    changed.identity.group.values[0] = .{ .text = "aBC" };
    changed.cells[0] = .{ .value = .{ .atom = .{ .bytes = "aBC" } } };
    const delta: Delta = .{ .ordinal = 0, .before = old, .after = .{ .binding = try after.fingerprint(), .ordinal = 0, .row = changed } };
    const delta_bytes = try delta.encodeAlloc(allocator, before, after);
    defer allocator.free(delta_bytes);
    var recovered = try Delta.decode(allocator, before, after, delta_bytes);
    defer recovered.deinit();
    @memset(delta_bytes, 0);
    try t.expectEqualStrings("AbC", recovered.before.?.row.cells[0].value.atom.bytes);
    try t.expectEqualStrings("aBC", recovered.after.?.row.cells[0].value.atom.bytes);
    try t.expectEqual(std.math.Order.eq, try Delta.identityOrder(recovered.before.?.row.identity, recovered.after.?.row.identity, plan));

    const first = row(1, "A", 1);
    const second = row(2, "a", 2);
    const partition = try Exchange.route(plan, 0, 17, first);
    try t.expectEqual(partition, try Exchange.route(plan, 0, 17, second));
    var segment: Exchange.Segment = .{ .exchange = 1, .source = 0, .partitions = 17, .partition = partition, .epoch = 1, .sequence = 0, .terminal = true, .len = 2 };
    segment.rows[0] = first;
    segment.rows[1] = second;
    const segment_bytes = try segment.encodeAlloc(allocator, before);
    defer allocator.free(segment_bytes);
    var copied = try Exchange.Segment.decode(allocator, before, segment_bytes);
    defer copied.deinit();
    @memset(segment_bytes, 0);
    try t.expectEqualStrings("A", copied.rows[0].values[0].?.text);
    try t.expectEqualStrings("a", copied.rows[1].values[0].?.text);
}

test "relational text output exchange and delta records own bytes and preserve group identity" {
    try ownedRecords(t.allocator);
}

test "relational text partial record allocation failures release every owned vector" {
    try t.checkAllAllocationFailures(t.allocator, ownedRecords, .{});
}

test "relational text routing matches independent Unicode and codepage fixtures" {
    const Case = struct { key: ?[]const u8, collation: []const u8, partitions: u64, partition: u64 };
    const fixture = try std.json.parseFromSlice(struct { text_routing: []const Case }, t.allocator, @embedFile("fixtures/relational-exchange.json"), .{ .ignore_unknown_fields = true });
    defer fixture.deinit();
    for (fixture.value.text_routing) |sample| {
        const declared = std.meta.stringToEnum(table.Collation, sample.collation) orelse return error.UnknownCollation;
        const columns = [_]table.Column{ .{ .id = 1, .name = "k", .type = .utf8, .nullable = true, .collation = declared }, .{ .id = 2, .name = "v", .type = .int64 } };
        const inputs = [_]r.Source{ source(&columns, 0), source(&columns, 1) };
        const plan: r.Plan = .{ .sources = &inputs, .join = .{ .kind = .inner, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } }, .outputs = &.{.{ .name = "k", .expression = .{ .column = .{ .source = 0, .id = 1 } } }}, .lifetime = .captured, .budgets = budgets };
        try t.expectEqual(sample.partition, try @import("RelationalExchange.zig").route(plan, 0, sample.partitions, row(1, sample.key, 0)));
    }
}
