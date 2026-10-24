//! Direct catalog lifecycle. The control log admits exact work and reserves
//! names; only the Table acceptance log publishes its definition and row state.
//! Callers serialize this owner's directory and DDL methods. Data scans and row
//! writes use separately acquired Table owners and never publish a catalog root.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const a = c.TableAuthority;
const s = c.storage;
const r = @import("DirectCatalogRecords.zig");
const Store = @import("DirectCatalogStore.zig");
const IntentStore = @import("DirectCatalogIntent.zig");
const N = c.DirectNamespace;
const Dependency = c.DirectDependency;
const Resource = c.DirectResource;
const P = s.TablePartition;
const pages = s.TreeStore.pages;
const Self = @This();
pub const Configuration = r.Configuration;
pub const Request = r.Request;
pub const Intent = r.Intent;
pub const Properties = r.Properties;
pub const Options = struct { resident_pages: usize = 16, index_work_bytes: usize = 64 * 1024 * 1024, table: P.Options = .{} };

/// The service implements these callbacks using the existing native authority.
/// make_guard returns an independently owned context in the supplied request
/// allocator; later callbacks must not overwrite an earlier guard's identity.
/// Its optional final argument is an additional acceptance prerequisite. The
/// provider checks it with the primary guard under the same authority fence.
/// Observation and cancellation retain primary rights without requiring new
/// acceptance rights from the original prerequisite subject.
pub const Policy = struct {
    context: *anyopaque,
    subject: p.Authorization.Subject,
    make_guard: *const fn (*anyopaque, std.mem.Allocator, p.Authorization.Guard, ?p.Authorization.Guard) anyerror!P.Guard,
    registered: *const fn (*anyopaque, a.Kind, u64) anyerror!?p.Authorization.Object,
    native_resource: ?Resource.Native = null,
};
pub const View = struct {
    table: P,
    properties: Properties,
    pub fn deinit(self: *View) void {
        self.table.deinit();
        self.* = undefined;
    }
};
pub const Current = struct {
    view: View,
    authority: c.DirectReadAuthority,
    page: ?P.CurrentPage,
    pub fn deinit(self: *Current) void {
        if (self.page) |*page| page.deinit();
        self.view.deinit();
        self.* = undefined;
    }
};
pub const CurrentRead = struct {
    current: Current,
    selection: union(enum) { key: ?P.OwnedRow, rows: P.RowPage },
    pub fn deinit(self: *CurrentRead) void {
        switch (self.selection) {
            .key => |*maybe| if (maybe.*) |*row| row.deinit(),
            .rows => |*page| page.deinit(),
        }
        self.current.deinit();
        self.* = undefined;
    }
};
pub const Observation = union(enum) {
    not_observed,
    admitted: r.Operation,
    committed: P.Evidence,
    rejected: r.Operation,
    cancelled: r.Operation,
};
pub const Listed = struct { interpretation: d.Definition, namespace: u64, name: a.Name, position: d.Position, changed_lsn: u64 };
pub const Preview = struct {
    pub const Basis = struct { interpretation: s.TableDeclaration.Stored, position: d.Position, changed_lsn: u64, row_count: u64 };
    binding: d.Binding,
    directory_position: d.Position,
    current: ?Basis,
    reason: r.Reason,
    work: ?c.fuze.TableEvolution.Work = null,
    rebuild_key: bool = false,
    schema_fingerprint: ?[32]u8 = null,
};
pub const Page = struct {
    entries: [pages.page_entries]?Listed = @splat(null),
    next: ?pages.Key = null,
    directory_position: d.Position,
    consistency: enum { independent } = .independent,
};

allocator: std.mem.Allocator,
store: Store,
data_log: s.TransitLog.Log,
data_objects: s.TransitObjectStore.ObjectStore,
options: Options,
/// Failure injection after the Table acceptance and before its caller reply.
lose_table_reply: bool = false,

pub fn init(allocator: std.mem.Allocator, configuration: Configuration, control_log: s.TransitLog.Log, control_objects: s.TransitObjectStore.ObjectStore, data_log: s.TransitLog.Log, data_objects: s.TransitObjectStore.ObjectStore, options: Options) !Self {
    if (options.index_work_bytes == 0) return error.InvalidStorageBudget;
    return .{ .allocator = allocator, .store = try Store.init(allocator, configuration, control_log, control_objects, options.resident_pages), .data_log = data_log, .data_objects = data_objects, .options = options };
}
pub fn deinit(self: *Self) void {
    self.store.deinit();
    self.* = undefined;
}
pub fn recover(self: *Self) !void {
    try self.store.recover();
}

fn namedRecord(self: *Self, object: u64) !?Resource.Operation {
    const target = try self.entry(object) orelse return null;
    const at = target.resource orelse return null;
    const value = try self.store.resourceRecord(at);
    if (value.binding.object.object != object) return error.InvalidDirectCatalogEntry;
    return value;
}

fn resourceRequirements(self: *Self, policy: Policy, binding: Resource.Binding, value: ?Resource.Definition, write: bool) !p.Authorization.Guard {
    const namespace = try self.authorizationSchema(if (value) |known| known.namespace else if (binding.action == .create) binding.action.create.namespace else return error.CatalogDenied);
    const target: ?a.Table = if (value) |known| .{ .id = known.object.object, .schema = known.namespace, .authorization = known.authorization } else null;
    const access: a.Access = if (binding.action == .create and (write or value == null)) .create_table else if (write) .alter else .inspect;
    var required = try self.requirements(policy, namespace, target, access);
    if (binding.action == .create and (write or value == null)) required.selectable = binding.action.create.owner;
    return required;
}

fn resourceReason(self: *Self, binding: Resource.Binding, current: P.Guard) !Resource.Reason {
    if (binding.action == .create) {
        const proposed = binding.action.create;
        if (try self.namespacePending(proposed.namespace) != null or try self.entry(binding.object.object) != null) return .object_conflict;
        _ = try self.schema(proposed.namespace);
        if (!try self.available(proposed.namespace, proposed.name, binding.object.object, current)) return .name_conflict;
        return .none;
    }
    const known = try self.namedRecord(binding.object.object) orelse return .object_conflict;
    if (known.phase != .complete or known.retired) return .object_conflict;
    const value = known.resulting.?;
    if (try self.namespacePending(value.namespace) != null or try self.pending(binding.object.object, current)) return .object_conflict;
    if (!std.meta.eql(binding.expected.?, try value.interpretation(self.allocator))) return .stale_definition;
    if (binding.action == .drop and try self.hasDependents(binding.object.object)) return .dependency;
    if (binding.action == .rename and !try self.available(value.namespace, binding.action.rename, binding.object.object, current)) return .name_conflict;
    return .none;
}

fn recordResource(self: *Self, operation_input: Resource.Operation, previous: ?Resource.Operation, current: P.Guard) !Resource.Operation {
    try self.store.index.begin(self.options.index_work_bytes);
    defer self.store.index.end();
    var next = self.store.root;
    var operation = operation_input;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    operation.position = .{ .partition = self.config().partition, .next_lsn = next.next_lsn };
    try operation.validate();
    const binding = operation.binding;
    const id = try r.idKey(binding.object.object);
    const updates_object = if (binding.action == .create) operation.phase == .admitted or previous != null else operation.phase == .complete;
    if (updates_object) {
        const target: r.Entry = .{ .object = binding.object.object, .partition = 0, .seed = null, .resource = self.store.root.next_lsn };
        next.objects = try self.store.tree().put(next.objects, id, try r.pageValue(target));
    }
    if (operation.phase == .admitted and binding.action != .drop) {
        const namespace = if (binding.action == .create) binding.action.create.namespace else operation.resulting.?.namespace;
        const name = if (binding.action == .create) binding.action.create.name else binding.action.rename;
        const candidate_name: r.Name = .{ .namespace = namespace, .name = name, .object = binding.object.object, .reservation = binding.identity() };
        next.names = try self.store.tree().put(next.names, try r.nameKey(namespace, name), try r.pageValue(candidate_name));
    }
    if (operation.pending()) {
        next.pending = try self.store.tree().put(next.pending, id, try r.pageValue(binding.identity()));
    } else if (previous != null) next.pending = try self.store.tree().remove(next.pending, id);
    if (operation.phase == .prepared) {
        next.native_allocations = try self.store.tree().put(next.native_allocations, try r.principalKey(binding.connection.principal), try r.pageValue(binding.identity()));
    } else if (previous != null and previous.?.phase == .prepared) {
        next.native_allocations = try self.store.tree().remove(next.native_allocations, try r.principalKey(binding.connection.principal));
    }
    try self.store.receiptIdentity(&next, binding.identity());
    try self.store.publish(next, .{ .resource = operation }, current);
    return operation;
}

/// Admission and metadata control share the Table directory and native role
/// authority. They do not allocate, initialize, retire or delete native data.
pub fn previewResource(self: *Self, binding: Resource.Binding, policy: Policy) !Resource.Preview {
    try self.requireInitialized();
    try binding.validate();
    if (!binding.connection.matches(self.config()) or binding.connection.principal != policy.subject.principal()) return error.CatalogDenied;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const known = try self.namedRecord(binding.object.object);
    const value = if (known) |operation| operation.resulting else null;
    const required = try self.resourceRequirements(policy, binding, value, true);
    const current = try policy.make_guard(policy.context, arena.allocator(), required, null);
    try check(current);
    if (try c.OperationBinding.lookupResource(self.allocator, self.store.objects, binding.identity())) |claimed| try binding.requireSame(claimed);
    const result: Resource.Preview = .{ .binding = binding, .position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn }, .current = value, .reason = try self.resourceReason(binding, current) };
    try check(current);
    return result;
}

pub fn resourceOperation(self: *Self, binding: Resource.Binding, command: Resource.Command, policy: Policy) !Resource.Observation {
    try self.requireInitialized();
    try binding.validate();
    if (!binding.connection.matches(self.config()) or binding.connection.principal != policy.subject.principal()) return error.CatalogDenied;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const known = try self.namedRecord(binding.object.object);
    const definition = if (known) |value| value.resulting else null;
    const required = try self.resourceRequirements(policy, binding, definition, command != .inspect);
    const current = try policy.make_guard(policy.context, arena.allocator(), required, null);
    try check(current);
    if (try c.OperationBinding.lookupResource(self.allocator, self.store.objects, binding.identity())) |claimed| try binding.requireSame(claimed);
    const previous = try self.store.resourceOperation(binding);
    if (command == .inspect or (previous != null and !previous.?.pending())) {
        try check(current);
        return if (previous) |value| .{ .operation = value } else .not_observed;
    }
    if (command == .execute and previous == null) return error.NamedResourceNotAdmitted;
    if (command == .admit and previous != null) {
        try check(current);
        return .{ .operation = previous.? };
    }
    var operation = previous orelse Resource.Operation{ .binding = binding, .position = .{ .partition = self.config().partition, .next_lsn = 1 }, .phase = .admitted, .reason = .none, .allocation = null, .resulting = if (binding.action == .create) null else definition, .retired = false };
    var publication_guard = current;
    switch (command) {
        .inspect => unreachable,
        .admit => {
            operation.reason = try self.resourceReason(binding, current);
            if (operation.reason != .none) operation.phase = .rejected;
        },
        .cancel => {
            // The service first reconciles an accepted native allocation, even
            // if its reply was lost before the catalog recorded the resource.
            if (binding.action == .create and operation.allocation != null and operation.resulting == null) {
                const native = policy.native_resource orelse return error.NamedResourceNativeUnavailable;
                const allocation_id = native.allocation(native.context, binding, operation.allocation.?) catch |err| if (err == error.ConflictingRetry) null else return err;
                if (allocation_id != null) return error.NamedResourceAllocationUnreconciled;
            }
            operation.phase = .cancelled;
        },
        .execute => if (binding.action == .create) {
            if (operation.phase != .allocated) return .{ .operation = operation };
            const native = policy.native_resource orelse return error.NamedResourceNativeUnavailable;
            const value = operation.resulting.?;
            var native_required = required;
            const metadata: p.Authorization.Guard = .{ .subject = policy.subject, .requirements = blk: {
                var requirements_value: [p.Authorization.max_requirements]?p.Authorization.Requirement = @splat(null);
                requirements_value[0] = .{ .object = .{ .kind = .resource, .id = value.resource }, .privileges = p.State.permission(.inspect) | p.State.permission(.read) };
                break :blk requirements_value;
            } };
            native_required = try native_required.merge(metadata);
            publication_guard = try native.make_guard(native.context, arena.allocator(), native_required, .{ .binding = binding, .allocation = operation.allocation.?, .resource = value.resource, .initialization = try value.initialization(self.allocator) });
            try check(publication_guard);
            operation.phase = .complete;
        } else {
            if (binding.action == .drop and try self.hasDependents(binding.object.object)) {
                operation.phase = .rejected;
                operation.reason = .dependency;
            } else {
                var result = operation.resulting.?;
                result.revision = try std.math.add(u64, result.revision, 1);
                if (binding.action == .rename) result.name = binding.action.rename;
                operation.resulting = result;
                operation.retired = binding.action == .drop;
                operation.phase = .complete;
            }
        },
    }
    try c.OperationBinding.claimResource(self.allocator, self.store.objects, binding);
    return .{ .operation = try self.recordResource(operation, previous, publication_guard) };
}

/// A recorded allocation is partial progress, including when the resource has
/// since retired. The provider checks its original receipt under the same fence
/// as catalog publication; a caller-supplied numeric ID cannot pass this step.
pub fn attachResource(self: *Self, binding: Resource.Binding, resource: u64, policy: Policy) !Resource.Observation {
    const observed = try self.resourceOperation(binding, .inspect, policy);
    if (observed != .operation or observed.operation.phase != .prepared or binding.action != .create) return observed;
    try c.Model.nativeId(resource);
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const proposed = binding.action.create;
    const namespace = try self.schema(proposed.namespace);
    const registration_value = try policy.registered(policy.context, .table, binding.object.object) orelse return error.CatalogRegistrationRequired;
    try a.validateObject(self.config().authority, self.config().scope, .table, binding.object.object, a.reference(namespace.authorization), registration_value);
    if (registration_value.owner != proposed.owner) return error.CatalogIdentityConflict;
    const result: Resource.Definition = .{ .object = binding.object, .revision = 1, .namespace = proposed.namespace, .name = proposed.name, .authorization = registration_value.reference.id, .resource = resource, .allocating_principal = binding.connection.principal, .allocation = observed.operation.allocation.?, .creation = proposed };
    var required = try self.resourceRequirements(policy, binding, result, true);
    var native_required: p.Authorization.Guard = .{ .subject = policy.subject, .requirements = @splat(null) };
    native_required.requirements[0] = .{ .object = .{ .kind = .resource, .id = resource }, .privileges = p.State.permission(.inspect) };
    required = try required.merge(native_required);
    const native = policy.native_resource orelse return error.NamedResourceNativeUnavailable;
    const current = try native.make_guard(native.context, arena.allocator(), required, .{ .binding = binding, .allocation = observed.operation.allocation.?, .resource = resource, .initialization = null });
    try check(current);
    var operation = observed.operation;
    operation.phase = .allocated;
    operation.resulting = result;
    return .{ .operation = try self.recordResource(operation, observed.operation, current) };
}

pub fn resourceRegistration(self: *Self, binding: Resource.Binding, policy: Policy) !?Registration {
    const observed = try self.resourceOperation(binding, .inspect, policy);
    if (observed != .operation or observed.operation.phase != .admitted or binding.action != .create) return null;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const required = try self.resourceRequirements(policy, binding, null, true);
    const current = try policy.make_guard(policy.context, arena.allocator(), required, null);
    const namespace = try self.schema(binding.action.create.namespace);
    const registered_value = try policy.registered(policy.context, .table, binding.object.object);
    const fence = try current.acquire(current.context);
    defer current.release(current.context);
    if (registered_value != null) return null;
    return .{ .action = .{ .domain = self.config().authority.table_domain, .owner = binding.action.create.owner, .schema = a.reference(namespace.authorization), .binding = try a.binding(self.config().scope, .table, binding.object.object) }, .authorization_revision = fence.policy_epoch - 1 };
}

/// Rechecked before the service accepts the frozen signed native request. The
/// native authority separately enforces the caller's ADMIN right on its writer.
pub fn resourceAllocation(self: *Self, binding: Resource.Binding, policy: Policy) !?p.Growth.Request {
    const observed = try self.resourceOperation(binding, .inspect, policy);
    if (observed != .operation or observed.operation.phase != .prepared or binding.action != .create) return null;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const required = try self.resourceAllocationRequirements(binding, policy);
    try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
    return try binding.allocation(observed.operation.allocation.?);
}

fn resourceAllocationRequirements(self: *Self, binding: Resource.Binding, policy: Policy) !p.Authorization.Guard {
    const namespace = try self.schema(binding.action.create.namespace);
    const registered_value = try policy.registered(policy.context, .table, binding.object.object) orelse return error.CatalogRegistrationRequired;
    try a.validateObject(self.config().authority, self.config().scope, .table, binding.object.object, a.reference(namespace.authorization), registered_value);
    if (registered_value.owner != binding.action.create.owner) return error.CatalogIdentityConflict;
    var required = try self.resourceRequirements(policy, binding, null, true);
    var native_required: p.Authorization.Guard = .{ .subject = policy.subject, .requirements = @splat(null) };
    native_required.requirements[0] = .{ .object = .{ .kind = .process, .id = binding.action.create.writer }, .privileges = p.permission(.admin) };
    required = try required.merge(native_required);
    return required;
}

pub fn prepareResourceAllocation(self: *Self, binding: Resource.Binding, policy: Policy) !Resource.Observation {
    const observed = try self.resourceOperation(binding, .inspect, policy);
    if (observed != .operation or observed.operation.phase != .admitted or binding.action != .create) return observed;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const required = try self.resourceAllocationRequirements(binding, policy);
    try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
    // The native sequence belongs to the original caller. Only one declaration
    // in this catalog may hold its next allocation at a time. Other native
    // commands can still race; the native receipt/CAS remains authoritative.
    if (try self.store.tree().get(self.store.root.native_allocations, try r.principalKey(binding.connection.principal)) != null) return error.NativeAllocationBusy;
    const native = policy.native_resource orelse return error.NamedResourceNativeUnavailable;
    const allocation = try native.prepare(native.context, binding);
    const current = try native.make_guard(native.context, arena.allocator(), required, .{ .binding = binding, .allocation = allocation, .resource = null, .initialization = null });
    try check(current);
    var operation = observed.operation;
    operation.allocation = allocation;
    operation.phase = .prepared;
    return .{ .operation = try self.recordResource(operation, observed.operation, current) };
}

pub const ResourceView = struct { definition: Resource.Definition, interpretation: d.Definition, position: d.Position };
pub fn resolveResource(self: *Self, namespace_id: u64, name: a.Name, policy: Policy) !?ResourceView {
    try self.requireInitialized();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const namespace = try self.schema(namespace_id);
    const initial = try self.guard(arena.allocator(), policy, namespace, null, .schema);
    try check(initial);
    const candidate_name = try self.candidate(namespace_id, name) orelse {
        try check(initial);
        return null;
    };
    const known = try self.namedRecord(candidate_name.object) orelse {
        try check(initial);
        return null;
    };
    if (known.phase != .complete or known.retired) {
        try check(initial);
        return null;
    }
    const value = known.resulting.?;
    if (value.namespace != namespace_id or !std.meta.eql(value.name, name)) {
        try check(initial);
        return null;
    }
    try check(try self.guard(arena.allocator(), policy, namespace, .{ .id = value.object.object, .schema = namespace_id, .authorization = value.authorization }, .inspect));
    return .{ .definition = value, .interpretation = try value.interpretation(self.allocator), .position = known.position };
}

pub const ResourcePage = struct { entries: [pages.page_entries]?ResourceView = @splat(null), next: ?pages.Key, position: d.Position };
/// One bounded page of catalog metadata. Every accepted definition retains its
/// publication evidence; this read does not certify current native data access
/// or resource lifetime. Empty filtered pages still advance their continuation.
pub fn listResources(self: *Self, namespace_id: u64, after: ?pages.Key, policy: Policy) !ResourcePage {
    try self.requireInitialized();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const namespace = try self.schema(namespace_id);
    var combined = try self.requirements(policy, namespace, null, .schema);
    try check(try policy.make_guard(policy.context, arena.allocator(), combined, null));
    const batch = try self.store.tree().scan(self.store.root.objects, after);
    var result: ResourcePage = .{ .next = batch.next, .position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn } };
    var count: usize = 0;
    for (batch.entries) |slot| if (slot) |item| {
        const target = try r.fromValue(r.Entry, self.allocator, item.value);
        try target.validate(self.config());
        if (!std.meta.eql(item.key, try r.idKey(target.object))) return error.InvalidDirectCatalogEntry;
        const at = target.resource orelse continue;
        const known = try self.store.resourceRecord(at);
        if (known.binding.object.object != target.object) return error.InvalidDirectCatalogEntry;
        if (known.phase != .complete or known.retired) continue;
        const value = known.resulting.?;
        if (value.namespace != namespace_id) continue;
        const required = try self.requirements(policy, namespace, .{ .id = target.object, .schema = namespace_id, .authorization = value.authorization }, .inspect);
        check(try policy.make_guard(policy.context, arena.allocator(), required, null)) catch |err| {
            if (err == error.CatalogDenied or err == error.Forbidden) continue;
            return err;
        };
        combined = try combined.merge(required);
        result.entries[count] = .{ .definition = value, .interpretation = try value.interpretation(self.allocator), .position = known.position };
        count += 1;
    };
    try check(try policy.make_guard(policy.context, arena.allocator(), combined, null));
    return result;
}

fn config(self: *Self) Configuration {
    return self.store.root.configuration;
}
fn requireInitialized(self: *Self) !void {
    try self.store.refresh();
    if (!self.store.root.initialized) return error.CatalogNotInitialized;
}

fn verifiedObject(self: *Self, policy: Policy, kind: a.Kind, id: u64, native: u64, parent: ?p.Authorization.ObjectRef) !void {
    const object = try policy.registered(policy.context, kind, id) orelse return error.CatalogRegistrationRequired;
    try a.validateObject(self.config().authority, self.config().scope, kind, id, parent, object);
    if (object.reference.id != native) return error.CatalogIdentityConflict;
}

fn requirements(self: *Self, policy: Policy, namespace: ?a.Schema, target: ?a.Table, access: a.Access) !p.Authorization.Guard {
    const profile = self.config().authority;
    try policy.subject.validate();
    if (policy.subject.audience() != self.config().audience) return error.CatalogDenied;
    try self.verifiedObject(policy, .database, 0, profile.database, null);
    if (namespace) |value| try self.verifiedObject(policy, .schema, value.id, value.authorization, a.reference(profile.database));
    if (target) |value| try self.verifiedObject(policy, .table, value.id, value.authorization, a.reference((namespace orelse return error.InvalidCatalogConfiguration).authorization));
    var requested = try a.guard(policy.subject, profile, namespace, target, access);
    // CREATE must still own the explicitly registered target at publication;
    // namespace CREATE alone cannot adopt another role's registered identity.
    if (access == .create_table) if (target) |value| {
        requested.requirements[2] = .{ .object = a.reference(value.authorization), .access = .ownership };
    };
    return requested;
}

fn guard(self: *Self, allocator: std.mem.Allocator, policy: Policy, namespace: ?a.Schema, target: ?a.Table, access: a.Access) !P.Guard {
    return policy.make_guard(policy.context, allocator, try self.requirements(policy, namespace, target, access), null);
}

fn check(current: P.Guard) !void {
    _ = try current.acquire(current.context);
    current.release(current.context);
}

fn schema(self: *Self, id: u64) !a.Schema {
    const result = try self.storedSchema(id) orelse return error.CatalogNamespaceMissing;
    if (result.retired) return error.CatalogNamespaceMissing;
    return result;
}
fn storedSchema(self: *Self, id: u64) !?a.Schema {
    const value = try self.store.tree().get(self.store.root.schemas, try r.idKey(id)) orelse return null;
    const result = try r.fromValue(a.Schema, self.allocator, value);
    try result.validate();
    if (result.id != id or !std.meta.eql(result.scope, self.config().scope)) return error.InvalidDirectCatalogEntry;
    return result;
}
// Logical retirement removes admission/name visibility, not the original
// native permission object protecting retained Table data and receipts.
fn authorizationSchema(self: *Self, id: u64) !a.Schema {
    var result = try self.storedSchema(id) orelse return error.CatalogNamespaceMissing;
    result.retired = false;
    return result;
}

/// Current namespace metadata under CONNECT/USAGE. This creates no definition
/// or operation, and its native reference grants no rights by itself.
pub fn inspectNamespace(self: *Self, id: u64, policy: Policy) !?a.Schema {
    try self.requireInitialized();
    try c.Model.nativeId(id);
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const database = try self.guard(arena.allocator(), policy, null, null, .database);
    try check(database);
    const found = self.schema(id) catch |err| switch (err) {
        error.CatalogNamespaceMissing => {
            try check(database);
            return null;
        },
        else => return err,
    };
    try check(try self.guard(arena.allocator(), policy, found, null, .schema));
    return found;
}

pub const AccessRequest = struct {
    namespace: ?u64,
    target: ?d.Definition,
    access: a.Access,
    pub fn validate(self: AccessRequest, scope: d.Scope, branch: u64) !void {
        const database_only = self.access == .database or self.access == .create_schema;
        const table_required = !database_only and self.access != .schema and self.access != .create_table;
        if (database_only != (self.namespace == null) or table_required != (self.target != null)) return error.InvalidTableAccessRequest;
        if (self.namespace) |id| try c.Model.nativeId(id);
        if (self.target) |target| {
            try target.validate();
            if (!std.meta.eql(target.object.scope, scope) or target.object.branch != branch) return error.CatalogDenied;
        }
    }
};

/// Preparation checks exact current interpretation and action-specific rights
/// without admission, native provisioning, a read pin or raw resource access.
pub fn checkAccess(self: *Self, request: AccessRequest, policy: Policy) !void {
    try self.requireInitialized();
    try request.validate(self.config().scope, self.config().branch);
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const namespace_value = if (request.namespace) |id| try self.schema(id) else null;
    const initial = try self.guard(arena.allocator(), policy, namespace_value, null, if (namespace_value != null) .schema else .database);
    try check(initial);
    var view: ?View = null;
    defer if (view) |*value| value.deinit();
    if (request.target) |expected| {
        const target_entry = try self.entry(expected.object.object) orelse return error.CatalogDenied;
        if (target_entry.seed == null) return error.CatalogDenied;
        view = try self.open(self.allocator, target_entry, false);
        if (view.?.table.root.next_lsn == 0 or view.?.table.root.retired or view.?.properties.namespace != request.namespace.?) return error.CatalogDenied;
        const required = try self.guard(arena.allocator(), policy, namespace_value, view.?.properties.target(expected.object.object), request.access);
        try check(required);
        if (!std.meta.eql(expected, view.?.table.root.interpretation)) return error.TableDefinitionChanged;
        try check(required);
    } else try check(try self.guard(arena.allocator(), policy, namespace_value, null, request.access));
}

/// Observe one exact current definition and optionally its first bounded row
/// page. This is read-only and carries no durable retention or continuation.
/// The service serializes the target Table while this observation is copied.
pub fn observe(self: *Self, allocator: std.mem.Allocator, namespace_id: u64, expected: d.Definition, limits: ?P.ReadLimits, policy: Policy) !Current {
    try self.requireInitialized();
    try (AccessRequest{ .namespace = namespace_id, .target = expected, .access = .read }).validate(self.config().scope, self.config().branch);
    if (limits) |value| try value.validate();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const namespace_value = try self.schema(namespace_id);
    try check(try self.guard(arena.allocator(), policy, namespace_value, null, .schema));
    const target = try self.entry(expected.object.object) orelse return error.CatalogDenied;
    if (target.seed == null) return error.CatalogDenied;
    var view = try self.open(allocator, target, false);
    errdefer view.deinit();
    if (view.properties.namespace != namespace_id) return error.CatalogDenied;
    const current = try self.guard(arena.allocator(), policy, namespace_value, view.properties.target(expected.object.object), .read);
    try check(current);
    if (view.table.root.retired or view.table.root.next_lsn == 0) return error.TableDefinitionChanged;
    if (!std.meta.eql(expected, view.table.root.interpretation)) return error.TableDefinitionChanged;
    var page: ?P.CurrentPage = if (limits) |value| try view.table.observeRows(allocator, value, current) else null;
    errdefer if (page) |*value| value.deinit();
    const authority: c.DirectReadAuthority = .{ .database = self.config().authority.database, .schema = namespace_value.authorization, .table = view.properties.authorization };
    try authority.validate();
    try check(current);
    return .{ .view = view, .authority = authority, .page = page };
}

/// Optimistic point/suffix reads share current observation's exact definition
/// and authority checks, with a logical-change fence on all row disclosure.
pub fn readCurrent(self: *Self, allocator: std.mem.Allocator, request: c.DirectTableProtocol.CurrentRead, policy: Policy) !CurrentRead {
    var current = try self.observe(allocator, request.namespace, request.interpretation, null, policy);
    errdefer current.deinit();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const required = try self.guard(arena.allocator(), policy, try self.schema(request.namespace), current.view.properties.target(request.interpretation.object.object), .read);
    const selection: @FieldType(CurrentRead, "selection") = switch (request.selection) {
        .key => |binary| blk: {
            const key = try binary.decode(allocator, c.fuze.Collation.max_sort_key_bytes);
            defer allocator.free(key);
            if (key.len == 0) return error.InvalidTableKey;
            break :blk .{ .key = try current.view.table.readCurrent(allocator, request.expected, key, required) };
        },
        .rows => |value| .{ .rows = try current.view.table.scanCurrent(allocator, request.expected, value.after, value.limits, required) },
    };
    return .{ .current = current, .selection = selection };
}

/// Current action rights for frozen operation work, including a retired target.
/// Unlike preparation, this does not demand a current definition: admission and
/// recovery preserve the original expectation and its eventual recorded result.
pub fn checkOperation(self: *Self, binding: d.Binding, namespace_id: u64, policy: Policy) !void {
    try self.requireInitialized();
    try self.original(policy, binding);
    try c.Model.nativeId(namespace_id);
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    try check(try self.guard(arena.allocator(), policy, null, null, .database));
    const namespace_value = try self.authorizationSchema(namespace_id);
    try check(try self.guard(arena.allocator(), policy, namespace_value, null, .schema));
    if (binding.action == .create) {
        const native = try policy.registered(policy.context, .table, binding.target.object);
        const target: ?a.Table = if (native) |value| .{ .id = binding.target.object, .schema = namespace_id, .authorization = value.reference.id } else null;
        try check(try self.guard(arena.allocator(), policy, namespace_value, target, .create_table));
        return;
    }
    const target_entry = try self.entry(binding.target.object) orelse return error.CatalogDenied;
    if (target_entry.seed == null) return error.CatalogDenied;
    var view = try self.open(self.allocator, target_entry, false);
    defer view.deinit();
    if (view.properties.namespace != namespace_id or view.table.root.next_lsn == 0) return error.CatalogDenied;
    const access: a.Access = switch (binding.action) {
        .insert => .insert,
        .update => .update,
        .delete => .delete,
        .alter, .rename => .alter,
        .drop => .drop,
        .create => unreachable,
    };
    try check(try self.guard(arena.allocator(), policy, namespace_value, view.properties.target(binding.target.object), access));
}

pub fn initialize(self: *Self, policy: Policy) !void {
    try self.store.refresh();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const initial: a.Schema = .{ .scope = self.config().scope, .id = self.config().authority.initial_schema, .authorization = self.config().authority.initial_schema_authority, .name = self.config().initial_schema_name, .revision = 1 };
    const current = try self.guard(arena.allocator(), policy, initial, null, .create_schema);
    try check(current);
    if (self.store.root.initialized) return;
    try self.store.index.begin(self.options.index_work_bytes);
    defer self.store.index.end();
    var next = self.store.root;
    next.initialized = true;
    next.next_lsn = 1;
    next.schemas = try self.store.tree().put(null, try r.idKey(initial.id), try r.pageValue(initial));
    next.schema_names = try self.store.tree().put(null, try pages.Key.init(&r.hash(initial.name.slice())), try r.pageValue(N.Name{ .namespace = initial.id, .name = initial.name }));
    try self.store.publish(next, .initialize, current);
}

fn entry(self: *Self, object: u64) !?r.Entry {
    const value = try self.store.tree().get(self.store.root.objects, try r.idKey(object)) orelse return null;
    const result = try r.fromValue(r.Entry, self.allocator, value);
    try result.validate(self.config());
    if (result.object != object or result.partition >= self.store.root.next_partition or (result.resource orelse 0) >= self.store.root.next_lsn) return error.InvalidDirectCatalogEntry;
    return result;
}

fn open(self: *Self, allocator: std.mem.Allocator, target: r.Entry, control: bool) !View {
    if (target.resource != null) return error.CatalogKindMismatch;
    var seed = try s.TableDeclaration.load(allocator, self.data_objects, target.seed orelse return error.CatalogRegistrationRequired);
    defer seed.deinit();
    var options = self.options.table;
    options.control = .{ .log = self.store.log, .objects = self.store.objects };
    var table = try P.init(allocator, target.partition, seed.definition, if (control) self.store.log else self.data_log, if (control) self.store.objects else self.data_objects, options);
    errdefer table.deinit();
    try table.recover();
    const properties = try Properties.decode(allocator, table.declaration.definition.properties);
    return .{ .table = table, .properties = properties };
}

fn candidate(self: *Self, namespace: u64, name: a.Name) !?r.Name {
    const value = try self.store.tree().get(self.store.root.names, try r.nameKey(namespace, name)) orelse return null;
    const result = try r.fromValue(r.Name, self.allocator, value);
    try result.validate(self.config());
    if (result.namespace != namespace or !std.meta.eql(result.name, name)) return error.CatalogNameHashCollision;
    return result;
}

/// A name candidate alone is not a published object. The returned owner has an
/// exact observed Table root; it is not a catalog-wide consistent snapshot.
pub fn resolve(self: *Self, allocator: std.mem.Allocator, namespace_id: u64, name: a.Name, policy: Policy) !?View {
    try self.requireInitialized();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const namespace = try self.schema(namespace_id);
    const initial = try self.guard(arena.allocator(), policy, namespace, null, .schema);
    try check(initial);
    const proposed = try self.candidate(namespace_id, name) orelse {
        try check(initial);
        return null;
    };
    const target = try self.entry(proposed.object) orelse return error.InvalidDirectCatalogName;
    if (target.seed == null) {
        try check(initial);
        return null;
    }
    var view = try self.open(allocator, target, false);
    errdefer view.deinit();
    if (view.table.root.next_lsn == 0 or view.table.root.retired or view.properties.namespace != namespace_id or !std.meta.eql(view.properties.name, name)) {
        view.deinit();
        try check(initial);
        return null;
    }
    try check(try self.guard(arena.allocator(), policy, namespace, view.properties.target(target.object), .inspect));
    return view;
}

/// A bounded directory page with independently observed Table versions. Empty
/// filtered pages can have a continuation. Recheck every included object in one
/// native guard before returning any of the page's metadata to its caller.
pub fn list(self: *Self, namespace_id: u64, after: ?pages.Key, policy: Policy) !Page {
    try self.requireInitialized();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const namespace = try self.schema(namespace_id);
    var combined = try self.requirements(policy, namespace, null, .schema);
    try check(try policy.make_guard(policy.context, arena.allocator(), combined, null));
    const batch = try self.store.tree().scan(self.store.root.objects, after);
    var result: Page = .{ .next = batch.next, .directory_position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn } };
    var count: usize = 0;
    for (batch.entries) |slot| if (slot) |item| {
        const target = try r.fromValue(r.Entry, self.allocator, item.value);
        try target.validate(self.config());
        if (!std.meta.eql(item.key, try r.idKey(target.object))) return error.InvalidDirectCatalogEntry;
        if (target.seed == null) continue;
        var view = try self.open(self.allocator, target, false);
        defer view.deinit();
        if (view.table.root.next_lsn == 0 or view.table.root.retired or view.properties.namespace != namespace_id) continue;
        const required = try self.requirements(policy, namespace, view.properties.target(target.object), .inspect);
        check(try policy.make_guard(policy.context, arena.allocator(), required, null)) catch |err| {
            if (err == error.CatalogDenied or err == error.Forbidden) continue;
            return err;
        };
        combined = try combined.merge(required);
        result.entries[count] = .{ .interpretation = view.table.root.interpretation, .namespace = namespace_id, .name = view.properties.name, .position = .{ .partition = target.partition, .next_lsn = view.table.root.next_lsn }, .changed_lsn = view.table.root.changed_lsn };
        count += 1;
    };
    try check(try policy.make_guard(policy.context, arena.allocator(), combined, null));
    return result;
}

pub const NamespacePage = struct { entries: [8]?a.Schema = @splat(null), next: ?pages.Key = null, directory_position: d.Position };
/// Directory traversal filters current USAGE rights, including empty pages.
pub fn listNamespaces(self: *Self, after: ?pages.Key, policy: Policy) !NamespacePage {
    try self.requireInitialized();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var combined = try self.requirements(policy, null, null, .database);
    try check(try policy.make_guard(policy.context, arena.allocator(), combined, null));
    const batch = try self.store.tree().scan(self.store.root.schemas, after);
    var result: NamespacePage = .{ .next = batch.next, .directory_position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn } };
    var count: usize = 0;
    for (batch.entries) |slot| if (slot) |item| {
        const namespace_value = try r.fromValue(a.Schema, self.allocator, item.value);
        try namespace_value.validate();
        if (!std.meta.eql(item.key, try r.idKey(namespace_value.id)) or !std.meta.eql(namespace_value.scope, self.config().scope)) return error.InvalidDirectCatalogEntry;
        if (namespace_value.retired) continue;
        const required = try self.requirements(policy, namespace_value, null, .schema);
        check(try policy.make_guard(policy.context, arena.allocator(), required, null)) catch |err| {
            if (err == error.CatalogDenied or err == error.Forbidden) continue;
            return err;
        };
        combined = try combined.merge(required);
        result.entries[count] = namespace_value;
        count += 1;
    };
    try check(try policy.make_guard(policy.context, arena.allocator(), combined, null));
    return result;
}

fn namespacePending(self: *Self, id: u64) !?d.Operation {
    const value = try self.store.tree().get(self.store.root.namespace_pending, try r.idKey(id)) orelse return null;
    return try r.fromValue(d.Operation, self.allocator, value);
}
fn namespaceGuard(self: *Self, allocator: std.mem.Allocator, binding: N.Binding, policy: Policy) !P.Guard {
    try binding.validate();
    if (!binding.connection.matches(self.config()) or binding.connection.principal != policy.subject.principal()) return error.CatalogDenied;
    var required = try self.requirements(policy, null, null, if (binding.action == .create) .create_schema else .database);
    if (binding.action == .create) {
        required.selectable = binding.action.create.owner;
    } else {
        const expected = binding.expected.?;
        try self.verifiedObject(policy, .schema, expected.id, expected.authorization, a.reference(self.config().authority.database));
        required.requirements[1] = .{ .object = a.reference(expected.authorization), .access = .ownership };
    }
    return policy.make_guard(policy.context, allocator, required, null);
}
fn namespaceNameAvailable(self: *Self, id: u64, name: a.Name) !bool {
    const encoded = try self.store.tree().get(self.store.root.schema_names, try pages.Key.init(&r.hash(name.slice()))) orelse return true;
    const reserved = try r.fromValue(N.Name, self.allocator, encoded);
    if (!std.meta.eql(reserved.name, name)) return error.CatalogIdentityConflict;
    if (try self.storedSchema(reserved.namespace)) |found| {
        if (!found.retired and std.meta.eql(found.name, name)) return found.id == id;
    }
    if (try self.namespacePending(reserved.namespace)) |identity| {
        const binding = try c.OperationBinding.lookupNamespace(self.allocator, self.store.objects, identity) orelse return error.InvalidDirectCatalogOperation;
        if (std.meta.eql(binding.proposedName(), name)) return reserved.namespace == id;
    }
    return true;
}
fn namespaceReason(self: *Self, binding: N.Binding) !N.Reason {
    if (try self.namespacePending(binding.namespace) != null) return .object_conflict;
    const found = try self.storedSchema(binding.namespace);
    if (binding.action == .create) {
        if (found != null or try self.store.tree().get(self.store.root.namespace_claims, try r.idKey(binding.namespace)) != null) return .object_conflict;
    } else {
        if (found == null or found.?.retired) return .object_conflict;
        if (!std.meta.eql(found, binding.expected)) return .stale_definition;
    }
    if (binding.action != .drop and !try self.namespaceNameAvailable(binding.namespace, binding.proposedName())) return .name_conflict;
    return .none;
}
/// Checks identity, current authority and name conflicts without provisioning
/// or reserving anything. DROP dependency traversal belongs to bounded execution.
pub fn previewNamespace(self: *Self, binding: N.Binding, policy: Policy) !N.Preview {
    try self.requireInitialized();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const current = try self.namespaceGuard(arena.allocator(), binding, policy);
    try check(current);
    if (try c.OperationBinding.lookupNamespace(self.allocator, self.store.objects, binding.identity())) |known| try binding.requireSame(known);
    const result: N.Preview = .{ .binding = binding, .position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn }, .current = try self.storedSchema(binding.namespace), .reason = try self.namespaceReason(binding) };
    try check(current);
    return result;
}
fn recordNamespace(self: *Self, candidate_root: r.Root, proposed: N.Operation, current: P.Guard) !N.Operation {
    var next = candidate_root;
    next.next_lsn = try std.math.add(u64, self.store.root.next_lsn, 1);
    var operation = proposed;
    operation.position = .{ .partition = self.config().partition, .next_lsn = next.next_lsn };
    if (operation.phase != .admitted) {
        operation.after = null;
        if (try self.namespacePending(operation.binding.namespace)) |pending_identity| {
            if (std.meta.eql(pending_identity, operation.binding.identity())) next.namespace_pending = try self.store.tree().remove(next.namespace_pending, try r.idKey(operation.binding.namespace));
        }
    }
    try self.store.receiptIdentity(&next, operation.binding.identity());
    try self.store.publish(next, .{ .namespace = operation }, current);
    return operation;
}
/// CREATE has separate native provisioning and catalog publication. DROP scans
/// one directory page per execution while fencing new DDL in that namespace.
/// Repeating inspect/execute never chooses another identity, name or revision.
pub fn namespaceOperation(self: *Self, binding: N.Binding, command: N.Command, policy: Policy) !N.Observation {
    try self.requireInitialized();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const current = try self.namespaceGuard(arena.allocator(), binding, policy);
    try check(current);
    if (try c.OperationBinding.lookupNamespace(self.allocator, self.store.objects, binding.identity())) |known| try binding.requireSame(known);
    const previous = try self.store.namespaceOperation(binding);
    if (command == .inspect or (previous != null and previous.?.phase != .admitted) or (command == .admit and previous != null)) {
        try check(current);
        return if (previous) |value| .{ .operation = value } else .not_observed;
    }
    if (command == .execute and previous == null) return .not_observed;
    try c.OperationBinding.claimNamespace(self.allocator, self.store.objects, binding);
    try self.store.index.begin(self.options.index_work_bytes);
    defer self.store.index.end();
    var next = self.store.root;
    var operation: N.Operation = previous orelse .{ .binding = binding, .position = .{ .partition = self.config().partition, .next_lsn = 1 }, .phase = .admitted, .reason = .none, .after = null, .resulting = null };
    if (command == .cancel) {
        operation.phase = .cancelled;
    } else if (command == .admit) {
        operation.reason = try self.namespaceReason(binding);
        if (operation.reason != .none) {
            operation.phase = .rejected;
        } else {
            const id = try r.idKey(binding.namespace);
            next.namespace_pending = try self.store.tree().put(next.namespace_pending, id, try r.pageValue(binding.identity()));
            if (binding.action == .create) next.namespace_claims = try self.store.tree().put(next.namespace_claims, id, try r.pageValue(binding.identity()));
            if (binding.action != .drop) {
                const name: N.Name = .{ .namespace = binding.namespace, .name = binding.proposedName() };
                next.schema_names = try self.store.tree().put(next.schema_names, try pages.Key.init(&r.hash(name.name.slice())), try r.pageValue(name));
            }
        }
    } else {
        const pending_identity = try self.namespacePending(binding.namespace) orelse return error.InvalidDirectCatalogOperation;
        if (!std.meta.eql(pending_identity, binding.identity())) return error.InvalidDirectCatalogOperation;
        var resulting: a.Schema = undefined;
        if (binding.action == .create) {
            const native = try policy.registered(policy.context, .schema, binding.namespace) orelse return error.CatalogRegistrationRequired;
            try a.validateObject(self.config().authority, self.config().scope, .schema, binding.namespace, a.reference(self.config().authority.database), native);
            if (native.owner != binding.action.create.owner) return error.CatalogIdentityConflict;
            resulting = .{ .scope = self.config().scope, .id = binding.namespace, .authorization = native.reference.id, .name = binding.action.create.name, .revision = 1 };
        } else {
            resulting = try self.storedSchema(binding.namespace) orelse return error.InvalidDirectCatalogOperation;
            if (!std.meta.eql(resulting, binding.expected.?)) return error.InvalidDirectCatalogOperation;
            if (binding.action == .drop) {
                const scanned = try self.namespaceDependencies(binding.namespace, operation.after, current);
                if (scanned.blocked) {
                    operation.phase = .rejected;
                    operation.reason = .dependency;
                    return .{ .operation = try self.recordNamespace(next, operation, current) };
                }
                if (scanned.after) |after| {
                    operation.after = after;
                    return .{ .operation = try self.recordNamespace(next, operation, current) };
                }
                resulting.retired = true;
            } else resulting.name = binding.action.rename;
            resulting.revision = try std.math.add(u64, resulting.revision, 1);
        }
        operation.phase = .applied;
        operation.resulting = resulting;
        next.schemas = try self.store.tree().put(next.schemas, try r.idKey(resulting.id), try r.pageValue(resulting));
    }
    return .{ .operation = try self.recordNamespace(next, operation, current) };
}
fn namespaceDependencies(self: *Self, namespace_id: u64, after: ?u64, current: P.Guard) !struct { blocked: bool, after: ?u64 } {
    const batch = try self.store.tree().scan(self.store.root.objects, if (after) |id| try r.idKey(id) else null);
    for (batch.entries) |slot| if (slot) |item| {
        const target = try r.fromValue(r.Entry, self.allocator, item.value);
        try target.validate(self.config());
        if (!std.meta.eql(item.key, try r.idKey(target.object))) return error.InvalidDirectCatalogEntry;
        if (target.resource) |at| {
            const named = try self.store.resourceRecord(at);
            const named_namespace = if (named.resulting) |value| value.namespace else named.binding.action.create.namespace;
            if (named_namespace == namespace_id and (named.pending() or (named.phase == .complete and !named.retired))) return .{ .blocked = true, .after = null };
            continue;
        }
        if (target.seed != null) {
            var view = try self.open(self.allocator, target, true);
            defer view.deinit();
            if (view.properties.namespace == namespace_id and view.table.root.next_lsn != 0 and !view.table.root.retired) return .{ .blocked = true, .after = null };
        }
        if (try self.pending(target.object, current)) {
            const value = (try self.store.tree().get(self.store.root.pending, item.key)).?;
            const identity = try r.fromValue(d.Operation, self.allocator, value);
            const binding = try c.OperationBinding.lookup(self.allocator, self.store.objects, identity) orelse return error.InvalidDirectCatalogOperation;
            var request = (try self.loadRequest(binding)) orelse return error.InvalidDirectCatalogOperation;
            defer request.deinit();
            if (request.value.intent.namespace == namespace_id) return .{ .blocked = true, .after = null };
        }
    };
    const cursor = if (batch.next) |key| blk: {
        if (key.len != 8) return error.InvalidCatalogCursor;
        break :blk std.mem.readInt(u64, key.data[0..8], .big);
    } else null;
    return .{ .blocked = false, .after = cursor };
}
pub fn namespaceRegistration(self: *Self, binding: N.Binding, policy: Policy) !?Registration {
    const observation = try self.namespaceOperation(binding, .inspect, policy);
    if (observation != .operation or observation.operation.phase != .admitted or binding.action != .create) return null;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const current = try self.namespaceGuard(arena.allocator(), binding, policy);
    const native = try policy.registered(policy.context, .schema, binding.namespace);
    const fence = try current.acquire(current.context);
    defer current.release(current.context);
    if (native != null) return null;
    if (fence.policy_epoch == 0) return error.InvalidPartitionLease;
    return .{ .action = .{ .domain = self.config().authority.schema_domain, .owner = binding.action.create.owner, .schema = a.reference(self.config().authority.database), .binding = try a.binding(self.config().scope, .schema, binding.namespace) }, .authorization_revision = fence.policy_epoch - 1 };
}

/// Accept a conditional name outcome under the directory lock, without
/// allocating a Table object, changing its rows, or pretending it committed.
/// Inspection and exact retries recheck the original caller's current rights.
pub fn assertName(self: *Self, binding: c.NameAssertion.Binding, command: c.NameAssertion.Command, policy: Policy) !c.NameAssertion.Observation {
    try self.requireInitialized();
    try binding.validate();
    if (!binding.connection.matches(self.config()) or binding.connection.principal != policy.subject.principal()) return error.CatalogDenied;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const namespace = try self.schema(binding.namespace);
    var required = try self.requirements(policy, namespace, null, if (binding.action == .create_if_not_exists) .create_table else .schema);
    try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
    if (binding.expected) |expected| {
        const allocated = try self.entry(expected.object.object) orelse return error.CatalogDenied;
        if (allocated.seed == null) return error.CatalogDenied;
        var original_view = try self.open(self.allocator, allocated, true);
        defer original_view.deinit();
        if (original_view.properties.namespace != binding.namespace or original_view.table.root.next_lsn == 0) return error.CatalogDenied;
        required = try required.merge(try self.requirements(policy, namespace, original_view.properties.target(allocated.object), .inspect));
        try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
    }
    if (try c.OperationBinding.lookupAssertion(self.allocator, self.store.objects, binding.identity())) |known| try binding.requireSame(known);
    if (try self.store.assertion(binding)) |outcome| {
        try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
        return .{ .outcome = outcome };
    }
    if (command == .inspect) {
        try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
        return .not_observed;
    }
    var matches = false;
    if (command == .accept) {
        var current = try self.resolve(self.allocator, binding.namespace, binding.name, policy);
        defer if (current) |*view| view.deinit();
        if (current) |view| {
            required = try required.merge(try self.requirements(policy, namespace, view.properties.target(view.table.root.interpretation.object.object), .inspect));
            matches = if (binding.expected) |expected| std.meta.eql(expected, view.table.root.interpretation) else false;
        } else matches = binding.expected == null and try self.available(binding.namespace, binding.name, 0, try policy.make_guard(policy.context, arena.allocator(), required, null));
    }
    const current_guard = try policy.make_guard(policy.context, arena.allocator(), required, null);
    try check(current_guard);
    try c.OperationBinding.claimAssertion(self.allocator, self.store.objects, binding);
    try self.store.index.begin(self.options.index_work_bytes);
    defer self.store.index.end();
    var next = self.store.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    const outcome: c.NameAssertion.Outcome = .{ .binding = binding, .position = .{ .partition = self.config().partition, .next_lsn = next.next_lsn }, .state = if (command == .cancel) .cancelled else if (matches) .unchanged else .rejected, .reason = if (command == .accept and !matches) .condition_changed else .none };
    try self.store.receiptIdentity(&next, binding.identity());
    try self.store.publish(next, .{ .assertion = outcome }, current_guard);
    return .{ .outcome = outcome };
}

fn original(self: *Self, policy: Policy, binding: d.Binding) !void {
    try binding.validate();
    if (policy.subject.principal() != binding.identity.principal or !std.meta.eql(binding.identity.scope, self.config().scope) or binding.target.branch != self.config().branch) return error.CatalogDenied;
}

fn requestGuard(self: *Self, allocator: std.mem.Allocator, policy: Policy, request: Request, view: ?*View, acceptance: bool) !P.Guard {
    const namespace = if (acceptance) try self.schema(request.intent.namespace) else try self.authorizationSchema(request.intent.namespace);
    const target: ?a.Table = if (view) |value| value.properties.target(request.binding.target.object) else if (request.intent.action == .create) target: {
        const native = try policy.registered(policy.context, .table, request.binding.target.object) orelse break :target null;
        break :target .{ .id = request.binding.target.object, .schema = namespace.id, .authorization = native.reference.id };
    } else return error.CatalogObjectMissing;
    const access: a.Access = switch (request.intent.action) {
        .create => .create_table,
        .alter, .rename => .alter,
        .drop => .drop,
    };
    var requested = try self.requirements(policy, namespace, target, access);
    if (request.intent.action == .create) requested.selectable = request.intent.action.create.owner;
    return policy.make_guard(policy.context, allocator, requested, if (acceptance) request.binding.prerequisite else null);
}

fn pending(self: *Self, object: u64, current: P.Guard) !bool {
    const value = try self.store.tree().get(self.store.root.pending, try r.idKey(object)) orelse return false;
    const operation = try r.fromValue(d.Operation, self.allocator, value);
    const target = try self.entry(object) orelse return error.InvalidDirectCatalogOperation;
    if (target.resource != null) {
        const binding = try c.OperationBinding.lookupResource(self.allocator, self.store.objects, operation) orelse return error.InvalidDirectCatalogOperation;
        return (try self.store.resourceOperation(binding) orelse return error.InvalidDirectCatalogOperation).pending();
    }
    const binding = try c.OperationBinding.lookup(self.allocator, self.store.objects, operation) orelse return error.InvalidDirectCatalogOperation;
    const observed = try self.store.operation(binding) orelse return error.InvalidDirectCatalogOperation;
    if (!observed.pending()) return false;
    if (target.seed == null) return true;
    var view = try self.open(self.allocator, target, false);
    defer view.deinit();
    return (try view.table.observeEvidence(binding, current)) == null;
}

fn available(self: *Self, namespace: u64, name: a.Name, object: u64, current: P.Guard) !bool {
    const proposed = try self.candidate(namespace, name) orelse return true;
    const target = try self.entry(proposed.object) orelse return error.InvalidDirectCatalogName;
    if (target.resource) |at| {
        const named = try self.store.resourceRecord(at);
        if (named.phase == .complete and !named.retired) {
            const value = named.resulting.?;
            if (value.namespace == namespace and std.meta.eql(value.name, name)) return proposed.object == object;
        }
        const binding = try c.OperationBinding.lookupResource(self.allocator, self.store.objects, proposed.reservation) orelse return error.InvalidDirectCatalogOperation;
        return !(try self.store.resourceOperation(binding) orelse return error.InvalidDirectCatalogOperation).pending();
    }
    var view: ?View = null;
    defer if (view) |*value| value.deinit();
    if (target.seed != null) {
        view = try self.open(self.allocator, target, false);
        if (view.?.table.root.next_lsn != 0 and !view.?.table.root.retired and view.?.properties.namespace == namespace and std.meta.eql(view.?.properties.name, name)) return proposed.object == object;
    }
    const binding = try c.OperationBinding.lookup(self.allocator, self.store.objects, proposed.reservation) orelse return error.InvalidDirectCatalogOperation;
    const observed = try self.store.operation(binding) orelse return error.InvalidDirectCatalogOperation;
    if (!observed.pending()) return true;
    if (view) |*value| return (try value.table.observeEvidence(binding, current)) != null;
    return false;
}

fn record(self: *Self, next_input: r.Root, operation: r.Operation, current: P.Guard) !void {
    var next = next_input;
    next.next_lsn = try std.math.add(u64, self.store.root.next_lsn, 1);
    try self.store.receipt(&next, operation.binding);
    try self.store.publish(next, .{ .operation = operation }, current);
}

fn admissionReason(self: *Self, request: Request, known: bool, existing: ?*View, current: P.Guard) !r.Reason {
    if (try self.namespacePending(request.intent.namespace) != null) return .object_conflict;
    const object = request.binding.target.object;
    if (request.intent.action == .create) {
        if (known) return .object_conflict;
    } else if (existing) |view| {
        if (view.table.root.next_lsn == 0 or view.table.root.retired or view.properties.namespace != request.intent.namespace or !std.meta.eql(view.properties.name, request.intent.name)) return .object_conflict;
        if (!std.meta.eql(request.binding.expected_definition, @as(?d.Definition, view.table.root.interpretation))) return .stale_definition;
        if (request.binding.expected_data) |expected| {
            if (!expected.unchangedAt(.{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn }, view.table.root.changed_lsn)) return .stale_data;
        }
        if (view.table.root.pending != null or try self.pending(object, current)) return .object_conflict;
        if (request.intent.action == .drop and try self.hasDependents(object)) return .dependency;
    } else return .object_conflict;
    const proposed_name = if (request.intent.action == .rename) request.intent.action.rename else request.intent.name;
    if ((request.intent.action == .create or request.intent.action == .rename) and !try self.available(request.intent.namespace, proposed_name, object, current)) return .name_conflict;
    return .none;
}

/// Checks a proposal against current policy and independently observed directory
/// and Table state. No claim, intent, reservation, native registration or write
/// is made. Row constraints and publication are still checked during execution.
pub fn preview(self: *Self, request: Request, policy: Policy) !Preview {
    try self.requireInitialized();
    try self.original(policy, request.binding);
    try request.validate(self.allocator, self.config());
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var existing: ?View = null;
    defer if (existing) |*view| view.deinit();
    const known = try self.entry(request.binding.target.object);
    if (known) |target| if (target.seed != null) {
        existing = try self.open(self.allocator, target, false);
    };
    const view: ?*View = if (existing) |*value| value else null;
    const current = try self.requestGuard(arena.allocator(), policy, request, view, true);
    try check(current);
    if (try c.OperationBinding.lookup(self.allocator, self.store.objects, request.binding.identity)) |claimed| try request.binding.requireSame(claimed);
    var result: Preview = .{
        .binding = request.binding,
        .directory_position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn },
        .current = if (view) |value| if (value.table.root.next_lsn != 0) .{ .interpretation = value.table.root.declared(), .position = .{ .partition = value.table.root.partition, .next_lsn = value.table.root.next_lsn }, .changed_lsn = value.table.root.changed_lsn, .row_count = value.table.root.live_rows } else null else null,
        .reason = try self.admissionReason(request, known != null, view, current),
    };
    if (result.reason == .none) {
        result.work = .metadata;
        switch (request.intent.action) {
            .create => |value| result.schema_fingerprint = try value.schema.fingerprint(),
            .rename, .drop => result.schema_fingerprint = view.?.table.root.schema_fingerprint,
            .alter => |change| {
                var columns: [c.fuze.TableSchema.max_columns]c.fuze.TableSchema.Column = undefined;
                const transition = try c.fuze.TableEvolution.apply(view.?.table.declaration.schema.schema, change, &columns);
                result.work = transition.work;
                result.rebuild_key = transition.rebuild_key;
                result.schema_fingerprint = try transition.after.fingerprint();
            },
        }
    }
    try check(current);
    return result;
}

/// Admission preserves the complete exact intent and name reservation. It does
/// not execute the Table mutation. Repeating it never resolves a replacement.
pub fn admit(self: *Self, request: Request, policy: Policy) !r.Operation {
    try self.requireInitialized();
    try self.original(policy, request.binding);
    try request.validate(self.allocator, self.config());
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var existing: ?View = null;
    defer if (existing) |*value| value.deinit();
    const known = try self.entry(request.binding.target.object);
    if (known) |target| if (target.seed != null) {
        existing = try self.open(self.allocator, target, false);
    };
    const current = try self.requestGuard(arena.allocator(), policy, request, if (existing) |*value| value else null, true);
    try check(current);
    try c.OperationBinding.claim(self.allocator, self.store.objects, request.binding);
    if (try self.store.operation(request.binding)) |observed| {
        try check(current);
        return observed;
    }
    const content = try IntentStore.stage(self.allocator, self.store.objects, self.config(), request);
    var operation: r.Operation = .{ .binding = request.binding, .intent = content, .phase = .admitted, .reason = .none };
    const object = request.binding.target.object;
    const reason = try self.admissionReason(request, known != null, if (existing) |*view| view else null, current);
    const proposed_name = if (request.intent.action == .rename) request.intent.action.rename else request.intent.name;
    try self.store.index.begin(self.options.index_work_bytes);
    defer self.store.index.end();
    var next = self.store.root;
    if (reason != .none) {
        operation.phase = .rejected;
        operation.reason = reason;
    } else {
        if (request.intent.action == .create) {
            const target: r.Entry = .{ .object = object, .partition = next.next_partition, .seed = null, .resource = null };
            next.next_partition = try std.math.add(u64, next.next_partition, 1);
            next.objects = try self.store.tree().put(next.objects, try r.idKey(object), try r.pageValue(target));
        }
        if (request.intent.action == .create or request.intent.action == .rename) {
            const name: r.Name = .{ .namespace = request.intent.namespace, .name = proposed_name, .object = object, .reservation = request.binding.identity };
            next.names = try self.store.tree().put(next.names, try r.nameKey(name.namespace, name.name), try r.pageValue(name));
        }
        next.pending = try self.store.tree().put(next.pending, try r.idKey(object), try r.pageValue(request.binding.identity));
    }
    try self.record(next, operation, current);
    return operation;
}

fn loadRequest(self: *Self, binding: d.Binding) !?IntentStore.Owned {
    const operation = try self.store.operation(binding) orelse return null;
    var request = try IntentStore.load(self.allocator, self.store.objects, self.config(), operation.intent);
    errdefer request.deinit();
    try binding.requireSame(request.value.binding);
    return request;
}

/// Observes evidence only. It does not resume private staging, provision native
/// identities, publish a name or settle pending work as a side effect.
pub fn status(self: *Self, binding: d.Binding, policy: Policy) !Observation {
    try self.requireInitialized();
    try self.original(policy, binding);
    const operation = try self.store.operation(binding) orelse {
        // An unknown operation still requires current database access.
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        try check(try self.guard(arena.allocator(), policy, null, null, .database));
        return .not_observed;
    };
    var request = (try self.loadRequest(binding)).?;
    defer request.deinit();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var view: ?View = null;
    defer if (view) |*value| value.deinit();
    if (try self.entry(binding.target.object)) |target| if (target.seed != null) {
        view = try self.open(self.allocator, target, false);
    };
    const current = try self.requestGuard(arena.allocator(), policy, request.value, if (view) |*value| value else null, false);
    try check(current);
    if (view) |*value| if (try value.table.observeEvidence(binding, current)) |accepted| return .{ .committed = accepted };
    return switch (operation.phase) {
        .admitted, .ready => .{ .admitted = operation },
        .rejected => .{ .rejected = operation },
        .cancelled => .{ .cancelled = operation },
        .settled => error.InvalidDirectCatalogCompletion,
    };
}

pub const Registration = struct {
    action: @FieldType(p.Authorization.Action, "register_object"),
    /// A registrar must bind its native BEGIN to this checked policy revision.
    /// Native candidate publication also checks that unchanged policy basis.
    authorization_revision: u64,
};

/// Inspect the native work required by an already admitted CREATE. This does
/// not register anything or make the Table visible. The service's registrar
/// uses the existing signed native administration/recovery operations.
pub fn registration(self: *Self, binding: d.Binding, policy: Policy) !?Registration {
    const observed = try self.status(binding, policy);
    if (observed != .admitted or binding.action != .create) return null;
    var request = (try self.loadRequest(binding)).?;
    defer request.deinit();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const current = try self.requestGuard(arena.allocator(), policy, request.value, null, true);
    const namespace = try self.schema(request.value.intent.namespace);
    const native = try policy.registered(policy.context, .table, binding.target.object);
    const fence = try current.acquire(current.context);
    defer current.release(current.context);
    if (native != null) return null;
    if (fence.policy_epoch == 0) return error.InvalidPartitionLease;
    return .{ .action = .{
        .domain = self.config().authority.table_domain,
        .owner = request.value.intent.action.create.owner,
        .schema = a.reference(namespace.authorization),
        .binding = try a.binding(self.config().scope, .table, binding.target.object),
    }, .authorization_revision = fence.policy_epoch - 1 };
}

/// Attach a verified native registration to the original reserved object and
/// partition. The complete user intent stays unchanged. A lost reply recovers
/// this ready phase; only a subsequent Table acceptance publishes the name.
pub fn attachRegistration(self: *Self, binding: d.Binding, policy: Policy) !Observation {
    const observed = try self.status(binding, policy);
    if (observed != .admitted or binding.action != .create or observed.admitted.phase == .ready) return observed;
    var request = (try self.loadRequest(binding)).?;
    defer request.deinit();
    var target = try self.entry(binding.target.object) orelse return error.InvalidDirectCatalogOperation;
    if (target.seed != null) return error.InvalidDirectCatalogTransition;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const current = try self.requestGuard(arena.allocator(), policy, request.value, null, true);
    try check(current);
    const namespace = try self.schema(request.value.intent.namespace);
    const native = try policy.registered(policy.context, .table, binding.target.object) orelse return error.CatalogRegistrationRequired;
    try a.validateObject(self.config().authority, self.config().scope, .table, binding.target.object, a.reference(namespace.authorization), native);
    if (native.owner != request.value.intent.action.create.owner) return error.CatalogIdentityConflict;
    const properties: Properties = .{ .namespace = namespace.id, .authorization = native.reference.id, .name = request.value.intent.name };
    var bytes: [s.TableDeclaration.max_properties_bytes]u8 = undefined;
    var declaration = try s.TableDeclaration.prepare(self.allocator, .{ .object = binding.target, .revision = 1, .schema = request.value.intent.action.create.schema, .properties = try properties.encode(&bytes) });
    defer declaration.deinit();
    target.seed = try s.TableDeclaration.stage(self.store.objects, &declaration);
    try self.store.index.begin(self.options.index_work_bytes);
    defer self.store.index.end();
    var next = self.store.root;
    next.objects = try self.store.tree().put(next.objects, try r.idKey(target.object), try r.pageValue(target));
    var ready = observed.admitted;
    ready.phase = .ready;
    try self.record(next, ready, current);
    return .{ .admitted = ready };
}

pub fn perform(self: *Self, binding: d.Binding, policy: Policy) !Observation {
    const observed = try self.status(binding, policy);
    if (observed != .admitted) return observed;
    if (binding.action == .create and observed.admitted.phase == .admitted) _ = try self.attachRegistration(binding, policy);
    var request = (try self.loadRequest(binding)).?;
    defer request.deinit();
    const target = try self.entry(binding.target.object) orelse return error.InvalidDirectCatalogOperation;
    // Metadata-only lifecycle actions can use the control reserve. ALTER stages
    // row segments against data quota but accepts its small root through control.
    var view = try self.open(self.allocator, target, binding.action != .alter);
    defer view.deinit();
    if (binding.action == .alter) view.table.log = self.store.log;
    view.table.lose_reply = self.lose_table_reply;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const current = try self.requestGuard(arena.allocator(), policy, request.value, &view, true);
    if (binding.action == .drop and try self.hasDependents(binding.target.object)) {
        try self.terminal(observed.admitted, .rejected, .dependency, current);
        return self.status(binding, policy);
    }
    var properties = view.properties;
    if (request.value.intent.action == .rename) properties.name = request.value.intent.action.rename;
    var bytes: [s.TableDeclaration.max_properties_bytes]u8 = undefined;
    const encoded = try properties.encode(&bytes);
    const outcome = switch (request.value.intent.action) {
        .create => view.table.apply(binding, &.{}, .point, current),
        .rename => view.table.changeDefinition(binding, .{ .rename = encoded }, current),
        .alter => |change| view.table.changeDefinition(binding, .{ .alter = .{ .change = change, .properties = encoded } }, current),
        .drop => view.table.changeDefinition(binding, .{ .drop = encoded }, current),
    } catch |err| {
        // Never turn an uncertain append or unavailable storage into rejection.
        if (view.table.recovery_required) return err;
        const reason: r.Reason = switch (err) {
            error.TableDefinitionChanged => .stale_definition,
            error.TableDataChanged => .stale_data,
            error.DuplicatePrimaryKey, error.MissingRequiredField, error.NullNotAllowed, error.Overflow, error.TableRetired => .constraint,
            error.IbmHfpUnderflow, error.IbmHfpOverflow, error.UnrepresentableEbcdic037 => .constraint,
            else => return err,
        };
        try self.terminal(observed.admitted, .rejected, reason, current);
        return self.status(binding, policy);
    };
    // No catalog publication is needed for visibility or the accepted result.
    // A later explicit settlement only removes the pending-work directory entry.
    return .{ .committed = .{ .binding = binding, .resulting = view.table.root.declared(), .outcome = outcome } };
}

fn hasDependents(self: *Self, object: u64) !bool {
    const prefix = try r.idKey(object);
    const page = try self.store.tree().scan(self.store.root.dependents, prefix);
    const first = page.entries[0] orelse return false;
    if (!std.mem.startsWith(u8, first.key.slice(), prefix.slice())) return false;
    const edge = try r.fromValue(Dependency.Edge, self.allocator, first.value);
    try edge.validate();
    if (!std.meta.eql(first.key, try edge.forwardKey()) or edge.source.object.object != object) return error.InvalidCatalogDependency;
    return true;
}

fn dependentRequirements(self: *Self, policy: Policy, object: d.Object, write: bool) !p.Authorization.Guard {
    try object.validate();
    if (object.scope.realm != self.config().scope.realm or object.branch != 1) return error.CatalogDenied;
    if (std.meta.eql(object.scope, self.config().scope)) {
        const known = try self.namedRecord(object.object) orelse return error.CatalogDenied;
        const value = known.resulting orelse return error.CatalogDenied;
        return self.requirements(policy, try self.authorizationSchema(value.namespace), .{ .id = object.object, .schema = value.namespace, .authorization = value.authorization }, if (write) .alter else .inspect);
    }
    var result = try self.requirements(policy, null, null, .database);
    result.requirements[1] = .{ .object = .{ .kind = .resource, .id = object.scope.resource }, .privileges = if (write) 4 else 1 };
    return result;
}

/// Resource declarations use their catalog metadata authority, never write
/// access to the shared catalog's backing native resource. Registration may
/// precede publication after allocation has fixed the exact interpretation.
fn dependentDefinition(self: *Self, dependent: Dependency.Dependent) !bool {
    const object = dependent.interpretation.object;
    if (dependent.kind == .captured or dependent.kind == .maintained)
        return !std.meta.eql(object.scope, self.config().scope);
    if (!std.meta.eql(object.scope, self.config().scope)) return false;
    const known = try self.namedRecord(object.object) orelse return false;
    if ((known.phase != .allocated and known.phase != .complete) or known.retired) return false;
    const value = known.resulting.?;
    if ((dependent.kind == .kv) != (value.creation.spec == .kv)) return false;
    return std.meta.eql(dependent.interpretation, try value.interpretation(self.allocator));
}

fn dependencyAdministration(self: *Self, policy: Policy) !p.Authorization.Guard {
    var result = try self.requirements(policy, null, null, .database);
    result.requirements[1] = .{ .object = .{ .kind = .realm, .id = 0 }, .privileges = p.permission(.admin) };
    return result;
}

fn dependencyOperationRequirements(self: *Self, policy: Policy, binding: Dependency.Binding, write: bool) !p.Authorization.Guard {
    if (binding.authority == .dependent) return self.dependentRequirements(policy, binding.edge.dependent.interpretation.object, write);
    var found = try self.dependencySource(binding.edge.source.object, policy, 0);
    found.requirements.requirements[2].?.privileges = 0;
    found.requirements.requirements[2].?.access = .ownership;
    return (try self.dependencyAdministration(policy)).merge(found.requirements);
}

const DependencySource = struct { interpretation: d.Definition, live: bool, requirements: p.Authorization.Guard };
fn dependencySource(self: *Self, object: d.Object, policy: Policy, privileges: u64) !DependencySource {
    try object.validate();
    if (!std.meta.eql(object.scope, self.config().scope) or object.branch != self.config().branch) return error.CatalogDenied;
    const target = try self.entry(object.object) orelse return error.CatalogDenied;
    if (target.resource) |at| {
        const known = try self.store.resourceRecord(at);
        const value = known.resulting orelse return error.CatalogDenied;
        if (!std.meta.eql(value.object, object)) return error.InvalidDirectCatalogEntry;
        // SELECT is the shared logical read requirement. It maps to native
        // INSPECT/READ for named KV/Document data; row mutation masks are not
        // meaningful for these source kinds and must not be reinterpreted.
        if (privileges != 0 and privileges != a.select) return error.InvalidCatalogDependency;
        var required = try self.requirements(policy, try self.authorizationSchema(value.namespace), .{ .id = object.object, .schema = value.namespace, .authorization = value.authorization }, .inspect);
        if (privileges != 0) {
            var native: p.Authorization.Guard = .{ .subject = policy.subject, .requirements = @splat(null) };
            native.requirements[0] = .{ .object = .{ .kind = .resource, .id = value.resource }, .privileges = p.State.permission(.inspect) | p.State.permission(.read) };
            required = try required.merge(native);
        }
        return .{ .interpretation = try value.interpretation(self.allocator), .live = known.phase == .complete and !known.retired, .requirements = required };
    }
    if (target.seed == null) return error.CatalogDenied;
    var view = try self.open(self.allocator, target, false);
    defer view.deinit();
    var requested = try self.requirements(policy, try self.authorizationSchema(view.properties.namespace), view.properties.target(object.object), .inspect);
    if (privileges != 0) {
        requested.requirements[2].?.privileges = privileges;
        requested.requirements[2].?.access = .all;
    }
    return .{ .interpretation = view.table.root.interpretation, .live = view.table.root.next_lsn != 0 and !view.table.root.retired, .requirements = requested };
}

fn dependencyEdge(self: *Self, edge: Dependency.Edge) !?pages.Value {
    const found = try self.store.tree().get(self.store.root.dependents, try edge.forwardKey());
    const reverse = try self.store.tree().get(self.store.root.dependencies, try edge.reverseKey());
    if (!std.meta.eql(found, reverse)) return error.InvalidCatalogDependency;
    if (found) |value| {
        const saved = try r.fromValue(Dependency.Edge, self.allocator, value);
        try saved.validate();
        if (!std.meta.eql(saved, edge)) return error.DataIdentityConflict;
    }
    return found;
}

/// One bounded catalog acceptance updates both directions and its exact receipt.
/// Register requires current source actions and dependent metadata write access.
/// Remove/cancel can close an explicitly known edge after source rights change;
/// they require dependent write access, never infer permission from PID ownership.
pub fn dependencyOperation(self: *Self, binding: Dependency.Binding, command: Dependency.Command, policy: Policy) !Dependency.Observation {
    try self.requireInitialized();
    try binding.validate();
    if (!binding.connection.matches(self.config()) or binding.connection.principal != policy.subject.principal()) return error.CatalogDenied;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const inspect = try policy.make_guard(policy.context, arena.allocator(), try self.dependencyOperationRequirements(policy, binding, false), null);
    try check(inspect);
    if (try c.OperationBinding.lookupDependency(self.allocator, self.store.objects, binding.identity())) |known| try known.requireSame(binding);
    if (try self.store.dependency(binding)) |outcome| {
        try check(inspect);
        return .{ .outcome = outcome };
    }
    if (command == .inspect) return .not_observed;
    var requested = try self.dependencyOperationRequirements(policy, binding, true);
    var source: ?DependencySource = null;
    if (command == .accept and binding.action == .register) {
        const found = try self.dependencySource(binding.edge.source.object, policy, binding.edge.privileges);
        requested = try requested.merge(found.requirements);
        source = found;
    }
    const current = try policy.make_guard(policy.context, arena.allocator(), requested, null);
    try check(current);
    try c.OperationBinding.claimDependency(self.allocator, self.store.objects, binding);
    var outcome: Dependency.Outcome = .{
        .binding = binding,
        .position = .{ .partition = self.config().partition, .next_lsn = try std.math.add(u64, self.store.root.next_lsn, 1) },
        .phase = if (command == .cancel) .cancelled else .applied,
        .reason = .none,
        .changed = false,
    };
    if (source) |value| {
        if (!value.live or !std.meta.eql(value.interpretation, binding.edge.source) or !try self.dependentDefinition(binding.edge.dependent)) {
            outcome.phase = .rejected;
            outcome.reason = .stale_definition;
        } else if (try self.pending(binding.edge.source.object.object, current)) {
            outcome.phase = .rejected;
            outcome.reason = .source_busy;
        }
    }
    const previous = try self.dependencyEdge(binding.edge);
    try self.store.index.begin(self.options.index_work_bytes);
    defer self.store.index.end();
    var next = self.store.root;
    if (outcome.phase == .applied) {
        outcome.changed = (binding.action == .register) == (previous == null);
        if (outcome.changed) {
            if (binding.action == .register) {
                const encoded = try r.pageValue(binding.edge);
                next.dependents = try self.store.tree().put(next.dependents, try binding.edge.forwardKey(), encoded);
                next.dependencies = try self.store.tree().put(next.dependencies, try binding.edge.reverseKey(), encoded);
            } else {
                next.dependents = try self.store.tree().remove(next.dependents, try binding.edge.forwardKey());
                next.dependencies = try self.store.tree().remove(next.dependencies, try binding.edge.reverseKey());
            }
        }
    }
    next.next_lsn = outcome.position.next_lsn;
    try self.store.receiptIdentity(&next, binding.identity());
    try self.store.publish(next, .{ .dependency = outcome }, current);
    return .{ .outcome = outcome };
}

/// Bounded, current-authorized graph inspection. A continuation is tied to the
/// catalog position; a changed directory rejects rather than stitching pages.
/// Filtered entries still advance the bounded scan but reveal no dependent IDs.
pub fn dependencyPage(self: *Self, selection: Dependency.Selection, cursor: ?Dependency.Cursor, authority: Dependency.Authority, policy: Policy) !Dependency.Page {
    try self.requireInitialized();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var prefix: pages.Key = undefined;
    var requested: p.Authorization.Guard = undefined;
    switch (selection) {
        .dependents => |object| {
            const found = try self.dependencySource(object, policy, 0);
            requested = found.requirements;
            prefix = try r.idKey(object.object);
        },
        .dependencies => |object| {
            try object.validate();
            if (object.scope.realm != self.config().scope.realm or object.branch != 1) return error.CatalogDenied;
            requested = if (authority == .dependent) try self.dependentRequirements(policy, object, false) else try self.dependencyAdministration(policy);
            prefix = try pages.Key.init(&try Dependency.dependentKey(object));
        },
    }
    if (authority == .catalog_administrator) requested = try requested.merge(try self.dependencyAdministration(policy));
    const current = try policy.make_guard(policy.context, arena.allocator(), requested, null);
    try check(current);
    const position: d.Position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn };
    var after_key = prefix;
    if (cursor) |after| {
        if (!std.meta.eql(after.selection, selection) or after.authority != authority) return error.InvalidCatalogCursor;
        if (!std.meta.eql(after.position, position)) return error.CatalogObservationChanged;
        @memcpy(after_key.data[after_key.len..][0..32], &after.after);
        after_key.len += 32;
    }
    const page = try self.store.tree().scan(if (selection == .dependents) self.store.root.dependents else self.store.root.dependencies, after_key);
    var result: Dependency.Page = .{ .position = position };
    var count: usize = 0;
    var disclosure = current;
    var last: ?pages.Key = null;
    for (page.entries[0..Dependency.page_entries]) |slot| {
        const item = slot orelse break;
        if (!std.mem.startsWith(u8, item.key.slice(), prefix.slice())) {
            try check(disclosure);
            return result;
        }
        const edge = try r.fromValue(Dependency.Edge, self.allocator, item.value);
        try edge.validate();
        switch (selection) {
            .dependents => |object| if (!std.meta.eql(object, edge.source.object)) return error.InvalidCatalogDependency,
            .dependencies => |object| if (!std.meta.eql(object, edge.dependent.interpretation.object)) return error.InvalidCatalogDependency,
        }
        if (!std.meta.eql(item.key, if (selection == .dependents) try edge.forwardKey() else try edge.reverseKey())) return error.InvalidCatalogDependency;
        last = item.key;
        const extra = if (selection == .dependents)
            (if (authority == .dependent) try self.dependentRequirements(policy, edge.dependent.interpretation.object, false) else try self.dependencyAdministration(policy))
        else blk: {
            const found = try self.dependencySource(edge.source.object, policy, 0);
            break :blk found.requirements;
        };
        const combined = try requested.merge(extra);
        const disclosure_guard = try policy.make_guard(policy.context, arena.allocator(), combined, null);
        check(disclosure_guard) catch |err| {
            if (err == error.CatalogDenied or err == error.Forbidden) continue;
            return err;
        };
        requested = combined;
        disclosure = disclosure_guard;
        result.entries[count] = edge;
        count += 1;
    }
    if (last) |after| if (page.entries[Dependency.page_entries] != null or page.next != null) {
        result.next = .{ .selection = selection, .authority = authority, .position = position, .after = after.slice()[prefix.len..][0..32].* };
    };
    try check(disclosure);
    return result;
}

/// Row admission and outcomes belong to the Table partition. None of these
/// operations publishes a catalog root or resolves the current name again.
pub fn admitRows(self: *Self, request: s.TableDmlIntent.Request, policy: Policy) !P.OperationState {
    try request.validate();
    return self.rowOperation(request.binding, .admit, request, policy);
}
pub fn performRows(self: *Self, binding: d.Binding, policy: Policy) !P.OperationState {
    return self.rowOperation(binding, .perform, null, policy);
}
pub fn rowStatus(self: *Self, binding: d.Binding, policy: Policy) !P.OperationState {
    return self.rowOperation(binding, .status, null, policy);
}
pub fn cancelRows(self: *Self, binding: d.Binding, policy: Policy) !P.OperationState {
    return self.rowOperation(binding, .cancel, null, policy);
}
pub fn applyRows(self: *Self, request: s.TableDmlIntent.Request, policy: Policy) !P.OperationState {
    const admitted = try self.admitRows(request, policy);
    if (admitted != .admitted) return admitted;
    return self.performRows(request.binding, policy);
}

fn rowOperation(self: *Self, binding: d.Binding, action: enum { admit, perform, status, cancel }, request: ?s.TableDmlIntent.Request, policy: Policy) !P.OperationState {
    try self.requireInitialized();
    try self.original(policy, binding);
    const access: a.Access = switch (binding.action) {
        .insert => .insert,
        .update => .update,
        .delete => .delete,
        else => return error.UnsupportedTableAction,
    };
    const target = try self.entry(binding.target.object) orelse return error.CatalogDenied;
    var view = try self.open(self.allocator, target, action == .cancel);
    defer view.deinit();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const required = try self.requirements(policy, try self.authorizationSchema(view.properties.namespace), view.properties.target(target.object), access);
    const current = try policy.make_guard(policy.context, arena.allocator(), required, if (action == .admit or action == .perform) binding.prerequisite else null);
    try check(current);
    if (action == .admit) {
        try c.OperationBinding.claim(self.allocator, self.data_objects, binding);
        if (try view.table.operationState(binding, current) == .not_observed and try self.pending(target.object, current)) return error.CatalogObjectBusy;
    }
    view.table.lose_reply = self.lose_table_reply;
    return switch (action) {
        .admit => view.table.admit(request.?, current),
        .perform => view.table.perform(binding, current),
        .status => view.table.operationState(binding, current),
        .cancel => view.table.cancel(binding, current),
    };
}

const SnapshotAccess = struct { view: View, current: P.Guard };
fn snapshotAccess(self: *Self, allocator: std.mem.Allocator, object: d.Object, owner: d.Operation, policy: Policy, control: bool) !SnapshotAccess {
    try owner.validate();
    if (!std.meta.eql(owner.scope, object.scope) or owner.principal != policy.subject.principal()) return error.CatalogDenied;
    return self.readAccess(allocator, object, policy, control);
}
fn readAccess(self: *Self, allocator: std.mem.Allocator, object: d.Object, policy: Policy, control: bool) !SnapshotAccess {
    try self.requireInitialized();
    try object.validate();
    if (!std.meta.eql(object.scope, self.config().scope) or object.branch != self.config().branch) return error.CatalogDenied;
    const target = try self.entry(object.object) orelse return error.CatalogDenied;
    if (target.seed == null) return error.CatalogDenied;
    var view = try self.open(self.allocator, target, control);
    errdefer view.deinit();
    const current = try self.guard(allocator, policy, try self.authorizationSchema(view.properties.namespace), view.properties.target(object.object), .read);
    try check(current);
    return .{ .view = view, .current = current };
}

/// Pin ownership is private to the original principal. Possession of a handle
/// never substitutes for current database/schema/Table SELECT rights.
pub fn pinRows(self: *Self, object: d.Object, owner: d.Operation, expected: d.Position, policy: Policy) !P.SnapshotHandle {
    return self.pinRowsChecked(object, owner, expected, null, .snapshot, policy);
}

/// A delegated acquisition also freezes interpretation. Exact retries can
/// recover a retained old definition after the current Table has evolved.
pub fn pinRowsDefined(self: *Self, interpretation: d.Definition, owner: d.Operation, expected: d.Position, policy: Policy) !P.SnapshotHandle {
    try interpretation.validate();
    return self.pinRowsChecked(interpretation.object, owner, expected, interpretation, .snapshot, policy);
}

/// First acquisition selects the current frontier once. A lost reply or owner
/// restart recovers the retained original frontier, including after ALTER/DROP.
/// The native caller and executor checks remain the service's responsibility.
pub fn captureRowsDefined(self: *Self, interpretation: d.Definition, owner: d.Operation, minimum: d.Position, policy: Policy) !P.SnapshotHandle {
    try interpretation.validate();
    try minimum.validate();
    if (minimum.next_lsn == 0) return error.InvalidTableBasis;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), interpretation.object, owner, policy, false);
    defer access.view.deinit();
    const state = try access.view.table.pinState(owner, access.current);
    var selected = state.position;
    if (state.handle) |handle| {
        if (state.released) return error.TableSnapshotReleased;
        var retained = try access.view.table.inspectSnapshot(arena.allocator(), handle, access.current);
        defer retained.deinit();
        if (!std.meta.eql(interpretation, retained.root.interpretation)) return error.TableDefinitionChanged;
        selected = .{ .partition = retained.root.partition, .next_lsn = retained.root.next_lsn };
    } else if (!std.meta.eql(interpretation, access.view.table.root.interpretation)) return error.TableDefinitionChanged;
    if (selected.partition != minimum.partition or selected.next_lsn < minimum.next_lsn) return error.TableDataChanged;
    access.view.table.lose_reply = self.lose_table_reply;
    return access.view.table.pin(owner, selected, access.current);
}

pub fn retainHistory(self: *Self, object: d.Object, owner: d.Operation, expected: d.Position, interpretation: ?d.Definition, policy: Policy) !P.SnapshotHandle {
    if (interpretation) |required| {
        try required.validate();
        if (!std.meta.eql(required.object, object)) return error.DataIdentityConflict;
    }
    return self.pinRowsChecked(object, owner, expected, interpretation, .history, policy);
}

fn pinRowsChecked(self: *Self, object: d.Object, owner: d.Operation, expected: d.Position, interpretation: ?d.Definition, retention: P.Retention, policy: Policy) !P.SnapshotHandle {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, owner, policy, false);
    defer access.view.deinit();
    if (interpretation) |required| {
        const state = try access.view.table.pinState(owner, access.current);
        if (state.handle) |handle| {
            if (state.released) return error.TableSnapshotReleased;
            var retained = try access.view.table.inspectSnapshot(arena.allocator(), handle, access.current);
            defer retained.deinit();
            if (!std.meta.eql(required, retained.root.interpretation)) return error.TableDefinitionChanged;
        } else if (!std.meta.eql(required, access.view.table.root.interpretation)) return error.TableDefinitionChanged;
    }
    return switch (retention) {
        .snapshot => access.view.table.pin(owner, expected, access.current),
        .history => access.view.table.retainHistory(owner, expected, access.current),
    };
}

pub fn history(self: *Self, object: d.Object, lease: P.SnapshotHandle, from: d.Position, through: d.Position, frames: u8, policy: Policy) !P.HistoryPage {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, lease.owner, policy, false);
    defer access.view.deinit();
    return access.view.table.retainedHistory(lease, from, through, frames, access.current);
}

pub fn historyDefinition(self: *Self, allocator: std.mem.Allocator, object: d.Object, lease: P.SnapshotHandle, point: ?P.HistoryPoint, policy: Policy) !P.HistoryDefinition {
    if (point) |required| if (!std.meta.eql(lease, required.lease)) return error.DataIdentityConflict;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, lease.owner, policy, false);
    defer access.view.deinit();
    return if (point) |required| access.view.table.historyAt(allocator, required, access.current) else access.view.table.historyStart(allocator, lease, access.current);
}

pub fn scanHistory(self: *Self, allocator: std.mem.Allocator, object: d.Object, point: P.HistoryPoint, after: ?P.SnapshotCursor, limits: P.ReadLimits, policy: Policy) !P.HistoryRows {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, point.lease.owner, policy, false);
    defer access.view.deinit();
    return access.view.table.scanHistory(allocator, point, after, limits, access.current);
}

pub fn pinState(self: *Self, object: d.Object, owner: d.Operation, policy: Policy) !P.PinState {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, owner, policy, true);
    defer access.view.deinit();
    return access.view.table.pinState(owner, access.current);
}

pub fn snapshotDefinition(self: *Self, allocator: std.mem.Allocator, object: d.Object, handle: P.SnapshotHandle, policy: Policy) !P.SnapshotDefinition {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, handle.owner, policy, false);
    defer access.view.deinit();
    return access.view.table.inspectSnapshot(allocator, handle, access.current);
}

/// Resolve exactly the native objects whose current rights guard this source.
/// This does not grant access or acquire a pin. A computation uses these same
/// references in its own native publication guard after reading direct rows.
pub fn readAuthority(self: *Self, object: d.Object, owner: d.Operation, policy: Policy, control: bool) !c.DirectReadAuthority {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, owner, policy, control);
    defer access.view.deinit();
    const namespace = try self.authorizationSchema(access.view.properties.namespace);
    const result: c.DirectReadAuthority = .{ .database = self.config().authority.database, .schema = namespace.authorization, .table = access.view.properties.authorization };
    try result.validate();
    try check(access.current);
    return result;
}

/// Current rights for retained evidence are independent of live definition and
/// pin state. This reads the stable object, including after DROP/name reuse; it
/// creates no acquisition and returns no rows or replacement definition.
pub fn currentReadAuthority(self: *Self, object: d.Object, policy: Policy) !c.DirectReadAuthority {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.readAccess(arena.allocator(), object, policy, false);
    defer access.view.deinit();
    const namespace = try self.authorizationSchema(access.view.properties.namespace);
    const result: c.DirectReadAuthority = .{ .database = self.config().authority.database, .schema = namespace.authorization, .table = access.view.properties.authorization };
    try result.validate();
    try check(access.current);
    return result;
}

pub fn readRow(self: *Self, allocator: std.mem.Allocator, object: d.Object, handle: P.SnapshotHandle, key: []const u8, policy: Policy) !?P.OwnedRow {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, handle.owner, policy, false);
    defer access.view.deinit();
    return access.view.table.readSnapshot(allocator, handle, key, access.current);
}

pub fn scanRows(self: *Self, allocator: std.mem.Allocator, object: d.Object, handle: P.SnapshotHandle, after: ?P.SnapshotCursor, limits: P.ReadLimits, policy: Policy) !P.SnapshotPage {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, handle.owner, policy, false);
    defer access.view.deinit();
    return access.view.table.scanSnapshot(allocator, handle, after, limits, access.current);
}

pub fn releaseRows(self: *Self, object: d.Object, handle: P.SnapshotHandle, policy: Policy) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, handle.owner, policy, true);
    defer access.view.deinit();
    return access.view.table.releaseSnapshot(handle, access.current);
}

fn terminal(self: *Self, previous: r.Operation, phase: r.Phase, reason: r.Reason, current: P.Guard) !void {
    try self.store.index.begin(self.options.index_work_bytes);
    defer self.store.index.end();
    var next = self.store.root;
    const object_key = try r.idKey(previous.binding.target.object);
    if (try self.store.tree().get(next.pending, object_key)) |value| {
        const owner = try r.fromValue(d.Operation, self.allocator, value);
        if (std.meta.eql(owner, previous.binding.identity)) next.pending = try self.store.tree().remove(next.pending, object_key);
    }
    var operation = previous;
    operation.phase = phase;
    operation.reason = reason;
    try self.record(next, operation, current);
}

pub fn cancel(self: *Self, binding: d.Binding, policy: Policy) !Observation {
    const observed = try self.status(binding, policy);
    if (observed != .admitted) return observed;
    var request = (try self.loadRequest(binding)).?;
    defer request.deinit();
    const target = try self.entry(binding.target.object) orelse return error.InvalidDirectCatalogOperation;
    var view: ?View = null;
    defer if (view) |*value| value.deinit();
    if (target.seed != null) view = try self.open(self.allocator, target, true);
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const current = try self.requestGuard(arena.allocator(), policy, request.value, if (view) |*value| value else null, false);
    try self.terminal(observed.admitted, .cancelled, .none, current);
    return self.status(binding, policy);
}

pub fn settle(self: *Self, binding: d.Binding, policy: Policy) !Observation {
    const observed = try self.status(binding, policy);
    if (observed != .committed) return observed;
    const operation = (try self.store.operation(binding)).?;
    if (operation.phase == .settled) return observed;
    var request = (try self.loadRequest(binding)).?;
    defer request.deinit();
    const target = try self.entry(binding.target.object) orelse return error.InvalidDirectCatalogOperation;
    var view = try self.open(self.allocator, target, true);
    defer view.deinit();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const current = try self.requestGuard(arena.allocator(), policy, request.value, &view, false);
    try self.terminal(operation, .settled, .none, current);
    return observed;
}
