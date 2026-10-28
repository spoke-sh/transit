//! Catalog admission of a local transaction's original begin request. Admission
//! reserves a coordination partition; it does not acquire pins or publish data.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;

pub const Reference = struct {
    connection: c.DirectTableProtocol.Connection,
    namespace: u64,
    begin: p.Transaction.Begin,

    pub fn validate(self: Reference) !void {
        try self.connection.validate();
        try c.Model.nativeId(self.namespace);
        try self.begin.validate();
        if (!std.meta.eql(self.connection.scope, self.begin.identity.begin.scope) or
            self.connection.principal != self.begin.identity.begin.principal)
            return error.TransactionIdentityConflict;
    }

    pub fn identity(self: Reference) p.DataLifecycle.Operation {
        return self.begin.identity.begin;
    }
};

/// Server admission ceilings, independent of the account's durable token quota.
pub const default_limits: p.Transaction.Limits = .{
    .resident_bytes = 16 * 1024 * 1024,
    .workspace_bytes = 1024 * 1024 * 1024,
    .participants = 100_000,
    .statements = 100_000,
    .savepoints = 1024,
};

pub fn requireLimits(requested: p.Transaction.Limits, maximum: p.Transaction.Limits) !void {
    try requested.validate();
    try maximum.validate();
    inline for (@typeInfo(p.Transaction.Limits).@"struct".field_names) |name| {
        if (@field(requested, name) > @field(maximum, name)) return error.TransactionCapacity;
    }
}

/// Validate all immutable selection entries before reserving a partition. This
/// is a descriptor check, not proof of a consistent cut or read authorization.
pub fn inspectSelection(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, reference: Reference, options: c.DirectCatalog.Options) !void {
    try reference.validate();
    try requireLimits(reference.begin.limits, options.transaction_limits);
    var directory = try c.storage.TransactionDirectory.init(allocator, objects, reference.begin.identity, .participants, reference.begin.limits.participants, options.resident_pages, options.index_work_bytes);
    defer directory.deinit();
    try directory.restore(reference.begin.tables);
    var after: ?u64 = null;
    while (true) {
        const page = try directory.page(after);
        for (page.entries) |slot| if (slot) |entry| {
            try entry.participant.requireLocalTable(reference.begin);
            if (entry.participant.state.access != .read) return error.InvalidTransactionBegin;
        };
        after = page.next orelse break;
    }
}

test "transaction admission signature binds the complete independent begin fixture" {
    const t = std.testing;
    const Fixture = struct { request: c.DirectTableProtocol.Request, public_key: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-transaction-v1.json"));
    defer parsed.deinit();
    const fixture = parsed.value;
    try fixture.request.validate(t.allocator);
    try fixture.request.proof.verify(fixture.public_key);
    try t.expect(fixture.request.transport().mutation);
    var changed = fixture.request;
    changed.action.client_token.bind.intent.transaction.begin.limits.workspace_bytes += 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = fixture.request;
    changed.action.client_token.bind.intent.transaction.begin.identity.begin.principal += 1;
    try t.expectError(error.TransactionIdentityConflict, changed.action.client_token.bind.intent.transaction.validate());
}
