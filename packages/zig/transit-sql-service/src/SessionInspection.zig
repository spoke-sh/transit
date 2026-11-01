//! Definition, plan and direct storage inspection produce ordinary logical rows.
//! Preparation binds metadata; disclosure rechecks current rights and identity.
const std = @import("std");
const g = @import("root.zig");
const f = g.fuze;
const c = g.catalog;
const Storage = @import("SessionStorage.zig");
const Self = @This();
arena: std.heap.ArenaAllocator,
name: ?c.TableMetadata.Name = null,
metadata: ?c.DirectTableBinding = null,
log_metadata: ?struct { connection: c.DirectTableProtocol.Connection, definition: c.DirectLog.Definition } = null,
statement: ?g.Statement = null,
source: bool = false,
storage: bool = false,
node_storage: bool = false,
kind: @FieldType(g.results.Observation.Metadata, "kind") = .catalog,
rows: []const []const f.Types.Values.Cell,
output: []const f.Types.Field,
const describe_fields = [_]f.Types.Field{
    .{ .name = "name", .type = .utf8 },                      .{ .name = "type", .type = .utf8 },
    .{ .name = "nullable", .type = .boolean },               .{ .name = "primary_key", .type = .boolean },
    .{ .name = "default", .type = .utf8, .nullable = true }, .{ .name = "max_characters", .type = .uint32, .nullable = true },
    .{ .name = "object", .type = .uint64 },                  .{ .name = "schema_revision", .type = .uint64 },
    .{ .name = "column_id", .type = .uint64 },
};
const explain_fields = [_]f.Types.Field{.{ .name = "plan", .type = .utf8 }};
// Log inspection is also a database-wire surface. Its character bound uses
// the common lossless unsigned type; native Table descriptions retain theirs.
const log_describe_fields = blk: {
    var fields = describe_fields;
    fields[5].type = .uint64;
    break :blk fields;
};
const log_fields = [_]f.Types.Field{
    .{ .name = "object", .type = .uint64 },     .{ .name = "definition_revision", .type = .uint64 },
    .{ .name = "partitions", .type = .uint64 }, .{ .name = "configuration", .type = .utf8 },
    .{ .name = "limits", .type = .utf8 },
};
test "log metadata fields use the lossless common database wire matrix" {
    for (log_fields ++ log_describe_fields) |field| _ = try g.Type.from(field);
}
fn text(bytes: []const u8) f.Types.Values.Cell {
    return .{ .value = .{ .atom = .{ .bytes = bytes } } };
}
fn boolean(value: bool) f.Types.Values.Cell {
    return .{ .value = .{ .atom = .{ .boolean = value } } };
}
fn unsigned(value: u64) f.Types.Values.Cell {
    return .{ .value = .{ .atom = .{ .unsigned = value } } };
}
pub fn prepare(host: *g.Session, sql: []const u8) !?Self {
    if (host.source) |source| return if (host.native_profile) prepareSource(host, source, sql) else null;
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    var parser = try f.SqlTyped.initDialect(a, sql, null, false, host.dialect);
    if (try f.LogDdl.inspection(parser)) |inspection| {
        const name = try c.TableMetadata.Name.init(inspection.name);
        const response = try host.table.call(.{ .log_lookup = .{ .namespace = host.namespace, .name = name.slice() } });
        defer response.deinit();
        const metadata = response.value.result.log_lookup orelse return error.CatalogNameNotFound;
        const definition = metadata.declaration;
        if (definition.kind() != inspection.kind) return error.CatalogKindMismatch;
        const rows = if (!inspection.describe) blk: {
            const rows = try a.alloc([]const f.Types.Values.Cell, 1);
            rows[0] = try a.dupe(f.Types.Values.Cell, &.{ unsigned(definition.stored.declaration.interpretation.object.object), unsigned(definition.stored.declaration.interpretation.revision), unsigned(definition.count()), text(try c.protocol.Json.valueAlloc(a, definition.stored.declaration.configuration)), text(try c.protocol.Json.valueAlloc(a, definition.stored.declaration.limits)) });
            break :blk rows;
        } else blk: {
            var owned = try f.TableSchema.decode(a, try metadata.schema.decode(a, f.TableSchema.max_bytes));
            defer owned.deinit();
            break :blk try describeRows(a, owned.schema);
        };
        return .{ .arena = arena, .name = name, .log_metadata = .{ .connection = host.table.connection, .definition = definition }, .rows = rows, .output = if (inspection.describe) &log_describe_fields else &log_fields };
    }
    if (try parser.takeWord("SHOW")) {
        if (!(try parser.takeWord("STORAGE"))) {
            arena.deinit();
            return null;
        }
        if (!(try parser.takeWord("FOR"))) {
            try parser.finish();
            try validateNode(host);
            return .{ .arena = arena, .node_storage = true, .rows = &.{}, .output = &Storage.node_fields };
        }
        const name = try c.TableMetadata.Name.init(try parser.name());
        try parser.finish();
        const response = try host.table.call(.{ .lookup = .{ .namespace = host.namespace, .name = name.slice() } });
        defer response.deinit();
        const definition = response.value.result.lookup orelse return error.CatalogNameNotFound;
        const binding = try c.DirectTableBinding.init(host.table.connection, definition);
        return .{ .arena = arena, .name = name, .metadata = binding, .storage = true, .rows = &.{}, .output = &Storage.fields };
    }
    if (!host.native_profile) {
        arena.deinit();
        return null;
    }
    if (try parser.takeWord("DESCRIBE")) {
        const name = try c.TableMetadata.Name.init(try parser.name());
        try parser.finish();
        const response = try host.table.call(.{ .lookup = .{ .namespace = host.namespace, .name = name.slice() } });
        defer response.deinit();
        const definition = response.value.result.lookup orelse return error.CatalogNameNotFound;
        const binding = try c.DirectTableBinding.init(host.table.connection, definition);
        var owned_schema = try f.TableSchema.decode(a, try definition.schema.decode(a, f.TableSchema.max_bytes));
        defer owned_schema.deinit();
        const rows = try describeRows(a, owned_schema.schema);
        return .{ .arena = arena, .name = name, .metadata = binding, .rows = rows, .output = &describe_fields };
    }
    if (try parser.takeWord("EXPLAIN")) {
        var statement = try g.Statement.prepare(host.allocator, &host.table, host.namespace, sql[parser.lexer.start..], host.dialect, .inspection, g.Session.read_options);
        errdefer statement.deinit();
        if (statement.kind() != .select or statement.parameters().len != 0) return error.UnsupportedConstruct;
        const plan = switch (statement.plan) {
            .select => |*selected| blk: {
                const template = &selected.template;
                var bound = try template.bind(host.allocator, template.name, template.descriptor.type, template.basis, &.{}, null);
                defer bound.deinit();
                bound.plan.collations = selected.collations;
                break :blk try std.json.Stringify.valueAlloc(a, .{
                    .object = selected.binding.interpretation.interpretation.object.object,
                    .traits = f.OperatorTraits.Summary.forExplain(try f.OperatorTraits.forLogicalPlan(bound.plan)),
                    .filter = bound.plan.predicate != .all,
                    .aggregate = @tagName(bound.plan.aggregate),
                    .limit = bound.plan.limit,
                    .schema = f.LogicalJson.TypeEnvelope{ .definition = f.Types.definition, .type = statement.output.?.type },
                    .executed = false,
                    .basis = @as(?[]const u8, null),
                }, .{});
            },
            .relational => |compilation| try std.json.Stringify.valueAlloc(a, .{
                .traits = f.OperatorTraits.Summary.forExplain(try f.OperatorTraits.forRelationalPlan(compilation.plan)),
                .consistency = "independent_table_snapshots",
                .sources = compilation.plan.sources.len,
                .join = if (compilation.plan.join) |join| @tagName(join.kind) else "none",
                .grouped = compilation.grouped(),
                .group_columns = compilation.plan.group_by.len,
                .schema = f.LogicalJson.TypeEnvelope{ .definition = f.Types.definition, .type = statement.output.?.type },
                .executed = false,
                .basis = @as(?[]const u8, null),
            }, .{}),
            else => unreachable,
        };
        const rows = try a.alloc([]const f.Types.Values.Cell, 1);
        rows[0] = try a.dupe(f.Types.Values.Cell, &.{text(plan)});
        return .{ .arena = arena, .statement = statement, .kind = .plan, .rows = rows, .output = &explain_fields };
    }
    arena.deinit();
    return null;
}
fn describeRows(a: std.mem.Allocator, schema: f.TableSchema.Schema) ![]const []const f.Types.Values.Cell {
    const rows = try a.alloc([]const f.Types.Values.Cell, schema.columns.len);
    for (schema.columns, rows) |column, *row| {
        var type_text: std.Io.Writer.Allocating = .init(a);
        try f.LogicalDisplay.typeName(&type_text.writer, column.type);
        row.* = try a.dupe(f.Types.Values.Cell, &.{
            text(try a.dupe(u8, column.name)),                                                                                                          text(type_text.written()),                                     boolean(column.nullable), boolean(std.mem.indexOfScalar(u64, schema.primary_key, column.id) != null),
            if (column.default) |cell| text(try std.json.Stringify.valueAlloc(a, try f.LogicalJson.foreignCell(a, cell, column.type), .{})) else .null, if (column.max_characters) |limit| unsigned(limit) else .null, unsigned(schema.object),  unsigned(schema.revision),
            unsigned(column.id),
        });
    }
    return rows;
}
pub fn validate(self: *Self, host: *g.Session) !void {
    if (self.node_storage) try validateNode(host);
    if (self.source) {
        const source = host.source orelse return error.UnknownSqlSource;
        try source.current();
        _ = try source.client.describe(source.definition);
    }
    if (self.metadata) |binding| {
        if (host.namespace != binding.namespace) return error.CatalogIdentityConflict;
        _ = try binding.require(host.table, .inspect);
    }
    if (self.log_metadata) |binding| {
        if (host.namespace != binding.definition.properties.namespace or !std.meta.eql(host.table.connection, binding.connection)) return error.CatalogIdentityConflict;
        try c.DirectLogClient.requireCurrent(host.table, binding.definition);
    }
    if (self.statement) |*statement| try statement.validate(&host.table);
}
fn validateNode(host: *g.Session) !void {
    const response = try host.wire.query(.{ .realm = host.table.connection.scope.realm, .principal = host.table.connection.principal, .kind = .identity }, host.table.key);
    if (response.body.identity.pid != null) return error.Forbidden;
}
fn prepareSource(host: *g.Session, source: *g.SourceSession, sql: []const u8) !?Self {
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    var parser = try f.SqlTyped.init(a, sql, null);
    const describe = try parser.takeWord("DESCRIBE");
    const explain = if (!describe) try parser.takeWord("EXPLAIN") else false;
    const tables = if (!describe and !explain) (try parser.takeWord("SHOW")) and (try parser.takeWord("TABLES")) else false;
    if (!describe and !explain and !tables) {
        arena.deinit();
        return null;
    }
    const workspace = source.configuration.workspace;
    const result = try g.query.SqlInspection.apply(a, &source.client, .{ .scope = .{ .name = workspace.name, .source = workspace.source, .limits = workspace.limits }, .sql = sql });
    const rows = try a.alloc([]const f.Types.Values.Cell, 1);
    rows[0] = try a.dupe(f.Types.Values.Cell, &.{text(try g.query.protocol.Json.valueAlloc(a, result))});
    return .{ .arena = arena, .source = true, .kind = if (explain) .plan else .catalog, .rows = rows, .output = &.{.{ .name = "source_inspection", .type = .utf8 }} };
}
pub fn deinit(self: *Self) void {
    if (self.statement) |*statement| statement.deinit();
    self.arena.deinit();
}
pub fn count(self: Self) usize {
    return if (self.storage or self.node_storage) 1 else self.rows.len;
}
pub const Read = struct {
    host: *g.Session,
    prepared: *Self,
    index: usize = 0,
    storage_values: [Storage.fields.len]f.Types.Values.Cell = undefined,
    node_observation: g.query.protocol.Storage.Observation = undefined,
    node_values: [Storage.node_fields.len]f.Types.Values.Cell = undefined,
    pub fn next(self: *Read) !?[]const f.Types.Values.Cell {
        try self.prepared.validate(self.host);
        if (self.index == self.prepared.count()) return null;
        if (self.prepared.node_storage) {
            const response = try self.host.wire.query(.{ .realm = self.host.table.connection.scope.realm, .principal = self.host.table.connection.principal, .kind = .storage }, self.host.table.key);
            self.node_observation = response.body.storage;
            self.node_values = Storage.nodeRow(&self.node_observation);
            self.index += 1;
            return &self.node_values;
        }
        if (self.prepared.storage) {
            const binding = self.prepared.metadata.?;
            const response = try self.host.table.call(.{ .storage = .{ .object = binding.interpretation.interpretation.object, .pending_limit = Storage.pending_limit } });
            defer response.deinit();
            const observed = response.value.result.storage;
            if (!std.meta.eql(binding.interpretation, observed.interpretation)) return error.TableDefinitionChanged;
            self.storage_values = Storage.row(observed);
            self.index += 1;
            return &self.storage_values;
        }
        defer self.index += 1;
        return self.prepared.rows[self.index];
    }
};
