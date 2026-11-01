//! Explicit service execution over retained catalog work and the existing native
//! registration ledger. Inspection never enters this runner. Callers serialize
//! catalog DDL and the registrar's native sequence; its key grants no Table rights
//! to the original caller.
const std = @import("std");
const c = @import("transit_catalog");
const client = @import("transit_client");
const backend = @import("transit_backend_local");
const p = c.protocol;
const g = p.Growth;
const D = c.DirectCatalog;
const Engine = backend.DataAuthority.Engine;
const Self = @This();

engine: *Engine,
principal: u64,
key: p.Ed25519.KeyPair,
role: ?u64 = null,
/// Fault/race injection after preparing a native candidate, before its final
/// original-caller check. No deployment configuration exposes this callback.
after_prepare: ?struct { context: *anyopaque, run: *const fn (*anyopaque, *Engine) anyerror!void } = null,

const Transport = struct {
    engine: *Engine,
    pub fn query(self: *@This(), query_value: g.Query, key: p.Ed25519.KeyPair) !g.Response {
        return self.engine.query(try g.signQuery(query_value, key));
    }
};
pub const Result = struct { observation: D.Observation, native_steps: u16 };
pub const NamespaceResult = struct { observation: c.DirectNamespace.Observation, native_steps: u16 };
pub const ResourceResult = struct { observation: c.DirectResource.Observation, native_steps: u16 };

/// The original caller signs its frozen native allocation. Registrar credentials
/// only create catalog permission objects; they never grant data or allocate a
/// caller's resource. Kind-specific initialization remains its framework owner.
pub fn runResource(self: *Self, catalog: *D, binding: c.DirectResource.Binding, policy: D.Policy, command: c.DirectResource.Command, step_limit: u16, signed_allocation: ?c.DirectResource.SignedAllocation) !ResourceResult {
    if (step_limit == 0 or step_limit > 256 or (command != .execute and command != .cancel)) return error.InvalidCatalogStepBudget;
    var native_steps: u16 = 0;
    var attempts: u16 = 0;
    var transport: Transport = .{ .engine = self.engine };
    const registrar: client.AuthorizationClientWithTransport(Transport) = .{ .transport = &transport, .realm = self.engine.genesis.realm, .principal = self.principal, .key = self.key, .role = self.role };
    while (true) {
        const observed = try catalog.resourceOperation(binding, .inspect, policy);
        if (observed != .operation or !observed.operation.pending()) return .{ .observation = observed, .native_steps = native_steps };
        if (binding.action != .create) return .{ .observation = try catalog.resourceOperation(binding, command, policy), .native_steps = native_steps };
        if (observed.operation.phase == .allocated) {
            const result = catalog.resourceOperation(binding, command, policy) catch |err| {
                if (err == error.NamedResourceNotInitialized) return .{ .observation = observed, .native_steps = native_steps };
                return err;
            };
            return .{ .observation = result, .native_steps = native_steps };
        }
        if (observed.operation.phase == .prepared) {
            const native = policy.native_resource orelse return error.NamedResourceNativeUnavailable;
            const allocated = native.allocation(native.context, binding, observed.operation.allocation.?) catch |err| {
                if (err == error.ConflictingRetry and command == .cancel) return .{ .observation = try catalog.resourceOperation(binding, .cancel, policy), .native_steps = native_steps };
                return err;
            };
            if (allocated) |resource| {
                _ = try catalog.attachResource(binding, resource, policy);
                continue;
            }
            if (command == .cancel) return .{ .observation = try catalog.resourceOperation(binding, .cancel, policy), .native_steps = native_steps };
            if (attempts == step_limit) return .{ .observation = observed, .native_steps = native_steps };
            attempts += 1;
            const signed = signed_allocation orelse return .{ .observation = observed, .native_steps = native_steps };
            if (!std.meta.eql(signed.allocation, observed.operation.allocation.?)) return error.DataIdentityConflict;
            const request = try catalog.resourceAllocation(binding, policy) orelse continue;
            const prepared = self.engine.prepare(.{ .request = request, .signature = signed.signature }) catch |err| {
                if (err == error.AlreadyCommitted) continue;
                return err;
            };
            if (self.after_prepare) |inject| try inject.run(inject.context, self.engine);
            const checked = try catalog.resourceAllocation(binding, policy) orelse continue;
            if (!std.meta.eql(checked, request)) return error.DataIdentityConflict;
            _ = self.engine.commit(prepared) catch |err| {
                if (err == error.Conflict) continue;
                return err;
            };
            native_steps += 1;
            continue;
        }
        if (command == .cancel) return .{ .observation = try catalog.resourceOperation(binding, .cancel, policy), .native_steps = native_steps };
        if (attempts == step_limit) return .{ .observation = observed, .native_steps = native_steps };
        attempts += 1;
        if (try catalog.resourceRegistration(binding, policy)) |plan| {
            const next = registrar.registrationAt(plan.action, plan.authorization_revision) catch |err| {
                if (err == error.StaleAuthorizationRevision) return .{ .observation = try catalog.resourceOperation(binding, .inspect, policy), .native_steps = native_steps };
                return err;
            };
            switch (next) {
                .ready => continue,
                .submit => |signed| {
                    const prepared = self.engine.prepare(signed) catch |err| {
                        if (err == error.AlreadyCommitted or err == error.StaleAuthorizationRevision) continue;
                        return err;
                    };
                    if (self.after_prepare) |inject| try inject.run(inject.context, self.engine);
                    const checked = try catalog.resourceRegistration(binding, policy) orelse continue;
                    if (!std.meta.eql(checked.action, plan.action)) return error.CatalogIdentityConflict;
                    if (checked.authorization_revision != plan.authorization_revision) continue;
                    _ = self.engine.commit(prepared) catch |err| {
                        if (err == error.Conflict) continue;
                        return err;
                    };
                    native_steps += 1;
                    continue;
                },
            }
        }
        return .{ .observation = try catalog.prepareResourceAllocation(binding, policy), .native_steps = native_steps };
    }
}

/// The step bound limits one request's work, not total registration progress.
/// A later explicit call resumes the same operation and native change record.
pub fn run(self: *Self, catalog: *D, binding: p.DataLifecycle.Binding, policy: D.Policy, step_limit: u16) !Result {
    return self.runInner(false, catalog, binding, policy, step_limit);
}
pub fn runNamespace(self: *Self, catalog: *D, binding: c.DirectNamespace.Binding, policy: D.Policy, step_limit: u16) !NamespaceResult {
    return self.runInner(true, catalog, binding, policy, step_limit);
}
/// Each iteration performs at most one native registration step or one private
/// partition initialization. The next call resumes the original accepted work.
pub fn runLog(self: *Self, catalog: *D, binding: p.DataLifecycle.Binding, policy: D.Policy, step_limit: u16) !c.DirectLog.Observation {
    if (step_limit == 0 or step_limit > 256) return error.InvalidCatalogStepBudget;
    var transport: Transport = .{ .engine = self.engine };
    const registrar: client.AuthorizationClientWithTransport(Transport) = .{ .transport = &transport, .realm = self.engine.genesis.realm, .principal = self.principal, .key = self.key, .role = self.role };
    for (0..step_limit) |_| {
        const observed = try catalog.logOperation(binding, .inspect, policy);
        if (observed != .operation or !observed.operation.pending()) return observed;
        const plan = if (binding.action == .create) try catalog.logRegistration(binding, policy) else null;
        if (plan == null) {
            _ = try catalog.logOperation(binding, .execute, policy);
            continue;
        }
        const next = registrar.registrationAt(plan.?.action, plan.?.authorization_revision) catch |err| {
            if (err == error.StaleAuthorizationRevision) return catalog.logOperation(binding, .inspect, policy);
            return err;
        };
        switch (next) {
            .ready => continue,
            .submit => |signed| {
                const prepared = self.engine.prepare(signed) catch |err| {
                    if (err == error.AlreadyCommitted or err == error.StaleAuthorizationRevision) continue;
                    return err;
                };
                if (self.after_prepare) |inject| try inject.run(inject.context, self.engine);
                const checked = try catalog.logRegistration(binding, policy) orelse continue;
                if (!std.meta.eql(checked.action, plan.?.action)) return error.CatalogIdentityConflict;
                if (checked.authorization_revision != plan.?.authorization_revision) continue;
                _ = self.engine.commit(prepared) catch |err| {
                    if (err == error.Conflict) continue;
                    return err;
                };
            },
        }
    }
    return catalog.logOperation(binding, .inspect, policy);
}
fn observe(comptime namespace: bool, catalog: *D, binding: anytype, policy: D.Policy) !(if (namespace) c.DirectNamespace.Observation else D.Observation) {
    return if (namespace) catalog.namespaceOperation(binding, .inspect, policy) else catalog.status(binding, policy);
}
fn registration(comptime namespace: bool, catalog: *D, binding: anytype, policy: D.Policy) !?D.Registration {
    return if (namespace) catalog.namespaceRegistration(binding, policy) else catalog.registration(binding, policy);
}
fn runInner(self: *Self, comptime namespace: bool, catalog: *D, binding: anytype, policy: D.Policy, step_limit: u16) !(if (namespace) NamespaceResult else Result) {
    if (step_limit == 0 or step_limit > 256) return error.InvalidCatalogStepBudget;
    var native_steps: u16 = 0;
    var attempts: u16 = 0;
    var transport: Transport = .{ .engine = self.engine };
    const registrar: client.AuthorizationClientWithTransport(Transport) = .{ .transport = &transport, .realm = self.engine.genesis.realm, .principal = self.principal, .key = self.key, .role = self.role };
    while (true) {
        const observed = try observe(namespace, catalog, binding, policy);
        if (!namespace) if (observed == .finalizing) {
            if (attempts == step_limit) return .{ .observation = observed, .native_steps = native_steps };
            attempts += 1;
            _ = try catalog.settle(binding, policy);
            continue;
        };
        const admitted = if (namespace) observed == .operation and observed.operation.phase == .admitted else observed == .admitted;
        if (!admitted) return .{ .observation = observed, .native_steps = native_steps };
        if (binding.action != .create) return .{ .observation = if (namespace) try catalog.namespaceOperation(binding, .execute, policy) else try catalog.perform(binding, policy), .native_steps = native_steps };
        const plan = try registration(namespace, catalog, binding, policy) orelse {
            if (!namespace) _ = try catalog.attachRegistration(binding, policy);
            return .{ .observation = if (namespace) try catalog.namespaceOperation(binding, .execute, policy) else try catalog.perform(binding, policy), .native_steps = native_steps };
        };
        if (attempts == step_limit) return .{ .observation = observed, .native_steps = native_steps };
        attempts += 1;
        const next = registrar.registrationAt(plan.action, plan.authorization_revision) catch |err| {
            // Changed policy has accepted no registrar step. A fresh loop must
            // establish the original caller's current rights again.
            if (err == error.StaleAuthorizationRevision) return .{ .observation = try observe(namespace, catalog, binding, policy), .native_steps = native_steps };
            return err;
        };
        switch (next) {
            .ready => continue,
            .submit => |signed| {
                const prepared = self.engine.prepare(signed) catch |err| {
                    if (err == error.AlreadyCommitted or err == error.StaleAuthorizationRevision) return .{ .observation = try observe(namespace, catalog, binding, policy), .native_steps = native_steps };
                    return err;
                };
                if (self.after_prepare) |inject| try inject.run(inject.context, self.engine);
                const checked = try registration(namespace, catalog, binding, policy) orelse continue;
                if (!std.meta.eql(checked.action, plan.action)) return error.CatalogIdentityConflict;
                if (checked.authorization_revision != plan.authorization_revision) return .{ .observation = try observe(namespace, catalog, binding, policy), .native_steps = native_steps };
                // The final check also covers resource retirement. Native CAS
                // rejects any later native change, even when it did not change
                // the authorization revision. Never reprepare behind that check.
                _ = self.engine.commit(prepared) catch |err| {
                    if (err == error.Conflict) return .{ .observation = try observe(namespace, catalog, binding, policy), .native_steps = native_steps };
                    return err;
                };
                native_steps += 1;
            },
        }
    }
}
