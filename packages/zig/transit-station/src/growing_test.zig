const std = @import("std");
const t = std.testing;
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig").Growing;
const Table = @import("Table.zig");
const Frame = @import("Frame.zig");
const Waiting = @import("Waiting.zig");
const Store = struct {
    entries: [128]?p.State.Entry = @splat(null),
    reads: usize = 0,
    fail: bool = false,
    pages: usize = 0,
    fail_page: bool = false,
    fn read(context: *anyopaque, view: p.Growth.View, key: p.Value) anyerror!?p.Value {
        const self: *Store = @ptrCast(@alignCast(context));
        self.reads += 1;
        try t.expectEqual(@as(u64, 6), view.id);
        if (self.fail) return error.Unavailable;
        for (self.entries) |slot| if (slot) |entry| if (entry.key.eql(key)) return entry.value;
        return null;
    }
    fn turn(self: *Store, value: p.Value) !Turn {
        return Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = 5, .revision = 0, .input = .{ .position = 4, .ordinal = 1, .value = value, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = 6, .pid = 2, .principal = 65536, .generation = 3, .input = 4, .process_revision = 0, .resource = 7, .revision = 0, .deadline_ms = 100 }, .{ .context = self, .read = read, .page = page });
    }
    fn page(raw: *anyopaque, _: p.Growth.View, after: ?p.Value) anyerror!@import("Turn.zig").Page {
        const self: *Store = @ptrCast(@alignCast(raw));
        self.pages += 1;
        if (self.fail_page) return error.Unavailable;
        // Simple independent fixture ordering, not the production page index.
        var ordered: [128]p.State.Entry = undefined;
        var len: usize = 0;
        for (self.entries) |slot| if (slot) |entry| {
            ordered[len] = entry;
            len += 1;
        };
        std.mem.sort(p.State.Entry, ordered[0..len], {}, struct {
            fn less(_: void, a: p.State.Entry, b: p.State.Entry) bool {
                return std.mem.order(u8, a.key.slice(), b.key.slice()) == .lt;
            }
        }.less);
        var result: @import("Turn.zig").Page = .{};
        var count: usize = 0;
        for (ordered[0..len]) |entry| {
            if (after) |key| if (std.mem.order(u8, entry.key.slice(), key.slice()) != .gt) continue;
            if (count == result.entries.len) {
                result.next = result.entries[count - 1].?.key;
                break;
            }
            result.entries[count] = .{ .key = entry.key, .value = entry.value, .revision = entry.revision };
            count += 1;
        }
        return result;
    }
};

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
    try t.expect(@TypeOf(turn.entries) == void);
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
    const Server = @import("GenServer.zig").Growing;
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

test "growing waits preserve wide observer identities and authenticate closure" {
    var store: Store = .{};
    var caller = try store.turn(.{});
    caller.delivery.work_before_ms = 200;
    caller.resource_deadline_ms = 150;
    try t.expectError(error.InvalidWaitLifetime, caller.callWithTimer(8, .{}, 151, 65536));
    const correlation = try caller.callWithTimer(8, .{}, 150, 65536);
    const encoded = (try caller.waiting(correlation)).?.encode();
    try t.expectEqual(@as(?u64, 65536), (try Turn.Wait.decode(encoded)).observer);
    try t.expectError(error.InvalidWait, @import("Turn.zig").Legacy.Wait.decode(encoded));
    try t.expectError(error.InvalidWait, Turn.Wait.decode((@import("Turn.zig").Legacy.Wait{ .target = 8 }).encode()));
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
