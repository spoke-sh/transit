//! Private outbox-to-native admission adapter. The embedding consumer persists
//! Saved before admission and records a discoverable effect before settling its
//! scheduling input. This adapter never dispatches, ACKs, or releases a claim.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const Actor = @import("Actor.zig");

pub const Saved = struct {
    definition: p.Growth.Definition,
    connection: c.DirectTableProtocol.Connection,
    admission: @FieldType(c.DirectQueue.Request, "admit_effect"),

    pub fn validate(self: Saved) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try (c.DirectQueue.Request{ .admit_effect = self.admission }).validate(self.connection.principal, self.connection.scope);
        try self.connection.object(self.admission.cursor.receipt.claim.target.interpretation.object);
    }

    /// Serialization is not persistence. The consumer saves these exact bytes
    /// in its durable pending directory before invoking admit.
    pub fn encode(self: Saved, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        return p.Json.valueAllocBounded(allocator, self, c.DirectTableProtocol.max_request_bytes);
    }

    pub fn load(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Saved) {
        if (bytes.len == 0 or bytes.len > c.DirectTableProtocol.max_request_bytes) return error.InvalidEffectSource;
        const parsed = try p.Json.parseFromSliceOwned(Saved, allocator, bytes);
        errdefer parsed.deinit();
        try parsed.value.validate();
        return parsed;
    }

    pub fn admit(self: Saved, output: *std.heap.ArenaAllocator, caller: c.DirectTableClient) !c.DirectQueueClient.Result {
        try self.validate();
        if (!std.meta.eql(self.connection, caller.connection)) return error.InvalidEffectSource;
        return c.DirectQueueClient.apply(output, caller, .{ .admit_effect = self.admission });
    }

    /// Current inspection survives source claim release and credential/owner
    /// replacement. Null is an observation only; it never causes an implicit send.
    pub fn inspect(self: Saved, authority: *c.client.Client, principal: u64, key: p.Ed25519.KeyPair) !?p.Growth.Effect {
        try self.validate();
        const command = self.admission.signed.request.command.admit_effect;
        const binding = try command.source.commitment();
        const result = try authority.query(.{ .realm = self.connection.scope.realm, .principal = principal, .kind = .{ .effect_admission = .{ .pid = command.pid, .key = binding.key } } }, key);
        if (result.body.effect_admission) |effect| if (effect.source == null or !std.meta.eql(effect.source.?, binding)) return error.EffectSourceConflict;
        return result.body.effect_admission;
    }
};

/// Sequence/generation are explicit inputs, never refreshed after uncertainty.
/// An actor's committed outbox row supplies the original transaction and bytes.
pub fn prepare(actor: Actor.Declaration, page: c.DirectQueueClient.Page, index: usize, generation: u64, sequence: u64, key: p.Ed25519.KeyPair) !Saved {
    try actor.validate();
    try actor.outbox.requireSame(page.cursor.receipt.claim.target);
    const source = try page.effectSource(index);
    if (source.execution.pid != actor.pid or source.execution.realm != actor.connection.scope.realm) return error.InvalidEffectSource;
    if (page.cursor.next < page.rows.len) return error.InvalidQueueCursor;
    var cursor = page.cursor;
    cursor.next = @intCast(page.cursor.next - page.rows.len + index);
    const result: Saved = .{
        .definition = p.Growth.current_definition,
        .connection = actor.connection,
        .admission = .{ .cursor = cursor, .signed = try p.Growth.sign(.{ .realm = actor.connection.scope.realm, .principal = actor.connection.principal, .sequence = sequence, .command = .{ .admit_effect = .{ .pid = actor.pid, .generation = generation, .source = source } } }, key) },
    };
    try result.validate();
    return result;
}
