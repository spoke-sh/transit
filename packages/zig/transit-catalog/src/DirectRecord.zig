//! Immutable caller-owned operation bodies. The catalog authenticates the
//! principal/account scope; a format's owner validates its application meaning.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const w = c.DirectTableProtocol;
const Objects = c.storage.TransitObjectStore;
pub const max_bytes = w.max_work_bytes;
pub const Scope = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    account: [32]u8,
    pub fn validate(self: Scope) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        if (std.mem.allEqual(u8, &self.account, 0)) return error.InvalidClientToken;
    }
};
pub const Reference = struct {
    scope: Scope,
    format: u32,
    content: p.DataLifecycle.Content,
    pub fn validate(self: Reference) !void {
        try self.scope.validate();
        try self.content.validate();
        if (self.format == 0 or self.content.bytes == 0 or self.content.bytes > max_bytes) return error.InvalidDirectRecord;
    }
    pub fn requireSame(self: Reference, other: Reference) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
};
pub const Request = union(enum) {
    stage: struct { scope: Scope, format: u32, bytes: w.Binary },
    read: Reference,
    pub fn scope(self: Request) Scope {
        return switch (self) {
            .stage => |value| value.scope,
            .read => |value| value.scope,
        };
    }
    pub fn validate(self: Request) !void {
        try self.scope().validate();
        switch (self) {
            .read => |value| try value.validate(),
            .stage => |value| if (value.format == 0) return error.InvalidDirectRecord,
        }
    }
};
pub const Result = struct { reference: Reference, bytes: ?w.Binary };
pub fn reference(scope: Scope, format: u32, bytes: []const u8) !Reference {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const result: Reference = .{ .scope = scope, .format = format, .content = .{ .bytes = bytes.len, .sha256 = digest } };
    try result.validate();
    return result;
}
fn key(value: Reference, output: *[96]u8) ![]const u8 {
    try value.validate();
    var bytes: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(writer.buffered(), &digest, .{});
    return std.fmt.bufPrint(output, "direct-records/{x}.data", .{&digest});
}
pub fn store(objects: Objects.ObjectStore, scope: Scope, format: u32, bytes: []const u8) !Reference {
    const value = try reference(scope, format, bytes);
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try key(value, &name), bytes, value.content.sha256);
    if (stored.size != value.content.bytes or !std.mem.eql(u8, &stored.sha256, &value.content.sha256)) return error.InvalidDirectRecord;
    return value;
}
pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, value: Reference) ![]u8 {
    var name: [96]u8 = undefined;
    const path = try key(value, &name);
    const metadata = try objects.head(path) orelse return error.DirectRecordMissing;
    if (metadata.size != value.content.bytes or !std.mem.eql(u8, &metadata.sha256, &value.content.sha256)) return error.InvalidDirectRecord;
    const bytes = try allocator.alloc(u8, @intCast(value.content.bytes));
    errdefer allocator.free(bytes);
    if ((try objects.getRange(path, 0, @intCast(bytes.len), bytes)).len != bytes.len) return error.InvalidDirectRecord;
    try value.requireSame(try reference(value.scope, value.format, bytes));
    return bytes;
}
pub fn stage(client: c.DirectTableClient, account: [32]u8, format: u32, bytes: []const u8) !Reference {
    const scope: Scope = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = account };
    const expected = try reference(scope, format, bytes);
    const binary = try w.Binary.encode(client.allocator, bytes);
    defer client.allocator.free(binary.base64);
    const response = try client.call(.{ .record = .{ .stage = .{ .scope = scope, .format = format, .bytes = binary } } });
    defer response.deinit();
    try expected.requireSame(response.value.result.record.reference);
    return expected;
}
pub fn read(allocator: std.mem.Allocator, client: c.DirectTableClient, value: Reference) ![]u8 {
    const response = try client.call(.{ .record = .{ .read = value } });
    defer response.deinit();
    const bytes = try (response.value.result.record.bytes orelse return error.InvalidDirectRecord).decode(allocator, max_bytes);
    return @constCast(bytes);
}
