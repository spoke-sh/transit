//! Bounded Catalog facets sharing caller-owned I/O. No worker pool, durable
//! queue, sequence allocator or implicit operation recovery is created here.
const std = @import("std");
const Catalog = @import("Catalog.zig");
const c = @import("transit_catalog");
pub const Admission = @import("Admission.zig");
const Self = @This();

allocator: std.mem.Allocator,
io: std.Io,
slots: []Slot,
admission: Admission,
serial: u64 = 1,
mutex: std.Io.Mutex = .init,
condition: std.Io.Condition = .init,

const Slot = struct {
    caller: ?Catalog = null,
    serial: u64 = 0,
    active: bool = false,
};
pub const Config = struct {
    /// Bound on simultaneously open transport/intent owners, not data objects.
    catalogs: usize,
    active: Admission.Limits,
};
pub const Handle = struct { owner: *Self, slot: usize, serial: u64 };

/// Pure local initialization. Keep the context at a stable address until deinit.
pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config) !Self {
    const admission = try Admission.init(config.active);
    if (config.catalogs < config.active.data + config.active.control or config.catalogs > std.math.maxInt(usize) / @sizeOf(Slot)) return error.InvalidClientCapacity;
    const slots = try allocator.alloc(Slot, config.catalogs);
    @memset(slots, .{});
    return .{ .allocator = allocator, .io = io, .slots = slots, .admission = admission };
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
    if (slot.active) return error.ClientWorkOutstanding;
    slot.caller.?.deinit();
    slot.* = .{};
}

const Borrow = struct { slot: *Slot, lane: Admission.Lane };
fn acquire(self: *Self, handle: Handle, lane: Admission.Lane) !Borrow {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    const slot = try self.validate(handle);
    if (slot.active) return error.Busy;
    try self.admission.enter(lane);
    slot.active = true;
    return .{ .slot = slot, .lane = lane };
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
    const lane: Admission.Lane = switch (action) {
        .operation => |value| if (value.command == .execute) .data else .control,
        .retention => |value| switch (value) {
            .status, .release => .control,
            else => .data,
        },
        else => .data,
    };
    const borrow = try self.acquire(handle, lane);
    defer self.release(borrow);
    return borrow.slot.caller.?.call(output, action);
}

pub fn callLog(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectLogClient.Action) !Catalog.LogOutcome {
    const lane: Admission.Lane = switch (action) {
        .operation => |value| if (value.command == .execute) .data else .control,
        .pending => .control,
        else => .data,
    };
    const borrow = try self.acquire(handle, lane);
    defer self.release(borrow);
    return borrow.slot.caller.?.callLog(output, action);
}

pub fn callStream(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectStreamClient.Action) !Catalog.StreamOutcome {
    const lane: Admission.Lane = switch (action) {
        .operation => .control,
        .mutate => |value| switch (value.work) {
            .release, .offset => .control,
            else => .data,
        },
        else => .data,
    };
    const borrow = try self.acquire(handle, lane);
    defer self.release(borrow);
    return borrow.slot.caller.?.callStream(output, action);
}

pub fn callQueue(self: *Self, handle: Handle, output: *std.heap.ArenaAllocator, action: c.DirectQueueClient.Action) !Catalog.QueueOutcome {
    const lane: Admission.Lane = switch (action) {
        .operation => .control,
        .mutate => |value| switch (value.work) {
            .release, .settle => .control,
            else => .data,
        },
        else => .data,
    };
    const borrow = try self.acquire(handle, lane);
    defer self.release(borrow);
    return borrow.slot.caller.?.callQueue(output, action);
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
    while (!self.admission.idle()) try self.condition.waitTimeout(self.io, &self.mutex, deadline);
    try self.admission.join();
}

/// Join all callers first. After successful deinit no thread may access the owner.
pub fn deinit(self: *Self) !void {
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);
    if (self.admission.state != .joined) return error.ClientWorkOutstanding;
    for (self.slots) |*slot| if (slot.caller) |*caller| caller.deinit();
    self.allocator.free(self.slots);
    self.slots = &.{};
}

const test_config: Config = .{ .catalogs = 3, .active = .{ .data = 1, .control = 1 } };
const test_catalog: Catalog.Config = .{
    .url = "http://127.0.0.1:1",
    .connection = .{ .scope = .{ .realm = 46, .resource = 7, .catalog = std.math.maxInt(u64) }, .branch = 1, .audience = 3, .principal = 17, .role = null },
    .timeout_ms = 100,
};

fn initFailure(allocator: std.mem.Allocator) !void {
    var context = try Self.init(allocator, std.testing.io, test_config);
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
    try context.deinit();
    deinitialized = true;
    try t.expectEqualStrings("18446744073709551615", loaded.value.result.loaded.binding.name_assertion.operation);
    try t.expectEqualStrings("original", loaded.value.result.loaded.binding.name_assertion.name);
}
