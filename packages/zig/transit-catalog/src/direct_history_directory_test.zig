const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const H = c.DirectHistoryDirectory;
const s = c.storage;
const d = c.protocol.DataLifecycle;
const scope: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
const owner: d.Operation = .{ .scope = scope, .principal = 4, .operation = 91 };

// Synthetic exact bindings qualify the directory, not pin acquisition or row
// interpretation. Owner tests must supply real accepted declarations and pins.
fn entry(object: u64, kind: H.Kind) !H.Entry {
    var buffer: [63]u8 = undefined;
    const name = try c.TableAuthority.Name.init(try std.fmt.bufPrint(&buffer, "item_{d}", .{object}));
    const definition: d.Definition = .{ .object = .{ .scope = scope, .branch = 1, .object = object }, .revision = 1, .digest = @splat(7) };
    return .{
        .namespace = .{ .scope = scope, .id = 1, .authorization = 5, .name = try .init("original"), .revision = 1 },
        .properties = .{ .namespace = 1, .authorization = 100 + object, .name = name },
        .declaration = .{ .kind = .table, .interpretation = definition, .content = .{ .bytes = 256, .sha256 = @splat(7) }, .schema_fingerprint = @splat(9), .retired = false },
        .source = .{ .interpretation = definition, .manifest = null, .checkpoint_lsn = 0, .accepted = .{ .partition = 1000 + object, .next_lsn = 5 } },
        .catalog = .{ .partition = 17, .next_lsn = 99 },
        .pin = if (kind == .retained) .{ .owner = owner, .content = .{ .bytes = 512, .sha256 = @splat(8) } } else null,
    };
}

test "historical directory freezes names namespaces and selected cuts beyond its disk cache" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var first: H.Reference = undefined;
    var full: H.Reference = undefined;
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var history = try H.init(t.allocator, objects.objectStore(), owner, 1, .selection, 1000, 1, 1024 * 1024);
        defer history.deinit();
        for (1..138) |id| {
            try history.put(try entry(id, .selection));
            if (id == 8) first = try history.seal();
        }
        full = try history.seal();
        try t.expectEqual(@as(usize, 1), history.index.cache.len);
        try t.expectEqual(@as(u64, 1), history.root.namespace_count);
        const puts = objects.puts;
        try history.put(try entry(1, .selection));
        try t.expectEqual(puts, objects.puts);
        var changed = try entry(1, .selection);
        changed.source.accepted.next_lsn += 1;
        try t.expectError(error.HistoricalIdentityConflict, history.put(changed));
        try t.expectEqualDeep(full, try history.commitment());
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var history = try H.init(t.allocator, objects.objectStore(), owner, 1, .selection, 1000, 0, 1024 * 1024);
    defer history.deinit();
    for ([_]H.Reference{ first, full }) |selected| {
        try history.restore(selected);
        var after: ?H.Cursor = null;
        var count: u64 = 0;
        while (true) {
            const page = try history.page(after);
            for (page.entries) |slot| if (slot) |value| {
                count += 1;
                try t.expectEqualDeep(try entry(count, .selection), value);
                try t.expectEqualDeep(value, (try history.lookup(1, value.properties.name)).?);
            };
            after = page.next;
            if (after == null) break;
        }
        try t.expectEqual(selected.count, count);
        try t.expectEqualDeep((try entry(1, .selection)).namespace, (try history.namespaceByName(try .init("original"))).?);
        try t.expect(try history.namespaceByName(try .init("renamed")) == null);
    }
    const cursor = (try history.page(null)).next.?;
    try history.restore(first);
    try t.expectError(error.InvalidHistoricalCursor, history.page(cursor));
    var wrong = first;
    wrong.count += 1;
    try t.expectError(error.HistoricalIdentityConflict, history.restore(wrong));
    var path: [96]u8 = undefined;
    try objects.objectStore().delete(try H.objectKey(full.content, &path));
    try t.expectError(error.HistoricalArtifactUnavailable, history.restore(full));
    try t.expectEqualDeep(first, try history.commitment());
}

test "historical directory rejects collisions mixed namespace revisions and partial private roots" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var history = try H.init(t.allocator, objects.objectStore(), owner, 1, .selection, 2, 1, 1024 * 1024);
    defer history.deinit();
    try history.put(try entry(1, .selection));
    const original = try history.seal();
    var duplicate = try entry(2, .selection);
    duplicate.properties.name = (try entry(1, .selection)).properties.name;
    try t.expectError(error.HistoricalNameConflict, history.put(duplicate));
    var renamed = try entry(2, .selection);
    renamed.namespace.revision += 1;
    renamed.namespace.name = try .init("renamed");
    try t.expectError(error.HistoricalNamespaceConflict, history.put(renamed));
    var reused = try entry(2, .selection);
    reused.namespace.id = 2;
    reused.properties.namespace = 2;
    try t.expectError(error.HistoricalNamespaceConflict, history.put(reused));
    try t.expectError(error.InvalidHistoricalBinding, history.put(try entry(2, .retained)));
    history.index_work_bytes = 1;
    try t.expectError(error.StorageCandidateTooLarge, history.put(try entry(2, .selection)));
    try t.expectEqualDeep(original, try history.commitment());
    try t.expect(try history.get(2) == null);
    try t.expect(try history.lookup(1, (try entry(2, .selection)).properties.name) == null);
    history.index_work_bytes = 1024 * 1024;
    try history.put(try entry(2, .selection));
    try t.expectError(error.HistoricalObjectLimit, history.put(try entry(3, .selection)));
    var other = try H.init(t.allocator, objects.objectStore(), owner, 1, .retained, 2, 1, 1024 * 1024);
    defer other.deinit();
    try t.expectError(error.HistoricalIdentityConflict, other.restore(original));
    var wrong_owner = try entry(1, .retained);
    wrong_owner.pin.?.owner.operation += 1;
    try t.expectError(error.HistoricalIdentityConflict, other.put(wrong_owner));
    try other.put(try entry(1, .retained));
    try t.expectError(error.InvalidHistoricalCursor, other.page(.{ .directory = try other.commitment(), .after = 2 }));
}

test "historical directory verifies actual declaration and unflushed pinned interpretation" {
    const Access = struct {
        fn acquire(_: *anyopaque) !s.TablePartition.Guard.Fence {
            return .{ .writer_epoch = 1, .policy_epoch = 1 };
        }
        fn release(_: *anyopaque) void {}
    };
    var context: u8 = 0;
    const guard: s.TablePartition.Guard = .{ .context = &context, .acquire = Access.acquire, .release = Access.release };
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var actual = try entry(7, .selection);
    var properties: [4096]u8 = undefined;
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: c.fuze.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    var table = try s.TablePartition.init(t.allocator, 17, .{ .object = actual.source.interpretation.object, .revision = 1, .schema = schema, .properties = try actual.properties.encode(&properties) }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    const binding: d.Binding = .{ .definition = c.protocol.Growth.current_definition, .identity = owner, .target = actual.source.interpretation.object, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(7) };
    const changes = [_]s.TablePartition.Change{.{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 91, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 42 } } }} }, .expect = .absent } }};
    _ = try table.apply(binding, &changes, .point, guard);
    actual.declaration = table.root.declared();
    actual.source.interpretation = table.root.interpretation;
    actual.source.accepted = .{ .partition = table.root.partition, .next_lsn = table.root.next_lsn };
    actual.pin = try table.pin(owner, actual.source.accepted, guard);
    try actual.validate(owner, 1, .retained);
    try actual.verify(t.allocator, objects.objectStore());
    var wrong = actual;
    wrong.properties.name = try .init("replacement");
    try t.expectError(error.InvalidHistoricalBinding, wrong.verify(t.allocator, objects.objectStore()));
    wrong = actual;
    wrong.source.accepted.next_lsn += 1;
    try t.expectError(error.InvalidHistoricalBinding, wrong.verify(t.allocator, objects.objectStore()));
    wrong = actual;
    wrong.pin.?.content.sha256[0] ^= 1;
    try t.expectError(error.TableSnapshotMissing, wrong.verify(t.allocator, objects.objectStore()));
    var history = try H.init(t.allocator, objects.objectStore(), owner, 1, .retained, 10, 0, 1024 * 1024);
    defer history.deinit();
    try history.put(actual);
    const selected = try history.seal();
    var path: [96]u8 = undefined;
    const key = try H.objectKey(selected.content, &path);
    for (objects.objects.items) |*object| if (std.mem.eql(u8, object.key, key)) {
        object.bytes[8] ^= 1;
        try t.expectError(error.InvalidHistoricalArtifact, history.restore(selected));
        std.crypto.hash.sha2.Sha256.hash(object.bytes, &object.sha256, .{});
        const foreign: H.Reference = .{ .count = selected.count, .content = .{ .bytes = object.bytes.len, .sha256 = object.sha256 } };
        var foreign_key: [96]u8 = undefined;
        // Re-address a self-consistent foreign-definition artifact. Failure is
        // the format boundary, not merely the outer content checksum.
        _ = try objects.objectStore().putImmutable(try H.objectKey(foreign.content, &foreign_key), object.bytes, foreign.content.sha256);
        try t.expectError(error.IncompatibleDefinition, history.restore(foreign));
        return;
    };
    return error.MissingHistoricalTestArtifact;
}
