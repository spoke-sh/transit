//! Typed declarations and mutations lower to the same frozen direct work as
//! SQL. Prepared definition identities never grant rights or select newer data.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const f = c.fuze;
const w = c.DirectTableProtocol;
const h = c.DirectTableValues;
const v = c.TableValues;
pub const Request = struct {
    definition: p.Growth.Definition,
    namespace: u64,
    operation: []const u8,
    name: []const u8,
    action: union(enum) {
        create: struct { schema: f.TableSchemaJson.Schema, if_not_exists: bool },
        alter: struct { basis: h.PreparedBinding, change: c.TableTyped.Change },
        rename: struct { basis: h.PreparedBinding, name: []const u8 },
        drop: struct { basis: ?h.PreparedBinding, if_exists: bool },
        mutate: struct { basis: h.PreparedBinding, mutation: c.TableTyped.Mutation, ingestion: c.storage.TablePartition.Ingestion },
    },
    fn basis(self: Request) ?h.PreparedBinding {
        return switch (self.action) {
            .create => null,
            inline else => |value| value.basis,
        };
    }
};
fn assertion(allocator: std.mem.Allocator, client: c.DirectTableClient, input: Request, operation: u64, expected: ?p.DataLifecycle.Definition) !c.DirectTablePreparedDdl.Write {
    const bytes = try p.Json.valueAlloc(allocator, input);
    defer allocator.free(bytes);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.table.direct.typed.conditional.v1\x00");
    hash.update(bytes);
    const binding: c.NameAssertion.Binding = .{ .definition = p.Growth.current_definition, .connection = client.connection, .operation = operation, .namespace = input.namespace, .name = try .init(input.name), .action = if (input.action == .create) .create_if_not_exists else .drop_if_exists, .expected = expected, .intent = hash.finalResult() };
    try binding.validate();
    return .{ .name_assertion = binding };
}
/// Read-only preparation returns independently owned work. Save it before
/// staging/admission; recovery loads these bytes instead of repeating preparation.
pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, input: Request) !c.DirectTablePreparedDdl.Write {
    if (input.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try client.connection.validate();
    try c.Model.nativeId(input.namespace);
    const operation = try v.unsigned(input.operation);
    if (operation == 0) return error.InvalidDataOperation;
    const name = try c.TableAuthority.Name.init(input.name);
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var ddl: w.Ddl = .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = operation }, .target = .{ .scope = client.connection.scope, .branch = client.connection.branch, .object = 0 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(0) }, .namespace = input.namespace, .name = input.name, .action = undefined };
    if (input.action == .create) {
        const create = input.action.create;
        const schema = try f.TableSchemaJson.native(&arena, create.schema);
        if (schema.revision != 1) return error.InvalidTableSchema;
        const subject = try client.require(.{ .namespace = input.namespace, .target = null, .access = .create_table });
        if (create.if_not_exists) {
            const response = try client.call(.{ .lookup = .{ .namespace = input.namespace, .name = input.name } });
            defer response.deinit();
            if (response.value.result.lookup) |existing| return assertion(allocator, client, input, operation, existing.interpretation.interpretation);
        }
        var bytes: [f.TableSchema.max_bytes]u8 = undefined;
        ddl.binding.target.object = schema.object;
        ddl.action = .{ .create = .{ .owner = subject.role, .schema = try .encode(a, try schema.encode(&bytes)) } };
    } else {
        const basis = if (input.basis()) |value| try value.native() else null;
        if (basis) |binding| if (!std.meta.eql(binding.connection, client.connection) or binding.namespace != input.namespace or !std.meta.eql(binding.name, name)) return error.CatalogIdentityConflict;
        const response = try client.call(.{ .lookup = .{ .namespace = input.namespace, .name = input.name } });
        defer response.deinit();
        const metadata = response.value.result.lookup;
        const original = basis orelse {
            if (metadata != null) return error.TableDefinitionChanged;
            if (input.action != .drop or !input.action.drop.if_exists) return error.TableNotFound;
            return assertion(allocator, client, input, operation, null);
        };
        const current = metadata orelse return error.TableNotFound;
        try original.check(client.connection, current);
        const right: c.TableAuthority.Access = switch (input.action) {
            .alter, .rename => .alter,
            .drop => .drop,
            .mutate => |value| switch (value.mutation.action) {
                .insert => .insert,
                .update => .update,
                .delete => .delete,
            },
            .create => unreachable,
        };
        _ = try original.require(client, right);
        var schema = try f.TableSchema.decode(allocator, try current.schema.decode(a, f.TableSchema.max_bytes));
        defer schema.deinit();
        if (input.action == .mutate) {
            const plan = try c.TableTyped.plan(&arena, schema.schema, input.name, input.action.mutate.mutation);
            var intent = try c.DirectTableIntent.fromDml(allocator, client.connection, current, operation, plan, input.action.mutate.ingestion);
            errdefer intent.deinit();
            _ = try original.require(client, right);
            return .{ .table = intent };
        }
        ddl.binding.target = original.interpretation.interpretation.object;
        ddl.binding.expected_definition = original.interpretation.interpretation;
        switch (input.action) {
            .alter => |value| {
                ddl.binding.action = .alter;
                ddl.action = .{ .alter = try c.DirectTablePreparedDdl.encodeChange(a, try c.TableTyped.change(&arena, schema.schema, value.change), schema.schema) };
            },
            .rename => |value| {
                _ = try c.TableAuthority.Name.init(value.name);
                ddl.binding.action = .rename;
                ddl.action = .{ .rename = value.name };
            },
            .drop => {
                ddl.binding.action = .drop;
                ddl.action = .drop;
            },
            .create, .mutate => unreachable,
        }
    }
    ddl.binding.intent = try ddl.digest(a);
    return .{ .table = try c.DirectTableIntent.create(allocator, client.connection, .{ .ddl = ddl }) };
}
