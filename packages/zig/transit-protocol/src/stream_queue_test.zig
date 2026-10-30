const std = @import("std");
const t = std.testing;
const p = @import("root.zig");
const q = p.StreamQueue;

fn fixture() !std.json.Parsed(q.SchemaTypes) {
    return p.Json.parseFromSlice(q.SchemaTypes, t.allocator, @embedFile("fixtures/stream-queue-v1.json"));
}

test "stream finite read attribution freezes its original cut range source and claimant" {
    const parsed = try fixture();
    defer parsed.deinit();
    const receipt = parsed.value.read;
    try receipt.validate();
    const initial = try receipt.initialCoverage();
    try t.expect(!initial.complete);
    try t.expectEqual(initial.from, initial.through);
    try t.expectEqual(@as(u64, 0), initial.rows);
    var request = receipt.request;
    request.until = receipt.until;
    try t.expectError(error.StreamReadConflict, receipt.requireRequest(request));
    request = receipt.request;
    request.operation.principal += 1;
    try t.expectError(error.LogGroupFenced, request.validate());
    var changed = receipt;
    changed.cut.next -= 1;
    try t.expectError(error.LogOffsetBeyondCut, changed.validate());
    changed = receipt;
    changed.accepted.next_lsn += 1;
    try t.expectError(error.InvalidStreamRead, changed.validate());
    changed = receipt;
    changed.request.from = receipt.until;
    try t.expect((try changed.initialCoverage()).complete);
    var cursor = parsed.value.read_cursor;
    cursor.read.source.sha256[0] ^= 1;
    try t.expectError(error.StreamReadConflict, cursor.requireReceipt(receipt));
    cursor = parsed.value.read_cursor;
    cursor.coverage.from -= 1;
    try t.expectError(error.StreamReadConflict, cursor.requireReceipt(receipt));
    cursor = parsed.value.read_cursor;
    cursor.authentication = @splat(0);
    try t.expectError(error.InvalidStreamCursor, cursor.validate());
    var release = parsed.value.read_release.release;
    release.operation = release.read.owner;
    try t.expectError(error.InvalidStreamRelease, release.validate());
    release = parsed.value.read_release.release;
    release.operation.principal = 0;
    try t.expectError(error.InvalidStreamRelease, release.validate());
}

test "stream queue fixture keeps logical offsets separate from WAL and preserves wide identities" {
    const parsed = try fixture();
    defer parsed.deinit();
    const v = parsed.value;
    try v.declaration.validate();
    try v.append.validate();
    try v.producer.validate();
    try v.claim.validate();
    try v.offset_commit.validate();
    try v.group_progress.validate();
    try v.group_assignment.validate();
    try v.offset_receipt.validate();
    try v.read.validate();
    try v.read_cursor.requireReceipt(v.read);
    try v.read_release.validate();
    try v.settlement.validate();
    try t.expectEqual(std.math.maxInt(u64), v.append.next);
    try t.expectEqual(@as(u32, 0), v.append.append.target.partition);
    try t.expectEqual(@as(u64, 91), v.append.accepted.partition);
    try t.expectEqual(@as(u64, 12), v.append.accepted.next_lsn);
    try t.expectEqual(std.math.maxInt(u64), v.append.append.producer.?.sequence);
    const encoded = try p.Json.valueAlloc(t.allocator, v);
    defer t.allocator.free(encoded);
    const roundtrip = try p.Json.parseFromSlice(q.SchemaTypes, t.allocator, encoded);
    defer roundtrip.deinit();
    try t.expectEqualDeep(v, roundtrip.value);
}

test "log declaration successors preserve object identity routing and required budgets" {
    const parsed = try fixture();
    defer parsed.deinit();
    const first = parsed.value.declaration;
    var next = first;
    next.interpretation.revision += 1;
    next.interpretation.digest[0] ^= 1;
    next.configuration.retention.max_age_ms = 1000;
    try first.requireSuccessor(next);
    next.interpretation.object.object += 1;
    try t.expectError(error.LogDeclarationConflict, first.requireSuccessor(next));
    next = first;
    next.limits.read_bytes = 0;
    try t.expectError(error.InvalidLogLimits, next.validate());
    next = first;
    next.limits.claim_rows = next.limits.active_leases + 1;
    try t.expectError(error.InvalidLogLimits, next.validate());
}

test "stream exact append retry refuses changed payload producer or original binding" {
    const parsed = try fixture();
    defer parsed.deinit();
    const receipt = parsed.value.append;
    try receipt.requireAppend(receipt.append);
    inline for (.{ "content", "producer", "operation", "partition", "kind", "schema" }) |field| {
        var changed = receipt.append;
        if (comptime std.mem.eql(u8, field, "content")) changed.payload.sha256[0] ^= 1;
        if (comptime std.mem.eql(u8, field, "producer")) changed.producer.?.epoch += 1;
        if (comptime std.mem.eql(u8, field, "operation")) changed.operation.operation -= 1;
        if (comptime std.mem.eql(u8, field, "partition")) changed.target.partition += 1;
        if (comptime std.mem.eql(u8, field, "kind")) changed.kind = .queue;
        if (comptime std.mem.eql(u8, field, "schema")) changed.target.interpretation.digest[0] ^= 1;
        try t.expectError(error.LogAppendConflict, receipt.requireAppend(changed));
    }
    var changed = receipt;
    changed.first = changed.next;
    try t.expectError(error.InvalidLogAppendReceipt, changed.validate());
    changed = receipt;
    changed.append.rows += 1;
    try t.expectError(error.InvalidLogAppendReceipt, changed.validate());
    changed = receipt;
    changed.accepted.next_lsn = 0;
    try t.expectError(error.InvalidLogAppendReceipt, changed.validate());
}

test "stream filtered coverage permits empty complete ranges but never silent history gaps" {
    const parsed = try fixture();
    defer parsed.deinit();
    var coverage = parsed.value.offset_commit.coverage;
    coverage.rows = 0;
    try coverage.validate();
    coverage.from = coverage.until;
    try coverage.validate();
    coverage.complete = false;
    try t.expectError(error.InvalidLogCoverage, coverage.validate());
    coverage = parsed.value.offset_commit.coverage;
    coverage.from = coverage.cut.retained_from - 1;
    try t.expectError(error.LogHistoryUnavailable, coverage.validate());
    coverage = parsed.value.offset_commit.coverage;
    coverage.rows = 5;
    try t.expectError(error.InvalidLogCoverage, coverage.validate());
    coverage = parsed.value.offset_commit.coverage;
    coverage.through -= 1;
    try t.expectError(error.InvalidLogCoverage, coverage.validate());
    coverage.complete = false;
    try coverage.validate();
}

test "stream group settlement fences stale owners incomplete coverage and skipped checkpoints" {
    const parsed = try fixture();
    defer parsed.deinit();
    const commit = parsed.value.offset_commit;
    try commit.requireCurrent(commit.group, commit.expected_next);
    var group = commit.group;
    group.generation += 1;
    try t.expectError(error.LogGroupFenced, commit.requireCurrent(group, commit.expected_next));
    group = commit.group;
    group.principal += 1;
    try t.expectError(error.LogGroupFenced, commit.requireCurrent(group, commit.expected_next));
    try t.expectError(error.LogOffsetConflict, commit.requireCurrent(commit.group, commit.next));
    var changed = commit;
    changed.coverage.through -= 1;
    changed.coverage.complete = false;
    try t.expectError(error.InvalidOffsetCommit, changed.validate());
    changed = commit;
    changed.expected_next -= 1;
    try t.expectError(error.InvalidOffsetCommit, changed.validate());
    changed = commit;
    changed.next -= 1;
    try t.expectError(error.InvalidOffsetCommit, changed.validate());
}

test "queue expired unassigned lease fails without relying on a successor epoch" {
    const parsed = try fixture();
    defer parsed.deinit();
    const settlement = parsed.value.settlement.settlement;
    const lease = settlement.lease;
    try settlement.requireLive(lease, 999);
    try t.expectError(error.QueueLeaseExpired, settlement.requireLive(lease, 1000));
    try t.expectError(error.QueueLeaseExpired, settlement.requireLive(lease, 1001));
    try t.expectError(error.QueueTimeUnavailable, settlement.requireLive(lease, null));
    var reassigned = lease;
    reassigned.epoch += 1;
    try t.expectError(error.QueueLeaseFenced, settlement.requireLive(reassigned, 999));
    var renewed = lease;
    renewed.expires_ms += 1;
    try t.expectError(error.QueueLeaseFenced, settlement.requireLive(renewed, 999));
    var foreign = lease;
    foreign.target.partition += 1;
    try t.expectError(error.QueueLeaseFenced, settlement.requireLive(foreign, 999));
}

test "stream group assignment is explicit preserves checkpoints and fences concurrent progress" {
    const parsed = try fixture();
    defer parsed.deinit();
    const receipt = parsed.value.group_assignment;
    const assignment = receipt.assignment;
    const previous = assignment.expected.?;
    try assignment.requireCurrent(previous, assignment.cut);
    const reassigned = try assignment.resulting();
    try t.expectEqual(previous.next, reassigned.next);
    try t.expectEqual(previous.group.generation + 1, reassigned.group.generation);
    try t.expectEqual(@as(u64, 19), reassigned.group.principal);
    var advanced = previous;
    advanced.next += 1;
    try t.expectError(error.LogGroupAssignmentConflict, assignment.requireCurrent(advanced, assignment.cut));
    try t.expectError(error.LogGroupAssignmentConflict, assignment.requireCurrent(null, assignment.cut));
    try t.expectError(error.LogGroupFenced, reassigned.advance(parsed.value.offset_commit));
    // Later progress or reassignment cannot rewrite the original accepted result.
    try receipt.requireAssignment(assignment);
    var changed = assignment;
    changed.group.principal += 1;
    try t.expectError(error.LogGroupAssignmentConflict, receipt.requireAssignment(changed));
    changed = assignment;
    changed.next += 1;
    try t.expectError(error.InvalidLogGroupAssignment, changed.validate());
    changed = assignment;
    changed.group.generation += 1;
    try t.expectError(error.InvalidLogGroupAssignment, changed.validate());
    changed = assignment;
    changed.expected.?.group.generation = std.math.maxInt(u64);
    try t.expectError(error.LogGroupGenerationExhausted, changed.validate());
    var cut = assignment.cut;
    cut.retained_from = assignment.next + 1;
    try t.expectError(error.LogHistoryUnavailable, assignment.requireCurrent(previous, cut));
    cut = assignment.cut;
    cut.target.interpretation.revision += 1;
    try t.expectError(error.LogPartitionConflict, assignment.requireCurrent(previous, cut));
    // A later declaration may explicitly retain the old group checkpoint.
    changed = assignment;
    changed.cut = cut;
    try changed.requireCurrent(previous, cut);
    var initial = assignment;
    initial.expected = null;
    initial.group.generation = 1;
    initial.next = initial.cut.retained_from;
    try initial.requireCurrent(null, initial.cut);
    try t.expectError(error.LogGroupAssignmentConflict, initial.requireCurrent(previous, initial.cut));
    initial.next = initial.cut.next;
    try initial.validate();
    initial.next = initial.cut.retained_from - 1;
    try t.expectError(error.LogHistoryUnavailable, initial.validate());
}

test "stream offset receipt retains original settlement independently of later assignments" {
    const parsed = try fixture();
    defer parsed.deinit();
    const receipt = parsed.value.offset_receipt;
    const progress = try parsed.value.group_progress.advance(receipt.commit);
    try t.expectEqual(receipt.commit.next, progress.next);
    try t.expectError(error.LogOffsetConflict, progress.advance(receipt.commit));
    try receipt.requireCommit(receipt.commit);
    var changed = receipt.commit;
    changed.operation.operation -= 1;
    try t.expectError(error.LogOffsetConflict, receipt.requireCommit(changed));
    var invalid = receipt;
    invalid.accepted = receipt.commit.coverage.cut.accepted;
    try t.expectError(error.InvalidOffsetReceipt, invalid.validate());
    invalid = receipt;
    invalid.accepted.partition += 1;
    try t.expectError(error.InvalidOffsetReceipt, invalid.validate());
    changed = receipt.commit;
    changed.coverage.cut.target.partition += 1;
    try t.expectError(error.LogPartitionConflict, parsed.value.group_progress.advance(changed));
}

test "queue accepted original settlement survives later expiry without renewing execution authority" {
    const parsed = try fixture();
    defer parsed.deinit();
    const receipt = parsed.value.settlement;
    try t.expectError(error.QueueLeaseExpired, receipt.settlement.requireLive(receipt.settlement.lease, 1000));
    try receipt.requireSettlement(receipt.settlement);
    var changed = receipt.settlement;
    changed.action = .{ .nack = .{ .visible_ms = 2000 } };
    try t.expectError(error.QueueSettlementConflict, receipt.requireSettlement(changed));
    changed = receipt.settlement;
    changed.operation.principal += 1;
    try t.expectError(error.InvalidQueueSettlement, changed.validate());
    changed = receipt.settlement;
    changed.operation.operation = changed.lease.claim.operation;
    try t.expectError(error.InvalidQueueSettlement, changed.validate());
    changed = receipt.settlement;
    changed.action = .{ .extend = .{ .expires_ms = changed.lease.expires_ms } };
    try t.expectError(error.InvalidQueueSettlement, changed.validate());
    changed.action.extend.expires_ms += 1;
    try changed.validate();
}

test "stream queue persisted binding has no missing or foreign definition fallback" {
    const parsed = try fixture();
    defer parsed.deinit();
    const bytes = try p.Json.valueAlloc(t.allocator, parsed.value.append.append.target);
    defer t.allocator.free(bytes);
    const comma = std.mem.indexOfScalar(u8, bytes, ',').?;
    const missing = try std.fmt.allocPrint(t.allocator, "{{{s}", .{bytes[comma + 1 ..]});
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(q.Partition, t.allocator, missing));
    const foreign = try t.allocator.dupe(u8, bytes);
    defer t.allocator.free(foreign);
    const at = std.mem.indexOf(u8, foreign, @tagName(p.Growth.current_definition)).?;
    foreign[at] = if (foreign[at] == '0') '1' else '0';
    try t.expectError(error.InvalidJsonShape, p.Json.parseFromSlice(q.Partition, t.allocator, foreign));
}

test "producer floors fence epochs sequence gaps other principals and discarded receipts" {
    const parsed = try fixture();
    defer parsed.deinit();
    var append = parsed.value.append.append;
    append.producer.?.epoch = 1;
    append.producer.?.sequence = 1;
    const initial = try q.ProducerState.initial(append);
    try t.expectEqual(.retry, try initial.check(append));
    append.producer.?.sequence = 3;
    try t.expectError(error.LogProducerSequenceGap, initial.check(append));
    append.producer.?.sequence = 2;
    try t.expectEqual(.append, try initial.check(append));
    // Definition changes preserve the producer's stable object/partition scope.
    append.target.interpretation.revision += 1;
    try t.expectEqual(.append, try initial.check(append));
    append.operation.principal += 1;
    try t.expectError(error.LogProducerConflict, initial.check(append));
    append.operation.principal -= 1;
    append.producer.?.epoch = 2;
    try t.expectError(error.LogProducerSequenceGap, initial.check(append));
    append.producer.?.sequence = 1;
    try t.expectEqual(.advance_epoch, try initial.check(append));
    const renewed = try q.ProducerState.initial(append);
    append.producer.?.epoch = 1;
    try t.expectError(error.LogProducerFenced, renewed.check(append));
    const expired = try initial.forgetThrough(1);
    try t.expectError(error.LogProducerReceiptExpired, expired.check(append));
    try t.expectError(error.InvalidLogProducerFloor, expired.forgetThrough(0));
    append = parsed.value.append.append;
    try t.expectEqual(.retry, try parsed.value.producer.check(append));
    const exhausted = try parsed.value.producer.forgetThrough(std.math.maxInt(u64));
    try t.expectError(error.LogProducerReceiptExpired, exhausted.check(append));
    append.producer.?.epoch += 1;
    append.producer.?.sequence = 1;
    try t.expectEqual(.advance_epoch, try exhausted.check(append));
}

test "claim receipts preserve exact empty selection and expiry and trusted time never rolls back" {
    const parsed = try fixture();
    defer parsed.deinit();
    var receipt = parsed.value.claim;
    try receipt.requireClaim(receipt.claim);
    var changed = receipt.claim;
    changed.maximum += 1;
    try t.expectError(error.QueueClaimConflict, receipt.requireClaim(changed));
    receipt.rows = 0;
    try t.expectError(error.InvalidQueueClaimReceipt, receipt.validate());
    receipt.leases = null;
    try receipt.validate();
    receipt.expires_ms += 1;
    try t.expectError(error.InvalidQueueClaimReceipt, receipt.validate());
    receipt.observed_ms = std.math.maxInt(u64);
    try t.expectError(error.QueueLeaseDeadlineOverflow, receipt.validate());
    try t.expectEqual(@as(u64, 500), try parsed.value.clock.observe(500));
    try t.expectError(error.QueueTimeRegression, parsed.value.clock.observe(499));
    try t.expectError(error.QueueTimeUnavailable, parsed.value.clock.observe(null));
}
