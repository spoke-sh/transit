const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const s = q.station;
const c = q.catalog;
const r = q.UnifiedRecords;
const tables = @import("catalog_store_test.zig");
const Owner = q.CatalogQueryOwner;
const Store = q.testing.Store;
const cancellation = q.fuze.execution.Cancellation.init(false);
fn owner() Owner {
    return .{ .tables = .{ .allocator = t.allocator, .configuration = tables.configuration }, .resources = undefined, .adapter = &.{}, .workspace = &.{}, .cancellation = &cancellation };
}
fn change(peer: u64) Owner.PolicyChange {
    return .{ .expected_revision = 0, .policy = .{ .peer = peer, .requests = 8, .revision = 1, .allow = true, .target = .{ .catalog = .{ .scope = tables.configuration.scope, .owner = 3, .principal = 17 } }, .limits = .{ .pages = 100, .segments = 100, .result_bytes = 1048576 } } };
}
fn input(store: *Store, origin: @FieldType(q.protocol.Input, "origin"), frame: s.Frame) !s.Turn {
    var turn = try store.capture();
    turn.delivery.input.origin = origin;
    turn.delivery.input.value = try frame.encode();
    return turn;
}
fn external(store: *Store, principal: u64, payload: q.protocol.Value) !s.Turn {
    return input(store, .{ .external = .{ .principal = principal, .policy_revision = 1 } }, .{ .kind = .cast, .payload = payload });
}
fn dispatch(value: *Owner, turn: *s.Turn) !void {
    const guard = value.guard();
    if (try guard.reject(guard.context, turn)) return;
    const handler = value.interface();
    if (try turn.read(s.GenServer.descriptor_key) == null) {
        try turn.write(s.GenServer.descriptor_key, s.GenServer.descriptor);
        try handler.initialize.?(handler.context, turn);
    }
    try handler.handle(handler.context, turn, try s.Frame.decode(turn.delivery.input.value));
}
fn outcome(turn: *s.Turn) !@FieldType(c.TableControl.Disposition, "outcome") {
    return (try c.Records.decode(c.TableControl.Disposition, 'E', (try turn.read(c.Records.key(9, 'e', turn.delivery.input.position, 0))).?)).outcome;
}
fn initialize(store: *Store, value: *Owner) !void {
    var turn = try external(store, 17, try (c.TableControl.Command{ .initialize = value.tables.configuration }).encode());
    try dispatch(value, &turn);
    try turn.validate();
    var writes: usize = 0;
    for (turn.decision.mutations) |mutation| if (mutation != null) {
        writes += 1;
    };
    try t.expectEqual(4, writes);
    try store.commit(turn);
}
test "catalog query delegation has one definition-bound canonical command" {
    const policy = change(9);
    const bytes = try policy.encode();
    try t.expectEqual(@as(usize, 138), bytes.len);
    try t.expectEqualDeep(policy, try Owner.PolicyChange.decode(bytes));
    for (0..bytes.len) |length| {
        if (Owner.PolicyChange.decode(try q.protocol.Value.init(bytes.slice()[0..length]))) |_| return error.AcceptedTruncatedPolicy else |_| {}
    }
    var foreign = bytes;
    foreign.data[16] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Owner.PolicyChange.decode(foreign));
    var stale = policy;
    stale.expected_revision = 1;
    try t.expectError(error.InvalidQueryPolicyChange, stale.encode());
    stale = policy;
    stale.policy.target = .{ .declaration = @splat(0) };
    try t.expectError(error.InvalidQueryPolicyChange, stale.encode());
}
test "catalog initialization and requester delegation are separate bounded decisions" {
    var store: Store = .{};
    defer store.deinit();
    var value = owner();
    var turn = try external(&store, 17, try change(9).encode());
    const before = turn.decision;
    try t.expectError(error.CatalogNotInitialized, dispatch(&value, &turn));
    try t.expectEqualDeep(before, turn.decision);
    try initialize(&store, &value);
    turn = try store.capture();
    try t.expectEqual(null, try q.UnifiedCapture.policy(&turn, 9));
    for ([_]u64{ 9, 10 }) |peer| {
        turn = try external(&store, 17, try change(peer).encode());
        try dispatch(&value, &turn);
        const first = turn.decision;
        var retry = try external(&store, 17, try change(peer).encode());
        var restarted = owner();
        try dispatch(&restarted, &retry);
        try t.expectEqualDeep(first, retry.decision);
        try store.commit(retry);
    }
    turn = try store.capture();
    try t.expectEqual(@as(u64, 17), (try q.UnifiedCapture.policy(&turn, 9)).?.target.catalog.principal);
    try t.expectEqual(@as(u64, 17), (try q.UnifiedCapture.policy(&turn, 10)).?.target.catalog.principal);
    value.tables.configuration.administrator += 1;
    try t.expectError(error.CatalogConfigurationChanged, Owner.check(value.tables.configuration, &turn));
}
test "catalog delegation authenticates the administrator and isolates rights and revisions" {
    var store: Store = .{};
    defer store.deinit();
    var value = owner();
    try initialize(&store, &value);
    var turn = try external(&store, 9, try change(9).encode());
    try dispatch(&value, &turn);
    try t.expectEqual(.denied, try outcome(&turn));
    try t.expectEqual(null, try q.UnifiedCapture.policy(&turn, 9));
    try store.commit(turn);
    turn = try input(&store, .{ .process = .{ .pid = 17, .turn = 1, .output = 0 } }, .{ .kind = .cast, .payload = try change(9).encode() });
    try dispatch(&value, &turn);
    try t.expectEqual(.denied, try outcome(&turn));
    try store.commit(turn);
    turn = try external(&store, 17, try change(9).encode());
    try dispatch(&value, &turn);
    try store.commit(turn);
    var revised = change(9);
    revised.expected_revision = 1;
    revised.policy.revision = 2;
    revised.policy.allow = false;
    turn = try external(&store, 17, try revised.encode());
    try dispatch(&value, &turn);
    try store.commit(turn);
    turn = try external(&store, 17, try change(9).encode());
    try dispatch(&value, &turn);
    try t.expectEqual(.stale_policy, try outcome(&turn));
    try store.commit(turn);
    turn = try external(&store, 17, try revised.encode());
    try dispatch(&value, &turn);
    try t.expectEqual(.policy_applied, try outcome(&turn));
    const catalog: c.TableCatalog = .{ .configuration = value.tables.configuration };
    _ = try catalog.authorize(&turn, 17, .insert);
    _ = try catalog.authorize(&turn, 17, .read);
    try t.expect(!(try q.UnifiedCapture.policy(&turn, 9)).?.allow);
}
test "catalog query calls require committed delegation before accessing request bodies" {
    var store: Store = .{};
    defer store.deinit();
    var value = owner();
    try initialize(&store, &value);
    const ref: s.PublicationReference = .{ .domain = .query_request, .resource = 8, .namespace = 1, .record = 1, .spec = .{ .format = q.Bundle.format, .length = q.Bundle.header_bytes, .digest = @splat(0) } };
    var turn = try input(&store, .{ .process = .{ .pid = 9, .turn = 1, .output = 0 } }, .{ .kind = .call, .correlation = 77, .payload = try ref.encode() });
    // resources is intentionally undefined: a denied call must not inspect it.
    try dispatch(&value, &turn);
    const reply = try s.Frame.decode(turn.decision.outputs[0].?.value);
    try t.expectEqual(.policy_denied, (try q.QueryFailure.decode(reply.payload)).code);
    try t.expectEqual(@as(usize, 0), store.versions.count());
    try store.commit(turn);
    const continuation: r.Continuation = .{ .job = 100, .input = 100 };
    turn = try input(&store, .{ .process = .{ .pid = 9, .turn = 1, .output = 0 } }, .{ .kind = .cast, .payload = try continuation.encode() });
    try dispatch(&value, &turn);
    try t.expectEqualStrings("UnexpectedQueryContinuation", (try turn.read(r.key('e', turn.delivery.input.position, 0))).?.slice());
}

test "catalog delegation rolls back exhausted proposals and propagates poisoned reads" {
    var store: Store = .{};
    defer store.deinit();
    var value = owner();
    try initialize(&store, &value);
    var turn = try external(&store, 17, try change(9).encode());
    // Leave room for the policy but not its mandatory input disposition.
    for ([_][]const u8{ "a", "b", "c" }) |key| try turn.write(try q.protocol.Value.init(key), try q.protocol.Value.init("original"));
    const before = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, dispatch(&value, &turn));
    try t.expectEqualDeep(before, turn.decision);
    try t.expectEqual(null, try q.UnifiedCapture.policy(&turn, 9));
    turn = try external(&store, 17, try change(9).encode());
    const untouched = turn.decision;
    store.denied = true;
    try t.expectError(error.AccessDenied, dispatch(&value, &turn));
    try t.expectEqualDeep(untouched, turn.decision);
    try t.expectEqual(error.AccessDenied, turn.read_error.?);
    store.denied = false;
    turn = try external(&store, 17, try change(9).encode());
    try dispatch(&value, &turn);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqualDeep(change(9).policy, (try q.UnifiedCapture.policy(&turn, 9)).?);
}
