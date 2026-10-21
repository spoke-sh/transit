//! Live account worker and bounded command handoff. The application supplies an
//! exclusive activation marker before ticking; native generation remains authority.
const std = @import("std");
const g = @import("root.zig");
const s = g.station;
const c = g.catalog;
const p = c.protocol;
const Self = @This();
allocator: std.mem.Allocator,
io: std.Io,
ledger: g.Ledger,
background: s.client.Client,
ingress_wire: s.client.Client,
ingress: g.Client,
private: g.Client,
server: s.GenServer,
behavior: g.Behavior,
coordinator: g.Coordinator,
ingress_mutex: std.Io.Mutex = .init,
settings_mutex: std.Io.Mutex = .init,
capture_mutex: std.Io.Mutex = .init,
admission_mutex: std.Io.Mutex = .init,
ingress_lane: g.ControlLane = .{},
private_lane: g.ControlLane = .{},
ready: std.atomic.Value(bool) = .init(false),
await_initialization: bool = false,
pub const Keys = struct { worker: p.Ed25519.KeyPair, ingress: p.Ed25519.KeyPair, coordinator: p.Ed25519.KeyPair, table: p.Ed25519.KeyPair, reader: p.Ed25519.KeyPair };
fn staleRead(client: *s.client.Client, err: anyerror) bool {
    return client.contended(err) or ((err == error.Rejected or err == error.Conflict) and client.last_rejection == .StaleStateResource);
}
fn retryObservation(client: *s.client.Client, err: anyerror) bool {
    return staleRead(client, err) or client.contended(err) or s.client.Client.unavailable(err);
}
/// Construction owns transports, but neither initializes an unprovisioned ledger
/// nor assumes ownership. The operator provisions and initializes before start.
pub fn init(allocator: std.mem.Allocator, io: std.Io, url: []const u8, ledger: g.Ledger, generation: u64, association: []const u8, keys: Keys, timeout_ms: u32) !*Self {
    return create(allocator, io, url, ledger, generation, association, keys, timeout_ms, false);
}
/// A separate fenced bootstrap activation consumes an operator-signed initialize
/// control. It never supplies SQL listeners and cannot initialize by itself.
pub fn bootstrap(allocator: std.mem.Allocator, io: std.Io, url: []const u8, ledger: g.Ledger, generation: u64, association: []const u8, keys: Keys, timeout_ms: u32) !*Self {
    return create(allocator, io, url, ledger, generation, association, keys, timeout_ms, true);
}
fn create(allocator: std.mem.Allocator, io: std.Io, url: []const u8, ledger: g.Ledger, generation: u64, association: []const u8, keys: Keys, timeout_ms: u32, await_initialization: bool) !*Self {
    try ledger.configuration.validate();
    if (generation == 0 or timeout_ms == 0 or timeout_ms > 60000) return error.InvalidGatewayConfiguration;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{ .allocator = allocator, .io = io, .ledger = ledger, .background = s.client.Client.init(allocator, io, url), .ingress_wire = s.client.Client.init(allocator, io, url), .ingress = undefined, .private = undefined, .server = undefined, .behavior = .{ .allocator = allocator, .ledger = ledger }, .coordinator = undefined };
    errdefer self.background.deinit();
    errdefer self.ingress_wire.deinit();
    self.background.timeout_ms = timeout_ms;
    self.ingress_wire.timeout_ms = timeout_ms;
    self.await_initialization = await_initialization;
    const config = ledger.configuration;
    self.ingress = .{ .transport = &self.ingress_wire, .ledger = ledger, .principal = config.ingress, .key = keys.ingress };
    self.private = .{ .transport = &self.background, .ledger = ledger, .principal = config.coordinator, .key = keys.coordinator };
    self.coordinator = .{ .allocator = allocator, .client = &self.private, .table_key = keys.table, .reader_key = keys.reader, .generation = generation };
    self.server = try s.GenServer.init(.{ .client = &self.background, .realm = config.realm, .principal = config.worker, .pid = config.owner, .generation = generation, .key = keys.worker }, association);
    self.server.input_guard = self.behavior.guard();
    self.server.failure_policy = .stop;
    _ = try self.server.session.receive();
    try self.coordinator.fence();
    var source = try self.private.source();
    _ = ledger.head(&source) catch |err| {
        if (await_initialization and err == error.GatewayNotInitialized) return self;
        return err;
    };
    return self;
}
/// Call only after joining the worker and every borrowing connection. A restart
/// requires a new native generation; process shutdown is no recovery evidence.
pub fn deinit(self: *Self) void {
    self.coordinator.deinit();
    self.background.deinit();
    self.ingress_wire.deinit();
    const allocator = self.allocator;
    std.crypto.secureZero(u8, std.mem.asBytes(self));
    allocator.destroy(self);
}
fn advancePrivate(self: *Self) !bool {
    if (self.private_lane.pending == null) return false;
    const result = self.private_lane.poll(&self.private) catch |err| {
        if (staleRead(&self.background, err)) return false;
        if (err == error.Conflict and self.background.last_rejection == .ConflictingRetry) {
            try self.private_lane.discardConflictingProposal(&self.coordinator);
            return true;
        }
        return err;
    };
    return switch (result) {
        .processed => |rejected| if (rejected != null) error.GatewayControlRejected else true,
        else => false,
    };
}
/// A bounded pass runs independently of socket lifetimes. The application keeps
/// polling after temporary native unavailability and stops on lost authority.
pub fn tick(self: *Self) !bool {
    errdefer self.ready.store(false, .release);
    const now: u64 = @intCast(std.Io.Clock.real.now(self.io).toMilliseconds());
    const result = self.server.step(self.behavior.interface(), now + 30000) catch |err| {
        if (self.background.contended(err)) {
            if (self.server.pending == null and self.server.ready != null) try self.server.discard();
            return false;
        }
        if (self.server.pending == null and (err == error.Conflict or err == error.Rejected) and (self.background.last_rejection == .StaleStateResource or self.background.last_rejection == .QueryExpired or self.background.last_rejection == .StateViewExpired)) {
            if (self.background.last_rejection == .StateViewExpired) self.server.view_id = null;
            return false;
        }
        if (s.client.Client.unavailable(err) and self.server.pending == null and self.server.ready != null) try self.server.discard();
        return err;
    };
    if (result == .blocked) return self.server.handler_error orelse error.GatewayOwnerUnavailable;
    // Detached ingress never blocks the owner thread waiting for itself.
    if (self.ingress_mutex.tryLock()) {
        defer self.ingress_mutex.unlock(self.io);
        _ = self.ingress_lane.poll(&self.ingress) catch |err| if (staleRead(&self.ingress_wire, err)) g.ControlLane.Result.pending else return err;
    }
    // Finish the captured turn before potentially long coordinator reads. A
    // separate intent acquisition must not consume this turn's view lifetime.
    if (result == .progress) return true;
    var progressed = result != .idle;
    if (self.private_lane.pending != null) {
        progressed = try self.advancePrivate() or progressed;
    } else switch (self.coordinator.next() catch |err| {
        if (staleRead(&self.background, err)) return progressed;
        if (self.await_initialization and err == error.GatewayNotInitialized) return progressed;
        return err;
    }) {
        .idle, .blocked => {},
        .control => |command| {
            try self.private_lane.start(&self.private, command);
            progressed = try self.advancePrivate() or progressed;
        },
        .dispatch => |action| {
            // Receipt loss leaves the committed Table pointer unchanged. A
            // subsequent pass dispatches the identical published signed bytes.
            const command = self.coordinator.dispatch(action) catch |err| {
                if (staleRead(&self.background, err)) return progressed;
                return err;
            };
            try self.private_lane.start(&self.private, command);
            progressed = try self.advancePrivate() or progressed;
        },
    }
    self.ready.store(true, .release);
    return progressed;
}
pub const Deadline = struct {
    start: std.Io.Timestamp,
    milliseconds: u32,
    cancellation: ?*const std.atomic.Value(bool) = null,
    pub fn check(self: Deadline, io: std.Io) !void {
        if (self.cancellation) |cancel| if (cancel.load(.acquire)) return error.GatewayWaitCancelled;
        if (self.start.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() >= self.milliseconds) return error.GatewayDeadline;
    }
};
fn finishControl(self: *Self, deadline: Deadline) !?g.Control.Disposition {
    while (true) {
        try deadline.check(self.io);
        switch (self.ingress_lane.poll(&self.ingress) catch |err| {
            if (!s.client.Client.unavailable(err) and !staleRead(&self.ingress_wire, err)) return err;
            try self.io.sleep(.fromMilliseconds(5), .awake);
            continue;
        }) {
            .idle => return null,
            .admitted => return null,
            .processed => |rejected| return rejected,
            .pending => try self.io.sleep(.fromMilliseconds(5), .awake),
        }
    }
}
/// A deadline/cancellation leaves any prepared request in account-owned memory.
/// The background tick takes over after this function releases the lane lock.
pub fn control(self: *Self, command: g.Control.Command, deadline: Deadline) !void {
    return self.handoff(command, deadline, .processed);
}
fn handoff(self: *Self, command: g.Control.Command, deadline: Deadline, completion: enum { processed, admitted }) !void {
    if (completion == .admitted and command != .intent_part) return error.InvalidGatewayCommand;
    while (!self.ingress_mutex.tryLock()) {
        try deadline.check(self.io);
        try self.io.sleep(.fromMilliseconds(5), .awake);
    }
    defer self.ingress_mutex.unlock(self.io);
    _ = try self.finishControl(deadline); // Prior caller's detached observation.
    try deadline.check(self.io);
    while (!self.ready.load(.acquire)) {
        try deadline.check(self.io);
        try self.io.sleep(.fromMilliseconds(20), .awake);
    }
    try prepareControl(&self.ingress_lane, &self.ingress, command, deadline, self.io);
    self.ingress_lane.pending.?.admission_only = completion == .admitted;
    if (try self.finishControl(deadline) != null) return error.GatewayControlRejected;
}
/// Only prepare reads are repeated. Once preparation publishes into the lane,
/// finishControl owns the exact request, including any uncertain native send.
fn prepareControl(lane: *g.ControlLane, client: anytype, command: g.Control.Command, deadline: Deadline, io: std.Io) !void {
    var attempts: u8 = 0;
    while (true) {
        try deadline.check(io);
        lane.start(client, command) catch |err| {
            if (attempts == 64 or !retryObservation(client.transport, err)) return err;
            attempts += 1;
            try io.sleep(.fromMilliseconds(20), .awake);
            continue;
        };
        return;
    }
}
/// observer and table borrow the connection's own native transport; no HTTP
/// client or mutable sequence state is shared between concurrent sessions.
pub fn execute(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.TableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, deadline: Deadline, operation: *?u64) !g.Terminal {
    var nonce: [16]u8 = undefined;
    try self.io.randomSecure(&nonce);
    const item = try self.admit(allocator, observer, table, statement, values, nonce, @splat(0), deadline, operation);
    var source = try observer.source();
    const bytes = try g.Upload.read(allocator, self.ledger.publication(item.id), &source, 1, self.ledger.configuration.intent_bytes);
    defer allocator.free(bytes);
    var intent = try c.TableIntent.restore(allocator, bytes);
    defer intent.deinit();
    while (true) {
        try deadline.check(self.io);
        const terminal = self.observe(observer, table, &intent, item.id) catch |err| {
            if (!retryObservation(observer.transport, err)) return err;
            try self.io.sleep(.fromMilliseconds(5), .awake);
            continue;
        };
        if (terminal) |value| return value;
        try self.io.sleep(.fromMilliseconds(5), .awake);
    }
}
/// Look up before preparing SQL. Existing tokens never recompile or republish
/// missing intent parts; an incomplete reservation remains explicitly incomplete.
pub fn lookup(self: *Self, observer: *g.Client, nonce: [16]u8, fingerprint: ?[32]u8) !?g.LedgerRecords.Operation {
    var source = try observer.source();
    const item = (try self.ledger.discover(&source, nonce)) orelse return null;
    const index = try g.LedgerRecords.decode(g.LedgerRecords.Nonce, (try source.read(g.LedgerRecords.nonceKey(nonce))) orelse return error.MissingGatewayOperation);
    if (fingerprint) |expected| if (!std.mem.eql(u8, &expected, &index.fingerprint)) return error.SqlTokenConflict;
    return item;
}
pub fn admit(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.TableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, nonce: [16]u8, fingerprint: [32]u8, deadline: Deadline, operation: *?u64) !g.LedgerRecords.Operation {
    // This lock covers publication, never outcome waiting or client output.
    // Read sessions and the independently reserved control lane remain separate.
    while (!self.admission_mutex.tryLock()) {
        try deadline.check(self.io);
        try self.io.sleep(.fromMilliseconds(1), .awake);
    }
    defer self.admission_mutex.unlock(self.io);
    if (try self.lookup(observer, nonce, fingerprint)) |existing| {
        operation.* = existing.id;
        return existing;
    }
    try statement.checkValues(allocator, values);
    try statement.validate(table);
    if (observer.principal != self.ledger.configuration.ingress or !std.mem.eql(u8, &try observer.ledger.configuration.digest(), &try self.ledger.configuration.digest())) return error.GatewayIdentityConflict;
    const connection = table.connection;
    try self.control(.{ .begin = .{ .nonce = nonce, .fingerprint = fingerprint, .binding = .{ .resource = connection.scope.resource, .catalog = connection.scope.catalog, .owner = connection.owner, .namespace = connection.namespace, .role = connection.role } } }, deadline);
    const item = while (true) {
        try deadline.check(self.io);
        break self.discover(observer, nonce) catch |err| {
            if (!retryObservation(observer.transport, err)) return err;
            try self.io.sleep(.fromMilliseconds(5), .awake);
            continue;
        };
    };
    operation.* = item.id;
    var attempts: u8 = 0;
    var intent = while (true) {
        try deadline.check(self.io);
        break statement.bindWrite(allocator, table, values, item.id) catch |err| {
            if (attempts == 64 or (!retryObservation(table.transport, err) and err != error.CatalogDefinitionChanged)) return err;
            attempts += 1;
            try self.io.sleep(.fromMilliseconds(if (s.client.Client.unavailable(err)) 20 else 1), .awake);
            continue;
        };
    };
    defer intent.deinit();
    try self.control(.{ .begin_intent = .{ .operation = item.id, .spec = try s.Publication.Digest.of(g.LedgerRecords.intent_format, intent.bytes) } }, deadline);
    var offset: usize = 0;
    while (offset < intent.bytes.len) {
        const count = @min(g.Upload.part_bytes, intent.bytes.len - offset);
        // Admission retains the exact bytes in the ordered native mailbox.
        // Keep only one uncertain send resident; let the ledger consume parts
        // independently, then require the seal's domain result below.
        try self.handoff(.{ .intent_part = .{ .operation = item.id, .part = try g.Control.Part.init(@intCast(offset), intent.bytes[offset..][0..count]) } }, deadline, .admitted);
        offset += count;
    }
    try self.control(.{ .seal_intent = item.id }, deadline);
    return try self.discover(observer, nonce);
}
/// A service-side status read reopens the frozen intent only to check current
/// disclosure rights. It cannot dispatch, recompile or invent an outcome.
pub fn status(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.TableClient, id: u64) !g.session_protocol.Operation {
    var source = try observer.source();
    const item = try self.ledger.operation(&source, id);
    const connection = table.connection;
    if (item.resource != connection.scope.resource or item.catalog != connection.scope.catalog or item.owner != connection.owner or item.namespace != connection.namespace or item.selectedRole() != connection.role) return error.GatewayCatalogDenied;
    _ = try table.describeDatabase();
    var outcome: ?g.Terminal = null;
    if (item.phase == .ready or item.phase == .active or item.phase == .terminal) {
        const bytes = try g.Upload.read(allocator, self.ledger.publication(id), &source, 1, self.ledger.configuration.intent_bytes);
        defer allocator.free(bytes);
        var intent = try c.TableIntent.restore(allocator, bytes);
        defer intent.deinit();
        _ = try table.inspectIntent(&intent);
        if (item.phase == .terminal) outcome = try self.observe(observer, table, &intent, id);
    }
    return .{
        .identity = .{ .account = self.ledger.configuration.account, .id = id },
        .token = item.nonce,
        .phase = switch (item.phase) {
            inline else => |phase| @field(@FieldType(g.session_protocol.Operation, "phase"), @tagName(phase)),
        },
        .blocked = item.blocked != 0,
        .cancellation_requested = item.cancel != 0,
        .outcome = if (outcome) |terminal| switch (terminal.state) {
            .applied => .applied,
            .unchanged => .unchanged,
            .rejected => .rejected,
            .cancelled, .upload_cancelled => .cancelled,
        } else null,
        .matched = if (outcome) |terminal| terminal.matched else 0,
        .changed = if (outcome) |terminal| terminal.changed else 0,
    };
}

fn discover(self: *Self, observer: *g.Client, nonce: [16]u8) !g.LedgerRecords.Operation {
    var source = try observer.source();
    return (try self.ledger.discover(&source, nonce)) orelse error.MissingGatewayOperation;
}
fn observe(self: *Self, observer: *g.Client, table: *c.TableClient, intent: *const c.TableIntent, id: u64) !?g.Terminal {
    var source = try observer.source();
    const current = try self.ledger.operation(&source, id);
    if (current.phase == .terminal) {
        const bytes = (try source.read(g.LedgerRecords.key('t', id, 0))) orelse return error.MissingGatewayTerminal;
        const terminal = try g.LedgerRecords.decode(g.Terminal, bytes);
        // A cached ledger summary never carries current disclosure rights.
        const native = try table.inspectIntent(intent);
        const actual = if (native.outcome) |outcome| try g.Terminal.fromOutcome(outcome) else if (native.upload) |upload| try g.Terminal.fromUpload(upload) else return error.MissingGatewayTerminal;
        if (!std.meta.eql(terminal, actual)) return error.GatewayIdentityConflict;
        return terminal;
    }
    if (current.phase == .abandoned or current.blocked != 0) return error.GatewayOperationBlocked;
    return null;
}

test "observation retries unavailable transport without treating denial as transient" {
    var wire: s.client.Client = undefined;
    wire.last_rejection = .AccessDenied;
    try std.testing.expect(retryObservation(&wire, error.AuthorityTimeout));
    try std.testing.expect(!retryObservation(&wire, error.Rejected));
    try std.testing.expect(!retryObservation(&wire, error.CatalogDenied));
    try std.testing.expect(!retryObservation(&wire, error.Canceled));
    wire.last_rejection = .StaleStateResource;
    try std.testing.expect(retryObservation(&wire, error.Conflict));
    wire.last_rejection = .Conflict;
    try std.testing.expect(retryObservation(&wire, error.Conflict));
    wire.last_rejection = .ConflictingRetry;
    try std.testing.expect(!retryObservation(&wire, error.Conflict));
    try std.testing.expect(!retryObservation(&wire, error.InvalidGatewayRecord));
}

test "unsent control preparation retries observations and preserves the published request" {
    const t = std.testing;
    const Fake = struct {
        transport: *s.client.Client,
        attempts: u8 = 0,
        failure: anyerror = error.AuthorityUnavailable,
        pub fn prepare(self: *@This(), command: g.Control.Command) !g.Client.Prepared {
            self.attempts += 1;
            if (self.attempts <= 2) return self.failure;
            const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(11));
            return .{ .version = 1, .definition = p.Growth.current_definition, .realm = 1, .resource = 2, .owner = 3, .configuration = @splat(7), .signed = try p.Growth.sign(.{ .realm = 1, .principal = 4, .sequence = 5, .command = .{ .send = .{ .pid = 3, .value = try (s.Frame{ .kind = .cast, .payload = try command.encode() }).encode() } } }, key) };
        }
    };
    var wire: s.client.Client = undefined;
    wire.last_rejection = .HttpCapacity;
    var client: Fake = .{ .transport = &wire };
    var lane: g.ControlLane = .{};
    const deadline: Deadline = .{ .start = std.Io.Clock.awake.now(t.io), .milliseconds = 5000 };
    try prepareControl(&lane, &client, .{ .seal_intent = 17 }, deadline, t.io);
    try t.expectEqual(@as(u8, 3), client.attempts);
    const saved = lane.pending.?.prepared;
    try t.expectError(error.GatewayControlBusy, prepareControl(&lane, &client, .{ .seal_intent = 18 }, deadline, t.io));
    try t.expectEqualDeep(saved, lane.pending.?.prepared);
    lane = .{};
    client = .{ .transport = &wire, .failure = error.AccessDenied };
    try t.expectError(error.AccessDenied, prepareControl(&lane, &client, .{ .seal_intent = 17 }, deadline, t.io));
    try t.expectEqual(@as(u8, 1), client.attempts);
    try t.expect(lane.pending == null);
}
