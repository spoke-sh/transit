const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const pages = s.TreeStore.pages;

fn key(value: u64) !pages.Key {
    var encoded: [8]u8 = undefined;
    std.mem.writeInt(u64, &encoded, value, .big);
    return pages.Key.init(&encoded);
}

test "immutable data indexes reopen beyond one resident page and retain earlier roots" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var root: ?pages.Reference = null;
    var before: ?pages.Reference = null;
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
        defer store.deinit();
        const tree: pages.Tree(s.TreeStore) = .{ .store = &store };
        for (0..513) |i| {
            try store.begin(1024 * 1024);
            defer store.end();
            root = try tree.put(root, try key(i), try pages.Value.init("original"));
        }
        before = root;
        try store.begin(1024 * 1024);
        defer store.end();
        root = try tree.put(root, try key(512), try pages.Value.init("changed"));
        root = try tree.remove(root, try key(0));
        try t.expectEqual(@as(usize, @sizeOf(@TypeOf(store.cache[0]))), store.residentBytes());
        try t.expect(store.misses > 1);
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 0);
    defer store.deinit();
    const tree: pages.Tree(s.TreeStore) = .{ .store = &store };
    try t.expectEqual(@as(usize, 0), store.residentBytes());
    try t.expect((try tree.get(root, try key(0))) == null);
    const changed = (try tree.get(root, try key(512))).?;
    try t.expectEqualStrings("changed", changed.slice());
    const original = (try tree.get(before, try key(512))).?;
    try t.expectEqualStrings("original", original.slice());
    var after: ?pages.Key = null;
    var count: usize = 0;
    while (true) {
        const batch = try tree.scan(root, after);
        for (batch.entries) |slot| if (slot) |entry| {
            count += 1;
            try t.expectEqual(count, std.mem.readInt(u64, entry.key.data[0..8], .big));
        };
        after = batch.next orelse break;
    }
    try t.expectEqual(@as(usize, 512), count);
    var invalid = root.?;
    invalid.digest[0] ^= 1;
    try t.expectError(error.CorruptPage, store.load(invalid));
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try std.fmt.bufPrint(&name, "data-index/{x}.data", .{&root.?.location}));
    try t.expectError(error.MissingDataIndexObject, store.load(root.?));
}

test "a private index budget failure cannot change the accepted root" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer store.deinit();
    const tree: pages.Tree(s.TreeStore) = .{ .store = &store };
    try store.begin(1024);
    const root = try tree.put(null, try key(1), try pages.Value.init("accepted"));
    store.end();
    try store.begin(1);
    defer store.end();
    try t.expectError(error.StorageCandidateTooLarge, tree.put(root, try key(1), try pages.Value.init("unpublished")));
    const value = (try tree.get(root, try key(1))).?;
    try t.expectEqualStrings("accepted", value.slice());
}

test "second-chance cache retains loaded root pages across staging churn" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 2);
    defer store.deinit();
    const tree: pages.Tree(s.TreeStore) = .{ .store = &store };
    try store.begin(1024 * 1024);
    const hot_root = try tree.put(null, try key(1), try pages.Value.init("hot"));
    store.end();
    _ = try store.load(hot_root);
    const misses_before = store.misses;
    for (0..4) |i| {
        try store.begin(1024 * 1024);
        defer store.end();
        _ = try tree.put(null, try key(100 + i), try pages.Value.init("transient"));
        _ = try store.load(hot_root);
    }
    try t.expectEqual(misses_before, store.misses);
}

test "immutable page batches preserve duplicate pages and bounded failure output" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 0);
    defer store.deinit();
    var page: pages.Page = .{ .count = 1, .body = .{ .leaf = @splat(null) } };
    page.body.leaf[0] = .{ .key = try key(11), .value = try pages.Value.init("retained") };
    var refs: [2]pages.Reference = undefined;
    try store.begin(1024 * 1024);
    try store.stageMany(&.{ page, page }, &refs);
    store.end();
    try t.expectEqualDeep(refs[0], refs[1]);
    try t.expectEqual(@as(u64, 1), objects.puts);
    try t.expectEqualDeep(page, try store.load(refs[0]));
    const original = refs;
    try store.begin(1);
    defer store.end();
    try t.expectError(error.StorageCandidateTooLarge, store.stageMany(&.{ page, page }, &refs));
    try t.expectEqualDeep(original, refs);
    try t.expectEqualDeep(page, try store.load(original[0]));
}
