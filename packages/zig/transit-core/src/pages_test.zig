const std = @import("std");
const t = std.testing;
const p = @import("pages.zig");

pub const Store = struct {
    allocator: std.mem.Allocator = t.allocator,
    pages: std.AutoHashMapUnmanaged(p.Reference, p.Page) = .empty,
    writes: usize = 0,
    reads: usize = 0,
    fail_at: ?usize = null,
    lose_at: ?usize = null,
    missing: bool = false,
    corrupt: bool = false,
    missing_at: ?usize = null,
    pub fn stage(self: *Store, ref: p.Reference, page: *const p.Page) !p.Reference {
        if (self.fail_at == self.writes) return error.StagingFailed;
        self.writes += 1;
        if (!self.pages.contains(ref)) try self.pages.put(self.allocator, ref, page.*);
        if (self.lose_at == self.writes - 1) return error.StagingAcknowledgementLost;
        return ref;
    }
    pub fn load(self: *Store, ref: p.Reference) !p.Page {
        const unavailable = self.missing_at == self.reads;
        self.reads += 1;
        if (self.missing or unavailable) return error.PageUnavailable;
        if (self.pages.getPtr(ref)) |item| {
            var result = item.*;
            if (self.corrupt) switch (result.body) {
                .leaf => result.body.leaf[0].?.value.data[0] ^= 1,
                .branch => result.body.branch[0].?.reference.digest[0] ^= 1,
            };
            return result;
        }
        return error.PageUnavailable;
    }
    pub fn deinit(self: *Store) void {
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

test "independent leaf rewrites share bounded batches without publishing partial locators" {
    const Batched = struct {
        inner: Store = .{},
        batches: usize = 0,
        singles: usize = 0,
        largest: usize = 0,
        pub fn load(self: *@This(), ref: p.Reference) !p.Page {
            return self.inner.load(ref);
        }
        pub fn stage(self: *@This(), ref: p.Reference, page: *const p.Page) !p.Reference {
            self.singles += 1;
            return self.locate(ref, page);
        }
        fn locate(self: *@This(), ref: p.Reference, page: *const p.Page) !p.Reference {
            var located = ref;
            std.mem.writeInt(u64, located.location[0..8], self.inner.writes + 1, .big);
            return self.inner.stage(located, page);
        }
        pub fn stageMany(self: *@This(), batch: []const p.Page, output: []p.Reference) !void {
            try t.expect(batch.len <= p.mutation_batch);
            self.batches += 1;
            self.largest = @max(self.largest, batch.len);
            for (batch, output) |*page, *reference| reference.* = try self.locate(try page.reference(), page);
        }
    };
    var store: Batched = .{};
    defer store.inner.deinit();
    const tree: p.Tree(Batched) = .{ .store = &store };
    var root: ?p.Reference = null;
    for (0..64) |i| root = try tree.put(root, key(i), value(i));
    var mutations: [p.mutation_batch]p.Mutation = undefined;
    for (&mutations, 0..) |*mutation, i| mutation.* = .{ .key = key(i * 8), .value = value(1000 + i) };
    store.singles = 0;
    const before = store.inner.writes;
    const next = try tree.mutate(root, &mutations);
    try t.expectEqual(@as(usize, 1), store.batches);
    try t.expectEqual(@as(usize, 1), store.singles);
    try t.expectEqual(p.mutation_batch, store.largest);
    const staged = store.inner.writes - before;
    for (0..64) |i| {
        try t.expectEqualDeep(value(i), (try tree.get(root, key(i))).?);
        try t.expectEqualDeep(value(if (i % 8 == 0) 1000 + i / 8 else i), (try tree.get(next, key(i))).?);
    }
    // Every accepted-but-lost batch frame and parent acknowledgement fails the
    // candidate. The original root retains its exact values and references.
    for (0..staged) |offset| {
        store.inner.lose_at = store.inner.writes + offset;
        try t.expectError(error.StagingAcknowledgementLost, tree.mutate(root, &mutations));
        store.inner.lose_at = null;
        for (0..64) |i| try t.expectEqualDeep(value(i), (try tree.get(root, key(i))).?);
    }
}

test "bounded point batches share paths and preserve input order, absence and failure" {
    var store: Store = .{};
    defer store.deinit();
    const tree: p.Tree(Store) = .{ .store = &store };
    var root: ?p.Reference = null;
    for (0..257) |i| root = try tree.put(root, key(i * 2), value(i));
    const indices = [_]usize{ 130, 129, 128, 136, 134, 133, 132, 138 };
    var keys: [p.page_entries]p.Key = undefined;
    var expected: [p.page_entries]?p.Value = @splat(null);
    for (indices, 0..) |index, i| {
        keys[i] = key(index);
        if (index % 2 == 0) expected[i] = value(index / 2);
    }
    store.reads = 0;
    for (keys, expected) |k, v| try t.expectEqualDeep(v, try tree.get(root, k));
    const separate_reads = store.reads;
    store.reads = 0;
    const writes = store.writes;
    try t.expectEqualDeep(expected, try tree.getMany(root, &keys));
    const shared_reads = store.reads;
    try t.expect(shared_reads < separate_reads);
    try t.expectEqual(writes, store.writes);
    for (0..shared_reads) |offset| {
        store.missing_at = store.reads + offset;
        try t.expectError(error.PageUnavailable, tree.getMany(root, &keys));
    }
    store.missing_at = null;
    store.corrupt = true;
    try t.expectError(error.CorruptPage, tree.getMany(root, &keys));
    store.corrupt = false;
    const reads = store.reads;
    const empty: [p.page_entries]?p.Value = @splat(null);
    try t.expectEqualDeep(empty, try tree.getMany(root, &.{}));
    try t.expectEqualDeep(empty, try tree.getMany(null, &keys));
    const oversized: [p.page_entries + 1]p.Key = @splat(key(0));
    try t.expectError(error.PageReadBudget, tree.getMany(root, &oversized));
    var malformed = keys;
    malformed[3].data[malformed[3].len] = 1;
    try t.expectError(error.InvalidPageValue, tree.getMany(root, &malformed));
    try t.expectEqual(reads, store.reads);
    // Distinct native keys are validated above the tree. The reusable primitive
    // also resolves repeated requests consistently without loading a path twice.
    const repeated = try tree.getMany(root, &.{ key(8), key(8) });
    try t.expectEqualDeep(value(4), repeated[0].?);
    try t.expectEqualDeep(repeated[0], repeated[1]);
    const next = try tree.put(root, key(130), value(999));
    try t.expectEqualDeep(expected, try tree.getMany(root, &keys));
    try t.expectEqualDeep(value(999), (try tree.getMany(next, &keys))[0].?);
}

test "descending bounded mutations retain shallow lookup paths and old roots" {
    for ([_]usize{ 1, 4, 8 }) |batch_size| {
        var store: Store = .{};
        defer store.deinit();
        const tree: p.Tree(Store) = .{ .store = &store };
        var root: ?p.Reference = null;
        var remaining: usize = 257;
        while (remaining > 0) {
            const count = @min(batch_size, remaining);
            var changes: [p.mutation_batch]p.Mutation = undefined;
            for (changes[0..count], 0..) |*change, i| {
                const index = remaining - i - 1;
                change.* = .{ .key = key(index), .value = value(index) };
            }
            const previous = root;
            root = try tree.mutate(root, changes[0..count]);
            try t.expect((try tree.get(previous, key(remaining - 1))) == null);
            remaining -= count;
        }
        // A 257-key insertion-only tree must not approach the 32-level address
        // guard. This generous bound permits half-full binary branching.
        for (0..257) |i| {
            store.reads = 0;
            const found = (try tree.get(root, key(i))).?;
            try t.expectEqualSlices(u8, value(i).slice(), found.slice());
            try t.expect(store.reads <= 9);
        }
        var cursor: ?p.Key = null;
        var expected: usize = 0;
        while (true) {
            const batch = try tree.scan(root, cursor);
            for (batch.entries) |slot| if (slot) |entry| {
                try t.expectEqualSlices(u8, key(expected).slice(), entry.key.slice());
                try t.expectEqualSlices(u8, value(expected).slice(), entry.value.slice());
                expected += 1;
            };
            cursor = batch.next;
            if (cursor == null) break;
        }
        try t.expectEqual(257, expected);
    }
}

fn thinChild(store: *Store, index: usize, height: u8) !p.Child {
    var page: p.Page = .{ .count = 1, .body = .{ .leaf = @splat(null) } };
    page.body.leaf[0] = .{ .key = key(index), .value = value(index) };
    var child: p.Child = .{ .minimum = key(index), .reference = try store.stage(try page.reference(), &page) };
    for (0..height) |level| {
        page = .{ .height = @intCast(level + 1), .count = 1, .body = .{ .branch = @splat(null) } };
        page.body.branch[0] = child;
        child.reference = try store.stage(try page.reference(), &page);
    }
    return child;
}

test "mutations continue from a sparse root at the height guard without replacing old cuts" {
    var store: Store = .{};
    defer store.deinit();
    const tree: p.Tree(Store) = .{ .store = &store };
    var page: p.Page = .{ .count = p.leaf_entries, .body = .{ .leaf = @splat(null) } };
    for (&page.body.leaf, 0..) |*slot, i| slot.* = .{ .key = key(1024 + i), .value = value(1024 + i) };
    var root: p.Child = .{ .minimum = key(1024), .reference = try store.stage(try page.reference(), &page) };
    var next_key: usize = 1024 + p.leaf_entries;
    // A valid persisted shape produced by repeatedly filling the left split:
    // a full spine, with sparse same-height siblings. No obsolete codec or
    // alternate implementation is needed to construct this current-v1 root.
    for (0..p.max_height) |level| {
        var children: [p.branch_children]?p.Child = @splat(null);
        children[0] = root;
        for (children[1..]) |*child| {
            child.* = try thinChild(&store, next_key, @intCast(level));
            next_key += 1;
        }
        page = .{ .height = @intCast(level + 1), .count = p.branch_children, .body = .{ .branch = children } };
        root.reference = try store.stage(try page.reference(), &page);
    }
    const retained = root.reference;
    var keys: [p.page_entries]p.Key = undefined;
    var expected: [p.page_entries]?p.Value = @splat(null);
    for (&keys, 0..) |*k, i| {
        const index = 1024 + keys.len - i - 1;
        k.* = key(index);
        expected[i] = value(index);
    }
    store.reads = 0;
    for (keys, expected) |k, v| try t.expectEqualDeep(v, try tree.get(retained, k));
    const separate_reads = store.reads;
    store.reads = 0;
    try t.expectEqualDeep(expected, try tree.getMany(retained, &keys));
    try t.expect(store.reads <= p.max_height + keys.len);
    try t.expect(store.reads < separate_reads);
    std.debug.print("Depth-32 point batch: {d} separate loads, {d} shared loads for eight keys.\n", .{ separate_reads, store.reads });
    const first = [_]p.Mutation{.{ .key = key(1023), .value = value(1023) }};
    const before = store.writes;
    _ = try tree.mutate(retained, &first);
    const stages = store.writes - before;
    for (0..stages) |offset| for (0..2) |kind| {
        store.fail_at = if (kind == 0) store.writes + offset else null;
        store.lose_at = if (kind == 1) store.writes + offset else null;
        if (kind == 0) {
            try t.expectError(error.StagingFailed, tree.mutate(retained, &first));
        } else {
            try t.expectError(error.StagingAcknowledgementLost, tree.mutate(retained, &first));
        }
        store.fail_at = null;
        store.lose_at = null;
        try t.expect((try tree.get(retained, key(1023))) == null);
        try t.expectEqualSlices(u8, value(1024).slice(), (try tree.get(retained, key(1024))).?.slice());
    };
    var current: ?p.Reference = retained;
    for (0..64) |i| {
        const index = 1023 - i;
        current = try tree.mutate(current, &.{.{ .key = key(index), .value = value(index) }});
        try t.expect((try tree.get(retained, key(index))) == null);
    }
    for (960..next_key) |i| {
        const found = (try tree.get(current, key(i))).?;
        try t.expectEqualSlices(u8, value(i).slice(), found.slice());
        if (i >= 1024) try t.expectEqualSlices(u8, value(i).slice(), (try tree.get(retained, key(i))).?.slice());
    }
}

test "bounded tree ranges stop at the exclusive end and avoid unrelated leaves" {
    var store: Store = .{};
    defer store.deinit();
    const tree: p.Tree(Store) = .{ .store = &store };
    var root: ?p.Reference = null;
    for (0..256) |i| root = try tree.put(root, key(i), value(i));
    store.reads = 0;
    const short = try tree.scanRange(root, key(30), true, key(31));
    const bounded_reads = store.reads;
    try t.expect(short.entries[0].?.key.len != 0 and short.entries[1] == null and short.next == null);
    try t.expectEqualSlices(u8, key(30).slice(), short.entries[0].?.key.slice());
    store.reads = 0;
    _ = try tree.scanFrom(root, key(30));
    try t.expect(bounded_reads < store.reads);
    const empty = try tree.scanRange(root, key(30), false, key(31));
    try t.expect(empty.entries[0] == null and empty.next == null);
    const full = try tree.scanRange(root, key(30), true, key(38));
    try t.expect(full.entries[7] != null and full.next == null);
    const more = try tree.scanRange(root, key(30), true, key(39));
    try t.expectEqualSlices(u8, key(37).slice(), more.next.?.slice());
    try t.expectError(error.InvalidPageRange, tree.scanRange(root, key(31), true, key(30)));
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
    try t.expect(std.meta.eql(try page.reference(), try decoded.reference()));
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

test "bounded mutations match an independent map and retain every old cut" {
    var store: Store = .{};
    defer store.deinit();
    const tree: p.Tree(Store) = .{ .store = &store };
    var root: ?p.Reference = null;
    var expected: [257]?usize = @splat(null);
    for (0..160) |round| {
        const previous = root;
        const before = expected;
        var mutations: [p.mutation_batch]p.Mutation = undefined;
        for (&mutations, 0..) |*mutation, i| {
            // Prime modulus gives distinct, deliberately unordered keys per batch.
            const index = (round * 47 + i * 31) % expected.len;
            expected[index] = if ((round + i) % 3 == 0) null else round * 8 + i;
            mutation.* = .{ .key = key(index), .value = if (expected[index]) |n| value(n) else null };
        }
        root = try tree.mutate(root, &mutations);
        for (expected, before, 0..) |now, old, i| {
            const current = try tree.get(root, key(i));
            const retained = try tree.get(previous, key(i));
            if (now) |n| try t.expectEqualSlices(u8, value(n).slice(), current.?.slice()) else try t.expect(current == null);
            if (old) |n| try t.expectEqualSlices(u8, value(n).slice(), retained.?.slice()) else try t.expect(retained == null);
        }
    }
    // Deletion collapses all levels, including missing keys, back to an empty root.
    for (0..33) |batch| {
        var mutations: [p.mutation_batch]p.Mutation = undefined;
        const count = @min(mutations.len, expected.len - batch * mutations.len);
        for (mutations[0..count], 0..) |*mutation, i| mutation.* = .{ .key = key(batch * mutations.len + i), .value = null };
        root = try tree.mutate(root, mutations[0..count]);
    }
    try t.expect(root == null);
}

test "batch validation and every staging failure leave the published root intact" {
    var store: Store = .{};
    defer store.deinit();
    const tree: p.Tree(Store) = .{ .store = &store };
    var root: ?p.Reference = null;
    for (0..64) |i| root = try tree.put(root, key(i), value(i));
    var mutations: [p.mutation_batch]p.Mutation = undefined;
    for (&mutations, 0..) |*mutation, i| mutation.* = .{ .key = key(i + 8), .value = value(i + 100) };
    const writes = store.writes;
    _ = try tree.mutate(root, &mutations);
    const staged = store.writes - writes;
    const sequential = store.writes;
    var separate = root;
    for (mutations) |mutation| separate = try tree.put(separate, mutation.key, mutation.value.?);
    try t.expect(staged < store.writes - sequential);
    for (0..staged) |failure| {
        for (0..2) |kind| {
            if (kind == 0) store.fail_at = store.writes + failure else store.lose_at = store.writes + failure;
            if (kind == 0) try t.expectError(error.StagingFailed, tree.mutate(root, &mutations)) else try t.expectError(error.StagingAcknowledgementLost, tree.mutate(root, &mutations));
            store.fail_at = null;
            store.lose_at = null;
            for (0..64) |i| try t.expectEqualSlices(u8, value(i).slice(), (try tree.get(root, key(i))).?.slice());
        }
    }
    const before = store.writes;
    try t.expectError(error.DuplicatePageMutation, tree.mutate(root, &.{ mutations[0], mutations[0] }));
    const excessive: [p.mutation_batch + 1]p.Mutation = @splat(mutations[0]);
    try t.expectError(error.PageMutationBudget, tree.mutate(root, &excessive));
    const unchanged = try tree.mutate(root, &.{ .{ .key = key(3), .value = value(3) }, .{ .key = key(999), .value = null } });
    try t.expectEqualDeep(root, unchanged);
    try t.expectEqual(before, store.writes);
}

test "compact pages reject truncation, trailing bytes, old JSON and noncanonical structure" {
    const page: p.Page = .{ .count = 1, .body = .{ .leaf = leaf: {
        var entries: [p.leaf_entries]?p.Entry = @splat(null);
        entries[0] = .{ .key = key(1), .value = value(2) };
        break :leaf entries;
    } } };
    var buffer: [p.max_encoded_bytes]u8 = undefined;
    const encoded = try page.encode(&buffer);
    try t.expectEqualStrings("TPG1", encoded[0..4]);
    for (0..encoded.len) |length| try t.expectError(error.InvalidPage, p.Page.decode(t.allocator, encoded[0..length]));
    buffer[encoded.len] = 0;
    try t.expectError(error.InvalidPage, p.Page.decode(t.allocator, buffer[0 .. encoded.len + 1]));
    const old = try std.json.Stringify.valueAlloc(t.allocator, page, .{});
    defer t.allocator.free(old);
    try t.expectError(error.InvalidPage, p.Page.decode(t.allocator, old));
    buffer[3] = '2';
    try t.expectError(error.InvalidPage, p.Page.decode(t.allocator, encoded));
    buffer[3] = '1';
    buffer[5] = 0;
    try t.expectError(error.InvalidPage, p.Page.decode(t.allocator, encoded));
    buffer[5] = 1;
    buffer[6] = 65; // Key length exceeds its owned representation.
    try t.expectError(error.InvalidPage, p.Page.decode(t.allocator, encoded));
    // Every maximal branch and leaf remains below the unchanged 24 KiB bound.
    var branch: p.Page = .{ .height = 1, .count = p.branch_children, .body = .{ .branch = @splat(null) } };
    for (&branch.body.branch, 0..) |*slot, i| slot.* = .{ .minimum = key(i), .reference = try page.reference() };
    const branch_bytes = try branch.encode(&buffer);
    try t.expectEqualDeep(branch, try p.Page.decode(t.allocator, branch_bytes));
    buffer[4] = 0; // A branch cannot be reinterpreted as leaf bytes.
    try t.expectError(error.InvalidPage, p.Page.decode(t.allocator, branch_bytes));
}

test "complete candidate at maximum height keeps leaf workspace off recursive frames" {
    var store: Store = .{};
    defer store.deinit();
    const tree: p.BoundedTree(Store, @import("catalog.zig").Candidate.capacity) = .{ .store = &store };
    var root = try tree.put(null, key(1), value(1));
    for (1..p.max_height + 1) |height| {
        var page: p.Page = .{ .height = @intCast(height), .count = 1, .body = .{ .branch = @splat(null) } };
        page.body.branch[0] = .{ .minimum = key(1), .reference = root };
        root = try store.stage(try page.reference(), &page);
    }
    const changed = try tree.mutate(root, &.{.{ .key = key(1), .value = value(2) }});
    try t.expectEqualDeep(value(1), (try tree.get(root, key(1))).?);
    try t.expectEqualDeep(value(2), (try tree.get(changed, key(1))).?);
}
