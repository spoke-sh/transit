//! Public direct database client for SQL account recovery.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const wire = @import("transit_client");
const Self = @This();
transport: *wire.Client,
execution: g.DatabaseAccount,
principal: u64,
key: p.Ed25519.KeyPair,
lease: ?c.DirectClientToken.Lease = null,
credential_epoch: ?u64 = null,
pub fn table(self: *Self, binding: g.DatabaseAccount.Binding) c.DirectTableClient {
    return .{ .allocator = self.transport.http.allocator, .authority = self.transport, .service = self.transport, .connection = .{ .scope = .{ .realm = self.execution.configuration.realm, .resource = binding.resource, .catalog = binding.catalog }, .branch = 1, .audience = binding.owner, .principal = self.execution.configuration.table_principal, .role = binding.role }, .key = self.key, .lease = self.lease, .credential_epoch = self.credential_epoch };
}
pub const Source = struct {
    client: *Self,
    pub fn operation(self: *Source, id: u64) !c.DirectClientToken.Progress {
        for (self.client.execution.configuration.bindings) |binding| {
            const found = c.DirectClientToken.operation(self.client.table(binding), self.client.execution.configuration.account, id) catch |err| {
                if (err == error.DataIdentityConflict or self.client.transport.contended(err)) continue;
                return err;
            };
            if (found) |value| return value;
        }
        return error.MissingGatewayOperation;
    }
    pub fn lookup(self: *Source, token: [16]u8, fingerprint: ?[32]u8) !?c.DirectClientToken.Progress {
        for (self.client.execution.configuration.bindings) |binding| {
            const caller = self.client.table(binding);
            const key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = caller.connection, .account = self.client.execution.configuration.account, .token = token };
            const found = c.DirectClientToken.inspect(caller, key) catch |err| {
                if (err == error.DataIdentityConflict or self.client.transport.contended(err)) continue;
                return err;
            };
            if (found) |value| {
                if (fingerprint) |expected| if (!std.mem.eql(u8, &expected, &value.receipt.binding.fingerprint)) return error.SqlTokenConflict;
                return value;
            }
        }
        return null;
    }
    pub fn direct(self: *Source, state: c.DirectClientToken.Progress) c.DirectTableClient {
        var result = self.client.table(self.client.execution.configuration.bindings[0]);
        result.connection = state.receipt.binding.key.connection;
        return result;
    }
};
pub fn source(self: *Self) !Source {
    return .{ .client = self };
}
