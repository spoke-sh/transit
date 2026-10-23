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
pub const Policy = struct {
    context: *anyopaque,
    subject: p.Authorization.Subject,
    make_guard: *const fn (*anyopaque, std.mem.Allocator, p.Authorization.Guard) anyerror!P.Guard,
    registered: *const fn (*anyopaque, a.Kind, u64) anyerror!?p.Authorization.Object,
};
pub const View = struct {
    table: P,
    properties: Properties,
    pub fn deinit(self: *View) void {
        self.table.deinit();
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
    return policy.make_guard(policy.context, allocator, try self.requirements(policy, namespace, target, access));
}

fn check(current: P.Guard) !void {
    _ = try current.acquire(current.context);
    current.release(current.context);
}

fn schema(self: *Self, id: u64) !a.Schema {
    const value = try self.store.tree().get(self.store.root.schemas, try r.idKey(id)) orelse return error.CatalogNamespaceMissing;
    const result = try r.fromValue(a.Schema, self.allocator, value);
    try result.validate();
    if (result.id != id or !std.meta.eql(result.scope, self.config().scope) or result.retired) return error.CatalogNamespaceMissing;
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
    next.schema_names = try self.store.tree().put(null, try pages.Key.init(&r.hash(initial.name.slice())), try r.pageValue(initial));
    try self.store.publish(next, .initialize, current);
}

fn entry(self: *Self, object: u64) !?r.Entry {
    const value = try self.store.tree().get(self.store.root.objects, try r.idKey(object)) orelse return null;
    const result = try r.fromValue(r.Entry, self.allocator, value);
    try result.validate(self.config());
    if (result.object != object or result.partition >= self.store.root.next_partition) return error.InvalidDirectCatalogEntry;
    return result;
}

fn open(self: *Self, allocator: std.mem.Allocator, target: r.Entry, control: bool) !View {
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
    try check(try policy.make_guard(policy.context, arena.allocator(), combined));
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
        check(try policy.make_guard(policy.context, arena.allocator(), required)) catch |err| {
            if (err == error.CatalogDenied or err == error.Forbidden) continue;
            return err;
        };
        combined = try combined.merge(required);
        result.entries[count] = .{ .interpretation = view.table.root.interpretation, .namespace = namespace_id, .name = view.properties.name, .position = .{ .partition = target.partition, .next_lsn = view.table.root.next_lsn }, .changed_lsn = view.table.root.changed_lsn };
        count += 1;
    };
    try check(try policy.make_guard(policy.context, arena.allocator(), combined));
    return result;
}

fn original(self: *Self, policy: Policy, binding: d.Binding) !void {
    try binding.validate();
    if (policy.subject.principal() != binding.identity.principal or !std.meta.eql(binding.identity.scope, self.config().scope) or binding.target.branch != self.config().branch) return error.CatalogDenied;
}

fn requestGuard(self: *Self, allocator: std.mem.Allocator, policy: Policy, request: Request, view: ?*View) !P.Guard {
    const namespace = try self.schema(request.intent.namespace);
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
    return policy.make_guard(policy.context, allocator, requested);
}

fn pending(self: *Self, object: u64, current: P.Guard) !bool {
    const value = try self.store.tree().get(self.store.root.pending, try r.idKey(object)) orelse return false;
    const operation = try r.fromValue(d.Operation, self.allocator, value);
    const binding = try c.OperationBinding.lookup(self.allocator, self.store.objects, operation) orelse return error.InvalidDirectCatalogOperation;
    const observed = try self.store.operation(binding) orelse return error.InvalidDirectCatalogOperation;
    if (!observed.pending()) return false;
    const target = try self.entry(object) orelse return error.InvalidDirectCatalogOperation;
    if (target.seed == null) return true;
    var view = try self.open(self.allocator, target, false);
    defer view.deinit();
    return (try view.table.observeEvidence(binding, current)) == null;
}

fn available(self: *Self, namespace: u64, name: a.Name, object: u64, current: P.Guard) !bool {
    const proposed = try self.candidate(namespace, name) orelse return true;
    const target = try self.entry(proposed.object) orelse return error.InvalidDirectCatalogName;
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
    const current = try self.requestGuard(arena.allocator(), policy, request, view);
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
    const current = try self.requestGuard(arena.allocator(), policy, request, if (existing) |*value| value else null);
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
            const target: r.Entry = .{ .object = object, .partition = next.next_partition, .seed = null };
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
    const current = try self.requestGuard(arena.allocator(), policy, request.value, if (view) |*value| value else null);
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
    const current = try self.requestGuard(arena.allocator(), policy, request.value, null);
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
    const current = try self.requestGuard(arena.allocator(), policy, request.value, null);
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
    const current = try self.requestGuard(arena.allocator(), policy, request.value, &view);
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
            else => return err,
        };
        try self.terminal(observed.admitted, .rejected, reason, current);
        return self.status(binding, policy);
    };
    // No catalog publication is needed for visibility or the accepted result.
    // A later explicit settlement only removes the pending-work directory entry.
    return .{ .committed = .{ .binding = binding, .resulting = view.table.root.declared(), .outcome = outcome } };
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
    const current = try self.guard(arena.allocator(), policy, try self.schema(view.properties.namespace), view.properties.target(target.object), access);
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
    try self.requireInitialized();
    try object.validate();
    try owner.validate();
    if (!std.meta.eql(object.scope, self.config().scope) or object.branch != self.config().branch or
        !std.meta.eql(owner.scope, object.scope) or owner.principal != policy.subject.principal()) return error.CatalogDenied;
    const target = try self.entry(object.object) orelse return error.CatalogDenied;
    var view = try self.open(self.allocator, target, control);
    errdefer view.deinit();
    const current = try self.guard(allocator, policy, try self.schema(view.properties.namespace), view.properties.target(object.object), .read);
    try check(current);
    return .{ .view = view, .current = current };
}

/// Pin ownership is private to the original principal. Possession of a handle
/// never substitutes for current database/schema/Table SELECT rights.
pub fn pinRows(self: *Self, object: d.Object, owner: d.Operation, expected: d.Position, policy: Policy) !P.SnapshotHandle {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, owner, policy, false);
    defer access.view.deinit();
    return access.view.table.pin(owner, expected, access.current);
}

pub fn snapshotDefinition(self: *Self, allocator: std.mem.Allocator, object: d.Object, handle: P.SnapshotHandle, policy: Policy) !P.SnapshotDefinition {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, handle.owner, policy, false);
    defer access.view.deinit();
    return access.view.table.inspectSnapshot(allocator, handle, access.current);
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
    const current = try self.requestGuard(arena.allocator(), policy, request.value, if (view) |*value| value else null);
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
    const current = try self.requestGuard(arena.allocator(), policy, request.value, &view);
    try self.terminal(operation, .settled, .none, current);
    return observed;
}
