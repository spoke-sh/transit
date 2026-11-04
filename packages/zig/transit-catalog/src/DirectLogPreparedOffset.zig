//! Bind explicit Stream progress to the current named declaration. Native
//! admission checks cursor authentication, the live pin and current assignment.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const p = c.protocol;
const w = c.DirectTableProtocol;
const Self = @This();
connection: w.Connection,
definition: c.DirectLog.Definition,
declaration: c.storage.LogDeclaration.Owned,
compiled: f.LogOffsetSql.Prepared,

pub fn prepare(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    const target = try f.LogOffsetSql.target(scratch.allocator(), text, dialect, location);
    const response = try client.call(.{ .log_lookup = .{ .namespace = namespace, .name = target.name } });
    defer response.deinit();
    return init(allocator, client.connection, namespace, text, response.value.result.log_lookup orelse return error.CatalogNameNotFound, dialect, location);
}
pub fn init(allocator: std.mem.Allocator, connection: w.Connection, namespace: u64, text: []const u8, metadata: c.DirectLogProtocol.Definition, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Self {
    try connection.validate();
    var declaration = try c.DirectLogProtocol.decodeMetadata(allocator, connection, metadata);
    errdefer declaration.deinit();
    if (metadata.declaration.properties.namespace != namespace or metadata.declaration.stored.retired) return error.CatalogDefinitionChanged;
    if (metadata.declaration.kind() != .stream) return error.CatalogKindMismatch;
    var compiled = try f.LogOffsetSql.Prepared.init(allocator, text, dialect, location);
    errdefer compiled.deinit();
    if (!std.mem.eql(u8, metadata.declaration.properties.name.slice(), compiled.source.name)) return error.CatalogDefinitionChanged;
    return .{ .connection = connection, .definition = metadata.declaration, .declaration = declaration, .compiled = compiled };
}
pub fn deinit(self: *Self) void {
    self.compiled.deinit();
    self.declaration.deinit();
    self.* = undefined;
}
pub fn validate(self: *const Self, client: c.DirectTableClient) !void {
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    try c.DirectLogClient.requireCurrent(client, self.definition);
}
pub fn checkValues(self: *const Self, allocator: std.mem.Allocator, values: []const ?f.Types.Values.Atom, diagnostic: ?*f.Sql.Binding) !p.StreamHandle.Progress {
    const bound = try self.compiled.bind(allocator, values, diagnostic);
    const target = bound.receipt.request.target;
    const declared = self.definition.stored.declaration;
    try self.connection.object(target.interpretation.object);
    if (bound.receipt.request.operation.principal != self.connection.principal or
        !std.meta.eql(target.interpretation.object, declared.interpretation.object) or
        target.partition >= declared.configuration.partitioning.count or
        target.interpretation.revision > declared.interpretation.revision or
        (target.interpretation.revision == declared.interpretation.revision and
            !std.meta.eql(target.interpretation, declared.interpretation))) return error.InvalidStreamHandle;
    return bound;
}
pub fn bindPrepared(self: *const Self, allocator: std.mem.Allocator, client: c.DirectTableClient, operation: u64, values: []const ?f.Types.Values.Atom, diagnostic: ?*f.Sql.Binding, fresh: bool) !c.DirectWorkloadIntent {
    if (!fresh) try self.validate(client) else if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    return self.freeze(allocator, operation, values, diagnostic);
}
pub fn freeze(self: *const Self, allocator: std.mem.Allocator, operation: u64, values: []const ?f.Types.Values.Atom, diagnostic: ?*f.Sql.Binding) !c.DirectWorkloadIntent {
    const bound = try self.checkValues(allocator, values, diagnostic);
    const work: c.DirectWorkloadIntent.Work = .{ .stream = .{ .work = .{ .offset = try bound.settlement(.{ .scope = self.connection.scope, .principal = self.connection.principal, .operation = operation }) }, .payload = null } };
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    var schema_buffer: [f.TableSchema.max_bytes]u8 = undefined;
    const metadata: c.DirectLogProtocol.Definition = .{ .declaration = self.definition, .schema = try w.Binary.encode(scratch.allocator(), try self.declaration.definition.schema.encode(&schema_buffer)) };
    return c.DirectWorkloadIntent.create(allocator, self.connection, metadata, work);
}
