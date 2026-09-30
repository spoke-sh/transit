const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const s = c.station;
const p = c.protocol;
const m = c.Model;
const r = c.Records;
const Store = @import("TestStore.zig");
const config: m.Configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = std.math.maxInt(u64) }, .owner = 3, .administrator = 17 };
fn command(value: m.Command) !p.Value {
    return (s.Frame{ .kind = .cast, .payload = try value.encode() }).encode();
}
fn request() !m.CreateTable {
    return m.CreateTable.compile(config.scope, 99, 99, 9, "CREATE TABLE items (id INT64 NOT NULL,value UTF8 NULL)");
}
// Run the public hooks with the same descriptor/guard/initialize/handle order
// as GenServer. This models private work; the native host proof owns recovery.
fn dispatch(store: *Store, behavior: *c.Behavior, origin: p.Growth.Origin, value: p.Value) !s.Turn {
    var turn = try store.capture(17);
    turn.delivery.input.origin = origin;
    turn.delivery.input.value = value;
    const initializing = try turn.read(s.GenServer.descriptor_key) == null;
    if (initializing) try turn.write(s.GenServer.descriptor_key, s.GenServer.descriptor);
    const guard = behavior.guard();
    if (try guard.reject(guard.context, &turn)) {
        if (initializing) return error.UninitializedCatalog;
        return turn;
    }
    const handler = behavior.interface();
    if (initializing) try handler.initialize.?(handler.context, &turn);
    try handler.handle(handler.context, &turn, try s.Frame.decode(value));
    try turn.validate();
    return turn;
}
fn external(principal: u64) p.Growth.Origin {
    return .{ .external = .{ .principal = principal, .policy_revision = 1 } };
}
fn disposition(turn: *s.Turn) !?m.Disposition {
    return if (try turn.read(r.key(config.scope.catalog, 'e', turn.delivery.input.position, 0))) |value| try r.decode(m.Disposition, 'e', value) else null;
}
fn count(turn: s.Turn) usize {
    var total: usize = 0;
    for (turn.decision.mutations) |slot| if (slot != null) {
        total += 1;
    };
    return total;
}
fn ready(store: *Store, behavior: *c.Behavior) !void {
    try store.commit(try dispatch(store, behavior, external(17), try command(.{ .initialize = config })));
}
test "catalog behavior initializes in four writes and keeps creation and control outcomes distinct" {
    var store: Store = .{};
    defer store.deinit();
    var behavior: c.Behavior = .{ .configuration = config };
    var turn = try dispatch(&store, &behavior, external(17), try command(.{ .initialize = config }));
    try t.expectEqual(4, count(turn));
    try t.expectEqual(0, store.state.count());
    try t.expectEqual(.initialized, (try disposition(&turn)).?.outcome);
    try store.commit(turn);
    turn = try dispatch(&store, &behavior, external(17), try command(.{ .initialize = config }));
    try t.expectEqual(1, count(turn));
    try store.commit(turn);
    const req = try request();
    turn = try dispatch(&store, &behavior, external(17), try command(.{ .create_table = req }));
    try t.expectEqual(4, count(turn));
    try t.expectEqual(null, try disposition(&turn));
    try store.commit(turn);
    var replacement = try store.clone();
    defer replacement.deinit();
    turn = try dispatch(&replacement, &behavior, external(17), try command(.{ .create_table = req }));
    try t.expectEqual(0, count(turn));
    var changed = req;
    changed.table += 1;
    turn = try dispatch(&replacement, &behavior, external(17), try command(.{ .create_table = changed }));
    try t.expectEqual(.identity_conflict, (try disposition(&turn)).?.outcome);
    try t.expectEqual(1, count(turn));
}
test "catalog behavior preserves administrator controls and current creation policy" {
    var store: Store = .{};
    defer store.deinit();
    var behavior: c.Behavior = .{ .configuration = config };
    try ready(&store, &behavior);
    const deny: m.PolicyChange = .{ .expected_revision = 1, .policy = .{ .scope = config.scope, .principal = 17, .revision = 2, .create = false, .inspect = true } };
    var turn = try dispatch(&store, &behavior, external(18), try command(.{ .set_policy = deny }));
    try t.expectEqual(.denied, (try disposition(&turn)).?.outcome);
    try t.expectEqual(1, count(turn));
    try store.commit(turn);
    turn = try dispatch(&store, &behavior, external(17), try command(.{ .set_policy = deny }));
    try t.expectEqual(.policy_applied, (try disposition(&turn)).?.outcome);
    try t.expectEqual(2, count(turn));
    try store.commit(turn);
    turn = try dispatch(&store, &behavior, external(17), try command(.{ .create_table = try request() }));
    try t.expectEqual(.denied, (try disposition(&turn)).?.outcome);
    try store.commit(turn);
    turn = try dispatch(&store, &behavior, external(17), try command(.{ .initialize = config }));
    try store.commit(turn);
    const policy = try r.decode(m.Policy, 'p', store.state.get(r.key(config.scope.catalog, 'p', 17, 0)).?);
    try t.expectEqual(2, policy.revision);
    try t.expect(!policy.create);
    var next = deny;
    next.expected_revision = 2;
    next.policy.revision = 3;
    next.policy.create = true;
    try store.commit(try dispatch(&store, &behavior, external(17), try command(.{ .set_policy = next })));
    turn = try dispatch(&store, &behavior, external(17), try command(.{ .set_policy = deny }));
    try t.expectEqual(.stale_policy, (try disposition(&turn)).?.outcome);
    try store.commit(turn);
    turn = try dispatch(&store, &behavior, external(17), try command(.{ .set_policy = next }));
    try t.expectEqual(.policy_applied, (try disposition(&turn)).?.outcome);
    try t.expectEqual(1, count(turn));
}
test "catalog guard rejects untrusted frames and never adopts an initialized manual catalog" {
    var store: Store = .{};
    defer store.deinit();
    var behavior: c.Behavior = .{ .configuration = config };
    try t.expectError(error.UninitializedCatalog, dispatch(&store, &behavior, external(18), try command(.{ .initialize = config })));
    try t.expectEqual(0, store.state.count());
    try ready(&store, &behavior);
    for ([_]p.Growth.Origin{ .{ .process = .{ .pid = 8, .turn = 1, .output = 0 } }, .{ .effect = .{ .id = 8, .attempt = 1, .executor = 17 } } }) |origin| {
        var turn = try dispatch(&store, &behavior, origin, try command(.{ .create_table = try request() }));
        const result = (try disposition(&turn)).?;
        try t.expectEqual(.invalid_command, result.outcome);
        try t.expect(result.origin != .external and result.principal == 0);
        try store.commit(turn);
    }
    var turn = try dispatch(&store, &behavior, external(17), try p.Value.init("malformed"));
    try t.expectEqual(.invalid_command, (try disposition(&turn)).?.outcome);
    var other = config;
    other.owner += 1;
    behavior.configuration = other;
    try t.expectError(error.CatalogOwnerChanged, dispatch(&store, &behavior, external(17), try command(.{ .initialize = other })));
    behavior.configuration = config;
    var manual: Store = .{};
    defer manual.deinit();
    turn = try manual.capture(17);
    try (c.Catalog{ .configuration = config }).initialize(&turn);
    try manual.commit(turn);
    try t.expectError(error.CatalogAlreadyPopulated, dispatch(&manual, &behavior, external(17), try command(.{ .initialize = config })));
}
test "catalog behavior never converts unavailable evidence into a durable rejection" {
    const operations = [_]m.Command{
        .{ .initialize = config },
        .{ .create_table = try request() },
        .{ .set_policy = .{ .expected_revision = 1, .policy = .{ .scope = config.scope, .principal = 17, .revision = 2, .create = false, .inspect = true } } },
    };
    for (operations) |operation| {
        var store: Store = .{};
        defer store.deinit();
        var behavior: c.Behavior = .{ .configuration = config };
        if (operation != .initialize) try ready(&store, &behavior);
        const original_size = store.state.count();
        const frame = try command(operation);
        store.reads = 0;
        _ = try dispatch(&store, &behavior, external(17), frame);
        const reads = store.reads;
        for (1..reads + 1) |index| {
            store.reads = 0;
            store.fail_at = index;
            try t.expectError(error.Unavailable, dispatch(&store, &behavior, external(17), frame));
            try t.expectEqual(original_size, store.state.count());
        }
        store.fail_at = null;
        if (operation != .set_policy) {
            store.fail_page = true;
            try t.expectError(error.Unavailable, dispatch(&store, &behavior, external(17), frame));
            try t.expectEqual(original_size, store.state.count());
        }
    }
}
