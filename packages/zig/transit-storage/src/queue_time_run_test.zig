const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const s = @import("root.zig");
const Run = s.QueueTimeRun;

fn seed() p.StreamQueue.Partition {
    return .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(1) }, .partition = 2 };
}

test "queue time runs retain exact ordered metadata in bounded columnar chunks across disk reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "runs");
    defer objects.deinit();
    var events: [Run.max_rows]Run.Event = undefined;
    for (&events, 0..) |*event, i| event.* = .{ .at_ms = (@as(u64, 1) << 60) + i / 3, .offset = i / 2, .epoch = i % 2 };
    var encoded: [Run.max_bytes]u8 = undefined;
    var budget: f.memory.Budget = .{ .parent = t.allocator, .limit = 4 * 1024 * 1024 };
    defer t.expectEqual(@as(usize, 0), budget.used) catch unreachable;
    const descriptor = try Run.stage(budget.allocator(), objects.objectStore(), seed(), .visible, 10, &events, &encoded);
    try t.expectEqualDeep(descriptor, try Run.Descriptor.decode(try descriptor.encode()));
    objects.deinit();
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "runs");
    var output: [Run.max_rows]Run.Event = undefined;
    try t.expectEqualDeep(events, (try Run.load(budget.allocator(), objects.objectStore(), descriptor, &output))[0..Run.max_rows].*);
    try t.expectEqual(@as(u64, 0), objects.puts);
    // Retained scalar output survives scratch disposal and another read.
    var next_output: [Run.max_rows]Run.Event = undefined;
    _ = try Run.load(t.allocator, objects.objectStore(), descriptor, &next_output);
    try t.expectEqualDeep(events, output);
    var probe: f.memory.AllocationProbe = .{ .parent = t.allocator };
    var scratch = std.heap.ArenaAllocator.init(probe.allocator());
    defer scratch.deinit();
    _ = try Run.load(scratch.allocator(), objects.objectStore(), descriptor, &next_output);
    _ = scratch.reset(.retain_capacity);
    probe.begin(true);
    for (0..5) |_| {
        _ = try Run.load(scratch.allocator(), objects.objectStore(), descriptor, &next_output);
        _ = scratch.reset(.retain_capacity);
        try t.expectEqualDeep(events, next_output);
    }
    try probe.verify();
    probe.begin(false);
    std.debug.print("Queue timer chunk: {d} rows, {d} encoded bytes, {d} peak codec bytes; warm scratch reused.\n", .{ descriptor.rows, descriptor.content.bytes, budget.peak });
    try t.expectError(error.QueueTimeRunBudget, Run.load(t.allocator, objects.objectStore(), descriptor, output[0..1]));
    var changed = descriptor;
    changed.seed.partition += 1;
    try t.expectError(error.InvalidQueueTimeRun, Run.load(t.allocator, objects.objectStore(), changed, &output));
    changed = descriptor;
    changed.kind = .lease;
    // The first epoch is zero, so the descriptor itself refuses this kind.
    try t.expectError(error.InvalidQueueTimeRun, changed.validate());
    changed = descriptor;
    changed.seed.interpretation.object.object += 1;
    try t.expectError(error.InvalidQueueTimeRun, Run.load(t.allocator, objects.objectStore(), changed, &output));
    changed = descriptor;
    changed.last.offset += 1;
    try t.expectError(error.InvalidQueueTimeRun, Run.load(t.allocator, objects.objectStore(), changed, &output));
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try Run.key(descriptor.content, &name));
    try t.expectError(error.QueueTimeRunMissing, Run.load(t.allocator, objects.objectStore(), descriptor, &output));
}

test "queue time runs reject duplicate unsorted cross-bucket and incompatible interpretations" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var encoded: [Run.max_bytes]u8 = undefined;
    const a: Run.Event = .{ .at_ms = 100, .offset = 1, .epoch = 1 };
    const b: Run.Event = .{ .at_ms = 100, .offset = 1, .epoch = 2 };
    try t.expectError(error.InvalidQueueTimeRun, Run.stage(t.allocator, objects.objectStore(), seed(), .lease, 1, &.{ a, a }, &encoded));
    try t.expectError(error.InvalidQueueTimeRun, Run.stage(t.allocator, objects.objectStore(), seed(), .lease, 1, &.{ b, a }, &encoded));
    try t.expectError(error.InvalidQueueTimeRun, Run.stage(t.allocator, objects.objectStore(), seed(), .visible, 1, &.{ a, .{ .at_ms = 1 << Run.bucket_bits, .offset = 2, .epoch = 1 } }, &encoded));
    try t.expectEqual(@as(u64, 0), objects.puts);
    const descriptor = try Run.stage(t.allocator, objects.objectStore(), seed(), .lease, 1, &.{ a, b }, &encoded);
    var output: [2]Run.Event = undefined;
    try t.expectEqualDeep([_]Run.Event{ a, b }, (try Run.load(t.allocator, objects.objectStore(), descriptor, &output))[0..2].*);
    var value = try descriptor.encode();
    value.data[8] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Run.Descriptor.decode(value));
    value = try descriptor.encode();
    value.data[239] = 1;
    try t.expectError(error.InvalidQueueTimeRun, Run.Descriptor.decode(value));
    value = try descriptor.encode();
    value.len -= 1;
    try t.expectError(error.InvalidQueueTimeRun, Run.Descriptor.decode(value));
    var changed = descriptor;
    changed.kind = .visible;
    try t.expectError(error.InvalidQueueTimeRun, Run.load(t.allocator, objects.objectStore(), changed, &output));
    objects.objects.items[0].bytes[40] ^= 1;
    try t.expectError(error.InvalidQueueTimeRun, Run.load(t.allocator, objects.objectStore(), descriptor, &output));
    objects.objects.items[0].bytes[40] ^= 1;
    const largest: Run.Event = .{ .at_ms = std.math.maxInt(u64), .offset = std.math.maxInt(u64) - 1, .epoch = std.math.maxInt(u64) };
    const last = try Run.stage(t.allocator, objects.objectStore(), seed(), .lease, 2, &.{largest}, &encoded);
    try t.expectEqualDeep(largest, (try Run.load(t.allocator, objects.objectStore(), last, &output))[0]);
}
