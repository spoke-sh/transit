//! Bounded catalog control records for general Tables. Public transitions own
//! current policy and compose these records with Table/native commit decisions.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const Meta = c.TableMetadata;
const Pub = c.station.Publication;
const Ref = c.station.TablePages.Reference;
pub const Scope = c.Model.Scope;
pub const Configuration = struct {
    scope: Scope,
    owner: u64,
    administrator: u64,
    table_limits: Pub.Limits,
    authority: c.TableAuthority.Profile,
    database_name: c.TableAuthority.Name,
    pub fn validate(self: Configuration) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.owner);
        // Principals include native root zero. Ownership/resource identities
        // remain nonzero; selecting root here grants no implicit catalog bypass.
        if (self.administrator > p.max_counter) return error.InvalidCatalogIdentity;
        try self.table_limits.validate();
        try self.authority.validate();
        try self.database_name.validate();
        if (self.table_limits.record_bytes > c.fuze.TableRow.max_bytes) return error.InvalidCatalogLimits;
    }
};
pub const Right = enum { inspect, create, read, insert, update, delete, alter, drop };
pub const Kind = enum(u8) { create = 1, alter = 2, rename = 3, drop = 4 };
pub const ObjectKind = enum(u8) { table = 1, kv = 2, document = 3 };
pub const LifecycleState = enum(u8) { defined = 1, published = 2, pending = 3, complete = 4, unavailable = 5 };
pub const LifecycleEvidence = struct {
    kind: ObjectKind,
    state: LifecycleState,
    scope: Scope,
    namespace: u64,
    object: u64,
    revision: u64,
    name: Meta.Name,
    definition_digest: [32]u8,
    resource_revision: u64,
    pending_operation: u64 = 0,
    admitted_input: u64 = 0,
    completed_input: u64 = 0,
};
pub const Preview = struct {
    kind: ObjectKind,
    action: Kind,
    name: Meta.Name,
    object: u64,
    expected_revision: u64,
    disposition: enum(u8) { admissible = 1, unchanged = 2, rejected = 3 },
    reason: @FieldType(Operation, "reason") = .none,
    work: c.fuze.TableEvolution.Work = .metadata,
    rebuild_key: bool = false,
    definition_digest: [32]u8 = @splat(0),
    blocker: ?Dependency = null,
    resource_revision: u64,
};
pub const empty_reference: Ref = .{ .id = 0, .spec = .{ .format = 0, .length = 0, .digest = @splat(0) } };
pub fn metadataReference(ref: Ref) !void {
    if (ref.id == 0 or ref.spec.format != Meta.format or ref.spec.length == 0 or ref.spec.length > Meta.max_bytes) return error.InvalidCatalogDefinition;
}
pub const Object = struct {
    scope: Scope,
    object: u64,
    namespace: u64,
    authorization: u64,
    state: enum(u8) { initializing = 1, live = 2, retired = 3 },
    metadata: Ref = empty_reference,
    next_revision: u64,
    pending_principal: u64 = 0,
    pending_operation: u64 = 0,
    pending_revision: u64 = 0,
    pending_digest: [32]u8 = @splat(0),
    pub fn validate(self: Object) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.namespace);
        try c.Model.nativeId(self.authorization);
        if (self.object == 0 or self.next_revision == 0 or self.pending_principal > p.max_counter) return error.InvalidCatalogObject;
        if (self.state == .initializing) {
            if (!std.meta.eql(self.metadata, empty_reference) or self.pending_operation == 0 or self.pending_revision != 1 or self.next_revision != 2) return error.InvalidCatalogObject;
        } else if (self.state == .retired and self.metadata.id == 0) {
            if (!std.meta.eql(self.metadata, empty_reference) or self.next_revision < 2) return error.InvalidCatalogObject;
        } else {
            try metadataReference(self.metadata);
            if (self.metadata.id >= self.next_revision) return error.InvalidCatalogObject;
        }
        if (self.pending_operation == 0) {
            if (self.pending_principal != 0 or self.pending_revision != 0 or !std.mem.eql(u8, &self.pending_digest, &@as([32]u8, @splat(0)))) return error.InvalidCatalogObject;
        } else if (self.state == .retired or self.pending_revision == 0 or self.pending_revision != self.next_revision - 1 or self.pending_revision <= self.metadata.id) return error.InvalidCatalogObject;
    }
    pub fn clearPending(self: *Object) void {
        self.pending_principal = 0;
        self.pending_operation = 0;
        self.pending_revision = 0;
        self.pending_digest = @splat(0);
    }
};
pub const Operation = struct {
    scope: Scope,
    principal: u64,
    operation: u64,
    object: u64,
    actual_object: u64 = 0,
    namespace: u64 = 1,
    digest: [32]u8,
    kind: Kind,
    state: enum(u8) { preparing = 1, delegated = 2, applied = 3, unchanged = 4, rejected = 5, cancelled = 6 },
    reason: enum(u8) { none = 0, name_conflict = 1, object_conflict = 2, not_found = 3, dependency = 4, schema_changed = 5 } = .none,
    metadata: Ref = empty_reference,
    table_digest: [32]u8 = @splat(0),
    admitted_input: u64,
    completed_input: u64 = 0,
    blocker: union(enum(u8)) {
        none = 0,
        dependency: struct { identity: u64, owner: u64, kind: @FieldType(Dependency, "kind") } = 1,
    } = .none,
    pub fn validate(self: Operation) !void {
        try self.scope.validate();
        if (self.principal > p.max_counter or self.operation == 0 or self.admitted_input == 0 or self.admitted_input > p.max_counter or self.completed_input > p.max_counter) return error.InvalidCatalogReceipt;
        const active = self.state == .preparing or self.state == .delegated;
        if (active != (self.completed_input == 0) or (self.completed_input != 0 and self.completed_input < self.admitted_input)) return error.InvalidCatalogReceipt;
        if ((self.state == .rejected) != (self.reason != .none)) return error.InvalidCatalogReceipt;
        if ((self.reason == .dependency) != (self.blocker == .dependency)) return error.InvalidCatalogReceipt;
        if (self.blocker == .dependency) {
            const evidence = self.blocker.dependency;
            if (self.kind != .drop or self.object == 0 or self.actual_object != self.object or evidence.identity == 0 or evidence.kind == .history) return error.InvalidCatalogReceipt;
            try c.Model.nativeId(evidence.owner);
        }
        if (self.state == .delegated and self.kind != .alter) return error.InvalidCatalogReceipt;
        if ((active or self.state == .applied) and self.object == 0) return error.InvalidCatalogReceipt;
        if (self.metadata.id != 0) try metadataReference(self.metadata) else if (!std.meta.eql(self.metadata, empty_reference)) return error.InvalidCatalogReceipt;
        if (self.state == .delegated and self.metadata.id == 0) return error.InvalidCatalogReceipt;
        if ((self.state == .applied or self.state == .delegated) and (self.metadata.id == 0 or self.actual_object != self.object)) return error.InvalidCatalogReceipt;
        if (self.kind != .alter and !std.mem.eql(u8, &self.table_digest, &@as([32]u8, @splat(0)))) return error.InvalidCatalogReceipt;
    }
    pub fn tableReference(self: Operation) !c.station.TableWrite.Reference {
        try self.validate();
        if (self.kind != .alter or self.object == 0) return error.InvalidCatalogReceipt;
        return .{ .resource = self.scope.resource, .object = self.object, .principal = self.principal, .operation = self.operation, .digest = self.table_digest };
    }
};
pub const Binding = struct {
    scope: Scope,
    object: u64,
    pub fn validate(self: Binding) !void {
        try self.scope.validate();
        if (self.object == 0) return error.InvalidCatalogBinding;
    }
};
pub const Dependency = struct {
    scope: Scope,
    object: u64,
    identity: u64,
    owner: u64,
    kind: enum(u8) { query_source = 1, writer = 2, watch = 3, maintained_relation = 4, history = 5 },
    pub fn validate(self: Dependency) !void {
        try self.scope.validate();
        if (self.object == 0 or self.identity == 0) return error.InvalidCatalogDependency;
        try c.Model.nativeId(self.owner);
    }
    pub fn restricts(self: Dependency) bool {
        return self.kind != .history;
    }
};
pub const DependencyCursor = struct {
    scope: Scope,
    resource_revision: u64,
    subject: u64,
    after: u64,
};
pub const DependencyPage = struct {
    entries: [p.Growth.page_size]?Dependency = @splat(null),
    next: ?DependencyCursor = null,
    resource_revision: u64,
};
pub const PolicyReferences = struct {
    kind: ObjectKind,
    scope: Scope,
    namespace: u64,
    object: u64,
    authorization_domain: u64,
    authorization_object: u64,
    schema_authorization: u64,
    owner_pid: u64,
    retention_unlimited: bool = true,
    record_bytes: u32,
    staging_bytes: u64,
    staging_records: u32,
    can_read: bool,
    redacted: bool,
    resource_revision: u64,
};
