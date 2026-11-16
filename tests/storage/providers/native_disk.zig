//! Shared fixture operations for the real disk authority proofs. Production
//! transitions remain signed; raw reads below inspect committed recovery state.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_local");
pub const g = core.protocol.Growth;
pub const Engine = core.Engine(adapter.Store, adapter.PageStore);
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
/// Native checkpoint publication is already in the accepted WAL entry. Verify
/// that evidence without trimming, then the parent kills the proof process.
pub fn assertCheckpointPublished(store: *adapter.Store) !void {
    const tail = try store.tail();
    const saved = (try store.read(tail - 1)) orelse return error.MissingFixtureHead;
    const head = switch (saved) {
        .genesis => |value| value.head,
        .operation => |value| value.next,
    };
    if (head.history_floor == 0 or head.position != tail) return error.MissingCheckpoint;
}
pub fn open(init: std.process.Init, directory: []const u8, name: []const u8) !adapter.Backend {
    const path = try std.fs.path.join(init.gpa, &.{ directory, name });
    defer init.gpa.free(path);
    return adapter.Backend.open(init.gpa, init.io, std.Io.Dir.cwd(), path, .{});
}
pub fn completed(io: std.Io) !void {
    try std.Io.File.stdout().writeStreamingAll(io, "native-proof-complete\n");
    // The external driver must observe completion and SIGKILL this live process.
    try io.sleep(.fromSeconds(30), .awake);
    return error.ExpectedParentKill;
}
