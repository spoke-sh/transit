//! Bounded Stream/Queue work within the shared local maintenance memory budget.
//! One active recovery workspace per kind survives turns; durable roots, not a
//! resident object population, determine work. No proof or clock is cached.
const std = @import("std");
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Host = @import("LocalTableHost.zig");
const Authority = @import("LocalMaintenanceAuthority.zig");
pub fn Owner(comptime kind: c.protocol.StreamQueueDeclaration.Kind) type {
    return struct {
        const Partition = if (kind == .stream) c.storage.StreamPartition else c.storage.QueuePartition;
        const Self = @This();
        fn runtime(partition: *Partition) *(if (kind == .stream) Partition else @FieldType(Partition, "owner")) {
            return if (kind == .stream) partition else &partition.owner;
        }
        pub const recovery_frames: u16 = if (kind == .stream) 16 else 256;
        const Hints = [64]?Partition.RecoveryState;
        const Class = enum {
            flush,
            archive,
            checkpoint,
            trim,
            compact,
            expire,
            retention,
            fn next(self: Class) Class {
                return @fromBackingInt(@intCast((@backingInt(self) + 1) % class_count));
            }
            fn enabled(self: Class, settings: c.protocol.Storage.Maintenance) bool {
                return switch (self) {
                    .flush => settings.flush.enabled,
                    .archive, .trim => settings.archive.enabled,
                    // Queue metadata checkpoints bound cold-reopen WAL replay
                    // independently of optional WAL archiving.
                    .checkpoint => kind == .queue,
                    // Queue scheduling cleanup is control progress, independent
                    // of optional Stream payload compaction settings.
                    .compact => kind == .queue or settings.compact,
                    .expire => true, // Queue lease expiry and opted-in Stream age are distinct.
                    .retention => kind == .queue,
                };
            }
        };
        const class_count = @typeInfo(Class).@"enum".field_names.len;
        const Active = struct {
            cursor: c.DirectCatalog.LogMaintenanceCursor = .{},
            pending: ?c.DirectCatalog.LogMaintenanceTarget = null,
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
            stream: Partition,
            fn create(allocator: std.mem.Allocator, native: *backend.Backend, initial: c.storage.LogInitialization.Request, guard: c.storage.PublicationGuard, options: c.DirectTransactionLog.Options) !*Workspace {
                const self = try allocator.create(Workspace);
                errdefer allocator.destroy(self);
                self.* = .{ .allocator = allocator, .control = .{ .backend = native, .control = true, .scratch_allocator = allocator }, .data = .{ .backend = native, .scratch_allocator = allocator }, .stream = undefined };
                var configured = if (kind == .stream) options.stream else options.queue;
                configured.clock = null;
                configured.control = .{ .log = self.control.log(), .objects = self.control.objects() };
                self.stream = try Partition.open(allocator, self.data.log(), self.data.objects(), initial, guard, configured);
                return self;
            }
            fn destroy(self: *Workspace) void {
                self.stream.deinit() catch unreachable; // Maintenance retains no borrows.
                self.allocator.destroy(self);
            }
        };

        active: [class_count]Active = @splat(.{}),
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
            for (0..class_count) |_| {
                const selected = self.next_class;
                self.next_class = selected.next();
                const active = &self.active[@backingInt(selected)];
                if (!selected.enabled(settings)) {
                    active.clear();
                    continue;
                }
                const worked = try self.unit(allocator, host, engine, settings, selected, active, signed);
                // Keep only one recovering workspace per kind. The outer executor
                // rotates Table/Stream/Queue work, while this bounded replay resumes.
                if (active.workspace != null) self.next_class = selected;
                if (worked) return true;
            }
            return false;
        }

        noinline fn unit(self: *Self, allocator: std.mem.Allocator, host: *Host, engine: *backend.DataAuthority.Engine, settings: c.protocol.Storage.Maintenance, selected: Class, active: *Active, signed: c.protocol.Growth.SignedRequest) !bool {
            errdefer active.clear();
            const native = engine.journal.backend;
            const io = native.io;
            try host.directory.lockShared(io);
            defer host.directory.unlockShared(io);
            var authority: Authority = .{ .engine = engine, .signed = signed, .resource = host.configuration.scope.resource };
            var control: backend.DataStore = .{ .backend = native, .control = true, .scratch_allocator = allocator };
            var data: backend.DataStore = .{ .backend = native, .scratch_allocator = allocator };
            var catalog = try c.DirectCatalog.init(allocator, host.configuration, control.log(), control.objects(), data.log(), data.objects(), host.options);
            defer catalog.deinit();
            try host.recovery_mutex.lock(io);
            const prior = host.recovery;
            host.recovery_mutex.unlock(io);
            try catalog.recoverSince(prior);
            if (active.pending == null) active.pending = (try catalog.logMaintenanceNext(kind, &active.cursor, authority.guard())).target;
            const target = active.pending orelse return false;
            return self.executeSelectedLog(allocator, host, engine, &catalog, &data, &authority, settings, selected, active, target);
        }

        noinline fn executeSelectedLog(self: *Self, allocator: std.mem.Allocator, host: *Host, engine: *backend.DataAuthority.Engine, catalog: *c.DirectCatalog, data: *backend.DataStore, authority: *Authority, settings: c.protocol.Storage.Maintenance, selected: Class, active: *Active, target: c.DirectCatalog.LogMaintenanceTarget) !bool {
            const native = engine.journal.backend;
            const io = native.io;
            self.last_object = target.object;
            const lock = &host.tables[@intCast(target.object % host.tables.len)];
            try lock.lock(io);
            defer lock.unlock(io);
            const definition = (try catalog.logMaintenanceDefinition(kind, target, authority.guard())) orelse {
                active.clear();
                return false;
            };
            if ((selected == .retention and definition.stored.declaration.configuration.retention.max_age_ms == null) or
                (kind == .stream and selected == .expire and (definition.stored.retired or definition.stored.declaration.configuration.retention.max_age_ms == null)) or
                (kind == .stream and selected == .compact and definition.stored.declaration.configuration.policy.stream.compact_key_column == null) or
                (kind == .stream and selected == .flush and definition.stored.retired))
            {
                active.clear();
                return false;
            }
            const initial = try definition.genesis(target.ordinal);
            if (active.workspace == null and !try hasCandidateWork(allocator, data.log(), initial, definition.stored, selected, host.options.logs)) {
                active.clear();
                return false;
            }
            return self.runReadyWorkspace(allocator, host, engine, authority, settings, selected, active, definition.stored, initial);
        }

        noinline fn runReadyWorkspace(self: *Self, allocator: std.mem.Allocator, host: *Host, engine: *backend.DataAuthority.Engine, authority: *Authority, settings: c.protocol.Storage.Maintenance, selected: Class, active: *Active, stored: c.storage.LogDeclaration.Stored, initial: c.storage.LogInitialization.Request) !bool {
            const native = engine.journal.backend;
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
                try runtime(&workspace.stream).root.initialization.requireSame(initial);
            } else active.workspace = try Workspace.create(allocator, native, initial, authority.guard(), host.options.logs);
            const workspace = active.workspace.?;
            const stream = &workspace.stream;
            // A cold history longer than one replay budget resumes next turn. Clearing
            // the owner between such turns would keep every long partition unready.
            if (!(try stream.recoverStepSince(authority.guard(), recovery_frames, hint.*)).complete) return true;
            defer active.clear();
            hint.* = try stream.recoveryState();
            defer if (runtime(stream).ready) {
                hint.* = stream.recoveryState() catch unreachable;
            };
            runtime(stream).options.clock = @import("LocalLogClock.zig").source(engine);
            defer runtime(stream).options.clock = null;
            const before = runtime(stream).root.next_lsn;
            defer if (runtime(stream).root.next_lsn != before or !runtime(stream).ready) host.notifyLogs();
            switch (selected) {
                .archive => return stream.archiveMaintenanceUnit(.{ .frames = settings.archive.work_frames }, authority.guard()),
                .checkpoint => {
                    if (kind == .stream or !runtime(stream).needsCheckpoint()) return false;
                    return stream.checkpointMaintenanceUnit(authority.guard());
                },
                .compact => return if (kind == .stream)
                    stream.compactionMaintenanceUnit(stored, @min(settings.compaction_rows, c.storage.StreamCompaction.max_rows), authority.guard())
                else
                    stream.scheduleMaintenanceUnit(stored, @intCast(@min(stored.declaration.limits.timer_steps, c.storage.QueueTimeRun.max_rows)), authority.guard()),
                .trim => {
                    if (runtime(stream).root.archive.through == 0 or runtime(stream).root.recovery == null) return false;
                    const guard = authority.guard();
                    _ = try guard.acquire(guard.context);
                    defer guard.release(guard.context);
                    return !(try workspace.data.trimUnit(initial.partition, @min(runtime(stream).root.archive.through, runtime(stream).root.recovery.?.next_lsn))).complete;
                },
                .flush => {
                    if ((kind == .stream and stored.retired) or runtime(stream).root.sealed_through == runtime(stream).root.next_offset) return false;
                    // Log sealing preserves one whole accepted append and its digest.
                    // The schema-bound batch byte/row limits bound this unit, rather
                    // than Table's partial-row flush budget or volatile age hints.
                    const progress = try stream.flush(runtime(stream).root.position(), authority.guard());
                    self.last_rows = progress.rows;
                    return progress.rows != 0;
                },
                .retention => {
                    if (kind == .stream) return false;
                    const progress = try stream.expireTerminalHistory(stored, runtime(stream).root.position(), authority.guard());
                    self.last_rows = progress.expired_rows;
                    return progress.expired_rows != 0;
                },
                .expire => {
                    if (kind == .queue) {
                        if (runtime(stream).root.queue.?.active == 0) return false;
                        return stream.expireOne(stored, authority.guard());
                    }
                    if (runtime(stream).root.compaction != null) return false;
                    _ = try stream.expireHistory(stored, runtime(stream).root.position(), authority.guard());
                    return runtime(stream).root.next_lsn != before;
                },
            }
        }

        fn hasCandidateWork(
            allocator: std.mem.Allocator,
            log: c.storage.TransitLog.Log,
            initial: c.storage.LogInitialization.Request,
            stored: c.storage.LogDeclaration.Stored,
            selected: Class,
            options: c.DirectTransactionLog.Options,
        ) !bool {
            const tail = try log.tail(initial.partition);
            if (tail <= 1) return false;
            var latest = log.read(allocator, initial.partition, tail - 1, 1) catch |err| switch (err) {
                error.OutOfMemory => return err,
                else => return true,
            };
            defer latest.deinit();
            if (latest.frames.len != 1) return true;
            var scratch: std.heap.ArenaAllocator = .init(allocator);
            defer scratch.deinit();
            const decoded = c.storage.LogPartitionRecord.decode(scratch.allocator(), latest.frames[0], initial.partition, tail - 1) catch |err| switch (err) {
                error.OutOfMemory => return err,
                else => return true,
            };
            const root = decoded.record.root;
            if (!std.meta.eql(root.initialization, initial)) return true;
            if (root.transaction != null) return false;
            return switch (selected) {
                .flush => root.sealed_through != root.next_offset,
                .archive => root.maintenance.archive_target != null or root.maintenance.archive_source_lsn > root.maintenance.archived_source_lsn,
                .trim => root.archive.through != 0 and root.recovery != null,
                .checkpoint => blk: {
                    if (kind == .stream) break :blk false;
                    const checkpoint_lsn = if (root.recovery) |ref| ref.next_lsn else 0;
                    if (root.maintenance.archive_source_lsn <= checkpoint_lsn) break :blk false;
                    const floor: u64 = if (checkpoint_lsn == 0) 1 else checkpoint_lsn + 1;
                    const uncheckpointed: u64 = if (root.next_lsn > floor) root.next_lsn - floor else 1;
                    break :blk uncheckpointed >= options.queue.queue_checkpoint_soft_frames;
                },
                .compact => if (kind == .stream) blk: {
                    if (stored.retired) break :blk root.compaction != null or root.maintenance.rewrite_target != null;
                    break :blk root.compaction != null or
                        root.maintenance.rewrite_target != null or
                        root.maintenance.rewrite_source_lsn > root.maintenance.rewritten_source_lsn or
                        root.maintenance.compaction_source_lsn > root.maintenance.compacted_through_lsn;
                } else blk: {
                    const q_root = root.queue orelse break :blk true;
                    const basis = c.storage.QueueIndex.timerBasis(q_root);
                    const eligible = c.storage.QueueSchedule.needsMaintenance(q_root.eligible, basis) catch break :blk true;
                    if (eligible) break :blk true;
                    break :blk c.storage.QueueSchedule.needsMaintenance(q_root.deadlines, basis) catch true;
                },
                .expire => if (kind == .queue)
                    (if (root.queue) |q_root| q_root.active != 0 else true)
                else
                    root.compaction == null and root.retained_from < root.sealed_through,
                .retention => if (kind == .queue) root.retained_from < root.sealed_through else false,
            };
        }
    };
}
