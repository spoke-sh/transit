const std = @import("std");
const t = std.testing;
const storage = @import("transit_storage");
const Marks = @import("DataMarkWork.zig");
const Work = struct { sequence: u64, name: storage.TreeStore.pages.Bytes(256) };
const Workspace = Marks.Workspace(Work);

fn digest(bytes: []const u8) [32]u8 {
    var value: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &value, .{});
    return value;
}

test "direct mark work reopens paged queues and typed scopes with fixed private memory" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var state: Marks.State = .{};
    var fixed: @import("transit_fuze").MemoryBudget = .{ .parent = t.allocator, .limit = 512 * 1024 };
    {
        var objects = try storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var index = try storage.TreeStore.init(fixed.allocator(), objects.objectStore(), 0);
        defer index.deinit();
        var workspace: Workspace = .{ .state = &state, .index = &index };
        for (0..97) |i| {
            var buffer: [96]u8 = undefined;
            const name = try std.fmt.bufPrint(&buffer, "test-owned/{d}.data", .{i});
            const meta = try objects.objectStore().putImmutable(name, name, digest(name));
            try index.begin(1024 * 1024);
            defer index.end();
            try workspace.mark(name, meta);
            try t.expect(try workspace.marked(name, meta));
            try t.expect(!try workspace.visited(digest(name)));
            try t.expect(try workspace.visited(digest(name)));
            try workspace.enqueue(.{ .sequence = i, .name = try .init(name) });
        }
    }
    try state.validate();
    try t.expectEqual(@as(usize, 0), fixed.used);
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, state, .{});
    defer t.allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(Marks.State, t.allocator, bytes, .{});
    defer parsed.deinit();
    state = parsed.value;
    var objects = try storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var index = try storage.TreeStore.init(fixed.allocator(), objects.objectStore(), 0);
    defer index.deinit();
    var workspace: Workspace = .{ .state = &state, .index = &index };
    for (0..97) |i| {
        try index.begin(1024 * 1024);
        defer index.end();
        const item = (try workspace.take(fixed.allocator())).?;
        try t.expectEqual(i, item.sequence);
        var buffer: [96]u8 = undefined;
        const name = try std.fmt.bufPrint(&buffer, "test-owned/{d}.data", .{i});
        try t.expectEqualStrings(name, item.name.slice());
        try t.expect(try workspace.marked(name, .{ .size = name.len, .sha256 = digest(name) }));
        try t.expect(try workspace.visited(digest(name)));
    }
    try t.expect(try workspace.take(fixed.allocator()) == null);
    try state.validate();
    try t.expect(state.queue == null);
    try t.expectEqual(@as(usize, 0), fixed.used);
}

test "direct mark work rejects missing work and mismatched object evidence" {
    var objects = storage.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var index = try storage.TreeStore.init(t.allocator, objects.objectStore(), 0);
    defer index.deinit();
    var state: Marks.State = .{};
    var workspace: Workspace = .{ .state = &state, .index = &index };
    try index.begin(1024 * 1024);
    defer index.end();
    const name = "test-owned/retained";
    const meta = try objects.objectStore().putImmutable(name, "value", digest("value"));
    try workspace.mark(name, meta);
    var conflict = meta;
    conflict.size += 1;
    try t.expectError(error.InvalidStorageGraph, workspace.mark(name, conflict));
    try t.expectError(error.InvalidStorageGraph, workspace.marked(name, conflict));
    try t.expectError(error.ObjectNotFound, workspace.mark("test-owned/absent", meta));
    try workspace.enqueue(.{ .sequence = 9, .name = try .init(name) });
    const before = state;
    for (objects.objects.items) |item| if (std.mem.startsWith(u8, item.key, "data-maintenance/")) {
        const copy = try t.allocator.dupe(u8, item.key);
        defer t.allocator.free(copy);
        try objects.deleteObject(copy);
        break;
    };
    try t.expectError(error.ObjectNotFound, workspace.take(t.allocator));
    try t.expectEqualDeep(before, state);
    state.queue = null;
    try t.expectError(error.InvalidStorageCollection, workspace.take(t.allocator));
}
