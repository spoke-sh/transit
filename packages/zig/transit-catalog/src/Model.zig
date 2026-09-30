//! Owned catalog identities. Native IDs, object IDs, definition revisions and
//! operation IDs remain distinct; a name never supplies a capability.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const m = c.fuze.model;
pub const Scope = struct {
    realm: u64,
    resource: u64,
    catalog: u64,
    pub fn validate(self: Scope) !void {
        try nativeId(self.realm);
        try nativeId(self.resource);
        if (self.catalog == 0) return error.InvalidCatalogIdentity;
    }
};
pub const Configuration = struct {
    scope: Scope,
    owner: u64,
    administrator: u64,
    pub fn validate(self: Configuration) !void {
        try self.scope.validate();
        try nativeId(self.owner);
        try nativeId(self.administrator);
    }
};
pub const Policy = struct {
    scope: Scope,
    principal: u64,
    revision: u64,
    inspect: bool,
    create: bool,
    pub fn validate(self: Policy) !void {
        try self.scope.validate();
        if (self.principal > p.max_counter or self.revision == 0) return error.InvalidCatalogPolicy;
    }
};
pub const CreateTable = struct {
    scope: Scope,
    operation: u64,
    object: u64,
    table: u32,
    name: m.Name,
    schema: m.Schema,
    pub fn validate(self: CreateTable) !void {
        try self.scope.validate();
        if (self.operation == 0 or self.object == 0 or self.table == 0) return error.InvalidCatalogIdentity;
        try validName(self.name);
        try self.schema.validate();
    }
    pub fn compile(scope: Scope, operation: u64, object: u64, table: u32, sql: []const u8) !CreateTable {
        const declaration = try c.fuze.Declaration.compile(sql);
        const result: CreateTable = .{ .scope = scope, .operation = operation, .object = object, .table = table, .name = declaration.name, .schema = try declaration.tableSchema() };
        try result.validate();
        return result;
    }
};
pub const Definition = struct {
    scope: Scope,
    object: u64,
    revision: u64,
    name: m.Name,
    source: union(enum(u8)) { table: struct { id: u32, schema: m.Schema } = 1 },
    principal: u64,
    operation: u64,
    input: u64,
    /// Column IDs are scoped by object, independent of names and physical IDs.
    pub const ColumnId = enum(u8) { key = 1, value = 2 };
    pub fn validate(self: Definition) !void {
        try self.scope.validate();
        if (self.object == 0 or self.revision == 0 or self.operation == 0 or self.principal > p.max_counter) return error.InvalidCatalogDefinition;
        try nativeId(self.input);
        try validName(self.name);
        switch (self.source) {
            .table => |table| {
                if (table.id == 0) return error.InvalidTableId;
                try table.schema.validate();
            },
        }
    }
    pub fn created(request: CreateTable, principal: u64, input: u64) !Definition {
        try request.validate();
        const result: Definition = .{ .scope = request.scope, .object = request.object, .revision = 1, .name = request.name, .source = .{ .table = .{ .id = request.table, .schema = request.schema } }, .principal = principal, .operation = request.operation, .input = input };
        try result.validate();
        return result;
    }
    pub fn digest(self: Definition) ![32]u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.definition.v1\x00");
        hash.update((try c.Records.encode('d', self)).slice());
        return hash.finalResult();
    }
};
pub const Binding = struct {
    scope: Scope,
    object: u64,
    revision: u64,
    digest: [32]u8,
    pub fn validate(self: Binding) !void {
        try self.scope.validate();
        if (self.object == 0 or self.revision == 0) return error.InvalidCatalogBinding;
    }
};
pub const Outcome = enum(u8) { applied = 1, name_conflict = 2, object_conflict = 3, table_conflict = 4 };
pub const Receipt = struct {
    request: CreateTable,
    principal: u64,
    input: u64,
    outcome: Outcome,
    pub fn validate(self: Receipt) !void {
        try self.request.validate();
        if (self.principal > p.max_counter) return error.InvalidCatalogIdentity;
        try nativeId(self.input);
    }
};
pub fn nativeId(id: u64) !void {
    if (id == 0 or id > p.max_counter) return error.InvalidCatalogIdentity;
}
pub fn validName(name: m.Name) !void {
    if (name.len > name.bytes.len or !std.meta.eql(name, try m.Name.init(name.slice()))) return error.InvalidColumnName;
}
