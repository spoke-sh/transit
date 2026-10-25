const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const Index = s.OrderedKeyIndex;
const pages = s.TreeStore.pages;

fn value(ordinal: usize) [32]u8 {
    var result: [32]u8 = @splat(0);
    std.mem.writeInt(u64, result[0..8], ordinal, .big);
    return result;
}
fn less(_: void, a: Index.Entry, b: Index.Entry) bool {
    return std.mem.order(u8, a.key.slice(), b.key.slice()) == .lt;
}
fn expected(oracle: []const Index.Entry, lower: ?Index.Bound, upper: ?Index.Bound) ?Index.Entry {
    for (oracle) |entry| {
        if (lower) |bound| {
            const order = std.mem.order(u8, entry.key.slice(), bound.key);
            if (order == .lt or (order == .eq and !bound.inclusive)) continue;
        }
        if (upper) |bound| {
            const order = std.mem.order(u8, entry.key.slice(), bound.key);
            if (order == .gt or (order == .eq and !bound.inclusive)) return null;
        }
        return entry;
    }
    return null;
}

test "ordered full keys match an independent sorted oracle across chunk boundaries and prefixes" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer store.deinit();
    const index: Index = .{ .store = &store };
    var root: ?pages.Reference = null;
    var oracle: [96]Index.Entry = undefined;
    const lengths = [_]usize{ 1, 2, 63, 64, 65, 127, 128, 129, 255, 256, 257, 4096 };
    for (&oracle, 0..) |*entry, i| {
        var key: Index.Key = .{ .len = @intCast(lengths[i % lengths.len]) };
        @memset(key.data[0..key.len], @intCast(i / lengths.len));
        entry.* = .{ .key = key, .value = value(i) };
    }
    // Deliberately reverse the generated prefix order when building the index.
    for (0..oracle.len) |i| {
        const entry = oracle[oracle.len - i - 1];
        try store.begin(16 * 1024 * 1024);
        defer store.end();
        root = try index.put(root, entry.key.slice(), entry.value);
    }
    std.mem.sort(Index.Entry, &oracle, {}, less);
    var after: ?Index.Key = null;
    for (oracle) |entry| {
        const found = (try index.seek(root, if (after) |*key| .{ .key = key.slice(), .inclusive = false } else null, null)).?;
        try t.expectEqualDeep(entry, found);
        try t.expectEqualDeep(entry.value, (try index.get(root, entry.key.slice())).?);
        after = found.key;
    }
    try t.expect((try index.seek(root, .{ .key = after.?.slice(), .inclusive = false }, null)) == null);
    for (oracle, 0..) |entry, i| {
        const high = oracle[@min(i + 7, oracle.len - 1)].key;
        for ([_]bool{ false, true }) |inclusive| {
            const lower: Index.Bound = .{ .key = entry.key.slice(), .inclusive = inclusive };
            const upper: Index.Bound = .{ .key = high.slice(), .inclusive = inclusive };
            try t.expectEqualDeep(expected(&oracle, lower, upper), try index.seek(root, lower, upper));
            var absent = entry.key;
            absent.data[absent.len - 1] +%= 17;
            const between: Index.Bound = .{ .key = absent.slice(), .inclusive = inclusive };
            try t.expectEqualDeep(expected(&oracle, between, upper), try index.seek(root, between, upper));
        }
    }
    const retained = root;
    for (oracle, 0..) |entry, i| {
        try store.begin(16 * 1024 * 1024);
        defer store.end();
        if (i % 2 == 0) {
            root = try index.remove(root, entry.key.slice());
            try t.expect((try index.get(root, entry.key.slice())) == null);
        } else {
            root = try index.put(root, entry.key.slice(), value(i + 1000));
            try t.expectEqualDeep(value(i + 1000), (try index.get(root, entry.key.slice())).?);
        }
        try t.expectEqualDeep(entry.value, (try index.get(retained, entry.key.slice())).?);
    }
    after = null;
    for (oracle, 0..) |entry, i| {
        if (i % 2 == 0) continue;
        const found = (try index.seek(root, if (after) |*key| .{ .key = key.slice(), .inclusive = false } else null, null)).?;
        try t.expectEqualDeep(entry.key, found.key);
        try t.expectEqualDeep(value(i + 1000), found.value);
        after = found.key;
    }
    for (oracle) |entry| {
        try store.begin(16 * 1024 * 1024);
        defer store.end();
        root = try index.remove(root, entry.key.slice());
    }
    try t.expect(root == null);
}

test "ordered full keys reopen on disk beyond cache with exact bounds and failed candidate isolation" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var root: ?pages.Reference = null;
    var retained: ?pages.Reference = null;
    var keys: [33][129]u8 = undefined;
    for (&keys, 0..) |*key, i| {
        @memset(key, 0);
        key[128] = @intCast(i);
    }
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
        defer store.deinit();
        const index: Index = .{ .store = &store };
        for (keys, 0..) |key, i| {
            try store.begin(1024 * 1024);
            defer store.end();
            root = try index.put(root, &key, value(i));
        }
        retained = root;
        try store.begin(1);
        try t.expectError(error.StorageCandidateTooLarge, index.put(root, &keys[16], value(1000)));
        store.end();
        try t.expectEqualDeep(value(16), (try index.get(root, &keys[16])).?);
        try store.begin(1024 * 1024);
        defer store.end();
        root = try index.remove(root, &keys[16]);
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 0);
    defer store.deinit();
    const index: Index = .{ .store = &store };
    try t.expectEqual(@as(usize, 0), store.residentBytes());
    try t.expectEqualDeep(value(16), (try index.get(retained, &keys[16])).?);
    try t.expect((try index.get(root, &keys[16])) == null);
    const next = (try index.seek(root, .{ .key = &keys[16] }, .{ .key = &keys[18] })).?;
    try t.expectEqualSlices(u8, &keys[17], next.key.slice());
    try t.expect((try index.seek(root, .{ .key = &keys[16] }, .{ .key = &keys[17], .inclusive = false })) == null);
    try t.expectError(error.InvalidTableKey, index.get(root, ""));
    var invalid = root.?;
    invalid.digest[0] ^= 1;
    try t.expectError(error.CorruptPage, index.seek(invalid, null, null));
}
