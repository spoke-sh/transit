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
const L = c.DirectLog;
const P = s.TablePartition;
const pages = s.TreeStore.pages;
const Self = @This();
pub const Configuration = r.Configuration;
pub const RecoveryState = Store.RecoveryState;
pub const Request = r.Request;
pub const Intent = r.Intent;
pub const Properties = r.Properties;
pub const Options = struct {
    resident_pages: usize = 16,
    index_work_bytes: usize = 64 * 1024 * 1024,
    /// Durable token capacity, independent of the bounded resident page cache.
    /// Exhaustion refuses new bindings; it never forgets accepted identities.
    client_token_quota: u64 = 1_000_000,
    transaction_limits: p.Transaction.Limits = c.DirectTransaction.default_limits,
    transaction_account_limits: c.DirectClientToken.TransactionReservations = .defaults,
    /// Same bounded log owner profiles used by the embedding data service.
    logs: c.DirectTransactionLog.Options = .{},
    table: P.Options = .{},
    /// Optional same-storage-owner hint, serialized by the embedding host.
    /// No request allocations, permission or retained read are cached here.
    table_recovery: ?*?P.RecoveryState = null,
    /// Optional bounded live-owner slot. The host serializes borrowing, binds
    /// its provider/allocator lifetime and destroys it before storage replacement.
    table_owner: ?*?CachedTable = null,
};

pub const CachedTable = struct { seed: s.TableDeclaration.Stored, table: P };

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
    recovery_state: ?*?P.RecoveryState = null,
    owner_slot: ?*?CachedTable = null,
    seed: ?s.TableDeclaration.Stored = null,
    pub fn deinit(self: *View) void {
        if (self.recovery_state) |slot| {
            if (self.table.recoveryState()) |known| {
                if (slot.* == null or slot.*.?.root.partition != known.root.partition or
                    slot.*.?.root.next_lsn <= known.root.next_lsn) slot.* = known;
            } else |_| slot.* = null;
        }
        if (self.owner_slot) |slot| {
            if (self.table.recoveryState()) |_| {
                if (slot.*) |*previous| previous.table.deinit();
                slot.* = .{ .seed = self.seed.?, .table = self.table };
            } else |_| self.table.deinit();
        } else self.table.deinit();
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
/// Owned retained interpretation and its current native authorization objects,
/// resolved through one acquired Table owner. This is not a retention pin.
pub const SnapshotRead = struct {
    definition: P.SnapshotDefinition,
    authority: c.DirectReadAuthority,
    pub fn deinit(self: *SnapshotRead) void {
        self.definition.deinit();
        self.* = undefined;
    }
};
pub const HistoryRead = struct {
    definition: P.HistoryDefinition,
    authority: c.DirectReadAuthority,
    pub fn deinit(self: *HistoryRead) void {
        self.definition.deinit();
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
pub const RowPreview = struct {
    binding: d.Binding,
    directory_position: d.Position,
    current: Preview.Basis,
    reason: enum { none, stale_definition, stale_data, object_conflict },
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
/// Borrowed only during one signed read dispatch; never retained between calls.
transaction_read: ?c.DirectTransactionRead.Context = null,
/// Borrowed only during the enclosing trusted host dispatch.
log_environment: ?*const c.DirectTransactionLog.Environment = null,
/// Failure injection after the Table acceptance and before its caller reply.
lose_table_reply: bool = false,
/// Failure injection after the original coordination acceptance.
lose_transaction_reply: bool = false,

pub fn init(allocator: std.mem.Allocator, configuration: Configuration, control_log: s.TransitLog.Log, control_objects: s.TransitObjectStore.ObjectStore, data_log: s.TransitLog.Log, data_objects: s.TransitObjectStore.ObjectStore, options: Options) !Self {
    if (options.index_work_bytes == 0 or options.client_token_quota == 0) return error.InvalidStorageBudget;
    return .{ .allocator = allocator, .store = try Store.init(allocator, configuration, control_log, control_objects, options.resident_pages), .data_log = data_log, .data_objects = data_objects, .options = options };
}
pub fn deinit(self: *Self) void {
    self.store.deinit();
    self.* = undefined;
}
pub fn recover(self: *Self) !void {
    try self.store.recover();
}

/// Reuse only a prefix validated by this same live owner and immutable log.
/// A new owner starts with recover(); current policy is always checked separately.
pub fn recoverSince(self: *Self, prior: RecoveryState) !void {
    try self.store.recoverSince(prior);
}

pub fn recoveryState(self: *Self) !RecoveryState {
    return self.store.recoveryState();
}

/// Disposable physical-work hints, never a retained read or permission. The
/// pass boundary prevents continual high-ID creation from starving older Tables.
/// Each step observes the current directory; additions behind it wait one pass.
pub const MaintenanceCursor = struct { after: ?u64 = null, through: ?u64 = null };
pub const MaintenanceSelection = struct { object: ?u64, pass_complete: bool };

/// Internal operator traversal, not application metadata disclosure. The host
/// supplies a current native maintenance guard and holds its directory lock.
/// Inspect one entry per step, including unregistered and named native objects.
/// No Table owner or list proportional to durable cardinality remains resident.
pub fn maintenanceNext(self: *Self, cursor: *MaintenanceCursor, guard_value: P.Guard) !MaintenanceSelection {
    try check(guard_value);
    try self.store.refresh();
    if (cursor.after) |after| if (cursor.through == null or after > cursor.through.?) return error.InvalidMaintenanceCursor;
    var next = cursor.*;
    if (next.through == null) {
        if (try self.store.tree().lastEntry(self.store.root.objects)) |last| {
            const value = try r.fromValue(r.Entry, self.allocator, last.value);
            try self.validateEntry(value, last.key);
            next.through = value.object;
        }
    }
    var selected: ?u64 = null;
    var complete = true;
    if (self.store.root.initialized and next.through != null) {
        const page = try self.store.tree().scan(self.store.root.objects, if (next.after) |after| try r.idKey(after) else null);
        if (page.entries[0]) |item| {
            const value = try r.fromValue(r.Entry, self.allocator, item.value);
            try self.validateEntry(value, item.key);
            if (value.object <= next.through.?) {
                next.after = value.object;
                complete = value.object == next.through.?;
                if (value.resource == null and value.seed != null) selected = value.object;
            }
        }
    }
    try check(guard_value);
    cursor.* = if (complete) .{} else next;
    return .{ .object = selected, .pass_complete = complete };
}

fn validateEntry(self: *Self, value: r.Entry, key: pages.Key) !void {
    try value.validate(self.config());
    if (!std.meta.eql(key, try r.idKey(value.object)) or value.partition >= self.store.root.next_partition or (value.resource orelse 0) >= self.store.root.next_lsn) return error.InvalidDirectCatalogEntry;
}

/// The caller takes the selected Table's lock after directory discovery and
/// retains both locks through the physical unit. Revalidate the current entry;
/// the cursor contains no borrowed schema, stale owner, or authorization.
pub fn maintenanceOpen(self: *Self, allocator: std.mem.Allocator, object: u64, guard_value: P.Guard) !?View {
    try check(guard_value);
    try self.requireInitialized();
    const target = try self.entry(object) orelse {
        try check(guard_value);
        return null;
    };
    if (target.resource != null or target.seed == null) {
        try check(guard_value);
        return null;
    }
    var view = try self.open(allocator, target, false);
    errdefer view.deinit();
    try check(guard_value);
    return view;
}

fn namedRecord(self: *Self, object: u64) !?Resource.Operation {
    const target = try self.entry(object) orelse return null;
    const at = target.resource orelse return null;
    const value = try self.store.resourceRecord(at);
    if (value.binding.object.object != object) return error.InvalidDirectCatalogEntry;
    return value;
}

fn logRecord(self: *Self, object: u64) !?L.Operation {
    const target = try self.entry(object) orelse return null;
    const value = try self.store.logRecord(target.log orelse return null);
    if (value.binding.target.object != object or value.first_partition != target.partition) return error.InvalidDirectCatalogEntry;
    return value;
}

/// Bounded operator traversal. A pass freezes its highest object ID and visits
/// one partition of one complete declaration of the selected log kind per step. These disposable
/// hints retain no authorization, schema allocations or partition owners.
pub const LogMaintenanceCursor = struct {
    objects: MaintenanceCursor = .{},
    pending: ?struct { object: u64, ordinal: u32 } = null,
};
pub const LogMaintenanceTarget = struct { object: u64, ordinal: u32 };
pub const LogMaintenanceSelection = struct { target: ?LogMaintenanceTarget, pass_complete: bool };

pub fn logMaintenanceNext(self: *Self, kind: p.StreamQueueDeclaration.Kind, cursor: *LogMaintenanceCursor, guard_value: P.Guard) !LogMaintenanceSelection {
    try check(guard_value);
    try self.store.refresh();
    var next = cursor.*;
    if (next.objects.after) |after| if (next.objects.through == null or after > next.objects.through.?) return error.InvalidMaintenanceCursor;
    if (next.pending) |active| {
        if (next.objects.through == null or active.object > next.objects.through.? or
            active.object <= (next.objects.after orelse 0) or active.ordinal == 0)
            return error.InvalidMaintenanceCursor;
    }
    if (next.objects.through == null) {
        if (try self.store.tree().lastEntry(self.store.root.objects)) |last| {
            const value = try r.fromValue(r.Entry, self.allocator, last.value);
            try self.validateEntry(value, last.key);
            next.objects.through = value.object;
        }
    }
    var object: ?u64 = if (next.pending) |active| active.object else null;
    if (object == null and self.store.root.initialized and next.objects.through != null) {
        const page = try self.store.tree().scan(self.store.root.objects, if (next.objects.after) |after| try r.idKey(after) else null);
        if (page.entries[0]) |item| {
            const value = try r.fromValue(r.Entry, self.allocator, item.value);
            try self.validateEntry(value, item.key);
            if (value.object <= next.objects.through.?) object = value.object;
        }
    }
    var target: ?LogMaintenanceTarget = null;
    var complete = true;
    if (object) |id| {
        const ordinal = if (next.pending) |active| active.ordinal else 0;
        next.pending = null;
        next.objects.after = id;
        complete = id == next.objects.through.?;
        if (try self.logRecord(id)) |known| {
            if (known.phase == .complete and known.kind == kind) {
                const definition = known.resulting.?;
                if (ordinal >= definition.count()) return error.InvalidMaintenanceCursor;
                target = .{ .object = id, .ordinal = ordinal };
                if (ordinal + 1 < definition.count()) {
                    next.pending = .{ .object = id, .ordinal = ordinal + 1 };
                    next.objects.after = cursor.objects.after;
                    complete = false;
                }
            }
        }
    }
    try check(guard_value);
    cursor.* = if (complete) .{} else next;
    return .{ .target = target, .pass_complete = complete };
}

/// Revalidate under the host's directory and object locks. The returned owned
/// scalar definition can select storage work; only the current guard can
/// authorize it. Retired declarations remain eligible for recovery and closure.
pub fn logMaintenanceDefinition(self: *Self, kind: p.StreamQueueDeclaration.Kind, target: LogMaintenanceTarget, guard_value: P.Guard) !?L.Definition {
    try check(guard_value);
    try self.store.refresh();
    const known = try self.logRecord(target.object);
    const definition = if (known != null and known.?.phase == .complete and known.?.kind == kind) known.?.resulting else null;
    if (definition) |value| _ = try value.partition(target.ordinal);
    try check(guard_value);
    return definition;
}

fn logGuard(self: *Self, allocator: std.mem.Allocator, request: L.Request, policy: Policy, write: bool, acceptance: bool) !P.Guard {
    if (request.binding.identity.principal != policy.subject.principal()) return error.CatalogDenied;
    const known = try self.logRecord(request.binding.target.object);
    if (known) |value| if (value.kind != request.intent.kind) return error.CatalogKindMismatch;
    const definition = if (known) |value| value.resulting else null;
    const namespace = try self.authorizationSchema(if (definition) |value| value.properties.namespace else request.intent.namespace);
    // Verify the same database and schema registrations as every other direct
    // object; the log target then selects its own immutable native domain.
    _ = try self.requirements(policy, namespace, null, .schema);
    var target: ?a.Table = null;
    if (definition) |value| {
        target = value.properties.target(request.binding.target.object);
    } else if (try policy.registered(policy.context, L.authorityKind(request.intent.kind), request.binding.target.object)) |native| {
        try a.validateObject(self.config().authority, self.config().scope, L.authorityKind(request.intent.kind), request.binding.target.object, a.reference(namespace.authorization), native);
        target = .{ .id = request.binding.target.object, .schema = namespace.id, .authorization = native.reference.id };
    }
    if (target) |value| try self.verifiedObject(policy, L.authorityKind(request.intent.kind), value.id, value.authorization, a.reference(namespace.authorization));
    const access: c.LogAuthority.Access = if (request.binding.action == .create and (write or definition == null)) .create else if (write) .administer else .inspect;
    var required = try c.LogAuthority.requirements(self.config().authority, policy.subject, namespace, target, access);
    if (access == .create) {
        required.selectable = request.intent.action.create.owner;
        if (target) |value| required.requirements[2] = .{ .object = a.reference(value.authorization), .access = .ownership };
    }
    if (acceptance and (request.intent.action == .create or request.intent.action == .alter)) {
        const configuration = if (request.intent.action == .create) request.intent.action.create.configuration else request.intent.action.alter.configuration;
        if (configuration.policy == .queue) if (configuration.policy.queue.dead_letter) |destination| {
            const found = try self.dependencySource(destination.object, policy, c.LogAuthority.inspect | c.LogAuthority.append);
            required = try required.merge(found.requirements);
        };
    }
    return policy.make_guard(policy.context, allocator, required, if (acceptance) request.binding.prerequisite else null);
}

fn logReason(self: *Self, request: L.Request, current: P.Guard) !L.Reason {
    const binding = request.binding;
    const intent = request.intent;
    if (try self.namespacePending(intent.namespace) != null) return .object_conflict;
    _ = try self.schema(intent.namespace);
    if (binding.action == .create) {
        if (try self.entry(binding.target.object) != null) return .object_conflict;
        if (!try self.available(intent.namespace, intent.name, binding.target.object, current)) return .name_conflict;
        return .none;
    }
    const known = try self.logRecord(binding.target.object) orelse return .object_conflict;
    if (known.phase != .complete or known.resulting.?.stored.retired or try self.pending(binding.target.object, current)) return .object_conflict;
    const value = known.resulting.?;
    if (!std.meta.eql(value.stored.declaration.interpretation, binding.expected_definition.?) or value.properties.namespace != intent.namespace or !std.meta.eql(value.properties.name, intent.name)) return .stale_definition;
    if (binding.action == .drop and try self.hasDependents(binding.target.object)) return .dependency;
    if (binding.action == .rename and !try self.available(intent.namespace, intent.action.rename, binding.target.object, current)) return .name_conflict;
    if (binding.action == .alter) try value.stored.declaration.configuration.requireEvolution(intent.action.alter.configuration);
    return .none;
}

/// Validate typed policies against the exact schema before any identity or
/// partition reservation. DLQ publication joins the dependency/transaction owner.
fn validateLogRequest(self: *Self, request: L.Request) !void {
    try request.validate(self.allocator, self.config());
    if (request.intent.action == .alter) {
        const current = try self.logRecord(request.binding.target.object) orelse return error.CatalogKindMismatch;
        if (current.resulting) |value| {
            var stored = try s.LogDeclaration.load(self.allocator, self.data_objects, value.stored);
            defer stored.deinit();
            var next = stored.definition;
            next.configuration = request.intent.action.alter.configuration;
            next.limits = request.intent.action.alter.limits;
            try next.validate();
            try stored.definition.configuration.requireEvolution(next.configuration);
        }
    }
    const configuration = switch (request.intent.action) {
        .create => |value| value.configuration,
        .alter => |value| value.configuration,
        else => return,
    };
    if (configuration.policy == .queue) if (configuration.policy.queue.dead_letter) |destination| {
        const target = try self.logRecord(destination.object.object) orelse return error.InvalidQueueDestination;
        if (target.phase != .complete or target.kind != .queue or target.resulting.?.stored.retired or
            !std.meta.eql(target.resulting.?.stored.declaration.interpretation, destination)) return error.QueueDestinationChanged;
        var destination_schema = try s.LogDeclaration.load(self.allocator, self.data_objects, target.resulting.?.stored);
        defer destination_schema.deinit();
        var source_schema: ?s.LogDeclaration.Owned = null;
        defer if (source_schema) |*value| value.deinit();
        const expected = if (request.intent.action == .create) request.intent.action.create.schema else blk: {
            const source = (try self.logRecord(request.binding.target.object)).?.resulting.?;
            source_schema = try s.LogDeclaration.load(self.allocator, self.data_objects, source.stored);
            break :blk source_schema.?.definition.schema;
        };
        var actual = destination_schema.definition.schema;
        actual.object = expected.object;
        actual.revision = expected.revision;
        if (!std.mem.eql(u8, &try expected.fingerprint(), &try actual.fingerprint())) return error.QueueDestinationSchemaMismatch;
    };
}

pub fn previewLog(self: *Self, request: L.Request, policy: Policy) !L.Preview {
    try self.requireInitialized();
    var arena: std.heap.ArenaAllocator = .init(self.allocator);
    defer arena.deinit();
    try request.validate(arena.allocator(), self.config());
    const current = try self.logGuard(arena.allocator(), request, policy, true, true);
    try check(current);
    try self.validateLogRequest(request);
    if (try c.OperationBinding.lookup(self.allocator, self.store.objects, request.binding.identity)) |known| try known.requireSame(request.binding);
    const known = try self.logRecord(request.binding.target.object);
    const result: L.Preview = .{ .binding = request.binding, .position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn }, .current = if (known) |value| value.resulting else null, .reason = try self.logReason(request, current) };
    try check(current);
    return result;
}

fn recordLog(self: *Self, input: L.Operation, previous: ?L.Operation, current: P.Guard) !L.Operation {
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
    defer self.store.index.end();
    var next = self.store.root;
    var operation = input;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    operation.position = .{ .partition = self.config().partition, .next_lsn = next.next_lsn };
    try operation.validate();
    const id = try r.idKey(operation.binding.target.object);
    if (operation.phase == .admitted and operation.binding.action == .create) {
        if (operation.first_partition != next.next_partition) return error.InvalidLogCatalogOperation;
        next.next_partition = try std.math.add(u64, next.next_partition, operation.partition_count);
        var namespace = try self.schema(operation.namespace);
        namespace.revision = try std.math.add(u64, namespace.revision, 1);
        next.schemas = try self.store.tree().put(next.schemas, try r.idKey(namespace.id), try r.pageValue(namespace));
    }
    const updates_object = if (operation.binding.action == .create) operation.phase == .admitted or previous != null else operation.phase == .complete;
    if (updates_object) {
        const target: r.Entry = .{ .object = operation.binding.target.object, .partition = operation.first_partition, .seed = null, .resource = null, .log = self.store.root.next_lsn };
        next.objects = try self.store.tree().put(next.objects, id, try r.pageValue(target));
    }
    if (operation.phase == .admitted and (operation.binding.action == .create or operation.binding.action == .rename)) {
        const name: r.Name = .{ .namespace = operation.namespace, .name = operation.name, .object = operation.binding.target.object, .reservation = operation.binding.identity };
        next.names = try self.store.tree().put(next.names, try r.nameKey(name.namespace, name.name), try r.pageValue(name));
    }
    if (operation.pending()) {
        next.pending = try self.store.tree().put(next.pending, id, try r.pageValue(operation.binding.identity));
    } else if (previous != null) next.pending = try self.store.tree().remove(next.pending, id);
    if (operation.phase == .complete) if (try operation.resulting.?.deadLetterEdge()) |edge| {
        const value = try r.pageValue(edge);
        next.dependents = try self.store.tree().put(next.dependents, try edge.forwardKey(), value);
        next.dependencies = try self.store.tree().put(next.dependencies, try edge.reverseKey(), value);
    };
    try self.store.receiptIdentity(&next, operation.binding.identity);
    try self.store.publish(next, .{ .log = operation }, current);
    return operation;
}

pub fn admitLog(self: *Self, request: L.Request, policy: Policy) !L.Operation {
    try self.requireInitialized();
    var arena: std.heap.ArenaAllocator = .init(self.allocator);
    defer arena.deinit();
    try request.validate(arena.allocator(), self.config());
    const current = try self.logGuard(arena.allocator(), request, policy, true, true);
    try check(current);
    if (try c.OperationBinding.lookup(self.allocator, self.store.objects, request.binding.identity)) |known| try known.requireSame(request.binding);
    if (try self.store.logOperation(request.binding)) |previous| {
        try check(current);
        return previous;
    }
    try self.validateLogRequest(request);
    const reason = try self.logReason(request, current);
    var operation: L.Operation = .{ .binding = request.binding, .intent = try L.IntentStore.stage(self.allocator, self.store.objects, self.config(), request), .kind = request.intent.kind, .namespace = request.intent.namespace, .name = if (request.intent.action == .rename) request.intent.action.rename else request.intent.name, .owner = if (request.intent.action == .create) request.intent.action.create.owner else null, .position = .{ .partition = self.config().partition, .next_lsn = 1 }, .phase = if (reason == .none) .admitted else .rejected, .reason = reason, .first_partition = 0, .partition_count = 0, .initialized = 0, .resulting = null };
    if (reason == .none) {
        if (request.intent.action == .create) {
            operation.first_partition = self.store.root.next_partition;
            operation.partition_count = request.intent.action.create.configuration.partitioning.count;
        } else {
            const known = (try self.logRecord(request.binding.target.object)).?.resulting.?;
            operation.first_partition = known.first_partition;
            operation.partition_count = known.count();
        }
    }
    try operation.validate();
    try c.OperationBinding.claim(self.allocator, self.store.objects, request.binding);
    return self.recordLog(operation, null, current);
}

fn logRequest(self: *Self, binding: d.Binding) !?L.IntentStore.Owned {
    if (try c.OperationBinding.lookup(self.allocator, self.store.objects, binding.identity)) |known| try known.requireSame(binding);
    const operation = try self.store.logOperation(binding) orelse return null;
    var request = try L.IntentStore.load(self.allocator, self.store.objects, self.config(), operation.intent);
    errdefer request.deinit();
    try request.value.binding.requireSame(binding);
    return request;
}

pub fn logRegistration(self: *Self, binding: d.Binding, policy: Policy) !?Registration {
    const status_value = try self.logOperation(binding, .inspect, policy);
    if (status_value != .operation or !status_value.operation.pending() or binding.action != .create) return null;
    const operation = status_value.operation;
    var request = (try self.logRequest(binding)).?;
    defer request.deinit();
    var arena: std.heap.ArenaAllocator = .init(self.allocator);
    defer arena.deinit();
    const guard_value = try self.logGuard(arena.allocator(), request.value, policy, true, true);
    const fence = try guard_value.acquire(guard_value.context);
    defer guard_value.release(guard_value.context);
    if (try policy.registered(policy.context, L.authorityKind(operation.kind), binding.target.object) != null) return null;
    const namespace = try self.schema(operation.namespace);
    return .{ .action = .{ .domain = self.config().authority.domain(L.authorityKind(operation.kind)), .owner = operation.owner.?, .schema = a.reference(namespace.authorization), .binding = try a.binding(self.config().scope, L.authorityKind(operation.kind), binding.target.object) }, .authorization_revision = fence.policy_epoch - 1 };
}

fn prepareLogDefinition(self: *Self, request: L.Request, operation: L.Operation, policy: Policy) !L.Definition {
    if (request.intent.action == .create) {
        const namespace = try self.schema(operation.namespace);
        const native = try policy.registered(policy.context, L.authorityKind(operation.kind), request.binding.target.object) orelse return error.CatalogRegistrationRequired;
        try a.validateObject(self.config().authority, self.config().scope, L.authorityKind(operation.kind), request.binding.target.object, a.reference(namespace.authorization), native);
        if (native.owner != operation.owner.?) return error.CatalogIdentityConflict;
        const properties: Properties = .{ .namespace = operation.namespace, .authorization = native.reference.id, .name = operation.name };
        var bytes: [s.LogDeclaration.max_properties_bytes]u8 = undefined;
        const proposed = request.intent.action.create;
        var candidate_value = try s.LogDeclaration.prepare(self.allocator, .{ .object = request.binding.target, .revision = 1, .schema = proposed.schema, .configuration = proposed.configuration, .limits = proposed.limits, .properties = try properties.encode(&bytes) });
        defer candidate_value.deinit();
        const stored = try s.LogDeclaration.stage(self.data_objects, &candidate_value);
        return .{ .stored = stored, .seed = stored, .properties = properties, .initialization = request.binding.identity, .first_partition = operation.first_partition };
    }
    const known = (try self.logRecord(request.binding.target.object) orelse return error.InvalidLogCatalogOperation).resulting.?;
    if (!std.meta.eql(known.stored.declaration.interpretation, request.binding.expected_definition.?)) return error.DataIdentityConflict;
    var previous_declaration = try s.LogDeclaration.load(self.allocator, self.data_objects, known.stored);
    defer previous_declaration.deinit();
    var result = known;
    var next = previous_declaration.definition;
    next.revision = try std.math.add(u64, next.revision, 1);
    switch (request.intent.action) {
        .create => unreachable,
        .rename => |name| result.properties.name = name,
        .drop => next.retired = true,
        .alter => |value| {
            try next.configuration.requireEvolution(value.configuration);
            next.configuration = value.configuration;
            next.limits = value.limits;
        },
    }
    var bytes: [s.LogDeclaration.max_properties_bytes]u8 = undefined;
    next.properties = try result.properties.encode(&bytes);
    var candidate_value = try s.LogDeclaration.prepare(self.allocator, next);
    defer candidate_value.deinit();
    result.stored = try s.LogDeclaration.stage(self.data_objects, &candidate_value);
    try known.stored.declaration.requireSuccessor(result.stored.declaration);
    return result;
}

/// One execute initializes at most one partition, with verified readback before
/// recording progress. Lost replies recover the same allocation and genesis.
pub fn logOperation(self: *Self, binding: d.Binding, command: L.Command, policy: Policy) !L.Observation {
    if (command == .admit) return error.LogCatalogRequestRequired;
    try self.requireInitialized();
    try binding.validate();
    if (binding.identity.principal != policy.subject.principal()) return error.CatalogDenied;
    var arena: std.heap.ArenaAllocator = .init(self.allocator);
    defer arena.deinit();
    const initial = try self.guard(arena.allocator(), policy, null, null, .database);
    try check(initial);
    var request = (try self.logRequest(binding)) orelse {
        try check(initial);
        return .not_observed;
    };
    defer request.deinit();
    const previous = (try self.store.logOperation(binding)).?;
    const current = try self.logGuard(arena.allocator(), request.value, policy, command != .inspect and previous.pending(), command == .execute and previous.pending());
    try check(current);
    if (!previous.pending() or command == .inspect) {
        try check(current);
        return .{ .operation = previous };
    }
    var next = previous;
    if (command == .cancel) {
        next.phase = .cancelled;
    } else {
        try self.validateLogRequest(request.value);
        if (binding.action == .drop and try self.hasDependents(binding.target.object)) {
            next.phase = .rejected;
            next.reason = .dependency;
        } else {
            if (next.resulting == null) next.resulting = try self.prepareLogDefinition(request.value, next, policy);
            if (binding.action == .create) {
                _ = try s.LogInitialization.initialize(self.allocator, self.data_log, self.data_objects, try next.resulting.?.genesis(next.initialized), current);
                next.initialized += 1;
                next.phase = if (next.initialized == next.partition_count) .complete else .initializing;
            } else next.phase = .complete;
        }
    }
    return .{ .operation = try self.recordLog(next, previous, current) };
}

fn inspectLogDefinition(self: *Self, allocator: std.mem.Allocator, definition: L.Definition, policy: Policy) !p.Authorization.Guard {
    try definition.validate();
    const namespace = try self.authorizationSchema(definition.properties.namespace);
    _ = try self.requirements(policy, namespace, null, .schema);
    try self.verifiedObject(policy, L.authorityKind(definition.kind()), definition.stored.declaration.interpretation.object.object, definition.properties.authorization, a.reference(namespace.authorization));
    const requirements_value = try c.LogAuthority.requirements(self.config().authority, policy.subject, namespace, definition.properties.target(definition.stored.declaration.interpretation.object.object), .inspect);
    try check(try policy.make_guard(policy.context, allocator, requirements_value, null));
    var loaded = try s.LogDeclaration.load(allocator, self.data_objects, definition.stored);
    defer loaded.deinit();
    if (!std.meta.eql(definition.properties, try Properties.decode(allocator, loaded.definition.properties))) return error.InvalidLogCatalogDefinition;
    return requirements_value;
}

pub fn resolveLog(self: *Self, namespace_id: u64, name: a.Name, policy: Policy) !?L.Definition {
    try self.requireInitialized();
    var arena: std.heap.ArenaAllocator = .init(self.allocator);
    defer arena.deinit();
    const namespace = try self.schema(namespace_id);
    var required = try self.requirements(policy, namespace, null, .schema);
    try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
    var result: ?L.Definition = null;
    if (try self.candidate(namespace_id, name)) |candidate_name| {
        if (try self.logRecord(candidate_name.object)) |known| {
            if (known.phase == .complete and !known.resulting.?.stored.retired) {
                const value = known.resulting.?;
                if (value.properties.namespace == namespace_id and std.meta.eql(value.properties.name, name)) {
                    required = try required.merge(try self.inspectLogDefinition(arena.allocator(), value, policy));
                    result = value;
                }
            }
        }
    }
    try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
    return result;
}

pub fn listLogs(self: *Self, namespace_id: u64, after: ?pages.Key, policy: Policy) !L.Page {
    try self.requireInitialized();
    var arena: std.heap.ArenaAllocator = .init(self.allocator);
    defer arena.deinit();
    const namespace = try self.schema(namespace_id);
    var required = try self.requirements(policy, namespace, null, .schema);
    try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
    const batch = try self.store.tree().scan(self.store.root.objects, after);
    var result: L.Page = .{ .next = batch.next, .position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn } };
    var count: usize = 0;
    for (batch.entries) |slot| if (slot) |item| {
        const target = try r.fromValue(r.Entry, self.allocator, item.value);
        try target.validate(self.config());
        if (!std.meta.eql(item.key, try r.idKey(target.object))) return error.InvalidDirectCatalogEntry;
        const known = try self.store.logRecord(target.log orelse continue);
        if (known.binding.target.object != target.object) return error.InvalidDirectCatalogEntry;
        if (known.phase != .complete or known.resulting.?.stored.retired) continue;
        const value = known.resulting.?;
        if (value.properties.namespace != namespace_id) continue;
        const checked = self.inspectLogDefinition(arena.allocator(), value, policy) catch |err| switch (err) {
            error.CatalogDenied, error.AccessDenied, error.Forbidden => continue,
            else => return err,
        };
        required = try required.merge(checked);
        result.entries[count] = value;
        count += 1;
    };
    try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
    return result;
}

/// Discover only this caller's accepted pending log declarations. A scanned
/// shared-directory page remains bounded even when every entry is filtered.
pub fn pendingLogs(self: *Self, namespace_id: u64, after: ?pages.Key, policy: Policy) !L.PendingPage {
    try self.requireInitialized();
    var arena: std.heap.ArenaAllocator = .init(self.allocator);
    defer arena.deinit();
    const initial = try self.guard(arena.allocator(), policy, try self.schema(namespace_id), null, .schema);
    try check(initial);
    const batch = try self.store.tree().scan(self.store.root.pending, after);
    var result: L.PendingPage = .{ .next = batch.next, .position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn } };
    var guards: [pages.page_entries]?P.Guard = @splat(null);
    var count: usize = 0;
    for (batch.entries) |slot| if (slot) |item| {
        if (item.key.len != 8) return error.InvalidDirectCatalogEntry;
        const identity = try r.fromValue(d.Operation, self.allocator, item.value);
        if (identity.principal != policy.subject.principal()) continue;
        const object = std.mem.readInt(u64, item.key.data[0..8], .big);
        const target = try self.entry(object) orelse return error.InvalidDirectCatalogEntry;
        if (target.log == null) continue;
        const binding = try c.OperationBinding.lookup(self.allocator, self.store.objects, identity) orelse return error.InvalidLogCatalogOperation;
        const operation = try self.store.logOperation(binding) orelse return error.InvalidLogCatalogOperation;
        if (operation.binding.target.object != object or !operation.pending()) return error.InvalidLogCatalogOperation;
        if (operation.namespace != namespace_id) continue;
        var request = (try self.logRequest(binding)).?;
        defer request.deinit();
        const current = try self.logGuard(arena.allocator(), request.value, policy, false, false);
        check(current) catch |err| switch (err) {
            error.CatalogDenied, error.AccessDenied, error.Forbidden => continue,
            else => return err,
        };
        guards[count] = current;
        result.entries[count] = operation;
        count += 1;
    };
    try check(initial);
    for (guards) |slot| if (slot) |current| try check(current);
    return result;
}

/// Open schema bytes for a currently observed descriptor under the same native
/// metadata rights. The caller owns this allocation and must recheck its request
/// guard after buffering any response derived from it.
pub fn logDefinition(self: *Self, allocator: std.mem.Allocator, definition: L.Definition, policy: Policy) !s.LogDeclaration.Owned {
    try self.requireInitialized();
    var arena: std.heap.ArenaAllocator = .init(self.allocator);
    defer arena.deinit();
    const required = try self.inspectLogDefinition(arena.allocator(), definition, policy);
    const known = try self.logRecord(definition.stored.declaration.interpretation.object.object) orelse return error.InvalidLogCatalogDefinition;
    if (known.phase != .complete or !std.meta.eql(known.resulting, @as(?L.Definition, definition))) return error.LogDeclarationConflict;
    var result = try s.LogDeclaration.load(allocator, self.data_objects, definition.stored);
    errdefer result.deinit();
    try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
    return result;
}

pub const LogAuthorization = struct { definition: L.Definition, guard: P.Guard };
/// Resolve stable identity under current native rights, independently of the
/// original request's definition. Storage checks that frozen definition for new
/// acceptance; old outcomes and retained reads remain observable after ALTER
/// or DROP. The caller holds the directory/partition locks through disclosure.
/// Guard context belongs to scratch and must never enter a cached owner.
pub fn logAuthorization(self: *Self, scratch: std.mem.Allocator, kind: p.StreamQueueDeclaration.Kind, target: p.StreamQueue.Partition, access: c.LogAuthority.Access, policy: Policy) !LogAuthorization {
    try self.requireInitialized();
    try target.validate();
    if (access == .create or !std.meta.eql(target.interpretation.object.scope, self.config().scope) or target.interpretation.object.branch != self.config().branch) return error.CatalogDenied;
    const known = try self.logRecord(target.interpretation.object.object) orelse return error.LogDeclarationConflict;
    if (known.phase != .complete) return error.LogDeclarationConflict;
    const definition = known.resulting.?;
    if (definition.kind() != kind) return error.CatalogKindMismatch;
    _ = try definition.partition(target.partition);
    const namespace = try self.authorizationSchema(definition.properties.namespace);
    _ = try self.requirements(policy, namespace, null, .schema);
    try self.verifiedObject(policy, switch (kind) {
        .stream => .stream,
        .queue => .queue,
    }, target.interpretation.object.object, definition.properties.authorization, a.reference(namespace.authorization));
    const required = try c.LogAuthority.requirements(self.config().authority, policy.subject, namespace, definition.properties.target(target.interpretation.object.object), access);
    const current = try policy.make_guard(policy.context, scratch, required, null);
    try check(current);
    return .{ .definition = definition, .guard = current };
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
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
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
        const target: r.Entry = .{ .object = binding.object.object, .partition = 0, .seed = null, .resource = self.store.root.next_lsn, .log = null };
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

fn kvRequirements(self: *Self, policy: Policy, namespace: a.Schema, target: ?a.Table, access: c.KVAuthority.Access) !p.Authorization.Guard {
    _ = try self.requirements(policy, namespace, null, .schema);
    if (target) |value| try self.verifiedObject(policy, .kv, value.id, value.authorization, a.reference(namespace.authorization));
    var requested = try c.KVAuthority.requirements(self.config().authority, policy.subject, namespace, target, access);
    if (access == .create) if (target) |value| {
        requested.requirements[2] = .{ .object = a.reference(value.authorization), .access = .ownership };
    };
    return requested;
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
        if (self.transaction_read) |context| {
            const read = try self.guard(arena.allocator(), policy, namespace_value, view.?.properties.target(expected.object.object), .read);
            try self.overlayTransactionRead(&view.?, context, read, policy);
        }
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
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    try check(try self.operationGuard(arena.allocator(), binding, namespace_id, policy));
}
fn operationGuard(self: *Self, allocator: std.mem.Allocator, binding: d.Binding, namespace_id: u64, policy: Policy) !P.Guard {
    try self.requireInitialized();
    try self.original(policy, binding);
    try c.Model.nativeId(namespace_id);
    try check(try self.guard(allocator, policy, null, null, .database));
    const namespace_value = try self.authorizationSchema(namespace_id);
    try check(try self.guard(allocator, policy, namespace_value, null, .schema));
    if (binding.action == .create) {
        const native = try policy.registered(policy.context, .table, binding.target.object);
        const target: ?a.Table = if (native) |value| .{ .id = binding.target.object, .schema = namespace_id, .authorization = value.reference.id } else null;
        return self.guard(allocator, policy, namespace_value, target, .create_table);
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
    return self.guard(allocator, policy, namespace_value, view.properties.target(binding.target.object), access);
}

pub fn directRecord(self: *Self, allocator: std.mem.Allocator, request: c.DirectRecord.Request, policy: Policy) !c.DirectRecord.Result {
    try self.requireInitialized();
    try request.validate();
    const scope = request.scope();
    if (!scope.connection.matches(self.config()) or scope.connection.principal != policy.subject.principal()) return error.CatalogDenied;
    const current = try self.guard(allocator, policy, null, null, .database);
    try check(current);
    const format = switch (request) {
        inline .stage, .read => |value| value.format,
    };
    // The cut is server-owned evidence. Generic caller records only check
    // CONNECT and cannot bypass its complete current Table disclosure checks.
    if (format == c.DirectBranch.format) return error.BranchOperationRequired;
    if (format == c.DirectTransaction.Acquired.format or c.DirectTransactionWorkspace.reserved(format)) return error.TransactionOperationRequired;
    const result: c.DirectRecord.Result = switch (request) {
        .stage => |value| blk: {
            const bytes = try value.bytes.decode(allocator, c.DirectRecord.max_bytes);
            defer allocator.free(bytes);
            try check(current);
            break :blk .{ .reference = try c.DirectRecord.store(self.data_objects, scope, value.format, bytes), .bytes = null };
        },
        .read => |value| blk: {
            const bytes = try c.DirectRecord.load(allocator, self.data_objects, value);
            defer allocator.free(bytes);
            break :blk .{ .reference = value, .bytes = try c.DirectTableProtocol.Binary.encode(allocator, bytes) };
        },
    };
    try check(current);
    return result;
}

fn intentGuard(self: *Self, allocator: std.mem.Allocator, reference: c.DirectIntent.Reference, policy: Policy) !P.Guard {
    try reference.validate();
    return switch (reference) {
        .branch => |value| self.branchGuard(allocator, value, policy, false),
        .transaction, .transaction_call => self.guard(allocator, policy, null, null, .database),
        .external => self.guard(allocator, policy, null, null, .database),
        .table => |value| self.operationGuard(allocator, value.binding, value.namespace, policy),
        .log => |value| blk: {
            var intent = try c.DirectLogIntent.load(allocator, self.data_objects, value);
            defer intent.deinit();
            const request = try intent.parsed.value.work.request(allocator);
            break :blk try self.logGuard(allocator, request, policy, true, true);
        },
        .namespace_change => |value| self.namespaceGuard(allocator, value.binding, policy),
        .name_assertion => |value| policy.make_guard(policy.context, allocator, try self.assertionRequirements(allocator, value, policy), null),
    };
}

/// Atomically selects the first complete direct intent for a caller token.
/// This neither admits nor executes that intent. Even an exact retry rechecks
/// the original target's current rights before disclosing its reference.
pub fn requireClientLease(self: *Self, lease: c.DirectClientToken.Lease, policy: Policy) !void {
    try self.requireInitialized();
    if (lease.key.connection.principal != policy.subject.principal()) return error.CatalogDenied;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const current = try self.guard(arena.allocator(), policy, null, null, .database);
    try check(current);
    const state = (try self.store.clientTokenState(lease.key)) orelse return error.StaleClientLease;
    if (!std.meta.eql(state.revision, lease.revision)) return error.StaleClientLease;
    try check(current);
}

pub fn clientToken(self: *Self, request: c.DirectClientToken.Request, policy: Policy) !?c.DirectClientToken.Receipt {
    return self.clientTokenSelected(request, policy, false);
}
fn clientTokenSelected(self: *Self, request: c.DirectClientToken.Request, policy: Policy, server_selection: bool) !?c.DirectClientToken.Receipt {
    try self.requireInitialized();
    try request.validate();
    const key = request.key();
    if (!key.connection.matches(self.config()) or key.connection.principal != policy.subject.principal()) return error.CatalogDenied;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const database = try self.guard(arena.allocator(), policy, null, null, .database);
    try check(database);
    if (try self.store.clientToken(key)) |receipt| {
        const reference = receipt.binding.intent;
        const current = try self.intentGuard(arena.allocator(), reference, policy);
        try check(current);
        if (request == .bind) try receipt.binding.retry(request.bind);
        try check(current);
        return receipt;
    }
    if (request == .lookup) {
        try check(database);
        return null;
    }
    const binding = request.bind;
    const reference = binding.intent;
    const current = if (reference == .branch) try self.branchGuard(arena.allocator(), reference.branch, policy, true) else try self.intentGuard(arena.allocator(), reference, policy);
    try check(current);
    if (self.store.root.client_token_count >= self.options.client_token_quota) return error.ClientTokenCapacity;
    const usage = (try self.store.clientUsage(self.store.root, key)) orelse c.DirectClientToken.Usage.initial(binding.budget.limits);
    const coordination: ?u64 = if (reference == .transaction) self.store.root.next_partition else null;
    const receipt: c.DirectClientToken.Receipt = .{ .binding = binding, .position = .{ .partition = self.config().partition, .next_lsn = try std.math.add(u64, self.store.root.next_lsn, 1) }, .coordination = coordination };
    try receipt.validate();
    const reserved = try usage.transition(null, c.DirectClientToken.Progress.initial(receipt));
    if (reference == .transaction) try reserved.transactions.requireWithin(self.options.transaction_account_limits);
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
    defer self.store.index.end();
    // A token claims the complete original identity before accepting its
    // reference; this is independent of data admission and execution.
    switch (reference) {
        .branch => |value| {
            try self.prepareBranchAdmission(value, policy);
            try c.OperationBinding.claimBranchInTree(self.allocator, &self.store.index, value);
        },
        .transaction => |value| {
            if (value.begin.catalog.partition != self.config().partition or value.begin.catalog.next_lsn != self.store.root.next_lsn)
                return error.TransactionCatalogChanged;
            try c.DirectTransaction.inspectSelection(self.allocator, self.data_objects, value, self.options, server_selection);
            try check(current);
            try c.OperationBinding.claimTransactionInTree(self.allocator, &self.store.index, value, try key.digest());
        },
        .transaction_call => |value| {
            if (value.work == .statement) {
                const request_value = value.work.statement.request;
                var intent = try s.TableDmlIntent.load(self.allocator, self.data_objects, request_value.intent);
                defer intent.deinit();
                try request_value.binding.requireSame(intent.request.binding);
            }
            try c.OperationBinding.claimTransactionCallInTree(self.allocator, &self.store.index, value);
        },
        .external => |value| {
            const bytes = try c.DirectRecord.load(self.allocator, self.data_objects, value.record);
            defer self.allocator.free(bytes);
            try check(current);
            try c.OperationBinding.claimExternalInTree(self.allocator, &self.store.index, value);
        },
        .table => |table| {
            var intent = try c.DirectTableIntentStore.load(self.allocator, self.data_objects, table);
            defer intent.deinit();
            if (intent.parsed.value.work == .ddl) _ = try self.preview(try intent.parsed.value.work.ddl.native(arena.allocator(), self.config()), policy);
            try check(current);
            if (intent.parsed.value.work == .ddl) {
                try c.OperationBinding.claimInTree(self.allocator, &self.store.index, table.binding);
            } else {
                try c.OperationBinding.claim(self.allocator, self.data_objects, table.binding);
            }
        },
        .name_assertion => |value| try c.OperationBinding.claimAssertionInTree(self.allocator, &self.store.index, value),
        .log => |value| {
            var intent = try c.DirectLogIntent.load(self.allocator, self.data_objects, value);
            defer intent.deinit();
            _ = try self.previewLog(try intent.parsed.value.work.request(arena.allocator()), policy);
            try check(current);
            try c.OperationBinding.claimInTree(self.allocator, &self.store.index, value.binding);
        },
        .namespace_change => |value| try c.OperationBinding.claimNamespaceInTree(self.allocator, &self.store.index, value.binding),
    }
    var next = self.store.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    next.client_token_count = try std.math.add(u64, next.client_token_count, 1);
    if (coordination != null) next.next_partition = try std.math.add(u64, next.next_partition, 1);
    const state = c.DirectClientToken.Progress.initial(receipt);
    try self.store.clientIndices(&next, state);
    try self.store.publish(next, .{ .client_token = state }, current);
    try check(current);
    return receipt;
}

/// Paged recovery metadata never substitutes for the operation owner's result.
/// CAS updates and immutable payloads preserve exact retries across lost replies.
pub fn clientProgress(self: *Self, request: c.DirectClientToken.ProgressRequest, policy: Policy) !c.DirectClientToken.ProgressResult {
    try self.requireInitialized();
    try request.validate();
    const scope = request.scope();
    if (!scope.connection.matches(self.config()) or scope.connection.principal != policy.subject.principal()) return error.CatalogDenied;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const database = try self.guard(arena.allocator(), policy, null, null, .database);
    try check(database);
    if (request == .list) {
        const page = try self.store.clientPage(request.list);
        for (page.entries) |slot| if (slot) |state| try check(try self.intentGuard(arena.allocator(), state.receipt.binding.intent, policy));
        try check(database);
        return .{ .page = page };
    }
    var state = (switch (request) {
        .inspect => |key| try self.store.clientTokenState(key),
        .operation => |value| try self.store.clientOperation(value.scope, value.id),
        .update => |value| try self.store.clientTokenState(value.key),
        .list => unreachable,
    }) orelse {
        if (request == .update) return error.ClientOperationMissing;
        try check(database);
        return .{ .state = null };
    };
    const current = try self.intentGuard(arena.allocator(), state.receipt.binding.intent, policy);
    try check(current);
    if (request != .update) return .{ .state = state };
    // Transaction workspace, cancellation and settlement belong to the
    // transaction owner. Generic client bookkeeping cannot replace that state
    // or manufacture a cancellation request while the original attempt lives.
    if (state.receipt.binding.intent == .branch) return error.BranchOperationRequired;
    if (state.receipt.binding.intent == .transaction or state.receipt.binding.intent == .transaction_call) return error.TransactionOperationRequired;
    const value = request.update;
    if (state.pending == value.pending and state.cancel == value.cancel and std.meta.eql(state.record, value.record)) return .{ .state = state };
    if (!std.meta.eql(state.revision, value.expected)) return error.ClientOperationConflict;
    if ((!state.pending and value.pending) or (state.cancel and !value.cancel)) return error.ClientOperationConflict;
    if (!value.pending) try self.requireClientTerminal(state.receipt.binding.intent, policy);
    if (value.record) |reference| {
        const bytes = try c.DirectRecord.load(self.allocator, self.data_objects, reference);
        defer self.allocator.free(bytes);
    }
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
    defer self.store.index.end();
    var next = self.store.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    state.revision = .{ .partition = self.config().partition, .next_lsn = next.next_lsn };
    state.pending = value.pending;
    state.cancel = value.cancel;
    state.record = value.record;
    try state.validate();
    try self.store.clientIndices(&next, state);
    try self.store.publish(next, .{ .client_token = state }, current);
    try check(current);
    return .{ .state = state };
}
fn requireClientTerminal(self: *Self, reference: c.DirectIntent.Reference, policy: Policy) anyerror!void {
    switch (reference) {
        .branch => return error.BranchOperationRequired,
        .transaction => return error.ClientOperationPending,
        .transaction_call => return error.TransactionOperationRequired,
        // External owners interpret their own progress. No external completion
        // or authorization is inferred from removing a recovery index entry.
        .external => {},
        .table => |value| switch (value.binding.action) {
            .create, .alter, .rename, .drop => switch (try self.status(value.binding, policy)) {
                .not_observed, .admitted => return error.ClientOperationPending,
                else => {},
            },
            .insert, .update, .delete => switch (try self.rowStatus(value.binding, policy)) {
                .not_observed, .admitted => return error.ClientOperationPending,
                else => {},
            },
        },
        .name_assertion => |value| if (try self.assertName(value, .inspect, policy) == .not_observed) return error.ClientOperationPending,
        .log => |value| switch (try self.logOperation(value.binding, .inspect, policy)) {
            .not_observed => return error.ClientOperationPending,
            .operation => |operation| if (operation.pending()) return error.ClientOperationPending,
        },
        .namespace_change => |value| switch (try self.namespaceOperation(value.binding, .inspect, policy)) {
            .not_observed => return error.ClientOperationPending,
            .operation => |operation| if (operation.phase == .admitted) return error.ClientOperationPending,
        },
    }
}

const CutFence = struct {
    underlying: P.Guard,
    epoch: *?P.Guard.Fence,

    fn guard(self: *CutFence) P.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
    fn acquire(context: *anyopaque) !P.Guard.Fence {
        const self: *CutFence = @ptrCast(@alignCast(context));
        const fence = try self.underlying.acquire(self.underlying.context);
        errdefer self.underlying.release(self.underlying.context);
        if (self.epoch.*) |accepted_fence| {
            if (!std.meta.eql(accepted_fence, fence)) return error.TransactionAuthorityChanged;
        } else self.epoch.* = fence;
        return fence;
    }
    fn release(context: *anyopaque) void {
        const self: *CutFence = @ptrCast(@alignCast(context));
        self.underlying.release(self.underlying.context);
    }
};

fn transactionTableGuard(root: P.Root) p.Transaction.StateGuard {
    return .{ .source = .{ .interpretation = root.interpretation, .accepted = .{ .partition = root.partition, .next_lsn = root.next_lsn } }, .changed_lsn = root.changed_lsn };
}

fn transactionWriteAccess(action: @FieldType(d.Binding, "action")) !a.Access {
    return switch (action) {
        .insert => .insert,
        .update => .update,
        .delete => .delete,
        else => error.InvalidTransactionWorkspace,
    };
}

fn transactionStateGuard(self: *Self, allocator: std.mem.Allocator, view: *const View, access: a.Access, prerequisite: ?p.Authorization.Guard, policy: Policy) !P.Guard {
    const namespace = try self.authorizationSchema(view.properties.namespace);
    const target = view.properties.target(view.table.root.interpretation.object.object);
    const required = if (view.table.root.kind == .kv)
        try self.kvRequirements(policy, namespace, target, switch (access) {
            .read => .read,
            .insert => .write,
            else => return error.InvalidKVOperation,
        })
    else
        try self.requirements(policy, namespace, target, access);
    return policy.make_guard(policy.context, allocator, required, prerequisite);
}

fn transactionSnapshotAccess(self: *Self, allocator: std.mem.Allocator, object: d.Object, owner: d.Operation, policy: Policy) !SnapshotAccess {
    try owner.validate();
    if (!std.meta.eql(owner.scope, object.scope) or owner.principal != policy.subject.principal()) return error.CatalogDenied;
    var view = try self.transactionView(object);
    errdefer view.deinit();
    const current = try self.transactionStateGuard(allocator, &view, .read, null, policy);
    try check(current);
    if (view.table.root.next_lsn == 0) return error.CatalogRegistrationRequired;
    return .{ .view = view, .current = current };
}

/// The host must exclude all catalog/Table publication throughout this call,
/// including transaction decisions. Individual policy guards need not nest:
/// their epochs must agree with the guard held through the final catalog append.
/// A crash can leave original pins but cannot publish a partial common cut.
pub fn acquireTransaction(self: *Self, key: c.DirectClientToken.Key, policy: Policy) !c.DirectTransaction.Acquired {
    try self.requireInitialized();
    try key.validate();
    if (!key.connection.matches(self.config()) or key.connection.principal != policy.subject.principal()) return error.CatalogDenied;
    const state = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (state.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    var memory: c.fuze.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(state.receipt.binding.intent.transaction.begin.limits.resident_bytes) };
    const parent = self.allocator;
    const retained = self.options.table_owner;
    // Transaction Table owners belong to this temporary budget. Borrowing a
    // resident owner would bypass it; retaining a new one would outlive it.
    self.options.table_owner = null;
    self.allocator = memory.allocator();
    defer {
        self.allocator = parent;
        self.options.table_owner = retained;
        std.debug.assert(memory.used == 0);
    }
    return self.acquireTransactionBounded(state, policy) catch |err| {
        return if (err == error.OutOfMemory and memory.exhausted) error.TransactionMemoryLimit else err;
    };
}

fn acquireTransactionBounded(self: *Self, admitted: c.DirectClientToken.Progress, policy: Policy) !c.DirectTransaction.Acquired {
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    var epoch: ?P.Guard.Fence = null;
    var state = admitted;
    const begin = state.receipt.binding.intent.transaction.begin;
    var selected = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .participants, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
    defer selected.deinit();
    try selected.restore(begin.objects);
    var sources = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .sources, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
    defer sources.deinit();
    const previous = if (state.record != null) try c.DirectTransaction.Acquired.load(self.allocator, self.data_objects, state) else null;
    if (previous) |acquired| try sources.restore(acquired.cut.sources);
    var count: u64 = 0;
    var after: ?s.TransactionDirectory.Cursor = null;
    while (true) {
        const page = try selected.page(after);
        for (page.entries) |slot| if (slot) |entry_value| {
            _ = scratch.reset(.retain_capacity);
            const participant = entry_value.participant;
            if (participant == .log) {
                try self.acquireTransactionLog(&sources, begin, participant, previous != null, policy, &epoch, scratch.allocator());
                count = try std.math.add(u64, count, 1);
                if (count > begin.objects.count) return error.InvalidTransactionDirectory;
                continue;
            }
            try participant.requireLocalState(begin);
            if (participant.state.access != .read) return error.InvalidTransactionBegin;
            const expected = participant.state.guard.source;
            var access = try self.transactionSnapshotAccess(scratch.allocator(), expected.interpretation.object, begin.identity.begin, policy);
            defer access.view.deinit();
            if (!std.meta.eql(entry_value.target(), s.TableTransaction.target(access.view.table.root))) return error.TransactionIdentityConflict;
            var checked: CutFence = .{ .underlying = access.current, .epoch = &epoch };
            const guard_value = checked.guard();
            const pin_state = try access.view.table.pinState(begin.identity.begin, guard_value);
            const pin = if (pin_state.handle) |retained| blk: {
                if (pin_state.released) return error.TableSnapshotReleased;
                break :blk retained;
            } else blk: {
                if (previous != null) return error.TableSnapshotNotPinned;
                if (access.view.table.root.retired or !std.meta.eql(expected.interpretation, access.view.table.root.interpretation) or expected.accepted.partition != access.view.table.root.partition) return error.TransactionConflict;
                access.view.table.lose_reply = self.lose_table_reply;
                break :blk try access.view.table.pin(begin.identity.begin, pin_state.position, guard_value);
            };
            var frozen = try access.view.table.inspectSnapshot(self.allocator, pin, guard_value);
            defer frozen.deinit();
            const basis = transactionTableGuard(frozen.root);
            if (!std.meta.eql(expected.interpretation, basis.source.interpretation) or expected.accepted.partition != basis.source.accepted.partition) return error.TransactionConflict;
            if (previous == null) {
                // Pins recovered after a lost acquisition reply are not moved
                // forward. All old logical/definition bases must still agree.
                if (access.view.table.root.retired) return error.TransactionConflict;
                try basis.requireUnchanged(transactionTableGuard(access.view.table.root));
                try sources.put(.{ .source = .{ .guard = .{ .state = .{ .kind = participant.state.kind, .basis = basis } }, .pin = pin } });
            } else {
                const source = (try sources.get(entry_value.target()) orelse return error.IncompleteTransactionCut).source;
                if (!std.meta.eql((try source.guard.requirePagedState()), basis) or !std.meta.eql(source.pin, pin)) return error.InvalidTransactionCut;
            }
            count = try std.math.add(u64, count, 1);
            if (count > begin.objects.count) return error.InvalidTransactionDirectory;
        };
        after = page.next orelse break;
    }
    if (count != begin.objects.count or sources.root.count != count) return error.IncompleteTransactionCut;
    _ = scratch.reset(.retain_capacity);
    var publication: CutFence = .{ .underlying = try self.guard(scratch.allocator(), policy, null, null, .database), .epoch = &epoch };
    if (previous) |acquired| {
        try check(publication.guard());
        return acquired;
    }
    if (!state.pending or state.cancel) return error.InvalidTransactionCut;
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
    defer self.store.index.end();
    var next = self.store.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    state.revision = .{ .partition = self.config().partition, .next_lsn = next.next_lsn };
    const acquired: c.DirectTransaction.Acquired = .{ .definition = p.Growth.current_definition, .cut = .{ .begin = begin, .sources = try sources.seal(), .acquired = state.revision }, .coordination = state.receipt.coordination.? };
    state.record = try acquired.stage(self.data_objects, state.receipt);
    try state.validate();
    try self.store.clientIndices(&next, state);
    try self.store.publish(next, .{ .client_token = state }, publication.guard());
    try check(publication.guard());
    return acquired;
}

fn acquireTransactionLog(self: *Self, sources: *s.TransactionDirectory, begin: p.Transaction.Begin, participant: p.Transaction.Participant, acquired: bool, policy: Policy, epoch: *?P.Guard.Fence, scratch: std.mem.Allocator) !void {
    try participant.validate(begin.identity);
    if (participant.log.actions != null) return error.InvalidTransactionBegin;
    const expected = participant.log.guard;
    const authorized = try self.logAuthorization(scratch, switch (expected.kind) {
        .stream => .stream,
        .queue => .queue,
    }, expected.source.target, .read, policy);
    var checked: CutFence = .{ .underlying = authorized.guard, .epoch = epoch };
    const guard_value = checked.guard();
    var view = try self.transactionLogView(authorized.definition, expected.source.target.partition, guard_value);
    defer view.deinit();
    const current = view.root();
    const pin_state = try view.pinState(begin.identity.begin, guard_value);
    const pin = if (pin_state.handle) |retained| blk: {
        if (pin_state.released) return error.LogTransactionSourceReleased;
        break :blk retained;
    } else blk: {
        if (acquired) return error.LogTransactionSourceNotPinned;
        if (!std.meta.eql(expected.source.target, (try view.basis()).source.target) or expected.source.accepted.partition != current.initialization.partition) return error.TransactionConflict;
        break :blk try view.pin(begin.identity, pin_state.position, guard_value);
    };
    const frozen = try view.inspect(pin, guard_value);
    const basis = try frozen.guard();
    if (!std.meta.eql(frozen.identity, begin.identity) or expected.kind != basis.kind or !std.meta.eql(expected.source.target, basis.source.target) or expected.source.accepted.partition != basis.source.accepted.partition) return error.TransactionConflict;
    if (!acquired) {
        // A partial acquisition retries its original pins only while all logical
        // frontiers still agree. A published cut may outlive later changes.
        try basis.requireUnchanged(try view.basis());
        try sources.put(.{ .source = .{ .guard = .{ .log = basis }, .pin = pin } });
    } else {
        const source = (try sources.get(participant.guard().target()) orelse return error.IncompleteTransactionCut).source;
        if (source.guard != .log or !std.meta.eql(source.guard.log, basis) or !std.meta.eql(source.pin, pin)) return error.InvalidTransactionCut;
    }
}

const TransactionPolicy = struct {
    original: Policy,
    epoch: ?P.Guard.Fence = null,
    fn policy(self: *@This()) Policy {
        return .{ .context = self, .subject = self.original.subject, .make_guard = make, .registered = registered, .native_resource = self.original.native_resource };
    }
    fn make(raw: *anyopaque, allocator: std.mem.Allocator, request: p.Authorization.Guard, prerequisite: ?p.Authorization.Guard) !P.Guard {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const fence = try allocator.create(CutFence);
        fence.* = .{ .underlying = try self.original.make_guard(self.original.context, allocator, request, prerequisite), .epoch = &self.epoch };
        return fence.guard();
    }
    fn registered(raw: *anyopaque, kind: a.Kind, id: u64) !?p.Authorization.Object {
        const self: *@This() = @ptrCast(@alignCast(raw));
        return self.original.registered(self.original.context, kind, id);
    }
};

/// Server-owned discovery freezes either exact selected IDs or the complete
/// currently SELECT-authorized catalog Table set. The host excludes all database
/// publication until admission completes; current-policy epochs must agree.
pub fn beginTransaction(self: *Self, request: c.DirectTransactionRequest.Begin, policy: Policy) !c.DirectClientToken.Receipt {
    try request.validate();
    if (try self.clientToken(.{ .lookup = request.key }, policy)) |receipt| {
        if (receipt.binding.intent != .transaction or !std.mem.eql(u8, &receipt.binding.fingerprint, &request.fingerprint)) return error.ClientTokenConflict;
        return receipt;
    }
    try c.DirectTransaction.requireLimits(request.limits, self.options.transaction_limits);
    var memory: c.fuze.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(request.limits.resident_bytes) };
    const parent = self.allocator;
    const retained = self.options.table_owner;
    self.options.table_owner = null;
    self.allocator = memory.allocator();
    defer {
        self.allocator = parent;
        self.options.table_owner = retained;
        std.debug.assert(memory.used == 0);
    }
    return self.beginTransactionBounded(request, policy) catch |err| return if (err == error.OutOfMemory and memory.exhausted) error.TransactionMemoryLimit else err;
}

fn beginTransactionBounded(self: *Self, request: c.DirectTransactionRequest.Begin, original_policy: Policy) !c.DirectClientToken.Receipt {
    var checked: TransactionPolicy = .{ .original = original_policy };
    const policy = checked.policy();
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    try check(try self.guard(scratch.allocator(), policy, try self.schema(request.namespace), null, .schema));
    const identity: p.Transaction.Identity = .{ .begin = request.operation, .branch = request.key.connection.branch };
    var selected = try s.TransactionDirectory.init(self.allocator, self.data_objects, identity, .participants, request.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
    defer selected.deinit();
    switch (request.selection) {
        .explicit_objects => |objects| for (objects) |object| {
            _ = scratch.reset(.retain_capacity);
            switch (object.kind) {
                .table, .kv => {
                    const target = try self.entry(object.object.object) orelse return error.CatalogDenied;
                    if (target.resource != null or target.log != null) return error.UnsupportedTransactionParticipant;
                    if (target.seed) |seed| if ((seed.kind == .kv) != (object.kind == .kv)) return error.CatalogKindMismatch;
                    if (!try self.selectTransactionTable(&selected, target, policy, scratch.allocator(), false)) return error.CatalogDenied;
                },
                .stream, .queue => {
                    const known = try self.logRecord(object.object.object) orelse return error.CatalogDenied;
                    if (known.phase != .complete) return error.LogDeclarationConflict;
                    const definition = known.resulting.?;
                    const authorization = try self.logAuthorization(scratch.allocator(), if (object.kind == .stream) .stream else .queue, .{ .definition = p.Growth.current_definition, .interpretation = definition.stored.declaration.interpretation, .partition = object.partition.? }, .read, policy);
                    var view = try self.transactionLogView(authorization.definition, object.partition.?, authorization.guard);
                    defer view.deinit();
                    try selected.put(.{ .participant = .{ .log = .{ .guard = try view.basis(), .actions = null } } });
                },
                .document => return error.UnsupportedTransactionParticipant,
            }
        },
        .authorized_catalog_tables => {
            var cursor: ?pages.Key = null;
            while (true) {
                const page = try self.store.tree().scan(self.store.root.objects, cursor);
                for (page.entries) |slot| if (slot) |item| {
                    _ = scratch.reset(.retain_capacity);
                    const target = try r.fromValue(r.Entry, self.allocator, item.value);
                    try target.validate(self.config());
                    if (!std.meta.eql(item.key, try r.idKey(target.object))) return error.InvalidDirectCatalogEntry;
                    if (target.resource != null or target.log != null) continue;
                    _ = try self.selectTransactionTable(&selected, target, policy, scratch.allocator(), true);
                };
                cursor = page.next orelse break;
            }
        },
    }
    const begin: p.Transaction.Begin = .{ .definition = p.Growth.current_definition, .identity = identity, .mode = request.mode, .selection = if (request.selection == .explicit_objects) .explicit_objects else .authorized_catalog_tables, .objects = try selected.seal(), .catalog = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn }, .limits = request.limits };
    const binding: c.DirectClientToken.Binding = .{ .key = request.key, .fingerprint = request.fingerprint, .budget = request.budget, .intent = .{ .transaction = .{ .connection = request.key.connection, .namespace = request.namespace, .begin = begin } } };
    return (try self.clientTokenSelected(.{ .bind = binding }, policy, true)).?;
}

fn selectTransactionTable(self: *Self, selected: *s.TransactionDirectory, target: r.Entry, policy: Policy, scratch: std.mem.Allocator, filter: bool) !bool {
    if (target.seed == null) return false;
    if (filter and target.seed.?.kind != .table) return false;
    var view = try self.openTransaction(self.allocator, target, false, true);
    defer view.deinit();
    if (view.table.root.next_lsn == 0 or view.table.root.retired) return false;
    const current = try self.transactionStateGuard(scratch, &view, .read, null, policy);
    check(current) catch |err| {
        if (filter and (err == error.CatalogDenied or err == error.Forbidden)) return false;
        return err;
    };
    if (view.table.root.transaction != null) return error.TransactionPrepared;
    try selected.put(.{ .participant = .{ .state = .{ .kind = if (view.table.root.kind == .kv) .kv else .table, .access = .read, .guard = transactionTableGuard(view.table.root) } } });
    return true;
}

const TransactionWorkspace = c.DirectTransactionWorkspace;
const TransactionStateWork = union(enum) { table: c.DirectTableIntent.Work, kv: c.DirectKV.Mutation };

/// Stage exact native DML for a private statement. Staging creates no admission,
/// consumes no sequence and grants no permission to publish Table data.
pub fn stageTransactionStatement(self: *Self, key: c.DirectClientToken.Key, basis: p.DataLifecycle.Position, sequence: u64, work: c.DirectTableIntent.Work, policy: Policy) !c.DirectTransactionWorkspace.Request {
    return self.stageTransactionStateWork(key, basis, sequence, .{ .table = work }, policy);
}

pub fn stageTransactionKV(self: *Self, key: c.DirectClientToken.Key, basis: d.Position, sequence: u64, work: c.DirectKV.Mutation, policy: Policy) !TransactionWorkspace.Request {
    return self.stageTransactionStateWork(key, basis, sequence, .{ .kv = work }, policy);
}

fn stageTransactionStateWork(self: *Self, key: c.DirectClientToken.Key, basis: d.Position, sequence: u64, work: TransactionStateWork, policy: Policy) !TransactionWorkspace.Request {
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    const head = try TransactionWorkspace.recover(self.allocator, self.data_objects, progress);
    if (head.acquired.cut.begin.mode == .read_only) return error.ReadOnlyTransaction;
    if ((work == .table and work.table == .ddl) or sequence == 0 or sequence > head.acquired.cut.begin.limits.statements) return error.InvalidTransactionWork;
    if (head.pending_control != null) return error.TransactionControlPending;
    if (head.pending != null) return error.TransactionStatementPending;
    if (sequence != head.last_statement + 1) return error.TransactionStatementConflict;
    if (!std.meta.eql(basis, head.revision)) return error.TransactionReadChanged;
    var memory: c.fuze.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(head.acquired.cut.begin.limits.resident_bytes) };
    const parent = self.allocator;
    const retained = self.options.table_owner;
    self.options.table_owner = null;
    self.allocator = memory.allocator();
    defer {
        self.allocator = parent;
        self.options.table_owner = retained;
        std.debug.assert(memory.used == 0);
    }
    return self.stageTransactionStatementBounded(progress, head, sequence, work, policy) catch |err| return if (err == error.OutOfMemory and memory.exhausted) error.TransactionMemoryLimit else err;
}

fn stageTransactionStatementBounded(self: *Self, progress: c.DirectClientToken.Progress, head: TransactionWorkspace.Head, sequence: u64, work: TransactionStateWork, policy: Policy) !TransactionWorkspace.Request {
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    const binding = switch (work) {
        .table => |value| value.binding(),
        .kv => |value| value.binding,
    };
    try progress.receipt.binding.key.connection.binding(binding);
    const state = try self.transactionTableStateBounded(progress, binding.target, policy);
    if ((state.root.kind == .kv) != (work == .kv)) return error.CatalogKindMismatch;
    var declaration = try s.TableDeclaration.load(scratch.allocator(), self.data_objects, state.root.declared());
    defer declaration.deinit();
    const native: s.TableDmlIntent.Request = switch (work) {
        .table => |value| switch (value) {
            .ddl => unreachable,
            inline .rows, .statement => |v| try v.native(scratch.allocator()),
        },
        .kv => |value| blk: {
            try value.validate(scratch.allocator());
            const spec = (try s.KVDeclaration.fromPhysical(declaration.definition)).spec;
            const changes = try value.decodeChanges(scratch.allocator(), spec);
            break :blk .{ .binding = binding, .interpretation = state.root.declared(), .changes = try s.KVPartition.lower(scratch.allocator(), declaration.schema.schema, binding, changes), .ingestion = .bulk };
        },
    };
    if (native.ingestion != .bulk) return error.InvalidTransactionWorkspace;
    if (!std.meta.eql(native.interpretation, state.root.declared())) return error.TableDefinitionChanged;
    var view = try self.transactionView(binding.target);
    defer view.deinit();
    try self.original(policy, binding);
    const current = try self.transactionStateGuard(scratch.allocator(), &view, try transactionWriteAccess(binding.action), binding.prerequisite, policy);
    try check(current);
    var staging: TransactionWorkspace.Staging = .{ .underlying = self.data_objects, .used = head.charged_bytes, .limit = head.acquired.cut.begin.limits.workspace_bytes };
    const result: TransactionWorkspace.Request = .{ .basis = head.revision, .statement = .{ .transaction = head.acquired.cut.begin.identity, .sequence = sequence, .intent = native.binding.intent }, .binding = native.binding, .intent = try s.TableDmlIntent.stage(scratch.allocator(), staging.objects(), native) };
    try result.validate();
    try check(current);
    return result;
}

/// The embedding host excludes all database publication for the entire call.
/// This freezes the original statement before private evaluation. A returned
/// null means the statement remains pending, never rejected or committed.
pub fn admitTransactionStatement(self: *Self, key: c.DirectClientToken.Key, request: TransactionWorkspace.Request, policy: Policy) !?s.TableWorkspace.Outcome {
    return self.transactionStatementWork(key, request, policy, false);
}

/// Resume exactly the admitted statement, or return its original provisional
/// outcome. Neither path appends Table data or decides the transaction.
pub fn executeTransactionStatement(self: *Self, key: c.DirectClientToken.Key, request: TransactionWorkspace.Request, policy: Policy) !s.TableWorkspace.Outcome {
    if (try self.transactionStatementWork(key, request, policy, false)) |outcome| return outcome;
    return (try self.transactionStatementWork(key, request, policy, true)).?;
}

fn transactionStatementWork(self: *Self, key: c.DirectClientToken.Key, request: TransactionWorkspace.Request, policy: Policy, evaluate: bool) !?s.TableWorkspace.Outcome {
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    var memory: c.fuze.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(progress.receipt.binding.intent.transaction.begin.limits.resident_bytes) };
    const parent = self.allocator;
    const retained = self.options.table_owner;
    // Transaction Table owners belong to this temporary budget. Borrowing a
    // resident owner would bypass it; retaining a new one would outlive it.
    self.options.table_owner = null;
    self.allocator = memory.allocator();
    defer {
        self.allocator = parent;
        self.options.table_owner = retained;
        std.debug.assert(memory.used == 0);
    }
    return self.transactionStatementBounded(progress, request, policy, evaluate) catch |err|
        return if (err == error.OutOfMemory and memory.exhausted) error.TransactionMemoryLimit else err;
}

fn transactionStatementBounded(self: *Self, progress: c.DirectClientToken.Progress, request: TransactionWorkspace.Request, policy: Policy, evaluate: bool) !?s.TableWorkspace.Outcome {
    var head = try TransactionWorkspace.recover(self.allocator, self.data_objects, progress);
    const begin = head.acquired.cut.begin;
    try request.validate();
    if (!std.meta.eql(request.statement.transaction, begin.identity)) return error.TransactionIdentityConflict;
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    var access = try self.transactionSnapshotAccess(scratch.allocator(), request.binding.target, begin.identity.begin, policy);
    defer access.view.deinit();
    var epoch: ?P.Guard.Fence = null;
    var read_fence: CutFence = .{ .underlying = access.current, .epoch = &epoch };
    try check(read_fence.guard());
    try self.original(policy, request.binding);
    var write_fence: CutFence = .{ .underlying = try self.transactionStateGuard(scratch.allocator(), &access.view, try transactionWriteAccess(request.binding.action), request.binding.prerequisite, policy), .epoch = &epoch };
    try check(write_fence.guard());
    // Scope and live original pins are checked before returning an old result.
    var sources = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .sources, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
    defer sources.deinit();
    try sources.restore(head.acquired.cut.sources);
    const source = (try sources.get(s.TableTransaction.target(access.view.table.root)) orelse return error.TransactionObjectNotSelected).source;
    var frozen = try access.view.table.inspectSnapshot(self.allocator, source.pin, read_fence.guard());
    defer frozen.deinit();
    if (!std.meta.eql((try source.guard.requirePagedState()), transactionTableGuard(frozen.root))) return error.InvalidTransactionCut;
    var staging: TransactionWorkspace.Staging = .{ .underlying = self.data_objects, .used = head.charged_bytes, .limit = begin.limits.workspace_bytes };
    var index = try s.TreeStore.init(self.allocator, staging.objects(), self.options.resident_pages);
    defer index.deinit();
    const record_scope = progress.receipt.binding.key.scope();
    if (try TransactionWorkspace.get(TransactionWorkspace.StatementCompletion, self.allocator, &index, head.statements, request.statement.sequence, record_scope, TransactionWorkspace.statement_format)) |stored| {
        try stored.validate();
        if (stored != .state) return error.TransactionStatementConflict;
        const completed = stored.state;
        if (!std.meta.eql(request, completed.request)) return error.TransactionStatementConflict;
        try check(read_fence.guard());
        try check(write_fence.guard());
        return completed.outcome;
    }
    if (begin.mode == .read_only) return error.ReadOnlyTransaction;
    if (request.statement.sequence > begin.limits.statements) return error.TransactionStatementLimit;
    if (head.pending_control != null) return error.TransactionControlPending;
    if (head.pending) |pending_statement| {
        if (pending_statement != .state or !std.meta.eql(pending_statement.state, request)) return error.TransactionStatementPending;
        if (!evaluate) return null;
    } else {
        if (evaluate or request.statement.sequence != head.last_statement + 1) return error.TransactionStatementConflict;
        if (!std.meta.eql(request.basis, head.revision)) return error.TransactionReadChanged;
    }
    var intent = try s.TableDmlIntent.load(self.allocator, self.data_objects, request.intent);
    defer intent.deinit();
    try request.binding.requireSame(intent.request.binding);
    if (intent.request.ingestion != .bulk or !std.meta.eql(intent.request.interpretation, frozen.root.declared())) return error.InvalidTransactionWorkspace;
    // A durable claim prevents this private operation from later being admitted
    // as autocommit, including when the following catalog reply is lost.
    if (!evaluate) {
        staging.used = try std.math.add(u64, staging.used, request.intent.bytes);
        if (staging.used > staging.limit) return error.TransactionWorkspaceLimit;
        try c.OperationBinding.claimTransactionStatement(self.allocator, self.data_objects, request);
        head.pending = .{ .state = request };
        head.last_statement = request.statement.sequence;
        try self.publishTransactionWorkspace(progress, &head, &staging, write_fence.guard());
        try check(read_fence.guard());
        return null;
    }
    const previous = try TransactionWorkspace.get(s.TableWorkspace.State, self.allocator, &index, head.tables, request.binding.target.object, record_scope, TransactionWorkspace.table_format);
    access.view.table.objects = staging.objects();
    var evaluator = try s.TableWorkspace.init(self.allocator, &access.view.table, begin, source.pin, previous, read_fence.guard());
    defer evaluator.deinit();
    const outcome = try evaluator.execute(request.statement, intent.request, write_fence.guard());
    const next_table = evaluator.state();
    try next_table.validate();
    const table_record = try TransactionWorkspace.stage(staging.objects(), record_scope, TransactionWorkspace.table_format, next_table);
    head.tables = try TransactionWorkspace.put(&index, head.tables, request.binding.target.object, table_record, self.options.index_work_bytes);
    const completed: TransactionWorkspace.StatementCompletion = .{ .state = .{ .request = request, .outcome = outcome } };
    try completed.validate();
    const result_record = try TransactionWorkspace.stage(staging.objects(), record_scope, TransactionWorkspace.statement_format, completed);
    head.statements = try TransactionWorkspace.put(&index, head.statements, request.statement.sequence, result_record, self.options.index_work_bytes);
    head.pending = null;
    try check(read_fence.guard());
    try self.publishTransactionWorkspace(progress, &head, &staging, write_fence.guard());
    try check(read_fence.guard());
    return outcome;
}

const TransactionLogWork = c.DirectTransactionLogWork;

const TransactionTransferAccess = struct {
    definition: L.Definition,
    read: CutFence,
    write: CutFence,
    fn checkCurrent(self: *@This()) !void {
        try check(self.read.guard());
        try check(self.write.guard());
    }
};
fn transactionTransferAccess(self: *Self, scratch: std.mem.Allocator, work: TransactionLogWork.Work, policy: Policy, epoch: *?P.Guard.Fence) !?TransactionTransferAccess {
    if (work != .queue_transfer) return null;
    const target = work.queue_transfer.destination.target;
    const read = try self.logAuthorization(scratch, .queue, target, .read, policy);
    const write = try self.logAuthorization(scratch, .queue, target, .append, policy);
    var result: TransactionTransferAccess = .{ .definition = read.definition, .read = .{ .underlying = read.guard, .epoch = epoch }, .write = .{ .underlying = write.guard, .epoch = epoch } };
    try result.checkCurrent();
    return result;
}
fn transactionTransferSource(sources: *s.TransactionDirectory, work: TransactionLogWork.Work) !@FieldType(s.TransactionDirectory.Entry, "source") {
    const target = work.queue_transfer.destination.target;
    const source = (try sources.get(.{ .object = target.interpretation.object, .kind = .queue, .partition = target.partition }) orelse return error.TransactionObjectNotSelected).source;
    if (source.guard != .log) return error.InvalidTransactionCut;
    try target.requireSame(source.guard.log.source.target);
    return source;
}
const TransactionLogSource = @FieldType(s.TransactionDirectory.Entry, "source");
const TransactionLogSources = struct { source: TransactionLogSource, destination: ?TransactionLogSource };
fn transactionLogSources(self: *Self, begin: p.Transaction.Begin, reference: p.Transaction.Directory, work: TransactionLogWork.Work) !TransactionLogSources {
    var sources = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .sources, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
    defer sources.deinit();
    try sources.restore(reference);
    const target: p.Transaction.Target = .{ .object = work.target().interpretation.object, .kind = if (work.kind() == .stream) .stream else .queue, .partition = work.target().partition };
    const source = (try sources.get(target) orelse return error.TransactionObjectNotSelected).source;
    if (source.guard != .log) return error.InvalidTransactionCut;
    try work.target().requireSame(source.guard.log.source.target);
    // These fixed descriptors own no directory memory. Release its cache before
    // a temporary partition performs recovery or private evaluation.
    return .{ .source = source, .destination = if (work == .queue_transfer) try transactionTransferSource(&sources, work) else null };
}
fn validateTransactionTransfer(self: *Self, source: TransactionLogSource, access: *TransactionTransferAccess, work: TransactionLogWork.Work, payload: ?[]const u8, unchanged: bool) !void {
    var destination = try self.transactionLogView(access.definition, work.queue_transfer.destination.target.partition, access.read.guard());
    defer destination.deinit();
    const frozen = try destination.inspect(source.pin, access.read.guard());
    if (!std.meta.eql(try frozen.guard(), source.guard.log)) return error.InvalidTransactionCut;
    if (unchanged) try source.guard.log.requireUnchanged(try destination.basis());
    try destination.validatePayload(work, payload);
    try access.checkCurrent();
}

fn authenticateTransactionLog(self: *Self, work: TransactionLogWork.Work) !void {
    if (work == .stream_offset) {
        const environment = self.log_environment orelse return error.InvalidStreamReadAuthority;
        const authority = environment.authority orelse return error.InvalidStreamReadAuthority;
        try authority.verify(work.stream_offset.cursor);
    }
}

/// Stage an exact payload and source basis without accepting a statement or
/// reserving a public offset. The caller keeps this request for uncertain retry.
pub fn stageTransactionLog(self: *Self, key: c.DirectClientToken.Key, basis: d.Position, sequence: u64, work: TransactionLogWork.Work, payload: ?[]const u8, policy: Policy) !TransactionLogWork.Request {
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    var memory: c.fuze.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(progress.receipt.binding.intent.transaction.begin.limits.resident_bytes) };
    const parent = self.allocator;
    self.allocator = memory.allocator();
    defer {
        self.allocator = parent;
        std.debug.assert(memory.used == 0);
    }
    return self.stageTransactionLogBounded(progress, basis, sequence, work, payload, policy) catch |err| return if (err == error.OutOfMemory and memory.exhausted) error.TransactionMemoryLimit else err;
}

fn stageTransactionLogBounded(self: *Self, progress: c.DirectClientToken.Progress, basis: d.Position, sequence: u64, work: TransactionLogWork.Work, payload: ?[]const u8, policy: Policy) !TransactionLogWork.Request {
    try work.validate();
    try self.authenticateTransactionLog(work);
    const head = try TransactionWorkspace.recover(self.allocator, self.data_objects, progress);
    const begin = head.acquired.cut.begin;
    if (begin.mode == .read_only) return error.ReadOnlyTransaction;
    if (sequence == 0 or sequence > begin.limits.statements) return error.TransactionStatementLimit;
    if (head.pending_control != null) return error.TransactionControlPending;
    if (head.pending != null) return error.TransactionStatementPending;
    if (sequence != head.last_statement + 1) return error.TransactionStatementConflict;
    if (!std.meta.eql(basis, head.revision)) return error.TransactionReadChanged;
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    const read = try self.logAuthorization(scratch.allocator(), work.kind(), work.target(), .read, policy);
    const write = try self.logAuthorization(scratch.allocator(), work.kind(), work.target(), work.access(), policy);
    var epoch: ?P.Guard.Fence = null;
    var read_fence: CutFence = .{ .underlying = read.guard, .epoch = &epoch };
    var write_fence: CutFence = .{ .underlying = write.guard, .epoch = &epoch };
    try check(read_fence.guard());
    try check(write_fence.guard());
    const selected = try self.transactionLogSources(begin, head.acquired.cut.sources, work);
    const source = selected.source;
    var transfer_access = try self.transactionTransferAccess(scratch.allocator(), work, policy, &epoch);
    const request: TransactionLogWork.Request = .{ .statement = .{ .transaction = begin.identity, .sequence = sequence, .intent = try work.digest() }, .basis = basis, .guard = source.guard.log, .work = work };
    try request.validate();
    var staging: TransactionWorkspace.Staging = .{ .underlying = self.data_objects, .used = head.charged_bytes, .limit = begin.limits.workspace_bytes };
    {
        var view = try self.transactionLogView(read.definition, work.target().partition, read_fence.guard());
        defer view.deinit();
        const frozen = try view.inspect(source.pin, read_fence.guard());
        if (!std.meta.eql(try frozen.guard(), source.guard.log)) return error.InvalidTransactionCut;
        try source.guard.log.requireUnchanged(try view.basis());
        if (work == .queue_transfer) try view.validateTransferPayload(work.queue_transfer, read_fence.guard()) else try view.validatePayload(work, payload);
    }
    if (transfer_access) |*access| try self.validateTransactionTransfer(selected.destination.?, access, work, payload, true);
    try TransactionLogWork.stagePayload(staging.objects(), work, payload);
    try check(read_fence.guard());
    try check(write_fence.guard());
    if (transfer_access) |*access| try access.checkCurrent();
    return request;
}

pub fn admitTransactionLog(self: *Self, key: c.DirectClientToken.Key, request: TransactionLogWork.Request, policy: Policy) !?TransactionLogWork.Outcome {
    return self.transactionLogStatement(key, request, policy, false);
}

pub fn executeTransactionLog(self: *Self, key: c.DirectClientToken.Key, request: TransactionLogWork.Request, policy: Policy) !TransactionLogWork.Outcome {
    if (try self.transactionLogStatement(key, request, policy, false)) |outcome| return outcome;
    return (try self.transactionLogStatement(key, request, policy, true)).?;
}

fn transactionLogStatement(self: *Self, key: c.DirectClientToken.Key, request: TransactionLogWork.Request, policy: Policy, evaluate: bool) !?TransactionLogWork.Outcome {
    try request.validate();
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    var memory: c.fuze.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(progress.receipt.binding.intent.transaction.begin.limits.resident_bytes) };
    const parent = self.allocator;
    self.allocator = memory.allocator();
    defer {
        self.allocator = parent;
        std.debug.assert(memory.used == 0);
    }
    return self.transactionLogStatementBounded(progress, request, policy, evaluate) catch |err| return if (err == error.OutOfMemory and memory.exhausted) error.TransactionMemoryLimit else err;
}

fn transactionLogStatementBounded(self: *Self, progress: c.DirectClientToken.Progress, request: TransactionLogWork.Request, policy: Policy, evaluate: bool) !?TransactionLogWork.Outcome {
    var head = try TransactionWorkspace.recover(self.allocator, self.data_objects, progress);
    const begin = head.acquired.cut.begin;
    if (!std.meta.eql(request.statement.transaction, begin.identity)) return error.TransactionIdentityConflict;
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    const read = try self.logAuthorization(scratch.allocator(), request.work.kind(), request.work.target(), .read, policy);
    const write = try self.logAuthorization(scratch.allocator(), request.work.kind(), request.work.target(), request.work.access(), policy);
    var epoch: ?P.Guard.Fence = null;
    var read_fence: CutFence = .{ .underlying = read.guard, .epoch = &epoch };
    var write_fence: CutFence = .{ .underlying = write.guard, .epoch = &epoch };
    try check(read_fence.guard());
    try check(write_fence.guard());
    var transfer_access = try self.transactionTransferAccess(scratch.allocator(), request.work, policy, &epoch);
    var staging: TransactionWorkspace.Staging = .{ .underlying = self.data_objects, .used = head.charged_bytes, .limit = begin.limits.workspace_bytes };
    var index = try s.TreeStore.init(self.allocator, staging.objects(), self.options.resident_pages);
    defer index.deinit();
    const scope_value = progress.receipt.binding.key.scope();
    // A completed private result is original evidence even if the current
    // public frontier has since advanced. Disclosure still needs current rights.
    if (try TransactionWorkspace.get(TransactionWorkspace.StatementCompletion, self.allocator, &index, head.statements, request.statement.sequence, scope_value, TransactionWorkspace.statement_format)) |stored| {
        try stored.validate();
        if (stored != .log or !std.meta.eql(request, stored.log.request)) return error.TransactionStatementConflict;
        try check(read_fence.guard());
        try check(write_fence.guard());
        if (transfer_access) |*access| try access.checkCurrent();
        return stored.log.outcome;
    }
    if (begin.mode == .read_only) return error.ReadOnlyTransaction;
    if (request.statement.sequence > begin.limits.statements) return error.TransactionStatementLimit;
    if (head.pending_control != null) return error.TransactionControlPending;
    if (head.pending) |pending_statement| {
        if (pending_statement != .log or !std.meta.eql(pending_statement.log, request)) return error.TransactionStatementPending;
        if (!evaluate) return null;
    } else {
        if (evaluate or request.statement.sequence != head.last_statement + 1) return error.TransactionStatementConflict;
        if (!std.meta.eql(request.basis, head.revision)) return error.TransactionReadChanged;
    }
    const selected = try self.transactionLogSources(begin, head.acquired.cut.sources, request.work);
    const target = (p.Transaction.Guard{ .log = request.guard }).target();
    const source = selected.source;
    if (source.guard != .log or !std.meta.eql(source.guard.log, request.guard)) return error.InvalidTransactionCut;
    // Every private owner write, including regenerated indexes and segments,
    // belongs to the same conservative workspace byte account.
    const objects = self.data_objects;
    self.data_objects = staging.objects();
    defer self.data_objects = objects;
    const payload = try TransactionLogWork.loadPayload(self.allocator, self.data_objects, request.work);
    defer if (payload) |bytes| self.allocator.free(bytes);
    if (!evaluate) {
        try self.authenticateTransactionLog(request.work);
        {
            var view = try self.transactionLogView(read.definition, target.partition.?, read_fence.guard());
            defer view.deinit();
            const frozen = try view.inspect(source.pin, read_fence.guard());
            if (!std.meta.eql(try frozen.guard(), request.guard)) return error.InvalidTransactionCut;
            try request.guard.requireUnchanged(try view.basis());
            if (request.work == .queue_transfer) try view.validateTransferPayload(request.work.queue_transfer, read_fence.guard()) else try view.validatePayload(request.work, payload);
        }
        if (transfer_access) |*access| try self.validateTransactionTransfer(selected.destination.?, access, request.work, payload, true);
        staging.used = try std.math.add(u64, staging.used, if (payload) |bytes| bytes.len else 0);
        if (staging.used > staging.limit) return error.TransactionWorkspaceLimit;
        try c.OperationBinding.claimTransactionLogStatement(self.allocator, self.data_objects, request);
        head.pending = .{ .log = request };
        head.last_statement = request.statement.sequence;
        try self.publishTransactionWorkspace(progress, &head, &staging, write_fence.guard());
        try check(read_fence.guard());
        if (transfer_access) |*access| try access.checkCurrent();
        return null;
    }
    const prior = references: {
        var logs = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .participants, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
        defer logs.deinit();
        if (head.logs) |directory| try logs.restore(directory);
        const source_previous = if (try logs.get(target)) |item| item.participant.log.actions else null;
        const destination_previous: ?p.Transaction.Directory = if (selected.destination) |destination_source| blk: {
            break :blk if (try logs.get(destination_source.guard.target())) |item| item.participant.log.actions else null;
        } else null;
        break :references .{ .source = source_previous, .destination = destination_previous };
    };
    const previous = prior.source;
    const directory = sealed: {
        var actions = try s.LogTransactionActions.init(self.allocator, self.data_objects, begin.identity, request.guard, begin.limits.statements, begin.limits.workspace_bytes, self.options.resident_pages, self.options.index_work_bytes);
        defer actions.deinit();
        if (previous) |value| try actions.restore(value);
        const action_entry = request.work.entry(request.statement);
        if (action_entry.offset_cursor) |cursor| try actions.putOffset(action_entry.work, cursor) else try actions.put(action_entry.work, if (request.work == .queue_transfer) null else payload);
        break :sealed try actions.seal();
    };
    var destination: ?TransactionTransferAdvance = null;
    const outcome: TransactionLogWork.Outcome = evaluated: {
        destination = self.evaluateTransactionLogStatement(read.definition, selected, prior.destination, &transfer_access, request, begin, directory, payload, write_fence.guard()) catch |err| {
            const reason: TransactionLogWork.Outcome.Reason = switch (err) {
                error.TransactionConflict => .conflict,
                error.QueueLeaseExpired => .lease_expired,
                error.QueueLeaseFenced => .lease_fenced,
                error.LogProducerConflict => .producer_conflict,
                error.LogOffsetConflict, error.LogGroupFenced => .offset_conflict,
                else => return err,
            };
            break :evaluated .{ .rejected = .{ .statement = request.statement, .reason = reason } };
        };
        break :evaluated .{ .provisional = .{ .statement = request.statement, .proposed = TransactionLogWork.Summary.proposed(request.work) } };
    };
    if (outcome == .provisional) {
        var logs = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .participants, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
        defer logs.deinit();
        if (head.logs) |value| try logs.restore(value);
        try logs.advanceLog(request.guard, previous, directory);
        if (destination) |next| try logs.advanceLog(next.guard, next.previous, next.directory);
        head.logs = try logs.seal();
    }
    const completed: TransactionWorkspace.StatementCompletion = .{ .log = .{ .request = request, .outcome = outcome } };
    try completed.validate();
    const result_record = try TransactionWorkspace.stage(staging.objects(), scope_value, TransactionWorkspace.statement_format, completed);
    head.statements = try TransactionWorkspace.put(&index, head.statements, request.statement.sequence, result_record, self.options.index_work_bytes);
    head.pending = null;
    try check(read_fence.guard());
    if (transfer_access) |*access| try access.checkCurrent();
    try self.publishTransactionWorkspace(progress, &head, &staging, write_fence.guard());
    try check(read_fence.guard());
    if (transfer_access) |*access| try access.checkCurrent();
    return outcome;
}

const TransactionTransferAdvance = struct { guard: p.Transaction.LogGuard, previous: ?p.Transaction.Directory, directory: p.Transaction.Directory };
fn evaluateTransactionLogStatement(self: *Self, definition: L.Definition, selected: TransactionLogSources, destination_previous: ?p.Transaction.Directory, transfer_access: *?TransactionTransferAccess, request: TransactionLogWork.Request, begin: p.Transaction.Begin, directory: p.Transaction.Directory, payload: ?[]const u8, guard_value: P.Guard) !?TransactionTransferAdvance {
    const environment = if (self.log_environment) |value| value.* else c.DirectTransactionLog.Environment{};
    const limits = TransactionLogWork.evaluationLimits(begin, request.statement.sequence);
    {
        const target = (p.Transaction.Guard{ .log = request.guard }).target();
        const source = selected.source;
        var view = try self.transactionLogView(definition, target.partition.?, guard_value);
        defer view.deinit();
        view.clock(environment.clock);
        _ = try view.evaluate(source.pin, directory, limits, environment.authority, guard_value);
    }
    if (transfer_access.*) |*access| {
        const source = selected.destination.?;
        const target = source.guard.target();
        const next = destination_actions: {
            var actions = try s.LogTransactionActions.init(self.allocator, self.data_objects, begin.identity, source.guard.log, begin.limits.statements, begin.limits.workspace_bytes, self.options.resident_pages, self.options.index_work_bytes);
            defer actions.deinit();
            if (destination_previous) |prior| try actions.restore(prior);
            try actions.put(request.work.destinationEntry(request.statement).?.work, payload);
            break :destination_actions try actions.seal();
        };
        var destination = try self.transactionLogView(access.definition, target.partition.?, access.read.guard());
        defer destination.deinit();
        destination.clock(environment.clock);
        _ = try destination.evaluate(source.pin, next, limits, environment.authority, access.write.guard());
        try access.checkCurrent();
        return .{ .directory = next, .previous = destination_previous, .guard = source.guard.log };
    }
    return null;
}

pub fn publishTransactionWorkspace(self: *Self, prior: c.DirectClientToken.Progress, head: *TransactionWorkspace.Head, staging: *TransactionWorkspace.Staging, current: P.Guard) !void {
    // Reserve the fixed metadata ceiling before staging. This conservative
    // charge includes header growth without a self-referential byte count.
    const charge = try std.math.add(u64, staging.used, TransactionWorkspace.max_bytes);
    if (charge > staging.limit) return error.TransactionWorkspaceLimit;
    var progress = prior;
    var next = self.store.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    progress.revision = .{ .partition = self.config().partition, .next_lsn = next.next_lsn };
    head.revision = progress.revision;
    head.charged_bytes = charge;
    try head.validate(progress);
    progress.record = try TransactionWorkspace.stage(staging.objects(), prior.receipt.binding.key.scope(), TransactionWorkspace.head_format, head.*);
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
    defer self.store.index.end();
    try self.store.clientIndices(&next, progress);
    try self.store.publish(next, .{ .client_token = progress }, current);
    try check(current);
}

/// Caller-command recovery never substitutes a new native operation after an
/// uncertain response. The catalog retains definitive precondition refusals too.
pub fn transactionCall(self: *Self, key: c.DirectClientToken.Key, steps: u16, control: bool, request_cancel: bool, policy: Policy) anyerror!?c.DirectTransactionCall.Result {
    if (steps == 0 or steps > 256) return error.InvalidTransactionWork;
    var progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction_call) return error.TransactionOperationRequired;
    const call = progress.receipt.binding.intent.transaction_call;
    if (control != (call.work == .settle)) return error.InvalidTransactionWork;
    if (try self.transactionCallOutcome(key, policy)) |result| {
        if (!progress.pending) return result;
    }
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const current = try self.guard(arena.allocator(), policy, null, null, .database);
    try check(current);
    if (request_cancel and !progress.cancel) {
        progress.cancel = true;
        try self.publishTransactionCall(&progress, null, current);
    }
    const result = self.executeTransactionCall(call, steps, policy) catch |err| {
        const reason = c.DirectTransactionCall.refusal(err) orelse return err;
        const rejected: c.DirectTransactionCall.Result = .{ .rejected = reason };
        try self.publishTransactionCall(&progress, rejected, current);
        return rejected;
    };
    if (result) |value| {
        if (value != .settled or value.settled.cleanup_complete) try self.publishTransactionCall(&progress, value, current);
    }
    return result;
}

pub fn transactionCallOutcome(self: *Self, key: c.DirectClientToken.Key, policy: Policy) anyerror!?c.DirectTransactionCall.Result {
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction_call) return error.TransactionOperationRequired;
    const call = progress.receipt.binding.intent.transaction_call;
    if (progress.record) |reference| {
        const stored = try TransactionWorkspace.load(c.DirectTransactionCall.Stored, self.allocator, self.data_objects, reference, key.scope(), c.DirectTransactionCall.format);
        try stored.validate();
        if (!std.meta.eql(stored.call, call)) return error.TransactionIdentityConflict;
        if (stored.result == .rejected) return stored.result;
    }
    return self.observeTransactionCall(call, policy);
}

fn observeTransactionCall(self: *Self, call: c.DirectTransactionCall, policy: Policy) anyerror!?c.DirectTransactionCall.Result {
    switch (call.work) {
        .begin => |work| {
            if (try self.clientToken(.{ .lookup = work.key }, policy) == null) return null;
            const observed = try self.inspectTransaction(work.key, policy);
            return if (observed.cut) |cut| .{ .begun = cut } else null;
        },
        .statement => |work| return if (try self.transactionStatementOutcome(work.key, work.request, policy)) |outcome| .{ .statement = outcome } else null,
        .savepoint => |work| {
            const outcome = try self.transactionSavepointOutcome(work.key, work.request, policy) orelse return null;
            return if (outcome.completed != null) .{ .savepoint = outcome } else null;
        },
        .settle => |work| {
            const observed = try self.inspectTransaction(work.key, policy);
            if (observed.attempt) |attempt| if (!std.meta.eql(attempt.operation, work.operation)) return error.TransactionIdentityConflict;
            return if (observed.observation == .decided) .{ .settled = observed } else null;
        },
    }
}

fn executeTransactionCall(self: *Self, call: c.DirectTransactionCall, steps: u16, policy: Policy) anyerror!?c.DirectTransactionCall.Result {
    if (call.work != .settle) if (try self.observeTransactionCall(call, policy)) |result| return result;
    switch (call.work) {
        .begin => |work| {
            _ = try self.beginTransaction(try call.beginRequest(), policy);
            return .{ .begun = (try self.acquireTransaction(work.key, policy)).cut };
        },
        .statement => |work| return .{ .statement = try self.executeTransactionStatement(work.key, work.request, policy) },
        .savepoint => |work| {
            const result = try self.transactionSavepoint(work.key, work.request, steps, policy);
            return if (result.completed != null) .{ .savepoint = result } else null;
        },
        .settle => |work| {
            const result = self.settleTransaction(work.key, work.operation, work.command, steps, policy) catch |err| retry: {
                // An invalidated serializable commit cannot publish. Record the
                // abort through the same original attempt, never as new work.
                if (work.command != .commit or err != error.TransactionConflict) return err;
                break :retry try self.settleTransaction(work.key, work.operation, .abort, steps, policy);
            };
            return if (result.observation == .decided) .{ .settled = result } else null;
        },
    }
}

fn publishTransactionCall(self: *Self, progress: *c.DirectClientToken.Progress, result: ?c.DirectTransactionCall.Result, current: P.Guard) !void {
    var next = self.store.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    progress.revision = .{ .partition = self.config().partition, .next_lsn = next.next_lsn };
    if (result) |value| {
        try value.requireCall(progress.receipt.binding.intent.transaction_call);
        progress.pending = value == .settled and !value.settled.cleanup_complete;
        progress.record = try TransactionWorkspace.stage(self.data_objects, progress.receipt.binding.key.scope(), c.DirectTransactionCall.format, c.DirectTransactionCall.Stored{ .definition = p.Growth.current_definition, .call = progress.receipt.binding.intent.transaction_call, .result = value });
    }
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
    defer self.store.index.end();
    try self.store.clientIndices(&next, progress.*);
    try self.store.publish(next, .{ .client_token = progress.* }, current);
    try check(current);
}

/// Observe a statement without admitting or evaluating it. Original provisional
/// evidence remains inspectable after the transaction has released its pins.
pub fn transactionStatementOutcome(self: *Self, key: c.DirectClientToken.Key, request: TransactionWorkspace.Request, policy: Policy) anyerror!?s.TableWorkspace.Outcome {
    try request.validate();
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    if (!std.meta.eql(request.statement.transaction, progress.receipt.binding.intent.transaction.begin.identity)) return error.TransactionIdentityConflict;
    var memory: c.fuze.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(progress.receipt.binding.intent.transaction.begin.limits.resident_bytes) };
    const parent = self.allocator;
    const retained = self.options.table_owner;
    self.allocator = memory.allocator();
    self.options.table_owner = null;
    defer {
        self.allocator = parent;
        self.options.table_owner = retained;
        std.debug.assert(memory.used == 0);
    }
    const head = try self.transactionObservationHead(progress) orelse return null;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var view = try self.transactionView(request.binding.target);
    defer view.deinit();
    const read = try self.transactionStateGuard(arena.allocator(), &view, .read, null, policy);
    const write = try self.transactionStateGuard(arena.allocator(), &view, try transactionWriteAccess(request.binding.action), request.binding.prerequisite, policy);
    try check(read);
    try check(write);
    var index = try s.TreeStore.init(self.allocator, self.data_objects, self.options.resident_pages);
    defer index.deinit();
    const stored = try TransactionWorkspace.get(TransactionWorkspace.StatementCompletion, self.allocator, &index, head.statements, request.statement.sequence, key.scope(), TransactionWorkspace.statement_format) orelse return null;
    try stored.validate();
    if (stored != .state) return error.TransactionStatementConflict;
    const completed = stored.state;
    if (!std.meta.eql(completed.request, request)) return error.TransactionStatementConflict;
    try check(read);
    try check(write);
    return completed.outcome;
}

pub fn transactionLogOutcome(self: *Self, key: c.DirectClientToken.Key, request: TransactionLogWork.Request, policy: Policy) !?TransactionLogWork.Outcome {
    try request.validate();
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    if (!std.meta.eql(request.statement.transaction, progress.receipt.binding.intent.transaction.begin.identity)) return error.TransactionIdentityConflict;
    var memory: c.fuze.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(progress.receipt.binding.intent.transaction.begin.limits.resident_bytes) };
    const parent = self.allocator;
    self.allocator = memory.allocator();
    defer {
        self.allocator = parent;
        std.debug.assert(memory.used == 0);
    }
    return self.transactionLogOutcomeBounded(progress, request, policy) catch |err| return if (err == error.OutOfMemory and memory.exhausted) error.TransactionMemoryLimit else err;
}

fn transactionLogOutcomeBounded(self: *Self, progress: c.DirectClientToken.Progress, request: TransactionLogWork.Request, policy: Policy) !?TransactionLogWork.Outcome {
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    const read = try self.logAuthorization(scratch.allocator(), request.work.kind(), request.work.target(), .read, policy);
    const write = try self.logAuthorization(scratch.allocator(), request.work.kind(), request.work.target(), request.work.access(), policy);
    var epoch: ?P.Guard.Fence = null;
    var read_fence: CutFence = .{ .underlying = read.guard, .epoch = &epoch };
    var write_fence: CutFence = .{ .underlying = write.guard, .epoch = &epoch };
    try check(read_fence.guard());
    try check(write_fence.guard());
    var transfer_access = try self.transactionTransferAccess(scratch.allocator(), request.work, policy, &epoch);
    var outcome: ?TransactionLogWork.Outcome = null;
    if (try self.transactionObservationHead(progress)) |head| {
        var index = try s.TreeStore.init(self.allocator, self.data_objects, self.options.resident_pages);
        defer index.deinit();
        if (try TransactionWorkspace.get(TransactionWorkspace.StatementCompletion, self.allocator, &index, head.statements, request.statement.sequence, progress.receipt.binding.key.scope(), TransactionWorkspace.statement_format)) |stored| {
            try stored.validate();
            if (stored != .log or !std.meta.eql(stored.log.request, request)) return error.TransactionStatementConflict;
            outcome = stored.log.outcome;
        }
    }
    try check(read_fence.guard());
    try check(write_fence.guard());
    if (transfer_access) |*access| try access.checkCurrent();
    return outcome;
}

pub fn transactionSavepointOutcome(self: *Self, key: c.DirectClientToken.Key, request: c.DirectTransactionSavepoint.Request, policy: Policy) anyerror!?c.DirectTransactionSavepoint.Result {
    try request.validate();
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    if (!std.meta.eql(request.transaction, progress.receipt.binding.intent.transaction.begin.identity)) return error.TransactionIdentityConflict;
    var memory: c.fuze.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(progress.receipt.binding.intent.transaction.begin.limits.resident_bytes) };
    const parent = self.allocator;
    const retained = self.options.table_owner;
    self.allocator = memory.allocator();
    self.options.table_owner = null;
    defer {
        self.allocator = parent;
        self.options.table_owner = retained;
        std.debug.assert(memory.used == 0);
    }
    const head = try self.transactionObservationHead(progress) orelse return null;
    var index = try s.TreeStore.init(self.allocator, self.data_objects, self.options.resident_pages);
    defer index.deinit();
    if (try TransactionWorkspace.get(c.DirectTransactionSavepoint.Result, self.allocator, &index, head.controls, request.sequence, key.scope(), c.DirectTransactionSavepoint.result_format)) |result| {
        try result.validate();
        if (!std.meta.eql(result.request, request)) return error.TransactionControlConflict;
        return result;
    }
    if (head.pending_control) |control_pending| if (std.meta.eql(control_pending.result.request, request)) return control_pending.result;
    return null;
}

fn transactionObservationHead(self: *Self, progress: c.DirectClientToken.Progress) !?TransactionWorkspace.Head {
    if (progress.record == null) return null;
    if (progress.record.?.format == TransactionControl.format) return (try TransactionControl.load(self.allocator, self.data_objects, progress)).workspace;
    return try TransactionWorkspace.recover(self.allocator, self.data_objects, progress);
}

/// Named private-root controls retain exact accepted identities across retries.
pub fn transactionSavepoint(self: *Self, key: c.DirectClientToken.Key, request: c.DirectTransactionSavepoint.Request, steps: u16, policy: Policy) anyerror!c.DirectTransactionSavepoint.Result {
    if (steps == 0 or steps > 256) return error.InvalidTransactionWork;
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    var memory: c.fuze.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(progress.receipt.binding.intent.transaction.begin.limits.resident_bytes) };
    const parent = self.allocator;
    const retained = self.options.table_owner;
    self.allocator = memory.allocator();
    self.options.table_owner = null;
    defer {
        self.allocator = parent;
        self.options.table_owner = retained;
        std.debug.assert(memory.used == 0);
    }
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    var epoch: ?P.Guard.Fence = null;
    var fence: CutFence = .{ .underlying = try self.guard(scratch.allocator(), policy, null, null, .database), .epoch = &epoch };
    try check(fence.guard());
    const result = c.DirectTransactionSavepoint.apply(self, progress, request, steps, policy, fence.guard()) catch |err| return if (err == error.OutOfMemory and memory.exhausted) error.TransactionMemoryLimit else err;
    try check(fence.guard());
    return result;
}

/// Return the current accepted private root under current SELECT permission.
/// It is evaluation state, never an accepted Table recovery checkpoint.
pub fn transactionTableState(self: *Self, key: c.DirectClientToken.Key, object: d.Object, policy: Policy) !s.TableWorkspace.State {
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    var memory: c.fuze.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(progress.receipt.binding.intent.transaction.begin.limits.resident_bytes) };
    const parent = self.allocator;
    const retained = self.options.table_owner;
    // Transaction Table owners belong to this temporary budget. Borrowing a
    // resident owner would bypass it; retaining a new one would outlive it.
    self.options.table_owner = null;
    self.allocator = memory.allocator();
    defer {
        self.allocator = parent;
        self.options.table_owner = retained;
        std.debug.assert(memory.used == 0);
    }
    return self.transactionTableStateBounded(progress, object, policy) catch |err|
        return if (err == error.OutOfMemory and memory.exhausted) error.TransactionMemoryLimit else err;
}

fn transactionTableStateBounded(self: *Self, progress: c.DirectClientToken.Progress, object: d.Object, policy: Policy) !s.TableWorkspace.State {
    const head = try TransactionWorkspace.recover(self.allocator, self.data_objects, progress);
    const begin = head.acquired.cut.begin;
    try begin.identity.requireObject(object);
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    var access = try self.transactionSnapshotAccess(scratch.allocator(), object, begin.identity.begin, policy);
    defer access.view.deinit();
    var sources = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .sources, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
    defer sources.deinit();
    try sources.restore(head.acquired.cut.sources);
    const source = (try sources.get(s.TableTransaction.target(access.view.table.root)) orelse return error.TransactionObjectNotSelected).source;
    var index = try s.TreeStore.init(self.allocator, self.data_objects, self.options.resident_pages);
    defer index.deinit();
    const previous = try TransactionWorkspace.get(s.TableWorkspace.State, self.allocator, &index, head.tables, object.object, progress.receipt.binding.key.scope(), TransactionWorkspace.table_format);
    var evaluator = try s.TableWorkspace.init(self.allocator, &access.view.table, begin, source.pin, previous, access.current);
    defer evaluator.deinit();
    try check(access.current);
    return evaluator.state();
}

/// Validate the active revision before opening any private cursor or metadata.
pub fn transactionReadHead(self: *Self, context: c.DirectTransactionRead.Context, policy: Policy) anyerror!TransactionWorkspace.Head {
    try context.validate();
    const progress = (try self.clientProgress(.{ .inspect = context.key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    if (!std.meta.eql(progress.revision, context.revision)) return error.TransactionReadChanged;
    const head = try TransactionWorkspace.recover(self.allocator, self.data_objects, progress);
    if (head.pending_control != null) return error.TransactionControlPending;
    if (head.pending != null) return error.TransactionStatementPending;
    return head;
}

fn overlayTransactionRead(self: *Self, view: *View, context: c.DirectTransactionRead.Context, current: P.Guard, policy: Policy) !void {
    const head = try self.transactionReadHead(context, policy);
    const begin = head.acquired.cut.begin;
    const object = view.table.root.interpretation.object;
    try begin.identity.requireObject(object);
    var sources = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .sources, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
    defer sources.deinit();
    try sources.restore(head.acquired.cut.sources);
    const source = (try sources.get(s.TableTransaction.target(view.table.root)) orelse return error.TransactionObjectNotSelected).source;
    var frozen = try view.table.inspectSnapshot(self.allocator, source.pin, current);
    defer frozen.deinit();
    if (!std.meta.eql(transactionTableGuard(frozen.root), (try source.guard.requirePagedState()))) return error.InvalidTransactionCut;
    var index = try s.TreeStore.init(self.allocator, self.data_objects, self.options.resident_pages);
    defer index.deinit();
    const prior = try TransactionWorkspace.get(s.TableWorkspace.State, self.allocator, &index, head.tables, object.object, context.key.scope(), TransactionWorkspace.table_format);
    var evaluator = try s.TableWorkspace.init(self.allocator, &view.table, begin, source.pin, prior, current);
    defer evaluator.deinit();
    const state = evaluator.state();
    const observation = try c.DirectTransactionRead.view(context, head, (try source.guard.requirePagedState()), state);
    var declaration = try s.TableDeclaration.load(self.allocator, self.data_objects, state.root.declared());
    defer declaration.deinit();
    var options = self.options.table;
    options.control = null;
    options.kind = state.root.kind;
    var table = try P.init(self.allocator, state.root.partition, declaration.definition, self.data_log, self.data_objects, options);
    errdefer table.deinit();
    table.workspace = true;
    table.workspace_read = observation;
    table.root = state.root;
    table.recovery_required = false;
    const properties = try Properties.decode(self.allocator, declaration.definition.properties);
    try check(current);
    // Private roots and their temporary allocator must never enter an ordinary
    // Table owner cache or a public recovery hint.
    view.table.deinit();
    view.* = .{ .table = table, .properties = properties };
}

fn resolveTransactionRead(self: *Self, allocator: std.mem.Allocator, context: c.DirectTransactionRead.Context, namespace_id: u64, name: a.Name, policy: Policy) !?View {
    _ = allocator;
    const head = try self.transactionReadHead(context, policy);
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    const initial = try self.guard(scratch.allocator(), policy, try self.schema(namespace_id), null, .schema);
    try check(initial);
    const position = head.acquired.cut.begin.catalog;
    var frames = try self.store.log.read(self.allocator, position.partition, position.next_lsn - 1, 1);
    defer frames.deinit();
    if (frames.frames.len != 1) return error.CatalogHistoryMissing;
    const frozen = try Store.decodeFrame(self.allocator, frames.frames[0], position.partition, position.next_lsn - 1);
    const value = try self.store.tree().get(frozen.root.names, try r.nameKey(namespace_id, name)) orelse return null;
    const proposed = try r.fromValue(r.Name, self.allocator, value);
    if (proposed.namespace != namespace_id or !std.meta.eql(proposed.name, name)) return error.CatalogNameHashCollision;
    var access = try self.readAccess(scratch.allocator(), .{ .scope = self.config().scope, .branch = self.config().branch, .object = proposed.object }, policy, false);
    errdefer access.view.deinit();
    if (access.view.properties.namespace != namespace_id or !std.meta.eql(access.view.properties.name, name)) return error.InvalidTransactionRead;
    try check(access.current);
    return access.view;
}

const TransactionControl = c.DirectTransactionControl;

/// Resume accepted work only. An idle active transaction stays active; no new
/// statement, commit attempt or abort is chosen by maintenance.
pub fn resumeTransaction(self: *Self, key: c.DirectClientToken.Key, steps: u16, policy: Policy) !TransactionControl.Status {
    if (steps == 0 or steps > 256) return error.InvalidTransactionWork;
    const observed = try self.inspectTransaction(key, policy);
    if (observed.attempt) |attempt| return self.settleTransaction(key, attempt.operation, .commit, steps, policy);
    if (!observed.pending_statement and !observed.pending_control) return observed;
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    const head = try TransactionWorkspace.recover(self.allocator, self.data_objects, progress);
    if (head.pending_control) |control_pending| {
        _ = try self.transactionSavepoint(key, control_pending.result.request, steps, policy);
    } else switch (head.pending orelse return error.InvalidTransactionWorkspace) {
        .state => |request| _ = try self.executeTransactionStatement(key, request, policy),
        .log => |request| _ = try self.executeTransactionLog(key, request, policy),
    }
    return self.inspectTransaction(key, policy);
}

/// Inspect original transaction knowledge without acquiring a cut or deciding.
/// The host serializes database publication while this method observes owners.
pub fn inspectTransaction(self: *Self, key: c.DirectClientToken.Key, policy: Policy) !TransactionControl.Status {
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    const begin = progress.receipt.binding.intent.transaction.begin;
    var result: TransactionControl.Status = .{ .revision = progress.revision, .begin = begin, .acquired = false, .cut = null, .last_statement = 0, .pending_statement = false, .last_control = 0, .pending_control = false, .savepoints = 0, .attempt = null, .observation = .not_observed, .cleanup_complete = false };
    const reference = progress.record orelse return result;
    if (reference.format != TransactionControl.format) {
        const head = try TransactionWorkspace.recover(self.allocator, self.data_objects, progress);
        result.acquired = true;
        result.cut = head.acquired.cut;
        result.last_statement = head.last_statement;
        result.pending_statement = head.pending != null;
        result.last_control = head.last_control;
        result.pending_control = head.pending_control != null;
        result.savepoints = head.savepoint_count;
        return result;
    }
    const control = try TransactionControl.load(self.allocator, self.data_objects, progress);
    result.acquired = control.workspace != null;
    result.cut = if (control.workspace) |head| head.acquired.cut else null;
    result.last_statement = control.binding.attempt.last_statement;
    if (control.workspace) |head| result.last_control = head.last_control;
    result.attempt = control.binding.attempt;
    result.cleanup_complete = control.cleanup_complete;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var journal = try s.TransactionDecisionLog.init(self.allocator, self.data_log, self.data_objects, progress.receipt.coordination.?, control.binding);
    try journal.recover();
    result.observation = try journal.observe(try self.guard(arena.allocator(), policy, null, null, .database));
    if (control.decision) |known| {
        if (result.observation != .decided or !std.meta.eql(known, result.observation.decided)) return error.InvalidTransactionControl;
    }
    return result;
}

/// Resume the original attempt in bounded participant preparation/cleanup units.
/// The embedding host excludes ALL database publication throughout the call.
/// This exclusion plus one unchanged policy/writer epoch closes validation to
/// decision races without retaining one in-memory guard per participant.
/// Abort requests race through the same journal; they cannot undo a commit.
pub fn settleTransaction(self: *Self, key: c.DirectClientToken.Key, operation: d.Operation, command: TransactionControl.Command, steps: u16, policy: Policy) !TransactionControl.Status {
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return error.ClientOperationMissing;
    if (progress.receipt.binding.intent != .transaction) return error.TransactionOperationRequired;
    if (steps == 0) return error.InvalidTransactionWork;
    var memory: c.fuze.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(progress.receipt.binding.intent.transaction.begin.limits.resident_bytes) };
    const parent = self.allocator;
    const retained = self.options.table_owner;
    self.options.table_owner = null;
    self.allocator = memory.allocator();
    defer {
        self.allocator = parent;
        self.options.table_owner = retained;
        std.debug.assert(memory.used == 0);
    }
    self.settleTransactionBounded(progress, operation, command, steps, policy) catch |err| return if (err == error.OutOfMemory and memory.exhausted) error.TransactionMemoryLimit else err;
    return self.inspectTransaction(key, policy);
}

fn transactionView(self: *Self, object: d.Object) !View {
    if (!std.meta.eql(object.scope, self.config().scope) or object.branch != self.config().branch) return error.CatalogDenied;
    const target = try self.entry(object.object) orelse return error.CatalogDenied;
    return self.openTransaction(self.allocator, target, false, true);
}

fn transactionLogView(self: *Self, definition: L.Definition, ordinal: u32, guard_value: P.Guard) !c.DirectTransactionLog {
    return c.DirectTransactionLog.open(self.allocator, self, definition, ordinal, guard_value, self.options.logs);
}

fn publishTransactionControl(self: *Self, progress: *c.DirectClientToken.Progress, control: *TransactionControl.State, guard_value: P.Guard) !void {
    var next = self.store.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    progress.revision = .{ .partition = self.config().partition, .next_lsn = next.next_lsn };
    progress.pending = !control.cleanup_complete;
    control.revision = progress.revision;
    try control.validate(progress.*);
    progress.record = try TransactionWorkspace.stage(self.data_objects, progress.receipt.binding.key.scope(), TransactionControl.format, control.*);
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
    defer self.store.index.end();
    try self.store.clientIndices(&next, progress.*);
    try self.store.publish(next, .{ .client_token = progress.* }, guard_value);
    try check(guard_value);
}

fn freezeTransaction(self: *Self, progress: *c.DirectClientToken.Progress, operation: d.Operation, command: TransactionControl.Command, guard_value: P.Guard) !TransactionControl.State {
    if (progress.record != null and progress.record.?.format == TransactionControl.format) {
        const control = try TransactionControl.load(self.allocator, self.data_objects, progress.*);
        if (!std.meta.eql(control.binding.attempt.operation, operation)) return error.TransactionIdentityConflict;
        return control;
    }
    const begin = progress.receipt.binding.intent.transaction.begin;
    const head = if (progress.record != null) try TransactionWorkspace.recover(self.allocator, self.data_objects, progress.*) else null;
    if (command == .commit) {
        if (head == null) return error.TransactionCutNotAcquired;
        if (head.?.pending_control != null) return error.TransactionControlPending;
        if (head.?.pending != null) return error.TransactionStatementPending;
    }
    var selected = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, if (head != null) .sources else .participants, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
    defer selected.deinit();
    try selected.restore(if (head) |value| value.acquired.cut.sources else begin.objects);
    var participants = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .participants, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
    defer participants.deinit();
    var private_logs = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .participants, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
    defer private_logs.deinit();
    if (head) |value| if (value.logs) |directory| try private_logs.restore(directory);
    var index = try s.TreeStore.init(self.allocator, self.data_objects, self.options.resident_pages);
    defer index.deinit();
    var after: ?s.TransactionDirectory.Cursor = null;
    while (true) {
        const page = try selected.page(after);
        for (page.entries) |slot| if (slot) |entry_value| {
            const selected_guard = if (head != null) entry_value.source.guard else entry_value.participant.guard();
            if (selected_guard == .log) {
                const private = try private_logs.get(entry_value.target());
                if (private) |value| if (value.participant != .log or !std.meta.eql(value.participant.log.guard, selected_guard.log)) return error.InvalidTransactionWorkspace;
                try participants.put(.{ .participant = .{ .log = .{ .guard = selected_guard.log, .actions = if (private) |value| value.participant.log.actions else null } } });
                continue;
            }
            const guard_basis = try selected_guard.requirePagedState();
            const private = if (head) |value| try TransactionWorkspace.get(s.TableWorkspace.State, self.allocator, &index, value.tables, entry_value.object().object, progress.receipt.binding.key.scope(), TransactionWorkspace.table_format) else null;
            try participants.put(.{ .participant = .{ .state = .{ .kind = selected_guard.state.kind, .guard = guard_basis, .access = if (private != null) .write else .read } } });
        };
        after = page.next orelse break;
    }
    const binding: s.TransactionDecisionLog.Binding = .{ .begin = begin, .attempt = .{
        .definition = p.Growth.current_definition,
        .transaction = begin.identity,
        .operation = operation,
        .cut = if (head) |value| (try value.acquired.stage(self.data_objects, progress.receipt)).content else begin.objects.content,
        .workspace = if (progress.record) |reference| reference.content else begin.objects.content,
        .participants = try participants.seal(),
        .writes = participants.root.writes,
        .last_statement = if (head) |value| value.last_statement else 0,
    } };
    try binding.validate();
    try check(guard_value);
    try c.OperationBinding.claimTransactionAttempt(self.allocator, self.data_objects, binding);
    var control: TransactionControl.State = .{ .definition = p.Growth.current_definition, .revision = progress.revision, .binding = binding, .abort_requested = command == .abort, .workspace = head, .preparations = null, .prepared_after = null, .preparation_complete = false, .decision = null, .cleanup_after = null, .cleanup_complete = false };
    try self.publishTransactionControl(progress, &control, guard_value);
    return control;
}

fn settleTransactionBounded(self: *Self, admitted: c.DirectClientToken.Progress, operation: d.Operation, command: TransactionControl.Command, steps: u16, policy: Policy) !void {
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    var epoch: ?P.Guard.Fence = null;
    // The publication guard lives outside the per-participant scratch arena.
    var guards = std.heap.ArenaAllocator.init(self.allocator);
    defer guards.deinit();
    var publication: CutFence = .{ .underlying = try self.guard(guards.allocator(), policy, null, null, .database), .epoch = &epoch };
    const guard_value = publication.guard();
    try check(guard_value);
    var progress = admitted;
    var control = try self.freezeTransaction(&progress, operation, command, guard_value);
    if (control.cleanup_complete) return;
    const begin = control.binding.begin;
    var journal = try s.TransactionDecisionLog.init(self.allocator, self.data_log, self.data_objects, progress.receipt.coordination.?, control.binding);
    try journal.recover();
    journal.lose_reply = self.lose_transaction_reply;
    try journal.freeze(guard_value);
    var participants = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .participants, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
    defer participants.deinit();
    try participants.restore(control.binding.attempt.participants);
    var remaining = steps;
    if (journal.decision == null and (command == .abort or control.abort_requested)) {
        if (!control.abort_requested) {
            control.abort_requested = true;
            try self.publishTransactionControl(&progress, &control, guard_value);
        }
        control.decision = try journal.abort(guard_value);
        try self.publishTransactionControl(&progress, &control, guard_value);
    }
    if (journal.decision == null) {
        if (control.workspace == null) return error.TransactionCutNotAcquired;
        if (control.workspace.?.pending != null) return error.TransactionStatementPending;
        var preparations = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .preparations, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
        defer preparations.deinit();
        if (control.preparations) |directory| try preparations.restore(directory);
        var index = try s.TreeStore.init(self.allocator, self.data_objects, self.options.resident_pages);
        defer index.deinit();
        var sources = try s.TransactionDirectory.init(self.allocator, self.data_objects, begin.identity, .sources, begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
        defer sources.deinit();
        try sources.restore(control.workspace.?.acquired.cut.sources);
        while (!control.preparation_complete and remaining != 0) {
            const page = try participants.page(control.prepared_after);
            var complete = true;
            for (page.entries) |slot| if (slot) |entry_value| {
                if (remaining == 0) {
                    complete = false;
                    break;
                }
                _ = scratch.reset(.retain_capacity);
                if (entry_value.participant == .log) {
                    const participant = entry_value.participant.log;
                    const authorized = try self.logAuthorization(scratch.allocator(), switch (participant.guard.kind) {
                        .stream => .stream,
                        .queue => .queue,
                    }, participant.guard.source.target, .read, policy);
                    var read: CutFence = .{ .underlying = authorized.guard, .epoch = &epoch };
                    var view = try self.transactionLogView(authorized.definition, participant.guard.source.target.partition, read.guard());
                    defer view.deinit();
                    if (participant.actions) |actions| {
                        const source = (try sources.get(entry_value.target()) orelse return error.InvalidTransactionCut).source;
                        if (source.guard != .log or !std.meta.eql(source.guard.log, participant.guard)) return error.InvalidTransactionCut;
                        const environment = if (self.log_environment) |value| value.* else c.DirectTransactionLog.Environment{};
                        view.clock(environment.clock);
                        const prepared = try view.prepare(control.binding, progress.receipt.coordination.?, participant.guard, source.pin, actions, TransactionLogWork.evaluationLimits(begin, control.binding.attempt.last_statement), environment.authority, read.guard());
                        try preparations.put(.{ .prepared = prepared });
                    } else if (begin.mode != .read_only) try participant.guard.requireUnchanged(try view.basis());
                    control.prepared_after = entry_value.cursor();
                    remaining -= 1;
                    continue;
                }
                const participant = entry_value.participant.state;
                var view = try self.transactionView(entry_value.object());
                defer view.deinit();
                if (!std.meta.eql(entry_value.target(), s.TableTransaction.target(view.table.root))) return error.TransactionIdentityConflict;
                var read: CutFence = .{ .underlying = try self.transactionStateGuard(scratch.allocator(), &view, .read, null, policy), .epoch = &epoch };
                try check(read.guard());
                if (participant.access == .write) {
                    const private = try TransactionWorkspace.get(s.TableWorkspace.State, self.allocator, &index, control.workspace.?.tables, entry_value.object().object, progress.receipt.binding.key.scope(), TransactionWorkspace.table_format) orelse return error.InvalidTransactionControl;
                    view.table.lose_reply = self.lose_table_reply;
                    const prepared = try view.table.prepareTransaction(control.binding, progress.receipt.coordination.?, participant.guard, private, read.guard());
                    try preparations.put(.{ .prepared = prepared });
                } else if (begin.mode != .read_only) {
                    if (view.table.root.transaction != null) return error.TransactionConflict;
                    try participant.guard.requireUnchanged(transactionTableGuard(view.table.root));
                }
                control.prepared_after = entry_value.cursor();
                remaining -= 1;
            };
            if (complete and page.next == null) control.preparation_complete = true;
            control.preparations = try preparations.seal();
            try self.publishTransactionControl(&progress, &control, guard_value);
        }
        if (!control.preparation_complete) return;
        // Recheck every original statement's current operation privilege. The
        // aggregate receipt must not introduce an unrelated UPDATE requirement.
        try self.authorizeTransactionStatements(control, progress.receipt.binding.key.scope(), policy, &epoch, &scratch, &index);
        var verification: TransactionVerification = .{ .catalog = self, .binding = control.binding, .epoch = &epoch };
        control.decision = try journal.commit(control.preparations.?, .{ .context = &verification, .participant = TransactionVerification.participant, .prepared = TransactionVerification.prepared, .before_decision = TransactionVerification.beforeDecision }, guard_value);
        try self.publishTransactionControl(&progress, &control, guard_value);
    }
    if (control.decision == null) {
        control.decision = journal.decision orelse return error.InvalidTransactionControl;
        try self.publishTransactionControl(&progress, &control, guard_value);
    }
    while (!control.cleanup_complete and remaining != 0) {
        const page = try participants.page(control.cleanup_after);
        var complete = true;
        for (page.entries) |slot| if (slot) |entry_value| {
            if (remaining == 0) {
                complete = false;
                break;
            }
            if (entry_value.participant == .log) {
                const selected = entry_value.participant.log.guard;
                const known = try self.logRecord(entry_value.object().object) orelse return error.LogDeclarationConflict;
                if (known.phase != .complete) return error.LogDeclarationConflict;
                var view = try self.transactionLogView(known.resulting.?, selected.source.target.partition, guard_value);
                defer view.deinit();
                if (view.root().transaction) |reference| {
                    const prepared = try s.LogTransaction.loadPreparation(self.data_objects, reference);
                    if (!std.meta.eql(prepared.binding, control.binding)) return error.TransactionPrepared;
                    const resolved = (try view.resolve(guard_value)) orelse return error.InvalidTransactionControl;
                    if (!std.meta.eql(resolved, control.decision.?)) return error.InvalidTransactionControl;
                }
                // Cleanup uses the common control authority; it neither reads
                // payloads nor resolves a different transaction's barrier.
                const pinned = try view.pinState(begin.identity.begin, guard_value);
                if (pinned.handle) |handle| if (!pinned.released) try view.release(handle, guard_value);
                control.cleanup_after = entry_value.cursor();
                remaining -= 1;
                continue;
            }
            var view = try self.transactionView(entry_value.object());
            defer view.deinit();
            view.table.lose_reply = self.lose_table_reply;
            if (view.table.root.transaction) |reference| {
                const prepared = try s.TableTransaction.load(self.allocator, self.data_objects, reference);
                // Another transaction's barrier is not ours to resolve. It may
                // temporarily defer release of this transaction's old pin.
                if (!std.meta.eql(prepared.binding, control.binding)) return error.TransactionPrepared;
                const resolved = (try view.table.resolveTransaction(guard_value)) orelse return error.InvalidTransactionControl;
                if (!std.meta.eql(resolved, control.decision.?)) return error.InvalidTransactionControl;
            }
            const pinned = try view.table.pinState(begin.identity.begin, guard_value);
            if (pinned.handle) |handle| if (!pinned.released) try view.table.releaseSnapshot(handle, guard_value);
            control.cleanup_after = entry_value.cursor();
            remaining -= 1;
        };
        if (complete and page.next == null) control.cleanup_complete = true;
        try self.publishTransactionControl(&progress, &control, guard_value);
    }
}

fn authorizeTransactionStatements(self: *Self, control: TransactionControl.State, scope_value: c.DirectRecord.Scope, policy: Policy, epoch: *?P.Guard.Fence, scratch: *std.heap.ArenaAllocator, index: *s.TreeStore) !void {
    const head = control.workspace orelse return error.InvalidTransactionControl;
    var selected = try s.TransactionDirectory.init(self.allocator, self.data_objects, control.binding.begin.identity, .participants, control.binding.begin.limits.participants, self.options.resident_pages, self.options.index_work_bytes);
    defer selected.deinit();
    try selected.restore(control.binding.attempt.participants);
    var after: ?s.TransactionDirectory.Cursor = null;
    while (true) {
        const page = try selected.page(after);
        for (page.entries) |slot| if (slot) |entry_value| {
            _ = scratch.reset(.retain_capacity);
            if (entry_value.participant == .log) {
                const dependency = entry_value.participant.log;
                const authorized = try self.logAuthorization(scratch.allocator(), switch (dependency.guard.kind) {
                    .stream => .stream,
                    .queue => .queue,
                }, dependency.guard.source.target, .read, policy);
                var read: CutFence = .{ .underlying = authorized.guard, .epoch = epoch };
                try check(read.guard());
                continue;
            }
            var view = try self.transactionView(entry_value.object());
            defer view.deinit();
            if (!std.meta.eql(entry_value.target(), s.TableTransaction.target(view.table.root))) return error.TransactionIdentityConflict;
            var read: CutFence = .{ .underlying = try self.transactionStateGuard(scratch.allocator(), &view, .read, null, policy), .epoch = epoch };
            try check(read.guard());
        };
        after = page.next orelse break;
    }
    var tree: pages.Tree(s.TreeStore) = .{ .store = index };
    var cursor: ?pages.Key = null;
    while (true) {
        const page = try tree.scan(head.statements, cursor);
        for (page.entries) |slot| if (slot) |entry_value| {
            _ = scratch.reset(.retain_capacity);
            const stored = try TransactionWorkspace.load(TransactionWorkspace.StatementCompletion, self.allocator, self.data_objects, try TransactionWorkspace.referenceOf(entry_value.value, scope_value, TransactionWorkspace.statement_format), scope_value, TransactionWorkspace.statement_format);
            try stored.validate();
            if (stored == .log) {
                const work = stored.log.request.work;
                const authorized = try self.logAuthorization(scratch.allocator(), work.kind(), work.target(), work.access(), policy);
                var write: CutFence = .{ .underlying = authorized.guard, .epoch = epoch };
                try check(write.guard());
                var transfer_access = try self.transactionTransferAccess(scratch.allocator(), work, policy, epoch);
                if (transfer_access) |*access| try access.checkCurrent();
                continue;
            }
            const completed = stored.state;
            var view = try self.transactionView(completed.request.binding.target);
            defer view.deinit();
            try self.original(policy, completed.request.binding);
            const permission: a.Access = switch (completed.request.binding.action) {
                .insert => .insert,
                .update => .update,
                .delete => .delete,
                else => return error.InvalidTransactionWorkspace,
            };
            var write: CutFence = .{ .underlying = try self.transactionStateGuard(scratch.allocator(), &view, permission, completed.request.binding.prerequisite, policy), .epoch = epoch };
            try check(write.guard());
        };
        cursor = page.next orelse break;
    }
}

const TransactionVerification = struct {
    catalog: *Self,
    binding: s.TransactionDecisionLog.Binding,
    epoch: *?P.Guard.Fence,
    floor_ms: ?u64 = null,
    lease_expires_ms: ?u64 = null,
    append_expires_ms: ?u64 = null,
    transfer_not_before_ms: ?u64 = null,
    clock_required: bool = false,
    // Journal callbacks execute only while the common publication guard is held.
    // Reusing that fence avoids recursively entering the service policy lock.
    fn held(raw: *anyopaque) !P.Guard.Fence {
        const self: *@This() = @ptrCast(@alignCast(raw));
        return self.epoch.* orelse error.TransactionAuthorityChanged;
    }
    fn releaseHeld(_: *anyopaque) void {}
    fn participant(raw: *anyopaque, value: p.Transaction.Participant) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (value == .log) {
            try value.validate(self.binding.begin.identity);
            const expected = value.log.guard;
            const known = try self.catalog.logRecord(expected.source.target.interpretation.object.object) orelse return error.LogDeclarationConflict;
            if (known.phase != .complete) return error.LogDeclarationConflict;
            const guard_value: P.Guard = .{ .context = self, .acquire = held, .release = releaseHeld };
            var view = try self.catalog.transactionLogView(known.resulting.?, expected.source.target.partition, guard_value);
            defer view.deinit();
            if (value.log.actions) |actions| {
                const reference = view.root().transaction orelse return error.TransactionPreparationMissing;
                const preparation = try s.LogTransaction.loadPreparation(self.catalog.data_objects, reference);
                try self.binding.requireSame(preparation.binding);
                if (!std.meta.eql(preparation.guard, expected) or !std.meta.eql(preparation.actions, actions) or
                    !std.meta.eql(known.resulting.?.stored, preparation.predecessor.declared)) return error.TransactionConflict;
            } else if (self.binding.begin.mode != .read_only) try expected.requireUnchanged(try view.basis());
            return;
        }
        try value.requireLocalState(self.binding.begin);
        var view = try self.catalog.transactionView(value.state.guard.source.interpretation.object);
        defer view.deinit();
        if (!std.meta.eql(value.guard().target(), s.TableTransaction.target(view.table.root))) return error.TransactionIdentityConflict;
        if (self.binding.begin.mode == .read_only) return;
        if (view.table.root.retired) return error.TransactionConflict;
        try value.state.guard.requireUnchanged(transactionTableGuard(view.table.root));
        if (value.state.access == .read and view.table.root.transaction != null) return error.TransactionConflict;
        if (value.state.access == .write and view.table.root.transaction == null) return error.TransactionPreparationMissing;
    }
    fn prepared(raw: *anyopaque, value: p.Transaction.Prepared) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (value.predecessor == .log) {
            const known = try self.catalog.logRecord(value.target.object.object) orelse return error.LogDeclarationConflict;
            if (known.phase != .complete) return error.LogDeclarationConflict;
            const guard_value: P.Guard = .{ .context = self, .acquire = held, .release = releaseHeld };
            var view = try self.catalog.transactionLogView(known.resulting.?, value.target.partition.?, guard_value);
            defer view.deinit();
            const environment = if (self.catalog.log_environment) |capabilities| capabilities.* else c.DirectTransactionLog.Environment{};
            view.clock(environment.clock);
            const checked = try view.verifyPrepared(value, guard_value);
            const preparation = try s.LogTransaction.loadPreparation(self.catalog.data_objects, checked.reference);
            try self.binding.requireSame(preparation.binding);
            try c.DirectTransactionGraph.verifyLog(self.catalog.allocator, self.catalog.data_objects, self.catalog.data_log, preparation);
            if (checked.floor_ms) |floor| self.floor_ms = @max(self.floor_ms orelse 0, floor);
            if (checked.lease_expires_ms) |expires| self.lease_expires_ms = @min(self.lease_expires_ms orelse std.math.maxInt(u64), expires);
            if (checked.append_expires_ms) |expires| self.append_expires_ms = @min(self.append_expires_ms orelse std.math.maxInt(u64), expires);
            if (checked.transfer_not_before_ms) |after| self.transfer_not_before_ms = @max(self.transfer_not_before_ms orelse 0, after);
            self.clock_required = self.clock_required or value.predecessor.log.kind == .queue;
            return;
        }
        _ = try value.predecessor.requirePagedState();
        var view = try self.catalog.transactionView(value.target.object);
        defer view.deinit();
        const reference = view.table.root.transaction orelse return error.TransactionPreparationMissing;
        const preparation = try s.TableTransaction.load(self.catalog.allocator, self.catalog.data_objects, reference);
        try self.binding.requireSame(preparation.binding);
        if (!std.meta.eql(value, try preparation.prepared(reference)) or value.position.next_lsn != view.table.root.next_lsn) return error.InvalidTransactionPreparation;
        try s.TableTransaction.verifyWorkspace(self.catalog.allocator, &view.table.index, view.table.log, preparation.workspace.root, view.table.root.archive);
    }
    fn beforeDecision(raw: *anyopaque) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (!self.clock_required and self.floor_ms == null and self.lease_expires_ms == null and self.append_expires_ms == null and self.transfer_not_before_ms == null) return;
        const environment = self.catalog.log_environment orelse return error.LogTimeUnavailable;
        const now = (try s.LogTime.bounds(environment.clock, self.floor_ms, true)).?;
        if (self.lease_expires_ms) |expires| {
            if (now.earliest_ms >= expires) return error.QueueLeaseExpired;
            if (now.latest_ms >= expires) return error.QueueTimeUnavailable;
        }
        if (self.append_expires_ms) |expires| if (now.latest_ms >= expires) return error.LogRetentionWindowElapsed;
        if (self.transfer_not_before_ms) |after| if (now.earliest_ms < after) return error.QueueTimeUnavailable;
    }
};

pub fn initialize(self: *Self, policy: Policy) !void {
    try self.store.refresh();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const initial: a.Schema = .{ .scope = self.config().scope, .id = self.config().authority.initial_schema, .authorization = self.config().authority.initial_schema_authority, .name = self.config().initial_schema_name, .revision = 1 };
    const current = try self.guard(arena.allocator(), policy, initial, null, .create_schema);
    try check(current);
    if (self.store.root.initialized) return;
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
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
    if (result.object != object or result.partition >= self.store.root.next_partition or (result.resource orelse 0) >= self.store.root.next_lsn or (result.log orelse 0) >= self.store.root.next_lsn) return error.InvalidDirectCatalogEntry;
    return result;
}

fn open(self: *Self, allocator: std.mem.Allocator, target: r.Entry, control: bool) !View {
    return self.openTransaction(allocator, target, control, false);
}

fn openTransaction(self: *Self, allocator: std.mem.Allocator, target: r.Entry, control: bool, transaction_control: bool) !View {
    if (target.resource != null or target.log != null) return error.CatalogKindMismatch;
    const resident = if (control or transaction_control or self.transaction_read != null) null else self.options.table_owner;
    const original_seed = target.seed orelse return error.CatalogRegistrationRequired;
    if (resident) |slot| if (slot.*) |cached| {
        slot.* = null;
        var table = cached.table;
        if (table.root.partition == target.partition and std.meta.eql(cached.seed, original_seed)) {
            errdefer table.deinit();
            try table.refresh();
            const properties = try Properties.decode(allocator, table.declaration.definition.properties);
            return .{ .table = table, .properties = properties, .recovery_state = self.options.table_recovery, .owner_slot = slot, .seed = original_seed };
        }
        table.deinit();
    };
    // Control allocation opens and ordinary data opens never share a hint.
    const slot = if (control) null else self.options.table_recovery;
    const prior = if (slot) |value| value.* else null;
    if (slot) |value| value.* = null;
    var seed = try s.TableDeclaration.load(allocator, self.data_objects, target.seed orelse return error.CatalogRegistrationRequired);
    defer seed.deinit();
    var options = self.options.table;
    options.control = .{ .log = self.store.log, .objects = self.store.objects };
    options.transaction_control = transaction_control;
    options.kind = seed.definition.kind;
    var table = try P.init(if (resident != null) self.allocator else allocator, target.partition, seed.definition, if (control) self.store.log else self.data_log, if (control) self.store.objects else self.data_objects, options);

    errdefer table.deinit();
    if (prior != null and prior.?.root.partition == target.partition and
        std.meta.eql(prior.?.root.interpretation.object, seed.definition.object))
        try table.recoverSince(prior.?)
    else
        try table.recover();
    const properties = try Properties.decode(allocator, table.declaration.definition.properties);
    return .{ .table = table, .properties = properties, .recovery_state = slot, .owner_slot = resident, .seed = original_seed };
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
    return self.resolveState(allocator, namespace_id, name, .table, policy);
}
pub fn resolveKV(self: *Self, allocator: std.mem.Allocator, namespace_id: u64, name: a.Name, policy: Policy) !?View {
    return self.resolveState(allocator, namespace_id, name, .kv, policy);
}
fn resolveState(self: *Self, allocator: std.mem.Allocator, namespace_id: u64, name: a.Name, kind: s.TableDeclaration.Kind, policy: Policy) !?View {
    if (self.transaction_read) |context| {
        if (kind != .table) return error.UnsupportedTransactionParticipant;
        return self.resolveTransactionRead(allocator, context, namespace_id, name, policy);
    }
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
    if (target.seed == null or target.seed.?.kind != kind) {
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
    const required = if (kind == .table) try self.requirements(policy, namespace, view.properties.target(target.object), .inspect) else try self.kvRequirements(policy, namespace, view.properties.target(target.object), .inspect);
    try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
    return view;
}

/// A bounded directory page with independently observed Table versions. Empty
/// filtered pages can have a continuation. Recheck every included object in one
/// native guard before returning any of the page's metadata to its caller.
pub fn list(self: *Self, namespace_id: u64, after: ?pages.Key, policy: Policy) !Page {
    return self.listState(namespace_id, after, .table, policy);
}
pub fn listKV(self: *Self, namespace_id: u64, after: ?pages.Key, policy: Policy) !Page {
    return self.listState(namespace_id, after, .kv, policy);
}
fn listState(self: *Self, namespace_id: u64, after: ?pages.Key, kind: s.TableDeclaration.Kind, policy: Policy) !Page {
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
        if (target.seed == null or target.seed.?.kind != kind) continue;
        var view = try self.open(self.allocator, target, false);
        defer view.deinit();
        if (view.table.root.next_lsn == 0 or view.table.root.retired or view.properties.namespace != namespace_id) continue;
        const required = if (kind == .table) try self.requirements(policy, namespace, view.properties.target(target.object), .inspect) else try self.kvRequirements(policy, namespace, view.properties.target(target.object), .inspect);
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
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
    defer self.store.index.end();
    try c.OperationBinding.claimNamespaceInTree(self.allocator, &self.store.index, binding);
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
        if (target.log) |at| {
            const named = try self.store.logRecord(at);
            if (named.namespace == namespace_id and (named.pending() or (named.phase == .complete and !named.resulting.?.stored.retired))) return .{ .blocked = true, .after = null };
            continue;
        }
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

/// Common current rights and original identity checks for conditional names.
fn assertionRequirements(self: *Self, allocator: std.mem.Allocator, binding: c.NameAssertion.Binding, policy: Policy) !p.Authorization.Guard {
    try self.requireInitialized();
    try binding.validate();
    if (!binding.connection.matches(self.config()) or binding.connection.principal != policy.subject.principal()) return error.CatalogDenied;
    const namespace = try self.schema(binding.namespace);
    var required = try self.requirements(policy, namespace, null, if (binding.action == .create_if_not_exists) .create_table else .schema);
    try check(try policy.make_guard(policy.context, allocator, required, null));
    if (binding.expected) |expected| {
        const allocated = try self.entry(expected.object.object) orelse return error.CatalogDenied;
        if (allocated.seed == null) return error.CatalogDenied;
        var original_view = try self.open(self.allocator, allocated, true);
        defer original_view.deinit();
        if (original_view.properties.namespace != binding.namespace or original_view.table.root.next_lsn == 0) return error.CatalogDenied;
        required = try required.merge(try self.requirements(policy, namespace, original_view.properties.target(allocated.object), .inspect));
        try check(try policy.make_guard(policy.context, allocator, required, null));
    }
    if (try c.OperationBinding.lookupAssertion(self.allocator, self.store.objects, binding.identity())) |known| try binding.requireSame(known);
    return required;
}

fn assertionCondition(self: *Self, allocator: std.mem.Allocator, binding: c.NameAssertion.Binding, required: *p.Authorization.Guard, policy: Policy) !c.NameAssertion.Preview {
    var current = try self.resolve(self.allocator, binding.namespace, binding.name, policy);
    defer if (current) |*view| view.deinit();
    var result: c.NameAssertion.Preview = .{ .binding = binding, .position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn }, .current = null, .matches = false };
    if (current) |view| {
        required.* = try required.merge(try self.requirements(policy, try self.schema(binding.namespace), view.properties.target(view.table.root.interpretation.object.object), .inspect));
        result.current = view.table.root.interpretation;
        result.matches = if (binding.expected) |expected| std.meta.eql(expected, result.current.?) else false;
    } else result.matches = binding.expected == null and try self.available(binding.namespace, binding.name, 0, try policy.make_guard(policy.context, allocator, required.*, null));
    try check(try policy.make_guard(policy.context, allocator, required.*, null));
    return result;
}

/// Observe the current condition without claiming an operation or recording an
/// outcome. A matching preview is not an accepted conditional declaration.
pub fn previewName(self: *Self, binding: c.NameAssertion.Binding, policy: Policy) !c.NameAssertion.Preview {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var required = try self.assertionRequirements(arena.allocator(), binding, policy);
    return self.assertionCondition(arena.allocator(), binding, &required, policy);
}

/// Accept a conditional name outcome under the directory lock without a Table
/// mutation. Inspection and retries recheck the original caller's current rights.
pub fn assertName(self: *Self, binding: c.NameAssertion.Binding, command: c.NameAssertion.Command, policy: Policy) !c.NameAssertion.Observation {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var required = try self.assertionRequirements(arena.allocator(), binding, policy);
    if (try self.store.assertion(binding)) |outcome| {
        try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
        return .{ .outcome = outcome };
    }
    if (command == .inspect) {
        try check(try policy.make_guard(policy.context, arena.allocator(), required, null));
        return .not_observed;
    }
    const matches = command == .accept and (try self.assertionCondition(arena.allocator(), binding, &required, policy)).matches;
    const current_guard = try policy.make_guard(policy.context, arena.allocator(), required, null);
    try check(current_guard);
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
    defer self.store.index.end();
    try c.OperationBinding.claimAssertionInTree(self.allocator, &self.store.index, binding);
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
    if (view) |value| if (value.table.root.kind != request.intent.kind) return error.CatalogKindMismatch;
    const target: ?a.Table = if (view) |value| value.properties.target(request.binding.target.object) else if (request.intent.action == .create) target: {
        const native = try policy.registered(policy.context, request.intent.authorityKind(), request.binding.target.object) orelse break :target null;
        break :target .{ .id = request.binding.target.object, .schema = namespace.id, .authorization = native.reference.id };
    } else return error.CatalogObjectMissing;
    const access: a.Access = switch (request.intent.action) {
        .create => .create_table,
        .alter, .rename => .alter,
        .drop => .drop,
    };
    var requested = if (request.intent.kind == .table)
        try self.requirements(policy, namespace, target, access)
    else
        try self.kvRequirements(policy, namespace, target, if (request.intent.action == .create) .create else .administer);
    if (request.intent.action == .create) requested.selectable = request.intent.action.create.owner;
    return policy.make_guard(policy.context, allocator, requested, if (acceptance) request.binding.prerequisite else null);
}

fn pending(self: *Self, object: u64, current: P.Guard) !bool {
    const value = try self.store.tree().get(self.store.root.pending, try r.idKey(object)) orelse return false;
    const operation = try r.fromValue(d.Operation, self.allocator, value);
    const target = try self.entry(object) orelse return error.InvalidDirectCatalogOperation;
    if (target.log != null) {
        const binding = try c.OperationBinding.lookup(self.allocator, self.store.objects, operation) orelse return error.InvalidDirectCatalogOperation;
        return (try self.store.logOperation(binding) orelse return error.InvalidDirectCatalogOperation).pending();
    }
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
    if (target.log) |at| {
        const named = try self.store.logRecord(at);
        if (named.phase == .complete and !named.resulting.?.stored.retired) {
            const value = named.resulting.?;
            if (value.properties.namespace == namespace and std.meta.eql(value.properties.name, name)) return proposed.object == object;
        }
        const binding = try c.OperationBinding.lookup(self.allocator, self.store.objects, proposed.reservation) orelse return error.InvalidDirectCatalogOperation;
        return !(try self.store.logOperation(binding) orelse return error.InvalidDirectCatalogOperation).pending();
    }
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
    if (try self.store.operation(request.binding)) |observed| {
        try c.OperationBinding.claim(self.allocator, self.store.objects, request.binding);
        try check(current);
        return observed;
    }
    const object = request.binding.target.object;
    const reason = try self.admissionReason(request, known != null, if (existing) |*view| view else null, current);
    const proposed_name = if (request.intent.action == .rename) request.intent.action.rename else request.intent.name;
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
    defer self.store.index.end();
    try c.OperationBinding.claimInTree(self.allocator, &self.store.index, request.binding);
    const content = try IntentStore.stageInTree(self.allocator, &self.store.index, self.config(), request);
    var operation: r.Operation = .{ .binding = request.binding, .intent = content, .phase = .admitted, .reason = .none };
    var next = self.store.root;
    if (reason != .none) {
        operation.phase = .rejected;
        operation.reason = reason;
    } else {
        if (request.intent.action == .create) {
            const target: r.Entry = .{ .object = object, .partition = next.next_partition, .seed = null, .resource = null, .log = null };
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
    const native = try policy.registered(policy.context, request.value.intent.authorityKind(), binding.target.object);
    const fence = try current.acquire(current.context);
    defer current.release(current.context);
    if (native != null) return null;
    if (fence.policy_epoch == 0) return error.InvalidPartitionLease;
    return .{ .action = .{
        .domain = self.config().authority.domain(request.value.intent.authorityKind()),
        .owner = request.value.intent.action.create.owner,
        .schema = a.reference(namespace.authorization),
        .binding = try a.binding(self.config().scope, request.value.intent.authorityKind(), binding.target.object),
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
    const native = try policy.registered(policy.context, request.value.intent.authorityKind(), binding.target.object) orelse return error.CatalogRegistrationRequired;
    try a.validateObject(self.config().authority, self.config().scope, request.value.intent.authorityKind(), binding.target.object, a.reference(namespace.authorization), native);
    if (native.owner != request.value.intent.action.create.owner) return error.CatalogIdentityConflict;
    const properties: Properties = .{ .namespace = namespace.id, .authorization = native.reference.id, .name = request.value.intent.name };
    var bytes: [s.TableDeclaration.max_properties_bytes]u8 = undefined;
    var declaration = try s.TableDeclaration.prepare(self.allocator, .{ .kind = request.value.intent.kind, .object = binding.target, .revision = 1, .schema = request.value.intent.action.create.schema, .properties = try properties.encode(&bytes) });
    defer declaration.deinit();
    target.seed = try s.TableDeclaration.stage(self.store.objects, &declaration);
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
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
            error.IbmHfpUnderflow, error.IbmHfpOverflow, error.UnrepresentableEbcdic037, error.UnrepresentableEbcdic1047 => .constraint,
            else => return err,
        };
        try self.terminal(observed.admitted, .rejected, reason, current);
        return self.status(binding, policy);
    };
    // No catalog publication is needed for visibility or the accepted result.
    // A later explicit settlement only removes the pending-work directory entry.
    return .{ .committed = .{ .binding = binding, .resulting = view.table.root.declared(), .outcome = outcome, .transaction = null } };
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
        if (try self.logRecord(object.object)) |known| {
            const value = known.resulting orelse return error.CatalogDenied;
            const namespace = try self.authorizationSchema(value.properties.namespace);
            _ = try self.requirements(policy, namespace, null, .schema);
            try self.verifiedObject(policy, L.authorityKind(value.kind()), object.object, value.properties.authorization, a.reference(namespace.authorization));
            return c.LogAuthority.requirements(self.config().authority, policy.subject, namespace, value.properties.target(object.object), if (write) .administer else .inspect);
        }
        if (try self.entry(object.object)) |target| if (target.seed) |seed| {
            if (seed.kind != .kv) return error.CatalogKindMismatch;
            var view = try self.open(self.allocator, target, false);
            defer view.deinit();
            return self.kvRequirements(policy, try self.authorizationSchema(view.properties.namespace), view.properties.target(object.object), if (write) .administer else .inspect);
        };
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
    if (dependent.kind == .stream or dependent.kind == .queue) {
        const known = try self.logRecord(object.object) orelse return false;
        const value = known.resulting orelse return false;
        return known.phase == .complete and !value.stored.retired and
            (dependent.kind == .queue) == (value.kind() == .queue) and std.meta.eql(dependent.interpretation, value.stored.declaration.interpretation);
    }
    if (dependent.kind == .kv) {
        const target = try self.entry(object.object) orelse return false;
        if (target.seed == null or target.seed.?.kind != .kv) return false;
        var view = try self.open(self.allocator, target, false);
        defer view.deinit();
        return view.table.root.next_lsn != 0 and !view.table.root.retired and std.meta.eql(dependent.interpretation, view.table.root.interpretation);
    }
    const known = try self.namedRecord(object.object) orelse return false;
    if ((known.phase != .allocated and known.phase != .complete) or known.retired) return false;
    const value = known.resulting.?;
    if (dependent.kind != .document) return false;
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
    if (target.log) |at| {
        const known = try self.store.logRecord(at);
        const value = known.resulting orelse return error.CatalogDenied;
        const namespace = try self.authorizationSchema(value.properties.namespace);
        _ = try self.requirements(policy, namespace, null, .schema);
        try self.verifiedObject(policy, L.authorityKind(value.kind()), object.object, value.properties.authorization, a.reference(namespace.authorization));
        var required = try c.LogAuthority.requirements(self.config().authority, policy.subject, namespace, value.properties.target(object.object), .inspect);
        if (privileges & ~c.LogAuthority.all_privileges != 0) return error.InvalidCatalogDependency;
        if (privileges != 0) required.requirements[2].?.privileges = privileges;
        return .{ .interpretation = value.stored.declaration.interpretation, .live = known.phase == .complete and !value.stored.retired, .requirements = required };
    }
    if (target.resource) |at| {
        const known = try self.store.resourceRecord(at);
        const value = known.resulting orelse return error.CatalogDenied;
        if (!std.meta.eql(value.object, object)) return error.InvalidDirectCatalogEntry;
        // SELECT is the shared logical read requirement. It maps to native
        // INSPECT/READ for named Document data; row mutation masks are not
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
    const seed = target.seed orelse return error.CatalogDenied;
    const allowed = if (seed.kind == .kv) c.KVAuthority.all_privileges else a.table_actions;
    if (privileges & ~allowed != 0) return error.InvalidCatalogDependency;
    var view = try self.open(self.allocator, target, false);
    defer view.deinit();
    const namespace = try self.authorizationSchema(view.properties.namespace);
    var requested = if (seed.kind == .kv)
        try self.kvRequirements(policy, namespace, view.properties.target(object.object), .inspect)
    else
        try self.requirements(policy, namespace, view.properties.target(object.object), .inspect);
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

pub fn dependencyState(self: *Self, edge: Dependency.Edge, policy: Policy) !Dependency.State {
    try self.requireInitialized();
    try edge.validate();
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const source = try self.dependencySource(edge.source.object, policy, 0);
    const required = try source.requirements.merge(try self.dependentRequirements(policy, edge.dependent.interpretation.object, false));
    const current = try policy.make_guard(policy.context, arena.allocator(), required, null);
    try check(current);
    const result: Dependency.State = .{ .edge = edge, .position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn }, .present = try self.dependencyEdge(edge) != null };
    try check(current);
    return result;
}

/// One bounded catalog acceptance updates both directions and its exact receipt.
/// Register requires current source actions and dependent metadata write access.
/// Remove/cancel can close an explicitly known edge after source rights change;
/// they require dependent write access, never infer permission from PID ownership.
pub fn dependencyOperation(self: *Self, binding: Dependency.Binding, command: Dependency.Command, policy: Policy) !Dependency.Observation {
    try self.requireInitialized();
    try binding.validate();
    // Queue declaration edges also retain historical routing. Removing one
    // requires the Queue's closure/retention proof, not generic graph editing.
    if (binding.action == .remove and binding.edge.dependent.kind == .queue) return error.QueueDependencyRetained;
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
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
    defer self.store.index.end();
    try c.OperationBinding.claimDependencyInTree(self.allocator, &self.store.index, binding);
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
pub fn previewRows(self: *Self, request: s.TableDmlIntent.Request, policy: Policy) !RowPreview {
    try self.requireInitialized();
    try self.original(policy, request.binding);
    try request.validate();
    const target = try self.entry(request.binding.target.object) orelse return error.CatalogDenied;
    var view = try self.open(self.allocator, target, false);
    defer view.deinit();
    if (view.table.root.kind != .table) return error.CatalogKindMismatch;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const namespace = try self.authorizationSchema(view.properties.namespace);
    const access: a.Access = switch (request.binding.action) {
        .insert => .insert,
        .update => .update,
        .delete => .delete,
        else => return error.UnsupportedTableAction,
    };
    const required = try (try self.requirements(policy, namespace, view.properties.target(target.object), access)).merge(try self.requirements(policy, namespace, view.properties.target(target.object), .inspect));
    const current = try policy.make_guard(policy.context, arena.allocator(), required, request.binding.prerequisite);
    try check(current);
    if (try c.OperationBinding.lookup(self.allocator, self.data_objects, request.binding.identity)) |known| try request.binding.requireSame(known);
    var result: RowPreview = .{
        .binding = request.binding,
        .directory_position = .{ .partition = self.config().partition, .next_lsn = self.store.root.next_lsn },
        .current = .{ .interpretation = view.table.root.declared(), .position = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn }, .changed_lsn = view.table.root.changed_lsn, .row_count = view.table.root.live_rows },
        .reason = .none,
    };
    view.table.checkExpectations(request.binding, current) catch |err| switch (err) {
        error.TableDefinitionChanged => result.reason = .stale_definition,
        error.TableDataChanged => result.reason = .stale_data,
        error.TableRetired, error.TableNotCreated => result.reason = .object_conflict,
        else => return err,
    };
    if (result.reason == .none) {
        if (!std.meta.eql(request.interpretation, result.current.interpretation)) return error.TableSchemaChanged;
        if (try self.pending(target.object, current)) result.reason = .object_conflict;
    }
    try check(current);
    return result;
}

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
    try request.validate();
    return self.rowOperation(request.binding, .commit, request, policy);
}

fn rowOperation(self: *Self, binding: d.Binding, action: enum { admit, commit, perform, status, cancel }, request: ?s.TableDmlIntent.Request, policy: Policy) !P.OperationState {
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
    if (view.table.root.kind != .table) return error.CatalogKindMismatch;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const required = try self.requirements(policy, try self.authorizationSchema(view.properties.namespace), view.properties.target(target.object), access);
    const current = try policy.make_guard(policy.context, arena.allocator(), required, if (action == .admit or action == .commit or action == .perform) binding.prerequisite else null);
    try check(current);
    if (action == .admit or action == .commit) {
        try c.OperationBinding.claim(self.allocator, self.data_objects, binding);
        if (try view.table.operationState(binding, current) == .not_observed and try self.pending(target.object, current)) return error.CatalogObjectBusy;
    }
    view.table.lose_reply = self.lose_table_reply;
    return switch (action) {
        .admit => view.table.admit(request.?, current),
        .commit => view.table.commit(request.?, current),
        .perform => view.table.perform(binding, current),
        .status => view.table.operationState(binding, current),
        .cancel => view.table.cancel(binding, current),
    };
}

pub const KVAccess = struct { view: View, current: P.Guard };

/// Borrow the common state owner under the KV domain's current policy. The
/// host serializes access with publication and returns/destroys the owned view.
pub fn kvAccess(self: *Self, allocator: std.mem.Allocator, object: d.Object, access: c.KVAuthority.Access, control: bool, prerequisite: ?p.Authorization.Guard, policy: Policy) !KVAccess {
    try self.requireInitialized();
    try object.validate();
    if (!std.meta.eql(object.scope, self.config().scope) or object.branch != self.config().branch) return error.CatalogDenied;
    const target = try self.entry(object.object) orelse return error.CatalogDenied;
    if (target.seed == null) return error.CatalogDenied;
    if (target.seed.?.kind != .kv) return error.CatalogKindMismatch;
    var view = try self.open(self.allocator, target, control);
    errdefer view.deinit();
    _ = try s.KVDeclaration.fromPhysical(view.table.declaration.definition);
    const required = try self.kvRequirements(policy, try self.authorizationSchema(view.properties.namespace), view.properties.target(object.object), access);
    const current = try policy.make_guard(policy.context, allocator, required, prerequisite);
    try check(current);
    if (view.table.root.next_lsn == 0) return error.CatalogRegistrationRequired;
    if (self.transaction_read) |context| {
        if (access != .read) return error.UnsupportedTransactionRead;
        try self.overlayTransactionRead(&view, context, current, policy);
    }
    return .{ .view = view, .current = current };
}

pub fn kvReady(self: *Self, object: d.Object, current: P.Guard) !void {
    if (try self.pending(object.object, current)) return error.CatalogObjectBusy;
}

const SnapshotAccess = struct { view: View, current: P.Guard };
pub const StorageObservation = struct {
    interpretation: s.TableDeclaration.Stored,
    position: d.Position,
    changed_lsn: u64,
    live_rows: u64,
    pending: struct { rows: u64, bytes: u64, complete: bool, oldest_lsn: ?u64 },
    archive_through: u64,
    recovery_through: ?u64,
    history_floor: u64,
    next_segment: u64,
    maintenance: @FieldType(P.Root, "maintenance"),
};
pub const FlushTarget = struct { object: d.Object, through: d.Position };
pub const FlushObservation = struct { target: FlushTarget, observed: StorageObservation, complete: bool };

fn storageAccess(self: *Self, allocator: std.mem.Allocator, object: d.Object, policy: Policy, write: bool) !SnapshotAccess {
    try self.requireInitialized();
    try object.validate();
    if (!std.meta.eql(object.scope, self.config().scope) or object.branch != self.config().branch) return error.CatalogDenied;
    const target = try self.entry(object.object) orelse return error.CatalogDenied;
    if (target.seed == null) return error.CatalogDenied;
    var view = try self.open(self.allocator, target, false);
    errdefer view.deinit();
    if (view.table.root.kind != .table) return error.CatalogKindMismatch;
    const current = try self.guard(allocator, policy, try self.authorizationSchema(view.properties.namespace), view.properties.target(object.object), if (write) .alter else .inspect);
    try check(current);
    if (view.table.root.next_lsn == 0) return error.CatalogRegistrationRequired;
    return .{ .view = view, .current = current };
}
fn storageState(view: *View, limit: u16, guard_value: P.Guard) !StorageObservation {
    const backlog = try view.table.pendingRows(limit, guard_value);
    const root = view.table.root;
    return .{
        .interpretation = root.declared(),
        .position = .{ .partition = root.partition, .next_lsn = root.next_lsn },
        .changed_lsn = root.changed_lsn,
        .live_rows = root.live_rows,
        .pending = .{ .rows = backlog.rows, .bytes = backlog.bytes, .complete = backlog.complete, .oldest_lsn = backlog.oldest_lsn },
        .archive_through = root.archive.through,
        .recovery_through = if (root.recovery) |known| known.next_lsn else null,
        .history_floor = root.history_floor,
        .next_segment = root.next_segment,
        .maintenance = root.maintenance,
    };
}
pub fn inspectStorage(self: *Self, object: d.Object, limit: u16, policy: Policy) !StorageObservation {
    var arena: std.heap.ArenaAllocator = .init(self.allocator);
    defer arena.deinit();
    var selected = try self.storageAccess(arena.allocator(), object, policy, false);
    defer selected.view.deinit();
    return storageState(&selected.view, limit, selected.current);
}
/// Execute one bounded physical unit against the caller's saved exclusive cut.
/// Repeating the same target after uncertainty observes accepted coverage; it
/// does not enqueue another request or choose a new cut. Automatic scheduling
/// can independently satisfy this target. No logical receipt or pin is created.
pub fn flushStorage(self: *Self, target: FlushTarget, policy: Policy) !FlushObservation {
    try target.through.validate();
    var arena: std.heap.ArenaAllocator = .init(self.allocator);
    defer arena.deinit();
    var selected = try self.storageAccess(arena.allocator(), target.object, policy, true);
    defer selected.view.deinit();
    if (target.through.partition != selected.view.table.root.partition) return error.InvalidTableBasis;
    selected.view.table.lose_reply = self.lose_table_reply;
    _ = try selected.view.table.flushThroughRows(target.through.next_lsn, (p.Storage.Flush{}).work_rows, selected.current);
    const observed = try storageState(&selected.view, 1, selected.current);
    return .{ .target = target, .observed = observed, .complete = observed.pending.oldest_lsn == null or observed.pending.oldest_lsn.? >= target.through.next_lsn };
}

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
    if (view.table.root.kind != .table) return error.CatalogKindMismatch;
    const current = try self.guard(allocator, policy, try self.authorizationSchema(view.properties.namespace), view.properties.target(object.object), .read);
    try check(current);
    if (self.transaction_read) |context| try self.overlayTransactionRead(&view, context, current, policy);
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
    try self.requireUnreservedBranchPin(interpretation.object, owner);
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
    try self.requireUnreservedBranchPin(object, owner);
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, owner, policy, false);
    defer access.view.deinit();
    if (access.view.table.workspace_read) |read| {
        if (retention != .snapshot or !std.meta.eql(owner, read.cut.begin.identity.begin) or
            !std.meta.eql(expected, read.source.source.accepted)) return error.InvalidTransactionRead;
        if (interpretation) |required| if (!std.meta.eql(required, read.source.source.interpretation)) return error.TableDefinitionChanged;
        try check(access.current);
        return .{ .owner = owner, .content = read.private };
    }
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

/// Resolve the selected history point without reopening/recovering the same
/// Table for authority metadata. The dispatcher checks original grants first.
pub fn historyRead(self: *Self, allocator: std.mem.Allocator, object: d.Object, lease: P.SnapshotHandle, point: ?P.HistoryPoint, policy: Policy) !HistoryRead {
    if (point) |required| if (!std.meta.eql(lease, required.lease)) return error.DataIdentityConflict;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, lease.owner, policy, false);
    defer access.view.deinit();
    var definition = if (point) |required| try access.view.table.historyAt(allocator, required, access.current) else try access.view.table.historyStart(allocator, lease, access.current);
    errdefer definition.deinit();
    return .{ .definition = definition, .authority = try self.sourceAuthority(&access) };
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
    if (access.view.table.workspace_read) |read| {
        if (!std.meta.eql(owner, read.cut.begin.identity.begin)) return error.InvalidTransactionRead;
        return .{ .interpretation = read.source.source.interpretation, .position = read.source.source.accepted, .retired = false, .handle = .{ .owner = owner, .content = read.private }, .released = false };
    }
    return access.view.table.pinState(owner, access.current);
}

pub fn snapshotDefinition(self: *Self, allocator: std.mem.Allocator, object: d.Object, handle: P.SnapshotHandle, policy: Policy) !P.SnapshotDefinition {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, handle.owner, policy, false);
    defer access.view.deinit();
    return access.view.table.inspectSnapshot(allocator, handle, access.current);
}

pub fn snapshotRead(self: *Self, allocator: std.mem.Allocator, object: d.Object, handle: P.SnapshotHandle, policy: Policy) !SnapshotRead {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, handle.owner, policy, false);
    defer access.view.deinit();
    var definition = try access.view.table.inspectSnapshot(allocator, handle, access.current);
    errdefer definition.deinit();
    return .{ .definition = definition, .authority = try self.sourceAuthority(&access) };
}

fn sourceAuthority(self: *Self, access: *const SnapshotAccess) !c.DirectReadAuthority {
    const namespace = try self.authorizationSchema(access.view.properties.namespace);
    const result: c.DirectReadAuthority = .{ .database = self.config().authority.database, .schema = namespace.authorization, .table = access.view.properties.authorization };
    try result.validate();
    try check(access.current);
    return result;
}

/// Resolve exactly the native objects whose current rights guard this source.
/// This does not grant access or acquire a pin. A computation uses these same
/// references in its own native publication guard after reading direct rows.
pub fn readAuthority(self: *Self, object: d.Object, owner: d.Operation, policy: Policy, control: bool) !c.DirectReadAuthority {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, owner, policy, control);
    defer access.view.deinit();
    return self.sourceAuthority(&access);
}

/// Current rights for retained evidence are independent of live definition and
/// pin state. This reads the stable object, including after DROP/name reuse; it
/// creates no acquisition and returns no rows or replacement definition.
pub fn currentReadAuthority(self: *Self, object: d.Object, policy: Policy) !c.DirectReadAuthority {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.readAccess(arena.allocator(), object, policy, false);
    defer access.view.deinit();
    return self.sourceAuthority(&access);
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

pub fn scanColumns(self: *Self, allocator: std.mem.Allocator, object: d.Object, handle: P.SnapshotHandle, columns: []const u8, after: ?P.SnapshotCursor, limits: P.ReadLimits, policy: Policy) !P.SnapshotPage {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, handle.owner, policy, false);
    defer access.view.deinit();
    return access.view.table.scanSnapshotColumns(allocator, handle, columns, after, limits, access.current);
}

pub fn scanFiltered(self: *Self, allocator: std.mem.Allocator, object: d.Object, handle: P.SnapshotHandle, plan: c.fuze.LogicalQuery.Plan, after: ?P.SnapshotCursor, limits: P.ReadLimits, policy: Policy) !P.FilteredPage {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, handle.owner, policy, false);
    defer access.view.deinit();
    return access.view.table.scanSnapshotFiltered(allocator, handle, plan, after, limits, access.current);
}

pub fn releaseRows(self: *Self, object: d.Object, handle: P.SnapshotHandle, policy: Policy) !void {
    try self.requireUnreservedBranchPin(object, handle.owner);
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, handle.owner, policy, true);
    defer access.view.deinit();
    if (access.view.table.workspace_read) |read| {
        if (!std.meta.eql(handle.owner, read.cut.begin.identity.begin) or !std.meta.eql(handle.content, read.private)) return error.InvalidTransactionRead;
        return check(access.current);
    }
    return access.view.table.releaseSnapshot(handle, access.current);
}

pub fn rangeRows(self: *Self, allocator: std.mem.Allocator, object: d.Object, handle: P.SnapshotHandle, interval: P.KeyRange, after: ?P.KeyRange.Cursor, limits: P.ReadLimits, policy: Policy) !P.KeyRangePage {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var access = try self.snapshotAccess(arena.allocator(), object, handle.owner, policy, false);
    defer access.view.deinit();
    return access.view.table.rangeSnapshot(allocator, handle, interval, after, limits, access.current);
}

fn terminal(self: *Self, previous: r.Operation, phase: r.Phase, reason: r.Reason, current: P.Guard) !void {
    var index_batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &index_batch);
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

fn branchGuard(self: *Self, allocator: std.mem.Allocator, intent: c.DirectBranch.Intent, policy: Policy, create: bool) !P.Guard {
    try intent.validate();
    if (!intent.connection.matches(self.config()) or intent.connection.principal != policy.subject.principal()) return error.CatalogDenied;
    var access = try self.readAccess(allocator, intent.source.interpretation.object, policy, false);
    defer access.view.deinit();
    if (access.view.table.root.declared().kind != .table) return error.CatalogKindMismatch;
    if (access.view.properties.namespace != intent.namespace) return error.BranchIdentityConflict;
    const namespace = try self.authorizationSchema(intent.namespace);
    var requested = try self.requirements(policy, namespace, access.view.properties.target(intent.source.interpretation.object.object), .read);
    if (create) requested = try requested.merge(try self.requirements(policy, try self.schema(intent.namespace), null, .create_table));
    return policy.make_guard(policy.context, allocator, requested, null);
}

fn prepareBranchAdmission(self: *Self, intent: c.DirectBranch.Intent, policy: Policy) !void {
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    try check(try self.branchGuard(scratch.allocator(), intent, policy, true));
    if (try self.store.tree().get(self.store.root.branch_names, try r.nameKey(intent.namespace, intent.name)) != null) return error.BranchNameConflict;
    var access = try self.snapshotAccess(scratch.allocator(), intent.source.interpretation.object, intent.identity(), policy, false);
    defer access.view.deinit();
    const root = access.view.table.root;
    if (root.retired or root.transaction != null or !std.meta.eql(root.interpretation, intent.source.interpretation) or
        root.partition != intent.source.accepted.partition or root.next_lsn != intent.source.accepted.next_lsn) return error.BranchSourceChanged;
    // An unrelated pin using this identity cannot be adopted as branch work.
    if ((try access.view.table.pinState(intent.identity(), access.current)).handle != null) return error.DataIdentityConflict;
}

fn requireUnreservedBranchPin(self: *Self, object: d.Object, owner: d.Operation) !void {
    try self.requireInitialized();
    try owner.validate();
    if (!std.meta.eql(owner.scope, self.config().scope)) return error.DataIdentityConflict;
    const value = try self.store.tree().get(self.store.root.branch_owners, try r.operationKey(owner)) orelse return;
    const progress = try self.store.branchByDigest(value);
    // Ordinary multi-source readers can use one owner on several Tables.
    // Only this branch's original source pin belongs to its retention owner.
    if (std.meta.eql(object, progress.receipt.binding.intent.branch.source.interpretation.object)) return error.BranchRetentionOwned;
}

fn branchProgress(self: *Self, key: c.DirectClientToken.Key, policy: Policy) !?c.DirectClientToken.Progress {
    const progress = (try self.clientProgress(.{ .inspect = key }, policy)).state orelse return null;
    if (progress.receipt.binding.intent != .branch) return error.BranchOperationRequired;
    return progress;
}
fn branchStatus(self: *Self, progress: c.DirectClientToken.Progress) !c.DirectBranch.Status {
    return .{ .receipt = progress.receipt, .revision = progress.revision, .state = try c.DirectBranch.State.load(self.allocator, self.store.objects, progress) };
}

/// Host excludes database publication for creation/advance/cancel, as for
/// transaction cut acquisition. Admission reserves only the name and identity.
pub fn createBranch(self: *Self, request: @FieldType(c.DirectBranch.Request, "create"), policy: Policy) !c.DirectBranch.Status {
    const binding: c.DirectClientToken.Binding = .{ .key = request.key, .fingerprint = try request.intent.digest(), .intent = .{ .branch = request.intent }, .budget = request.budget };
    _ = try self.clientToken(.{ .bind = binding }, policy);
    return self.advanceBranch(request.key, false, policy);
}

fn publishBranchState(self: *Self, progress: *c.DirectClientToken.Progress, state: c.DirectBranch.State, current: P.Guard) !void {
    var next = self.store.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    var updated = progress.*;
    updated.revision = .{ .partition = self.config().partition, .next_lsn = next.next_lsn };
    updated.pending = state.phase == .admitted or state.phase == .abandoning;
    updated.cancel = state.phase == .abandoning or state.phase == .cancelled;
    updated.record = try state.stage(self.store.objects, updated);
    var batch: s.TreeStore.Batch = .{};
    try self.store.index.beginBatch(self.options.index_work_bytes, &batch);
    defer self.store.index.end();
    try self.store.clientIndices(&next, updated);
    try self.store.publish(next, .{ .client_token = updated }, current);
    progress.* = updated;
}

pub fn advanceBranch(self: *Self, key: c.DirectClientToken.Key, cancel_requested: bool, policy: Policy) !c.DirectBranch.Status {
    var progress = try self.branchProgress(key, policy) orelse return error.ClientOperationMissing;
    var state = (try self.branchStatus(progress)).state;
    if (state.phase == .published or state.phase == .cancelled) return self.branchStatus(progress);
    const intent = progress.receipt.binding.intent.branch;
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    const current = try self.branchGuard(scratch.allocator(), intent, policy, !cancel_requested and state.phase != .abandoning);
    try check(current);
    if (cancel_requested and state.phase == .admitted) {
        state.phase = .abandoning;
        try self.publishBranchState(&progress, state, current);
    }
    var access = try self.snapshotAccess(scratch.allocator(), intent.source.interpretation.object, intent.identity(), policy, false);
    defer access.view.deinit();
    const pin_state = try access.view.table.pinState(intent.identity(), access.current);
    access.view.table.lose_reply = self.lose_table_reply;
    if (state.phase == .abandoning) {
        if (pin_state.handle) |pin| if (!pin_state.released) try access.view.table.releaseSnapshot(pin, current);
        state.phase = .cancelled;
        try self.publishBranchState(&progress, state, current);
        try check(current);
        return self.branchStatus(progress);
    }
    var epoch: ?P.Guard.Fence = null;
    var fenced: CutFence = .{ .underlying = current, .epoch = &epoch };
    const pin = if (pin_state.handle) |pin| blk: {
        if (pin_state.released) return error.TableSnapshotReleased;
        break :blk pin;
    } else try access.view.table.pin(intent.identity(), intent.source.accepted, fenced.guard());
    var frozen = try access.view.table.inspectSnapshot(self.allocator, pin, fenced.guard());
    defer frozen.deinit();
    const source: d.SourceCut = .{ .interpretation = frozen.root.interpretation, .manifest = null, .checkpoint_lsn = 0, .accepted = frozen.position() };
    if (frozen.root.retired or !std.meta.eql(source, intent.source)) return error.BranchSourceChanged;
    var directory = try s.BranchSnapshot.init(self.allocator, self.data_objects, state.branch, intent.identity(), 1, self.options.resident_pages, self.options.index_work_bytes);
    defer directory.deinit();
    try directory.put(.{ .source = source, .pin = pin });
    const reference = try directory.stageManifest(.{
        .definition = p.Growth.current_definition,
        .identity = state.branch,
        .version = 1,
        // An explicit single-Table projection has no claim to a complete main
        // branch history. Its genesis retains the exact source attribution.
        .kind = .genesis,
        .mode = intent.mode,
        .catalog = progress.receipt.position,
        .objects = try directory.seal(),
        .retention_owner = intent.identity(),
        .parent = null,
        .merge_parent = null,
        .restored_from = null,
    });
    state.phase = .published;
    state.head = .{ .reference = reference, .generation = 1 };
    try self.publishBranchState(&progress, state, fenced.guard());
    try check(fenced.guard());
    return self.branchStatus(progress);
}

pub fn inspectBranch(self: *Self, key: c.DirectClientToken.Key, policy: Policy) !?c.DirectBranch.Status {
    return try self.branchStatus(try self.branchProgress(key, policy) orelse return null);
}
pub fn lookupBranch(self: *Self, namespace: u64, name: a.Name, policy: Policy) !?c.DirectBranch.Status {
    try self.requireInitialized();
    var scratch = std.heap.ArenaAllocator.init(self.allocator);
    defer scratch.deinit();
    const current = try self.guard(scratch.allocator(), policy, try self.authorizationSchema(namespace), null, .schema);
    try check(current);
    const value = try self.store.tree().get(self.store.root.branch_names, try r.nameKey(namespace, name)) orelse {
        try check(current);
        return null;
    };
    const progress = try self.store.branchByDigest(value);
    const intent = progress.receipt.binding.intent.branch;
    if (intent.namespace != namespace or !std.meta.eql(intent.name, name)) return error.InvalidBranchState;
    const checked = try self.branchProgress(progress.receipt.binding.key, policy) orelse return error.InvalidBranchState;
    const observed = try self.branchStatus(checked);
    try check(current);
    return if (observed.state.phase == .published) observed else null;
}

pub const BranchRead = struct {
    access: SnapshotAccess,
    entry: s.BranchSnapshot.Entry,
    mode: p.Branch.Mode,
    pub fn deinit(self: *BranchRead) void {
        self.access.view.deinit();
    }
};
/// The head is exact and current rights apply to the original source object.
/// No branch grant, execution binding or newer source is inferred from a name.
pub fn openBranch(self: *Self, scratch: std.mem.Allocator, head: p.Branch.Head, policy: Policy) !BranchRead {
    try self.requireInitialized();
    try head.validate();
    try head.reference.identity.requireScope(self.config().scope);
    const progress = try self.store.branchById(head.reference.identity.branch) orelse return error.BranchNotFound;
    const intent = progress.receipt.binding.intent.branch;
    const checked = try self.branchProgress(progress.receipt.binding.key, policy) orelse return error.InvalidBranchState;
    const observed = try self.branchStatus(checked);
    try (observed.state.head orelse return error.BranchNotPublished).requireSame(head);
    const manifest = try s.BranchSnapshot.loadManifest(self.data_objects, head.reference);
    if (manifest.kind != .genesis or manifest.mode != intent.mode or !std.meta.eql(manifest.catalog, progress.receipt.position) or !std.meta.eql(manifest.retention_owner, intent.identity())) return error.InvalidBranchState;
    var directory = try s.BranchSnapshot.init(self.allocator, self.data_objects, observed.state.branch, intent.identity(), 1, self.options.resident_pages, self.options.index_work_bytes);
    defer directory.deinit();
    try directory.restore(manifest.objects);
    const entry_value = try directory.get(intent.source.interpretation.object.object) orelse return error.IncompleteBranchDirectory;
    if (directory.root.count != 1 or !std.meta.eql(entry_value.source, intent.source)) return error.InvalidBranchState;
    try directory.verifyEntry(self.allocator, entry_value);
    var access = try self.snapshotAccess(scratch, intent.source.interpretation.object, intent.identity(), policy, false);
    errdefer access.view.deinit();
    var pinned = try access.view.table.inspectSnapshot(self.allocator, entry_value.pin, access.current);
    defer pinned.deinit();
    return .{ .access = access, .entry = entry_value, .mode = intent.mode };
}
