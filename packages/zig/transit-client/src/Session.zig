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
    work_before_ms: ?u64 = null,
};
pub const Decision = struct {
    state: p.Value,
    outputs: [p.max_turn_outputs]?p.Output = @splat(null),
    effect: ?p.Value = null,
    failed: bool = false,
};
pub const StateDecision = struct {
    views: [p.State.max_views]?p.State.View = @splat(null),
    write_view: ?u64 = null,
    mutations: [p.State.max_mutations]?p.State.Mutation = @splat(null),
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
    switch (process.lifecycle) {
        .expired => return error.ProcessExpired,
        .terminated => return error.ProcessTerminated,
        .running => {},
    }
    if (process.owner != self.principal or process.generation != self.generation) return error.StaleActivation;
    if (process.failure != null) return error.BlockedProcess;
    const input = view.input orelse return null;
    if (input.origin.version != 1) return error.InvalidAuthorityResponse;
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
        .work_before_ms = process.work_before_ms,
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

/// Opening a view is a durable mutation. Reconcile its Pending, then receive
/// again to obtain the next principal sequence before preparing another command.
pub fn prepareStateView(self: *const Session, delivery: Delivery, resource: p.State.Resource, deadline_ms: u64) !Pending {
    if (delivery.needs_permit) return error.MissingTurnPermit;
    return self.prepare(delivery, .{ .state = .{ .open = .{ .pid = self.pid, .generation = self.generation, .input = delivery.input.position, .expected_revision = delivery.revision, .resource = resource.id, .revision = resource.revision, .deadline_ms = deadline_ms } } });
}
pub fn readStateView(self: *Session, view: u64, key: ?p.Value) !p.State.Page {
    return self.client.state(.{ .realm = self.realm, .principal = self.principal, .kind = .view, .pid = self.pid, .view = view, .key = key }, self.key);
}
pub fn associations(self: *Session) !p.State.Page {
    return self.client.state(.{ .realm = self.realm, .principal = self.principal, .kind = .associations, .pid = self.pid }, self.key);
}
pub fn prepareCloseStateView(self: *const Session, delivery: Delivery, view: u64) !Pending {
    return self.prepare(delivery, .{ .state = .{ .close = .{ .pid = self.pid, .view = view } } });
}
pub fn prepareStateCommit(self: *const Session, delivery: Delivery, decision: StateDecision) !Pending {
    const ordinary = try self.prepareCommit(delivery, .{ .state = delivery.state, .outputs = decision.outputs, .effect = decision.effect, .failed = decision.failed });
    var command: p.State.Turn = .{ .turn = ordinary.signed.request.command.turn, .write_view = decision.write_view, .mutations = decision.mutations };
    for (decision.views, 0..) |slot, index| if (slot) |view| {
        if (view.pid != self.pid or view.principal != self.principal or view.generation != self.generation or view.input != delivery.input.position or view.process_revision != delivery.revision) return error.InvalidStateView;
        command.views[index] = view.id;
    };
    return self.prepare(delivery, .{ .state = .{ .turn = command } });
}

test "state decisions freeze mutations and exact view identities for retry" {
    var client: wire.Client = undefined;
    const session: Session = .{ .client = &client, .realm = 1, .principal = 1, .pid = 2, .generation = 3, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) };
    const delivery: Delivery = .{ .realm = 1, .principal = 1, .pid = 2, .generation = 3, .sequence = 4, .revision = 5, .input = .{ .origin = .{ .source = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .position = 6, .value = .{} }, .state = try p.Value.init("legacy"), .permit = null, .needs_permit = false };
    const view: p.State.View = .{ .id = 7, .pid = 2, .principal = 1, .generation = 3, .input = 6, .process_revision = 5, .resource = 8, .revision = 9, .deadline_ms = 10 };
    var decision: StateDecision = .{ .views = .{ view, null, null, null }, .write_view = 7, .mutations = .{ .{ .key = try p.Value.init("key"), .value = try p.Value.init("frozen") }, null, null, null } };
    const pending = try session.prepareStateCommit(delivery, decision);
    decision.mutations[0].?.value = .{};
    try std.testing.expectEqualStrings("frozen", pending.signed.request.command.state.turn.mutations[0].?.value.?.slice());
    try std.testing.expectEqualStrings("legacy", pending.signed.request.command.state.turn.turn.result.slice());
    decision.views[0].?.generation = 4;
    try std.testing.expectError(error.InvalidStateView, session.prepareStateCommit(delivery, decision));
}

test "pending commits own bytes and cannot be prepared for another activation" {
    const t = std.testing;
    var client: wire.Client = undefined; // Preparation performs no transport I/O.
    const session: Session = .{ .client = &client, .realm = 1, .principal = 1, .pid = 2, .generation = 3, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) };
    var delivery: Delivery = .{ .realm = 1, .principal = 1, .pid = 2, .generation = 3, .sequence = 4, .revision = 5, .input = .{ .origin = .{ .source = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .position = 6, .value = try p.Value.init("message") }, .state = .{}, .permit = null, .needs_permit = false };
    var decision: Decision = .{ .state = try p.Value.init("owned state") };
    const pending = try session.prepareCommit(delivery, decision);
    decision.state = .{};
    delivery.input.value = .{};
    try t.expectEqualStrings("owned state", pending.signed.request.command.turn.result.slice());
    try t.expectEqual(@as(u64, 5), pending.signed.request.command.turn.expected_revision);
    delivery.generation = 4;
    try t.expectError(error.WrongActivation, session.prepareCommit(delivery, decision));
}
