//! Shared read-only DDL preparation. Binding freezes one direct Table operation
//! or conditional name assertion; admission and recovery remain explicit.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const w = c.DirectTableProtocol;
const Self = @This();

connection: w.Connection,
namespace: u64,
compiled: f.TableDdl.Owned,
definition: ?c.DirectTableBinding,
schema: ?f.TableSchema.Owned,
conditional_intent: [32]u8,

pub const Write = union(enum) {
    table: c.DirectTableIntent,
    name_assertion: c.NameAssertion.Binding,
    pub fn deinit(self: *Write) void {
        if (self.* == .table) self.table.deinit();
        self.* = undefined;
    }
};

pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const target = try f.TableDdl.targetDialect(arena.allocator(), text, location, dialect);
    var definition: ?c.DirectTableBinding = null;
    var schema: ?f.TableSchema.Owned = null;
    errdefer if (schema) |*value| value.deinit();
    if (target.kind != .create) {
        const response = try client.call(.{ .lookup = .{ .namespace = namespace, .name = target.name } });
        defer response.deinit();
        if (response.value.result.lookup) |metadata| {
            definition = try c.DirectTableBinding.init(client.connection, metadata);
            schema = try f.TableSchema.decode(allocator, try metadata.schema.decode(arena.allocator(), f.TableSchema.max_bytes));
        }
    }
    var compiled = try f.TableDdl.compileDialect(allocator, text, if (schema) |value| value.schema else null, location, dialect);
    errdefer compiled.deinit();
    if (target.kind == .create) {
        _ = try client.require(.{ .namespace = namespace, .target = null, .access = .create_table });
    } else if (definition) |value| {
        _ = try value.require(client, if (target.kind == .alter) .alter else .drop);
    }
    // Preserve every proposed clause even when an existing name makes CREATE
    // IF NOT EXISTS a conditional no-op. This is the shared SQL intent domain.
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.sql.conditional.name.v1\x00");
    hash.update(@tagName(dialect));
    hash.update("\x00");
    hash.update(text);
    return .{ .connection = client.connection, .namespace = namespace, .compiled = compiled, .definition = definition, .schema = schema, .conditional_intent = hash.finalResult() };
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
        if (self.compiled.statement != .drop) return error.TableNotFound;
        const response = try client.call(.{ .lookup = .{ .namespace = self.namespace, .name = self.compiled.statement.drop.name } });
        defer response.deinit();
        if (response.value.result.lookup != null) return error.TableDefinitionChanged;
    }
}

fn assertion(self: *const Self, operation: u64, name: []const u8, expected: ?c.protocol.DataLifecycle.Definition) !Write {
    const value: c.NameAssertion.Binding = .{ .definition = c.protocol.Growth.current_definition, .connection = self.connection, .operation = operation, .namespace = self.namespace, .name = try .init(name), .action = if (expected != null) .create_if_not_exists else .drop_if_exists, .expected = expected, .intent = self.conditional_intent };
    try value.validate();
    return .{ .name_assertion = value };
}

/// CREATE requires an explicit new object ID. Other forms require null. The
/// operation ID is independent; neither binding nor loading admits that work.
pub fn bind(self: *const Self, allocator: std.mem.Allocator, client: c.DirectTableClient, operation: u64, create_object: ?u64) !Write {
    if (operation == 0) return error.InvalidDataOperation;
    if ((self.compiled.statement == .create) != (create_object != null)) return error.InvalidTableIntent;
    if (create_object) |object| if (object == 0) return error.InvalidDataIdentity;
    try self.validate(client);
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var ddl: w.Ddl = .{ .binding = .{ .definition = c.protocol.Growth.current_definition, .identity = .{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = operation }, .target = .{ .scope = self.connection.scope, .branch = self.connection.branch, .object = create_object orelse 0 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(0) }, .namespace = self.namespace, .name = undefined, .action = undefined };
    switch (self.compiled.statement) {
        .create => |create| {
            if (create.if_not_exists) {
                const response = try client.call(.{ .lookup = .{ .namespace = self.namespace, .name = create.name } });
                defer response.deinit();
                if (response.value.result.lookup) |existing| return self.assertion(operation, create.name, existing.interpretation.interpretation);
            }
            const subject = try client.require(.{ .namespace = self.namespace, .target = null, .access = .create_table });
            var buffer: [f.TableSchema.max_bytes]u8 = undefined;
            ddl.name = create.name;
            ddl.action = .{ .create = .{ .owner = subject.role, .schema = try .encode(a, try (try create.bind(create_object.?)).encode(&buffer)) } };
        },
        .alter, .drop => {
            const definition = self.definition orelse {
                if (self.compiled.statement == .drop and self.compiled.statement.drop.if_exists) return self.assertion(operation, self.compiled.statement.drop.name, null);
                return error.TableNotFound;
            };
            ddl.binding.target = definition.interpretation.interpretation.object;
            ddl.binding.expected_definition = definition.interpretation.interpretation;
            ddl.name = definition.name.slice();
            switch (self.compiled.statement) {
                .alter => |alter| switch (alter.action) {
                    .columns => |change| {
                        ddl.binding.action = .alter;
                        ddl.action = .{ .alter = try wireChange(a, change, self.schema.?.schema) };
                    },
                    .rename_table => |name| {
                        ddl.binding.action = .rename;
                        ddl.action = .{ .rename = name };
                    },
                },
                .drop => {
                    ddl.binding.action = .drop;
                    ddl.action = .drop;
                },
                .create => unreachable,
            }
        },
    }
    ddl.binding.intent = try ddl.digest(a);
    return .{ .table = try c.DirectTableIntent.create(allocator, self.connection, .{ .ddl = ddl }) };
}

fn wireCell(allocator: std.mem.Allocator, value: ?f.Types.Values.Cell, logical_type: f.Types.Type) !?c.DirectTableProtocol.Binary {
    const cell = value orelse return null;
    const output = try allocator.alloc(u8, f.TableSchema.max_bytes);
    defer allocator.free(output);
    return try c.DirectTableProtocol.Binary.encode(allocator, try f.Types.Codec.encode(cell, .{ .name = "", .type = logical_type, .nullable = true }, output));
}
fn wireChange(allocator: std.mem.Allocator, change: f.TableEvolution.Change, schema: f.TableSchema.Schema) !c.DirectTableProtocol.Change {
    return switch (change) {
        .add => |v| .{ .add = .{ .name = v.name, .type = v.type, .nullable = v.nullable, .default = try wireCell(allocator, v.default, v.type), .max_characters = v.max_characters, .encoding = v.encoding, .collation = v.collation } },
        .drop => |v| .{ .drop = v },
        .rename => |v| .{ .rename = .{ .column = v.column, .name = v.name } },
        .default => |v| .{ .default = .{ .column = v.column, .value = try wireCell(allocator, v.value, schema.columns[try schema.index(v.column)].type) } },
        .nullable => |v| .{ .nullable = .{ .column = v.column, .value = v.value } },
        .type => |v| .{ .type = .{ .column = v.column, .type = v.type, .max_characters = v.max_characters } },
        .physical => |v| .{ .physical = .{ .column = v.column, .encoding = v.encoding, .collation = v.collation } },
    };
}
