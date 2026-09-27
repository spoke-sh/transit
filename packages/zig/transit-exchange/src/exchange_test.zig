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
test "independent shared fixtures fix full-width identities and publication coverage bytes" {
    const Fixture = struct {
        version: u32,
        resource: []const u8,
        exchange: []const u8,
        segments: []const struct { ordinal: u32, kind: u32, body: []const u8, publication_digest: []const u8, chain: []const u8, member: p.Value },
        reference: p.Value,
        intent: p.Value,
    };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    try t.expectEqual(@as(u32, 1), fixture.version);
    const resource = try std.fmt.parseInt(u64, fixture.resource, 10);
    const id = try std.fmt.parseInt(u64, fixture.exchange, 10);
    var chain = root.Coverage.initial;
    for (fixture.segments) |item| {
        var bytes: [513]u8 = undefined;
        const body = try std.fmt.hexToBytes(&bytes, item.body);
        const spec = try Pub.Digest.of(1, body);
        var expected: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected, item.publication_digest);
        try t.expectEqual(expected, spec.digest);
        chain = root.Coverage.next(chain, item.ordinal, item.kind, spec);
        _ = try std.fmt.hexToBytes(&expected, item.chain);
        try t.expectEqual(expected, chain);
        const member = try root.Member.decode(item.member);
        try t.expectEqual(spec, member.spec());
        try t.expectEqual(chain, member.chain);
        try t.expect((try member.encode()).eql(item.member));
    }
    const reference = try root.Client.Reference.decode(fixture.reference);
    try t.expectEqual(resource, reference.resource);
    try t.expectEqual(id, reference.exchange);
    try t.expectEqual(std.math.maxInt(u64), reference.exchange);
    try t.expectEqual(chain, reference.chain);
    try t.expect((try reference.encode()).eql(fixture.reference));
    const intent = try root.Intent.decode(fixture.intent);
    try t.expectEqual(@as(u64, 513), intent.bytes);
    try t.expectEqual(@as(u32, 2), intent.segments);
    try t.expect((try intent.encode()).eql(fixture.intent));
}
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
fn closeAndSettle(store: *Store, ex: Exchange) !void {
    var turn = try store.capture();
    _ = try ex.closeUnknown(&turn);
    const d = try ex.inspect(&turn);
    _ = try ex.settle(&turn, .{ .id = d.effect, .pid = d.owner, .payload = (try turn.read(Exchange.key(ex.id, 'i', 0))).?, .phase = .closed_unknown, .attempt = d.attempt, .executor = d.executor, .reconcile_before_ms = d.reconcile_before_ms });
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
    try t.expectError(error.UnsettledExchange, ex.retire(&turn));
    _ = try ex.settle(&turn, .{ .id = 19, .pid = 2, .payload = (try turn.read(Exchange.key(ex.id, 'i', 0))).?, .phase = .observed, .attempt = 20, .executor = 7, .reconcile_before_ms = 10000, .result = try (try ex.reference(&turn)).encode() });
    try t.expectError(error.ExchangeHasDependents, ex.retire(&turn));
    _ = try ex.releaseCaller(&turn, 9);
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

test "durable dependency tokens block release across turns and never reacquire after disposal" {
    var store: Store = .{};
    defer store.deinit();
    const ex = try exchange(&store, 1);
    for (1..97) |i| {
        var turn = try store.capture();
        _ = try ex.retain(&turn, i, 70000 + i);
        try t.expectEqual(.duplicate, try ex.retain(&turn, i, 70000 + i));
        try t.expectError(error.ExchangeIdentityConflict, ex.retain(&turn, i, 1));
        try store.commit(turn);
    }
    try bind(&store, ex);
    var turn = try store.capture();
    _ = try ex.closeUnknown(&turn);
    try store.commit(turn);
    turn = try store.capture();
    const effect: p.Growth.Effect = .{ .id = 19, .pid = 2, .payload = (try turn.read(Exchange.key(ex.id, 'i', 0))).?, .phase = .closed_unknown, .attempt = 20, .executor = 7, .reconcile_before_ms = 10000 };
    var forged = effect;
    forged.phase = .authorized;
    try t.expectError(error.UnsettledExchange, ex.settle(&turn, forged));
    try t.expectError(error.UnsettledExchange, ex.releaseCaller(&turn, 9));
    forged = effect;
    forged.payload.data[forged.payload.len - 1] ^= 1;
    try t.expectError(error.InvalidExchangeAttempt, ex.settle(&turn, forged));
    _ = try ex.settle(&turn, effect);
    try t.expectEqual(.duplicate, try ex.settle(&turn, effect));
    try t.expectError(error.WrongExchangeHolder, ex.releaseCaller(&turn, 10));
    _ = try ex.releaseCaller(&turn, 9);
    try t.expectError(error.ExchangeHasDependents, ex.retire(&turn));
    try store.commit(turn);
    for (1..97) |i| {
        turn = try store.capture();
        try t.expectError(error.WrongExchangeHolder, ex.release(&turn, i, 1));
        _ = try ex.release(&turn, i, 70000 + i);
        try t.expectEqual(.duplicate, try ex.release(&turn, i, 70000 + i));
        try t.expectError(error.ExchangeDependencyReleased, ex.retain(&turn, i, 70000 + i));
        if (i < 96) try t.expectError(error.ExchangeHasDependents, ex.retire(&turn));
        try store.commit(turn);
    }
    turn = try store.capture();
    try t.expectEqual(@as(u64, 0), (try ex.control(&turn)).dependents);
    _ = try ex.retire(&turn);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.ExchangeUnavailable, ex.retain(&turn, 999, 9));
    try t.expectEqual(.duplicate, try ex.release(&turn, 1, 70001));
}
test "terminal recovery after dispatch before bind preserves the original attempt identity" {
    var store: Store = .{};
    defer store.deinit();
    const ex = try exchange(&store, 1);
    try segment(&store, ex, 0, 1, "request");
    var turn = try store.capture();
    _ = try ex.commitIntent(&turn);
    const intent = turn.decision.effect.?;
    try store.commit(turn);
    turn = try store.capture();
    _ = try ex.closeUnknown(&turn);
    try store.commit(turn);
    turn = try store.capture();
    const effect: p.Growth.Effect = .{ .id = 19, .pid = 2, .payload = intent, .phase = .closed_unknown, .attempt = 20, .executor = 7, .reconcile_before_ms = 10000 };
    var bad = effect;
    bad.reconcile_before_ms = 10001;
    try t.expectError(error.InvalidExchangeAttempt, ex.settle(&turn, bad));
    bad = effect;
    bad.executor = null;
    try t.expectError(error.InvalidExchangeAttempt, ex.settle(&turn, bad));
    for (turn.decision.mutations) |slot| try t.expectEqual(null, slot);
    _ = try ex.settle(&turn, effect);
    try store.commit(turn);
    turn = try store.capture();
    const d = try ex.inspect(&turn);
    try t.expectEqual(@as(u64, 19), d.effect);
    try t.expectEqual(@as(u64, 20), d.attempt);
    try t.expectEqual(@as(u64, 7), d.executor);
    try t.expectEqual(.duplicate, try ex.settle(&turn, effect));
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
    try closeAndSettle(&store, parent);
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
    try bind(&store, child);
    try closeAndSettle(&store, child);
    turn = try store.capture();
    const last = try child.followup(&turn, 3, .reconcile, 7, 1, limits);
    try store.commit(turn);
    turn = try store.capture();
    try bind(&store, last);
    try closeAndSettle(&store, last);
    turn = try store.capture();
    try t.expectError(error.ExchangeAttemptBudgetExceeded, last.followup(&turn, 4, .cancel, 7, 1, limits));
    try t.expectError(error.ExchangeAttemptBudgetExceeded, parent.followup(&turn, 4, .retry, 7, 1, limits));
    try t.expectEqual(@as(u32, 3), (try root.codec.decode(Exchange.AttemptBudget, (try turn.read(Exchange.key(1, 'b', 0))).?)).used);
}

test "independent lineage fixtures preserve legacy encoding and bounded binary context" {
    const Fixture = struct { version: u32, lineage: p.Value, context: p.Value, bound: p.Value };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("lineage-fixtures.json"), .{});
    defer parsed.deinit();
    const f = parsed.value;
    try t.expectEqual(@as(u32, 1), f.version);
    const legacy = try Exchange.Link.decode(f.lineage);
    try t.expectEqual(@as(u64, std.math.maxInt(u64)), legacy.lineage.root);
    try t.expectEqual(@as(u64, std.math.maxInt(u64) - 1), legacy.lineage.parent);
    try t.expectEqual(@as(u16, 0), legacy.context.len);
    try t.expect(f.lineage.eql(try legacy.encode()));
    const linked = try Exchange.Link.decode(f.bound);
    try t.expectEqualDeep(legacy.lineage, linked.lineage);
    try t.expect(f.context.eql(linked.context));
    try t.expect(f.bound.eql(try linked.encode()));
    var largest = linked;
    largest.context = try p.Value.init(&(@as([214]u8, @splat(0xff))));
    try t.expectEqual(@as(u16, 256), (try largest.encode()).len);
    try t.expectEqualDeep(largest, try Exchange.Link.decode(try largest.encode()));
    largest.context = try p.Value.init(&(@as([215]u8, @splat(0))));
    try t.expectError(error.ExchangeContextTooLarge, largest.encode());
    var invalid = f.bound;
    invalid.data[41] = 0;
    try t.expectError(error.InvalidExchangeRecord, Exchange.Link.decode(invalid));
    invalid = f.bound;
    invalid.len += 1;
    try t.expectError(error.InvalidExchangeRecord, Exchange.Link.decode(invalid));
    invalid = f.bound;
    invalid.data[24] = 99;
    try t.expectError(error.InvalidExchangeRecord, Exchange.Link.decode(invalid));
    invalid = f.bound;
    invalid.len -= 1;
    invalid.data[invalid.len] = 0;
    try t.expectError(error.InvalidExchangeRecord, Exchange.Link.decode(invalid));
}

test "child context shares atomic allocation and cannot change or renew descendants" {
    var store: Store = .{};
    defer store.deinit();
    const parent = try exchange(&store, 1);
    var turn = try store.capture();
    try parent.configureAttempts(&turn, 3);
    try store.commit(turn);
    try bind(&store, parent);
    turn = try store.capture();
    try closeAndSettle(&store, parent);
    turn = try store.capture();
    const before = turn.decision;
    try turn.put(try p.Value.init("unrelated"), .{});
    const occupied = turn.decision;
    const context = try p.Value.init("\x00route\xff");
    try t.expectError(error.MutationBudgetExceeded, parent.followupWithContext(&turn, 2, .retry, 7, 1, limits, context));
    try t.expectEqualDeep(occupied, turn.decision);
    turn.decision = before;
    const child = try parent.followupWithContext(&turn, 2, .retry, 7, 1, limits, context);
    for (turn.decision.mutations) |slot| try t.expect(slot != null);
    try store.commit(turn);
    turn = try store.capture();
    try t.expect(context.eql((try child.lineage(&turn)).?.context));
    _ = try parent.followupWithContext(&turn, 2, .retry, 7, 1, limits, context);
    for (turn.decision.mutations) |slot| try t.expectEqual(null, slot);
    const empty = turn.decision;
    try t.expectError(error.ExchangeIdentityConflict, parent.followup(&turn, 2, .retry, 7, 1, limits));
    try t.expectError(error.ExchangeIdentityConflict, parent.followupWithContext(&turn, 2, .retry, 7, 1, limits, try p.Value.init("changed")));
    try t.expectEqualDeep(empty, turn.decision);
    try bind(&store, child);
    try closeAndSettle(&store, child);
    turn = try store.capture();
    const last = try child.followup(&turn, 3, .reconcile, 7, 1, limits);
    try store.commit(turn);
    turn = try store.capture();
    const origin = try parent.inspect(&turn);
    const descendant = try last.inspect(&turn);
    const linked = (try last.lineage(&turn)).?;
    try t.expectEqual(parent.id, linked.lineage.root);
    try t.expectEqual(@as(u32, 3), linked.lineage.ordinal);
    try t.expectEqual(@as(u16, 0), linked.context.len);
    try t.expectEqual(origin.caller, descendant.caller);
    try t.expectEqual(origin.input, descendant.input);
    try t.expectEqual(origin.reconcile_before_ms, descendant.reconcile_before_ms);
    try t.expectEqual(@as(u32, 3), (try root.codec.decode(Exchange.AttemptBudget, (try turn.read(Exchange.key(1, 'b', 0))).?)).used);
}

test "unsettled children protect ancestors and explicit abandonment releases only its own hold" {
    var store: Store = .{};
    defer store.deinit();
    const parent = try exchange(&store, 1);
    var turn = try store.capture();
    try parent.configureAttempts(&turn, 5);
    try store.commit(turn);
    try bind(&store, parent);
    turn = try store.capture();
    _ = try parent.closeUnknown(&turn);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.UnsettledExchange, parent.followup(&turn, 2, .retry, 7, 1, limits));
    try closeAndSettle(&store, parent);
    turn = try store.capture();
    const abandoned = try parent.followup(&turn, 2, .retry, 7, 1, limits);
    try store.commit(turn);
    turn = try store.capture();
    const child = try parent.followup(&turn, 3, .retry, 7, 1, limits);
    try store.commit(turn);
    turn = try store.capture();
    _ = try parent.releaseCaller(&turn, 9);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.ExchangeHasDependents, parent.retire(&turn));
    _ = try abandoned.closeUnknown(&turn);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.UnsettledExchange, abandoned.followup(&turn, 4, .retry, 7, 1, limits));
    for ([_][]const u8{ "a", "b", "c" }) |name| try turn.put(try p.Value.init(name), .{});
    const occupied = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, abandoned.retire(&turn));
    try t.expectEqualDeep(occupied, turn.decision);
    turn = try store.capture();
    _ = try abandoned.retire(&turn);
    try t.expectEqual(.duplicate, try abandoned.retire(&turn));
    try store.commit(turn);
    turn = try store.capture();
    const budget_key = Exchange.key(1, 'b', 0);
    try t.expectEqual(@as(u32, 1), (try root.codec.decode(Exchange.AttemptBudget, (try turn.read(budget_key)).?)).unsettled);
    try t.expectError(error.ExchangeHasDependents, parent.retire(&turn));
    try bind(&store, child);
    try closeAndSettle(&store, child);
    // A duplicate terminal read cannot discharge somebody else's hold.
    try closeAndSettle(&store, child);
    turn = try store.capture();
    try t.expectEqual(@as(u32, 0), (try root.codec.decode(Exchange.AttemptBudget, (try turn.read(budget_key)).?)).unsettled);
    const descendant = try child.followup(&turn, 4, .reconcile, 7, 1, limits);
    try store.commit(turn);
    turn = try store.capture();
    _ = try child.releaseCaller(&turn, 9);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.ExchangeHasDependents, parent.retire(&turn));
    try t.expectError(error.ExchangeHasDependents, child.retire(&turn));
    _ = try descendant.closeUnknown(&turn);
    try store.commit(turn);
    turn = try store.capture();
    _ = try descendant.retire(&turn);
    try store.commit(turn);
    turn = try store.capture();
    _ = try parent.retire(&turn);
    _ = try child.retire(&turn);
    try store.commit(turn);
    turn = try store.capture();
    const budget = try root.codec.decode(Exchange.AttemptBudget, (try turn.read(budget_key)).?);
    try t.expectEqual(@as(u32, 4), budget.used);
    try t.expectEqual(@as(u32, 0), budget.unsettled);
}

test "independent EXB2 budget fixture bounds holds and rejects old untracked budgets" {
    const Fixture = struct { version: u32, budget: p.Value, legacy: p.Value };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("budget-fixtures.json"), .{});
    defer parsed.deinit();
    const f = parsed.value;
    try t.expectEqual(@as(u32, 2), f.version);
    const budget = try root.codec.decode(Exchange.AttemptBudget, f.budget);
    try t.expectEqual(@as(u32, std.math.maxInt(u32)), budget.limit);
    try t.expectEqual(@as(u32, 3), budget.used);
    try t.expectEqual(@as(u32, 2), budget.unsettled);
    try t.expect(f.budget.eql(try root.codec.encode(budget)));
    try t.expectError(error.InvalidExchangeRecord, root.codec.decode(Exchange.AttemptBudget, f.legacy));
    var bad = budget;
    bad.unsettled = 3;
    try t.expectError(error.InvalidExchangeBudget, root.codec.encode(bad));
}
