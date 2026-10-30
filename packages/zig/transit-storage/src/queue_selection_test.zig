const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const s = @import("root.zig");
const Selection = @import("QueueSelection.zig");
const support = @import("log_test_support.zig");

fn metadata(declared: s.LogDeclaration.Stored) Selection.Metadata {
    return .{
        .definition = p.Growth.current_definition,
        .declared = declared,
        .claim = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = declared.declaration.interpretation, .partition = 1 }, .operation = .{ .scope = declared.declaration.interpretation.object.scope, .principal = 3, .operation = 9 }, .maximum = 4, .lease_ms = 100 },
        .accepted = .{ .partition = 91, .next_lsn = 6 },
        .observed = .{ .earliest_ms = 90, .latest_ms = 110 },
        .expires_ms = 210,
        .rows = 2,
        .source = .{ .accepted = .{ .partition = 91, .next_lsn = 5 }, .retained_from = 0, .next_offset = 12, .batches = .{ .digest = @splat(10), .location = @splat(11) }, .segments = .{ .digest = @splat(12), .location = @splat(13) } },
    };
}
fn leases(meta: Selection.Metadata) [2]p.StreamQueue.Lease {
    return .{
        .{ .target = meta.claim.target, .claim = meta.claim.operation, .offset = 3, .epoch = 7, .attempt = 2, .expires_ms = meta.expires_ms },
        .{ .target = meta.claim.target, .claim = meta.claim.operation, .offset = 9, .epoch = 12, .attempt = 4, .expires_ms = meta.expires_ms },
    };
}

test "queue selection original leases and placement cut reopen independently of current state" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.queue));
    defer declaration.deinit();
    const declared = try s.LogDeclaration.stage(objects.objectStore(), &declaration);
    const meta = metadata(declared);
    const selected = leases(meta);
    var output: [Selection.max_bytes]u8 = undefined;
    const content = try Selection.stage(objects.objectStore(), meta, &selected, &output);
    const receipt = try meta.receipt(content);
    try t.expectEqual(@as(u32, 2), receipt.rows);
    try t.expectEqual(@as(u64, 210), receipt.expires_ms);
    objects.deinit();
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    var parsing: [65536]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(&parsing);
    const view = try Selection.load(fixed.allocator(), objects.objectStore(), content, &output);
    try view.requireReceipt(receipt);
    try t.expectEqualDeep(meta, view.metadata);
    try t.expectEqualDeep(selected[0], try view.lease(0));
    try t.expectEqualDeep(selected[1], try view.lease(1));
    try t.expectError(error.QueueSelectionOffsetOutOfRange, view.lease(2));
    var changed = receipt;
    changed.claim.maximum += 1;
    try t.expectError(error.QueueClaimConflict, view.requireReceipt(changed));
    try t.expectError(error.QueueSelectionBudgetExceeded, Selection.load(t.allocator, objects.objectStore(), content, output[0..48]));
    // An original selection describes historical leases. Current liveness and
    // payload graph retention belong to the partition, not this format reader.
    try t.expectError(error.QueueLeaseExpired, selected[0].requireLive(selected[0], 210));
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try Selection.objectKey(content, &name));
    try t.expectError(error.QueueSelectionMissing, Selection.load(t.allocator, objects.objectStore(), content, &output));
}

test "queue selection independent row bytes reject duplicates foreign definitions and truncation" {
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.queue));
    defer declaration.deinit();
    const meta = metadata(try declaration.stored());
    const selected = leases(meta);
    var output: [Selection.max_bytes]u8 = undefined;
    const bytes = try Selection.encode(meta, &selected, &output);
    try t.expectEqualStrings("QCLAIM01", bytes[0..8]);
    try t.expectEqualSlices(u8, &.{ 0, 0, 0, 2 }, bytes[44..48]);
    const body = Selection.header_bytes + std.mem.readInt(u32, bytes[40..44], .big);
    const expected = [_]u8{
        0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 7,  0, 0, 0, 0, 0, 0, 0, 2,
        0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0, 0, 0, 0, 0, 4,
    };
    try t.expectEqualSlices(u8, &expected, bytes[body..]);
    const receipt = try meta.receipt(s.LogBatch.content(bytes));
    std.mem.writeInt(u64, output[body..][0..8], 4, .big);
    const altered = try Selection.decode(t.allocator, bytes);
    try t.expectError(error.QueueClaimConflict, altered.requireReceipt(receipt));
    std.mem.writeInt(u64, output[body..][0..8], 3, .big);
    for ([_]usize{ 0, 47, body, bytes.len - 1 }) |length|
        try t.expectError(error.InvalidQueueSelection, Selection.decode(t.allocator, bytes[0..length]));
    output[bytes.len] = 0;
    try t.expectError(error.InvalidQueueSelection, Selection.decode(t.allocator, output[0 .. bytes.len + 1]));
    std.mem.writeInt(u64, output[body + 24 ..][0..8], 3, .big);
    try t.expectError(error.InvalidQueueSelection, Selection.decode(t.allocator, bytes));
    std.mem.writeInt(u64, output[body + 24 ..][0..8], 9, .big);
    output[8] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Selection.decode(t.allocator, bytes));
    output[8] ^= 1;
    var changed = selected;
    changed[1].claim.operation += 1;
    try t.expectError(error.InvalidQueueSelection, Selection.encode(meta, &changed, &output));
    changed = selected;
    changed[1].offset = meta.source.next_offset;
    try t.expectError(error.InvalidQueueSelection, Selection.encode(meta, &changed, &output));
    var empty = meta;
    empty.rows = 0;
    try t.expectError(error.InvalidQueueSelection, Selection.encode(empty, &.{}, &output));
    var wrong_cut = meta;
    wrong_cut.source.accepted.next_lsn += 1;
    try t.expectError(error.InvalidQueueSelection, Selection.encode(wrong_cut, &selected, &output));
    // The generic typed JSON decoder accepts strings for byte arrays. The
    // stored-format canonical comparison must reject that alternate shape.
    const canonical = try Selection.encode(meta, &selected, &output);
    const canonical_size = std.mem.readInt(u32, output[40..44], .big);
    const start = 48 + std.mem.indexOf(u8, output[48..][0..canonical_size], "\"location\":[").? + "\"location\":".len;
    const end = start + std.mem.indexOfScalar(u8, output[start..canonical.len], ']').? + 1;
    const replacement = "\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"";
    const reduction = end - start - replacement.len;
    @memcpy(output[start..][0..replacement.len], replacement);
    std.mem.copyForwards(u8, output[start + replacement.len .. canonical.len - reduction], output[end..canonical.len]);
    std.mem.writeInt(u32, output[40..44], @intCast(canonical_size - reduction), .big);
    try t.expectError(error.InvalidQueueSelection, Selection.decode(t.allocator, output[0 .. canonical.len - reduction]));
    // Definition is required in the structured metadata as well as the prefix.
    const original = try Selection.encode(meta, &selected, &output);
    const metadata_bytes = std.mem.readInt(u32, output[40..44], .big);
    const removed = std.mem.indexOfScalar(u8, output[48..][0..metadata_bytes], ',').?;
    std.mem.copyForwards(u8, output[49 .. original.len - removed], output[49 + removed .. original.len]);
    std.mem.writeInt(u32, output[40..44], @intCast(metadata_bytes - removed), .big);
    try t.expectError(error.MissingField, Selection.decode(t.allocator, output[0 .. original.len - removed]));
}

test "queue selection binds the retained lower boundary without a compatibility default" {
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.queue));
    defer declaration.deinit();
    var meta = metadata(try declaration.stored());
    const selected = leases(meta);
    var output: [Selection.max_bytes]u8 = undefined;
    meta.source.retained_from = 3;
    const bytes = try Selection.encode(meta, &selected, &output);
    try t.expectEqualDeep(meta, (try Selection.decode(t.allocator, bytes)).metadata);
    meta.source.retained_from = 4;
    try t.expectError(error.InvalidQueueSelection, Selection.encode(meta, &selected, &output));
    meta.source.retained_from = 13;
    try t.expectError(error.InvalidQueueSelection, meta.validate());
    meta.source.retained_from = 0;
    const canonical = try Selection.encode(meta, &selected, &output);
    const field = "\"retained_from\":0,";
    const at = std.mem.indexOf(u8, canonical, field).?;
    std.mem.copyForwards(u8, output[at..], output[at + field.len .. canonical.len]);
    const size = std.mem.readInt(u32, output[40..44], .big);
    std.mem.writeInt(u32, output[40..44], @intCast(size - field.len), .big);
    try t.expectError(error.MissingField, Selection.decode(t.allocator, output[0 .. canonical.len - field.len]));
}
