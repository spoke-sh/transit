//! Shared catalog names, definition bytes and scoped identity encoding.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
pub const Scope = c.Model.Scope;
pub const Name = struct {
    len: u8,
    data: [255]u8 = @splat(0),
    pub fn init(bytes: []const u8) !Name {
        if (bytes.len == 0 or bytes.len > 255 or !std.unicode.utf8ValidateSlice(bytes) or std.mem.indexOfScalar(u8, bytes, 0) != null) return error.InvalidCatalogName;
        var result: Name = .{ .len = @intCast(bytes.len) };
        @memcpy(result.data[0..bytes.len], bytes);
        return result;
    }
    pub fn slice(self: *const Name) []const u8 {
        return self.data[0..self.len];
    }
    pub fn validate(self: *const Name) !void {
        _ = try init(self.slice());
    }
    pub fn eql(self: *const Name, other: *const Name) bool {
        return std.mem.eql(u8, self.slice(), other.slice());
    }
    pub fn digest(self: *const Name) ![32]u8 {
        return self.digestIn(1);
    }
    pub fn digestIn(self: *const Name, namespace: u64) ![32]u8 {
        try c.Model.nativeId(namespace);
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.name.v1\x00");
        var id: [8]u8 = undefined;
        std.mem.writeInt(u64, &id, namespace, .little);
        hash.update(&id);
        hash.update(self.slice());
        return hash.finalResult();
    }
};
pub fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}
pub fn scopeWrite(writer: *std.Io.Writer, scope: Scope) !void {
    try scope.validate();
    try writer.writeInt(u64, scope.realm, .little);
    try writer.writeInt(u64, scope.resource, .little);
    try writer.writeInt(u64, scope.catalog, .little);
}
pub fn scopeRead(reader: *std.Io.Reader) !Scope {
    const scope: Scope = .{ .realm = try reader.takeInt(u64, .little), .resource = try reader.takeInt(u64, .little), .catalog = try reader.takeInt(u64, .little) };
    try scope.validate();
    return scope;
}
