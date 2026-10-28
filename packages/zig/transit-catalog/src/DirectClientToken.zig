//! Database-owned immutable client-token bindings. A binding selects saved
//! work; its catalog position is not the data operation's completion position.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;

pub const Key = struct {
    definition: p.Growth.Definition,
    connection: c.DirectTableProtocol.Connection,
    account: [32]u8,
    token: [16]u8,

    pub fn validate(self: Key) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        if (std.mem.allEqual(u8, &self.account, 0)) return error.InvalidClientToken;
    }
    /// Roles, credentials, target names and proposed operations cannot create
    /// another identity for the same principal/account/token in this catalog.
    pub fn digest(self: Key) ![32]u8 {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.client-token.v1\x00");
        var bytes: [8]u8 = undefined;
        inline for (.{ self.connection.scope.realm, self.connection.scope.resource, self.connection.scope.catalog, self.connection.principal }) |value| {
            std.mem.writeInt(u64, &bytes, value, .little);
            hash.update(&bytes);
        }
        hash.update(&self.account);
        hash.update(&self.token);
        return hash.finalResult();
    }
    pub fn requireSame(self: Key, other: Key) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
};

pub const Binding = struct {
    key: Key,
    /// Caller-defined commitment to the complete original request, including
    /// parameters and selected database. The catalog does not interpret SQL.
    fingerprint: [32]u8,
    intent: c.DirectTableIntent.Reference,

    pub fn validate(self: Binding) !void {
        try self.key.validate();
        try self.intent.validate();
        if (!std.meta.eql(self.key.connection, self.intent.connection) or
            std.mem.allEqual(u8, &self.fingerprint, 0)) return error.InvalidClientToken;
    }
    /// Racing preparations of the same request may propose different operation
    /// IDs or cuts. Only the originally accepted reference may be dispatched.
    pub fn retry(self: Binding, proposed: Binding) !void {
        try self.validate();
        try proposed.validate();
        try self.key.requireSame(proposed.key);
        if (!std.mem.eql(u8, &self.fingerprint, &proposed.fingerprint)) return error.ClientTokenConflict;
    }
};

pub const Receipt = struct {
    binding: Binding,
    position: p.DataLifecycle.Position,
    pub fn validate(self: Receipt) !void {
        try self.binding.validate();
        try self.position.validate();
        if (self.position.next_lsn < 2) return error.InvalidClientToken;
    }
};
pub const Request = union(enum) {
    lookup: Key,
    bind: Binding,
    pub fn key(self: Request) Key {
        return switch (self) {
            .lookup => |value| value,
            .bind => |value| value.key,
        };
    }
    pub fn validate(self: Request) !void {
        switch (self) {
            inline else => |value| try value.validate(),
        }
    }
};

/// A lookup is observation only. No automatic retry or data admission occurs.
pub fn lookup(client: c.DirectTableClient, key: Key) !?Receipt {
    const response = try client.call(.{ .client_token = .{ .lookup = key } });
    defer response.deinit();
    return response.value.result.client_token;
}
/// Save the key before calling. A missing reply requires lookup or the same
/// binding attempt; dispatch only the reference in the returned receipt.
pub fn bind(client: c.DirectTableClient, binding: Binding) !Receipt {
    const response = try client.call(.{ .client_token = .{ .bind = binding } });
    defer response.deinit();
    return response.value.result.client_token orelse error.InvalidTableResponse;
}

test "direct client token signing and key identity match independent fixtures" {
    const t = std.testing;
    const w = c.DirectTableProtocol;
    const Fixture = struct { request: w.Request, public_key: [32]u8, key_digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-client-token-v1.json"));
    defer parsed.deinit();
    const fixture = parsed.value;
    try fixture.request.validate(t.allocator);
    try fixture.request.proof.verify(fixture.public_key);
    const binding = fixture.request.action.client_token.bind;
    try t.expectEqualDeep(fixture.key_digest, try binding.key.digest());
    try t.expectEqual(std.math.maxInt(u64), binding.intent.binding.identity.operation);
    var changed_key = binding.key;
    changed_key.connection.role = 12;
    try t.expectEqualDeep(fixture.key_digest, try changed_key.digest());
    try t.expectError(error.DataIdentityConflict, binding.key.requireSame(changed_key));
    var changed = fixture.request;
    changed.action.client_token.bind.fingerprint[0] ^= 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    try t.expect(fixture.request.transport().mutation);
    changed.action = .{ .client_token = .{ .lookup = binding.key } };
    try t.expect(!changed.transport().mutation);

    const response: w.Response = .{ .definition = p.Growth.current_definition, .context = fixture.request.proof.claim.context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = fixture.request.proof.claim.context }, .result = .{ .client_token = .{ .binding = binding, .position = .{ .partition = 1, .next_lsn = 2 } } } };
    try c.DirectTableClient.validateResponse(t.allocator, fixture.request, response);
    var damaged = response;
    damaged.result.client_token = null;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, fixture.request, damaged));
    damaged = response;
    damaged.result.client_token.?.binding.key.account[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, c.DirectTableClient.validateResponse(t.allocator, fixture.request, damaged));
    damaged = response;
    damaged.result.client_token.?.binding.fingerprint[0] ^= 1;
    try t.expectError(error.ClientTokenConflict, c.DirectTableClient.validateResponse(t.allocator, fixture.request, damaged));
    damaged = response;
    damaged.result.client_token.?.position.next_lsn = 0;
    try t.expectError(error.InvalidClientToken, c.DirectTableClient.validateResponse(t.allocator, fixture.request, damaged));
}
