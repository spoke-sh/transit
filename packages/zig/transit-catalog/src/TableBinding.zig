//! Immutable preparation identity. Resource data revisions are deliberately
//! absent; Table replacement/schema/name changes and caller changes are not.
const std = @import("std");
const c = @import("root.zig");
const Self = @This();
connection: c.TableClient.Connection,
metadata: c.TableMetadata.Record,
pub fn init(connection: c.TableClient.Connection, metadata: c.TableMetadata.Record) !Self {
    try connection.validate();
    try metadata.validate();
    if (!std.meta.eql(connection.scope, metadata.scope)) return error.CatalogIdentityConflict;
    return .{ .connection = connection, .metadata = metadata };
}
pub fn fingerprint(self: Self) ![32]u8 {
    var hash: std.crypto.hash.sha2.Sha256 = .init(.{});
    hash.update("transit.table.preparation.v1\x00");
    hash.update(@tagName(c.protocol.Growth.current_definition));
    const spec = try self.metadata.spec();
    hash.update(&spec.digest);
    inline for (.{ self.connection.scope.realm, self.connection.scope.resource, self.connection.scope.catalog, self.connection.owner, self.connection.principal }) |value| {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, value, .little);
        hash.update(&bytes);
    }
    return hash.finalResult();
}
pub fn check(self: Self, connection: c.TableClient.Connection, metadata: c.TableMetadata.Record) !void {
    const current = try init(connection, metadata);
    if (!std.mem.eql(u8, &try self.fingerprint(), &try current.fingerprint())) return error.CatalogDefinitionChanged;
}
