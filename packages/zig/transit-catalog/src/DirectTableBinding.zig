//! Metadata-only prepared binding. It names an exact interpretation, not a data
//! snapshot or an authorization ticket; row progress may change independently.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const w = c.DirectTableProtocol;
const Self = @This();
definition: p.Growth.Definition,
connection: w.Connection,
namespace: u64,
name: c.TableAuthority.Name,
interpretation: c.storage.TableDeclaration.Stored,
catalog: ?p.DataLifecycle.Snapshot = null,
/// Accepted view interpretation; its current rights are independent of source rights.
view: ?p.DataLifecycle.Definition = null,

pub fn init(connection: w.Connection, metadata: w.Definition) !Self {
    const result: Self = .{ .definition = p.Growth.current_definition, .connection = connection, .namespace = metadata.namespace, .name = metadata.name, .interpretation = metadata.interpretation };
    try result.validate();
    return result;
}
pub fn initCatalog(connection: w.Connection, source: c.DirectHistory.Source) !Self {
    const value: Self = .{ .definition = p.Growth.current_definition, .connection = connection, .namespace = source.binding.namespace.id, .name = source.binding.properties.name, .interpretation = source.binding.declaration, .catalog = source.snapshot };
    try value.validate();
    return value;
}
pub fn validate(self: Self) !void {
    if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try self.connection.validate();
    try c.Model.nativeId(self.namespace);
    try self.name.validate();
    try self.interpretation.validate();
    if (self.interpretation.kind != .table) return error.InvalidTableResponse;
    try self.connection.object(self.interpretation.interpretation.object);
    if (self.interpretation.retired) return error.TableDefinitionChanged;
    if (self.view) |definition| {
        try definition.validate();
        try self.connection.object(definition.object);
        if (definition.object.object == self.interpretation.interpretation.object.object) return error.InvalidCatalogDescriptor;
    }
    if (self.catalog) |snapshot| {
        try (c.DirectHistory.Request{ .source = .{ .snapshot = snapshot, .object = self.interpretation.interpretation.object.object } }).validate(self.connection);
    }
}
pub fn fingerprint(self: Self, allocator: std.mem.Allocator) ![32]u8 {
    try self.validate();
    const bytes = try p.Json.valueAlloc(allocator, self);
    defer allocator.free(bytes);
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    digest.update("transit.table.direct.preparation.v1\x00");
    digest.update(bytes);
    return digest.finalResult();
}
/// A local binding comparison never substitutes for current permission checks.
pub fn check(self: Self, connection: w.Connection, metadata: w.Definition) !void {
    try self.validate();
    if (!std.meta.eql(self.connection, connection)) return error.CatalogIdentityConflict;
    if (self.namespace != metadata.namespace or !std.meta.eql(self.name, metadata.name) or !std.meta.eql(self.interpretation, metadata.interpretation)) return error.TableDefinitionChanged;
}
/// Read-only current validation. The owner serializes this against definition
/// changes and rechecks current native rights before returning its subject.
pub fn require(self: Self, client: c.DirectTableClient, access: c.TableAuthority.Access) !p.Authorization.Verified {
    try self.validate();
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    if (self.view) |definition| {
        if (access != .read and access != .inspect) return error.UnsupportedCatalogView;
        const response = try client.call(.{ .descriptor = .{ .authorize = .{ .interpretation = definition, .rows = access == .read } } });
        response.deinit();
    }
    if (self.catalog) |snapshot| {
        if (access != .read and access != .inspect) return error.HistoricalReadOnly;
        const response = try c.DirectHistory.call(client, .{ .source = .{ .snapshot = snapshot, .object = self.interpretation.interpretation.object.object, .rows = access == .read } });
        defer response.deinit();
        const source = response.value.result.historical_catalog.source;
        if (self.namespace != source.binding.namespace.id or !std.meta.eql(self.name, source.binding.properties.name) or !std.meta.eql(self.interpretation, source.binding.declaration)) return error.HistoricalIdentityConflict;
        return response.value.subject;
    }
    return client.require(.{ .namespace = self.namespace, .target = self.interpretation.interpretation, .access = access });
}
