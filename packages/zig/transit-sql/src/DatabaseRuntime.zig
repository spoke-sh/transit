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
work: g.RecoveryWork = .{},
external_work: ?*g.RecoveryWork = null,
wake_mutex: std.Io.Mutex = .init,
progress_cond: std.Io.Condition = .init,
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
pub const Keys = struct { table: p.Ed25519.KeyPair };
const Activation = struct { generation: u64, instance: [16]u8 };
const activation_format: u32 = 0x53514131;
pub fn notify(self: *Self) void {
    self.work.notify(self.io);
}
pub fn notifyExternal(self: *Self) void {
    if (self.external_work) |work| work.notify(self.io);
}
fn claim(self: *Self, token: [16]u8) *std.Io.Mutex {
    return &self.claims[std.hash.Wyhash.hash(0, &token) % self.claims.len];
}

pub fn notifyProgress(self: *Self) void {
    self.wake_mutex.lockUncancelable(self.io);
    defer self.wake_mutex.unlock(self.io);
    self.progress_cond.broadcast(self.io);
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
    start: std.Io.Timestamp,
    milliseconds: u32,
    cancellation: ?*const std.atomic.Value(bool) = null,
    pub fn check(self: Deadline, io: std.Io) !void {
        if (self.cancellation) |requested| if (requested.load(.acquire)) return error.GatewayWaitCancelled;
        if (self.start.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() >= self.milliseconds) return error.GatewayDeadline;
    }
};

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
    const caller = self.private.table(self.execution.configuration.bindings[0]);
    const configuration = try self.execution.configuration.digest();
    const key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = caller.connection, .account = g.AccountIdentity.internal(self.execution.configuration.account, "activation", ""), .token = @splat(0) };
    var state = try c.DirectClientToken.inspect(caller, key);
    if (state == null) {
        const body = try c.DirectRecord.stage(caller, key.account, activation_format, &configuration);
        const receipt = try c.DirectClientToken.bind(caller, .{ .key = key, .fingerprint = configuration, .intent = .{ .external = .{ .connection = caller.connection, .namespace = self.execution.configuration.bindings[0].namespace, .operation = (std.mem.readInt(u64, configuration[0..8], .little) % p.max_counter) + 1, .record = body } } });
        state = c.DirectClientToken.Progress.initial(receipt);
    }
    var current = state orelse return error.MissingGatewayOperation;
    if (!std.mem.eql(u8, &configuration, &current.receipt.binding.fingerprint)) return error.GatewayConfigurationChanged;
    if (current.record) |record| {
        const bytes = try c.DirectRecord.read(self.allocator, caller, record);
        defer self.allocator.free(bytes);
        const saved = try p.Json.parseFromSlice(Activation, self.allocator, bytes);
        defer saved.deinit();
        if (saved.value.generation >= self.generation) return error.StaleGatewayCoordinator;
    }
    var value: Activation = .{ .generation = self.generation, .instance = undefined };
    try self.io.randomSecure(&value.instance);
    const bytes = try p.Json.valueAlloc(self.allocator, value);
    defer self.allocator.free(bytes);
    self.activation_record = try c.DirectRecord.stage(caller, key.account, activation_format, bytes);
    current = try c.DirectClientToken.update(caller, .{ .key = key, .expected = current.revision, .pending = true, .cancel = false, .record = self.activation_record });
    self.activation = current;
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
    if (!std.meta.eql(state.record, self.activation_record)) return error.StaleGatewayCoordinator;
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
            if (reference.kind != .table and reference.kind != .transaction) continue;
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
    self.finishSweep(self.retry_pending);
    return false;
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
    if (self.cleanup_route < bindings.len) return self.private.table(bindings[self.cleanup_route]);
    const resolve = self.read_sources.resolve orelse return null;
    return resolve(self.read_sources.context.?, self.cleanup_route - bindings.len, self.allocator, self.io, &self.background);
}

fn advance(self: *Self, source: *g.Client.Source, state: c.DirectClientToken.Progress) !bool {
    try self.checkFence(source.client);
    if (!state.pending) return false;
    const reference = state.receipt.binding.intent;
    if (reference == .external) return false;
    const caller = source.direct(state);
    if (reference == .transaction_call) {
        return transactionPending(try g.TransactionWork.advance(caller, state, state.cancel));
    }
    // commit_saved resolves an existing receipt before execution. Repeating it
    // with the original frozen reference needs no preceding inspection RPC.
    // Cancellation retains its separate owner transition below.
    if (reference == .table and (reference.table.binding.action == .insert or reference.table.binding.action == .update or reference.table.binding.action == .delete) and !state.cancel) {
        const response = try caller.call(.{ .commit_saved = reference.table });
        defer response.deinit();
        if (try g.Terminal.fromReference(reference, response.value.result) == null) return true;
        _ = try c.DirectClientToken.update(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = false, .cancel = false, .record = state.record });
        return false;
    }
    const observed = try reference.operation(caller, .inspect, 1);
    defer observed.deinit();
    if (try g.Terminal.fromReference(reference, observed.value.result) != null) {
        _ = try c.DirectClientToken.update(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = false, .cancel = state.cancel, .record = state.record });
        return false;
    }
    const absent = switch (observed.value.result) {
        inline .ddl, .rows, .name_assertion, .namespace_operation, .log_operation => |value| value == .not_observed,
        else => return error.InvalidGatewayTerminal,
    };
    const response = try if (absent and !(reference == .name_assertion and state.cancel)) reference.admit(caller) else reference.operation(caller, if (state.cancel) .cancel else .execute, 8);
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
    while (true) {
        try deadline.check(self.io);
        return @call(.auto, function, args) catch |err| {
            if (!wire.Client.unavailable(err) or observer.transport.last_rejection == .StorageQuota or
                started.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds() >= self.background.timeout_ms) return err;
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
    const state = try self.admitWithWake(allocator, observer, table, statement, values, nonce, fingerprint, deadline, operation, true, false, false, false);
    return self.execution.operationFromState(state);
}
fn admitWithWake(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, nonce: [16]u8, fingerprint: [32]u8, deadline: Deadline, operation: *?u64, wake: bool, fresh_nonce: bool, fresh_prepared: bool, fresh_fenced: bool) !c.DirectClientToken.Progress {
    try deadline.check(self.io);
    if (!fresh_fenced) try self.available(observer, deadline, Self.fence, .{ self, observer });
    table.lease = self.lease();
    const expected_fingerprint = if (std.mem.allEqual(u8, &fingerprint, 0)) null else fingerprint;
    if (!fresh_nonce) {
        if (try self.available(observer, deadline, Self.lookupState, .{ observer, nonce, expected_fingerprint })) |previous| {
            operation.* = previous.id();
            _ = try self.execution.operationFromState(previous);
            return previous;
        }
    }
    if (!fresh_prepared) try statement.checkValues(allocator, values);
    var random: [8]u8 = undefined;
    try self.io.randomSecure(&random);
    const id = (std.mem.readInt(u64, &random, .little) % p.max_counter) + 1;
    var fresh = fresh_prepared;
    var intent = self.available(observer, deadline, g.Statement.bindWritePrepared, .{ statement, allocator, table, values, id, &fresh }) catch |err| {
        if (expected_fingerprint != null) {
            if (try self.available(observer, deadline, Self.lookupState, .{ observer, nonce, expected_fingerprint })) |previous| {
                operation.* = previous.id();
                _ = try self.execution.operationFromState(previous);
                return previous;
            }
        }
        return err;
    };
    defer intent.deinit();
    if (try intent.workBytes() > self.execution.configuration.intent_bytes) return error.GatewayRecordTooLarge;
    const reference = try self.available(observer, deadline, g.Statement.Write.stage, .{ &intent, table.*, statement.namespace, self.execution.configuration.account });
    const binding: c.DirectClientToken.Binding = .{ .key = .{ .definition = p.Growth.current_definition, .connection = table.connection, .account = self.execution.configuration.account, .token = nonce }, .fingerprint = expected_fingerprint orelse try reference.digest(), .intent = reference, .budget = self.execution.configuration.budget(self.execution.configuration.reservation()) };
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
    operation.* = receipt.position.next_lsn;
    if (wake) self.notify();
    const state = c.DirectClientToken.Progress.initial(receipt);
    _ = try self.execution.operationFromState(state);
    return state;
}
/// Submit through the same durable token owner and attempt bounded foreground
/// DML completion. Interrupted work remains pending under its original identity;
/// recovery is notified if foreground execution cannot settle the original work.
pub fn submit(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, nonce: [16]u8, fingerprint: [32]u8, deadline: Deadline, operation: *?u64) !g.session_protocol.Operation {
    return self.submitPrepared(allocator, observer, table, statement, values, nonce, fingerprint, deadline, operation, false, false);
}
pub fn submitPrepared(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, nonce: [16]u8, fingerprint: [32]u8, deadline: Deadline, operation: *?u64, fresh_prepared: bool, fresh_fenced: bool) !g.session_protocol.Operation {
    const selected = self.claim(nonce);
    try selected.lock(self.io);
    defer selected.unlock(self.io);
    errdefer self.notify();
    const state = try self.admitWithWake(allocator, observer, table, statement, values, nonce, fingerprint, deadline, operation, false, true, fresh_prepared, fresh_fenced);
    try requireRoute(state, table, statement.namespace);
    if (try self.foreground(observer, table, state, deadline)) |terminal|
        return self.project(state, terminal, null);
    if (state.pending) self.notify();
    return self.status(allocator, observer, table, statement.namespace, state.id());
}
fn requireRoute(state: c.DirectClientToken.Progress, table: *c.DirectTableClient, namespace: u64) !void {
    const intent = state.receipt.binding.intent;
    if (!std.meta.eql(intent.connection(), table.connection) or intent.namespace() != namespace) return error.GatewayCatalogDenied;
}
fn foreground(self: *Self, observer: *g.Client, table: *c.DirectTableClient, state: c.DirectClientToken.Progress, deadline: Deadline) !?g.Terminal {
    const intent = state.receipt.binding.intent;
    if (!state.pending or state.cancel or intent != .table) return null;
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
pub fn execute(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, deadline: Deadline, operation: *?u64) !Execution {
    return self.executePrepared(allocator, observer, table, statement, values, deadline, operation, false, false);
}
pub fn executePrepared(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, deadline: Deadline, operation: *?u64, fresh_prepared: bool, fresh_fenced: bool) !Execution {
    var nonce: [16]u8 = undefined;
    try self.io.randomSecure(&nonce);
    const selected = self.claim(nonce);
    try selected.lock(self.io);
    var claimed = true;
    defer if (claimed) selected.unlock(self.io);
    errdefer self.notify();
    const state = try self.admitWithWake(allocator, observer, table, statement, values, nonce, @splat(0), deadline, operation, false, true, fresh_prepared, fresh_fenced);
    const intent = state.receipt.binding.intent;
    try requireRoute(state, table, statement.namespace);
    if (try self.foreground(observer, table, state, deadline)) |terminal| return .{ .terminal = terminal, .completion = try terminal.completion(try g.IntentReference.commandKind(intent), .{ .account = self.execution.configuration.account, .id = state.id() }) };
    claimed = false;
    selected.unlock(self.io);
    self.notify();
    while (true) {
        try deadline.check(self.io);
        const response = try self.available(observer, deadline, c.DirectIntent.Reference.operation, .{ intent, table.*, .inspect, 1 });
        defer response.deinit();
        if (try g.Terminal.fromReference(intent, response.value.result)) |terminal| return .{ .terminal = terminal, .completion = try terminal.completion(try g.IntentReference.commandKind(intent), .{ .account = self.execution.configuration.account, .id = state.id() }) };
        try self.waitProgress(2);
    }
}
pub fn status(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, namespace: u64, id: u64) !g.session_protocol.Operation {
    _ = allocator;
    var source = try observer.source();
    const state = try source.operation(id);
    const intent = state.receipt.binding.intent;
    try requireRoute(state, table, namespace);
    if (intent == .transaction_call) return g.TransactionWork.status(table.*, state);
    const response = try intent.operation(table.*, .inspect, 1);
    defer response.deinit();
    const outcome = try g.Terminal.fromReference(intent, response.value.result);
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
