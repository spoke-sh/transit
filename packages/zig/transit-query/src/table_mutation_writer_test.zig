const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const s = q.station;
const r = q.TableMutationRecords;
const a = q.TableMutationAdmission;
const Writer = q.TableMutationWriter;
const Store = q.testing.Store;
test "writer configuration controls and input dispositions match independent canonical bytes" {
    const Fixture = struct { version: u8, configuration: []const u8, initialize: []const u8, policy_change: []const u8, frame: []const u8, dispositions: []const struct { reason: u8, wire_hex: []const u8 } };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/table-mutation-writer-v1.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    var bytes: [256]u8 = undefined;
    const config: Writer.Configuration = .{ .resource = 7, .initializer = 17, .principal = 10, .table = 9, .permissions = 7 };
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&bytes, fixture.configuration), (try config.encode()).slice());
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&bytes, fixture.initialize), (try config.initializeCommand()).slice());
    const policy_bytes = try q.protocol.Value.init(try std.fmt.hexToBytes(&bytes, fixture.policy_change));
    const policy = try Writer.PolicyChange.decode(policy_bytes);
    try t.expect(policy_bytes.eql(try policy.encode()));
    try t.expectEqual(7, policy.resource);
    try t.expectEqual(3, policy.expected_revision);
    try t.expectEqual(4, policy.policy.revision);
    for (0..policy_bytes.len) |length| {
        if (Writer.PolicyChange.decode(try q.protocol.Value.init(policy_bytes.slice()[0..length]))) |_| return error.AcceptedTruncation else |_| {}
    }
    const frame = try q.protocol.Value.init(try std.fmt.hexToBytes(&bytes, fixture.frame));
    for (fixture.dispositions) |case| {
        const encoded = try q.protocol.Value.init(try std.fmt.hexToBytes(&bytes, case.wire_hex));
        const value = try Writer.Disposition.decode(encoded);
        try t.expect(encoded.eql(try value.encode()));
        try t.expectEqual(case.reason, @backingInt(value.reason));
        try t.expectEqual(10, value.principal);
        try t.expectEqual(123, value.input);
        try t.expectEqualSlices(u8, &try Writer.Disposition.fingerprint(frame), &value.payload);
        for (0..encoded.len) |length| {
            if (Writer.Disposition.decode(try q.protocol.Value.init(encoded.slice()[0..length]))) |_| return error.AcceptedTruncation else |_| {}
        }
        var invalid = encoded;
        invalid.data[52] = 0;
        try t.expectError(error.InvalidMutationDisposition, Writer.Disposition.decode(invalid));
    }
    var maximum = config;
    maximum.key_name = "abcdefghijklmnop";
    maximum.value_name = "ABCDEFGHIJKLMNOP";
    try t.expectEqual(73, (try maximum.encode()).len);
}
fn writer() Writer {
    return .{ .configuration = .{ .resource = 7, .initializer = 17, .principal = 10, .permissions = 7 } };
}
fn input(store: *Store, principal: u64, payload: q.protocol.Value) !s.Turn {
    var turn = try store.capture();
    turn.delivery.input.origin = .{ .external = .{ .principal = principal, .policy_revision = 1 } };
    turn.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = payload }).encode();
    return turn;
}
fn dispatch(owner: *Writer, turn: *s.Turn) !void {
    const guard = owner.guard();
    if (try guard.reject(guard.context, turn)) return;
    const handler = owner.interface();
    try handler.handle(handler.context, turn, try s.Frame.decode(turn.delivery.input.value));
}
fn initialize(store: *Store, owner: *Writer) !void {
    var turn = try input(store, owner.configuration.initializer, try owner.configuration.initializeCommand());
    // Model the real GenServer's first-turn descriptor write.
    try turn.write(s.GenServer.descriptor_key, s.GenServer.descriptor);
    const guard = owner.guard();
    try t.expect(!try guard.reject(guard.context, &turn));
    const handler = owner.interface();
    try handler.initialize.?(handler.context, &turn);
    try handler.handle(handler.context, &turn, try s.Frame.decode(turn.delivery.input.value));
    for (turn.decision.mutations) |mutation| try t.expect(mutation != null);
    try store.commit(turn);
}
fn rejected(turn: *s.Turn, reason: Writer.Rejection) !void {
    const value = (try turn.read(r.key('e', turn.delivery.input.position, 0))).?;
    const result = try Writer.Disposition.decode(value);
    try t.expectEqual(reason, result.reason);
    try t.expectEqual(turn.delivery.input.position, result.input);
    try t.expectEqual(turn.delivery.input.origin.external.principal, result.principal);
    try t.expectEqualSlices(u8, &try Writer.Disposition.fingerprint(turn.delivery.input.value), &result.payload);
    const diagnostic = try q.MutationDiagnostic.input(result);
    try t.expectEqual(.input_rejected, diagnostic.outcome);
    try t.expectEqual(.transport, diagnostic.identity.?.domain);
    try t.expectEqual(result.input, try diagnostic.identity.?.id.value());
    for (diagnostic.actions) |slot| if (slot) |action| try t.expect(action.kind != .resume_exact and action.kind != .cancel_mutation);
}
test "mutation writer initializes only the explicit principal/configuration in four native slots" {
    var store: Store = .{};
    defer store.deinit();
    var owner = writer();
    var turn = try input(&store, 10, try owner.configuration.initializeCommand());
    try t.expectError(error.UninitializedMutationWriter, dispatch(&owner, &turn));
    for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
    try initialize(&store, &owner);
    turn = try store.capture();
    const table = try s.Table.open(&turn, 1);
    try t.expect(std.meta.eql(table, try owner.configuration.target()));
    try t.expectEqual(7, (try a.policy(&turn, 10, 1)).?.permissions);
    turn = try input(&store, 17, try owner.configuration.initializeCommand());
    try dispatch(&owner, &turn);
    for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
    owner.configuration.permissions = 0;
    try t.expectError(error.MutationWriterConfigurationChanged, dispatch(&owner, &turn));
    owner = writer();
    owner.configuration.resource += 1;
    try t.expectError(error.MutationWriterConfigurationChanged, dispatch(&owner, &turn));
}
test "writer records malformed and conflicting input dispositions without replacing request status" {
    var store: Store = .{};
    defer store.deinit();
    var owner = writer();
    try initialize(&store, &owner);
    var turn = try input(&store, 10, try q.protocol.Value.init("unsupported"));
    try dispatch(&owner, &turn);
    try rejected(&turn, .invalid_command);
    try store.commit(turn);
    const request = try q.TableMutationRequest.fromSql(1, store.pid, try owner.configuration.target(), try .init("items"), "DELETE FROM items WHERE id=1");
    const ref = try request.reference(99);
    turn = try input(&store, 10, try (r.Command{ .begin = .{ .reference = ref, .table = 1, .policy_revision = 1 } }).encode());
    try dispatch(&owner, &turn);
    try store.commit(turn);
    const before = (try a.status(&turn, 99)).?;
    turn = try input(&store, 10, try (r.Command{ .begin = .{ .reference = try request.reference(100), .table = 1, .policy_revision = 1 } }).encode());
    try dispatch(&owner, &turn);
    try rejected(&turn, .busy);
    try t.expectEqual(null, try a.status(&turn, 100));
    try t.expect(std.meta.eql(before, (try a.status(&turn, 99)).?));
    try store.commit(turn);
    var wrong = ref;
    wrong.resource += 1;
    turn = try input(&store, 10, try (r.Command{ .apply = wrong }).encode());
    try dispatch(&owner, &turn);
    try rejected(&turn, .identity_conflict);
    try t.expect(std.meta.eql(before, (try a.status(&turn, 99)).?));
}
test "only the configured initializer changes policy; stale changes retain history" {
    var store: Store = .{};
    defer store.deinit();
    var owner = writer();
    try initialize(&store, &owner);
    var turn = try store.capture();
    var policy = (try a.policy(&turn, 10, 1)).?;
    policy.revision = 2;
    policy.permissions = 0;
    var change: Writer.PolicyChange = .{ .resource = store.resource, .expected_revision = 1, .policy = policy };
    turn = try input(&store, 10, try change.encode());
    try dispatch(&owner, &turn);
    try rejected(&turn, .denied);
    try t.expectEqual(1, (try a.policy(&turn, 10, 1)).?.revision);
    try store.commit(turn);
    change.expected_revision = 0;
    turn = try input(&store, 17, try change.encode());
    try dispatch(&owner, &turn);
    try rejected(&turn, .stale_policy);
    try store.commit(turn);
    change.expected_revision = 1;
    turn = try input(&store, 17, try change.encode());
    try dispatch(&owner, &turn);
    try store.commit(turn);
    turn = try store.capture();
    try t.expect(std.meta.eql(policy, (try a.policy(&turn, 10, 1)).?));
}
test "writer does not acknowledge corrupt stored records or poisoned reads" {
    var store: Store = .{};
    defer store.deinit();
    var owner = writer();
    try initialize(&store, &owner);
    const request = try q.TableMutationRequest.fromSql(1, store.pid, try owner.configuration.target(), try .init("items"), "DELETE FROM items WHERE id=1");
    const command = try (r.Command{ .apply = try request.reference(99) }).encode();
    var turn = try input(&store, 10, command);
    store.denied = true;
    try t.expectError(error.AccessDenied, dispatch(&owner, &turn));
    try t.expectError(error.AccessDenied, turn.validate());
    store.denied = false;
    try store.state.put(t.allocator, r.key('u', 99, 0), try q.protocol.Value.init("broken"));
    turn = try input(&store, 10, command);
    if (dispatch(&owner, &turn)) |_| return error.AcceptedCorruptRecord else |_| {}
    for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
}
