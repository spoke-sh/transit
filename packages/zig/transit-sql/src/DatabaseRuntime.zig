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
admission_mutex: std.Io.Mutex = .init,
wake_mutex: std.Io.Mutex = .init,
wake_cond: std.Io.Condition = .init,
progress_cond: std.Io.Condition = .init,
wake_pending: bool = false,
ready: std.atomic.Value(bool) = .init(false),
read_pins: ?g.ReadCache = null,
read_sources: ReadSources = .{},
read_cleanup_failure: std.atomic.Value(u16) = .init(0),
direct_work_failure: std.atomic.Value(u16) = .init(0),
after: u64 = 0,
cleanup_route: usize = 0,
activation: ?c.DirectClientToken.Progress = null,
activation_record: ?c.DirectRecord.Reference = null,
pub const Keys = struct { table: p.Ed25519.KeyPair };
const Activation = struct { generation: u64, instance: [16]u8 };
const activation_format: u32 = 0x53514131;
pub fn notify(self: *Self) void {
    self.wake_mutex.lockUncancelable(self.io);
    defer self.wake_mutex.unlock(self.io);
    self.wake_pending = true;
    self.wake_cond.broadcast(self.io);
}

pub fn notifyProgress(self: *Self) void {
    self.wake_mutex.lockUncancelable(self.io);
    defer self.wake_mutex.unlock(self.io);
    self.progress_cond.broadcast(self.io);
}

pub fn waitIdle(self: *Self, milliseconds: u32) !void {
    try self.wake_mutex.lock(self.io);
    defer self.wake_mutex.unlock(self.io);
    if (self.wake_pending) {
        self.wake_pending = false;
        return;
    }
    self.wake_cond.waitTimeout(self.io, &self.wake_mutex, .{ .duration = .{ .raw = .fromMilliseconds(milliseconds), .clock = .awake } }) catch |err| switch (err) {
        error.Timeout => {},
        else => return err,
    };
    self.wake_pending = false;
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
    try execution.configuration.validate();
    if (generation == 0 or timeout_ms == 0 or timeout_ms > 60000) return error.InvalidGatewayConfiguration;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{ .allocator = allocator, .io = io, .execution = execution, .background = wire.Client.init(allocator, io, url), .ingress_wire = wire.Client.init(allocator, io, url), .ingress = undefined, .private = undefined, .table_key = keys.table, .generation = generation };
    errdefer self.background.deinit();
    errdefer self.ingress_wire.deinit();
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
        state = try c.DirectClientToken.inspect(caller, receipt.binding.key);
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
    self.read_sources = sources;
}
pub fn tick(self: *Self) !bool {
    errdefer self.ready.store(false, .release);
    try self.fence(&self.private);
    var source = try self.private.source();
    const page = g.SessionOperations.list(self.execution, &source, self.after, true) catch |err| {
        if (err != error.AccessDenied and !wire.Client.unavailable(err) and !self.background.contended(err)) return err;
        self.direct_work_failure.store(@intFromError(err), .release);
        const was_ready = self.ready.swap(true, .release);
        if (!was_ready) self.notifyProgress();
        return false;
    };
    var progressed = false;
    for (page.entries) |slot| if (slot) |reference| {
        self.after = reference.id;
        if (reference.kind != .table) continue;
        self.advance(&source, try source.operation(reference.id)) catch |err| {
            self.direct_work_failure.store(@intFromError(err), .release);
            if (wire.Client.unavailable(err) or err == error.ClientOperationConflict or self.background.contended(err) or err == error.AccessDenied) break;
            return err;
        };
        self.direct_work_failure.store(0, .release);
        progressed = true;
        break;
    };
    if (page.next == null) self.after = 0;
    if (self.read_pins) |*pins| {
        if (self.cleanupClient() catch |err| blk: {
            self.read_cleanup_failure.store(@intFromError(err), .release);
            break :blk null;
        }) |caller| {
            const cleaned = pins.tick(caller) catch |err| blk: {
                if (err == error.StaleGatewayCoordinator) return err;
                self.read_cleanup_failure.store(@intFromError(err), .release);
                break :blk false;
            };
            if (cleaned) self.read_cleanup_failure.store(0, .release);
            progressed = progressed or cleaned;
        }
        if (pins.cleanup_slot == 0) self.cleanup_route = (self.cleanup_route + 1) % (self.execution.configuration.bindings.len + self.read_sources.len);
    }
    const was_ready = self.ready.swap(true, .release);
    if (!was_ready or progressed) self.notifyProgress();
    return progressed;
}
fn cleanupClient(self: *Self) !?c.DirectTableClient {
    const bindings = self.execution.configuration.bindings;
    if (self.cleanup_route < bindings.len) return self.private.table(bindings[self.cleanup_route]);
    const resolve = self.read_sources.resolve orelse return null;
    return resolve(self.read_sources.context.?, self.cleanup_route - bindings.len, self.allocator, self.io, &self.background);
}

fn advance(self: *Self, source: *g.Client.Source, state: c.DirectClientToken.Progress) !void {
    try self.fence(source.client);
    if (!state.pending) return;
    const reference = state.receipt.binding.intent;
    if (reference == .external) return;
    const caller = source.direct(state);
    const observed = try reference.operation(caller, .inspect, 1);
    defer observed.deinit();
    if (try g.Terminal.fromReference(reference, observed.value.result) != null) {
        _ = try c.DirectClientToken.update(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = false, .cancel = state.cancel, .record = state.record });
        return;
    }
    const absent = switch (observed.value.result) {
        inline .ddl, .rows, .name_assertion, .namespace_operation => |value| value == .not_observed,
        else => return error.InvalidGatewayTerminal,
    };
    const rows = reference == .table and (reference.table.binding.action == .insert or reference.table.binding.action == .update or reference.table.binding.action == .delete);
    const response = try if (absent and rows and !state.cancel)
        caller.call(.{ .commit_saved = reference.table })
    else if (absent and !(reference == .name_assertion and state.cancel)) reference.admit(caller) else reference.operation(caller, if (state.cancel) .cancel else .execute, 8);
    defer response.deinit();
    if (try g.Terminal.fromReference(reference, response.value.result) != null) _ = try c.DirectClientToken.update(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = false, .cancel = state.cancel, .record = state.record });
}
pub fn cancel(self: *Self, observer: *g.Client, id: u64) !void {
    try self.fence(observer);
    var source = try observer.source();
    const state = try source.operation(id);
    _ = try c.DirectClientToken.update(source.direct(state), .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = state.pending, .cancel = true, .record = state.record });
    self.notify();
}
pub fn resumeOperation(self: *Self, observer: *g.Client, id: u64) !void {
    var source = try observer.source();
    try self.advance(&source, try source.operation(id));
    self.notify();
}
pub fn lookup(self: *Self, observer: *g.Client, nonce: [16]u8, fingerprint: ?[32]u8) !?g.OperationRecords.Operation {
    var source = try observer.source();
    const state = (try source.lookup(nonce, fingerprint)) orelse return null;
    return try self.execution.operation(&source, state.id());
}
pub fn admit(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, nonce: [16]u8, fingerprint: [32]u8, deadline: Deadline, operation: *?u64) !g.OperationRecords.Operation {
    try deadline.check(self.io);
    try self.fence(observer);
    table.lease = self.lease();
    if (try self.lookup(observer, nonce, if (std.mem.allEqual(u8, &fingerprint, 0)) null else fingerprint)) |previous| {
        operation.* = previous.id;
        return previous;
    }
    try statement.checkValues(allocator, values);
    try statement.validate(table);
    var random: [8]u8 = undefined;
    try self.io.randomSecure(&random);
    const id = (std.mem.readInt(u64, &random, .little) % p.max_counter) + 1;
    var intent = try statement.bindWrite(allocator, table, values, id);
    defer intent.deinit();
    if (try intent.workBytes() > self.execution.configuration.intent_bytes) return error.GatewayRecordTooLarge;
    const reference = try intent.stage(table.*, statement.namespace);
    const receipt = c.DirectClientToken.bind(table.*, .{ .key = .{ .definition = p.Growth.current_definition, .connection = table.connection, .account = self.execution.configuration.account, .token = nonce }, .fingerprint = if (std.mem.allEqual(u8, &fingerprint, 0)) try reference.digest() else fingerprint, .intent = reference, .budget = self.execution.configuration.budget(self.execution.configuration.reservation()) }) catch |err| {
        // A concurrent first submission may have won after the initial lookup.
        // Reconcile only the same token; never invent a new operation.
        if (observer.transport.contended(err)) {
            if (try self.lookup(observer, nonce, if (std.mem.allEqual(u8, &fingerprint, 0)) null else fingerprint)) |previous| {
                operation.* = previous.id;
                return previous;
            }
        }
        return err;
    };
    operation.* = receipt.position.next_lsn;
    self.notify();
    var source = try observer.source();
    return self.execution.operation(&source, operation.*.?);
}
pub fn execute(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, deadline: Deadline, operation: *?u64) !struct { terminal: g.Terminal, completion: g.results.CommandCompletion } {
    var nonce: [16]u8 = undefined;
    try self.io.randomSecure(&nonce);
    const item = try self.admit(allocator, observer, table, statement, values, nonce, @splat(0), deadline, operation);
    var source = try observer.source();
    const state = try source.operation(item.id);
    const intent = state.receipt.binding.intent;
    while (true) {
        try deadline.check(self.io);
        const response = try intent.operation(table.*, .inspect, 1);
        defer response.deinit();
        if (try g.Terminal.fromReference(intent, response.value.result)) |terminal| return .{ .terminal = terminal, .completion = try terminal.completion(try g.IntentReference.commandKind(intent), .{ .account = self.execution.configuration.account, .id = item.id }) };
        self.notify();
        try self.waitProgress(2);
    }
}
pub fn status(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.DirectTableClient, namespace: u64, id: u64) !g.session_protocol.Operation {
    _ = allocator;
    var source = try observer.source();
    const state = try source.operation(id);
    const intent = state.receipt.binding.intent;
    if (!std.meta.eql(intent.connection(), table.connection) or intent.namespace() != namespace) return error.GatewayCatalogDenied;
    const response = try intent.operation(table.*, .inspect, 1);
    defer response.deinit();
    const outcome = try g.Terminal.fromReference(intent, response.value.result);
    if (!state.pending and outcome == null) return error.MissingGatewayTerminal;
    const command = try g.IntentReference.commandKind(intent);
    const identity: g.results.Operation = .{ .account = self.execution.configuration.account, .id = id };
    const completion = if (outcome) |terminal| try terminal.completion(command, identity) else null;
    return .{ .identity = identity, .command = command, .token = state.receipt.binding.key.token, .phase = if (completion != null) .terminal else .ready, .blocked = false, .cancellation_requested = state.cancel, .outcome = if (completion) |value| value.outcome else null, .matched = if (completion) |value| value.counts.?.matched else 0, .changed = if (completion) |value| value.counts.?.changed else 0, .diagnostic = if (response.value.result == .namespace_operation and response.value.result.namespace_operation == .operation) try response.value.result.namespace_operation.operation.diagnostic() else null };
}
