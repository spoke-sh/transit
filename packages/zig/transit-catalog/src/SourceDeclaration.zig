//! Immutable connector declarations. Canonical bytes contain no self digest,
//! control state, credentials, callbacks or mutable name resolution.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const r = @import("DirectCatalogRecords.zig");
pub const max_bytes = 64 * 1024;
pub const header_bytes = 40;
pub const Kind = enum { connection, source };
pub const Source = struct {
    connection: d.Definition,
    destination: d.Definition,
    executor: u64,
    http: p.Source.Http,
    columns: [7]u64,

    pub fn definition(self: Source, interpretation: d.Definition) p.Source.Definition {
        return .{ .definition = p.Growth.current_definition, .interpretation = interpretation, .connection = self.connection, .destination = self.destination, .executor = self.executor, .http = self.http, .columns = self.columns };
    }
};
pub const Payload = union(Kind) {
    connection: struct {
        endpoint: []const u8,
        pub const json_schema_fields = .{ .endpoint = .{ .type = "string", .minLength = 1, .maxLength = p.Source.max_endpoint_bytes } };
    },
    source: Source,

    pub fn validate(self: Payload, object: d.Object) !void {
        switch (self) {
            .connection => |value| try p.Source.validateEndpoint(value.endpoint),
            .source => |value| {
                try c.Model.nativeId(value.executor);
                // A nonzero validation placeholder is never persisted. The
                // actual digest is computed only from the canonical payload.
                try value.definition(.{ .object = object, .revision = 1, .digest = @splat(1) }).validate();
            },
        }
    }
};
pub const Definition = struct {
    definition: p.Growth.Definition,
    object: d.Object,
    revision: u64,
    properties: r.Properties,
    owner: u64,
    payload: Payload,

    pub fn validate(self: Definition) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.object.validate();
        try self.properties.validate();
        try p.Authorization.roleId(self.owner);
        if (self.object.branch != 1 or self.revision != 1) return error.InvalidSourceDeclaration;
        try self.payload.validate(self.object);
    }
    pub fn stored(self: Definition, allocator: std.mem.Allocator) !Stored {
        const bytes = try encode(allocator, self);
        defer allocator.free(bytes);
        const content: d.Content = .{ .bytes = bytes.len, .sha256 = r.hash(bytes) };
        return .{ .kind = std.meta.activeTag(self.payload), .interpretation = .{ .object = self.object, .revision = self.revision, .digest = content.sha256 }, .content = content, .properties = self.properties, .owner = self.owner };
    }
};
pub const Stored = struct {
    kind: Kind,
    interpretation: d.Definition,
    content: d.Content,
    properties: r.Properties,
    owner: u64,
    pub fn validate(self: Stored) !void {
        try self.interpretation.validate();
        try self.content.validate();
        try self.properties.validate();
        try p.Authorization.roleId(self.owner);
        if (self.interpretation.object.branch != 1 or self.interpretation.revision != 1 or self.content.bytes <= header_bytes or self.content.bytes > max_bytes or !std.mem.eql(u8, &self.interpretation.digest, &self.content.sha256)) return error.InvalidSourceDeclaration;
    }
};
pub const Owned = std.json.Parsed(Definition);

pub fn encode(allocator: std.mem.Allocator, value: Definition) ![]u8 {
    try value.validate();
    const buffer = try allocator.alloc(u8, max_bytes);
    defer allocator.free(buffer);
    buffer[0..8].* = "TSOURCE1".*;
    buffer[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(buffer[header_bytes..]);
    std.json.Stringify.value(value, .{}, &writer) catch return error.CatalogRecordTooLarge;
    return allocator.dupe(u8, buffer[0 .. header_bytes + writer.end]);
}
pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "catalog-sources/{x}.data", .{&content.sha256});
}
pub fn stage(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, value: Definition) !Stored {
    const bytes = try encode(allocator, value);
    defer allocator.free(bytes);
    const stored = try value.stored(allocator);
    var path: [96]u8 = undefined;
    const accepted = try objects.putImmutable(try key(stored.content, &path), bytes, stored.content.sha256);
    if (accepted.size != stored.content.bytes or !std.mem.eql(u8, &accepted.sha256, &stored.content.sha256)) return error.InvalidSourceDeclaration;
    return stored;
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8, stored: Stored) !Owned {
    try stored.validate();
    if (bytes.len != stored.content.bytes or !std.mem.eql(u8, bytes[0..8], "TSOURCE1") or !std.mem.eql(u8, &r.hash(bytes), &stored.content.sha256)) return error.InvalidSourceDeclaration;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var parsed = try std.json.parseFromSlice(Definition, allocator, bytes[header_bytes..], .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    if (!std.meta.eql(try parsed.value.stored(allocator), stored)) return error.InvalidSourceDeclaration;
    return parsed;
}
pub fn load(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, stored: Stored) !Owned {
    try stored.validate();
    var path: [96]u8 = undefined;
    const name = try key(stored.content, &path);
    const metadata = try objects.head(name) orelse return error.CatalogIntentMissing;
    if (metadata.size != stored.content.bytes or !std.mem.eql(u8, &metadata.sha256, &stored.content.sha256)) return error.InvalidSourceDeclaration;
    const buffer = try allocator.alloc(u8, @intCast(metadata.size));
    defer allocator.free(buffer);
    const bytes = try objects.getRange(name, 0, @intCast(buffer.len), buffer);
    return decode(allocator, bytes, stored);
}

test "SOURCE declaration identity excludes control and owns canonical strings" {
    const t = std.testing;
    const value: Definition = .{ .definition = p.Growth.current_definition, .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .properties = .{ .namespace = 1, .authorization = 6, .name = try .init("upstream") }, .owner = 1, .payload = .{ .connection = .{ .endpoint = "https://example.com" } } };
    const stored = try value.stored(t.allocator);
    const bytes = try encode(t.allocator, value);
    defer t.allocator.free(bytes);
    var owned = try decode(t.allocator, bytes, stored);
    defer owned.deinit();
    try t.expectEqualStrings("https://example.com", owned.value.payload.connection.endpoint);
    try t.expect(owned.value.payload.connection.endpoint.ptr != value.payload.connection.endpoint.ptr);
    var changed = value;
    changed.owner = 2;
    try t.expect(!std.meta.eql(stored.interpretation, (try changed.stored(t.allocator)).interpretation));
    var corrupt = stored;
    corrupt.content.sha256[0] ^= 1;
    try t.expectError(error.InvalidSourceDeclaration, decode(t.allocator, bytes, corrupt));
    try t.expectError(error.InvalidSourceDeclaration, decode(t.allocator, bytes[0..10], stored));
}

test "SOURCE maximum canonical artifact fits independent 64 KiB budget" {
    const t = std.testing;
    const maximum = std.math.maxInt(u64);
    const object: d.Object = .{ .scope = .{ .realm = p.max_counter, .resource = p.max_counter, .catalog = maximum }, .branch = 1, .object = maximum };
    var connection = object;
    connection.object -= 1;
    var destination = connection;
    destination.object -= 1;
    var path: [p.Source.max_path_bytes]u8 = @splat('"');
    path[0] = '/';
    const value: Definition = .{ .definition = p.Growth.current_definition, .object = object, .revision = 1, .properties = .{ .namespace = p.max_counter, .authorization = p.max_counter, .name = try .init(&@as([p.Authorization.max_name_bytes]u8, @splat('"'))) }, .owner = p.Authorization.public_role - 1, .payload = .{ .source = .{ .connection = .{ .object = connection, .revision = maximum, .digest = @splat(255) }, .destination = .{ .object = destination, .revision = maximum, .digest = @splat(255) }, .executor = p.max_counter, .http = .{ .method = .GET, .path = &path, .poll_interval_ms = maximum, .request_timeout_ms = maximum, .response_max_bytes = maximum }, .columns = .{ maximum, maximum - 1, maximum - 2, maximum - 3, maximum - 4, maximum - 5, maximum - 6 } } } };
    const bytes = try encode(t.allocator, value);
    defer t.allocator.free(bytes);
    // ASCII endpoint/path validation bounds JSON escaping to two bytes per
    // character. The remaining fixed fields fit independently in 8 KiB.
    try t.expect(bytes.len <= header_bytes + 2 * p.Source.max_path_bytes + 8192);
    var decoded = try decode(t.allocator, bytes, try value.stored(t.allocator));
    defer decoded.deinit();
    var invalid = value;
    invalid.payload.source.executor = 0;
    try t.expectError(error.InvalidCatalogIdentity, invalid.validate());
}
