const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const r = q.TableMutationRecords;
const Owner = q.TableQueryWriter;
const Store = q.testing.Store;
fn source() q.UnifiedBehavior.Source {
    return .{ .peer = 9, .initializer = 17, .resources = undefined, .adapter = &.{}, .workspace = &.{}, .cancellation = undefined };
}
fn configuration() Owner.Configuration {
    return .{ .writer = .{ .resource = 7, .initializer = 17, .principal = 10, .table = 9, .permissions = 7 }, .peer = 9, .requests = 8, .allow = true, .limits = .{ .pages = 1000, .segments = 100, .result_bytes = 1048576 } };
}
fn input(store: *Store, origin: @FieldType(p.Input, "origin"), frame: s.Frame) !s.Turn {
    var turn = try store.capture();
    turn.delivery.input.origin = origin;
    turn.delivery.input.value = try frame.encode();
    return turn;
}
fn external(store: *Store, principal: u64, payload: p.Value) !s.Turn {
    return input(store, .{ .external = .{ .principal = principal, .policy_revision = 1 } }, .{ .kind = .cast, .payload = payload });
}
fn process(store: *Store, peer: u64, frame: s.Frame) !s.Turn {
    return input(store, .{ .process = .{ .pid = peer, .turn = 1, .output = 0 } }, frame);
}
fn dispatch(owner: *Owner, turn: *s.Turn) !void {
    const admission = owner.guard();
    if (try admission.reject(admission.context, turn)) return;
    const handler = owner.interface();
    if (try turn.read(s.GenServer.descriptor_key) == null) {
        try turn.write(s.GenServer.descriptor_key, s.GenServer.descriptor);
        try handler.initialize.?(handler.context, turn);
    }
    try handler.handle(handler.context, turn, try s.Frame.decode(turn.delivery.input.value));
}
fn count(turn: *s.Turn) usize {
    var result: usize = 0;
    for (turn.decision.mutations) |entry| if (entry != null) {
        result += 1;
    };
    return result;
}
fn stage(store: *Store, owner: *Owner) !void {
    var turn = try external(store, 17, try owner.configuration.initializeCommand());
    try dispatch(owner, &turn);
    try t.expectEqual(4, count(&turn));
    try t.expectEqual(.staged, (try owner.phase(&turn)).?);
    try t.expectEqual(store.pid, turn.decision.outputs[0].?.pid);
    const scheduled = try s.Frame.decode(turn.decision.outputs[0].?.value);
    try t.expect(scheduled.payload.eql(try owner.configuration.continuation()));
    try store.commit(turn);
}
fn ready(store: *Store, owner: *Owner) !void {
    var turn = try process(store, store.pid, .{ .kind = .cast, .payload = try owner.configuration.continuation() });
    try dispatch(owner, &turn);
    try t.expectEqual(4, count(&turn));
    try t.expectEqual(.ready, (try owner.phase(&turn)).?);
    try store.commit(turn);
}
fn rejected(turn: *s.Turn, reason: q.TableMutationWriter.Rejection) !void {
    const result = try q.TableMutationWriter.Disposition.decode((try turn.read(r.key('e', turn.delivery.input.position, 0))).?);
    try t.expectEqual(reason, result.reason);
    try t.expectEqualSlices(u8, &try q.TableMutationWriter.Disposition.fingerprint(turn.delivery.input.value), &result.payload);
}
test "combined Table owner matches independently generated configuration, phase and policy bytes" {
    const Fixture = struct { version: u8, configuration: []const u8, initialize: []const u8, continuation: []const u8, staged: []const u8, ready: []const u8, policy_change: []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/table-query-writer-v1.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    const config = configuration();
    var bytes: [256]u8 = undefined;
    const actual = .{ try config.encode(), try config.initializeCommand(), try config.continuation(), try config.state(.staged), try config.state(.ready) };
    inline for (.{ "configuration", "initialize", "continuation", "staged", "ready" }, 0..) |field, index| try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&bytes, @field(fixture, field)), actual[index].slice());
    const encoded = try p.Value.init(try std.fmt.hexToBytes(&bytes, fixture.policy_change));
    const policy = try Owner.QueryPolicyChange.decode(encoded);
    try t.expect(encoded.eql(try policy.encode()));
    try t.expectEqualSlices(u8, &try q.Bundle.declaration(try config.definition()), &policy.policy.target.declaration);
    for (0..encoded.len) |length| {
        if (Owner.QueryPolicyChange.decode(try p.Value.init(encoded.slice()[0..length]))) |_| return error.AcceptedTruncation else |_| {}
    }
    var invalid = encoded;
    invalid.len += 1;
    try t.expectError(error.InvalidQueryPolicyChange, Owner.QueryPolicyChange.decode(invalid));
    var maximum = config;
    maximum.writer.key_name = "abcdefghijklmnop";
    maximum.writer.value_name = "ABCDEFGHIJKLMNOP";
    try t.expectEqual(119, (try maximum.encode()).len);
    try t.expectEqual(124, (try maximum.state(.ready)).len);
    maximum.writer.initializer = 0;
    try t.expectError(error.InvalidQueryIdentity, maximum.encode());
}
test "combined initialization is bounded, freezes configuration and resumes from a new owner" {
    var store: Store = .{};
    defer store.deinit();
    var query = source();
    var owner: Owner = .{ .configuration = configuration(), .source = &query };
    var turn = try external(&store, 10, try owner.configuration.initializeCommand());
    try t.expectError(error.UninitializedTableQueryWriter, dispatch(&owner, &turn));
    try t.expectEqual(0, count(&turn));
    try stage(&store, &owner);
    turn = try store.capture();
    try t.expectEqual(.staged, (try owner.phase(&turn)).?);
    try t.expectEqual(null, try q.TableMutationAdmission.policy(&turn, 10, 9));
    try t.expectEqual(null, try q.UnifiedCapture.policy(&turn, 9));
    try t.expectEqual(null, try (try s.Table.open(&turn, 9)).get(&turn, 0));
    // The entire phase-one proposal may be replayed only through native exact
    // commit recovery. A new admitted initializer is an idempotent no-op.
    turn = try external(&store, 17, try owner.configuration.initializeCommand());
    try dispatch(&owner, &turn);
    try t.expectEqual(0, count(&turn));
    for (turn.decision.outputs) |output| try t.expect(output == null);
    owner.configuration.allow = false;
    try t.expectError(error.TableQueryWriterConfigurationChanged, dispatch(&owner, &turn));
    owner.configuration = configuration();
    query.peer += 1;
    try t.expectError(error.TableQueryWriterConfigurationChanged, dispatch(&owner, &turn));
    query = source();
    var replacement: Owner = .{ .configuration = configuration(), .source = &query };
    try ready(&store, &replacement);
    turn = try process(&store, store.pid, .{ .kind = .cast, .payload = try replacement.configuration.continuation() });
    try dispatch(&replacement, &turn);
    try t.expectEqual(0, count(&turn));
    try t.expectEqual(1, (try q.TableMutationAdmission.policy(&turn, 10, 9)).?.revision);
    try t.expect((try q.UnifiedCapture.policy(&turn, 9)).?.allow);
}
test "staged ingress and forged continuations cannot execute or block later activation" {
    var store: Store = .{};
    defer store.deinit();
    var query = source();
    var owner: Owner = .{ .configuration = configuration(), .source = &query };
    try stage(&store, &owner);
    var turn = try external(&store, 17, try owner.configuration.continuation());
    try dispatch(&owner, &turn);
    try rejected(&turn, .busy);
    try store.commit(turn);
    turn = try process(&store, 9, .{ .kind = .call, .correlation = 8 });
    try dispatch(&owner, &turn);
    try t.expectEqual(0, count(&turn));
    try t.expectEqual(.writer_not_ready, (try q.QueryFailure.decode((try s.Frame.decode(turn.decision.outputs[0].?.value)).payload)).code);
    try store.commit(turn);
    turn = try process(&store, 9, .{ .kind = .cast, .payload = try owner.configuration.continuation() });
    try dispatch(&owner, &turn);
    try t.expectEqual(.staged, (try owner.phase(&turn)).?);
    try store.commit(turn);
    try ready(&store, &owner);
    turn = try process(&store, store.pid, .{ .kind = .reply, .correlation = 8 });
    try dispatch(&owner, &turn);
    try t.expectEqualStrings("UnexpectedTableQueryFrame", (try turn.read(q.UnifiedRecords.key('e', turn.delivery.input.position, 0))).?.slice());
}
test "combined query and mutation revocations are independent and conditionally revised" {
    var store: Store = .{};
    defer store.deinit();
    var query = source();
    var owner: Owner = .{ .configuration = configuration(), .source = &query };
    try stage(&store, &owner);
    try ready(&store, &owner);
    var turn = try store.capture();
    var policy = (try q.UnifiedCapture.policy(&turn, 9)).?;
    policy.allow = false;
    policy.revision = 2;
    var change: Owner.QueryPolicyChange = .{ .resource = 7, .expected_revision = 1, .policy = policy };
    turn = try external(&store, 10, try change.encode());
    try dispatch(&owner, &turn);
    try rejected(&turn, .denied);
    try store.commit(turn);
    change.expected_revision = 0;
    turn = try external(&store, 17, try change.encode());
    try dispatch(&owner, &turn);
    try rejected(&turn, .stale_policy);
    try store.commit(turn);
    change.expected_revision = 1;
    turn = try external(&store, 17, try change.encode());
    try dispatch(&owner, &turn);
    try t.expectEqual(1, count(&turn));
    try store.commit(turn);
    turn = try external(&store, 17, try change.encode());
    try dispatch(&owner, &turn);
    try t.expectEqual(0, count(&turn));
    try t.expectEqual(7, (try q.TableMutationAdmission.policy(&turn, 10, 9)).?.permissions);
    var mutation_policy = (try q.TableMutationAdmission.policy(&turn, 10, 9)).?;
    mutation_policy.permissions = 0;
    mutation_policy.revision = 2;
    turn = try external(&store, 17, try (q.TableMutationWriter.PolicyChange{ .resource = 7, .expected_revision = 1, .policy = mutation_policy }).encode());
    try dispatch(&owner, &turn);
    try store.commit(turn);
    turn = try store.capture();
    try t.expect(std.meta.eql(policy, (try q.UnifiedCapture.policy(&turn, 9)).?));
    change.policy.requests = 100;
    turn = try external(&store, 17, try change.encode());
    try dispatch(&owner, &turn);
    try rejected(&turn, .identity_conflict);
}
test "combined initialization refuses existing owners and rolls back failed bounded proposals" {
    var store: Store = .{};
    defer store.deinit();
    var query = source();
    var owner: Owner = .{ .configuration = configuration(), .source = &query };
    var turn = try external(&store, 17, try owner.configuration.initializeCommand());
    // Exhaust output slots before initialization; all newly proposed state is
    // rolled back when scheduling the durable continuation fails.
    for (0..turn.decision.outputs.len) |_| try turn.cast(3, .{});
    const before = turn.decision;
    const handler = owner.interface();
    if (handler.initialize.?(handler.context, &turn)) |_| return error.AcceptedOverBudget else |_| {}
    try t.expectEqualDeep(before, turn.decision);
    try stage(&store, &owner);
    turn = try process(&store, store.pid, .{ .kind = .cast, .payload = try owner.configuration.continuation() });
    try turn.write(try p.Value.init("unrelated"), .{});
    const before_ready = turn.decision;
    if (handler.handle(handler.context, &turn, try s.Frame.decode(turn.delivery.input.value))) |_| return error.AcceptedOverBudget else |_| {}
    try t.expectEqualDeep(before_ready, turn.decision);
    try t.expectEqual(.staged, (try owner.phase(&turn)).?);
    store.denied = true;
    try t.expectError(error.AccessDenied, dispatch(&owner, &turn));
    try t.expectError(error.AccessDenied, turn.validate());
    store.denied = false;
    try ready(&store, &owner);
    // A standalone writer/source cannot be adopted merely by adding this role.
    _ = store.state.remove(Owner.state_key);
    turn = try external(&store, 17, try owner.configuration.initializeCommand());
    try t.expectError(error.TableQueryWriterAlreadyInitialized, handler.initialize.?(handler.context, &turn));
    try t.expectEqual(0, count(&turn));
}
