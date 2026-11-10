//! Bounded transient request storage. Ingress reserves an exact Queue input
//! before accepting it; a native expression binder borrows its protected state.
//! This registry supplies lifetime/ownership only, never native authorization.
const std = @import("std");
const c = @import("transit_catalog");
const R = @import("ApplicationReservation.zig");
const H = @import("ApplicationProtectedHost.zig");
const Reference = c.fuze.ApplicationProgram.Values.Reference;
const Self = @This();

pub const Limits = struct {
    active_requests: usize,
    request_bytes: usize,
    protected_bytes: usize,
    protected_values: usize,
    scratch_bytes: usize,
    resident_bytes: usize,

    fn allocation(self: Limits) !usize {
        if (self.active_requests == 0 or self.request_bytes == 0 or self.protected_bytes == 0 or
            self.protected_values == 0 or self.scratch_bytes == 0) return error.InvalidApplicationReservation;
        const buffers = try std.math.add(usize, try std.math.add(usize, self.request_bytes, self.protected_bytes), self.scratch_bytes);
        const metadata = try std.math.add(usize, @sizeOf(Slot), try std.math.mul(usize, self.protected_values, @sizeOf(R.Slot)));
        const total = try std.math.mul(usize, self.active_requests, try std.math.add(usize, buffers, metadata));
        if (total > self.resident_bytes) return error.ApplicationReservationCapacity;
        return try std.math.mul(usize, self.active_requests, buffers);
    }
};
pub const Ticket = struct { reference: Reference };
const Slot = struct {
    state: enum { free, initializing, open, closing } = .free,
    borrowed: bool = false,
    sequence: u64 = 0,
    /// Immutable ingress identity, also present while construction is in flight.
    /// A later committed handoff may change reservation.input under its borrow.
    original_input: R.Input = undefined,
    reservation: R = undefined,
    request: H.Request = undefined,
    request_memory: []u8,
    protected_memory: []u8,
    private_memory: []u8,
    values: []R.Slot,

    fn wipe(self: *Slot) void {
        std.debug.assert(!self.borrowed);
        std.crypto.secureZero(u8, self.request_memory);
        std.crypto.secureZero(u8, self.protected_memory);
        std.crypto.secureZero(u8, self.private_memory);
        std.crypto.secureZero(u8, std.mem.sliceAsBytes(self.values));
        self.original_input = undefined;
        self.reservation = undefined;
        self.request = undefined;
        self.sequence = 0;
        self.state = .free;
    }
};
allocator: std.mem.Allocator,
slots: []Slot,
memory: []u8,
values: []R.Slot,
mutex: std.Io.Mutex = .init,
changed: std.Io.Condition = .init,
stopped: bool = false,

/// All per-request buffers and metadata are allocated at deployment setup.
/// Keep this owner at a stable address until its requests and borrows join.
pub fn init(allocator: std.mem.Allocator, limits: Limits) !Self {
    const bytes = try limits.allocation();
    const slots = try allocator.alloc(Slot, limits.active_requests);
    errdefer allocator.free(slots);
    const memory = try allocator.alloc(u8, bytes);
    errdefer allocator.free(memory);
    const values = try allocator.alloc(R.Slot, try std.math.mul(usize, limits.active_requests, limits.protected_values));
    @memset(memory, 0);
    std.crypto.secureZero(u8, std.mem.sliceAsBytes(values));
    var offset: usize = 0;
    for (slots, 0..) |*slot, index| {
        slot.* = .{
            .request_memory = memory[offset..][0..limits.request_bytes],
            .protected_memory = memory[offset + limits.request_bytes ..][0..limits.protected_bytes],
            .private_memory = memory[offset + limits.request_bytes + limits.protected_bytes ..][0..limits.scratch_bytes],
            .values = values[index * limits.protected_values ..][0..limits.protected_values],
        };
        offset += limits.request_bytes + limits.protected_bytes + limits.scratch_bytes;
    }
    return .{ .allocator = allocator, .slots = slots, .memory = memory, .values = values };
}
/// Stop admission and join all in-flight construction/evaluation before erasure.
/// The deployment joins HTTP/recovery tasks before releasing this owner's address.
pub fn deinit(self: *Self, io: std.Io) void {
    self.mutex.lockUncancelable(io);
    self.stopped = true;
    for (self.slots) |*slot| if (slot.state == .open) {
        slot.state = .closing;
    };
    self.changed.broadcast(io);
    while (true) {
        var pending = false;
        for (self.slots) |*slot| if (slot.borrowed or slot.state == .initializing) {
            pending = true;
        };
        if (!pending) break;
        self.changed.waitUncancelable(io, &self.mutex);
    }
    for (self.slots) |*slot| slot.wipe();
    self.mutex.unlock(io);
    self.allocator.free(self.values);
    self.allocator.free(self.memory);
    self.allocator.free(self.slots);
    self.* = undefined;
}
fn now(io: std.Io) !u64 {
    return std.math.cast(u64, std.Io.Clock.awake.now(io).toMilliseconds()) orelse error.ClockUnavailable;
}
fn deny(_: *anyopaque, _: R.Evidence) anyerror!void {
    return error.MissingProgramNativeBinding;
}
fn find(self: *Self, ticket: Ticket) ?*Slot {
    for (self.slots) |*slot| {
        if (slot.state != .open and slot.state != .closing) continue;
        if (std.crypto.timing_safe.eql([32]u8, slot.reservation.reference.id, ticket.reference.id)) return slot;
    }
    return null;
}
fn vacant(self: *Self, io: std.Io, input: R.Input) !*Slot {
    try self.mutex.lock(io);
    defer self.mutex.unlock(io);
    if (self.stopped) return error.ApplicationReservationLost;
    for (self.slots) |*slot| if (slot.state != .free and std.meta.eql(slot.original_input, input)) return error.ApplicationRequestOwnerMismatch;
    for (self.slots) |*slot| if (slot.state == .free) {
        slot.original_input = input;
        slot.state = .initializing;
        return slot;
    };
    return error.ApplicationReservationCapacity;
}
/// Copies every borrowed request byte. Lifetime starts once and is never
/// extended by evaluation, waiting for a borrower, or a resumed invocation.
pub fn open(self: *Self, io: std.Io, input: R.Input, request_id: [16]u8, request: H.Request, lifetime_ms: u32) !Ticket {
    try input.validate();
    const started = try now(io);
    if (lifetime_ms == 0) return error.InvalidApplicationReservation;
    const expires = try std.math.add(u64, started, lifetime_ms);
    const slot = try self.vacant(io, input);
    errdefer {
        self.mutex.lockUncancelable(io);
        slot.wipe();
        self.changed.broadcast(io);
        self.mutex.unlock(io);
    }
    var memory = std.heap.FixedBufferAllocator.init(slot.request_memory);
    const headers = memory.allocator().alloc(c.DeclarativeIngress.HeaderPair, request.headers.len) catch return error.ApplicationReservationCapacity;
    const query = memory.allocator().dupe(u8, request.query) catch return error.ApplicationReservationCapacity;
    for (headers, request.headers) |*out, header| out.* = .{
        .name = memory.allocator().dupe(u8, header.name) catch return error.ApplicationReservationCapacity,
        .value = memory.allocator().dupe(u8, header.value) catch return error.ApplicationReservationCapacity,
    };
    slot.request = .{ .query = query, .headers = headers };
    slot.reservation = try R.init(io, slot.protected_memory, slot.values, request_id, input, started, expires, .{ .context = slot, .check = deny });
    try self.mutex.lock(io);
    defer self.mutex.unlock(io);
    if (self.stopped) return error.ApplicationReservationLost;
    if (try now(io) >= expires) return error.ApplicationReservationExpired;
    slot.state = .open;
    self.changed.broadcast(io);
    return .{ .reference = slot.reservation.reference };
}
/// Disconnect/response completion revokes new accesses immediately, then joins
/// any current evaluation before erasing bytes. It does not cancel durable work.
pub fn close(self: *Self, io: std.Io, ticket: Ticket) void {
    self.mutex.lockUncancelable(io);
    defer self.mutex.unlock(io);
    while (self.find(ticket)) |slot| {
        slot.state = .closing;
        self.changed.broadcast(io);
        if (!slot.borrowed) {
            slot.wipe();
            return;
        }
        self.changed.waitUncancelable(io, &self.mutex);
    }
}
pub const Borrow = struct {
    registry: *Self,
    /// The borrowing task owns cancellation and cleanup through this runtime.
    io: std.Io,
    ticket: Ticket,
    sequence: u64,

    fn checked(self: Borrow) !*Slot {
        const slot = self.registry.find(self.ticket) orelse return error.ApplicationReservationLost;
        if (!slot.borrowed or slot.sequence != self.sequence or slot.state != .open or self.registry.stopped) return error.ApplicationReservationLost;
        if (try now(self.io) >= slot.reservation.expires_ms) {
            slot.state = .closing;
            return error.ApplicationReservationExpired;
        }
        return slot;
    }
    /// A native authority adapter calls this before each redemption, dispatch
    /// or disclosure. The original bound timestamp cannot establish freshness.
    pub fn requireLive(self: Borrow) !void {
        try self.registry.mutex.lock(self.io);
        defer self.registry.mutex.unlock(self.io);
        _ = try self.checked();
    }
    pub const View = struct { reservation: *R, request: H.Request, private_memory: []u8 };
    /// The view belongs exclusively to this borrow and cannot outlive it.
    /// Native binders must replace the denying authority for this evaluation.
    pub fn view(self: Borrow) !View {
        try self.registry.mutex.lock(self.io);
        defer self.registry.mutex.unlock(self.io);
        const slot = try self.checked();
        return .{ .reservation = &slot.reservation, .request = slot.request, .private_memory = slot.private_memory };
    }
    pub fn deinit(self: *Borrow) void {
        const registry = self.registry;
        // The deferred unlock outlives this borrow's invalidation.
        const io = self.io;
        registry.mutex.lockUncancelable(io);
        defer registry.mutex.unlock(io);
        const slot = registry.find(self.ticket) orelse unreachable;
        std.debug.assert(slot.borrowed and slot.sequence == self.sequence);
        // No scope/allocator borrowed from this evaluation remains callable.
        slot.reservation.authority = .{ .context = slot, .check = deny };
        std.crypto.secureZero(u8, slot.private_memory);
        slot.borrowed = false;
        if (slot.state == .closing or registry.stopped) slot.wipe();
        registry.changed.broadcast(io);
        self.* = undefined;
    }
};
/// Waiting for the same request releases the metadata lock. Independent
/// requests never hold it during native I/O or protected expression evaluation.
pub fn borrow(self: *Self, io: std.Io, ticket: Ticket, input: R.Input) !Borrow {
    try self.mutex.lock(io);
    defer self.mutex.unlock(io);
    while (true) {
        const slot = self.find(ticket) orelse return error.ApplicationReservationLost;
        if (self.stopped or slot.state != .open) return error.ApplicationReservationLost;
        if (try now(io) >= slot.reservation.expires_ms) {
            slot.state = .closing;
            if (!slot.borrowed) slot.wipe();
            return error.ApplicationReservationExpired;
        }
        if (!std.meta.eql(input, slot.reservation.input)) return error.ApplicationRequestOwnerMismatch;
        if (!slot.borrowed) {
            slot.sequence = try std.math.add(u64, slot.sequence, 1);
            slot.borrowed = true;
            return .{ .registry = self, .io = io, .ticket = ticket, .sequence = slot.sequence };
        }
        try self.changed.wait(io, &self.mutex);
    }
}

const Proof = struct {
    fn limits() Limits {
        return .{ .active_requests = 2, .request_bytes = 512, .protected_bytes = 1024, .protected_values = 4, .scratch_bytes = 256, .resident_bytes = 64 * 1024 };
    }
    fn input(ordinal: u32) R.Input {
        const scope: c.protocol.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
        return .{ .target = .{ .definition = c.protocol.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(3) }, .partition = 0 }, .operation = .{ .scope = scope, .principal = 11, .operation = 13 }, .ordinal = ordinal };
    }
    fn access(io: std.Io) !R.Access {
        const original = input(0);
        return .{ .owner = .{ .definition = c.protocol.Growth.current_definition, .connection = .{ .scope = original.operation.scope, .branch = 1, .audience = 5, .principal = 7, .role = 9 }, .account = @splat(1), .token = @splat(2) }, .input = original, .now_ms = try now(io) };
    }
    fn allow(_: *anyopaque, _: R.Evidence) anyerror!void {}
};

test "application request registry owns bounded bytes and never evicts a live reservation" {
    const t = std.testing;
    var limits = Proof.limits();
    limits.resident_bytes = 1;
    try t.expectError(error.ApplicationReservationCapacity, init(t.allocator, limits));
    var registry = try init(t.allocator, Proof.limits());
    defer registry.deinit(t.io);
    // Construction publishes its original identity before copying bytes or
    // obtaining randomness, so another admission cannot race that interval.
    const constructing = try registry.vacant(t.io, Proof.input(99));
    try t.expectError(error.ApplicationRequestOwnerMismatch, registry.open(t.io, Proof.input(99), @splat(9), .{ .query = "duplicate", .headers = &.{} }, 60_000));
    registry.mutex.lockUncancelable(t.io);
    constructing.wipe();
    registry.mutex.unlock(t.io);
    var query = "state=private".*;
    var cookie = "private-cookie".*;
    const ticket = try registry.open(t.io, Proof.input(0), @splat(1), .{ .query = &query, .headers = &.{.{ .name = "cookie", .value = &cookie }} }, 60_000);
    try t.expectError(error.ApplicationRequestOwnerMismatch, registry.open(t.io, Proof.input(0), @splat(9), .{ .query = "duplicate", .headers = &.{} }, 60_000));
    @memset(&query, 'x');
    @memset(&cookie, 'x');
    const other = try registry.open(t.io, Proof.input(1), @splat(2), .{ .query = "", .headers = &.{} }, 60_000);
    try t.expectError(error.ApplicationReservationCapacity, registry.open(t.io, Proof.input(2), @splat(3), .{ .query = "", .headers = &.{} }, 60_000));
    try t.expectError(error.ApplicationRequestOwnerMismatch, registry.borrow(t.io, ticket, Proof.input(1)));
    var stale: Borrow = undefined;
    var expires: u64 = undefined;
    {
        var first = try registry.borrow(t.io, ticket, Proof.input(0));
        defer first.deinit();
        stale = first;
        var second = try registry.borrow(t.io, other, Proof.input(1));
        defer second.deinit();
        const view = try first.view();
        try t.expectEqualStrings("state=private", view.request.query);
        try t.expectEqualStrings("private-cookie", view.request.headers[0].value);
        expires = view.reservation.expires_ms;
        try t.expectError(error.MissingProgramNativeBinding, view.reservation.request(try Proof.access(t.io), .{ .capability = ticket.reference }));
        // The test adapter authorizes only this borrow. Production composition
        // supplies the signed native authority, never an ingress assertion.
        view.reservation.authority = .{ .context = &registry, .check = Proof.allow };
        _ = try view.reservation.retain(t.io, try Proof.access(t.io), .{ .step = 1, .node = 1, .arguments = @splat(1) }, .{ .secret = .{ .bytes = "protected-material", .revision = "transient", .origin = .random, .revision_kind = .transient } });
        @memset(view.private_memory, 0xa5);
    }
    try t.expectError(error.ApplicationReservationLost, stale.requireLive());
    {
        var next = try registry.borrow(t.io, ticket, Proof.input(0));
        defer next.deinit();
        try t.expectError(error.ApplicationReservationLost, stale.requireLive());
        const view = try next.view();
        try t.expectEqual(expires, view.reservation.expires_ms);
        try t.expect(std.mem.allEqual(u8, view.private_memory, 0));
        try t.expectEqual(1, view.reservation.used);
        try t.expectError(error.MissingProgramNativeBinding, view.reservation.request(try Proof.access(t.io), .{ .capability = ticket.reference }));
    }
    registry.close(t.io, ticket);
    try t.expectError(error.ApplicationReservationLost, registry.borrow(t.io, ticket, Proof.input(0)));
    const replacement = try registry.open(t.io, Proof.input(2), @splat(3), .{ .query = "replacement", .headers = &.{} }, 60_000);
    registry.close(t.io, ticket); // A stale close cannot erase a reused slot.
    {
        var current = try registry.borrow(t.io, replacement, Proof.input(2));
        defer current.deinit();
        try t.expectEqualStrings("replacement", (try current.view()).request.query);
    }
    registry.close(t.io, replacement);
    registry.close(t.io, other);
    try t.expect(std.mem.allEqual(u8, registry.memory, 0));
    try t.expect(std.mem.allEqual(u8, std.mem.sliceAsBytes(registry.values), 0));
    const oversized: [513]u8 = @splat('x');
    try t.expectError(error.ApplicationReservationCapacity, registry.open(t.io, Proof.input(3), @splat(4), .{ .query = &oversized, .headers = &.{} }, 60_000));
    try t.expect(std.mem.allEqual(u8, registry.memory, 0));
    const recovered = try registry.open(t.io, Proof.input(3), @splat(4), .{ .query = "after refusal", .headers = &.{} }, 60_000);
    registry.close(t.io, recovered);
}

test "application request close revokes access before joining and erasing one borrower" {
    const t = std.testing;
    const Closing = struct {
        registry: *Self,
        ticket: Ticket,
        finished: std.Io.Event = .unset,
        fn run(self: *@This(), io: std.Io) void {
            self.registry.close(io, self.ticket);
            self.finished.set(io);
        }
    };
    var registry = try init(t.allocator, Proof.limits());
    defer registry.deinit(t.io);
    const ticket = try registry.open(t.io, Proof.input(0), @splat(1), .{ .query = "private-query", .headers = &.{} }, 60_000);
    const other = try registry.open(t.io, Proof.input(1), @splat(2), .{ .query = "other-query", .headers = &.{} }, 60_000);
    var first: ?Borrow = try registry.borrow(t.io, ticket, Proof.input(0));
    defer if (first) |*value| value.deinit();
    const original = try first.?.view();
    var closing: Closing = .{ .registry = &registry, .ticket = ticket };
    var future = try t.io.concurrent(Closing.run, .{ &closing, t.io });
    // On a failed assertion, release the borrow before joining the closer.
    defer {
        if (first) |*value| {
            value.deinit();
            first = null;
        }
        future.await(t.io);
    }
    {
        try registry.mutex.lock(t.io);
        defer registry.mutex.unlock(t.io);
        while (registry.find(ticket).?.state != .closing) try registry.changed.wait(t.io, &registry.mutex);
    }
    try t.expect(!closing.finished.isSet());
    try t.expectError(error.ApplicationReservationLost, first.?.requireLive());
    try t.expectError(error.ApplicationReservationLost, registry.borrow(t.io, ticket, Proof.input(0)));
    // Existing borrowed bytes are erased only after their user releases them.
    try t.expectEqualStrings("private-query", original.request.query);
    {
        var independent = try registry.borrow(t.io, other, Proof.input(1));
        defer independent.deinit();
        try t.expectEqualStrings("other-query", (try independent.view()).request.query);
    }
    first.?.deinit();
    first = null;
    try closing.finished.wait(t.io);
    try t.expect(closing.finished.isSet());
    try t.expect(std.mem.allEqual(u8, original.request.query, 0));
    registry.close(t.io, other);
}

test "application request expiry uses the current clock and erases after the active borrow" {
    const t = std.testing;
    var registry = try init(t.allocator, Proof.limits());
    defer registry.deinit(t.io);
    const ticket = try registry.open(t.io, Proof.input(0), @splat(1), .{ .query = "private", .headers = &.{} }, 60_000);
    {
        var borrowed = try registry.borrow(t.io, ticket, Proof.input(0));
        defer borrowed.deinit();
        const view = try borrowed.view();
        view.reservation.expires_ms = 0;
        try t.expectError(error.ApplicationReservationExpired, borrowed.requireLive());
        try t.expectEqualStrings("private", view.request.query);
    }
    try t.expectError(error.ApplicationReservationLost, registry.borrow(t.io, ticket, Proof.input(0)));
    try t.expect(std.mem.allEqual(u8, registry.memory, 0));
}

test "application request borrowing uses each task runtime for cancellation and cleanup" {
    const t = std.testing;
    var runtime: std.Io.Threaded = .init(t.allocator, .{ .concurrent_limit = .limited(2), .async_limit = .limited(2) });
    defer runtime.deinit();
    const caller = runtime.io();
    var registry = try init(t.allocator, Proof.limits());
    defer registry.deinit(t.io);
    const ticket = try registry.open(t.io, Proof.input(0), @splat(1), .{ .query = "original", .headers = &.{} }, 60_000);
    var held: ?Borrow = try registry.borrow(t.io, ticket, Proof.input(0));
    defer if (held) |*value| value.deinit();
    const Waiting = struct {
        fn run(owner: *Self, io: std.Io, selected: Ticket, entered: *std.Io.Event) !void {
            entered.set(io);
            var borrowed = try owner.borrow(io, selected, Proof.input(0));
            defer borrowed.deinit();
            try borrowed.requireLive();
            try t.expectEqualStrings("original", (try borrowed.view()).request.query);
        }
    };
    var entered: std.Io.Event = .unset;
    var waiting = try caller.concurrent(Waiting.run, .{ &registry, caller, ticket, &entered });
    defer _ = waiting.cancel(caller) catch {};
    try entered.wait(t.io);
    // The competing task belongs to a different runtime from ingress and the
    // current borrow. Cancelling its wait neither steals nor closes that borrow.
    try t.expectError(error.Canceled, waiting.cancel(caller));
    try held.?.requireLive();
    try t.expectEqualStrings("original", (try held.?.view()).request.query);
    held.?.deinit();
    held = null;
    var resumed = try caller.concurrent(Waiting.run, .{ &registry, caller, ticket, &entered });
    try resumed.await(caller);
    registry.close(t.io, ticket);
    try t.expect(std.mem.allEqual(u8, registry.memory, 0));
}
