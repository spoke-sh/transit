const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const d = @import("transit_protocol").DataLifecycle;
const r = @import("TablePartitionRecord.zig");
const Snapshot = @import("TableSnapshot.zig");
const W = s.TableStorageWalk;
const pages = s.TreeStore.pages;
const context: W.Context = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 }, .partition = 17, .next_lsn = 100, .next_segment = 100 };

const Probe = struct {
    store: *s.TreeStore,
    loads: usize = 0,
    deny: bool = false,
    pub fn load(self: *Probe, reference: pages.Reference) !pages.Page {
        self.loads += 1;
        if (self.deny) return error.InjectedReadFailure;
        return self.store.load(reference);
    }
};

test "Table storage walk resumes bounded page paths and preserves failed cursors" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer store.deinit();
    try store.begin(8 * 1024 * 1024);
    defer store.end();
    const tree: pages.Tree(s.TreeStore) = .{ .store = &store };
    var root: ?pages.Reference = null;
    for (0..257) |i| {
        var key: [32]u8 = @splat(0);
        std.mem.writeInt(u64, key[0..8], i, .big);
        const row: r.Locator = .{ .kind = if (i % 2 == 0) .wal else .segment, .lsn = 1 + i % 98, .offset = 0, .length = 256, .digest = @splat(@intCast(i % 256)) };
        root = try tree.put(root, try pages.Key.init(&key), try row.encode());
    }
    var walk = try W.init(context, .{ .reference = root.?, .kind = .rows });
    var probe: Probe = .{ .store = &store };
    var count: usize = 0;
    var index_pages: usize = 0;
    var wal: usize = 0;
    var segments: usize = 0;
    while (true) {
        const before = walk;
        probe.deny = true;
        try t.expectError(error.InjectedReadFailure, walk.next(&probe));
        try t.expectEqualDeep(before, walk);
        probe.deny = false;
        const loads = probe.loads;
        const edge = (try walk.next(&probe)) orelse break;
        try t.expect(probe.loads - loads <= W.max_depth + 1);
        switch (edge) {
            .page => index_pages += 1,
            .wal => |position| {
                try t.expectEqual(@as(u64, 17), position.partition);
                try t.expect(position.next_lsn <= context.next_lsn);
                wal += 1;
            },
            .segment => |content| {
                try t.expectEqual(@as(u64, 256), content.bytes);
                segments += 1;
            },
            else => return error.UnexpectedStorageEdge,
        }
        count += 1;
        // JSON is a test transport for owned cursor fields, not an on-disk
        // maintenance format or authority to select a retained root.
        const encoded = try std.json.Stringify.valueAlloc(t.allocator, walk, .{});
        defer t.allocator.free(encoded);
        const parsed = try std.json.parseFromSlice(W, t.allocator, encoded, .{});
        defer parsed.deinit();
        walk = parsed.value;
    }
    try t.expect(index_pages > 1);
    try t.expectEqual(@as(usize, 129), wal);
    try t.expectEqual(@as(usize, 128), segments);
    try t.expectEqual(index_pages + wal + segments, count);
    try t.expect(@sizeOf(W) < 4096);
    walk = try W.init(context, .{ .reference = root.?, .kind = .rows });
    _ = (try walk.next(&probe)).?;
    try walk.skip();
    try t.expectEqual(null, try walk.next(&probe));
    try t.expectError(error.InvalidTableStorageGraph, walk.skip());
}

test "Table storage walk emits live pins compact evidence and archive frames without implicit recursion" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 0);
    defer store.deinit();
    try store.begin(1024 * 1024);
    defer store.end();
    const tree: pages.Tree(s.TreeStore) = .{ .store = &store };
    const identity: d.Operation = .{ .scope = context.object.scope, .principal = 4, .operation = 9 };
    const key = try r.operationKey(identity);
    const content: d.Content = .{ .bytes = 1024, .sha256 = @splat(7) };
    const reference = try s.TableEvidence.reference(content);
    const evidence_root = try tree.put(null, key, reference);
    for ([_]W.Kind{ .receipts, .operations }) |kind| {
        var walk = try W.init(context, .{ .reference = evidence_root, .kind = kind });
        _ = (try walk.next(&store)).?;
        const edge = (try walk.next(&store)).?.evidence;
        try t.expectEqualDeep(identity, edge.owner);
        try t.expectEqualDeep(content, edge.content);
        try t.expectEqual(kind == .receipts, edge.kind == .receipt);
        try t.expectError(error.InvalidTableStorageGraph, walk.skip());
        try t.expectEqual(null, try walk.next(&store));
    }
    var pins = try tree.put(null, key, try (Snapshot.Pin{ .content = content }).encode());
    var released = identity;
    released.operation += 1;
    pins = try tree.put(pins, try r.operationKey(released), try (Snapshot.Pin{ .content = content, .released = true }).encode());
    var walk = try W.init(context, .{ .reference = pins, .kind = .pins });
    _ = (try walk.next(&store)).?;
    try t.expectEqualDeep(Snapshot.Handle{ .owner = identity, .content = content }, (try walk.next(&store)).?.snapshot);
    try t.expectEqual(null, try walk.next(&store));
    // Opaque directories own only their pages, even if a value looks exactly
    // like an evidence/pin reference. The caller chooses the semantic role.
    walk = try W.init(context, .{ .reference = pins, .kind = .pages_only });
    _ = (try walk.next(&store)).?;
    try t.expectEqual(null, try walk.next(&store));
    var archive_value: [36]u8 = undefined;
    std.mem.writeInt(u32, archive_value[0..4], 1024, .little);
    archive_value[4..36].* = content.sha256;
    const archive = try tree.put(null, try s.TableArchive.key(2), try pages.Value.init(&archive_value));
    walk = try W.init(context, .{ .reference = archive, .kind = .archive });
    _ = (try walk.next(&store)).?;
    const frame = (try walk.next(&store)).?.archive;
    try t.expectEqualDeep(d.Position{ .partition = 17, .next_lsn = 3 }, frame.position);
    try t.expectEqualDeep(content, frame.content);
    try t.expectEqual(null, try walk.next(&store));
}

test "Table storage walk queues long-key child directories with bounded resident depth" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer store.deinit();
    try store.begin(8 * 1024 * 1024);
    defer store.end();
    const ordered: s.OrderedKeyIndex = .{ .store = &store };
    const key: [s.OrderedKeyIndex.max_key_bytes]u8 = @splat('x');
    const root = try ordered.put(null, &key, @splat(7));
    var next: ?W.Root = .{ .reference = root, .kind = .ordered_rows };
    var directories: usize = 0;
    while (next) |selected| {
        next = null;
        var walk = try W.init(context, selected);
        var count: usize = 0;
        while (try walk.next(&store)) |edge| switch (edge) {
            .page => count += 1,
            .index => |child| {
                try t.expectEqual(null, next);
                try t.expectEqual(selected.prefix_bytes + 64, child.prefix_bytes);
                next = child;
            },
            else => return error.UnexpectedStorageEdge,
        };
        try t.expectEqual(@as(usize, 1), count);
        directories += 1;
    }
    try t.expectEqual(@as(usize, 64), directories);
    try t.expectError(error.InvalidTableStorageGraph, W.init(context, .{ .reference = root, .kind = .ordered_rows, .prefix_bytes = 4096 }));
}

test "Table storage walk rejects malformed typed edges without advancing" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 0);
    defer store.deinit();
    try store.begin(1024 * 1024);
    defer store.end();
    const tree: pages.Tree(s.TreeStore) = .{ .store = &store };
    const root = try tree.put(null, try pages.Key.init("bad"), try pages.Value.init("bad"));
    for ([_]W.Kind{ .rows, .scan_rows, .receipts, .operations, .pins, .archive, .ordered_rows }) |kind| {
        var walk = try W.init(context, .{ .reference = root, .kind = kind });
        _ = (try walk.next(&store)).?;
        const before = walk;
        if (walk.next(&store)) |_| return error.ExpectedInvalidGraph else |_| {}
        try t.expectEqualDeep(before, walk);
    }
    var corrupt = root;
    corrupt.digest[0] ^= 1;
    var walk = try W.init(context, .{ .reference = corrupt, .kind = .pages_only });
    var before = walk;
    try t.expectError(error.CorruptPage, walk.next(&store));
    try t.expectEqualDeep(before, walk);

    // Each page is valid by itself, but the parent lies about its child's
    // height. Traversal must verify that edge before disclosing the child.
    var parent: pages.Page = .{ .height = 2, .count = 1, .body = .{ .branch = @splat(null) } };
    parent.body.branch[0] = .{ .minimum = try pages.Key.init("bad"), .reference = root };
    const wrong_height = try store.stage(try parent.reference(), &parent);
    walk = try W.init(context, .{ .reference = wrong_height, .kind = .pages_only });
    _ = (try walk.next(&store)).?;
    before = walk;
    try t.expectError(error.InvalidTableStorageGraph, walk.next(&store));
    try t.expectEqualDeep(before, walk);
}
