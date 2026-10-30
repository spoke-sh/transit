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
    return .{ .store = &owner.owner.store, .scratch = &owner.owner.scratch, .bitmap = bitmap, .container = &owner.owner.queue_container, .key_buffer = owner.owner.key_buffer };
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
}
