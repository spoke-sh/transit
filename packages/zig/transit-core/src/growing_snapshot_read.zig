//! One captured data cut, followed by bounded current-authority validation.
//! The host serializes engine access. External journal writers remain possible.
const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;
const g = p.Growth;
const growth = @import("growing.zig");
const state = @import("growing_state.zig");
const reads = @import("growing_read.zig");
const c = @import("catalog.zig");

pub fn read(engine: anytype, principal: growth.Principal, realm: u64, query: g.SnapshotRead.Query) !g.Response {
    const now = try reads.snapshotTime(engine);
    reads.sweepSnapshots(engine, now);
    var fresh = false;
    const slot: *?growth.StoredSnapshot = switch (query.snapshot) {
        .existing => |id| (try reads.snapshotSlot(engine, id, principal, now)) orelse return error.QueryExpired,
        .open => |opened| blk: {
            var free: ?*?growth.StoredSnapshot = null;
            var owned: usize = 0;
            for (engine.snapshotSlots()) |*candidate| {
                if (candidate.*) |stored| {
                    if (stored.principal != principal.grant.subject) continue;
                    owned += 1;
                    if (stored.principal_epoch == principal.epoch and stored.meta.resource.id == opened.resource and
                        std.mem.eql(u8, &stored.nonce, &opened.nonce))
                    {
                        try now.before(stored.meta.deadline_ms);
                        break :blk candidate;
                    }
                } else if (free == null) free = candidate;
            }
            if (free == null or owned >= g.snapshots_per_principal or engine.snapshot_serial >= p.max_counter) return error.StateViewCapacity;
            fresh = true;
            break :blk free.?;
        },
    };
    const stored: growth.StoredSnapshot = if (!fresh) slot.*.? else blk: {
        if (now.lower() > p.max_counter - g.snapshot_lifetime_ms) return error.UntrustedTime;
        const opened = query.snapshot.open;
        break :blk .{
            .meta = .{
                .id = .{ .epoch = engine.snapshot_epoch.?, .serial = engine.snapshot_serial + 1 },
                .resource = try state.resource(engine, opened.resource),
                .deadline_ms = now.lower() + g.view_lifetime_ms,
                .hard_deadline_ms = now.lower() + g.snapshot_lifetime_ms,
            },
            .snapshot = engine.head.catalog,
            .principal = principal.grant.subject,
            .principal_epoch = principal.epoch,
            .nonce = opened.nonce,
        };
    };
    try reads.snapshotAccess(engine, principal, stored.meta.resource.id, now);
    var result: g.SnapshotRead.Result = .{ .snapshot = stored.meta, .finished = query.finish };
    var basis = try @TypeOf(try engine.state()).open(engine.page_store, stored.snapshot);
    for (query.points, 0..) |key, i| if (key) |value| {
        result.points[i] = try point(&basis, stored.meta.resource.id, value);
    };
    if (query.blocks[0] != null) result.blocks = try reads.blockEntries(engine, &basis, stored.meta.resource, query.blocks);
    if (query.range) |range| try scan(&basis, stored.meta.resource.id, range, &result);

    // Unrelated writes while materializing immutable data need not restart it.
    // Reacquire ALL live authorization/lifetime and requested metadata at one
    // final root. Retry only this bounded validation if its tail races; never
    // recapture data or carry permission across a failed validation attempt.
    for (0..3) |_| {
        try engine.refresh();
        const current_principal = try engine.principal(principal.grant.subject);
        if (current_principal.epoch != principal.epoch or current_principal.grant.permissions & p.permission(.inspect) == 0 or
            !std.mem.eql(u8, &current_principal.grant.public_key, &principal.grant.public_key)) return error.Forbidden;
        const position = engine.head.position;
        var current = try engine.state();
        const before = try reads.snapshotTime(engine);
        try before.before(stored.meta.deadline_ms);
        try reads.snapshotAccess(engine, current_principal, stored.meta.resource.id, before);
        for (query.current, 0..) |requested, i| if (requested) |request| {
            if (request.resource != stored.meta.resource.id) try reads.snapshotAccess(engine, current_principal, request.resource, before);
            var acquired: g.SnapshotRead.CurrentResult = .{ .resource = try state.resource(engine, request.resource), .entries = @splat(null) };
            for (request.keys, 0..) |key, j| if (key) |value| {
                acquired.entries[j] = try point(&current, request.resource, value);
            };
            result.current[i] = acquired;
        };
        const after = try reads.snapshotTime(engine);
        try after.before(stored.meta.deadline_ms);
        try state.usable(engine, try state.resource(engine, stored.meta.resource.id), after);
        for (result.current) |value| if (value) |acquired| {
            if (acquired.resource.id != stored.meta.resource.id) try state.usable(engine, acquired.resource, after);
        };
        if (try engine.journal.tail() != position) continue;
        result.snapshot.deadline_ms = @min(stored.meta.hard_deadline_ms, try std.math.add(u64, after.lower(), g.view_lifetime_ms));
        // No slot allocation, renewal or release precedes successful validation.
        if (query.finish) {
            slot.* = null;
        } else {
            var renewed = stored;
            renewed.meta = result.snapshot;
            slot.* = renewed;
            if (fresh) engine.snapshot_serial = stored.meta.id.serial;
        }
        return .{ .realm = realm, .position = position, .definition = g.current_definition, .principal_sequence = current_principal.sequence, .body = .{ .snapshot_read = result } };
    }
    return error.Conflict;
}
fn point(basis: anytype, resource: u64, key: p.Value) !?g.Entry {
    const value = try basis.get(g.Entry, try c.key(.entry, resource, 0, key.slice()));
    if (value) |entry| if (!entry.key.eql(key)) return error.InvalidHistory;
    return value;
}
fn scan(basis: anytype, resource: u64, range: g.SnapshotRead.Range, result: *g.SnapshotRead.Result) !void {
    const namespace: c.Range = .{ .namespace = .entry, .major = resource, .minor = 0 };
    var after = if (range.after) |key| try c.key(.entry, resource, 0, key.slice()) else if (range.prefix) |prefix| try c.key(.entry, resource, 0, prefix.slice()) else namespace.prefix();
    var inclusive = range.after == null;
    var count: usize = 0;
    var bytes: u32 = 0;
    while (true) {
        const page = try basis.tree.scanRange(basis.snapshot.root, after, inclusive, namespace.end());
        for (page.entries) |slot| if (slot) |record| {
            const entry = try c.decode(g.Entry, &record.value);
            if (!std.mem.eql(u8, record.key.slice()[17..], entry.key.slice())) return error.InvalidHistory;
            if (range.prefix) |prefix| if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return;
            const size = g.SnapshotRead.entryBytes(entry);
            if (count == range.limit or bytes + size > range.bytes) {
                std.debug.assert(count != 0); // Minimum budget fits one maximum entry.
                result.next = result.entries[count - 1].?.key;
                return;
            }
            result.entries[count] = entry;
            count += 1;
            bytes += size;
        };
        after = page.next orelse return;
        inclusive = false;
    }
}
