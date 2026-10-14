//! Authorized DML preparation over immutable catalog metadata. Preparing and
//! binding are read-only; an exact returned TableIntent owns later recovery.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const Self = @This();
binding: c.TableBinding,
template: f.TableDmlPrepared,

pub fn prepare(allocator: std.mem.Allocator, client: *c.TableClient, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const target = try f.TableDml.targetDialect(arena.allocator(), text, location, dialect);
    const before = try client.describe();
    if (!before.policy.permits(right(target.kind))) return error.CatalogDenied;
    var definition = (try client.lookup(allocator, try c.TableMetadata.Name.init(target.name))) orelse return error.TableNotFound;
    defer definition.deinit();
    var result: Self = .{
        .binding = try c.TableBinding.init(client.connection, definition.metadata),
        .template = try f.TableDmlPrepared.init(allocator, text, target.name, definition.schema.schema, dialect, location),
    };
    errdefer result.deinit();
    if (!std.meta.eql(before, try client.describe())) return error.CatalogDefinitionChanged;
    return result;
}
pub fn right(action: std.meta.Tag(f.TableDml.Action)) c.TableCatalogRecords.Right {
    return switch (action) {
        .insert => .insert,
        .update => .update,
        .delete => .delete,
    };
}
pub fn deinit(self: *Self) void {
    self.template.deinit();
    self.* = undefined;
}
pub fn parameterTypes(self: *const Self) []const f.Types.Type {
    return self.template.parameterTypes();
}
/// Fresh execution identity only. Recovery never calls this method again.
pub fn bind(self: *const Self, allocator: std.mem.Allocator, client: *c.TableClient, values: []const ?f.Types.Values.Atom, identity: c.TableClient.CompileIdentity, location: ?*f.Sql.Location) !c.TableIntent {
    if (identity.operation == 0 or identity.namespace == 0 or identity.create_object != null) return error.InvalidCatalogIdentity;
    const before = try client.describe();
    if (!before.policy.permits(right(self.template.syntax.subject.kind))) return error.CatalogDenied;
    var definition = (try client.lookup(allocator, self.binding.metadata.name)) orelse return error.TableNotFound;
    defer definition.deinit();
    try self.binding.check(client.connection, definition.metadata);
    var plan = try self.template.bind(allocator, self.template.name, definition.schema.schema, values, location);
    defer plan.deinit();
    const request: c.TableDmlRequest = .{
        .principal = client.connection.principal,
        .operation = identity.operation,
        .metadata = .{ .id = definition.metadata.revision, .spec = try definition.metadata.spec() },
        .plan = plan.plan,
    };
    var result = try c.TableIntent.create(allocator, try c.TableCommand.fromDml(client.connection.scope, client.connection.owner, request, definition.metadata), identity.namespace);
    errdefer result.deinit();
    if (!std.meta.eql(before, try client.describe())) return error.CatalogDefinitionChanged;
    return result;
}
