//! Shared native maintenance over two Queue partitions and existing Streams.
//! Accepted lease deadlines remain authoritative through clock uncertainty,
//! executor loss, tiering and physical WAL truncation.
const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const p = c.protocol;
const backend = @import("transit_backend_local");
const Service = @import("LocalTableService.zig");
const Host = @import("LocalTableHost.zig");
const Work = @import("LocalTableMaintenance.zig");
const Authority = @import("LocalMaintenanceAuthority.zig");
const Clock = struct {
    now: u64,
    fn read(raw: *anyopaque) !@import("transit_core").Time.Sample {
        return .{ .unix_ms = @as(*@This(), @ptrCast(@alignCast(raw))).now, .error_ms = 5 };
    }
};

pub fn exercise(service: *Service, declared: c.DirectLog.Definition, schema: c.fuze.TableSchema.Schema, policy: c.DirectCatalog.Policy) !void {
    const native = service.engine.journal.backend;
    var control: backend.DataStore = .{ .backend = native, .control = true };
    var data: backend.DataStore = .{ .backend = native };
    var catalog = try c.DirectCatalog.init(t.allocator, service.configuration, control.log(), control.objects(), data.log(), data.objects(), service.options);
    defer catalog.deinit();
    try catalog.recover();
    const initial = try declared.genesis(1);
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = declared.stored.declaration.interpretation, .partition = 1 };
    var clock: Clock = .{ .now = 2000 };
    const original_clock = service.engine.clock;
    defer service.engine.clock = original_clock;
    service.engine.clock = .{ .context = &clock, .read = Clock.read };
    var claimed: p.StreamQueue.ClaimReceipt = undefined;
    {
        var cached: ?c.DirectQueue.Cached = null;
        defer if (cached) |*value| value.deinit();
        var scratch: std.heap.ArenaAllocator = .init(t.allocator);
        defer scratch.deinit();
        var output: std.heap.ArenaAllocator = .init(t.allocator);
        defer output.deinit();
        const environment: c.DirectQueue.Environment = .{ .clock = @import("LocalLogClock.zig").source(service.engine) };
        const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 73 } } }};
        var buffer: [8192]u8 = undefined;
        for (0..40) |i| {
            _ = scratch.reset(.retain_capacity);
            _ = output.reset(.retain_capacity);
            const identity: p.DataLifecycle.Operation = .{ .scope = target.interpretation.object.scope, .principal = 101, .operation = 20000 + i };
            const payload = try c.storage.LogBatch.encode(schema, identity, .queue, &.{.{ .cells = &cells }}, &buffer);
            const work: c.DirectQueueMutation.Request = .{ .enqueue = .{ .target = target, .operation = identity, .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(payload) } };
            const result = try c.DirectQueue.apply(scratch.allocator(), output.allocator(), &catalog, &cached, .{}, environment, .{ .mutate = .{ .work = work, .payload = try c.DirectTableProtocol.Binary.encode(scratch.allocator(), payload) } }, policy);
            try t.expectEqual(@as(u64, i + 1), result.operation.?.enqueue.next);
        }
        const claim: p.StreamQueue.Claim = .{ .target = target, .operation = .{ .scope = target.interpretation.object.scope, .principal = 101, .operation = 20040 }, .maximum = 2, .lease_ms = 100, .predicate = null };
        claimed = (try c.DirectQueue.apply(scratch.allocator(), output.allocator(), &catalog, &cached, .{}, environment, .{ .mutate = .{ .work = .{ .claim = claim }, .payload = null } }, policy)).operation.?.claim;
        try t.expectEqual(@as(u32, 2), claimed.rows);
        try t.expectEqual(@as(u64, 2105), claimed.expires_ms);
        try t.expect(cached.?.owner.owner.root.next_lsn > 40 and cached.?.owner.owner.root.recovery == null);
    }
    var admission: @import("DirectStorageMemory.zig") = undefined;
    try admission.init(t.allocator, .{ .admission = .{ .data_bytes = 1024 * 1024, .control_bytes = 1024 * 1024 }, .maintenance = .{ .resident_bytes = 32 * 1024 * 1024 } });
    defer admission.deinit();
    const held_response = try admission.allocator(false).alloc(u8, admission.data.limit);
    defer admission.allocator(false).free(held_response);
    try t.expectError(error.OutOfMemory, admission.allocator(false).alloc(u8, 1));
    var host: Host = .{ .configuration = service.configuration, .registrar = service.registrar, .options = service.options, .recovery = try catalog.recoveryState(), .admission = &admission };
    defer host.deinit();
    var allocations: c.fuze.memory.AllocationProbe = .{ .parent = t.allocator };
    var work: Work = .{ .host = &host, .allocator = allocations.allocator(), .next_kind = .queue };
    defer work.deinit();
    const request: p.Growth.Request = .{ .realm = 42, .principal = 0, .sequence = (try service.engine.principal(0)).sequence + 1, .command = .checkpoint };
    const signed = try p.Growth.sign(request, service.registrar.key);
    var authority: Authority = .{ .engine = service.engine, .signed = signed, .resource = service.configuration.scope.resource };
    var settings: p.Storage.Maintenance = .{ .resident_bytes = 32 * 1024 * 1024, .flush = .{ .enabled = false }, .archive = .{ .enabled = false }, .compact = false };
    const tail = try data.log().tail(initial.partition);
    service.engine.clock = null;
    var refused = false;
    for (0..32) |_| {
        // Force Queue selection to isolate its clock requirement from Stream age.
        work.next_kind = .queue;
        _ = Work.step(&work, service.engine, settings, signed) catch |err| {
            try t.expectEqual(error.QueueTimeUnavailable, err);
            refused = true;
            break;
        };
    }
    try t.expect(refused);
    const after_refusal = try data.log().tail(initial.partition);
    var lsn = tail;
    while (lsn < after_refusal) : (lsn += 1) {
        var frames = try data.log().read(t.allocator, initial.partition, lsn, 1);
        defer frames.deinit();
        const recorded = try c.storage.LogPartitionRecord.decode(t.allocator, frames.frames[0], initial.partition, lsn);
        // Physical scheduling cleanup and standalone metadata checkpoints need
        // no clock and may precede refusal of an expiry unit. Neither settles
        // an accepted lease.
        try t.expect(recorded.record.action == .queue_schedule or recorded.record.action == .checkpoint);
    }
    try check(&data, initial, declared, claimed, authority.guard(), 2, false, false);
    // The upper bound has reached the deadline; the lower bound has not.
    // The older lease on partition zero can expire, but these two cannot.
    var peak: usize = work.last_peak_bytes;
    clock.now = 2105;
    service.engine.clock = .{ .context = &clock, .read = Clock.read };
    _ = try settle(&work, service, settings, signed, &allocations, false, &peak);
    try check(&data, initial, declared, claimed, authority.guard(), 2, true, false);
    clock.now = 2110;
    const limits = native.limits;
    native.limits.bytes = native.allocated; // Expiry and standalone Queue checkpoints use reserved control capacity.
    defer native.limits = limits;
    _ = try settle(&work, service, settings, signed, &allocations, false, &peak);
    try check(&data, initial, declared, claimed, authority.guard(), 0, true, false);
    native.limits = limits;
    // Verify QueueCheckpointBacklog transient backpressure and retry after standalone
    // checkpoint maintenance (archive.enabled == false), with zero memory leak.
    {
        var cached: ?c.DirectQueue.Cached = null;
        defer if (cached) |*value| value.deinit();
        var scratch: std.heap.ArenaAllocator = .init(t.allocator);
        defer scratch.deinit();
        var output: std.heap.ArenaAllocator = .init(t.allocator);
        defer output.deinit();
        const environment: c.DirectQueue.Environment = .{ .clock = @import("LocalLogClock.zig").source(service.engine) };
        const tight_options: c.storage.QueuePartition.Options = .{
            .queue_checkpoint_soft_frames = 1,
            .queue_checkpoint_hard_frames = 2,
            .queue_checkpoint_hard_mode = .refuse,
        };
        const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 91 } } }};
        var buffer: [8192]u8 = undefined;
        for (0..2) |step| {
            _ = scratch.reset(.retain_capacity);
            _ = output.reset(.retain_capacity);
            const identity: p.DataLifecycle.Operation = .{ .scope = target.interpretation.object.scope, .principal = 101, .operation = 29000 + step };
            const payload = try c.storage.LogBatch.encode(schema, identity, .queue, &.{.{ .cells = &cells }}, &buffer);
            const work_req: c.DirectQueueMutation.Request = .{ .enqueue = .{ .target = target, .operation = identity, .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(payload) } };
            const res = try c.DirectQueue.apply(scratch.allocator(), output.allocator(), &catalog, &cached, tight_options, environment, .{ .mutate = .{ .work = work_req, .payload = try c.DirectTableProtocol.Binary.encode(scratch.allocator(), payload) } }, policy);
            try t.expectEqual(@as(u64, 41 + step), res.operation.?.enqueue.next);
        }
        _ = scratch.reset(.retain_capacity);
        _ = output.reset(.retain_capacity);
        const blocked_op: p.DataLifecycle.Operation = .{ .scope = target.interpretation.object.scope, .principal = 101, .operation = 29002 };
        const blocked_payload = try c.storage.LogBatch.encode(schema, blocked_op, .queue, &.{.{ .cells = &cells }}, &buffer);
        const blocked_work: c.DirectQueueMutation.Request = .{ .enqueue = .{ .target = target, .operation = blocked_op, .kind = .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(blocked_payload) } };
        const encoded_payload = try c.DirectTableProtocol.Binary.encode(scratch.allocator(), blocked_payload);
        try t.expectError(error.QueueCheckpointBacklog, c.DirectQueue.apply(scratch.allocator(), output.allocator(), &catalog, &cached, tight_options, environment, .{ .mutate = .{ .work = blocked_work, .payload = encoded_payload } }, policy));
        // Operation ID remains open (not permanently refused) and succeeds once
        // standalone Queue checkpoint maintenance drains the dirty backlog.
        const observed = try c.DirectQueue.apply(scratch.allocator(), output.allocator(), &catalog, &cached, tight_options, environment, .{ .operation = blocked_work }, policy);
        try t.expect(observed.operation == null);
        cached.?.deinit();
        cached = null;
        _ = try settle(&work, service, settings, signed, &allocations, false, &peak);
        const accepted = try c.DirectQueue.apply(scratch.allocator(), output.allocator(), &catalog, &cached, tight_options, environment, .{ .mutate = .{ .work = blocked_work, .payload = encoded_payload } }, policy);
        try t.expectEqual(@as(u64, 43), accepted.operation.?.enqueue.next);
    }
    settings.flush.enabled = true;
    settings.archive = .{ .enabled = true, .work_frames = 8 };
    settings.compact = true;
    const units = try settle(&work, service, settings, signed, &allocations, true, &peak);
    try check(&data, initial, declared, claimed, authority.guard(), 0, true, true);
    try t.expectEqual(work.memory.used, admission.maintenance.used.load(.acquire));
    try t.expect(admission.maintenance.peak.load(.acquire) > 0);
    // Settle all work through the owning public composition. The original expired
    // claim remains open; payload retention must preserve its older read basis.
    clock.now = 2220;
    {
        var cached: ?c.DirectQueue.Cached = null;
        defer if (cached) |*value| value.deinit();
        var scratch: std.heap.ArenaAllocator = .init(t.allocator);
        defer scratch.deinit();
        var output: std.heap.ArenaAllocator = .init(t.allocator);
        defer output.deinit();
        const environment: c.DirectQueue.Environment = .{ .clock = @import("LocalLogClock.zig").source(service.engine) };
        var operation: u64 = 20041;
        var remaining: u32 = 43;
        while (remaining != 0) {
            _ = scratch.reset(.retain_capacity);
            _ = output.reset(.retain_capacity);
            const claim: p.StreamQueue.Claim = .{ .target = target, .operation = .{ .scope = target.interpretation.object.scope, .principal = 101, .operation = operation }, .maximum = 16, .lease_ms = 100, .predicate = null };
            operation += 1;
            const receipt = (try c.DirectQueue.apply(scratch.allocator(), output.allocator(), &catalog, &cached, .{}, environment, .{ .mutate = .{ .work = .{ .claim = claim }, .payload = null } }, policy)).operation.?.claim;
            try t.expectEqual(@min(remaining, 16), receipt.rows);
            const page = (try c.DirectQueue.apply(scratch.allocator(), output.allocator(), &catalog, &cached, .{}, environment, .{ .page = .{ .cursor = .{ .receipt = receipt, .next = 0 }, .limits = .{ .rows = 16, .encoded_bytes = 8192 } } }, policy)).page;
            try t.expect(page.cursor.complete());
            var leases: [16]p.StreamQueue.Lease = undefined;
            for (page.rows, 0..) |row, i| leases[i] = row.lease.original;
            for (leases[0..receipt.rows]) |lease| {
                _ = scratch.reset(.retain_capacity);
                _ = output.reset(.retain_capacity);
                _ = try c.DirectQueue.apply(scratch.allocator(), output.allocator(), &catalog, &cached, .{}, environment, .{ .mutate = .{ .work = .{ .settle = .{ .operation = .{ .scope = target.interpretation.object.scope, .principal = 101, .operation = operation }, .lease = lease, .action = .ack } }, .payload = null } }, policy);
                operation += 1;
            }
            remaining -= receipt.rows;
        }
    }
    native.limits.bytes = native.allocated;
    const retention_units = try settle(&work, service, settings, signed, &allocations, true, &peak);
    native.limits = limits;
    var retained = try c.storage.QueuePartition.open(t.allocator, data.log(), data.objects(), initial, authority.guard(), .{});
    defer retained.deinit() catch unreachable;
    while (!(try retained.recoverStep(authority.guard(), 16)).complete) {}
    try t.expectEqual(@as(u64, 43), retained.owner.root.retained_from);
    try t.expectEqual(@as(u64, 43), retained.owner.root.queue.?.terminal);
    try t.expect(retained.owner.root.batches == null and retained.owner.root.segments == null);
    var original = try retained.readClaimPage(declared.stored, .{ .receipt = claimed, .next = 0 }, .{ .rows = 2 }, t.allocator, authority.guard());
    defer original.deinit();
    try t.expect(original.cursor.complete() and original.len == 2);
    try t.expectEqual(@as(u64, 43), original.basis.cut.retained_from);
    for (original.rows()) |row| try t.expectEqual(p.QueueRead.State.acked, row.lease.state);
    std.debug.print("Native Queue maintenance: {d} physical units, {d} terminal-retention units, {d} peak bytes; expiry preserves open claims under reserved capacity.\n", .{ units, retention_units, peak });
}

fn settle(work: *Work, service: *Service, settings: p.Storage.Maintenance, signed: p.Growth.SignedRequest, allocations: *c.fuze.memory.AllocationProbe, restart: bool, peak: *usize) !usize {
    var idle: usize = 0;
    var units: usize = 0;
    while (idle < 16) : (units += 1) {
        if (units == 2048) return error.FixtureBudget;
        if (restart and units == 3) {
            const host = work.host;
            work.deinit();
            try t.expectEqual(@as(usize, 0), allocations.live_bytes);
            work.* = .{ .host = host, .allocator = allocations.allocator() };
        }
        const progressed = try Work.step(work, service.engine, settings, signed);
        peak.* = @max(peak.*, work.last_peak_bytes);
        try t.expect(work.last_peak_bytes <= settings.resident_bytes);
        try t.expectEqual(work.memory.used, allocations.live_bytes);
        idle = if (progressed) 0 else idle + 1;
    }
    return units;
}

fn check(data: *backend.DataStore, initial: c.storage.LogInitialization.Request, declared: c.DirectLog.Definition, claimed: p.StreamQueue.ClaimReceipt, guard: c.storage.PublicationGuard, active: u64, checkpointed: bool, archived: bool) !void {
    var queue = try c.storage.QueuePartition.open(t.allocator, data.log(), data.objects(), initial, guard, .{});
    defer queue.deinit() catch unreachable;
    while (!(try queue.recoverStep(guard, 16)).complete) {}
    try t.expectEqual(active, queue.owner.root.queue.?.active);
    const record = (try queue.operation(claimed.claim.operation, guard)).?;
    try t.expectEqualDeep(claimed, record.outcome.claim.receipt);
    var page = try queue.readClaimPage(declared.stored, .{ .receipt = claimed, .next = 0 }, .{ .rows = 2, .encoded_bytes = 8192 }, t.allocator, guard);
    defer page.deinit();
    try t.expect(page.cursor.complete() and page.len == 2);
    for (page.rows(), 0..) |row, i| {
        try t.expectEqual(@as(u64, i), row.lease.original.offset);
        try t.expectEqual(if (active == 0) p.QueueRead.State.available else p.QueueRead.State.acquired, row.lease.state);
        try t.expectEqual(@as(u64, 1), row.lease.epoch);
        try t.expectEqual(@as(u64, 1), row.lease.attempt);
        if (active == 0) {
            const tree: c.storage.TreeStore.pages.Tree(c.storage.TreeStore) = .{ .store = &queue.owner.store };
            const encoded = (try tree.get(queue.owner.root.queue.?.items, try c.storage.LogPartitionRecord.integerKey(i))).?;
            const item = try c.storage.LogPartitionRecord.valueDecode(c.storage.QueueItem, queue.owner.scratch.allocator(), encoded);
            defer _ = queue.owner.scratch.reset(.retain_capacity);
            try t.expectEqual(@as(u64, 2115), item.visible_ms);
        }
    }
    try t.expectEqual(@as(u64, 0), queue.owner.root.retained_from);
    try t.expect(queue.owner.root.next_offset >= 40);
    if (checkpointed) try t.expect(queue.owner.root.recovery != null);
    if (archived) {
        try t.expectEqual(queue.owner.root.next_offset, queue.owner.root.sealed_through);
        try t.expect(queue.owner.root.archive.through > 1 and queue.owner.root.recovery != null);
        try t.expectError(error.WalHistoryTrimmed, data.log().read(t.allocator, initial.partition, 0, 1));
    }
}
