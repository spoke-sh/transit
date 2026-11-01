const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const Candidates = @import("CandidateObjects.zig");
fn put(store: s.TransitObjectStore.ObjectStore, name: []const u8, value: []const u8) !void {
    _ = try store.putImmutable(name, value, s.LogBatch.content(value).sha256);
}

test "candidate objects reuse bounded storage and resolve full keys without backend writes" {
    var base = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer base.deinit();
    try put(base.objectStore(), "base", "accepted");
    var failing = t.FailingAllocator.init(t.allocator, .{});
    var candidates = try Candidates.init(failing.allocator(), base.objectStore(), .{ .bytes = 1024, .objects = 4, .resident_bytes = 2048 });
    defer candidates.deinit();
    const allocations = failing.alloc_index;
    failing.fail_index = allocations;
    const first_name = "key-0";
    var second_buffer: [32]u8 = undefined;
    var second_name: []const u8 = undefined;
    const bucket = std.hash.Wyhash.hash(0, first_name) & (candidates.slots.len - 1);
    for (1..256) |number| {
        second_name = try std.fmt.bufPrint(&second_buffer, "key-{d}", .{number});
        if (std.hash.Wyhash.hash(0, second_name) & (candidates.slots.len - 1) == bucket) break;
    } else return error.TestExpectedCollision;
    var output: [32]u8 = undefined;
    for (0..64) |_| {
        try candidates.reset(base.objectStore());
        const store = candidates.objectStore();
        try put(store, first_name, "first");
        try put(store, second_name, "second");
        try t.expectError(error.InvalidCandidateObjectBase, candidates.reset(store));
        try t.expectEqualStrings("first", try store.getRange(first_name, 0, 5, &output));
        try t.expectEqualStrings("cond", try store.getRange(second_name, 2, 4, &output));
        try t.expectEqualStrings("accepted", try store.getRange("base", 0, 8, &output));
        try t.expectEqual(@as(u64, 5), (try store.getObject(first_name, &output)).?.size);
        try t.expectEqualStrings("first", output[0..5]);
        try t.expectEqual(@as(u64, 8), (try store.getObject("base", &output)).?.size);
        try t.expectEqualStrings("accepted", output[0..8]);
        try t.expectError(error.BufferTooSmall, store.getObject(first_name, output[0..1]));
        try t.expect(try store.getObject("absent", &output) == null);
        try t.expect(try base.objectStore().head(first_name) == null);
        const used = candidates.used;
        try put(store, first_name, "first");
        try t.expectEqual(used, candidates.used);
        try t.expectError(error.ImmutableObjectConflict, put(store, first_name, "changed"));
        const oversized: [1024]u8 = @splat(1);
        try t.expectError(error.CandidateObjectBudgetExceeded, put(store, "oversized", &oversized));
        try t.expectEqual(used, candidates.used);
        try put(store, "third", "3");
        try put(store, "fourth", "4");
        try t.expectError(error.CandidateObjectBudgetExceeded, put(store, "fifth", "5"));
        try t.expectError(error.CandidateMutationUnsupported, store.delete("base"));
        try t.expectError(error.CandidateMutationUnsupported, store.putConditional("base", .if_none_match, "changed"));
        try t.expectError(error.InvalidObjectRange, store.getRange(first_name, 6, 1, &output));
        try t.expectEqual(@as(usize, 0), (try store.getRange(first_name, 5, 1, &output)).len);
    }
    try t.expectEqual(allocations, failing.alloc_index);
    try t.expect(candidates.residentBytes() <= 2048);
    try candidates.persist();
    try t.expectEqualStrings("second", try base.objectStore().getRange(second_name, 0, 6, &output));
    try candidates.reset(base.objectStore());
    try t.expectEqualStrings("first", try candidates.objectStore().getRange(first_name, 0, 5, &output));
}

fn derive(store: *s.TreeStore) !s.TreeStore.pages.Reference {
    const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = store };
    try store.begin(1024 * 1024);
    defer store.end();
    var root: ?s.TreeStore.pages.Reference = null;
    for (0..40) |offset| root = try tree.put(root, try s.LogPartitionRecord.integerKey(offset), try s.TreeStore.pages.Value.init("value"));
    return root.?;
}

test "candidate objects derive identical paged roots without intermediate disk objects" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var base = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer base.deinit();
    var candidates = try Candidates.init(t.allocator, base.objectStore(), .{ .bytes = 1024 * 1024, .objects = 1024, .resident_bytes = 2 * 1024 * 1024 });
    defer candidates.deinit();
    var store = try s.TreeStore.init(t.allocator, candidates.objectStore(), 1);
    defer store.deinit();
    const first = try derive(&store);
    try t.expect(candidates.count > 40);
    var name: [96]u8 = undefined;
    const root_key = try s.TreeStore.key(first.location, &name);
    try t.expect(try base.objectStore().head(root_key) == null);
    try candidates.reset(base.objectStore());
    store.clearCache();
    const again = try derive(&store);
    try t.expectEqualDeep(first, again);
    try t.expect(try base.objectStore().head(root_key) == null);
    try candidates.persist();
    try t.expect(try base.objectStore().head(root_key) != null);
    store.deinit();
    base.deinit();
    base = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    try candidates.reset(base.objectStore());
    store = try s.TreeStore.init(t.allocator, base.objectStore(), 1);
    const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &store };
    for (0..40) |offset| {
        const value = (try tree.get(first, try s.LogPartitionRecord.integerKey(offset))).?;
        try t.expectEqualStrings("value", value.data[0..value.len]);
    }
    // The caller retained a candidate root, not a WAL acceptance receipt. The
    // partition's publication/replay tests must establish that separate boundary.
}

fn allocationSchedule(allocator: std.mem.Allocator) !void {
    var base = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer base.deinit();
    var candidates = try Candidates.init(allocator, base.objectStore(), .{ .bytes = 1024, .objects = 4, .resident_bytes = 2048 });
    defer candidates.deinit();
    try put(candidates.objectStore(), "key", "value");
}
test "candidate objects release failed initialization allocations and enforce resident quota" {
    try t.checkAllAllocationFailures(t.allocator, allocationSchedule, .{});
    var base = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer base.deinit();
    try t.expectError(error.InvalidCandidateObjectBudget, Candidates.init(t.allocator, base.objectStore(), .{ .bytes = 1024, .objects = 4, .resident_bytes = 1024 }));
    try t.expectError(error.InvalidCandidateObjectBudget, Candidates.init(t.allocator, base.objectStore(), .{ .bytes = 1024, .objects = 0, .resident_bytes = 2048 }));
}

const Fault = struct {
    underlying: s.TransitObjectStore.ObjectStore,
    lose_reply: bool = true,
    corrupt_metadata: bool = false,
    batches: usize = 0,
    largest_batch: usize = 0,
    fn objectStore(self: *@This()) s.TransitObjectStore.ObjectStore {
        return .{ .context = self, .vtable = &.{ .putImmutable = immutable, .putConditional = conditional, .getRange = get, .head = head, .delete = delete } };
    }
    fn batchStore(self: *@This()) s.TransitObjectStore.ObjectStore {
        return .{ .context = self, .vtable = &.{ .putImmutable = immutable, .putImmutableBatch = batch, .putConditional = conditional, .getRange = get, .head = head, .delete = delete } };
    }
    fn batch(ctx: *anyopaque, inputs: []const s.TransitObjectStore.ImmutablePut, output: []s.TransitObjectStore.ObjectMeta) !void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.batches += 1;
        self.largest_batch = @max(self.largest_batch, inputs.len);
        try self.underlying.putImmutableBatch(inputs, output);
        if (self.lose_reply) {
            self.lose_reply = false;
            return error.TestLostObjectReply;
        }
        if (self.corrupt_metadata) output[0].size += 1;
    }
    fn immutable(ctx: *anyopaque, name: []const u8, value: []const u8, digest: [32]u8) !s.TransitObjectStore.ObjectMeta {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        const result = try self.underlying.putImmutable(name, value, digest);
        if (self.lose_reply) {
            self.lose_reply = false;
            return error.TestLostObjectReply;
        }
        return result;
    }
    fn conditional(ctx: *anyopaque, name: []const u8, condition: s.TransitObjectStore.Condition, value: []const u8) !bool {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        return self.underlying.putConditional(name, condition, value);
    }
    fn get(ctx: *anyopaque, name: []const u8, offset: u64, length: u32, out: []u8) ![]const u8 {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        return self.underlying.getRange(name, offset, length, out);
    }
    fn head(ctx: *anyopaque, name: []const u8) !?s.TransitObjectStore.ObjectMeta {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        return self.underlying.head(name);
    }
    fn delete(ctx: *anyopaque, name: []const u8) !void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        return self.underlying.delete(name);
    }
};
test "candidate objects retain exact private bytes through partial persistence and immutable conflict" {
    var base = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer base.deinit();
    var fault: Fault = .{ .underlying = base.objectStore() };
    var candidates = try Candidates.init(t.allocator, fault.objectStore(), .{ .bytes = 1024, .objects = 4, .resident_bytes = 2048 });
    defer candidates.deinit();
    try put(candidates.objectStore(), "first", "1");
    try put(candidates.objectStore(), "second", "2");
    try t.expectError(error.TestLostObjectReply, candidates.persist());
    try t.expect(try base.objectStore().head("first") != null);
    try t.expect(try base.objectStore().head("second") == null);
    try t.expectEqual(@as(u32, 2), candidates.count);
    try candidates.persist();
    try t.expect(try base.objectStore().head("second") != null);
    try candidates.reset(base.objectStore());
    try put(candidates.objectStore(), "first", "changed private proposal");
    try t.expectError(error.ImmutableObjectConflict, candidates.persist());
    var output: [32]u8 = undefined;
    try t.expectEqualStrings("1", try base.objectStore().getRange("first", 0, 1, &output));
}

test "candidate objects batch selected persistence and preserve original bytes after a lost group reply" {
    var base = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer base.deinit();
    var fault: Fault = .{ .underlying = base.objectStore() };
    var allocator = t.FailingAllocator.init(t.allocator, .{});
    var candidates = try Candidates.init(allocator.allocator(), fault.batchStore(), .{ .bytes = 4096, .objects = 16, .resident_bytes = 8192 });
    defer candidates.deinit();
    allocator.fail_index = allocator.alloc_index;
    const selection = struct {
        pub fn keep(_: @This(), name: []const u8) bool {
            return !std.mem.eql(u8, name, "excluded");
        }
    }{};
    var name: [32]u8 = undefined;
    for (0..9) |number| {
        if (number == 4) try put(candidates.objectStore(), "excluded", "private intermediate");
        const key = try std.fmt.bufPrint(&name, "key-{d}", .{number});
        try put(candidates.objectStore(), key, key);
    }
    const used = candidates.used;
    try t.expectError(error.TestLostObjectReply, candidates.persistSelected(selection));
    try t.expectEqual(@as(usize, 1), fault.batches);
    try t.expectEqual(@as(usize, 8), fault.largest_batch);
    try t.expect(try base.objectStore().head("key-7") != null);
    try t.expect(try base.objectStore().head("key-8") == null);
    try t.expect(try base.objectStore().head("excluded") == null);
    try t.expectEqual(used, candidates.used);
    try t.expectEqual(@as(u32, 10), candidates.count);
    try candidates.persistSelected(selection);
    try t.expectEqual(@as(usize, 3), fault.batches);
    var output: [32]u8 = undefined;
    for (0..9) |number| {
        const key = try std.fmt.bufPrint(&name, "key-{d}", .{number});
        try t.expectEqualStrings(key, try base.objectStore().getRange(key, 0, @intCast(key.len), &output));
    }
    try t.expect(try base.objectStore().head("excluded") == null);
    fault.corrupt_metadata = true;
    try t.expectError(error.InvalidCandidateObject, candidates.persistSelected(selection));
    try t.expectEqual(used, candidates.used);
    fault.corrupt_metadata = false;
    try candidates.persistSelected(selection);
}
