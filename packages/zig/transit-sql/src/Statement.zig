//! Gateway statement lifetime over shared metadata-only compilers. Preparation
//! owns immutable metadata; execution opens a new authorized cut or typed intent.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const f = g.fuze;
const Self = @This();
allocator: std.mem.Allocator,
text: []const u8,
connection: c.DirectTableProtocol.Connection,
namespace: u64,
dialect: f.Sql.Dialect,
plan: union(enum) { select: g.direct.DirectTablePrepared, dml: c.DirectTablePreparedDml, ddl: c.DirectTablePreparedDdl, relational: *g.direct.DirectRelationalCompilation, namespace_change: c.DirectAuthorizationSql.NamespacePlan },
output: ?f.Types.Decoded,
pub const Kind = enum { select, insert, update, delete, create, alter, drop };
pub fn kind(self: *const Self) Kind {
    return switch (self.plan) {
        .select, .relational => .select,
        .ddl => |value| switch (value.compiled.statement) {
            .create => .create,
            .alter => .alter,
            .drop => .drop,
        },
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
pub fn prepare(allocator: std.mem.Allocator, client: *c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, profile: Profile, options: g.direct.DirectRelationalQuery.Options) !Self {
    return prepareDiagnostic(allocator, client, namespace, text, dialect, profile, options, null);
}
pub fn prepareDiagnostic(allocator: std.mem.Allocator, client: *c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, profile: Profile, options: g.direct.DirectRelationalQuery.Options, detail: ?*f.Sql.Binding) !Self {
    if (detail) |value| value.* = .{};
    var location: f.Sql.Location = .{};
    return prepareInner(allocator, client, namespace, text, dialect, profile, options, detail, &location) catch |err| {
        if (detail) |value| if (value.location == null and (location.offset != 0 or location.expected != null)) {
            value.location = location;
        };
        return err;
    };
}
fn prepareInner(allocator: std.mem.Allocator, client: *c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, profile: Profile, options: g.direct.DirectRelationalQuery.Options, detail: ?*f.Sql.Binding, location: *f.Sql.Location) !Self {
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
            plan = .{ .relational = try g.direct.DirectRelationalCompilation.prepare(allocator, clients[0..syntax.targets.len], namespace, text, .interactive, selected, location) };
        } else plan = .{ .select = try g.direct.DirectTablePrepared.prepare(allocator, client.*, namespace, text, dialect, detail) };
    } else if (std.ascii.eqlIgnoreCase(first.text, "INSERT") or std.ascii.eqlIgnoreCase(first.text, "UPDATE") or std.ascii.eqlIgnoreCase(first.text, "DELETE")) {
        plan = .{ .dml = try c.DirectTablePreparedDml.prepare(allocator, client.*, namespace, text, dialect, location) };
    } else if (std.ascii.eqlIgnoreCase(first.text, "CREATE") or (profile == .native and (std.ascii.eqlIgnoreCase(first.text, "ALTER") or std.ascii.eqlIgnoreCase(first.text, "DROP")))) {
        plan = .{ .ddl = try c.DirectTablePreparedDdl.prepare(allocator, client.*, namespace, text, dialect, location) };
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
        .ddl => |*value| try value.validate(client.*),
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
    /// Staging an inline assertion is pure. Database recovery dispatches only
    /// the complete reference accepted by the Catalog's client-token binding.
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
pub fn bindWrite(self: *const Self, allocator: std.mem.Allocator, client: *c.DirectTableClient, values: []const ?f.Types.Values.Atom, operation: u64) !Write {
    if (operation == 0 or operation > c.protocol.max_counter) return error.InvalidCatalogIdentity;
    if (self.plan == .ddl) {
        if (values.len != 0) return error.WireParameterCountMismatch;
        const prepared = &self.plan.ddl;
        const result = try prepared.bind(allocator, client.*, operation, if (prepared.compiled.statement == .create) operation else null);
        return switch (result) {
            .table => |value| .{ .table = value },
            .name_assertion => |value| .{ .name_assertion = value },
        };
    }
    try self.validate(client);
    if (self.plan == .dml) return .{ .table = try self.plan.dml.bind(allocator, client.*, operation, values, if (client.transaction != null) .bulk else .point, null) };
    if (values.len != 0) return error.WireParameterCountMismatch;
    if (self.plan == .namespace_change) return .{ .namespace_change = .{ .namespace = self.namespace, .binding = try self.plan.namespace_change.bind(operation, operation) } };
    return error.ExpectedGatewayWrite;
}
pub fn openSelect(self: *const Self, allocator: std.mem.Allocator, client: *c.DirectTableClient, values: []const ?f.Types.Values.Atom, snapshot: c.DirectTableProtocol.Snapshot, limits: g.direct.DirectTableQuery.Limits, cancellation: ?*const std.atomic.Value(bool)) !g.direct.DirectTableQuery {
    if (self.plan != .select) return error.ExpectedSingleTableSelect;
    return g.direct.DirectTableQuery.openPreparedRetained(allocator, client.*, snapshot, &self.plan.select, values, limits, cancellation, null, .{});
}
pub fn openRelational(self: *const Self, allocator: std.mem.Allocator, io: std.Io, directory: std.Io.Dir, name: []const u8, client: *c.DirectTableClient, snapshots: []const c.DirectTableProtocol.Snapshot, options: g.direct.DirectRelationalQuery.Options, cancellation: ?*const std.atomic.Value(bool)) !*g.direct.DirectRelationalQuery {
    if (self.plan != .relational) return error.ExpectedRelationalSelect;
    return g.direct.DirectRelationalQuery.openPreparedRetained(allocator, io, directory, name, client.*, self.plan.relational, snapshots, options, cancellation);
}

test "gateway statements reject transaction controls and multiple commands before authority access" {
    const t = std.testing;
    var client: c.DirectTableClient = undefined;
    const options: g.direct.DirectRelationalQuery.Options = .{ .consistency = .independent_table_snapshots, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 100000, .source_pins = 2 }, .requests = 10000, .spill_work = 10000 };
    for ([_][]const u8{ "BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT s", "COPY t FROM STDIN", "CREATE SCHEMA app", "ALTER SCHEMA app RENAME TO archive", "DROP SCHEMA app" }) |sql| try t.expectError(error.UnsupportedGatewayStatement, prepare(t.allocator, &client, 1, sql, .transit, .wire, options));
    if (prepare(t.allocator, &client, 1, "CREATE TABLE t (id BIGINT); CREATE TABLE u (id BIGINT)", .transit, .wire, options)) |value| {
        var result = value;
        result.deinit();
        return error.ExpectedMultipleStatementRejection;
    } else |_| {}
}
