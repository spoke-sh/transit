//! Original-caller permission for one executor to capture/read/close one Table
//! pin. These bytes never replace current native caller or executor checks.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const Self = @This();

pub const Binding = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    executor: u64,
    interpretation: d.Definition,
    expected: d.Position,
    owner: d.Operation,
    /// Application-owned immutable work commitment. The data owner enforces
    /// the Table/pin scope; this digest does not prove honest computation.
    purpose: [32]u8,

    pub fn validate(self: Binding) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.interpretation.validate();
        try self.expected.validate();
        try self.connection.object(self.interpretation.object);
        try self.connection.owner(self.owner);
        if (self.executor > p.max_counter or self.expected.next_lsn == 0 or std.mem.allEqual(u8, &self.purpose, 0)) return error.InvalidTableDelegation;
    }
    pub fn context(self: Binding, allocator: std.mem.Allocator) ![32]u8 {
        try self.validate();
        const bytes = try p.Json.valueAlloc(allocator, self);
        defer allocator.free(bytes);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.read-delegation.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
};

binding: Binding,
proof: p.Authorization.Proof,

pub fn validate(self: Self, allocator: std.mem.Allocator) !void {
    try self.binding.validate();
    try self.proof.claim.validate();
    const connection = self.binding.connection;
    const claim = self.proof.claim;
    if (claim.realm != connection.scope.realm or claim.principal != connection.principal or claim.role != connection.role or claim.audience != connection.audience or
        !std.mem.eql(u8, &claim.context, &try self.binding.context(allocator))) return error.InvalidTableDelegation;
}

/// The original caller signs once, before saving accepted work. Recovery must
/// retain this proof and its credential epoch; it must not sign as that caller
/// with the executor's key or silently replace a revoked delegation.
pub fn prepare(client: c.DirectTableClient, binding: Binding) !Self {
    try binding.validate();
    if (client.delegation != null or !std.meta.eql(binding.connection, client.connection)) return error.InvalidTableDelegation;
    const native: c.station.client.AuthorizationClient = .{ .transport = client.authority, .realm = client.connection.scope.realm, .principal = client.connection.principal, .role = client.connection.role, .key = client.key };
    return .{ .binding = binding, .proof = (try native.proof(client.connection.audience, try binding.context(client.allocator))).signed };
}

pub fn requirePin(self: Self, object: d.Object, owner: d.Operation) !void {
    if (!std.meta.eql(object, self.binding.interpretation.object) or !std.meta.eql(owner, self.binding.owner)) return error.TableDelegationDenied;
}

pub fn requireSource(self: Self, interpretation: d.Definition, position: d.Position) !void {
    if (!std.meta.eql(interpretation, self.binding.interpretation) or !std.meta.eql(position, self.binding.expected)) return error.TableDelegationDenied;
}

/// No name lookup, general metadata discovery, new target, mutation, policy
/// operation or delegation chain. The owner checks the retained root itself.
pub fn allow(self: Self, action: w.Action) !void {
    switch (action) {
        .pin => |value| {
            try self.requirePin(value.object, value.owner);
            if (!std.meta.eql(value.expected, self.binding.expected)) return error.TableDelegationDenied;
        },
        .pin_status => |value| try self.requirePin(value.object, value.owner),
        inline .snapshot, .release => |value| try self.requirePin(value.object, value.handle.owner),
        .scan => |value| try self.requirePin(value.snapshot.object, value.snapshot.handle.owner),
        .check_set => |values| for (values) |value| switch (value) {
            .snapshot => |snapshot| try self.requirePin(snapshot.object, snapshot.handle.owner),
            .access => return error.TableDelegationDenied,
        },
        else => return error.TableDelegationDenied,
    }
}

test "direct read delegation binds one caller role, executor, definition, pin and purpose" {
    const t = std.testing;
    const binding: Binding = .{
        .definition = p.Growth.current_definition,
        .connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .audience = 4, .principal = 5, .role = 6 },
        .executor = 7,
        .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 8 }, .revision = 9, .digest = @splat(10) },
        .expected = .{ .partition = 2, .next_lsn = 15 },
        .owner = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 5, .operation = 11 },
        .purpose = @splat(12),
    };
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(13));
    const original: Self = .{ .binding = binding, .proof = try p.Authorization.Proof.sign(.{
        .definition = p.Growth.current_definition,
        .realm = 1,
        .principal = 5,
        .credential_epoch = 14,
        .role = 6,
        .audience = 4,
        .context = try binding.context(t.allocator),
    }, key) };
    try original.validate(t.allocator);
    try original.proof.verify(key.public_key.toBytes());
    try original.requirePin(binding.interpretation.object, binding.owner);
    var other = binding.owner;
    other.operation += 1;
    try t.expectError(error.TableDelegationDenied, original.requirePin(binding.interpretation.object, other));
    inline for (.{ "executor", "interpretation", "expected", "owner", "purpose", "connection" }) |field| {
        var changed = original;
        if (comptime std.mem.eql(u8, field, "executor")) changed.binding.executor += 1;
        if (comptime std.mem.eql(u8, field, "interpretation")) changed.binding.interpretation.revision += 1;
        if (comptime std.mem.eql(u8, field, "expected")) changed.binding.expected.next_lsn += 1;
        if (comptime std.mem.eql(u8, field, "owner")) changed.binding.owner.operation += 1;
        if (comptime std.mem.eql(u8, field, "purpose")) changed.binding.purpose[0] ^= 1;
        if (comptime std.mem.eql(u8, field, "connection")) changed.binding.connection.role = null;
        try t.expectError(error.InvalidTableDelegation, changed.validate(t.allocator));
    }
}
