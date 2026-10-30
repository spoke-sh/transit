const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const s = @import("root.zig");
const Index = @import("QueueIndex.zig");
const support = @import("log_test_support.zig");

fn operation(id: u64) p.DataLifecycle.Operation {
    return .{ .scope = support.definition(.queue).object.scope, .principal = 1, .operation = id };
}
fn key(declaration: *const s.LogDeclaration.Owned, text: []const u8, buffer: []u8) ![]const u8 {
    const column = declaration.definition.schema.columns[0];
    return f.Collation.encodeSortKey(.{ .value = .{ .atom = .{ .bytes = text } } }, column.type, column.collation, buffer);
}
const Appended = struct { root: Index.Root, target: p.StreamQueue.Partition };
fn enqueue(index: Index, before: Index.Root, declaration: *const s.LogDeclaration.Owned, id: u64, at: u64, names: []const []const u8, delays: []const u64) !Appended {
    const declared = try declaration.stored();
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declared.declaration.interpretation, .partition = 0 };
    var buffer: [16384]u8 = undefined;
    var encoder = try s.LogBatch.Encoder.init(declaration.definition.schema, operation(id), .queue, @intCast(names.len), &buffer);
    for (names, delays) |name, delay| {
        const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .bytes = name } } }, .{ .value = .{ .atom = .{ .bytes = "payload" } } } };
        try encoder.append(.{ .cells = &cells, .visible_ms = delay });
    }
    const bytes = try encoder.finish();
    const append: p.StreamQueue.Append = .{ .target = target, .operation = operation(id), .kind = .queue, .producer = null, .rows = names.len, .payload = s.LogBatch.content(bytes) };
    const receipt: p.StreamQueue.AppendReceipt = .{ .append = append, .first = before.next_offset, .next = before.next_offset + names.len, .accepted = .{ .partition = 91, .next_lsn = at }, .observed_ms = null };
    return .{ .root = try index.enqueue(before, declaration, receipt, bytes), .target = target };
}

test "queue index paged FIFO heads survive reopen delays and unrelated key claims" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var probe: f.memory.AllocationProbe = .{ .parent = t.allocator };
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(probe.allocator(), t.io, tmp.dir, "objects");
    defer objects.deinit();
    var store = try s.TreeStore.init(probe.allocator(), objects.objectStore(), 1);
    defer store.deinit();
    var scratch: std.heap.ArenaAllocator = .init(probe.allocator());
    defer scratch.deinit();
    var affinity_buckets: [1]s.QueueAffinity.Atomic = undefined;
    var affinity_slots: [2]s.QueueAffinity.Slot = undefined;
    var affinity = try s.QueueAffinity.init(&affinity_buckets, &affinity_slots);
    var bitmap: s.BitmapDirectory = .{ .store = &store, .objects = objects.objectStore() };
    var container: s.BitmapDirectory.Container = .{};
    var key_buffer: [8192]u8 = undefined;
    var definition = support.definition(.queue);
    definition.configuration.partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 };
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    const timer_workspace = try t.allocator.create(s.QueueSchedule.Workspace);
    defer t.allocator.destroy(timer_workspace);
    var index: Index = .{ .store = &store, .scratch = &scratch, .bitmap = &bitmap, .container = &container, .key_buffer = &key_buffer, .timer_workspace = timer_workspace, .timer_seed = .{ .definition = p.Growth.current_definition, .interpretation = (try declaration.stored()).declaration.interpretation, .partition = 0 } };
    index.affinity = &affinity;
    const policy = definition.configuration.policy.queue;
    try store.begin(8 * 1024 * 1024);
    const first = try enqueue(index, .empty, &declaration, 1, 2, &.{ "Alpha", "Beta", "aLPHa" }, &.{ 1000, 0, 0 });
    const second = try enqueue(index, first.root, &declaration, 2, 3, &.{ "ALPHA", "Gamma" }, &.{ 0, 5 });
    store.end();
    try t.expectEqual(@as(u64, 3), second.root.scheduled);
    try t.expectEqual(@as(u64, 1), (try index.firstEligible(second.root, 0)).?.offset);
    var root = second.root;
    const claim: p.StreamQueue.Claim = .{ .target = second.target, .operation = operation(3), .maximum = 2, .lease_ms = 100 };
    try store.begin(8 * 1024 * 1024);
    var foreign = claim;
    foreign.target.interpretation.object.object += 1;
    try t.expectError(error.LogPartitionConflict, index.acquire(root, 1, foreign, policy, .exact(10), .{ .partition = 91, .next_lsn = 4 }));
    try t.expectError(error.QueueNotEligible, index.acquire(root, 2, claim, policy, .exact(10), .{ .partition = 91, .next_lsn = 4 }));
    root = try index.acquire(root, 1, claim, policy, .exact(10), .{ .partition = 91, .next_lsn = 4 });
    root = try index.acquire(root, 4, claim, policy, .exact(10), .{ .partition = 91, .next_lsn = 4 });
    store.end();
    try t.expectEqual(@as(u64, 2), root.active);
    try t.expect(try index.firstEligible(root, 999) == null);
    const active = root;
    const beta_visible: s.QueueTimeRun.Event = .{ .at_ms = 0, .offset = 1, .epoch = 0 };
    const beta_deadline: s.QueueTimeRun.Event = .{ .at_ms = 110, .offset = 1, .epoch = 1 };
    const filter: Index.TimerFilter = .{ .index = index };
    try t.expect(try filter.keep(Index.timerBasis(first.root), .visible, beta_visible));
    try t.expect(!try filter.keep(Index.timerBasis(active), .visible, beta_visible));
    try t.expect(try filter.keep(Index.timerBasis(active), .lease, beta_deadline));
    try t.expectError(error.InvalidQueueSchedule, filter.keep(Index.timerBasis(first.root), .lease, beta_deadline));
    // Replace all volatile pages and object handles, retaining only the candidate
    // root. This tests the index, not WAL acceptance or process-death recovery.
    store.deinit();
    objects.deinit();
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(probe.allocator(), t.io, tmp.dir, "objects");
    store = try s.TreeStore.init(probe.allocator(), objects.objectStore(), 1);
    affinity.clear();
    bitmap = .{ .store = &store, .objects = objects.objectStore() };
    index.store = &store;
    index.bitmap = &bitmap;
    var canonical: [8192]u8 = undefined;
    const alpha = (try index.head(root, try key(&declaration, "alpha", &canonical))).?;
    try t.expectEqualDeep(Index.Head{ .first = 0, .last = 3 }, alpha);
    store.clearCache();
    const reads = objects.range_reads;
    probe.begin(true);
    for (0..100) |_| try t.expectEqualDeep(alpha, (try index.head(root, try key(&declaration, "ALPHA", &canonical))).?);
    try probe.verify();
    try t.expectEqual(reads, objects.range_reads);
    probe.begin(false);
    try t.expectEqual(@as(?u64, 2), (try index.item(root, 0)).next_key);
    try t.expectEqual(@as(?u64, 3), (try index.item(root, 2)).next_key);
    try t.expectEqual(@as(u64, 0), (try index.firstEligible(root, 1000)).?.offset);
    const leased_beta = try index.item(root, 1);
    const ack: p.StreamQueue.Settlement = .{ .operation = operation(4), .lease = leased_beta.lease.?, .action = .ack };
    try store.begin(8 * 1024 * 1024);
    root = try index.settle(root, ack, policy, .exact(20), .{ .partition = 91, .next_lsn = 5 }, try key(&declaration, "BETA", &canonical));
    store.end();
    try t.expect(try index.head(root, try key(&declaration, "beta", &canonical)) == null);
    try t.expectEqual(@as(u64, 1), root.terminal);
    // Filtering still uses the retained frozen roots after disk reopen and ACK.
    const reopened_filter: Index.TimerFilter = .{ .index = index };
    try t.expect(try reopened_filter.keep(Index.timerBasis(active), .lease, beta_deadline));
    try t.expect(!try reopened_filter.keep(Index.timerBasis(root), .lease, beta_deadline));
    try t.expect(!try reopened_filter.keep(Index.timerBasis(root), .visible, .{ .at_ms = 0, .offset = 1, .epoch = 1 }));
    var missing = Index.timerBasis(root);
    missing.sidecars = null;
    try t.expectError(error.InvalidQueueTimeMerge, reopened_filter.keep(missing, .lease, beta_deadline));
    try t.expect(try index.firstExpired(root, 109) == null);
    try t.expectEqual(@as(u64, 4), (try index.firstExpired(root, 110)).?.offset);
    try store.begin(8 * 1024 * 1024);
    root = try index.expire(root, 4, policy, .exact(500), .{ .partition = 91, .next_lsn = 6 });
    store.end();
    try t.expectEqual(@as(u64, 111), (try index.item(root, 4)).visible_ms);
    try t.expect(!try reopened_filter.keep(Index.timerBasis(root), .lease, .{ .at_ms = 110, .offset = 4, .epoch = 1 }));
    try t.expect(try reopened_filter.keep(Index.timerBasis(root), .visible, .{ .at_ms = 111, .offset = 4, .epoch = 1 }));
    try t.expectEqual(@as(u64, 4), (try index.firstEligible(root, 500)).?.offset);
    try store.begin(8 * 1024 * 1024);
    root = try index.acquire(root, 0, .{ .target = second.target, .operation = operation(5), .maximum = 1, .lease_ms = 100 }, policy, .exact(1000), .{ .partition = 91, .next_lsn = 7 });
    const alpha_lease = (try index.item(root, 0)).lease.?;
    root = try index.settle(root, .{ .operation = operation(6), .lease = alpha_lease, .action = .ack }, policy, .exact(1001), .{ .partition = 91, .next_lsn = 8 }, try key(&declaration, "alpha", &canonical));
    store.end();
    try t.expectEqualDeep(Index.Head{ .first = 2, .last = 3 }, (try index.head(root, try key(&declaration, "ALPHA", &canonical))).?);
    try t.expectEqual(@as(u64, 2), (try index.firstEligible(root, 1001)).?.offset);
    try store.begin(8 * 1024 * 1024);
    root = try index.acquire(root, 2, .{ .target = second.target, .operation = operation(7), .maximum = 1, .lease_ms = 100 }, policy, .exact(1001), .{ .partition = 91, .next_lsn = 9 });
    const successor_lease = (try index.item(root, 2)).lease.?;
    try t.expectError(error.QueueNotEligible, index.acquire(root, 3, claim, policy, .exact(1001), .{ .partition = 91, .next_lsn = 10 }));
    root = try index.settle(root, .{ .operation = operation(8), .lease = successor_lease, .action = .ack }, policy, .exact(1002), .{ .partition = 91, .next_lsn = 10 }, try key(&declaration, "aLPHa", &canonical));
    store.end();
    try t.expect(try (try index.sidecar(root, try index.item(root, 0))).terminal());
    try t.expect(!try (try index.sidecar(root, try index.item(root, 3))).terminal());
    // Earlier roots retain their old bits and lease metadata after every change.
    try t.expectEqual(@as(u64, 1), (try index.firstEligible(first.root, 0)).?.offset);
    try t.expectEqual(s.Tack.State.available, try index.state(first.root, try index.item(first.root, 1)));
}

test "queue index backlog exceeds resident pages and same-batch claims keep disjoint states" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var store = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer store.deinit();
    var scratch: std.heap.ArenaAllocator = .init(t.allocator);
    defer scratch.deinit();
    var bitmap: s.BitmapDirectory = .{ .store = &store, .objects = objects.objectStore() };
    var container: s.BitmapDirectory.Container = .{};
    var key_buffer: [8192]u8 = undefined;
    var definition = support.definition(.queue);
    definition.configuration.partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 };
    definition.configuration.policy.queue.ordering = .unordered;
    definition.configuration.policy.queue.key_column = null;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    const timer_workspace = try t.allocator.create(s.QueueSchedule.Workspace);
    defer t.allocator.destroy(timer_workspace);
    const index: Index = .{ .store = &store, .scratch = &scratch, .bitmap = &bitmap, .container = &container, .key_buffer = &key_buffer, .timer_workspace = timer_workspace, .timer_seed = .{ .definition = p.Growth.current_definition, .interpretation = (try declaration.stored()).declaration.interpretation, .partition = 0 } };
    const names: [40][]const u8 = @splat("same key, unordered");
    const delays: [40]u64 = @splat(0);
    try store.begin(1);
    try t.expectError(error.StorageCandidateTooLarge, enqueue(index, .empty, &declaration, 1, 2, &names, &delays));
    store.end();
    try store.begin(8 * 1024 * 1024);
    const appended = try enqueue(index, .empty, &declaration, 1, 2, &names, &delays);
    store.end();
    var root = appended.root;
    try t.expect(root.keys == null and root.scheduled == 40);
    const claim: p.StreamQueue.Claim = .{ .target = appended.target, .operation = operation(2), .maximum = 4, .lease_ms = 100 };
    try store.begin(8 * 1024 * 1024);
    for (0..4) |offset| root = try index.acquire(root, offset, claim, definition.configuration.policy.queue, .exact(10), .{ .partition = 91, .next_lsn = 3 });
    store.end();
    store.clearCache();
    try t.expect(root.active == 4 and root.scheduled == 36);
    try t.expectEqual(@as(u64, 4), (try index.firstEligible(root, 10)).?.offset);
    try t.expectEqual(@as(u64, 0), (try index.firstExpired(root, 110)).?.offset);
    const manifest = try index.sidecar(root, try index.item(root, 0));
    try t.expectEqual(@as(u64, 36), manifest.states[0].cardinality);
    try t.expectEqual(@as(u64, 4), manifest.states[1].cardinality);
    var audit = try s.Tack.Audit.init(manifest);
    while (!try audit.page(&bitmap, &container)) {}
    for (0..40) |offset| {
        const item = try index.item(root, offset);
        try t.expectEqual(@as(u64, @intFromBool(offset < 4)), item.attempts);
        try t.expectEqual(if (offset < 4) s.Tack.State.acquired else s.Tack.State.available, try index.state(root, item));
    }
    // Exact unchanged original root still exposes every offset as available.
    for (0..4) |offset| try t.expectEqual(s.Tack.State.available, try index.state(appended.root, try index.item(appended.root, offset)));
    const filter: Index.TimerFilter = .{ .index = index };
    var inconsistent = Index.timerBasis(root);
    inconsistent.sidecars = appended.root.sidecars;
    try t.expectError(error.QueueStateConflict, filter.keep(inconsistent, .lease, .{ .at_ms = 110, .offset = 0, .epoch = 1 }));
    const lease = (try index.item(root, 0)).lease.?;
    try store.begin(8 * 1024 * 1024);
    defer store.end();
    const renewed = try index.settle(root, .{ .operation = operation(3), .lease = lease, .action = .{ .extend = .{ .expires_ms = 150 } } }, definition.configuration.policy.queue, .exact(20), .{ .partition = 91, .next_lsn = 4 }, null);
    try t.expect(!try filter.keep(Index.timerBasis(renewed), .lease, .{ .at_ms = 110, .offset = 0, .epoch = 1 }));
    try t.expect(try filter.keep(Index.timerBasis(renewed), .lease, .{ .at_ms = 150, .offset = 0, .epoch = 1 }));
    var exhausted_policy = definition.configuration.policy.queue;
    exhausted_policy.maximum_attempts = 1;
    const blocked = try index.settle(renewed, .{ .operation = operation(4), .lease = (try index.item(renewed, 0)).lease.?, .action = .{ .nack = .{ .visible_ms = 0 } } }, exhausted_policy, .exact(30), .{ .partition = 91, .next_lsn = 5 }, null);
    try t.expect(!try filter.keep(Index.timerBasis(blocked), .visible, .{ .at_ms = 0, .offset = 0, .epoch = 1 }));
    try t.expect(!try filter.keep(Index.timerBasis(blocked), .lease, .{ .at_ms = 150, .offset = 0, .epoch = 1 }));
}
