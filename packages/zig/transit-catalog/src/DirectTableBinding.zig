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

pub fn init(connection: w.Connection, metadata: w.Definition) !Self {
    const result: Self = .{ .definition = p.Growth.current_definition, .connection = connection, .namespace = metadata.namespace, .name = metadata.name, .interpretation = metadata.interpretation };
    try result.validate();
    return result;
}
pub fn validate(self: Self) !void {
    if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try self.connection.validate();
    try c.Model.nativeId(self.namespace);
    try self.name.validate();
    try self.interpretation.validate();
    try self.connection.object(self.interpretation.interpretation.object);
    if (self.interpretation.retired) return error.TableDefinitionChanged;
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
    return client.require(.{ .namespace = self.namespace, .target = self.interpretation.interpretation, .access = access });
}
