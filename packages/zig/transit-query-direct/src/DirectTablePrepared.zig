//! Metadata-only SELECT preparation for direct Table storage. The caller owns
//! pin acquisition separately; each execution binds one exact retained source.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const Self = @This();
binding: c.DirectTableBinding,
metadata: ?c.DirectTableProtocol.Definition = null,
template: f.LogicalPrepared,
output: f.Types.Decoded,
collations: f.QueryCollations = .{},
projection: ?c.DirectSchemaProjection.Accepted = null,
view: ?@import("DirectView.zig") = null,

pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, detail: ?*f.Sql.Binding) !Self {
    return prepareAccess(allocator, client, namespace, text, dialect, detail, .read);
}
pub fn prepareAccess(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, detail: ?*f.Sql.Binding, access: c.TableAuthority.Access) !Self {
    return prepareAt(allocator, client, namespace, text, dialect, detail, access, null);
}
pub fn prepareAt(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, detail: ?*f.Sql.Binding, access: c.TableAuthority.Access, snapshot: ?q.protocol.DataLifecycle.Snapshot) !Self {
    return prepareProjectedAt(allocator, client, namespace, text, dialect, detail, access, snapshot, null);
}
pub fn prepareProjectedAt(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, detail: ?*f.Sql.Binding, access: c.TableAuthority.Access, snapshot: ?q.protocol.DataLifecycle.Snapshot, projection: ?c.DirectSchemaProjection.Target) !Self {
    if (snapshot != null and client.transaction != null) return error.UnsupportedHistoricalTransaction;
    if (access != .read and access != .inspect) return error.InvalidQueryAccess;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var location: f.Sql.Location = .{};
    const name = try f.TableSelect.targetDialect(arena.allocator(), text, &location, dialect);
    const response = if (snapshot) |cut| c.DirectHistory.resolve(client, cut, namespace, name, access == .read) catch |err| {
        if (err == error.HistoricalObjectNotSelected) return prepareView(allocator, client, namespace, name, text, dialect, detail, access, snapshot, projection);
        return err;
    } else try client.call(.{ .lookup = .{ .namespace = namespace, .name = name } });
    defer response.deinit();
    const metadata: c.DirectTableProtocol.Definition = if (snapshot != null) blk: {
        const source = response.value.result.historical_catalog.source;
        break :blk .{ .interpretation = source.binding.declaration, .namespace = source.binding.namespace.id, .authorization = source.binding.properties.authorization, .name = source.binding.properties.name, .position = source.binding.source.accepted, .changed_lsn = source.changed_lsn, .row_count = source.rows, .schema = source.schema };
    } else response.value.result.lookup orelse return prepareView(allocator, client, namespace, name, text, dialect, detail, access, snapshot, projection);
    var binding = try c.DirectTableBinding.init(client.connection, metadata);
    binding.catalog = snapshot;
    _ = try binding.require(client, access);
    const projected = if (projection) |target| try c.DirectSchemaProjection.resolve(client, binding.interpretation, target) else null;
    defer if (projected) |value| value.deinit();
    const target = if (projected) |value| value.value.result.schema_projection.prepared.target else null;
    const schema_bytes = if (projected) |value| value.value.result.schema_projection.prepared.schema else metadata.schema;
    var schema = try f.TableSchema.decode(allocator, try schema_bytes.decode(arena.allocator(), f.TableSchema.max_bytes));
    defer schema.deinit();
    try q.DirectTableQuery.qualify(schema.schema);
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const row_type = try schema.schema.rowType(&fields);
    const basis = try preparationBasis(allocator, binding, target);
    var semantics: [f.TableSchema.max_columns]f.ColumnSemantics = undefined;
    for (schema.schema.columns, semantics[0..schema.schema.columns.len]) |column, *value| value.* = column.semantics;
    var template = try f.LogicalPrepared.initSemantics(allocator, text, name, row_type, basis, detail, dialect, semantics[0..schema.schema.columns.len]);
    errdefer template.deinit();
    var witnesses: [f.LogicalPrepared.max_parameters]?f.Types.Values.Atom = undefined;
    for (template.parameterTypes(), witnesses[0..template.count]) |kind, *value| value.* = try f.LogicalPrepared.witness(kind);
    var prototype = try template.bind(allocator, name, row_type, basis, witnesses[0..template.count], detail);
    defer prototype.deinit();
    var output_fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var output = try (try prototype.plan.outputSchema(&output_fields)).clone(allocator);
    errdefer output.deinit();
    _ = try binding.require(client, access);
    var stored_metadata = metadata;
    stored_metadata.schema = .{ .base64 = "" };
    return .{ .binding = binding, .metadata = stored_metadata, .template = template, .output = output, .collations = .fromTable(schema.schema), .projection = target };
}
fn preparationBasis(allocator: std.mem.Allocator, binding: c.DirectTableBinding, target: ?c.DirectSchemaProjection.Accepted) ![32]u8 {
    const source = try binding.fingerprint(allocator);
    const projection = target orelse return source;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.table.prepared.projection.v1\x00");
    hash.update(&source);
    const bytes = try projection.encode();
    hash.update(bytes.slice());
    return hash.finalResult();
}
pub fn parameterTypes(self: *const Self) []const f.Types.Type {
    return self.template.parameterTypes();
}
pub fn deinit(self: *Self) void {
    if (self.view) |*value| value.deinit();
    self.output.deinit();
    self.template.deinit();
    self.* = undefined;
}
/// Pure binding to a captured source. This grants no access and obtains no pin.
pub fn instantiate(self: *const Self, allocator: std.mem.Allocator, connection: c.DirectTableProtocol.Connection, interpretation: c.storage.TableDeclaration.Stored, schema: f.TableSchema.Schema, captured_basis: [32]u8, values: []const ?f.Types.Values.Atom, detail: ?*f.Sql.Binding) !f.TableSelect.Owned {
    try self.binding.validate();
    if (!std.meta.eql(self.binding.connection, connection)) return error.CatalogIdentityConflict;
    if (!std.meta.eql(self.binding.interpretation, interpretation) or !std.mem.eql(u8, &try schema.fingerprint(), &(if (self.projection) |target| target.declaration.schema_fingerprint else interpretation.schema_fingerprint))) return error.TableDefinitionChanged;
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const name = try arena.allocator().dupe(u8, self.template.name);
    var bound = try self.template.instantiate(allocator, name, if (self.view) |view| try view.schema.schema.rowType(&fields) else try schema.rowType(&fields), try preparationBasis(allocator, self.binding, self.projection), captured_basis, values, detail);
    if (self.view) |view| {
        const expanded = view.expand(allocator, bound.plan) catch |err| {
            bound.deinit();
            return err;
        };
        bound.deinit();
        bound = expanded;
    }
    errdefer bound.deinit();
    bound.plan.collations = .fromTable(schema);
    try bound.plan.validate();
    return .{ .arena = arena, .name = name, .descriptor = bound.descriptor, .plan = bound.plan };
}

test "direct SELECT preparation separates complete caller identity from captured data" {
    const t = std.testing;
    const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64 }};
    const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns };
    const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 1 }, .branch = 1, .audience = 5, .principal = 4, .role = null };
    var declaration = try c.storage.TableDeclaration.prepare(t.allocator, .{ .object = .{ .scope = connection.scope, .branch = 1, .object = 7 }, .revision = 1, .schema = schema, .properties = "" });
    defer declaration.deinit();
    const binding: c.DirectTableBinding = .{ .definition = q.protocol.Growth.current_definition, .connection = connection, .namespace = 1, .name = try .init("events"), .interpretation = try declaration.stored() };
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const row_type = try schema.rowType(&fields);
    var prepared: Self = .{ .binding = binding, .template = try f.LogicalPrepared.init(t.allocator, "SELECT id FROM events WHERE id = $1", "events", row_type, try binding.fingerprint(t.allocator), null), .output = try row_type.clone(t.allocator) };
    defer prepared.deinit();
    var compiled = try prepared.instantiate(t.allocator, connection, binding.interpretation, schema, @splat(9), &.{.{ .signed = 42 }}, null);
    defer compiled.deinit();
    try t.expectEqual(@as([32]u8, @splat(9)), compiled.plan.source_basis);
    var other = binding;
    other.connection.role = 0;
    try t.expect(!std.mem.eql(u8, &try binding.fingerprint(t.allocator), &try other.fingerprint(t.allocator)));
    try t.expectError(error.CatalogIdentityConflict, prepared.instantiate(t.allocator, other.connection, binding.interpretation, schema, @splat(9), &.{.{ .signed = 42 }}, null));
    other = binding;
    other.namespace = 2;
    try t.expect(!std.mem.eql(u8, &try binding.fingerprint(t.allocator), &try other.fingerprint(t.allocator)));
    other = binding;
    other.interpretation.interpretation.revision += 1;
    try t.expectError(error.TableDefinitionChanged, prepared.instantiate(t.allocator, connection, other.interpretation, schema, @splat(9), &.{.{ .signed = 42 }}, null));
}

fn prepareView(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, name: []const u8, text: []const u8, dialect: f.Sql.Dialect, detail: ?*f.Sql.Binding, access: c.TableAuthority.Access, snapshot: ?q.protocol.DataLifecycle.Snapshot, projection: ?c.DirectSchemaProjection.Target) !Self {
    if (projection != null or client.transaction != null) return error.UnsupportedCatalogView;
    const response = try c.DirectDefinition.call(client, if (snapshot) |cut| .{ .historical = .{ .snapshot = cut, .namespace = namespace, .name = try .init(name), .rows = access == .read } } else .{ .lookup = .{ .namespace = namespace, .name = try .init(name) } });
    defer response.deinit();
    const value = if (snapshot != null) (response.value.result.descriptor.historical orelse return error.HistoricalObjectNotSelected).value else response.value.result.descriptor.definition orelse return error.TableNotFound;
    if (value.body != .view or value.sources.len != 1) return error.UnsupportedCatalogView;
    const stored = try value.stored(allocator);
    const dependency = value.sources[0];
    const source_response = if (snapshot) |cut| try c.DirectHistory.call(client, .{ .source = .{ .snapshot = cut, .object = dependency.declaration.interpretation.object.object, .rows = access == .read } }) else try client.call(.{ .lookup = .{ .namespace = dependency.properties.namespace, .name = dependency.properties.name.slice() } });
    defer source_response.deinit();
    const metadata: c.DirectTableProtocol.Definition = if (snapshot != null) blk: {
        const source = source_response.value.result.historical_catalog.source;
        break :blk .{ .interpretation = source.binding.declaration, .namespace = source.binding.namespace.id, .authorization = source.binding.properties.authorization, .name = source.binding.properties.name, .position = source.binding.source.accepted, .changed_lsn = source.changed_lsn, .row_count = source.rows, .schema = source.schema };
    } else source_response.value.result.lookup orelse return error.TableDefinitionChanged;
    if (!std.meta.eql(metadata.interpretation, dependency.declaration) or !std.mem.eql(u8, metadata.schema.base64, dependency.schema.base64)) return error.TableDefinitionChanged;
    var binding = try c.DirectTableBinding.init(client.connection, metadata);
    binding.catalog = snapshot;
    binding.view = stored.interpretation;
    _ = try binding.require(client, access);
    var view_schema = try c.CatalogDefinition.decodeSchema(allocator, value.schema);
    errdefer view_schema.deinit();
    var source_schema = try c.CatalogDefinition.decodeSchema(allocator, dependency.schema);
    defer source_schema.deinit();
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const plan_bytes = try value.body.view.plan.decode(allocator, f.LogicalPlanCodec.max_bytes);
    defer allocator.free(plan_bytes);
    var view_plan = try f.LogicalPlanCodec.decode(allocator, try source_schema.schema.rowType(&fields), dependency.declaration.interpretation.digest, plan_bytes);
    errdefer view_plan.deinit();
    var semantics: [f.TableSchema.max_columns]f.ColumnSemantics = undefined;
    for (view_schema.schema.columns, semantics[0..view_schema.schema.columns.len]) |column_value, *out| out.* = column_value.semantics;
    var template = try f.LogicalPrepared.initSemantics(allocator, text, name, try view_schema.schema.rowType(&fields), try preparationBasis(allocator, binding, null), detail, dialect, semantics[0..view_schema.schema.columns.len]);
    errdefer template.deinit();
    var output = try template.outputSchema(allocator);
    errdefer output.deinit();
    _ = try binding.require(client, access);
    var stored_metadata = metadata;
    stored_metadata.schema = .{ .base64 = "" };
    return .{ .binding = binding, .metadata = stored_metadata, .template = template, .output = output, .collations = .fromTable(source_schema.schema), .view = .{ .stored = stored, .schema = view_schema, .plan = view_plan } };
}
