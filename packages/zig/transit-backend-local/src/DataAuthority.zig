//! Current native authorization fence for a service-owned direct data request.
const std = @import("std");
const core = @import("transit_core");
const storage = @import("transit_storage");
const Self = @This();
pub const Engine = core.growing.Engine(@import("Store.zig"), @import("PageStore.zig"));

engine: *Engine,
request: core.protocol.Authorization.Guard,
audience: u64,
resource: u64,
/// An explicitly delegated service request authenticates its executor under
/// this same fence. Object requirements continue to use the original subject.
executor: ?core.protocol.Authorization.Subject = null,
held: bool = false,
/// Valid only after successful acquisition of the current native fence.
verified: ?core.protocol.Authorization.Verified = null,

pub fn guard(self: *Self) storage.TablePartition.Guard {
    return .{ .context = self, .acquire = acquire, .release = release };
}

fn acquire(context: *anyopaque) !storage.TablePartition.Guard.Fence {
    const self: *Self = @ptrCast(@alignCast(context));
    if (self.held) return error.AuthorityFenceAlreadyHeld;
    self.verified = null;
    const owner = self.engine.journal.backend;
    try owner.authority.lockShared(owner.io);
    errdefer owner.authority.unlockShared(owner.io);
    const verified = try self.engine.authorizeDomain(self.request, self.audience);
    if (self.executor) |subject| _ = try self.engine.authenticateDomain(subject, self.audience);
    try self.engine.requireResourceLifetime(self.resource);
    self.held = true;
    self.verified = verified;
    return .{ .writer_epoch = self.engine.head.storage_epoch, .policy_epoch = self.engine.head.authorization.revision + 1 };
}

fn release(context: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(context));
    std.debug.assert(self.held);
    self.held = false;
    const owner = self.engine.journal.backend;
    owner.authority.unlockShared(owner.io);
}
