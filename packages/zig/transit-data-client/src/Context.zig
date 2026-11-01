//! Bounded Catalog and SQL facets sharing caller-owned I/O. No worker pool,
//! durable queue, sequence allocator or implicit recovery is created here.
const std = @import("std");
const Catalog = @import("Catalog.zig");
const c = @import("transit_catalog");
const sql = @import("transit_sql_client");
const SqlSession = @import("SqlSession.zig");
const AdmissionQueue = @import("AdmissionQueue.zig");
pub const Admission = @import("Admission.zig");
const Self = @This();

allocator: std.mem.Allocator,
io: std.Io,
slots: []Slot,
sql_slots: []SqlSlot,
admission: Admission,
queue: AdmissionQueue,
serial: u64 = 1,
mutex: std.Io.Mutex = .init,
condition: std.Io.Condition = .init,
joining: bool = false,

const Slot = struct {
    caller: ?Catalog = null,
    serial: u64 = 0,
    active: bool = false,
    waiting: bool = false,
};
const SqlSlot = struct { session: ?*SqlSession = null, opening: bool = false, waiting: bool = false, serial: u64 = 0, lease: u64 = 0 };
/// Waiting is opt-in and always deadline bounded. Borrowed input/output storage
/// remains caller-owned while queued; no request is sent before admission.
pub const AdmissionOptions = union(enum) {
    refuse,
    wait: std.Io.Timeout,

    fn deadline(self: AdmissionOptions, io: std.Io) AdmissionOptions {
        return switch (self) {
            .refuse => .refuse,
            .wait => |timeout| .{ .wait = timeout.toDeadline(io) },
        };
    }
};
pub const Config = struct {
    /// Bound on simultaneously open transport/intent owners, not data objects.
    catalogs: usize,
    sqls: usize = 0,
    active: Admission.Limits,
    pending: AdmissionQueue.Limits = .{},
};
pub const Handle = struct { owner: *Self, slot: usize, serial: u64 };
pub const SqlHandle = struct { owner: *Self, slot: usize, serial: u64 };
/// Exclusive data permit. All outcomes, readers and batch borrows obtained
/// through this lease must end before release. Copying it creates no new owner.
pub const SqlLease = struct {
    handle: SqlHandle,
    serial: u64,
    pub fn connect(self: SqlLease) !void {
        try (try self.handle.owner.sqlSession(self)).connect();
    }
    pub fn executor(self: SqlLease) !*sql.Executor {
        const session = try self.handle.owner.sqlSession(self);
        if (session.client.session == null) return error.SqlSessionRequired;
        return &session.executor;
    }
    pub fn release(self: SqlLease) !void {
        try self.handle.owner.releaseSql(self);
    }
};

/// Pure local initialization. Keep the context at a stable address until deinit.
pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config) !Self {
    const admission = try Admission.init(config.active);
    const total = std.math.add(usize, config.catalogs, config.sqls) catch return error.InvalidClientCapacity;
    if (total < config.active.data + config.active.control or config.catalogs > std.math.maxInt(usize) / @sizeOf(Slot) or config.sqls > std.math.maxInt(usize) / @sizeOf(SqlSlot)) return error.InvalidClientCapacity;
    const slots = try allocator.alloc(Slot, config.catalogs);
    errdefer allocator.free(slots);
    @memset(slots, .{});
    const sql_slots = try allocator.alloc(SqlSlot, config.sqls);
    errdefer allocator.free(sql_slots);
    @memset(sql_slots, .{});
    const queue = try AdmissionQueue.init(allocator, config.pending);
    return .{ .allocator = allocator, .io = io, .slots = slots, .sql_slots = sql_slots, .admission = admission, .queue = queue };
}

/// Owns bounded configuration/credential copies and native transport reserves.
/// May read configured CA files, but opens no session and starts no worker pool.
pub fn openSql(self: *Self, config: sql.Client.Config, password: ?[]const u8) !SqlHandle {
    const handle = reserved: {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        if (self.admission.state != .open) return error.ClientContextClosed;
        if (self.serial == std.math.maxInt(u64)) return error.ClientHandleExhausted;
        for (self.sql_slots, 0..) |*slot, index| {
            if (slot.session != null or slot.opening) continue;
            if (self.queue.first(.data, self, facetAvailable) != null) return error.ClientCapacityExceeded;
            try self.admission.enter(.data);
            slot.opening = true;
            slot.serial = self.serial;
            self.serial += 1;
            break :reserved SqlHandle{ .owner = self, .slot = index, .serial = slot.serial };
        }
        return error.ClientCapacityExceeded;
    };
    // Configured trust-file I/O must not hold the context's control mutex.
    const session = SqlSession.create(self.allocator, self.io, config, password);
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);
    defer {
        self.admission.leave(.data) catch unreachable;
        self.condition.broadcast(self.io);
    }
    const slot = &self.sql_slots[handle.slot];
    slot.opening = false;
    slot.session = try session;
    return handle;
}
fn validateSql(self: *Self, handle: SqlHandle) !*SqlSlot {
    if (handle.owner != self or handle.slot >= self.sql_slots.len or handle.serial == 0) return error.StaleClientHandle;
    const slot = &self.sql_slots[handle.slot];
    if (slot.session == null or slot.serial != handle.serial) return error.StaleClientHandle;
    return slot;
}
pub fn closeSql(self: *Self, handle: SqlHandle) !void {
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);
    const slot = try self.validateSql(handle);
    if (slot.lease != 0 or slot.waiting) return error.ClientWorkOutstanding;
    slot.session.?.destroy();
    slot.* = .{};
}
pub fn borrowSql(self: *Self, handle: SqlHandle) !SqlLease {
    return self.borrowSqlWithAdmission(handle, .refuse);
}
pub fn borrowSqlWithAdmission(self: *Self, handle: SqlHandle, options: AdmissionOptions) !SqlLease {
    const admission_options = options.deadline(self.io);
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const slot = try self.validateSql(handle);
    if (self.serial == std.math.maxInt(u64)) return error.ClientHandleExhausted;
    try self.enterFacet(self.slots.len + handle.slot, .data, admission_options);
    // Waiting releases the mutex, so another facet may consume the last serial.
    if (self.serial == std.math.maxInt(u64)) {
        self.admission.leave(.data) catch unreachable;
        self.condition.broadcast(self.io);
        return error.ClientHandleExhausted;
    }
    slot.lease = self.serial;
    self.serial += 1;
    slot.session.?.cancel.store(@backingInt(sql.Executor.Cancellation.Request.none), .release);
    slot.session.?.executor.interrupted = false;
    return .{ .handle = handle, .serial = slot.lease };
}
fn sqlSession(self: *Self, lease: SqlLease) !*SqlSession {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const slot = try self.validateSql(lease.handle);
    if (lease.serial == 0 or slot.lease != lease.serial) return error.StaleSqlLease;
    return slot.session.?;
}
fn releaseSql(self: *Self, lease: SqlLease) !void {
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);
    const slot = try self.validateSql(lease.handle);
    if (lease.serial == 0 or slot.lease != lease.serial) return error.StaleSqlLease;
    slot.lease = 0;
    self.admission.leave(.data) catch unreachable;
    self.condition.broadcast(self.io);
}
/// Signals only this lease's shared executor. The executor owns the distinction
/// between stopping a wait and requesting cancellation of accepted work.
/// This method reports local delivery, never a remote cancellation outcome.
pub fn cancelSql(self: *Self, lease: SqlLease, request: sql.Executor.Cancellation.Request) !void {
    if (request == .none) return error.InvalidSqlCancellation;
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const slot = try self.validateSql(lease.handle);
    if (lease.serial == 0 or slot.lease != lease.serial) return error.StaleSqlLease;
    if (self.queue.first(.control, self, facetAvailable) != null) return error.ClientCapacityExceeded;
    try self.admission.enter(.control);
    defer self.admission.leave(.control) catch unreachable;
    const signal = &slot.session.?.cancel;
    var previous = signal.load(.acquire);
    while (previous < @backingInt(request)) {
        previous = signal.cmpxchgWeak(previous, @backingInt(request), .acq_rel, .acquire) orelse break;
    }
}

/// Copies endpoints and key through the existing caller; contacts no authority.
pub fn openCatalog(self: *Self, config: Catalog.Config, seed: [32]u8) !Handle {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    if (self.admission.state != .open) return error.ClientContextClosed;
    if (self.serial == std.math.maxInt(u64)) return error.ClientHandleExhausted;
    for (self.slots, 0..) |*slot, index| {
        if (slot.caller != null) continue;
        slot.caller = try Catalog.init(self.allocator, self.io, config, seed);
        slot.serial = self.serial;
        self.serial += 1;
        return .{ .owner = self, .slot = index, .serial = slot.serial };
    }
    return error.ClientCapacityExceeded;
}

fn validate(self: *Self, handle: Handle) !*Slot {
    if (handle.owner != self or handle.slot >= self.slots.len or handle.serial == 0) return error.StaleClientHandle;
    const slot = &self.slots[handle.slot];
    if (slot.caller == null or slot.serial != handle.serial) return error.StaleClientHandle;
    return slot;
}

/// Does not cancel work or free a transport that is still borrowed.
pub fn closeCatalog(self: *Self, handle: Handle) !void {
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);
    const slot = try self.validate(handle);
    if (slot.active or slot.waiting) return error.ClientWorkOutstanding;
    slot.caller.?.deinit();
    slot.* = .{};
}

const Borrow = struct { slot: *Slot, lane: Admission.Lane };
fn acquire(self: *Self, handle: Handle, lane: Admission.Lane) !Borrow {
    return self.acquireWithAdmission(handle, lane, .refuse);
}
fn acquireWithAdmission(self: *Self, handle: Handle, lane: Admission.Lane, options: AdmissionOptions) !Borrow {
    const admission_options = options.deadline(self.io);
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const slot = try self.validate(handle);
    try self.enterFacet(handle.slot, lane, admission_options);
    slot.active = true;
    return .{ .slot = slot, .lane = lane };
}

fn facetAvailable(self: *Self, index: usize) bool {
    return if (index < self.slots.len) !self.slots[index].active else self.sql_slots[index - self.slots.len].lease == 0;
}
fn facetWaiting(self: *Self, index: usize) *bool {
    return if (index < self.slots.len) &self.slots[index].waiting else &self.sql_slots[index - self.slots.len].waiting;
}
fn requireLane(self: *Self, lane: Admission.Lane) !void {
    if (self.admission.state == .joined or (self.admission.state == .closing and lane == .data)) return error.ClientContextClosed;
}

/// Called with mutex held and a validated facet, which cannot close while
/// waiting. A cancelled/expired waiter releases its metadata before returning.
fn enterFacet(self: *Self, index: usize, lane: Admission.Lane, options: AdmissionOptions) !void {
    if (options == .wait and options.wait == .none) return error.InvalidClientAdmissionTimeout;
    const deadline = if (options == .wait) options.wait.toDeadline(self.io) else std.Io.Timeout.none;
    try self.requireLane(lane);
    if (deadline != .none and deadline.deadline.durationFromNow(self.io).raw.nanoseconds <= 0) return error.Timeout;
    const waiting = self.facetWaiting(index);
    if (waiting.*) return error.Busy;
    if (self.facetAvailable(index) and self.queue.first(lane, self, facetAvailable) == null) {
        if (self.admission.enter(lane)) |_| return else |err| switch (err) {
            error.ClientCapacityExceeded => {},
            else => return err,
        }
    }
    if (options == .refuse) return if (self.facetAvailable(index)) error.ClientCapacityExceeded else error.Busy;
    const ticket = try self.queue.enqueue(index, lane);
    waiting.* = true;
    self.condition.broadcast(self.io);
    defer {
        waiting.* = false;
        self.queue.remove(ticket) catch unreachable;
        self.condition.broadcast(self.io);
    }
    while (true) {
        try self.requireLane(lane);
        if (deadline.deadline.durationFromNow(self.io).raw.nanoseconds <= 0) return error.Timeout;
        if (self.queue.first(lane, self, facetAvailable)) |selected| if (std.meta.eql(selected, ticket)) {
            if (self.admission.enter(lane)) |_| return else |err| switch (err) {
                error.ClientCapacityExceeded => {},
                else => return err,
            }
        };
        try self.condition.waitTimeout(self.io, &self.mutex, deadline);
    }
}
fn release(self: *Self, borrow: Borrow) void {
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);
    std.debug.assert(borrow.slot.active);
    borrow.slot.active = false;
    self.admission.leave(borrow.lane) catch unreachable;
    self.condition.broadcast(self.io);
}

pub fn call(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectTableBridge.Action) !Catalog.Outcome {
    return self.callWithAdmission(handle, output, action, .refuse);
}
pub fn callWithAdmission(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectTableBridge.Action, options: AdmissionOptions) !Catalog.Outcome {
    const lane: Admission.Lane = switch (action) {
        .operation => |value| if (value.command == .execute) .data else .control,
        .retention => |value| switch (value) {
            .status, .release => .control,
            else => .data,
        },
        else => .data,
    };
    const borrow = try self.acquireWithAdmission(handle, lane, options);
    defer self.release(borrow);
    return borrow.slot.caller.?.call(output, action);
}

pub fn callLog(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectLogClient.Action) !Catalog.LogOutcome {
    return self.callLogWithAdmission(handle, output, action, .refuse);
}
pub fn callLogWithAdmission(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectLogClient.Action, options: AdmissionOptions) !Catalog.LogOutcome {
    const lane: Admission.Lane = switch (action) {
        .operation => |value| if (value.command == .execute) .data else .control,
        .pending => .control,
        else => .data,
    };
    const borrow = try self.acquireWithAdmission(handle, lane, options);
    defer self.release(borrow);
    return borrow.slot.caller.?.callLog(output, action);
}

pub fn callStream(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectStreamClient.Action) !Catalog.StreamOutcome {
    return self.callStreamWithAdmission(handle, output, action, .refuse);
}
pub fn callStreamWithAdmission(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectStreamClient.Action, options: AdmissionOptions) !Catalog.StreamOutcome {
    const lane: Admission.Lane = switch (action) {
        .operation => .control,
        .mutate => |value| switch (value.work) {
            .release, .offset => .control,
            else => .data,
        },
        else => .data,
    };
    const borrow = try self.acquireWithAdmission(handle, lane, options);
    defer self.release(borrow);
    return borrow.slot.caller.?.callStream(output, action);
}

pub fn callQueue(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectQueueClient.Action) !Catalog.QueueOutcome {
    return self.callQueueWithAdmission(handle, output, action, .refuse);
}
pub fn callQueueWithAdmission(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectQueueClient.Action, options: AdmissionOptions) !Catalog.QueueOutcome {
    const lane: Admission.Lane = switch (action) {
        .operation => .control,
        .mutate => |value| switch (value.work) {
            .release, .settle => .control,
            else => .data,
        },
        else => .data,
    };
    const borrow = try self.acquireWithAdmission(handle, lane, options);
    defer self.release(borrow);
    return borrow.slot.caller.?.callQueue(output, action);
}

/// Named KV uses the direct owner, including its existing control semantics.
/// Closing a context does not implicitly release retained KV pins.
pub fn callKV(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectKVClient.Action) !Catalog.KVOutcome {
    return self.callKVWithAdmission(handle, output, action, .refuse);
}
pub fn callKVWithAdmission(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectKVClient.Action, options: AdmissionOptions) !Catalog.KVOutcome {
    const lane: Admission.Lane = switch (action) {
        .declaration => |value| if (value.control()) .control else .data,
        .operation, .pin_status, .release => .control,
        else => .data,
    };
    const borrow = try self.acquireWithAdmission(handle, lane, options);
    defer self.release(borrow);
    return borrow.slot.caller.?.callKV(output, action);
}

pub fn beginClose(self: *Self) void {
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);
    self.admission.beginClose();
    self.condition.broadcast(self.io);
}

/// Refuses new data work and waits for existing calls to return. Timeout or
/// cancellation leaves closing ownership intact; the caller must retry close.
/// No accepted operation, transaction or durable pin is cancelled by this call.
pub fn close(self: *Self, timeout: std.Io.Timeout) !void {
    const deadline = timeout.toDeadline(self.io);
    self.beginClose();
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    if (self.joining) return error.Busy;
    self.joining = true;
    defer self.joining = false;
    while (!self.admission.idle() or !self.queue.empty()) try self.condition.waitTimeout(self.io, &self.mutex, deadline);
    try self.admission.join();
}

/// Join all callers first. After successful deinit no thread may access the owner.
pub fn deinit(self: *Self) !void {
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);
    if (self.admission.state != .joined) return error.ClientWorkOutstanding;
    self.queue.deinit();
    for (self.slots) |*slot| if (slot.caller) |*caller| caller.deinit();
    for (self.sql_slots) |slot| if (slot.session) |session| session.destroy();
    self.allocator.free(self.slots);
    self.slots = &.{};
    self.allocator.free(self.sql_slots);
    self.sql_slots = &.{};
}

const test_config: Config = .{ .catalogs = 3, .active = .{ .data = 1, .control = 1 } };
const test_catalog: Catalog.Config = .{
    .url = "http://127.0.0.1:1",
    .connection = .{ .scope = .{ .realm = 46, .resource = 7, .catalog = std.math.maxInt(u64) }, .branch = 1, .audience = 3, .principal = 17, .role = null },
    .timeout_ms = 100,
};

fn initFailure(allocator: std.mem.Allocator) !void {
    var config = test_config;
    config.pending = .{ .data = 2, .control = 1 };
    var context = try Self.init(allocator, std.testing.io, config);
    defer {
        context.close(.none) catch unreachable;
        context.deinit() catch unreachable;
    }
    _ = try context.openCatalog(test_catalog, @splat(10));
    _ = try context.openCatalog(test_catalog, @splat(11));
}
test "context and facet construction unwind every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, initFailure, .{});
}

test "SQL leases share admission preserve cancellation capacity and fence stale release" {
    const t = std.testing;
    var context = try Self.init(t.allocator, t.io, .{ .catalogs = 1, .sqls = 1, .active = .{ .data = 1, .control = 1 } });
    defer context.deinit() catch unreachable;
    defer context.close(.none) catch unreachable;
    const catalog = try context.openCatalog(test_catalog, @splat(10));
    const handle = try context.openSql(.{ .endpoint = "http://127.0.0.1:1", .authentication = .trust }, null);
    const lease = try context.borrowSql(handle);
    try t.expectError(error.SqlSessionRequired, lease.executor());
    try t.expectError(error.Busy, context.borrowSql(handle));
    try t.expectError(error.ClientCapacityExceeded, context.acquire(catalog, .data));
    const control = try context.acquire(catalog, .control);
    try t.expectError(error.ClientCapacityExceeded, context.cancelSql(lease, .cancel));
    context.release(control);
    context.beginClose();
    try context.cancelSql(lease, .terminate);
    try context.cancelSql(lease, .cancel);
    try t.expectEqual(@as(u8, @backingInt(sql.Executor.Cancellation.Request.terminate)), context.sql_slots[handle.slot].session.?.cancel.load(.acquire));
    try t.expectError(error.Timeout, context.close(.{ .duration = .{ .clock = .awake, .raw = .fromMilliseconds(0) } }));
    try t.expectError(error.ClientWorkOutstanding, context.closeSql(handle));
    try lease.release();
    try t.expectError(error.StaleSqlLease, lease.release());
    try t.expectError(error.StaleSqlLease, context.cancelSql(lease, .cancel));
    try t.expectError(error.ClientContextClosed, context.borrowSql(handle));
    try context.closeSql(handle);
    try t.expectError(error.StaleClientHandle, context.closeSql(handle));
}

test "context fences handles across slots scopes replacement and serial exhaustion" {
    const t = std.testing;
    var context = try Self.init(t.allocator, t.io, test_config);
    defer context.deinit() catch unreachable;
    defer context.close(.none) catch unreachable;
    var other = try Self.init(t.allocator, t.io, test_config);
    defer other.deinit() catch unreachable;
    defer other.close(.none) catch unreachable;
    const old = try context.openCatalog(test_catalog, @splat(10));
    try t.expectError(error.StaleClientHandle, other.closeCatalog(old));
    try context.closeCatalog(old);
    var options = test_catalog;
    options.connection.principal = 18;
    const fresh = try context.openCatalog(options, @splat(11));
    try t.expectEqual(old.slot, fresh.slot);
    try t.expect(old.serial != fresh.serial);
    try t.expectEqual(18, context.slots[fresh.slot].caller.?.connection.principal);
    try t.expectError(error.StaleClientHandle, context.closeCatalog(old));
    try t.expectError(error.StaleClientHandle, context.acquire(old, .control));
    context.serial = std.math.maxInt(u64);
    try t.expectError(error.ClientHandleExhausted, context.openCatalog(test_catalog, @splat(12)));
    try context.closeCatalog(fresh);
}

test "context admission reuses reserved storage and isolates controls from busy facets" {
    const t = std.testing;
    var allocator: t.FailingAllocator = .init(t.allocator, .{});
    var context = try Self.init(allocator.allocator(), t.io, test_config);
    defer context.deinit() catch unreachable;
    defer context.close(.none) catch unreachable;
    const first = try context.openCatalog(test_catalog, @splat(10));
    const second = try context.openCatalog(test_catalog, @splat(11));
    const third = try context.openCatalog(test_catalog, @splat(12));
    try t.expectError(error.ClientCapacityExceeded, context.openCatalog(test_catalog, @splat(13)));
    const before = allocator.alloc_index;
    allocator.fail_index = before;
    for (0..4096) |_| {
        const data = try context.acquire(first, .data);
        try t.expectError(error.Busy, context.acquire(first, .control));
        try t.expectError(error.ClientCapacityExceeded, context.acquire(second, .data));
        const control = try context.acquire(second, .control);
        try t.expectError(error.ClientCapacityExceeded, context.acquire(third, .control));
        try t.expectError(error.ClientWorkOutstanding, context.closeCatalog(first));
        context.release(control);
        context.release(data);
    }
    try t.expectEqual(before, allocator.alloc_index);
    try t.expect(!allocator.has_induced_failure);
}

test "context close timeout and cancellation retain active native ownership" {
    const t = std.testing;
    var context = try Self.init(t.allocator, t.io, test_config);
    defer context.deinit() catch unreachable;
    const first = try context.openCatalog(test_catalog, @splat(10));
    const second = try context.openCatalog(test_catalog, @splat(11));
    const borrowed = try context.acquire(first, .data);
    var released = false;
    defer if (!released) {
        context.release(borrowed);
        context.close(.none) catch unreachable;
    };
    try t.expectError(error.Timeout, context.close(.{ .duration = .{ .clock = .awake, .raw = .fromMilliseconds(0) } }));
    try t.expectError(error.ClientWorkOutstanding, context.deinit());
    try t.expectError(error.ClientContextClosed, context.acquire(second, .data));
    const control = try context.acquire(second, .control);
    context.release(control);
    var ready: std.Io.Event = .unset;
    var closing = try t.io.concurrent(struct {
        fn run(owner: *Self, started: *std.Io.Event) !void {
            started.set(owner.io);
            try owner.close(.none);
        }
    }.run, .{ &context, &ready });
    try ready.wait(t.io);
    try t.expectError(error.Canceled, closing.cancel(t.io));
    try t.expectEqual(.closing, context.admission.state);
    try t.expectError(error.ClientWorkOutstanding, context.closeCatalog(first));
    context.release(borrowed);
    released = true;
    try context.close(.none);
    try context.close(.none);
    try t.expectError(error.ClientContextClosed, context.acquire(second, .control));
}

test "Table retention cleanup retains control admission while data is occupied and closing" {
    const t = std.testing;
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    const a = output.allocator();
    var context = try Self.init(t.allocator, t.io, test_config);
    defer context.deinit() catch unreachable;
    defer context.close(.none) catch unreachable;
    const first = try context.openCatalog(test_catalog, @splat(10));
    const second = try context.openCatalog(test_catalog, @splat(11));
    const borrowed = try context.acquire(first, .data);
    defer context.release(borrowed);
    context.beginClose();
    // The original owner must still be validated by Catalog. A mismatched
    // principal gives a deterministic local refusal after control admission,
    // with no network dependency or substituted cleanup authority.
    var foreign = test_catalog.connection;
    foreign.principal += 1;
    const snapshot: c.DirectCatalogRetention.Snapshot = .{
        .owner = .{
            .definition = c.protocol.Growth.current_definition,
            .connection = try c.DirectTableValues.Connection.foreign(a, foreign),
            .object = try c.DirectTableValues.Object.foreign(a, .{ .scope = foreign.scope, .branch = 1, .object = 7 }),
            .operation = "1",
        },
        .content = try c.DirectTableValues.Content.foreign(a, .{ .bytes = 1, .sha256 = @splat(3) }),
    };
    for ([_]c.DirectCatalogRetention.Action{ .{ .status = snapshot.owner }, .{ .release = snapshot } }) |action| {
        const outcome = try context.call(second, &output, .{ .retention = action });
        try t.expectEqual(error.CatalogIdentityConflict, outcome.value.failure.cause);
        try t.expect(!outcome.mutationAttempted());
    }
    try t.expectError(error.ClientContextClosed, context.call(second, &output, .{ .retention = .{ .metadata = snapshot } }));
}

test "context executes the shared catalog caller and preserves owned results after close" {
    const t = std.testing;
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    var context = try Self.init(t.allocator, t.io, test_config);
    var deinitialized = false;
    defer if (!deinitialized) {
        context.close(.none) catch unreachable;
        context.deinit() catch unreachable;
    };
    const handle = try context.openCatalog(test_catalog, @splat(10));
    const work = try c.DirectTableValues.NameAssertion.foreign(output.allocator(), .{
        .definition = c.protocol.Growth.current_definition,
        .connection = test_catalog.connection,
        .operation = std.math.maxInt(u64),
        .namespace = 1,
        .name = try c.TableAuthority.Name.init("original"),
        .action = .drop_if_exists,
        .expected = null,
        .intent = @splat(9),
    });
    const loaded = try context.call(handle, &output, .{ .load = .{ .name_assertion = work } });
    try t.expect(!loaded.mutationAttempted());
    var failing: t.FailingAllocator = .init(t.allocator, .{ .fail_index = 0 });
    var exhausted: std.heap.ArenaAllocator = .init(failing.allocator());
    defer exhausted.deinit();
    const refused = try context.call(handle, &exhausted, .{ .load = .{ .name_assertion = work } });
    try t.expectEqual(error.OutOfMemory, refused.value.failure.cause);
    const forgotten = try context.call(handle, &output, .{ .forget = loaded.value.result.loaded.id });
    try t.expect(forgotten.value.result == .forgotten);
    try context.close(.none);
    try t.expectError(error.ClientContextClosed, context.callLog(handle, &output, .{ .lookup = .{ .namespace = 1, .name = "events" } }));
    const partition: c.protocol.StreamQueue.Partition = .{
        .definition = c.protocol.Growth.current_definition,
        .interpretation = .{ .object = .{ .scope = test_catalog.connection.scope, .branch = 1, .object = 7 }, .revision = 1, .digest = @splat(3) },
        .partition = 0,
    };
    try t.expectError(error.ClientContextClosed, context.callStream(handle, &output, .{ .observe = partition }));
    try t.expectError(error.ClientContextClosed, context.callQueue(handle, &output, .{ .observe = partition }));
    try t.expectError(error.ClientContextClosed, context.callKV(handle, &output, .{ .observe = partition.interpretation.object }));
    try context.deinit();
    deinitialized = true;
    try t.expectEqualStrings("18446744073709551615", loaded.value.result.loaded.binding.name_assertion.operation);
    try t.expectEqualStrings("original", loaded.value.result.loaded.binding.name_assertion.name);
}

const test_wait: std.Io.Timeout = .{ .duration = .{ .clock = .awake, .raw = .fromSeconds(5) } };
const WaitingCall = struct {
    context: *Self,
    handle: Handle,
    lane: Admission.Lane = .data,
    entered: std.Io.Event = .unset,
    finish: std.Io.Event = .unset,

    fn run(self: *WaitingCall) !void {
        const borrow = try self.context.acquireWithAdmission(self.handle, self.lane, .{ .wait = test_wait });
        defer self.context.release(borrow);
        self.entered.set(self.context.io);
        try self.finish.waitTimeout(self.context.io, test_wait);
    }
};
fn waitForPending(context: *Self, data: usize, control: usize) !void {
    const deadline = test_wait.toDeadline(context.io);
    try context.mutex.lock(context.io);
    defer context.mutex.unlock(context.io);
    while (context.queue.data != data or context.queue.control != control)
        try context.condition.waitTimeout(context.io, &context.mutex, deadline);
}

test "queued admission preserves order and control capacity under saturation" {
    const t = std.testing;
    var context = try Self.init(t.allocator, t.io, .{
        .catalogs = 5,
        .active = .{ .data = 1, .control = 1 },
        .pending = .{ .data = 2, .control = 1 },
    });
    defer context.deinit() catch unreachable;
    defer context.close(.none) catch unreachable;
    var handles: [5]Handle = undefined;
    for (&handles) |*handle| handle.* = try context.openCatalog(test_catalog, @splat(10));
    const occupied = try context.acquire(handles[0], .data);
    var released = false;
    defer if (!released) context.release(occupied);
    var first: WaitingCall = .{ .context = &context, .handle = handles[1] };
    var a = try t.io.concurrent(WaitingCall.run, .{&first});
    defer a.cancel(t.io) catch {};
    try waitForPending(&context, 1, 0);
    var second: WaitingCall = .{ .context = &context, .handle = handles[2] };
    var b = try t.io.concurrent(WaitingCall.run, .{&second});
    defer b.cancel(t.io) catch {};
    try waitForPending(&context, 2, 0);
    try t.expectError(error.ClientCapacityExceeded, context.acquireWithAdmission(handles[3], .data, .{ .wait = test_wait }));
    try t.expectError(error.Busy, context.acquire(handles[1], .data));
    try t.expectError(error.ClientWorkOutstanding, context.closeCatalog(handles[1]));
    const control = try context.acquire(handles[3], .control);
    context.release(control);
    context.release(occupied);
    released = true;
    try first.entered.waitTimeout(t.io, test_wait);
    try t.expect(!second.entered.isSet());
    try t.expectError(error.ClientCapacityExceeded, context.acquire(handles[4], .data));
    first.finish.set(t.io);
    try a.await(t.io);
    try second.entered.waitTimeout(t.io, test_wait);
    second.finish.set(t.io);
    try b.await(t.io);
    try waitForPending(&context, 0, 0);
    try context.closeCatalog(handles[1]);
}

test "queued cancellation deadline and close release metadata without dispatch" {
    const t = std.testing;
    var context = try Self.init(t.allocator, t.io, .{
        .catalogs = 3,
        .active = .{ .data = 1, .control = 1 },
        .pending = .{ .data = 1, .control = 1 },
    });
    defer context.deinit() catch unreachable;
    defer context.close(.none) catch unreachable;
    const active = try context.openCatalog(test_catalog, @splat(10));
    const waiting = try context.openCatalog(test_catalog, @splat(11));
    const controls = try context.openCatalog(test_catalog, @splat(12));
    const data = try context.acquire(active, .data);
    var released = false;
    defer if (!released) context.release(data);
    const expired: AdmissionOptions = .{ .wait = .{ .duration = .{ .clock = .awake, .raw = .zero } } };
    try t.expectError(error.Timeout, context.acquireWithAdmission(waiting, .data, expired));
    try t.expectError(error.Timeout, context.acquireWithAdmission(waiting, .data, .{ .wait = .{ .duration = .{ .clock = .awake, .raw = .fromMilliseconds(1) } } }));
    try t.expectError(error.InvalidClientAdmissionTimeout, context.acquireWithAdmission(waiting, .data, .{ .wait = .none }));
    var waiter: WaitingCall = .{ .context = &context, .handle = waiting };
    var task = try t.io.concurrent(WaitingCall.run, .{&waiter});
    defer task.cancel(t.io) catch {};
    try waitForPending(&context, 1, 0);
    try t.expectError(error.Canceled, task.cancel(t.io));
    try waitForPending(&context, 0, 0);
    try t.expect(!waiter.entered.isSet());
    // The cancelled slot is reusable. Closing drains it without acquiring a
    // data permit; the control waiter survives until its facet becomes idle.
    var retry = try t.io.concurrent(WaitingCall.run, .{&waiter});
    defer retry.cancel(t.io) catch {};
    try waitForPending(&context, 1, 0);
    const held_control = try context.acquire(controls, .control);
    var control_call: WaitingCall = .{ .context = &context, .handle = controls, .lane = .control };
    var control_task = try t.io.concurrent(WaitingCall.run, .{&control_call});
    defer control_task.cancel(t.io) catch {};
    var control_released = false;
    defer if (!control_released) context.release(held_control);
    try waitForPending(&context, 1, 1);
    context.beginClose();
    try t.expectError(error.ClientContextClosed, retry.await(t.io));
    try t.expect(!waiter.entered.isSet());
    context.release(data);
    released = true;
    context.release(held_control);
    control_released = true;
    try control_call.entered.waitTimeout(t.io, test_wait);
    control_call.finish.set(t.io);
    try control_task.await(t.io);
    try context.close(.none);
    try t.expect(context.queue.empty());
}

test "SQL lease admission waits behind Catalog work and cannot lose its facet" {
    const t = std.testing;
    var context = try Self.init(t.allocator, t.io, .{
        .catalogs = 1,
        .sqls = 1,
        .active = .{ .data = 1, .control = 1 },
        .pending = .{ .data = 1 },
    });
    defer context.deinit() catch unreachable;
    defer context.close(.none) catch unreachable;
    const catalog = try context.openCatalog(test_catalog, @splat(10));
    const handle = try context.openSql(.{ .endpoint = "http://127.0.0.1:1", .authentication = .trust }, null);
    const data = try context.acquire(catalog, .data);
    var released = false;
    defer if (!released) context.release(data);
    var task = try t.io.concurrent(struct {
        fn run(owner: *Self, sql_handle: SqlHandle) !SqlLease {
            return owner.borrowSqlWithAdmission(sql_handle, .{ .wait = test_wait });
        }
    }.run, .{ &context, handle });
    var joined = false;
    defer if (!joined) {
        if (task.cancel(t.io)) |lease| lease.release() catch unreachable else |_| {}
    };
    try waitForPending(&context, 1, 0);
    try t.expectError(error.ClientWorkOutstanding, context.closeSql(handle));
    try t.expectError(error.Busy, context.borrowSql(handle));
    context.release(data);
    released = true;
    const lease = try task.await(t.io);
    joined = true;
    defer lease.release() catch unreachable;
    try context.cancelSql(lease, .terminate);
    try t.expectEqual(@as(u8, @backingInt(sql.Executor.Cancellation.Request.terminate)), context.sql_slots[handle.slot].session.?.cancel.load(.acquire));
}
