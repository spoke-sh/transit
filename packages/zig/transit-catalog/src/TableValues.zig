//! Language-neutral general Table values. Native authority and validation stay
//! with their domain owners; every returned string belongs to the caller arena.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const m = c.Model;
const f = c.fuze;
const Allocator = std.mem.Allocator;
pub const Schema = f.TableSchemaJson.Schema;
pub fn unsigned(text: []const u8) !u64 {
    if (text.len == 0 or text.len > 20 or (text.len > 1 and text[0] == '0')) return error.InvalidCatalogInteger;
    for (text) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidCatalogInteger;
    return std.fmt.parseInt(u64, text, 10) catch error.InvalidCatalogInteger;
}
pub fn decimal(allocator: Allocator, value: u64) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}
pub fn hex(allocator: Allocator, bytes: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, try std.math.mul(usize, bytes.len, 2));
    const alphabet = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        result[2 * i] = alphabet[byte >> 4];
        result[2 * i + 1] = alphabet[byte & 15];
    }
    return result;
}
pub fn unhex(allocator: Allocator, text: []const u8, max_bytes: usize) ![]u8 {
    if (text.len % 2 != 0 or text.len / 2 > max_bytes) return error.InvalidTableIntent;
    for (text) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return error.InvalidTableIntent;
    const result = try allocator.alloc(u8, text.len / 2);
    errdefer allocator.free(result);
    _ = std.fmt.hexToBytes(result, text) catch return error.InvalidTableIntent;
    return result;
}
pub fn digest(text: []const u8) ![32]u8 {
    if (text.len != 64) return error.CatalogIdentityConflict;
    for (text) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return error.CatalogIdentityConflict;
    var result: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&result, text) catch return error.CatalogIdentityConflict;
    return result;
}
pub const Scope = struct {
    realm: u64,
    resource: u64,
    catalog: []const u8,
    pub fn native(self: Scope) !m.Scope {
        const value: m.Scope = .{ .realm = self.realm, .resource = self.resource, .catalog = try unsigned(self.catalog) };
        try value.validate();
        return value;
    }
    pub fn foreign(allocator: Allocator, value: m.Scope) !Scope {
        try value.validate();
        return .{ .realm = value.realm, .resource = value.resource, .catalog = try decimal(allocator, value.catalog) };
    }
};
pub const PublicationLimits = struct {
    record_bytes: u32,
    staging_bytes: []const u8,
    staging_records: u32,
    pub fn native(self: PublicationLimits) !c.protocol.DataLifecycle.PublicationLimits {
        const value: c.protocol.DataLifecycle.PublicationLimits = .{ .record_bytes = self.record_bytes, .staging_bytes = try unsigned(self.staging_bytes), .staging_records = self.staging_records };
        try value.validate();
        return value;
    }
};
pub const Namespace = struct {
    scope: Scope,
    id: u64,
    authorization: u64,
    name: []const u8,
    revision: u64,
    retired: bool,
    pub fn foreign(allocator: Allocator, value: c.TableAuthority.Schema) !Namespace {
        try value.validate();
        return .{ .scope = try Scope.foreign(allocator, value.scope), .id = value.id, .authorization = value.authorization, .name = try allocator.dupe(u8, value.name.slice()), .revision = value.revision, .retired = value.retired };
    }
};
pub const SchemaRequest = struct {
    scope: Scope,
    principal: u64,
    operation: u64,
    schema: u64,
    expected_revision: u64,
    action: union(enum) { create: struct { name: []const u8, owner: u64 }, rename: []const u8, drop },
    pub fn native(self: SchemaRequest) !c.SchemaCommand {
        const value: c.SchemaCommand = .{ .scope = try self.scope.native(), .principal = self.principal, .operation = self.operation, .schema = self.schema, .expected_revision = self.expected_revision, .action = switch (self.action) {
            .create => |creation| .{ .create = .{ .name = try .init(creation.name), .owner = creation.owner } },
            .rename => |name| .{ .rename = try .init(name) },
            .drop => .drop,
        } };
        try value.validate();
        return value;
    }
    pub fn foreign(allocator: Allocator, value: c.SchemaCommand) !SchemaRequest {
        try value.validate();
        return .{ .scope = try Scope.foreign(allocator, value.scope), .principal = value.principal, .operation = value.operation, .schema = value.schema, .expected_revision = value.expected_revision, .action = switch (value.action) {
            .create => |creation| .{ .create = .{ .name = try allocator.dupe(u8, creation.name.slice()), .owner = creation.owner } },
            .rename => |name| .{ .rename = try allocator.dupe(u8, name.slice()) },
            .drop => .drop,
        } };
    }
};
pub const AuthorizationPlan = struct {
    definition: c.protocol.Growth.Definition,
    scope: Scope,
    principal: u64,
    role: u64,
    expected_revision: u64,
    action: union(enum) { authorization: c.protocol.Authorization.Action, schema: SchemaRequest, set_role: ?u64 },
    pub fn native(self: AuthorizationPlan) !c.AuthorizationLowering.Plan {
        const plan: c.AuthorizationLowering.Plan = .{ .definition = self.definition, .scope = try self.scope.native(), .principal = self.principal, .role = self.role, .expected_revision = self.expected_revision, .action = switch (self.action) {
            .authorization => |value| .{ .authorization = value },
            .schema => |value| .{ .schema = try value.native() },
            .set_role => |value| .{ .set_role = value },
        } };
        try plan.validate();
        return plan;
    }
    pub fn foreign(allocator: Allocator, value: c.AuthorizationLowering.Plan) !AuthorizationPlan {
        try value.validate();
        return .{ .definition = value.definition, .scope = try Scope.foreign(allocator, value.scope), .principal = value.principal, .role = value.role, .expected_revision = value.expected_revision, .action = switch (value.action) {
            .authorization => |action| .{ .authorization = action },
            .schema => |action| .{ .schema = try SchemaRequest.foreign(allocator, action) },
            .set_role => |action| .{ .set_role = action },
        } };
    }
};
pub const Counts = struct { matched: []const u8, changed: []const u8 };
