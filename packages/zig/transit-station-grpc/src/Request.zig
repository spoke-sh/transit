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
    return self.validateDiagnostic(null);
}
fn reject(context: ?*?rpc.Service.Rejection, check: rpc.exchange.AdmissionRejection.Check, field: []const u8, expected: rpc.exchange.AdmissionRejection.Scalar, actual: rpc.exchange.AdmissionRejection.Scalar, cause: anyerror) anyerror {
    if (context) |slot| if (slot.* == null) {
        slot.* = rpc.Service.Rejection.detail(.invalid_request, check, field, expected, actual, cause);
    };
    return cause;
}
fn scalar(value: rpc.transport.Validation.Scalar) rpc.exchange.AdmissionRejection.Scalar {
    return switch (value) {
        .unsigned => |v| .{ .unsigned = v },
        .text => |v| .{ .text = v },
        .redacted => .redacted,
    };
}
pub fn transportFailure(context: ?*?rpc.Service.Rejection, detail: ?rpc.transport.Validation, reason: rpc.exchange.AdmissionRejection.Reason, cause: anyerror) anyerror {
    if (detail) |value| if (context) |slot| if (slot.* == null) {
        const check: rpc.exchange.AdmissionRejection.Check = switch (value.check) {
            .equal => .equal,
            .maximum => .maximum,
            .different => .different,
            .decode => .decode,
            .policy => .policy,
        };
        slot.* = rpc.Service.Rejection.detail(reason, check, value.path(), scalar(value.expected), scalar(value.actual), cause);
    };
    return cause;
}
pub fn validateDiagnostic(self: Self, context: ?*?rpc.Service.Rejection) !void {
    if (self.metadata.len > 64) return reject(context, .maximum, "request.metadata.count", .{ .unsigned = 64 }, .{ .unsigned = self.metadata.len }, error.InvalidGrpcMetadata);
    var fields: [64]rpc.transport.Entry = undefined;
    for (self.metadata, 0..) |entry, index| {
        var path_bytes: [64]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_bytes, "metadata[{d}].value", .{index});
        if (entry.value == .literal and rpc.Policy.sensitive(entry.name)) return reject(context, .policy, path, .{ .text = "credential reference" }, .redacted, error.GrpcCredentialReferenceRequired);
        fields[index] = .{ .name = entry.name, .value = switch (entry.value) {
            .literal => |bytes| bytes,
            .secret => |secret| blk: {
                var binding_path: [64]u8 = undefined;
                const binding = try std.fmt.bufPrint(&binding_path, "metadata[{d}].binding.bytes", .{index});
                var version_path: [64]u8 = undefined;
                const version = try std.fmt.bufPrint(&version_path, "metadata[{d}].version", .{index});
                if (secret.binding.len == 0) return reject(context, .different, binding, .{ .unsigned = 0 }, .{ .unsigned = 0 }, error.InvalidGrpcSecret);
                if (secret.binding.len > 128) return reject(context, .maximum, binding, .{ .unsigned = 128 }, .{ .unsigned = secret.binding.len }, error.InvalidGrpcSecret);
                if (secret.version == 0) return reject(context, .different, version, .{ .unsigned = 0 }, .{ .unsigned = 0 }, error.InvalidGrpcSecret);
                for (secret.binding) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '_' and byte != '-' and byte != '.') return reject(context, .policy, binding, .{ .text = "binding: letters/digits/_/./-" }, .redacted, error.InvalidGrpcSecret);
                break :blk "";
            },
        } };
    }
    var detail: ?rpc.transport.Validation = null;
    (rpc.transport.Request{ .method = self.method, .shape = self.shape, .messages = if (self.shape == .unary or self.shape == .server_streaming) &.{""} else &.{}, .metadata = fields[0..self.metadata.len] }).validateDiagnostic(.{}, &detail) catch |err| return transportFailure(context, detail, .invalid_request, err);
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
    return parseDiagnostic(gpa, bytes, null);
}
pub fn parseDiagnostic(gpa: std.mem.Allocator, bytes: []const u8, context: ?*?rpc.Service.Rejection) !Owned {
    if (bytes.len == 0) return reject(context, .different, "request.metadata.bytes", .{ .unsigned = 0 }, .{ .unsigned = 0 }, error.InvalidGrpcRequest);
    if (bytes.len > maximum_bytes) return reject(context, .maximum, "request.metadata.bytes", .{ .unsigned = maximum_bytes }, .{ .unsigned = bytes.len }, error.InvalidGrpcRequest);
    var arena: std.heap.ArenaAllocator = .init(gpa);
    errdefer arena.deinit();
    const a = arena.allocator();
    const wire = std.json.parseFromSliceLeaky(Wire, a, bytes, .{ .allocate = .alloc_always }) catch |err| {
        if (err == error.OutOfMemory) return err;
        return reject(context, .decode, "request.metadata", .{ .text = "request provenance JSON" }, .redacted, err);
    };
    if (wire.version != 1) return reject(context, .equal, "request.version", .{ .unsigned = 1 }, .{ .unsigned = wire.version }, error.InvalidGrpcRequest);
    if (wire.descriptor_digest.len != 64) return reject(context, .equal, "request.descriptor_digest.bytes", .{ .unsigned = 64 }, .{ .unsigned = wire.descriptor_digest.len }, error.InvalidGrpcRequest);
    if (wire.metadata.len > 64) return reject(context, .maximum, "request.metadata.count", .{ .unsigned = 64 }, .{ .unsigned = wire.metadata.len }, error.InvalidGrpcRequest);
    var request: Self = .{ .method = wire.method, .shape = wire.shape, .descriptor_digest = undefined };
    _ = std.fmt.hexToBytes(&request.descriptor_digest, wire.descriptor_digest) catch |err| return reject(context, .decode, "request.descriptor_digest", .{ .text = "64 hexadecimal characters" }, .redacted, err);
    const entries = try a.alloc(Entry, wire.metadata.len);
    for (entries, wire.metadata, 0..) |*entry, field, index| {
        entry.* = .{ .name = field.name, .value = switch (field.value) {
            .secret => |secret| .{ .secret = secret },
            .literal_hex => |hex| blk: {
                var path_bytes: [64]u8 = undefined;
                const path = try std.fmt.bufPrint(&path_bytes, "request.metadata[{d}].literal_hex", .{index});
                if (hex.len % 2 != 0) return reject(context, .decode, path, .{ .text = "even hexadecimal byte length" }, .{ .unsigned = hex.len }, error.InvalidGrpcMetadata);
                const literal = try a.alloc(u8, hex.len / 2);
                _ = std.fmt.hexToBytes(literal, hex) catch |err| return reject(context, .decode, path, .{ .text = "hexadecimal bytes" }, .redacted, err);
                break :blk .{ .literal = literal };
            },
        } };
    }
    request.metadata = entries;
    try request.validateDiagnostic(context);
    var canonical: [maximum_bytes]u8 = undefined;
    const encoded = request.provenance(&canonical) catch |err| {
        if (err != error.WriteFailed) return err;
        return reject(context, .maximum, "request.metadata.bytes", .{ .unsigned = canonical.len }, .unrecorded, err);
    };
    if (!std.mem.eql(u8, bytes, encoded)) return reject(context, .equal, "request.metadata.encoding", .{ .text = "canonical provenance JSON" }, .redacted, error.NonCanonicalGrpcRequest);
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
