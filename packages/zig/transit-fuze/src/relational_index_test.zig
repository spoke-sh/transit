const std = @import("std");
const t = std.testing;
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const Index = @import("RelationalIndex.zig");
const columns = [_]@import("TableSchema.zig").Column{.{ .id = 1, .name = "k", .type = .int64 }};
const sources = [_]r.Source{.{ .alias = "t", .realm = 1, .resource = 101, .catalog = 9, .owner = 7, .schema = .{ .object = 11, .revision = 1, .next_column = 2, .columns = &columns } }};
const plan: r.Plan = .{ .sources = &sources, .group_by = &.{.{ .source = 0, .id = 1 }}, .outputs = &.{.{ .name = "n", .expression = .count_all }}, .lifetime = .captured, .budgets = .{ .resident_bytes = Index.resident_bytes, .spill_bytes = 1 << 30, .result_bytes = 1 << 20, .output_rows = 10000, .work_steps = 1000000, .source_pins = 1 } };
fn cut() ![1]r.Cut {
    return .{.{ .resource = 101, .revision = 7, .commitment = @splat(17), .schema = try sources[0].schema.fingerprint() }};
}
// Test-only materialized medium. Runtime stores use bounded pages and staging.
pub const Store = struct {
    records: std.ArrayList([]u8) = .empty,
    attempts: usize = 0,
    fail: ?usize = null,
    missing: ?u64 = null,
    pub fn save(self: *Store, bytes: []const u8) !u64 {
        if (self.fail == self.attempts) return error.StoreUnavailable;
        self.attempts += 1;
        const owned = try t.allocator.dupe(u8, bytes);
        errdefer t.allocator.free(owned);
        try self.records.append(t.allocator, owned);
        return self.records.items.len;
    }
    pub fn read(self: *Store, id: u64, output: []u8) ![]const u8 {
        if (self.missing == id or id == 0 or id > self.records.items.len) return error.MissingRecord;
        const bytes = self.records.items[@intCast(id - 1)];
        @memcpy(output[0..bytes.len], bytes);
        return output[0..bytes.len];
    }
    pub fn deinit(self: *Store) void {
        for (self.records.items) |record| t.allocator.free(record);
        self.records.deinit(t.allocator);
    }
};
fn key(value: ?i64) e.Key {
    var result: e.Key = .{ .len = 1 };
    result.values[0] = value;
    return result;
}
fn group(value: ?i64, count: u64) e.Group {
    var result: e.Group = .{ .key = key(value) };
    result.states[0].rows = count;
    return result;
}
test "immutable AVL preserves ordered groups and old roots across rotations and replacements" {
    const cuts = try cut();
    const bound: r.Bound = .{ .plan = plan, .cuts = &cuts };
    for (0..3) |order| {
        var store: Store = .{};
        defer store.deinit();
        var tree = try Index.init(bound, null);
        var old: ?Index = null;
        for (0..901) |i| {
            const value: i64 = @intCast(switch (order) {
                0 => i,
                1 => 900 - i,
                else => (i * 487) % 901,
            });
            const before = store.attempts;
            try tree.put(&store, group(value, @intCast(value + 1)));
            try t.expect(store.attempts - before <= Index.max_candidate_records);
            try t.expectEqual(i + 1, tree.root.?.entries);
            if (i == 450) old = tree;
        }
        try tree.put(&store, group(null, 9));
        try tree.put(&store, group(17, 999));
        try t.expectEqual(@as(u64, 902), tree.root.?.entries);
        var after: ?e.Key = null;
        for (0..902) |i| {
            const actual = (try tree.next(&store, after)).?;
            const value: ?i64 = if (i == 0) null else @intCast(i - 1);
            try t.expectEqual(value, actual.key.values[0]);
            try t.expectEqual(@as(u64, if (i == 0) 9 else if (i == 18) 999 else i), actual.states[0].rows);
            try t.expect(std.meta.eql(actual, (try tree.get(&store, key(value))).?));
            after = actual.key;
        }
        try t.expect(try tree.next(&store, after) == null);
        try t.expect(try tree.get(&store, key(1000)) == null);
        try t.expectEqual(@as(u64, 451), old.?.root.?.entries);
        try t.expect(try old.?.get(&store, key(null)) == null);
        if (try old.?.get(&store, key(17))) |before| try t.expectEqual(@as(u64, 18), before.states[0].rows);
        var count: usize = 0;
        after = null;
        while (try old.?.next(&store, after)) |before| {
            count += 1;
            after = before.key;
        }
        try t.expectEqual(@as(usize, 451), count);
    }
}
test "every failed candidate write leaves the accepted root readable and retry possible" {
    const cuts = try cut();
    const bound: r.Bound = .{ .plan = plan, .cuts = &cuts };
    var store: Store = .{};
    defer store.deinit();
    var tree = try Index.init(bound, null);
    for (0..200) |i| try tree.put(&store, group(@intCast(i * 2), i));
    const old = tree;
    var fail: usize = 0;
    while (true) : (fail += 1) {
        tree = old;
        store.fail = store.attempts + fail;
        tree.put(&store, group(175, 55)) catch |err| {
            try t.expectEqual(error.StoreUnavailable, err);
            try t.expect(std.meta.eql(old.root, tree.root));
            try t.expect(try tree.get(&store, key(175)) == null);
            try t.expectEqual(@as(u64, 88), (try tree.get(&store, key(176))).?.states[0].rows);
            continue;
        };
        break;
    }
    try t.expect(fail > 1 and fail <= Index.max_candidate_records);
    try t.expectEqual(@as(u64, 201), tree.root.?.entries);
    try t.expectEqual(@as(u64, 55), (try tree.get(&store, key(175))).?.states[0].rows);
    try t.expect(try old.get(&store, key(175)) == null);
}
test "immutable groups reject missing corrupt foreign bound and malformed roots" {
    var cuts = try cut();
    var store: Store = .{};
    defer store.deinit();
    var tree = try Index.init(.{ .plan = plan, .cuts = &cuts }, null);
    try tree.put(&store, group(7, 1));
    store.missing = tree.root.?.id;
    try t.expectError(error.MissingRecord, tree.get(&store, key(7)));
    store.missing = null;
    store.records.items[0][0] ^= 1;
    try t.expectError(error.InvalidRelationalIndex, tree.get(&store, key(7)));
    store.records.items[0][0] ^= 1;
    cuts[0].revision += 1;
    const foreign = try Index.init(.{ .plan = plan, .cuts = &cuts }, tree.root);
    try t.expectError(error.RelationalSourceChanged, foreign.get(&store, key(7)));
    var invalid = tree;
    invalid.root.?.entries += 1;
    try t.expectError(error.InvalidRelationalIndex, invalid.get(&store, key(7)));
    invalid = tree;
    invalid.root.?.bytes -= 1;
    try t.expectError(error.IncompleteRelationalIndex, invalid.get(&store, key(7)));
    var bad = group(1, 0);
    bad.states[0].values = 1;
    try t.expectError(error.InvalidRelationalGroup, tree.put(&store, bad));
    try t.expectError(error.InvalidRelationalGroup, tree.get(&store, .{}));
}
