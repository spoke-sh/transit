//! SQL object semantics above generic native authorization. These values bind
//! stable identities; they are never a second grant store or cached decision.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const a = p.Authorization;
pub const connect: u64 = 1;
pub const usage: u64 = 1;
pub const create: u64 = 2;
pub const select: u64 = 1;
pub const insert: u64 = 2;
pub const update: u64 = 4;
pub const delete: u64 = 8;
pub const table_actions: u64 = select | insert | update | delete;
pub const Kind = enum(u8) { database = 1, schema = 2, table = 3 };
pub const Profile = struct {
    database_domain: u64,
    schema_domain: u64,
    table_domain: u64,
    database: u64,
    initial_schema: u64,
    initial_schema_authority: u64,
    pub fn validate(self: Profile) !void {
        inline for (@typeInfo(Profile).@"struct".field_names) |field| try c.Model.nativeId(@field(self, field));
        if (self.database_domain == self.schema_domain or self.database_domain == self.table_domain or self.schema_domain == self.table_domain or self.database == self.initial_schema_authority) return error.InvalidCatalogConfiguration;
    }
    pub fn domain(self: Profile, kind: Kind) u64 {
        return switch (kind) {
            .database => self.database_domain,
            .schema => self.schema_domain,
            .table => self.table_domain,
        };
    }
};
pub const Name = struct {
    len: u8,
    bytes: [a.max_name_bytes]u8 = @splat(0),
    pub fn init(text: []const u8) !Name {
        try a.name(try p.Value.init(text));
        var result: Name = .{ .len = @intCast(text.len) };
        @memcpy(result.bytes[0..text.len], text);
        return result;
    }
    pub fn slice(self: *const Name) []const u8 {
        return self.bytes[0..self.len];
    }
    pub fn validate(self: Name) !void {
        if (self.len == 0 or self.len > self.bytes.len) return error.InvalidCatalogName;
        try a.name(try p.Value.init(self.bytes[0..self.len]));
        for (self.bytes[self.len..]) |byte| if (byte != 0) return error.InvalidCatalogName;
    }
};
/// Catalog-owned namespace metadata. Native policy owns the current role owner.
pub const Schema = struct {
    scope: c.Model.Scope,
    id: u64,
    authorization: u64,
    name: Name,
    revision: u64,
    retired: bool = false,
    pub fn validate(self: Schema) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.id);
        try c.Model.nativeId(self.authorization);
        try self.name.validate();
        if (self.revision == 0 or self.revision > p.max_counter) return error.InvalidCatalogConfiguration;
    }
};
pub const Table = struct { id: u64, schema: u64, authorization: u64 };
pub fn reference(id: u64) a.ObjectRef {
    return .{ .kind = .domain, .id = id };
}
pub fn actions(kind: Kind) u64 {
    return switch (kind) {
        .database => connect,
        .schema => usage | create,
        .table => table_actions,
    };
}
/// Full identities are hashed, never truncated numeric IDs or reusable names.
pub fn binding(scope: c.Model.Scope, kind: Kind, id: u64) ![32]u8 {
    try scope.validate();
    if ((kind == .database) != (id == 0)) return error.InvalidCatalogIdentity;
    var bytes: [33]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try c.TableMetadata.scopeWrite(&writer, scope);
    try writer.writeByte(@backingInt(kind));
    try writer.writeInt(u64, id, .little);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.catalog.authorization.binding.v1\x00");
    hash.update(&c.TableMetadata.definition());
    hash.update(writer.buffered());
    return hash.finalResult();
}
pub fn validateObject(profile: Profile, scope: c.Model.Scope, kind: Kind, id: u64, parent: ?a.ObjectRef, object: a.Object) !void {
    try profile.validate();
    try object.validate();
    if (object.reference.kind != .domain or object.domain != profile.domain(kind) or object.actions != actions(kind) or object.binding == null or !std.mem.eql(u8, &object.binding.?, &try binding(scope, kind, id)) or !std.meta.eql(object.parent, parent)) return error.InvalidCatalogConfiguration;
    if (object.retired) return error.CatalogDenied;
}
pub const Access = enum { database, schema, create_schema, create_table, inspect, read, insert, update, delete, alter, drop };
/// Every source needs CONNECT and USAGE in addition to its own Table privilege.
/// A caller prepares one union of requirements for a multi-source disclosure.
pub fn guard(subject: a.Subject, profile: Profile, schema: ?Schema, table: ?Table, access: Access) !a.Guard {
    try profile.validate();
    var result: a.Guard = .{ .subject = subject, .requirements = @splat(null) };
    result.requirements[0] = .{ .object = reference(profile.database), .privileges = connect };
    if (access == .create_schema) {
        result.requirements[1] = .{ .object = reference(profile.database), .access = .ownership };
    } else if (access != .database) {
        const namespace = schema orelse return error.InvalidCatalogConfiguration;
        try namespace.validate();
        if (namespace.retired) return error.CatalogDenied;
        result.requirements[1] = .{ .object = reference(namespace.authorization), .privileges = usage | if (access == .create_table) create else @as(u64, 0) };
        if (access != .schema and access != .create_table) {
            const target = table orelse return error.InvalidCatalogIdentity;
            if (target.id == 0 or target.schema != namespace.id) return error.InvalidCatalogIdentity;
            try c.Model.nativeId(target.authorization);
            result.requirements[2] = switch (access) {
                .inspect => .{ .object = reference(target.authorization), .privileges = table_actions, .access = .visible },
                .read => .{ .object = reference(target.authorization), .privileges = select },
                .insert => .{ .object = reference(target.authorization), .privileges = insert },
                .update => .{ .object = reference(target.authorization), .privileges = update },
                .delete => .{ .object = reference(target.authorization), .privileges = delete },
                .alter, .drop => .{ .object = reference(target.authorization), .access = .ownership },
                else => unreachable,
            };
        }
    }
    try result.validate();
    return result;
}

test "Table requirements distinguish namespace access, data and ownership" {
    const t = std.testing;
    const profile: Profile = .{ .database_domain = 1, .schema_domain = 2, .table_domain = 3, .database = 4, .initial_schema = 1, .initial_schema_authority = 5 };
    const scope: c.Model.Scope = .{ .realm = 1, .resource = 7, .catalog = 9 };
    const schema: Schema = .{ .scope = scope, .id = 1, .authorization = 5, .name = try Name.init("public"), .revision = 1 };
    const table: Table = .{ .id = 11, .schema = 1, .authorization = 6 };
    const subject: a.Subject = .{ .accepted = .{ .pid = 3, .input = 7, .principal = 17 } };
    const read = try guard(subject, profile, schema, table, .read);
    try t.expectEqual(connect, read.requirements[0].?.privileges);
    try t.expectEqual(usage, read.requirements[1].?.privileges);
    try t.expectEqual(select, read.requirements[2].?.privileges);
    const ddl = try guard(subject, profile, schema, table, .alter);
    try t.expectEqual(.ownership, ddl.requirements[2].?.access);
    const creation = try guard(subject, profile, schema, null, .create_table);
    try t.expectEqual(usage | create, creation.requirements[1].?.privileges);
    try t.expectEqual(null, creation.requirements[2]);
    try t.expectEqual(.visible, (try guard(subject, profile, schema, table, .inspect)).requirements[2].?.access);
    const first = try binding(scope, .table, 11);
    try t.expect(!std.mem.eql(u8, &first, &try binding(scope, .table, 12)));
    try t.expect(!std.mem.eql(u8, &first, &try binding(scope, .schema, 11)));
    var other = scope;
    other.catalog += 1;
    try t.expect(!std.mem.eql(u8, &first, &try binding(other, .table, 11)));
    const encoded = try c.Records.encode('S', schema);
    try t.expect(std.meta.eql(schema, try c.Records.decode(Schema, 'S', encoded)));
}
