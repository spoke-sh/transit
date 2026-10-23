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

/// The step bound limits one request's work, not total registration progress.
/// A later explicit call resumes the same operation and native change record.
pub fn run(self: *Self, catalog: *D, binding: p.DataLifecycle.Binding, policy: D.Policy, step_limit: u16) !Result {
    if (step_limit == 0 or step_limit > 256) return error.InvalidCatalogStepBudget;
    var native_steps: u16 = 0;
    var attempts: u16 = 0;
    var transport: Transport = .{ .engine = self.engine };
    const registrar: client.AuthorizationClientWithTransport(Transport) = .{ .transport = &transport, .realm = self.engine.genesis.realm, .principal = self.principal, .key = self.key, .role = self.role };
    while (true) {
        const observed = try catalog.status(binding, policy);
        if (observed != .admitted) return .{ .observation = observed, .native_steps = native_steps };
        if (binding.action != .create) return .{ .observation = try catalog.perform(binding, policy), .native_steps = native_steps };
        const plan = try catalog.registration(binding, policy) orelse {
            _ = try catalog.attachRegistration(binding, policy);
            return .{ .observation = try catalog.perform(binding, policy), .native_steps = native_steps };
        };
        if (attempts == step_limit) return .{ .observation = observed, .native_steps = native_steps };
        attempts += 1;
        const next = registrar.registrationAt(plan.action, plan.authorization_revision) catch |err| {
            // Changed policy has accepted no registrar step. A fresh loop must
            // establish the original caller's current rights again.
            if (err == error.StaleAuthorizationRevision) return .{ .observation = try catalog.status(binding, policy), .native_steps = native_steps };
            return err;
        };
        switch (next) {
            .ready => continue,
            .submit => |signed| {
                const prepared = self.engine.prepare(signed) catch |err| {
                    if (err == error.AlreadyCommitted or err == error.StaleAuthorizationRevision) return .{ .observation = try catalog.status(binding, policy), .native_steps = native_steps };
                    return err;
                };
                if (self.after_prepare) |inject| try inject.run(inject.context, self.engine);
                const checked = try catalog.registration(binding, policy) orelse continue;
                if (!std.meta.eql(checked.action, plan.action)) return error.CatalogIdentityConflict;
                if (checked.authorization_revision != plan.authorization_revision) return .{ .observation = try catalog.status(binding, policy), .native_steps = native_steps };
                // The final check also covers resource retirement. Native CAS
                // rejects any later native change, even when it did not change
                // the authorization revision. Never reprepare behind that check.
                _ = self.engine.commit(prepared) catch |err| {
                    if (err == error.Conflict) return .{ .observation = try catalog.status(binding, policy), .native_steps = native_steps };
                    return err;
                };
                native_steps += 1;
            },
        }
    }
}
