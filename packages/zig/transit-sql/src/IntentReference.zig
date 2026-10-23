//! SQL retains only this bounded control reference. Complete mutation bytes
//! live in the direct Table owner's immutable object store.
const std = @import("std");
const g = @import("root.zig");
const p = g.catalog.protocol;
const c = g.catalog;
const w = c.DirectTableProtocol;
pub const Reference = union(enum) {
    table: c.DirectTableIntent.Reference,
    name_assertion: c.NameAssertion.Binding,
    pub fn validate(self: Reference) !void {
        switch (self) {
            inline else => |value| try value.validate(),
        }
    }
    pub fn connection(self: Reference) w.Connection {
        return switch (self) {
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
            .table => |value| value.binding.identity,
            .name_assertion => |value| value.identity(),
        };
    }
    pub fn workBytes(self: Reference) !u64 {
        if (self == .table) return self.table.content.bytes;
        var bytes: [max_bytes]u8 = undefined;
        return (try encode(self, &bytes)).len;
    }
    pub fn digest(self: Reference) ![32]u8 {
        return switch (self) {
            .table => |value| bindingDigest(value.binding),
            .name_assertion => |value| assertionDigest(value),
        };
    }
    pub fn requireSame(self: Reference, other: Reference) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
    pub fn admit(self: Reference, client: c.DirectTableClient) !std.json.Parsed(w.Response) {
        if (self == .table) return self.table.admit(client);
        return self.operation(client, .execute, 1);
    }
    pub fn operation(self: Reference, client: c.DirectTableClient, command: @FieldType(@FieldType(w.Action, "operation"), "command"), steps: u16) !std.json.Parsed(w.Response) {
        try self.validate();
        if (!std.meta.eql(self.connection(), client.connection)) return error.CatalogIdentityConflict;
        return switch (self) {
            .table => |value| value.operation(client, command, steps),
            .name_assertion => |value| client.call(.{ .name_assertion = .{ .binding = value, .command = switch (command) {
                .inspect => .inspect,
                .execute => .accept,
                .cancel => .cancel,
            } } }),
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
