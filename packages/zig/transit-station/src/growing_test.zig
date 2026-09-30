const std = @import("std");
const t = std.testing;
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig");
const Table = @import("Table.zig");
const Frame = @import("Frame.zig");
const Waiting = @import("Waiting.zig");
const Registry = @import("Registry.zig");
const Store = @import("TestStore.zig");

test "explicit committed reads exclude private inserts updates and deletes at one captured cut" {
    var store: Store = .{};
    const schema: @import("transit_fuze").model.Schema = .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 };
    const table: Table = .{ .resource = 7, .id = 1, .schema = schema };
    store.entries[0] = .{ .key = Table.descriptorKey(1), .value = try Table.encodeSchema(schema), .revision = 0 };
    for (0..2) |i| store.entries[i + 1] = .{ .key = Table.rowKey(1, @intCast(i)), .value = try table.encodeCell(.{ .int64 = @intCast(i + 10) }), .revision = 0 };
    var turn = try store.turn(.{});
    var source = turn.committed();
    try table.update(&turn, .{ .key = 0, .value = .{ .int64 = 90 } });
    try table.delete(&turn, 1);
    try table.insert(&turn, .{ .key = 2, .value = .{ .int64 = 92 } });
    const proposal = turn.decision;
    try t.expectEqual(90, (try table.get(&turn, 0)).?.value.int64);
    try t.expectEqual(null, try table.get(&turn, 1));
    try t.expectEqual(92, (try table.get(&turn, 2)).?.value.int64);
    try t.expectError(error.QueryAfterMutation, table.page(&turn, null));
    const captured = try Table.open(&source, 1);
    const page = try captured.page(&source, null);
    try t.expectEqual(2, page.len);
    try t.expectEqual(10, page.rows[0].value.int64);
    try t.expectEqual(11, page.rows[1].value.int64);
    try t.expectEqual(10, (try captured.get(&source, 0)).?.value.int64);
    try t.expectEqual(null, try captured.get(&source, 2));
    try t.expect(std.meta.eql(proposal, turn.decision));
    try turn.validate();
    for ([_]bool{ false, true }) |page_failure| {
        turn = try store.turn(.{});
        try turn.put(try p.Value.init("private"), try p.Value.init("kept"));
        source = turn.committed();
        store.fail = !page_failure;
        store.fail_page = page_failure;
        if (page_failure) try t.expectError(error.Unavailable, source.page(null)) else try t.expectError(error.Unavailable, source.read(Table.descriptorKey(1)));
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

test "growing Table pages bind a view and stop at Table boundaries without losing extreme keys" {
    var store: Store = .{};
    const schema: @import("transit_fuze").model.Schema = .{ .names = .{ try .init("id"), try .init("amount") }, .value_type = .int64 };
    store.entries[0] = .{ .key = Table.descriptorKey(1), .value = try Table.encodeSchema(schema), .revision = 1 };
    for (0..41) |i| {
        const key: i64 = if (i == 0) std.math.minInt(i64) else if (i == 40) std.math.maxInt(i64) else @as(i64, @intCast(i)) - 20;
        var value: [10]u8 = .{ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0 };
        std.mem.writeInt(i64, value[2..10], @intCast(i), .little);
        store.entries[i + 1] = .{ .key = Table.rowKey(1, key), .value = try p.Value.init(&value), .revision = 1 };
    }
    store.entries[42] = .{ .key = Table.descriptorKey(2), .value = try Table.encodeSchema(schema), .revision = 1 };
    store.entries[43] = .{ .key = Table.rowKey(2, 0), .value = try p.Value.init(&.{ 1, 0 }), .revision = 1 };
    store.entries[44] = .{ .key = Table.descriptorKey(3), .value = try Table.encodeSchema(schema), .revision = 1 };
    var turn = try store.turn(.{});
    const table = try Table.open(&turn, 1);
    var cursor: ?Table.Cursor = null;
    var first_cursor: ?Table.Cursor = null;
    var count: usize = 0;
    var previous: ?i64 = null;
    while (true) {
        const batch = try table.page(&turn, cursor);
        try t.expectEqual(turn.view.revision, batch.basis.revision);
        for (batch.rows[0..batch.len]) |row| {
            if (previous) |key| try t.expect(row.key > key);
            if (count == 0) try t.expectEqual(std.math.minInt(i64), row.key);
            if (count == 40) try t.expectEqual(std.math.maxInt(i64), row.key);
            try t.expectEqual(@as(i64, @intCast(count)), row.value.int64);
            previous = row.key;
            count += 1;
        }
        cursor = batch.next;
        if (first_cursor == null) first_cursor = cursor;
        if (cursor == null) break;
    }
    try t.expectEqual(@as(usize, 41), count);
    try t.expectEqual(@as(usize, 6), store.pages);
    const second = try Table.open(&turn, 2);
    try t.expectError(error.StaleTableCursor, second.page(&turn, first_cursor));
    const second_page = try second.page(&turn, null);
    try t.expectEqual(@as(u8, 1), second_page.len);
    try t.expect(second_page.rows[0].value == .null and second_page.next == null);
    const empty = try (try Table.open(&turn, 3)).page(&turn, null);
    try t.expect(empty.len == 0 and empty.next == null);
    turn.view.id += 1;
    try t.expectError(error.StaleTableCursor, table.page(&turn, first_cursor));
    turn.view.id -= 1;
    var forged = first_cursor.?;
    forged.schema[0] ^= 1;
    try t.expectError(error.StaleTableCursor, table.page(&turn, forged));
    forged = first_cursor.?;
    forged.resource += 1;
    try t.expectError(error.StaleTableCursor, table.page(&turn, forged));
    forged = first_cursor.?;
    forged.revision += 1;
    try t.expectError(error.StaleTableCursor, table.page(&turn, forged));
    try table.delete(&turn, 0);
    try t.expectError(error.QueryAfterMutation, table.page(&turn, null));
    turn = try store.turn(.{});
    store.fail_page = true;
    try t.expectError(error.Unavailable, table.page(&turn, null));
    try t.expectError(error.Unavailable, turn.validate());
}

test "growing Table point operations share codecs and atomic rollback without a whole-resource read" {
    var store: Store = .{};
    const schema: @import("transit_fuze").model.Schema = .{ .names = .{ try .init("id"), try .init("amount") }, .value_type = .int64 };
    store.entries[0] = .{ .key = Table.descriptorKey(1), .value = try Table.encodeSchema(schema), .revision = 1 };
    for (1..store.entries.len) |i| {
        var value: [10]u8 = .{ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0 };
        std.mem.writeInt(i64, value[2..10], @intCast(i), .little);
        store.entries[i] = .{ .key = Table.rowKey(1, @intCast(i)), .value = try p.Value.init(&value), .revision = 1 };
    }
    var turn = try store.turn(.{});
    const table = try Table.open(&turn, 1);
    try t.expectEqual(@as(i64, 100), (try table.get(&turn, 100)).?.value.int64);
    try t.expect(store.reads <= 3);
    try table.update(&turn, .{ .key = 100, .value = .{ .int64 = 200 } });
    try t.expectEqual(@as(i64, 200), (try table.get(&turn, 100)).?.value.int64);
    const before = turn.decision;
    var other = table;
    other.resource += 1;
    try t.expectError(error.CrossResourceTransaction, Table.atomic(&turn, &.{ .{ .table = table, .operation = .{ .delete = 100 } }, .{ .table = other, .operation = .{ .delete = 1 } } }));
    try t.expect(std.meta.eql(before, turn.decision));
    try table.insert(&turn, .{ .key = 200, .value = .null });
    try turn.validate(); // 129th retained key is not a resident-array limit.
    try t.expect(!@hasField(Turn, "entries"));
    try t.expectEqual(@as(i64, 100), std.mem.readInt(i64, store.entries[100].?.value.data[2..10], .little));
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

test "retained Table sources survive new handler views and stage their dependency automatically" {
    const Fixture = struct {
        live: Store = .{},
        snapshot: Store = .{},
        identity: p.Growth.ReadVersionId = .{ .pid = 2, .input = 1, .index = 0 },
        fail: bool = false,
        fn metadata(raw: *anyopaque, id: p.Growth.ReadVersionId) anyerror!p.Growth.ReadVersion {
            const self: *@This() = @ptrCast(@alignCast(raw));
            try t.expect(std.meta.eql(self.identity, id));
            return .{ .id = id, .resource = 7, .revision = 8, .created_at = 9 };
        }
        fn entries(raw: *anyopaque, basis: p.Growth.ReadVersion, key: ?p.Value, after: ?p.Value) anyerror!@import("Turn.zig").Page {
            const self: *@This() = @ptrCast(@alignCast(raw));
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
            result.reader = .{ .context = self, .read = liveRead, .version = metadata, .version_entries = entries };
            return result;
        }
    };
    var fixture: Fixture = .{};
    const schema: @import("transit_fuze").model.Schema = .{ .names = .{ try .init("id"), try .init("amount") }, .value_type = .int64 };
    fixture.snapshot.entries[0] = .{ .key = Table.descriptorKey(1), .value = try Table.encodeSchema(schema), .revision = 8 };
    for (0..12) |i| {
        var value: [10]u8 = .{ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0 };
        std.mem.writeInt(i64, value[2..10], @intCast(i), .little);
        fixture.snapshot.entries[i + 1] = .{ .key = Table.rowKey(1, @intCast(i)), .value = try p.Value.init(&value), .revision = 8 };
    }
    var first = try fixture.turn();
    const retained = try first.retain();
    try t.expect(std.meta.eql(retained, try first.retain())); // One private slot.
    try t.expectEqual(@as(u8, 0), retained.index);
    try t.expectEqual(@as(?u64, 6), first.decision.retain[0]);
    try first.put(try p.Value.init("manifest"), p.Value.integer(1));
    var source = try first.openVersion(fixture.identity);
    const table = try Table.open(&source, 1);
    const one = try table.page(&source, null);
    try t.expectEqual(@as(u8, 8), one.len);
    try t.expect(std.meta.eql(fixture.identity, first.decision.read_versions[0].?));
    try t.expect(first.decision.read_versions[1] == null); // Repeated reads deduplicate.
    try first.validate(); // Manifest writes do not mix into retained source rows.

    var next = try fixture.turn();
    next.view.id = 100;
    next.delivery.input.position = 101;
    next.delivery.generation = 4;
    var resumed = try next.openVersion(fixture.identity);
    const two = try table.page(&resumed, one.next);
    try t.expectEqual(@as(u8, 4), two.len);
    try t.expectEqual(@as(i64, 8), two.rows[0].key);
    try t.expect(two.next == null);
    try next.release(fixture.identity);
    try next.release(fixture.identity);
    try t.expect(next.decision.release[1] == null);
    try t.expect(std.meta.eql(fixture.identity, next.decision.read_versions[0].?));
    var wrong = one.next.?;
    wrong.source = .{ .version = .{ .pid = 2, .input = 2, .index = 0 } };
    try t.expectError(error.StaleTableCursor, table.page(&resumed, wrong));
    wrong.source = .{ .view = 9 };
    try t.expectError(error.StaleTableCursor, table.page(&resumed, wrong));
    try t.expectError(error.WrongActivation, next.release(.{ .pid = 3, .input = 1, .index = 0 }));
    fixture.fail = true;
    try t.expectError(error.Unavailable, resumed.read(Table.rowKey(1, 0)));
    try next.put(try p.Value.init("ignored"), .{});
    try t.expectError(error.Unavailable, next.validate());
}
