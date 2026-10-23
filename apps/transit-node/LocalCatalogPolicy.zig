//! Original-caller catalog policy over the exclusive local native owner.
//! Request dispatch supplies the digest of its complete canonical request.
const std = @import("std");
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const p = c.protocol;
const a = c.TableAuthority;
const Self = @This();

engine: *backend.DataAuthority.Engine,
configuration: c.DirectCatalog.Configuration,
proof: p.Authorization.Proof,
executor: ?p.Authorization.Proof,
observed: ?p.Authorization.Guard = null,

pub fn init(engine: *backend.DataAuthority.Engine, configuration: c.DirectCatalog.Configuration, proof: p.Authorization.Proof, request_digest: [32]u8, executor: ?p.Authorization.Proof) !Self {
    try configuration.validate();
    try proof.claim.validate();
    if (configuration.scope.realm != engine.genesis.realm or proof.claim.realm != configuration.scope.realm or
        proof.claim.audience != configuration.audience or !std.mem.eql(u8, &proof.claim.context, &request_digest)) return error.InvalidAuthorizationCredential;
    if (executor) |value| {
        try value.claim.validate();
        if (value.claim.realm != configuration.scope.realm or value.claim.audience != configuration.audience) return error.InvalidAuthorizationCredential;
    }
    var result: Self = .{ .engine = engine, .configuration = configuration, .proof = proof, .executor = executor };
    var initial = result.authority(try a.guard(.{ .signed = proof }, configuration.authority, null, null, .database));
    const guard = initial.guard();
    _ = try guard.acquire(guard.context);
    guard.release(guard.context);
    result.observed = initial.request;
    return result;
}

pub fn policy(self: *Self) c.DirectCatalog.Policy {
    return .{ .context = self, .subject = .{ .signed = self.proof }, .make_guard = makeGuard, .registered = registered };
}

fn erased(context: *anyopaque) *Self {
    return @ptrCast(@alignCast(context));
}

fn authority(self: *Self, request: p.Authorization.Guard) backend.DataAuthority {
    return .{ .engine = self.engine, .request = request, .audience = self.configuration.audience, .resource = self.configuration.scope.resource, .executor = if (self.executor) |value| .{ .signed = value } else null };
}

fn makeGuard(context: *anyopaque, allocator: std.mem.Allocator, requested: p.Authorization.Guard) !c.storage.TablePartition.Guard {
    const self = erased(context);
    try requested.validate();
    if (!std.meta.eql(requested.subject, self.policy().subject)) return error.InvalidAuthorizationCredential;
    const owned = try allocator.create(ObservedGuard);
    owned.* = .{ .policy = self, .authority = self.authority(requested) };
    return .{ .context = owned, .acquire = ObservedGuard.acquire, .release = ObservedGuard.release };
}

/// Accumulate only successfully checked requirements. A filtered list entry's
/// denied guard must not become a requirement for disclosing the allowed page.
const ObservedGuard = struct {
    policy: *Self,
    authority: backend.DataAuthority,
    fn acquire(context: *anyopaque) !c.storage.TablePartition.Guard.Fence {
        const self: *@This() = @ptrCast(@alignCast(context));
        const guard = self.authority.guard();
        const fence = try guard.acquire(guard.context);
        errdefer guard.release(guard.context);
        self.policy.observed = if (self.policy.observed) |previous| try previous.merge(self.authority.request) else self.authority.request;
        return fence;
    }
    fn release(context: *anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        const guard = self.authority.guard();
        guard.release(guard.context);
    }
};

/// Recheck all disclosed inputs after response buffering, including empty pages
/// and the caller credential/resource lifetime. This does not execute any work.
pub fn check(self: *Self) !u64 {
    return (try self.observation()).revision;
}

pub fn observation(self: *Self) !struct { revision: u64, subject: p.Authorization.Verified } {
    var value = self.authority(self.observed orelse return error.CatalogDenied);
    const guard = value.guard();
    const fence = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return .{ .revision = fence.policy_epoch - 1, .subject = value.verified.? };
}

fn registered(context: *anyopaque, kind: a.Kind, logical: u64) !?p.Authorization.Object {
    const self = erased(context);
    const owner = self.engine.journal.backend;
    try owner.authority.lockShared(owner.io);
    defer owner.authority.unlockShared(owner.io);
    try self.engine.refresh();
    var store = try self.engine.authorization();
    return store.bound(self.configuration.authority.domain(kind), try a.binding(self.configuration.scope, kind, logical));
}

test {
    _ = @import("local_catalog_policy_test.zig");
}
