const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const s = @import("root.zig");
const Run = s.QueueTimeRun;
const Directory = s.QueueTimeDirectory;
const Merge = s.QueueTimeMerge;
const empty_basis: Merge.Basis = .{ .items = null, .sidecars = null, .next_offset = 0 };
fn seed() p.StreamQueue.Partition {
    return .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(1) }, .partition = 2 };
}
fn event(ordinal: u64) Run.Event {
    return .{ .at_ms = ordinal / 3 + 1, .offset = ordinal, .epoch = ordinal % 2 + 1 };
}
const Keep = struct {
    divisor: u64 = 0,
    fail_offset: ?u64 = null,
    pub fn keep(self: @This(), basis: Merge.Basis, kind: Run.Kind, value: Run.Event) !bool {
        try t.expectEqualDeep(empty_basis, basis);
        try t.expectEqual(Run.Kind.lease, kind);
        if (self.fail_offset == value.offset) return error.FilterUnavailable;
        return self.divisor == 0 or value.offset % self.divisor != 0;
    }
};
fn source(directory: Directory, from: u64, count: usize, step: u64, serial: *u64, workspace: *Merge.Workspace) !Directory.Root {
    var root: Directory.Root = .empty;
    var next: usize = 0;
    while (next < count) {
        const size = @min(31, count - next);
        for (workspace.output[0..size], 0..) |*value, i| value.* = event(from + (next + i) * step);
        const chunk = try Run.stage(t.allocator, directory.store.store, seed(), .lease, serial.*, workspace.output[0..size], &workspace.encoded);
        serial.* += 1;
        try directory.store.begin(1024 * 1024);
        defer directory.store.end();
        root = try directory.append(root, chunk);
        next += size;
    }
    return root;
}
fn roundTrip(value: Merge.State) !Merge.State {
    const json = try std.json.Stringify.valueAlloc(t.allocator, value, .{});
    defer t.allocator.free(json);
    var parsed = try std.json.parseFromSlice(Merge.State, t.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();
    try parsed.value.validate();
    return parsed.value;
}

test "queue time merge resumes bounded disk progress with duplicate and filtered rows" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "merge");
    defer objects.deinit();
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer tree.deinit();
    var scratch = std.heap.ArenaAllocator.init(t.allocator);
    defer scratch.deinit();
    const workspace = try t.allocator.create(Merge.Workspace);
    defer t.allocator.destroy(workspace);
    const directory: Directory = .{ .store = &tree, .seed = seed(), .kind = .lease, .bucket = 0 };
    var serial: u64 = 1;
    const left = try source(directory, 0, 1000, 2, &serial, workspace);
    const right = try source(directory, 0, 1000, 1, &serial, workspace);
    var state = try Merge.State.init(seed(), .lease, 0, empty_basis, .{ left, right });
    var steps: usize = 0;
    var earlier: ?Merge.State = null;
    while (!state.complete) {
        const before = state;
        try tree.begin(1024 * 1024);
        state = try (Merge{ .store = &tree, .scratch = &scratch, .workspace = workspace }).step(state, serial, 37, Keep{ .divisor = 5 });
        tree.end();
        serial += 1;
        const examined = state.positions[0].rows + state.positions[1].rows - before.positions[0].rows - before.positions[1].rows;
        try t.expect(examined > 0 and examined <= 37);
        try t.expect(state.output.rows - before.output.rows <= examined);
        try t.expect(state.output.chunks - before.output.chunks <= 1);
        state = try roundTrip(state);
        steps += 1;
        if (steps == 11) earlier = state;
        if (steps % 11 == 0) {
            tree.deinit();
            objects.deinit();
            objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "merge");
            tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
            _ = scratch.reset(.free_all);
        }
    }
    try t.expectEqual(@as(usize, 55), steps);
    try t.expectEqual(@as(u64, 1200), state.output.rows);
    try t.expectEqual(@as(u64, 800), state.discarded);
    for ([_]Merge.State{ earlier.?, state }) |checkpoint| {
        var cursor: Directory.Audit = .{ .basis = checkpoint.output };
        var expected: u64 = 0;
        var count: u64 = 0;
        while (try directory.audit(&cursor)) |entry| {
            const rows = try Run.load(t.allocator, objects.objectStore(), entry.chunk, &workspace.output);
            for (rows) |value| {
                while (expected % 5 == 0 or (expected >= 1000 and expected % 2 != 0)) expected += 1;
                try t.expectEqualDeep(event(expected), value);
                expected += 1;
                count += 1;
            }
        }
        try t.expectEqual(checkpoint.output.rows, count);
        try t.expect(cursor.complete);
    }
    const puts = objects.puts;
    try t.expectEqualDeep(state, try (Merge{ .store = &tree, .scratch = &scratch, .workspace = workspace }).step(state, serial, 37, Keep{}));
    try t.expectEqual(puts, objects.puts);
}

test "queue time merge splits duplicates at budget one and proves an empty filtered result" {
    try t.expectError(error.MissingField, std.json.parseFromSlice(Merge.Position, t.allocator, "{\"rows\":0,\"chunks\":0,\"after\":null}", .{}));
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 0);
    defer tree.deinit();
    var scratch = std.heap.ArenaAllocator.init(t.allocator);
    defer scratch.deinit();
    const workspace = try t.allocator.create(Merge.Workspace);
    defer t.allocator.destroy(workspace);
    const directory: Directory = .{ .store = &tree, .seed = seed(), .kind = .lease, .bucket = 0 };
    var serial: u64 = 1;
    const input = try source(directory, 1, 1, 1, &serial, workspace);
    const merge: Merge = .{ .store = &tree, .scratch = &scratch, .workspace = workspace };
    var state = try Merge.State.init(seed(), .lease, 0, empty_basis, .{ input, input });
    try tree.begin(1024 * 1024);
    defer tree.end();
    state = try merge.step(state, serial, 1, Keep{});
    try t.expect(!state.complete);
    try t.expectEqual(@as(u64, 1), state.output.rows);
    state = try merge.step(try roundTrip(state), serial + 1, 1, Keep{});
    try t.expect(state.complete);
    try t.expectEqual(@as(u64, 1), state.output.rows);
    try t.expectEqual(@as(u64, 1), state.discarded);
    state = try Merge.State.init(seed(), .lease, 0, empty_basis, .{ input, .empty });
    state = try merge.step(state, serial, 1, Keep{ .divisor = 1 });
    try t.expect(state.complete);
    try t.expectEqualDeep(Directory.Root.empty, state.output);
    try t.expectEqual(@as(u64, 1), state.discarded);
    const empty = try Merge.State.init(seed(), .lease, 0, empty_basis, .{ .empty, .empty });
    try t.expect((try merge.step(empty, serial, 1, Keep{})).complete);
}

test "queue time merge privately rederives identical chunks and refuses incomplete or failed steps" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const workspace = try t.allocator.create(Merge.Workspace);
    defer t.allocator.destroy(workspace);
    var originals = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer originals.deinit();
    const directory: Directory = .{ .store = &originals, .seed = seed(), .kind = .lease, .bucket = 0 };
    var serial: u64 = 1;
    const input = try source(directory, 0, 75, 1, &serial, workspace);
    const before = try Merge.State.init(seed(), .lease, 0, empty_basis, .{ input, .empty });
    var candidate = try @import("CandidateObjects.zig").init(t.allocator, objects.objectStore(), .{ .bytes = 2 * 1024 * 1024, .objects = 64, .resident_bytes = 3 * 1024 * 1024 });
    defer candidate.deinit();
    var probe: f.memory.AllocationProbe = .{ .parent = t.allocator };
    var scratch = std.heap.ArenaAllocator.init(probe.allocator());
    defer scratch.deinit();
    var derived: ?Merge.State = null;
    const puts = objects.puts;
    for (0..3) |iteration| {
        try candidate.reset(objects.objectStore());
        var tree = try s.TreeStore.init(t.allocator, candidate.objectStore(), 1);
        defer tree.deinit();
        const merge: Merge = .{ .store = &tree, .scratch = &scratch, .workspace = workspace };
        try tree.begin(1024 * 1024);
        defer tree.end();
        if (iteration == 2) probe.begin(true);
        const next = try merge.step(before, serial, 64, Keep{});
        if (derived) |expected| try t.expectEqualDeep(expected, next) else derived = next;
        try t.expectEqual(puts, objects.puts);
        if (iteration == 0) _ = scratch.reset(.free_all);
        if (iteration == 2) {
            try probe.verify();
            probe.begin(false);
        }
    }
    try candidate.persist();
    try t.expect(objects.puts > puts);
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 0);
    defer tree.deinit();
    const merge: Merge = .{ .store = &tree, .scratch = &scratch, .workspace = workspace };
    const accepted = try roundTrip(derived.?);
    try tree.begin(1);
    try t.expectError(error.StorageCandidateTooLarge, merge.step(accepted, serial + 1, 4, Keep{}));
    tree.end();
    try tree.begin(1024 * 1024);
    defer tree.end();
    try t.expectError(error.FilterUnavailable, merge.step(accepted, serial + 1, 4, Keep{ .fail_offset = 65 }));
    try t.expectError(error.InvalidQueueTimerBudget, merge.step(accepted, serial + 1, 0, Keep{}));
    var bad = accepted;
    bad.positions[0].rows -= 1;
    try t.expectError(error.InvalidQueueTimeMerge, merge.step(bad, serial + 1, 4, Keep{}));
    bad = before;
    bad.seed.partition += 1;
    try t.expectError(error.InvalidQueueTimeDirectory, merge.step(bad, serial + 1, 4, Keep{}));
    var raw_tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &tree };
    const first = (try directory.find(input, null)).?;
    bad = before;
    bad.sources[0].directory = try raw_tree.remove(input.directory, try Directory.eventKey(first.chunk.last));
    try t.expectError(error.InvalidQueueTimeDirectory, merge.step(bad, serial + 1, 4, Keep{}));
    const next = try merge.step(accepted, serial + 1, 64, Keep{});
    try t.expect(next.complete);
    try t.expectEqual(@as(u64, 75), next.output.rows);
    // The old accepted progress remains a complete description of its prefix.
    try t.expectEqual(@as(u64, 64), accepted.output.rows);
}
