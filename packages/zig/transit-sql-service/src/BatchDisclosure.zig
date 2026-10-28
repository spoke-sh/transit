//! Bounded authority subjects retained with a metadata batch. A prior row check
//! cannot authorize later disclosure or repetition after buffering.
const std = @import("std");
const g = @import("root.zig");
const Self = @This();
pub const Subject = union(enum) {
    table: g.catalog.protocol.DataLifecycle.Definition,
    namespace: g.catalog.TableAuthority.Schema,
    database: g.DatabaseAccount.Binding,
};
subjects: [g.ReadBatch.max_rows]?Subject = @splat(null),
len: u8 = 0,
origins: bool = false,
pub fn append(self: *Self, subject: ?Subject) !void {
    const value = subject orelse return;
    if (self.len == self.subjects.len) return error.InvalidReadBatch;
    self.subjects[self.len] = value;
    self.len += 1;
}
pub fn validate(self: Self, host: *g.Session, prepared: *g.Session.Prepared) !void {
    try host.validate(prepared);
    if (self.origins) {
        const settings = try @import("SessionSettings.zig").client(host);
        if (!try host.freshOn(.settings, g.query.SettingsClient.canSeeOrigins, .{settings})) return error.ConfigurationDenied;
    }
    for (self.subjects[0..self.len]) |slot| switch (slot.?) {
        .table => |definition| {
            _ = try host.table.require(.{ .namespace = host.namespace, .target = definition, .access = .inspect });
        },
        .namespace => |namespace| {
            const response = try host.table.call(.{ .namespace = namespace.id });
            defer response.deinit();
            if (response.value.result.namespace == null or !std.meta.eql(namespace, response.value.result.namespace.?)) return error.CatalogIdentityConflict;
        },
        .database => |binding| {
            var table = host.table;
            table.connection.scope.resource = binding.resource;
            table.connection.scope.catalog = binding.catalog;
            table.connection.audience = binding.owner;
            table.connection.role = binding.role;
            _ = try table.require(.{ .namespace = null, .target = null, .access = .database });
        },
    };
}
