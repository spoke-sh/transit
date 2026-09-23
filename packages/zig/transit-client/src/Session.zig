//! One authorized activation. All returned values own their bytes. A pending
//! operation is immutable retry material; transport failure is not rejection.
const std = @import("std");
const wire = @import("root.zig");
const p = wire.protocol;
const Session = @This();
client: *wire.Client,
realm: u64,
principal: u8,
pid: u64,
generation: u64,
key: p.Ed25519.KeyPair,

pub const Delivery = struct {
    realm: u64,
    principal: u8,
    pid: u64,
    generation: u64,
    sequence: u64,
    revision: u64,
    input: p.Input,
    state: p.Value,
    permit: ?u64,
    needs_permit: bool,
};
pub const Decision = struct {
    state: p.Value,
    outputs: [p.max_turn_outputs]?p.Output = @splat(null),
    effect: ?p.Value = null,
    failed: bool = false,
};
pub const Pending = struct {
    signed: p.SignedRequest,

    /// Retry this exact signed request after an uncertain transport outcome.
    /// No automatic retry, new sequence, or external dispatch occurs here.
    pub fn submit(self: *const Pending, client: *wire.Client) !p.Receipt {
        return client.submit(self.signed);
    }
};

pub fn receive(self: *Session) !?Delivery {
    const view = try self.client.view(.{ .realm = self.realm, .principal = self.principal, .sequence = 0, .command = .{ .inspect = self.pid } }, self.key);
    const process = view.process;
    if (process.pid != self.pid) return error.InvalidAuthorityResponse;
    if (process.lifecycle != .running or process.owner != self.principal or process.generation != self.generation) return error.StaleActivation;
    if (process.failure != null) return error.BlockedProcess;
    const input = view.input orelse return null;
    return .{
        .realm = self.realm,
        .principal = self.principal,
        .pid = self.pid,
        .generation = self.generation,
        .sequence = try std.math.add(u64, view.principal_sequence, 1),
        .revision = process.revision,
        .input = input,
        .state = process.state,
        .permit = if (process.turn_permit) |permit| permit.id else null,
        .needs_permit = process.work_before_ms != null and process.turn_permit == null,
    };
}
fn prepare(self: *const Session, delivery: Delivery, command: p.Command) !Pending {
    if (delivery.realm != self.realm or delivery.principal != self.principal or delivery.pid != self.pid or delivery.generation != self.generation) return error.WrongActivation;
    return .{ .signed = try p.sign(.{ .realm = self.realm, .principal = self.principal, .sequence = delivery.sequence, .command = command }, self.key) };
}
pub fn prepareBegin(self: *const Session, delivery: Delivery) !Pending {
    if (!delivery.needs_permit) return error.InvalidTurnPermit;
    return self.prepare(delivery, .{ .begin_turn = .{ .pid = self.pid, .generation = self.generation, .input = delivery.input.position } });
}
pub fn prepareCommit(self: *const Session, delivery: Delivery, decision: Decision) !Pending {
    if (delivery.needs_permit) return error.MissingTurnPermit;
    return self.prepare(delivery, .{ .turn = .{
        .pid = self.pid,
        .generation = self.generation,
        .input = delivery.input.position,
        .expected_revision = delivery.revision,
        .permit = delivery.permit,
        .result = decision.state,
        .outputs = decision.outputs,
        .effect = decision.effect,
        .failed = decision.failed,
    } });
}

test "pending commits own bytes and cannot be prepared for another activation" {
    const t = std.testing;
    var client: wire.Client = undefined; // Preparation performs no transport I/O.
    const session: Session = .{ .client = &client, .realm = 1, .principal = 1, .pid = 2, .generation = 3, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) };
    var delivery: Delivery = .{ .realm = 1, .principal = 1, .pid = 2, .generation = 3, .sequence = 4, .revision = 5, .input = .{ .position = 6, .value = try p.Value.init("message") }, .state = .{}, .permit = null, .needs_permit = false };
    var decision: Decision = .{ .state = try p.Value.init("owned state") };
    const pending = try session.prepareCommit(delivery, decision);
    decision.state = .{};
    delivery.input.value = .{};
    try t.expectEqualStrings("owned state", pending.signed.request.command.turn.result.slice());
    try t.expectEqual(@as(u64, 5), pending.signed.request.command.turn.expected_revision);
    delivery.generation = 4;
    try t.expectError(error.WrongActivation, session.prepareCommit(delivery, decision));
}
