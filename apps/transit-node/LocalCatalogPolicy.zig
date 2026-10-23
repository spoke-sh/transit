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

pub fn init(engine: *backend.DataAuthority.Engine, configuration: c.DirectCatalog.Configuration, proof: p.Authorization.Proof, request_digest: [32]u8) !Self {
    try configuration.validate();
    try proof.claim.validate();
    if (configuration.scope.realm != engine.genesis.realm or proof.claim.realm != configuration.scope.realm or
        proof.claim.audience != configuration.audience or !std.mem.eql(u8, &proof.claim.context, &request_digest)) return error.InvalidAuthorizationCredential;
    var result: Self = .{ .engine = engine, .configuration = configuration, .proof = proof };
    var initial = result.authority(try a.guard(.{ .signed = proof }, configuration.authority, null, null, .database));
    const guard = initial.guard();
    _ = try guard.acquire(guard.context);
    guard.release(guard.context);
    return result;
}

pub fn policy(self: *Self) c.DirectCatalog.Policy {
    return .{ .context = self, .subject = .{ .signed = self.proof }, .make_guard = makeGuard, .registered = registered };
}

fn erased(context: *anyopaque) *Self {
    return @ptrCast(@alignCast(context));
}

fn authority(self: *Self, request: p.Authorization.Guard) backend.DataAuthority {
    return .{ .engine = self.engine, .request = request, .audience = self.configuration.audience, .resource = self.configuration.scope.resource };
}

fn makeGuard(context: *anyopaque, allocator: std.mem.Allocator, requested: p.Authorization.Guard) !c.storage.TablePartition.Guard {
    const self = erased(context);
    try requested.validate();
    if (!std.meta.eql(requested.subject, self.policy().subject)) return error.InvalidAuthorizationCredential;
    const owned = try allocator.create(backend.DataAuthority);
    owned.* = self.authority(requested);
    return owned.guard();
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
