//! Replay QueueLeaseTransaction.tla traces and negative controls against
//! Tack, QueuePartition, LogTransaction, DirectCatalog, and DirectStorageGraph.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const s = c.storage;
const f = c.fuze;
const a = c.TableAuthority;
const D = c.DirectCatalog;
const P = s.TablePartition;
const Q = s.QueuePartition;
const q = p.StreamQueue;

const Event = enum {
    Init,
    ClaimOffset1,
    ClaimOffset2,
    ClaimOffset3,
    AckOffset2,
    AckOffset3,
    Tick,
    TickDeadline,
    ExpireLease1,
    ReclaimOffset1,
    PublishDlq,
    ArchiveDlq,
    PrepareTurn,
    PrepareTurnDeadline,
    Revoke,
    CommitThreePrimitiveTurn,
    AbortTurn,
    RecoverDecision,
    Restart,
    LoadAccepted,
    StaleWorkerAck,
    CorruptTackBitmap,
    ReleaseHistory,
    ReclaimSegment,
};

const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
const profile: a.Profile = .{
    .database_domain = 1,
    .schema_domain = 2,
    .table_domain = 3,
    .stream_domain = 31,
    .queue_domain = 32,
    .kv_domain = 33,
    .connection_domain = 34,
    .source_domain = 35,
    .sink_domain = 36,
    .database = 4,
    .initial_schema = 1,
    .initial_schema_authority = 5,
};
const table_columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
const stream_columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "seq", .type = .int64, .nullable = false }};
const queue_columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "entity", .type = .utf8, .nullable = false },
    .{ .id = 2, .name = "seq", .type = .int64, .nullable = false },
};
const queue_options: Q.Options = .{
    .resident_pages = 4,
    .batch_bytes = 8192,
    .key_bytes = 256,
    .tail = .{ .slots = 1, .borrow_slots = 2, .slot_bytes = 8192, .resident_bytes = 16384 },
};

const Clock = struct {
    now_ms: u64 = 990,
    fn source(self: *Clock) s.LogTime.Source {
        return .{ .context = self, .read = sample };
    }
    fn sample(raw: *anyopaque) !?s.LogTime.Sample {
        const self: *Clock = @ptrCast(@alignCast(raw));
        return .exact(self.now_ms);
    }
};

const Access = struct {
    allowed: bool = true,
    const Context = struct { access: *Access };

    fn erased(context: *anyopaque) *Access {
        return @ptrCast(@alignCast(context));
    }
    fn make(context: *anyopaque, allocator: std.mem.Allocator, requested: p.Authorization.Guard, prerequisite: ?p.Authorization.Guard) !P.Guard {
        if (prerequisite != null) return error.CatalogDenied;
        try requested.validate();
        const result = try allocator.create(Context);
        result.* = .{ .access = erased(context) };
        return .{ .context = result, .acquire = acquire, .release = release };
    }
    fn acquire(context: *anyopaque) !P.Guard.Fence {
        const value: *Context = @ptrCast(@alignCast(context));
        if (!value.access.allowed) return error.CatalogDenied;
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn permitGuard() s.PublicationGuard {
        const Holder = struct {
            fn acq(_: *anyopaque) !s.PublicationGuard.Fence {
                return .{ .writer_epoch = 1, .policy_epoch = 1 };
            }
            fn rel(_: *anyopaque) void {}
        };
        var dummy: u8 = 0;
        return .{ .context = @ptrCast(&dummy), .acquire = Holder.acq, .release = Holder.rel };
    }
    fn guard(self: *Access) s.PublicationGuard {
        return .{ .context = self, .acquire = guardAcquire, .release = release };
    }
    fn guardAcquire(raw: *anyopaque) !s.PublicationGuard.Fence {
        const self: *Access = @ptrCast(@alignCast(raw));
        if (!self.allowed) return error.CatalogDenied;
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn registered(_: *anyopaque, kind: a.Kind, id: u64) !?p.Authorization.Object {
        const native: u64 = switch (kind) {
            .database => profile.database,
            .schema => if (id == 1) profile.initial_schema_authority else 20000 + id,
            .table, .stream, .queue => 100 + id,
            .kv, .connection, .source, .sink => return null,
        };
        return .{
            .reference = a.reference(native),
            .owner = 0,
            .registrar = 1,
            .actions = a.actions(kind),
            .domain = profile.domain(kind),
            .binding = try a.binding(scope, kind, id),
            .parent = switch (kind) {
                .database => null,
                .schema => a.reference(profile.database),
                .table, .stream, .queue => a.reference(profile.initial_schema_authority),
                .kv, .connection, .source, .sink => return null,
            },
            .revision = 1,
        };
    }
    fn policy(self: *Access) D.Policy {
        return .{
            .context = self,
            .subject = .{ .accepted = .{ .pid = 3, .input = 1, .principal = 1 } },
            .make_guard = make,
            .registered = registered,
        };
    }
};

const CollectorWorkspace = struct {
    allocator: std.mem.Allocator,
    jobs: std.ArrayListUnmanaged(c.DirectStorageGraph.Work) = .empty,
    seen: std.AutoHashMapUnmanaged([32]u8, void) = .empty,
    marks: std.StringHashMapUnmanaged(void) = .empty,

    fn deinit(self: *CollectorWorkspace) void {
        self.seen.deinit(self.allocator);
        var mark_it = self.marks.keyIterator();
        while (mark_it.next()) |key| self.allocator.free(key.*);
        self.marks.deinit(self.allocator);
        self.jobs.deinit(self.allocator);
    }
    pub fn enqueue(self: *CollectorWorkspace, job: c.DirectStorageGraph.Work) !void {
        try self.jobs.append(self.allocator, job);
    }
    pub fn visited(self: *CollectorWorkspace, key: [32]u8) !bool {
        if (self.seen.contains(key)) return true;
        try self.seen.put(self.allocator, key, {});
        return false;
    }
    pub fn mark(self: *CollectorWorkspace, key: []const u8, _: s.TransitObjectStore.ObjectMeta) !void {
        if (self.marks.contains(key)) return;
        try self.marks.put(self.allocator, try self.allocator.dupe(u8, key), {});
    }
};

fn op(id: u64) p.DataLifecycle.Operation {
    return .{ .scope = scope, .principal = 1, .operation = id };
}

fn configuration() !D.Configuration {
    return .{
        .scope = scope,
        .branch = 1,
        .partition = 1,
        .audience = 3,
        .authority = profile,
        .database_name = try a.Name.init("main"),
        .initial_schema_name = try a.Name.init("public"),
    };
}

fn openCatalog(allocator: std.mem.Allocator, wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore, environment: *const c.DirectTransactionLog.Environment) !D {
    const options: D.Options = .{ .resident_pages = 4, .table = .{ .resident_pages = 4 } };
    var catalog = try D.init(allocator, try configuration(), wal.log(), objects.objectStore(), wal.log(), objects.objectStore(), options);
    errdefer catalog.deinit();
    catalog.log_environment = environment;
    try catalog.recover();
    return catalog;
}

fn createTable(allocator: std.mem.Allocator, catalog: *D, access: *Access) !void {
    const schema: f.TableSchema.Schema = .{ .object = 10, .revision = 1, .next_column = 2, .columns = &table_columns, .primary_key = &.{1} };
    const intent: D.Intent = .{ .kind = .table, .namespace = 1, .name = try a.Name.init("ledger"), .action = .{ .create = .{ .schema = schema, .owner = 0 } } };
    const req: D.Request = .{
        .binding = .{
            .definition = p.Growth.current_definition,
            .identity = op(10),
            .target = .{ .scope = scope, .branch = 1, .object = 10 },
            .action = .create,
            .expected_definition = null,
            .expected_data = null,
            .intent = try intent.digest(allocator),
        },
        .intent = intent,
    };
    _ = try catalog.admit(req, access.policy());
    _ = try catalog.perform(req.binding, access.policy());
    _ = try catalog.settle(req.binding, access.policy());
}

fn createStream(allocator: std.mem.Allocator, catalog: *D, access: *Access) !c.DirectLog.Definition {
    const schema: f.TableSchema.Schema = .{ .object = 20, .revision = 1, .next_column = 2, .columns = &stream_columns, .primary_key = &.{} };
    const intent: c.DirectLog.Intent = .{ .kind = .stream, .namespace = 1, .name = try a.Name.init("outbox"), .action = .{ .create = .{
        .owner = 0,
        .schema = schema,
        .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } },
        .limits = .{ .append_rows = 64, .append_bytes = 65536, .claim_rows = 16, .read_rows = 64, .read_bytes = 65536, .active_leases = 64, .waiters = 16, .timer_steps = 64 },
    } } };
    const req: c.DirectLog.Request = .{
        .binding = .{
            .definition = p.Growth.current_definition,
            .identity = op(20),
            .target = .{ .scope = scope, .branch = 1, .object = 20 },
            .action = .create,
            .expected_definition = null,
            .expected_data = null,
            .intent = try intent.digest(allocator),
        },
        .intent = intent,
    };
    _ = try catalog.admitLog(req, access.policy());
    for (0..8) |_| {
        const progressed = try catalog.logOperation(req.binding, .execute, access.policy());
        if (progressed.operation.phase == .complete) break;
    } else return error.IncompleteSetup;
    return (try catalog.resolveLog(1, try a.Name.init("outbox"), access.policy())).?;
}

fn createQueue(allocator: std.mem.Allocator, catalog: *D, access: *Access, object_id: u64, op_id: u64, name: []const u8, key_fifo: bool, dead_letter: ?p.DataLifecycle.Definition) !c.DirectLog.Definition {
    const schema: f.TableSchema.Schema = .{ .object = object_id, .revision = 1, .next_column = 3, .columns = &queue_columns, .primary_key = &.{} };
    const intent: c.DirectLog.Intent = .{ .kind = .queue, .namespace = 1, .name = try a.Name.init(name), .action = .{ .create = .{
        .owner = 0,
        .schema = schema,
        .configuration = .{
            .partitioning = .{ .count = 1, .key_column = if (key_fifo) 1 else null, .hash = .sha256_64 },
            .retention = .{ .max_age_ms = 5 },
            .policy = .{ .queue = .{
                .ordering = if (key_fifo) .key_fifo else .unordered,
                .key_column = if (key_fifo) 1 else null,
                .lease_ms = 100,
                .maximum_lease_ms = 100,
                .maximum_attempts = 2,
                .backoff = .{ .initial_ms = 0, .maximum_ms = 0, .multiplier = 1 },
                .dead_letter = dead_letter,
            } },
        },
        .limits = .{ .append_rows = 64, .append_bytes = 65536, .claim_rows = 16, .read_rows = 64, .read_bytes = 65536, .active_leases = 64, .waiters = 16, .timer_steps = 64 },
    } } };
    const req: c.DirectLog.Request = .{
        .binding = .{
            .definition = p.Growth.current_definition,
            .identity = op(op_id),
            .target = .{ .scope = scope, .branch = 1, .object = object_id },
            .action = .create,
            .expected_definition = null,
            .expected_data = null,
            .intent = try intent.digest(allocator),
        },
        .intent = intent,
    };
    _ = try catalog.admitLog(req, access.policy());
    for (0..8) |_| {
        const progressed = try catalog.logOperation(req.binding, .execute, access.policy());
        if (progressed.operation.phase == .complete) break;
    } else return error.IncompleteSetup;
    return (try catalog.resolveLog(1, try a.Name.init(name), access.policy())).?;
}

fn openWorkQueue(allocator: std.mem.Allocator, wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore, definition: c.DirectLog.Definition, clock: *Clock, access: *Access) !Q {
    var configured = queue_options;
    configured.clock = clock.source();
    const initial = try definition.genesis(0);
    var owner = try Q.open(allocator, wal.log(), objects.objectStore(), initial, access.guard(), configured);
    errdefer owner.deinit() catch {};
    while (!(try owner.recoverStep(access.guard(), 256)).complete) {}
    return owner;
}

fn predicateClaim(allocator: std.mem.Allocator, schema: f.TableSchema.Schema, target: q.Partition, id: u64, sql: []const u8) !q.Claim {
    var prepared = try f.LogClaimSql.Prepared.init(allocator, sql, schema, .transit, null);
    defer prepared.deinit();
    var bound = try prepared.bind(allocator, &.{}, null);
    defer bound.deinit();
    return .{
        .target = target,
        .operation = op(id),
        .maximum = 1,
        .lease_ms = 100,
        .predicate = try f.QueuePredicate.encode(allocator, target, schema, bound.fields, bound.plan.plan),
    };
}

fn selectedLease(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore, receipt: q.ClaimReceipt) !q.Lease {
    var buffer: [s.QueueSelection.max_bytes]u8 = undefined;
    const selected = try s.QueueSelection.load(allocator, objects, receipt.leases.?, &buffer);
    try selected.requireReceipt(receipt);
    return selected.lease(0);
}

fn firstSegmentKey(owner: *Q, out: *[96]u8) ![]const u8 {
    const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &owner.owner.store };
    const entry = (try tree.get(owner.owner.root.segments, try s.LogPartitionRecord.integerKey(2))) orelse return error.MissingSegment;
    const descriptor = try s.LogSegment.Descriptor.decode(entry);
    return s.LogSegment.segmentKey(descriptor.segment.?, out);
}

fn sweepUnmarkedDataObjects(allocator: std.mem.Allocator, catalog: *D, wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore) !void {
    try catalog.recover();
    var workspace: CollectorWorkspace = .{ .allocator = allocator };
    defer workspace.deinit();
    const log = wal.log();
    const cat_tail = try log.tail(1);
    var cat_batch = try log.read(allocator, 1, cat_tail - 1, 1);
    defer cat_batch.deinit();
    try workspace.enqueue(try c.DirectStorageGraph.fromFrame(allocator, cat_batch.frames[0]));
    var at: usize = 0;
    while (at < workspace.jobs.items.len) : (at += 1) {
        var current = workspace.jobs.items[at];
        while (!(try c.DirectStorageGraph.step(allocator, &catalog.store.index, log, &current, &workspace))) {}
    }
    var to_delete: std.ArrayListUnmanaged([]u8) = .empty;
    defer {
        for (to_delete.items) |k| allocator.free(k);
        to_delete.deinit(allocator);
    }
    for (objects.objects.items) |entry| {
        if (!std.mem.startsWith(u8, entry.key, "log-segments/")) continue;
        if (!workspace.marks.contains(entry.key)) {
            try to_delete.append(allocator, try allocator.dupe(u8, entry.key));
        }
    }
    for (to_delete.items) |k| {
        try objects.objectStore().delete(k);
    }
}

const OffsetSnapshot = struct {
    state: []const u8,
    epoch: u64,
    item: s.QueueItem,
};

fn inspectOffset(owner: *Q, offset: u64) !OffsetSnapshot {
    if (offset < owner.owner.root.retained_from) {
        return .{ .state = "acked", .epoch = 0, .item = try s.QueueItem.initial(offset, offset + 1, 0) };
    }
    var bitmap: s.BitmapDirectory = .{ .store = &owner.owner.store, .objects = owner.owner.objects };
    const idx: s.QueueIndex = .{
        .store = &owner.owner.store,
        .scratch = &owner.owner.scratch,
        .bitmap = &bitmap,
        .container = &owner.owner.queue_container,
        .key_buffer = owner.owner.key_buffer,
        .timer_workspace = owner.owner.queue_timers,
        .timer_seed = owner.owner.root.initialization.target(),
        .timer_read_work = owner.owner.options.queue_timer_read_work,
    };
    const qroot = owner.owner.root.queue.?;
    const item = try idx.item(qroot, offset);
    const state = try idx.state(qroot, item);
    const label: []const u8 = switch (state) {
        .available => if (item.blocked == .dead_letter) "blocked" else "available",
        .acquired => "acquired",
        .acked => "acked",
        .archived => "archived",
    };
    return .{ .state = label, .epoch = item.epoch, .item = item };
}

fn expectedError(err: anyerror) ![]const u8 {
    return switch (err) {
        error.QueueSidecarOverlap,
        error.QueueLeaseFenced,
        error.QueueLeaseExpired,
        error.CatalogDenied,
        error.TransactionDeadlineElapsed,
        error.ClientOperationMissing,
        error.FIFOKeyBlocked,
        error.QueueTerminalSegmentPinned,
        => @errorName(err),
        else => return err,
    };
}

fn replay(allocator: std.mem.Allocator, events: []const Event, out: *std.Io.Writer) !void {
    var wal = s.LocalWal.LocalWal.initMemory(allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(allocator);
    defer objects.deinit();
    var clock: Clock = .{ .now_ms = 990 };
    const environment: c.DirectTransactionLog.Environment = .{
        .clock = clock.source(),
        .authority = try s.LogRead.Authority.init(@splat(4)),
    };
    var access: Access = .{};
    var catalog: ?D = try openCatalog(allocator, &wal, &objects, &environment);
    defer if (catalog) |*cat| cat.deinit();

    try catalog.?.initialize(access.policy());
    try createTable(allocator, &catalog.?, &access);
    const outbox_def = try createStream(allocator, &catalog.?, &access);
    const dlq_def = try createQueue(allocator, &catalog.?, &access, 30, 30, "dlq", false, null);
    const work_def = try createQueue(allocator, &catalog.?, &access, 40, 40, "work", true, dlq_def.stored.declaration.interpretation);
    const work_schema: f.TableSchema.Schema = .{ .object = 40, .revision = 1, .next_column = 3, .columns = &queue_columns, .primary_key = &.{} };
    const work_target: q.Partition = .{ .definition = p.Growth.current_definition, .interpretation = work_def.stored.declaration.interpretation, .partition = 0 };
    const outbox_target: q.Partition = .{ .definition = p.Growth.current_definition, .interpretation = outbox_def.stored.declaration.interpretation, .partition = 0 };
    const dlq_target: q.Partition = .{ .definition = p.Growth.current_definition, .interpretation = dlq_def.stored.declaration.interpretation, .partition = 0 };

    var work_owner: ?Q = try openWorkQueue(allocator, &wal, &objects, work_def, &clock, &access);
    defer if (work_owner) |*owner| owner.deinit() catch {};

    // Enqueue Segment 1 = {offset 0 ("k1", 1), offset 1 ("k1", 2)} and flush to .tseg,
    // then Segment 2 = {offset 2 ("k2", 3)} and flush to a second .tseg.
    var encode_buf: [8192]u8 = undefined;
    {
        var enc1 = try s.LogBatch.Encoder.init(work_schema, op(100), .queue, 2, &encode_buf);
        try enc1.append(.{ .cells = &.{ .{ .value = .{ .atom = .{ .bytes = "k1" } } }, .{ .value = .{ .atom = .{ .signed = 1 } } } } });
        try enc1.append(.{ .cells = &.{ .{ .value = .{ .atom = .{ .bytes = "k1" } } }, .{ .value = .{ .atom = .{ .signed = 2 } } } } });
        const payload1 = try enc1.finish();
        _ = try work_owner.?.enqueue(work_def.stored, .{ .target = work_target, .operation = op(100), .kind = .queue, .producer = null, .rows = 2, .payload = s.LogBatch.content(payload1) }, payload1, access.guard());
        const cut1 = work_owner.?.owner.root.position();
        while (!(try work_owner.?.flush(cut1, access.guard())).complete) {}

        var enc2 = try s.LogBatch.Encoder.init(work_schema, op(101), .queue, 1, &encode_buf);
        try enc2.append(.{ .cells = &.{ .{ .value = .{ .atom = .{ .bytes = "k2" } } }, .{ .value = .{ .atom = .{ .signed = 3 } } } } });
        const payload2 = try enc2.finish();
        _ = try work_owner.?.enqueue(work_def.stored, .{ .target = work_target, .operation = op(101), .kind = .queue, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload2) }, payload2, access.guard());
        const cut2 = work_owner.?.owner.root.position();
        while (!(try work_owner.?.flush(cut2, access.guard())).complete) {}
        _ = try work_owner.?.checkpoint(work_owner.?.owner.root.position(), access.guard());
    }
    var seg_key_buf: [96]u8 = undefined;
    const seg_key = try firstSegmentKey(&work_owner.?, &seg_key_buf);
    clock.now_ms = 1000;

    var next_op: u64 = 200;
    var worker_a_lease: ?q.Lease = null;
    var current_lease1: ?q.Lease = null;
    var lease2: ?q.Lease = null;
    var lease3: ?q.Lease = null;
    var held_claims: [4]?q.ClaimReceipt = .{ null, null, null, null };
    var held_count: usize = 0;
    var tx_key: ?c.DirectClientToken.Key = null;
    var tx_commit_op: ?p.DataLifecycle.Operation = null;
    var dlq_key: ?c.DirectClientToken.Key = null;
    var history_held = true;
    var last_error: []const u8 = "none";
    var decision_state: []const u8 = "none";
    // Control check: did prepareTurn keep uncommitted Table/Stream writes invisible?
    var uncommitted_isolated = true;

    for (events) |event| {
        last_error = "none";
        switch (event) {
            .Init => {},
            .ClaimOffset1 => {
                const claim_req = try predicateClaim(allocator, work_schema, work_target, next_op, "CLAIM * FROM work WHERE seq = 1 WITH LEASE '100ms'");
                next_op += 1;
                const receipt = try work_owner.?.claim(work_def.stored, claim_req, access.guard());
                if (receipt.rows != 1) return error.UnexpectedClaimCount;
                const lease = try selectedLease(allocator, work_owner.?.owner.objects, receipt);
                worker_a_lease = lease;
                current_lease1 = lease;
                held_claims[held_count] = receipt;
                held_count += 1;
            },
            .ClaimOffset2 => {
                const claim_req = try predicateClaim(allocator, work_schema, work_target, next_op, "CLAIM * FROM work WHERE seq = 2 WITH LEASE '100ms'");
                next_op += 1;
                const receipt = try work_owner.?.claim(work_def.stored, claim_req, access.guard());
                if (receipt.rows == 0) {
                    last_error = try expectedError(error.FIFOKeyBlocked);
                } else {
                    lease2 = try selectedLease(allocator, work_owner.?.owner.objects, receipt);
                    held_claims[held_count] = receipt;
                    held_count += 1;
                }
            },
            .ClaimOffset3 => {
                const claim_req = try predicateClaim(allocator, work_schema, work_target, next_op, "CLAIM * FROM work WHERE seq = 3 WITH LEASE '100ms'");
                next_op += 1;
                const receipt = try work_owner.?.claim(work_def.stored, claim_req, access.guard());
                if (receipt.rows != 1) return error.UnexpectedClaimCount;
                lease3 = try selectedLease(allocator, work_owner.?.owner.objects, receipt);
                held_claims[held_count] = receipt;
                held_count += 1;
            },
            .AckOffset2 => {
                _ = try work_owner.?.settle(work_def.stored, .{ .operation = op(next_op), .lease = lease2.?, .action = .ack }, access.guard());
                next_op += 1;
            },
            .AckOffset3 => {
                _ = try work_owner.?.settle(work_def.stored, .{ .operation = op(next_op), .lease = lease3.?, .action = .ack }, access.guard());
                next_op += 1;
            },
            .Tick => {
                clock.now_ms += 100;
            },
            .TickDeadline => {
                clock.now_ms = 1050;
            },
            .ExpireLease1 => {
                if (!(try work_owner.?.expireOne(work_def.stored, access.guard()))) return error.ExpectedExpiredLease;
                current_lease1 = null;
            },
            .ReclaimOffset1 => {
                const claim_req = try predicateClaim(allocator, work_schema, work_target, next_op, "CLAIM * FROM work WHERE seq = 1 WITH LEASE '100ms'");
                next_op += 1;
                const receipt = try work_owner.?.claim(work_def.stored, claim_req, access.guard());
                if (receipt.rows != 1) return error.UnexpectedClaimCount;
                current_lease1 = try selectedLease(allocator, work_owner.?.owner.objects, receipt);
                held_claims[held_count] = receipt;
                held_count += 1;
            },
            .StaleWorkerAck => {
                if (work_owner.?.settle(work_def.stored, .{ .operation = op(next_op), .lease = worker_a_lease.?, .action = .ack }, access.guard())) |_| {
                    return error.StaleWorkerAckAccepted;
                } else |err| {
                    last_error = try expectedError(err);
                }
                next_op += 1;
            },
            .CorruptTackBitmap => {
                var bitmap: s.BitmapDirectory = .{ .store = &work_owner.?.owner.store, .objects = work_owner.?.owner.objects };
                const idx: s.QueueIndex = .{
                    .store = &work_owner.?.owner.store,
                    .scratch = &work_owner.?.owner.scratch,
                    .bitmap = &bitmap,
                    .container = &work_owner.?.owner.queue_container,
                    .key_buffer = work_owner.?.owner.key_buffer,
                    .timer_workspace = work_owner.?.owner.queue_timers,
                    .timer_seed = work_owner.?.owner.root.initialization.target(),
                    .timer_read_work = work_owner.?.owner.options.queue_timer_read_work,
                };
                const qroot = work_owner.?.owner.root.queue.?;
                const item0 = try idx.item(qroot, 0);
                var bad = try idx.sidecar(qroot, item0);
                bad.states[@backingInt(s.Tack.State.acked)] = bad.states[@backingInt(s.Tack.State.acquired)];
                if (bad.validate()) |_| return error.UnbalancedTackAccepted else |err| {
                    if (err != error.InvalidQueueSidecar) return err;
                }
                // Even if total cardinality is forged to match segment width, Audit.page catches overlap.
                bad.states[@backingInt(s.Tack.State.available)] = .empty;
                var audit = try s.Tack.Audit.init(bad);
                const runAudit = struct {
                    fn check(a_ptr: *s.Tack.Audit, dir: *s.BitmapDirectory, container: *s.BitmapDirectory.Container) !void {
                        while (!(try a_ptr.page(dir, container))) {}
                    }
                }.check;
                if (runAudit(&audit, &bitmap, &work_owner.?.owner.queue_container)) |_| {
                    return error.OverlappingTackAccepted;
                } else |err| {
                    last_error = try expectedError(err);
                }
            },
            .PrepareTurn, .PrepareTurnDeadline => {
                // Flush candidate objects to shared store before DirectCatalog pins the Queue participant.
                _ = try work_owner.?.checkpoint(work_owner.?.owner.root.position(), access.guard());
                work_owner.?.deinit() catch {};
                work_owner = null;

                const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
                const key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(9), .token = @splat(1) };
                const targets = [_]p.Transaction.Target{
                    .{ .object = .{ .scope = scope, .branch = 1, .object = 10 }, .kind = .table, .partition = null },
                    .{ .object = outbox_target.interpretation.object, .kind = .stream, .partition = 0 },
                    .{ .object = work_target.interpretation.object, .kind = .queue, .partition = 0 },
                };
                const deadline: ?p.Transaction.Deadline = if (event == .PrepareTurnDeadline) .{ .floor_ms = 990, .expires_ms = 1050 } else null;
                _ = try catalog.?.beginTransaction(.{
                    .key = key,
                    .fingerprint = @splat(11),
                    .operation = op(next_op),
                    .namespace = 1,
                    .mode = .serializable,
                    .deadline = deadline,
                    .execution = null,
                    .selection = .{ .explicit_objects = &targets },
                    .limits = .{ .resident_bytes = 16 * 1024 * 1024, .workspace_bytes = 1024 * 1024, .participants = 8, .statements = 16, .savepoints = 4 },
                    .budget = .{ .bytes = 256 * 1024 },
                }, access.policy());
                next_op += 1;
                _ = try catalog.?.acquireTransaction(key, access.policy());

                // 1. Stage + execute Table insert.
                {
                    var view = (try catalog.?.resolve(allocator, 1, try a.Name.init("ledger"), access.policy())).?;
                    defer view.deinit();
                    const status = try catalog.?.inspectTransaction(key, access.policy());
                    const binding: p.DataLifecycle.Binding = .{
                        .definition = p.Growth.current_definition,
                        .identity = op(next_op),
                        .target = view.table.root.interpretation.object,
                        .action = .insert,
                        .expected_definition = view.table.root.interpretation,
                        .expected_data = null,
                        .intent = @splat(21),
                    };
                    next_op += 1;
                    const cells = [_]f.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 1 } } }};
                    const dml: s.TableDmlIntent.Request = .{
                        .binding = binding,
                        .interpretation = view.table.root.declared(),
                        .changes = &.{.{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(binding.identity, 0), .cells = &cells }, .expect = .absent } }},
                        .ingestion = .bulk,
                    };
                    const stmt: c.DirectTransactionWorkspace.Request = .{
                        .basis = status.revision,
                        .statement = .{ .transaction = status.begin.identity, .sequence = 1, .intent = binding.intent },
                        .binding = binding,
                        .intent = try s.TableDmlIntent.stage(allocator, catalog.?.data_objects, dml),
                    };
                    _ = try catalog.?.admitTransactionStatement(key, stmt, access.policy());
                    _ = try catalog.?.executeTransactionStatement(key, stmt, access.policy());
                }

                // 2. Stage + execute Queue ACK on offset 0.
                {
                    const status = try catalog.?.inspectTransaction(key, access.policy());
                    const ack_req = try catalog.?.stageTransactionLog(
                        key,
                        status.revision,
                        2,
                        .{ .queue_ack = .{ .operation = op(next_op), .lease = current_lease1.?, .action = .ack } },
                        null,
                        access.policy(),
                    );
                    next_op += 1;
                    _ = try catalog.?.executeTransactionLog(key, ack_req, access.policy());
                }

                // 3. Stage + execute outbox Stream append.
                {
                    const status = try catalog.?.inspectTransaction(key, access.policy());
                    const append_op = op(next_op);
                    next_op += 1;
                    const cells = [_]f.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 1 } } }};
                    const stream_schema: f.TableSchema.Schema = .{ .object = 20, .revision = 1, .next_column = 2, .columns = &stream_columns, .primary_key = &.{} };
                    const bytes = try s.LogBatch.encode(stream_schema, append_op, .stream, &.{.{ .cells = &cells }}, &encode_buf);
                    const outbox_req = try catalog.?.stageTransactionLog(
                        key,
                        status.revision,
                        3,
                        .{ .append = .{ .target = outbox_target, .operation = append_op, .kind = .stream, .producer = null, .rows = 1, .payload = s.LogBatch.content(bytes) } },
                        bytes,
                        access.policy(),
                    );
                    _ = try catalog.?.executeTransactionLog(key, outbox_req, access.policy());
                }

                // Verify public Table & Stream remain completely isolated prior to CommitThreePrimitiveTurn.
                {
                    var view = (try catalog.?.resolve(allocator, 1, try a.Name.init("ledger"), access.policy())).?;
                    defer view.deinit();
                    var scratch: std.heap.ArenaAllocator = .init(allocator);
                    defer scratch.deinit();
                    var cached: ?c.DirectStream.Cached = null;
                    defer if (cached) |*value| value.deinit();
                    const stream_obs = try c.DirectStream.apply(scratch.allocator(), allocator, &catalog.?, &cached, .{ .resident_pages = 2, .batch_bytes = 8192, .key_bytes = 256, .tail = .{ .slots = 1, .borrow_slots = 2, .slot_bytes = 8192, .resident_bytes = 16384 } }, .{ .authority = environment.authority.?, .clock = clock.source() }, .{ .observe = outbox_target }, access.policy());
                    if (view.table.root.live_rows != 0 or stream_obs.cut.next != 0) uncommitted_isolated = false;
                }

                tx_key = key;
                tx_commit_op = op(next_op);
                next_op += 1;
                work_owner = try openWorkQueue(allocator, &wal, &objects, work_def, &clock, &access);
            },
            .Revoke => {
                access.allowed = false;
            },
            .CommitThreePrimitiveTurn => {
                if (work_owner) |*owner| {
                    if (owner.owner.root.transaction == null) {
                        const saved = access.allowed;
                        access.allowed = true;
                        _ = try owner.checkpoint(owner.owner.root.position(), access.guard());
                        access.allowed = saved;
                    }
                    owner.deinit() catch {};
                    work_owner = null;
                }
                if (catalog.?.settleTransaction(tx_key.?, tx_commit_op.?, .commit, 64, access.policy())) |status| {
                    if (status.observation == .decided and status.observation.decided.outcome == .committed) {
                        decision_state = "committed";
                        current_lease1 = null;
                    }
                } else |err| {
                    last_error = try expectedError(err);
                }
                const saved = access.allowed;
                access.allowed = true;
                work_owner = try openWorkQueue(allocator, &wal, &objects, work_def, &clock, &access);
                access.allowed = saved;
            },
            .AbortTurn => {
                if (work_owner) |*owner| {
                    if (owner.owner.root.transaction == null) {
                        const saved = access.allowed;
                        access.allowed = true;
                        _ = try owner.checkpoint(owner.owner.root.position(), access.guard());
                        access.allowed = saved;
                    }
                    owner.deinit() catch {};
                    work_owner = null;
                }
                const saved = access.allowed;
                access.allowed = true;
                const status = try catalog.?.settleTransaction(tx_key.?, tx_commit_op.?, .abort, 64, access.policy());
                if (status.observation == .decided and status.observation.decided.outcome == .aborted) {
                    decision_state = "aborted";
                }
                work_owner = try openWorkQueue(allocator, &wal, &objects, work_def, &clock, &access);
                access.allowed = saved;
            },
            .RecoverDecision => {
                const saved = access.allowed;
                access.allowed = true;
                const inspected = try catalog.?.inspectTransaction(tx_key.?, access.policy());
                access.allowed = saved;
                if (inspected.observation == .decided) {
                    decision_state = if (inspected.observation.decided.outcome == .committed) "committed" else "aborted";
                }
            },
            .Restart => {
                if (work_owner) |*owner| {
                    owner.deinit() catch {};
                    work_owner = null;
                }
                if (catalog) |*cat| {
                    cat.deinit();
                    catalog = null;
                }
            },
            .LoadAccepted => {
                const saved = access.allowed;
                access.allowed = true;
                catalog = try openCatalog(allocator, &wal, &objects, &environment);
                work_owner = try openWorkQueue(allocator, &wal, &objects, work_def, &clock, &access);
                access.allowed = saved;
            },
            .PublishDlq => {
                if (!(try work_owner.?.expireOne(work_def.stored, access.guard()))) return error.ExpectedExhaustedLease;
                current_lease1 = null;
                const snap0 = try inspectOffset(&work_owner.?, 0);
                const dlq_enq_op = op(next_op);
                next_op += 1;
                const dlq_src_op = op(next_op);
                next_op += 1;
                const materialized = try work_owner.?.deadLetterWork(
                    work_def.stored,
                    .{
                        .source = .{
                            .target = work_target,
                            .offset = 0,
                            .lease_epoch = snap0.item.epoch,
                            .attempt = @intCast(snap0.item.attempts),
                            .not_before_ms = snap0.item.blocked_after_ms.?,
                        },
                        .destination = dlq_target.interpretation,
                    },
                    dlq_src_op,
                    dlq_target,
                    dlq_enq_op,
                    &encode_buf,
                    access.guard(),
                );
                _ = try work_owner.?.checkpoint(work_owner.?.owner.root.position(), access.guard());
                work_owner.?.deinit() catch {};
                work_owner = null;

                const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
                const key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(19), .token = @splat(2) };
                const begin_op = op(next_op);
                next_op += 1;
                const settle_op = op(next_op);
                next_op += 1;
                const plan: c.DirectQueueTransferPlan = .{
                    .definition = p.Growth.current_definition,
                    .key = key,
                    .namespace = 1,
                    .operation = begin_op,
                    .settlement = settle_op,
                    .transfer = materialized.request,
                    .limits = .{ .resident_bytes = 16 * 1024 * 1024, .workspace_bytes = 1024 * 1024, .participants = 2, .statements = 1, .savepoints = 1 },
                    .budget = .{ .bytes = 32 * 1024 },
                };
                _ = try catalog.?.admitQueueTransfer(plan, access.policy());
                dlq_key = key;
                work_owner = try openWorkQueue(allocator, &wal, &objects, work_def, &clock, &access);
            },
            .ArchiveDlq => {
                if (dlq_key) |key| {
                    _ = try work_owner.?.checkpoint(work_owner.?.owner.root.position(), access.guard());
                    work_owner.?.deinit() catch {};
                    work_owner = null;
                    for (0..32) |_| {
                        const status = try catalog.?.advanceQueueTransfer(key, 8, access.policy());
                        if (status.cleanup_complete) break;
                    } else return error.IncompleteDlqTransfer;
                    work_owner = try openWorkQueue(allocator, &wal, &objects, work_def, &clock, &access);
                } else {
                    // Counterexample path: lease exhausted without PublishDlq.
                    // Expiring moves offset 0 to .blocked (dead_letter), NEVER .archived,
                    // and advancing an unadmitted transfer fails closed.
                    _ = try work_owner.?.expireOne(work_def.stored, access.guard());
                    current_lease1 = null;
                    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
                    const missing_key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(19), .token = @splat(99) };
                    if (catalog.?.advanceQueueTransfer(missing_key, 8, access.policy())) |_| {
                        return error.UnpublishedDlqAccepted;
                    } else |err| {
                        last_error = try expectedError(err);
                    }
                }
            },
            .ReleaseHistory => {
                const saved = access.allowed;
                access.allowed = true;
                for (held_claims[0..held_count]) |maybe_claim| if (maybe_claim) |claim| {
                    _ = try work_owner.?.releaseClaimRead(work_def.stored, .{ .operation = op(next_op), .claim = claim }, access.guard());
                    next_op += 1;
                };
                access.allowed = saved;
                history_held = false;
            },
            .ReclaimSegment => {
                const saved = access.allowed;
                access.allowed = true;
                if (work_owner == null) {
                    work_owner = try openWorkQueue(allocator, &wal, &objects, work_def, &clock, &access);
                }
                if (catalog == null) {
                    catalog = try openCatalog(allocator, &wal, &objects, &environment);
                }
                const cut = work_owner.?.owner.root.position();
                const exp = try work_owner.?.expireTerminalHistory(work_def.stored, cut, access.guard());
                _ = try work_owner.?.checkpoint(work_owner.?.owner.root.position(), access.guard());
                try sweepUnmarkedDataObjects(allocator, &catalog.?, &wal, &objects);
                if (exp.expired_rows > 0 and try objects.objectStore().head(seg_key) != null) {
                    last_error = try expectedError(error.QueueTerminalSegmentPinned);
                }
                access.allowed = saved;
            },
        }
    }

    // Reopen read-only observers if trace ended in Restart (!resident) so we can project durable accepted state.
    const resident_at_end = work_owner != null and catalog != null;
    const saved_allowed = access.allowed;
    access.allowed = true;
    var inspect_cat = if (catalog == null) try openCatalog(allocator, &wal, &objects, &environment) else null;
    defer if (inspect_cat) |*cat| cat.deinit();
    const cat_ref: *D = if (catalog) |*cat| cat else &inspect_cat.?;

    var inspect_work = if (work_owner == null) try openWorkQueue(allocator, &wal, &objects, work_def, &clock, &access) else null;
    defer if (inspect_work) |*owner| owner.deinit() catch {};
    const work_ref: *Q = if (work_owner) |*owner| owner else &inspect_work.?;

    const table_rows: u64 = blk: {
        if (cat_ref.resolve(allocator, 1, try a.Name.init("ledger"), access.policy())) |maybe_view| {
            var view = maybe_view.?;
            defer view.deinit();
            break :blk view.table.root.live_rows;
        } else |err| {
            if (err == error.TransactionPrepared and std.mem.eql(u8, decision_state, "none")) break :blk 0;
            return err;
        }
    };
    var outbox_scratch: std.heap.ArenaAllocator = .init(allocator);
    defer outbox_scratch.deinit();
    var outbox_cached: ?c.DirectStream.Cached = null;
    defer if (outbox_cached) |*value| value.deinit();
    const outbox_next: u64 = blk: {
        if (c.DirectStream.apply(outbox_scratch.allocator(), allocator, cat_ref, &outbox_cached, .{ .resident_pages = 2, .batch_bytes = 8192, .key_bytes = 256, .tail = .{ .slots = 1, .borrow_slots = 2, .slot_bytes = 8192, .resident_bytes = 16384 } }, .{ .authority = environment.authority.?, .clock = clock.source() }, .{ .observe = outbox_target }, access.policy())) |obs| {
            break :blk obs.cut.next;
        } else |err| {
            if (err == error.TransactionPrepared and std.mem.eql(u8, decision_state, "none")) break :blk 0;
            return err;
        }
    };
    var dlq_owner = try openWorkQueue(allocator, &wal, &objects, dlq_def, &clock, &access);
    defer dlq_owner.deinit() catch {};

    const s0 = try inspectOffset(work_ref, 0);
    const s1 = try inspectOffset(work_ref, 1);
    const s2 = try inspectOffset(work_ref, 2);
    const segment_reclaimed = (try objects.objectStore().head(seg_key)) == null;
    access.allowed = saved_allowed;

    try out.print(
        "{{\"last_error\":\"{s}\",\"decision\":\"{s}\",\"table_rows\":{d},\"outbox_next\":{d},\"dlq_next\":{d},\"offset0_state\":\"{s}\",\"offset1_state\":\"{s}\",\"offset2_state\":\"{s}\",\"epoch\":{d},\"resident\":{},\"history_held\":{},\"segment_reclaimed\":{},\"uncommitted_isolated\":{}}}\n",
        .{
            last_error,
            decision_state,
            table_rows,
            outbox_next,
            dlq_owner.owner.root.next_offset,
            s0.state,
            s1.state,
            s2.state,
            s0.epoch,
            resident_at_end,
            history_held,
            segment_reclaimed,
            uncommitted_isolated,
        },
    );
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.InvalidArguments;
    const text = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(4 * 1024 * 1024));
    defer init.gpa.free(text);
    const parsed = try std.json.parseFromSlice([]const []const Event, init.gpa, text, .{});
    defer parsed.deinit();

    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &buffer);
    for (parsed.value) |events| try replay(init.gpa, events, &stdout.interface);
    try stdout.interface.flush();
}
