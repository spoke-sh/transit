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

test "derived page eviction retains provider reads without masking absent accepted pages" {
    const Candidates = @import("CandidateObjects.zig");
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var probe: @import("transit_fuze").memory.AllocationProbe = .{ .parent = t.allocator };
    var store = try s.TreeStore.init(probe.allocator(), objects.objectStore(), 4);
    defer store.deinit();
    const tree: pages.Tree(s.TreeStore) = .{ .store = &store };
    try store.begin(1024 * 1024);
    const retained = try tree.put(null, try key(1), try pages.Value.init("retained"));
    const missing = try tree.put(null, try key(2), try pages.Value.init("missing"));
    const missing_page = try store.load(missing);
    store.end();
    store.clearCache();
    const retained_page = try store.load(retained);
    const provider_reads = objects.range_reads;
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try s.TreeStore.key(missing.location, &name));

    var candidates = try Candidates.init(t.allocator, objects.objectStore(), .{ .bytes = 1024 * 1024, .objects = 16, .resident_bytes = 2 * 1024 * 1024 });
    defer candidates.deinit();
    store.store = candidates.objectStore();
    store.load_provenance = .{ .context = &candidates, .is_private = struct {
        fn contains(raw: *anyopaque, object_key: []const u8) bool {
            const private: *Candidates = @ptrCast(@alignCast(raw));
            return private.contains(object_key);
        }
    }.contains };
    probe.begin(true);
    try store.begin(1024 * 1024);
    // One reconstructed page matches an earlier verified provider read; the
    // other can recreate an absent accepted page byte-for-byte.
    try t.expectEqualDeep(retained, try store.stage(try retained_page.reference(), &retained_page));
    try t.expectEqualDeep(missing, try store.stage(try missing_page.reference(), &missing_page));
    store.end();
    store.clearDerived();
    try t.expectEqualDeep(missing_page, try store.load(missing)); // Overlay read, not provider evidence.
    store.clearDerived();
    store.store = objects.objectStore();
    store.load_provenance = null;
    try t.expectEqualDeep(retained_page, try store.load(retained));
    try t.expectEqual(provider_reads, objects.range_reads);
    try t.expectError(error.MissingDataIndexObject, store.load(missing));
    try probe.verify();
    probe.begin(false);
}

test "derived page eviction does not retain an unflushed batch read" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer store.deinit();
    const tree: pages.Tree(s.TreeStore) = .{ .store = &store };
    var batch: s.TreeStore.Batch = .{};
    try store.beginBatch(1024 * 1024, &batch);
    const private = try tree.put(null, try key(1), try pages.Value.init("unflushed"));
    store.clearDerived();
    _ = try store.load(private);
    store.end();
    store.clearDerived();
    try t.expectEqual(@as(u64, 0), objects.puts);
    try t.expectError(error.MissingDataIndexObject, store.load(private));
}
