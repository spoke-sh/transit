const std = @import("std");
const t = std.testing;
const p = @import("pages.zig");

const Store = struct {
    allocator: std.mem.Allocator = t.allocator,
    pages: std.AutoHashMapUnmanaged(p.Reference, p.Page) = .empty,
    writes: usize = 0,
    reads: usize = 0,
    fail_at: ?usize = null,
    lose_at: ?usize = null,
    missing: bool = false,
    corrupt: bool = false,
    pub fn stage(self: *Store, ref: p.Reference, page: *const p.Page) !void {
        if (self.fail_at == self.writes) return error.StagingFailed;
        self.writes += 1;
        if (!self.pages.contains(ref)) try self.pages.put(self.allocator, ref, page.*);
        if (self.lose_at == self.writes - 1) return error.StagingAcknowledgementLost;
    }
    pub fn load(self: *Store, ref: p.Reference) !p.Page {
        self.reads += 1;
        if (self.missing) return error.PageUnavailable;
        if (self.pages.getPtr(ref)) |item| {
            var result = item.*;
            if (self.corrupt) switch (result.body) {
                .leaf => result.body.leaf[0].?.value.data[0] ^= 1,
                .branch => result.body.branch[0].?.reference[0] ^= 1,
            };
            return result;
        }
        return error.PageUnavailable;
    }
    fn deinit(self: *Store) void {
        self.pages.deinit(self.allocator);
    }
};
fn key(index: usize) p.Key {
    var buffer: [8]u8 = undefined;
    std.mem.writeInt(u64, &buffer, index, .big);
    return p.Key.init(&buffer) catch unreachable;
}
fn value(index: usize) p.Value {
    var buffer: [8]u8 = undefined;
    std.mem.writeInt(u64, &buffer, index, .big);
    return p.Value.init(&buffer) catch unreachable;
}

test "immutable pages grow beyond legacy rows and keep independent snapshot roots" {
    var store: Store = .{};
    defer store.deinit();
    const tree: p.Tree(Store) = .{ .store = &store };
    var root: ?p.Reference = null;
    for (0..256) |i| root = try tree.put(root, key(i), value(i));
    const snapshot = root;
    for (0..256) |i| {
        store.reads = 0;
        const found = (try tree.get(root, key(i))).?;
        try t.expectEqualSlices(u8, value(i).slice(), found.slice());
        try t.expect(store.reads <= p.max_height + 1);
    }
    for (0..256) |i| if (i % 3 == 0) {
        root = try tree.remove(root, key(i));
    } else {
        root = try tree.put(root, key(i), value(i + 1));
    };
    var cursor: ?p.Key = null;
    var seen: usize = 0;
    var expected: usize = 0;
    while (true) {
        const page = try tree.scan(root, cursor);
        for (page.entries) |slot| if (slot) |entry| {
            while (expected % 3 == 0) expected += 1;
            try t.expectEqualSlices(u8, key(expected).slice(), entry.key.slice());
            try t.expectEqualSlices(u8, value(expected + 1).slice(), entry.value.slice());
            seen += 1;
            expected += 1;
        };
        cursor = page.next;
        if (cursor == null) break;
    }
    try t.expectEqual(@as(usize, 170), seen);
    for (0..256) |i| {
        try t.expectEqualSlices(u8, value(i).slice(), (try tree.get(snapshot, key(i))).?.slice());
        root = try tree.remove(root, key(i));
    }
    try t.expectEqual(@as(?p.Reference, null), root);
    try t.expect((try tree.get(snapshot, key(0))) != null);
}

test "every staging fault leaves published root intact; missing or corrupt pages never mean empty" {
    var store: Store = .{};
    defer store.deinit();
    const tree: p.Tree(Store) = .{ .store = &store };
    var root: ?p.Reference = null;
    for (0..64) |i| root = try tree.put(root, key(i), value(i));
    for (0..32) |failure| {
        store.fail_at = store.writes + failure;
        _ = tree.put(root, key(64), value(64)) catch |err| {
            try t.expectEqual(error.StagingFailed, err);
            try t.expect((try tree.get(root, key(64))) == null);
            try t.expect((try tree.get(root, key(63))) != null);
            continue;
        };
        store.fail_at = null;
        break;
    } else return error.StagingEnumerationDidNotComplete;
    // The caller has still not published any of those candidate roots.
    try t.expect((try tree.get(root, key(64))) == null);
    store.missing = true;
    try t.expectError(error.PageUnavailable, tree.get(root, key(1)));
    store.missing = false;
    store.corrupt = true;
    try t.expectError(error.CorruptPage, tree.get(root, key(1)));
}

test "page codec is versioned, bounded and owns decoded values" {
    var page: p.Page = .{ .count = p.leaf_entries, .body = .{ .leaf = @splat(null) } };
    for (&page.body.leaf, 0..) |*slot, i| slot.* = .{ .key = key(i), .value = try p.Value.init(&@as([2048]u8, @splat(255))) };
    var bytes: [p.max_encoded_bytes]u8 = undefined;
    const encoded = try page.encode(&bytes);
    const decoded = try p.Page.decode(t.allocator, encoded);
    try t.expect(std.meta.eql(page, decoded));
    try t.expectEqualSlices(u8, &try page.reference(), &try decoded.reference());
    page.version += 1;
    try t.expectError(error.UnsupportedPageVersion, page.reference());
    page.version = p.version;
    page.body.leaf[1].?.key = page.body.leaf[0].?.key;
    try t.expectError(error.InvalidPage, page.reference());
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    var store: Store = .{ .allocator = allocator };
    defer store.deinit();
    const tree: p.Tree(Store) = .{ .store = &store };
    var root: ?p.Reference = null;
    for (0..8) |i| {
        const next = tree.put(root, key(i), value(i)) catch |err| {
            try t.expect((try tree.get(root, key(i))) == null);
            return err;
        };
        root = next;
    }
}
test "page staging allocation failures preserve the previously published root" {
    try t.checkAllAllocationFailures(t.allocator, allocationCase, .{});
}

test "permuted updates and deletion match a separate ordered map through churn" {
    var store: Store = .{};
    defer store.deinit();
    const tree: p.Tree(Store) = .{ .store = &store };
    var root: ?p.Reference = null;
    var model: [128]?usize = @splat(null);
    var random: u64 = 0x6e624eb7;
    for (0..1024) |step| {
        random ^= random << 13;
        random ^= random >> 7;
        random ^= random << 17;
        const index: usize = @intCast(random % model.len);
        if (random & 0x100 != 0) {
            root = try tree.put(root, key(index), value(step));
            model[index] = step;
        } else {
            root = try tree.remove(root, key(index));
            model[index] = null;
        }
        if (step % 31 != 0) continue;
        var cursor: ?p.Key = null;
        var expected: usize = 0;
        while (true) {
            const batch = try tree.scan(root, cursor);
            for (batch.entries) |slot| if (slot) |entry| {
                while (expected < model.len and model[expected] == null) expected += 1;
                try t.expect(expected < model.len);
                try t.expectEqualSlices(u8, key(expected).slice(), entry.key.slice());
                try t.expectEqualSlices(u8, value(model[expected].?).slice(), entry.value.slice());
                expected += 1;
            };
            cursor = batch.next;
            if (cursor == null) break;
        }
        while (expected < model.len and model[expected] == null) expected += 1;
        try t.expectEqual(model.len, expected);
    }
}

test "lost staging acknowledgements do not publish candidates and retry is idempotent" {
    var store: Store = .{};
    defer store.deinit();
    const tree: p.Tree(Store) = .{ .store = &store };
    var root: ?p.Reference = null;
    for (0..32) |i| root = try tree.put(root, key(i), value(i));
    store.lose_at = store.writes;
    try t.expectError(error.StagingAcknowledgementLost, tree.put(root, key(100), value(100)));
    try t.expect((try tree.get(root, key(100))) == null);
    store.lose_at = null;
    const candidate = try tree.put(root, key(100), value(100));
    const retried = try tree.put(root, key(100), value(100));
    try t.expectEqual(candidate, retried);
    try t.expect((try tree.get(root, key(100))) == null);
    try t.expectEqualSlices(u8, value(100).slice(), (try tree.get(candidate, key(100))).?.slice());
}
