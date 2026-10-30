const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const s = @import("root.zig");
const Buffer = s.QueueTimeBuffer;
fn seed() p.StreamQueue.Partition {
    return .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(9) }, .partition = 0 };
}

test "queue time buffers order bounded deltas without eviction and retain exact bytes across disk reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "buffer");
    defer objects.deinit();
    var entries: [Buffer.max_rows]Buffer.Event = undefined;
    var buffer = try Buffer.init(seed(), .visible, &entries);
    for (0..Buffer.max_rows) |i| {
        const offset = Buffer.max_rows - i - 1;
        try buffer.append(.{ .at_ms = @as(u64, offset) << s.QueueTimeRun.bucket_bits, .offset = offset, .epoch = offset });
    }
    const original = entries;
    try t.expectError(error.QueueTimeBufferFull, buffer.append(.{ .at_ms = std.math.maxInt(u64), .offset = 0, .epoch = 0 }));
    try t.expectError(error.InvalidQueueTimeBuffer, buffer.append(entries[0]));
    try t.expectEqualDeep(original, entries);
    var encoded: [Buffer.max_bytes]u8 = undefined;
    const content = try buffer.stage(objects.objectStore(), &encoded);
    try t.expectEqual(@as(u64, Buffer.max_bytes), content.bytes);
    objects.deinit();
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "buffer");
    var output: [Buffer.max_rows]Buffer.Event = undefined;
    const loaded = try Buffer.load(seed(), .visible, objects.objectStore(), content, &encoded, &output);
    try t.expectEqualDeep(original, loaded.rows()[0..Buffer.max_rows].*);
    @memset(&encoded, 0);
    try t.expectEqualDeep(original, output);
    try t.expectEqual(@as(u64, 0), objects.puts);
    var foreign = seed();
    foreign.partition += 1;
    try t.expectError(error.InvalidQueueTimeBuffer, Buffer.load(foreign, .visible, objects.objectStore(), content, &encoded, &output));
    try t.expectError(error.InvalidQueueTimeBuffer, Buffer.load(seed(), .lease, objects.objectStore(), content, &encoded, &output));
    try t.expectError(error.QueueTimeBufferBudget, Buffer.load(seed(), .visible, objects.objectStore(), content, &encoded, output[0..1]));
    buffer.clear();
    try t.expectError(error.InvalidQueueTimeBuffer, buffer.encode(&encoded));
    try buffer.append(original[0]);
    try t.expectEqual(@as(usize, 1), buffer.rows().len);
}

test "queue time buffers reject foreign definitions malformed ordering and incomplete frames" {
    var entries: [3]Buffer.Event = undefined;
    var buffer = try Buffer.init(seed(), .lease, &entries);
    try t.expectError(error.InvalidQueueTimeRun, buffer.append(.{ .at_ms = 0, .offset = 0, .epoch = 0 }));
    try buffer.append(.{ .at_ms = 100, .offset = 2, .epoch = 1 });
    try buffer.append(.{ .at_ms = 100, .offset = 1, .epoch = 2 });
    try buffer.append(.{ .at_ms = 100, .offset = 1, .epoch = 1 });
    var encoded: [Buffer.max_bytes]u8 = undefined;
    var output: [3]Buffer.Event = undefined;
    const bytes = try buffer.encode(&encoded);
    _ = try Buffer.decode(seed(), .lease, bytes, &output);
    try t.expectEqualDeep(entries, output);
    encoded[8] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Buffer.decode(seed(), .lease, bytes, &output));
    encoded[8] ^= 1;
    encoded[127] = 1;
    try t.expectError(error.InvalidQueueTimeBuffer, Buffer.decode(seed(), .lease, bytes, &output));
    encoded[127] = 0;
    try t.expectError(error.InvalidQueueTimeBuffer, Buffer.decode(seed(), .lease, bytes[0 .. bytes.len - 1], &output));
    @memcpy(encoded[Buffer.header_bytes + 24 ..][0..24], encoded[Buffer.header_bytes..][0..24]);
    try t.expectError(error.InvalidQueueTimeBuffer, Buffer.decode(seed(), .lease, bytes, &output));
}

test "queue time buffers seal complete bucket slices into sorted columnar runs without changing events" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var entries: [128]Buffer.Event = undefined;
    var buffer = try Buffer.init(seed(), .visible, &entries);
    for (0..entries.len) |i| try buffer.append(.{ .at_ms = (@as(u64, i % 4) << s.QueueTimeRun.bucket_bits) + i / 4, .offset = i, .epoch = i });
    var encoded: [Buffer.max_bytes]u8 = undefined;
    const content = try buffer.stage(objects.objectStore(), &encoded);
    objects.objects.items[0].bytes[Buffer.header_bytes] ^= 1;
    var copied: [128]Buffer.Event = undefined;
    try t.expectError(error.InvalidQueueTimeBuffer, Buffer.load(seed(), .visible, objects.objectStore(), content, &encoded, &copied));
    objects.objects.items[0].bytes[Buffer.header_bytes] ^= 1;
    const loaded = try Buffer.load(seed(), .visible, objects.objectStore(), content, &encoded, &copied);
    var run_bytes: [s.QueueTimeRun.max_bytes]u8 = undefined;
    var restored: [128]Buffer.Event = undefined;
    var from: usize = 0;
    var chunks: u64 = 0;
    while (from < loaded.len) {
        var end = from + 1;
        while (end < loaded.len and copied[end].bucket() == copied[from].bucket()) : (end += 1) {}
        const run = try s.QueueTimeRun.stage(t.allocator, objects.objectStore(), seed(), .visible, chunks + 1, copied[from..end], &run_bytes);
        const decoded = try s.QueueTimeRun.load(t.allocator, objects.objectStore(), run, restored[from..end]);
        try t.expectEqual(end - from, decoded.len);
        from = end;
        chunks += 1;
    }
    try t.expectEqual(@as(u64, 4), chunks);
    try t.expectEqualDeep(entries, restored);
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try Buffer.key(content, &name));
    try t.expectError(error.QueueTimeBufferMissing, Buffer.load(seed(), .visible, objects.objectStore(), content, &encoded, &copied));
}
