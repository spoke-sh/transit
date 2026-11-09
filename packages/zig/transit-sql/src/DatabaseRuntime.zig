//! Bounded recovery over Catalog-owned SQL identities. No actor owns admission.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const wire = @import("transit_client");
const Self = @This();
allocator: std.mem.Allocator,
io: std.Io,
execution: g.DatabaseAccount,
background: wire.Client,
ingress_wire: wire.Client,
ingress: g.Client,
private: g.Client,
table_key: p.Ed25519.KeyPair,
generation: u64,
settings_mutex: std.Io.Mutex = .init,
capture_mutex: std.Io.Mutex = .init,
// Stripes bound active scheduling memory, not the durable operation population.
// A collision only serializes callers; the Catalog token remains the authority.
claims: [64]std.Io.Mutex = @splat(.init),
table_claims: [64]TableClaim = @splat(.{}),
work: g.RecoveryWork = .{},
external_work: ?*g.RecoveryWork = null,
wake_mutex: std.Io.Mutex = .init,
progress_cond: std.Io.Condition = .init,
progress_epoch: std.atomic.Value(u64) = .init(0),
ready: std.atomic.Value(bool) = .init(false),
read_pins: ?g.ReadCache = null,
read_sources: ReadSources = .{},
read_cleanup_failure: std.atomic.Value(u16) = .init(0),
direct_work_failure: std.atomic.Value(u16) = .init(0),
after: u64 = 0,
sweep: ?u64 = null,
scan_complete: bool = false,
retry_pending: bool = false,
cleanup_route: usize = 0,
cleanup_swept_routes: usize = 0,
activation: ?c.DirectClientToken.Progress = null,
activation_record: ?c.DirectRecord.Reference = null,
managed_directory: ?std.Io.Dir = null,
managed_route: usize = 0,
managed_after: ?u64 = null,
managed_pending: bool = false,
managed_work: bool = true,
managed_has_declarations: u64 = 0,
foreground_active: std.atomic.Value(u32) = .init(0),
foreground_notified: std.atomic.Value(bool) = .init(false),
pub const Keys = struct { table: p.Ed25519.KeyPair };
const Activation = struct { generation: u64, instance: [16]u8 };
const activation_format: u32 = 0x53514131;
const TableClaim = struct {
    mutex: std.Io.Mutex = .init,
    object: ?p.DataLifecycle.Object = null,
    next_lsn: u64 = 0,
    pending: ?c.DirectClientToken.Progress = null,
};
pub fn notify(self: *Self) void {
    if (self.foreground_active.load(.acquire) != 0) {
        self.foreground_notified.store(true, .release);
        return;
    }
    self.work.notify(self.io);
}
fn beginForeground(self: *Self) void {
    _ = self.foreground_active.fetchAdd(1, .acquire);
}
fn endForeground(self: *Self) void {
    if (self.foreground_active.fetchSub(1, .acq_rel) == 1) {
        if (self.foreground_notified.swap(false, .acq_rel)) self.work.notify(self.io);
    }
}
pub fn notifyExternal(self: *Self) void {
    if (self.external_work) |work| work.notify(self.io);
}
fn claim(self: *Self, token: [16]u8) *std.Io.Mutex {
    return &self.claims[std.hash.Wyhash.hash(0, &token) % self.claims.len];
}
fn tableClaim(self: *Self, statement: *const g.Statement) ?*TableClaim {
    if (statement.plan != .dml) return null;
    const object = statement.plan.dml.binding.interpretation.interpretation.object;
    return &self.table_claims[std.hash.Wyhash.hash(0, std.mem.asBytes(&object)) % self.table_claims.len];
}
fn tableFresh(claim_slot: ?*const TableClaim, statement: *const g.Statement, fresh_prepared: bool) bool {
    if (!fresh_prepared or statement.plan != .dml) return fresh_prepared;
    if (statement.kind() == .insert) return true;
    const dml = &statement.plan.dml;
    if (dml.metadata.position.next_lsn == 0) return false;
    const table_claim = claim_slot orelse return false;
    const object = dml.binding.interpretation.interpretation.object;
    return table_claim.object == null or
        (std.meta.eql(table_claim.object.?, object) and table_claim.next_lsn <= dml.metadata.position.next_lsn);
}
fn finishTableClaim(claim_slot: ?*TableClaim, statement: *const g.Statement, terminal: ?g.Terminal) void {
    const table_claim = claim_slot orelse return;
    if (statement.plan != .dml) return;
    if (terminal != null) table_claim.pending = null;
    table_claim.object = statement.plan.dml.binding.interpretation.interpretation.object;
    table_claim.next_lsn = if (terminal != null and terminal.?.state == .applied) terminal.?.next_lsn else std.math.maxInt(u64);
}
fn recordPendingTableClaim(claim_slot: ?*TableClaim, state: c.DirectClientToken.Progress) void {
    const table_claim = claim_slot orelse return;
    if (!state.pending or state.cancel or state.receipt.binding.intent != .table) return;
    switch (state.receipt.binding.intent.table.binding.action) {
        .insert, .update, .delete => table_claim.pending = state,
        else => {},
    }
}
fn settlePendingTableClaim(self: *Self, claim_slot: ?*TableClaim, observer: *g.Client, table: *c.DirectTableClient, deadline: Deadline) !void {
    const table_claim = claim_slot orelse return;
    const pending_state = table_claim.pending orelse return;
    const intent = pending_state.receipt.binding.intent;
    if (intent != .table or !std.meta.eql(intent.connection(), table.connection)) {
        table_claim.pending = null;
        return;
    }
    table.lease = self.lease();
    if (try self.foreground(observer, table, pending_state, deadline)) |terminal| {
        table_claim.pending = null;
        table_claim.object = intent.table.binding.target;
        table_claim.next_lsn = if (terminal.state == .applied) terminal.next_lsn else std.math.maxInt(u64);
        return;
    }
    const observed = try self.available(observer, deadline, c.DirectIntent.Reference.operation, .{ intent, table.*, .inspect, 1 });
    defer observed.deinit();
    if (try g.Terminal.fromReference(intent, observed.value.result)) |terminal| {
        table_claim.pending = null;
        table_claim.object = intent.table.binding.target;
        table_claim.next_lsn = if (terminal.state == .applied) terminal.next_lsn else std.math.maxInt(u64);
        return;
    }
    return error.GatewayOwnerUnavailable;
}

pub fn notifyProgress(self: *Self) void {
    self.wake_mutex.lockUncancelable(self.io);
    defer self.wake_mutex.unlock(self.io);
    _ = self.progress_epoch.fetchAdd(1, .release);
    self.progress_cond.broadcast(self.io);
}

/// Retain notifications arriving between status inspection and sleeping.
/// Local timer wakes check cancellation/deadlines without polling native state.
fn waitProgressAfter(self: *Self, observed: u64, deadline: Deadline) !void {
    try self.wake_mutex.lock(self.io);
    defer self.wake_mutex.unlock(self.io);
    while (self.progress_epoch.load(.acquire) == observed) {
        try deadline.check(self.io);
        const wake = wire.Deadline.init(self.io, 100, deadline.budget);
        self.progress_cond.waitTimeout(self.io, &self.wake_mutex, wake.timeout()) catch |err| switch (err) {
            error.Timeout => {},
            else => return err,
        };
    }
    try deadline.check(self.io);
}

pub fn waitIdle(self: *Self, milliseconds: u32) !void {
    try self.work.wait(self.io, milliseconds);
}

pub fn waitProgress(self: *Self, milliseconds: u32) !void {
    try self.wake_mutex.lock(self.io);
    defer self.wake_mutex.unlock(self.io);
    self.progress_cond.waitTimeout(self.io, &self.wake_mutex, .{ .duration = .{ .raw = .fromMilliseconds(milliseconds), .clock = .awake } }) catch |err| switch (err) {
        error.Timeout => {},
        else => return err,
    };
}
pub const Deadline = struct {
    budget: wire.Deadline,
    cancellation: ?*const std.atomic.Value(bool) = null,
    pub fn check(self: Deadline, io: std.Io) !void {
        if (self.cancellation) |requested| if (requested.load(.acquire)) return error.GatewayWaitCancelled;
        self.budget.check(io) catch return error.GatewayDeadline;
    }
};

test "progress notifications survive the status-to-wait gap and preserve deadlines" {
    const t = std.testing;
    // Only the synchronization fields are used: this check cannot issue a
    // native request or manufacture durable operation progress.
    var runtime: Self = undefined;
    runtime.io = t.io;
    runtime.wake_mutex = .init;
    runtime.progress_cond = .init;
    runtime.progress_epoch = .init(0);
    const observed = runtime.progress_epoch.load(.acquire);
    runtime.notifyProgress();
    const deadline: Deadline = .{ .budget = .init(t.io, 60000, null) };
    try runtime.waitProgressAfter(observed, deadline);
    var cancelled: std.atomic.Value(bool) = .init(true);
    var cancellation = deadline;
    cancellation.cancellation = &cancelled;
    try t.expectError(error.GatewayWaitCancelled, runtime.waitProgressAfter(observed, cancellation));
    var expired = deadline;
    expired.budget = .init(t.io, 0, null);
    try t.expectError(error.GatewayDeadline, runtime.waitProgressAfter(observed, expired));
    const Wait = struct {
        fn run(value: *Self, epoch: u64, limit: Deadline) !void {
            try value.waitProgressAfter(epoch, limit);
            return error.ProgressWaitWokeWithoutNotification;
        }
    };
    var task = try t.io.concurrent(Wait.run, .{ &runtime, runtime.progress_epoch.load(.acquire), deadline });
    if (task.cancel(t.io)) |_| return error.CancellationMissing else |err| try t.expect(err == error.Canceled or err == error.Cancelled);
}

test "per-table DML stripes preserve fresh single-writer preparation and force refresh after concurrent advancement" {
    const t = std.testing;
    var runtime: Self = undefined;
    runtime.table_claims = @splat(.{});
    const table_a: p.DataLifecycle.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 1 }, .branch = 1, .object = 10 };
    const table_b: p.DataLifecycle.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 1 }, .branch = 1, .object = 11 };
    var update: g.Statement = undefined;
    update.plan = .{ .dml = undefined };
    update.plan.dml.template.syntax.subject.kind = .update;
    update.plan.dml.binding.interpretation.interpretation.object = table_a;
    update.plan.dml.metadata.position = .{ .partition = 1, .next_lsn = 5 };

    const slot_a = runtime.tableClaim(&update).?;
    try t.expect(tableFresh(slot_a, &update, true));
    try t.expect(!tableFresh(slot_a, &update, false));

    var applied: g.Terminal = undefined;
    applied.state = .applied;
    applied.next_lsn = 6;
    finishTableClaim(slot_a, &update, applied);
    try t.expect(!tableFresh(slot_a, &update, true));
    update.plan.dml.metadata.position.next_lsn = 6;
    try t.expect(tableFresh(slot_a, &update, true));

    update.plan.dml.metadata.position.next_lsn = 0;
    try t.expect(!tableFresh(slot_a, &update, true));
    update.plan.dml.metadata.position.next_lsn = 7;
    finishTableClaim(slot_a, &update, null);
    try t.expect(!tableFresh(slot_a, &update, true));

    update.plan.dml.template.syntax.subject.kind = .insert;
    try t.expect(tableFresh(slot_a, &update, true));

    update.plan.dml.template.syntax.subject.kind = .delete;
    update.plan.dml.binding.interpretation.interpretation.object = table_b;
    const slot_b = runtime.tableClaim(&update).?;
    if (slot_b != slot_a) try t.expect(tableFresh(slot_b, &update, true));
}

pub fn init(allocator: std.mem.Allocator, io: std.Io, url: []const u8, execution: g.DatabaseAccount, generation: u64, keys: Keys, timeout_ms: u32) !*Self {
    return initEndpoint(allocator, io, url, execution, generation, keys, timeout_ms, null);
}
pub fn initEndpoint(allocator: std.mem.Allocator, io: std.Io, url: []const u8, execution: g.DatabaseAccount, generation: u64, keys: Keys, timeout_ms: u32, endpoint: ?wire.LocalEndpoint) !*Self {
    try execution.configuration.validate();
    if (generation == 0 or timeout_ms == 0 or timeout_ms > 60000) return error.InvalidGatewayConfiguration;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{ .allocator = allocator, .io = io, .execution = execution, .background = wire.Client.init(allocator, io, url), .ingress_wire = wire.Client.init(allocator, io, url), .ingress = undefined, .private = undefined, .table_key = keys.table, .generation = generation };
    errdefer self.background.deinit();
    errdefer self.ingress_wire.deinit();
    self.background.local = endpoint;
    self.ingress_wire.local = endpoint;
    self.background.timeout_ms = timeout_ms;
    self.ingress_wire.timeout_ms = timeout_ms;
    self.ingress = .{ .transport = &self.ingress_wire, .execution = execution, .principal = execution.configuration.table_principal, .key = keys.table };
    self.private = .{ .transport = &self.background, .execution = execution, .principal = execution.configuration.table_principal, .key = keys.table };
    try self.activate();
    return self;
}
fn activate(self: *Self) !void {
    var caller = self.private.table(self.execution.configuration.bindings[0]);
    const configuration = try self.execution.configuration.digest();
    const key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = caller.connection, .account = g.AccountIdentity.internal(self.execution.configuration.account, "activation", ""), .token = @splat(0) };
    const inspected = try caller.call(.{ .client_progress = .{ .inspect = key } });
    defer inspected.deinit();
    const epoch = inspected.value.subject.credential_epoch;
    self.private.credential_epoch = epoch;
    self.ingress.credential_epoch = epoch;
    caller.credential_epoch = epoch;
    var value: Activation = .{ .generation = self.generation, .instance = undefined };
    try self.io.randomSecure(&value.instance);
    const bytes = try p.Json.valueAlloc(self.allocator, value);
    defer self.allocator.free(bytes);
    if (inspected.value.result.client_progress.state) |state| {
        var current = state;
        if (!std.mem.eql(u8, &configuration, &current.receipt.binding.fingerprint)) return error.GatewayConfigurationChanged;
        const record = current.record orelse if (current.receipt.binding.intent == .external) current.receipt.binding.intent.external.record else return error.MissingGatewayOperation;
        const saved_bytes = try c.DirectRecord.read(self.allocator, caller, record);
        defer self.allocator.free(saved_bytes);
        const saved = try p.Json.parseFromSlice(Activation, self.allocator, saved_bytes);
        defer saved.deinit();
        if (saved.value.generation >= self.generation) return error.StaleGatewayCoordinator;
        self.activation_record = try c.DirectRecord.stage(caller, key.account, activation_format, bytes);
        current = try c.DirectClientToken.update(caller, .{ .key = key, .expected = current.revision, .pending = true, .cancel = false, .record = self.activation_record });
        self.activation = current;
    } else {
        const record = try c.DirectRecord.stage(caller, key.account, activation_format, bytes);
        const receipt = try c.DirectClientToken.bind(caller, .{ .key = key, .fingerprint = configuration, .intent = .{ .external = .{ .connection = caller.connection, .namespace = self.execution.configuration.bindings[0].namespace, .operation = (std.mem.readInt(u64, configuration[0..8], .little) % p.max_counter) + 1, .record = record } } });
        if (receipt.binding.intent != .external or !std.meta.eql(receipt.binding.intent.external.record, record)) return error.StaleGatewayCoordinator;
        self.activation_record = record;
        self.activation = c.DirectClientToken.Progress.initial(receipt);
    }
    self.private.lease = self.lease();
    self.ingress.lease = self.lease();
}
pub fn lease(self: *Self) c.DirectClientToken.Lease {
    return .{ .key = self.activation.?.receipt.binding.key, .revision = self.activation.?.revision };
}
pub fn fence(self: *Self, observer: *g.Client) !void {
    return self.checkFence(observer) catch |err| {
        // With no idle polling, the foreground observation transfers the
        // readiness obligation. A worker's own failed check retains retry debt
        // without generating another notification on every retry.
        self.ready.store(false, .release);
        self.notify();
        return err;
    };
}
fn checkFence(self: *Self, observer: *g.Client) !void {
    var caller = observer.table(self.execution.configuration.bindings[0]);
    caller.lease = null;
    const state = (try c.DirectClientToken.inspect(caller, self.activation.?.receipt.binding.key)) orelse return error.StaleGatewayCoordinator;
    const active_record = state.record orelse if (state.receipt.binding.intent == .external) state.receipt.binding.intent.external.record else return error.StaleGatewayCoordinator;
    if (!std.meta.eql(active_record, self.activation_record.?)) return error.StaleGatewayCoordinator;
}
pub fn deinit(self: *Self) void {
    if (self.read_pins) |*pins| pins.deinit();
    self.background.deinit();
    self.ingress_wire.deinit();
    const allocator = self.allocator;
    std.crypto.secureZero(u8, std.mem.asBytes(self));
    allocator.destroy(self);
}
pub const ReadSources = struct {
    context: ?*const anyopaque = null,
    len: usize = 0,
    resolve: ?*const fn (*const anyopaque, usize, std.mem.Allocator, std.Io, *wire.Client) anyerror!?c.DirectTableClient = null,
};
pub fn attachReadCache(self: *Self, directory: std.Io.Dir, sources: ReadSources) !void {
    self.managed_directory = directory;
    if (self.read_pins != null) return error.InvalidSqlReadRecovery;
    const config = self.execution.configuration;
    self.read_pins = try g.ReadCache.init(self.allocator, self.io, directory, .{ .realm = config.realm, .account = config.account }, self.generation);
    self.read_pins.?.wake = &self.work;
    self.read_sources = sources;
    self.notify();
}
pub fn tick(self: *Self) !bool {
    if (self.sweep == null) {
        self.sweep = self.work.begin(self.io) orelse return false;
        self.after = 0;
        self.scan_complete = false;
        self.retry_pending = false;
        self.managed_route = 0;
        self.managed_after = null;
        self.managed_work = true;
        self.managed_pending = false;
    }
    errdefer {
        self.ready.store(false, .release);
        self.finishSweep(true);
    }
    try self.checkFence(&self.private);
    var progressed = false;
    if (!self.scan_complete) {
        var source = try self.private.source();
        const page = g.SessionOperations.list(self.execution, &source, self.after, true) catch |err| {
            if (err != error.AccessDenied and !wire.Client.unavailable(err) and !self.background.contended(err)) return err;
            self.direct_work_failure.store(@intFromError(err), .release);
            self.finishSweep(true);
            const was_ready = self.ready.swap(true, .release);
            if (!was_ready) self.notifyProgress();
            return false;
        };
        // Consume the entire bounded page before advancing its cursor. Stopping
        // at its first entry and resetting on next=null starves the final page.
        for (page.entries) |slot| if (slot) |reference| {
            if (reference.kind != .table and reference.kind != .transaction and reference.kind != .workload) continue;
            const selected = self.claim(reference.nonce);
            if (!selected.tryLock()) {
                self.retry_pending = true;
                continue;
            }
            defer selected.unlock(self.io);
            const pending = self.recoverOne(&source, reference.id) catch |err| {
                self.direct_work_failure.store(@intFromError(err), .release);
                if (!wire.Client.unavailable(err) and err != error.ClientOperationConflict and !self.background.contended(err) and err != error.AccessDenied) return err;
                self.retry_pending = true;
                continue;
            };
            self.direct_work_failure.store(0, .release);
            self.retry_pending = self.retry_pending or pending;
            progressed = true;
        };
        self.after = page.next orelse 0;
        self.scan_complete = page.next == null;
    }
    var cleanup_pending = false;
    if (self.read_pins) |*pins| {
        const route_count = self.execution.configuration.bindings.len + self.read_sources.len;
        if (pins.dirty.swap(false, .acq_rel)) self.cleanup_swept_routes = if (pins.cleanup_slot == 0) 1 else 0;
        // A dirty signal can arrive halfway through a route. Include one extra
        // wrap so a successful sweep covers the prefix already passed too.
        if (self.cleanup_swept_routes <= route_count or self.read_cleanup_failure.load(.acquire) != 0) {
            var route_clean = true;
            const previous_slot = pins.cleanup_slot;
            var route_complete = false;
            if (self.cleanupClient() catch |err| blk: {
                if (err == error.Canceled or err == error.Cancelled) return err;
                self.read_cleanup_failure.store(@intFromError(err), .release);
                route_clean = false;
                break :blk null;
            }) |caller| {
                while (true) {
                    const slot_before = pins.cleanup_slot;
                    const cleaned = pins.tick(caller) catch |err| blk: {
                        if (err == error.StaleGatewayCoordinator or err == error.Canceled or err == error.Cancelled) return err;
                        self.read_cleanup_failure.store(@intFromError(err), .release);
                        route_clean = false;
                        break :blk false;
                    };
                    progressed = progressed or cleaned;
                    route_complete = slot_before != pins.cleanup_slot and pins.cleanup_slot == 0;
                    if (!route_clean or cleaned or route_complete or pins.cleanup_slot == slot_before) break;
                }
            } else if (route_clean) {
                // A disabled optional source has no cleanup connection.
                pins.cleanup_slot = 0;
                route_complete = true;
            }
            if (!route_clean) {
                self.cleanup_swept_routes = 0;
                self.retry_pending = true;
            } else if (route_complete) {
                self.cleanup_swept_routes += 1;
                if (self.cleanup_swept_routes > route_count) self.read_cleanup_failure.store(0, .release);
            }
            if (route_complete) self.cleanup_route = (self.cleanup_route + 1) % route_count;
            // A foreground borrower can own the cache lock. Back off without
            // declaring this unswept slot clean or spinning on a busy mutex.
            if (route_clean and !route_complete and previous_slot == pins.cleanup_slot) self.retry_pending = true;
            cleanup_pending = route_clean and (route_complete or previous_slot != pins.cleanup_slot) and self.cleanup_swept_routes <= route_count;
        }
    }
    const was_ready = self.ready.swap(true, .release);
    if (!was_ready or progressed) self.notifyProgress();
    if (!self.scan_complete or cleanup_pending) return true;
    if (self.managed_directory != null and try self.managedStep()) return true;
    if (self.managed_pending) {
        self.managed_route = 0;
        self.managed_after = null;
        self.managed_work = true;
        self.managed_pending = false;
        return true;
    }
    self.finishSweep(self.retry_pending);
    return false;
}
/// Bounded declaration discovery over ordinary catalog pages. Active work gets
/// another fair sweep; settled declarations cause no timer or upstream requests.
fn managedStep(self: *Self) !bool {
    const bindings = self.execution.configuration.bindings;
    const M = g.direct.ManagedTable;
    while (true) {
        while (self.managed_route < bindings.len and g.Client.isDuplicateBindingConnection(bindings, self.managed_route)) {
            self.managed_route += 1;
            self.managed_after = null;
            self.managed_work = true;
        }
        if (self.managed_route >= bindings.len) return false;
        const route_bit = @as(u64, 1) << @intCast(self.managed_route);
        if (self.managed_work and (self.managed_has_declarations & route_bit) == 0) {
            self.managed_work = false;
            self.managed_after = null;
        }
        const caller = self.private.table(bindings[self.managed_route]);
        const manager: M = .{ .client = caller };
        const page = try c.DirectClientToken.list(caller, if (self.managed_work) M.workAccount() else M.account(), self.managed_after, self.managed_work);
        if (!self.managed_work and page.entries[0] != null and (self.managed_has_declarations & route_bit) == 0) {
            self.managed_has_declarations |= route_bit;
            self.managed_pending = true;
        }
        for (page.entries) |slot| if (slot) |entry| {
            self.managed_after = entry.id();
            const original = entry.original orelse return error.InvalidManagedTableRecord;
            // Reservations need the exact caller payload or explicit closure. They
            // are discoverable but do not spin a worker or read nonexistent bytes.
            if (original.phase == .reserved or original.phase == .closed) continue;
            if (self.managed_work) {
                if (entry.receipt.binding.intent != .external or entry.receipt.binding.intent.external.record.format != c.DirectOwnedRecord.format) return error.InvalidManagedTableRecord;
                if (!g.Client.hasConnectionNamespace(bindings, self.managed_route, entry.receipt.binding.intent.external.namespace)) continue;
                const token = entry.receipt.binding.key;
                const selected = self.claim(token.token);
                if (!selected.tryLock()) {
                    self.retry_pending = true;
                    return true;
                }
                defer selected.unlock(self.io);
                const pending = manager.step(token, self.io, self.managed_directory.?, null) catch |err| {
                    if (err == error.Canceled or err == error.Cancelled) return err;
                    self.direct_work_failure.store(@intFromError(err), .release);
                    if (wire.Client.unavailable(err) or self.background.contended(err)) self.retry_pending = true;
                    return true;
                };
                self.direct_work_failure.store(0, .release);
                self.managed_pending = self.managed_pending or pending;
                return true;
            }
            if (entry.receipt.binding.intent != .external or entry.receipt.binding.intent.external.record.format != c.DirectOwnedRecord.format) return error.InvalidManagedTableRecord;
            const declared = try manager.load(M.Declaration, entry.receipt.binding.intent.external.record, M.declaration_format);
            defer declared.deinit();
            if (!g.Client.hasConnectionNamespace(bindings, self.managed_route, declared.value.namespace)) continue;
            self.managedOne(manager, declared.value, entry) catch |err| {
                if (err == error.Canceled or err == error.Cancelled) return err;
                self.direct_work_failure.store(@intFromError(err), .release);
                // Transport uncertainty retains bounded retry debt. Policy/source
                // refusals wait for a publication hint or explicit control command.
                if (wire.Client.unavailable(err) or self.background.contended(err)) self.retry_pending = true;
            };
            return true;
        };
        if (page.next) |next| {
            self.managed_after = next;
            return true;
        }
        if (self.managed_work) {
            self.managed_work = false;
            self.managed_after = null;
            continue;
        }
        self.managed_route += 1;
        self.managed_after = null;
        self.managed_work = true;
    }
}
fn managedOne(self: *Self, manager: g.direct.ManagedTable, declared: g.direct.ManagedTable.Declaration, entry: c.DirectClientToken.Progress) !void {
    if (entry.pending) _ = try manager.initialize(declared, entry.receipt.binding.key);
    if (try manager.start(declared) != null) self.managed_pending = true;
}
fn finishSweep(self: *Self, retry: bool) void {
    self.work.finish(self.io, self.sweep.?, retry);
    self.sweep = null;
}
fn recoverOne(self: *Self, source: *g.Client.Source, id: u64) !bool {
    return self.advance(source, try source.operation(id));
}
fn cleanupClient(self: *Self) !?c.DirectTableClient {
    const bindings = self.execution.configuration.bindings;
    if (self.cleanup_route < bindings.len) {
        if (g.Client.isDuplicateBindingConnection(bindings, self.cleanup_route)) return null;
        return self.private.table(bindings[self.cleanup_route]);
    }
    const resolve = self.read_sources.resolve orelse return null;
    return resolve(self.read_sources.context.?, self.cleanup_route - bindings.len, self.allocator, self.io, &self.background);
}

fn advance(self: *Self, source: *g.Client.Source, state: c.DirectClientToken.Progress) !bool {
    try self.checkFence(source.client);
    if (!state.pending) return false;
    const reference = state.receipt.binding.intent;
    if (reference == .external or reference == .branch) return false;
    const caller = source.direct(state);
    if (reference == .workload) return g.WorkloadOperations.advance(caller, state);
    if (reference == .transaction_call) {
        return transactionPending(try g.TransactionWork.advance(caller, state, state.cancel));
    }
    // commit_saved resolves an existing receipt before execution. Repeating it
    // with the original frozen reference needs no preceding inspection RPC.
    // Cancellation retains its separate owner transition below.
    if (reference == .table and (reference.table.binding.action == .insert or reference.table.binding.action == .update or reference.table.binding.action == .delete) and !state.cancel) {
        const object = reference.table.binding.target;
        const claim_slot = &self.table_claims[std.hash.Wyhash.hash(0, std.mem.asBytes(&object)) % self.table_claims.len];
        try claim_slot.mutex.lock(self.io);
        defer claim_slot.mutex.unlock(self.io);
        const response = try caller.call(.{ .commit_saved = reference.table });
        defer response.deinit();
        const terminal = (try g.Terminal.fromReference(reference, response.value.result)) orelse return true;
        if (claim_slot.pending) |pending_state| if (std.meta.eql(pending_state.receipt.binding.key, state.receipt.binding.key)) {
            claim_slot.pending = null;
        };
        claim_slot.object = object;
        claim_slot.next_lsn = if (terminal.state == .applied) terminal.next_lsn else std.math.maxInt(u64);
        _ = try c.DirectClientToken.update(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = false, .cancel = false, .record = state.record });
        return false;
    }
    const observed = try reference.operation(caller, .inspect, 1);
    defer observed.deinit();
    if (try g.Terminal.fromReference(reference, observed.value.result) != null) {
        _ = try c.DirectClientToken.update(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = false, .cancel = state.cancel, .record = state.record });
        return false;
    }
    if (reference == .kv and reference.kv.kind != .ddl) {
        if (!state.cancel) {
            const response = reference.admit(caller) catch |err| switch (err) {
                error.DuplicatePrimaryKey, error.DuplicateBatchKey, error.TableRowMissing, error.TableDefinitionChanged, error.TableDataChanged, error.KVRevisionChanged => null,
                else => return err,
            };
            defer if (response) |value| value.deinit();
        }
        _ = try c.DirectClientToken.update(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = false, .cancel = state.cancel, .record = state.record });
        return false;
    }
    const absent = switch (observed.value.result) {
        inline .ddl, .rows, .name_assertion, .namespace_operation, .log_operation => |value| value == .not_observed,
        .kv_declaration => |value| value.operation == .not_observed,
        .document_declaration => |value| value.operation == .not_observed,
        else => return error.InvalidGatewayTerminal,
    };
    const response = try if (absent and !((reference == .name_assertion or reference == .kv_name_assertion or reference == .document_name_assertion) and state.cancel)) reference.admit(caller) else reference.operation(caller, if (state.cancel) .cancel else .execute, 8);
    defer response.deinit();
    if (try g.Terminal.fromReference(reference, response.value.result) == null) return true;
    _ = try c.DirectClientToken.update(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = false, .cancel = state.cancel, .record = state.record });
    return false;
}
fn transactionPending(result: ?c.DirectTransactionCall.Result) bool {
    const value = result orelse return true;
    return value == .settled and !value.settled.cleanup_complete;
}
pub fn cancel(self: *Self, observer: *g.Client, id: u64) !void {
    try self.fence(observer);
    var source = try observer.source();
    const state = try source.operation(id);
    defer if (state.receipt.binding.intent == .external) self.notifyExternal() else self.notify();
    if (state.receipt.binding.intent == .transaction_call) {
        _ = try g.TransactionWork.advance(source.direct(state), state, true);
        return;
    }
    _ = try c.DirectClientToken.update(source.direct(state), .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = state.pending, .cancel = true, .record = state.record });
}
pub fn resumeOperation(self: *Self, observer: *g.Client, id: u64) !void {
    var source = try observer.source();
    const token = (try source.operation(id)).receipt.binding.key.token;
    const selected = self.claim(token);
    try selected.lock(self.io);
    defer selected.unlock(self.io);
    errdefer self.notify();
    if (try self.recoverOne(&source, id)) self.notify();
}
/// One explicit attempt against the original workload; never retries a native
/// wait automatically. The token lock coordinates recovery, not partition data.
pub fn resumeWorkload(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, namespace: u64, id: u64, deadline: Deadline) !g.session_protocol.Operation {
    var source = try observer.source();
    const token = (try source.operation(id)).receipt.binding.key.token;
    const selected = self.claim(token);
    try selected.lock(self.io);
    defer selected.unlock(self.io);
    defer self.notify();
    try deadline.check(self.io);
    try self.fence(observer);
    table.lease = self.lease();
    const state = try source.operation(id);
    try requireRoute(state, table, namespace);
    if (state.receipt.binding.intent != .workload) return error.WorkloadOperationRequired;
    const attempt = try g.WorkloadOperations.attemptWithIntent(table.*, state, null, false);
    if (attempt.terminal) |completed| return completed;
    var result = try self.status(allocator, observer, table, namespace, id);
    if (result.wait != null and attempt.wait != null) {
        try result.wait.?.requireSame(attempt.wait.?);
        result.wait = attempt.wait;
    }
    return result;
}
pub fn lookup(self: *Self, observer: *g.Client, nonce: [16]u8, fingerprint: ?[32]u8) !?g.OperationRecords.Operation {
    const state = (try lookupState(observer, nonce, fingerprint)) orelse return null;
    return try self.execution.operationFromState(state);
}
fn lookupState(observer: *g.Client, nonce: [16]u8, fingerprint: ?[32]u8) !?c.DirectClientToken.Progress {
    var source = try observer.source();
    return source.lookup(nonce, fingerprint);
}
/// Repeat only observations or independently idempotent database requests with
/// the same arguments. In particular, a token bind retains its frozen reference;
/// this helper never resubmits SQL or chooses another accepted identity.
fn available(self: *Self, observer: *g.Client, deadline: Deadline, comptime function: anytype, args: std.meta.ArgsTuple(@TypeOf(function))) !@typeInfo(@typeInfo(@TypeOf(function)).@"fn".return_type.?).error_union.payload {
    const started = std.Io.Clock.awake.now(self.io);
    var attempts: u8 = 0;
    while (true) {
        try deadline.check(self.io);
        return @call(.auto, function, args) catch |err| {
            if (!wire.Client.unavailable(err) or observer.transport.last_rejection == .StorageQuota or
                (attempts > 0 and started.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds() >= self.background.timeout_ms)) return err;
            attempts +|= 1;
            try self.io.sleep(.fromMilliseconds(20), .awake);
            continue;
        };
    }
}
pub fn admit(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, nonce: [16]u8, fingerprint: [32]u8, deadline: Deadline, operation: *?u64) !g.OperationRecords.Operation {
    const selected = self.claim(nonce);
    try selected.lock(self.io);
    defer selected.unlock(self.io);
    defer self.notify();
    const state = try self.admitWithWake(allocator, observer, table, statement, values, nonce, fingerprint, deadline, operation, null, true, false, false, false, false, null, null);
    return self.execution.operationFromState(state);
}
fn admitWithWake(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, nonce: [16]u8, fingerprint: [32]u8, deadline: Deadline, operation: *?u64, acceptance_possible: ?*bool, wake: bool, fresh_nonce: bool, fresh_prepared: bool, fresh_table: bool, fresh_fenced: bool, newly_bound: ?*bool, retained_workload: ?*?c.DirectWorkloadIntent) !c.DirectClientToken.Progress {
    if (newly_bound) |flag| flag.* = false;
    if (retained_workload) |slot| slot.* = null;
    if (acceptance_possible) |flag| flag.* = false;
    try deadline.check(self.io);
    if (!fresh_fenced) try self.available(observer, deadline, Self.fence, .{ self, observer });
    table.lease = self.lease();
    const expected_fingerprint = if (std.mem.allEqual(u8, &fingerprint, 0)) null else fingerprint;
    if (!fresh_nonce) {
        if (acceptance_possible) |flag| flag.* = true;
        if (try self.available(observer, deadline, Self.lookupState, .{ observer, nonce, expected_fingerprint })) |previous| {
            operation.* = previous.id();
            _ = try self.execution.operationFromState(previous);
            return previous;
        }
        if (acceptance_possible) |flag| flag.* = false;
    }
    if (!fresh_prepared) try statement.checkValues(allocator, values);
    var random: [8]u8 = undefined;
    try self.io.randomSecure(&random);
    const id = (std.mem.readInt(u64, &random, .little) % p.max_counter) + 1;
    var fresh = fresh_table;
    var intent = self.available(observer, deadline, g.Statement.bindWritePrepared, .{ statement, allocator, table, values, id, &fresh }) catch |err| {
        if (expected_fingerprint != null) {
            if (acceptance_possible) |flag| flag.* = true;
            if (try self.available(observer, deadline, Self.lookupState, .{ observer, nonce, expected_fingerprint })) |previous| {
                operation.* = previous.id();
                _ = try self.execution.operationFromState(previous);
                return previous;
            }
            if (acceptance_possible) |flag| flag.* = false;
        }
        return err;
    };
    var intent_owned = true;
    defer if (intent_owned) intent.deinit();
    if (try intent.workBytes() > self.execution.configuration.intent_bytes) return error.GatewayRecordTooLarge;
    const reference = try self.available(observer, deadline, g.Statement.Write.stage, .{ &intent, table.*, statement.namespace, self.execution.configuration.account });
    // Workload recovery retains the complete frozen body as well as its
    // reference. Charge the owner's required reservation without changing the
    // account quota or the separate per-intent body-size limit above.
    const reserved = if (reference == .workload) try reference.workload.reservationBytes() else self.execution.configuration.reservation();
    const binding: c.DirectClientToken.Binding = .{ .key = .{ .definition = p.Growth.current_definition, .connection = table.connection, .account = self.execution.configuration.account, .token = nonce }, .fingerprint = expected_fingerprint orelse try reference.digest(), .intent = reference, .budget = self.execution.configuration.budget(reserved) };
    if (acceptance_possible) |flag| flag.* = true;
    // A lost bind response can leave work accepted even without an observed ID.
    errdefer self.notify();
    const receipt = self.available(observer, deadline, c.DirectClientToken.bind, .{ table.*, binding }) catch |err| {
        // A concurrent first submission may have won after the initial lookup.
        // Reconcile only the same token; never invent a new operation.
        if (observer.transport.contended(err)) {
            if (try self.available(observer, deadline, Self.lookupState, .{ observer, nonce, expected_fingerprint })) |previous| {
                operation.* = previous.id();
                _ = try self.execution.operationFromState(previous);
                return previous;
            }
        }
        return err;
    };
    const is_newly_bound = std.meta.eql(receipt.binding.intent, reference);
    if (newly_bound) |flag| flag.* = is_newly_bound;
    operation.* = receipt.position.next_lsn;
    if (wake) self.notify();
    const state = c.DirectClientToken.Progress.initial(receipt);
    _ = try self.execution.operationFromState(state);
    if (is_newly_bound and intent == .workload) {
        if (retained_workload) |slot| {
            slot.* = intent.workload;
            intent_owned = false;
        }
    }
    return state;
}
pub const RetainedWorkload = struct {
    id: u64,
    reference: c.DirectWorkloadIntent.Reference,
    intent: c.DirectWorkloadIntent,
    pub fn deinit(self: *RetainedWorkload) void {
        self.intent.deinit();
        self.* = undefined;
    }
};
/// Submit through the same durable token owner and attempt bounded foreground
/// DML completion. Interrupted work remains pending under its original identity;
/// recovery is notified if foreground execution cannot settle the original work.
pub fn submit(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, nonce: [16]u8, fingerprint: [32]u8, deadline: Deadline, operation: *?u64) !g.session_protocol.Operation {
    return self.submitPrepared(allocator, observer, table, statement, values, nonce, fingerprint, deadline, operation, null, false, false);
}
pub fn submitPrepared(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, nonce: [16]u8, fingerprint: [32]u8, deadline: Deadline, operation: *?u64, acceptance_possible: ?*bool, fresh_prepared: bool, fresh_fenced: bool) !g.session_protocol.Operation {
    return self.submitPreparedRetained(allocator, observer, table, statement, values, nonce, fingerprint, deadline, operation, acceptance_possible, fresh_prepared, fresh_fenced, null);
}
pub fn submitPreparedRetained(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, nonce: [16]u8, fingerprint: [32]u8, deadline: Deadline, operation: *?u64, acceptance_possible: ?*bool, fresh_prepared: bool, fresh_fenced: bool, out_retained_workload: ?*?RetainedWorkload) !g.session_protocol.Operation {
    if (out_retained_workload) |slot| slot.* = null;
    const selected = self.claim(nonce);
    try selected.lock(self.io);
    self.beginForeground();
    defer self.endForeground();
    defer selected.unlock(self.io);
    const table_claim = self.tableClaim(statement);
    if (table_claim) |claim_slot| try claim_slot.mutex.lock(self.io);
    defer if (table_claim) |claim_slot| claim_slot.mutex.unlock(self.io);
    errdefer self.notify();
    try self.settlePendingTableClaim(table_claim, observer, table, deadline);
    var newly_bound = false;
    var retained_workload: ?c.DirectWorkloadIntent = null;
    defer if (retained_workload) |*workload| workload.deinit();
    const fresh_table = tableFresh(table_claim, statement, fresh_prepared);
    const state = try self.admitWithWake(allocator, observer, table, statement, values, nonce, fingerprint, deadline, operation, acceptance_possible, false, true, fresh_prepared, fresh_table, fresh_fenced, &newly_bound, &retained_workload);
    recordPendingTableClaim(table_claim, state);
    errdefer finishTableClaim(table_claim, statement, null);
    try requireRoute(state, table, statement.namespace);
    if (state.receipt.binding.intent == .workload and newly_bound) {
        try deadline.check(self.io);
        const is_wait = if (retained_workload) |*workload| workload.parsed.value.wait_ms != null else false;
        const attempt = g.WorkloadOperations.attemptWithIntent(table.*, state, if (retained_workload) |*workload| workload else null, true) catch |err| switch (err) {
            error.GatewayDeadline, error.Conflict => if (!is_wait) g.WorkloadOperations.Attempt{ .pending = true } else return err,
            else => if (!is_wait and wire.Client.unavailable(err)) g.WorkloadOperations.Attempt{ .pending = true } else return err,
        };
        if (attempt.terminal) |completed| {
            finishTableClaim(table_claim, statement, null);
            if (out_retained_workload) |slot| if (retained_workload != null and completed.result_kind == .rows) {
                slot.* = .{ .id = state.id(), .reference = state.receipt.binding.intent.workload, .intent = retained_workload.? };
                retained_workload = null;
            };
            return completed;
        }
        if (state.pending and !is_wait) self.notify();
        var result = try self.status(allocator, observer, table, statement.namespace, state.id());
        if (result.wait != null and attempt.wait != null) {
            try result.wait.?.requireSame(attempt.wait.?);
            result.wait = attempt.wait;
        }
        return result;
    }
    const terminal = self.foreground(observer, table, state, deadline) catch |err| switch (err) {
        error.GatewayDeadline, error.Conflict => null,
        else => if (wire.Client.unavailable(err)) null else return err,
    };
    finishTableClaim(table_claim, statement, terminal);
    if (terminal != null)
        return self.project(state, terminal, null);
    if (state.pending) self.notify();
    return self.status(allocator, observer, table, statement.namespace, state.id()) catch |err| switch (err) {
        error.GatewayDeadline, error.Conflict => if (state.receipt.binding.intent != .workload) self.project(state, null, null) else return err,
        else => if (wire.Client.unavailable(err) and state.receipt.binding.intent != .workload) self.project(state, null, null) else return err,
    };
}
fn requireRoute(state: c.DirectClientToken.Progress, table: *c.DirectTableClient, namespace: u64) !void {
    const intent = state.receipt.binding.intent;
    if (!std.meta.eql(intent.connection(), table.connection) or intent.namespace() != namespace) return error.GatewayCatalogDenied;
}
fn foreground(self: *Self, observer: *g.Client, table: *c.DirectTableClient, state: c.DirectClientToken.Progress, deadline: Deadline) !?g.Terminal {
    const intent = state.receipt.binding.intent;
    if (!state.pending or state.cancel) return null;
    if (intent == .kv and intent.kv.kind != .ddl) {
        try deadline.check(self.io);
        var terminal: g.Terminal = undefined;
        if (intent.kv.admit(table.*)) |response| {
            defer response.deinit();
            terminal = (try g.Terminal.fromReference(intent, response.value.result)) orelse return null;
        } else |err| switch (err) {
            error.DuplicatePrimaryKey, error.DuplicateBatchKey => terminal = try g.Terminal.rejectedKV(intent.kv, .duplicate_key),
            error.TableRowMissing => terminal = try g.Terminal.rejectedKV(intent.kv, .missing_row),
            error.TableDefinitionChanged => terminal = try g.Terminal.rejectedKV(intent.kv, .definition_changed),
            error.TableDataChanged, error.KVRevisionChanged => terminal = try g.Terminal.rejectedKV(intent.kv, .data_changed),
            else => return err,
        }
        deadline.check(self.io) catch {
            self.notify();
            return terminal;
        };
        _ = c.DirectClientToken.update(table.*, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = false, .cancel = state.cancel, .record = state.record }) catch {
            self.notify();
            return terminal;
        };
        return terminal;
    }
    if (intent != .table) return null;
    switch (intent.table.binding.action) {
        .insert, .update, .delete => {},
        else => return null,
    }
    // Every call carries the activation lease fixed by admission. The claim
    // prevents background scheduling while this caller owns foreground work.
    // Only the owner's freshly authorized terminal response supplies the counts.
    const response = try self.available(observer, deadline, c.DirectTableClient.call, .{ table.*, c.DirectTableProtocol.Action{ .commit_saved = intent.table } });
    defer response.deinit();
    const terminal = (try g.Terminal.fromReference(intent, response.value.result)) orelse return null;
    // Settlement releases the account reservation and pending index entry. Its
    // failure cannot erase an already observed terminal result or replay SQL.
    // Recovery reuses the frozen reference and preserves a concurrent cancel.
    deadline.check(self.io) catch {
        self.notify();
        return terminal;
    };
    _ = c.DirectClientToken.update(table.*, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = false, .cancel = state.cancel, .record = state.record }) catch {
        self.notify();
        // Bookkeeping may have failed because authority changed while the
        // terminal was buffered. Re-observe the original receipt before
        // disclosing it; a denied/unavailable recheck cannot release old counts.
        const observed = try self.available(observer, deadline, c.DirectIntent.Reference.operation, .{ intent, table.*, .inspect, 1 });
        defer observed.deinit();
        const current = (try g.Terminal.fromReference(intent, observed.value.result)) orelse return error.MissingGatewayTerminal;
        if (!std.meta.eql(current, terminal)) return error.GatewayIdentityConflict;
        return current;
    };
    return terminal;
}
pub const Execution = struct { terminal: g.Terminal, completion: g.results.CommandCompletion };

/// Wire callers create one operation, then observe its original workload result.
/// The protocol-neutral result distinguishes command completion from rows;
/// neither branch recreates SQL or turns an absent receipt into rejection.
pub fn executeWorkloadPrepared(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, deadline: Deadline, operation: *?u64, fresh_prepared: bool, fresh_fenced: bool) !g.session_protocol.Operation {
    return self.executeWorkloadRetained(allocator, observer, table, statement, values, deadline, operation, fresh_prepared, fresh_fenced, null, null);
}
pub fn executeWorkloadRetained(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, deadline: Deadline, operation: *?u64, fresh_prepared: bool, fresh_fenced: bool, out_reference: ?*c.DirectWorkloadIntent.Reference, out_intent: ?*?c.DirectWorkloadIntent) !g.session_protocol.Operation {
    if (out_intent) |slot| slot.* = null;
    if (!statement.isWorkload()) return error.ExpectedSqlWorkload;
    var nonce: [16]u8 = undefined;
    try self.io.randomSecure(&nonce);
    const selected = self.claim(nonce);
    try selected.lock(self.io);
    self.beginForeground();
    var claimed = true;
    defer if (claimed) {
        selected.unlock(self.io);
        self.endForeground();
    };
    errdefer self.notify();
    var newly_bound = false;
    var retained_workload: ?c.DirectWorkloadIntent = null;
    defer if (retained_workload) |*workload| workload.deinit();
    const state = try self.admitWithWake(allocator, observer, table, statement, values, nonce, @splat(0), deadline, operation, null, false, true, fresh_prepared, fresh_prepared, fresh_fenced, &newly_bound, &retained_workload);
    try requireRoute(state, table, statement.namespace);
    const attempt = try g.WorkloadOperations.attemptWithIntent(table.*, state, if (retained_workload) |*workload| workload else null, newly_bound);
    claimed = false;
    selected.unlock(self.io);
    self.endForeground();
    if (attempt.terminal) |terminal| {
        if (out_reference) |slot| slot.* = state.receipt.binding.intent.workload;
        if (out_intent) |slot| {
            slot.* = retained_workload;
            retained_workload = null;
        }
        return terminal;
    }
    if (state.pending) self.notify();
    while (true) {
        try deadline.check(self.io);
        const epoch = self.progress_epoch.load(.acquire);
        var result = try self.status(allocator, observer, table, statement.namespace, state.id());
        if (result.wait != null) {
            if (attempt.wait) |value| {
                try result.wait.?.requireSame(value);
                result.wait = value;
            }
            return result;
        }
        if (result.phase == .terminal) {
            if (out_reference) |slot| slot.* = state.receipt.binding.intent.workload;
            if (out_intent) |slot| {
                slot.* = retained_workload;
                retained_workload = null;
            }
            return result;
        }
        try self.waitProgressAfter(epoch, deadline);
    }
}
pub fn execute(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, deadline: Deadline, operation: *?u64) !Execution {
    return self.executePrepared(allocator, observer, table, statement, values, deadline, operation, false, false);
}
pub fn executePrepared(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, deadline: Deadline, operation: *?u64, fresh_prepared: bool, fresh_fenced: bool) !Execution {
    var nonce: [16]u8 = undefined;
    try self.io.randomSecure(&nonce);
    const selected = self.claim(nonce);
    try selected.lock(self.io);
    self.beginForeground();
    var claimed = true;
    defer if (claimed) {
        selected.unlock(self.io);
        self.endForeground();
    };
    const table_claim = self.tableClaim(statement);
    if (table_claim) |claim_slot| try claim_slot.mutex.lock(self.io);
    var table_claimed = table_claim != null;
    defer if (table_claimed) table_claim.?.mutex.unlock(self.io);
    errdefer self.notify();
    try self.settlePendingTableClaim(table_claim, observer, table, deadline);
    const fresh_table = tableFresh(table_claim, statement, fresh_prepared);
    const state = try self.admitWithWake(allocator, observer, table, statement, values, nonce, @splat(0), deadline, operation, null, false, true, fresh_prepared, fresh_table, fresh_fenced, null, null);
    recordPendingTableClaim(table_claim, state);
    errdefer finishTableClaim(table_claim, statement, null);
    const intent = state.receipt.binding.intent;
    try requireRoute(state, table, statement.namespace);
    // Catalog already owns this token and frozen intent. A private candidate
    // fenced by collection must yield to original-work recovery, just as a
    // conflict received after commit must resolve the original receipt.
    const completed = self.foreground(observer, table, state, deadline) catch |err|
        if (table.service.contended(err)) null else return err;
    finishTableClaim(table_claim, statement, completed);
    if (completed) |terminal| return .{ .terminal = terminal, .completion = try terminal.completion(try g.IntentReference.commandKind(intent), .{ .account = self.execution.configuration.account, .id = state.id() }) };
    table_claimed = false;
    if (table_claim) |claim_slot| claim_slot.mutex.unlock(self.io);
    claimed = false;
    selected.unlock(self.io);
    self.endForeground();
    self.notify();
    while (true) {
        try deadline.check(self.io);
        const epoch = self.progress_epoch.load(.acquire);
        const response = try self.available(observer, deadline, c.DirectIntent.Reference.operation, .{ intent, table.*, .inspect, 1 });
        defer response.deinit();
        if (try g.Terminal.fromReference(intent, response.value.result)) |terminal| return .{ .terminal = terminal, .completion = try terminal.completion(try g.IntentReference.commandKind(intent), .{ .account = self.execution.configuration.account, .id = state.id() }) };
        try self.waitProgressAfter(epoch, deadline);
    }
}
pub fn status(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, namespace: u64, id: u64) !g.session_protocol.Operation {
    _ = allocator;
    var source = try observer.source();
    const state = try source.operation(id);
    const intent = state.receipt.binding.intent;
    try requireRoute(state, table, namespace);
    if (intent == .workload) return g.WorkloadOperations.status(table.*, state);
    if (intent == .transaction_call) return g.TransactionWork.status(table.*, state);
    const response = try intent.operation(table.*, .inspect, 1);
    defer response.deinit();
    var outcome = try g.Terminal.fromReference(intent, response.value.result);
    if (!state.pending and outcome == null and intent == .kv and intent.kv.kind != .ddl) {
        outcome = if (state.cancel) try g.Terminal.cancelledKV(intent.kv) else try g.Terminal.rejectedKV(intent.kv, .duplicate_key);
    }
    if (!state.pending and outcome == null) return error.MissingGatewayTerminal;
    return self.project(state, outcome, if (response.value.result == .namespace_operation and response.value.result.namespace_operation == .operation) try response.value.result.namespace_operation.operation.diagnostic() else null);
}
fn project(self: *Self, state: c.DirectClientToken.Progress, outcome: ?g.Terminal, diagnostic: @FieldType(g.session_protocol.Operation, "diagnostic")) !g.session_protocol.Operation {
    const command = try g.IntentReference.commandKind(state.receipt.binding.intent);
    const identity: g.results.Operation = .{ .account = self.execution.configuration.account, .id = state.id() };
    const completion = if (outcome) |terminal| try terminal.completion(command, identity) else null;
    return .{ .identity = identity, .command = command, .token = state.receipt.binding.key.token, .phase = if (completion != null) .terminal else .ready, .blocked = false, .cancellation_requested = state.cancel, .outcome = if (completion) |value| value.outcome else null, .matched = if (completion) |value| value.counts.?.matched else 0, .changed = if (completion) |value| value.counts.?.changed else 0, .diagnostic = diagnostic };
}

/// Submit one frozen transaction command through the existing SQL token owner.
/// The exact reference is retained before its native owner admits or executes it.
pub const TransactionSubmission = struct { token: [16]u8, fingerprint: [32]u8, call: c.DirectTransactionCall };
pub fn submitTransaction(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, namespace: u64, request: g.TransactionWork.Request, nonce: [16]u8, fingerprint: [32]u8, deadline: Deadline, operation: *?u64, submission: *?TransactionSubmission) !g.session_protocol.Operation {
    const selected = self.claim(nonce);
    try selected.lock(self.io);
    defer selected.unlock(self.io);
    errdefer self.notify();
    try deadline.check(self.io);
    try self.available(observer, deadline, Self.fence, .{ self, observer });
    table.lease = self.lease();
    var source = try observer.source();
    if (try self.available(observer, deadline, g.Client.Source.lookup, .{ &source, nonce, @as(?[32]u8, fingerprint) })) |state| {
        operation.* = state.id();
        try requireRoute(state, table, namespace);
        const result = try self.available(observer, deadline, g.TransactionWork.advance, .{ table.*, state, false });
        if (transactionPending(result)) self.notify();
        return g.TransactionWork.project(table.*, state, result);
    }
    var caller = table.*;
    caller.transaction = null;
    const call = try g.TransactionWork.build(allocator, self.io, self.execution.configuration, caller, namespace, nonce, fingerprint, request);
    // Preserve complete original recovery material before a bind can be sent.
    submission.* = .{ .token = nonce, .fingerprint = fingerprint, .call = call };
    return self.resumeTransactionClaimed(observer, caller, submission.*.?, deadline, operation);
}
pub fn resumeTransactionSubmission(self: *Self, observer: *g.Client, caller: c.DirectTableClient, submission: TransactionSubmission, deadline: Deadline, operation: *?u64) !g.session_protocol.Operation {
    const selected = self.claim(submission.token);
    try selected.lock(self.io);
    defer selected.unlock(self.io);
    return self.resumeTransactionClaimed(observer, caller, submission, deadline, operation);
}
fn resumeTransactionClaimed(self: *Self, observer: *g.Client, caller: c.DirectTableClient, submission: TransactionSubmission, deadline: Deadline, operation: *?u64) !g.session_protocol.Operation {
    errdefer self.notify();
    try self.available(observer, deadline, Self.fence, .{ self, observer });
    if (!std.meta.eql(caller.connection, submission.call.connection)) return error.CatalogIdentityConflict;
    var control = caller;
    control.transaction = null;
    const binding: c.DirectClientToken.Binding = .{
        .key = .{ .definition = p.Growth.current_definition, .connection = control.connection, .account = self.execution.configuration.account, .token = submission.token },
        .fingerprint = submission.fingerprint,
        .intent = .{ .transaction_call = submission.call },
        .budget = self.execution.configuration.budget(c.DirectTransactionCall.reservation_bytes),
    };
    const receipt = self.available(observer, deadline, c.DirectClientToken.bind, .{ control, binding }) catch |err| {
        if (observer.transport.contended(err)) {
            var source = try observer.source();
            if (try self.available(observer, deadline, g.Client.Source.lookup, .{ &source, submission.token, @as(?[32]u8, submission.fingerprint) })) |original| {
                operation.* = original.id();
                try requireRoute(original, &control, submission.call.namespace);
                if (original.pending) self.notify();
                return g.TransactionWork.status(control, original);
            }
        }
        return err;
    };
    operation.* = receipt.position.next_lsn;
    var source = try observer.source();
    const state = try self.available(observer, deadline, g.Client.Source.operation, .{ &source, operation.*.? });
    const result = try self.available(observer, deadline, g.TransactionWork.advance, .{ control, state, false });
    if (transactionPending(result)) self.notify();
    return g.TransactionWork.project(control, state, result);
}
