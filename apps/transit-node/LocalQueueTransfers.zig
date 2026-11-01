//! Automatic DLQ composition over the catalog's protected transaction owner.
//! Native maintenance permits discovery; an explicitly configured database
//! signer supplies current application rights. Neither authority implies the other.
const std = @import("std");
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Host = @import("LocalTableHost.zig");
const Native = @import("LocalMaintenanceAuthority.zig");
const Policy = @import("LocalCatalogPolicy.zig");
const p = c.protocol;
const Q = c.storage.QueuePartition;
const Plan = c.DirectQueueTransferPlan;
const Self = @This();

pub const Config = struct {
    principal: u64,
    seed_file: []const u8,
    role: ?u64 = null,
    account: [32]u8,
    limits: p.Transaction.Limits,
    budget: c.DirectClientToken.Budget,
    pub fn validate(self: Config, maximum: p.Transaction.Limits) !void {
        try c.Model.nativeId(self.principal);
        if (self.role) |role| try p.Authorization.roleId(role);
        if (self.seed_file.len == 0 or std.mem.allEqual(u8, &self.account, 0) or
            self.limits.participants != 2 or self.limits.statements != 1) return error.InvalidQueueTransferConfiguration;
        try self.limits.validate();
        try c.DirectTransaction.requireLimits(self.limits, maximum);
        try self.budget.validate();
        if (self.budget.bytes < Plan.max_bytes) return error.InvalidQueueTransferConfiguration;
    }
};
pub const Identity = struct {
    principal: u64,
    key: p.Ed25519.KeyPair,
    role: ?u64,
    account: [32]u8,
    limits: p.Transaction.Limits,
    budget: c.DirectClientToken.Budget,
    fn connection(self: Identity, host: *Host) c.DirectTableProtocol.Connection {
        return .{ .scope = host.configuration.scope, .branch = host.configuration.branch, .audience = host.configuration.audience, .principal = self.principal, .role = self.role };
    }
};

const Workspace = struct {
    allocator: std.mem.Allocator,
    control: backend.DataStore,
    data: backend.DataStore,
    queue: Q,
    fn create(allocator: std.mem.Allocator, native: *backend.Backend, initial: c.storage.LogInitialization.Request, guard: c.storage.PublicationGuard) !*Workspace {
        const self = try allocator.create(Workspace);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .control = .{ .backend = native, .control = true }, .data = .{ .backend = native }, .queue = undefined };
        self.queue = try Q.open(allocator, self.data.log(), self.data.objects(), initial, guard, .{ .control = .{ .log = self.control.log(), .objects = self.control.objects() } });
        return self;
    }
    fn destroy(self: *Workspace) void {
        self.queue.deinit() catch unreachable;
        self.allocator.destroy(self);
    }
};

next: enum { recovery, discovery } = .recovery,
pending_after: ?[32]u8 = null,
objects: c.DirectCatalog.LogMaintenanceCursor = .{},
target: ?c.DirectCatalog.LogMaintenanceTarget = null,
cursor: ?Q.DeadLetterCursor = null,
workspace: ?*Workspace = null,
last_object: ?u64 = null,
last_rows: usize = 0,

pub fn deinit(self: *Self) void {
    self.clear();
    self.* = .{};
}
fn clear(self: *Self) void {
    if (self.workspace) |workspace| workspace.destroy();
    self.workspace = null;
    self.target = null;
    self.cursor = null;
}

pub fn step(self: *Self, allocator: std.mem.Allocator, host: *Host, engine: *backend.DataAuthority.Engine, signed: p.Growth.SignedRequest) !bool {
    self.last_object = null;
    self.last_rows = 0;
    const identity = host.queue_transfers orelse return false;
    const native = engine.journal.backend;
    const io = native.io;
    // This precedes every source lock and excludes collection. No shared-lock
    // upgrade is attempted from a physical Queue maintenance unit.
    try host.directory.lock(io);
    defer host.directory.unlock(io);
    var authority: Native = .{ .engine = engine, .signed = signed, .resource = host.configuration.scope.resource };
    const guard = authority.guard();
    _ = try guard.acquire(guard.context);
    guard.release(guard.context);
    var control: backend.DataStore = .{ .backend = native, .control = true };
    var data: backend.DataStore = .{ .backend = native };
    var catalog = try c.DirectCatalog.init(allocator, host.configuration, control.log(), control.objects(), data.log(), data.objects(), host.options);
    defer catalog.deinit();
    try host.recovery_mutex.lock(io);
    const prior = host.recovery;
    host.recovery_mutex.unlock(io);
    try catalog.recoverSince(prior);
    defer {
        // A failed append keeps the old valid prefix, never a guessed success.
        if (catalog.recoveryState()) |recovered| {
            host.recovery_mutex.lockUncancelable(io);
            host.recovery = recovered;
            host.recovery_mutex.unlock(io);
        } else |_| {}
        host.notifyLogs();
    }
    if (!catalog.store.root.initialized) return false;
    const context = try contextDigest(identity.connection(host), identity.account);
    const proof = try databaseProof(engine, host, identity, context);
    var policy = try Policy.init(engine, host.configuration, proof, context, null);
    policy.paged = true;
    var environment: c.DirectTransactionLog.Environment = .{ .clock = @import("LocalLogClock.zig").source(engine) };
    catalog.log_environment = &environment;
    defer catalog.log_environment = null;
    const selected = self.next;
    self.next = if (selected == .recovery) .discovery else .recovery;
    const worked = switch (selected) {
        .recovery => try self.recoverOne(&catalog, identity, host, &policy, guard),
        .discovery => try self.discoverOne(allocator, &catalog, identity, host, engine, &policy, guard),
    };
    _ = try policy.check();
    return worked;
}

fn databaseProof(engine: *backend.DataAuthority.Engine, host: *Host, identity: Identity, context: [32]u8) !p.Authorization.Proof {
    const native = engine.journal.backend;
    try native.authority.lockShared(native.io);
    defer native.authority.unlockShared(native.io);
    try engine.refresh();
    return p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = host.configuration.scope.realm, .principal = identity.principal, .credential_epoch = (try engine.principal(identity.principal)).credential_epoch, .role = identity.role, .audience = host.configuration.audience, .context = context }, identity.key);
}

fn contextDigest(connection: c.DirectTableProtocol.Connection, account: [32]u8) ![32]u8 {
    var bytes: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(.{ .connection = connection, .account = account }, &encoder);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.node.queue-transfer.owner.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}

fn recoverOne(self: *Self, catalog: *c.DirectCatalog, identity: Identity, host: *Host, policy: *Policy, guard: c.storage.PublicationGuard) !bool {
    // Global pending traversal also notices work belonging to replaced signers.
    // It cannot adopt that work or create another source binding. Advance the
    // cursor before execution so one denied attempt cannot monopolize recovery.
    const page = try catalog.store.queueTransferPending(self.pending_after);
    for (page.entries) |slot| {
        const progress = slot orelse break;
        const key = progress.receipt.binding.key;
        if (!std.meta.eql(key.connection, identity.connection(host)) or !std.mem.eql(u8, &key.account, &identity.account)) continue;
        const plan = try Plan.fromReceipt(catalog.allocator, catalog.data_objects, progress.receipt);
        self.pending_after = try plan.sourceKey();
        self.last_object = plan.transfer.target().interpretation.object.object;
        _ = try guard.acquire(guard.context);
        guard.release(guard.context);
        _ = try catalog.advanceQueueTransfer(key, 1, policy.policy());
        return true;
    }
    self.pending_after = page.next;
    _ = try guard.acquire(guard.context);
    guard.release(guard.context);
    return page.next != null;
}

fn discoverOne(self: *Self, allocator: std.mem.Allocator, catalog: *c.DirectCatalog, identity: Identity, host: *Host, engine: *backend.DataAuthority.Engine, policy: *Policy, guard: c.storage.PublicationGuard) !bool {
    errdefer self.clear();
    if (self.target == null) self.target = (try catalog.logMaintenanceNext(.queue, &self.objects, guard)).target;
    const target = self.target orelse return false;
    self.last_object = target.object;
    const definition = (try catalog.logMaintenanceDefinition(.queue, target, guard)) orelse {
        self.clear();
        return false;
    };
    if (definition.stored.retired) {
        self.clear();
        return false;
    }
    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();
    const source: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = definition.stored.declaration.interpretation, .partition = target.ordinal };
    const access = try catalog.logAuthorization(scratch.allocator(), .queue, source, .administer, policy.policy());
    const initial = try definition.genesis(target.ordinal);
    if (self.workspace) |workspace| {
        if (workspace.data.backend != engine.journal.backend) return error.InvalidTableOwner;
        try workspace.queue.owner.root.initialization.requireSame(initial);
    } else self.workspace = try Workspace.create(allocator, engine.journal.backend, initial, access.guard);
    const queue = &self.workspace.?.queue;
    if (!(try queue.recoverStep(access.guard, 16)).complete) return true;
    // A prepared participant belongs to the common decision owner. Discovery
    // skips it; the alternating pending-work pass advances that original.
    if (queue.owner.root.transaction != null) {
        self.clear();
        return false;
    }
    // Retain one finite per-partition sweep until exhausted. Evicting one of a
    // fixed number of cursor hints cannot starve a large Queue population.
    const page = try queue.deadLetterNext(definition.stored, self.cursor, @intCast(@min(256, definition.stored.declaration.limits.timer_steps)), access.guard);
    self.cursor = page.cursor;
    self.last_rows = page.scanned;
    defer if (page.cursor.complete()) self.clear();
    const candidate = page.candidate orelse return !page.cursor.complete();
    if (try catalog.store.queueTransferSource(Plan.sourceDigest(candidate.source)) != null) return true;
    const ids = try identities(identity.connection(host), identity.account, candidate.source);
    if (try c.OperationBinding.lookupTransaction(catalog.allocator, catalog.store.objects, ids.begin)) |reserved| {
        if (reserved.reference.purpose != .queue_transfer or !std.mem.eql(u8, &reserved.token, &try ids.key.digest())) return error.TransactionIdentityConflict;
        const frozen = try Plan.load(catalog.allocator, catalog.data_objects, reserved.reference.purpose.queue_transfer);
        try frozen.key.requireSame(ids.key);
        if (!std.mem.eql(u8, &try frozen.sourceKey(), &Plan.sourceDigest(candidate.source))) return error.TransactionIdentityConflict;
        _ = try catalog.admitQueueTransfer(frozen, policy.policy());
        return true;
    }
    const bytes = try scratch.allocator().alloc(u8, c.storage.LogTransactionActions.max_payload_bytes);
    const read = try catalog.logAuthorization(scratch.allocator(), .queue, source, .read, policy.policy());
    const materialized = try queue.deadLetterRoutedWork(definition.stored, candidate, ids.source, ids.destination, bytes, read.guard);
    const plan: Plan = .{ .definition = p.Growth.current_definition, .key = ids.key, .namespace = definition.properties.namespace, .operation = ids.begin, .transfer = materialized.request, .limits = identity.limits, .budget = identity.budget, .settlement = ids.settlement };
    // Only catalog acceptance binds this source. A lost reply is recovered by
    // the global pending index before another attempt could be dispatched.
    _ = try catalog.admitQueueTransfer(plan, policy.policy());
    return true;
}

const Identities = struct {
    key: c.DirectClientToken.Key,
    begin: p.DataLifecycle.Operation,
    settlement: p.DataLifecycle.Operation,
    source: p.DataLifecycle.Operation,
    destination: p.DataLifecycle.Operation,
};
fn identities(connection: c.DirectTableProtocol.Connection, account: [32]u8, source: @FieldType(@FieldType(p.Transaction.TerminalTransfer, "source"), "exhausted")) !Identities {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.node.queue-transfer.identities.v1\x00");
    hash.update(&try contextDigest(connection, account));
    hash.update(&Plan.sourceDigest(source));
    const digest = hash.finalResult();
    // Four distinct native identities, with explicit domain separation. A
    // collision is a typed identity conflict, never permission to replace work.
    const first = (std.mem.readInt(u64, digest[16..24], .little) % ((p.max_counter - 4) / 4)) * 4 + 1;
    return .{
        .key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = account, .token = digest[0..16].* },
        .begin = .{ .scope = connection.scope, .principal = connection.principal, .operation = first },
        .settlement = .{ .scope = connection.scope, .principal = connection.principal, .operation = first + 1 },
        .source = .{ .scope = connection.scope, .principal = connection.principal, .operation = first + 2 },
        .destination = .{ .scope = connection.scope, .principal = connection.principal, .operation = first + 3 },
    };
}
