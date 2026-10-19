const std = @import("std");
const t = std.testing;
const core = @import("root.zig");
const b = core.protocol.Blocks;
const blocks = core.blocks;

pub const Store = struct {
    pages: @import("pages_test.zig").Store = .{},
    values: std.AutoHashMapUnmanaged(blocks.Reference, []const u8) = .empty,
    writes: usize = 0,
    fail_at: ?usize = null,
    lose_at: ?usize = null,
    missing: bool = false,
    corrupt: bool = false,
    pub fn deinit(self: *Store) void {
        var values = self.values.valueIterator();
        while (values.next()) |bytes| t.allocator.free(bytes.*);
        self.values.deinit(t.allocator);
        self.pages.deinit();
    }
    pub fn stage(self: *Store, reference: core.pages.Reference, page: *const core.pages.Page) !core.pages.Reference {
        return self.pages.stage(reference, page);
    }
    pub fn load(self: *Store, reference: core.pages.Reference) !core.pages.Page {
        return self.pages.load(reference);
    }
    pub fn stageBlock(self: *Store, spec: b.Spec, bytes: []const u8) !blocks.Reference {
        try spec.verify(bytes);
        if (self.fail_at == self.writes) return error.StagingFailed;
        const reference: blocks.Reference = .{ .value = spec, .location = spec.digest };
        if (!self.values.contains(reference)) {
            const owned = try t.allocator.dupe(u8, bytes);
            errdefer t.allocator.free(owned);
            try self.values.put(t.allocator, reference, owned);
        }
        self.writes += 1;
        if (self.lose_at == self.writes - 1) return error.StagingAcknowledgementLost;
        return reference;
    }
    pub fn loadBlock(self: *Store, reference: blocks.Reference, output: []u8) ![]const u8 {
        if (self.missing) return error.BlockUnavailable;
        const bytes = self.values.get(reference) orelse return error.BlockUnavailable;
        if (output.len < bytes.len) return error.BlockBufferTooSmall;
        @memcpy(output[0..bytes.len], bytes);
        if (self.corrupt and bytes.len != 0) output[0] ^= 1;
        return output[0..bytes.len];
    }
};

test "block roots retain independent old values beyond inline and turn-mutation limits" {
    var store: Store = .{};
    defer store.deinit();
    const index: blocks.Index(Store) = .{ .store = &store };
    var batch: b.Batch = .{};
    const first: [32768]u8 = @splat(17);
    const second: [65536]u8 = @splat(29);
    try batch.put(try .init("a"), &first);
    try batch.put(try .init("b"), &second);
    for (0..10) |i| {
        var key: [8]u8 = undefined;
        std.mem.writeInt(u64, &key, i, .big);
        try batch.put(try .init(&key), "small");
    }
    const old = try index.publish(.{}, batch.mutations, &batch.body, 1);
    try t.expectEqual(12, old.records);
    var changed: b.Batch = .{};
    try changed.put(try .init("a"), null);
    try changed.put(try .init("b"), "replacement");
    const next = try index.publish(old, changed.mutations, &changed.body, 2);
    try t.expectEqual(11, next.records);
    const keys: [core.protocol.Growth.page_size]?core.Value = .{ try .init("a"), null, try .init("b"), null, null, null, null, null };
    var body: b.Body = .{};
    const retained = try index.read(old, keys, &body);
    try t.expectEqual(1, retained[0].?.revision);
    try t.expectEqual(null, retained[1]);
    try t.expectEqualSlices(u8, &first, body.slice()[0..first.len]);
    try t.expectEqualSlices(u8, &second, body.slice()[first.len..]);
    const current = try index.read(next, keys, &body);
    try t.expectEqual(null, current[0]);
    try t.expectEqual(2, current[2].?.revision);
    try t.expectEqualStrings("replacement", body.slice());
    // Sharing a root establishes independent logical ownership. This fixture
    // has no physical collector and does not claim a reclamation result.
    const independently_owned = old;
    const again = try index.read(independently_owned, keys, &body);
    try t.expectEqualDeep(retained, again);
    try t.expectEqual(first.len + second.len, body.len);
    var after: ?core.Value = null;
    var count: usize = 0;
    while (true) {
        const page = try index.scan(next, after);
        for (page.entries) |entry| if (entry != null) {
            count += 1;
        };
        after = page.next orelse break;
    }
    try t.expectEqual(11, count);
}

test "block and page acknowledgement failures never return a partial root" {
    var store: Store = .{};
    defer store.deinit();
    const index: blocks.Index(Store) = .{ .store = &store };
    var initial: b.Batch = .{};
    try initial.put(try .init("a"), "old");
    const old = try index.publish(.{}, initial.mutations, &initial.body, 1);
    var change: b.Batch = .{};
    try change.put(try .init("a"), "new");
    try change.put(try .init("b"), "other");
    for (0..2) |offset| {
        store.fail_at = store.writes + offset;
        try t.expectError(error.StagingFailed, index.publish(old, change.mutations, &change.body, 2));
        store.fail_at = null;
        store.lose_at = store.writes + offset;
        try t.expectError(error.StagingAcknowledgementLost, index.publish(old, change.mutations, &change.body, 2));
        store.lose_at = null;
    }
    store.pages.lose_at = store.pages.writes;
    try t.expectError(error.StagingAcknowledgementLost, index.publish(old, change.mutations, &change.body, 2));
    store.pages.lose_at = null;
    var body: b.Body = .{};
    const keys: [core.protocol.Growth.page_size]?core.Value = .{ try .init("a"), try .init("b"), null, null, null, null, null, null };
    const read = try index.read(old, keys, &body);
    try t.expectEqual(1, read[0].?.revision);
    try t.expectEqual(null, read[1]);
    try t.expectEqualStrings("old", body.slice());
    store.pages.missing = true;
    try t.expectError(error.PageUnavailable, index.read(old, keys, &body));
    try t.expectEqual(0, body.len);
    try body.validate();
    store.pages.missing = false;
    store.corrupt = true;
    try t.expectError(error.CorruptBlock, index.read(old, keys, &body));
    try t.expectEqual(0, body.len);
    try body.validate();
    store.corrupt = false;
    store.missing = true;
    try t.expectError(error.BlockUnavailable, index.read(old, keys, &body));
    try t.expectEqual(0, body.len);
    const writes = store.writes;
    change.body.data[0] ^= 1;
    try t.expectError(error.CorruptBlock, index.publish(old, change.mutations, &change.body, 2));
    try t.expectEqual(writes, store.writes);
}
