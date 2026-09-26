const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const p = root.p;
const Exchange = root.Exchange;
const Turn = root.station.GrowingTurn;
const Pub = root.Publication;
const Map = std.AutoHashMapUnmanaged(p.Value, p.Value);
const Store = struct {
    state: Map = .empty,
    revision: u64 = 1,
    input: u64 = 1,
    reads: usize = 0,
    fail_read: bool = false,
    fn deinit(self: *Store) void {
        self.state.deinit(t.allocator);
    }
    fn capture(self: *Store) !Turn {
        self.input += 1;
        self.reads = 0;
        return Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 2, .principal = 65536, .generation = 3, .input = self.input, .process_revision = self.revision, .resource = 7, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read });
    }
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
        const self: *Store = @ptrCast(@alignCast(raw));
        self.reads += 1;
        if (self.fail_read) return error.Unavailable;
        return self.state.get(key);
    }
    fn commit(self: *Store, turn: Turn) !void {
        try turn.validate();
        for (turn.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| try self.state.put(t.allocator, mutation.key, value) else _ = self.state.remove(mutation.key);
        };
        self.revision += 1;
    }
    fn create(self: *Store, policy: Pub.Limits) !Pub {
        var turn = try self.capture();
        const pubn = try Pub.create(&turn, std.math.maxInt(u64), policy);
        try self.commit(turn);
        return pubn;
    }
    fn stage(self: *Store, pubn: Pub, id: u64, bytes: []const u8) !Pub.Spec {
        const spec = try Pub.Digest.of(7, bytes);
        var turn = try self.capture();
        try t.expectEqual(.changed, try pubn.begin(&turn, id, spec));
        try self.commit(turn);
        for (0..spec.chunks()) |i| {
            turn = try self.capture();
            const part = bytes[i * Pub.chunk_bytes ..][0..try spec.size(@intCast(i))];
            try t.expectEqual(.changed, try pubn.append(&turn, id, @intCast(i), part));
            try t.expectEqual(.duplicate, try pubn.append(&turn, id, @intCast(i), part));
            try t.expect(self.reads <= 3);
            try self.commit(turn);
        }
        return spec;
    }
};
const limits: root.Limits = .{ .segment_bytes = 1024, .capture_bytes = 8192, .segments = 64 };
fn exchange(store: *Store, id: u64) !Exchange {
    var turn = try store.capture();
    const result = try Exchange.create(&turn, id, .{ .caller = 9, .input = 8, .protocol = 1 }, limits, 10000);
    try store.commit(turn);
    return result;
}
fn bind(store: *Store, ex: Exchange) !void {
    var turn = try store.capture();
    if ((try ex.inspect(&turn)).segments == 0) {
        try segment(store, ex, 0, 1, "request");
        turn = try store.capture();
    }
    _ = try ex.commitIntent(&turn);
    const payload = turn.decision.effect.?;
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(.duplicate, try ex.commitIntent(&turn));
    try t.expectEqual(null, turn.decision.effect);
    var forged = payload;
    forged.data[forged.len - 1] ^= 1;
    try t.expectError(error.ExchangeIdentityConflict, ex.bind(&turn, .{ .id = 19, .pid = 2, .payload = forged, .phase = .authorized, .attempt = 20, .executor = 7, .reconcile_before_ms = 10000 }));
    _ = try ex.bind(&turn, .{ .id = 19, .pid = 2, .payload = payload, .phase = .authorized, .attempt = 20, .executor = 7, .reconcile_before_ms = 10000 });
    try store.commit(turn);
}
fn segment(store: *Store, ex: Exchange, ordinal: u32, kind: u32, bytes: []const u8) !void {
    const spec = try Pub.Digest.of(1, bytes);
    var turn = try store.capture();
    _ = try ex.beginSegment(&turn, ordinal, kind, spec);
    try store.commit(turn);
    for (0..spec.chunks()) |i| {
        turn = try store.capture();
        _ = try ex.append(&turn, ordinal, @intCast(i), bytes[i * 256 ..][0..try spec.size(@intCast(i))]);
        try store.commit(turn);
    }
    turn = try store.capture();
    try t.expectEqual(.changed, try ex.sealSegment(&turn, ordinal));
    for (turn.decision.mutations) |slot| try t.expect(slot != null);
    try store.commit(turn);
}
test "finite segment coverage grows on disk shape, replay validates and retirement rejects old roots" {
    var store: Store = .{};
    defer store.deinit();
    const ex = try exchange(&store, std.math.maxInt(u64));
    try segment(&store, ex, 0, 1, "GET / HTTP/1.1\r\n\r\n");
    try bind(&store, ex);
    var body: [513]u8 = undefined;
    for (&body, 0..) |*b, i| b.* = @truncate(i * 13);
    for (1..42) |i| try segment(&store, ex, @intCast(i), 2, if (i == 1) &body else "captured");
    var turn = try store.capture();
    try t.expectError(error.IncompleteExchange, ex.open(&turn, &turn));
    _ = try ex.finish(&turn, 200);
    try store.commit(turn);
    var historical = try store.state.clone(t.allocator);
    defer historical.deinit(t.allocator);
    var old: Store = .{ .state = historical, .revision = store.revision };
    turn = try store.capture();
    var source = try old.capture();
    var cursor = try ex.open(&turn, &source);
    var count: usize = 0;
    while (true) {
        const part = try ex.read(&turn, &source, cursor);
        count += part.bytes.len;
        cursor = part.next orelse break;
    }
    try t.expectEqual(try ex.inspect(&turn), try root.Descriptor.decode(try (try ex.inspect(&turn)).encode()));
    try t.expectEqual(count, (try ex.inspect(&turn)).bytes);
    // Return a real prefix, then change current availability. The old complete
    // source remains intact and must not bypass that change.
    const opened = try ex.open(&turn, &source);
    const prefix = try ex.read(&turn, &source, opened);
    try t.expect(prefix.next != null);
    turn = try store.capture();
    _ = try ex.retire(&turn);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.ExchangeUnavailable, ex.read(&turn, &source, prefix.next.?));
    var steps: usize = 0;
    while (true) {
        turn = try store.capture();
        const done = try ex.collect(&turn);
        try store.commit(turn);
        steps += 1;
        if (done) break;
        try t.expect(steps < 200);
    }
    turn = try store.capture();
    try t.expectEqual(@as(u32, 42), (try ex.inspect(&turn)).collected);
    try t.expectError(error.ExchangeUnavailable, ex.open(&turn, &source));
    try t.expectError(error.ExchangeUnavailable, Exchange.create(&turn, ex.id, .{ .caller = 9, .input = 8, .protocol = 1 }, limits, 10000));
}
test "gaps, conflicting duplicates, terminal races and atomic rollback preserve capture" {
    var store: Store = .{};
    defer store.deinit();
    const ex = try exchange(&store, 1);
    var turn = try store.capture();
    try t.expectError(error.ExchangeGap, ex.beginSegment(&turn, 1, 2, try Pub.Digest.of(1, "a")));
    _ = try ex.beginSegment(&turn, 0, 2, try Pub.Digest.of(1, "a"));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.ExchangeIdentityConflict, ex.beginSegment(&turn, 0, 3, try Pub.Digest.of(1, "a")));
    try t.expectError(error.PublicationIdentityConflict, ex.beginSegment(&turn, 0, 2, try Pub.Digest.of(1, "b")));
    try t.expectError(error.ExchangeClosed, ex.finish(&turn, 200));
    _ = try ex.append(&turn, 0, 0, "a");
    try store.commit(turn);
    turn = try store.capture();
    try turn.put(try p.Value.init("unrelated"), .{});
    const before = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, ex.sealSegment(&turn, 0));
    try t.expectEqualDeep(before, turn.decision);
    turn = try store.capture();
    _ = try ex.sealSegment(&turn, 0);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(.duplicate, try ex.beginSegment(&turn, 0, 2, try Pub.Digest.of(1, "a")));
    try t.expectEqual(.duplicate, try ex.sealSegment(&turn, 0));
    try store.commit(turn);
    try bind(&store, ex);
    turn = try store.capture();
    _ = try ex.closeUnknown(&turn);
    try t.expectError(error.ExchangeClosed, ex.finish(&turn, 200));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.IncompleteExchange, ex.open(&turn, &turn));
    try t.expectError(error.ExchangeClosed, ex.beginSegment(&turn, 1, 2, try Pub.Digest.of(1, "a")));
}
test "quota refusal, interrupted staging cleanup and current read errors" {
    var store: Store = .{};
    defer store.deinit();
    const ex = try exchange(&store, 1);
    var turn = try store.capture();
    const before = turn.decision;
    try t.expectError(error.ExchangeCapacity, ex.beginSegment(&turn, 0, 1, .{ .format = 1, .length = 8193, .digest = @splat(0) }));
    try t.expectEqualDeep(before, turn.decision);
    _ = try ex.beginSegment(&turn, 0, 1, try Pub.Digest.of(1, "incomplete"));
    try store.commit(turn);
    turn = try store.capture();
    _ = try ex.closeUnknown(&turn);
    _ = try ex.retire(&turn);
    try store.commit(turn);
    var done = false;
    for (0..4) |_| {
        turn = try store.capture();
        done = try ex.collect(&turn);
        try store.commit(turn);
    }
    try t.expect(done);
    turn = try store.capture();
    try t.expectEqual(@as(u64, 0), (try ex.publication().budget(&turn)).bytes);
    store.fail_read = true;
    try t.expectError(error.Unavailable, ex.inspect(&turn));
    try t.expectError(error.Unavailable, turn.validate());
}
test "strict codecs reject unknown tags, trailing bytes and inconsistent counts" {
    var store: Store = .{};
    defer store.deinit();
    const ex = try exchange(&store, 1);
    var turn = try store.capture();
    const d = try ex.inspect(&turn);
    var encoded = try d.encode();
    encoded.data[4] = 99;
    try t.expectError(error.InvalidExchangeRecord, root.Descriptor.decode(encoded));
    encoded = try d.encode();
    encoded.len += 1;
    try t.expectError(error.InvalidExchangeRecord, root.Descriptor.decode(encoded));
    var invalid = d;
    invalid.bytes = 1;
    try t.expectError(error.InvalidExchangeRecord, invalid.encode());
    try t.expect(root.codec.size(root.Descriptor) <= 256);
    try t.expect(root.codec.size(root.Member) <= 256);
}

test "linked followups share a finite original budget and never renew lineage or deadline" {
    var store: Store = .{};
    defer store.deinit();
    const parent = try exchange(&store, 1);
    var turn = try store.capture();
    try parent.configureAttempts(&turn, 3);
    try store.commit(turn);
    try bind(&store, parent);
    turn = try store.capture();
    try t.expectError(error.ExchangePolicyChanged, parent.configureAttempts(&turn, 4));
    try t.expectError(error.ExchangeStillOpen, parent.followup(&turn, 2, .retry, 7, 1, limits));
    _ = try parent.closeUnknown(&turn);
    try store.commit(turn);
    turn = try store.capture();
    const before = turn.decision;
    try turn.put(try p.Value.init("unrelated"), .{});
    const private = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, parent.followup(&turn, 2, .retry, 7, 1, limits));
    try t.expectEqualDeep(private, turn.decision);
    turn.decision = before;
    const child = try parent.followup(&turn, 2, .retry, 7, 1, limits);
    try store.commit(turn);
    turn = try store.capture();
    _ = try parent.followup(&turn, 2, .retry, 7, 1, limits);
    for (turn.decision.mutations) |slot| try t.expectEqual(null, slot);
    try t.expectError(error.ExchangeIdentityConflict, parent.followup(&turn, 2, .cancel, 7, 1, limits));
    const original = try parent.inspect(&turn);
    const next = try child.inspect(&turn);
    try t.expectEqual(original.caller, next.caller);
    try t.expectEqual(original.input, next.input);
    try t.expectEqual(original.reconcile_before_ms, next.reconcile_before_ms);
    _ = try child.closeUnknown(&turn);
    try store.commit(turn);
    turn = try store.capture();
    const last = try child.followup(&turn, 3, .reconcile, 7, 1, limits);
    try store.commit(turn);
    turn = try store.capture();
    _ = try last.closeUnknown(&turn);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.ExchangeAttemptBudgetExceeded, last.followup(&turn, 4, .cancel, 7, 1, limits));
    try t.expectError(error.ExchangeAttemptBudgetExceeded, parent.followup(&turn, 4, .retry, 7, 1, limits));
    try t.expectEqual(@as(u32, 3), (try root.codec.decode(Exchange.AttemptBudget, (try turn.read(Exchange.key(1, 'b', 0))).?)).used);
}
