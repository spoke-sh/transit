const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const s = @import("root.zig");
const q = p.StreamQueue;
const support = @import("log_test_support.zig");
const Stream = s.StreamPartition;
const options: Stream.Options = .{ .resident_pages = 1, .batch_bytes = 8192, .key_bytes = 256, .tail = .{ .slots = 1, .borrow_slots = 2, .slot_bytes = 8192, .resident_bytes = 16384 } };
const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "AbC" } } }, .{ .value = .{ .atom = .{ .bytes = "payload" } } } };
const Policy = struct {
    calls: usize = 0,
    deny_at: usize = std.math.maxInt(usize),
    epoch: u64 = 1,
    held: bool = false,
    fn guard(self: *Policy) s.PublicationGuard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
    fn acquire(context: *anyopaque) !s.PublicationGuard.Fence {
        const self: *Policy = @ptrCast(@alignCast(context));
        try t.expect(!self.held);
        self.calls += 1;
        if (self.calls >= self.deny_at) return error.PermissionDenied;
        self.held = true;
        return .{ .writer_epoch = self.epoch, .policy_epoch = self.epoch };
    }
    fn release(context: *anyopaque) void {
        const self: *Policy = @ptrCast(@alignCast(context));
        t.expect(self.held) catch unreachable;
        self.held = false;
    }
};
const Clock = struct {
    value: ?u64 = 100,
    after: ?u64 = null,
    change: bool = false,
    error_ms: u64 = 0,
    after_error_ms: ?u64 = null,
    fn source(self: *Clock) s.LogTime.Source {
        return .{ .context = self, .read = sample };
    }
    fn sample(raw: *anyopaque) !?s.LogTime.Sample {
        const self: *Clock = @ptrCast(@alignCast(raw));
        const result = self.value;
        const uncertainty = self.error_ms;
        if (self.change) {
            self.value = self.after;
            self.change = false;
            if (self.after_error_ms) |next| self.error_ms = next;
        }
        return if (result) |now| .{ .earliest_ms = now -| uncertainty, .latest_ms = now +| uncertainty } else null;
    }
};
fn operation(id: u64) p.DataLifecycle.Operation {
    return .{ .scope = support.definition(.stream).object.scope, .principal = 0, .operation = id };
}
fn initialize(wal: s.TransitLog.Log, objects: s.TransitObjectStore.ObjectStore, policy: *Policy, declaration: *const s.LogDeclaration.Owned) !s.LogInitialization.Request {
    const request: s.LogInitialization.Request = .{ .definition = p.Growth.current_definition, .declared = try s.LogDeclaration.stage(objects, declaration), .operation = operation(1), .ordinal = 1, .partition = 91 };
    _ = try s.LogInitialization.initialize(t.allocator, wal, objects, request, policy.guard());
    return request;
}
fn appendRequest(declaration: *const s.LogDeclaration.Owned, id: u64, producer: ?q.Producer, buffer: []u8) !struct { request: q.Append, payload: []const u8 } {
    const bytes = try s.LogBatch.encode(declaration.definition.schema, operation(id), .stream, &.{ .{ .cells = &cells }, .{ .cells = &cells } }, buffer);
    return .{ .request = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = (try declaration.stored()).declaration.interpretation, .partition = 1 }, .operation = operation(id), .kind = .stream, .producer = producer, .rows = 2, .payload = s.LogBatch.content(bytes) }, .payload = bytes };
}
fn reopen(wal: s.TransitLog.Log, objects: s.TransitObjectStore.ObjectStore, request: s.LogInitialization.Request, policy: *Policy) !Stream {
    return Stream.open(t.allocator, wal, objects, request, policy.guard(), options);
}

test "stream partition disk recovery preserves offsets producer receipts and bounded borrowed reads" {
    var temporary = t.tmpDir(.{});
    defer temporary.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, temporary.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, temporary.dir, "objects");
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    try t.expectError(error.LogRecoveryRequired, owner.observe(initial.declared, policy.guard()));
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    const initial_cut = try owner.observe(initial.declared, policy.guard());
    const assignment: q.GroupAssignment = .{ .operation = operation(2), .cut = initial_cut, .expected = null, .group = .{ .id = 7, .generation = 1, .principal = 0 }, .next = 0 };
    const assigned = try owner.assign(initial.declared, assignment, policy.guard());
    try t.expectEqual(@as(u64, 2), assigned.accepted.next_lsn);
    var buffer: [8192]u8 = undefined;
    var producer: q.Producer = .{ .id = @splat(4), .epoch = 1, .sequence = 1 };
    const first = try appendRequest(&declaration, std.math.maxInt(u64), producer, &buffer);
    const accepted = try owner.append(initial.declared, first.request, first.payload, policy.guard());
    try t.expectEqual(@as(u64, 0), accepted.first);
    try t.expectEqual(@as(u64, 2), accepted.next);
    try t.expectEqual(@as(u64, 3), accepted.accepted.next_lsn);
    const original = accepted.append;
    const root = owner.root;
    for (0..3) |_| try t.expectEqualDeep(accepted, try owner.append(initial.declared, first.request, first.payload, policy.guard()));
    try t.expectEqualDeep(root, owner.root);
    var read = (try owner.readBatch(initial.declared, 1, policy.guard())).?;
    try t.expectEqualSlices(u8, first.payload, try read.payload.bytes());
    try t.expectError(error.OutstandingTailBorrows, owner.deinit());
    producer.sequence = 2;
    const second = try appendRequest(&declaration, 4, producer, &buffer);
    const accepted_second = try owner.append(initial.declared, second.request, second.payload, policy.guard());
    try t.expectEqual(@as(u64, 2), accepted_second.first);
    try t.expectEqual(@as(u64, 4), accepted_second.next);
    try t.expectError(error.TailCachePinned, owner.readBatch(initial.declared, 2, policy.guard()));
    read.deinit();
    read = (try owner.readBatch(initial.declared, 2, policy.guard())).?;
    try t.expectEqualDeep(accepted_second, read.receipt);
    read.deinit();
    try t.expectEqual(@as(?Stream.BorrowedBatch, null), try owner.readBatch(initial.declared, 4, policy.guard()));
    try t.expectError(error.LogOffsetBeyondCut, owner.readBatch(initial.declared, 5, policy.guard()));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, temporary.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, temporary.dir, "objects");
    policy.epoch = 2;
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    try t.expect(!(try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectError(error.LogRecoveryRequired, owner.observe(initial.declared, policy.guard()));
    try t.expect(!(try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqualDeep(accepted, (try owner.operation(original.operation, policy.guard())).?.outcome.append);
    try t.expectEqualDeep(assigned, try owner.assign(initial.declared, assignment, policy.guard()));
    try t.expectEqualDeep(try assignment.resulting(), (try owner.group(7, policy.guard())).?);
    read = (try owner.readBatch(initial.declared, 0, policy.guard())).?;
    var rows = try s.LogBatch.Iterator.init(try read.payload.bytes(), declaration.definition.schema, .stream, 2);
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    const decoded = try (try rows.next()).?.decode(output.allocator(), declaration.definition.schema, original.operation);
    read.deinit();
    read = (try owner.readBatch(initial.declared, 2, policy.guard())).?;
    read.deinit();
    try t.expectEqualStrings("payload", decoded.cells[1].value.atom.bytes);
    try t.expectEqual(@as(u64, 0), wal.appends);
}

test "stream partition fences producer sequences and preserves exact retries across definition edits" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    var producer: q.Producer = .{ .id = @splat(4), .epoch = 1, .sequence = 2 };
    var request = try appendRequest(&declaration, 2, producer, &buffer);
    try t.expectError(error.LogProducerSequenceGap, owner.append(initial.declared, request.request, request.payload, policy.guard()));
    producer.sequence = 1;
    request = try appendRequest(&declaration, 2, producer, &buffer);
    const accepted = try owner.append(initial.declared, request.request, request.payload, policy.guard());
    request = try appendRequest(&declaration, 3, producer, &buffer);
    try t.expectError(error.LogProducerConflict, owner.append(initial.declared, request.request, request.payload, policy.guard()));
    producer.sequence = 3;
    request = try appendRequest(&declaration, 3, producer, &buffer);
    try t.expectError(error.LogProducerSequenceGap, owner.append(initial.declared, request.request, request.payload, policy.guard()));
    producer.epoch = 2;
    producer.sequence = 1;
    request = try appendRequest(&declaration, 3, producer, &buffer);
    _ = try owner.append(initial.declared, request.request, request.payload, policy.guard());
    producer.epoch = 1;
    producer.sequence = 2;
    request = try appendRequest(&declaration, 4, producer, &buffer);
    try t.expectError(error.LogProducerFenced, owner.append(initial.declared, request.request, request.payload, policy.guard()));
    var changed = support.definition(.stream);
    changed.revision = 2;
    changed.configuration.retention.max_age_ms = 1000;
    var revised = try s.LogDeclaration.prepare(t.allocator, changed);
    defer revised.deinit();
    const stored = try s.LogDeclaration.stage(objects.objectStore(), &revised);
    var clock: Clock = .{};
    owner.options.clock = clock.source();
    request = try appendRequest(&revised, 5, null, &buffer);
    _ = try owner.append(stored, request.request, request.payload, policy.guard());
    request = try appendRequest(&declaration, 2, accepted.append.producer, &buffer);
    try t.expectEqualDeep(accepted, try owner.append(stored, request.request, request.payload, policy.guard()));
    request = try appendRequest(&declaration, 6, null, &buffer);
    try t.expectError(error.LogDeclarationConflict, owner.append(initial.declared, request.request, request.payload, policy.guard()));
    request = try appendRequest(&revised, 2, null, &buffer);
    try t.expectError(error.LogAppendConflict, owner.append(stored, request.request, request.payload, policy.guard()));
    try t.expectEqual(@as(u64, 6), owner.root.next_offset);
}

test "stream partition rechecks authorization before publishing and after buffering including empty reads" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const request = try appendRequest(&declaration, 2, null, &buffer);
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.append(initial.declared, request.request, request.payload, policy.guard()));
    try t.expectEqual(@as(u64, 1), try wal.log().tail(91));
    try t.expectEqual(@as(u64, 0), owner.root.next_offset);
    policy.deny_at = std.math.maxInt(usize);
    _ = try owner.append(initial.declared, request.request, request.payload, policy.guard());
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.readBatch(initial.declared, 0, policy.guard()));
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.readBatch(initial.declared, 2, policy.guard()));
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.operation(operation(2), policy.guard()));
    policy.deny_at = std.math.maxInt(usize);
    // A newer fence rejects before any additional acceptance, and invalidates
    // resident readiness so subsequent requests must recover the original log.
    try wal.log().fence(91, 3, 3);
    const newer = try appendRequest(&declaration, 3, null, &buffer);
    try t.expectError(error.StaleWriterEpoch, owner.append(initial.declared, newer.request, newer.payload, policy.guard()));
    try t.expectError(error.LogRecoveryRequired, owner.observe(initial.declared, policy.guard()));
    try t.expectEqual(@as(u64, 2), try wal.log().tail(91));
    policy.epoch = 3;
    _ = try owner.recoverStep(policy.guard(), 1);
    _ = try owner.append(initial.declared, newer.request, newer.payload, policy.guard());
}

const Fault = struct {
    underlying: s.TransitLog.Log,
    lose_reply: bool = true,
    fn log(self: *Fault) s.TransitLog.Log {
        return .{ .context = self, .vtable = &.{ .append = append, .read = read, .tail = tail, .trim = trim, .fence = fence } };
    }
    fn cast(context: *anyopaque) *Fault {
        return @ptrCast(@alignCast(context));
    }
    fn append(context: *anyopaque, partition: u64, expected: ?u64, writer: u64, policy: u64, kind: s.TransitLog.FrameKind, bytes: []const u8) !s.TransitLog.AppendReceipt {
        const self = cast(context);
        const accepted = try self.underlying.append(partition, expected, writer, policy, kind, bytes);
        if (self.lose_reply) {
            self.lose_reply = false;
            return error.InjectedReplyLoss;
        }
        return accepted;
    }
    fn read(context: *anyopaque, allocator: std.mem.Allocator, partition: u64, from: u64, count: usize) !s.TransitLog.Log.OwnedBatch {
        return cast(context).underlying.read(allocator, partition, from, count);
    }
    fn tail(context: *anyopaque, partition: u64) !u64 {
        return cast(context).underlying.tail(partition);
    }
    fn trim(context: *anyopaque, partition: u64, until: u64) !void {
        return cast(context).underlying.trim(partition, until);
    }
    fn fence(context: *anyopaque, partition: u64, writer: u64, policy: u64) !void {
        return cast(context).underlying.fence(partition, writer, policy);
    }
};

test "stream partition lost reply survives disk restart and backlog exceeds every resident cache" {
    var temporary = t.tmpDir(.{});
    defer temporary.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, temporary.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, temporary.dir, "objects");
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var fault: Fault = .{ .underlying = wal.log() };
    var owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var original_buffer: [8192]u8 = undefined;
    const original = try appendRequest(&declaration, 2, .{ .id = @splat(0x41), .epoch = 1, .sequence = 1 }, &original_buffer);
    try t.expectError(error.LogAppendUncertain, owner.append(initial.declared, original.request, original.payload, policy.guard()));
    try t.expectEqual(@as(u64, 2), try wal.log().tail(91));
    try t.expectEqual(@as(u64, 0), owner.root.next_offset);
    try t.expectError(error.LogRecoveryRequired, owner.append(initial.declared, original.request, original.payload, policy.guard()));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, temporary.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, temporary.dir, "objects");
    fault.underlying = wal.log();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    const accepted = try owner.append(initial.declared, original.request, original.payload, policy.guard());
    try t.expectEqual(@as(u64, 0), accepted.first);
    try t.expectEqual(@as(u64, 2), accepted.next);
    try t.expectEqual(@as(u64, 0), wal.appends);
    const resident_bytes = owner.store.residentBytes();
    var buffer: [8192]u8 = undefined;
    for (3..35) |id| {
        const request = try appendRequest(&declaration, id, .{ .id = @splat(0x41), .epoch = 1, .sequence = id - 1 }, &buffer);
        const receipt = try owner.append(initial.declared, request.request, request.payload, policy.guard());
        try t.expectEqual(@as(u64, id - 2) * 2, receipt.first);
        try t.expectEqual(@as(u64, id - 1) * 2, receipt.next);
    }
    try t.expectEqual(resident_bytes, owner.store.residentBytes());
    try t.expectEqual(@as(usize, 1), owner.store.cache.len);
    try owner.deinit();
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    var recovered: u64 = 0;
    while (true) {
        const step = try owner.recoverStep(policy.guard(), 3);
        try t.expect(step.examined <= 3);
        recovered += step.examined;
        if (step.complete) break;
    }
    try t.expectEqual(@as(u64, 33), recovered);
    try t.expectEqualDeep(accepted, try owner.append(initial.declared, original.request, original.payload, policy.guard()));
    for (0..33) |index| {
        var read = (try owner.readBatch(initial.declared, index * 2, policy.guard())).?;
        defer read.deinit();
        try t.expectEqual(@as(u64, index * 2), read.receipt.first);
        var iterator = try s.LogBatch.Iterator.init(try read.payload.bytes(), declaration.definition.schema, .stream, 2);
        try t.expect(try iterator.next() != null);
        try t.expect(try iterator.next() != null);
        try t.expectEqual(@as(?s.LogBatch.EncodedRow, null), try iterator.next());
    }
    try t.expectEqual(@as(u64, 32), wal.appends);
}

test "stream partition group reassignment fences generations without resetting progress or replaying control" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const request = try appendRequest(&declaration, 2, null, &buffer);
    _ = try owner.append(initial.declared, request.request, request.payload, policy.guard());
    const cut = try owner.observe(initial.declared, policy.guard());
    const first: q.GroupAssignment = .{ .operation = operation(3), .cut = cut, .expected = null, .group = .{ .id = std.math.maxInt(u64), .generation = 1, .principal = 7 }, .next = 1 };
    const original = try owner.assign(initial.declared, first, policy.guard());
    var second = first;
    second.operation.operation = 4;
    second.group.generation = 2;
    second.group.principal = 8;
    second.expected = try first.resulting();
    _ = try owner.assign(initial.declared, second, policy.guard());
    var conflict = second;
    conflict.operation.operation = 5;
    try t.expectError(error.LogGroupAssignmentConflict, owner.assign(initial.declared, conflict, policy.guard()));
    try t.expectEqualDeep(original, try owner.assign(initial.declared, first, policy.guard()));
    try owner.deinit();
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    try t.expect((try owner.recoverStep(policy.guard(), 8)).complete);
    try t.expectEqualDeep(try second.resulting(), (try owner.group(first.group.id, policy.guard())).?);
    try t.expectEqual(@as(u64, 2), owner.root.next_offset);
    try t.expectEqual(@as(u64, 4), owner.root.next_lsn);
}

test "stream partition warmed tail reads reuse metadata scratch without heap allocation" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var counted = t.FailingAllocator.init(t.allocator, .{});
    var owner = try Stream.open(counted.allocator(), wal.log(), objects.objectStore(), initial, policy.guard(), options);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const request = try appendRequest(&declaration, 2, null, &buffer);
    _ = try owner.append(initial.declared, request.request, request.payload, policy.guard());
    for (0..2) |_| {
        var read = (try owner.readBatch(initial.declared, 0, policy.guard())).?;
        read.deinit();
    }
    const allocations = counted.alloc_index;
    counted.fail_index = allocations;
    const verifications = owner.cache.verified;
    for (0..32) |_| {
        var read = (try owner.readBatch(initial.declared, 1, policy.guard())).?;
        defer read.deinit();
        try t.expectEqualSlices(u8, request.payload, try read.payload.bytes());
    }
    try t.expectEqual(allocations, counted.alloc_index);
    try t.expectEqual(verifications, owner.cache.verified);
}

test "stream partition missing published evidence blocks recovery without resetting accepted history" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const request = try appendRequest(&declaration, 2, null, &buffer);
    const receipt = try owner.append(initial.declared, request.request, request.payload, policy.guard());
    const evidence: s.LogEvidence.Record = .{ .declared = initial.declared, .outcome = .{ .append = receipt } };
    const reference = try s.LogEvidence.expectedReference(evidence);
    const content = try s.LogEvidence.decodeReference(reference);
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try s.LogEvidence.key(content, &name));
    try owner.deinit();
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    try t.expectError(error.LogEvidenceMissing, owner.recoverStep(policy.guard(), 1));
    try t.expectError(error.LogRecoveryRequired, owner.readBatch(initial.declared, 0, policy.guard()));
    try t.expectEqual(@as(u64, 2), try wal.log().tail(91));
    try t.expectEqual(@as(u64, 1), owner.root.next_lsn);
    _ = try s.LogEvidence.stage(objects.objectStore(), evidence);
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqualDeep(receipt, (try owner.operation(operation(2), policy.guard())).?.outcome.append);
}

test "stream partition pins finite cuts and atomically commits authenticated consumer coverage after restart" {
    var temporary = t.tmpDir(.{});
    defer temporary.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, temporary.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, temporary.dir, "objects");
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var fault: Fault = .{ .underlying = wal.log(), .lose_reply = false };
    var owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    const assignment: q.GroupAssignment = .{ .operation = operation(2), .cut = try owner.observe(initial.declared, policy.guard()), .expected = null, .group = .{ .id = 7, .generation = 1, .principal = 0 }, .next = 0 };
    _ = try owner.assign(initial.declared, assignment, policy.guard());
    var buffer: [8192]u8 = undefined;
    for (3..5) |id| {
        const request = try appendRequest(&declaration, id, null, &buffer);
        _ = try owner.append(initial.declared, request.request, request.payload, policy.guard());
    }
    const selection: p.StreamRead.Request = .{ .target = initial.target(), .operation = operation(5), .group = assignment.group, .from = 0, .until = null, .timestamp = null };
    const read = try owner.beginRead(initial.declared, selection, policy.guard());
    try t.expectEqual(@as(u64, 4), read.cut.next);
    const later = try appendRequest(&declaration, 6, null, &buffer);
    _ = try owner.append(initial.declared, later.request, later.payload, policy.guard());
    try t.expectEqualDeep(read, try owner.beginRead(initial.declared, selection, policy.guard()));
    const authority = try s.LogRead.Authority.init(@splat(7));
    const start = try owner.readCursor(read.handle(), authority, policy.guard());
    var first = try owner.readPage(start, authority, .{ .rows = 3, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer first.deinit();
    try t.expectEqual(@as(u32, 3), first.count);
    try t.expectEqual(@as(u64, 3), first.cursor.coverage.through);
    try t.expect(!first.cursor.coverage.complete);
    for (first.rows(), 0..) |row, index| try t.expectEqual(@as(u64, index), row.offset);
    var commit: q.OffsetCommit = .{ .operation = operation(7), .group = assignment.group, .coverage = first.cursor.coverage, .expected_next = 0, .next = 4 };
    try t.expectError(error.InvalidOffsetCommit, owner.commitOffset(initial.declared, commit, first.cursor, authority, policy.guard()));
    var forged = first.cursor;
    forged.coverage.through = 4;
    forged.coverage.complete = true;
    commit.coverage = forged.coverage;
    try t.expectError(error.StreamCursorUnauthenticated, owner.commitOffset(initial.declared, commit, forged, authority, policy.guard()));
    // Continuation retains the original cut after all resident reader state is
    // gone; the output from the earlier page remains independently owned.
    try owner.deinit();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    try t.expect((try owner.recoverStep(policy.guard(), 16)).complete);
    var last = try owner.readPage(first.cursor, authority, .{ .rows = 3, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer last.deinit();
    try t.expectEqual(@as(u32, 1), last.count);
    try t.expectEqual(@as(u64, 4), last.cursor.coverage.through);
    try t.expectEqual(@as(u64, 4), last.cursor.coverage.rows);
    try t.expect(last.cursor.coverage.complete);
    var terminal = try owner.readPage(last.cursor, authority, .{ .rows = 3, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer terminal.deinit();
    try t.expectEqual(@as(u32, 0), terminal.count);
    try t.expectEqualDeep(last.cursor, terminal.cursor);
    // The retained output survives a different cache slab admission and owner
    // destruction; later appends cannot be spliced into this finite result.
    var decoded = std.heap.ArenaAllocator.init(t.allocator);
    defer decoded.deinit();
    const row = try first.rows()[0].encoded.decode(decoded.allocator(), declaration.definition.schema, first.rows()[0].operation);
    try t.expectEqualStrings("payload", row.cells[1].value.atom.bytes);
    commit.coverage = last.cursor.coverage;
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.commitOffset(initial.declared, commit, last.cursor, authority, policy.guard()));
    try t.expectError(error.LogRecoveryRequired, owner.group(7, policy.guard()));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, temporary.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, temporary.dir, "objects");
    fault.underlying = wal.log();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    try t.expect((try owner.recoverStep(policy.guard(), 16)).complete);
    try t.expectEqual(@as(u64, 4), (try owner.group(7, policy.guard())).?.next);
    const accepted = try owner.commitOffset(initial.declared, commit, last.cursor, authority, policy.guard());
    try t.expectEqual(@as(u64, 0), wal.appends);
    var duplicate_progress = commit;
    duplicate_progress.operation.operation = 70;
    try t.expectError(error.LogOffsetConflict, owner.commitOffset(initial.declared, duplicate_progress, last.cursor, authority, policy.guard()));
    var reassignment = assignment;
    reassignment.operation.operation = 9;
    reassignment.cut = try owner.observe(initial.declared, policy.guard());
    reassignment.expected = (try owner.group(7, policy.guard())).?;
    reassignment.group.generation += 1;
    reassignment.next = 4;
    _ = try owner.assign(initial.declared, reassignment, policy.guard());
    try t.expectError(error.LogGroupFenced, owner.readPage(last.cursor, authority, .{ .rows = 3, .encoded_bytes = 8192 }, t.allocator, policy.guard()));
    try t.expectError(error.LogGroupFenced, owner.commitOffset(initial.declared, duplicate_progress, last.cursor, authority, policy.guard()));
    const release: p.StreamRead.Release = .{ .target = initial.target(), .operation = operation(8), .read = read.handle() };
    const released = try owner.releaseRead(initial.declared, release, policy.guard());
    try t.expectError(error.StreamReadReleased, owner.readCursor(read.handle(), authority, policy.guard()));
    // A rotated key and closed pin cannot rewrite an already accepted result.
    try t.expectEqualDeep(accepted, try owner.commitOffset(initial.declared, commit, last.cursor, try s.LogRead.Authority.init(@splat(8)), policy.guard()));
    try t.expectEqualDeep(released, try owner.releaseRead(initial.declared, release, policy.guard()));
    try owner.deinit();
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    try t.expect((try owner.recoverStep(policy.guard(), 16)).complete);
    try t.expectEqual(@as(u64, 4), (try owner.group(7, policy.guard())).?.next);
    try t.expectEqual(@as(u64, 2), (try owner.group(7, policy.guard())).?.group.generation);
    try t.expectEqualDeep(accepted, try owner.commitOffset(initial.declared, commit, last.cursor, authority, policy.guard()));
    try t.expectEqual(@as(u64, 2), wal.appends);
}

test "stream partition finite readers enforce budgets early release empty completion and buffered revocation" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const request = try appendRequest(&declaration, 2, null, &buffer);
    _ = try owner.append(initial.declared, request.request, request.payload, policy.guard());
    const selection: p.StreamRead.Request = .{ .target = initial.target(), .operation = operation(3), .group = null, .from = 1, .until = null, .timestamp = null };
    const retained = try owner.beginRead(initial.declared, selection, policy.guard());
    const authority = try s.LogRead.Authority.init(@splat(7));
    const start = try owner.readCursor(retained.handle(), authority, policy.guard());
    try t.expectError(error.StreamReadByteBudgetTooSmall, owner.readPage(start, authority, .{ .rows = 1, .encoded_bytes = 1 }, t.allocator, policy.guard()));
    try t.expectError(error.InvalidStreamReadBudget, owner.readPage(start, authority, .{ .rows = 0, .encoded_bytes = 8192 }, t.allocator, policy.guard()));
    policy.deny_at = policy.calls + 3;
    try t.expectError(error.PermissionDenied, owner.readPage(start, authority, .{ .rows = 1, .encoded_bytes = 8192 }, t.allocator, policy.guard()));
    policy.deny_at = std.math.maxInt(usize);
    var page = try owner.readPage(start, authority, .{ .rows = 1, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer page.deinit();
    try t.expectEqual(@as(u64, 1), page.rows()[0].offset);
    try t.expect(page.cursor.coverage.complete);
    _ = try owner.releaseRead(initial.declared, .{ .target = initial.target(), .operation = operation(4), .read = retained.handle() }, policy.guard());
    try t.expectError(error.StreamReadReleased, owner.readPage(start, authority, .{ .rows = 1, .encoded_bytes = 8192 }, t.allocator, policy.guard()));
    var partial_selection = selection;
    partial_selection.operation.operation = 6;
    partial_selection.from = 0;
    const partial_read = try owner.beginRead(initial.declared, partial_selection, policy.guard());
    const partial_cursor = try owner.readCursor(partial_read.handle(), authority, policy.guard());
    var partial = try owner.readPage(partial_cursor, authority, .{ .rows = 2, .encoded_bytes = page.encoded_bytes }, t.allocator, policy.guard());
    defer partial.deinit();
    try t.expectEqual(@as(u32, 1), partial.count);
    try t.expect(!partial.cursor.coverage.complete);
    try t.expectEqual(@as(u64, 1), partial.cursor.coverage.through);
    _ = try owner.releaseRead(initial.declared, .{ .target = initial.target(), .operation = operation(7), .read = partial_read.handle() }, policy.guard());
    try t.expectError(error.StreamReadReleased, owner.readPage(partial.cursor, authority, .{ .rows = 1, .encoded_bytes = 8192 }, t.allocator, policy.guard()));
    var empty = selection;
    empty.operation.operation = 5;
    empty.from = 2;
    const empty_read = try owner.beginRead(initial.declared, empty, policy.guard());
    const empty_cursor = try owner.readCursor(empty_read.handle(), authority, policy.guard());
    try t.expect(empty_cursor.coverage.complete);
    var empty_page = try owner.readPage(empty_cursor, authority, .{ .rows = 1, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer empty_page.deinit();
    try t.expectEqual(@as(u32, 0), empty_page.count);
    try t.expectEqual(@as(u64, 0), empty_page.cursor.coverage.rows);
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.readPage(empty_cursor, authority, .{ .rows = 1, .encoded_bytes = 8192 }, t.allocator, policy.guard()));
}

test "stream partition checkpoint and archive retain exact pins receipts and initialization through physical trim" {
    var temporary = t.tmpDir(.{});
    defer temporary.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, temporary.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, temporary.dir, "objects");
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    const initialized = try s.LogInitialization.observe(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard());
    var fault: Fault = .{ .underlying = wal.log(), .lose_reply = false };
    var owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const request = try appendRequest(&declaration, 2, null, &buffer);
    const accepted = try owner.append(initial.declared, request.request, request.payload, policy.guard());
    const pin = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(3), .group = null, .from = 0, .until = null, .timestamp = null }, policy.guard());
    const authority = try s.LogRead.Authority.init(@splat(7));
    const cursor = try owner.readCursor(pin.handle(), authority, policy.guard());
    const cut = owner.root.position();
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.archive(cut, .{ .frames = 1 }, policy.guard()));
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqual(@as(u64, 1), owner.root.archive.through);
    try t.expectError(error.LogCheckpointRequired, owner.trimArchived(policy.guard()));
    while (!(try owner.archive(cut, .{ .frames = 1 }, policy.guard())).complete) {}
    const writes = wal.appends;
    try t.expectEqual(@as(u8, 0), (try owner.archive(cut, .{ .frames = 1 }, policy.guard())).frames);
    try t.expectEqual(writes, wal.appends);
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.checkpoint(cut, policy.guard()));
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    const checkpoint = try owner.checkpoint(cut, policy.guard());
    try t.expectEqual(cut.next_lsn, try owner.trimArchived(policy.guard()));
    try t.expectError(error.WalHistoryTrimmed, wal.log().read(t.allocator, 91, 0, 1));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, temporary.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, temporary.dir, "objects");
    fault.underlying = wal.log();
    policy.epoch = 2;
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    const recovered = try owner.recoverStep(policy.guard(), 1);
    try t.expect(recovered.complete);
    try t.expectEqual(@as(u16, 1), recovered.examined);
    try t.expectEqualDeep(initialized, try s.LogInitialization.initialize(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard()));
    try t.expectEqualDeep(accepted, (try owner.operation(operation(2), policy.guard())).?.outcome.append);
    var page = try owner.readPage(cursor, authority, .{ .rows = 2, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer page.deinit();
    try t.expectEqual(@as(u32, 2), page.count);
    try t.expect(page.cursor.coverage.complete);
    try t.expectEqual(@as(u64, 0), wal.appends);
    const later = try appendRequest(&declaration, 4, null, &buffer);
    _ = try owner.append(initial.declared, later.request, later.payload, policy.guard());
    const newer_cut = owner.root.position();
    const newer = try owner.checkpoint(newer_cut, policy.guard());
    try t.expect(newer.next_lsn > checkpoint.next_lsn);
    while (!(try owner.archive(newer_cut, .{ .frames = 3 }, policy.guard())).complete) {}
    try t.expectEqual(newer_cut.next_lsn, try owner.trimArchived(policy.guard()));
    // The superseded reference inside the new baseline is structural metadata;
    // recovery may not recursively retain or open every earlier checkpoint.
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try s.LogRecovery.key(checkpoint.content, &name));
    try owner.deinit();
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    try t.expect((try owner.recoverStep(policy.guard(), 3)).complete);
    var replay = try owner.readPage(cursor, authority, .{ .rows = 2, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer replay.deinit();
    try t.expectEqualDeep(page.cursor, replay.cursor);
    try t.expectEqualDeep(accepted, (try owner.operation(operation(2), policy.guard())).?.outcome.append);
    try objects.objectStore().delete(try s.LogRecovery.key(newer.content, &name));
    try t.expectError(error.LogRecoveryMissing, reopen(wal.log(), objects.objectStore(), initial, &policy));
}

test "stream partition sealed batches preserve finite reads and resume lost flush publication" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var fault: Fault = .{ .underlying = wal.log(), .lose_reply = false };
    var owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const first = try appendRequest(&declaration, 2, null, &buffer);
    const accepted = try owner.append(initial.declared, first.request, first.payload, policy.guard());
    const pin = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(3), .group = null, .from = 0, .until = null, .timestamp = null }, policy.guard());
    const authority = try s.LogRead.Authority.init(@splat(7));
    const cursor = try owner.readCursor(pin.handle(), authority, policy.guard());
    const cut = owner.root.position();
    const before = owner.root;
    owner.options.segment_work_bytes = 4096;
    try t.expectError(error.LogSegmentBudgetExceeded, owner.flush(cut, policy.guard()));
    try t.expectEqualDeep(before, owner.root);
    owner.options.segment_work_bytes = 64 * 1024 * 1024;
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.flush(cut, policy.guard()));
    try t.expectEqualDeep(before, owner.root);
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqual(@as(u64, 2), owner.root.sealed_through);
    const appended = wal.appends;
    const complete = try owner.flush(cut, policy.guard());
    try t.expect(complete.complete and complete.rows == 0);
    try t.expectEqual(appended, wal.appends);
    const second = try appendRequest(&declaration, 4, null, &buffer);
    _ = try owner.append(initial.declared, second.request, second.payload, policy.guard());
    try t.expect((try owner.flush(cut, policy.guard())).complete);
    try t.expectEqual(@as(u64, 2), owner.root.sealed_through);
    const mixed = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(5), .group = null, .from = 0, .until = null, .timestamp = null }, policy.guard());
    const mixed_cursor = try owner.readCursor(mixed.handle(), authority, policy.guard());
    const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &owner.store };
    const segment = try s.LogSegment.Descriptor.decode((try tree.get(owner.root.segments, try s.LogPartitionRecord.integerKey(2))).?);
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    fault.underlying = wal.log();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    var page = try owner.readPage(mixed_cursor, authority, .{ .rows = 3, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer page.deinit();
    try t.expectEqual(@as(u32, 3), page.count);
    try t.expect(!page.cursor.coverage.complete);
    try t.expectEqual(operation(2), page.rows()[0].operation);
    try t.expectEqual(operation(4), page.rows()[2].operation);
    var end = try owner.readPage(page.cursor, authority, .{ .rows = 3, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer end.deinit();
    try t.expectEqual(@as(u32, 1), end.count);
    try t.expect(end.cursor.coverage.complete);
    // Output from the earlier physical batch remains owned after cache reuse.
    var decoded = std.heap.ArenaAllocator.init(t.allocator);
    defer decoded.deinit();
    const row = try page.rows()[0].encoded.decode(decoded.allocator(), declaration.definition.schema, operation(2));
    try t.expectEqualStrings("payload", row.cells[1].value.atom.bytes);
    var old = try owner.readPage(cursor, authority, .{ .rows = 3, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer old.deinit();
    try t.expect(old.cursor.coverage.complete and old.count == 2);
    try t.expectEqualDeep(accepted, (try owner.operation(operation(2), policy.guard())).?.outcome.append);
    var name: [96]u8 = undefined;
    const key = try s.LogSegment.metadataKey(segment.metadata, &name);
    const metadata = try t.allocator.alloc(u8, @intCast(segment.metadata.bytes));
    defer t.allocator.free(metadata);
    _ = try objects.objectStore().getRange(key, 0, @intCast(metadata.len), metadata);
    try objects.objectStore().delete(key);
    try owner.deinit();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    try t.expectError(error.LogSegmentMissing, owner.recoverStep(policy.guard(), 256));
    try t.expectError(error.LogRecoveryRequired, owner.observe(initial.declared, policy.guard()));
    _ = try objects.objectStore().putImmutable(key, metadata, segment.metadata.sha256);
    try t.expect((try owner.recoverStep(policy.guard(), 256)).complete);
    try t.expect((try owner.flush(owner.root.position(), policy.guard())).complete);
    try t.expectEqual(@as(u64, 4), owner.root.sealed_through);
}

test "stream partition timestamp bounds preserve scanned coverage across nonmonotonic hot and sealed groups" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var definition = support.definition(.stream);
    var columns = definition.schema.columns[0..2].*;
    columns[1].type = .{ .timestamp = .utc };
    definition.schema.columns = &columns;
    definition.configuration.policy.stream.timestamp_column = 2;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    const assignment: q.GroupAssignment = .{ .operation = operation(2), .cut = try owner.observe(initial.declared, policy.guard()), .expected = null, .group = .{ .id = 7, .generation = 1, .principal = 0 }, .next = 0 };
    _ = try owner.assign(initial.declared, assignment, policy.guard());
    var values: [4][2]f.Types.Values.Cell = undefined;
    var rows: [4]s.LogBatch.Row = undefined;
    for ([_]i64{ 30, 5, 20, 10 }, &values, &rows) |time, *value, *row| {
        value.* = .{ cells[0], .{ .value = .{ .atom = .{ .timestamp = time } } } };
        row.* = .{ .cells = value };
    }
    var buffer: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(declaration.definition.schema, operation(3), .stream, &rows, &buffer);
    _ = try owner.append(initial.declared, .{ .target = initial.target(), .operation = operation(3), .kind = .stream, .producer = null, .rows = 4, .payload = s.LogBatch.content(payload) }, payload, policy.guard());
    var selection: p.StreamRead.Request = .{ .target = initial.target(), .operation = operation(4), .group = assignment.group, .from = 0, .until = null, .timestamp = .{ .from_us = 10, .until_us = 30 } };
    const hot = try owner.beginRead(initial.declared, selection, policy.guard());
    const authority = try s.LogRead.Authority.init(@splat(7));
    const hot_cursor = try owner.readCursor(hot.handle(), authority, policy.guard());
    var hot_page = try owner.readPage(hot_cursor, authority, .{ .rows = 4, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer hot_page.deinit();
    try t.expectEqual(@as(u32, 4), hot_page.examined);
    try t.expectEqual(@as(u32, 2), hot_page.count);
    try t.expectEqual(@as(u64, 2), hot_page.rows()[0].offset);
    try t.expectEqual(@as(u64, 3), hot_page.rows()[1].offset);
    try t.expect(hot_page.cursor.coverage.complete);
    owner.options.segment_rows_per_group = 1;
    try t.expect((try owner.flush(owner.root.position(), policy.guard())).complete);
    selection.operation = operation(5);
    const sealed = try owner.beginRead(initial.declared, selection, policy.guard());
    const sealed_cursor = try owner.readCursor(sealed.handle(), authority, policy.guard());
    _ = try owner.checkpoint(owner.root.position(), policy.guard());
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    var empty = try owner.readPage(sealed_cursor, authority, .{ .rows = 4, .encoded_bytes = 8192, .scanned_rows = 1 }, t.allocator, policy.guard());
    defer empty.deinit();
    try t.expectEqual(@as(u32, 0), empty.count);
    try t.expectEqual(@as(u32, 1), empty.examined);
    try t.expectEqual(@as(u64, 1), empty.cursor.coverage.through);
    try t.expect(!empty.cursor.coverage.complete);
    // The first nonmatching group was pruned from verified zone metadata;
    // no reconstructed batch entered the tail cache.
    try t.expectEqual(@as(u64, 0), owner.cache.verified);
    var middle = try owner.readPage(empty.cursor, authority, .{ .rows = 4, .encoded_bytes = 8192, .scanned_rows = 2 }, t.allocator, policy.guard());
    defer middle.deinit();
    try t.expectEqual(@as(u32, 1), middle.count);
    try t.expectEqual(@as(u32, 2), middle.examined);
    try t.expectEqual(@as(u64, 2), middle.rows()[0].offset);
    var end = try owner.readPage(middle.cursor, authority, .{ .rows = 4, .encoded_bytes = 8192, .scanned_rows = 1 }, t.allocator, policy.guard());
    defer end.deinit();
    try t.expectEqual(@as(u32, 1), end.count);
    try t.expectEqual(@as(u64, 3), end.rows()[0].offset);
    try t.expectEqual(@as(u64, 2), end.cursor.coverage.rows);
    try t.expectEqual(@as(u64, 4), end.cursor.coverage.through);
    try t.expect(end.cursor.coverage.complete);
    const commit: q.OffsetCommit = .{ .operation = operation(6), .group = assignment.group, .coverage = end.cursor.coverage, .expected_next = 0, .next = 4 };
    _ = try owner.commitOffset(initial.declared, commit, end.cursor, authority, policy.guard());
    try t.expectEqual(@as(u64, 4), (try owner.group(7, policy.guard())).?.next);
    selection.operation = operation(7);
    selection.group = null;
    selection.timestamp = .{ .from_us = 30, .until_us = 30 };
    const none = try owner.beginRead(initial.declared, selection, policy.guard());
    const none_cursor = try owner.readCursor(none.handle(), authority, policy.guard());
    var none_page = try owner.readPage(none_cursor, authority, .{ .rows = 4, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer none_page.deinit();
    try t.expect(none_page.count == 0 and none_page.examined == 4 and none_page.cursor.coverage.complete);
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.readPage(none_cursor, authority, .{ .rows = 4, .encoded_bytes = 8192 }, t.allocator, policy.guard()));
}

test "stream partition trusted observation floors survive lost replies without timing original recovery" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var definition = support.definition(.stream);
    definition.configuration.retention.max_age_ms = 100;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var fault: Fault = .{ .underlying = wal.log(), .lose_reply = false };
    var owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const first = try appendRequest(&declaration, 2, null, &buffer);
    const original_bytes = try t.allocator.dupe(u8, first.payload);
    defer t.allocator.free(original_bytes);
    const before = owner.root;
    try t.expectError(error.LogTimeUnavailable, owner.append(initial.declared, first.request, first.payload, policy.guard()));
    var clock: Clock = .{ .value = 100, .after = 99, .change = true };
    owner.options.clock = clock.source();
    try t.expectError(error.LogTimeRegression, owner.append(initial.declared, first.request, first.payload, policy.guard()));
    clock = .{ .value = 100, .after = null, .change = true };
    try t.expectError(error.LogTimeUnavailable, owner.append(initial.declared, first.request, first.payload, policy.guard()));
    clock = .{ .value = 100, .after = 200, .change = true };
    try t.expectError(error.LogRetentionWindowElapsed, owner.append(initial.declared, first.request, first.payload, policy.guard()));
    try t.expectEqualDeep(before, owner.root);
    try t.expectEqual(@as(u64, 1), try wal.log().tail(91));
    clock = .{ .value = 100 };
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.append(initial.declared, first.request, first.payload, policy.guard()));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    fault.underlying = wal.log();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqual(@as(?u64, 100), owner.root.clock_ms);
    var accepted_frame = try wal.log().read(t.allocator, 91, 1, 1);
    defer accepted_frame.deinit();
    try t.expectEqual(@as(u64, 0), accepted_frame.frames[0].header.timestamp_ms);
    const original = try owner.append(initial.declared, first.request, original_bytes, policy.guard());
    try t.expectEqual(@as(?u64, 100), original.observed_ms);
    const second = try appendRequest(&declaration, 3, null, &buffer);
    try t.expectError(error.LogTimeUnavailable, owner.append(initial.declared, second.request, second.payload, policy.guard()));
    owner.options.clock = clock.source();
    clock.value = 99;
    try t.expectError(error.LogTimeRegression, owner.append(initial.declared, second.request, second.payload, policy.guard()));
    try t.expectEqualDeep(original, try owner.append(initial.declared, first.request, original_bytes, policy.guard()));
    clock.value = null;
    try t.expectError(error.LogTimeUnavailable, owner.append(initial.declared, second.request, second.payload, policy.guard()));
    clock.value = 150;
    const next = try owner.append(initial.declared, second.request, second.payload, policy.guard());
    try t.expectEqual(@as(?u64, 150), next.observed_ms);
    try t.expectEqual(@as(?u64, 150), owner.root.clock_ms);
    try t.expectEqual(@as(u64, 4), owner.root.next_offset);
}

test "stream partition expiry uses lower time bounds independently of active append floors" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var definition = support.definition(.stream);
    definition.configuration.retention.max_age_ms = 100;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{ .value = 100, .error_ms = 10 };
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    owner.options.clock = clock.source();
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const first = try appendRequest(&declaration, 2, null, &buffer);
    const receipt = try owner.append(initial.declared, first.request, first.payload, policy.guard());
    try t.expectEqual(@as(?u64, 110), receipt.observed_ms);
    const cut = owner.root.position();
    while (!(try owner.flush(cut, policy.guard())).complete) {}
    // Even a later upper bound of 220 cannot prove that 100 ms has elapsed
    // from the first append's conservative bound of 110.
    clock.value = 210;
    try t.expectEqual(Stream.ExpirationStatus.not_due, (try owner.expireHistory(initial.declared, cut, policy.guard())).status);
    try t.expectEqual(@as(u64, 0), owner.root.retained_from);
    clock.value = 220;
    const second = try appendRequest(&declaration, 3, null, &buffer);
    _ = try owner.append(initial.declared, second.request, second.payload, policy.guard());
    try t.expectEqual(@as(?u64, 230), owner.root.clock_ms);
    // An uncertainty increase between staging and publication withdraws the
    // lower-bound proof even while the upper clock observation advances.
    clock.after = 220;
    clock.after_error_ms = 20;
    clock.change = true;
    try t.expectError(error.LogTimeRegression, owner.expireHistory(initial.declared, cut, policy.guard()));
    try t.expectEqual(@as(u64, 0), owner.root.retained_from);
    clock.value = 230;
    clock.error_ms = 10;
    const expired = try owner.expireHistory(initial.declared, cut, policy.guard());
    try t.expectEqual(Stream.ExpirationStatus.complete, expired.status);
    try t.expectEqual(@as(u64, 2), expired.retained_from);
    try t.expectEqual(@as(?u64, 240), owner.root.clock_ms);
    // Replay needs the recorded lower eligibility proof and upper floor, not a
    // fresh clock or the old resident owner.
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqual(@as(u64, 2), owner.root.retained_from);
    try t.expectEqual(@as(u64, 4), owner.root.next_offset);
    try t.expectEqual(@as(?u64, 240), owner.root.clock_ms);
}

test "stream partition expiry protects paged consumer watermarks pins and original producer outcomes" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var definition = support.definition(.stream);
    definition.configuration.retention.max_age_ms = 100;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    var policy: Policy = .{};
    var clock: Clock = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var fault: Fault = .{ .underlying = wal.log(), .lose_reply = false };
    var owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    owner.options.clock = clock.source();
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const producer: q.Producer = .{ .id = @splat(4), .epoch = 1, .sequence = 1 };
    const first = try appendRequest(&declaration, 2, producer, &buffer);
    const original_bytes = try t.allocator.dupe(u8, first.payload);
    defer t.allocator.free(original_bytes);
    const accepted = try owner.append(initial.declared, first.request, first.payload, policy.guard());
    var next_producer = producer;
    next_producer.sequence = 2;
    const second = try appendRequest(&declaration, 3, next_producer, &buffer);
    _ = try owner.append(initial.declared, second.request, second.payload, policy.guard());
    const payload_cut = owner.root.position();
    try t.expectEqual(Stream.ExpirationStatus.unsealed, (try owner.expireHistory(initial.declared, payload_cut, policy.guard())).status);
    while (!(try owner.flush(payload_cut, policy.guard())).complete) {}
    clock.value = 199;
    try t.expectEqual(Stream.ExpirationStatus.not_due, (try owner.expireHistory(initial.declared, payload_cut, policy.guard())).status);
    for (0..32) |i| {
        const assignment: q.GroupAssignment = .{ .operation = operation(100 + i), .cut = try owner.observe(initial.declared, policy.guard()), .expected = null, .group = .{ .id = i + 1, .generation = 1, .principal = 0 }, .next = if (i == 31) 0 else 2 };
        _ = try owner.assign(initial.declared, assignment, policy.guard());
    }
    clock.value = 200;
    try t.expectEqual(Stream.ExpirationStatus.consumer, (try owner.expireHistory(initial.declared, payload_cut, policy.guard())).status);
    const authority = try s.LogRead.Authority.init(@splat(7));
    const lagging = (try owner.group(32, policy.guard())).?.group;
    const consumed = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(200), .group = lagging, .from = 0, .until = 2, .timestamp = null }, policy.guard());
    var page = try owner.readPage(try owner.readCursor(consumed.handle(), authority, policy.guard()), authority, .{ .rows = 4, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer page.deinit();
    _ = try owner.commitOffset(initial.declared, .{ .operation = operation(201), .group = lagging, .coverage = page.cursor.coverage, .expected_next = 0, .next = 2 }, page.cursor, authority, policy.guard());
    const retained = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(202), .group = null, .from = 0, .until = null, .timestamp = null }, policy.guard());
    const cursor = try owner.readCursor(retained.handle(), authority, policy.guard());
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.expireHistory(initial.declared, payload_cut, policy.guard()));
    clock.value = null;
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqual(@as(u64, 2), owner.root.retained_from);
    try t.expectEqual(Stream.ExpirationStatus.consumer, (try owner.expireHistory(initial.declared, payload_cut, policy.guard())).status);
    try t.expectError(error.LogHistoryUnavailable, owner.readBatch(initial.declared, 0, policy.guard()));
    try t.expectEqualDeep(accepted, try owner.append(initial.declared, first.request, original_bytes, policy.guard()));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    fault.underlying = wal.log();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqual(Stream.ExpirationStatus.consumer, (try owner.expireHistory(initial.declared, payload_cut, policy.guard())).status);
    var old = try owner.readPage(cursor, authority, .{ .rows = 4, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer old.deinit();
    try t.expect(old.count == 4 and old.cursor.coverage.complete);
    var illegal = retained.request;
    illegal.operation = operation(203);
    try t.expectError(error.LogRangeExpired, owner.beginRead(initial.declared, illegal, policy.guard()));
    for (0..32) |i| {
        const group = (try owner.group(i + 1, policy.guard())).?.group;
        const pin = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(300 + i * 2), .group = group, .from = 2, .until = null, .timestamp = null }, policy.guard());
        var window = try owner.readPage(try owner.readCursor(pin.handle(), authority, policy.guard()), authority, .{ .rows = 4, .encoded_bytes = 8192 }, t.allocator, policy.guard());
        defer window.deinit();
        _ = try owner.commitOffset(initial.declared, .{ .operation = operation(301 + i * 2), .group = group, .coverage = window.cursor.coverage, .expected_next = 2, .next = 4 }, window.cursor, authority, policy.guard());
        _ = try owner.releaseRead(initial.declared, .{ .target = initial.target(), .operation = operation(500 + i), .read = pin.handle() }, policy.guard());
    }
    owner.options.clock = clock.source();
    clock.value = 300;
    const expired = try owner.expireHistory(initial.declared, payload_cut, policy.guard());
    try t.expectEqual(Stream.ExpirationStatus.complete, expired.status);
    try t.expectEqual(@as(u32, 2), expired.expired_rows);
    try t.expectEqual(@as(u64, 4), owner.root.retained_from);
    try t.expect(owner.root.batches == null and owner.root.segments == null);
    const empty = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(1000), .group = null, .from = 4, .until = null, .timestamp = null }, policy.guard());
    var ended = try owner.readPage(try owner.readCursor(empty.handle(), authority, policy.guard()), authority, .{ .rows = 4, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer ended.deinit();
    try t.expect(ended.count == 0 and ended.cursor.coverage.complete);
    next_producer.sequence = 3;
    const third = try appendRequest(&declaration, 1001, next_producer, &buffer);
    const later = try owner.append(initial.declared, third.request, third.payload, policy.guard());
    try t.expectEqual(@as(u64, 4), later.first);
    try t.expectEqual(@as(u64, 6), later.next);
    try t.expectEqualDeep(accepted, (try owner.operation(operation(2), policy.guard())).?.outcome.append);
}

test "stream partition expiry never invents time for earlier unlimited history" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const request = try appendRequest(&declaration, 2, null, &buffer);
    const accepted = try owner.append(initial.declared, request.request, request.payload, policy.guard());
    try t.expect(accepted.observed_ms == null);
    try t.expectError(error.LogRetentionNotDeclared, owner.expireHistory(initial.declared, owner.root.position(), policy.guard()));
    _ = try owner.flush(owner.root.position(), policy.guard());
    var definition = support.definition(.stream);
    definition.revision = 2;
    definition.configuration.retention.max_age_ms = 1;
    var revised = try s.LogDeclaration.prepare(t.allocator, definition);
    defer revised.deinit();
    const stored = try s.LogDeclaration.stage(objects.objectStore(), &revised);
    var clock: Clock = .{ .value = 1000 };
    owner.options.clock = clock.source();
    const before = owner.root;
    try t.expectEqual(Stream.ExpirationStatus.untimed, (try owner.expireHistory(stored, owner.root.position(), policy.guard())).status);
    try t.expectEqualDeep(before, owner.root);
}

fn compactAppend(owner: *Stream, declaration: *const s.LogDeclaration.Owned, policy: *Policy, id: u64, rows: []const s.LogBatch.Row) !q.AppendReceipt {
    var buffer: [8192]u8 = undefined;
    const payload = try s.LogBatch.encode(declaration.definition.schema, operation(id), .stream, rows, &buffer);
    const declared = try declaration.stored();
    return owner.append(declared, .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = declared.declaration.interpretation, .partition = 1 }, .operation = operation(id), .kind = .stream, .producer = null, .rows = rows.len, .payload = s.LogBatch.content(payload) }, payload, policy.guard());
}

test "stream partition sparse rewrites resume exact cuts and preserve old pins through empty placements" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var definition = support.definition(.stream);
    definition.configuration.partitioning.key_column = null;
    definition.configuration.policy.stream.compact_key_column = 1;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var fault: Fault = .{ .underlying = wal.log(), .lose_reply = false };
    var owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    const Case = struct {
        fn row(key: []const u8) [2]f.Types.Values.Cell {
            return .{ .{ .value = .{ .atom = .{ .bytes = key } } }, cells[1] };
        }
    };
    const first = try compactAppend(&owner, &declaration, &policy, 2, &.{ .{ .cells = &Case.row("a") }, .{ .cells = &Case.row("b") }, .{ .cells = &Case.row("A") }, .{ .cells = &Case.row("c") } });
    _ = try compactAppend(&owner, &declaration, &policy, 3, &.{.{ .cells = &Case.row("a") }});
    const old = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(10), .group = null, .from = 0, .until = null, .timestamp = null }, policy.guard());
    const flush_cut = owner.root.position();
    while (!(try owner.flush(flush_cut, policy.guard())).complete) {}
    const cut = owner.root.position();
    while ((try owner.compactStep(initial.declared, cut, 1, policy.guard())).status != .complete) {}
    try t.expectEqual(@as(u64, 2), owner.root.hidden.cardinality);
    const middle = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(11), .group = null, .from = 0, .until = null, .timestamp = null }, policy.guard());
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.rewriteMaintenanceUnit(initial.declared, policy.guard()));
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqual(@as(u64, 5), owner.root.maintenance.rewrite_target.?.through_offset);
    _ = try compactAppend(&owner, &declaration, &policy, 4, &.{.{ .cells = &Case.row("d") }});
    const before = owner.root;
    owner.options.segment_work_bytes = 4096;
    try t.expectError(error.LogSegmentBudgetExceeded, owner.rewriteMaintenanceUnit(initial.declared, policy.guard()));
    try t.expectEqualDeep(before, owner.root);
    owner.options.segment_work_bytes = 64 * 1024 * 1024;
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.rewriteMaintenanceUnit(initial.declared, policy.guard()));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    fault.underlying = wal.log();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqual(@as(u64, 4), owner.root.maintenance.rewrite_target.?.after_offset);
    try t.expectEqual(@as(u64, 5), owner.root.maintenance.rewrite_target.?.through_offset);
    var units: usize = 0;
    while (try owner.rewriteMaintenanceUnit(initial.declared, policy.guard())) : (units += 1) try t.expect(units < 4);
    var batch = (try owner.readBatch(initial.declared, 0, policy.guard())).?;
    try t.expectEqual(s.LogSegment.Layout.sparse, batch.layout);
    var rows = try batch.iterator(declaration.definition.schema);
    try t.expectEqual(@as(u32, 1), (try rows.next()).?.ordinal);
    try t.expectEqual(@as(u32, 3), (try rows.next()).?.ordinal);
    try t.expect(try rows.next() == null);
    batch.deinit();
    const authority = try s.LogRead.Authority.init(@splat(7));
    for ([_]p.StreamRead.Receipt{ old, middle }, [_]u32{ 5, 3 }) |pin, count| {
        var page = try owner.readPage(try owner.readCursor(pin.handle(), authority, policy.guard()), authority, .{ .rows = 8, .encoded_bytes = 8192 }, t.allocator, policy.guard());
        defer page.deinit();
        try t.expect(page.count == count and page.cursor.coverage.complete);
    }
    const current = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(12), .group = null, .from = 0, .until = null, .timestamp = null }, policy.guard());
    var cursor = try owner.readCursor(current.handle(), authority, policy.guard());
    var at: usize = 0;
    const expected = [_]u64{ 1, 3, 4, 5 };
    while (!cursor.coverage.complete) {
        var page = try owner.readPage(cursor, authority, .{ .rows = 2, .encoded_bytes = 8192, .scanned_rows = 2 }, t.allocator, policy.guard());
        defer page.deinit();
        for (page.rows()) |row| {
            try t.expectEqual(expected[at], row.offset);
            at += 1;
        }
        cursor = page.cursor;
    }
    try t.expectEqual(expected.len, at);
    _ = try compactAppend(&owner, &declaration, &policy, 5, &.{ .{ .cells = &Case.row("a") }, .{ .cells = &Case.row("b") }, .{ .cells = &Case.row("c") }, .{ .cells = &Case.row("d") } });
    const sealed = owner.root.position();
    while (!(try owner.flush(sealed, policy.guard())).complete) {}
    units = 0;
    while (try owner.compactionMaintenanceUnit(initial.declared, 1, policy.guard())) : (units += 1) try t.expect(units < 64);
    try t.expectEqual(@as(u64, 6), owner.root.hidden.cardinality);
    batch = (try owner.readBatch(initial.declared, 0, policy.guard())).?;
    rows = try batch.iterator(declaration.definition.schema);
    try t.expect(try rows.next() == null);
    batch.deinit();
    // New compaction traverses empty placements with bounded logical progress.
    const again = owner.root.position();
    units = 0;
    while ((try owner.compactStep(initial.declared, again, 1, policy.guard())).status != .complete) : (units += 1) try t.expect(units < 32);
    while (try owner.compactionMaintenanceUnit(initial.declared, 1, policy.guard())) {}
    while (try owner.archiveMaintenanceUnit(.{ .frames = 4 }, policy.guard())) {}
    _ = try owner.trimArchived(policy.guard());
    try owner.deinit();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqualDeep(first, (try owner.operation(operation(2), policy.guard())).?.outcome.append);
    for ([_]p.StreamRead.Receipt{ old, middle, current }, [_]u32{ 5, 3, 4 }) |pin, count| {
        var page = try owner.readPage(try owner.readCursor(pin.handle(), authority, policy.guard()), authority, .{ .rows = 8, .encoded_bytes = 8192 }, t.allocator, policy.guard());
        defer page.deinit();
        try t.expect(page.count == count and page.cursor.coverage.complete);
    }
}

test "stream partition compaction freezes collation supersession tombstones and retained reads across disk restart" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var definition = support.definition(.stream);
    definition.configuration.partitioning.key_column = null;
    definition.configuration.policy.stream.compact_key_column = 1;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var fault: Fault = .{ .underlying = wal.log(), .lose_reply = false };
    var owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    const Case = struct {
        fn row(key: []const u8) [2]f.Types.Values.Cell {
            return .{ .{ .value = .{ .atom = .{ .bytes = key } } }, cells[1] };
        }
    };
    var long_a: [121]u8 = @splat('x');
    long_a[120] = 'a';
    var long_b = long_a;
    long_b[120] = 'b';
    const first = try compactAppend(&owner, &declaration, &policy, 2, &.{
        .{ .cells = &Case.row("Alpha") },                    .{ .cells = &Case.row("b") },
        .{ .cells = &Case.row("ALPHA"), .tombstone = true }, .{ .cells = &Case.row(&long_a) },
        .{ .cells = &Case.row(&long_b) },
    });
    _ = try compactAppend(&owner, &declaration, &policy, 3, &.{ .{ .cells = &Case.row("alpha") }, .{ .cells = &Case.row("B") }, .{ .cells = &Case.row(&long_a) } });
    const old_read = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(10), .group = null, .from = 0, .until = null, .timestamp = null }, policy.guard());
    const flush_cut = owner.root.position();
    while (!(try owner.flush(flush_cut, policy.guard())).complete) {}
    const cut = owner.root.position();
    try t.expectError(error.InvalidStreamCompactionBudget, owner.compactStep(initial.declared, cut, 65, policy.guard()));
    try t.expectEqual(s.StreamCompaction.Progress{ .cut = cut, .position = .{ .partition = cut.partition, .next_lsn = cut.next_lsn + 1 }, .next = 0, .examined = 0, .hidden = 0, .status = .progress }, try owner.compactStep(initial.declared, cut, 2, policy.guard()));
    try t.expectEqual(@as(u32, 2), (try owner.compactStep(initial.declared, cut, 2, policy.guard())).examined);
    const before = owner.root;
    owner.options.index_work_bytes = 1;
    try t.expectError(error.StorageCandidateTooLarge, owner.compactStep(initial.declared, cut, 2, policy.guard()));
    try t.expectEqualDeep(before, owner.root);
    owner.options.index_work_bytes = options.index_work_bytes;
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.compactStep(initial.declared, cut, 2, policy.guard()));
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    // A later append is outside the frozen compaction source, including when
    // it shares a key. It cannot retroactively hide the source's latest value.
    _ = try compactAppend(&owner, &declaration, &policy, 4, &.{.{ .cells = &Case.row("b") }});
    const recovery_cut = owner.root.position();
    while (!(try owner.archive(recovery_cut, .{ .frames = 1 }, policy.guard())).complete) {}
    _ = try owner.checkpoint(recovery_cut, policy.guard());
    _ = try owner.trimArchived(policy.guard());
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    var steps: usize = 0;
    while ((try owner.compactStep(initial.declared, cut, 2, policy.guard())).status != .complete) : (steps += 1) try t.expect(steps < 32);
    try t.expectEqual(@as(u64, 3), owner.root.hidden.cardinality);
    const settled = owner.root;
    try t.expectEqual(@as(u32, 0), (try owner.compactStep(initial.declared, cut, 2, policy.guard())).examined);
    try t.expectEqualDeep(settled, owner.root);
    try t.expectEqualDeep(first, (try owner.operation(operation(2), policy.guard())).?.outcome.append);
    const authority = try s.LogRead.Authority.init(@splat(7));
    var old = try owner.readPage(try owner.readCursor(old_read.handle(), authority, policy.guard()), authority, .{ .rows = 16, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer old.deinit();
    try t.expect(old.count == 8 and old.cursor.coverage.complete and old.cursor.coverage.until == 8);
    const current = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(11), .group = null, .from = 0, .until = null, .timestamp = null }, policy.guard());
    var cursor = try owner.readCursor(current.handle(), authority, policy.guard());
    const expected = [_]u64{ 2, 4, 5, 6, 7, 8 };
    var at: usize = 0;
    var empty: usize = 0;
    while (!cursor.coverage.complete) {
        var page = try owner.readPage(cursor, authority, .{ .rows = 1, .encoded_bytes = 8192, .scanned_rows = 1 }, t.allocator, policy.guard());
        defer page.deinit();
        if (page.count == 0) empty += 1;
        for (page.rows()) |row| {
            try t.expectEqual(expected[at], row.offset);
            try t.expectEqual(row.offset == 2, row.encoded.tombstone);
            at += 1;
        }
        cursor = page.cursor;
    }
    try t.expectEqual(expected.len, at);
    try t.expectEqual(@as(usize, 3), empty);
    try t.expect(cursor.coverage.through == 9 and cursor.coverage.rows == 6);
    try owner.deinit();
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    var replay = try owner.readPage(try owner.readCursor(current.handle(), authority, policy.guard()), authority, .{ .rows = 16, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer replay.deinit();
    try t.expect(replay.count == 6 and replay.cursor.coverage.complete);
}

test "stream partition compaction protects consumer checkpoints and cancels unpublished candidates" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var definition = support.definition(.stream);
    definition.configuration.policy.stream.compact_key_column = 1;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    _ = try compactAppend(&owner, &declaration, &policy, 2, &.{ .{ .cells = &cells }, .{ .cells = &cells }, .{ .cells = &cells }, .{ .cells = &cells } });
    try t.expectEqual(@FieldType(s.StreamCompaction.Progress, "status").unsealed, (try owner.compactStep(initial.declared, owner.root.position(), 1, policy.guard())).status);
    _ = try owner.flush(owner.root.position(), policy.guard());
    _ = try owner.assign(initial.declared, .{ .operation = operation(3), .cut = try owner.observe(initial.declared, policy.guard()), .expected = null, .group = .{ .id = 1, .generation = 1, .principal = 0 }, .next = 2 }, policy.guard());
    const cut = owner.root.position();
    _ = try owner.compactStep(initial.declared, cut, 1, policy.guard());
    _ = try owner.assign(initial.declared, .{ .operation = operation(4), .cut = try owner.observe(initial.declared, policy.guard()), .expected = null, .group = .{ .id = 2, .generation = 1, .principal = 0 }, .next = 0 }, policy.guard());
    while (owner.root.compaction.?.phase != .ready) _ = try owner.compactStep(initial.declared, cut, 1, policy.guard());
    try t.expectEqual(@FieldType(s.StreamCompaction.Progress, "status").consumer, (try owner.compactStep(initial.declared, cut, 1, policy.guard())).status);
    try t.expectEqual(@as(u64, 0), owner.root.hidden.cardinality);
    const authority = try s.LogRead.Authority.init(@splat(7));
    const group = (try owner.group(2, policy.guard())).?.group;
    const pin = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(5), .group = group, .from = 0, .until = 2, .timestamp = null }, policy.guard());
    var page = try owner.readPage(try owner.readCursor(pin.handle(), authority, policy.guard()), authority, .{ .rows = 4, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer page.deinit();
    _ = try owner.commitOffset(initial.declared, .{ .operation = operation(6), .group = group, .coverage = page.cursor.coverage, .expected_next = 0, .next = 2 }, page.cursor, authority, policy.guard());
    const before = owner.root;
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.compactStep(initial.declared, cut, 1, policy.guard()));
    try t.expectEqualDeep(before, owner.root);
    policy.deny_at = std.math.maxInt(usize);
    try t.expectEqual(@FieldType(s.StreamCompaction.Progress, "status").complete, (try owner.compactStep(initial.declared, cut, 1, policy.guard())).status);
    try t.expectEqual(@as(u64, 2), owner.root.hidden.cardinality);
    const newer = owner.root.position();
    _ = try owner.compactStep(initial.declared, newer, 1, policy.guard());
    _ = try owner.compactStep(initial.declared, newer, 1, policy.guard());
    try owner.cancelCompaction(newer, policy.guard());
    try t.expect(owner.root.compaction == null and owner.root.hidden.cardinality == 2);
    try owner.deinit();
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expect(owner.root.compaction == null and owner.root.hidden.cardinality == 2);
}

test "stream partition maintenance settles fixed targets through lost replies disk restart and later input" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var definition = support.definition(.stream);
    definition.configuration.policy.stream.compact_key_column = 1;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var fault: Fault = .{ .underlying = wal.log(), .lose_reply = false };
    var owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    try t.expect(!try owner.archiveMaintenanceUnit(.{ .frames = 1 }, policy.guard()));
    try t.expect(!try owner.compactionMaintenanceUnit(initial.declared, 1, policy.guard()));
    const first = try compactAppend(&owner, &declaration, &policy, 2, &.{ .{ .cells = &cells }, .{ .cells = &cells } });
    _ = try owner.flush(owner.root.position(), policy.guard());
    const pin = try owner.beginRead(initial.declared, .{ .target = initial.target(), .operation = operation(3), .group = null, .from = 0, .until = null, .timestamp = null }, policy.guard());
    const original_cut = owner.root.position();
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.archiveMaintenanceUnit(.{ .frames = 1 }, policy.guard()));
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);
    try t.expectEqual(original_cut.next_lsn, owner.root.maintenance.archive_target.?.through_lsn);
    try t.expect(try owner.compactionMaintenanceUnit(initial.declared, 1, policy.guard()));
    const compact_cut = owner.root.compaction.?.source.cut.accepted;
    const later = try compactAppend(&owner, &declaration, &policy, 4, &.{.{ .cells = &cells }});
    try t.expectEqual(original_cut.next_lsn, owner.root.maintenance.archive_target.?.through_lsn);
    try t.expectEqualDeep(compact_cut, owner.root.compaction.?.source.cut.accepted);

    // Reopen disk providers with both targets in flight, after a missing archive
    // reply. Neither a restart nor later foreground input changes their cuts.
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.archiveMaintenanceUnit(.{ .frames = 1 }, policy.guard()));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    fault.underlying = wal.log();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqual(original_cut.next_lsn, owner.root.maintenance.archive_target.?.through_lsn);
    try t.expectEqualDeep(compact_cut, owner.root.compaction.?.source.cut.accepted);
    _ = try owner.flush(owner.root.position(), policy.guard());
    var steps: usize = 0;
    while (true) : (steps += 1) {
        try t.expect(steps < 128);
        const before = owner.root.next_lsn;
        const compacted = try owner.compactionMaintenanceUnit(initial.declared, 1, policy.guard());
        try t.expectEqual(before + @intFromBool(compacted), owner.root.next_lsn);
        const archived = try owner.archiveMaintenanceUnit(.{ .frames = 1 }, policy.guard());
        try t.expectEqual(before + @intFromBool(compacted) + @intFromBool(archived), owner.root.next_lsn);
        if (!compacted and !archived) break;
    }
    try t.expectEqual(@as(u64, 2), owner.root.hidden.cardinality);
    try t.expect(owner.root.compacted.?.next_lsn > compact_cut.next_lsn);
    try t.expect(owner.root.maintenance.archive_target == null);
    const stable = owner.root;
    for (0..4) |_| {
        try t.expect(!try owner.archiveMaintenanceUnit(.{ .frames = 1 }, policy.guard()));
        try t.expect(!try owner.compactionMaintenanceUnit(initial.declared, 1, policy.guard()));
    }
    try t.expectEqualDeep(stable, owner.root);
    _ = try owner.trimArchived(policy.guard());
    try owner.deinit();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqualDeep(stable, owner.root);
    try t.expect(!try owner.archiveMaintenanceUnit(.{ .frames = 1 }, policy.guard()));
    try t.expect(!try owner.compactionMaintenanceUnit(initial.declared, 1, policy.guard()));
    try t.expectEqualDeep(first, (try owner.operation(operation(2), policy.guard())).?.outcome.append);
    try t.expectEqualDeep(later, (try owner.operation(operation(4), policy.guard())).?.outcome.append);
    const authority = try s.LogRead.Authority.init(@splat(7));
    var old = try owner.readPage(try owner.readCursor(pin.handle(), authority, policy.guard()), authority, .{ .rows = 4, .encoded_bytes = 8192 }, t.allocator, policy.guard());
    defer old.deinit();
    try t.expect(old.count == 2 and old.cursor.coverage.complete);
    policy.deny_at = policy.calls + 1;
    try t.expectError(error.PermissionDenied, owner.archiveMaintenanceUnit(.{ .frames = 1 }, policy.guard()));
}

test "stream partition maintenance rejects invented completion and closes retired candidates" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var definition = support.definition(.stream);
    definition.configuration.policy.stream.compact_key_column = 1;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    _ = try compactAppend(&owner, &declaration, &policy, 2, &.{ .{ .cells = &cells }, .{ .cells = &cells } });
    _ = try owner.flush(owner.root.position(), policy.guard());
    try t.expect(try owner.compactionMaintenanceUnit(initial.declared, 1, policy.guard()));
    var retired = initial.declared;
    retired.retired = true;
    retired.declaration.interpretation.revision += 1;
    try t.expect(try owner.compactionMaintenanceUnit(retired, 1, policy.guard()));
    try t.expect(owner.root.compaction == null and owner.root.hidden.cardinality == 0);
    try t.expect(!try owner.compactionMaintenanceUnit(retired, 1, policy.guard()));
    try owner.deinit();
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expect(owner.root.compaction == null and owner.root.hidden.cardinality == 0);

    while (owner.root.compacted == null) _ = try owner.compactionMaintenanceUnit(initial.declared, 1, policy.guard());
    try t.expect(try owner.rewriteMaintenanceUnit(initial.declared, policy.guard()));
    const visibility = owner.root.hidden;
    const placements = owner.root.segments;
    try t.expect(try owner.compactionMaintenanceUnit(retired, 1, policy.guard()));
    try t.expect(owner.root.maintenance.rewrite_target == null);
    try t.expectEqualDeep(visibility, owner.root.hidden);
    try t.expectEqualDeep(placements, owner.root.segments);
    try t.expect(!try owner.compactionMaintenanceUnit(retired, 1, policy.guard()));
    try owner.deinit();
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try t.expectEqualDeep(placements, owner.root.segments);

    // This root is locally well formed, but no archive/checkpoint target has
    // completed. Replay must reject its invented scheduling progress.
    var forged = owner.root;
    forged.next_lsn += 1;
    forged.maintenance.archived_source_lsn = forged.maintenance.archive_source_lsn;
    var bytes: [s.LogPartitionRecord.max_metadata_bytes + s.LogPartitionRecord.header_bytes]u8 = undefined;
    const encoded = try s.LogPartitionRecord.encode(.{ .definition = p.Growth.current_definition, .previous = owner.commitment, .root = forged, .action = .{ .maintenance = .complete_archive } }, &.{}, &bytes);
    _ = try wal.log().append(91, owner.root.next_lsn, policy.epoch, policy.epoch, .manifest_checkpoint, encoded);
    try t.expectError(error.InvalidStreamMaintenance, owner.recoverStep(policy.guard(), 1));
    try t.expectError(error.LogRecoveryRequired, owner.observe(initial.declared, policy.guard()));
}

test "stream partition rewrite replay rejects a valid sparse segment that changes surviving bytes" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var definition = support.definition(.stream);
    definition.configuration.policy.stream.compact_key_column = 1;
    var declaration = try s.LogDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    const receipt = try compactAppend(&owner, &declaration, &policy, 2, &.{ .{ .cells = &cells }, .{ .cells = &cells } });
    _ = try owner.flush(owner.root.position(), policy.guard());
    const cut = owner.root.position();
    while ((try owner.compactStep(initial.declared, cut, 1, policy.guard())).status != .complete) {}
    try t.expect(try owner.rewriteMaintenanceUnit(initial.declared, policy.guard()));
    const evidence = (try owner.operation(operation(2), policy.guard())).?;
    var changed = cells;
    changed[1] = .{ .value = .{ .atom = .{ .bytes = "changed" } } };
    const row: f.TableRow.Row = .{ .identity = .{ .origin = 1, .operation = 2, .ordinal = 1 }, .cells = &changed };
    var row_bytes: [4096]u8 = undefined;
    var view_bytes: [8192]u8 = undefined;
    var encoder = try s.LogView.Encoder.init(declaration.definition.schema, 2, 1, &view_bytes);
    try encoder.append(.{ .ordinal = 1, .visible_ms = 0, .tombstone = false, .bytes = try row.encode(declaration.definition.schema, &row_bytes) });
    const replacement = try s.LogSegment.stageSparse(t.allocator, objects.objectStore(), &declaration, evidence, try encoder.finish(), 1);
    var forged = owner.root;
    forged.next_lsn += 1;
    forged.maintenance.archive_source_lsn = forged.next_lsn;
    forged.maintenance.rewrite_target.?.after_offset = receipt.next;
    try owner.store.begin(options.index_work_bytes);
    const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &owner.store };
    forged.segments = try tree.put(forged.segments, try s.LogPartitionRecord.integerKey(receipt.next), try replacement.encode());
    owner.store.end();
    var bytes: [s.LogPartitionRecord.max_metadata_bytes + s.LogPartitionRecord.header_bytes]u8 = undefined;
    const record = try s.LogPartitionRecord.encode(.{ .definition = p.Growth.current_definition, .previous = owner.commitment, .root = forged, .action = .{ .rewrite = .{ .receipt = receipt, .segment = replacement } } }, &.{}, &bytes);
    _ = try wal.log().append(91, owner.root.next_lsn, policy.epoch, policy.epoch, .manifest_checkpoint, record);
    try t.expectError(error.LogPayloadConflict, owner.recoverStep(policy.guard(), 1));
    try t.expectError(error.LogRecoveryRequired, owner.observe(initial.declared, policy.guard()));
}

test "stream partition recovery hints verify accepted anchors and yield to newer checkpoints" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    for (2..8) |id| _ = try compactAppend(&owner, &declaration, &policy, id, &.{.{ .cells = &cells }});
    const prior = try owner.recoveryState();
    _ = try compactAppend(&owner, &declaration, &policy, 8, &.{.{ .cells = &cells }});
    const accepted = owner.root;
    try owner.deinit();
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    var corrupt = prior;
    corrupt.commitment[0] ^= 1;
    try t.expectError(error.InvalidLogHistory, owner.recoverStepSince(policy.guard(), 1, corrupt));
    try t.expectError(error.LogRecoveryRequired, owner.recoveryState());
    corrupt = prior;
    corrupt.root.clock_ms = 999;
    try t.expectError(error.InvalidLogHistory, owner.recoverStepSince(policy.guard(), 1, corrupt));
    policy.deny_at = policy.calls + 1;
    try t.expectError(error.PermissionDenied, owner.recoverStepSince(policy.guard(), 1, prior));
    policy.deny_at = std.math.maxInt(usize);
    const recovered = try owner.recoverStepSince(policy.guard(), 1, prior);
    try t.expect(recovered.complete and recovered.examined == 1);
    try t.expectEqualDeep(accepted, owner.root);
    while (try owner.archiveMaintenanceUnit(.{ .frames = 2 }, policy.guard())) {}
    _ = try owner.trimArchived(policy.guard());
    const checkpointed = owner.root;
    try owner.deinit();
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStepSince(policy.guard(), 1, prior)).complete) {}
    try t.expectEqualDeep(checkpointed, owner.root);
}

test "stream partition staged checkpoint cannot grant trim or reconstruct missing initialization" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declaration);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const request = try appendRequest(&declaration, 2, null, &buffer);
    _ = try owner.append(initial.declared, request.request, request.payload, policy.guard());
    _ = try owner.archive(owner.root.position(), .{}, policy.guard());
    const basis: s.LogRecovery.Basis = .{ .root = owner.root, .commitment = owner.commitment };
    const staged = try s.LogRecovery.stage(objects.objectStore(), basis);
    try t.expectError(error.LogCheckpointRequired, owner.trimArchived(policy.guard()));
    var candidate = owner.root;
    candidate.next_lsn += 1;
    candidate.recovery = staged;
    var record: s.LogPartitionRecord.Record = .{ .definition = p.Growth.current_definition, .root = candidate, .previous = owner.commitment, .action = .checkpoint };
    try s.LogRecovery.requirePublication(basis, staged, record);
    record.root.next_offset += 1;
    try t.expectError(error.InvalidLogRecovery, s.LogRecovery.requirePublication(basis, staged, record));
    record.root = candidate;
    record.previous[0] ^= 1;
    try t.expectError(error.InvalidLogRecovery, s.LogRecovery.requirePublication(basis, staged, record));
    // Force a forbidden raw-storage trim to prove that even a correctly staged
    // baseline cannot be inferred as an accepted checkpoint on reopen.
    try wal.log().trim(91, 1);
    try t.expectError(error.WalHistoryTrimmed, reopen(wal.log(), objects.objectStore(), initial, &policy));
}

test "log transaction stream cuts survive lost pin and release replies with exact disk recovery" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var declared = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declared.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var fault: Fault = .{ .underlying = wal.log(), .lose_reply = false };
    var owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    var buffer: [8192]u8 = undefined;
    const first = try appendRequest(&declared, 2, null, &buffer);
    _ = try owner.append(initial.declared, first.request, first.payload, policy.guard());
    const basis = owner.root;
    const identity: p.Transaction.Identity = .{ .begin = operation(100), .branch = 1 };
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.pinTransactionSource(initial.declared, identity, basis.position(), policy.guard()));
    try t.expectError(error.LogRecoveryRequired, owner.transactionPinState(identity.begin, policy.guard()));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    fault.underlying = wal.log();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    const handle = try owner.pinTransactionSource(initial.declared, identity, basis.position(), policy.guard());
    try t.expectEqualDeep(basis, (try owner.inspectTransactionSource(handle, policy.guard())).root);
    try t.expectEqual(basis.changed_lsn, owner.root.changed_lsn);
    try (try s.LogTransaction.logGuard(basis)).requireUnchanged(try s.LogTransaction.logGuard(owner.root));
    const later = try appendRequest(&declared, 3, null, &buffer);
    _ = try owner.append(initial.declared, later.request, later.payload, policy.guard());
    try t.expectError(error.TransactionConflict, (try s.LogTransaction.logGuard(basis)).requireUnchanged(try s.LogTransaction.logGuard(owner.root)));
    try t.expectEqualDeep(handle, try owner.pinTransactionSource(initial.declared, identity, basis.position(), policy.guard()));
    try t.expectError(error.TransactionIdentityConflict, owner.pinTransactionSource(initial.declared, identity, owner.root.position(), policy.guard()));
    try t.expectEqualDeep(basis, (try owner.inspectTransactionSource(handle, policy.guard())).root);
    const cut = owner.root.position();
    while (!(try owner.flush(cut, policy.guard())).complete) {}
    while (!(try owner.archive(cut, .{ .frames = 2 }, policy.guard())).complete) {}
    _ = try owner.checkpoint(cut, policy.guard());
    _ = try owner.trimArchived(policy.guard());
    const changed = owner.root.changed_lsn;
    fault.lose_reply = true;
    try t.expectError(error.LogAppendUncertain, owner.releaseTransactionSource(handle, policy.guard()));
    try owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    fault.underlying = wal.log();
    owner = try reopen(fault.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    try owner.releaseTransactionSource(handle, policy.guard());
    try t.expect((try owner.transactionPinState(identity.begin, policy.guard())).released);
    try t.expectEqual(changed, owner.root.changed_lsn);
    try t.expectError(error.LogTransactionSourceReleased, owner.inspectTransactionSource(handle, policy.guard()));
    try t.expectError(error.LogTransactionSourceReleased, owner.pinTransactionSource(initial.declared, identity, basis.position(), policy.guard()));
    var foreign = handle;
    foreign.content.sha256[0] ^= 1;
    try t.expectError(error.LogTransactionSourceNotPinned, owner.releaseTransactionSource(foreign, policy.guard()));
    policy.deny_at = policy.calls + 1;
    try t.expectError(error.PermissionDenied, owner.transactionPinState(identity.begin, policy.guard()));
    try t.expectError(error.PermissionDenied, owner.releaseTransactionSource(handle, policy.guard()));
}

test "log transaction stream pins page independently and refuse stale cuts and revoked publication" {
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declared = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declared.deinit();
    var policy: Policy = .{};
    const initial = try initialize(wal.log(), objects.objectStore(), &policy, &declared);
    var owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    defer owner.deinit() catch unreachable;
    _ = try owner.recoverStep(policy.guard(), 1);
    const identity: p.Transaction.Identity = .{ .begin = operation(100), .branch = 1 };
    const before = owner.root;
    policy.deny_at = policy.calls + 3;
    try t.expectError(error.PermissionDenied, owner.pinTransactionSource(initial.declared, identity, before.position(), policy.guard()));
    try t.expectEqualDeep(before, owner.root);
    try t.expectEqual(before.next_lsn, try wal.log().tail(91));
    policy.deny_at = std.math.maxInt(usize);
    for (100..173) |id| {
        const current: p.Transaction.Identity = .{ .begin = operation(id), .branch = 1 };
        const expected = owner.root.position();
        const handle = try owner.pinTransactionSource(initial.declared, current, expected, policy.guard());
        const source = try owner.inspectTransactionSource(handle, policy.guard());
        try t.expectEqualDeep(expected, source.root.position());
        try t.expect(source.root.transaction_pins == null);
    }
    try t.expectEqual(@as(usize, 1), owner.store.cache.len);
    try t.expectEqual(@as(u64, 0), owner.root.changed_lsn);
    try t.expectError(error.TransactionConflict, owner.pinTransactionSource(initial.declared, .{ .begin = operation(200), .branch = 1 }, before.position(), policy.guard()));
    const first = (try owner.transactionPinState(identity.begin, policy.guard())).handle.?;
    var name: [96]u8 = undefined;
    var encoded: [s.LogTransaction.max_bytes]u8 = undefined;
    const old = try objects.objectStore().getRange(try s.LogTransaction.sourceKey(first.content, &name), 0, @intCast(first.content.bytes), &encoded);
    encoded[8] ^= 1;
    const foreign = s.LogBatch.content(encoded[0..old.len]);
    _ = try objects.objectStore().putImmutable(try s.LogTransaction.sourceKey(foreign, &name), encoded[0..old.len], foreign.sha256);
    try t.expectError(error.IncompatibleDefinition, s.LogTransaction.loadSource(objects.objectStore(), .{ .owner = first.owner, .content = foreign }));
    // A well-formed physical pin record cannot invent a logical mutation.
    var frames = try wal.log().read(t.allocator, 91, 1, 1);
    defer frames.deinit();
    var forged = (try s.LogPartitionRecord.decode(t.allocator, frames.frames[0], 91, 1)).record;
    forged.root.changed_lsn = forged.root.next_lsn;
    const altered = try s.LogPartitionRecord.encode(forged, &.{}, &encoded);
    var other = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer other.deinit();
    _ = try initialize(other.log(), objects.objectStore(), &policy, &declared);
    _ = try other.log().append(91, 1, 1, 1, .manifest_checkpoint, altered);
    var rejected = try reopen(other.log(), objects.objectStore(), initial, &policy);
    defer rejected.deinit() catch unreachable;
    try t.expectError(error.InvalidLogHistory, rejected.recoverStep(policy.guard(), 1));
    try owner.deinit();
    owner = try reopen(wal.log(), objects.objectStore(), initial, &policy);
    while (!(try owner.recoverStep(policy.guard(), 3)).complete) {}
    try t.expectEqualDeep(before.position(), (try owner.inspectTransactionSource(first, policy.guard())).root.position());
}
