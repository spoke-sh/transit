//! Catalog scope and native identity validation; names never confer authority.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
pub const Scope = p.DataLifecycle.Scope;
pub fn nativeId(id: u64) !void {
    if (id == 0 or id > p.max_counter) return error.InvalidCatalogIdentity;
}
pub fn fingerprint(value: p.Value) ![32]u8 {
    try value.validate();
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.catalog.input.v1\x00");
    hash.update(value.slice());
    return hash.finalResult();
}
