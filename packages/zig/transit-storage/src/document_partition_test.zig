const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const s = @import("root.zig");
const d = p.DataLifecycle;
const doc = p.DocumentOperation;

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
const sample_columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "doc_key", .type = .utf8, .nullable = false, .collation = .utf8_binary },
};

fn sampleDefinition() s.DocumentDeclaration.Definition {
    return .{
        .object = .{
            .scope = .{ .realm = 1, .resource = 2, .catalog = 3 },
            .branch = 1,
            .object = 505,
        },
        .revision = 1,
        .schema = .{
            .object = 505,
            .revision = 1,
            .next_column = 2,
            .columns = &sample_columns,
        },
        .configuration = .{
            .partitioning = .{ .count = 4, .key_column = 1, .hash = .sha256_64 },
            .profile = .causal_crdt,
            .shredding = .{
                .frequent_path_threshold = 64,
                .max_shredded_columns = 32,
                .default_collation = .utf8_binary,
            },
            .retention = .{ .max_age_ms = null, .merge_window_revisions = 16 },
        },
        .limits = .{
            .change_bytes = 65_536,
            .operations_per_change = 64,
            .path_depth = 32,
            .read_steps = 4096,
            .read_bytes = 262_144,
            .unresolved_conflicts = 16,
        },
        .properties = "doc-partition-props",
    };
}

fn operation(id: u64) d.Operation {
    return .{
        .scope = sampleDefinition().object.scope,
        .principal = 7,
        .operation = id,
    };
}

fn hashBytes(bytes: []const u8) [32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}

test "document read authority matches shared protocol fixture and rejects modified cursor" {
    const parsed = try p.Json.parseFromSlice(
        doc.SchemaTypes,
        t.allocator,
        doc.fixture_json,
    );
    defer parsed.deinit();
    const authority = try s.DocumentRead.Authority.init(@splat(7));
    try authority.verify(parsed.value.read_cursor);
    const re_signed = try authority.sign(parsed.value.read_cursor.read, parsed.value.read_cursor.coverage);
    try t.expectEqualDeep(parsed.value.read_cursor, re_signed);

    var tampered = parsed.value.read_cursor;
    tampered.coverage.bytes += 1;
    try t.expectError(error.InvalidDocumentCursor, authority.verify(tampered));
}

test "document partition disk recovery preserves mutations checkpoints retained reads and trimmed baselines" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();

    var owned_decl = try s.DocumentDeclaration.prepare(t.allocator, sampleDefinition());
    defer owned_decl.deinit();
    const declared = try s.DocumentDeclaration.stage(objects.objectStore(), &owned_decl);
    var policy: Policy = .{};
    const init_req: s.DocumentInitialization.Request = .{
        .definition = p.Growth.current_definition,
        .declared = declared,
        .operation = operation(1),
        .ordinal = 0,
        .partition = 111,
    };
    _ = try s.DocumentInitialization.initialize(t.allocator, wal.log(), objects.objectStore(), init_req, policy.guard());

    var owner = try s.DocumentPartition.open(
        t.allocator,
        wal.log(),
        objects.objectStore(),
        init_req,
        policy.guard(),
        .{ .read_secret = @splat(7) },
    );
    defer owner.deinit();

    const doc_id: [16]u8 = @splat(0x21);
    const rep_id: [16]u8 = @splat(0x31);
    const target: doc.Target = .{
        .partition = init_req.target(),
        .document = doc_id,
    };

    const payload1 = "delta-op-1";
    const state1 = "{\"title\":\"v1\"}";
    const mut1: doc.Mutation = .{
        .target = target,
        .operation = operation(2),
        .lineage = .{
            .profile = .causal_crdt,
            .merge_epoch = 1,
            .base_revision = 0,
            .parent_revision = null,
            .replica = .{ .id = rep_id, .epoch = 1, .sequence = 1, .preceding_sequence = 0 },
            .raw_span = null,
        },
        .operations = 1,
        .payload = .{ .bytes = payload1.len, .sha256 = hashBytes(payload1) },
    };
    const rec1 = try owner.applyMutation(mut1, payload1, state1, 0, policy.guard());
    try t.expectEqual(@as(u64, 1), rec1.accepted_revision);
    try t.expectEqual(@as(u64, 2), rec1.accepted.next_lsn);
    const appends_after_m1 = wal.appends;
    // Exact retry returns the original receipt without appending to the WAL.
    try t.expectEqualDeep(rec1, try owner.applyMutation(mut1, payload1, state1, 0, policy.guard()));
    try t.expectEqual(appends_after_m1, wal.appends);

    // Different mutation with the same operation ID conflicts.
    var conflicting_mut1 = mut1;
    conflicting_mut1.operations = 2;
    try t.expectError(
        error.DocumentMutationConflict,
        owner.applyMutation(conflicting_mut1, payload1, state1, 0, policy.guard()),
    );

    // Replica sequence gap is rejected before WAL append.
    const payload2 = "delta-op-2";
    const state2 = "{\"title\":\"v2\"}";
    var mut2: doc.Mutation = .{
        .target = target,
        .operation = operation(3),
        .lineage = .{
            .profile = .causal_crdt,
            .merge_epoch = 1,
            .base_revision = 1,
            .parent_revision = null,
            .replica = .{ .id = rep_id, .epoch = 1, .sequence = 3, .preceding_sequence = 2 },
            .raw_span = null,
        },
        .operations = 1,
        .payload = .{ .bytes = payload2.len, .sha256 = hashBytes(payload2) },
    };
    try t.expectError(
        error.DocumentReplicaSequenceGap,
        owner.applyMutation(mut2, payload2, state2, 0, policy.guard()),
    );
    mut2.lineage.replica = .{ .id = rep_id, .epoch = 1, .sequence = 2, .preceding_sequence = 1 };
    const rec2 = try owner.applyMutation(mut2, payload2, state2, 0, policy.guard());
    try t.expectEqual(@as(u64, 2), rec2.accepted_revision);

    // Finite merge-window checkpoint advances merge_epoch to 2 and retained_from to 2.
    const cp_req: doc.Checkpoint = .{
        .target = target,
        .operation = operation(4),
        .previous_epoch = 1,
        .next_epoch = 2,
        .retained_from = 2,
        .checkpoint_revision = 2,
        .checkpoint = .{ .bytes = state2.len, .sha256 = hashBytes(state2) },
    };
    const cp_rec = try owner.publishCheckpoint(cp_req, state2, policy.guard());
    try t.expectEqual(@as(u64, 2), cp_rec.cut.merge_epoch);
    try t.expectEqual(@as(u64, 2), cp_rec.cut.retained_from);
    try t.expectEqualDeep(cp_rec, try owner.publishCheckpoint(cp_req, state2, policy.guard()));

    // Stale merge_epoch or pruned base_revision is fenced.
    const payload3 = "delta-op-3";
    const state3 = "{\"title\":\"v3\"}";
    var mut3: doc.Mutation = .{
        .target = target,
        .operation = operation(5),
        .lineage = .{
            .profile = .causal_crdt,
            .merge_epoch = 1,
            .base_revision = 2,
            .parent_revision = null,
            .replica = .{ .id = rep_id, .epoch = 1, .sequence = 3, .preceding_sequence = 2 },
            .raw_span = null,
        },
        .operations = 1,
        .payload = .{ .bytes = payload3.len, .sha256 = hashBytes(payload3) },
    };
    try t.expectError(
        error.DocumentEpochFenced,
        owner.applyMutation(mut3, payload3, state3, 0, policy.guard()),
    );
    mut3.lineage.merge_epoch = 2;
    mut3.lineage.replica = .{ .id = rep_id, .epoch = 2, .sequence = 1, .preceding_sequence = 0 };
    mut3.lineage.base_revision = 1;
    try t.expectError(
        error.DocumentHistoryUnavailable,
        owner.applyMutation(mut3, payload3, state3, 0, policy.guard()),
    );
    mut3.lineage.base_revision = 2;
    const rec3 = try owner.applyMutation(mut3, payload3, state3, 0, policy.guard());
    try t.expectEqual(@as(u64, 3), rec3.accepted_revision);

    // Begin retained read for revisions 2..3.
    var read_req: doc.Read.Request = .{
        .target = target,
        .operation = operation(6),
        .from_revision = 1,
        .through_revision = 3,
        .max_steps = 16,
        .max_bytes = 4096,
    };
    try t.expectError(error.DocumentHistoryUnavailable, owner.beginRead(read_req, policy.guard()));
    read_req.from_revision = 2;
    const read_rec = try owner.beginRead(read_req, policy.guard());
    const cursor0 = try owner.readCursor(read_rec, policy.guard());
    try t.expect(!cursor0.coverage.complete);

    // Reopen from disk and resume read cursor.
    owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    policy.epoch = 2;
    owner = try s.DocumentPartition.open(
        t.allocator,
        wal.log(),
        objects.objectStore(),
        init_req,
        policy.guard(),
        .{ .read_secret = @splat(7), .recovery_records = 1 },
    );

    try t.expect(!owner.ready);
    try t.expectError(error.DocumentRecoveryRequired, owner.readNextRevision(t.allocator, cursor0, policy.guard()));
    var recovery_steps: usize = 0;
    while (!owner.ready) : (recovery_steps += 1) {
        try t.expect(recovery_steps < 16);
        const progress = try owner.recoverStep(policy.guard(), 1);
        try t.expectEqual(@as(u16, 1), progress.examined);
        try t.expectEqual(owner.ready, progress.complete);
    }

    var step1 = (try owner.readNextRevision(t.allocator, cursor0, policy.guard())).?;
    defer step1.deinit(t.allocator);
    try t.expectEqual(@as(u64, 2), step1.revision);
    try t.expectEqualStrings(state2, step1.state);
    try t.expect(!step1.cursor.coverage.complete);

    var step2 = (try owner.readNextRevision(t.allocator, step1.cursor, policy.guard())).?;
    defer step2.deinit(t.allocator);
    try t.expectEqual(@as(u64, 3), step2.revision);
    try t.expectEqualStrings(state3, step2.state);
    try t.expect(step2.cursor.coverage.complete);
    try t.expectEqual(@as(?s.DocumentPartition.RevisionStep, null), try owner.readNextRevision(t.allocator, step2.cursor, policy.guard()));
    // A later fetch must not invalidate the earlier caller-owned state.
    try t.expectEqualStrings(state2, step1.state);

    // A live handle does not allow its receipt to be relabelled or another
    // Document to release it.
    var relabelled = read_rec;
    relabelled.accepted.next_lsn += 1;
    try t.expectError(error.DocumentReadConflict, owner.readCursor(relabelled, policy.guard()));
    var wrong_target = target;
    wrong_target.document = @splat(0x22);
    try t.expectError(error.DocumentTargetConflict, owner.releaseRead(.{
        .target = wrong_target,
        .operation = operation(20),
        .read = read_rec.handle(),
    }, policy.guard()));

    // Both budgets are cumulative. Refusal preserves the caller's cursor and
    // cannot turn the delivered prefix into successful terminal coverage.
    var bounded_req = read_req;
    bounded_req.operation = operation(21);
    bounded_req.max_steps = 1;
    const bounded_read = try owner.beginRead(bounded_req, policy.guard());
    const bounded_start = try owner.readCursor(bounded_read, policy.guard());
    var bounded_step = (try owner.readNextRevision(t.allocator, bounded_start, policy.guard())).?;
    defer bounded_step.deinit(t.allocator);
    try t.expect(!bounded_step.cursor.coverage.complete);
    try t.expectError(error.DocumentReadLimitExceeded, owner.readNextRevision(t.allocator, bounded_step.cursor, policy.guard()));
    var repeated = (try owner.readNextRevision(t.allocator, bounded_start, policy.guard())).?;
    defer repeated.deinit(t.allocator);
    try t.expectEqualDeep(bounded_step.cursor, repeated.cursor);
    try t.expectEqualStrings(bounded_step.state, repeated.state);

    bounded_req.operation = operation(22);
    bounded_req.max_steps = 16;
    bounded_req.max_bytes = state2.len + state3.len - 1;
    const byte_read = try owner.beginRead(bounded_req, policy.guard());
    var byte_step = (try owner.readNextRevision(t.allocator, try owner.readCursor(byte_read, policy.guard()), policy.guard())).?;
    defer byte_step.deinit(t.allocator);
    try t.expectError(error.DocumentReadLimitExceeded, owner.readNextRevision(t.allocator, byte_step.cursor, policy.guard()));

    // The rejected revision must not allocate its payload even when it alone
    // exceeds the request budget.
    bounded_req.operation = operation(23);
    bounded_req.max_bytes = state2.len - 1;
    const tiny_read = try owner.beginRead(bounded_req, policy.guard());
    const tiny_cursor = try owner.readCursor(tiny_read, policy.guard());
    var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    try t.expectError(error.DocumentReadLimitExceeded, owner.readNextRevision(failing.allocator(), tiny_cursor, policy.guard()));
    try t.expectEqual(@as(usize, 0), failing.alloc_index);

    // Current authorization gates both a buffered state and an empty terminal
    // observation. The failed buffered read releases its output allocation.
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.readNextRevision(t.allocator, cursor0, policy.guard()));
    policy.deny_at = std.math.maxInt(usize);
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.readNextRevision(t.allocator, step2.cursor, policy.guard()));
    policy.deny_at = std.math.maxInt(usize);

    const release_req: doc.Read.Release = .{
        .target = target,
        .operation = operation(7),
        .read = read_rec.handle(),
    };
    const release_rec = try owner.releaseRead(release_req, policy.guard());
    try t.expectEqualDeep(release_rec, try owner.releaseRead(release_req, policy.guard()));
    try t.expectError(error.DocumentReadReleased, owner.readNextRevision(t.allocator, cursor0, policy.guard()));

    // Enumerate roots before checkpointing.
    {
        var roots = try s.DocumentStorageRoots.Cursor.init(init_req, owner.root.next_lsn);
        var count: usize = 0;
        while (true) {
            switch (try roots.step(t.allocator, wal.log(), objects.objectStore())) {
                .empty => unreachable,
                .root => count += 1,
                .complete => break,
            }
        }
        try t.expect(count >= 2);
    }

    // Archive, checkpoint recovery, trim WAL, and reopen from trimmed WAL.
    const archive_cov = try owner.archive(owner.root.position(), .{}, policy.guard());
    try t.expect(archive_cov.through > 1);
    try t.expectError(error.DocumentCheckpointRequired, owner.trimArchived(policy.guard()));
    const recovery_ref = try owner.checkpointRecovery(owner.root.position(), policy.guard());
    try t.expect(recovery_ref.next_lsn >= archive_cov.through);
    const trimmed_through = try owner.trimArchived(policy.guard());
    try t.expectEqual(archive_cov.through, trimmed_through);

    // Even after WAL trim past lsn 0, DocumentInitialization.observe and DocumentStorageRoots succeed.
    const observed_init = try s.DocumentInitialization.observe(
        t.allocator,
        wal.log(),
        objects.objectStore(),
        init_req,
        policy.guard(),
    );
    try t.expectEqual(init_req.partition, observed_init.accepted.partition);
    {
        var roots = try s.DocumentStorageRoots.Cursor.init(init_req, owner.root.next_lsn);
        var count: usize = 0;
        while (true) {
            switch (try roots.step(t.allocator, wal.log(), objects.objectStore())) {
                .empty => unreachable,
                .root => count += 1,
                .complete => break,
            }
        }
        try t.expect(count >= 2);
    }

    owner.deinit();
    owner = try s.DocumentPartition.open(
        t.allocator,
        wal.log(),
        objects.objectStore(),
        init_req,
        policy.guard(),
        .{ .read_secret = @splat(7) },
    );
    try t.expectEqualDeep(rec3, try owner.applyMutation(mut3, payload3, state3, 0, policy.guard()));
}

test "document recovery bounds replay scratch and fences interrupted or invalid history" {
    // The disk test above owns persistence evidence; this memory fixture isolates
    // scratch growth across a longer replay without provider I/O allocations.
    var wal = s.LocalWal.LocalWal.initMemory(t.allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var definition = try s.DocumentDeclaration.prepare(t.allocator, sampleDefinition());
    defer definition.deinit();
    const declared = try s.DocumentDeclaration.stage(objects.objectStore(), &definition);
    var policy: Policy = .{};
    const initial: s.DocumentInitialization.Request = .{
        .definition = p.Growth.current_definition,
        .declared = declared,
        .operation = operation(1),
        .ordinal = 0,
        .partition = 112,
    };
    _ = try s.DocumentInitialization.initialize(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard());
    const options: s.DocumentPartition.Options = .{ .read_secret = @splat(9), .recovery_records = 1 };
    var owner = try s.DocumentPartition.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), options);
    defer owner.deinit();
    const payload = "replay-payload";
    const state = "replay-state";
    var mutation: doc.Mutation = .{
        .target = .{ .partition = initial.target(), .document = @splat(0x33) },
        .operation = operation(2),
        .lineage = .{
            .profile = .causal_crdt,
            .merge_epoch = 1,
            .base_revision = 0,
            .parent_revision = null,
            .replica = .{ .id = @splat(0x44), .epoch = 1, .sequence = 1, .preceding_sequence = 0 },
            .raw_span = null,
        },
        .operations = 1,
        .payload = .{ .bytes = payload.len, .sha256 = hashBytes(payload) },
    };
    var last: doc.MutationReceipt = undefined;
    for (0..40) |index| {
        mutation.operation = operation(index + 2);
        mutation.lineage.base_revision = index;
        mutation.lineage.replica.?.sequence = index + 1;
        mutation.lineage.replica.?.preceding_sequence = index;
        last = try owner.applyMutation(mutation, payload, state, 0, policy.guard());
    }
    const appends = wal.appends;
    owner.deinit();
    owner = try s.DocumentPartition.open(t.allocator, wal.log(), objects.objectStore(), initial, policy.guard(), options);
    try t.expectEqual(@as(u64, 2), owner.root.next_lsn);
    try t.expect(!owner.ready);
    try t.expectError(error.DocumentRecoveryRequired, owner.applyMutation(mutation, payload, state, 0, policy.guard()));
    try t.expectError(error.InvalidDocumentRecoveryBudget, owner.recoverStep(policy.guard(), 0));
    try t.expectError(error.InvalidDocumentRecoveryBudget, owner.recoverStep(policy.guard(), 257));

    // Revoke after decoding a record but before installing it. Neither readiness
    // nor the published replay position may advance on that refusal.
    const before = owner.root.position();
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.recoverStep(policy.guard(), 1));
    try t.expectEqualDeep(before, owner.root.position());
    try t.expect(!owner.ready);
    policy.deny_at = std.math.maxInt(usize);

    // Warm the largest frame/JSON workspace using single-record steps, then
    // replay the remaining 24 records together. Scratch must not scale with the
    // number of records in a call. Allow allocator growth to its next capacity.
    var warm_capacity: usize = owner.scratch.queryCapacity();
    for (0..15) |_| {
        const progress = try owner.recoverStep(policy.guard(), 1);
        try t.expectEqual(@as(u16, 1), progress.examined);
        try t.expect(!progress.complete);
        warm_capacity = @max(warm_capacity, owner.scratch.queryCapacity());
    }
    const complete = try owner.recoverStep(policy.guard(), 32);
    try t.expectEqual(@as(u16, 24), complete.examined);
    try t.expect(complete.complete);
    try t.expectEqual(@as(u64, 41), complete.position.next_lsn);
    try t.expect(owner.scratch.queryCapacity() <= warm_capacity * 2);
    try t.expectEqualDeep(last, try owner.applyMutation(mutation, payload, state, 0, policy.guard()));
    try t.expectEqual(appends, wal.appends);

    // A failed recovery call also fences an owner that had previously been ready.
    policy.deny_at = policy.calls + 1;
    try t.expectError(error.PermissionDenied, owner.recoverStep(policy.guard(), 1));
    try t.expect(!owner.ready);
    policy.deny_at = std.math.maxInt(usize);
    try t.expect((try owner.recoverStep(policy.guard(), 1)).complete);

    // Invalid history fails open with exactly one cleanup of its moved TreeStore.
    // The testing allocator detects leaks and the former double-free error path.
    var invalid_root = owner.root;
    invalid_root.next_lsn += 1;
    var buffer: [s.DocumentPartitionRecord.max_bytes]u8 = undefined;
    const bytes = try s.DocumentPartitionRecord.encode(.{
        .definition = p.Growth.current_definition,
        .previous_commitment = @splat(0x55),
        .root = invalid_root,
        .action = .{ .declaration = declared },
        .evidence = null,
    }, &buffer);
    _ = try wal.log().append(initial.partition, owner.root.next_lsn, 1, 1, .manifest_checkpoint, bytes);
    try t.expectError(error.InvalidDocumentPartitionRecord, s.DocumentPartition.open(
        t.allocator,
        wal.log(),
        objects.objectStore(),
        initial,
        policy.guard(),
        .{ .read_secret = @splat(9) },
    ));
}

test "document partition evaluates causal trees pages large values and recovers change aliases on disk" {
    const logical = @import("transit_document").LogicalChange;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var owned = try s.DocumentDeclaration.prepare(t.allocator, sampleDefinition());
    defer owned.deinit();
    const declared = try s.DocumentDeclaration.stage(objects.objectStore(), &owned);
    var policy: Policy = .{};
    const init_req: s.DocumentInitialization.Request = .{ .definition = p.Growth.current_definition, .declared = declared, .operation = operation(1), .ordinal = 0, .partition = 111 };
    _ = try s.DocumentInitialization.initialize(t.allocator, wal.log(), objects.objectStore(), init_req, policy.guard());
    var owner = try s.DocumentPartition.open(t.allocator, wal.log(), objects.objectStore(), init_req, policy.guard(), .{ .read_secret = @splat(7) });
    defer owner.deinit();
    const header: logical.Header = .{ .definition = p.Growth.definition_bytes, .document = @splat(0x81), .replica = @splat(0x91), .epoch = 1, .sequence = 1, .preceding_sequence = 0, .operations = 12 };
    const long_name: [160]u8 = @splat('n');
    const long_value: [5000]u8 = @splat('v');
    var ops: [12]logical.Operation = undefined;
    var names: [10][2]u8 = undefined;
    ops[0] = .{ .field = "nested", .value = .{ .kind = .map } };
    ops[1] = .{ .object = header.dot(0), .field = &long_name, .value = .{ .kind = .string, .bytes = &long_value } };
    for (ops[2..], &names, 0..) |*op, *name, i| {
        name.* = .{ 'f', @as(u8, @intCast(i)) + '0' };
        op.* = .{ .field = name, .value = .{ .kind = .null_value } };
    }
    var buffer: [16384]u8 = undefined;
    const bytes = try logical.encode(header, &ops, &buffer);
    const target: doc.Target = .{ .partition = init_req.target(), .document = header.document };
    const mutation: doc.Mutation = .{ .target = target, .operation = operation(2), .lineage = .{ .profile = .causal_crdt, .merge_epoch = 1, .base_revision = 0, .parent_revision = null, .replica = .{ .id = header.replica, .epoch = 1, .sequence = 1, .preceding_sequence = 0 }, .raw_span = null }, .operations = header.operations, .payload = .{ .bytes = bytes.len, .sha256 = hashBytes(bytes) } };
    const before = wal.appends;
    var fault: Fault = .{ .underlying = wal.log(), .lose_reply = true };
    owner.log = fault.log();
    try t.expectError(error.DocumentAppendUncertain, owner.applyCausal(mutation, bytes, policy.guard()));
    try t.expectEqual(before + 1, wal.appends);
    try t.expect(!owner.ready);
    owner.deinit();
    wal.deinit();
    objects.deinit();
    wal = try s.LocalWal.LocalWal.openDiskWithOptions(t.allocator, t.io, tmp.dir, "wal", .{});
    objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    owner = try s.DocumentPartition.open(t.allocator, wal.log(), objects.objectStore(), init_req, policy.guard(), .{ .read_secret = @splat(7), .recovery_records = 1 });
    while (!(try owner.recoverStep(policy.guard(), 1)).complete) {}
    const first = try owner.applyCausal(mutation, bytes, policy.guard());
    try t.expectEqual(@as(u64, 1), first.accepted_revision);
    try t.expectEqual(@as(u16, 0), first.unresolved_conflicts);
    try t.expectEqual(@as(u64, 0), wal.appends);
    const replay_appends = wal.appends;
    var alias = mutation;
    alias.operation = operation(3);
    const duplicate = try owner.applyCausal(alias, bytes, policy.guard());
    try t.expectEqual(first.accepted_revision, duplicate.accepted_revision);
    try t.expectEqualDeep(first.state, duplicate.state);
    try t.expectEqual(replay_appends + 1, wal.appends);
    try t.expectEqualDeep(duplicate, try owner.applyCausal(alias, bytes, policy.guard()));
    const read = try owner.beginRead(.{ .target = target, .operation = operation(4), .from_revision = 1, .through_revision = 1, .max_steps = 4096, .max_bytes = 6000 }, policy.guard());
    const path: []const []const u8 = &.{ "nested", &long_name };
    var cursor = try owner.causalCursor(read, path, policy.guard());
    var tampered = cursor;
    tampered.offset = 240;
    try t.expectError(error.InvalidDocumentCursor, owner.readCausalPage(tampered, path, policy.guard()));
    try t.expectError(error.InvalidDocumentCursor, owner.readCausalPage(cursor, &.{"f0"}, policy.guard()));
    var consumed: usize = 0;
    while (try owner.readCausalPage(cursor, path, policy.guard())) |page| {
        try t.expectEqual(.value, page.status);
        try t.expectEqual(logical.Kind.string, page.kind.?);
        try t.expectEqual(consumed, page.offset);
        try t.expectEqualSlices(u8, long_value[consumed..][0..page.data.len], page.data.slice());
        consumed += page.data.len;
        cursor = page.cursor;
    }
    try t.expectEqual(long_value.len, consumed);
    try t.expect(cursor.complete);
    var null_cursor = try owner.causalCursor(read, &.{"f0"}, policy.guard());
    const null_page = (try owner.readCausalPage(null_cursor, &.{"f0"}, policy.guard())).?;
    try t.expectEqual(.null_value, null_page.status);
    null_cursor = null_page.cursor;
    try t.expect((try owner.readCausalPage(null_cursor, &.{"f0"}, policy.guard())) == null);
    const missing = try owner.causalCursor(read, &.{"absent"}, policy.guard());
    try t.expectEqual(.missing, (try owner.readCausalPage(missing, &.{"absent"}, policy.guard())).?.status);
    const wrong_type = try owner.causalCursor(read, &.{ "f0", "child" }, policy.guard());
    try t.expectEqual(.type_error, (try owner.readCausalPage(wrong_type, &.{ "f0", "child" }, policy.guard())).?.status);
    const fresh = try owner.causalCursor(read, path, policy.guard());
    policy.deny_at = policy.calls + 2;
    try t.expectError(error.PermissionDenied, owner.readCausalPage(fresh, path, policy.guard()));
    policy.deny_at = std.math.maxInt(usize);
    const short_read = try owner.beginRead(.{ .target = target, .operation = operation(5), .from_revision = 1, .through_revision = 1, .max_steps = 4096, .max_bytes = 100 }, policy.guard());
    try t.expectError(error.DocumentReadLimitExceeded, owner.readCausalPage(try owner.causalCursor(short_read, path, policy.guard()), path, policy.guard()));
    var next_header = header;
    next_header.sequence = 2;
    next_header.preceding_sequence = 1;
    next_header.operations = 1;
    var next_buffer: [1024]u8 = undefined;
    const next_bytes = try logical.encode(next_header, &.{.{ .object = header.dot(0), .field = &long_name, .observed = &header.dot(1).bytes(), .value = .{ .kind = .string } }}, &next_buffer);
    var next_mutation = mutation;
    next_mutation.operation = operation(8);
    next_mutation.operations = 1;
    next_mutation.lineage.base_revision = 1;
    next_mutation.lineage.replica.?.sequence = 2;
    next_mutation.lineage.replica.?.preceding_sequence = 1;
    next_mutation.payload = .{ .bytes = next_bytes.len, .sha256 = hashBytes(next_bytes) };
    const second = try owner.applyCausal(next_mutation, next_bytes, policy.guard());
    try t.expectEqual(@as(u64, 2), second.accepted_revision);
    try t.expectEqualSlices(u8, long_value[0..240], (try owner.readCausalPage(fresh, path, policy.guard())).?.data.slice());
    var concurrent_header = header;
    concurrent_header.replica[15] += 1;
    concurrent_header.operations = 1;
    var concurrent_buffer: [1024]u8 = undefined;
    const concurrent_bytes = try logical.encode(concurrent_header, &.{.{ .object = header.dot(0), .field = &long_name, .value = .{ .kind = .string, .bytes = "concurrent" } }}, &concurrent_buffer);
    var concurrent = mutation;
    concurrent.operation = operation(9);
    concurrent.operations = 1;
    concurrent.lineage.base_revision = 1;
    concurrent.lineage.replica.?.id = concurrent_header.replica;
    concurrent.payload = .{ .bytes = concurrent_bytes.len, .sha256 = hashBytes(concurrent_bytes) };
    const third = try owner.applyCausal(concurrent, concurrent_bytes, policy.guard());
    try t.expectEqual(@as(u64, 3), third.accepted_revision);
    try t.expectEqual(@as(u16, 1), third.unresolved_conflicts);
    const conflict_read = try owner.beginRead(.{ .target = target, .operation = operation(10), .from_revision = 3, .through_revision = 3, .max_steps = 4096, .max_bytes = 6000 }, policy.guard());
    const conflict_first = (try owner.readCausalPage(try owner.causalCursor(conflict_read, path, policy.guard()), path, policy.guard())).?;
    try t.expectEqual(.conflict, conflict_first.status);
    try t.expectEqual(@as(u32, 2), conflict_first.alternatives);
    try t.expectEqual(@as(u16, 0), conflict_first.data.len);
    try t.expect(!conflict_first.cursor.complete);
    const conflict_last = (try owner.readCausalPage(conflict_first.cursor, path, policy.guard())).?;
    try t.expectEqualStrings("concurrent", conflict_last.data.slice());
    try t.expect(conflict_last.cursor.complete);
    var late_alias = mutation;
    late_alias.operation = operation(11);
    try t.expectEqual(@as(u64, 1), (try owner.applyCausal(late_alias, bytes, policy.guard())).accepted_revision);
    // A bad dependency after a valid first edit cannot publish a prefix.
    var invalid_header = next_header;
    invalid_header.sequence = 3;
    invalid_header.preceding_sequence = 2;
    invalid_header.operations = 2;
    var invalid_buffer: [1024]u8 = undefined;
    const invalid_bytes = try logical.encode(invalid_header, &.{
        .{ .field = "unpublished", .value = .{ .kind = .null_value } },
        .{ .object = .{ .replica = @splat(0xef), .sequence = 99 }, .field = "missing-parent", .value = .{ .kind = .map } },
    }, &invalid_buffer);
    var invalid_dependency = next_mutation;
    invalid_dependency.operation = operation(12);
    invalid_dependency.operations = 2;
    invalid_dependency.lineage.replica.?.sequence = 3;
    invalid_dependency.lineage.replica.?.preceding_sequence = 2;
    invalid_dependency.payload = .{ .bytes = invalid_bytes.len, .sha256 = hashBytes(invalid_bytes) };
    const before_refusal = wal.appends;
    try t.expectError(error.DocumentDependencyMissing, owner.applyCausal(invalid_dependency, invalid_bytes, policy.guard()));
    try t.expectEqual(before_refusal, wal.appends);
    var forged = mutation;
    forged.operation = operation(6);
    try t.expectError(error.DocumentLogicalEvaluationRequired, owner.applyMutation(forged, bytes, "supplied state", 0, policy.guard()));
    const appends = wal.appends;
    var invalid = mutation;
    invalid.operation = operation(7);
    invalid.payload = .{ .bytes = bytes.len - 1, .sha256 = hashBytes(bytes[0 .. bytes.len - 1]) };
    try t.expectError(error.InvalidDocumentEncoding, owner.applyCausal(invalid, bytes[0 .. bytes.len - 1], policy.guard()));
    try t.expectEqual(appends, wal.appends);
    owner.deinit();
    owner = try s.DocumentPartition.open(t.allocator, wal.log(), objects.objectStore(), init_req, policy.guard(), .{ .read_secret = @splat(7) });
    try t.expectEqualDeep(duplicate, try owner.applyCausal(alias, bytes, policy.guard()));
    try t.expect((try owner.readCausalPage(cursor, path, policy.guard())) == null);
    _ = try owner.releaseRead(.{ .target = target, .operation = operation(13), .read = read.handle() }, policy.guard());
    try t.expectError(error.DocumentReadReleased, owner.readCausalPage(cursor, path, policy.guard()));
}
