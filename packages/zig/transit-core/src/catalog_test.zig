const std = @import("std");
const t = std.testing;
const c = @import("catalog.zig");
const p = @import("pages.zig");
const Store = @import("pages_test.zig").Store;
const Principal = struct { id: u64, sequence: u64, public_key: [32]u8 };

test "catalogs retain wide identities and immutable namespace-scoped pages" {
    var store: Store = .{};
    defer store.deinit();
    var catalog = try c.Catalog(Store).open(&store, .{});
    for (0..96) |i| {
        const id = 256 + i * 257;
        try catalog.put(try c.key(.principal, id, 0, ""), Principal{ .id = id, .sequence = i, .public_key = @splat(@intCast(i)) });
        try catalog.put(try c.key(.mailbox, 42, i, ""), @as(u64, i));
    }
    try t.expectEqual(@as(u64, 192), catalog.snapshot.records);
    var old = try c.Catalog(Store).open(&store, catalog.snapshot);
    try catalog.put(try c.key(.principal, 256, 0, ""), Principal{ .id = 256, .sequence = 100, .public_key = @splat(0) });
    try t.expectEqual(@as(u64, 192), catalog.snapshot.records);
    try t.expectEqual(@as(u64, 0), (try old.get(Principal, try c.key(.principal, 256, 0, ""))).?.sequence);
    try t.expectEqual(@as(u64, 100), (try catalog.get(Principal, try c.key(.principal, 256, 0, ""))).?.sequence);
    var cursor: ?@import("pages.zig").Key = null;
    var count: u64 = 0;
    while (true) {
        const batch = try catalog.scan(u64, .{ .namespace = .mailbox, .major = 42 }, cursor);
        for (batch.records) |slot| if (slot) |record| {
            try t.expectEqual(count, record.value);
            count += 1;
        };
        cursor = batch.next;
        if (cursor == null) break;
    }
    try t.expectEqual(@as(u64, 96), count);
    try t.expectError(error.InvalidCatalogCursor, catalog.scan(u64, .{ .namespace = .mailbox, .major = 43 }, try c.key(.mailbox, 42, 0, "")));
    try t.expectEqual(@as(?u64, null), try catalog.get(u64, try c.key(.mailbox, 43, 0, "")));
    try catalog.remove(try c.key(.mailbox, 42, 0, ""));
    try t.expectEqual(@as(u64, 191), catalog.snapshot.records);
    try t.expectEqual(@as(?u64, 0), try old.get(u64, try c.key(.mailbox, 42, 0, "")));
}

test "catalog rejects unknown versions, malformed keys, oversized records and partial staging" {
    var store: Store = .{};
    defer store.deinit();
    try t.expectError(error.UnsupportedCatalogVersion, c.Catalog(Store).open(&store, .{ .version = 2 }));
    try t.expectError(error.InvalidCatalogSnapshot, c.Catalog(Store).open(&store, .{ .records = 1 }));
    var catalog = try c.Catalog(Store).open(&store, .{});
    try t.expectError(error.InvalidCatalogKey, catalog.put(.{}, @as(u64, 0)));
    const address = try c.key(.entry, 1, 0, "one");
    try t.expectError(error.CatalogRecordTooLarge, catalog.put(address, @as([4096]u8, @splat(0))));
    const before = catalog.snapshot;
    store.lose_at = 0;
    try t.expectError(error.StagingAcknowledgementLost, catalog.put(address, @as(u64, 1)));
    try t.expect(std.meta.eql(before, catalog.snapshot));
    store.lose_at = null;
    try catalog.put(address, @as(u64, 1));
    try t.expectEqual(@as(u64, 1), catalog.snapshot.records);
}

test "catalog nested range includes its exact lower key and fences other routes" {
    var store: Store = .{};
    defer store.deinit();
    var catalog = try c.Catalog(Store).open(&store, .{});
    for (0..16) |i| try catalog.put(try c.key(.mailbox, 42, i, ""), @as(u64, i));
    const address = try c.key(.mailbox, 42, 8, "");
    try catalog.put(try c.key(.mailbox, 42, 8, "next"), @as(u64, 100));
    const range: c.Range = .{ .namespace = .mailbox, .major = 42, .minor = 8 };
    const batch = try catalog.scan(u64, range, null);
    try t.expectEqual(@as(u64, 8), batch.records[0].?.value);
    try t.expectEqual(@as(u64, 100), batch.records[1].?.value);
    try t.expect(batch.records[2] == null and batch.next == null);
    const continued = try catalog.scan(u64, range, address);
    try t.expectEqual(@as(u64, 100), continued.records[0].?.value);
    try t.expect(continued.records[1] == null and continued.next == null);
    try t.expectError(error.InvalidCatalogCursor, catalog.scan(u64, range, try c.key(.mailbox, 42, 9, "")));
}

test "bounded control records survive data reads and invalidate on root changes" {
    var store: Store = .{};
    defer store.deinit();
    var catalog = try c.Catalog(Store).open(&store, .{});
    const grant = try c.key(.grant, 4, 3, "");
    try catalog.put(grant, @as(u64, 7));
    for (0..32) |i| try catalog.put(try c.key(.entry, 4, i, "data"), @as(u64, i));
    var cache: c.RecordCache = .{};
    catalog.record_cache = &cache;
    try t.expectEqual(@as(?u64, 7), try catalog.get(u64, grant));
    for (0..32) |i| _ = try catalog.get(u64, try c.key(.entry, 4, i, "data"));
    const before = store.reads;
    try t.expectEqual(@as(?u64, 7), try catalog.get(u64, grant));
    try t.expectEqual(before, store.reads);
    try t.expect(cache.hits > 0);
    const old = catalog.snapshot;
    try catalog.put(grant, @as(u64, 0));
    try t.expectEqual(@as(?u64, 0), try catalog.get(u64, grant));
    var retained = try c.Catalog(Store).open(&store, old);
    retained.record_cache = &cache;
    try t.expectEqual(@as(?u64, 7), try retained.get(u64, grant));
    try t.expectEqual(@as(?u64, 0), try catalog.get(u64, grant));
    try catalog.remove(grant);
    try t.expectEqual(@as(?u64, null), try catalog.get(u64, grant));
}

test "catalog mutation counts share paths and preserve mixed changes, retained cuts and failed candidates" {
    var store: Store = .{};
    defer store.deinit();
    var catalog = try c.Catalog(Store).open(&store, .{});
    for (0..64) |i| try catalog.put(try c.key(.entry, 7, i * 2, ""), @as(u64, i));
    const retained = catalog.snapshot;
    const changes = [_]p.Mutation{
        try c.putMutation(try c.key(.entry, 7, 43, ""), @as(u64, 1043)),
        try c.putMutation(try c.key(.entry, 7, 40, ""), @as(u64, 1040)),
        .{ .key = try c.key(.entry, 7, 46, ""), .value = null },
        try c.putMutation(try c.key(.entry, 7, 129, ""), @as(u64, 1129)),
        .{ .key = try c.key(.entry, 7, 45, ""), .value = null },
        try c.putMutation(try c.key(.entry, 7, 50, ""), @as(u64, 25)),
        .{ .key = try c.key(.entry, 7, 48, ""), .value = null },
        try c.putMutation(try c.key(.entry, 7, 41, ""), @as(u64, 1041)),
    };
    store.reads = 0;
    for (changes) |change| _ = try catalog.tree.get(retained.root, change.key);
    const control_root = try catalog.tree.mutate(retained.root, &changes);
    const separate_reads = store.reads;
    store.reads = 0;
    const before_writes = store.writes;
    try catalog.mutate(&changes);
    const shared_reads = store.reads;
    const stages = store.writes - before_writes;
    try t.expect(shared_reads < separate_reads);
    try t.expectEqualDeep(control_root, catalog.snapshot.root);
    try t.expectEqual(@as(u64, 65), catalog.snapshot.records);
    std.debug.print("Catalog mutation batch: {d} separate loads, {d} shared loads for eight mixed changes.\n", .{ separate_reads, shared_reads });
    const old = try c.Catalog(Store).open(&store, retained);
    for (0..130) |i| {
        const prior: ?u64 = if (i < 128 and i % 2 == 0) @intCast(i / 2) else null;
        const expected: ?u64 = switch (i) {
            40, 41, 43, 129 => @intCast(1000 + i),
            46, 48 => null,
            else => prior,
        };
        const address = try c.key(.entry, 7, i, "");
        try t.expectEqual(prior, try old.get(u64, address));
        try t.expectEqual(expected, try catalog.get(u64, address));
    }
    // A failed read, including a read after immutable staging, cannot install
    // either the new root or its count. Each candidate starts at the old cut.
    for (0..shared_reads) |offset| {
        var candidate = try c.Catalog(Store).open(&store, retained);
        store.missing_at = store.reads + offset;
        try t.expectError(error.PageUnavailable, candidate.mutate(&changes));
        store.missing_at = null;
        try t.expectEqualDeep(retained, candidate.snapshot);
    }
    var corrupt_candidate = try c.Catalog(Store).open(&store, retained);
    store.corrupt = true;
    try t.expectError(error.CorruptPage, corrupt_candidate.mutate(&changes));
    store.corrupt = false;
    try t.expectEqualDeep(retained, corrupt_candidate.snapshot);
    for (0..stages) |offset| for (0..2) |kind| {
        var candidate = try c.Catalog(Store).open(&store, retained);
        store.fail_at = if (kind == 0) store.writes + offset else null;
        store.lose_at = if (kind == 1) store.writes + offset else null;
        if (kind == 0) {
            try t.expectError(error.StagingFailed, candidate.mutate(&changes));
        } else {
            try t.expectError(error.StagingAcknowledgementLost, candidate.mutate(&changes));
        }
        store.fail_at = null;
        store.lose_at = null;
        try t.expectEqualDeep(retained, candidate.snapshot);
    };
    const unchanged = catalog.snapshot;
    const writes = store.writes;
    try catalog.mutate(&.{ changes[5], changes[4] });
    try t.expectEqual(writes, store.writes);
    try t.expectEqualDeep(unchanged, catalog.snapshot);
    const reads = store.reads;
    try catalog.mutate(&.{});
    try t.expectEqual(reads, store.reads);
    try t.expectEqual(writes, store.writes);
    try t.expectEqualDeep(unchanged, catalog.snapshot);
}

test "catalog mutation validation rejects the whole batch before page I/O" {
    var store: Store = .{};
    defer store.deinit();
    var catalog = try c.Catalog(Store).open(&store, .{});
    const valid = try c.putMutation(try c.key(.entry, 1, 0, ""), @as(u64, 1));
    try catalog.mutate(&.{valid});
    const retained = catalog.snapshot;
    const reads = store.reads;
    const writes = store.writes;
    const other = try c.key(.entry, 1, 1, "");
    try t.expectError(error.InvalidCatalogKey, catalog.mutate(&.{ valid, .{ .key = .{}, .value = null } }));
    try t.expectError(error.DuplicatePageMutation, catalog.mutate(&.{ valid, valid }));
    try t.expectError(error.InvalidPageValue, catalog.mutate(&.{ valid, .{ .key = other, .value = .{ .len = 2049 } } }));
    const excessive: [p.mutation_batch + 1]p.Mutation = @splat(valid);
    try t.expectError(error.PageMutationBudget, catalog.mutate(&excessive));
    try t.expectEqual(reads, store.reads);
    try t.expectEqual(writes, store.writes);
    try t.expectEqualDeep(retained, catalog.snapshot);
}
