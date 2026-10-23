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

/// Bounded canonical storage for the original grant. Repeated claim fields are
/// constrained by validate; decoding never supplies a missing definition/epoch.
pub const encoded_bytes = 309;
pub fn encode(self: Self, allocator: std.mem.Allocator) ![encoded_bytes]u8 {
    try self.validate(allocator);
    var bytes: [encoded_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try writer.writeAll("TRG1");
    try writer.writeAll(&p.Growth.definition_bytes);
    const connection = self.binding.connection;
    inline for (.{ "realm", "resource", "catalog" }) |field| try writer.writeInt(u64, @field(connection.scope, field), .little);
    try writer.writeInt(u64, connection.branch, .little);
    try writer.writeInt(u64, connection.audience, .little);
    try writer.writeInt(u64, connection.principal, .little);
    try writer.writeByte(@intFromBool(connection.role != null));
    try writer.writeInt(u64, connection.role orelse 0, .little);
    try writer.writeInt(u64, self.binding.executor, .little);
    try writer.writeInt(u64, self.binding.interpretation.object.object, .little);
    try writer.writeInt(u64, self.binding.interpretation.revision, .little);
    try writer.writeAll(&self.binding.interpretation.digest);
    try writer.writeInt(u64, self.binding.expected.partition, .little);
    try writer.writeInt(u64, self.binding.expected.next_lsn, .little);
    try writer.writeInt(u64, self.binding.owner.operation, .little);
    try writer.writeAll(&self.binding.purpose);
    try writer.writeInt(u64, self.proof.claim.credential_epoch, .little);
    try writer.writeAll(&self.proof.claim.context);
    try writer.writeAll(&self.proof.signature);
    std.debug.assert(writer.end == bytes.len);
    return bytes;
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len != encoded_bytes) return error.InvalidTableDelegation;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "TRG1")) return error.InvalidTableDelegation;
    if (!std.mem.eql(u8, try reader.take(32), &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var connection: w.Connection = .{
        .scope = .{ .realm = try reader.takeInt(u64, .little), .resource = try reader.takeInt(u64, .little), .catalog = try reader.takeInt(u64, .little) },
        .branch = try reader.takeInt(u64, .little),
        .audience = try reader.takeInt(u64, .little),
        .principal = try reader.takeInt(u64, .little),
        .role = null,
    };
    const present = try reader.takeByte();
    const role = try reader.takeInt(u64, .little);
    if (present > 1 or (present == 0 and role != 0)) return error.InvalidTableDelegation;
    if (present == 1) connection.role = role;
    const executor = try reader.takeInt(u64, .little);
    const interpretation: d.Definition = .{
        .object = .{ .scope = connection.scope, .branch = connection.branch, .object = try reader.takeInt(u64, .little) },
        .revision = try reader.takeInt(u64, .little),
        .digest = (try reader.takeArray(32)).*,
    };
    const expected: d.Position = .{ .partition = try reader.takeInt(u64, .little), .next_lsn = try reader.takeInt(u64, .little) };
    const operation = try reader.takeInt(u64, .little);
    const purpose = (try reader.takeArray(32)).*;
    const result: Self = .{
        .binding = .{ .definition = p.Growth.current_definition, .connection = connection, .executor = executor, .interpretation = interpretation, .expected = expected, .owner = .{ .scope = connection.scope, .principal = connection.principal, .operation = operation }, .purpose = purpose },
        .proof = .{
            .claim = .{ .definition = p.Growth.current_definition, .realm = connection.scope.realm, .principal = connection.principal, .role = connection.role, .audience = connection.audience, .credential_epoch = try reader.takeInt(u64, .little), .context = (try reader.takeArray(32)).* },
            .signature = (try reader.takeArray(64)).*,
        },
    };
    try result.validate(allocator);
    return result;
}

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
    var encoded = try original.encode(t.allocator);
    try t.expectEqualDeep(original, try decode(t.allocator, &encoded));
    try t.expectError(error.InvalidTableDelegation, decode(t.allocator, encoded[0 .. encoded.len - 1]));
    encoded[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, decode(t.allocator, &encoded));
    encoded = try original.encode(t.allocator);
    encoded[110] ^= 1;
    try t.expectError(error.InvalidTableDelegation, decode(t.allocator, &encoded));
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
