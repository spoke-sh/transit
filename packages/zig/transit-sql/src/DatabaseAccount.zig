//! SQL account mapping over Catalog-owned operation identities and recovery.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const Self = @This();
configuration: Configuration,
pub const Binding = struct {
    resource: u64,
    catalog: u64,
    owner: u64,
    namespace: u64 = 1,
    role: ?u64 = null,
};
pub const Configuration = struct {
    realm: u64,
    table_principal: u64,
    account: [32]u8,
    bindings: []const Binding,
    intent_bytes: u32 = c.DirectTableIntent.max_bytes,
    operation_quota: u64,
    byte_quota: u64,
    pending_quota: u32 = 16,
    pub fn validate(self: Configuration) !void {
        inline for (.{ self.realm, self.table_principal }) |id| if (id == 0 or id > p.max_counter) return error.InvalidGatewayConfiguration;
        if (self.bindings.len == 0 or self.bindings.len > 8 or self.intent_bytes < c.DirectTableIntent.prefix_bytes or self.intent_bytes > c.DirectTableIntent.max_bytes or self.operation_quota == 0 or self.byte_quota < self.reservation() or self.pending_quota == 0 or self.pending_quota > 1024) return error.InvalidGatewayConfiguration;
        if (std.mem.allEqual(u8, &self.account, 0)) return error.InvalidGatewayConfiguration;
        for (self.bindings, 0..) |binding, i| {
            // SQL operation IDs are positions in one Catalog. Namespace/role
            // routes share that identity domain; independent catalogs do not.
            const first = self.bindings[0];
            if (binding.resource != first.resource or binding.catalog != first.catalog or binding.owner != first.owner) return error.InvalidGatewayConfiguration;
            if (binding.resource == 0 or binding.resource > p.max_counter or binding.owner == 0 or binding.owner > p.max_counter or binding.catalog == 0 or binding.namespace == 0 or binding.namespace > p.max_counter or (binding.role != null and binding.role.? > p.max_counter)) return error.InvalidGatewayConfiguration;
            for (self.bindings[0..i]) |other| if (binding.resource == other.resource and binding.catalog == other.catalog and binding.namespace == other.namespace) return error.InvalidGatewayConfiguration;
        }
    }
    /// Only a bounded reference and terminal projection use private control
    /// storage. Complete work is separately charged by the direct data owner.
    pub fn budget(self: Configuration, bytes: u64) c.DirectClientToken.Budget {
        return .{ .limits = .{ .operations = self.operation_quota, .bytes = self.byte_quota, .pending = self.pending_quota }, .bytes = bytes };
    }
    pub fn reservation(_: Configuration) u64 {
        return g.IntentReference.max_bytes + 512;
    }
    pub fn digest(self: Configuration) ![32]u8 {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.sql-gateway.account.v1\x00");
        hash.update(&p.Growth.definition_bytes);
        hash.update(&self.account);
        var number: [8]u8 = undefined;
        inline for (.{ self.realm, self.table_principal, @as(u64, self.intent_bytes), self.operation_quota, self.byte_quota, @as(u64, self.pending_quota), @as(u64, self.bindings.len) }) |id| {
            std.mem.writeInt(u64, &number, id, .little);
            hash.update(&number);
        }
        for (self.bindings) |binding| inline for (.{ binding.resource, binding.catalog, binding.owner, binding.namespace, @as(u64, @intFromBool(binding.role != null)), binding.role orelse 0 }) |id| {
            std.mem.writeInt(u64, &number, id, .little);
            hash.update(&number);
        };
        return hash.finalResult();
    }
};

pub fn admittedBinding(self: Self, binding: Binding) !void {
    for (self.configuration.bindings) |candidate| if (std.meta.eql(candidate, binding)) return;
    return error.GatewayCatalogDenied;
}
pub fn operation(self: Self, source: *g.Client.Source, id: u64) !g.OperationRecords.Operation {
    const state = try source.operation(id);
    const reference = state.receipt.binding.intent;
    if (reference == .external) return error.InvalidSqlOperationReference;
    const connection = reference.connection();
    const binding: Binding = .{ .resource = connection.scope.resource, .catalog = connection.scope.catalog, .owner = connection.audience, .namespace = reference.namespace(), .role = connection.role };
    try self.admittedBinding(binding);
    return .{ .id = state.id(), .nonce = state.receipt.binding.key.token, .resource = binding.resource, .catalog = binding.catalog, .owner = binding.owner, .namespace = binding.namespace, .role_present = @intFromBool(binding.role != null), .role = binding.role orelse 0, .phase = if (state.pending) .ready else .terminal, .cancel = @intFromBool(state.cancel) };
}
