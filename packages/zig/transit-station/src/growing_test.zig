const std = @import("std");
const t = std.testing;
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig");
const Frame = @import("Frame.zig");
const Waiting = @import("Waiting.zig");
const Registry = @import("Registry.zig");
const Store = @import("TestStore.zig");
fn stateKey(index: usize) !p.Value {
    var bytes: [16]u8 = undefined;
    return p.Value.init(try std.fmt.bufPrint(&bytes, "row-{d:0>4}", .{index}));
}

test "explicit committed reads exclude private inserts updates and deletes at one captured cut" {
    var store: Store = .{};
    for (0..2) |i| store.entries[i] = .{ .key = try stateKey(i), .value = p.Value.integer(@intCast(i + 10)), .revision = 0 };
    var turn = try store.turn(.{});
    var source = turn.committed();
    try turn.put(try stateKey(0), p.Value.integer(90));
    try turn.delete(try stateKey(1));
    try turn.put(try stateKey(2), p.Value.integer(92));
    const proposal = turn.decision;
    try t.expectEqual(90, try (try turn.read(try stateKey(0))).?.asInteger());
    try t.expectEqual(null, try turn.read(try stateKey(1)));
    try t.expectEqual(92, try (try turn.read(try stateKey(2))).?.asInteger());
    try t.expectError(error.QueryAfterMutation, turn.page(null));
    const page = try source.page(null);
    try t.expect(page.entries[0] != null and page.entries[1] != null and page.entries[2] == null);
    try t.expectEqual(10, try page.entries[0].?.value.asInteger());
    try t.expectEqual(11, try page.entries[1].?.value.asInteger());
    try t.expectEqual(10, try (try source.read(try stateKey(0))).?.asInteger());
    try t.expectEqual(null, try source.read(try stateKey(2)));
    try t.expect(std.meta.eql(proposal, turn.decision));
    try turn.validate();
    for ([_]bool{ false, true }) |page_failure| {
        turn = try store.turn(.{});
        try turn.put(try p.Value.init("private"), try p.Value.init("kept"));
        source = turn.committed();
        store.fail = !page_failure;
        store.fail_page = page_failure;
        if (page_failure) try t.expectError(error.Unavailable, source.page(null)) else try t.expectError(error.Unavailable, source.read(try stateKey(0)));
        try t.expectError(error.Unavailable, turn.validate());
        try t.expectError(error.Unavailable, turn.read(try p.Value.init("private")));
        store.fail = false;
        store.fail_page = false;
    }
    turn = try store.turn(.{});
    source = turn.committed();
    source.view.resource += 1;
    try t.expectError(error.InvalidCommittedSource, source.page(null));
    try t.expectError(error.InvalidCommittedSource, turn.validate());
}

test "growing registry reads stay bounded across names with full-width scoped principals" {
    var store: Store = .{};
    var turn = try store.turn(.{});
    try Registry.create(&turn, 1);
    try Registry.grant(&turn, 1, .{ .principal = 65536 }, .{ .lookup = true, .mutate = true });
    for (turn.decision.mutations, 0..) |slot, index| if (slot) |mutation| {
        store.entries[index] = .{ .key = mutation.key, .value = mutation.value.?, .revision = 1 };
    };
    for (0..96) |index| {
        turn = try store.turn(.{});
        turn.delivery.input.origin = .{ .external = .{ .principal = 65536, .policy_revision = 1 } };
        var buffer: [24]u8 = undefined;
        const name = try Registry.Name.init(try std.fmt.bufPrint(&buffer, "name-{d}", .{index}));
        store.reads = 0;
        const binding = try Registry.apply(&turn, .{ .scope = 1, .name = name, .operation = .register, .destination = 1000 + index });
        try t.expectEqual(@as(u64, 1), binding.revision);
        try t.expectEqual(@as(usize, 3), store.reads);
        try t.expectEqual(null, turn.decision.mutations[1]);
        const mutation = turn.decision.mutations[0].?;
        store.entries[index + 2] = .{ .key = mutation.key, .value = mutation.value.?, .revision = 2 + index };
    }
    const name = try Registry.Name.init("name-95");
    turn = try store.turn(.{});
    turn.delivery.input.origin = .{ .external = .{ .principal = 0, .policy_revision = 1 } };
    try t.expectError(error.RegistryDenied, Registry.apply(&turn, .{ .scope = 1, .name = name, .operation = .lookup }));
    turn.delivery.input.origin.external.principal = 65536;
    try t.expectError(error.RegistryRevisionConflict, Registry.apply(&turn, .{ .scope = 1, .name = name, .operation = .rebind, .destination = 2000 }));
    _ = try Registry.apply(&turn, .{ .scope = 1, .name = name, .operation = .unregister, .expected_revision = 1 });
    const mutation = turn.decision.mutations[0].?;
    store.entries[97] = .{ .key = mutation.key, .value = mutation.value.?, .revision = 200 };
    turn = try store.turn(.{});
    turn.delivery.input.origin = .{ .external = .{ .principal = 65536, .policy_revision = 1 } };
    const tombstone = try Registry.apply(&turn, .{ .scope = 1, .name = name, .operation = .lookup });
    try t.expectEqual(@as(u64, 2), tombstone.revision);
    try t.expectEqual(null, tombstone.destination);
    store.fail = true;
    try t.expectError(error.Unavailable, Registry.apply(&turn, .{ .scope = 1, .name = name, .operation = .lookup }));
    try t.expectError(error.Unavailable, turn.validate());
}

test "growing registry routing keeps a verified resolution and rolls back exhausted output capacity" {
    var store: Store = .{};
    const correlation = 5;
    store.entries[0] = .{ .key = Turn.waitKey(correlation), .value = (Turn.Wait{ .target = 8, .phase = .replied, .resolution_input = 4 }).encode(), .revision = 1 };
    const frame: Frame = .{ .kind = .reply, .correlation = correlation, .payload = (Registry.Binding{ .scope = 1, .revision = 7, .destination = 9 }).encode() };
    var turn = try store.turn(try frame.encode());
    turn.delivery.input.origin = .{ .process = .{ .pid = 8, .turn = 3, .output = 2 } };
    try t.expectEqual(@as(u64, 9), try Registry.route(&turn, 8, frame, try p.Value.init("fixed")));
    try t.expectEqual(@as(u64, 9), turn.decision.outputs[0].?.pid);
    try t.expectEqual(@as(u64, 7), (try Registry.Binding.decode(try p.Value.init(turn.decision.mutations[0].?.value.?.slice()[8..]))).revision);
    turn = try store.turn(try frame.encode());
    turn.delivery.input.origin = .{ .process = .{ .pid = 8, .turn = 3, .output = 2 } };
    for (0..4) |_| try turn.cast(10, .{});
    const before = turn.decision;
    try t.expectError(error.OutputBudgetExceeded, Registry.route(&turn, 8, frame, .{}));
    try t.expect(std.meta.eql(before, turn.decision));
}

test "growing KV point reads and private mutation bounds do not depend on retained cardinality" {
    var store: Store = .{};
    for (0..store.entries.len) |i| store.entries[i] = .{ .key = try stateKey(i), .value = p.Value.integer(@intCast(i)), .revision = 1 };
    var turn = try store.turn(.{});
    try t.expectEqual(100, try (try turn.read(try stateKey(100))).?.asInteger());
    try t.expectEqual(@as(usize, 1), store.reads);
    try turn.put(try stateKey(100), p.Value.integer(200));
    try t.expectEqual(200, try (try turn.read(try stateKey(100))).?.asInteger());
    try t.expectEqual(@as(usize, 1), store.reads);
    for (128..131) |i| try turn.put(try stateKey(i), .{});
    const before = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, turn.put(try stateKey(131), .{}));
    try t.expectEqualDeep(before, turn.decision);
    try turn.validate(); // More than 128 retained keys is not a runtime array limit.
    try t.expect(!@hasField(Turn, "entries"));
    try t.expectEqual(100, try store.entries[100].?.value.asInteger());
}

test "caught growing read failures poison private proposals without hiding uncertain state" {
    var store: Store = .{};
    var turn = try store.turn(.{});
    const key = try p.Value.init("local");
    try turn.put(key, try p.Value.init("private"));
    try t.expectEqualStrings("private", (try turn.read(key)).?.slice());
    try t.expectEqual(@as(usize, 0), store.reads);
    try turn.cast(8, .{});
    store.fail = true;
    try t.expectError(error.Unavailable, turn.read(try p.Value.init("remote")));
    store.fail = false;
    try t.expectError(error.Unavailable, turn.read(key));
    try t.expectError(error.Unavailable, turn.validate());
    // A fresh private turn may retry reads; no write was sent by this abstraction.
    turn = try store.turn(.{});
    try t.expectEqual(@as(?p.Value, null), try turn.read(key));
    try turn.validate();
}

test "growing behavior finish distinguishes incomplete reads from application failure" {
    const Server = @import("GenServer.zig");
    var wire: @import("transit_client").Client = undefined;
    var host = try Server.init(.{ .client = &wire, .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) }, "state");
    var store: Store = .{};
    host.ready = try store.turn(.{});
    try host.ready.?.put(try p.Value.init("local"), .{});
    try host.ready.?.cast(8, .{});
    store.fail = true;
    try t.expectError(error.Unavailable, host.ready.?.read(try p.Value.init("missing")));
    try t.expectError(error.Unavailable, host.finish(null));
    try t.expect(host.ready == null and host.pending == null and !host.blocked);
    store.fail = false;
    host.ready = try store.turn(.{});
    try host.ready.?.put(try p.Value.init("local"), .{});
    try host.ready.?.cast(8, .{});
    try host.finish(error.ApplicationFailed);
    const proposal = host.pending.?.signed.request.command.turn;
    try t.expect(proposal.failed);
    try t.expectEqual(@as(?u64, 6), proposal.views[0]);
    try t.expect(proposal.write_view == null);
    for (proposal.mutations) |slot| try t.expect(slot == null);
    for (proposal.outputs) |slot| try t.expect(slot == null);
    try t.expectEqual(@as(?anyerror, error.ApplicationFailed), host.handler_error);
}

test "gated preparation never dispatches or discards frozen control and turn requests" {
    const Server = @import("GenServer.zig");
    // An uninitialized client deliberately makes any accidental I/O invalid.
    var wire: @import("transit_client").Client = undefined;
    var host = try Server.init(.{ .client = &wire, .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) }, "state");
    var store: Store = .{};
    const turn = try store.turn(.{});
    inline for ([_]Server.PendingKind{ .permit, .open, .commit }) |kind| {
        var delivery = turn.delivery;
        delivery.needs_permit = kind == .permit;
        host.delivery = delivery;
        host.pending_kind = kind;
        host.pending = switch (kind) {
            .permit => try host.session.prepareBegin(delivery),
            .open => try host.session.prepareView(delivery, .{ .id = 7, .writer = 2, .owner = null, .revision = 0, .deadline_ms = null }, 100),
            .commit => try host.session.prepareCommit(delivery, turn.decision),
        };
        const before = try std.json.Stringify.valueAlloc(t.allocator, host.pending.?.signed, .{});
        defer t.allocator.free(before);
        for (0..3) |_| try t.expectEqual(.progress, try host.prepare(100));
        try t.expectError(error.PendingOperation, host.discard());
        const after = try std.json.Stringify.valueAlloc(t.allocator, host.pending.?.signed, .{});
        defer t.allocator.free(after);
        try t.expectEqualStrings(before, after);
        try t.expect(host.ready == null and host.confirmation == null);
    }
}

test "stop policy and explicit discard drop private work without a failure mutation" {
    const Server = @import("GenServer.zig");
    var wire: @import("transit_client").Client = undefined;
    var host = try Server.init(.{ .client = &wire, .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) }, "state");
    var store: Store = .{};
    host.failure_policy = .stop;
    host.ready = try store.turn(.{});
    try host.ready.?.put(try p.Value.init("local"), .{});
    try host.ready.?.cast(8, .{});
    try t.expectError(error.ApplicationFailed, host.finish(error.ApplicationFailed));
    try t.expect(host.ready == null and host.pending == null and !host.blocked);
    host.ready = try store.turn(.{});
    try host.ready.?.put(try p.Value.init("local"), .{});
    try host.discard();
    try t.expect(host.ready == null and host.pending == null);
    try t.expectError(error.NoPreparedTurn, host.finish(null));
    host.ready = try store.turn(.{});
    store.fail = true;
    try t.expectError(error.Unavailable, host.ready.?.read(try p.Value.init("remote")));
    try t.expectError(error.Unavailable, host.finish(error.ApplicationFailed));
    try t.expect(host.pending == null and host.ready == null);
}

test "growing waits preserve wide observer identities and authenticate closure" {
    var store: Store = .{};
    var caller = try store.turn(.{});
    caller.delivery.work_before_ms = 200;
    caller.resource_deadline_ms = 150;
    try t.expectError(error.InvalidWaitLifetime, caller.callWithTimer(8, .{}, 151, 65536));
    const correlation = try caller.callWithTimer(8, .{}, 150, 65536);
    const encoded = (try caller.waiting(correlation)).?.encode();
    try t.expectEqual(@as(?u64, 65536), (try Turn.Wait.decode(encoded)).observer);
    var obsolete = encoded;
    obsolete.data[0] = 2;
    try t.expectError(error.InvalidWait, Turn.Wait.decode(obsolete));
    obsolete = encoded;
    obsolete = try p.Value.init(encoded.slice()[0..27]);
    try t.expectError(error.InvalidWait, Turn.Wait.decode(obsolete));
    store.entries[0] = .{ .key = Turn.waitKey(correlation), .value = encoded, .revision = 1 };
    var next = try store.turn(.{});
    const timeout = try Waiting.observation(correlation, 150);
    try t.expectError(error.UnexpectedTimerObserver, Waiting.dispatch(&next, timeout));
    next.delivery.input.origin = .{ .external = .{ .principal = 65536, .policy_revision = 1 } };
    try t.expect(!try Waiting.dispatch(&next, timeout));
    next.delivery.input.value = try (Frame{ .kind = .reply, .correlation = correlation }).encode();
    next.delivery.input.origin = .{ .process = .{ .pid = 9, .turn = 5, .output = 1 } };
    try t.expectError(error.UnexpectedReplySource, next.acceptReply());
    next.delivery.input.origin.process.pid = 8;
    try t.expect(try next.acceptReply() == .closed);
    try t.expect((try next.waiting(correlation)).?.phase == .timed_out);
}

test "retained state sources survive new handler views and stage their dependency automatically" {
    const Fixture = struct {
        live: Store = .{},
        snapshot: Store = .{},
        identity: p.Growth.ReadVersionId = .{ .pid = 2, .input = 1, .index = 0 },
        fail: bool = false,
        reads: usize = 0,
        fn metadata(raw: *anyopaque, id: p.Growth.ReadVersionId) anyerror!p.Growth.ReadVersion {
            const self: *@This() = @ptrCast(@alignCast(raw));
            try t.expect(std.meta.eql(self.identity, id));
            return .{ .id = id, .resource = 7, .revision = 8, .created_at = 9 };
        }
        fn entries(raw: *anyopaque, basis: p.Growth.ReadVersion, key: ?p.Value, after: ?p.Value) anyerror!@import("Turn.zig").Page {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.reads += 1;
            if (self.fail) return error.Unavailable;
            try t.expect(std.meta.eql(self.identity, basis.id));
            const view: p.Growth.View = .{ .id = 6, .pid = 2, .principal = 65536, .generation = 3, .input = 4, .process_revision = 0, .resource = 7, .revision = 8, .deadline_ms = 100 };
            if (key) |point| {
                var result: @import("Turn.zig").Page = .{};
                if (try Store.read(&self.snapshot, view, point)) |value| result.entries[0] = .{ .key = point, .value = value, .revision = 8 };
                return result;
            }
            return Store.page(&self.snapshot, view, after);
        }
        fn liveRead(raw: *anyopaque, view: p.Growth.View, key: p.Value) anyerror!?p.Value {
            const self: *@This() = @ptrCast(@alignCast(raw));
            return Store.read(&self.live, view, key);
        }
        fn turn(self: *@This()) !Turn {
            var result = try self.live.turn(.{});
            result.reader = .{ .context = self, .cache_reads = true, .read = liveRead, .version = metadata, .version_entries = entries };
            return result;
        }
    };
    var fixture: Fixture = .{};
    for (0..12) |i| fixture.snapshot.entries[i] = .{ .key = try stateKey(i), .value = p.Value.integer(@intCast(i)), .revision = 8 };
    var first = try fixture.turn();
    const retained = try first.retain();
    try t.expect(std.meta.eql(retained, try first.retain())); // One private slot.
    try t.expectEqual(@as(u8, 0), retained.index);
    try t.expectEqual(@as(?u64, 6), first.decision.retain[0]);
    try first.put(try p.Value.init("manifest"), p.Value.integer(1));
    var source = try first.openVersion(fixture.identity);
    const one = try source.page(null);
    try t.expect(one.entries[7] != null and one.next != null);
    try t.expect(std.meta.eql(fixture.identity, first.decision.read_versions[0].?));
    try t.expect(first.decision.read_versions[1] == null); // Repeated reads deduplicate.
    try first.validate(); // Manifest writes do not mix into retained source rows.

    var next = try fixture.turn();
    next.view.id = 100;
    next.delivery.input.position = 101;
    next.delivery.generation = 4;
    var resumed = try next.openVersion(fixture.identity);
    const two = try resumed.page(one.next);
    try t.expect(two.entries[3] != null and two.entries[4] == null);
    try t.expectEqual(@as(i64, 8), try two.entries[0].?.value.asInteger());
    try t.expect(two.next == null);
    try next.release(fixture.identity);
    try next.release(fixture.identity);
    try t.expect(next.decision.release[1] == null);
    try t.expect(std.meta.eql(fixture.identity, next.decision.read_versions[0].?));
    try t.expectError(error.WrongActivation, next.release(.{ .pid = 3, .input = 1, .index = 0 }));
    fixture.fail = true;
    try t.expectError(error.Unavailable, resumed.read(try stateKey(0)));
    try next.put(try p.Value.init("ignored"), .{});
    try t.expectError(error.Unavailable, next.validate());

    // Repeated point reads, including absence, reuse only this opened cut.
    // Eviction rereads immutable data; private writes never enter that cache.
    fixture.fail = false;
    fixture.reads = 0;
    for (0..Turn.read_cache_entries + 1) |i| fixture.snapshot.entries[i] = .{ .key = try stateKey(i), .value = p.Value.integer(@intCast(i)), .revision = 8 };
    var cached_turn = try fixture.turn();
    var cached = try cached_turn.openVersion(fixture.identity);
    for (0..2) |_| for (0..Turn.read_cache_entries) |i| {
        try t.expectEqual(@as(i64, @intCast(i)), try (try cached.read(try stateKey(i))).?.asInteger());
    };
    try t.expectEqual(Turn.read_cache_entries, fixture.reads);
    _ = try cached.read(try stateKey(Turn.read_cache_entries));
    _ = try cached.read(try stateKey(0));
    try t.expectEqual(Turn.read_cache_entries + 2, fixture.reads);
    const absent = try stateKey(Turn.read_cache_entries + 1);
    try t.expectEqual(null, try cached.read(absent));
    try cached_turn.put(absent, p.Value.integer(99));
    try t.expectEqual(null, try cached.read(absent));
    try t.expectEqual(Turn.read_cache_entries + 3, fixture.reads);
    cached_turn.decision.read_versions = @splat(null);
    _ = try cached.read(absent);
    try t.expect(std.meta.eql(fixture.identity, cached_turn.decision.read_versions[0].?));
    var reopened = try cached_turn.openVersion(fixture.identity);
    _ = try reopened.read(absent);
    try t.expectEqual(Turn.read_cache_entries + 4, fixture.reads);
    // A distinct retained basis cannot reuse a prior entry under the same key.
    fixture.identity.input += 1;
    cached.view.id = fixture.identity;
    fixture.snapshot.entries[0].?.value = p.Value.integer(200);
    try t.expectEqual(200, try (try cached.read(try stateKey(0))).?.asInteger());
    try t.expectEqual(Turn.read_cache_entries + 5, fixture.reads);
    fixture.fail = true;
    try t.expectError(error.Unavailable, cached.page(null));
    try t.expectError(error.Unavailable, cached.read(try stateKey(0)));
    try t.expectError(error.Unavailable, cached_turn.validate());
}

test "registered resource vectors preserve one writer shared pins and sticky read failure" {
    const Source = struct {
        fail: bool = false,
        reads: usize = 0,
        fn read(raw: *anyopaque, view: p.Growth.View, _: p.Value) anyerror!?p.Value {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.reads += 1;
            if (self.fail) return error.Unavailable;
            return p.Value.integer(@intCast(view.resource));
        }
    };
    var store: Store = .{};
    var source: Source = .{};
    var turn = try store.turn(.{});
    turn.reader = .{ .context = &source, .read = Source.read, .cache_reads = true };
    const key = try p.Value.init("value");
    var foreign = turn.view;
    foreign.resource = 8;
    foreign.id = 9;
    try t.expectError(error.UncapturedStateResource, turn.captured(8));
    try t.expectError(error.InvalidStateView, turn.retainView(foreign));
    try turn.addView(foreign);
    try turn.addView(foreign);
    var read = try turn.captured(8);
    try t.expectEqual(8, try (try read.read(key)).?.asInteger());
    try t.expectEqual(8, try (try read.read(key)).?.asInteger());
    try t.expectEqual(1, source.reads);
    try read.requireCurrent();
    try t.expectEqual(@as(?u64, foreign.id), turn.decision.current_views[1]);
    const retained = try read.retain();
    try t.expect(std.meta.eql(retained, try read.retain()));
    try t.expectEqual(9, turn.decision.retain[0].?);
    const own = try turn.retain();
    try t.expectEqual(1, own.index);
    try turn.put(key, p.Value.integer(99));
    try t.expectEqual(turn.view.id, turn.decision.write_view.?);
    try t.expectEqual(99, try (try turn.read(key)).?.asInteger());
    read.view = turn.view;
    try t.expectEqual(7, try (try read.read(key)).?.asInteger());
    try t.expectEqual(2, source.reads);
    var wrong = foreign;
    wrong.revision += 1;
    try t.expectError(error.InvalidStateView, turn.addView(wrong));
    wrong = foreign;
    wrong.input += 1;
    try t.expectError(error.InvalidStateView, turn.addView(wrong));
    for ([_]u64{ 10, 11 }) |id| {
        var next = foreign;
        next.id = id;
        next.resource = id;
        try turn.addView(next);
    }
    wrong = foreign;
    wrong.id = 12;
    wrong.resource = 12;
    try t.expectError(error.StateViewBudgetExceeded, turn.addView(wrong));
    source.fail = true;
    try t.expectError(error.Unavailable, read.read(try p.Value.init("uncached")));
    try t.expectError(error.Unavailable, turn.validate());
    try t.expectError(error.Unavailable, turn.read(key));
    try t.expectError(error.Unavailable, read.retain());
}

test "host read selections cannot change a prepared input or bypass the native view bound" {
    const Server = @import("GenServer.zig");
    var wire: @import("transit_client").Client = undefined;
    var host = try Server.init(.{ .client = &wire, .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) }, "state");
    try host.setReadResources(&.{ 7, 8 });
    try t.expectError(error.InvalidStateView, host.setReadResources(&.{ 8, 8 }));
    try t.expectError(error.InvalidStateView, host.setReadResources(&.{0}));
    try t.expectError(error.StateViewBudgetExceeded, host.setReadResources(&.{ 1, 2, 3, 4 }));
    try t.expectEqual(@as(?u64, 7), host.read_resources[0]);
    var store: Store = .{};
    host.ready = try store.turn(.{});
    var view = host.ready.?.view;
    view.id = 10;
    view.resource = 8;
    try host.ready.?.addView(view);
    try t.expectError(error.PendingOperation, host.setReadResources(&.{}));
    try host.finish(error.ApplicationFailure);
    const command = host.pending.?.signed.request.command.turn;
    try t.expectEqual(@as(?u64, 10), command.views[1]);
    try t.expect(command.failed and command.write_view == null);
    try t.expectError(error.PendingOperation, host.setReadResources(&.{}));
}
