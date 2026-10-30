const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const B = s.BitmapDirectory;

test "paged bitmap exceeds its cache and preserves full-width offsets across disk reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var root: B.Root = .empty;
    var earlier: B.Root = .empty;
    var scratch: B.Container = .{};
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "bitmap");
        defer objects.deinit();
        var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
        defer tree.deinit();
        var directory: B = .{ .store = &tree, .objects = objects.objectStore() };
        for (0..49) |i| {
            try tree.begin(1024 * 1024);
            defer tree.end();
            root = try directory.edit(root, i * 1000, &.{ .{ .offset = 0, .present = true }, .{ .offset = 65535, .present = true } }, &scratch);
        }
        earlier = root;
        try tree.begin(1024 * 1024);
        defer tree.end();
        root = try directory.edit(root, std.math.maxInt(u48), &.{.{ .offset = 65535, .present = true }}, &scratch);
        root = try directory.edit(root, 0, &.{.{ .offset = 0, .present = false }}, &scratch);
        try t.expectEqual(@as(u64, 98), root.cardinality);
        try t.expect(tree.misses > 1);
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "bitmap");
    defer objects.deinit();
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer tree.deinit();
    var directory: B = .{ .store = &tree, .objects = objects.objectStore() };
    try t.expect(!try directory.contains(root, 0));
    try t.expect(try directory.contains(earlier, 0));
    try t.expect(try directory.contains(root, std.math.maxInt(u64)));
    try t.expect(!try directory.contains(earlier, std.math.maxInt(u64)));
    for (0..49) |i| {
        const prefix: u64 = i * 1000;
        try t.expect(try directory.contains(root, (prefix << 16) | 65535));
        try t.expect(!try directory.contains(root, (prefix << 16) | 123));
    }
    var after: ?s.TreeStore.pages.Key = null;
    var total: u64 = 0;
    var containers: usize = 0;
    while (true) {
        const page = try directory.scan(root, after);
        for (page.entries) |slot| if (slot) |entry| {
            const prefix = try B.prefixOf(entry.key);
            const ref = try B.Reference.decode(entry.value);
            total += (try directory.read(prefix, ref)).cardinality;
            containers += 1;
        };
        after = page.next orelse break;
    }
    try t.expectEqual(root.cardinality, total);
    try t.expectEqual(@as(usize, 50), containers);
}

test "paged bitmap refuses failed private staging and missing or foreign containers" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer tree.deinit();
    var directory: B = .{ .store = &tree, .objects = objects.objectStore() };
    var scratch: B.Container = .{};
    try tree.begin(1024 * 1024);
    const root = try directory.edit(.empty, 0, &.{.{ .offset = 42, .present = true }}, &scratch);
    tree.end();
    try tree.begin(1);
    try t.expectError(error.StorageCandidateTooLarge, directory.edit(root, 0, &.{.{ .offset = 43, .present = true }}, &scratch));
    tree.end();
    try t.expect(try directory.contains(root, 42));
    try t.expect(!try directory.contains(root, 43));
    const ref = (try directory.reference(root, 0)).?;
    try t.expectError(error.InvalidBitmapContainer, directory.read(1, ref));
    try t.expect(try directory.contains(root, 42));
    const reads = objects.range_reads;
    for (0..100) |_| try t.expect(try directory.contains(root, 42));
    try t.expectEqual(reads, objects.range_reads);
    var key: [96]u8 = undefined;
    try objects.objectStore().delete(try B.objectKey(ref, &key));
    directory.cached = null;
    try t.expectError(error.MissingBitmapContainer, directory.contains(root, 42));
}

test "paged bitmap removes empty containers and rejects inconsistent root cardinality" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer tree.deinit();
    var directory: B = .{ .store = &tree, .objects = objects.objectStore() };
    var scratch: B.Container = .{};
    try tree.begin(1024 * 1024);
    defer tree.end();
    const root = try directory.edit(.empty, 0, &.{.{ .offset = 42, .present = true }}, &scratch);
    const empty = try directory.edit(root, 0, &.{.{ .offset = 42, .present = false }}, &scratch);
    try t.expectEqualDeep(B.Root.empty, empty);
    try t.expect(try directory.contains(root, 42));
    var invalid = root;
    invalid.cardinality = 0;
    try t.expectError(error.InvalidBitmapRoot, directory.contains(invalid, 42));
    try t.expectError(error.InvalidBitmapPrefix, directory.edit(root, std.math.maxInt(u64), &.{}, &scratch));
}

test "paged bitmap cache misses and edits use no owner heap after initialization" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var allocator = t.FailingAllocator.init(t.allocator, .{});
    var tree = try s.TreeStore.init(allocator.allocator(), objects.objectStore(), 1);
    defer tree.deinit();
    var directory: B = .{ .store = &tree, .objects = objects.objectStore() };
    var scratch: B.Container = .{};
    allocator.fail_index = allocator.alloc_index;
    const initial = allocator.allocated_bytes;
    var root: B.Root = .empty;
    for (0..40) |prefix| {
        try tree.begin(1024 * 1024);
        defer tree.end();
        root = try directory.edit(root, prefix, &.{.{ .offset = 17, .present = true }}, &scratch);
    }
    tree.clearCache();
    directory.cached = null;
    for (0..40) |prefix| try t.expect(try directory.contains(root, (prefix << 16) | 17));
    try t.expectEqual(initial, allocator.allocated_bytes);
    try t.expect(!allocator.has_induced_failure);
    // Provider storage allocations belong to its separate physical owner.
}
