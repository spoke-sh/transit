//! Shared KV SQL DDL preparation and immutable declaration binding.
//! Preparation reads current metadata; native preview checks declaration rights
//! before staging. Token acceptance and reconciliation use DirectKVIntent or NameAssertion.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const p = c.protocol;
const s = c.storage;
const Self = @This();

connection: c.DirectTableProtocol.Connection,
namespace: u64,
compiled: f.KVDdl.Owned,
definition: ?c.DirectKV.Definition,
conditional_intent: [32]u8,
create_owner: ?u64,

pub const Write = union(enum) {
    kv: c.DirectKVIntent,
    name_assertion: c.NameAssertion.Binding,
    pub fn deinit(self: *Write) void {
        if (self.* == .kv) self.kv.deinit();
        self.* = undefined;
    }
};

fn storageSpec(spec: f.KVDdl.Spec) s.KVDeclaration.Spec {
    return .{
        .value_type = switch (spec.value_type) {
            .int64 => .int64,
            .boolean => .boolean,
            .utf8 => .utf8,
            .binary => .binary,
        },
        .nullable = spec.nullable,
    };
}

pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    var compiled = try f.KVDdl.compile(allocator, text, dialect, location);
    errdefer compiled.deinit();
    var definition: ?c.DirectKV.Definition = null;
    var create_owner: ?u64 = null;
    const syntax = compiled.statement;
    if (syntax.action == .create) {
        create_owner = (try client.require(.{ .namespace = namespace, .target = null, .access = .create_table })).role;
    } else {
        const response = try client.call(.{ .kv_lookup = .{ .namespace = namespace, .name = syntax.name } });
        defer response.deinit();
        if (response.value.result.kv_lookup) |found| {
            definition = found;
        } else if (syntax.action != .drop or !syntax.action.drop.if_exists) {
            return error.CatalogNameNotFound;
        }
    }
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.sql.conditional.kv.name.v1\x00");
    hash.update(@tagName(dialect));
    hash.update("\x00");
    hash.update(text);
    return .{
        .connection = client.connection,
        .namespace = namespace,
        .compiled = compiled,
        .definition = definition,
        .conditional_intent = hash.finalResult(),
        .create_owner = create_owner,
    };
}

pub fn deinit(self: *Self) void {
    self.compiled.deinit();
    self.* = undefined;
}

pub fn validate(self: *const Self, client: c.DirectTableClient) !void {
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    const syntax = self.compiled.statement;
    if (syntax.action == .create) {
        _ = try client.require(.{ .namespace = self.namespace, .target = null, .access = .create_table });
    } else if (self.definition) |expected| {
        const response = try client.call(.{ .kv = .{ .observe = expected.interpretation.interpretation.object } });
        defer response.deinit();
        const observed = response.value.result.kv.definition;
        if (observed.retired or !std.meta.eql(observed.interpretation, expected.interpretation)) return error.CatalogDefinitionChanged;
    } else {
        if (syntax.action != .drop or !syntax.action.drop.if_exists) return error.CatalogNameNotFound;
        const response = try client.call(.{ .kv_lookup = .{ .namespace = self.namespace, .name = syntax.name } });
        defer response.deinit();
        if (response.value.result.kv_lookup != null) return error.CatalogDefinitionChanged;
    }
}

fn assertion(self: *const Self, operation: u64, name: []const u8, expected: ?p.DataLifecycle.Definition) !Write {
    const value: c.NameAssertion.Binding = .{
        .definition = p.Growth.current_definition,
        .connection = self.connection,
        .operation = operation,
        .namespace = self.namespace,
        .name = try .init(name),
        .action = if (expected != null) .create_if_not_exists else .drop_if_exists,
        .expected = expected,
        .intent = self.conditional_intent,
    };
    try value.validate();
    return .{ .name_assertion = value };
}

pub fn bindPrepared(self: *const Self, allocator: std.mem.Allocator, client: c.DirectTableClient, operation: u64, fresh: bool) !Write {
    if (!fresh) try self.validate(client) else if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    if (operation == 0 or operation > p.max_counter) return error.InvalidDataOperation;
    const syntax = self.compiled.statement;
    switch (syntax.action) {
        .create => |create| {
            const owner_role = if (fresh and self.create_owner != null) self.create_owner.? else (try client.require(.{ .namespace = self.namespace, .target = null, .access = .create_table })).role;
            if (create.if_not_exists) {
                const response = try client.call(.{ .kv_lookup = .{ .namespace = self.namespace, .name = syntax.name } });
                defer response.deinit();
                if (response.value.result.kv_lookup) |existing| return self.assertion(operation, syntax.name, existing.interpretation.interpretation);
            }
            const object: p.DataLifecycle.Object = .{ .scope = self.connection.scope, .branch = self.connection.branch, .object = operation };
            const decl = try c.DirectKVClient.prepareDeclaration(allocator, .{
                .binding = .{
                    .definition = p.Growth.current_definition,
                    .identity = .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = operation },
                    .target = object,
                    .action = .create,
                    .expected_definition = null,
                    .expected_data = null,
                    .intent = @splat(0),
                },
                .namespace = self.namespace,
                .name = try .init(syntax.name),
                .action = .{ .create = .{ .owner = owner_role, .spec = storageSpec(create.spec) } },
            });
            const preview = try client.call(.{ .kv_declaration = .{ .declaration = decl, .command = .preview, .steps = 1 } });
            defer preview.deinit();
            if (preview.value.result.kv_declaration.preview.reason == .stale_definition) return error.CatalogDefinitionChanged;
            return .{ .kv = try c.DirectKVIntent.create(allocator, self.connection, self.namespace, .{ .ddl = decl }) };
        },
        .rename, .drop => {
            const definition = self.definition orelse {
                if (syntax.action == .drop and syntax.action.drop.if_exists) return self.assertion(operation, syntax.name, null);
                return error.CatalogNameNotFound;
            };
            const decl = try c.DirectKVClient.prepareDeclaration(allocator, .{
                .binding = .{
                    .definition = p.Growth.current_definition,
                    .identity = .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = operation },
                    .target = definition.interpretation.interpretation.object,
                    .action = if (syntax.action == .rename) .rename else .drop,
                    .expected_definition = definition.interpretation.interpretation,
                    .expected_data = null,
                    .intent = @splat(0),
                },
                .namespace = self.namespace,
                .name = definition.name,
                .action = switch (syntax.action) {
                    .rename => |new_name| .{ .rename = try .init(new_name) },
                    .drop => .drop,
                    .create => unreachable,
                },
            });
            const preview = try client.call(.{ .kv_declaration = .{ .declaration = decl, .command = .preview, .steps = 1 } });
            defer preview.deinit();
            if (preview.value.result.kv_declaration.preview.reason == .stale_definition) return error.CatalogDefinitionChanged;
            return .{ .kv = try c.DirectKVIntent.create(allocator, self.connection, self.namespace, .{ .ddl = decl }) };
        },
    }
}
