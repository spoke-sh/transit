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
connection: c.TableClient.Connection,
dialect: f.Sql.Dialect,
plan: union(enum) { select: q.TablePrepared, dml: c.TablePreparedDml, create: f.TableDdl.Owned, relational: *q.RelationalCompilation },
output: ?f.Types.Decoded,
pub const Kind = enum { select, insert, update, delete, create };
pub fn kind(self: *const Self) Kind {
    return switch (self.plan) {
        .select, .relational => .select,
        .create => .create,
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
pub fn prepare(allocator: std.mem.Allocator, client: *c.TableClient, text: []const u8, dialect: f.Sql.Dialect, options: q.RelationalQuery.Options) !Self {
    try f.Sql.validateText(text);
    var lexer: f.Sql.Lexer = .{ .text = text, .dialect = dialect, .parameters_enabled = true };
    const first = try lexer.next();
    if (first.tag != .word) return error.UnsupportedGatewayStatement;
    const owned = try allocator.dupe(u8, text);
    errdefer allocator.free(owned);
    var plan: @FieldType(Self, "plan") = undefined;
    if (std.ascii.eqlIgnoreCase(first.text, "SELECT")) {
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
            var syntax = try f.RelationalSql.parseDialect(allocator, text, null, dialect);
            defer syntax.deinit();
            var clients: [f.Relational.max_sources]*c.TableClient = @splat(client);
            var selected = options;
            selected.dialect = dialect;
            plan = .{ .relational = try q.RelationalCompilation.prepare(allocator, clients[0..syntax.targets.len], text, .interactive, selected, null) };
        } else plan = .{ .select = try q.TablePrepared.prepare(allocator, client, text, dialect, null) };
    } else if (std.ascii.eqlIgnoreCase(first.text, "INSERT") or std.ascii.eqlIgnoreCase(first.text, "UPDATE") or std.ascii.eqlIgnoreCase(first.text, "DELETE")) {
        plan = .{ .dml = try c.TablePreparedDml.prepare(allocator, client, text, dialect, null) };
    } else if (std.ascii.eqlIgnoreCase(first.text, "CREATE")) {
        var ddl = try f.TableDdl.compileDialect(allocator, text, null, null, dialect);
        errdefer ddl.deinit();
        if (ddl.statement != .create) return error.UnsupportedGatewayStatement;
        _ = try client.requireObject(0, .create);
        plan = .{ .create = ddl };
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
    if (output) |schema| for (schema.structure) |field| {
        _ = try g.Type.from(field);
    };
    var result: Self = .{ .allocator = allocator, .text = owned, .connection = client.connection, .dialect = dialect, .plan = plan, .output = if (output) |schema| try schema.clone(allocator) else null };
    errdefer if (result.output) |*schema| schema.deinit();
    for (result.parameters()) |parameter| _ = try g.Type.from(.{ .name = "", .type = parameter, .nullable = true });
    return result;
}
/// Revalidate before disclosing cached descriptors. Data revisions can change;
/// a replacement object, schema, name or connection cannot inherit this handle.
pub fn validate(self: *const Self, client: *c.TableClient) !void {
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    const before = try client.describe();
    const right: c.TableCatalogRecords.Right = switch (self.kind()) {
        .select => .read,
        .insert => .insert,
        .update => .update,
        .delete => .delete,
        .create => .create,
    };
    switch (self.plan) {
        .select => |value| {
            _ = try client.requireObject(value.binding.metadata.object, right);
            try checkBinding(self.allocator, client, value.binding);
        },
        .dml => |value| {
            _ = try client.requireObject(value.binding.metadata.object, right);
            try checkBinding(self.allocator, client, value.binding);
        },
        .relational => |value| for (value.definitions[0..value.syntax.targets.len]) |definition| {
            _ = try client.requireObject(definition.?.metadata.object, .read);
            try checkBinding(self.allocator, client, try c.TableBinding.init(self.connection, definition.?.metadata));
        },
        .create => _ = try client.requireObject(0, .create),
    }
    if (!std.meta.eql(before, try client.describe())) return error.CatalogDefinitionChanged;
}
fn checkBinding(allocator: std.mem.Allocator, client: *c.TableClient, binding: c.TableBinding) !void {
    var definition = (try client.lookup(allocator, binding.metadata.name)) orelse return error.TableNotFound;
    defer definition.deinit();
    try binding.check(client.connection, definition.metadata);
}
pub fn bindWrite(self: *const Self, allocator: std.mem.Allocator, client: *c.TableClient, values: []const ?f.Types.Values.Atom, operation: u64) !c.TableIntent {
    try self.validate(client);
    if (operation == 0 or operation > c.protocol.max_counter) return error.InvalidCatalogIdentity;
    return switch (self.plan) {
        .dml => |*value| value.bind(allocator, client, values, .{ .operation = operation, .namespace = operation }, null),
        .create => |value| blk: {
            if (values.len != 0) return error.WireParameterCountMismatch;
            const create = value.statement.create;
            const request: c.TableDdlRequest = .{ .principal = client.connection.principal, .operation = operation, .namespace = client.connection.namespace, .object = operation, .expected_revision = 0, .name = try c.TableMetadata.Name.init(create.name), .action = .{ .create = .{ .schema = try create.bind(operation), .if_not_exists = create.if_not_exists } } };
            break :blk c.TableIntent.create(allocator, try c.TableCommand.fromDdl(client.connection.scope, client.connection.owner, request, null), operation);
        },
        else => error.ExpectedGatewayWrite,
    };
}
pub fn openSelect(self: *const Self, allocator: std.mem.Allocator, client: *c.TableClient, values: []const ?f.Types.Values.Atom, nonce: [16]u8, limits: q.TableQuery.Limits, cancellation: ?*const std.atomic.Value(bool)) !q.TableQuery {
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    if (self.plan != .select) return error.ExpectedSingleTableSelect;
    return q.TableQuery.openPrepared(allocator, client, &self.plan.select, values, nonce, limits, cancellation, null, .{});
}
pub fn openRelational(self: *const Self, allocator: std.mem.Allocator, io: std.Io, directory: std.Io.Dir, spill_name: []const u8, client: *c.TableClient, nonces: [f.Relational.max_sources][16]u8, options: q.RelationalQuery.Options, cancellation: ?*const std.atomic.Value(bool)) !*q.RelationalQuery {
    try self.validate(client);
    if (self.plan != .relational) return error.ExpectedRelationalSelect;
    const prepared = self.plan.relational;
    if (!std.meta.eql(prepared.plan.budgets, options.budgets)) return error.InvalidQueryBudget;
    var selected = options;
    selected.dialect = self.dialect;
    var clients: [f.Relational.max_sources]*c.TableClient = @splat(client);
    const result = try q.RelationalQuery.open(allocator, io, directory, spill_name, clients[0..prepared.syntax.targets.len], self.text, nonces, selected, cancellation, null);
    errdefer result.deinit();
    // Capture can race DDL after the metadata-only validation above. Check the
    // actual captured descriptors before any executor step or output disclosure.
    for (prepared.definitions[0..result.tables.count], result.tables.scans[0..result.tables.count]) |original, captured| {
        const binding = try c.TableBinding.init(self.connection, original.?.metadata);
        try binding.check(client.connection, captured.?.definition.?.metadata);
    }
    return result;
}
test "gateway statements reject transaction controls and multi-command CREATE before authority access" {
    const t = std.testing;
    var client: c.TableClient = undefined;
    const options: q.RelationalQuery.Options = .{ .consistency = .per_resource_snapshot_vector, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 100000, .source_pins = 2 }, .requests = 10000, .spill_work = 10000 };
    for ([_][]const u8{ "BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT s", "COPY t FROM STDIN", "ALTER TABLE t ADD x BIGINT", "DROP TABLE t" }) |sql| try t.expectError(error.UnsupportedGatewayStatement, prepare(t.allocator, &client, sql, .transit, options));
    if (prepare(t.allocator, &client, "CREATE TABLE t (id BIGINT); CREATE TABLE u (id BIGINT)", .transit, options)) |value| {
        var result = value;
        result.deinit();
        return error.ExpectedMultipleStatementRejection;
    } else |_| {}
}
