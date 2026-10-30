//! Read-only preparation and parameter binding over the direct Table owner.
//! Each bind returns independent frozen work; recovery uses that saved intent.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const Self = @This();
binding: c.DirectTableBinding,
template: f.TableDmlPrepared,

pub fn right(action: std.meta.Tag(f.TableDml.Action)) c.TableAuthority.Access {
    return switch (action) {
        .insert => .insert,
        .update => .update,
        .delete => .delete,
    };
}
pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const target = try f.TableDml.targetDialect(arena.allocator(), text, location, dialect);
    const response = try client.call(.{ .lookup = .{ .namespace = namespace, .name = target.name } });
    defer response.deinit();
    const metadata = response.value.result.lookup orelse return error.TableNotFound;
    const binding = try c.DirectTableBinding.init(client.connection, metadata);
    _ = try binding.require(client, right(target.kind));
    var schema = try f.TableSchema.decode(allocator, try metadata.schema.decode(arena.allocator(), f.TableSchema.max_bytes));
    defer schema.deinit();
    const template = try f.TableDmlPrepared.init(allocator, text, target.name, schema.schema, dialect, location);
    return .{ .binding = binding, .template = template };
}
pub fn parameterTypes(self: *const Self) []const f.Types.Type {
    return self.template.parameterTypes();
}
pub fn deinit(self: *Self) void {
    self.template.deinit();
    self.* = undefined;
}
/// New work only. No operation admission or pin acquisition occurs here. The
/// supplied ID and returned complete bytes must survive an uncertain dispatch.
pub fn bind(self: *const Self, allocator: std.mem.Allocator, client: c.DirectTableClient, operation: u64, values: []const ?f.Types.Values.Atom, ingestion: c.storage.TablePartition.Ingestion, location: ?*f.Sql.Location) !c.DirectTableIntent {
    if (operation == 0) return error.InvalidDataOperation;
    if (!std.meta.eql(self.binding.connection, client.connection)) return error.CatalogIdentityConflict;
    const response = try client.call(.{ .lookup = .{ .namespace = self.binding.namespace, .name = self.binding.name.slice() } });
    defer response.deinit();
    const metadata = response.value.result.lookup orelse return error.TableNotFound;
    try self.binding.check(client.connection, metadata);
    _ = try self.binding.require(client, right(self.template.syntax.subject.kind));
    var plan = try self.template.bind(allocator, self.template.name, self.template.schema.schema, values, location);
    defer plan.deinit();
    return c.DirectTableIntent.fromDml(allocator, client.connection, metadata, operation, plan.plan, ingestion);
}
