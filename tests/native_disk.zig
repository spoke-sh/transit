//! Shared fixture operations for the real disk authority proofs. Production
//! transitions remain signed; raw reads below inspect committed recovery state.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
pub const g = core.protocol.Growth;
pub const Engine = core.Engine(adapter.Store, adapter.PackedPageStore);
pub const Clock = struct {
    now: u64 = 1000,
    pub fn read(context: *anyopaque) !core.Time.Sample {
        const self: *Clock = @ptrCast(@alignCast(context));
        return .{ .unix_ms = self.now };
    }
};
pub fn signed(e: *Engine, key: core.Ed25519.KeyPair, principal: u64, command: g.Command) !g.SignedRequest {
    var current = command;
    if (current == .turn) current.turn.expected_revision = (try e.process(current.turn.pid)).revision;
    return g.sign(.{ .realm = e.genesis.realm, .principal = principal, .sequence = (try e.principal(principal)).sequence + 1, .command = current }, key);
}
pub fn submit(e: *Engine, key: core.Ed25519.KeyPair, principal: u64, command: g.Command) !u64 {
    return e.submit(try signed(e, key, principal, command));
}
pub fn record(e: *Engine, comptime T: type, namespace: core.catalog.Namespace, id: u64) !T {
    var state = try e.state();
    return (try state.get(T, core.growing.address(namespace, id))) orelse error.MissingFixtureRecord;
}
pub fn input(e: *Engine, pid: u64) !?g.Input {
    const process = try e.process(pid);
    if (process.lifecycle != .running or process.consumed == process.admitted) return null;
    var state = try e.state();
    return (try state.get(g.Input, try core.catalog.key(.mailbox, pid, process.consumed + 1, ""))) orelse error.MissingFixtureInput;
}
pub fn entry(e: *Engine, resource: u64, key: []const u8) !?g.Entry {
    var state = try e.state();
    return state.get(g.Entry, try core.catalog.key(.entry, resource, 0, key));
}
pub fn counterResource(e: *Engine, pid: u64) !u64 {
    var state = try e.state();
    const association = (try state.get(g.Association, try core.catalog.key(.association, pid, 0, "counter"))) orelse return error.MissingCounter;
    return association.resource;
}
pub fn counter(e: *Engine, pid: u64) !i64 {
    const value = try entry(e, try counterResource(e, pid), "count");
    return if (value) |item| item.value.asInteger() else 0;
}
pub fn provisionCounter(e: *Engine, root: core.Ed25519.KeyPair, pid: u64, worker: u64) !void {
    const id = try submit(e, root, 0, .{ .create_resource = .{ .writer = pid } });
    _ = try submit(e, root, 0, .{ .grant_resource = .{ .resource = id, .subject = 0, .permissions = 7 } });
    if (worker != 0) _ = try submit(e, root, 0, .{ .grant_resource = .{ .resource = id, .subject = worker, .permissions = 7 } });
    _ = try submit(e, root, 0, .{ .associate = .{ .pid = pid, .resource = id, .name = try core.Value.init("counter") } });
}
pub fn counterTurn(e: *Engine, key: core.Ed25519.KeyPair, worker: u64, pid: u64, value: i64) !g.Command {
    const process = try e.process(pid);
    const id = try counterResource(e, pid);
    const resource = try record(e, g.Resource, .resource, id);
    const next = (try input(e, pid)) orelse return error.MissingFixtureInput;
    const view = try submit(e, key, worker, .{ .open_view = .{ .pid = pid, .generation = process.generation, .input = next.position, .expected_revision = process.revision, .resource = id, .revision = resource.revision, .deadline_ms = 2000 } });
    return .{ .turn = .{ .pid = pid, .generation = process.generation, .input = next.position, .expected_revision = process.revision, .views = .{ view, null, null, null }, .write_view = view, .mutations = .{ .{ .key = try core.Value.init("count"), .value = core.Value.integer(value) }, null, null, null } } };
}
/// Inject the actual publication/trim crash boundary. The production maintain
/// operation performs both; this fixture publishes only, then kills the store.
pub fn publish(store: *adapter.Store) !void {
    const tail = try store.tail();
    const saved = (try store.read(tail - 1)) orelse return error.MissingFixtureHead;
    var bytes: [adapter.max_record_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try std.json.Stringify.value(adapter.Store.Checkpoint{ .entry = saved }, .{}, &writer);
    var response = try store.journal.client.send(.{ .publish_snapshot = .{ .stream = store.journal.stream, .at = .{ .record = tail }, .body = writer.buffered(), .content_type = "application/json" } });
    defer response.deinit();
    try response.head.requireSuccess();
    _ = (try store.loadCheckpoint()) orelse return error.MissingCheckpoint;
}
