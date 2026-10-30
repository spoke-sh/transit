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
    const selection: p.StreamRead.Request = .{ .target = initial.target(), .operation = operation(5), .group = assignment.group, .from = 0, .until = null };
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
    const selection: p.StreamRead.Request = .{ .target = initial.target(), .operation = operation(3), .group = null, .from = 1, .until = null };
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
