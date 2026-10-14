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
ingress_lane: g.ControlLane = .{},
private_lane: g.ControlLane = .{},
ready: std.atomic.Value(bool) = .init(false),
await_initialization: bool = false,
pub const Keys = struct { worker: p.Ed25519.KeyPair, ingress: p.Ed25519.KeyPair, coordinator: p.Ed25519.KeyPair, table: p.Ed25519.KeyPair };
fn staleRead(client: *s.client.Client, err: anyerror) bool {
    return (err == error.Rejected or err == error.Conflict) and client.last_rejection == .StaleStateResource;
}
fn retryObservation(client: *s.client.Client, err: anyerror) bool {
    return staleRead(client, err) or s.client.Client.unavailable(err);
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
    self.coordinator = .{ .allocator = allocator, .client = &self.private, .table_key = keys.table, .generation = generation };
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
            .processed => |rejected| return rejected,
            .pending => try self.io.sleep(.fromMilliseconds(5), .awake),
        }
    }
}
/// A deadline/cancellation leaves any prepared request in account-owned memory.
/// The background tick takes over after this function releases the lane lock.
pub fn control(self: *Self, command: g.Control.Command, deadline: Deadline) !void {
    while (!self.ingress_mutex.tryLock()) {
        try deadline.check(self.io);
        try self.io.sleep(.fromMilliseconds(5), .awake);
    }
    defer self.ingress_mutex.unlock(self.io);
    _ = try self.finishControl(deadline); // Prior caller's detached observation.
    try deadline.check(self.io);
    if (!self.ready.load(.acquire)) return error.GatewayOwnerUnavailable;
    try self.ingress_lane.start(&self.ingress, command);
    if (try self.finishControl(deadline) != null) return error.GatewayControlRejected;
}
/// observer and table borrow the connection's own native transport; no HTTP
/// client or mutable sequence state is shared between concurrent sessions.
pub fn execute(self: *Self, allocator: std.mem.Allocator, observer: *g.Client, table: *c.TableClient, statement: *const g.Statement, values: []const ?g.fuze.Types.Values.Atom, deadline: Deadline, operation: *?u64) !g.Terminal {
    try statement.checkValues(allocator, values);
    try statement.validate(table);
    if (observer.principal != self.ledger.configuration.ingress or !std.mem.eql(u8, &try observer.ledger.configuration.digest(), &try self.ledger.configuration.digest())) return error.GatewayIdentityConflict;
    var nonce: [16]u8 = undefined;
    try self.io.randomSecure(&nonce);
    const connection = table.connection;
    try self.control(.{ .begin = .{ .nonce = nonce, .binding = .{ .resource = connection.scope.resource, .catalog = connection.scope.catalog, .owner = connection.owner } } }, deadline);
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
            if (attempts == 64 or (!staleRead(table.transport, err) and err != error.CatalogDefinitionChanged)) return err;
            attempts += 1;
            try self.io.sleep(.fromMilliseconds(1), .awake);
            continue;
        };
    };
    defer intent.deinit();
    try self.control(.{ .begin_intent = .{ .operation = item.id, .spec = try s.Publication.Digest.of(g.LedgerRecords.intent_format, intent.bytes) } }, deadline);
    var offset: usize = 0;
    while (offset < intent.bytes.len) {
        const count = @min(g.Upload.part_bytes, intent.bytes.len - offset);
        try self.control(.{ .intent_part = .{ .operation = item.id, .part = try g.Control.Part.init(@intCast(offset), intent.bytes[offset..][0..count]) } }, deadline);
        offset += count;
    }
    try self.control(.{ .seal_intent = item.id }, deadline);
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
    try std.testing.expect(!retryObservation(&wire, error.InvalidGatewayRecord));
}
