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
        .{},
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
        .{},
    );

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
        .{},
    );
    try t.expectEqualDeep(rec3, try owner.applyMutation(mut3, payload3, state3, 0, policy.guard()));
}
