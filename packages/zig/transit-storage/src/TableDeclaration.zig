//! Immutable Table interpretation: exact schema plus catalog-owned properties.
//! The full definition revision can change for a rename while row interpretation
//! remains unchanged. Staging a declaration does not publish an object or name.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const f = @import("transit_fuze");
const Objects = @import("TransitObjectStore.zig");
const header_bytes = 104;
/// Both kinds share paged row storage. The kind is part of the immutable
/// interpretation, never inferred from a two-column schema or catalog name.
pub const Kind = enum(u8) { table = 0, kv = 1 };
pub const max_properties_bytes = 4096;
pub const max_bytes = header_bytes + max_properties_bytes + f.TableSchema.max_bytes;

pub const Definition = struct {
    kind: Kind = .table,
    object: d.Object,
    revision: u64,
    schema: f.TableSchema.Schema,
    /// The catalog owns syntax and semantics. Storage preserves these exact
    /// canonical bytes, including namespace/name and authorization bindings.
    properties: []const u8,
    retired: bool = false,
    pub fn validate(self: Definition) !void {
        try self.object.validate();
        try self.schema.validate();
        if (self.kind == .kv) _ = try @import("KVDeclaration.zig").validateSchema(self.schema);
        if (self.revision == 0 or self.schema.object != self.object.object or self.properties.len > max_properties_bytes) return error.InvalidTableDeclaration;
    }
    pub fn encode(self: Definition, output: []u8) ![]const u8 {
        try self.validate();
        if (output.len < header_bytes + self.properties.len) return error.TableDeclarationTooLarge;
        output[0..8].* = "TDECL001".*;
        output[8..40].* = p.Growth.definition_bytes;
        var writer: std.Io.Writer = .fixed(output[40..header_bytes]);
        for ([_]u64{ self.object.scope.realm, self.object.scope.resource, self.object.scope.catalog, self.object.branch, self.object.object, self.revision }) |id| try writer.writeInt(u64, id, .little);
        try writer.writeInt(u64, @as(u64, @backingInt(self.kind)) << 1 | @intFromBool(self.retired), .little);
        try writer.writeInt(u32, @intCast(self.properties.len), .little);
        @memcpy(output[header_bytes..][0..self.properties.len], self.properties);
        const schema = try self.schema.encode(output[header_bytes + self.properties.len ..]);
        try writer.writeInt(u32, @intCast(schema.len), .little);
        return output[0 .. header_bytes + self.properties.len + schema.len];
    }
};

pub const Stored = struct {
    kind: Kind,
    interpretation: d.Definition,
    content: d.Content,
    schema_fingerprint: [32]u8,
    retired: bool,
    pub fn validate(self: Stored) !void {
        try self.interpretation.validate();
        try self.content.validate();
        if (self.content.bytes < header_bytes or self.content.bytes > max_bytes or !std.mem.eql(u8, &self.interpretation.digest, &self.content.sha256)) return error.InvalidTableDeclaration;
    }
};

pub const Owned = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    schema: f.TableSchema.Owned,
    definition: Definition,
    pub fn stored(self: *const Owned) !Stored {
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(self.bytes, &digest, .{});
        return .{ .kind = self.definition.kind, .interpretation = .{ .object = self.definition.object, .revision = self.definition.revision, .digest = digest }, .content = .{ .bytes = self.bytes.len, .sha256 = digest }, .schema_fingerprint = try self.schema.schema.fingerprint(), .retired = self.definition.retired };
    }
    pub fn deinit(self: *Owned) void {
        self.schema.deinit();
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "table-definitions/{x}.data", .{&content.sha256});
}

/// Builds a private definition without I/O or publication.
pub fn prepare(allocator: std.mem.Allocator, definition: Definition) !Owned {
    const buffer = try allocator.alloc(u8, max_bytes);
    defer allocator.free(buffer);
    const bytes = try allocator.dupe(u8, try definition.encode(buffer));
    errdefer allocator.free(bytes);
    const schema = try definition.schema.clone(allocator);
    var owned_definition = definition;
    owned_definition.schema = schema.schema;
    owned_definition.properties = bytes[header_bytes..][0..definition.properties.len];
    return .{ .allocator = allocator, .bytes = bytes, .schema = schema, .definition = owned_definition };
}

pub fn stage(objects: Objects.ObjectStore, owned: *const Owned) !Stored {
    const stored = try owned.stored();
    try stored.validate();
    var name: [96]u8 = undefined;
    const accepted = try objects.putImmutable(try key(stored.content, &name), owned.bytes, stored.content.sha256);
    if (accepted.size != stored.content.bytes or !std.mem.eql(u8, &accepted.sha256, &stored.content.sha256)) return error.InvalidTableDeclaration;
    return stored;
}

pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, stored: Stored) !Owned {
    try stored.validate();
    var name: [96]u8 = undefined;
    const object_key = try key(stored.content, &name);
    const metadata = try objects.head(object_key) orelse return error.TableDeclarationMissing;
    if (metadata.size != stored.content.bytes or !std.mem.eql(u8, &metadata.sha256, &stored.content.sha256)) return error.InvalidTableDeclaration;
    const bytes = try allocator.alloc(u8, @intCast(stored.content.bytes));
    errdefer allocator.free(bytes);
    if ((try objects.getRange(object_key, 0, @intCast(bytes.len), bytes)).len != bytes.len) return error.InvalidTableDeclaration;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (!std.mem.eql(u8, &digest, &stored.content.sha256) or !std.mem.eql(u8, bytes[0..8], "TDECL001")) return error.InvalidTableDeclaration;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var reader: std.Io.Reader = .fixed(bytes[40..header_bytes]);
    const object: d.Object = .{ .scope = .{ .realm = try reader.takeInt(u64, .little), .resource = try reader.takeInt(u64, .little), .catalog = try reader.takeInt(u64, .little) }, .branch = try reader.takeInt(u64, .little), .object = try reader.takeInt(u64, .little) };
    const revision = try reader.takeInt(u64, .little);
    const flags = try reader.takeInt(u64, .little);
    if (flags > 3 or ((flags & 1) == 1) != stored.retired or flags >> 1 != @backingInt(stored.kind)) return error.InvalidTableDeclaration;
    const properties_length = try reader.takeInt(u32, .little);
    const schema_length = try reader.takeInt(u32, .little);
    if (properties_length > max_properties_bytes or schema_length > f.TableSchema.max_bytes or
        @as(u64, header_bytes) + properties_length + schema_length != bytes.len or
        !std.meta.eql(object, stored.interpretation.object) or revision != stored.interpretation.revision) return error.InvalidTableDeclaration;
    var schema = try f.TableSchema.decode(allocator, bytes[header_bytes + properties_length ..]);
    errdefer schema.deinit();
    if (!std.mem.eql(u8, &try schema.schema.fingerprint(), &stored.schema_fingerprint)) return error.InvalidTableDeclaration;
    const definition: Definition = .{ .kind = stored.kind, .object = object, .revision = revision, .schema = schema.schema, .properties = bytes[header_bytes..][0..properties_length], .retired = stored.retired };
    try definition.validate();
    return .{ .allocator = allocator, .bytes = bytes, .schema = schema, .definition = definition };
}
