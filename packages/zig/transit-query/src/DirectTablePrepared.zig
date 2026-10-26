//! Metadata-only SELECT preparation for direct Table storage. The caller owns
//! pin acquisition separately; each execution binds one exact retained source.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const Self = @This();
binding: c.DirectTableBinding,
template: f.LogicalPrepared,
output: f.Types.Decoded,

pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, detail: ?*f.Sql.Binding) !Self {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var location: f.Sql.Location = .{};
    const name = try f.TableSelect.targetDialect(arena.allocator(), text, &location, dialect);
    const response = try client.call(.{ .lookup = .{ .namespace = namespace, .name = name } });
    defer response.deinit();
    const metadata = response.value.result.lookup orelse return error.TableNotFound;
    const binding = try c.DirectTableBinding.init(client.connection, metadata);
    _ = try binding.require(client, .read);
    var schema = try f.TableSchema.decode(allocator, try metadata.schema.decode(arena.allocator(), f.TableSchema.max_bytes));
    defer schema.deinit();
    try q.DirectTableQuery.qualify(schema.schema);
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const row_type = try schema.schema.rowType(&fields);
    const basis = try binding.fingerprint(allocator);
    var template = try f.LogicalPrepared.initDialect(allocator, text, name, row_type, basis, detail, dialect);
    errdefer template.deinit();
    var witnesses: [f.LogicalPrepared.max_parameters]?f.Types.Values.Atom = undefined;
    for (template.parameterTypes(), witnesses[0..template.count]) |kind, *value| value.* = try f.LogicalPrepared.witness(kind);
    var prototype = try template.bind(allocator, name, row_type, basis, witnesses[0..template.count], detail);
    defer prototype.deinit();
    var output_fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var output = try (try prototype.plan.outputSchema(&output_fields)).clone(allocator);
    errdefer output.deinit();
    _ = try binding.require(client, .read);
    return .{ .binding = binding, .template = template, .output = output };
}
pub fn parameterTypes(self: *const Self) []const f.Types.Type {
    return self.template.parameterTypes();
}
pub fn deinit(self: *Self) void {
    self.output.deinit();
    self.template.deinit();
    self.* = undefined;
}
/// Pure binding to a captured source. This grants no access and obtains no pin.
pub fn instantiate(self: *const Self, allocator: std.mem.Allocator, connection: c.DirectTableProtocol.Connection, interpretation: c.storage.TableDeclaration.Stored, schema: f.TableSchema.Schema, captured_basis: [32]u8, values: []const ?f.Types.Values.Atom, detail: ?*f.Sql.Binding) !f.TableSelect.Owned {
    try self.binding.validate();
    if (!std.meta.eql(self.binding.connection, connection)) return error.CatalogIdentityConflict;
    if (!std.meta.eql(self.binding.interpretation, interpretation) or !std.mem.eql(u8, &try schema.fingerprint(), &interpretation.schema_fingerprint)) return error.TableDefinitionChanged;
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const name = try arena.allocator().dupe(u8, self.template.name);
    var bound = try self.template.instantiate(allocator, name, try schema.rowType(&fields), try self.binding.fingerprint(allocator), captured_basis, values, detail);
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
