//! Bounded volatile read-pin reservations. The host serializes these short
//! transitions; provider I/O and authorization remain outside this registry.
const std = @import("std");
const core = @import("root.zig");
const g = core.protocol.Growth;
const Stored = core.growing.StoredSnapshot;
const Self = @This();

pub const Selector = union(enum) {
    open: struct { resource: u64, nonce: [16]u8 },
    existing: g.SnapshotId,
    pub fn from(kind: @FieldType(g.Query, "kind")) ?Selector {
        return switch (kind) {
            .open_snapshot => |q| .{ .open = .{ .resource = q.resource, .nonce = q.nonce } },
            .snapshot_entries => |q| .{ .existing = q.id },
            .close_snapshot => |id| .{ .existing = id },
            .snapshot_read => |q| switch (q.snapshot) {
                .open => |v| .{ .open = .{ .resource = v.resource, .nonce = v.nonce } },
                .existing => |id| .{ .existing = id },
            },
            else => null,
        };
    }
};
const Reservation = struct {
    ticket: u64,
    serial: u64,
    principal: u64,
    epoch: u64,
    selector: Selector,
};
const Slot = struct { value: ?Stored = null, reservation: ?Reservation = null };
pub const Lease = struct {
    index: ?usize,
    ticket: u64,
    serial: u64,
    values: [1]?Stored,
};

epoch: [16]u8,
serial: u64 = 0,
ticket: u64 = 0,
time_floor_ms: u64 = 0,
slots: [g.snapshot_capacity]Slot = @splat(.{}),

/// Caller supplies an authenticated principal and validated trusted time.
/// Reservations count toward both quotas, including opens still reading data.
/// A second operation on the same pin conflicts; it cannot renew a closed pin.
pub fn acquire(self: *Self, principal: u64, epoch: u64, selector: Selector, now: core.Time.Sample) !Lease {
    if (now.unix_ms < self.time_floor_ms) return error.ClockRollback;
    self.time_floor_ms = now.unix_ms;
    if (self.ticket == std.math.maxInt(u64)) return error.StateViewCapacity;
    var free: ?usize = null;
    var selected: ?usize = null;
    var owned: usize = 0;
    for (&self.slots, 0..) |*slot, index| {
        if (slot.reservation == null) if (slot.value) |value| {
            if (now.lower() >= value.meta.deadline_ms) slot.value = null;
        };
        if (slot.reservation) |reservation| {
            if (reservation.principal == principal) owned += 1;
            if (reservation.principal == principal and reservation.epoch == epoch and
                std.meta.eql(reservation.selector, selector)) return error.Conflict;
        } else if (slot.value) |value| {
            if (value.principal == principal) owned += 1;
        } else if (free == null) free = index;
        if (slot.value) |value| {
            const matches = switch (selector) {
                .existing => |id| std.meta.eql(value.meta.id, id),
                .open => |open| value.principal == principal and value.principal_epoch == epoch and
                    value.meta.resource.id == open.resource and std.mem.eql(u8, &value.nonce, &open.nonce),
            };
            if (!matches) continue;
            if (value.principal != principal or value.principal_epoch != epoch) return error.Forbidden;
            if (slot.reservation != null) return error.Conflict;
            selected = index;
        }
    }
    var serial = self.serial;
    if (selected == null and selector == .open) {
        if (free == null or owned >= g.snapshots_per_principal or self.serial >= core.max_counter) return error.StateViewCapacity;
        selected = free;
        // Reserve the identity before I/O. Failed/cancelled opens consume it;
        // no later read can mistake an abandoned candidate for a new pin.
        self.serial += 1;
    }
    if (selected) |index| {
        self.ticket += 1;
        self.slots[index].reservation = .{ .ticket = self.ticket, .serial = if (self.slots[index].value) |value| value.meta.id.serial else self.serial, .principal = principal, .epoch = epoch, .selector = selector };
        if (self.slots[index].value != null) serial = self.serial;
        return .{ .index = index, .ticket = self.ticket, .serial = serial, .values = .{self.slots[index].value} };
    }
    // Unknown/foreign-epoch identities remain absent. Core determines whether
    // this is an expired read or an idempotent close, after current admission.
    return .{ .index = null, .ticket = 0, .serial = serial, .values = .{null} };
}

/// Only successful disclosure publishes a renewal/open/close. Failure releases
/// the reservation and keeps the preceding pin, including its original expiry.
pub fn release(self: *Self, lease: Lease, success: bool, time_floor_ms: u64) !void {
    const index = lease.index orelse {
        self.time_floor_ms = @max(self.time_floor_ms, time_floor_ms);
        return;
    };
    if (index >= self.slots.len) return error.InvalidSnapshotLease;
    const slot = &self.slots[index];
    const reservation = slot.reservation orelse return error.InvalidSnapshotLease;
    if (reservation.ticket != lease.ticket) return error.InvalidSnapshotLease;
    if (success) {
        if (lease.values[0]) |value| {
            if (value.principal != reservation.principal or value.principal_epoch != reservation.epoch or value.meta.id.serial != reservation.serial or
                !std.mem.eql(u8, &value.meta.id.epoch, &self.epoch)) return error.InvalidSnapshotLease;
            switch (reservation.selector) {
                .existing => |id| if (!std.meta.eql(id, value.meta.id)) return error.InvalidSnapshotLease,
                .open => |open| if (open.resource != value.meta.resource.id or !std.mem.eql(u8, &open.nonce, &value.nonce)) return error.InvalidSnapshotLease,
            }
        }
        slot.value = lease.values[0];
    }
    slot.reservation = null;
    self.time_floor_ms = @max(self.time_floor_ms, time_floor_ms);
}

test "independent opens reserve distinct identities and enforce pending quotas" {
    const t = std.testing;
    var registry: Self = .{ .epoch = @splat(1) };
    const now: core.Time.Sample = .{ .unix_ms = 1000, .error_ms = 1 };
    var leases: [g.snapshots_per_principal]Lease = undefined;
    for (&leases, 0..) |*lease, i| {
        lease.* = try registry.acquire(1, 2, .{ .open = .{ .resource = 3, .nonce = @splat(@intCast(i)) } }, now);
        try t.expectEqual(i, lease.serial);
    }
    try t.expectError(error.Conflict, registry.acquire(1, 2, .{ .open = .{ .resource = 3, .nonce = @splat(0) } }, now));
    try t.expectError(error.StateViewCapacity, registry.acquire(1, 2, .{ .open = .{ .resource = 3, .nonce = @splat(99) } }, now));
    const independent = try registry.acquire(4, 2, .{ .open = .{ .resource = 3, .nonce = @splat(99) } }, now);
    try registry.release(independent, false, 1001);
    for (leases) |lease| try registry.release(lease, false, 1001);
    try t.expectError(error.InvalidSnapshotLease, registry.release(leases[0], false, 1001));
    try t.expectError(error.ClockRollback, registry.acquire(1, 2, .{ .existing = .{ .epoch = @splat(1), .serial = 1 } }, now));
}

test "leased read failure preserves a pin and concurrent close cannot resurrect it" {
    const t = std.testing;
    var registry: Self = .{ .epoch = @splat(1) };
    const now: core.Time.Sample = .{ .unix_ms = 1000, .error_ms = 1 };
    var opened = try registry.acquire(1, 2, .{ .open = .{ .resource = 3, .nonce = @splat(4) } }, now);
    const id: g.SnapshotId = .{ .epoch = registry.epoch, .serial = opened.serial + 1 };
    opened.values[0] = .{
        .meta = .{ .id = id, .resource = .{ .id = 3, .writer = 1, .owner = 1, .revision = 1, .deadline_ms = null }, .deadline_ms = 2000, .hard_deadline_ms = 3000 },
        .snapshot = .{},
        .principal = 1,
        .principal_epoch = 2,
        .nonce = @splat(4),
    };
    try registry.release(opened, true, 1000);
    var reading = try registry.acquire(1, 2, .{ .existing = id }, now);
    try t.expectError(error.Conflict, registry.acquire(1, 2, .{ .existing = id }, now));
    try t.expectError(error.Forbidden, registry.acquire(2, 2, .{ .existing = id }, now));
    reading.values[0].?.meta.deadline_ms = 2500;
    try registry.release(reading, false, 1000);
    var closing = try registry.acquire(1, 2, .{ .existing = id }, now);
    try t.expectEqual(2000, closing.values[0].?.meta.deadline_ms);
    closing.values[0] = null;
    try registry.release(closing, true, 1000);
    try t.expectError(error.InvalidSnapshotLease, registry.release(reading, true, 9999));
    try t.expectEqual(1000, registry.time_floor_ms);
    const missing = try registry.acquire(1, 2, .{ .existing = id }, now);
    try t.expectEqual(null, missing.values[0]);
}

test "global reservations cannot exceed capacity or be reclaimed while active" {
    const t = std.testing;
    var registry: Self = .{ .epoch = @splat(1) };
    const now: core.Time.Sample = .{ .unix_ms = 1000, .error_ms = 1 };
    var leases: [g.snapshot_capacity]Lease = undefined;
    for (&leases, 0..) |*lease, i| lease.* = try registry.acquire(1 + i / g.snapshots_per_principal, 1, .{
        .open = .{ .resource = 3, .nonce = @splat(@intCast(i)) },
    }, now);
    // An unfinished open is not an expired published pin. Even much later
    // trusted time cannot recycle its slot out from underneath its owner.
    const later: core.Time.Sample = .{ .unix_ms = 1_000_000, .error_ms = 1 };
    try t.expectError(error.StateViewCapacity, registry.acquire(99, 1, .{ .open = .{ .resource = 3, .nonce = @splat(99) } }, later));
    try registry.release(leases[0], false, later.unix_ms);
    const replacement = try registry.acquire(99, 1, .{ .open = .{ .resource = 3, .nonce = @splat(99) } }, later);
    try t.expectEqual(leases[0].index, replacement.index);
    try t.expect(replacement.serial > leases[0].serial);
    try t.expectError(error.InvalidSnapshotLease, registry.release(leases[0], false, later.unix_ms));
    try registry.release(replacement, false, later.unix_ms);
    for (leases[1..]) |lease| try registry.release(lease, false, later.unix_ms);
}
