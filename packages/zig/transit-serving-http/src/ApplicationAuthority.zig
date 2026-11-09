//! Native authority for a borrowed application request scope. Reservation
//! ownership/purpose remain separate from current program and secret grants.
const std = @import("std");
const q = @import("transit_query_direct");
const R = @import("ApplicationReservation.zig");
const Secrets = @import("ApplicationSecrets.zig");
const Self = @This();

scope: q.ApplicationExecution.Context,
secrets: ?*Secrets,

/// This object and its scope must outlive the serialized reservation borrow,
/// and must be discarded before the expression host releases that borrow.
pub fn authority(self: *Self) R.Authority {
    return .{ .context = self, .check = check };
}
fn access(self: *Self, value: R.Access) !void {
    if (!std.meta.eql(value.owner, self.scope.invocation) or !std.meta.eql(value.input, self.scope.input.source)) return error.ApplicationRequestOwnerMismatch;
    try self.scope.requireCurrent();
}
fn check(context: *anyopaque, evidence: R.Evidence) !void {
    const self: *Self = @ptrCast(@alignCast(context));
    switch (evidence) {
        .access => |value| try self.access(value),
        .redemption => |value| {
            try self.access(value.access);
            if ((value.handle == .secret) != (value.revision_kind != null)) return error.ProtectedProgramValue;
            if (value.revision_kind == .native) {
                const secrets = self.secrets orelse return error.MissingProgramNativeBinding;
                if (!std.meta.eql(secrets.client.connection, self.scope.client.connection) or
                    !std.meta.eql(secrets.client.lease, self.scope.client.lease) or
                    !std.meta.eql(secrets.client.transaction, self.scope.client.transaction)) return error.DataflowLeaseFenced;
                var declared = false;
                for (self.scope.declaration.resources) |resource| {
                    if (resource.nativeBinding() != .secret_references) continue;
                    if (resource.namespace() != secrets.binding.namespace or
                        !std.meta.eql(resource.interpretation(), secrets.binding.interpretation)) return error.TableDefinitionChanged;
                    declared = true;
                }
                if (!declared) return error.MissingProgramNativeBinding;
                const current = try secrets.isCurrent(value.handle.secret.revision);
                // SECRET_CURRENT observes false on rotation, while still
                // checking read/use rights and retaining the native read guard.
                if (!current and value.use != .current) return error.SecretRevisionChanged;
            }
        },
        // The shared native handoff/checkpoint owner must establish this proof.
        // Access or local transaction flags cannot substitute for that owner.
        .transfer => return error.UnverifiedApplicationHandoff,
    }
}

test "application native authority rejects a copied input before contacting a service" {
    const t = std.testing;
    const scope: q.protocol.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const owner: q.catalog.DirectClientToken.Key = .{ .definition = q.protocol.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 5, .principal = 7, .role = 9 }, .account = @splat(1), .token = @splat(2) };
    const input: R.Input = .{ .target = .{ .definition = q.protocol.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(3) }, .partition = 0 }, .operation = .{ .scope = scope, .principal = 11, .operation = 13 }, .ordinal = 0 };
    var self: Self = .{ .scope = .{ .client = undefined, .declaration = undefined, .work = undefined, .invocation = owner, .input = .{ .definition = q.protocol.Growth.current_definition, .source = input, .claim = undefined, .lease = undefined, .environment = undefined }, .step = 1, .scratch = t.allocator }, .secrets = null };
    var value: R.Access = .{ .owner = owner, .input = input, .now_ms = 1 };
    value.input.ordinal += 1;
    try t.expectError(error.ApplicationRequestOwnerMismatch, check(&self, .{ .access = value }));
    value.input = input;
    value.owner.token[0] ^= 1;
    try t.expectError(error.ApplicationRequestOwnerMismatch, check(&self, .{ .access = value }));
    try t.expectError(error.UnverifiedApplicationHandoff, check(&self, .{ .transfer = .{ .from = owner, .input = input, .destination = input, .effect = @splat(1), .transaction = owner } }));
}
