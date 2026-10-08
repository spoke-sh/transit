const std = @import("std");
const t = std.testing;
const lib = @import("root.zig");
const p = lib.station.protocol;
const Turn = lib.station.Turn;
const Pub = lib.station.Publication;
const Index = lib.station.ImmutableIndex;
const Service = lib.Service;
const m = lib.Model;
const Turns = @import("test_store.zig");

const service: Service = .{ .resource = 7, .document = 17 };
const limits: Pub.Limits = .{ .record_bytes = 4096, .staging_bytes = 4096, .staging_records = 1 };
fn makeChange(replica: u64, first: u64, ops: []const m.Operation) m.Change {
    var c: m.Change = .{ .document = 17, .epoch = 1, .replica = replica, .first = first, .len = @intCast(ops.len) };
    @memcpy(c.operations[0..ops.len], ops);
    return c;
}
fn setup(store: *Turns) !void {
    var turn = try store.capture();
    try service.create(&turn, 1, limits);
    try store.commit(turn);
}
fn prepare(store: *Turns, id: u64, change: m.Change, nodes: u32) !Service.Job {
    var turn = try store.capture();
    const j = try service.prepare(&turn, id, change, nodes);
    try store.commit(turn);
    return j;
}
fn upload(store: *Turns, id: u64, change: m.Change) !void {
    for (0..32) |_| {
        var turn = try store.capture();
        const done = try service.upload(&turn, id, change);
        try store.commit(turn);
        if (done) return;
    }
    return error.UploadDidNotComplete;
}
fn finish(store: *Turns, id: u64) !u64 {
    for (0..10000) |_| {
        var turn = try store.capture();
        const outcome = try service.advance(&turn, id);
        switch (outcome) {
            .progress => {},
            .accepted, .duplicate => |revision| {
                try store.commit(turn);
                return revision;
            },
        }
        try store.commit(turn);
    }
    return error.DocumentDidNotComplete;
}
fn expectClean(turn: Turn) !void {
    for (turn.decision.mutations) |mutation| try t.expectEqual(null, mutation);
}

test "bounded register metadata counts conflicts without exposing application values and rechecks authority" {
    var store: Turns = .{};
    defer store.deinit();
    try setup(&store);
    var first = makeChange(1, 1, &.{.{ .assign = .{ .field = try m.Name.init("a"), .value = .{ .string = try m.Bytes.init("private application value") } } }});
    first.len = 8;
    for (1..8) |index| first.operations[index] = .{ .assign = .{ .field = try m.Name.init(&.{@as(u8, @intCast('a' + index))}), .value = .null_value } };
    _ = try prepare(&store, 1, first, 512);
    try upload(&store, 1, first);
    _ = try finish(&store, 1);
    const second = makeChange(2, 9, &.{ .{ .assign = .{ .field = try m.Name.init("a"), .value = .{ .string = try m.Bytes.init("another private value") } } }, .{ .assign = .{ .field = try m.Name.init("z"), .value = .{ .unsigned = 42 } } } });
    _ = try prepare(&store, 2, second, 512);
    try upload(&store, 2, second);
    _ = try finish(&store, 2);
    var turn = try store.capture();
    const page = try service.readRegisterMetadata(&turn, 2, null);
    try t.expectEqual(@as(u8, 8), page.registers);
    try t.expectEqual(@as(u8, 1), page.conflicts);
    try t.expectEqual(@as(u8, 9), page.assignments);
    try t.expect(page.next != null);
    const last = try service.readRegisterMetadata(&turn, 2, page.next);
    try t.expectEqual(@as(u8, 1), last.registers);
    try t.expectEqual(@as(u8, 0), last.conflicts);
    try t.expectEqual(null, last.next);
    try t.expectEqual(@as(u8, 0), (try service.readRegisterMetadata(&turn, 1, null)).conflicts);
    const encoded = try std.json.Stringify.valueAlloc(t.allocator, page, .{});
    defer t.allocator.free(encoded);
    try t.expect(std.mem.indexOf(u8, encoded, "private") == null);
    try t.expectError(error.InvalidDocumentCursor, service.readRegisterMetadata(&turn, 2, try Index.Key.init("invalid")));
    store.denied = true;
    turn = try store.capture();
    try t.expectError(error.AccessDenied, service.readRegisterMetadata(&turn, 2, page.next));
    store.denied = false;
    turn = try store.capture();
    try service.retire(&turn);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.DocumentRetired, service.readRegisterMetadata(&turn, 2, page.next));
}

test "every staging turn can be discarded or recovered and final acceptance is atomic within four mutations" {
    var store: Turns = .{};
    defer store.deinit();
    try setup(&store);
    const c = makeChange(1, 1, &.{
        .{ .assign = .{ .field = try m.Name.init("text"), .value = .text } },
        .{ .insert = .{ .object = .{ .counter = 1, .replica = 1 }, .value = .{ .character = 0x1f642 } } },
        .{ .assign = .{ .field = try m.Name.init("nested"), .value = .map } },
        .{ .assign = .{ .object = .{ .counter = 3, .replica = 1 }, .field = try m.Name.init("count"), .value = .{ .signed = 42 } } },
    });
    _ = try prepare(&store, 100, c, 512);
    try upload(&store, 100, c);
    var progress: usize = 0;
    for (0..10000) |_| {
        var discarded = try store.capture();
        const first = try service.advance(&discarded, 100);
        var view = try store.capture();
        try t.expectEqual(@as(u64, 0), (try service.head(&view)).state.revision);
        var turn = try store.capture(); // No candidate state survives replacement.
        const recovered = try service.advance(&turn, 100);
        try t.expectEqualDeep(first, recovered);
        try t.expectEqualDeep(discarded.decision.mutations, turn.decision.mutations);
        if (recovered == .accepted) {
            // One framework record still fits in the same acceptance decision.
            try turn.write(try p.Value.init("framework"), try p.Value.init("accepted"));
            try turn.cast(9, try p.Value.init("accepted"));
            try store.commit(turn);
            try t.expectEqual(@as(usize, 1), store.accepted_outputs);
            var accepted = try store.capture();
            try t.expectEqual(@as(u64, 1), (try service.head(&accepted)).state.revision);
            const doc = try service.open(&accepted, 1);
            var reader: Index.Reader(*Turn) = .{ .publication = service.publication(), .source = &accepted };
            const path = [_]m.Name{ try m.Name.init("nested"), try m.Name.init("count") };
            try t.expectEqual(@as(i64, 42), (try doc.path(&reader, &path)).assignments[0].value.signed);
            try t.expectEqual(.missing, (try (try service.open(&accepted, 0)).field(&reader, .root, try m.Name.init("nested"))).status());
            try t.expectEqual(@as(u64, 0), (try service.head(&accepted)).active_job);
            const duplicate = try service.advance(&accepted, 100);
            try t.expectEqual(@as(u64, 1), duplicate.duplicate);
            try expectClean(accepted);
            break;
        }
        try store.commit(turn);
        progress += 1;
    } else return error.DocumentDidNotComplete;
    try t.expect(progress > 20);
}

test "request and reserved identities freeze before upload and duplicate changes preserve original acceptance" {
    var store: Turns = .{};
    defer store.deinit();
    try setup(&store);
    const c = makeChange(1, 1, &.{.{ .assign = .{ .field = try m.Name.init("x"), .value = .null_value } }});
    const j = try prepare(&store, 1, c, 64);
    var turn = try store.capture();
    try t.expectEqualDeep(j, try service.prepare(&turn, 1, c, 1));
    try expectClean(turn);
    var changed = c;
    changed.operations[0].assign.value = .{ .signed = 3 };
    try t.expectError(error.DocumentIdentityConflict, service.upload(&turn, 1, changed));
    try expectClean(turn);
    try t.expectError(error.DocumentBusy, service.prepare(&turn, 2, changed, 64));
    try expectClean(turn);
    try upload(&store, 1, c);
    try t.expectEqual(@as(u64, 1), try finish(&store, 1));
    const repeated = try prepare(&store, 2, c, 64);
    try upload(&store, 2, c);
    try t.expectEqual(@as(u64, 1), try finish(&store, 2));
    turn = try store.capture();
    try t.expectEqual(@as(u64, 1), (try service.head(&turn)).state.revision);
    try t.expectEqual(repeated.first_node, (try service.job(&turn, 2)).used_end);
    try t.expectError(error.DocumentJobStillRetained, service.collectRejected(&turn, 1));
    try expectClean(turn);
}

test "invalid or capacity-limited candidate is explicitly rejected and reclaimed without touching accepted roots" {
    var store: Turns = .{};
    defer store.deinit();
    try setup(&store);
    const c = makeChange(1, 1, &.{.{ .assign = .{ .field = try m.Name.init("x"), .value = .null_value } }});
    _ = try prepare(&store, 1, c, 64);
    try upload(&store, 1, c);
    _ = try finish(&store, 1);
    const bad = makeChange(2, 2, &.{ .{ .assign = .{ .field = try m.Name.init("candidate"), .value = .map } }, .{ .insert = .{ .object = .{ .counter = 2, .replica = 2 }, .value = .null_value } } });
    const j = try prepare(&store, 2, bad, 64);
    try upload(&store, 2, bad);
    for (0..1000) |_| {
        var turn = try store.capture();
        _ = service.advance(&turn, 2) catch |err| {
            try t.expectEqual(error.DocumentTypeError, err);
            try expectClean(turn);
            try service.reject(&turn, 2);
            try store.commit(turn);
            break;
        };
        try store.commit(turn);
    } else return error.InvalidChangeAccepted;
    for (0..1000) |_| {
        var turn = try store.capture();
        const done = try service.collectRejected(&turn, 2);
        try store.commit(turn);
        if (done) break;
    } else return error.CleanupDidNotComplete;
    var turn = try store.capture();
    try t.expectEqual(j.end_node, (try service.job(&turn, 2)).cleanup);
    try t.expectEqual(@as(u32, 0), (try service.publication().budget(&turn)).records);
    try t.expectError(error.DocumentJobClosed, service.upload(&turn, 2, bad));
    const doc = try service.open(&turn, 1);
    var reader: Index.Reader(*Turn) = .{ .publication = service.publication(), .source = &turn };
    try t.expectEqual(.null_value, (try doc.field(&reader, .root, try m.Name.init("x"))).status());
    try t.expectEqual(.missing, (try doc.field(&reader, .root, try m.Name.init("candidate"))).status());
    const short = makeChange(3, 2, &.{.{ .assign = .{ .field = try m.Name.init("z"), .value = .map } }});
    _ = try prepare(&store, 3, short, 1);
    try upload(&store, 3, short);
    for (0..100) |_| {
        turn = try store.capture();
        _ = service.advance(&turn, 3) catch |err| {
            try t.expectEqual(error.IndexCapacity, err);
            try expectClean(turn);
            try service.reject(&turn, 3);
            try store.commit(turn);
            break;
        };
        try store.commit(turn);
    } else return error.CapacityWasIgnored;
}

test "current denial and permanent retirement block old snapshots and delayed work" {
    var store: Turns = .{};
    defer store.deinit();
    try setup(&store);
    const c = makeChange(1, 1, &.{.{ .assign = .{ .field = try m.Name.init("x"), .value = .null_value } }});
    _ = try prepare(&store, 1, c, 64);
    try upload(&store, 1, c);
    _ = try finish(&store, 1);
    for ([_]bool{ false, true }) |resynchronize| {
        store.denied = false;
        var cached = try store.capture();
        cached.reader.cache_reads = true;
        _ = try service.readPath(&cached, 1, &.{try m.Name.init("x")});
        store.denied = true;
        if (resynchronize) {
            try t.expectError(error.AccessDenied, service.resynchronize(&cached, 1));
        } else {
            try t.expectError(error.AccessDenied, service.readPath(&cached, 1, &.{try m.Name.init("x")}));
        }
        try t.expectError(error.AccessDenied, cached.validate());
    }
    store.denied = true;
    var turn = try store.capture();
    try t.expectError(error.AccessDenied, service.open(&turn, 1));
    try t.expectError(error.AccessDenied, service.advance(&turn, 1));
    try expectClean(turn);
    store.denied = false;
    turn = try store.capture();
    try service.retire(&turn);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.DocumentRetired, service.open(&turn, 0));
    try t.expectError(error.DocumentRetired, service.open(&turn, 1));
    try t.expectError(error.DocumentRetired, service.prepare(&turn, 2, c, 64));
    try t.expectError(error.DocumentRetired, service.create(&turn, 1, limits));
    try t.expectEqual(.accepted, (try service.job(&turn, 1)).phase);
}

test "current read pages pin accepted revisions and resync supplies causal basis" {
    var store: Turns = .{};
    defer store.deinit();
    try setup(&store);
    const c = makeChange(1, 1, &.{ .{ .assign = .{ .field = try m.Name.init("body"), .value = .text } }, .{ .insert = .{ .object = .{ .counter = 1, .replica = 1 }, .value = .{ .character = 'a' } } } });
    _ = try prepare(&store, 1, c, 128);
    try upload(&store, 1, c);
    _ = try finish(&store, 1);
    var turn = try store.capture();
    const sync = try service.resynchronize(&turn, 1);
    try t.expectEqual(@as(u64, 2), sync.previous_counter);
    try t.expectEqual(@as(u64, 2), sync.clock);
    const cursor: Service.PageCursor = .{ .revision = 1, .object = .{ .counter = 1, .replica = 1 } };
    const first = try service.readSequence(&turn, cursor);
    try t.expectEqual(@as(u8, 1), first.len);
    try t.expectEqual(null, first.next);
    const path = [_]m.Name{try m.Name.init("body")};
    try t.expectEqual(.object, (try service.readPath(&turn, 1, &path)).status());
    const c2 = makeChange(2, 3, &.{.{ .insert = .{ .object = cursor.object, .after = .{ .counter = 2, .replica = 1 }, .value = .{ .character = 'b' } } }});
    _ = try prepare(&store, 2, c2, 128);
    try upload(&store, 2, c2);
    _ = try finish(&store, 2);
    turn = try store.capture();
    try t.expectEqual(@as(u8, 1), (try service.readSequence(&turn, cursor)).len);
    var latest = cursor;
    latest.revision = 2;
    try t.expectEqual(@as(u8, 2), (try service.readSequence(&turn, latest)).len);
    store.denied = true;
    turn = try store.capture();
    try t.expectError(error.AccessDenied, service.readSequence(&turn, cursor));
    try t.expectError(error.AccessDenied, service.resynchronize(&turn, 2));
}

const Checkpoint = lib.Checkpoint;
fn checkpoint(store: *Turns, id: u64) !u64 {
    var turn = try store.capture();
    try Checkpoint.begin(service, &turn, id);
    try store.commit(turn);
    for (0..10000) |_| {
        turn = try store.capture();
        const step = try Checkpoint.step(service, &turn, id);
        try store.commit(turn);
        if (step == .complete) return step.complete;
    }
    return error.CheckpointDidNotComplete;
}

test "simulation: Document checkpoint head and epoch publish only at the accepted boundary" {
    var random = std.Random.DefaultPrng.init(t.random_seed);
    var store: Turns = .{};
    defer store.deinit();
    try setup(&store);
    const edit = makeChange(1, 1, &.{.{ .assign = .{ .field = try m.Name.init("value"), .value = .{ .unsigned = 42 } } }});
    _ = try prepare(&store, 1, edit, 128);
    try upload(&store, 1, edit);
    _ = try finish(&store, 1);
    var turn = try store.capture();
    const before = try service.head(&turn);
    try service.configureMergeWindow(&turn, 1);
    try store.commit(turn);
    turn = try store.capture();
    try Checkpoint.begin(service, &turn, 2);
    try store.commit(turn);
    for (0..1000) |step| {
        var candidate = try store.capture();
        const proposed = try Checkpoint.step(service, &candidate, 2);
        turn = try store.capture();
        try t.expectEqual(before.state.revision, (try service.head(&turn)).state.revision);
        try t.expectEqual(@as(u64, 0), (try service.head(&turn)).floor);
        _ = try service.open(&turn, 0);
        const discard = random.random().boolean();
        if (discard) {
            const recovered = try Checkpoint.step(service, &turn, 2);
            try t.expectEqualDeep(proposed, recovered);
            try t.expectEqualDeep(candidate.decision.mutations, turn.decision.mutations);
            candidate = turn;
        }
        try store.commit(candidate);
        if (t.environ.containsConstant("TRANSIT_SIMULATION_TRACE")) std.debug.print("SIMULATION {{\"domain\":\"checkpoint\",\"step\":{d},\"discard\":{},\"complete\":{}}}\n", .{ step, discard, proposed == .complete });
        if (proposed == .complete) break;
    } else return error.CheckpointDidNotComplete;
    turn = try store.capture();
    const head = try service.head(&turn);
    try t.expectEqual(@as(u64, 2), head.state.revision);
    try t.expectEqual(@as(u64, 2), head.floor);
    try t.expectEqual(@as(u64, 2), head.state.epoch);
    try t.expectError(error.DocumentHistoryGap, service.open(&turn, 1));
    try t.expectError(error.DocumentResyncRequired, service.prepare(&turn, 3, edit, 128));
}

test "unlimited checkpoints retain duplicate and deletion evidence; finite floor changes only at final publication" {
    var store: Turns = .{};
    defer store.deinit();
    try setup(&store);
    const boot = makeChange(1, 1, &.{ .{ .assign = .{ .field = try m.Name.init("body"), .value = .text } }, .{ .insert = .{ .object = .{ .counter = 1, .replica = 1 }, .value = .{ .character = 'x' } } }, .{ .assign = .{ .field = try m.Name.init("name"), .value = .null_value } } });
    _ = try prepare(&store, 1, boot, 128);
    try upload(&store, 1, boot);
    _ = try finish(&store, 1);
    const removed = makeChange(2, 4, &.{ .{ .delete_element = .{ .object = .{ .counter = 1, .replica = 1 }, .element = .{ .counter = 2, .replica = 1 } } }, .{ .remove = .{ .field = try m.Name.init("name"), .observed = try m.Observed.init(&.{.{ .counter = 3, .replica = 1 }}) } } });
    _ = try prepare(&store, 2, removed, 128);
    try upload(&store, 2, removed);
    _ = try finish(&store, 2);
    var turn = try store.capture();
    const before = (try service.head(&turn)).state;
    try t.expectEqual(@as(u64, 3), try checkpoint(&store, 10));
    turn = try store.capture();
    const unlimited = try service.head(&turn);
    try t.expectEqual(@as(u64, 0), unlimited.floor);
    try t.expectEqual(@as(u64, 1), unlimited.state.epoch);
    try t.expectEqual(before.index.root.?.entries, unlimited.state.index.root.?.entries);
    _ = try service.open(&turn, 0);
    _ = try service.open(&turn, 1);
    try t.expectError(error.DocumentCheckpointBoundary, service.acceptedChange(&turn, 3));
    _ = try prepare(&store, 3, boot, 64);
    try upload(&store, 3, boot);
    try t.expectEqual(@as(u64, 1), try finish(&store, 3));
    turn = try store.capture();
    try service.configureMergeWindow(&turn, 1);
    try store.commit(turn);
    turn = try store.capture();
    try Checkpoint.begin(service, &turn, 11);
    try store.commit(turn);
    var progress_count: usize = 0;
    for (0..10000) |_| {
        var discarded = try store.capture();
        const candidate = try Checkpoint.step(service, &discarded, 11);
        turn = try store.capture();
        try t.expectEqual(@as(u64, 0), (try service.head(&turn)).floor);
        _ = try service.open(&turn, 1); // Staged replacement cannot hide old history.
        const recovered = try Checkpoint.step(service, &turn, 11);
        try t.expectEqualDeep(candidate, recovered);
        try t.expectEqualDeep(discarded.decision.mutations, turn.decision.mutations);
        try store.commit(turn);
        if (recovered == .complete) {
            try t.expectEqual(@as(u64, 4), recovered.complete);
            break;
        }
        progress_count += 1;
    } else return error.CheckpointDidNotComplete;
    try t.expect(progress_count > 20);
    turn = try store.capture();
    const finite = try service.head(&turn);
    try t.expectEqual(@as(u64, 4), finite.floor);
    try t.expectEqual(@as(u64, 2), finite.state.epoch);
    try t.expect(finite.state.index.root.?.entries < unlimited.state.index.root.?.entries);
    try t.expectError(error.DocumentHistoryGap, service.open(&turn, 3));
    try t.expectError(error.DocumentResyncRequired, service.prepare(&turn, 4, boot, 64));
    const sync = try service.resynchronize(&turn, 1);
    try t.expectEqual(@as(u64, 3), sync.previous_counter);
    try t.expectEqual(@as(u64, 5), sync.clock);
    var fresh = makeChange(1, 6, &.{.{ .insert = .{ .object = .{ .counter = 1, .replica = 1 }, .after = .{ .counter = 2, .replica = 1 }, .value = .{ .character = 0x1f642 } } }});
    fresh.epoch = sync.epoch;
    fresh.previous = sync.previous_counter;
    _ = try prepare(&store, 4, fresh, 128);
    try upload(&store, 4, fresh);
    try t.expectEqual(@as(u64, 5), try finish(&store, 4));
    turn = try store.capture();
    const text_page = try service.readSequence(&turn, .{ .revision = 5, .object = .{ .counter = 1, .replica = 1 } });
    try t.expectEqual(@as(u8, 1), text_page.len);
    try t.expectEqual(@as(u32, 0x1f642), text_page.items[0].values.assignments[0].value.character);
    const tail = try service.acceptedChange(&turn, 5);
    var expected_bytes: [m.max_change_bytes]u8 = undefined;
    var actual_bytes: [m.max_change_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, try lib.codec.encode(fresh, &expected_bytes), try lib.codec.encode(tail, &actual_bytes));
    const retained = try service.readSequence(&turn, .{ .revision = 4, .object = .{ .counter = 1, .replica = 1 } });
    try t.expectEqual(@as(u8, 0), retained.len);
    // Compaction cannot permit reuse of an old replica's operation counters.
    var recycled = boot;
    recycled.epoch = 2;
    _ = try prepare(&store, 5, recycled, 64);
    try upload(&store, 5, recycled);
    turn = try store.capture();
    try t.expectError(error.DocumentIdentityConflict, service.advance(&turn, 5));
    try expectClean(turn);
    try service.reject(&turn, 5);
    try store.commit(turn);
}

test "abandoned checkpoint nodes are reclaimable; accepted nodes require permanent retirement" {
    var store: Turns = .{};
    defer store.deinit();
    try setup(&store);
    const c = makeChange(1, 1, &.{.{ .assign = .{ .field = try m.Name.init("x"), .value = .null_value } }});
    _ = try prepare(&store, 1, c, 64);
    try upload(&store, 1, c);
    _ = try finish(&store, 1);
    var turn = try store.capture();
    try Checkpoint.begin(service, &turn, 2);
    try store.commit(turn);
    for (0..14) |_| {
        turn = try store.capture();
        _ = try Checkpoint.step(service, &turn, 2);
        try store.commit(turn);
    }
    turn = try store.capture();
    try Checkpoint.reject(service, &turn, 2);
    try store.commit(turn);
    for (0..1000) |_| {
        turn = try store.capture();
        const done = try Checkpoint.collectRejected(service, &turn, 2);
        try store.commit(turn);
        if (done) break;
    } else return error.CheckpointCleanupDidNotComplete;
    turn = try store.capture();
    const cp = try Checkpoint.inspect(service, &turn, 2);
    try t.expectEqual(cp.end_node, cp.cleanup);
    try t.expectEqual(@as(u32, 0), (try service.publication().budget(&turn)).records);
    try t.expectError(error.DocumentJobClosed, Checkpoint.begin(service, &turn, 2));
    try t.expectError(error.DocumentStillLive, service.collectRetired(&turn, 1));
    const path = [_]m.Name{try m.Name.init("x")};
    try t.expectEqual(.null_value, (try service.readPath(&turn, 1, &path)).status());
    _ = try checkpoint(&store, 3);
    turn = try store.capture();
    try t.expectError(error.DocumentStillLive, Checkpoint.collectRetired(service, &turn, 3));
    try service.retire(&turn);
    try store.commit(turn);
    for (0..1000) |_| {
        turn = try store.capture();
        const done = try service.collectRetired(&turn, 1);
        try store.commit(turn);
        if (done) break;
    } else return error.CleanupDidNotComplete;
    for (0..1000) |_| {
        turn = try store.capture();
        const done = try Checkpoint.collectRetired(service, &turn, 3);
        try store.commit(turn);
        if (done) break;
    } else return error.CheckpointCleanupDidNotComplete;
    turn = try store.capture();
    try t.expectError(error.DocumentRetired, service.open(&turn, 2));
    try t.expectError(error.DocumentRetired, service.create(&turn, 1, limits));
    const job = try service.job(&turn, 1);
    const descriptor = try service.publication().inspect(&turn, job.request);
    try t.expectEqual(.retired, descriptor.state);
    try t.expectEqual(descriptor.written, descriptor.collected);
}

const ReplayStore = struct {
    source: Index.Reader(*Turn),
    nodes: std.ArrayList([]const u8) = .empty,
    const base = 1 << 63;
    fn deinit(self: *ReplayStore) void {
        for (self.nodes.items) |bytes| t.allocator.free(bytes);
        self.nodes.deinit(t.allocator);
    }
    pub fn load(self: *ReplayStore, reference: Index.Reference, buffer: []u8) ![]const u8 {
        if (reference.id < base) return self.source.load(reference, buffer);
        const at = reference.id - base;
        if (at >= self.nodes.items.len) return error.SourceGap;
        const bytes = self.nodes.items[@intCast(at)];
        @memcpy(buffer[0..bytes.len], bytes);
        return buffer[0..bytes.len];
    }
    pub fn save(self: *ReplayStore, spec: Pub.Spec, bytes: []const u8) !u64 {
        try t.expectEqualDeep(spec, try Pub.Digest.of(Index.format, bytes));
        const copy = try t.allocator.dupe(u8, bytes);
        errdefer t.allocator.free(copy);
        try self.nodes.append(t.allocator, copy);
        return base + self.nodes.items.len - 1;
    }
};

test "checkpoint plus verified retained tail reconstructs text and conflict metadata without current-root substitution" {
    var store: Turns = .{};
    defer store.deinit();
    try setup(&store);
    const boot = makeChange(1, 1, &.{ .{ .assign = .{ .field = try m.Name.init("body"), .value = .text } }, .{ .assign = .{ .field = try m.Name.init("title"), .value = .null_value } } });
    _ = try prepare(&store, 1, boot, 128);
    try upload(&store, 1, boot);
    _ = try finish(&store, 1);
    try t.expectEqual(@as(u64, 2), try checkpoint(&store, 2));
    const tail = makeChange(2, 3, &.{ .{ .insert = .{ .object = .{ .counter = 1, .replica = 1 }, .value = .{ .character = 0x1f642 } } }, .{ .assign = .{ .field = try m.Name.init("title"), .value = .{ .string = try m.Bytes.init("new") } } } });
    _ = try prepare(&store, 3, tail, 128);
    try upload(&store, 3, tail);
    _ = try finish(&store, 3);
    var turn = try store.capture();
    const basis = try service.open(&turn, 2);
    const retained = try service.acceptedChange(&turn, 3);
    // Pure reconstruction uses scratch immutable nodes, never publishing a
    // second authoritative head or relying on the already materialized root.
    var scratch: ReplayStore = .{ .source = .{ .publication = service.publication(), .source = &turn } };
    defer scratch.deinit();
    const rebuilt = (try basis.apply(&scratch, retained)).state;
    try t.expectEqual(@as(u64, 3), rebuilt.revision);
    try t.expectEqual(.conflict, (try rebuilt.field(&scratch, .root, try m.Name.init("title"))).status());
    var cursor: lib.Document.SequenceCursor = .{};
    const first = (try rebuilt.sequenceStep(&scratch, .{ .counter = 1, .replica = 1 }, &cursor)).item;
    try t.expectEqual(@as(u32, 0x1f642), first.values.assignments[0].value.character);
    const path = [_]m.Name{try m.Name.init("title")};
    const expected = try service.readPath(&turn, 3, &path);
    const actual = try rebuilt.path(&scratch, &path);
    try t.expectEqualDeep(expected.assignments[0..expected.len], actual.assignments[0..actual.len]);
    try t.expect((try rebuilt.apply(&scratch, retained)).duplicate);
}
