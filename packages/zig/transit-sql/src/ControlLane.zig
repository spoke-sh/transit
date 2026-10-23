//! One principal's bounded control handoff. The host owns this object outside
//! sockets and serializes exact native attempts. Immutable intent parts may
//! advance after native admission; ordinary controls wait for domain processing.
const std = @import("std");
const g = @import("root.zig");
const p = g.catalog.protocol;
const Self = @This();
pending: ?struct { prepared: g.Client.Prepared, receipt: ?p.Receipt = null, admission_only: bool = false } = null,
pub const Result = union(enum) { idle, pending, admitted: p.Receipt, processed: ?g.Control.Disposition };
pub fn start(self: *Self, client: anytype, command: g.Control.Command) !void {
    if (self.pending != null) return error.GatewayControlBusy;
    // Prepare has only reads. Ownership transfers before the first send.
    const prepared = try client.prepare(command);
    self.pending = .{ .prepared = prepared };
}
/// Only immutable parts use this path. The ordered durable mailbox owns an
/// admitted part; the ordinary seal control still waits for full validation.
pub fn startPart(self: *Self, client: anytype, part: @FieldType(g.Control.Command, "intent_part")) !void {
    try self.start(client, .{ .intent_part = part });
    self.pending.?.admission_only = true;
}
pub fn poll(self: *Self, client: anytype) !Result {
    const pending = if (self.pending) |*value| value else return .idle;
    if (pending.receipt == null) {
        const receipt = try client.submit(pending.prepared);
        if (receipt.position == 0 or receipt.position > p.max_counter) return error.InvalidGatewayReceipt;
        pending.receipt = receipt;
    }
    if (pending.admission_only) {
        const receipt = pending.receipt.?;
        self.pending = null;
        return .{ .admitted = receipt };
    }
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
/// never replaces a published direct intent reference or an ingress/operator request.
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

test "failed preparation cannot publish a partially initialized control" {
    const t = std.testing;
    const Fake = struct {
        failure: bool = true,
        fn sign(self: *@This()) !p.Growth.SignedRequest {
            if (self.failure) return error.AuthorityTimeout;
            return error.UnexpectedTestPath;
        }
        fn prepare(self: *@This(), _: g.Control.Command) !g.Client.Prepared {
            return .{ .version = 1, .definition = p.Growth.current_definition, .realm = 1, .resource = 2, .owner = 3, .configuration = @splat(7), .signed = try self.sign() };
        }
    };
    var client: Fake = .{};
    var lane: Self = .{};
    try t.expectError(error.AuthorityTimeout, lane.start(&client, .{ .initialize = {} }));
    try t.expect(lane.pending == null);
    try t.expectError(error.AuthorityTimeout, lane.start(&client, .{ .initialize = {} }));
    try t.expect(lane.pending == null);
}

test "intent parts advance only after valid native admission and seal retains its processing barrier" {
    const t = std.testing;
    const Fake = struct {
        key: p.Ed25519.KeyPair,
        prepared: usize = 0,
        sends: usize = 0,
        observations: usize = 0,
        first: ?g.Client.Prepared = null,
        ready: bool = false,
        fn prepare(self: *@This(), command: g.Control.Command) !g.Client.Prepared {
            self.prepared += 1;
            return .{ .version = 1, .definition = p.Growth.current_definition, .realm = 1, .resource = 2, .owner = 3, .configuration = @splat(7), .signed = try p.Growth.sign(.{ .realm = 1, .principal = 4, .sequence = self.prepared, .command = .{ .send = .{ .pid = 3, .value = try (g.station.Frame{ .kind = .cast, .payload = try command.encode() }).encode() } } }, self.key) };
        }
        fn submit(self: *@This(), value: g.Client.Prepared) !p.Receipt {
            self.sends += 1;
            if (value.signed.request.sequence == 1) {
                if (self.first) |first| try t.expectEqualDeep(first, value) else self.first = value;
                if (self.sends == 1) return error.ConnectionResetByPeer;
                if (self.sends == 2) return .{ .position = 0 };
            }
            return .{ .position = 30 + value.signed.request.sequence };
        }
        fn progress(self: *@This(), value: g.Client.Prepared, _: p.Receipt) !g.Client.Progress {
            self.observations += 1;
            try t.expectEqual(@as(u64, 3), value.signed.request.sequence);
            if (!self.ready) return .pending;
            var rejected: g.Control.Disposition = .{ .input = 33, .principal = 4, .payload = @splat(0), .cause_length = 21, .cause = @splat(0) };
            @memcpy(rejected.cause[0..21], "IncompletePublication");
            try rejected.validate();
            return .{ .processed = rejected };
        }
    };
    var client: Fake = .{ .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(31)) };
    var lane: Self = .{};
    const part = try g.Control.Part.init(0, &@as([g.Upload.part_bytes]u8, @splat(9)));
    try lane.startPart(&client, .{ .operation = 7, .part = part });
    try t.expectError(error.ConnectionResetByPeer, lane.poll(&client));
    try t.expectError(error.GatewayControlBusy, lane.startPart(&client, .{ .operation = 7, .part = part }));
    try t.expectError(error.InvalidGatewayReceipt, lane.poll(&client));
    try t.expect(lane.pending != null and lane.pending.?.receipt == null);
    try t.expectEqual(Result{ .admitted = .{ .position = 31 } }, try lane.poll(&client));
    try lane.startPart(&client, .{ .operation = 7, .part = try g.Control.Part.init(128, "end") });
    try t.expectEqual(Result{ .admitted = .{ .position = 32 } }, try lane.poll(&client));
    try t.expectEqual(@as(usize, 0), client.observations);
    // Native acceptance of all parts is not publication or a successful write.
    try lane.start(&client, .{ .seal_intent = 7 });
    try t.expectEqual(Result.pending, try lane.poll(&client));
    try t.expectError(error.GatewayControlBusy, lane.start(&client, .{ .reconcile = 7 }));
    client.ready = true;
    const result = try lane.poll(&client);
    try t.expectEqualStrings("IncompletePublication", result.processed.?.cause[0..result.processed.?.cause_length]);
    try t.expectEqual(@as(usize, 5), client.sends);
    try t.expectEqual(@as(usize, 3), client.prepared);
    try t.expectEqual(Result.idle, try lane.poll(&client));
}
