//! Prepared general Table SELECT. Metadata is immutable; every execution owns
//! a newly captured cut. No snapshot, native sequence or upload exists at prepare.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const Self = @This();
binding: c.TableBinding,
template: f.LogicalPrepared,
output: f.Types.Decoded,

pub fn prepare(allocator: std.mem.Allocator, client: *c.TableClient, text: []const u8, dialect: f.Sql.Dialect, detail: ?*f.Sql.Binding) !Self {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    var location: f.Sql.Location = .{};
    const name = try c.TableMetadata.Name.init(try f.TableSelect.targetDialect(arena.allocator(), text, &location, dialect));
    const before = try client.describe();
    if (!before.policy.permits(.read)) return error.CatalogDenied;
    var definition = (try client.lookup(allocator, name)) orelse return error.TableNotFound;
    defer definition.deinit();
    const binding = try c.TableBinding.init(client.connection, definition.metadata);
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const schema = try definition.schema.schema.rowType(&fields);
    const basis = try binding.fingerprint();
    var template = try f.LogicalPrepared.initDialect(allocator, text, name.slice(), schema, basis, detail, dialect);
    errdefer template.deinit();
    var witnesses: [f.LogicalPrepared.max_parameters]?f.Types.Values.Atom = undefined;
    for (template.parameterTypes(), witnesses[0..template.count]) |kind, *value| value.* = try f.LogicalPrepared.witness(kind);
    var prototype = try template.bind(allocator, name.slice(), schema, basis, witnesses[0..template.count], detail);
    defer prototype.deinit();
    var output_fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var output = try (try prototype.plan.outputSchema(&output_fields)).clone(allocator);
    errdefer output.deinit();
    if (!std.meta.eql(before, try client.describe())) return error.CatalogDefinitionChanged;
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
/// Takes an already-authorized captured identity, not a previously bound plan.
/// The query owner controls acquisition and current disclosure validation.
pub fn instantiate(self: *const Self, allocator: std.mem.Allocator, connection: c.TableClient.Connection, definition: c.TableCatalog.Definition, captured_basis: [32]u8, values: []const ?f.Types.Values.Atom, detail: ?*f.Sql.Binding) !f.TableSelect.Owned {
    try self.binding.check(connection, definition.metadata);
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const name = try arena.allocator().dupe(u8, self.template.name);
    const bound = try self.template.instantiate(allocator, name, try definition.schema.schema.rowType(&fields), try self.binding.fingerprint(), captured_basis, values, detail);
    return .{ .arena = arena, .name = name, .descriptor = bound.descriptor, .plan = bound.plan };
}
