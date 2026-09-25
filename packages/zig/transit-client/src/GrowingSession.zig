//! One explicit v3 activation. State access stays bounded and in the caller.
const std = @import("std");
const wire = @import("root.zig");
const p = wire.protocol;
const g = p.Growth;
const Self = @This();

client: *wire.Client,
realm: u64,
principal: u64,
pid: u64,
generation: u64,
key: p.Ed25519.KeyPair,

pub const Delivery = struct {
    realm: u64,
    principal: u64,
    pid: u64,
    generation: u64,
    sequence: u64,
    revision: u64,
    input: g.Input,
    permit: ?u64,
    needs_permit: bool,
    work_before_ms: ?u64 = null,
    settle_before_ms: ?u64 = null,
};
pub const Decision = struct {
    views: [g.turn_views]?g.View = @splat(null),
    write_view: ?u64 = null,
    mutations: [g.turn_mutations]?g.Mutation = @splat(null),
    outputs: [g.turn_outputs]?g.Output = @splat(null),
    effect: ?p.Value = null,
    failed: bool = false,
    read_versions: [g.version_changes]?g.ReadVersionId = @splat(null),
    retain: [g.version_changes]?u64 = @splat(null),
    release: [g.version_changes]?g.ReadVersionId = @splat(null),
};
pub const Pending = struct {
    signed: g.SignedRequest,
    /// Retain this exact value across uncertain outcomes. No automatic retry.
    pub fn submit(self: *const Pending, client: *wire.Client) !p.Receipt {
        return client.submitGrowing(self.signed);
    }
};

pub fn receive(self: *Self) !?Delivery {
    const response = try self.client.queryGrowing(.{ .realm = self.realm, .principal = self.principal, .kind = .{ .process = self.pid } }, self.key);
    const process = response.body.process.process;
    switch (process.lifecycle) {
        .terminated => return error.ProcessTerminated,
        .expired => return error.ProcessExpired,
        .running => {},
    }
    if (process.failure != null) return error.BlockedProcess;
    if (process.owner != self.principal or process.generation != self.generation) return error.StaleActivation;
    const input = response.body.process.input orelse return null;
    return .{ .realm = self.realm, .principal = self.principal, .pid = self.pid, .generation = self.generation, .sequence = try std.math.add(u64, response.principal_sequence, 1), .revision = process.revision, .input = input, .permit = if (process.turn_permit) |permit| permit.id else null, .needs_permit = process.work_before_ms != null and process.turn_permit == null, .work_before_ms = process.work_before_ms, .settle_before_ms = process.settle_before_ms };
}

/// Bounded current metadata lookup; associations do not grant resource access.
/// Hidden/missing targets both return null. No catalog scan or cached decision.
pub fn association(self: *Self, name: p.Value) !?g.Association {
    const response = try self.client.queryGrowing(.{ .realm = self.realm, .principal = self.principal, .kind = .{ .association = .{ .pid = self.pid, .name = name } } }, self.key);
    return response.body.association;
}

fn prepare(self: *const Self, delivery: Delivery, command: g.Command) !Pending {
    if (delivery.realm != self.realm or delivery.principal != self.principal or delivery.pid != self.pid or delivery.generation != self.generation) return error.WrongActivation;
    return .{ .signed = try g.sign(.{ .realm = self.realm, .principal = self.principal, .sequence = delivery.sequence, .command = command }, self.key) };
}
pub fn prepareBegin(self: *const Self, delivery: Delivery) !Pending {
    if (!delivery.needs_permit) return error.InvalidTurnPermit;
    return self.prepare(delivery, .{ .begin_turn = .{ .pid = self.pid, .generation = self.generation, .input = delivery.input.position } });
}
pub fn prepareView(self: *const Self, delivery: Delivery, resource: g.Resource, deadline_ms: u64) !Pending {
    if (delivery.needs_permit) return error.MissingTurnPermit;
    return self.prepare(delivery, .{ .open_view = .{ .pid = self.pid, .generation = self.generation, .input = delivery.input.position, .expected_revision = delivery.revision, .resource = resource.id, .revision = resource.revision, .deadline_ms = deadline_ms } });
}
pub fn readView(self: *Self, view: u64, key: ?p.Value, after: ?p.Value) !@FieldType(@FieldType(g.Response, "body"), "entries") {
    const response = try self.client.queryGrowing(.{ .realm = self.realm, .principal = self.principal, .kind = .{ .entries = .{ .view = view, .key = key, .after = after } } }, self.key);
    const meta = response.body.entries.view orelse return error.InvalidAuthorityResponse;
    if (meta.pid != self.pid or meta.generation != self.generation) return error.InvalidStateView;
    return response.body.entries;
}
pub fn prepareCloseView(self: *const Self, delivery: Delivery, view: u64) !Pending {
    return self.prepare(delivery, .{ .close_view = .{ .pid = self.pid, .view = view } });
}
/// Fetch metadata separately from executable reads. This may report a released
/// version and never implies that source data is still accessible.
pub fn version(self: *Self, id: g.ReadVersionId) !g.ReadVersion {
    if (id.pid != self.pid) return error.WrongActivation;
    return (try self.client.queryGrowing(.{ .realm = self.realm, .principal = self.principal, .kind = .{ .read_version = id } }, self.key)).body.read_version;
}
pub fn readVersion(self: *Self, basis: g.ReadVersion, key: ?p.Value, after: ?p.Value) !@FieldType(@FieldType(g.Response, "body"), "version_entries") {
    if (basis.id.pid != self.pid) return error.WrongActivation;
    if (basis.released_at != null) return error.ReadVersionReleased;
    const response = try self.client.queryGrowing(.{ .realm = self.realm, .principal = self.principal, .kind = .{ .version_entries = .{ .id = basis.id, .generation = self.generation, .key = key, .after = after } } }, self.key);
    if (!std.meta.eql(basis, response.body.version_entries.version)) return error.InvalidAuthorityResponse;
    return response.body.version_entries;
}
pub fn prepareCommit(self: *const Self, delivery: Delivery, decision: Decision) !Pending {
    if (delivery.needs_permit) return error.MissingTurnPermit;
    var turn: g.Turn = .{ .pid = self.pid, .generation = self.generation, .input = delivery.input.position, .expected_revision = delivery.revision, .permit = delivery.permit, .write_view = decision.write_view, .mutations = decision.mutations, .outputs = decision.outputs, .effect = decision.effect, .failed = decision.failed };
    for (decision.views, 0..) |slot, i| if (slot) |view| {
        if (view.pid != self.pid or view.principal != self.principal or view.generation != self.generation or
            view.input != delivery.input.position or view.process_revision != delivery.revision or view.closed_at != null) return error.InvalidStateView;
        turn.views[i] = view.id;
    };
    const extended = for (decision.read_versions, decision.retain, decision.release) |read, retain, release| {
        if (read != null or retain != null or release != null) break true;
    } else false;
    return self.prepare(delivery, if (extended) .{ .turn_with_versions = .{ .turn = turn, .reads = decision.read_versions, .retain = decision.retain, .release = decision.release } } else .{ .turn = turn });
}

test "growing session preserves wide identities and freezes bounded proposals without I/O" {
    const t = std.testing;
    var client: wire.Client = undefined;
    const session: Self = .{ .client = &client, .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) };
    var delivery: Delivery = .{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = 4, .revision = 5, .input = .{ .position = 6, .ordinal = 1, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false };
    var decision: Decision = .{ .views = .{ .{ .id = 7, .pid = 2, .principal = 65536, .generation = 3, .input = 6, .process_revision = 5, .resource = 8, .revision = 9, .deadline_ms = 10 }, null, null, null }, .write_view = 7, .mutations = .{ .{ .key = try p.Value.init("key"), .value = try p.Value.init("owned") }, null, null, null } };
    const pending = try session.prepareCommit(delivery, decision);
    decision.mutations[0].?.value = null;
    try t.expectEqualStrings("owned", pending.signed.request.command.turn.mutations[0].?.value.?.slice());
    try t.expectEqual(@as(u64, 65536), pending.signed.request.principal);
    delivery.sequence += 1;
    try t.expectEqual(@as(u64, 4), pending.signed.request.sequence);
    delivery.pid += 1;
    try t.expectError(error.WrongActivation, session.prepareCommit(delivery, decision));
    delivery.pid -= 1;
    decision.views[0].?.generation += 1;
    try t.expectError(error.InvalidStateView, session.prepareCommit(delivery, decision));
    delivery.needs_permit = true;
    try t.expectError(error.MissingTurnPermit, session.prepareCommit(delivery, .{}));
}
