const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const s = @import("root.zig");
const q = p.StreamQueue;
const support = @import("log_test_support.zig");
const Queue = s.QueuePartition;
const options: Queue.Options = .{ .resident_pages = 1, .batch_bytes = 8192, .key_bytes = 256, .tail = .{ .slots = 1, .borrow_slots = 2, .slot_bytes = 8192, .resident_bytes = 16384 } };

const Policy = struct {
    calls: usize = 0,
    deny_at: usize = std.math.maxInt(usize),
    epoch: u64 = 1,
    held: bool = false,
    fn guard(self: *Policy) s.PublicationGuard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
    fn acquire(raw: *anyopaque) !s.PublicationGuard.Fence {
        const self: *Policy = @ptrCast(@alignCast(raw));
        try t.expect(!self.held);
        self.calls += 1;
        if (self.calls >= self.deny_at) return error.PermissionDenied;
        self.held = true;
        return .{ .writer_epoch = self.epoch, .policy_epoch = self.epoch };
    }
    fn release(raw: *anyopaque) void {
        const self: *Policy = @ptrCast(@alignCast(raw));
        t.expect(self.held) catch unreachable;
        self.held = false;
    }
};
const Clock = struct {
    value: ?s.LogTime.Sample = .exact(100),
    after: ?s.LogTime.Sample = null,
    change: bool = false,
    fn source(self: *Clock) s.LogTime.Source {
        return .{ .context = self, .read = sample };
    }
    fn sample(raw: *anyopaque) !?s.LogTime.Sample {
        const self: *Clock = @ptrCast(@alignCast(raw));
        const result = self.value;
        if (self.change) {
            self.value = self.after;
            self.change = false;
        }
        return result;
    }
};
const Fault = struct {
    underlying: s.TransitLog.Log,
    lose_reply: bool = false,
    fn log(self: *Fault) s.TransitLog.Log {
        return .{ .context = self, .vtable = &.{ .append = append, .read = read, .tail = tail, .trim = trim, .fence = fence } };
    }
    fn cast(raw: *anyopaque) *Fault {
        return @ptrCast(@alignCast(raw));
    }
    fn append(raw: *anyopaque, partition: u64, expected: ?u64, writer: u64, policy: u64, kind: s.TransitLog.FrameKind, bytes: []const u8) !s.TransitLog.AppendReceipt {
        const self = cast(raw);
        const result = try self.underlying.append(partition, expected, writer, policy, kind, bytes);
        if (self.lose_reply) {
            self.lose_reply = false;
            return error.InjectedReplyLoss;
        }
        return result;
    }
    fn read(raw: *anyopaque, allocator: std.mem.Allocator, partition: u64, from: u64, count: usize) !s.TransitLog.Log.OwnedBatch {
        return cast(raw).underlying.read(allocator, partition, from, count);
    }
    fn tail(raw: *anyopaque, partition: u64) !u64 {
        return cast(raw).underlying.tail(partition);
    }
    fn trim(raw: *anyopaque, partition: u64, until: u64) !void {
        return cast(raw).underlying.trim(partition, until);
    }
    fn fence(raw: *anyopaque, partition: u64, writer: u64, policy: u64) !void {
        return cast(raw).underlying.fence(partition, writer, policy);
    }
};
fn operation(id: u64) p.DataLifecycle.Operation {
    return .{ .scope = support.definition(.queue).object.scope, .principal = 1, .operation = id };
}
fn declaration() !s.LogDeclaration.Owned {
    var definition = support.definition(.queue);
    definition.configuration.partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 };
    return s.LogDeclaration.prepare(t.allocator, definition);
}
fn initialize(wal: s.TransitLog.Log, objects: s.TransitObjectStore.ObjectStore, policy: *Policy, declared: *const s.LogDeclaration.Owned) !s.LogInitialization.Request {
    const initial: s.LogInitialization.Request = .{ .definition = p.Growth.current_definition, .declared = try s.LogDeclaration.stage(objects, declared), .operation = operation(1), .ordinal = 0, .partition = 91 };
    _ = try s.LogInitialization.initialize(t.allocator, wal, objects, initial, policy.guard());
    return initial;
}
fn request(declared: *const s.LogDeclaration.Owned, id: u64, buffer: []u8) !struct { append: q.Append, payload: []const u8 } {
    var encoder = try s.LogBatch.Encoder.init(declared.definition.schema, operation(id), .queue, 3, buffer);
    for ([_][]const u8{ "Alpha", "Beta", "aLPHa" }, [_]u64{ 1000, 0, 0 }) |name, delay| {
        const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .bytes = name } } }, .{ .value = .{ .atom = .{ .bytes = "payload" } } } };
        try encoder.append(.{ .cells = &cells, .visible_ms = delay });
    }
    const payload = try encoder.finish();
    return .{ .append = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = (try declared.stored()).declaration.interpretation, .partition = 0 }, .operation = operation(id), .kind = .queue, .producer = .{ .id = @splat(4), .epoch = 1, .sequence = id - 1 }, .rows = 3, .payload = s.LogBatch.content(payload) }, .payload = payload };
}
fn index(owner: *Queue, bitmap: *s.BitmapDirectory) s.QueueIndex {
    bitmap.* = .{ .store = &owner.owner.store, .objects = owner.owner.objects };
    return .{ .store = &owner.owner.store, .scratch = &owner.owner.scratch, .bitmap = bitmap, .container = &owner.owner.queue_container, .key_buffer = owner.owner.key_buffer, .timer_workspace = owner.owner.queue_timers, .timer_seed = owner.owner.root.initialization.target(), .timer_read_work = owner.owner.options.queue_timer_read_work };
}
fn selectedLease(objects: s.TransitObjectStore.ObjectStore, receipt: q.ClaimReceipt, at: u32) !q.Lease {
    var buffer: [s.QueueSelection.max_bytes]u8 = undefined;
    const selected = try s.QueueSelection.load(t.allocator, objects, receipt.leases.?, &buffer);
    try selected.requireReceipt(receipt);
    return selected.lease(at);
}

test "queue partition resumes accepted timer merges through reply loss retirement and disk recovery" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var definition = support.definition(.queue);
    definition.configuration.partitioning.count = 1;
    definition.configuration.partitioning.key_column = null;
    definition.configuration.policy.queue.ordering = .unordered;
    definition.configuration.policy.queue.key_column = null;
    definition.limits.claim_rows = 256;
    definition.limits.active_leases = 512;
    var declared = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{};
    var configured = options;
    configured.clock = clock.source();
    configured.batch_bytes = 128 * 1024;
    configured.tail.slot_bytes = configured.batch_bytes;
    configured.tail.resident_bytes = configured.batch_bytes * 2;
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var fault: Fault = .{ .underlying = wal.log() };
    var owner = try Queue.open(t.allocator, fault.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [128 * 1024]u8 = undefined;
    for (2..4) |id| {
        var encoder = try s.LogBatch.Encoder.init(declared.definition.schema, operation(id), .queue, 256, &bytes);
        for (0..256) |_| try encoder.append(.{ .cells = &.{ .{ .value = .{ .atom = .{ .bytes = "key" } } }, .{ .value = .{ .atom = .{ .bytes = "payload" } } } } });
        const payload = try encoder.finish();
        _ = try owner.enqueue(initial.declared, .{ .target = initial.target(), .operation = operation(id), .kind = .queue, .producer = null, .rows = 256, .payload = s.LogBatch.content(payload) }, payload, policy.guard());
    }
    try t.expectEqual(@as(u64, 2), owner.owner.root.queue.?.eligible.pending_chunks);
    // Freeze visibility work while these entries are still available. Claims
    // change the live item/bitmap basis while that merge retains its own basis.
    while (owner.owner.root.queue.?.eligible.work == null) try t.expect(try owner.scheduleMaintenanceUnit(initial.declared, 17, policy.guard()));
    var claimed: [2]q.ClaimReceipt = undefined;
    for (&claimed, 4..) |*receipt, id| {
        receipt.* = try owner.claim(initial.declared, .{ .target = initial.target(), .operation = operation(id), .maximum = 256, .lease_ms = 100 }, policy.guard());
        try t.expectEqual(@as(u32, 256), receipt.rows);
    }
    try t.expectEqual(@as(u64, 2), owner.owner.root.queue.?.deadlines.pending_chunks);
    const old_first = try selectedLease(objects.objectStore(), claimed[0], 0);
    const old_second = try selectedLease(objects.objectStore(), claimed[0], 1);
    _ = try owner.settle(initial.declared, .{ .operation = operation(6), .lease = old_first, .action = .{ .nack = .{ .visible_ms = 300 } } }, policy.guard());
    _ = try owner.settle(initial.declared, .{ .operation = operation(7), .lease = old_second, .action = .ack }, policy.guard());
    var both = false;
    for (0..16) |_| {
        try t.expect(try owner.scheduleMaintenanceUnit(initial.declared, 17, policy.guard()));
        const state = owner.owner.root.queue.?;
        if (state.eligible.work != null and state.deadlines.work != null and state.eligible.work.?.merge.output.rows > 0 and state.deadlines.work.?.merge.output.rows > 0) {
            both = true;
            break;
        }
    }
    try t.expect(both);
    // Two nonempty unfinished merges, including their frozen roots and output
    // directories, fit the unchanged LOGPART1 metadata budget on every write.
    const before = owner.owner.root;
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.scheduleMaintenanceUnit(initial.declared, 17, policy.guard()));
    try t.expectEqualDeep(before, owner.owner.root);
    try t.expectEqual(before.next_lsn, try wal.log().tail(initial.partition));
    policy.deny_at = std.math.maxInt(usize);
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.scheduleMaintenanceUnit(initial.declared, 17, policy.guard()));
    try t.expectError(error.LogRecoveryRequired, owner.observe(initial.declared, policy.guard()));
    const puts = objects.puts;
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqual(puts, objects.puts);
    const accepted = owner.owner.root;
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    fault.underlying = wal.log();
    policy.epoch += 1;
    owner = try Queue.open(t.allocator, fault.log(), objects.objectStore(), initial, policy.guard(), configured);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqual(@as(u64, 0), objects.puts);
    try t.expectEqualDeep(accepted, owner.owner.root);
    definition.revision = 2;
    definition.retired = true;
    var retired = try s.LogDeclaration.prepare(t.allocator, definition);
    defer retired.deinit();
    const current = try s.LogDeclaration.stage(objects.objectStore(), &retired);
    clock.value = null; // Physical timer cleanup needs no lease-time decision.
    var units: usize = 0;
    while (try owner.scheduleMaintenanceUnit(current, 17, policy.guard())) : (units += 1) {
        if (units > 512) return error.FixtureBudget;
    }
    try t.expect(units > 50);
    const stable = owner.owner.root;
    const state = stable.queue.?;
    try t.expect(state.eligible.work == null and state.deadlines.work == null);
    try t.expectEqual(@as(u64, 0), state.eligible.pending_chunks + state.deadlines.pending_chunks);
    try t.expectEqual(@as(u64, 1), state.scheduled);
    try t.expectEqual(@as(u64, 510), state.active);
    try t.expectEqual(@as(u64, 0), state.eligible.level_count);
    try t.expect(state.deadlines.level_count > 0);
    const idle_puts = objects.puts;
    for (0..3) |_| try t.expect(!try owner.scheduleMaintenanceUnit(current, 17, policy.guard()));
    try t.expectEqual(idle_puts, objects.puts);
    try t.expectEqualDeep(stable, owner.owner.root);
    var bitmap: s.BitmapDirectory = undefined;
    const queue = index(&owner, &bitmap);
    try t.expect(try queue.firstEligible(state, 299) == null);
    try t.expectEqual(@as(u64, 0), (try queue.firstEligible(state, 300)).?.offset);
    try t.expectEqual(@as(u64, 2), (try queue.deadlineAfter(state, null)).?.offset);
    for (claimed) |receipt| try t.expectEqualDeep(receipt, (try owner.operation(receipt.claim.operation, policy.guard())).?.outcome.claim.receipt);
    const cut = stable.position();
    while (!(try owner.flush(cut, policy.guard())).complete) {}
    while (!(try owner.archive(cut, .{ .frames = 8 }, policy.guard())).complete) {}
    _ = try owner.checkpoint(cut, policy.guard());
    _ = try owner.trimArchived(policy.guard());
    try owner.deinit();
    owner = try Queue.open(t.allocator, fault.log(), objects.objectStore(), initial, policy.guard(), configured);
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqualDeep(state, owner.owner.root.queue.?);
    var page = try owner.readClaimPage(current, .{ .receipt = claimed[0], .next = 0 }, .{ .rows = 2, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer page.deinit();
    try t.expectEqual(@as(usize, 2), page.rows().len);
    try t.expectEqual(p.QueueRead.State.available, page.rows()[0].lease.state);
    try t.expectEqual(p.QueueRead.State.acked, page.rows()[1].lease.state);
}

test "queue partition publishes payload FIFO and producer outcome together through lost replies and disk restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var declared = try declaration();
    defer declared.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var fault: Fault = .{ .underlying = wal.log(), .lose_reply = true };
    var owner = try Queue.open(t.allocator, fault.log(), objects.objectStore(), initial, policy.guard(), options);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const first = try request(&declared, 2, &buffer);
    try t.expectError(error.LogAppendUncertain, owner.enqueue(initial.declared, first.append, first.payload, policy.guard()));
    try t.expectError(error.LogRecoveryRequired, owner.operation(operation(2), policy.guard()));
    const puts = objects.puts;
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqual(puts, objects.puts);
    const original = try owner.enqueue(initial.declared, first.append, first.payload, policy.guard());
    try t.expectEqual(@as(u64, 2), original.accepted.next_lsn);
    for (3..14) |id| {
        const next = try request(&declared, id, &buffer);
        _ = try owner.enqueue(initial.declared, next.append, next.payload, policy.guard());
    }
    const before = owner.owner.root;
    try t.expectEqual(@as(u64, 36), before.next_offset);
    try t.expectEqual(@as(u64, 2), before.queue.?.scheduled);
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    policy.epoch = 2;
    owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), options);
    var steps: usize = 0;
    while (true) {
        const recovered = try owner.recoverStep(policy.guard(), 1);
        try t.expectEqual(@as(u16, 1), recovered.examined);
        steps += 1;
        if (recovered.complete) break;
        try t.expectError(error.LogRecoveryRequired, owner.observe(initial.declared, policy.guard()));
    }
    try t.expectEqual(@as(usize, 12), steps);
    try t.expectEqual(@as(u64, 0), objects.puts);
    try t.expectEqual(@as(u64, 0), wal.appends);
    try t.expectEqualDeep(before, owner.owner.root);
    try t.expectEqualDeep(original, (try owner.operation(operation(2), policy.guard())).?.outcome.append);
    var bitmap: s.BitmapDirectory = undefined;
    const queue = index(&owner, &bitmap);
    try t.expectEqual(@as(u64, 1), (try queue.firstEligible(before.queue.?, 999)).?.offset);
    for (0..36) |offset| {
        const item = try queue.item(before.queue.?, offset);
        try t.expectEqual(s.Tack.State.available, try queue.state(before.queue.?, item));
    }
    // Storage-level payload access only: Queue's public wrapper has no consume
    // or unleased payload-read operation.
    var payload = (try owner.owner.readBatch(initial.declared, 0, policy.guard())).?;
    try t.expectEqualDeep(original, payload.receipt);
    const retry = try request(&declared, 2, &buffer);
    try t.expectEqualSlices(u8, retry.payload, try payload.payload.bytes());
    payload.deinit();
    try t.expectEqualDeep(original, try owner.enqueue(initial.declared, retry.append, retry.payload, policy.guard()));
    const cut = before.position();
    while (!(try owner.flush(cut, policy.guard())).complete) {}
    while (!(try owner.archive(cut, .{ .frames = 2 }, policy.guard())).complete) {}
    _ = try owner.checkpoint(cut, policy.guard());
    try t.expectEqual(cut.next_lsn, try owner.trimArchived(policy.guard()));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    policy.epoch = 3;
    owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), options);
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqualDeep(before.queue, owner.owner.root.queue);
    payload = (try owner.owner.readBatch(initial.declared, 0, policy.guard())).?;
    try t.expectEqualSlices(u8, retry.payload, try payload.payload.bytes());
    payload.deinit();
    try t.expectEqual(@as(u64, 0), objects.puts);
    try t.expectEqualDeep(original, try owner.enqueue(initial.declared, retry.append, retry.payload, policy.guard()));
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.operation(operation(2), policy.guard()));
}

test "queue partition rejects budget pressure and revoked publication without accepting staged roots" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declared = try declaration();
    defer declared.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var small = options;
    small.queue_candidate_objects = 1;
    var owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), small);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    const before = owner.owner.root;
    var buffer: [8192]u8 = undefined;
    const next = try request(&declared, 2, &buffer);
    const puts = objects.puts;
    try t.expectError(error.CandidateObjectBudgetExceeded, owner.enqueue(initial.declared, next.append, next.payload, policy.guard()));
    try t.expectEqual(puts, objects.puts);
    try t.expectEqualDeep(before, owner.owner.root);
    try t.expectEqual(@as(u64, 1), try wal.log().tail(91));
    try owner.deinit();
    owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), options);
    _ = try owner.recoverStep(policy.guard(), 1);
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.enqueue(initial.declared, next.append, next.payload, policy.guard()));
    try t.expectEqualDeep(before, owner.owner.root);
    try t.expectEqual(@as(u64, 1), try wal.log().tail(91));
    policy.deny_at = std.math.maxInt(usize);
    const accepted = try owner.enqueue(initial.declared, next.append, next.payload, policy.guard());
    try t.expectEqual(@as(u64, 2), accepted.accepted.next_lsn);
}

test "queue partition replay rejects a valid envelope with altered scheduling state" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declared = try declaration();
    defer declared.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), options);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const next = try request(&declared, 2, &buffer);
    _ = try owner.enqueue(initial.declared, next.append, next.payload, policy.guard());
    var batch = try wal.log().read(t.allocator, 91, 1, 1);
    defer batch.deinit();
    const decoded = try s.LogPartitionRecord.decode(t.allocator, batch.frames[0], 91, 1);
    var record = decoded.record;
    record.root.queue.?.scheduled -= 1;
    // Both roots are structurally valid and all referenced objects still exist.
    // Full deterministic reconstruction must reject the false accepted count.
    try record.validate(1);
    var encoded: [65536]u8 = undefined;
    const forged = try s.LogPartitionRecord.encode(record, decoded.payload, &encoded);
    var other = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer other.deinit();
    const same = try initialize(other.log(), objects.objectStore(), &policy, &declared);
    try t.expectEqualDeep(initial, same);
    _ = try other.log().append(91, 1, 1, 1, .row_delta, forged);
    var recovered = try Queue.open(t.allocator, other.log(), objects.objectStore(), initial, policy.guard(), options);
    defer recovered.deinit() catch unreachable;
    const puts = objects.puts;
    try t.expectError(error.InvalidLogHistory, recovered.recoverStep(policy.guard(), 1));
    try t.expectEqual(puts, objects.puts);
    try t.expectEqual(@as(u64, 0), recovered.owner.root.next_offset);
    try t.expectError(error.LogRecoveryRequired, recovered.observe(initial.declared, policy.guard()));
    // A physical scheduling record also requires exact reconstruction. A
    // syntactically valid sweep digest cannot substitute another frozen basis.
    try t.expect(try owner.scheduleMaintenanceUnit(initial.declared, 17, policy.guard()));
    var maintenance = try wal.log().read(t.allocator, 91, 2, 1);
    defer maintenance.deinit();
    record = (try s.LogPartitionRecord.decode(t.allocator, maintenance.frames[0], 91, 2)).record;
    try t.expect(record.action == .queue_schedule);
    record.root.queue.?.eligible.sweep.?.epoch[0] ^= 1;
    try record.validate(2);
    const altered = try s.LogPartitionRecord.encode(record, &.{}, &encoded);
    try recovered.deinit();
    other.deinit();
    other = s.LocalWal.LocalWal.initMemory(t.allocator);
    _ = try initialize(other.log(), objects.objectStore(), &policy, &declared);
    _ = try other.log().append(91, 1, 1, 1, .row_delta, batch.frames[0].payload);
    _ = try other.log().append(91, 2, 1, 1, .manifest_checkpoint, altered);
    recovered = try Queue.open(t.allocator, other.log(), objects.objectStore(), initial, policy.guard(), options);
    const before_replay = objects.puts;
    try t.expect(!(try recovered.recoverStep(policy.guard(), 1)).complete);
    const accepted = recovered.owner.root;
    try t.expectError(error.InvalidLogHistory, recovered.recoverStep(policy.guard(), 1));
    try t.expectEqual(before_replay, objects.puts);
    try t.expectEqualDeep(accepted, recovered.owner.root);
    try t.expectError(error.LogRecoveryRequired, recovered.observe(initial.declared, policy.guard()));
}

test "queue partition original claim selections and empty outcomes survive expiry and disk recovery" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var base = try declaration();
    defer base.deinit();
    var definition = base.definition;
    definition.limits.timer_steps = 1;
    var declared = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var fault: Fault = .{ .underlying = wal.log() };
    var configured = options;
    configured.clock = clock.source();
    configured.queue_visibility_rows = 1;
    var allocations: f.memory.AllocationProbe = .{ .parent = t.allocator };
    defer t.expectEqual(@as(usize, 0), allocations.live_bytes) catch unreachable;
    var owner = try Queue.open(allocations.allocator(), fault.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    const appended = try request(&declared, 2, &bytes);
    _ = try owner.enqueue(initial.declared, appended.append, appended.payload, policy.guard());
    // An observed cut with two due heads exceeds the resident prefix. Reading
    // beyond that prefix must still find the other key through its durable index.
    var visibility_bitmap: s.BitmapDirectory = undefined;
    var visibility_index = index(&owner, &visibility_bitmap);
    visibility_index.visibility = &owner.owner.queue_visibility;
    try visibility_index.prepareVisibility(owner.owner.root.queue.?, 1000, 1);
    const first_due = (try visibility_index.firstEligible(owner.owner.root.queue.?, 1000)).?;
    try t.expectEqual(@as(u64, 1), first_due.offset);
    try t.expectEqual(@as(u64, 0), (try visibility_index.eligibleAfter(owner.owner.root.queue.?, try s.QueueIndex.timedKey(first_due.visible_ms, first_due.offset), 1000)).?.offset);
    const claim: q.Claim = .{ .target = initial.target(), .operation = operation(3), .maximum = 2, .lease_ms = 100 };
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.claim(initial.declared, claim, policy.guard()));
    try t.expectError(error.LogRecoveryRequired, owner.claim(initial.declared, claim, policy.guard()));
    const puts = objects.puts;
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqual(puts, objects.puts);
    const original = try owner.claim(initial.declared, claim, policy.guard());
    try t.expectEqual(@as(u32, 1), original.rows);
    var selection_buffer: [s.QueueSelection.max_bytes]u8 = undefined;
    var view = try s.QueueSelection.load(t.allocator, objects.objectStore(), original.leases.?, &selection_buffer);
    try view.requireReceipt(original);
    try t.expectEqual(@as(u64, 1), (try view.lease(0)).offset);
    try t.expectEqual(@as(u64, 200), (try view.lease(0)).expires_ms);
    var empty_request = claim;
    empty_request.operation = operation(4);
    const empty = try owner.claim(initial.declared, empty_request, policy.guard());
    try t.expect(empty.rows == 0 and empty.leases == null);
    // This prefix contains the future head. Warm visibility checks allocate no
    // backing memory and read no objects; they do not publish a claim.
    const idle_reads = objects.range_reads;
    allocations.begin(true);
    for (0..20) |_| {
        try visibility_index.prepareVisibility(owner.owner.root.queue.?, 100, 1);
        try t.expect(try visibility_index.firstEligible(owner.owner.root.queue.?, 100) == null);
    }
    try allocations.verify();
    allocations.begin(false);
    try t.expectEqual(idle_reads, objects.range_reads);
    clock.value = .exact(1000);
    try visibility_index.prepareVisibility(owner.owner.root.queue.?, 1000, 1);
    try t.expect(owner.owner.queue_visibility.observed_ms == null); // Cascade is incomplete.
    try t.expectEqual(@as(u64, 0), (try visibility_index.firstEligible(owner.owner.root.queue.?, 1000)).?.offset);
    try t.expectEqualDeep(empty, try owner.claim(initial.declared, empty_request, policy.guard()));
    try t.expectEqualDeep(original, try owner.claim(initial.declared, claim, policy.guard()));
    var fresh = claim;
    fresh.operation = operation(5);
    const alpha = try owner.claim(initial.declared, fresh, policy.guard());
    try t.expectEqual(@as(u32, 1), alpha.rows);
    view = try s.QueueSelection.load(t.allocator, objects.objectStore(), alpha.leases.?, &selection_buffer);
    try t.expectEqual(@as(u64, 0), (try view.lease(0)).offset);
    const root = owner.owner.root;
    try t.expectEqual(@as(u64, 2), root.queue.?.active);
    try t.expectEqual(@as(u64, 0), root.queue.?.scheduled);
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    policy.epoch = 2;
    clock.value = null;
    owner = try Queue.open(allocations.allocator(), wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqualDeep(root, owner.owner.root);
    try t.expectEqual(@as(u64, 0), objects.puts);
    try t.expectEqualDeep(original, try owner.claim(initial.declared, claim, policy.guard()));
    try t.expectEqualDeep(empty, try owner.claim(initial.declared, empty_request, policy.guard()));
    var bitmap: s.BitmapDirectory = undefined;
    const queue = index(&owner, &bitmap);
    try t.expectEqual(@as(u64, 1), (try queue.firstExpired(root.queue.?, 1000)).?.offset);
    try t.expectEqual(s.Tack.State.available, try queue.state(root.queue.?, try queue.item(root.queue.?, 2)));
    fresh.operation = operation(6);
    try t.expectError(error.QueueTimeUnavailable, owner.claim(initial.declared, fresh, policy.guard()));
    var changed = claim;
    changed.maximum = 1;
    try t.expectError(error.QueueClaimConflict, owner.claim(initial.declared, changed, policy.guard()));
}

test "queue partition claim time and capacity refusals cannot publish empty success" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var base = try declaration();
    defer base.deinit();
    var limited = base.definition;
    limited.limits.active_leases = 1;
    limited.limits.claim_rows = 1;
    var declared = try s.LogDeclaration.prepare(t.allocator, limited);
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{};
    var configured = options;
    configured.clock = clock.source();
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    const appended = try request(&declared, 2, &bytes);
    _ = try owner.enqueue(initial.declared, appended.append, appended.payload, policy.guard());
    const before = owner.owner.root;
    var claim: q.Claim = .{ .target = initial.target(), .operation = operation(3), .maximum = 1, .lease_ms = 100 };
    clock.change = true;
    try t.expectError(error.QueueTimeUnavailable, owner.claim(initial.declared, claim, policy.guard()));
    try t.expectEqualDeep(before, owner.owner.root);
    try t.expectEqual(before.next_lsn, try wal.log().tail(91));
    clock.value = .exact(100);
    clock.after = .{ .earliest_ms = 199, .latest_ms = 200 };
    clock.change = true;
    try t.expectError(error.QueueTimeUnavailable, owner.claim(initial.declared, claim, policy.guard()));
    try t.expectEqualDeep(before, owner.owner.root);
    clock.value = .exact(100);
    clock.after = .exact(200);
    clock.change = true;
    try t.expectError(error.QueueLeaseExpired, owner.claim(initial.declared, claim, policy.guard()));
    try t.expectEqualDeep(before, owner.owner.root);
    clock.value = .exact(100);
    var competing = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer competing.deinit() catch unreachable;
    _ = try competing.recoverStep(policy.guard(), 1);
    _ = try owner.claim(initial.declared, claim, policy.guard());
    clock.value = .exact(1000);
    claim.operation = operation(4);
    try t.expectError(error.LogRecoveryRequired, competing.claim(initial.declared, claim, policy.guard()));
    try t.expect((try competing.recoverStep(policy.guard(), 1)).complete);
    const acquired = owner.owner.root;
    try t.expectEqualDeep(acquired, competing.owner.root);
    try t.expectError(error.QueueLeaseCapacityExceeded, owner.claim(initial.declared, claim, policy.guard()));
    try t.expectEqualDeep(acquired, owner.owner.root);
    try t.expect(try owner.operation(claim.operation, policy.guard()) == null);
    clock.value = .exact(99);
    try t.expectError(error.LogTimeRegression, owner.claim(initial.declared, claim, policy.guard()));
}

test "queue partition wait readiness cannot publish an empty claim when clock uncertainty widens" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declared = try declaration();
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{};
    var configured = options;
    configured.clock = clock.source();
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "entity" } } }, .{ .value = .{ .atom = .{ .bytes = "payload" } } } };
    const payload = try s.LogBatch.encode(declared.definition.schema, operation(2), .queue, &.{.{ .cells = &cells, .visible_ms = 200 }}, &bytes);
    _ = try owner.enqueue(initial.declared, .{ .target = initial.target(), .operation = operation(2), .kind = .queue, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload) }, payload, policy.guard());
    const claim: q.Claim = .{ .target = initial.target(), .operation = operation(3), .maximum = 1, .lease_ms = 100 };
    const before = owner.owner.root;
    clock.value = .exact(200);
    try t.expect((try owner.claimReadiness(initial.declared, claim, policy.guard())).available);
    clock.value = .{ .earliest_ms = 199, .latest_ms = 201 };
    try t.expectError(error.QueueNotEligible, owner.claimNonempty(initial.declared, claim, policy.guard()));
    try t.expectEqualDeep(before, owner.owner.root);
    try t.expectEqual(before.next_lsn, try wal.log().tail(91));
    try t.expect(try owner.operation(claim.operation, policy.guard()) == null);
    const pending = try owner.claimReadiness(initial.declared, claim, policy.guard());
    try t.expect(!pending.available);
    try t.expectEqual(@as(?u64, 1), pending.wake_after_ms);
    clock.value = .exact(201);
    const accepted = try owner.claimNonempty(initial.declared, claim, policy.guard());
    try t.expectEqual(@as(u32, 1), accepted.rows);
    clock.value = null;
    try t.expectEqualDeep(accepted, try owner.claimNonempty(initial.declared, claim, policy.guard()));
}

test "queue partition replay refuses a canonical claim selecting an ineligible FIFO successor" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declared = try declaration();
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{};
    var configured = options;
    configured.clock = clock.source();
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    const appended = try request(&declared, 2, &bytes);
    _ = try owner.enqueue(initial.declared, appended.append, appended.payload, policy.guard());
    const claim: q.Claim = .{ .target = initial.target(), .operation = operation(3), .maximum = 2, .lease_ms = 100 };
    const receipt = try owner.claim(initial.declared, claim, policy.guard());
    var selection_buffer: [s.QueueSelection.max_bytes]u8 = undefined;
    const selection = try s.QueueSelection.load(t.allocator, objects.objectStore(), receipt.leases.?, &selection_buffer);
    var lease = try selection.lease(0);
    lease.offset = 2;
    const false_selection = try s.QueueSelection.stage(objects.objectStore(), selection.metadata, &.{lease}, &selection_buffer);
    var frames = try wal.log().read(t.allocator, 91, 1, 2);
    defer frames.deinit();
    var record = (try s.LogPartitionRecord.decode(t.allocator, frames.frames[1], 91, 2)).record;
    record.action.operation.outcome.claim.receipt.leases = false_selection;
    var buffer: [65536]u8 = undefined;
    const encoded = try s.LogPartitionRecord.encode(record, &.{}, &buffer);
    var other = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer other.deinit();
    _ = try initialize(other.log(), objects.objectStore(), &policy, &declared);
    _ = try other.log().append(91, 1, 1, 1, .row_delta, frames.frames[0].payload);
    _ = try other.log().append(91, 2, 1, 1, .manifest_checkpoint, encoded);
    var recovered = try Queue.open(t.allocator, other.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer recovered.deinit() catch unreachable;
    const puts = objects.puts;
    try t.expect(!(try recovered.recoverStep(policy.guard(), 1)).complete);
    try t.expectError(error.InvalidLogHistory, recovered.recoverStep(policy.guard(), 1));
    try t.expectEqual(@as(u64, 0), recovered.owner.root.queue.?.active);
    try t.expectEqual(puts, objects.puts);
}

test "queue partition fenced ACK NACK and renewal recover original outcomes after expiry and retirement" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var declared = try declaration();
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{ .value = .exact(1000) };
    var configured = options;
    configured.clock = clock.source();
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var fault: Fault = .{ .underlying = wal.log() };
    var owner = try Queue.open(t.allocator, fault.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    const appended = try request(&declared, 2, &bytes);
    _ = try owner.enqueue(initial.declared, appended.append, appended.payload, policy.guard());
    var claim: q.Claim = .{ .target = initial.target(), .operation = operation(3), .maximum = 2, .lease_ms = 100 };
    const claimed = try owner.claim(initial.declared, claim, policy.guard());
    const old_alpha = try selectedLease(objects.objectStore(), claimed, 0);
    const beta = try selectedLease(objects.objectStore(), claimed, 1);
    clock.value = .exact(1010);
    const renewal: q.Settlement = .{ .operation = operation(4), .lease = old_alpha, .action = .{ .extend = .{ .expires_ms = 1200 } } };
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.settle(initial.declared, renewal, policy.guard()));
    const puts = objects.puts;
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqual(puts, objects.puts);
    const renewed = try owner.settle(initial.declared, renewal, policy.guard());
    const cut = owner.owner.root.position();
    while (!(try owner.flush(cut, policy.guard())).complete) {}
    try owner.deinit();
    owner = try Queue.open(t.allocator, fault.log(), objects.objectStore(), initial, policy.guard(), configured);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    clock.value = .exact(1011);
    var ack: q.Settlement = .{ .operation = operation(5), .lease = old_alpha, .action = .ack };
    try t.expectError(error.QueueLeaseFenced, owner.settle(initial.declared, ack, policy.guard()));
    ack.lease.expires_ms = 1200;
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.settle(initial.declared, ack, policy.guard()));
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    const acked = try owner.settle(initial.declared, ack, policy.guard());
    try t.expectEqual(@as(u64, 1), owner.owner.root.queue.?.terminal);
    clock.value = .exact(1013);
    const nack: q.Settlement = .{ .operation = operation(6), .lease = beta, .action = .{ .nack = .{ .visible_ms = 0 } } };
    const nacked = try owner.settle(initial.declared, nack, policy.guard());
    claim.operation = operation(7);
    const successor = try owner.claim(initial.declared, claim, policy.guard());
    const next_alpha = try selectedLease(objects.objectStore(), successor, 0);
    try t.expectEqual(@as(u64, 2), next_alpha.offset);
    try t.expectEqual(@as(u32, 1), successor.rows);
    clock.value = .exact(1014);
    claim.operation = operation(8);
    const retried = try owner.claim(initial.declared, claim, policy.guard());
    const next_beta = try selectedLease(objects.objectStore(), retried, 0);
    try t.expect(next_beta.offset == beta.offset and next_beta.epoch == 2 and next_beta.attempt == 2);
    const stale: q.Settlement = .{ .operation = operation(9), .lease = beta, .action = .ack };
    try t.expectError(error.QueueLeaseFenced, owner.settle(initial.declared, stale, policy.guard()));
    var retired_definition = declared.definition;
    retired_definition.revision = 2;
    retired_definition.retired = true;
    var retired = try s.LogDeclaration.prepare(t.allocator, retired_definition);
    defer retired.deinit();
    const current = try s.LogDeclaration.stage(objects.objectStore(), &retired);
    clock.value = .exact(1015);
    const closing: q.Settlement = .{ .operation = operation(9), .lease = next_alpha, .action = .ack };
    const closed = try owner.settle(current, closing, policy.guard());
    try t.expectEqual(@as(u64, 2), owner.owner.root.queue.?.terminal);
    claim.operation = operation(10);
    try t.expectError(error.LogDeclarationConflict, owner.claim(current, claim, policy.guard()));
    clock.value = .exact(next_beta.expires_ms);
    const expired: q.Settlement = .{ .operation = operation(10), .lease = next_beta, .action = .ack };
    try t.expectError(error.QueueLeaseExpired, owner.settle(current, expired, policy.guard()));
    const root = owner.owner.root;
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    clock.value = null;
    policy.epoch = 2;
    owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqualDeep(root, owner.owner.root);
    try t.expectEqual(@as(u64, 0), objects.puts);
    try t.expectEqualDeep(renewed, try owner.settle(current, renewal, policy.guard()));
    try t.expectEqualDeep(acked, try owner.settle(current, ack, policy.guard()));
    try t.expectEqualDeep(nacked, try owner.settle(current, nack, policy.guard()));
    try t.expectEqualDeep(closed, try owner.settle(current, closing, policy.guard()));
    var recovered_page = try owner.readClaimPage(current, .{ .receipt = claimed, .next = 0 }, .{}, t.allocator, policy.guard());
    defer recovered_page.deinit();
    try t.expect(recovered_page.cursor.complete() and recovered_page.rows().len == 2);
    try t.expect(recovered_page.basis.time == null);
    try t.expectEqual(p.QueueRead.State.acked, recovered_page.rows()[0].lease.state);
    try t.expectEqual(p.QueueRead.Liveness.fenced, recovered_page.rows()[1].lease.liveness);
    try t.expectEqual(@as(u64, 2), recovered_page.rows()[1].lease.epoch);
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.settle(current, closing, policy.guard()));
}

test "queue partition settlement rechecks time at publication and keeps exhausted heads blocked" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var base = try declaration();
    defer base.deinit();
    var definition = base.definition;
    definition.configuration.policy.queue.maximum_attempts = 1;
    var declared = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{ .value = .exact(1000) };
    var configured = options;
    configured.clock = clock.source();
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    const appended = try request(&declared, 2, &bytes);
    _ = try owner.enqueue(initial.declared, appended.append, appended.payload, policy.guard());
    const claimed = try owner.claim(initial.declared, .{ .target = initial.target(), .operation = operation(3), .maximum = 2, .lease_ms = 100 }, policy.guard());
    const alpha = try selectedLease(objects.objectStore(), claimed, 0);
    const nack: q.Settlement = .{ .operation = operation(4), .lease = alpha, .action = .{ .nack = .{ .visible_ms = 0 } } };
    const before = owner.owner.root;
    clock.value = .exact(1099);
    clock.after = .{ .earliest_ms = 1099, .latest_ms = 1100 };
    clock.change = true;
    try t.expectError(error.QueueTimeUnavailable, owner.settle(initial.declared, nack, policy.guard()));
    try t.expectEqualDeep(before, owner.owner.root);
    clock.value = .exact(1099);
    clock.after = .exact(1100);
    clock.change = true;
    try t.expectError(error.QueueLeaseExpired, owner.settle(initial.declared, nack, policy.guard()));
    try t.expectEqualDeep(before, owner.owner.root);
    clock.value = .exact(1099);
    _ = try owner.settle(initial.declared, nack, policy.guard());
    try t.expectEqual(@as(u64, 1), owner.owner.root.queue.?.blocked);
    try t.expectEqual(@as(u64, 0), owner.owner.root.queue.?.terminal);
    var bitmap: s.BitmapDirectory = undefined;
    const queue = index(&owner, &bitmap);
    const item = try queue.item(owner.owner.root.queue.?, 0);
    try t.expectEqual(s.Tack.State.available, try queue.state(owner.owner.root.queue.?, item));
    try t.expect(item.blocked == .exhausted);
    try t.expect(try queue.firstEligible(owner.owner.root.queue.?, 100000) == null);
}

test "queue partition expiry fences renewed deadlines and records bounded retries across downtime" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var base = try declaration();
    defer base.deinit();
    var definition = base.definition;
    definition.configuration.policy.queue.maximum_attempts = 2;
    definition.limits.timer_steps = 1;
    var declared = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{ .value = .exact(1000) };
    var configured = options;
    configured.clock = clock.source();
    configured.queue_deadline_rows = 1; // Active population is larger than its cached prefix.
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var fault: Fault = .{ .underlying = wal.log() };
    var allocations: f.memory.AllocationProbe = .{ .parent = t.allocator };
    defer t.expectEqual(@as(usize, 0), allocations.live_bytes) catch unreachable;
    var owner = try Queue.open(allocations.allocator(), fault.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    const appended = try request(&declared, 2, &bytes);
    _ = try owner.enqueue(initial.declared, appended.append, appended.payload, policy.guard());
    var claim: q.Claim = .{ .target = initial.target(), .operation = operation(3), .maximum = 2, .lease_ms = 100 };
    const original = try owner.claim(initial.declared, claim, policy.guard());
    const alpha = try selectedLease(objects.objectStore(), original, 0);
    // Warm the earliest prefix, then renew its lease. The old wakeup must not
    // expire a changed lease or hide the other acquired offset.
    try t.expect(!try owner.expireOne(initial.declared, policy.guard()));
    const idle_reads = objects.range_reads;
    allocations.begin(true);
    for (0..20) |_| try t.expect(!try owner.expireOne(initial.declared, policy.guard()));
    try t.expectEqual(idle_reads, objects.range_reads);
    policy.deny_at = policy.calls + 1;
    try t.expectError(error.PermissionDenied, owner.expireOne(initial.declared, policy.guard()));
    policy.deny_at = std.math.maxInt(usize);
    clock.value = null;
    try t.expectError(error.QueueTimeUnavailable, owner.expireOne(initial.declared, policy.guard()));
    try allocations.verify();
    allocations.begin(false);
    clock.value = .exact(1050);
    _ = try owner.settle(initial.declared, .{ .operation = operation(4), .lease = alpha, .action = .{ .extend = .{ .expires_ms = 1200 } } }, policy.guard());
    const before = owner.owner.root;
    clock.value = .{ .earliest_ms = 1099, .latest_ms = 1100 };
    try t.expect(!try owner.expireOne(initial.declared, policy.guard()));
    try t.expectEqualDeep(before, owner.owner.root);
    clock.value = .exact(1100);
    clock.after = .{ .earliest_ms = 1099, .latest_ms = 1101 };
    clock.change = true;
    try t.expectError(error.QueueTimeUnavailable, owner.expireOne(initial.declared, policy.guard()));
    try t.expectEqualDeep(before, owner.owner.root);
    clock.value = .exact(1100);
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.expireOne(initial.declared, policy.guard()));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    clock.value = null;
    policy.epoch = 2;
    configured.queue_deadline_rows = 4; // Refill still obeys the smaller declared timer budget.
    owner = try Queue.open(allocations.allocator(), wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqual(@as(u64, 0), objects.puts);
    try t.expectEqualDeep(original, try owner.claim(initial.declared, claim, policy.guard()));
    var bitmap: s.BitmapDirectory = undefined;
    var queue = index(&owner, &bitmap);
    try t.expectEqual(@as(u64, 1), owner.owner.root.queue.?.active);
    try t.expectEqual(@as(u64, 1101), (try queue.item(owner.owner.root.queue.?, 1)).visible_ms);
    try t.expectEqual(@as(u64, 1200), (try queue.item(owner.owner.root.queue.?, 0)).lease.?.expires_ms);
    try t.expectError(error.QueueTimeUnavailable, owner.expireOne(initial.declared, policy.guard()));
    clock.value = .exact(1150);
    claim.operation = operation(5);
    const retry = try owner.claim(initial.declared, claim, policy.guard());
    try t.expectEqual(@as(u32, 1), retry.rows);
    const beta = try selectedLease(objects.objectStore(), retry, 0);
    try t.expect(beta.offset == 1 and beta.attempt == 2 and beta.epoch == 2);
    try t.expect(!try owner.expireOne(initial.declared, policy.guard()));
    try t.expectEqual(@as(usize, 1), owner.owner.queue_deadlines.heap.len);
    clock.value = .exact(1000000);
    var retired_definition = declared.definition;
    retired_definition.revision = 2;
    retired_definition.retired = true;
    var retired = try s.LogDeclaration.prepare(t.allocator, retired_definition);
    defer retired.deinit();
    const current = try s.LogDeclaration.stage(objects.objectStore(), &retired);
    const frontier = owner.owner.root.next_lsn;
    try t.expect(try owner.expireOne(current, policy.guard()));
    try t.expectEqual(frontier + 1, owner.owner.root.next_lsn);
    try t.expectEqual(@as(u64, 1), owner.owner.root.queue.?.active);
    queue = index(&owner, &bitmap);
    try t.expectEqual(@as(u64, 1201), (try queue.item(owner.owner.root.queue.?, 0)).visible_ms);
    try t.expect(try owner.expireOne(current, policy.guard()));
    try t.expectEqual(frontier + 2, owner.owner.root.next_lsn);
    try t.expect(owner.owner.root.queue.?.active == 0 and owner.owner.root.queue.?.blocked == 1 and owner.owner.root.queue.?.terminal == 0);
    try t.expect(!try owner.expireOne(current, policy.guard()));
    try t.expectEqual(frontier + 2, owner.owner.root.next_lsn);
    const blocked = try queue.item(owner.owner.root.queue.?, 1);
    try t.expect(blocked.blocked == .exhausted);
    clock.value = .exact(999999);
    try t.expectError(error.LogTimeRegression, owner.expireOne(current, policy.guard()));

    // Expiry may record retirement before physical flushing starts. Accepted
    // payloads still seal, archive and recover; retirement cannot revive work.
    clock.value = .exact(1000000);
    try t.expect(owner.owner.root.declared.retired and owner.owner.root.sealed_through == 0);
    claim.operation = operation(6);
    try t.expectError(error.LogDeclarationConflict, owner.claim(current, claim, policy.guard()));
    const cut = owner.owner.root.position();
    try t.expect((try owner.flush(cut, policy.guard())).complete);
    try t.expectEqual(@as(u64, 3), owner.owner.root.sealed_through);
    const archived = owner.owner.root.position();
    while (!(try owner.archive(archived, .{ .frames = 2 }, policy.guard())).complete) {}
    _ = try owner.checkpoint(owner.owner.root.position(), policy.guard());
    _ = try owner.trimArchived(policy.guard());
    try t.expectError(error.WalHistoryTrimmed, wal.log().read(t.allocator, initial.partition, 0, 1));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    clock.value = null;
    owner = try Queue.open(allocations.allocator(), wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqualDeep(original, (try owner.operation(original.claim.operation, policy.guard())).?.outcome.claim.receipt);
    var page = try owner.readClaimPage(current, .{ .receipt = original, .next = 0 }, .{ .rows = 2, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer page.deinit();
    try t.expect(page.cursor.complete() and page.len == 2);
    for (page.rows(), 0..) |row, offset| {
        try t.expectEqual(@as(u64, offset), row.lease.original.offset);
        try t.expectEqual(.available, row.lease.state);
    }
    try t.expectEqual(@as(u64, 0), objects.puts);
}

test "queue partition payload read release preserves leases and recovers its original outcome" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var declared = try declaration();
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{ .value = .exact(1000) };
    var configured = options;
    configured.clock = clock.source();
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var fault: Fault = .{ .underlying = wal.log() };
    var owner = try Queue.open(t.allocator, fault.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    const appended = try request(&declared, 2, &bytes);
    _ = try owner.enqueue(initial.declared, appended.append, appended.payload, policy.guard());
    const claimed = try owner.claim(initial.declared, .{ .target = initial.target(), .operation = operation(3), .maximum = 2, .lease_ms = 100 }, policy.guard());
    const empty = try owner.claim(initial.declared, .{ .target = initial.target(), .operation = operation(4), .maximum = 2, .lease_ms = 100 }, policy.guard());
    try t.expectEqual(@as(u32, 0), empty.rows);
    const lease = try selectedLease(objects.objectStore(), claimed, 0);
    const before = owner.owner.root;
    const release: p.QueueRead.Release = .{ .operation = operation(5), .claim = claimed };
    var forged = release;
    forged.claim.leases.?.sha256[0] ^= 1;
    try t.expectError(error.QueueClaimConflict, owner.releaseClaimRead(initial.declared, forged, policy.guard()));
    try t.expectEqualDeep(before, owner.owner.root);
    // Closure is control work and does not need trusted lease time. Current
    // authority is still checked at publication after private candidate staging.
    clock.value = null;
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.releaseClaimRead(initial.declared, release, policy.guard()));
    try t.expectEqualDeep(before, owner.owner.root);
    policy.deny_at = std.math.maxInt(usize);
    var retired_definition = declared.definition;
    retired_definition.revision = 2;
    retired_definition.retired = true;
    var retired = try s.LogDeclaration.prepare(t.allocator, retired_definition);
    defer retired.deinit();
    const current = try s.LogDeclaration.stage(objects.objectStore(), &retired);
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.releaseClaimRead(current, release, policy.guard()));
    try t.expectError(error.LogRecoveryRequired, owner.operation(release.operation, policy.guard()));
    const puts = objects.puts;
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqual(puts, objects.puts);
    const released = try owner.releaseClaimRead(current, release, policy.guard());
    var unchanged = before.queue.?;
    unchanged.read_releases = owner.owner.root.queue.?.read_releases;
    try t.expectEqualDeep(unchanged, owner.owner.root.queue.?);
    try t.expectEqualDeep(before.clock_ms, owner.owner.root.clock_ms);
    try t.expectEqualDeep(claimed, try owner.claim(current, claimed.claim, policy.guard()));
    try t.expectError(error.QueueReadReleased, owner.readClaimPage(current, .{ .receipt = claimed, .next = 0 }, .{}, t.allocator, policy.guard()));
    try t.expectError(error.QueueReadReleased, owner.readClaimPage(current, .{ .receipt = claimed, .next = claimed.rows }, .{}, t.allocator, policy.guard()));
    const empty_release: p.QueueRead.Release = .{ .operation = operation(6), .claim = empty };
    const empty_released = try owner.releaseClaimRead(current, empty_release, policy.guard());
    try t.expectError(error.QueueReadReleased, owner.readClaimPage(current, .{ .receipt = empty, .next = 0 }, .{}, t.allocator, policy.guard()));
    forged = release;
    forged.operation = operation(7);
    try t.expectError(error.QueueReadReleased, owner.releaseClaimRead(current, forged, policy.guard()));
    // Payload-read closure neither fences nor settles the still-live lease.
    clock.value = .exact(1001);
    _ = try owner.settle(current, .{ .operation = operation(7), .lease = lease, .action = .ack }, policy.guard());
    try t.expectEqual(@as(u64, 1), owner.owner.root.queue.?.terminal);
    const cut = owner.owner.root.position();
    while (!(try owner.flush(cut, policy.guard())).complete) {}
    const archived = owner.owner.root.position();
    while (!(try owner.archive(archived, .{ .frames = 2 }, policy.guard())).complete) {}
    _ = try owner.checkpoint(owner.owner.root.position(), policy.guard());
    _ = try owner.trimArchived(policy.guard());
    try t.expectError(error.WalHistoryTrimmed, wal.log().read(t.allocator, initial.partition, 0, 1));
    const accepted = owner.owner.root;
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    clock.value = null;
    owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqualDeep(accepted, owner.owner.root);
    try t.expectEqualDeep(released, try owner.releaseClaimRead(current, release, policy.guard()));
    try t.expectEqualDeep(empty_released, try owner.releaseClaimRead(current, empty_release, policy.guard()));
    try t.expectEqualDeep(claimed, (try owner.operation(claimed.claim.operation, policy.guard())).?.outcome.claim.receipt);
    try t.expectEqual(@as(u64, 0), objects.puts);
    policy.deny_at = policy.calls + 1;
    try t.expectError(error.PermissionDenied, owner.releaseClaimRead(current, release, policy.guard()));
}

test "queue partition controls verify immutable declaration bytes before acceptance" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declared = try declaration();
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{ .value = .exact(1000) };
    var configured = options;
    configured.clock = clock.source();
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    const appended = try request(&declared, 2, &bytes);
    _ = try owner.enqueue(initial.declared, appended.append, appended.payload, policy.guard());
    var invented = initial.declared;
    invented.declaration.interpretation.revision = 2;
    try invented.validate();
    var claim: q.Claim = .{ .target = initial.target(), .operation = operation(3), .maximum = 2, .lease_ms = 100 };
    claim.target.interpretation = invented.declaration.interpretation;
    const enqueued = owner.owner.root;
    try t.expectError(error.InvalidLogDeclaration, owner.claim(invented, claim, policy.guard()));
    try t.expectEqualDeep(enqueued, owner.owner.root);
    claim.target = initial.target();
    const claimed = try owner.claim(initial.declared, claim, policy.guard());
    const acquired = owner.owner.root;
    const lease = try selectedLease(objects.objectStore(), claimed, 0);
    const ack: q.Settlement = .{ .operation = operation(4), .lease = lease, .action = .ack };
    try t.expectError(error.InvalidLogDeclaration, owner.settle(invented, ack, policy.guard()));
    try t.expectEqualDeep(acquired, owner.owner.root);
    clock.value = .exact(1100);
    try t.expectError(error.InvalidLogDeclaration, owner.expireOne(invented, policy.guard()));
    try t.expectError(error.InvalidLogDeclaration, owner.scheduleMaintenanceUnit(invented, 17, policy.guard()));
    try t.expectEqualDeep(acquired, owner.owner.root);
    try t.expectEqual(acquired.next_lsn, try wal.log().tail(91));
}

test "queue partition claim pages retain original payloads with bounded current lease observations" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declared = try declaration();
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{ .value = .exact(1000) };
    var configured = options;
    configured.clock = clock.source();
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    const appended = try request(&declared, 2, &bytes);
    _ = try owner.enqueue(initial.declared, appended.append, appended.payload, policy.guard());
    var claim: q.Claim = .{ .target = initial.target(), .operation = operation(3), .maximum = 2, .lease_ms = 100 };
    const accepted = try owner.claim(initial.declared, claim, policy.guard());
    const start: p.QueueRead.Cursor = .{ .receipt = accepted, .next = 0 };
    var first = try owner.readClaimPage(initial.declared, start, .{ .rows = 1 }, t.allocator, policy.guard());
    defer first.deinit();
    try t.expectEqual(@as(usize, 1), first.rows().len);
    try t.expect(!first.cursor.complete());
    try t.expectEqual(p.QueueRead.Liveness.live, first.rows()[0].lease.liveness);
    const retained_bytes = try t.allocator.dupe(u8, first.rows()[0].encoded);
    defer t.allocator.free(retained_bytes);
    var later = try request(&declared, 4, &bytes);
    later.append.producer = null;
    _ = try owner.enqueue(initial.declared, later.append, later.payload, policy.guard());
    var second = try owner.readClaimPage(initial.declared, first.cursor, .{ .rows = 1 }, t.allocator, policy.guard());
    defer second.deinit();
    try t.expect(second.cursor.complete());
    try t.expectEqual(@as(u64, 1), second.rows()[0].lease.original.offset);
    try t.expectEqualSlices(u8, retained_bytes, first.rows()[0].encoded);
    var byte_limited = try owner.readClaimPage(initial.declared, start, .{ .encoded_bytes = first.encoded_bytes + second.encoded_bytes - 1 }, t.allocator, policy.guard());
    defer byte_limited.deinit();
    try t.expect(byte_limited.rows().len == 1 and !byte_limited.cursor.complete());
    var decoded = try f.TableRow.decode(t.allocator, declared.definition.schema, first.rows()[0].encoded);
    defer decoded.deinit();
    try t.expectEqualStrings("Alpha", decoded.row().cells[0].value.atom.bytes);
    clock.value = .exact(1100);
    var expired = try owner.readClaimPage(initial.declared, start, .{}, t.allocator, policy.guard());
    defer expired.deinit();
    try t.expectEqual(p.QueueRead.Liveness.expired, expired.rows()[0].lease.liveness);
    try t.expectEqual(@as(u64, 2), owner.owner.root.queue.?.active);
    clock.value = .exact(2000);
    try t.expect(try owner.expireOne(initial.declared, policy.guard()));
    try t.expect(try owner.expireOne(initial.declared, policy.guard()));
    claim.operation = operation(5);
    const reassigned = try owner.claim(initial.declared, claim, policy.guard());
    var original_page = try owner.readClaimPage(initial.declared, start, .{}, t.allocator, policy.guard());
    defer original_page.deinit();
    try t.expectEqual(p.QueueRead.Liveness.fenced, original_page.rows()[0].lease.liveness);
    try t.expectEqual(@as(u64, 2), original_page.rows()[0].lease.epoch);
    try t.expectEqualDeep(accepted.claim.operation, original_page.rows()[0].lease.original.claim);
    try t.expectEqualSlices(u8, retained_bytes, original_page.rows()[0].encoded);
    clock.value = null;
    var unknown = try owner.readClaimPage(initial.declared, .{ .receipt = reassigned, .next = 0 }, .{}, t.allocator, policy.guard());
    defer unknown.deinit();
    try t.expect(unknown.basis.time == null);
    try t.expectEqual(p.QueueRead.Liveness.unavailable, unknown.rows()[0].lease.liveness);
    try t.expectError(error.QueueReadBudgetExceeded, owner.readClaimPage(initial.declared, start, .{ .encoded_bytes = 1 }, t.allocator, policy.guard()));
    var forged = start;
    forged.receipt.leases.?.sha256[0] ^= 1;
    try t.expectError(error.QueueClaimConflict, owner.readClaimPage(initial.declared, forged, .{}, t.allocator, policy.guard()));
    policy.deny_at = policy.calls + 3;
    try t.expectError(error.PermissionDenied, owner.readClaimPage(initial.declared, start, .{ .rows = 1 }, t.allocator, policy.guard()));
    policy.deny_at = std.math.maxInt(usize);
    var terminal = try owner.readClaimPage(initial.declared, second.cursor, .{}, t.allocator, policy.guard());
    defer terminal.deinit();
    try t.expect(terminal.cursor.complete() and terminal.rows().len == 0);
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.readClaimPage(initial.declared, second.cursor, .{}, t.allocator, policy.guard()));
    policy.deny_at = std.math.maxInt(usize);
    clock.value = .exact(2000);
    claim.operation = operation(6);
    const empty = try owner.claim(initial.declared, claim, policy.guard());
    try t.expectEqual(@as(u32, 0), empty.rows);
    var empty_page = try owner.readClaimPage(initial.declared, .{ .receipt = empty, .next = 0 }, .{}, t.allocator, policy.guard());
    defer empty_page.deinit();
    try t.expect(empty_page.cursor.complete() and empty_page.rows().len == 0);
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.readClaimPage(initial.declared, .{ .receipt = empty, .next = 0 }, .{}, t.allocator, policy.guard()));
}

test "queue partition claim page crosses original batches with one tail slot" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var base = try declaration();
    defer base.deinit();
    var definition = base.definition;
    definition.configuration.policy.queue.ordering = .unordered;
    definition.configuration.policy.queue.key_column = null;
    var declared = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{ .value = .exact(1000) };
    var configured = options;
    configured.clock = clock.source();
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    for (2..4) |id| {
        const appended = try request(&declared, id, &bytes);
        _ = try owner.enqueue(initial.declared, appended.append, appended.payload, policy.guard());
    }
    const accepted = try owner.claim(initial.declared, .{ .target = initial.target(), .operation = operation(4), .maximum = 6, .lease_ms = 100 }, policy.guard());
    var page = try owner.readClaimPage(initial.declared, .{ .receipt = accepted, .next = 0 }, .{}, t.allocator, policy.guard());
    defer page.deinit();
    try t.expect(page.cursor.complete() and page.rows().len == 6);
    for (page.rows(), 0..) |row, i| {
        try t.expectEqual(i, row.lease.original.offset);
        try t.expectEqual(@as(u32, @intCast(i % 3)), row.ordinal);
        try t.expectEqualDeep(operation(2 + i / 3), row.operation);
        try row.lease.requireBasis(page.basis, accepted);
    }
}

test "queue partition terminal retention preserves original reads and replays expiry without writes" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var base = try declaration();
    defer base.deinit();
    var definition = base.definition;
    definition.configuration.retention.max_age_ms = 100;
    definition.configuration.policy.queue.ordering = .unordered;
    definition.configuration.policy.queue.key_column = null;
    var declared = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{ .value = .exact(1000) };
    var configured = options;
    configured.clock = clock.source();
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var fault: Fault = .{ .underlying = wal.log() };
    var owner = try Queue.open(t.allocator, fault.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    var appended: [2]q.AppendReceipt = undefined;
    for (&appended, 2..) |*receipt, id| {
        var encoder = try s.LogBatch.Encoder.init(declared.definition.schema, operation(id), .queue, 3, &bytes);
        for (0..3) |_| try encoder.append(.{ .cells = &.{ .{ .value = .{ .atom = .{ .bytes = "key" } } }, .{ .value = .{ .atom = .{ .bytes = "payload" } } } } });
        const payload = try encoder.finish();
        receipt.* = try owner.enqueue(initial.declared, .{ .target = initial.target(), .operation = operation(id), .kind = .queue, .producer = null, .rows = 3, .payload = s.LogBatch.content(payload) }, payload, policy.guard());
    }
    const cut = owner.owner.root.position();
    try t.expectEqual(Queue.ExpirationStatus.unsealed, (try owner.expireTerminalHistory(initial.declared, cut, policy.guard())).status);
    while (!(try owner.flush(cut, policy.guard())).complete) {}
    const claimed = try owner.claim(initial.declared, .{ .target = initial.target(), .operation = operation(4), .maximum = 3, .lease_ms = 1000 }, policy.guard());
    try t.expectEqual(@as(u32, 3), claimed.rows);
    var acked: [3]q.SettlementReceipt = undefined;
    for (0..2) |i| acked[i] = try owner.settle(initial.declared, .{ .operation = operation(5 + i), .lease = try selectedLease(objects.objectStore(), claimed, @intCast(i)), .action = .ack }, policy.guard());
    clock.value = .exact(1100);
    const before = owner.owner.root;
    try t.expectEqual(Queue.ExpirationStatus.nonterminal, (try owner.expireTerminalHistory(initial.declared, cut, policy.guard())).status);
    try t.expectEqualDeep(before, owner.owner.root);
    acked[2] = try owner.settle(initial.declared, .{ .operation = operation(7), .lease = try selectedLease(objects.objectStore(), claimed, 2), .action = .ack }, policy.guard());
    // A terminal segment still needs opted-in policy and trusted age. A compatible
    // candidate without retention cannot authorize expiration or change the root.
    var unlimited_definition = definition;
    unlimited_definition.revision = 2;
    unlimited_definition.configuration.retention.max_age_ms = null;
    var unlimited = try s.LogDeclaration.prepare(t.allocator, unlimited_definition);
    defer unlimited.deinit();
    const unlimited_stored = try s.LogDeclaration.stage(objects.objectStore(), &unlimited);
    try t.expectError(error.LogRetentionNotDeclared, owner.expireTerminalHistory(unlimited_stored, cut, policy.guard()));
    clock.value = null;
    try t.expectError(error.LogTimeUnavailable, owner.expireTerminalHistory(initial.declared, cut, policy.guard()));
    clock.value = .exact(1100);
    clock.after = .exact(1099);
    clock.change = true;
    try t.expectError(error.LogTimeRegression, owner.expireTerminalHistory(initial.declared, cut, policy.guard()));
    clock.value = .exact(1100);
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.expireTerminalHistory(initial.declared, cut, policy.guard()));
    policy.deny_at = std.math.maxInt(usize);
    try t.expectEqual(@as(u64, 0), owner.owner.root.retained_from);
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.expireTerminalHistory(initial.declared, cut, policy.guard()));
    const puts = objects.puts;
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqual(puts, objects.puts);
    try t.expectEqual(@as(u64, 3), owner.owner.root.retained_from);
    try t.expectEqual(Queue.ExpirationStatus.nonterminal, (try owner.expireTerminalHistory(initial.declared, cut, policy.guard())).status);
    var original_page = try owner.readClaimPage(initial.declared, .{ .receipt = claimed, .next = 0 }, .{}, t.allocator, policy.guard());
    defer original_page.deinit();
    try t.expect(original_page.cursor.complete() and original_page.rows().len == 3);
    try t.expectEqual(@as(u64, 3), original_page.basis.cut.retained_from);
    for (original_page.rows(), 0..) |row, i| {
        try t.expectEqual(i, row.lease.original.offset);
        try t.expectEqual(p.QueueRead.State.acked, row.lease.state);
        try t.expectEqualDeep(acked[i], try owner.settle(initial.declared, acked[i].settlement, policy.guard()));
    }
    const later = try owner.claim(initial.declared, .{ .target = initial.target(), .operation = operation(8), .maximum = 3, .lease_ms = 1000 }, policy.guard());
    var selection_bytes: [s.QueueSelection.max_bytes]u8 = undefined;
    const selection = try s.QueueSelection.load(t.allocator, objects.objectStore(), later.leases.?, &selection_bytes);
    try t.expectEqual(@as(u64, 3), selection.metadata.source.retained_from);
    for (0..3) |i| _ = try owner.settle(initial.declared, .{ .operation = operation(9 + i), .lease = try selection.lease(@intCast(i)), .action = .ack }, policy.guard());
    var retired_definition = definition;
    retired_definition.revision = 2;
    retired_definition.retired = true;
    var retired = try s.LogDeclaration.prepare(t.allocator, retired_definition);
    defer retired.deinit();
    const current = try s.LogDeclaration.stage(objects.objectStore(), &retired);
    const released = try owner.releaseClaimRead(current, .{ .operation = operation(12), .claim = claimed }, policy.guard());
    const later_released = try owner.releaseClaimRead(current, .{ .operation = operation(13), .claim = later }, policy.guard());
    const expired = try owner.expireTerminalHistory(current, cut, policy.guard());
    try t.expectEqual(Queue.ExpirationStatus.complete, expired.status);
    try t.expectEqual(@as(u32, 3), expired.expired_rows);
    try t.expectEqual(@as(u64, 6), expired.retained_from);
    try t.expect(owner.owner.root.batches == null and owner.owner.root.segments == null);
    try t.expectEqual(@as(u64, 6), owner.owner.root.queue.?.terminal);
    try t.expectEqual(@as(u32, 0), (try owner.expireTerminalHistory(current, cut, policy.guard())).expired_rows);
    const archived = owner.owner.root.position();
    while (!(try owner.archive(archived, .{ .frames = 2 }, policy.guard())).complete) {}
    _ = try owner.checkpoint(owner.owner.root.position(), policy.guard());
    _ = try owner.trimArchived(policy.guard());
    try t.expectError(error.WalHistoryTrimmed, wal.log().read(t.allocator, initial.partition, 0, 1));
    const accepted = owner.owner.root;
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    clock.value = null;
    owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqualDeep(accepted, owner.owner.root);
    try t.expectEqualDeep(appended[0], (try owner.operation(operation(2), policy.guard())).?.outcome.append);
    try t.expectEqualDeep(claimed, (try owner.operation(operation(4), policy.guard())).?.outcome.claim.receipt);
    try t.expectEqualDeep(released, try owner.releaseClaimRead(current, released.release, policy.guard()));
    try t.expectEqualDeep(later_released, try owner.releaseClaimRead(current, later_released.release, policy.guard()));
    try t.expectError(error.QueueReadReleased, owner.readClaimPage(current, .{ .receipt = claimed, .next = 0 }, .{}, t.allocator, policy.guard()));
    try t.expectEqual(@as(u64, 0), objects.puts);
}

test "queue partition terminal retention replay refuses removal of another live batch" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var base = try declaration();
    defer base.deinit();
    var definition = base.definition;
    definition.configuration.retention.max_age_ms = 1;
    definition.configuration.policy.queue.ordering = .unordered;
    definition.configuration.policy.queue.key_column = null;
    var declared = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{ .value = .exact(1000) };
    var configured = options;
    configured.clock = clock.source();
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var owner = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var bytes: [65536]u8 = undefined;
    for (2..5) |id| {
        const payload = try s.LogBatch.encode(declared.definition.schema, operation(id), .queue, &.{.{ .cells = &.{ .{ .value = .{ .atom = .{ .bytes = "key" } } }, .{ .value = .{ .atom = .{ .bytes = "value" } } } } }}, &bytes);
        _ = try owner.enqueue(initial.declared, .{ .target = initial.target(), .operation = operation(id), .kind = .queue, .producer = null, .rows = 1, .payload = s.LogBatch.content(payload) }, payload, policy.guard());
    }
    const claimed = try owner.claim(initial.declared, .{ .target = initial.target(), .operation = operation(5), .maximum = 1, .lease_ms = 100 }, policy.guard());
    const lease = try selectedLease(objects.objectStore(), claimed, 0);
    try t.expectEqual(@as(u64, 0), lease.offset);
    _ = try owner.settle(initial.declared, .{ .operation = operation(6), .lease = lease, .action = .ack }, policy.guard());
    const cut = owner.owner.root.position();
    while (!(try owner.flush(cut, policy.guard())).complete) {}
    clock.value = .exact(1001);
    const before = owner.owner.root;
    _ = try owner.expireTerminalHistory(initial.declared, cut, policy.guard());
    var last = try wal.log().read(t.allocator, initial.partition, before.next_lsn, 1);
    defer last.deinit();
    var record = (try s.LogPartitionRecord.decode(t.allocator, last.frames[0], initial.partition, before.next_lsn)).record;
    try t.expect(record.action == .expire);
    const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &owner.owner.store };
    try owner.owner.store.begin(options.index_work_bytes);
    record.root.batches = try tree.remove(record.root.batches, try s.LogPartitionRecord.integerKey(2));
    record.root.segments = try tree.remove(record.root.segments, try s.LogPartitionRecord.integerKey(2));
    owner.owner.store.end();
    // The expired prefix key is absent and the resulting directories are valid,
    // but this record also discards an available batch that had no expiry right.
    try record.validate(before.next_lsn);
    const forged = try s.LogPartitionRecord.encode(record, &.{}, &bytes);
    var other = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer other.deinit();
    _ = try initialize(other.log(), objects.objectStore(), &policy, &declared);
    var at: u64 = 1;
    while (at < before.next_lsn) : (at += 1) {
        var frame = try wal.log().read(t.allocator, initial.partition, at, 1);
        defer frame.deinit();
        _ = try other.log().append(initial.partition, at, 1, 1, frame.frames[0].header.kind, frame.frames[0].payload);
    }
    _ = try other.log().append(initial.partition, at, 1, 1, last.frames[0].header.kind, forged);
    var recovered = try Queue.open(t.allocator, other.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer recovered.deinit() catch unreachable;
    const puts = objects.puts;
    while (recovered.owner.root.next_lsn < before.next_lsn) _ = try recovered.recoverStep(policy.guard(), 1);
    try t.expectEqualDeep(before, recovered.owner.root);
    try t.expectError(error.InvalidLogHistory, recovered.recoverStep(policy.guard(), 1));
    try t.expectEqualDeep(before, recovered.owner.root);
    try t.expectEqual(puts, objects.puts);
    try t.expect(!recovered.owner.ready);
}

test "log transaction queue cuts retain prior claims and distinguish physical from logical progress" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declared = try declaration();
    defer declared.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var configured = options;
    configured.clock = clock.source();
    var queue = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    defer queue.deinit() catch unreachable;
    _ = try queue.recoverStep(policy.guard(), 1);
    var bytes: [8192]u8 = undefined;
    const batch = try request(&declared, 2, &bytes);
    _ = try queue.enqueue(initial.declared, batch.append, batch.payload, policy.guard());
    const claimed = try queue.claim(initial.declared, .{ .target = initial.target(), .operation = operation(3), .maximum = 1, .lease_ms = 100 }, policy.guard());
    const basis = queue.owner.root;
    try t.expectEqual(basis.next_lsn, basis.changed_lsn);
    const identity: p.Transaction.Identity = .{ .begin = operation(100), .branch = 1 };
    const pin = try queue.pinTransactionSource(initial.declared, identity, basis.position(), policy.guard());
    const original = try queue.inspectTransactionSource(pin, policy.guard());
    try t.expectEqualDeep(basis, original.root);
    while (!(try queue.flush(queue.owner.root.position(), policy.guard())).complete) {}
    while (try queue.scheduleMaintenanceUnit(initial.declared, 16, policy.guard())) {}
    try (try original.guard()).requireUnchanged(try s.LogTransaction.logGuard(queue.owner.root));
    const lease = try selectedLease(objects.objectStore(), claimed, 0);
    _ = try queue.settle(initial.declared, .{ .operation = operation(4), .lease = lease, .action = .ack }, policy.guard());
    try t.expectEqual(queue.owner.root.next_lsn, queue.owner.root.changed_lsn);
    try t.expectError(error.TransactionConflict, (try original.guard()).requireUnchanged(try s.LogTransaction.logGuard(queue.owner.root)));
    try t.expectEqualDeep(basis, (try queue.inspectTransactionSource(pin, policy.guard())).root);
    try queue.deinit();
    queue = try Queue.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), configured);
    while (!(try queue.recoverStep(policy.guard(), 2)).complete) {}
    try t.expectEqualDeep(basis, (try queue.inspectTransactionSource(pin, policy.guard())).root);
    try queue.releaseTransactionSource(pin, policy.guard());
    try t.expectError(error.LogTransactionSourceReleased, queue.inspectTransactionSource(pin, policy.guard()));
}
