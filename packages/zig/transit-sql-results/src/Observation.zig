//! Observation evidence is separate from permissions and resource retention.
const std = @import("std");
const r = @import("root.zig");
const d = r.protocol.DataLifecycle;
const Self = @This();
pub const Projection = struct {
    source: d.Definition,
    target: d.Definition,
    declaration: d.Content,
    schema: [32]u8,
    accepted_lsn: u64,
    policy: enum { stable_columns_add_origins },
    pub fn validate(self: Projection) !void {
        try self.source.validate();
        try self.target.validate();
        try self.declaration.validate();
        if (!std.meta.eql(self.source.object, self.target.object) or self.source.revision > self.target.revision or self.accepted_lsn == 0 or std.mem.allEqual(u8, &self.schema, 0)) return error.InvalidProjectionObservation;
    }
};
pub const Table = struct { object: d.Object, interpretation: d.Definition, accepted: d.Position, changed_lsn: u64, pin: d.Content, commitment: [32]u8, schema: [32]u8, projection: ?Projection = null, view: ?d.Definition = null };
pub const Data = union(enum) {
    source: struct { kind: r.fuze.Unified.SourceKind, resource: u64, position: union(enum) { native_revision: u64, table: [32]u8 }, contract: [32]u8, schema: [32]u8 },
    table: Table,
    independent_table_snapshots: []const r.fuze.Relational.Cut,
    historical: struct { snapshot: d.Snapshot, sources: []const Table },
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
    historical: ?d.Snapshot = null,
    projections: []const Projection = &.{},
};
pub const Value = union(enum) { data: Data, metadata: Metadata };
pub fn validate(value: Value) !void {
    if (value == .metadata) {
        if (value.metadata.projections.len > r.fuze.Relational.max_sources) return error.InvalidProjectionObservation;
        for (value.metadata.projections) |projection| {
            try projection.validate();
            for (value.metadata.definitions) |definition| {
                if (std.meta.eql(definition, projection.source)) break;
            } else return error.InvalidProjectionObservation;
        }
        if (value.metadata.historical) |snapshot| {
            try snapshot.validate();
            if (snapshot.definition != r.protocol.Growth.current_definition) return error.IncompatibleDefinition;
            if (value.metadata.consistency != .exact_definitions) return error.InvalidHistoricalObservation;
            for (value.metadata.definitions) |definition| {
                try definition.validate();
                if (!std.meta.eql(definition.object.scope, snapshot.owner.scope) or definition.object.branch != snapshot.branch) return error.InvalidHistoricalObservation;
            }
        }
        return;
    }
    if (value.data == .table) try validateTableProjection(value.data.table);
    if (value.data == .historical) {
        const historical = value.data.historical;
        try historical.snapshot.validate();
        if (historical.snapshot.definition != r.protocol.Growth.current_definition) return error.IncompatibleDefinition;
        if (historical.snapshot.source_count == 0 or historical.sources.len == 0 or historical.sources.len > r.fuze.Relational.max_sources) return error.InvalidHistoricalObservation;
        var distinct: u64 = 0;
        for (historical.sources, 0..) |source, i| {
            try validateTableProjection(source);
            try source.object.validate();
            try source.pin.validate();
            try historical.snapshot.requireSource(.{ .interpretation = source.interpretation, .manifest = null, .checkpoint_lsn = 0, .accepted = source.accepted });
            if (!std.meta.eql(source.object, source.interpretation.object) or source.changed_lsn > source.accepted.next_lsn or std.mem.allEqual(u8, &source.commitment, 0) or std.mem.allEqual(u8, &source.schema, 0)) return error.InvalidHistoricalObservation;
            var duplicate = false;
            for (historical.sources[0..i]) |earlier| if (std.meta.eql(source.object, earlier.object)) {
                // Self-join aliases can have different compiled projections,
                // but a single retained catalog cannot supply two source cuts.
                if (!std.meta.eql(source.interpretation, earlier.interpretation) or !std.meta.eql(source.accepted, earlier.accepted) or !std.meta.eql(source.pin, earlier.pin) or source.changed_lsn != earlier.changed_lsn) return error.InvalidHistoricalObservation;
                duplicate = true;
                break;
            };
            if (!duplicate) distinct += 1;
        }
        if (distinct > historical.snapshot.source_count) return error.InvalidHistoricalObservation;
        return;
    }
    if (value.data != .transaction) return;
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

fn validateTableProjection(source: Table) !void {
    if (source.view) |definition| {
        try definition.validate();
        if (!std.meta.eql(definition.object.scope, source.object.scope) or definition.object.branch != source.object.branch or definition.object.object == source.object.object) return error.InvalidHistoricalObservation;
    }
    if (source.projection) |projection| {
        try projection.validate();
        if (!std.meta.eql(source.interpretation, projection.source)) return error.InvalidProjectionObservation;
    }
}

test "historical observations bind selected source cardinality scope and self-join cuts" {
    const t = std.testing;
    const scope: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const snapshot: d.Snapshot = .{ .definition = r.protocol.Growth.current_definition, .owner = .{ .scope = scope, .principal = 4, .operation = 5 }, .branch = 1, .catalog_root = .{ .bytes = 10, .sha256 = @splat(1) }, .sources_root = .{ .bytes = 11, .sha256 = @splat(2) }, .source_count = 1, .consistency = .independent };
    const object: d.Object = .{ .scope = scope, .branch = 1, .object = 7 };
    const source: Table = .{ .object = object, .interpretation = .{ .object = object, .revision = 1, .digest = @splat(3) }, .accepted = .{ .partition = 8, .next_lsn = 9 }, .changed_lsn = 8, .pin = .{ .bytes = 12, .sha256 = @splat(4) }, .commitment = @splat(5), .schema = @splat(6) };
    var aliases = [_]Table{ source, source };
    aliases[1].commitment = @splat(7);
    const observation: Value = .{ .data = .{ .historical = .{ .snapshot = snapshot, .sources = &aliases } } };
    try validate(observation);
    aliases[1].accepted.next_lsn += 1;
    try t.expectError(error.InvalidHistoricalObservation, validate(observation));
    aliases[1] = source;
    aliases[1].object.object += 1;
    aliases[1].interpretation.object = aliases[1].object;
    try t.expectError(error.InvalidHistoricalObservation, validate(observation));
    var definition = source.interpretation;
    var metadata: Value = .{ .metadata = .{ .kind = .catalog, .consistency = .exact_definitions, .namespace = 1, .definitions = &.{definition}, .configuration_revision = null, .session_settings = null, .historical = snapshot } };
    try validate(metadata);
    definition.object.branch += 1;
    metadata.metadata.definitions = &.{definition};
    try t.expectError(error.InvalidHistoricalObservation, validate(metadata));
    metadata.metadata.definitions = &.{};
    metadata.metadata.historical.?.source_count = 0;
    // Retained decoder/graph definitions can describe no Table data sources.
    // Their metadata remains exact; it cannot establish a data observation.
    try validate(metadata);
    metadata.metadata.definitions = &.{source.interpretation};
    try validate(metadata);
    metadata.metadata.consistency = .independent_observations;
    try t.expectError(error.InvalidHistoricalObservation, validate(metadata));
    aliases[1] = source;
    var empty_data = observation;
    empty_data.data.historical.snapshot.source_count = 0;
    try t.expectError(error.InvalidHistoricalObservation, validate(empty_data));
    empty_data.data.historical.snapshot = snapshot;
    empty_data.data.historical.sources = &.{};
    try t.expectError(error.InvalidHistoricalObservation, validate(empty_data));
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

test "explicit projection observation preserves source schema and rejects foreign target attribution" {
    const t = std.testing;
    const object: d.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 };
    const original: d.Definition = .{ .object = object, .revision = 1, .digest = @splat(1) };
    const target: d.Definition = .{ .object = object, .revision = 3, .digest = @splat(3) };
    const projection: Projection = .{ .source = original, .target = target, .declaration = .{ .bytes = 104, .sha256 = @splat(3) }, .schema = @splat(4), .accepted_lsn = 7, .policy = .stable_columns_add_origins };
    var table: Table = .{ .object = object, .interpretation = original, .accepted = .{ .partition = 5, .next_lsn = 6 }, .changed_lsn = 6, .pin = .{ .bytes = 100, .sha256 = @splat(5) }, .commitment = @splat(6), .schema = @splat(2), .projection = projection };
    try validate(.{ .data = .{ .table = table } });
    const fingerprinted = try fingerprint(t.allocator, .{ .data = .{ .table = table } });
    table.projection = null;
    try t.expect(!std.meta.eql(fingerprinted, try fingerprint(t.allocator, .{ .data = .{ .table = table } })));
    table.projection = projection;
    table.projection.?.source.revision += 1;
    try t.expectError(error.InvalidProjectionObservation, validate(.{ .data = .{ .table = table } }));
    table.projection = projection;
    table.projection.?.target.object.object += 1;
    try t.expectError(error.InvalidProjectionObservation, validate(.{ .data = .{ .table = table } }));
    table.projection = projection;
    table.projection.?.accepted_lsn = 0;
    try t.expectError(error.InvalidProjectionObservation, validate(.{ .data = .{ .table = table } }));
    var metadata: Value = .{ .metadata = .{ .kind = .plan, .consistency = .exact_definitions, .namespace = 1, .definitions = &.{original}, .configuration_revision = null, .session_settings = null, .projections = &.{projection} } };
    try validate(metadata);
    metadata.metadata.definitions = &.{target};
    try t.expectError(error.InvalidProjectionObservation, validate(metadata));
}
