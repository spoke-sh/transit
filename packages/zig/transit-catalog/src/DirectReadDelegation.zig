//! Original-caller permission for one executor to capture/read/close one Table
//! pin. These bytes never replace current native caller or executor checks.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const Self = @This();
pub const Borrow = @import("DirectReadBorrow.zig");

pub const Binding = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    executor: u64,
    interpretation: d.Definition,
    expected: d.Position,
    selection: w.CaptureSelection = .exact,
    owner: d.Operation,
    /// A history grant follows this object from the original cut until closure.
    /// A snapshot grant authorizes only the exact originally captured cut.
    retention: c.storage.TablePartition.Retention,
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
        if (self.selection == .current and self.retention != .snapshot) return error.InvalidTableDelegation;
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

/// Fresh authorization for closure of this exact original grant. It cannot
/// authorize snapshot disclosure or replace the grant used by accepted work.
/// Compact bytes travel in a bounded native cleanup command; all other claim
/// fields are reconstructed from the immutable original grant.
pub const Closure = struct {
    credential_epoch: u64,
    signature: [64]u8,
    pub const encoded_bytes = 72;

    pub fn context(original: Self, allocator: std.mem.Allocator) ![32]u8 {
        const bytes = try original.encode(allocator);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.pin-closure.v1\x00");
        hash.update(&bytes);
        return hash.finalResult();
    }
    pub fn prepare(client: c.DirectTableClient, original: Self) !Closure {
        if (client.delegation != null or client.closure != null or client.borrow != null or !std.meta.eql(client.connection, original.binding.connection)) return error.InvalidTableDelegation;
        const native: c.client.AuthorizationClient = .{ .transport = client.authority, .realm = client.connection.scope.realm, .principal = client.connection.principal, .role = client.connection.role, .key = client.key };
        const signed = (try native.proof(client.connection.audience, try context(original, client.allocator))).signed;
        return .{ .credential_epoch = signed.claim.credential_epoch, .signature = signed.signature };
    }
    pub fn proof(self: Closure, original: Self, allocator: std.mem.Allocator) !p.Authorization.Proof {
        var claim = original.proof.claim;
        claim.credential_epoch = self.credential_epoch;
        claim.context = try context(original, allocator);
        try claim.validate();
        return .{ .claim = claim, .signature = self.signature };
    }
    pub fn allow(action: w.Action) !void {
        // Exact-frontier pin acquisition may be needed to tombstone an
        // uncertain original request. No schema or row disclosure is allowed.
        switch (action) {
            .pin, .retain_history, .pin_status, .release => {},
            else => return error.TableDelegationDenied,
        }
    }
    pub fn encode(self: Closure) ![Closure.encoded_bytes]u8 {
        try p.Authorization.revision(self.credential_epoch);
        var bytes: [Closure.encoded_bytes]u8 = undefined;
        std.mem.writeInt(u64, bytes[0..8], self.credential_epoch, .little);
        bytes[8..].* = self.signature;
        return bytes;
    }
    pub fn decode(bytes: []const u8) !Closure {
        if (bytes.len != Closure.encoded_bytes) return error.InvalidTableDelegation;
        const value: Closure = .{ .credential_epoch = std.mem.readInt(u64, bytes[0..8], .little), .signature = bytes[8..][0..64].* };
        _ = try value.encode();
        return value;
    }
};

/// Bounded canonical storage for the original grant. Repeated claim fields are
/// constrained by validate; decoding never supplies a missing definition/epoch.
pub const encoded_bytes = 311;
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
    try writer.writeByte(@backingInt(self.binding.retention));
    try writer.writeByte(@backingInt(self.binding.selection));
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
    const retention = std.enums.fromInt(c.storage.TablePartition.Retention, try reader.takeByte()) orelse return error.InvalidTableDelegation;
    const selection = std.enums.fromInt(w.CaptureSelection, try reader.takeByte()) orelse return error.InvalidTableDelegation;
    const purpose = (try reader.takeArray(32)).*;
    const result: Self = .{
        .binding = .{ .definition = p.Growth.current_definition, .connection = connection, .executor = executor, .interpretation = interpretation, .expected = expected, .selection = selection, .owner = .{ .scope = connection.scope, .principal = connection.principal, .operation = operation }, .retention = retention, .purpose = purpose },
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
    if (client.delegation != null or client.borrow != null or client.closure != null or !std.meta.eql(binding.connection, client.connection)) return error.InvalidTableDelegation;
    const native: c.client.AuthorizationClient = .{ .transport = client.authority, .realm = client.connection.scope.realm, .principal = client.connection.principal, .role = client.connection.role, .key = client.key };
    return .{ .binding = binding, .proof = (try native.proof(client.connection.audience, try binding.context(client.allocator))).signed };
}

pub fn requirePin(self: Self, object: d.Object, owner: d.Operation) !void {
    if (!std.meta.eql(object, self.binding.interpretation.object) or !std.meta.eql(owner, self.binding.owner)) return error.TableDelegationDenied;
}

pub fn requireSource(self: Self, interpretation: d.Definition, position: d.Position) !void {
    if (!std.meta.eql(interpretation, self.binding.interpretation) or position.partition != self.binding.expected.partition or
        (if (self.binding.selection == .exact) position.next_lsn != self.binding.expected.next_lsn else position.next_lsn < self.binding.expected.next_lsn)) return error.TableDelegationDenied;
}
pub fn requireHistory(self: Self, interpretation: d.Definition, position: d.Position) !void {
    if (self.binding.retention != .history or !std.meta.eql(interpretation.object, self.binding.interpretation.object) or
        position.partition != self.binding.expected.partition or position.next_lsn < self.binding.expected.next_lsn) return error.TableDelegationDenied;
    if (position.next_lsn == self.binding.expected.next_lsn) try self.requireSource(interpretation, position);
}

/// No name lookup, general metadata discovery, new target, mutation, policy
/// operation or delegation chain. The owner checks the retained root itself.
pub fn allow(self: Self, action: w.Action) !void {
    switch (action) {
        inline .pin, .retain_history => |value, tag| {
            if ((tag == .retain_history) != (self.binding.retention == .history)) return error.TableDelegationDenied;
            if (value.selection != self.binding.selection) return error.TableDelegationDenied;
            try self.requirePin(value.object, value.owner);
            if (!std.meta.eql(value.expected, self.binding.expected)) return error.TableDelegationDenied;
        },
        .history_start => |value| {
            if (self.binding.retention != .history) return error.TableDelegationDenied;
            try self.requirePin(value.object, value.handle.owner);
        },
        .history => |value| {
            if (self.binding.retention != .history or value.from.partition != self.binding.expected.partition or value.from.next_lsn < self.binding.expected.next_lsn) return error.TableDelegationDenied;
            try self.requirePin(value.snapshot.object, value.snapshot.handle.owner);
        },
        .history_source => |value| try self.requireHistoryPoint(value),
        .history_scan => |value| try self.requireHistoryPoint(value.source),
        .pin_status => |value| try self.requirePin(value.object, value.owner),
        inline .snapshot, .release => |value| try self.requirePin(value.object, value.handle.owner),
        inline .scan, .column_scan, .filter_scan, .read_key, .key_range => |value| try self.requirePin(value.snapshot.object, value.snapshot.handle.owner),
        .check_set => |values| for (values) |value| switch (value) {
            .snapshot => |snapshot| try self.requirePin(snapshot.object, snapshot.handle.owner),
            .access, .historical => return error.TableDelegationDenied,
        },
        else => return error.TableDelegationDenied,
    }
}

fn requireHistoryPoint(self: Self, value: w.Historical) !void {
    if (self.binding.retention != .history or value.point.position.partition != self.binding.expected.partition or value.point.position.next_lsn < self.binding.expected.next_lsn) return error.TableDelegationDenied;
    try self.requirePin(value.object, value.point.lease.owner);
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
        .retention = .snapshot,
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
    const rotated = try p.Ed25519.KeyPair.generateDeterministic(@splat(29));
    var closure_claim = original.proof.claim;
    closure_claim.credential_epoch += 1;
    closure_claim.context = try Closure.context(original, t.allocator);
    const closure_proof = try p.Authorization.Proof.sign(closure_claim, rotated);
    const closure: Closure = .{ .credential_epoch = closure_claim.credential_epoch, .signature = closure_proof.signature };
    try t.expectEqualDeep(closure_proof, try closure.proof(original, t.allocator));
    try (try closure.proof(original, t.allocator)).verify(rotated.public_key.toBytes());
    try t.expectEqualDeep(closure, try Closure.decode(&try closure.encode()));
    // A fresh cleanup signature cannot become an execution grant.
    var forged_read = original.proof;
    forged_read.claim.credential_epoch = closure.credential_epoch;
    forged_read.signature = closure.signature;
    try t.expectError(error.SignatureVerificationFailed, forged_read.verify(rotated.public_key.toBytes()));
    var substituted = original;
    substituted.proof.signature[0] ^= 1;
    try t.expectError(error.SignatureVerificationFailed, (try closure.proof(substituted, t.allocator)).verify(rotated.public_key.toBytes()));
    try Closure.allow(.{ .pin_status = .{ .object = binding.interpretation.object, .owner = binding.owner } });
    try t.expectError(error.TableDelegationDenied, Closure.allow(.{ .snapshot = .{ .object = binding.interpretation.object, .handle = .{ .owner = binding.owner, .content = .{ .bytes = 1, .sha256 = @splat(2) } } } }));
    var other = binding.owner;
    other.operation += 1;
    try t.expectError(error.TableDelegationDenied, original.requirePin(binding.interpretation.object, other));
    inline for (.{ "executor", "interpretation", "expected", "selection", "owner", "retention", "purpose", "connection" }) |field| {
        var changed = original;
        if (comptime std.mem.eql(u8, field, "executor")) changed.binding.executor += 1;
        if (comptime std.mem.eql(u8, field, "interpretation")) changed.binding.interpretation.revision += 1;
        if (comptime std.mem.eql(u8, field, "expected")) changed.binding.expected.next_lsn += 1;
        if (comptime std.mem.eql(u8, field, "selection")) changed.binding.selection = .current;
        if (comptime std.mem.eql(u8, field, "owner")) changed.binding.owner.operation += 1;
        if (comptime std.mem.eql(u8, field, "retention")) changed.binding.retention = .history;
        if (comptime std.mem.eql(u8, field, "purpose")) changed.binding.purpose[0] ^= 1;
        if (comptime std.mem.eql(u8, field, "connection")) changed.binding.connection.role = null;
        try t.expectError(error.InvalidTableDelegation, changed.validate(t.allocator));
    }
}
