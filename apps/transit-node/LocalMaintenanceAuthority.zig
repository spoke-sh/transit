//! Current native maintenance authority, independent of cached data owners.
const std = @import("std");
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Self = @This();
engine: *backend.DataAuthority.Engine,
signed: c.protocol.Growth.SignedRequest,
resource: u64,
epoch: ?u64 = null,
held: bool = false,

pub fn guard(self: *Self) c.storage.PublicationGuard {
    return .{ .context = self, .acquire = acquire, .release = release };
}
fn acquire(raw: *anyopaque) !c.storage.PublicationGuard.Fence {
    const self: *Self = @ptrCast(@alignCast(raw));
    if (self.held) return error.AuthorityFenceAlreadyHeld;
    const owner = self.engine.journal.backend;
    try owner.authority.lockShared(owner.io);
    errdefer owner.authority.unlockShared(owner.io);
    try self.engine.authorizeMaintenance(self.signed);
    try self.engine.requireResourceLifetime(self.resource);
    if (self.epoch == null) self.epoch = self.engine.head.storage_epoch;
    self.held = true;
    return .{ .writer_epoch = self.epoch.?, .policy_epoch = self.engine.head.authorization.revision + 1 };
}
fn release(raw: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(raw));
    std.debug.assert(self.held);
    self.held = false;
    const owner = self.engine.journal.backend;
    owner.authority.unlockShared(owner.io);
}
