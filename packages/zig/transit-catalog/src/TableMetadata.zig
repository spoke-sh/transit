//! Immutable catalog metadata for a general typed Table. Names, catalog
//! revisions and physical schema references have distinct identities.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const Pages = c.station.TablePages;
const Pub = c.station.Publication;
pub const Scope = c.Model.Scope;
pub const max_bytes = 436;
pub const format: u32 = 0x54434d01;
pub const name_digest_bytes = 13;
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
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.name.v1\x00");
        hash.update(self.slice());
        return hash.finalResult();
    }
};
pub fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}
pub const Record = struct {
    scope: Scope,
    object: u64,
    revision: u64,
    name: Name,
    schema: Pages.Reference,
    schema_fingerprint: [32]u8,
    principal: u64,
    operation: u64,
    admitted_input: u64,
    pub fn validate(self: Record) !void {
        try self.scope.validate();
        try self.name.validate();
        if (self.object == 0 or self.revision == 0 or self.schema.id == 0 or self.schema.spec.format != Pages.schema_format or
            self.schema.spec.length == 0 or self.schema.spec.length > c.fuze.TableSchema.max_bytes or
            self.principal > p.max_counter or self.operation == 0 or self.admitted_input == 0 or self.admitted_input > p.max_counter) return error.InvalidCatalogDefinition;
    }
    pub fn encode(self: Record, output: []u8) ![]const u8 {
        try self.validate();
        var writer: std.Io.Writer = .fixed(output[0..@min(max_bytes, output.len)]);
        try writer.writeAll("TCM1");
        try writer.writeAll(&definition());
        try scopeWrite(&writer, self.scope);
        try writer.writeInt(u64, self.object, .little);
        try writer.writeInt(u64, self.revision, .little);
        try writer.writeByte(self.name.len);
        try writer.writeAll(self.name.slice());
        try referenceWrite(&writer, self.schema);
        try writer.writeAll(&self.schema_fingerprint);
        try writer.writeInt(u64, self.principal, .little);
        try writer.writeInt(u64, self.operation, .little);
        try writer.writeInt(u64, self.admitted_input, .little);
        return writer.buffered();
    }
    fn parse(bytes: []const u8) !Record {
        if (bytes.len > max_bytes) return error.InvalidCatalogDefinition;
        var reader: std.Io.Reader = .fixed(bytes);
        if (!std.mem.eql(u8, try reader.take(4), "TCM1")) return error.InvalidCatalogDefinition;
        if (!std.mem.eql(u8, try reader.take(32), &definition())) return error.IncompatibleDefinition;
        const result: Record = .{
            .scope = try scopeRead(&reader),
            .object = try reader.takeInt(u64, .little),
            .revision = try reader.takeInt(u64, .little),
            .name = try Name.init(try reader.take(try reader.takeByte())),
            .schema = try referenceRead(&reader),
            .schema_fingerprint = (try reader.take(32))[0..32].*,
            .principal = try reader.takeInt(u64, .little),
            .operation = try reader.takeInt(u64, .little),
            .admitted_input = try reader.takeInt(u64, .little),
        };
        if (reader.bufferedLen() != 0) return error.InvalidCatalogDefinition;
        try result.validate();
        return result;
    }
    pub fn decode(bytes: []const u8) !Record {
        return parse(bytes) catch |err| switch (err) {
            error.EndOfStream => error.InvalidCatalogDefinition,
            else => err,
        };
    }
    /// Current source authority is supplied by the caller. Historical metadata
    /// decodes its original immutable schema, never a later Table head.
    pub fn readSchema(self: Record, allocator: std.mem.Allocator, source: anytype) !c.fuze.TableSchema.Owned {
        try self.validate();
        const pages: Pages = .{ .resource = self.scope.resource, .object = self.object };
        const buffer = try allocator.alloc(u8, self.schema.spec.length);
        defer allocator.free(buffer);
        var owned = try c.fuze.TableSchema.decode(allocator, try pages.read(source, self.schema, buffer));
        errdefer owned.deinit();
        if (owned.schema.object != self.object or !std.mem.eql(u8, &try owned.schema.fingerprint(), &self.schema_fingerprint)) return error.CatalogDefinitionChanged;
        return owned;
    }
    pub fn spec(self: Record) !Pub.Spec {
        var bytes: [max_bytes]u8 = undefined;
        return Pub.Digest.of(format, try self.encode(&bytes));
    }
};
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
pub fn referenceWrite(writer: *std.Io.Writer, ref: Pages.Reference) !void {
    try writer.writeInt(u64, ref.id, .little);
    try writer.writeInt(u32, ref.spec.format, .little);
    try writer.writeInt(u32, ref.spec.length, .little);
    try writer.writeAll(&ref.spec.digest);
}
pub fn referenceRead(reader: *std.Io.Reader) !Pages.Reference {
    return .{ .id = try reader.takeInt(u64, .little), .spec = .{ .format = try reader.takeInt(u32, .little), .length = try reader.takeInt(u32, .little), .digest = (try reader.take(32))[0..32].* } };
}
/// Full names are checked after reading metadata from a collision bucket. Hash
/// equality alone never establishes a binding. Object suffixes retain all ties.
pub fn nameKey(catalog: u64, digest: [32]u8, object: u64) !p.Value {
    if (catalog == 0 or object == 0) return error.InvalidCatalogIdentity;
    var bytes: [32]u8 = undefined;
    bytes[0..11].* = c.Records.prefix(catalog, 'N').data[0..11].*;
    bytes[11..24].* = digest[0..name_digest_bytes].*;
    std.mem.writeInt(u64, bytes[24..32], object, .big);
    const result = try p.Value.init(&bytes);
    try p.State.key(result);
    return result;
}
