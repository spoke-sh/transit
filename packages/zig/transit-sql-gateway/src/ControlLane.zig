//! One principal's bounded control handoff. The host owns this object outside
//! sockets, serializes access and polls detached work while accepting no successor.
const std = @import("std");
const g = @import("root.zig");
const p = g.catalog.protocol;
const Self = @This();
pending: ?struct { prepared: g.Client.Prepared, receipt: ?p.Receipt = null } = null,
pub const Result = union(enum) { idle, pending, processed: ?g.Control.Disposition };
pub fn start(self: *Self, client: anytype, command: g.Control.Command) !void {
    if (self.pending != null) return error.GatewayControlBusy;
    // Prepare has only reads. Ownership transfers before the first send.
    self.pending = .{ .prepared = try client.prepare(command) };
}
pub fn poll(self: *Self, client: anytype) !Result {
    const pending = if (self.pending) |*value| value else return .idle;
    if (pending.receipt == null) pending.receipt = try client.submit(pending.prepared);
    return switch (try client.progress(pending.prepared, pending.receipt.?)) {
        .pending => .pending,
        .processed => |disposition| blk: {
            self.pending = null;
            break :blk .{ .processed = disposition };
        },
    };
}
/// A newly fenced coordinator can race a delayed old-generation scheduler send.
/// Only a definite native ConflictingRetry on an unreceipted private proposal
/// permits recomputation, after checking the actual current native fence. This
/// never touches a published Table SavedStep or an ingress/operator request.
pub fn discardConflictingProposal(self: *Self, coordinator: *g.Coordinator) !void {
    const pending = self.pending orelse return error.GatewayControlNotPending;
    const client = coordinator.client;
    if (pending.receipt != null or client.transport.last_rejection != .ConflictingRetry or pending.prepared.signed.request.principal != client.ledger.configuration.coordinator) return error.GatewayUnresolvedStep;
    try client.validate(pending.prepared);
    try coordinator.fence();
    self.pending = null;
}
test "control handoff survives receipt loss and source failure without allocating a successor" {
    const t = std.testing;
    const Fake = struct {
        key: p.Ed25519.KeyPair,
        prepared: usize = 0,
        sends: usize = 0,
        first: ?g.Client.Prepared = null,
        ready: bool = false,
        fail_read: bool = true,
        fn prepare(self: *@This(), _: g.Control.Command) !g.Client.Prepared {
            self.prepared += 1;
            return .{ .version = 1, .definition = p.Growth.current_definition, .realm = 1, .resource = 2, .owner = 3, .configuration = @splat(7), .signed = try p.Growth.sign(.{ .realm = 1, .principal = 4, .sequence = self.prepared, .command = .{ .send = .{ .pid = 3, .value = try (g.station.Frame{ .kind = .cast, .payload = try (g.Control.Command{ .reconcile = 17 }).encode() }).encode() } } }, self.key) };
        }
        fn submit(self: *@This(), value: g.Client.Prepared) !p.Receipt {
            self.sends += 1;
            if (self.first) |first| try t.expectEqualDeep(first, value) else self.first = value;
            if (self.sends == 1) return error.ConnectionResetByPeer;
            return .{ .position = 31 };
        }
        fn progress(self: *@This(), _: g.Client.Prepared, _: p.Receipt) !g.Client.Progress {
            if (self.fail_read) {
                self.fail_read = false;
                return error.ConnectionResetByPeer;
            }
            return if (self.ready) .{ .processed = null } else .pending;
        }
    };
    var client: Fake = .{ .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(31)) };
    var lane: Self = .{};
    try lane.start(&client, .{ .reconcile = 17 });
    try t.expectError(error.ConnectionResetByPeer, lane.poll(&client));
    // A disconnected caller does not own or destroy the retained request.
    try t.expectError(error.GatewayControlBusy, lane.start(&client, .{ .cancel = 18 }));
    try t.expectError(error.ConnectionResetByPeer, lane.poll(&client));
    try t.expectEqual(@as(?u64, 31), if (lane.pending.?.receipt) |receipt| receipt.position else null);
    try t.expectEqual(Result.pending, try lane.poll(&client));
    client.ready = true;
    try t.expectEqual(Result{ .processed = null }, try lane.poll(&client));
    try t.expectEqual(@as(usize, 1), client.prepared);
    try t.expectEqual(@as(usize, 2), client.sends);
    try t.expectEqual(Result.idle, try lane.poll(&client));
}
