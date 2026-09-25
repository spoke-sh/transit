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
    fn read(context: *anyopaque, view: p.Growth.View, key: p.Value) anyerror!?p.Value {
        const self: *Store = @ptrCast(@alignCast(context));
        self.reads += 1;
        try t.expectEqual(@as(u64, 6), view.id);
        if (self.fail) return error.Unavailable;
        for (self.entries) |slot| if (slot) |entry| if (entry.key.eql(key)) return entry.value;
        return null;
    }
    fn turn(self: *Store, value: p.Value) !Turn {
        return Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = 5, .revision = 0, .input = .{ .position = 4, .ordinal = 1, .value = value, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = 6, .pid = 2, .principal = 65536, .generation = 3, .input = 4, .process_revision = 0, .resource = 7, .revision = 0, .deadline_ms = 100 }, .{ .context = self, .read = read });
    }
};

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
