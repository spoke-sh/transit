const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const s = @import("root.zig");
const Run = s.QueueTimeRun;
const Directory = s.QueueTimeDirectory;
fn seed() p.StreamQueue.Partition {
    return .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(1) }, .partition = 2 };
}
fn event(ordinal: usize) Run.Event {
    return .{ .at_ms = ordinal / 2, .offset = ordinal, .epoch = ordinal % 2 };
}

test "queue time directory exceeds chunk and page cache bounds while preserving earlier disk roots" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var root: Directory.Root = .empty;
    var earlier: Directory.Root = .empty;
    var encoded: [Run.max_bytes]u8 = undefined;
    var events: [64]Run.Event = undefined;
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "directory");
        defer objects.deinit();
        var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
        defer tree.deinit();
        const directory: Directory = .{ .store = &tree, .seed = seed(), .kind = .visible, .bucket = 0 };
        for (0..49) |i| {
            for (&events, 0..) |*value, j| value.* = event(i * events.len + j);
            const chunk = try Run.stage(t.allocator, objects.objectStore(), seed(), .visible, i + 1, &events, &encoded);
            try tree.begin(1024 * 1024);
            defer tree.end();
            root = try directory.append(root, chunk);
            if (i == 20) earlier = root;
        }
        try t.expectEqual(@as(u64, 3136), root.rows);
        try t.expectEqual(@as(u64, 49), root.chunks);
        try t.expect(tree.misses > 1);
        for (&events, 0..) |*value, j| value.* = event(49 * events.len + j);
        const unpublished = try Run.stage(t.allocator, objects.objectStore(), seed(), .visible, 50, &events, &encoded);
        try tree.begin(1);
        try t.expectError(error.StorageCandidateTooLarge, directory.append(root, unpublished));
        tree.end();
        try t.expect(try directory.find(root, root.last) == null);
        try tree.begin(1024 * 1024);
        defer tree.end();
        const first = (try directory.find(root, null)).?;
        try t.expectError(error.QueueTimeRunOverlap, directory.append(root, first.chunk));
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "directory");
    defer objects.deinit();
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer tree.deinit();
    const directory: Directory = .{ .store = &tree, .seed = seed(), .kind = .visible, .bucket = 0 };
    for ([_]Directory.Root{ earlier, root }) |basis| {
        var cursor: Directory.Audit = .{ .basis = basis };
        var count: usize = 0;
        while (try directory.audit(&cursor)) |entry| {
            try t.expect(!cursor.complete);
            const rows = try Run.load(t.allocator, objects.objectStore(), entry.chunk, &events);
            for (rows) |value| {
                try t.expectEqualDeep(event(count), value);
                count += 1;
            }
        }
        try t.expect(cursor.complete);
        try t.expectEqual(basis.rows, count);
        try t.expectEqual(basis.chunks, cursor.chunks);
        try t.expect(try directory.audit(&cursor) == null);
    }
    const inside = (try directory.find(root, event(65))).?;
    try t.expectEqual(@as(u64, 64), inside.first_row);
    const following = (try directory.find(root, inside.chunk.last)).?;
    try t.expectEqual(@as(u64, 128), following.first_row);
    try t.expectEqual(@as(u64, 0), objects.puts);

    var bad: Directory.Audit = .{ .basis = root };
    bad.basis.rows -= 1;
    var refused = false;
    for (0..50) |_| {
        const before = bad;
        const entry = directory.audit(&bad) catch |err| {
            try t.expectEqual(error.InvalidQueueTimeDirectory, err);
            try t.expectEqualDeep(before, bad);
            refused = true;
            break;
        };
        if (entry == null) return error.UnexpectedAuditCompletion;
    }
    try t.expect(refused and !bad.complete);
    var foreign = directory;
    foreign.seed.partition += 1;
    var cursor: Directory.Audit = .{ .basis = root };
    const before = cursor;
    try t.expectError(error.InvalidQueueTimeDirectory, foreign.audit(&cursor));
    try t.expectEqualDeep(before, cursor);
    foreign = directory;
    foreign.bucket += 1;
    try t.expectError(error.InvalidQueueTimeDirectory, foreign.find(root, null));
}

test "queue time directory refuses gaps and extra entries before audit completion" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer tree.deinit();
    const directory: Directory = .{ .store = &tree, .seed = seed(), .kind = .visible, .bucket = 0 };
    var encoded: [Run.max_bytes]u8 = undefined;
    const first = try Run.stage(t.allocator, objects.objectStore(), seed(), .visible, 1, &.{event(0)}, &encoded);
    const second = try Run.stage(t.allocator, objects.objectStore(), seed(), .visible, 2, &.{event(1)}, &encoded);
    try tree.begin(1024 * 1024);
    defer tree.end();
    const one = try directory.append(.empty, first);
    const two = try directory.append(one, second);
    var forged = one;
    forged.directory = two.directory;
    var cursor: Directory.Audit = .{ .basis = forged };
    try t.expect((try directory.audit(&cursor)) != null);
    const before = cursor;
    try t.expectError(error.InvalidQueueTimeDirectory, directory.audit(&cursor));
    try t.expectEqualDeep(before, cursor);
    var index: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &tree };
    forged = two;
    forged.directory = try index.remove(two.directory, try Directory.eventKey(first.last));
    cursor = .{ .basis = forged };
    try t.expectError(error.InvalidQueueTimeDirectory, directory.audit(&cursor));
    try t.expect(!cursor.complete and cursor.rows == 0);
    var value = try (Directory.Entry{ .first_row = 0, .chunk = first }).encode();
    value.data[16] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Directory.Entry.decode(value));
    var empty: Directory.Audit = .{ .basis = .empty };
    try t.expect(try directory.audit(&empty) == null);
    try t.expect(empty.complete);
}
