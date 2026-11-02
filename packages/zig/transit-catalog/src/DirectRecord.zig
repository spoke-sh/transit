//! Immutable operation bodies and guarded retained content. The catalog checks
//! principal/account scope and immutable read guards; format owners validate
//! payload meaning.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const w = c.DirectTableProtocol;
const Objects = c.storage.TransitObjectStore;
pub const max_bytes = w.max_work_bytes;
/// High-bit formats carry an authenticated, content-addressed read envelope.
/// Its bounded conjunction is part of the immutable bytes, never caller-supplied
/// read authority. Generic reads must enforce it before returning the envelope.
pub const guarded_bit: u32 = 0x80000000;
pub const Guarded = struct {
    definition: p.Growth.Definition,
    objects: [3]?p.DataLifecycle.Object,
    payload: w.Binary,

    pub fn validate(self: Guarded, connection: w.Connection) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (self.objects[0] == null) return error.InvalidDirectRecord;
        var ended = false;
        for (self.objects, 0..) |slot, i| {
            const object = slot orelse {
                ended = true;
                continue;
            };
            if (ended) return error.InvalidDirectRecord;
            try connection.object(object);
            for (self.objects[0..i]) |previous| if (std.meta.eql(previous.?, object)) return error.InvalidDirectRecord;
        }
    }
};

pub fn encodeGuarded(allocator: std.mem.Allocator, connection: w.Connection, objects: [3]?p.DataLifecycle.Object, payload: []const u8) ![]u8 {
    const binary = try w.Binary.encode(allocator, payload);
    defer allocator.free(binary.base64);
    const value: Guarded = .{ .definition = p.Growth.current_definition, .objects = objects, .payload = binary };
    try value.validate(connection);
    return p.Json.valueAllocBounded(allocator, value, max_bytes);
}
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
pub fn key(value: Reference, output: *[96]u8) ![]const u8 {
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

test "guarded record policy is immutable content and requires a bounded nonempty same-scope conjunction" {
    const t = std.testing;
    const connection: w.Connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .principal = 0 };
    const object: p.DataLifecycle.Object = .{ .scope = connection.scope, .branch = 1, .object = 7 };
    const encoded = try encodeGuarded(t.allocator, connection, .{ object, null, null }, "retained bytes");
    defer t.allocator.free(encoded);
    const parsed = try p.Json.parseFromSlice(Guarded, t.allocator, encoded);
    defer parsed.deinit();
    try parsed.value.validate(connection);
    var invalid = parsed.value;
    invalid.objects = @splat(null);
    try t.expectError(error.InvalidDirectRecord, invalid.validate(connection));
    invalid.objects = .{ object, null, object };
    try t.expectError(error.InvalidDirectRecord, invalid.validate(connection));
    invalid.objects = .{ object, object, null };
    try t.expectError(error.InvalidDirectRecord, invalid.validate(connection));
    const scope: Scope = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(1) };
    const protected = try reference(scope, guarded_bit | 7, encoded);
    const raw = try reference(scope, 7, encoded);
    var first: [96]u8 = undefined;
    var second: [96]u8 = undefined;
    try t.expect(!std.mem.eql(u8, try key(protected, &first), try key(raw, &second)));
}
