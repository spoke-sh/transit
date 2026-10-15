//! A signed, bounded result reference, never execution or read authority.
//! Expiry limits access through this ticket; it cannot retire retained history.
const std = @import("std");
const root = @import("root.zig");
const p = root.query.protocol;
const Self = @This();
pub const max_command_bytes = 1024;
pub const max_bytes = 4 + 32 + 8 * 8 + 9 + 32 + 8 + 1 + 2 + max_command_bytes + 32 + 64;
pub const Scope = struct {
    realm: u64,
    principal: u64,
    role: ?u64 = null,
    service: u64,
    binding_revision: u64,
    ingress: u64,
    requests: u64,
    source: u64,
    resource: u64,
    declaration: [32]u8,
    pub fn validate(self: Scope) !void {
        if (self.role) |role| if (role == 0 or role > p.max_counter) return error.InvalidFlightTicket;
        inline for (identities) |name| {
            const value = @field(self, name);
            if (value == 0 or value > p.max_counter) return error.InvalidFlightTicket;
        }
    }
};
const identities = .{ "realm", "principal", "service", "binding_revision", "ingress", "requests", "source", "resource" };
pub const Reference = union(enum) {
    statement: struct { correlation: u64, manifest: [32]u8 },
    metadata: struct { command: []const u8, digest: [32]u8 },
};
scope: Scope,
expires_ms: u64,
reference: Reference,

fn digest(bytes: []const u8) [32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.flight.ticket.v1\x00");
    hash.update(bytes);
    return hash.finalResult();
}
pub fn issue(self: Self, key: p.Ed25519.KeyPair, output: []u8) ![]const u8 {
    try self.scope.validate();
    if (self.expires_ms == 0 or self.expires_ms > p.max_counter) return error.InvalidFlightTicket;
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll("FTK1");
    try writer.writeAll(&root.query.catalog.TableMetadata.definition());
    inline for (identities) |name| try writer.writeInt(u64, @field(self.scope, name), .little);
    try writer.writeByte(@intFromBool(self.scope.role != null));
    try writer.writeInt(u64, self.scope.role orelse 0, .little);
    try writer.writeAll(&self.scope.declaration);
    try writer.writeInt(u64, self.expires_ms, .little);
    switch (self.reference) {
        .statement => |value| {
            if (value.correlation == 0 or value.correlation > p.max_counter) return error.InvalidFlightTicket;
            try writer.writeByte(1);
            try writer.writeInt(u64, value.correlation, .little);
            try writer.writeAll(&value.manifest);
        },
        .metadata => |value| {
            if (value.command.len == 0 or value.command.len > max_command_bytes) return error.InvalidFlightTicket;
            try writer.writeByte(2);
            try writer.writeInt(u16, @intCast(value.command.len), .little);
            try writer.writeAll(value.command);
            try writer.writeAll(&value.digest);
        },
    }
    const signature = try key.sign(&digest(writer.buffered()), null);
    try writer.writeAll(&signature.toBytes());
    return writer.buffered();
}
/// Metadata command slices borrow bytes. The caller must independently recheck
/// current native/service/source/request rights and exact manifest/schema before
/// every bounded disclosure; successful decoding supplies none of those rights.
pub fn decode(bytes: []const u8, expected: Scope, now_ms: u64, public_key: p.Ed25519.PublicKey) !Self {
    try expected.validate();
    if (bytes.len < 4 + 32 + 8 * 8 + 9 + 32 + 8 + 1 + 2 + 1 + 32 + 64 or bytes.len > max_bytes) return error.InvalidFlightTicket;
    const body = bytes[0 .. bytes.len - 64];
    try p.Ed25519.Signature.fromBytes(bytes[bytes.len - 64 ..][0..64].*).verify(&digest(body), public_key);
    var reader: std.Io.Reader = .fixed(body);
    if (!std.mem.eql(u8, try reader.take(4), "FTK1")) return error.InvalidFlightTicket;
    if (!std.mem.eql(u8, try reader.take(32), &root.query.catalog.TableMetadata.definition())) return error.IncompatibleDefinition;
    var scope: Scope = undefined;
    inline for (identities) |name| @field(scope, name) = try reader.takeInt(u64, .little);
    const has_role = try reader.takeByte();
    const role = try reader.takeInt(u64, .little);
    if (has_role > 1 or (has_role == 0 and role != 0)) return error.InvalidFlightTicket;
    scope.role = if (has_role == 1) role else null;
    try scope.validate();
    scope.declaration = (try reader.takeArray(32)).*;
    if (!std.meta.eql(scope, expected)) return error.FlightTicketScope;
    const expires_ms = try reader.takeInt(u64, .little);
    if (expires_ms == 0 or expires_ms > p.max_counter) return error.InvalidFlightTicket;
    if (now_ms >= expires_ms) return error.FlightTicketExpired;
    const reference: Reference = switch (try reader.takeByte()) {
        1 => blk: {
            const correlation = try reader.takeInt(u64, .little);
            if (correlation == 0 or correlation > p.max_counter) return error.InvalidFlightTicket;
            break :blk .{ .statement = .{ .correlation = correlation, .manifest = (try reader.takeArray(32)).* } };
        },
        2 => blk: {
            const size = try reader.takeInt(u16, .little);
            if (size == 0 or size > max_command_bytes) return error.InvalidFlightTicket;
            const command = try reader.take(size);
            break :blk .{ .metadata = .{ .command = command, .digest = (try reader.takeArray(32)).* } };
        },
        else => return error.InvalidFlightTicket,
    };
    if (reader.bufferedLen() != 0) return error.InvalidFlightTicket;
    return .{ .scope = scope, .expires_ms = expires_ms, .reference = reference };
}

test "tickets bind principal, service generation and immutable result independently of expiry" {
    const t = std.testing;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(37));
    const scope: Scope = .{ .realm = 49, .principal = 65536, .service = 1, .binding_revision = 2, .ingress = 7, .requests = 11, .source = 3, .resource = 9, .declaration = @splat(3) };
    const ticket: Self = .{ .scope = scope, .expires_ms = 2000, .reference = .{ .statement = .{ .correlation = 123, .manifest = @splat(5) } } };
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try ticket.issue(key, &buffer);
    try t.expectEqualDeep(ticket, try decode(bytes, scope, 1999, key.public_key));
    try t.expectError(error.FlightTicketExpired, decode(bytes, scope, 2000, key.public_key));
    var foreign = scope;
    foreign.principal += 1;
    try t.expectError(error.FlightTicketScope, decode(bytes, foreign, 1999, key.public_key));
    foreign = scope;
    foreign.role = 19;
    try t.expectError(error.FlightTicketScope, decode(bytes, foreign, 1999, key.public_key));
    foreign = scope;
    foreign.binding_revision += 1;
    try t.expectError(error.FlightTicketScope, decode(bytes, foreign, 1999, key.public_key));
    foreign = scope;
    foreign.declaration[0] ^= 1;
    try t.expectError(error.FlightTicketScope, decode(bytes, foreign, 1999, key.public_key));
    buffer[100] ^= 1;
    try t.expectError(error.SignatureVerificationFailed, decode(bytes, scope, 1999, key.public_key));
    const metadata: Self = .{ .scope = scope, .expires_ms = 3000, .reference = .{ .metadata = .{ .command = "catalog request", .digest = @splat(4) } } };
    const encoded = try metadata.issue(key, &buffer);
    try t.expectEqualDeep(metadata, try decode(encoded, scope, 2000, key.public_key));
    // Even a valid deployment signature cannot admit a different definition.
    buffer[4] ^= 1;
    const signature = try key.sign(&digest(buffer[0 .. encoded.len - 64]), null);
    @memcpy(buffer[encoded.len - 64 ..][0..64], &signature.toBytes());
    try t.expectError(error.IncompatibleDefinition, decode(encoded, scope, 2000, key.public_key));
}
