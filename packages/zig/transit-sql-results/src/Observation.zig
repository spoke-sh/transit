//! Observation evidence is separate from permissions and resource retention.
const std = @import("std");
const r = @import("root.zig");
const d = r.protocol.DataLifecycle;
const Self = @This();
pub const Data = union(enum) {
    workload: r.Workload.Observation,
    source: struct { kind: r.fuze.Unified.SourceKind, resource: u64, position: union(enum) { native_revision: u64, table: [32]u8 }, contract: [32]u8, schema: [32]u8 },
    table: struct { object: d.Object, interpretation: d.Definition, accepted: d.Position, changed_lsn: u64, pin: d.Content, commitment: [32]u8, schema: [32]u8 },
    independent_table_snapshots: []const r.fuze.Relational.Cut,
    transaction: struct { handle: r.protocol.Transaction.Handle, cut: r.protocol.Transaction.Cut, revision: d.Position, last_statement: u64, sources: []const r.protocol.Transaction.ReadView },
};
pub const Metadata = struct {
    kind: enum { catalog, settings, plan, probe },
    /// Catalog pagination can observe different revisions. Only an owner-supplied
    /// revision is reported; metadata never pretends to be a data snapshot.
    consistency: enum { exact_definitions, independent_observations, session },
    namespace: ?u64,
    definitions: []const d.Definition,
    configuration_revision: ?u64,
    session_settings: ?[32]u8,
    source: ?struct { resource: u64, contract: [32]u8, schema: [32]u8 } = null,
};
pub const Value = union(enum) { data: Data, metadata: Metadata };
pub fn validate(value: Value) !void {
    if (value == .data and value.data == .workload) return value.data.workload.validate();
    if (value != .data or value.data != .transaction) return;
    const view = value.data.transaction;
    try view.handle.validate();
    try view.cut.validate();
    try view.revision.validate();
    if (!std.meta.eql(view.handle.identity, view.cut.begin.identity) or view.sources.len == 0 or view.sources.len > r.fuze.Relational.max_sources) return error.InvalidTransactionObservation;
    for (view.sources) |source| {
        try source.validate();
        if (!std.meta.eql(source.cut, view.cut) or !std.meta.eql(source.revision, view.revision) or source.last_statement != view.last_statement) return error.InvalidTransactionObservation;
    }
}
pub fn fingerprint(allocator: std.mem.Allocator, value: Value) ![32]u8 {
    try validate(value);
    const bytes = try r.protocol.Json.valueAlloc(allocator, value);
    defer allocator.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}
pub const PublishedResourceObservation = struct {
    resource_object: u64,
    definition_id: u64,
    publication_revision: u64,
    definition_digest: [32]u8,
    disclosure_mode: enum(u8) { caller_source_rights = 1, derived_publication = 2, retained_published_snapshot = 3 },
    audience_policy_hash: [32]u8,
    verified_policy_epoch: u64,
    investigation_id: u64,
    basis_revision: u64,
    is_globally_atomic: bool,
    basis_digest: [32]u8,
    attribution_receipt_digest: [32]u8,
    pub fn validate(self: PublishedResourceObservation) !void {
        if (self.resource_object == 0 or self.definition_id == 0 or self.publication_revision == 0 or self.verified_policy_epoch == 0 or self.investigation_id == 0 or self.basis_revision == 0) return error.InvalidPublishedResourceObservation;
        if (std.mem.allEqual(u8, &self.definition_digest, 0) or std.mem.allEqual(u8, &self.audience_policy_hash, 0) or std.mem.allEqual(u8, &self.basis_digest, 0) or std.mem.allEqual(u8, &self.attribution_receipt_digest, 0)) return error.InvalidPublishedResourceObservation;
    }
    pub fn validateBatchDisclosure(self: PublishedResourceObservation, current_policy_epoch: u64, resource_withdrawn: bool, caller_revoked: bool) !void {
        try self.validate();
        if (resource_withdrawn) return error.PublishedResourceWithdrawn;
        if (caller_revoked or current_policy_epoch < self.verified_policy_epoch) return error.AuthorizationRevokedMidStream;
    }
};
