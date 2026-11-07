//! Shared read-only Document collection DDL preparation. Binding freezes one direct
//! Document declaration operation or conditional name assertion; admission and recovery remain explicit.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const w = c.DirectTableProtocol;
const Self = @This();

connection: w.Connection,
namespace: u64,
compiled: f.DocumentDdl.Owned,
definition: ?c.DirectTableBinding,
policy: ?f.DocumentDdl.Policy,
schema: ?f.TableSchema.Owned,
conditional_intent: [32]u8,
create_owner: ?u64 = null,

pub const Write = union(enum) {
    document: c.DirectDocumentIntent,
    name_assertion: c.NameAssertion.Binding,
    pub fn deinit(self: *Write) void {
        if (self.* == .document) self.document.deinit();
        self.* = undefined;
    }
};

pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const target = try f.DocumentDdl.targetDialect(arena.allocator(), text, location, dialect);
    var definition: ?c.DirectTableBinding = null;
    var doc_policy: ?f.DocumentDdl.Policy = null;
    var schema: ?f.TableSchema.Owned = null;
    errdefer if (schema) |*value| value.deinit();
    if (target.kind != .create) {
        const response = try client.call(.{ .document_lookup = .{ .namespace = namespace, .name = target.name } });
        defer response.deinit();
        if (response.value.result.document_lookup) |metadata| {
            definition = try c.DirectTableBinding.init(client.connection, metadata.definition);
            doc_policy = metadata.policy;
            schema = try f.TableSchema.decode(allocator, try metadata.definition.schema.decode(arena.allocator(), f.TableSchema.max_bytes));
        }
    }
    const basis: ?f.DocumentDdl.Basis = if (schema) |value| .{ .schema = value.schema, .policy = doc_policy.? } else null;
    var compiled = try f.DocumentDdl.compileDialect(allocator, text, basis, location, dialect);
    errdefer compiled.deinit();
    var create_owner: ?u64 = null;
    if (target.kind == .create) {
        create_owner = (try client.require(.{ .namespace = namespace, .target = null, .access = .create_table })).role;
    } else if (definition) |value| {
        _ = try value.require(client, if (target.kind == .alter) .alter else .drop);
    }
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.sql.conditional.document.name.v1\x00");
    hash.update(@tagName(dialect));
    hash.update("\x00");
    hash.update(text);
    return .{
        .connection = client.connection,
        .namespace = namespace,
        .compiled = compiled,
        .definition = definition,
        .policy = doc_policy,
        .schema = schema,
        .conditional_intent = hash.finalResult(),
        .create_owner = create_owner,
    };
}

pub fn deinit(self: *Self) void {
    self.compiled.deinit();
    if (self.schema) |*value| value.deinit();
    self.* = undefined;
}

pub fn validate(self: *const Self, client: c.DirectTableClient) !void {
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    if (self.compiled.statement == .create) {
        _ = try client.require(.{ .namespace = self.namespace, .target = null, .access = .create_table });
    } else if (self.definition) |definition| {
        _ = try definition.require(client, if (self.compiled.statement == .alter) .alter else .drop);
    } else {
        if (self.compiled.statement != .drop) return error.DocumentNotFound;
        const response = try client.call(.{ .document_lookup = .{ .namespace = self.namespace, .name = self.compiled.statement.drop.name } });
        defer response.deinit();
        if (response.value.result.document_lookup != null) return error.TableDefinitionChanged;
    }
}

fn assertion(self: *const Self, operation: u64, name: []const u8, expected: ?c.protocol.DataLifecycle.Definition) !Write {
    const value: c.NameAssertion.Binding = .{
        .definition = c.protocol.Growth.current_definition,
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

pub fn bind(self: *const Self, allocator: std.mem.Allocator, client: c.DirectTableClient, operation: u64, create_object: ?u64) !Write {
    return self.bindPrepared(allocator, client, operation, create_object, false);
}

pub fn bindPrepared(self: *const Self, allocator: std.mem.Allocator, client: c.DirectTableClient, operation: u64, create_object: ?u64, fresh_prepared: bool) !Write {
    if (operation == 0) return error.InvalidDataOperation;
    if ((self.compiled.statement == .create) != (create_object != null)) return error.InvalidDirectCatalogOperation;
    if (create_object) |object| if (object == 0) return error.InvalidDataIdentity;
    if (self.compiled.statement != .create and !fresh_prepared) try self.validate(client) else if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var ddl: w.Ddl = .{
        .binding = .{
            .definition = c.protocol.Growth.current_definition,
            .identity = .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = operation },
            .target = .{ .scope = self.connection.scope, .branch = self.connection.branch, .object = create_object orelse 0 },
            .action = .create,
            .expected_definition = null,
            .expected_data = null,
            .intent = @splat(0),
        },
        .namespace = self.namespace,
        .name = undefined,
        .action = undefined,
    };
    var selected_policy: f.DocumentDdl.Policy = .{};
    switch (self.compiled.statement) {
        .create => |create| {
            const owner_role = if (fresh_prepared and self.create_owner != null) self.create_owner.? else (try client.require(.{ .namespace = self.namespace, .target = null, .access = .create_table })).role;
            if (create.table.if_not_exists) {
                const response = try client.call(.{ .document_lookup = .{ .namespace = self.namespace, .name = create.table.name } });
                defer response.deinit();
                if (response.value.result.document_lookup) |existing| return self.assertion(operation, create.table.name, existing.definition.interpretation.interpretation);
            }
            var buffer: [f.TableSchema.max_bytes]u8 = undefined;
            ddl.name = create.table.name;
            ddl.action = .{ .create = .{ .owner = owner_role, .schema = try .encode(a, try (try create.bind(create_object.?)).encode(&buffer)) } };
            selected_policy = create.policy;
        },
        .alter, .drop => {
            const definition = self.definition orelse {
                if (self.compiled.statement == .drop and self.compiled.statement.drop.if_exists) return self.assertion(operation, self.compiled.statement.drop.name, null);
                return error.DocumentNotFound;
            };
            ddl.binding.target = definition.interpretation.interpretation.object;
            ddl.binding.expected_definition = definition.interpretation.interpretation;
            ddl.name = definition.name.slice();
            switch (self.compiled.statement) {
                .alter => |alter| {
                    selected_policy = alter.policy;
                    switch (alter.table.action) {
                        .columns => |change| {
                            ddl.binding.action = .alter;
                            ddl.action = .{ .alter = try c.DirectTablePreparedDdl.encodeChange(a, change, self.schema.?.schema) };
                        },
                        .rename_table => |name| {
                            ddl.binding.action = .rename;
                            ddl.action = .{ .rename = name };
                        },
                    }
                },
                .drop => {
                    selected_policy = self.policy.?;
                    ddl.binding.action = .drop;
                    ddl.action = .drop;
                },
                .create => unreachable,
            }
        },
    }
    var decl: c.DirectDocument.Declaration = .{ .ddl = ddl, .policy = selected_policy };
    decl.ddl.binding.intent = try decl.digest(a);
    const preview = try client.call(.{ .document_declaration = .{ .declaration = decl, .command = .preview, .steps = 1 } });
    defer preview.deinit();
    if (preview.value.result.document_declaration.preview.reason == .stale_definition) return error.TableDefinitionChanged;
    return .{ .document = try c.DirectDocumentIntent.create(allocator, self.connection, self.namespace, decl) };
}
