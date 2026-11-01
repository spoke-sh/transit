//! Frozen database operation references shared by typed callers and SQL.
//! Preparing or decoding a reference never admits work or resolves its name.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const w = c.DirectTableProtocol;
pub const External = struct {
    connection: w.Connection,
    namespace: u64,
    operation: u64,
    record: c.DirectRecord.Reference,
    pub fn identity(self: External) p.DataLifecycle.Operation {
        return .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = self.operation };
    }
    pub fn validate(self: External) !void {
        try self.connection.validate();
        try c.Model.nativeId(self.namespace);
        try self.identity().validate();
        try self.record.validate();
        if (!std.meta.eql(self.connection, self.record.scope.connection)) return error.DataIdentityConflict;
    }
};
pub const NamespaceChange = struct {
    /// SQL session's selected namespace, independently of the changed schema.
    namespace: u64,
    binding: c.DirectNamespace.Binding,
    pub fn validate(self: NamespaceChange) !void {
        try c.Model.nativeId(self.namespace);
        try self.binding.validate();
    }
};
pub const Reference = union(enum) {
    transaction: c.DirectTransaction.Reference,
    transaction_call: c.DirectTransactionCall,
    external: External,
    table: c.DirectTableIntent.Reference,
    log: c.DirectLogIntent.Reference,
    name_assertion: c.NameAssertion.Binding,
    namespace_change: NamespaceChange,
    pub fn validate(self: Reference) !void {
        switch (self) {
            inline else => |value| try value.validate(),
        }
    }
    pub fn connection(self: Reference) w.Connection {
        return switch (self) {
            .namespace_change => |value| value.binding.connection,
            inline else => |value| value.connection,
        };
    }
    pub fn namespace(self: Reference) u64 {
        return switch (self) {
            inline else => |value| value.namespace,
        };
    }
    pub fn identity(self: Reference) p.DataLifecycle.Operation {
        return switch (self) {
            inline .transaction, .transaction_call => |value| value.identity(),
            .external => |value| value.identity(),
            .table => |value| value.binding.identity,
            .log => |value| value.binding.identity,
            .name_assertion => |value| value.identity(),
            .namespace_change => |value| value.binding.identity(),
        };
    }
    pub fn workBytes(self: Reference) !u64 {
        if (self == .table) return self.table.content.bytes;
        if (self == .external) return self.external.record.content.bytes;
        if (self == .log) return self.log.record.content.bytes;
        var bytes: [max_bytes]u8 = undefined;
        return (try encode(self, &bytes)).len;
    }
    pub fn digest(self: Reference) ![32]u8 {
        return switch (self) {
            .transaction, .transaction_call => blk: {
                var bytes: [max_bytes]u8 = undefined;
                var hasher = std.crypto.hash.sha2.Sha256.init(.{});
                hasher.update("transit.catalog.transaction.binding.v1\x00");
                hasher.update(try encode(self, &bytes));
                break :blk hasher.finalResult();
            },
            .external => |value| blk: {
                var bytes: [max_bytes]u8 = undefined;
                var digest_value = std.crypto.hash.sha2.Sha256.init(.{});
                digest_value.update("transit.catalog.external.binding.v1\x00");
                digest_value.update(try encode(.{ .external = value }, &bytes));
                break :blk digest_value.finalResult();
            },
            .table => |value| bindingDigest(value.binding),
            .log => blk: {
                var bytes: [max_bytes]u8 = undefined;
                var digest_value = std.crypto.hash.sha2.Sha256.init(.{});
                digest_value.update("transit.catalog.log.binding.v1\x00");
                digest_value.update(try encode(self, &bytes));
                break :blk digest_value.finalResult();
            },
            .name_assertion => |value| assertionDigest(value),
            .namespace_change => |value| namespaceDigest(value),
        };
    }
    pub fn requireSame(self: Reference, other: Reference) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
    pub fn admit(self: Reference, client: c.DirectTableClient) !std.json.Parsed(w.Response) {
        if (self == .transaction or self == .transaction_call) return error.TransactionOperationRequired;
        if (self == .external) return error.ExternalOperationOwnerRequired;
        if (self == .table) return self.table.admit(client);
        if (self == .log) return self.log.admit(client);
        if (self == .namespace_change) {
            try self.validate();
            if (!std.meta.eql(self.connection(), client.connection)) return error.CatalogIdentityConflict;
            return client.call(.{ .namespace_operation = .{ .binding = self.namespace_change.binding, .command = .admit, .steps = 1 } });
        }
        return self.operation(client, .execute, 1);
    }
    pub fn operation(self: Reference, client: c.DirectTableClient, command: @FieldType(@FieldType(w.Action, "operation"), "command"), steps: u16) !std.json.Parsed(w.Response) {
        try self.validate();
        if (!std.meta.eql(self.connection(), client.connection)) return error.CatalogIdentityConflict;
        return switch (self) {
            .transaction, .transaction_call => error.TransactionOperationRequired,
            .external => error.ExternalOperationOwnerRequired,
            .table => |value| value.operation(client, command, steps),
            .log => |value| value.operation(client, command, steps),
            .name_assertion => |value| client.call(.{ .name_assertion = .{ .binding = value, .command = switch (command) {
                .inspect => .inspect,
                .execute => .accept,
                .cancel => .cancel,
            } } }),
            .namespace_change => |value| client.call(.{ .namespace_operation = .{ .binding = value.binding, .command = switch (command) {
                .inspect => .inspect,
                .execute => .execute,
                .cancel => .cancel,
            }, .steps = steps } }),
        };
    }
};
pub const max_bytes = 4096;
pub const prefix_bytes = 36;

pub fn encode(value: Reference, output: *[max_bytes]u8) ![]const u8 {
    try value.validate();
    var writer: std.Io.Writer = .fixed(output);
    try writer.writeAll("GIR1");
    try writer.writeAll(&p.Growth.definition_bytes);
    var json: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &json);
    return writer.buffered();
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Reference {
    if (bytes.len <= prefix_bytes or bytes.len > max_bytes or !std.mem.eql(u8, bytes[0..4], "GIR1")) return error.InvalidGatewayIntent;
    if (!std.mem.eql(u8, bytes[4..36], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(Reference, allocator, bytes[prefix_bytes..]);
    defer parsed.deinit();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(parsed.value, &canonical))) return error.InvalidGatewayIntent;
    return parsed.value;
}
/// Complete binding commitment, independent of transport and credentials.
pub fn bindingDigest(binding: p.DataLifecycle.Binding) ![32]u8 {
    try binding.validate();
    var buffer: [max_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    var json: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(binding, &json);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.sql.direct.binding.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}

pub fn assertionDigest(binding: c.NameAssertion.Binding) ![32]u8 {
    try binding.validate();
    var buffer: [max_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    var json: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(binding, &json);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.sql.catalog.assertion.binding.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}

pub fn namespaceDigest(value: NamespaceChange) ![32]u8 {
    try value.validate();
    var buffer: [max_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    var json: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &json);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.sql.namespace.binding.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}
