//! SQL command projection over the database-owned frozen intent contract.
const c = @import("root.zig").catalog;
const g = @import("root.zig");
pub const Reference = c.DirectIntent.Reference;
pub const NamespaceChange = c.DirectIntent.NamespaceChange;
pub const max_bytes = c.DirectIntent.max_bytes;
pub const prefix_bytes = c.DirectIntent.prefix_bytes;
pub const encode = c.DirectIntent.encode;
pub const decode = c.DirectIntent.decode;
pub const bindingDigest = c.DirectIntent.bindingDigest;
pub const assertionDigest = c.DirectIntent.assertionDigest;
pub const namespaceDigest = c.DirectIntent.namespaceDigest;
pub fn commandKind(self: Reference) !g.results.Command {
    return switch (self) {
        .external => error.ExternalOperationOwnerRequired,
        .transaction => error.TransactionOperationRequired,
        .transaction_call => |call| g.TransactionWork.command(call),
        .table => |value| switch (value.binding.action) {
            .create => .create_table,
            .alter, .rename => .alter_table,
            .drop => .drop_table,
            .insert => .insert,
            .update => .update,
            .delete => .delete,
        },
        .name_assertion => |value| switch (value.action) {
            .create_if_not_exists => .create_table,
            .drop_if_exists => .drop_table,
        },
        .namespace_change => |value| switch (value.binding.action) {
            .create => .create_schema,
            .rename => .alter_schema,
            .drop => .drop_schema,
        },
    };
}
