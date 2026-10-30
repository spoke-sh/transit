const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const s = @import("root.zig");
const Schedule = s.QueueSchedule;
const Run = s.QueueTimeRun;
const basis: s.QueueTimeMerge.Basis = .{ .items = null, .sidecars = null, .next_offset = 0 };
fn seed() p.StreamQueue.Partition {
    return .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(1) }, .partition = 2 };
}
fn event(offset: u64, bucket: u64) Run.Event {
    return .{ .at_ms = (bucket << Run.bucket_bits) + offset, .offset = offset, .epoch = 0 };
}
const Even = struct {
    pub fn keep(_: @This(), frozen: s.QueueTimeMerge.Basis, kind: Run.Kind, value: Run.Event) !bool {
        try t.expectEqualDeep(basis, frozen);
        try t.expectEqual(Run.Kind.visible, kind);
        return value.offset % 2 == 0;
    }
};
fn roundTrip(value: Schedule.Root) !Schedule.Root {
    const json = try std.json.Stringify.valueAlloc(t.allocator, value, .{});
    defer t.allocator.free(json);
    var parsed = try std.json.parseFromSlice(Schedule.Root, t.allocator, json, .{});
    defer parsed.deinit();
    try parsed.value.validate();
    return parsed.value;
}

test "queue schedule seals pending chunks and resumes size-tier merges on disk" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "schedule");
    defer objects.deinit();
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer tree.deinit();
    var scratch = std.heap.ArenaAllocator.init(t.allocator);
    defer scratch.deinit();
    const workspace = try t.allocator.create(Schedule.Workspace);
    defer t.allocator.destroy(workspace);
    const schedule: Schedule = .{ .store = &tree, .scratch = &scratch, .workspace = workspace, .seed = seed(), .kind = .visible };
    var root: Schedule.Root = .empty;
    // Two overlapping chunks and a far-future bucket, all larger than RAM pages.
    for ([_]u64{ 0, 0, 1 << 30 }) |bucket| for (0..256) |i| {
        try tree.begin(1024 * 1024);
        defer tree.end();
        root = try schedule.append(root, event(255 - i, bucket));
    };
    try t.expectEqual(@as(u64, 3), root.pending_chunks);
    try t.expect(root.active == null);
    for ([_]u64{ 258, 257, 256 }) |offset| {
        try tree.begin(1024 * 1024);
        defer tree.end();
        root = try schedule.append(root, event(offset, 0));
    }
    const initial = root;
    try t.expectEqualDeep(event(0, 0), (try schedule.nextEvent(root, null, basis, 256, Even{})).?);
    try t.expectError(error.QueueTimerReadBudget, schedule.nextEvent(root, null, basis, 1, Even{}));
    try t.expectEqualDeep(event(0, 1 << 30), (try schedule.nextEvent(root, event(258, 0), basis, 256, Even{})).?);
    var units: usize = 0;
    var merging = false;
    var appended_during_merge = false;
    while (true) {
        try tree.begin(2 * 1024 * 1024);
        const next = try schedule.maintain(root, basis, 17, Even{});
        tree.end();
        root = next orelse break;
        root = try roundTrip(root);
        units += 1;
        if (root.work != null) merging = true;
        if (!appended_during_merge and root.work != null and root.work.?.merge.output.rows != 0) {
            const work = root.work;
            try tree.begin(1024 * 1024);
            root = try schedule.append(root, event(260, 0));
            tree.end();
            try t.expectEqualDeep(work, root.work);
            appended_during_merge = true;
        }
        // Private merge output must never hide unprocessed source events.
        try t.expectEqualDeep(event(254, 0), (try schedule.nextEvent(root, event(253, 0), basis, 2048, Even{})).?);
        if (units % 7 == 0) {
            tree.deinit();
            objects.deinit();
            objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "schedule");
            tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
            _ = scratch.reset(.free_all);
        }
        if (units > 256) return error.QueueScheduleDidNotSettle;
    }
    try t.expect(merging and appended_during_merge and units > 30);
    try t.expect(root.work == null and root.pending == null and root.sweep.?.complete);
    try t.expectEqual(@as(u64, 2), root.level_count);
    try t.expectEqual(@as(u16, 3), root.active_rows);
    for ([_]Schedule.Root{ initial, root }) |retained| {
        try t.expectEqualDeep(event(256, 0), (try schedule.nextEvent(retained, event(254, 0), basis, 2048, Even{})).?);
        try t.expectEqualDeep(event(0, 1 << 30), (try schedule.nextEvent(retained, event(260, 0), basis, 2048, Even{})).?);
        try t.expect(try schedule.nextEvent(retained, event(255, 1 << 30), basis, 2048, Even{}) == null);
    }
    try t.expectEqualDeep(event(0, 1 << 30), (try schedule.nextEvent(initial, event(258, 0), basis, 2048, Even{})).?);
    try t.expectEqualDeep(event(260, 0), (try schedule.nextEvent(root, event(258, 0), basis, 2048, Even{})).?);
    const puts = objects.puts;
    try t.expect(try schedule.maintain(root, basis, 17, Even{}) == null);
    try t.expectEqual(puts, objects.puts);
    std.debug.print("Queue schedule: {d} bounded units, two retained levels, exact reads across reopen.\n", .{units});
}

test "queue schedule pages pending fan-in and seeks far buckets within a small read budget" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer tree.deinit();
    var scratch = std.heap.ArenaAllocator.init(t.allocator);
    defer scratch.deinit();
    const workspace = try t.allocator.create(Schedule.Workspace);
    defer t.allocator.destroy(workspace);
    const schedule: Schedule = .{ .store = &tree, .scratch = &scratch, .workspace = workspace, .seed = seed(), .kind = .visible };
    var root: Schedule.Root = .empty;
    for (0..255) |i| root = try schedule.append(root, event(0, 255 - i));
    try tree.begin(2048);
    try t.expectError(error.StorageCandidateTooLarge, schedule.append(root, event(0, 0)));
    tree.end();
    // Failed partial sealing left the accepted candidate's original buffer whole.
    try t.expect(root.pending == null and root.active_rows == 255);
    try t.expectEqualDeep(event(0, 1), (try schedule.nextEvent(root, null, basis, 1, Even{})).?);
    try tree.begin(8 * 1024 * 1024);
    root = try schedule.append(root, event(0, 0));
    tree.end();
    try t.expectEqual(@as(u64, 256), root.pending_chunks);
    try t.expect(root.active == null);
    tree.clearCache();
    try t.expectEqualDeep(event(0, 251), (try schedule.nextEvent(root, event(0, 250), basis, 6, Even{})).?);
    try t.expect(try schedule.nextEvent(root, event(0, 255), basis, 2, Even{}) == null);
}

test "queue schedule refuses malformed roots lost coverage and private sealing failure" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 0);
    defer tree.deinit();
    var scratch = std.heap.ArenaAllocator.init(t.allocator);
    defer scratch.deinit();
    const workspace = try t.allocator.create(Schedule.Workspace);
    defer t.allocator.destroy(workspace);
    const schedule: Schedule = .{ .store = &tree, .scratch = &scratch, .workspace = workspace, .seed = seed(), .kind = .visible };
    var root: Schedule.Root = .empty;
    for (0..255) |i| root = try schedule.append(root, event(i, 0));
    try tree.begin(1);
    try t.expectError(error.StorageCandidateTooLarge, schedule.append(root, event(255, 0)));
    tree.end();
    try t.expectEqual(@as(u16, 255), root.active_rows);
    try t.expectEqualDeep(event(254, 0), (try schedule.nextEvent(root, event(253, 0), basis, 4, Even{})).?);
    try tree.begin(1024 * 1024);
    defer tree.end();
    root = try schedule.append(root, event(255, 0));
    var bad = root;
    bad.pending_chunks += 1;
    try t.expectError(error.InvalidQueueSchedule, schedule.nextEvent(bad, event(255, 0), basis, 1024, Even{}));
    bad = root;
    bad.active_rows = 1;
    try t.expectError(error.InvalidQueueSchedule, bad.validate());
    var foreign = schedule;
    foreign.seed.partition += 1;
    try t.expectError(error.InvalidQueueSchedule, foreign.nextEvent(root, null, basis, 1024, Even{}));
    try t.expectError(error.InvalidQueueTimerBudget, schedule.maintain(root, basis, 0, Even{}));
    const entry = (try (s.TreeStore.pages.Tree(s.TreeStore){ .store = &tree }).scan(root.pending, null)).entries[0].?;
    const chunk = try Run.Descriptor.decode(entry.value);
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try Run.key(chunk.content, &name));
    try t.expectError(error.QueueTimeRunMissing, schedule.nextEvent(root, null, basis, 1024, Even{}));
}

test "queue schedule persists final buffers and replays without intermediate disk writes" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "candidate");
    defer objects.deinit();
    var candidates = try @import("CandidateObjects.zig").init(t.allocator, objects.objectStore(), .{ .bytes = 2 * 1024 * 1024, .objects = 512, .resident_bytes = 3 * 1024 * 1024 });
    defer candidates.deinit();
    var tree = try s.TreeStore.init(t.allocator, candidates.objectStore(), 1);
    defer tree.deinit();
    var scratch = std.heap.ArenaAllocator.init(t.allocator);
    defer scratch.deinit();
    const workspace = try t.allocator.create(Schedule.Workspace);
    defer t.allocator.destroy(workspace);
    const schedule: Schedule = .{ .store = &tree, .scratch = &scratch, .workspace = workspace, .seed = seed(), .kind = .visible };
    var root: Schedule.Root = .empty;
    for (0..100) |i| root = try schedule.append(root, event(i, 0));
    const earlier = root;
    try t.expectEqual(@as(u64, 0), objects.puts);
    try candidates.persistSelected(try Schedule.Buffers.init(root, .empty));
    try t.expectEqual(@as(u64, 1), objects.puts);
    var final: ?Schedule.Root = null;
    var intermediate: ?p.DataLifecycle.Content = null;
    for (0..2) |_| {
        try candidates.reset(objects.objectStore());
        tree.clearCache();
        _ = scratch.reset(.free_all);
        root = earlier;
        try tree.begin(2 * 1024 * 1024);
        for (100..258) |i| {
            root = try schedule.append(root, event(i, 0));
            if (i == 123) intermediate = root.active;
        }
        tree.end();
        if (final) |expected| try t.expectEqualDeep(expected, root) else final = root;
        try t.expectEqual(@as(u64, 1), objects.puts);
        try t.expect(candidates.count > 150);
    }
    try candidates.persistSelected(try Schedule.Buffers.init(root, .empty));
    // One sealed chunk, one directory page and one final delta, independent of
    // the 158 private appends and their intermediate immutable buffer objects.
    try t.expectEqual(@as(u64, 4), objects.puts);
    tree.deinit();
    objects.deinit();
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "candidate");
    try candidates.reset(objects.objectStore());
    tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    var name: [96]u8 = undefined;
    try t.expect(try objects.objectStore().head(try s.QueueTimeBuffer.key(intermediate.?, &name)) == null);
    try t.expect(try objects.objectStore().head(try s.QueueTimeBuffer.key(earlier.active.?, &name)) != null);
    try t.expect(try schedule.nextEvent(earlier, event(98, 0), basis, 4, Even{}) == null);
    try t.expectEqualDeep(event(100, 0), (try schedule.nextEvent(root, event(98, 0), basis, 128, Even{})).?);
}
