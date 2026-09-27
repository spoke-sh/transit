const std = @import("std");
const t = std.testing;
const lib = @import("root.zig");
const p = lib.station.protocol;
const Turn = lib.station.GrowingTurn;
const Pub = lib.station.Publication;
const Index = lib.station.ImmutableIndex;
const Service = lib.Service;
const m = lib.Model;
const Turns = struct {
    state: std.AutoHashMapUnmanaged(p.Value, p.Value) = .empty,
    revision: u64 = 1,
    input: u64 = 1,
    denied: bool = false,
    accepted_outputs: usize = 0,
    fn deinit(self: *Turns) void {
        self.state.deinit(t.allocator);
    }
    fn read(raw: *anyopaque, _: p.Growth.View, address: p.Value) !?p.Value {
        const self: *Turns = @ptrCast(@alignCast(raw));
        if (self.denied) return error.AccessDenied;
        return self.state.get(address);
    }
    fn capture(self: *Turns) !Turn {
        return Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 2, .principal = 65536, .generation = 3, .input = self.input, .process_revision = self.revision, .resource = 7, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read });
    }
    fn commit(self: *Turns, turn: Turn) !void {
        try turn.validate();
        for (turn.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |bytes| try self.state.put(t.allocator, mutation.key, bytes) else _ = self.state.remove(mutation.key);
        };
        for (turn.decision.outputs) |output| if (output != null) {
            self.accepted_outputs += 1;
        };
        self.revision += 1;
        self.input += 1;
    }
};
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
