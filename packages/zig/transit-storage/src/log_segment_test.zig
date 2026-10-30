const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const s = @import("root.zig");
const support = @import("log_test_support.zig");

test "log segment sparse placement preserves identities and requires exact hidden coverage" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "sparse");
    defer objects.deinit();
    var definition = support.definition(.stream);
    definition.configuration.policy.stream.compact_key_column = 1;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    const declared = try s.LogDeclaration.stage(objects.objectStore(), &declaration);
    const operation: p.DataLifecycle.Operation = .{ .scope = definition.object.scope, .principal = 2, .operation = 99 };
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "a" } } }, .{ .value = .{ .atom = .{ .bytes = "payload" } } } };
    const rows: [6]s.LogBatch.Row = @splat(.{ .cells = &cells });
    var input: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(definition.schema, operation, .stream, &rows, &input);
    const append: p.StreamQueue.Append = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = declared.declaration.interpretation, .partition = 1 }, .operation = operation, .kind = .stream, .producer = null, .rows = rows.len, .payload = s.LogBatch.content(payload) };
    const evidence: s.LogEvidence.Record = .{ .declared = declared, .outcome = .{ .append = .{ .append = append, .first = 100, .next = 106, .accepted = .{ .partition = 91, .next_lsn = 7 }, .observed_ms = null } } };
    var encoded: [8192]u8 = undefined;
    var encoder = try s.LogView.Encoder.init(definition.schema, 6, 2, &encoded);
    var iterator = try s.LogBatch.Iterator.init(payload, definition.schema, .stream, 6);
    while (try iterator.next()) |row| if (row.ordinal == 1 or row.ordinal == 4) try encoder.append(row);
    const view = try encoder.finish();
    const sparse = try s.LogSegment.stageSparse(t.allocator, objects.objectStore(), &declaration, evidence, view, 1);
    const complete = try s.LogSegment.stage(t.allocator, objects.objectStore(), &declaration, evidence, payload, 1);
    try t.expectEqualDeep(sparse, try s.LogSegment.Descriptor.decode(try sparse.encode()));
    objects.deinit();
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "sparse");
    var output: [8192]u8 = undefined;
    try t.expectEqualSlices(u8, view, try s.LogSegment.materialize(t.allocator, objects.objectStore(), sparse, &declaration, evidence, &output));
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer tree.deinit();
    var bitmap: s.BitmapDirectory = .{ .store = &tree, .objects = objects.objectStore() };
    var scratch: s.BitmapDirectory.Container = .{};
    try tree.begin(1024 * 1024);
    const hidden = try bitmap.edit(.empty, 0, &.{ .{ .offset = 100, .present = true }, .{ .offset = 102, .present = true }, .{ .offset = 103, .present = true }, .{ .offset = 105, .present = true } }, &scratch);
    tree.end();
    try s.LogSegment.requireVisibility(sparse, view, definition.schema, evidence.outcome.append, &tree, hidden);
    try t.expectError(error.LogHistoryUnavailable, s.LogSegment.requireVisibility(sparse, view, definition.schema, evidence.outcome.append, &tree, .empty));
    var corrupt = sparse;
    corrupt.view.sha256[0] ^= 1;
    try t.expectError(error.LogPayloadConflict, s.LogSegment.materialize(t.allocator, objects.objectStore(), corrupt, &declaration, evidence, &output));
    try t.expectEqualSlices(u8, payload, try s.LogSegment.materialize(t.allocator, objects.objectStore(), complete, &declaration, evidence, &output));
    encoder = try s.LogView.Encoder.init(definition.schema, 6, 0, &encoded);
    const empty_view = try encoder.finish();
    const empty = try s.LogSegment.stageSparse(t.allocator, objects.objectStore(), &declaration, evidence, empty_view, 1);
    try t.expect(empty.segment == null);
    try t.expectEqualSlices(u8, empty_view, try s.LogSegment.materialize(t.allocator, objects.objectStore(), empty, &declaration, evidence, &output));
    try t.expectError(error.LogHistoryUnavailable, s.LogSegment.requireVisibility(empty, empty_view, definition.schema, evidence.outcome.append, &tree, hidden));
    try tree.begin(1024 * 1024);
    const all_hidden = try bitmap.edit(hidden, 0, &.{ .{ .offset = 101, .present = true }, .{ .offset = 104, .present = true } }, &scratch);
    tree.end();
    try s.LogSegment.requireVisibility(empty, empty_view, definition.schema, evidence.outcome.append, &tree, all_hidden);
}

test "log segment disk readback preserves original payload identity and delivery metadata" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    for ([_]p.StreamQueueDeclaration.Kind{ .stream, .queue }) |kind| {
        var definition = support.definition(kind);
        if (kind == .stream) definition.configuration.policy.stream.compact_key_column = 1;
        var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
        defer declaration.deinit();
        const declared = try s.LogDeclaration.stage(objects.objectStore(), &declaration);
        const operation: p.DataLifecycle.Operation = .{ .scope = definition.object.scope, .principal = 0, .operation = std.math.maxInt(u64) };
        const first = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "z" } } }, .{ .value = .{ .atom = .{ .bytes = "first" } } } };
        const second = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "a" } } }, .{ .value = .{ .atom = .{ .bytes = "second" } } } };
        var input: [8192]u8 = undefined;
        const payload = try s.LogBatch.encode(definition.schema, operation, kind, &.{
            .{ .cells = &first, .visible_ms = if (kind == .queue) 999 else 0 },
            .{ .cells = &second, .tombstone = kind == .stream },
        }, &input);
        const append: p.StreamQueue.Append = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = declared.declaration.interpretation, .partition = 1 }, .operation = operation, .kind = if (kind == .stream) .stream else .queue, .producer = null, .rows = 2, .payload = s.LogBatch.content(payload) };
        const evidence: s.LogEvidence.Record = .{ .declared = declared, .outcome = .{ .append = .{ .append = append, .first = 100, .next = 102, .accepted = .{ .partition = 91, .next_lsn = 7 }, .observed_ms = null } } };
        const segment = try s.LogSegment.stage(t.allocator, objects.objectStore(), &declaration, evidence, payload, 1);
        try t.expectEqualDeep(segment, try s.LogSegment.Descriptor.decode(try segment.encode()));
        objects.deinit();
        objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        var output: [8192]u8 = undefined;
        try t.expectEqualSlices(u8, payload, try s.LogSegment.materialize(t.allocator, objects.objectStore(), segment, &declaration, evidence, &output));
        var foreign = evidence;
        foreign.outcome.append.first = 101;
        foreign.outcome.append.next = 103;
        try t.expectError(error.InvalidLogSegment, s.LogSegment.materialize(t.allocator, objects.objectStore(), segment, &declaration, foreign, &output));
        var name: [96]u8 = undefined;
        try objects.objectStore().delete(try s.LogSegment.metadataKey(segment.metadata, &name));
        try t.expectError(error.LogSegmentMissing, s.LogSegment.materialize(t.allocator, objects.objectStore(), segment, &declaration, evidence, &output));
        var memory: f.MemoryBudget = .{ .parent = t.allocator, .limit = 4096 };
        try t.expectError(error.OutOfMemory, s.LogSegment.stage(memory.allocator(), objects.objectStore(), &declaration, evidence, payload, 1));
        try t.expect(memory.exhausted);
        try t.expectEqual(@as(usize, 0), memory.used);
    }
}
