const std = @import("std");
const t = std.testing;
const c = @import("catalog.zig");
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
