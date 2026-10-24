//! Gateway statement lifetime over shared metadata-only compilers. Preparation
//! owns immutable metadata; execution opens a new authorized cut or typed intent.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const q = g.query;
const f = g.fuze;
const Self = @This();
allocator: std.mem.Allocator,
text: []const u8,
connection: c.DirectTableProtocol.Connection,
namespace: u64,
dialect: f.Sql.Dialect,
plan: union(enum) { select: q.DirectTablePrepared, dml: c.DirectTablePreparedDml, create: f.TableDdl.Owned, ddl: Ddl, relational: *q.DirectRelationalCompilation, namespace_change: c.DirectAuthorizationSql.NamespacePlan },
output: ?f.Types.Decoded,
const Ddl = struct {
    compiled: f.TableDdl.Owned,
    definition: ?c.DirectTableBinding,
    schema: ?f.TableSchema.Owned,
    fn deinit(self: *Ddl) void {
        self.compiled.deinit();
        if (self.schema) |*value| value.deinit();
    }
};
pub const Kind = enum { select, insert, update, delete, create, alter, drop };
pub fn kind(self: *const Self) Kind {
    return switch (self.plan) {
        .select, .relational => .select,
        .create => .create,
        .ddl => |value| if (value.compiled.statement == .alter) .alter else .drop,
        .namespace_change => |value| switch (value.action) {
            .create => .create,
            .rename => .alter,
            .drop => .drop,
        },
        .dml => |value| switch (value.template.syntax.subject.kind) {
            .insert => .insert,
            .update => .update,
            .delete => .delete,
        },
    };
}
pub fn deinit(self: *Self) void {
    if (self.output) |*output| output.deinit();
    switch (self.plan) {
        .relational => |value| value.deinit(),
        inline else => |*value| value.deinit(),
    }
    self.allocator.free(self.text);
    self.* = undefined;
}
pub fn parameters(self: *const Self) []const f.Types.Type {
    return switch (self.plan) {
        .select => |*value| value.parameterTypes(),
        .dml => |*value| value.parameterTypes(),
        else => &.{},
    };
}
pub fn fields(self: *const Self) []const f.Types.Field {
    return if (self.output) |output| output.type.structure else &.{};
}
/// Bind-time validation has no native input, upload or snapshot. Actual
/// execution independently rechecks rights and immutable source identity.
pub fn checkValues(self: *const Self, allocator: std.mem.Allocator, values: []const ?f.Types.Values.Atom) !void {
    if (values.len != self.parameters().len) return error.WireParameterCountMismatch;
    switch (self.plan) {
        .select => |*value| {
            const template = &value.template;
            var bound = try template.bind(allocator, template.name, template.descriptor.type, template.basis, values, null);
            defer bound.deinit();
        },
        .dml => |*value| {
            const template = &value.template;
            var bound = try template.bind(allocator, template.name, template.schema.schema, values, null);
            defer bound.deinit();
        },
        else => {},
    }
}
/// This profile routes every relational target through the selected database's
/// explicit catalog connection. SQL names never select another configured account.
pub const Profile = enum { native, wire };
pub fn prepare(allocator: std.mem.Allocator, client: *c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, profile: Profile, options: q.RelationalQuery.Options) !Self {
    return prepareDiagnostic(allocator, client, namespace, text, dialect, profile, options, null);
}
pub fn prepareDiagnostic(allocator: std.mem.Allocator, client: *c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, profile: Profile, options: q.RelationalQuery.Options, detail: ?*f.Sql.Binding) !Self {
    if (detail) |value| value.* = .{};
    var location: f.Sql.Location = .{};
    return prepareInner(allocator, client, namespace, text, dialect, profile, options, detail, &location) catch |err| {
        if (detail) |value| if (value.location == null and (location.offset != 0 or location.expected != null)) {
            value.location = location;
        };
        return err;
    };
}
fn prepareInner(allocator: std.mem.Allocator, client: *c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, profile: Profile, options: q.RelationalQuery.Options, detail: ?*f.Sql.Binding, location: *f.Sql.Location) !Self {
    try f.Sql.validateText(text);
    var lexer: f.Sql.Lexer = .{ .text = text, .dialect = dialect, .parameters_enabled = true };
    const first = try lexer.next();
    if (first.tag != .word) return error.UnsupportedGatewayStatement;
    const owned = try allocator.dupe(u8, text);
    errdefer allocator.free(owned);
    var plan: @FieldType(Self, "plan") = undefined;
    var declaration = lexer;
    const namespace_change = (std.ascii.eqlIgnoreCase(first.text, "CREATE") or std.ascii.eqlIgnoreCase(first.text, "ALTER") or std.ascii.eqlIgnoreCase(first.text, "DROP")) and tokenIs(try declaration.next(), "SCHEMA");
    if (namespace_change) {
        if (profile != .native) return error.UnsupportedGatewayStatement;
        plan = .{ .namespace_change = try c.DirectAuthorizationSql.prepareNamespace(client.*, namespace, text, .{}, location) };
    } else if (std.ascii.eqlIgnoreCase(first.text, "SELECT")) {
        // Parameterized relational syntax is outside this profile. Parameter
        // tokens belong to the shared single-Table compiler; strings/comments
        // containing their spelling never change routing.
        var parameterized = false;
        while (true) {
            const token = try lexer.next();
            if (token.tag == .eof) break;
            if (token.tag == .integer and token.text.len != 0 and (token.text[0] == '$' or token.text[0] == '?')) parameterized = true;
        }
        if (!parameterized and try f.RelationalSql.requiredDialect(text, dialect)) {
            var syntax = try f.RelationalSql.parseDialect(allocator, text, location, dialect);
            defer syntax.deinit();
            const clients: [f.Relational.max_sources]c.DirectTableClient = @splat(client.*);
            var selected = options;
            selected.dialect = dialect;
            plan = .{ .relational = try q.DirectRelationalCompilation.prepare(allocator, clients[0..syntax.targets.len], namespace, text, .interactive, selected, location) };
        } else plan = .{ .select = try q.DirectTablePrepared.prepare(allocator, client.*, namespace, text, dialect, detail) };
    } else if (std.ascii.eqlIgnoreCase(first.text, "INSERT") or std.ascii.eqlIgnoreCase(first.text, "UPDATE") or std.ascii.eqlIgnoreCase(first.text, "DELETE")) {
        plan = .{ .dml = try c.DirectTablePreparedDml.prepare(allocator, client.*, namespace, text, dialect, location) };
    } else if (std.ascii.eqlIgnoreCase(first.text, "CREATE")) {
        var ddl = try f.TableDdl.compileDialect(allocator, text, null, location, dialect);
        errdefer ddl.deinit();
        if (ddl.statement != .create) return error.UnsupportedGatewayStatement;
        _ = try client.require(.{ .namespace = namespace, .target = null, .access = .create_table });
        plan = .{ .create = ddl };
    } else if (profile == .native and (std.ascii.eqlIgnoreCase(first.text, "ALTER") or std.ascii.eqlIgnoreCase(first.text, "DROP"))) {
        var names: std.heap.ArenaAllocator = .init(allocator);
        defer names.deinit();
        const target = try f.TableDdl.targetDialect(names.allocator(), text, location, dialect);
        const response = try client.call(.{ .lookup = .{ .namespace = namespace, .name = target.name } });
        defer response.deinit();
        const metadata = response.value.result.lookup;
        const definition = if (metadata) |value| try c.DirectTableBinding.init(client.connection, value) else null;
        var schema: ?f.TableSchema.Owned = if (metadata) |value| try f.TableSchema.decode(allocator, try value.schema.decode(names.allocator(), f.TableSchema.max_bytes)) else null;
        errdefer if (schema) |*value| value.deinit();
        var compiled = try f.TableDdl.compileDialect(allocator, text, if (schema) |value| value.schema else null, location, dialect);
        errdefer compiled.deinit();
        if (definition) |value| _ = try value.require(client.*, if (target.kind == .alter) .alter else .drop);
        plan = .{ .ddl = .{ .compiled = compiled, .definition = definition, .schema = schema } };
    } else return error.UnsupportedGatewayStatement;
    errdefer switch (plan) {
        .relational => |value| value.deinit(),
        inline else => |*value| value.deinit(),
    };
    var output_fields: [g.Limits.max_parameters]f.Types.Field = undefined;
    const output: ?f.Types.Type = switch (plan) {
        .select => |value| value.output.type,
        .relational => |value| try value.plan.outputSchema(&output_fields),
        else => null,
    };
    if (profile == .wire) {
        if (output) |schema| for (schema.structure) |field| {
            _ = try g.Type.from(field);
        };
    }
    var result: Self = .{ .allocator = allocator, .text = owned, .connection = client.connection, .namespace = namespace, .dialect = dialect, .plan = plan, .output = if (output) |schema| try schema.clone(allocator) else null };
    errdefer if (result.output) |*schema| schema.deinit();
    if (profile == .wire) for (result.parameters()) |parameter| {
        _ = try g.Type.from(.{ .name = "", .type = parameter, .nullable = true });
    };
    return result;
}
fn tokenIs(token: f.Sql.Token, word: []const u8) bool {
    return token.tag == .word and std.ascii.eqlIgnoreCase(token.text, word);
}
/// Revalidate before disclosing cached descriptors. Data revisions can change;
/// a replacement object, schema, name or connection cannot inherit this handle.
pub fn validate(self: *const Self, client: *c.DirectTableClient) !void {
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    const right: c.TableAuthority.Access = switch (self.kind()) {
        .select => .read,
        .insert => .insert,
        .update => .update,
        .delete => .delete,
        .create => .create_table,
        .alter => .alter,
        .drop => .drop,
    };
    switch (self.plan) {
        .select => |value| _ = try value.binding.require(client.*, right),
        .dml => |value| _ = try value.binding.require(client.*, right),
        .relational => |value| try value.validate(client.*),
        .namespace_change => |value| try value.validate(client.*, self.namespace, .{}),
        .create => _ = try client.require(.{ .namespace = self.namespace, .target = null, .access = .create_table }),
        .ddl => |value| if (value.definition) |definition| {
            _ = try definition.require(client.*, right);
        } else {
            const response = try client.call(.{ .lookup = .{ .namespace = self.namespace, .name = value.compiled.statement.drop.name } });
            defer response.deinit();
            if (response.value.result.lookup != null) return error.TableDefinitionChanged;
        },
    }
}
pub const Write = union(enum) {
    table: c.DirectTableIntent,
    name_assertion: c.NameAssertion.Binding,
    namespace_change: g.IntentReference.NamespaceChange,
    pub fn deinit(self: *Write) void {
        if (self.* == .table) self.table.deinit();
        self.* = undefined;
    }
    pub fn workBytes(self: *const Write) !u64 {
        return switch (self.*) {
            .table => |value| value.bytes.len,
            .name_assertion => |value| (g.IntentReference.Reference{ .name_assertion = value }).workBytes(),
            .namespace_change => |value| (g.IntentReference.Reference{ .namespace_change = value }).workBytes(),
        };
    }
    /// Staging the inline assertion is pure. Only the coordinator may accept it
    /// after the native ledger has committed dispatch eligibility.
    pub fn stage(self: *const Write, client: c.DirectTableClient, namespace: u64) !g.IntentReference.Reference {
        return switch (self.*) {
            .table => |*value| .{ .table = try value.stage(client, namespace) },
            .name_assertion => |value| blk: {
                try value.validate();
                if (!std.meta.eql(value.connection, client.connection) or value.namespace != namespace) return error.CatalogIdentityConflict;
                break :blk .{ .name_assertion = value };
            },
            .namespace_change => |value| blk: {
                try value.validate();
                if (!std.meta.eql(value.binding.connection, client.connection) or value.namespace != namespace) return error.CatalogIdentityConflict;
                break :blk .{ .namespace_change = value };
            },
        };
    }
};
fn assertion(self: *const Self, operation: u64, name: []const u8, expected: ?c.protocol.DataLifecycle.Definition) !Write {
    // Exact source text commits every proposed clause, including a schema that
    // will not be installed when CREATE IF NOT EXISTS observes an existing name.
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.sql.conditional.name.v1\x00");
    hash.update(@tagName(self.dialect));
    hash.update("\x00");
    hash.update(self.text);
    const value: c.NameAssertion.Binding = .{ .definition = c.protocol.Growth.current_definition, .connection = self.connection, .operation = operation, .namespace = self.namespace, .name = try .init(name), .action = if (expected != null) .create_if_not_exists else .drop_if_exists, .expected = expected, .intent = hash.finalResult() };
    try value.validate();
    return .{ .name_assertion = value };
}
pub fn bindWrite(self: *const Self, allocator: std.mem.Allocator, client: *c.DirectTableClient, values: []const ?f.Types.Values.Atom, operation: u64) !Write {
    try self.validate(client);
    if (operation == 0 or operation > c.protocol.max_counter) return error.InvalidCatalogIdentity;
    if (self.plan == .dml) return .{ .table = try self.plan.dml.bind(allocator, client.*, operation, values, .point, null) };
    if (values.len != 0) return error.WireParameterCountMismatch;
    if (self.plan == .namespace_change) return .{ .namespace_change = .{ .namespace = self.namespace, .binding = try self.plan.namespace_change.bind(operation, operation) } };
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const connection = client.connection;
    var ddl: c.DirectTableProtocol.Ddl = .{ .binding = .{ .definition = c.protocol.Growth.current_definition, .identity = .{ .scope = connection.scope, .principal = connection.principal, .operation = operation }, .target = .{ .scope = connection.scope, .branch = connection.branch, .object = operation }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(0) }, .namespace = self.namespace, .name = undefined, .action = undefined };
    switch (self.plan) {
        .create => |value| {
            const create = value.statement.create;
            if (create.if_not_exists) {
                const response = try client.call(.{ .lookup = .{ .namespace = self.namespace, .name = create.name } });
                defer response.deinit();
                if (response.value.result.lookup) |existing| return self.assertion(operation, create.name, existing.interpretation.interpretation);
            }
            const subject = try client.require(.{ .namespace = self.namespace, .target = null, .access = .create_table });
            var buffer: [f.TableSchema.max_bytes]u8 = undefined;
            ddl.name = create.name;
            ddl.action = .{ .create = .{ .owner = subject.role, .schema = try .encode(a, try (try create.bind(operation)).encode(&buffer)) } };
        },
        .ddl => |value| {
            const definition = value.definition orelse {
                if (value.compiled.statement == .drop and value.compiled.statement.drop.if_exists) return self.assertion(operation, value.compiled.statement.drop.name, null);
                return error.TableNotFound;
            };
            ddl.binding.target = definition.interpretation.interpretation.object;
            ddl.binding.expected_definition = definition.interpretation.interpretation;
            ddl.name = definition.name.slice();
            switch (value.compiled.statement) {
                .alter => |alter| switch (alter.action) {
                    .columns => |change| {
                        ddl.binding.action = .alter;
                        ddl.action = .{ .alter = try wireChange(a, change, value.schema.?.schema) };
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
                else => return error.ExpectedGatewayWrite,
            }
        },
        else => return error.ExpectedGatewayWrite,
    }
    ddl.binding.intent = try ddl.digest(a);
    return .{ .table = try c.DirectTableIntent.create(allocator, connection, .{ .ddl = ddl }) };
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
pub fn openSelect(self: *const Self, allocator: std.mem.Allocator, client: *c.DirectTableClient, values: []const ?f.Types.Values.Atom, snapshot: c.DirectTableProtocol.Snapshot, limits: q.DirectTableQuery.Limits, cancellation: ?*const std.atomic.Value(bool)) !q.DirectTableQuery {
    if (self.plan != .select) return error.ExpectedSingleTableSelect;
    return q.DirectTableQuery.openPreparedRetained(allocator, client.*, snapshot, &self.plan.select, values, limits, cancellation, null, .{});
}
pub fn openRelational(self: *const Self, allocator: std.mem.Allocator, io: std.Io, directory: std.Io.Dir, name: []const u8, client: *c.DirectTableClient, snapshots: []const c.DirectTableProtocol.Snapshot, options: q.DirectRelationalQuery.Options, cancellation: ?*const std.atomic.Value(bool)) !*q.DirectRelationalQuery {
    if (self.plan != .relational) return error.ExpectedRelationalSelect;
    return q.DirectRelationalQuery.openPreparedRetained(allocator, io, directory, name, client.*, self.plan.relational, snapshots, options, cancellation);
}

test "gateway statements reject transaction controls and multiple commands before authority access" {
    const t = std.testing;
    var client: c.DirectTableClient = undefined;
    const options: q.RelationalQuery.Options = .{ .consistency = .independent_table_snapshots, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 100000, .source_pins = 2 }, .requests = 10000, .spill_work = 10000 };
    for ([_][]const u8{ "BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT s", "COPY t FROM STDIN", "CREATE SCHEMA app", "ALTER SCHEMA app RENAME TO archive", "DROP SCHEMA app" }) |sql| try t.expectError(error.UnsupportedGatewayStatement, prepare(t.allocator, &client, 1, sql, .transit, .wire, options));
    if (prepare(t.allocator, &client, 1, "CREATE TABLE t (id BIGINT); CREATE TABLE u (id BIGINT)", .transit, .wire, options)) |value| {
        var result = value;
        result.deinit();
        return error.ExpectedMultipleStatementRejection;
    } else |_| {}
}
