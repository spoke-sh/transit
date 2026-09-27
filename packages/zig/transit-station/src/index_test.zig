const std = @import("std");
const t = std.testing;
const Index = @import("ImmutableIndex.zig");
const Pub = @import("Publication.zig");
const Store = struct {
    records: std.ArrayList([]const u8) = .empty,
    reads: usize = 0,
    max_read: usize = 0,
    denied: bool = false,
    fail_after: ?usize = null,
    fn deinit(self: *Store) void {
        for (self.records.items) |bytes| t.allocator.free(bytes);
        self.records.deinit(t.allocator);
    }
    pub fn load(self: *Store, ref: Index.Reference, buffer: []u8) ![]const u8 {
        if (self.denied) return error.AccessDenied;
        self.reads += 1;
        if (ref.id == 0 or ref.id > self.records.items.len) return error.IndexGap;
        const bytes = self.records.items[@intCast(ref.id - 1)];
        self.max_read = @max(self.max_read, bytes.len);
        if (bytes.len > buffer.len) return error.IndexGap;
        @memcpy(buffer[0..bytes.len], bytes);
        return buffer[0..bytes.len];
    }
    pub fn save(self: *Store, spec: Pub.Spec, bytes: []const u8) !u64 {
        if (self.fail_after) |limit| if (self.records.items.len >= limit) return error.StorageUnavailable;
        try t.expectEqualDeep(try Pub.Digest.of(Index.format, bytes), spec);
        const owned = try t.allocator.dupe(u8, bytes);
        errdefer t.allocator.free(owned);
        try self.records.append(t.allocator, owned);
        return self.records.items.len;
    }
};
fn key(number: u64) !Index.Key {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, number, .big);
    return Index.Key.init(&bytes);
}
fn value(number: u64) !Index.Value {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, number, .little);
    return Index.Value.init(&bytes);
}

test "immutable index preserves old roots and sorted pages through permuted inserts and replacements" {
    var store: Store = .{};
    defer store.deinit();
    var tree: Index = .{};
    try t.expectEqual(null, try tree.next(&store, null));
    // Permutation covers every key without ever needing all keys in the library.
    for (0..1024) |i| tree = try tree.put(&store, try key((i * 541) % 1024), try value(i));
    const original = tree;
    const retained_records = store.records.items.len;
    for (0..1024) |i| tree = try tree.put(&store, try key(i), try value(i + 10000));
    try t.expectEqual(@as(u64, 1024), tree.root.?.entries);
    try t.expect(store.records.items.len > retained_records);
    var after: ?Index.Key = null;
    for (0..1024) |i| {
        store.reads = 0;
        const entry = (try tree.next(&store, after)).?;
        try t.expect(Index.Key.eql(try key(i), entry.key));
        try t.expect(Index.Value.eql(try value(i + 10000), entry.value));
        try t.expect(store.reads <= 2 * (@as(usize, tree.root.?.level) + 1));
        after = entry.key;
        const before = (try original.get(&store, try key(i))).?;
        const source_number = std.mem.readInt(u64, before.data[0..8], .little);
        try t.expectEqual(i, (source_number * 541) % 1024);
    }
    try t.expectEqual(null, try tree.next(&store, after));
    try t.expectEqual(null, try tree.get(&store, try key(2000)));
    const count = store.records.items.len;
    const duplicate = try tree.put(&store, try key(10), try value(10010));
    try t.expectEqual(tree.root.?.id, duplicate.root.?.id);
    try t.expectEqual(count, store.records.items.len);
    try t.expect(store.max_read <= Index.node_bytes);
    store.denied = true;
    try t.expectError(error.AccessDenied, tree.get(&store, try key(10)));
    try t.expectError(error.AccessDenied, tree.next(&store, null));
}

test "failed path copying leaves accepted root intact and corrupted nodes fail closed" {
    var store: Store = .{};
    defer store.deinit();
    var tree: Index = .{};
    for (0..80) |i| tree = try tree.put(&store, try key(i), try value(i));
    const records = store.records.items.len;
    store.fail_after = records + 1; // One candidate leaf is stored; parent publication fails.
    try t.expectError(error.StorageUnavailable, tree.put(&store, try key(30), try value(1000)));
    try t.expect(Index.Value.eql(try value(30), (try tree.get(&store, try key(30))).?));
    store.fail_after = null;
    const changed = try tree.put(&store, try key(30), try value(1000));
    try t.expect(Index.Value.eql(try value(1000), (try changed.get(&store, try key(30))).?));
    var false_root = tree;
    false_root.root.?.entries += 1;
    try t.expectError(error.InvalidIndexReference, false_root.get(&store, try key(30)));
    const bytes = @constCast(store.records.items[@intCast(tree.root.?.id - 1)]);
    bytes[bytes.len - 1] ^= 1;
    try t.expectError(error.InvalidIndexCommitment, tree.next(&store, null));
}

test "full width keys and maximum values fit bounded nodes" {
    var store: Store = .{};
    defer store.deinit();
    var tree: Index = .{};
    for (0..100) |i| {
        var bytes: [128]u8 = @splat(0xff);
        bytes[0] = @intCast(i);
        tree = try tree.put(&store, try Index.Key.init(&bytes), try Index.Value.init(&@as([256]u8, @splat(@intCast(i)))));
    }
    try t.expectEqual(@as(u64, 100), tree.root.?.entries);
    try t.expect(store.max_read <= 4096);
}

const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig").Growing;
const Turns = struct {
    state: std.AutoHashMapUnmanaged(p.Value, p.Value) = .empty,
    revision: u64 = 1,
    input: u64 = 1,
    denied: bool = false,
    fn deinit(self: *Turns) void {
        self.state.deinit(t.allocator);
    }
    fn read(raw: *anyopaque, _: p.Growth.View, address: p.Value) !?p.Value {
        const self: *Turns = @ptrCast(@alignCast(raw));
        if (self.denied) return error.AccessDenied;
        return self.state.get(address);
    }
    fn capture(self: *Turns) !Turn {
        self.input += 1;
        return Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 2, .principal = 65536, .generation = 3, .input = self.input, .process_revision = self.revision, .resource = 7, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read });
    }
    fn commit(self: *Turns, turn: Turn) !void {
        try turn.validate();
        for (turn.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |bytes| try self.state.put(t.allocator, mutation.key, bytes) else _ = self.state.remove(mutation.key);
        };
        self.revision += 1;
    }
};
test "index candidates resume one publication operation per turn without changing accepted roots" {
    var store: Turns = .{};
    defer store.deinit();
    var turn = try store.capture();
    const publication = try Pub.create(&turn, 1, .{ .record_bytes = Index.node_bytes, .staging_bytes = Index.node_bytes, .staging_records = 1 });
    try store.commit(turn);
    var tree: Index = .{};
    var next_id: u64 = 1;
    for (0..24) |i| {
        const previous = tree;
        for (0..256) |_| {
            turn = try store.capture();
            var staging: Index.Staging = .{ .turn = &turn, .publication = publication, .next_id = next_id, .end_id = next_id + 128 };
            tree = previous.put(&staging, try key(i), try value(i)) catch |err| {
                if (err != error.IndexStaging) return err;
                try store.commit(turn);
                var visible = try store.capture();
                var reader: Index.Reader(*Turn) = .{ .publication = publication, .source = &visible };
                try t.expectEqual(null, try previous.get(&reader, try key(i)));
                continue;
            };
            next_id = staging.next_id;
            // A consumer may now bind this exact root in its final accepted head.
            try t.expectEqual(@as(u32, 0), (try publication.budget(&turn)).records);
            break;
        } else return error.IndexDidNotFinish;
    }
    turn = try store.capture();
    var reader: Index.Reader(*Turn) = .{ .publication = publication, .source = &turn };
    try t.expectEqual(@as(u64, 24), tree.root.?.entries);
    for (0..24) |i| try t.expect(Index.Value.eql(try value(i), (try tree.get(&reader, try key(i))).?));
    const original = tree;
    var staging: Index.Staging = .{ .turn = &turn, .publication = publication, .next_id = next_id, .end_id = next_id + 128 };
    try t.expectError(error.IndexStaging, original.put(&staging, try key(5), try value(900)));
    try store.commit(turn);
    turn = try store.capture();
    staging.turn = &turn;
    staging.next_id = next_id;
    try t.expectError(error.IndexCandidateChanged, original.put(&staging, try key(5), try value(901)));
    for (turn.decision.mutations) |mutation| try t.expectEqual(null, mutation);
    reader.source = &turn;
    try t.expect(Index.Value.eql(try value(5), (try original.get(&reader, try key(5))).?));
    store.denied = true;
    try t.expectError(error.AccessDenied, original.next(&reader, null));
}
