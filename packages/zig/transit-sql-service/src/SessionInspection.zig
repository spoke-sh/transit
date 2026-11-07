//! Definition, plan and direct storage inspection produce ordinary logical rows.
//! Preparation binds metadata; disclosure rechecks current rights and identity.
const std = @import("std");
const g = @import("root.zig");
const f = g.fuze;
const c = g.catalog;
const Storage = @import("SessionStorage.zig");
const Self = @This();
const PgCatalog = @import("PgCatalog.zig");
postgres: ?PgCatalog = null,
arena: std.heap.ArenaAllocator,
name: ?c.TableMetadata.Name = null,
metadata: ?c.DirectTableBinding = null,
kv_metadata: ?struct { connection: c.DirectTableProtocol.Connection, definition: c.DirectKV.Definition } = null,
log_metadata: ?struct { connection: c.DirectTableProtocol.Connection, definition: c.DirectLog.Definition } = null,
statement: ?g.Statement = null,
managed: ?g.direct.ManagedTable.Declaration = null,
managed_revision: ?struct { revision: u64, root: c.DirectRecord.Reference } = null,
source: bool = false,
connector_definition: ?c.protocol.DataLifecycle.Definition = null,
connector_proposal: ?c.DirectSource.Proposal = null,
connector_list: ?c.DirectSource.Selection = null,
historical_list: ?c.protocol.DataLifecycle.Snapshot = null,
historical_namespace: ?u64 = null,
projection: ?c.DirectSchemaProjection.Accepted = null,
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
const historical_list_fields = [_]f.Types.Field{ .{ .name = "name", .type = .utf8 }, .{ .name = "object", .type = .uint64 }, .{ .name = "definition_revision", .type = .uint64 } };
const connector_fields = [_]f.Types.Field{
    .{ .name = "name", .type = .utf8 },                      .{ .name = "object", .type = .uint64 },
    .{ .name = "kind", .type = .utf8 },                      .{ .name = "state", .type = .utf8 },
    .{ .name = "epoch", .type = .uint64, .nullable = true }, .{ .name = "execution_supported", .type = .boolean },
    .{ .name = "execution", .type = .utf8 },                 .{ .name = "catalog_partition", .type = .uint64 },
    .{ .name = "catalog_next_lsn", .type = .uint64 },
};
const connector_detail_fields = connector_fields ++ [_]f.Types.Field{
    .{ .name = "definition", .type = .utf8 },                  .{ .name = "dependency_state", .type = .utf8 },
    .{ .name = "last_poll", .type = .utf8, .nullable = true }, .{ .name = "last_publication", .type = .utf8, .nullable = true },
};
fn connectorRow(state: *const c.DirectSource.State, position: c.protocol.DataLifecycle.Position) [connector_fields.len]f.Types.Values.Cell {
    return .{ text(state.declaration.properties.name.slice()), unsigned(state.declaration.interpretation.object.object), text(@tagName(state.declaration.kind)), text(if (state.control) |control| @tagName(control.state) else "published"), if (state.control) |control| unsigned(control.epoch) else .null, boolean(false), text("never_run"), unsigned(position.partition), unsigned(position.next_lsn) };
}
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
const kv_fields = [_]f.Types.Field{
    .{ .name = "object", .type = .uint64 },     .{ .name = "definition_revision", .type = .uint64 },
    .{ .name = "key_type", .type = .utf8 },     .{ .name = "value_type", .type = .utf8 },
    .{ .name = "nullable", .type = .boolean },
};
test "log metadata fields use the lossless common database wire matrix" {
    for (log_fields ++ kv_fields ++ log_describe_fields) |field| _ = try g.Type.from(field);
}
test "metadata preparation leaves dialect probes to their owner without allocation or I O" {
    // Only the dialect is available: no connected runtime or allocator may be
    // touched when this metadata adapter declines another owner's statement.
    var host: g.Session = undefined;
    host.dialect = .mysql;
    for ([_][]const u8{
        "SELECT @@character_set_connection, @@collation_connection, @@sql_mode",
        "SELECT @@version_comment LIMIT 1",
        "SET @@session.autocommit=on",
    }) |sql| {
        try std.testing.expect(try prepare(&host, sql) == null);
        try std.testing.expect(try g.Probe.parse(sql, .mysql) != null);
    }
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
    if (try PgCatalog.prepare(host, sql)) |postgres| return .{ .arena = postgres.arena, .postgres = postgres, .metadata = postgres.binding, .rows = &.{}, .output = postgres.output() };
    // Inspect only this adapter's statements. SELECT (including MySQL's @@
    // probes) and writes belong to their own preparation/lexing boundaries.
    var lexer: f.Sql.Lexer = .{ .text = sql, .dialect = host.dialect };
    const first = try lexer.next();
    if (first.tag != .word or (!std.ascii.eqlIgnoreCase(first.text, "SHOW") and
        !std.ascii.eqlIgnoreCase(first.text, "DESCRIBE") and
        !std.ascii.eqlIgnoreCase(first.text, "EXPLAIN"))) return null;
    if (try g.database.SourceSql.parse(host.allocator, sql, host.dialect)) |parsed_value| {
        var parsed = parsed_value;
        defer parsed.deinit();
        return try prepareConnector(host, parsed.statement);
    }
    const selection = try g.database.HistoricalSql.select(sql, host.dialect);
    if (selection.snapshot != null and host.table.transaction != null) return error.UnsupportedHistoricalTransaction;
    if (selection.snapshot != null and host.source != null) return error.UnsupportedHistoricalKind;
    if (host.source) |source| return if (host.native_profile) prepareSource(host, source, sql) else null;
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    var parser = try f.SqlTyped.initDialect(a, selection.statement, null, false, host.dialect);
    if (try f.LogDdl.inspection(parser)) |inspection| {
        if (selection.snapshot != null) return error.UnsupportedHistoricalKind;
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
    if (try f.KVDdl.inspection(parser)) |inspection| {
        if (selection.snapshot != null) return error.UnsupportedHistoricalKind;
        const name = try c.TableMetadata.Name.init(inspection.name);
        const response = try host.table.call(.{ .kv_lookup = .{ .namespace = host.namespace, .name = name.slice() } });
        defer response.deinit();
        const definition = response.value.result.kv_lookup orelse return error.CatalogNameNotFound;
        const rows = if (!inspection.describe) blk: {
            const rows = try a.alloc([]const f.Types.Values.Cell, 1);
            rows[0] = try a.dupe(f.Types.Values.Cell, &.{
                unsigned(definition.interpretation.interpretation.object.object),
                unsigned(definition.interpretation.interpretation.revision),
                text("UTF8"),
                text(switch (definition.spec.value_type) {
                    .int64 => "INT64",
                    .boolean => "BOOLEAN",
                    .utf8 => "UTF8",
                    .binary => "BINARY",
                }),
                boolean(definition.spec.nullable),
            });
            break :blk rows;
        } else try kvDescribeRows(a, definition);
        return .{ .arena = arena, .name = name, .kv_metadata = .{ .connection = host.table.connection, .definition = definition }, .rows = rows, .output = if (inspection.describe) &log_describe_fields else &kv_fields };
    }
    const selected_namespace = if (selection.snapshot != null) try selection.resolveNamespace(host.table, host.namespace) else host.namespace;
    if (try parser.takeWord("SHOW")) {
        if (selection.projection != null) return error.UnsupportedConstruct;
        if (selection.snapshot) |snapshot| {
            try parser.requireWord("TABLES");
            try parser.finish();
            // Read one page to check publication/current namespace permission.
            // Preparation retains no list rows or data handles.
            const response = try c.DirectHistory.call(host.table, .{ .list = .{ .snapshot = snapshot, .namespace = selected_namespace, .after = null } });
            defer response.deinit();
            return .{ .arena = arena, .historical_list = snapshot, .historical_namespace = selected_namespace, .rows = &.{}, .output = &historical_list_fields };
        }
        if (try parser.takeWord("DATAFLOW")) {
            if (!host.native_profile or host.source != null or selection.snapshot != null) return error.UnsupportedManagedTable;
            const command = (try g.database.ManagedSql.inspect(a, sql, host.dialect)) orelse return error.InvalidSqlSyntax;
            const name = try c.TableMetadata.Name.init(command.name.slice());
            const revision = command.revision;
            const response = host.table.call(.{ .managed_inspection = .{ .namespace = host.namespace, .name = try .init(name.slice()), .expected = null, .revision = revision } }) catch |err| return if (err == error.NotFound) (if (revision != null) error.DataflowRevisionNotFound else error.CatalogNameNotFound) else err;
            defer response.deinit();
            const inspected = response.value.result.managed_inspection;
            var declared = inspected.declaration;
            declared.sql = try a.dupe(u8, declared.sql);
            const rows = try a.alloc([]const f.Types.Values.Cell, 1);
            if (revision) |number| {
                const completed = inspected.completed orelse return error.InvalidManagedTableRecord;
                rows[0] = try a.dupe(f.Types.Values.Cell, &.{text(try c.protocol.Json.valueAlloc(a, .{ .revision = completed.revision.metadata, .manifest = completed.manifest, .decision = completed.decision }))});
                return .{ .arena = arena, .name = name, .managed = declared, .managed_revision = .{ .revision = number, .root = completed.manifest }, .rows = rows, .output = &.{.{ .name = "dataflow_revision", .type = .utf8 }} };
            }
            rows[0] = try a.dupe(f.Types.Values.Cell, &.{text(try c.protocol.Json.valueAlloc(a, .{ .declaration = declared, .observation = inspected.observation.? }))});
            return .{ .arena = arena, .name = name, .managed = declared, .rows = rows, .output = &.{.{ .name = "dataflow", .type = .utf8 }} };
        }
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
        const response = if (selection.snapshot) |snapshot| c.DirectHistory.resolve(host.table, snapshot, selected_namespace, name.slice(), false) catch |err| {
            if (err == error.HistoricalObjectNotSelected) return try describeView(host, &arena, selected_namespace, name, selection.snapshot, selection.projection);
            return err;
        } else try host.table.call(.{ .lookup = .{ .namespace = host.namespace, .name = name.slice() } });
        defer response.deinit();
        const binding = if (selection.snapshot != null) try c.DirectTableBinding.initCatalog(host.table.connection, response.value.result.historical_catalog.source) else try c.DirectTableBinding.init(host.table.connection, response.value.result.lookup orelse return try describeView(host, &arena, selected_namespace, name, selection.snapshot, selection.projection));
        const projected = if (selection.projection) |target| try c.DirectSchemaProjection.resolve(host.table, binding.interpretation, target) else null;
        defer if (projected) |value| value.deinit();
        const projection = if (projected) |value| value.value.result.schema_projection.prepared.target else null;
        const schema = if (projected) |value| value.value.result.schema_projection.prepared.schema else if (selection.snapshot != null) response.value.result.historical_catalog.source.schema else response.value.result.lookup.?.schema;
        var owned_schema = try f.TableSchema.decode(a, try schema.decode(a, f.TableSchema.max_bytes));
        defer owned_schema.deinit();
        const rows = try describeRows(a, owned_schema.schema);
        return .{ .arena = arena, .name = name, .metadata = binding, .historical_namespace = if (selection.snapshot != null) selected_namespace else null, .rows = rows, .output = &describe_fields, .projection = projection };
    }
    if (try parser.takeWord("EXPLAIN")) {
        if (try g.database.ManagedSql.parse(a, sql[parser.lexer.start..], host.dialect)) |parsed_value| {
            var parsed = parsed_value;
            defer parsed.deinit();
            if (!host.native_profile or host.source != null or selection.snapshot != null or parsed.statement != .create) return error.UnsupportedManagedTable;
            const value = parsed.statement.create;
            const manager: g.direct.ManagedTable = .{ .client = host.table };
            var declared = try manager.prepare(host.namespace, value.name.slice(), 0, 1, value.output.slice(), value.sql, host.readOptions());
            declared.sql = try a.dupe(u8, declared.sql);
            const rows = try a.alloc([]const f.Types.Values.Cell, 1);
            rows[0] = try a.dupe(f.Types.Values.Cell, &.{text(try c.protocol.Json.valueAlloc(a, .{ .consumer = "finite_recomputation", .sources = .{declared.source}, .output = declared.output, .limits = declared.options, .executed = false, .basis = @as(?[]const u8, null) }))});
            return .{ .arena = arena, .managed = declared, .kind = .plan, .rows = rows, .output = &explain_fields };
        }
        var statement = try g.Statement.prepare(host.allocator, &host.table, host.namespace, sql[parser.lexer.start..], host.dialect, .inspection, g.Session.read_options);
        errdefer statement.deinit();
        if (statement.kind() != .select or statement.parameters().len != 0) return error.UnsupportedConstruct;
        const plan = switch (statement.plan) {
            .select => |*selected| blk: {
                const template = &selected.template;
                var bound = try template.bind(host.allocator, template.name, template.descriptor.type, template.basis, &.{}, null);
                defer bound.deinit();
                bound.plan.collations = if (selected.view) |view| .fromTable(view.schema.schema) else selected.collations;
                break :blk try std.json.Stringify.valueAlloc(a, .{
                    .object = selected.binding.interpretation.interpretation.object.object,
                    .traits = f.OperatorTraits.Summary.forExplain(try bound.plan.traits()),
                    .filter = bound.plan.predicate != .all or (if (selected.view) |view| view.plan.plan.predicate != .all else false),
                    .view = selected.binding.view,
                    .view_filter = if (selected.view) |view| f.OperatorTraits.Summary.forExplain(try view.plan.plan.traits()) else null,
                    .aggregate = @tagName(bound.plan.aggregate),
                    .limit = bound.plan.limit,
                    .schema = f.LogicalJson.TypeEnvelope{ .definition = f.Types.definition, .type = statement.output.?.type },
                    .executed = false,
                    .basis = selected.binding.catalog,
                    .projection = selected.projection,
                }, .{});
            },
            .relational => |compilation| try std.json.Stringify.valueAlloc(a, .{
                .traits = f.OperatorTraits.Summary.forExplain(try compilation.plan.traits()),
                .consistency = if (compilation.catalog) |snapshot| @tagName(snapshot.consistency) else "independent_table_snapshots",
                .sources = compilation.plan.sources.len,
                .join = if (compilation.plan.join) |join| @tagName(join.kind) else "none",
                .grouped = compilation.grouped(),
                .group_columns = compilation.plan.group_by.len,
                .schema = f.LogicalJson.TypeEnvelope{ .definition = f.Types.definition, .type = statement.output.?.type },
                .executed = false,
                .basis = compilation.catalog,
                .projections = compilation.projections[0..compilation.plan.sources.len],
            }, .{}),
            else => unreachable,
        };
        const rows = try a.alloc([]const f.Types.Values.Cell, 1);
        rows[0] = try a.dupe(f.Types.Values.Cell, &.{text(plan)});
        return .{ .arena = arena, .statement = statement, .historical_namespace = if (selection.snapshot != null) selected_namespace else null, .kind = .plan, .rows = rows, .output = &explain_fields };
    }
    arena.deinit();
    return null;
}
fn kvDescribeRows(a: std.mem.Allocator, definition: c.DirectKV.Definition) ![]const []const f.Types.Values.Cell {
    const rows = try a.alloc([]const f.Types.Values.Cell, 2);
    const object = definition.interpretation.interpretation.object.object;
    const revision = definition.interpretation.interpretation.revision;
    rows[0] = try a.dupe(f.Types.Values.Cell, &.{
        text("key"), text("UTF8"), boolean(false), boolean(true), .null, .null, unsigned(object), unsigned(revision), unsigned(1),
    });
    rows[1] = try a.dupe(f.Types.Values.Cell, &.{
        text("value"),
        text(switch (definition.spec.value_type) {
            .int64 => "INT64",
            .boolean => "BOOLEAN",
            .utf8 => "UTF8",
            .binary => "BINARY",
        }),
        boolean(definition.spec.nullable),
        boolean(false),
        .null,
        .null,
        unsigned(object),
        unsigned(revision),
        unsigned(2),
    });
    return rows;
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
    if (self.postgres) |*postgres| return postgres.validate(host);
    if (self.connector_list != null or self.connector_proposal != null or self.connector_definition != null) try g.SourceOperations.requireProfile(host);
    if (self.connector_list) |selection| {
        const response = try host.table.call(.{ .namespace = selection.namespace });
        defer response.deinit();
        if (response.value.result.namespace == null or selection.namespace != host.namespace) return error.CatalogIdentityConflict;
    }
    if (self.connector_definition) |definition| {
        const response = try host.table.call(.{ .source = .{ .inspect = definition } });
        defer response.deinit();
    }
    if (self.connector_proposal) |proposal| {
        const response = try host.table.call(.{ .source = .{ .prepare = proposal } });
        defer response.deinit();
        if (response.value.result.source.preview.reason != .none) return error.SourceDeclarationConflict;
    }
    if (self.historical_list) |snapshot| {
        const response = try c.DirectHistory.call(host.table, .{ .list = .{ .snapshot = snapshot, .namespace = self.historical_namespace orelse return error.CatalogIdentityConflict, .after = null } });
        defer response.deinit();
    }
    if (self.managed) |declared| {
        if (self.kind == .plan) {
            _ = try declared.source.require(host.table, .read);
            _ = try declared.output.require(host.table, .read);
        } else {
            const response = try host.table.call(.{ .managed_inspection = .{ .namespace = declared.namespace, .name = declared.name, .expected = try declared.interpretation(self.arena.allocator()), .revision = if (self.managed_revision) |revision| revision.revision else null } });
            defer response.deinit();
            if (self.managed_revision) |revision| try revision.root.requireSame(response.value.result.managed_inspection.completed.?.manifest);
        }
    }
    if (self.node_storage) try validateNode(host);
    if (self.source) {
        const source = host.source orelse return error.UnknownSqlSource;
        try source.current();
        _ = try source.client.describe(source.definition);
    }
    if (self.metadata) |binding| {
        if ((self.historical_namespace orelse host.namespace) != binding.namespace) return error.CatalogIdentityConflict;
        _ = try binding.require(host.table, .inspect);
    }
    if (self.kv_metadata) |binding| {
        if (host.namespace != binding.definition.namespace or !std.meta.eql(host.table.connection, binding.connection)) return error.CatalogIdentityConflict;
        const response = try host.table.call(.{ .kv = .{ .observe = binding.definition.interpretation.interpretation.object } });
        defer response.deinit();
        if (response.value.result.kv.definition.retired or !std.meta.eql(response.value.result.kv.definition.interpretation, binding.definition.interpretation)) return error.CatalogDefinitionChanged;
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
    postgres: ?PgCatalog.Read = null,
    host: *g.Session,
    prepared: *Self,
    index: usize = 0,
    storage_values: [Storage.fields.len]f.Types.Values.Cell = undefined,
    node_observation: g.query.protocol.Storage.Observation = undefined,
    node_values: [Storage.node_fields.len]f.Types.Values.Cell = undefined,
    connector_page: c.DirectSource.Page = .{ .next = null, .position = .{ .partition = 1, .next_lsn = 0 } },
    connector_index: usize = 0,
    connector_loaded: bool = false,
    connector_requests: u64 = 0,
    connector_row: [connector_fields.len]f.Types.Values.Cell = undefined,
    historical_entries: [8]c.DirectHistoryDirectory.Entry = undefined,
    historical_count: usize = 0,
    historical_index: usize = 0,
    historical_after: ?c.DirectHistoryDirectory.Cursor = null,
    historical_loaded: bool = false,
    historical_requests: u64 = 0,
    historical_row: [historical_list_fields.len]f.Types.Values.Cell = undefined,
    subject: ?g.BatchDisclosure.Subject = null,
    pub fn deinit(self: *Read) void {
        if (self.postgres) |*postgres| postgres.deinit();
    }
    pub fn complete(self: *const Read) bool {
        if (self.prepared.postgres != null) return if (self.postgres) |postgres| postgres.done else false;
        if (self.prepared.connector_list != null) return self.connector_loaded and self.connector_page.next == null and (self.connector_index == self.connector_page.entries.len or self.connector_page.entries[self.connector_index] == null);
        if (self.prepared.historical_list != null) return self.historical_loaded and self.historical_after == null and self.historical_index == self.historical_count;
        return self.index == self.prepared.count();
    }
    fn connectorNext(self: *Read, selection: c.DirectSource.Selection) !?[]const f.Types.Values.Cell {
        while (!self.connector_loaded or self.connector_index == self.connector_page.entries.len or self.connector_page.entries[self.connector_index] == null) {
            if (self.complete()) return null;
            if (self.connector_requests >= 10000) return error.QueryPageBudget;
            self.connector_requests += 1;
            const response = try self.host.table.call(.{ .source = .{ .list = .{ .selection = selection, .cursor = self.connector_page.next } } });
            defer response.deinit();
            self.connector_page = response.value.result.source.page;
            self.connector_loaded = true;
            self.connector_index = 0;
        }
        const entry = &self.connector_page.entries[self.connector_index].?;
        const definition = entry.declaration.interpretation;
        const checked = try self.host.table.call(.{ .source = .{ .inspect = definition } });
        defer checked.deinit();
        self.subject = .{ .connector = definition };
        self.connector_row = connectorRow(entry, self.connector_page.position);
        self.connector_index += 1;
        self.index += 1;
        return &self.connector_row;
    }
    fn historicalNext(self: *Read, snapshot: c.protocol.DataLifecycle.Snapshot) !?[]const f.Types.Values.Cell {
        while (self.historical_index == self.historical_count) {
            if (self.complete()) return null;
            if (self.historical_requests >= 10000) return error.QueryPageBudget;
            self.historical_requests += 1;
            const response = try c.DirectHistory.call(self.host.table, .{ .list = .{ .snapshot = snapshot, .namespace = self.prepared.historical_namespace orelse return error.CatalogIdentityConflict, .after = self.historical_after } });
            defer response.deinit();
            const page = response.value.result.historical_catalog.listing;
            @memcpy(self.historical_entries[0..page.entries.len], page.entries);
            self.historical_count = page.entries.len;
            self.historical_index = 0;
            self.historical_after = page.next;
            self.historical_loaded = true;
        }
        const entry = &self.historical_entries[self.historical_index];
        const checked = try c.DirectHistory.call(self.host.table, .{ .source = .{ .snapshot = snapshot, .object = entry.source.interpretation.object.object } });
        defer checked.deinit();
        self.subject = .{ .historical = .{ .snapshot = snapshot, .object = entry.source.interpretation.object.object, .rows = false } };
        self.historical_row = .{ text(entry.properties.name.slice()), unsigned(entry.source.interpretation.object.object), unsigned(entry.source.interpretation.revision) };
        self.historical_index += 1;
        self.index += 1;
        return &self.historical_row;
    }
    pub fn next(self: *Read) !?[]const f.Types.Values.Cell {
        if (self.prepared.postgres) |*prepared| {
            if (self.postgres == null) self.postgres = PgCatalog.Read.init(self.host, prepared);
            const result = try self.postgres.?.next();
            self.subject = self.postgres.?.subject;
            return result;
        }
        self.subject = null;
        // Revalidate the original metadata before advancing this iterator.
        // Concurrent catalog progress can invalidate a pure authority read.
        try self.host.fresh(Self.validate, .{ self.prepared, self.host });
        if (self.prepared.connector_list) |selection| return self.connectorNext(selection);
        if (self.prepared.historical_list) |snapshot| return self.historicalNext(snapshot);
        if (self.complete()) return null;
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

fn describeView(host: *g.Session, arena: *std.heap.ArenaAllocator, namespace: u64, name: c.TableMetadata.Name, snapshot: ?c.protocol.DataLifecycle.Snapshot, projection: ?c.DirectSchemaProjection.Target) !Self {
    if (projection != null) return error.UnsupportedCatalogView;
    if (snapshot == null) {
        const kv_response = try host.table.call(.{ .kv_lookup = .{ .namespace = namespace, .name = name.slice() } });
        defer kv_response.deinit();
        if (kv_response.value.result.kv_lookup) |definition| {
            const rows = try kvDescribeRows(arena.allocator(), definition);
            return .{ .arena = arena.*, .name = name, .kv_metadata = .{ .connection = host.table.connection, .definition = definition }, .rows = rows, .output = &log_describe_fields };
        }
    }
    var sql: std.Io.Writer.Allocating = .init(arena.allocator());
    const quote: u8 = if (host.dialect == .mysql) '`' else '"';
    try sql.writer.writeAll("SELECT * FROM ");
    try sql.writer.writeByte(quote);
    for (name.slice()) |byte| {
        try sql.writer.writeByte(byte);
        if (byte == quote) try sql.writer.writeByte(byte);
    }
    try sql.writer.writeByte(quote);
    if (snapshot) |cut| {
        var selector: [c.DirectHistory.Selector.text_bytes]u8 = undefined;
        try sql.writer.print(" AS OF SNAPSHOT '{s}'", .{try c.DirectHistory.Selector.encode(cut, &selector)});
    }
    var statement = try g.Statement.prepare(host.allocator, &host.table, namespace, sql.written(), host.dialect, .inspection, g.Session.read_options);
    errdefer statement.deinit();
    if (statement.plan != .select or statement.plan.select.view == null) return error.UnsupportedCatalogView;
    const rows = try describeRows(arena.allocator(), statement.plan.select.view.?.schema.schema);
    return .{ .arena = arena.*, .name = name, .statement = statement, .historical_namespace = if (snapshot != null) namespace else null, .rows = rows, .output = &describe_fields };
}

fn prepareConnector(host: *g.Session, statement: g.database.SourceSql.Statement) !Self {
    try g.SourceOperations.requireProfile(host);
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    if (statement == .explain) {
        // Own parser strings beyond the temporary syntax tree.
        const encoded = try c.protocol.Json.valueAlloc(a, statement);
        const copied = try std.json.parseFromSliceLeaky(g.database.SourceSql.Statement, a, encoded, .{ .allocate = .alloc_always });
        const proposal = try g.SourceOperations.proposal(host, &arena, copied);
        const preview = (try c.DirectSourceClient.apply(&arena, host.table, .{ .prepare = proposal })).preview;
        if (preview.reason != .none) return error.SourceDeclarationConflict;
        const rows = try a.alloc([]const f.Types.Values.Cell, 1);
        rows[0] = try a.dupe(f.Types.Values.Cell, &.{text(try c.protocol.Json.valueAlloc(a, .{ .proposal = proposal, .catalog = preview.position, .execution_supported = false, .executed = false, .identity = @as(?u64, null) }))});
        return .{ .arena = arena, .connector_proposal = proposal, .kind = .plan, .rows = rows, .output = &explain_fields };
    }
    if (statement != .inspect) return error.UnsupportedSourceStatement;
    const selection: c.DirectSource.Selection = .{ .namespace = host.namespace, .kind = statement.inspect.kind };
    const name = statement.inspect.name orelse return .{ .arena = arena, .connector_list = selection, .rows = &.{}, .output = &connector_fields };
    const value = try g.SourceOperations.lookup(host, &arena, selection.kind, name);
    const row = try a.alloc(f.Types.Values.Cell, connector_detail_fields.len);
    @memcpy(row[0..connector_fields.len], &connectorRow(&value.state, value.position));
    // The name in the fixed State above is stack-owned; other text already
    // belongs to the result arena.
    row[0] = text(try a.dupe(u8, value.state.declaration.properties.name.slice()));
    row[connector_fields.len] = text(try c.protocol.Json.valueAlloc(a, value.definition));
    row[connector_fields.len + 1] = text(@tagName(value.dependency_state));
    row[connector_fields.len + 2] = .null;
    row[connector_fields.len + 3] = .null;
    const rows = try a.alloc([]const f.Types.Values.Cell, 1);
    rows[0] = row;
    return .{ .arena = arena, .connector_definition = value.state.declaration.interpretation, .rows = rows, .output = &connector_detail_fields };
}
