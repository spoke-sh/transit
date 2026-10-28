//! One physical Table unit within the local owner's shared maintenance executor.
//! Durable roots determine work; bounded volatile age hints only select earlier
//! flushing when an age is unknown. They never authorize expiry or publication.
const std = @import("std");
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Host = @import("LocalTableHost.zig");
const g = c.protocol.Growth;
const P = c.storage.TablePartition;
const Slab = c.fuze.memory.Slab;
const Self = @This();

host: *Host,
/// Private Table workspace backing; provider and engine caches have their own
/// lifetimes and are accounted separately from this allocation boundary.
allocator: std.mem.Allocator,
/// One private reserve shared by sequential Table work classes. All borrowers
/// finish within step; no catalog, row or allocator escapes into a later unit.
workspace: ?Slab = null,
cursors: struct {
    flush: c.DirectCatalog.MaintenanceCursor = .{},
    archive: c.DirectCatalog.MaintenanceCursor = .{},
    trim: c.DirectCatalog.MaintenanceCursor = .{},
    compact: c.DirectCatalog.MaintenanceCursor = .{},
} = .{},
next_class: Class = .flush,
ages: [64]?Age = @splat(null),
last_peak_bytes: usize = 0,
last_rows: usize = 0,
last_object: ?u64 = null,
last_class: ?Class = null,
pub const Class = enum {
    flush,
    archive,
    trim,
    compact,
    fn next(self: Class) Class {
        return switch (self) {
            .flush => .archive,
            .archive => .trim,
            .trim => .compact,
            .compact => .flush,
        };
    }
    fn enabled(self: Class, settings: c.protocol.Storage.Maintenance) bool {
        return switch (self) {
            .flush => settings.flush.enabled,
            .archive, .trim => settings.archive.enabled,
            .compact => settings.compact,
        };
    }
};
const Age = struct { object: u64, since_ms: i64 };

pub fn deinit(self: *Self) void {
    if (self.workspace) |*workspace| workspace.deinit();
    self.* = undefined;
}

pub fn step(raw: *anyopaque, engine: *backend.DataAuthority.Engine, settings: c.protocol.Storage.Maintenance, signed: g.SignedRequest) !bool {
    const self: *Self = @ptrCast(@alignCast(raw));
    try settings.validate();
    self.last_peak_bytes = 0;
    self.last_rows = 0;
    self.last_object = null;
    self.last_class = null;
    if (!settings.flush.enabled and !settings.archive.enabled and !settings.compact) return false;
    // These settings require owner restart. Do not grow a live reserve or fall
    // back to the heap when a unit exhausts its bounded private capacity.
    if (self.workspace == null) self.workspace = try Slab.init(self.allocator, settings.resident_bytes);
    const workspace = &self.workspace.?;
    if (workspace.buffer.len != (settings.resident_bytes & ~@as(usize, Slab.granule - 1))) return error.InvalidStorageBudget;
    var memory: c.fuze.MemoryBudget = .{ .parent = workspace.allocator(), .limit = workspace.buffer.len };
    defer {
        self.last_peak_bytes = memory.peak;
        std.debug.assert(memory.used == 0 and workspace.live_bytes == 0);
    }
    // Independently advance each class before I/O. Idle classes can be skipped
    // in one finite rotation; hot or failed work cannot own the next turn too.
    for (0..4) |_| {
        const selected = self.next_class;
        self.next_class = selected.next();
        if (!selected.enabled(settings)) continue;
        self.last_class = selected;
        const refusals = workspace.refusals;
        const worked = self.unit(memory.allocator(), engine, settings, selected, signed) catch |err| {
            if (err == error.OutOfMemory and (memory.exhausted or workspace.refusals != refusals)) return error.StorageMaintenanceBudget;
            return err;
        };
        if (worked) return true;
    }
    return false;
}

fn unit(self: *Self, allocator: std.mem.Allocator, engine: *backend.DataAuthority.Engine, settings: c.protocol.Storage.Maintenance, selected: Class, signed: g.SignedRequest) !bool {
    const owner = engine.journal.backend;
    const io = owner.io;
    try self.host.directory.lockShared(io);
    defer self.host.directory.unlockShared(io);
    var authority: Authority = .{ .engine = engine, .signed = signed, .resource = self.host.configuration.scope.resource };
    var control: backend.DataStore = .{ .backend = owner, .control = true };
    var data: backend.DataStore = .{ .backend = owner };
    var catalog = try c.DirectCatalog.init(allocator, self.host.configuration, control.log(), control.objects(), data.log(), data.objects(), self.host.options);
    defer catalog.deinit();
    try self.host.recovery_mutex.lock(io);
    const recovered = self.host.recovery;
    self.host.recovery_mutex.unlock(io);
    try catalog.recoverSince(recovered);
    // Selection advances before doing the selected unit. A hot, corrupt, denied
    // or quota-blocked Table cannot prevent the following Table's next turn.
    const cursor = switch (selected) {
        inline else => |work| &@field(self.cursors, @tagName(work)),
    };
    const selection = try catalog.maintenanceNext(cursor, authority.guard());
    const object = selection.object orelse return false;
    self.last_object = object;
    const lock = &self.host.tables[@intCast(object % self.host.tables.len)];
    try lock.lock(io);
    defer lock.unlock(io);
    catalog.options.table_recovery = &self.host.table_recovery[@intCast(object % self.host.tables.len)];
    errdefer catalog.options.table_recovery.?.* = null;
    var view = (try catalog.maintenanceOpen(allocator, object, authority.guard())) orelse return false;
    defer view.deinit();
    if (view.table.root.next_lsn == 0) return false;
    switch (selected) {
        .archive => return view.table.archiveMaintenanceUnit(.{ .frames = settings.archive.work_frames }, authority.guard()),
        .compact => return view.table.compactionMaintenanceUnit(.{ .rows = settings.compaction_rows }, authority.guard()),
        .trim => {
            if (view.table.root.archive.through == 0) return false;
            const guard = authority.guard();
            _ = try guard.acquire(guard.context);
            defer guard.release(guard.context);
            return !(try data.trimUnit(view.table.root.partition, view.table.root.archive.through)).complete;
        },
        .flush => {},
    }
    if (view.table.root.retired) return false;
    const flush = settings.flush;
    const pending = try view.table.pendingRows(flush.rows, authority.guard());
    const now = std.Io.Clock.awake.now(io).toMilliseconds();
    if (!self.eligible(object, pending, now, flush)) return false;
    self.last_rows = try view.table.flushThroughRows(view.table.root.next_lsn, flush.work_rows, authority.guard());
    if (pending.complete and self.last_rows == pending.rows) self.ages[@intCast(object % self.ages.len)] = .{ .object = object, .since_ms = now };
    return self.last_rows != 0;
}

fn eligible(self: *Self, object: u64, pending: P.PendingRows, now: i64, settings: c.protocol.Storage.Flush) bool {
    const slot = &self.ages[@intCast(object % self.ages.len)];
    if (pending.rows == 0) {
        slot.* = .{ .object = object, .since_ms = now };
        return false;
    }
    // A previous empty observation is a conservative lower bound on first
    // pending time. Unknown, collided or restarted hints flush immediately.
    // Time selects physical relocation; no trusted UTC clock is needed.
    const known = slot.*;
    const since = if (known != null and known.?.object == object) known.?.since_ms else now -| @as(i64, settings.age_ms);
    slot.* = .{ .object = object, .since_ms = since };
    return pending.rows >= settings.rows or pending.bytes >= settings.bytes or now < since or now -| since >= settings.age_ms;
}

const Authority = struct {
    engine: *backend.DataAuthority.Engine,
    signed: g.SignedRequest,
    resource: u64,
    epoch: ?u64 = null,
    held: bool = false,
    fn guard(self: *@This()) P.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
    fn acquire(raw: *anyopaque) !P.Guard.Fence {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (self.held) return error.AuthorityFenceAlreadyHeld;
        const owner = self.engine.journal.backend;
        try owner.authority.lockShared(owner.io);
        errdefer owner.authority.unlockShared(owner.io);
        try self.engine.authorizeMaintenance(self.signed);
        try self.engine.requireResourceLifetime(self.resource);
        if (self.epoch == null) self.epoch = self.engine.head.storage_epoch;
        self.held = true;
        return .{ .writer_epoch = self.epoch.?, .policy_epoch = self.engine.head.authorization.revision + 1 };
    }
    fn release(raw: *anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        std.debug.assert(self.held);
        self.held = false;
        const owner = self.engine.journal.backend;
        owner.authority.unlockShared(owner.io);
    }
};

test "physical flush age hints cannot delay evicted Tables or track durable cardinality" {
    const t = std.testing;
    var work: Self = .{ .host = undefined, .allocator = undefined };
    const settings: c.protocol.Storage.Flush = .{};
    const pending: P.PendingRows = .{ .rows = 1, .bytes = 100, .oldest_lsn = 7 };
    try t.expect(!work.eligible(1, .{}, 1000, settings));
    try t.expect(!work.eligible(1, pending, 1001, settings));
    try t.expect(work.eligible(1, pending, 6000, settings));
    try t.expect(work.eligible(65, pending, 6001, settings));
    try t.expect(work.eligible(1, pending, 6002, settings));
    try t.expect(!work.eligible(1, .{}, 6003, settings));
    try t.expect(work.eligible(1, pending, 6002, settings)); // clock rollback
    try t.expect(!work.eligible(1, .{}, 6004, settings));
    try t.expect(work.eligible(1, .{ .rows = settings.rows }, 6004, settings));
    try t.expect(work.eligible(1, .{ .rows = 1, .bytes = settings.bytes }, 6004, settings));
}

test "disabled maintenance and failed workspace admission leave storage and discovery untouched" {
    const t = std.testing;
    var probe: c.fuze.memory.AllocationProbe = .{ .parent = t.allocator };
    var work: Self = .{ .host = undefined, .allocator = probe.allocator() };
    defer work.deinit();
    probe.begin(true);
    // Neither path may dereference an engine, host or authority request.
    try t.expect(!try step(&work, undefined, .{}, undefined));
    try probe.verify();
    const cursors = work.cursors;
    try t.expectError(error.OutOfMemory, step(&work, undefined, .{ .flush = .{ .enabled = true } }, undefined));
    try t.expectError(error.BackingAllocationAfterWarmup, probe.verify());
    try t.expectEqual(1, probe.counts.alloc_attempts);
    try t.expectEqual(0, probe.live_bytes);
    try t.expect(work.workspace == null and work.last_class == null);
    try t.expectEqual(.flush, work.next_class);
    try t.expectEqualDeep(cursors, work.cursors);
}
