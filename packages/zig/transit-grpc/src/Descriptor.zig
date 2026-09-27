//! Local pinned FileDescriptorSet method lookup. No reflection, network or
//! application-message decoding. The digest covers the original complete bytes.
const std = @import("std");
const grpc = @import("root.zig");
const pb = grpc.protobuf;
const Self = @This();
pub const maximum_bytes = 65536;
pub const allocation_bytes = 1048576;
const MethodProto = struct {
    name: []const u8 = "",
    input_type: []const u8 = "",
    output_type: []const u8 = "",
    client_streaming: bool = false,
    server_streaming: bool = false,
    pub const pb_fields = .{
        .name = pb.Field{ .number = 1, .kind = .string },
        .input_type = pb.Field{ .number = 2, .kind = .string },
        .output_type = pb.Field{ .number = 3, .kind = .string },
        .client_streaming = pb.Field{ .number = 5, .kind = .bool },
        .server_streaming = pb.Field{ .number = 6, .kind = .bool },
    };
};
const ServiceProto = struct {
    name: []const u8 = "",
    method: []const MethodProto = &.{},
    pub const pb_fields = .{ .name = pb.Field{ .number = 1, .kind = .string }, .method = pb.Field{ .number = 2, .kind = .message } };
};
const MessageProto = struct {
    name: []const u8 = "",
    nested: []const MessageProto = &.{},
    pub const pb_fields = .{ .name = pb.Field{ .number = 1, .kind = .string }, .nested = pb.Field{ .number = 3, .kind = .message } };
};
const FileProto = struct {
    name: []const u8 = "",
    package: []const u8 = "",
    message: []const MessageProto = &.{},
    service: []const ServiceProto = &.{},
    pub const pb_fields = .{
        .name = pb.Field{ .number = 1, .kind = .string },
        .package = pb.Field{ .number = 2, .kind = .string },
        .message = pb.Field{ .number = 4, .kind = .message },
        .service = pb.Field{ .number = 6, .kind = .message },
    };
};
const Set = struct {
    file: []const FileProto = &.{},
    pub const pb_fields = .{ .file = pb.Field{ .number = 1, .kind = .message } };
};
pub const Method = struct { path: []const u8, shape: grpc.Shape, descriptor_digest: [32]u8, input_type: []const u8, output_type: []const u8 };
decoded: pb.Decoded(Set),
digest: [32]u8,
methods: u32,
pub fn deinit(self: *Self) void {
    self.decoded.deinit();
}
fn identifier(name: []const u8) !void {
    if (name.len == 0 or name.len > 255 or (!std.ascii.isAlphabetic(name[0]) and name[0] != '_')) return error.InvalidGrpcDescriptor;
    for (name) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '_') return error.InvalidGrpcDescriptor;
}
fn qualified(name: []const u8) !void {
    if (name.len == 0 or name.len > 511) return error.InvalidGrpcDescriptor;
    var parts = std.mem.splitScalar(u8, name, '.');
    while (parts.next()) |part| try identifier(part);
}
fn messageCount(items: []const MessageProto, total: *usize) !void {
    for (items, 0..) |item, index| {
        try identifier(item.name);
        total.* += 1;
        if (total.* > 256) return error.GrpcDescriptorCapacity;
        for (items[0..index]) |previous| if (std.mem.eql(u8, previous.name, item.name)) return error.InvalidGrpcDescriptor;
        try messageCount(item.nested, total);
    }
}
pub fn parse(gpa: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len == 0 or bytes.len > maximum_bytes) return error.GrpcDescriptorCapacity;
    var decoded = try pb.decode(Set, gpa, bytes, .{ .max_depth = 16, .max_arena_bytes = allocation_bytes });
    errdefer decoded.deinit();
    if (decoded.value.file.len == 0 or decoded.value.file.len > 64) return error.GrpcDescriptorCapacity;
    var total_methods: u32 = 0;
    var total_messages: usize = 0;
    for (decoded.value.file, 0..) |file, file_index| {
        if (file.name.len == 0 or file.name.len > 512) return error.InvalidGrpcDescriptor;
        for (decoded.value.file[0..file_index]) |previous| if (std.mem.eql(u8, previous.name, file.name)) return error.InvalidGrpcDescriptor;
        if (file.package.len != 0) try qualified(file.package);
        try messageCount(file.message, &total_messages);
        if (file.service.len > 64) return error.GrpcDescriptorCapacity;
        for (file.service, 0..) |service, index| {
            try identifier(service.name);
            for (file.service[0..index]) |previous| if (std.mem.eql(u8, previous.name, service.name)) return error.InvalidGrpcDescriptor;
            for (service.method, 0..) |entry, method_index| {
                total_methods += 1;
                if (total_methods > 256) return error.GrpcDescriptorCapacity;
                try identifier(entry.name);
                for (service.method[0..method_index]) |previous| if (std.mem.eql(u8, previous.name, entry.name)) return error.InvalidGrpcDescriptor;
                for ([_][]const u8{ entry.input_type, entry.output_type }) |name| {
                    if (name.len == 0 or name[0] != '.') return error.InvalidGrpcDescriptor;
                    try qualified(name[1..]);
                }
            }
        }
    }
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{ .decoded = decoded, .digest = digest, .methods = total_methods };
}
fn typeCount(items: []const MessageProto, path: []const u8) usize {
    const dot = std.mem.indexOfScalar(u8, path, '.');
    const head = path[0 .. dot orelse path.len];
    var count: usize = 0;
    for (items) |item| if (std.mem.eql(u8, item.name, head)) {
        count += if (dot) |index| typeCount(item.nested, path[index + 1 ..]) else 1;
    };
    return count;
}
fn requireType(self: *const Self, name: []const u8) !void {
    const path = name[1..];
    var count: usize = 0;
    for (self.decoded.value.file) |file| {
        if (file.package.len == 0) {
            count += typeCount(file.message, path);
        } else if (std.mem.startsWith(u8, path, file.package) and path.len > file.package.len and path[file.package.len] == '.') {
            count += typeCount(file.message, path[file.package.len + 1 ..]);
        }
    }
    if (count != 1) return error.GrpcDescriptorTypeMissingOrAmbiguous;
}
/// The path borrows the caller string; type names borrow this descriptor's arena.
/// Schema identity and shape are derived from the pinned descriptor, not guessed.
pub fn method(self: *const Self, path: []const u8) !Method {
    if (path.len < 4 or path.len > 512 or path[0] != '/') return error.InvalidGrpcRequest;
    var result: ?Method = null;
    for (self.decoded.value.file) |file| for (file.service) |service| for (service.method) |item| {
        var buffer: [512]u8 = undefined;
        const candidate = if (file.package.len != 0)
            try std.fmt.bufPrint(&buffer, "/{s}.{s}/{s}", .{ file.package, service.name, item.name })
        else
            try std.fmt.bufPrint(&buffer, "/{s}/{s}", .{ service.name, item.name });
        if (!std.mem.eql(u8, candidate, path)) continue;
        if (result != null) return error.GrpcDescriptorMethodAmbiguous;
        try self.requireType(item.input_type);
        try self.requireType(item.output_type);
        result = .{ .path = path, .shape = if (item.client_streaming) (if (item.server_streaming) .bidi else .client_streaming) else (if (item.server_streaming) .server_streaming else .unary), .descriptor_digest = self.digest, .input_type = item.input_type, .output_type = item.output_type };
    };
    return result orelse error.GrpcDescriptorMethodMissing;
}
test "pinned descriptor refuses dangling types duplicates and unbounded input" {
    const t = std.testing;
    const valid: Set = .{ .file = &.{.{ .name = "peer.proto", .package = "test", .message = &.{.{ .name = "Outer", .nested = &.{.{ .name = "Payload" }} }}, .service = &.{.{ .name = "Peer", .method = &.{.{ .name = "Call", .input_type = ".test.Outer.Payload", .output_type = ".test.Outer.Payload", .client_streaming = true, .server_streaming = true }} }} }} };
    const bytes = try pb.encodeAlloc(t.allocator, valid, .{});
    defer t.allocator.free(bytes);
    var schema = try parse(t.allocator, bytes);
    defer schema.deinit();
    try t.expectEqual(grpc.Shape.bidi, (try schema.method("/test.Peer/Call")).shape);
    try t.expectError(error.GrpcDescriptorMethodMissing, schema.method("/test.Peer/Other"));
    try t.expectError(error.GrpcDescriptorTypeMissingOrAmbiguous, schema.requireType(".test.Missing"));
    var duplicate = valid;
    duplicate.file = &.{ valid.file[0], valid.file[0] };
    const bad = try pb.encodeAlloc(t.allocator, duplicate, .{});
    defer t.allocator.free(bad);
    try t.expectError(error.InvalidGrpcDescriptor, parse(t.allocator, bad));
    try t.expectError(error.GrpcDescriptorCapacity, parse(t.allocator, &@as([maximum_bytes + 1]u8, @splat(0))));
    try t.expectError(error.Truncated, parse(t.allocator, &.{ 10, 255, 255, 255, 255, 15 }));
}
