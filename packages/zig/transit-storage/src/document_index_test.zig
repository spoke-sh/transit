const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const d = @import("transit_document");
const Index = s.DocumentIndex;
const Store = Index.Store;
const Document = d.Document(Index);
const identity: Index.Identity = .{ .document = 17, .epoch = 1, .type_revision = 1 };
const index_budget = 4 * 1024 * 1024;

fn edit(replica: u64, value: u64, observed: d.Model.Observed) !d.Change {
    var result: d.Change = .{ .document = 17, .epoch = 1, .replica = replica, .first = replica, .len = 1 };
    result.operations[0] = .{ .assign = .{ .field = try d.Model.Name.init("x"), .observed = observed, .value = .{ .unsigned = value } } };
    return result;
}
fn field(doc: Document, store: *Store) !Document.Register {
    return doc.field(store, .root, try d.Model.Name.init("x"));
}
fn stage(doc: Document, store: *Store, change: d.Change) !Document {
    var pending = doc;
    pending.index = try store.begin(doc.index, index_budget);
    defer store.abort();
    var candidate = try pending.apply(store, change);
    candidate.state.index = try store.seal(candidate.state.index);
    return candidate.state;
}
fn keyFor(i: usize) !Index.Key {
    // Cross a chunk boundary; exercise keys with a common 64-byte prefix.
    var bytes: [80]u8 = @splat('k');
    std.mem.writeInt(u64, bytes[72..80], i, .big);
    return Index.Key.init(&bytes);
}
fn valueFor(i: usize) !Index.Value {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, i, .big);
    return Index.Value.init(&bytes);
}

test "Document tseg candidates reopen on disk with conflicts, deduplication and retained roots" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var doc: Document = .{ .document = 17 };
    var retained = doc;
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var store = try Store.init(t.allocator, objects.objectStore(), identity, .{ .resident_pages = 1 });
        defer store.deinit();
        doc = try stage(doc, &store, try edit(1, 11, .{}));
        retained = doc;
        doc = try stage(doc, &store, try edit(2, 22, .{}));
        try t.expectEqual(.conflict, (try field(doc, &store)).status());
        doc = try stage(doc, &store, try edit(3, 33, (try field(doc, &store)).observed()));
        try t.expectEqual(@as(u64, 33), (try field(doc, &store)).assignments[0].value.unsigned);
        try t.expectEqual(@as(u64, 11), (try field(retained, &store)).assignments[0].value.unsigned);
        try t.expect(store.tree.misses > store.tree.cache.len);
    }
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var store = try Store.init(t.allocator, objects.objectStore(), identity, .{ .resident_pages = 1 });
        defer store.deinit();
        try t.expectEqual(@as(u64, 33), (try field(doc, &store)).assignments[0].value.unsigned);
        try t.expectEqual(@as(u64, 11), (try field(retained, &store)).assignments[0].value.unsigned);
        const duplicate = try doc.apply(&store, try edit(1, 11, .{}));
        try t.expect(duplicate.duplicate);
        try t.expectEqual(@as(u64, 1), duplicate.accepted_revision);
        try t.expectEqualDeep(doc, duplicate.state);
        try t.expectError(error.DocumentIdentityConflict, doc.apply(&store, try edit(1, 999, .{})));
    }
}

test "Document tseg directory grows beyond its buffers and preserves ordered prefix reads" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var index: Index = .{};
    var retained: Index = .{};
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var store = try Store.init(t.allocator, objects.objectStore(), identity, .{ .pending_records = 8, .resident_pages = 1 });
        defer store.deinit();
        for (0..40) |batch| {
            var candidate = try store.begin(index, index_budget);
            for (0..8) |offset| {
                const i = batch * 8 + offset;
                candidate = try candidate.put(&store, try keyFor(i), try valueFor(i));
            }
            index = try store.seal(candidate);
        }
        retained = index;
        var candidate = try store.begin(index, index_budget);
        // Overlay keys bracket the current first key, including a repeated put.
        candidate = try candidate.put(&store, try keyFor(0), try valueFor(900));
        candidate = try candidate.put(&store, try keyFor(0), try valueFor(901));
        const first = (try candidate.next(&store, null)).?;
        try t.expectEqualDeep(try valueFor(901), first.value);
        index = try store.seal(candidate);
        try t.expectEqual(@as(u64, 320), index.root.?.entries);
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var store = try Store.init(t.allocator, objects.objectStore(), identity, .{ .pending_records = 8, .resident_pages = 1 });
    defer store.deinit();
    var after: ?Index.Key = null;
    for (0..320) |i| {
        const entry = (try index.next(&store, after)).?;
        try t.expectEqualDeep(try keyFor(i), entry.key);
        try t.expectEqualDeep(try valueFor(if (i == 0) 901 else i), entry.value);
        after = entry.key;
    }
    try t.expect((try index.next(&store, after)) == null);
    try t.expectEqualDeep(try valueFor(0), (try retained.get(&store, try keyFor(0))).?);
}

test "Document tseg sequence retains deleted anchors and detached history" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var store = try Store.init(t.allocator, objects.objectStore(), identity, .{ .resident_pages = 1 });
    defer store.deinit();
    var doc: Document = .{ .document = 17 };
    var change: d.Change = .{ .document = 17, .epoch = 1, .replica = 1, .first = 1, .len = 3 };
    const text: d.Dot = .{ .replica = 1, .counter = 1 };
    const a: d.Dot = .{ .replica = 1, .counter = 2 };
    change.operations[0] = .{ .assign = .{ .field = try d.Model.Name.init("text"), .value = .text } };
    change.operations[1] = .{ .insert = .{ .object = text, .value = .{ .character = 'a' } } };
    change.operations[2] = .{ .insert = .{ .object = text, .after = a, .value = .{ .character = 'b' } } };
    doc = try stage(doc, &store, change);
    const retained = doc;
    change.previous = 3;
    change.first = 4;
    change.len = 2;
    change.operations[0] = .{ .delete_element = .{ .object = text, .element = a } };
    change.operations[1] = .{ .insert = .{ .object = text, .after = a, .value = .{ .character = 'c' } } };
    doc = try stage(doc, &store, change);
    for ([_]Document{ retained, doc }, [_][]const u8{ "ab", "cb" }) |snapshot, expected| {
        var cursor: Document.SequenceCursor = .{};
        var count: usize = 0;
        var ended = false;
        for (0..32) |_| {
            switch (try snapshot.sequenceStep(&store, text, &cursor)) {
                .end => {
                    ended = true;
                    break;
                },
                .more => {},
                .item => |item| {
                    try t.expect(count < expected.len);
                    try t.expectEqual(@as(u32, expected[count]), item.values.assignments[0].value.character);
                    count += 1;
                },
            }
        }
        try t.expect(ended);
        try t.expectEqual(expected.len, count);
    }
    change.previous = 5;
    change.first = 6;
    change.len = 1;
    change.operations[0] = .{ .remove = .{ .field = try d.Model.Name.init("text"), .observed = try d.Model.Observed.init(&.{text}) } };
    doc = try stage(doc, &store, change);
    try t.expectEqual(.missing, (try doc.field(&store, .root, try d.Model.Name.init("text"))).status());
    try t.expectEqual(.object, (try retained.field(&store, .root, try d.Model.Name.init("text"))).status());
}

test "Document tseg failed staging and stale candidate handles cannot change retained roots" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var store = try Store.init(t.allocator, objects.objectStore(), identity, .{ .pending_records = 1 });
    defer store.deinit();
    const key = try Index.Key.init("key");
    var initial = try store.begin(.{}, index_budget);
    initial = try initial.put(&store, key, try Index.Value.init("old"));
    const retained = try store.seal(initial);
    try t.expectError(error.StaleDocumentCandidate, initial.get(&store, key));
    var candidate = try store.begin(retained, 1);
    const prefix = candidate;
    candidate = try candidate.put(&store, key, try Index.Value.init("new"));
    try t.expectError(error.StaleDocumentCandidate, prefix.put(&store, key, try Index.Value.init("fork")));
    try t.expectEqualStrings("old", (try prefix.get(&store, key)).?.slice());
    try t.expectError(error.DocumentCandidateTooLarge, candidate.put(&store, key, try Index.Value.init("overflow")));
    try t.expectError(error.StorageCandidateTooLarge, store.seal(candidate));
    try t.expectError(error.StaleDocumentCandidate, candidate.get(&store, key));
    try t.expectEqualStrings("old", (try retained.get(&store, key)).?.slice());
    candidate = try store.begin(retained, index_budget);
    var other = try Store.init(t.allocator, objects.objectStore(), identity, .{});
    defer other.deinit();
    _ = try other.begin(retained, index_budget);
    try t.expectError(error.StaleDocumentCandidate, candidate.get(&other, key));
    store.abort();
    _ = try store.begin(retained, index_budget);
    try t.expectError(error.StaleDocumentCandidate, candidate.get(&store, key));
    store.abort();
    var foreign = retained;
    foreign.root.?.definition[0] ^= 1;
    try t.expectError(error.IncompatibleDefinition, foreign.get(&store, key));
    foreign = retained;
    foreign.root.?.identity.epoch += 1;
    try t.expectError(error.DocumentIdentityMismatch, foreign.get(&store, key));
}

test "Document tseg scratch and segment bounds differ from provider allocation failure" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    for ([_]Store.Options{ .{ .scratch_bytes = 1 }, .{ .segment_bytes = 128 }, .{} }, 0..) |options, i| {
        var store = try Store.init(t.allocator, objects.objectStore(), identity, options);
        defer store.deinit();
        var candidate = try store.begin(.{}, index_budget);
        candidate = try candidate.put(&store, try Index.Key.init("key"), try Index.Value.init("value"));
        var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
        if (i == 2) objects.allocator = failing.allocator();
        defer objects.allocator = t.allocator;
        try t.expectError(switch (i) {
            0 => error.DocumentScratchBudget,
            1 => error.DocumentSegmentBudget,
            else => error.OutOfMemory,
        }, store.seal(candidate));
        try t.expect(!store.active);
    }
}

test "Document tseg cached reads allocate nothing and cold reads reject corruption or missing segments" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var allocator = t.FailingAllocator.init(t.allocator, .{});
    var store = try Store.init(allocator.allocator(), objects.objectStore(), identity, .{});
    defer store.deinit();
    var candidate = try store.begin(.{}, index_budget);
    const key = try Index.Key.init("key");
    candidate = try candidate.put(&store, key, try Index.Value.init("value"));
    const index = try store.seal(candidate);
    try t.expectEqualStrings("value", (try index.get(&store, key)).?.slice());
    allocator.fail_index = allocator.alloc_index;
    const reads = objects.range_reads;
    for (0..100) |_| try t.expectEqualStrings("value", (try index.get(&store, key)).?.slice());
    try t.expect(!allocator.has_induced_failure);
    try t.expectEqual(reads, objects.range_reads);
    allocator.fail_index = std.math.maxInt(usize);
    for (objects.objects.items) |*object| {
        if (!std.mem.startsWith(u8, object.key, "document-segment/")) continue;
        object.bytes[0] ^= 1;
        store.cached_segment = null;
        try t.expectError(error.InvalidDocumentSegment, index.get(&store, key));
        object.bytes[0] ^= 1;
        const metadata = (try objects.objectStore().head(object.key)).?;
        _ = try objects.reclaimImmutableObject(object.key, metadata);
        try t.expectError(error.MissingDocumentSegment, index.get(&store, key));
        return;
    }
    return error.MissingSegmentFixture;
}
