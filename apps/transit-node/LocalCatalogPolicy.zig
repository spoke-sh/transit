//! Original-caller catalog policy over the exclusive local native owner.
//! Request dispatch supplies the digest of its complete canonical request.
const std = @import("std");
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const core = @import("transit_core");
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
    var initial = result.authority(try a.guard(.{ .signed = proof }, configuration.authority, null, null, .database), null);
    const guard = initial.guard();
    _ = try guard.acquire(guard.context);
    guard.release(guard.context);
    result.observed = initial.request;
    return result;
}

pub fn policy(self: *Self) c.DirectCatalog.Policy {
    return .{ .context = self, .subject = .{ .signed = self.proof }, .make_guard = makeGuard, .registered = registered, .native_resource = .{ .context = self, .prepare = prepareResource, .allocation = resourceAllocation, .make_guard = resourceGuard } };
}

fn allocationLocked(self: *Self, binding: c.DirectResource.Binding, allocation: c.DirectResource.Allocation) !?u64 {
    try binding.validate();
    if (!binding.connection.matches(self.configuration) or binding.connection.principal != self.proof.claim.principal) return error.CatalogDenied;
    const request = try binding.allocation(allocation);
    var state = try self.engine.state();
    const receipt = try state.get(core.growing.Receipt, try core.catalog.key(.receipt, request.principal, request.sequence, "")) orelse {
        if (request.sequence <= (try self.engine.principal(request.principal)).sequence) return error.MissingReceipt;
        return null;
    };
    if (!std.mem.eql(u8, &receipt.digest, &try p.Growth.digest(request))) return error.ConflictingRetry;
    return receipt.position;
}

fn prepareResource(raw: *anyopaque, binding: c.DirectResource.Binding) !c.DirectResource.Allocation {
    const self = erased(raw);
    try binding.validate();
    if (!binding.connection.matches(self.configuration) or binding.connection.principal != self.proof.claim.principal) return error.CatalogDenied;
    var checked = self.authority(try a.guard(.{ .signed = self.proof }, self.configuration.authority, null, null, .database), null);
    const guard = checked.guard();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    const result: c.DirectResource.Allocation = .{ .sequence = try std.math.add(u64, (try self.engine.principal(binding.connection.principal)).sequence, 1) };
    try result.validate();
    return result;
}

fn resourceAllocation(raw: *anyopaque, binding: c.DirectResource.Binding, allocation: c.DirectResource.Allocation) !?u64 {
    const self = erased(raw);
    var checked = self.authority(try a.guard(.{ .signed = self.proof }, self.configuration.authority, null, null, .database), null);
    const guard = checked.guard();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return self.allocationLocked(binding, allocation);
}

const ResourceGuard = struct {
    policy: *Self,
    underlying: c.storage.TablePartition.Guard,
    condition: c.DirectResource.Condition,
    fn acquire(raw: *anyopaque) !c.storage.TablePartition.Guard.Fence {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const fence = try self.underlying.acquire(self.underlying.context);
        errdefer self.underlying.release(self.underlying.context);
        const policy_value = self.policy;
        const condition = self.condition;
        if (condition.resource == null) {
            try condition.allocation.validate();
            if (condition.initialization != null or (try policy_value.engine.principal(condition.binding.connection.principal)).sequence != condition.allocation.sequence - 1) return error.NativeAllocationSequenceChanged;
            return fence;
        }
        const resource_id = condition.resource.?;
        if (try policy_value.allocationLocked(condition.binding, condition.allocation) != resource_id) return error.NamedResourceAllocationMismatch;
        var state = try policy_value.engine.state();
        const resource = try state.get(p.Growth.Resource, core.growing.address(.resource, resource_id)) orelse return error.UnknownStateResource;
        const declaration = condition.binding.action.create;
        const expected_owner: ?u64 = if (declaration.owned) declaration.writer else null;
        if (resource.id != resource_id or resource.writer != declaration.writer or resource.owner != expected_owner or resource.history_ms != declaration.history_ms) return error.NamedResourceAllocationMismatch;
        if (condition.initialization) |expected| {
            try policy_value.engine.requireResourceLifetime(resource_id);
            const key = p.DataLifecycle.ResourceInitialization.key();
            const entry = try state.get(p.Growth.Entry, try core.catalog.key(.entry, resource_id, 0, key.slice())) orelse return error.NamedResourceNotInitialized;
            if (!entry.key.eql(key) or entry.revision == 0 or entry.revision > resource.revision) return error.InvalidHistory;
            if (!std.meta.eql(expected, try p.DataLifecycle.ResourceInitialization.decode(entry.value))) return error.NamedResourceIdentityConflict;
        }
        return fence;
    }
    fn release(raw: *anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.underlying.release(self.underlying.context);
    }
};

fn resourceGuard(raw: *anyopaque, allocator: std.mem.Allocator, requested: p.Authorization.Guard, condition: c.DirectResource.Condition) !c.storage.TablePartition.Guard {
    const self = erased(raw);
    const value = try allocator.create(ResourceGuard);
    value.* = .{ .policy = self, .underlying = try makeGuard(raw, allocator, requested, null), .condition = condition };
    return .{ .context = value, .acquire = ResourceGuard.acquire, .release = ResourceGuard.release };
}

fn erased(context: *anyopaque) *Self {
    return @ptrCast(@alignCast(context));
}

fn authority(self: *Self, request: p.Authorization.Guard, prerequisite: ?p.Authorization.Guard) backend.DataAuthority {
    return .{ .engine = self.engine, .request = request, .audience = self.configuration.audience, .resource = self.configuration.scope.resource, .prerequisite = prerequisite, .executor = if (self.executor) |value| .{ .signed = value } else null };
}

fn makeGuard(context: *anyopaque, allocator: std.mem.Allocator, requested: p.Authorization.Guard, prerequisite: ?p.Authorization.Guard) !c.storage.TablePartition.Guard {
    const self = erased(context);
    try requested.validate();
    if (prerequisite) |condition| try condition.validate();
    if (!std.meta.eql(requested.subject, self.policy().subject)) return error.InvalidAuthorizationCredential;
    const owned = try allocator.create(ObservedGuard);
    owned.* = .{ .policy = self, .authority = self.authority(requested, prerequisite) };
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
    var value = self.authority(self.observed orelse return error.CatalogDenied, null);
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
    const domain = (try store.domain(self.configuration.authority.domain(kind))) orelse return error.InvalidCatalogConfiguration;
    if (domain.lifetime_resource != self.configuration.scope.resource) return error.InvalidCatalogConfiguration;
    return store.bound(self.configuration.authority.domain(kind), try a.binding(self.configuration.scope, kind, logical));
}

test {
    _ = @import("local_catalog_policy_test.zig");
    _ = @import("LocalTableHost.zig");
}
