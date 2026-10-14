const std = @import("std");
const t = std.testing;
const serving = @import("transit_serving");
const q = serving.query;
const s = serving.station;
const c = q.catalog;
const p = s.protocol;
const Counter = @import("Counter.zig");
const Store = q.testing.Store;
const ingress = 42;
fn setup(store: *Store) !void {
    const catalog: c.TableCatalog = .{ .configuration = .{ .scope = .{ .realm = 1, .resource = store.resource, .catalog = 1 }, .owner = store.pid, .administrator = 17, .authority = c.testing.Authority.profile, .table_limits = .{ .record_bytes = s.fuze.TableRow.max_bytes, .staging_bytes = 8 * s.fuze.TableRow.max_bytes, .staging_records = 8 } } };
    var turn = try store.capture();
    turn.delivery.input.origin = .{ .external = .{ .principal = 17, .policy_revision = 1 } };
    try catalog.initialize(&turn);
    try store.commit(turn);
    for (0..4000) |_| {
        turn = try store.capture();
        turn.delivery.input.origin = .{ .external = .{ .principal = 17, .policy_revision = 1 } };
        const result = try catalog.step(t.allocator, &turn, .{ .principal = 17, .operation = 1, .object = Counter.object, .expected_revision = 0, .name = try .init("counter"), .action = .{ .create = .{ .schema = Counter.schema } } });
        try store.commit(turn);
        if (result.terminal()) {
            try t.expectEqual(.applied, result.operation.state);
            return;
        }
    }
    return error.UnfinishedCounterSetup;
}
fn enqueue(store: *Store, correlation: u64, key: i64, delta: i64) !void {
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(i64, bytes[0..8], key, .little);
    std.mem.writeInt(i64, bytes[8..16], delta, .little);
    const frame: s.Frame = .{ .kind = .call, .correlation = correlation, .payload = try serving.Codec.encode('i', serving.Model.Invocation{ .service = 1, .principal = 65536, .operation = correlation, .binding = 1, .codec = 1, .payload = try p.Value.init(&bytes) }) };
    var turn = try store.capture();
    turn.delivery.input.origin = .{ .process = .{ .pid = ingress, .turn = correlation, .output = 0 } };
    turn.delivery.input.value = try frame.encode();
    try Counter.enqueue(&turn, ingress, frame);
    try store.commit(turn);
}
fn selfTurn(store: *Store) !s.Turn {
    var turn = try store.capture();
    turn.delivery.input.origin = .{ .process = .{ .pid = store.pid, .turn = store.input - 1, .output = 0 } };
    turn.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = Counter.continuation }).encode();
    return turn;
}
fn value(store: *Store, key: i64) !?i64 {
    var turn = try store.capture();
    const head = try s.TableHead.load(&turn, Counter.object);
    var reader: s.TablePages.Reader(*s.Turn) = .{ .pages = .{ .resource = store.resource, .object = Counter.object }, .source = &turn };
    const data: s.TableData = .{ .schema = Counter.schema, .index = head.index };
    const identity = (try data.findKey(t.allocator, &reader, &.{.{ .value = .{ .atom = .{ .signed = key } } }})) orelse return null;
    var row = (try data.get(t.allocator, &reader, identity)).?;
    defer row.deinit();
    return @intCast(row.row().cells[1].value.atom.signed);
}
test "queued counters publish exact deltas, progress and original replies despite lost turns" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    // More accepted work than a resident native page; no in-memory work list.
    for (0..19) |i| try enqueue(&store, i + 1, 7, 1);
    var replies: usize = 0;
    for (0..4000) |_| {
        const before = try value(&store, 7);
        var lost = try selfTurn(&store);
        try Counter.drive(t.allocator, &lost);
        try t.expectEqual(before, try value(&store, 7));
        var turn = try selfTurn(&store);
        try Counter.drive(t.allocator, &turn);
        try t.expectEqualDeep(lost.decision, turn.decision);
        var returned: ?s.Frame = null;
        for (turn.decision.outputs) |slot| if (slot) |output| {
            const frame = try s.Frame.decode(output.value);
            if (frame.kind == .reply) {
                try t.expectEqual(ingress, output.pid);
                try t.expectEqual(replies + 1, frame.correlation);
                try t.expectEqual(@as(i64, @intCast(replies + 1)), std.mem.readInt(i64, frame.payload.data[0..8], .little));
                returned = frame;
            }
        };
        try store.commit(turn);
        if (returned != null) replies += 1;
        try t.expectEqual(if (replies == 0) @as(?i64, null) else @as(i64, @intCast(replies)), try value(&store, 7));
        var observed = try store.capture();
        const progress = if (try observed.read(Counter.progress_key)) |v| try v.asInteger() else 0;
        try t.expectEqual(@as(i64, @intCast(replies)), progress);
        if (replies == 19) break;
    } else return error.UnfinishedCounterWork;
    var idle = try selfTurn(&store);
    try Counter.drive(t.allocator, &idle);
    for (idle.decision.mutations) |entry| try t.expectEqual(null, entry);
    for (idle.decision.outputs) |entry| try t.expectEqual(null, entry);
}

fn complete(store: *Store) !p.Value {
    for (0..4000) |_| {
        // Exhausting the output budget must also discard private row/index
        // staging and terminal application writes, not consume the delta.
        var blocked = try selfTurn(store);
        for (&blocked.decision.outputs) |*output| output.* = .{ .pid = ingress, .value = try (s.Frame{ .kind = .cast, .payload = try p.Value.init("busy") }).encode() };
        const before = blocked.decision;
        try t.expectError(error.OutputBudgetExceeded, Counter.drive(t.allocator, &blocked));
        try t.expectEqualDeep(before, blocked.decision);
        var turn = try selfTurn(store);
        try Counter.drive(t.allocator, &turn);
        var reply: ?p.Value = null;
        for (turn.decision.outputs) |output| if (output) |entry| {
            const frame = try s.Frame.decode(entry.value);
            if (frame.kind == .reply) reply = frame.payload;
        };
        try store.commit(turn);
        if (reply) |result| return result;
    }
    return error.UnfinishedCounterWork;
}
test "counter overflow, no-op and output exhaustion preserve the exact saved delta" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    try enqueue(&store, 1, 7, std.math.maxInt(i64));
    try t.expectEqual(std.math.maxInt(i64), std.mem.readInt(i64, (try complete(&store)).data[0..8], .little));
    try enqueue(&store, 2, 7, 1);
    try t.expect((try complete(&store)).eql(try p.Value.init("CounterOverflow")));
    var turn = try store.capture();
    try t.expectEqual(1, try (try turn.read(Counter.progress_key)).?.asInteger());
    try t.expectEqual(std.math.maxInt(i64), (try value(&store, 7)).?);
    try enqueue(&store, 3, 7, 0);
    try t.expectEqual(std.math.maxInt(i64), std.mem.readInt(i64, (try complete(&store)).data[0..8], .little));
    turn = try store.capture();
    try t.expectEqual(2, try (try turn.read(Counter.progress_key)).?.asInteger());
    try t.expectEqual(std.math.maxInt(i64), (try value(&store, 7)).?);
}
test "counter continuation requires its owner and invocations require the configured ingress" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    try enqueue(&store, 1, 7, 1);
    var turn = try selfTurn(&store);
    turn.delivery.input.origin = .{ .process = .{ .pid = ingress, .turn = 1, .output = 0 } };
    const before = turn.decision;
    try t.expectError(error.AccessDenied, Counter.drive(t.allocator, &turn));
    try t.expectEqualDeep(before, turn.decision);
    try t.expectEqual(null, try value(&store, 7));
    turn.delivery.input.origin = .{ .process = .{ .pid = ingress + 1, .turn = 1, .output = 0 } };
    try t.expectError(error.UnexpectedServingIngress, Counter.enqueue(&turn, ingress, .{ .kind = .call, .correlation = 1, .payload = try p.Value.init("foreign") }));
    try t.expectEqualDeep(before, turn.decision);
    try t.expectEqual(1, std.mem.readInt(i64, (try complete(&store)).data[0..8], .little));
}

test "counter staging reads chunked growing indexes only before private mutation" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    // Distinct rows force the immutable index beyond an inline record and a
    // resident native page. A single repeatedly updated key misses this case.
    for (0..19) |i| try enqueue(&store, i + 1, @intCast(i + 1), 1);
    for (0..19) |i| {
        try t.expectEqual(1, std.mem.readInt(i64, (try complete(&store)).data[0..8], .little));
        for (0..i + 1) |row| try t.expectEqual(1, (try value(&store, @intCast(row + 1))).?);
    }
    var turn = try store.capture();
    try t.expectEqual(19, (try s.TableHead.load(&turn, Counter.object)).rows);
    try t.expectEqual(19, try (try turn.read(Counter.progress_key)).?.asInteger());
}
