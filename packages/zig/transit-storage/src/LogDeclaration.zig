//! Immutable schema and policy interpretation for a declared Stream or Queue.
//! Catalog publication and grants remain independent of staging these bytes.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const q = p.StreamQueueDeclaration;
const f = @import("transit_fuze");
const Objects = @import("TransitObjectStore.zig");
const header_bytes = 104;
pub const max_properties_bytes = 4096;
pub const max_policy_bytes = 4096;
pub const max_bytes = header_bytes + max_properties_bytes + max_policy_bytes + f.TableSchema.max_bytes;
const Policy = struct { configuration: q.Configuration, limits: q.Limits };

pub const Definition = struct {
    object: d.Object,
    revision: u64,
    schema: f.TableSchema.Schema,
    configuration: q.Configuration,
    limits: q.Limits,
    properties: []const u8,
    retired: bool = false,

    pub fn validate(self: Definition) !void {
        try self.object.validate();
        try self.schema.validate();
        try self.configuration.validate();
        try self.limits.validate();
        if (self.object.branch != 1 or self.revision == 0 or self.schema.object != self.object.object or self.properties.len > max_properties_bytes) return error.InvalidLogDeclaration;
        // Log offsets supply identity. A declared relational uniqueness key
        // would silently impose a different append contract.
        if (self.schema.primary_key.len != 0) return error.UnsupportedLogPrimaryKey;
        if (self.configuration.partitioning.key_column) |column| try self.requireKey(column);
        switch (self.configuration.policy) {
            .stream => |stream| {
                if (stream.compact_key_column) |column| try self.requireKey(column);
                if (stream.timestamp_column) |id| {
                    const column = self.schema.columns[try self.schema.index(id)];
                    if (column.nullable or column.type != .timestamp or column.type.timestamp != .utc) return error.InvalidStreamTimestampColumn;
                }
            },
            .queue => |queue| {
                if (queue.key_column) |column| try self.requireKey(column);
                if (queue.dead_letter) |destination| {
                    if (!std.meta.eql(destination.object.scope, self.object.scope) or destination.object.branch != self.object.branch or std.meta.eql(destination.object, self.object)) return error.InvalidQueueDestination;
                }
            },
        }
    }

    fn requireKey(self: Definition, id: u64) !void {
        const column = self.schema.columns[try self.schema.index(id)];
        if (column.nullable or !f.TableSchema.keyType(column.type)) return error.InvalidLogKeyColumn;
    }

    pub fn encode(self: Definition, output: []u8) ![]const u8 {
        try self.validate();
        if (output.len < header_bytes) return error.LogDeclarationTooLarge;
        var policy_writer: std.Io.Writer = .fixed(output[header_bytes..][0..@min(max_policy_bytes, output.len - header_bytes)]);
        var policy_encoder: std.json.Stringify = .{ .writer = &policy_writer };
        try p.Json.write(Policy{ .configuration = self.configuration, .limits = self.limits }, &policy_encoder);
        const policy_bytes = policy_writer.buffered().len;
        const at = header_bytes + policy_bytes;
        if (self.properties.len > output.len - at) return error.LogDeclarationTooLarge;
        @memcpy(output[at..][0..self.properties.len], self.properties);
        const schema = try self.schema.encode(output[at + self.properties.len ..]);
        output[0..8].* = "LDECL001".*;
        output[8..40].* = p.Growth.definition_bytes;
        var writer: std.Io.Writer = .fixed(output[40..header_bytes]);
        for ([_]u64{ self.object.scope.realm, self.object.scope.resource, self.object.scope.catalog, self.object.branch, self.object.object, self.revision }) |value| try writer.writeInt(u64, value, .big);
        try writer.writeByte(@intFromBool(self.retired));
        try writer.writeInt(u32, @intCast(policy_bytes), .big);
        try writer.writeInt(u32, @intCast(self.properties.len), .big);
        try writer.writeInt(u32, @intCast(schema.len), .big);
        try writer.writeAll(&.{ 0, 0, 0 });
        return output[0 .. at + self.properties.len + schema.len];
    }
};

pub const Stored = struct {
    declaration: q.Declaration,
    content: d.Content,
    retired: bool,

    pub fn validate(self: Stored) !void {
        try self.declaration.validate();
        try self.content.validate();
        if (self.content.bytes <= header_bytes or self.content.bytes > max_bytes or self.declaration.schema.bytes > f.TableSchema.max_bytes or !std.mem.eql(u8, &self.declaration.interpretation.digest, &self.content.sha256)) return error.InvalidLogDeclaration;
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
        const schema_length = std.mem.readInt(u32, self.bytes[97..101], .big);
        var schema_digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(self.bytes[self.bytes.len - schema_length ..], &schema_digest, .{});
        const result: Stored = .{
            .declaration = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = self.definition.object, .revision = self.definition.revision, .digest = digest }, .schema = .{ .bytes = schema_length, .sha256 = schema_digest }, .configuration = self.definition.configuration, .limits = self.definition.limits },
            .content = .{ .bytes = self.bytes.len, .sha256 = digest },
            .retired = self.definition.retired,
        };
        try result.validate();
        return result;
    }

    pub fn deinit(self: *Owned) void {
        self.schema.deinit();
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "log-definitions/{x}.data", .{&content.sha256});
}

pub fn prepare(allocator: std.mem.Allocator, definition: Definition) !Owned {
    const buffer = try allocator.alloc(u8, max_bytes);
    defer allocator.free(buffer);
    const bytes = try allocator.dupe(u8, try definition.encode(buffer));
    errdefer allocator.free(bytes);
    const schema = try definition.schema.clone(allocator);
    var owned_definition = definition;
    owned_definition.schema = schema.schema;
    const policy_length = std.mem.readInt(u32, bytes[89..93], .big);
    owned_definition.properties = bytes[header_bytes + policy_length ..][0..definition.properties.len];
    return .{ .allocator = allocator, .bytes = bytes, .schema = schema, .definition = owned_definition };
}

pub fn stage(objects: Objects.ObjectStore, owned: *const Owned) !Stored {
    const stored = try owned.stored();
    var name: [96]u8 = undefined;
    const accepted = try objects.putImmutable(try key(stored.content, &name), owned.bytes, stored.content.sha256);
    if (accepted.size != stored.content.bytes or !std.mem.eql(u8, &accepted.sha256, &stored.content.sha256)) return error.InvalidLogDeclaration;
    return stored;
}

pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, stored: Stored) !Owned {
    try stored.validate();
    var result = try loadContent(allocator, objects, stored.content);
    errdefer result.deinit();
    if (!std.meta.eql(stored, try result.stored())) return error.InvalidLogDeclaration;
    return result;
}

/// Resolve an exact retained interpretation without consulting a mutable name
/// or current catalog definition. This verifies bytes, not publication or access.
pub fn resolve(allocator: std.mem.Allocator, objects: Objects.ObjectStore, interpretation: d.Definition) !Owned {
    try interpretation.validate();
    var name: [96]u8 = undefined;
    const object_key = try std.fmt.bufPrint(&name, "log-definitions/{x}.data", .{&interpretation.digest});
    const metadata = try objects.head(object_key) orelse return error.LogDeclarationMissing;
    if (!std.mem.eql(u8, &metadata.sha256, &interpretation.digest)) return error.InvalidLogDeclaration;
    var result = try loadContent(allocator, objects, .{ .bytes = metadata.size, .sha256 = interpretation.digest });
    errdefer result.deinit();
    if (!std.meta.eql(interpretation, (try result.stored()).declaration.interpretation)) return error.InvalidLogDeclaration;
    return result;
}

fn loadContent(allocator: std.mem.Allocator, objects: Objects.ObjectStore, content: d.Content) !Owned {
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_bytes) return error.InvalidLogDeclaration;
    var name: [96]u8 = undefined;
    const object_key = try key(content, &name);
    const metadata = try objects.head(object_key) orelse return error.LogDeclarationMissing;
    if (metadata.size != content.bytes or !std.mem.eql(u8, &metadata.sha256, &content.sha256)) return error.InvalidLogDeclaration;
    const bytes = try allocator.alloc(u8, @intCast(content.bytes));
    errdefer allocator.free(bytes);
    if ((try objects.getRange(object_key, 0, @intCast(bytes.len), bytes)).len != bytes.len) return error.InvalidLogDeclaration;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (!std.mem.eql(u8, &digest, &content.sha256) or !std.mem.eql(u8, bytes[0..8], "LDECL001")) return error.InvalidLogDeclaration;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    if (bytes[88] > 1 or !std.mem.allEqual(u8, bytes[101..104], 0)) return error.InvalidLogDeclaration;
    const policy_length = std.mem.readInt(u32, bytes[89..93], .big);
    const properties_length = std.mem.readInt(u32, bytes[93..97], .big);
    const schema_length = std.mem.readInt(u32, bytes[97..101], .big);
    if (policy_length > max_policy_bytes or properties_length > max_properties_bytes or schema_length > f.TableSchema.max_bytes or @as(u64, header_bytes) + policy_length + properties_length + schema_length != bytes.len) return error.InvalidLogDeclaration;
    const policy = try p.Json.parseFromSlice(Policy, allocator, bytes[header_bytes..][0..policy_length]);
    defer policy.deinit();
    var canonical: [max_policy_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&canonical);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(policy.value, &encoder);
    if (!std.mem.eql(u8, bytes[header_bytes..][0..policy_length], writer.buffered())) return error.InvalidLogDeclaration;
    var schema = try f.TableSchema.decode(allocator, bytes[bytes.len - schema_length ..]);
    errdefer schema.deinit();
    var reader: std.Io.Reader = .fixed(bytes[40..88]);
    const definition: Definition = .{
        .object = .{ .scope = .{ .realm = try reader.takeInt(u64, .big), .resource = try reader.takeInt(u64, .big), .catalog = try reader.takeInt(u64, .big) }, .branch = try reader.takeInt(u64, .big), .object = try reader.takeInt(u64, .big) },
        .revision = try reader.takeInt(u64, .big),
        .schema = schema.schema,
        .configuration = policy.value.configuration,
        .limits = policy.value.limits,
        .properties = bytes[header_bytes + policy_length ..][0..properties_length],
        .retired = bytes[88] == 1,
    };
    try definition.validate();
    var result: Owned = .{ .allocator = allocator, .bytes = bytes, .schema = schema, .definition = definition };
    _ = try result.stored();
    return result;
}
