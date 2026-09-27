//! Metadata provenance is canonical JSON, never interpolated credentials.
const std = @import("std");
const rpc = @import("root.zig");
const Self = @This();
pub const maximum_bytes = 8192;
pub const Secret = struct { binding: []const u8, version: u64 };
pub const Value = union(enum) { literal: []const u8, secret: Secret };
pub const Entry = struct { name: []const u8, value: Value };
pub const Resolver = struct { context: *anyopaque, resolve: *const fn (*anyopaque, Secret) anyerror![]const u8 };
method: []const u8,
shape: rpc.Shape,
descriptor_digest: [32]u8,
metadata: []const Entry = &.{},
pub fn validate(self: Self) !void {
    if (self.metadata.len > 64) return error.InvalidGrpcMetadata;
    var fields: [64]rpc.transport.Entry = undefined;
    for (self.metadata, 0..) |entry, index| {
        fields[index] = .{ .name = entry.name, .value = switch (entry.value) {
            .literal => |bytes| bytes,
            .secret => |secret| blk: {
                if (secret.binding.len == 0 or secret.binding.len > 128 or secret.version == 0) return error.InvalidGrpcSecret;
                for (secret.binding) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '_' and byte != '-' and byte != '.') return error.InvalidGrpcSecret;
                break :blk "";
            },
        } };
    }
    try (rpc.transport.Request{ .method = self.method, .shape = self.shape, .messages = if (self.shape == .unary or self.shape == .server_streaming) &.{""} else &.{}, .metadata = fields[0..self.metadata.len] }).validate(.{});
}
pub fn provenance(self: Self, buffer: []u8) ![]const u8 {
    try self.validate();
    var out: std.Io.Writer = .fixed(buffer[0..@min(buffer.len, maximum_bytes)]);
    try out.writeAll("{\"version\":1,\"method\":");
    try std.json.Stringify.value(self.method, .{}, &out);
    try out.print(",\"shape\":\"{s}\",\"descriptor_digest\":\"{x}\",\"metadata\":[", .{ @tagName(self.shape), &self.descriptor_digest });
    for (self.metadata, 0..) |entry, index| {
        if (index != 0) try out.writeByte(',');
        try out.writeAll("{\"name\":");
        try std.json.Stringify.value(entry.name, .{}, &out);
        try out.writeAll(",\"value\":{");
        switch (entry.value) {
            .literal => |bytes| try out.print("\"literal_hex\":\"{x}\"", .{bytes}),
            .secret => |secret| {
                try out.writeAll("\"secret\":");
                try std.json.Stringify.value(secret, .{}, &out);
            },
        }
        try out.writeAll("}}");
    }
    try out.writeAll("]}");
    return out.buffered();
}
const Wire = struct {
    version: u32,
    method: []const u8,
    shape: rpc.Shape,
    descriptor_digest: []const u8,
    metadata: []const struct { name: []const u8, value: union(enum) { literal_hex: []const u8, secret: Secret } },
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    request: Self,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
    }
};
/// Accept only canonical bytes. A fixed input limit bounds JSON allocations;
/// the caller chooses the parent allocator (workers use a bounded arena).
pub fn parse(gpa: std.mem.Allocator, bytes: []const u8) !Owned {
    if (bytes.len == 0 or bytes.len > maximum_bytes) return error.InvalidGrpcRequest;
    var arena: std.heap.ArenaAllocator = .init(gpa);
    errdefer arena.deinit();
    const a = arena.allocator();
    const wire = try std.json.parseFromSliceLeaky(Wire, a, bytes, .{ .allocate = .alloc_always });
    if (wire.version != 1 or wire.descriptor_digest.len != 64 or wire.metadata.len > 64) return error.InvalidGrpcRequest;
    var request: Self = .{ .method = wire.method, .shape = wire.shape, .descriptor_digest = undefined };
    _ = try std.fmt.hexToBytes(&request.descriptor_digest, wire.descriptor_digest);
    const entries = try a.alloc(Entry, wire.metadata.len);
    for (entries, wire.metadata) |*entry, field| {
        entry.* = .{ .name = field.name, .value = switch (field.value) {
            .secret => |secret| .{ .secret = secret },
            .literal_hex => |hex| blk: {
                if (hex.len % 2 != 0) return error.InvalidGrpcMetadata;
                const literal = try a.alloc(u8, hex.len / 2);
                _ = try std.fmt.hexToBytes(literal, hex);
                break :blk .{ .literal = literal };
            },
        } };
    }
    request.metadata = entries;
    var canonical: [maximum_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try request.provenance(&canonical))) return error.NonCanonicalGrpcRequest;
    return .{ .arena = arena, .request = request };
}
/// Actual credential resolution belongs to the authorized executor. Borrowed
/// resolver bytes must remain alive through the joined transport execution.
pub fn render(self: Self, messages: []const []const u8, fields: []rpc.transport.Entry, resolver: ?Resolver, limits: rpc.transport.Limits) !rpc.transport.Request {
    try self.validate();
    if (fields.len < self.metadata.len) return error.GrpcMetadataCapacity;
    for (self.metadata, 0..) |field, index| fields[index] = .{ .name = field.name, .value = switch (field.value) {
        .literal => |bytes| bytes,
        .secret => |secret| if (resolver) |r| try r.resolve(r.context, secret) else return error.GrpcSecretUnresolved,
    } };
    const result: rpc.transport.Request = .{ .method = self.method, .shape = self.shape, .messages = messages, .metadata = fields[0..self.metadata.len] };
    try result.validate(limits);
    return result;
}
