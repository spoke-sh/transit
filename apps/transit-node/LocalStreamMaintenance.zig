//! Bounded Stream work within the shared local maintenance memory budget.
//! One active recovery workspace per class survives turns; durable roots, not a
//! resident object population, determine work. No proof or clock is cached.
const std = @import("std");
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Host = @import("LocalTableHost.zig");
const Authority = @import("LocalMaintenanceAuthority.zig");
const Stream = c.storage.StreamPartition;
const Self = @This();
pub const recovery_frames = 16;
const Hints = [64]?Stream.RecoveryState;
const Class = enum {
    flush,
    archive,
    trim,
    compact,
    expire,
    fn next(self: Class) Class {
        return @fromBackingInt(@intCast((@backingInt(self) + 1) % 5));
    }
    fn enabled(self: Class, settings: c.protocol.Storage.Maintenance) bool {
        return switch (self) {
            .flush => settings.flush.enabled,
            .archive, .trim => settings.archive.enabled,
            .compact => settings.compact,
            .expire => true, // Only a declaration's explicit age can expire.
        };
    }
};
const Active = struct {
    cursor: c.DirectCatalog.StreamMaintenanceCursor = .{},
    pending: ?c.DirectCatalog.StreamMaintenanceTarget = null,
    workspace: ?*Workspace = null,
    fn clear(self: *@This()) void {
        if (self.workspace) |workspace| workspace.destroy();
        self.workspace = null;
        self.pending = null;
    }
};
const Workspace = struct {
    allocator: std.mem.Allocator,
    control: backend.DataStore,
    data: backend.DataStore,
    stream: Stream,
    fn create(allocator: std.mem.Allocator, native: *backend.Backend, initial: c.storage.LogInitialization.Request, guard: c.storage.PublicationGuard) !*Workspace {
        const self = try allocator.create(Workspace);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .control = .{ .backend = native, .control = true }, .data = .{ .backend = native }, .stream = undefined };
        self.stream = try Stream.open(allocator, self.data.log(), self.data.objects(), initial, guard, .{
            .control = .{ .log = self.control.log(), .objects = self.control.objects() },
        });
        return self;
    }
    fn destroy(self: *Workspace) void {
        self.stream.deinit() catch unreachable; // Maintenance retains no borrows.
        self.allocator.destroy(self);
    }
};

active: [5]Active = @splat(.{}),
hints: ?struct { allocator: std.mem.Allocator, values: *Hints } = null,
next_class: Class = .flush,
last_object: ?u64 = null,
last_rows: usize = 0,

pub fn deinit(self: *Self) void {
    for (&self.active) |*active| active.clear();
    if (self.hints) |hints| hints.allocator.destroy(hints.values);
    self.* = .{};
}

pub fn step(self: *Self, allocator: std.mem.Allocator, host: *Host, engine: *backend.DataAuthority.Engine, settings: c.protocol.Storage.Maintenance, signed: c.protocol.Growth.SignedRequest) !bool {
    self.last_object = null;
    self.last_rows = 0;
    for (0..5) |_| {
        const selected = self.next_class;
        self.next_class = selected.next();
        const active = &self.active[@backingInt(selected)];
        if (!selected.enabled(settings)) {
            active.clear();
            continue;
        }
        if (try self.unit(allocator, host, engine, settings, selected, active, signed)) return true;
    }
    return false;
}

fn unit(self: *Self, allocator: std.mem.Allocator, host: *Host, engine: *backend.DataAuthority.Engine, settings: c.protocol.Storage.Maintenance, selected: Class, active: *Active, signed: c.protocol.Growth.SignedRequest) !bool {
    errdefer active.clear();
    const native = engine.journal.backend;
    const io = native.io;
    try host.directory.lockShared(io);
    defer host.directory.unlockShared(io);
    var authority: Authority = .{ .engine = engine, .signed = signed, .resource = host.configuration.scope.resource };
    var control: backend.DataStore = .{ .backend = native, .control = true };
    var data: backend.DataStore = .{ .backend = native };
    var catalog = try c.DirectCatalog.init(allocator, host.configuration, control.log(), control.objects(), data.log(), data.objects(), host.options);
    defer catalog.deinit();
    try host.recovery_mutex.lock(io);
    const prior = host.recovery;
    host.recovery_mutex.unlock(io);
    try catalog.recoverSince(prior);
    if (active.pending == null) active.pending = (try catalog.streamMaintenanceNext(&active.cursor, authority.guard())).target;
    const target = active.pending orelse return false;
    self.last_object = target.object;
    const lock = &host.tables[@intCast(target.object % host.tables.len)];
    try lock.lock(io);
    defer lock.unlock(io);
    const definition = (try catalog.streamMaintenanceDefinition(target, authority.guard())) orelse {
        active.clear();
        return false;
    };
    if ((selected == .expire and (definition.stored.retired or definition.stored.declaration.configuration.retention.max_age_ms == null)) or
        (selected == .compact and definition.stored.declaration.configuration.policy.stream.compact_key_column == null) or
        (selected == .flush and definition.stored.retired))
    {
        active.clear();
        return false;
    }
    const initial = try definition.genesis(target.ordinal);
    if (self.hints == null) {
        const values = try allocator.create(Hints);
        values.* = @splat(null);
        self.hints = .{ .allocator = allocator, .values = values };
    }
    const hint = &self.hints.?.values[@intCast(initial.partition % 64)];
    if (hint.*) |known| if (!std.meta.eql(known.root.initialization, initial)) {
        hint.* = null;
    };
    if (active.workspace) |workspace| {
        if (workspace.data.backend != native) return error.InvalidTableOwner;
        try workspace.stream.root.initialization.requireSame(initial);
    } else active.workspace = try Workspace.create(allocator, native, initial, authority.guard());
    const workspace = active.workspace.?;
    const stream = &workspace.stream;
    // A cold history longer than one replay budget resumes next turn. Clearing
    // the owner between such turns would keep every long partition unready.
    if (!(try stream.recoverStepSince(authority.guard(), recovery_frames, hint.*)).complete) return true;
    defer active.clear();
    hint.* = try stream.recoveryState();
    defer if (stream.ready) {
        hint.* = stream.recoveryState() catch unreachable;
    };
    stream.options.clock = @import("LocalLogClock.zig").source(engine);
    defer stream.options.clock = null;
    const before = stream.root.next_lsn;
    defer if (stream.root.next_lsn != before or !stream.ready) host.notifyStreams();
    switch (selected) {
        .archive => return stream.archiveMaintenanceUnit(.{ .frames = settings.archive.work_frames }, authority.guard()),
        .compact => return stream.compactionMaintenanceUnit(definition.stored, @min(settings.compaction_rows, c.storage.StreamCompaction.max_rows), authority.guard()),
        .trim => {
            if (stream.root.archive.through == 0 or stream.root.recovery == null) return false;
            const guard = authority.guard();
            _ = try guard.acquire(guard.context);
            defer guard.release(guard.context);
            return !(try workspace.data.trimUnit(initial.partition, @min(stream.root.archive.through, stream.root.recovery.?.next_lsn))).complete;
        },
        .flush => {
            if (definition.stored.retired or stream.root.sealed_through == stream.root.next_offset) return false;
            // Stream sealing preserves one whole accepted append and its digest.
            // The schema-bound batch byte/row limits bound this unit, rather
            // than Table's partial-row flush budget or volatile age hints.
            const progress = try stream.flush(stream.root.position(), authority.guard());
            self.last_rows = progress.rows;
            return progress.rows != 0;
        },
        .expire => {
            if (stream.root.compaction != null) return false;
            _ = try stream.expireHistory(definition.stored, stream.root.position(), authority.guard());
            return stream.root.next_lsn != before;
        },
    }
}
