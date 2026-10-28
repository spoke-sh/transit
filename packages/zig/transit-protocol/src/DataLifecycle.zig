//! Neutral data identities, accepted-operation evidence and snapshot coverage.
//! Validation establishes shape and attribution, never authorization or durability.
const std = @import("std");
const p = @import("root.zig");

/// Bounds shared by named resource declarations and immutable publication.
/// They describe stored data, independently of the worker that publishes it.
pub const PublicationLimits = struct {
    record_bytes: u32,
    staging_bytes: u64,
    staging_records: u32,
    pub fn validate(self: PublicationLimits) !void {
        if (self.record_bytes == 0 or self.staging_bytes < self.record_bytes or self.staging_records == 0) return error.InvalidPublicationLimits;
    }
};

/// Maximum encoded node size in the current Document immutable index format.
pub const document_index_node_bytes = 4096;

/// Resource is the existing logical catalog authority, not a file/provider path.
/// Catalog and object identifiers retain the full unsigned 64-bit range.
pub const Scope = struct {
    realm: u64,
    resource: u64,
    catalog: u64,

    pub fn validate(self: Scope) !void {
        if (self.realm == 0 or self.realm > p.max_counter or self.resource == 0 or
            self.resource > p.max_counter or self.catalog == 0) return error.InvalidCatalogIdentity;
    }
};

pub const Object = struct {
    scope: Scope,
    branch: u64,
    object: u64,

    pub fn validate(self: Object) !void {
        try self.scope.validate();
        if (self.branch == 0 or self.object == 0) return error.InvalidDataIdentity;
    }
};

/// An immutable interpretation. Neither a name nor a data progress position.
pub const Definition = struct {
    object: Object,
    revision: u64,
    digest: [32]u8,

    pub fn validate(self: Definition) !void {
        try self.object.validate();
        if (self.revision == 0) return error.InvalidDataDefinition;
    }
};

/// The framework writes this binding only after kind-specific initialization.
/// Catalog publication independently checks the native resource and this exact
/// entry under current authority. It is not a resource grant or execution proof.
pub const ResourceInitialization = struct {
    definition: p.Growth.Definition,
    interpretation: Definition,
    kind: enum(u8) { kv = 1, document = 2 },
    resource: u64,
    pub const encoded_bytes = 125;

    pub fn key() p.Value {
        return p.Value.init("\x00NL") catch unreachable;
    }

    pub fn validate(self: ResourceInitialization) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.interpretation.validate();
        if (self.interpretation.object.branch != 1 or self.interpretation.revision != 1 or
            self.resource == 0 or self.resource > p.max_counter) return error.InvalidResourceInitialization;
    }

    pub fn encode(self: ResourceInitialization) !p.Value {
        try self.validate();
        var bytes: [encoded_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("NSI1");
        try writer.writeAll(&p.Growth.definition_bytes);
        const object = self.interpretation.object;
        for ([_]u64{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object, self.interpretation.revision }) |field|
            try writer.writeInt(u64, field, .big);
        try writer.writeAll(&self.interpretation.digest);
        try writer.writeByte(@backingInt(self.kind));
        try writer.writeInt(u64, self.resource, .big);
        return p.Value.init(writer.buffered());
    }

    pub fn decode(value: p.Value) !ResourceInitialization {
        try value.validate();
        if (value.len != encoded_bytes) return error.InvalidResourceInitialization;
        var reader: std.Io.Reader = .fixed(value.slice());
        if (!std.mem.eql(u8, try reader.take(4), "NSI1")) return error.InvalidResourceInitialization;
        if (!std.mem.eql(u8, try reader.take(32), &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
        const result: ResourceInitialization = .{
            .definition = p.Growth.current_definition,
            .interpretation = .{
                .object = .{
                    .scope = .{ .realm = try reader.takeInt(u64, .big), .resource = try reader.takeInt(u64, .big), .catalog = try reader.takeInt(u64, .big) },
                    .branch = try reader.takeInt(u64, .big),
                    .object = try reader.takeInt(u64, .big),
                },
                .revision = try reader.takeInt(u64, .big),
                .digest = (try reader.takeArray(32)).*,
            },
            .kind = std.enums.fromInt(@FieldType(ResourceInitialization, "kind"), try reader.takeByte()) orelse return error.InvalidResourceInitialization,
            .resource = try reader.takeInt(u64, .big),
        };
        try result.validate();
        return result;
    }
};

pub const Operation = struct {
    scope: Scope,
    principal: u64,
    operation: u64,

    pub fn validate(self: Operation) !void {
        try self.scope.validate();
        if (self.principal > p.max_counter or self.operation == 0) return error.InvalidDataOperation;
    }
};

/// Exclusive accepted-log frontier: [0, next_lsn). Different partitions cannot
/// be compared as if they were one global sequence. Zero denotes an empty log.
pub const Position = struct {
    partition: u64,
    next_lsn: u64,

    pub fn validate(self: Position) !void {
        if (self.partition == 0) return error.InvalidDataPosition;
    }

    /// A source basis remains current through control/physical publications.
    /// The owner supplies its latest logical-change frontier, not a client clock.
    pub fn unchangedAt(self: Position, current: Position, changed_lsn: u64) bool {
        return self.partition != 0 and self.partition == current.partition and
            changed_lsn <= self.next_lsn and self.next_lsn <= current.next_lsn;
    }
};

pub const Content = struct {
    bytes: u64,
    sha256: [32]u8,

    pub fn validate(self: Content) !void {
        if (self.bytes == 0) return error.InvalidDataContent;
    }
};

pub const Action = enum { create, alter, rename, drop, insert, update, delete };

/// Frozen before sending. The owner checks current policy and these expectations
/// again at acceptance; an earlier preview grants no right or reservation.
pub const Binding = struct {
    definition: p.Growth.Definition,
    identity: Operation,
    target: Object,
    action: Action,
    expected_definition: ?Definition,
    expected_data: ?Position,
    intent: [32]u8,
    /// A further current-authority condition, never a replacement for the data
    /// caller's rights. The owner checks both under the same acceptance fence.
    /// Accepted actor inputs can retain their original subject across workers.
    /// Inspection and cancellation use the data caller's current rights; they
    /// do not require the prerequisite subject to authorize another mutation.
    prerequisite: ?p.Authorization.Guard = null,

    pub fn validate(self: Binding) !void {
        try self.identity.validate();
        try self.target.validate();
        if (self.prerequisite) |condition| {
            try condition.validate();
            if (condition.subject == .signed and condition.subject.signed.claim.realm != self.identity.scope.realm) return error.DataIdentityConflict;
        }
        if (!std.meta.eql(self.identity.scope, self.target.scope)) return error.DataIdentityConflict;
        if ((self.action == .create) != (self.expected_definition == null)) return error.InvalidDataDefinition;
        if (self.expected_definition) |expected| {
            try expected.validate();
            if (!std.meta.eql(expected.object, self.target)) return error.DataIdentityConflict;
        }
        if (self.expected_data) |position| {
            try position.validate();
            if (self.action == .create) return error.InvalidDataPosition;
        }
    }

    /// Retry equality includes content and every expectation. It never resolves
    /// a human name or substitutes the current definition for the saved one.
    pub fn requireSame(self: Binding, other: Binding) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
};

/// Both ingestion paths terminate in this same accepted-operation evidence.
/// A bulk object reference by itself is staged data, not a Commit.
pub const Commit = struct {
    binding: Binding,
    position: Position,
    resulting_definition: Definition,
    result: Content,
    ingestion: enum { point, bulk },

    pub fn validate(self: Commit) !void {
        try self.binding.validate();
        try self.position.validate();
        try self.resulting_definition.validate();
        try self.result.validate();
        if (self.position.next_lsn == 0) return error.InvalidDataPosition;
        if (!std.meta.eql(self.binding.target, self.resulting_definition.object)) return error.DataIdentityConflict;
        if (self.binding.expected_data) |expected| {
            if (expected.partition != self.position.partition or
                expected.next_lsn >= self.position.next_lsn) return error.InvalidDataPosition;
        }
        if (self.binding.expected_definition) |expected| {
            switch (self.binding.action) {
                .insert, .update, .delete => if (!std.meta.eql(expected, self.resulting_definition)) return error.InvalidDataDefinition,
                .alter, .rename, .drop => if (self.resulting_definition.revision <= expected.revision) return error.InvalidDataDefinition,
                .create => unreachable,
            }
        } else if (self.resulting_definition.revision != 1) return error.InvalidDataDefinition;
    }

    pub fn requireBinding(self: Commit, binding: Binding) !void {
        try self.validate();
        try self.binding.requireSame(binding);
    }
};

/// One source's reconstructible basis. A checkpoint covers [0, checkpoint_lsn);
/// the snapshot also retains WAL [checkpoint_lsn, accepted.next_lsn).
/// A durable pin must keep both reachable. This value is not itself that pin.
pub const SourceCut = struct {
    interpretation: Definition,
    manifest: ?Content,
    checkpoint_lsn: u64,
    accepted: Position,

    pub fn validate(self: SourceCut) !void {
        try self.interpretation.validate();
        try self.accepted.validate();
        if (self.checkpoint_lsn > self.accepted.next_lsn) return error.InvalidSnapshotCoverage;
        if (self.manifest) |manifest| {
            try manifest.validate();
        } else if (self.checkpoint_lsn != 0) return error.InvalidSnapshotCoverage;
    }

    pub fn needsWal(self: SourceCut) !bool {
        try self.validate();
        return self.checkpoint_lsn < self.accepted.next_lsn;
    }
};

pub const Consistency = union(enum) {
    /// All sources have one exclusive frontier in the same acceptance domain.
    single_partition: Position,
    /// Exact individual bases, without a cross-partition consistency promise.
    independent: void,
};

/// The source directory is immutable and paged; source count is not a resident
/// array bound. A pin owner publishes this root only after retaining every cut.
pub const Snapshot = struct {
    definition: p.Growth.Definition,
    owner: Operation,
    branch: u64,
    catalog_root: Content,
    sources_root: Content,
    source_count: u64,
    consistency: Consistency,

    pub fn validate(self: Snapshot) !void {
        try self.owner.validate();
        try self.catalog_root.validate();
        try self.sources_root.validate();
        if (self.branch == 0) return error.InvalidDataIdentity;
        switch (self.consistency) {
            .single_partition => |position| try position.validate(),
            .independent => {},
        }
    }

    pub fn requireSource(self: Snapshot, source: SourceCut) !void {
        try self.validate();
        try source.validate();
        if (!std.meta.eql(self.owner.scope, source.interpretation.object.scope) or
            self.branch != source.interpretation.object.branch) return error.DataIdentityConflict;
        switch (self.consistency) {
            .single_partition => |position| if (!std.meta.eql(position, source.accepted)) return error.InconsistentSnapshot,
            .independent => {},
        }
    }
};

/// This envelope distinguishes unavailable observation from an authoritative
/// terminal result. The owning operation separately authorizes every disclosure.
pub const Observation = union(enum) {
    unavailable: void,
    denied: void,
    not_observed: void,
    admitted: Binding,
    committed: Commit,
    rejected: Binding,
    cancelled: Binding,

    pub fn validate(self: Observation) !void {
        switch (self) {
            .unavailable, .denied, .not_observed => {},
            .admitted, .rejected, .cancelled => |binding| try binding.validate(),
            .committed => |commit| try commit.validate(),
        }
    }
};

/// Schema roots, not a request envelope or a new service endpoint.
pub const SchemaTypes = struct {
    resource_initialization: ResourceInitialization,
    binding: Binding,
    commit: Commit,
    source_cut: SourceCut,
    snapshot: Snapshot,
    observation: Observation,
};

test {
    _ = @import("data_lifecycle_test.zig");
}
