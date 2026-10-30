const std = @import("std");
const testing = std.testing;
const c = @import("root.zig");
const ManagedDataflow = c.ManagedDataflow;
const fuze = c.fuze;
const AnalyticalSql = fuze.AnalyticalSql;
const FuzeDelta = fuze.FuzeDelta;
const v = fuze.Types.Values;

fn intCell(n: i64) v.Cell {
    return .{ .value = .{ .atom = .{ .signed = n } } };
}

fn strCell(s: []const u8) v.Cell {
    return .{ .value = .{ .atom = .{ .bytes = s } } };
}

fn makeRow2(k: i64, s: []const u8) !AnalyticalSql.Row {
    return AnalyticalSql.Row.fromSlice(&.{ intCell(k), strCell(s) });
}

test "T5 and T8 five-state dataflow lifecycle, snapshot-to-live handoff and compacted history protection" {
    const sources = [_]ManagedDataflow.SourceBinding{
        .{ .object_id = 10, .definition_id = 1 },
    };
    const decl: ManagedDataflow.DataflowDeclaration = .{
        .catalog_id = 1,
        .dataflow_id = 100,
        .name = "active_orders_mv",
        .definition_id = 1,
        .kind = .materialized_view,
        .consumer_contract = .complete_ordered_changes,
        .default_resume_policy = .replay_history,
        .sources = &sources,
    };

    // 1. Published: no background work, cannot activate before authorization
    var df = try ManagedDataflow.DataflowRuntime.publish(decl);
    try testing.expectEqual(ManagedDataflow.LifecycleState.published, df.state);
    try testing.expectEqual(ManagedDataflow.BlockedReason.awaiting_authorization, df.blocked_reason);

    var initial_zset: FuzeDelta.ZSet = .{};
    try initial_zset.addRowWeight(try makeRow2(1, "INIT"), 1);
    try testing.expectError(
        error.DataflowNotAuthorized,
        df.establishSnapshotToLiveHandoff(10, 1, 500, &initial_zset),
    );

    // 2. Authorize -> Activate with atomic snapshot-to-live handoff at cut LSN 10
    try df.authorize(3);
    try testing.expectEqual(ManagedDataflow.LifecycleState.authorized, df.state);
    try testing.expectEqual(ManagedDataflow.BlockedReason.none, df.blocked_reason);

    const lease_1 = try df.establishSnapshotToLiveHandoff(10, 1, 500, &initial_zset);
    try testing.expectEqual(@as(u64, 1), lease_1);
    try testing.expectEqual(ManagedDataflow.LifecycleState.active, df.state);
    try testing.expectEqual(@as(u64, 1), df.completed_revision.revision_number);
    try testing.expectEqual(@as(u64, 10), df.checkpoint_lsn);

    // 3. Ingest WAL batch straddling cut LSN 10 (LSN 9 & 10 are skipped as handoff duplicates; LSN 11 applies)
    const wal_batch_1 = [_]ManagedDataflow.WalDeltaRecord{
        .{
            .source_object_id = 10,
            .source_definition_id = 1,
            .tx_id = 50,
            .tx_cut_id = 500,
            .tx_decision = .committed_cut,
            .commit_lsn = 10, // duplicate at cut boundary!
            .manifest_version = 1,
            .row = try makeRow2(1, "INIT"),
            .weight = 1,
        },
        .{
            .source_object_id = 10,
            .source_definition_id = 1,
            .tx_id = 51,
            .tx_cut_id = 501,
            .tx_decision = .committed_cut,
            .commit_lsn = 11,
            .manifest_version = 1,
            .row = try makeRow2(2, "LIVE"),
            .weight = 1,
        },
    };
    const published = try df.ingestWalDeltaBatch(lease_1, 3, true, true, 1, &wal_batch_1);
    try testing.expect(published);
    try testing.expectEqual(@as(usize, 1), df.skipped_duplicate_at_handoff_count);
    try testing.expectEqual(@as(u64, 2), df.completed_revision.revision_number);
    try testing.expectEqual(@as(usize, 2), df.completed_revision.row_count);
    try testing.expectEqual(@as(u64, 11), df.checkpoint_lsn);

    // 4. SUSPEND freezes watermarks, fences old lease_1, and continues serving revision 2
    try df.suspendDataflow();
    try testing.expectEqual(ManagedDataflow.LifecycleState.suspended, df.state);
    const frozen_read = try df.readCompletedRevision(true);
    try testing.expectEqual(@as(u64, 2), frozen_read.receipt.revision_number);
    try testing.expectEqual(@as(u64, 11), frozen_read.receipt.source_commit_lsn);

    // 5. Compaction during suspension: min_retained_wal_lsn advances to 20 (> checkpoint 11 + 1).
    // RESUME WITH (on_resume = 'replay_history') must fail closed with error.DataflowHistoryExpired!
    try testing.expectError(
        error.DataflowHistoryExpired,
        df.resumeDataflow(.replay_history, 20, null, null, null, null),
    );
    try testing.expectEqual(ManagedDataflow.BlockedReason.history_expired, df.blocked_reason);

    // Because consumer_contract is complete_ordered_changes, recompute_snapshot is also forbidden from skipping history
    try testing.expectError(
        error.CompleteOrderedConsumerCannotSkipHistory,
        df.resumeDataflow(.recompute_snapshot, 20, 25, 2, 600, &initial_zset),
    );

    // When history is still retained (min_retained_wal_lsn = 10 <= 12), replay_history succeeds and issues a new lease
    const lease_3 = try df.resumeDataflow(.replay_history, 10, null, null, null, null);
    try testing.expect(lease_3 > lease_1);
    try testing.expectEqual(ManagedDataflow.LifecycleState.active, df.state);

    // Old worker with lease_1 is fenced with error.StaleDataflowLeaseEpoch
    try testing.expectError(
        error.StaleDataflowLeaseEpoch,
        df.ingestWalDeltaBatch(lease_1, 3, true, true, 10, &wal_batch_1),
    );
}

test "multi-object M5 Transaction.Cut alignment prevents half-committed publication and discards aborted work" {
    const sources = [_]ManagedDataflow.SourceBinding{
        .{ .object_id = 10, .definition_id = 1 },
        .{ .object_id = 20, .definition_id = 1 },
    };
    const decl: ManagedDataflow.DataflowDeclaration = .{
        .catalog_id = 1,
        .dataflow_id = 200,
        .name = "joined_positions_mv",
        .definition_id = 1,
        .consumer_contract = .net_relation_changes,
        .sources = &sources,
    };

    var df = try ManagedDataflow.DataflowRuntime.publish(decl);
    try df.authorize(1);
    var empty_init: FuzeDelta.ZSet = .{};
    const lease = try df.establishSnapshotToLiveHandoff(5, 1, 100, &empty_init);
    try testing.expectEqual(@as(u64, 1), df.completed_revision.revision_number);

    // Step 1: Table 10's participant record for multi-table tx 77 arrives with .pending_participants,
    // and aborted tx 78 arrives. Neither may publish a completed revision!
    const batch_half = [_]ManagedDataflow.WalDeltaRecord{
        .{
            .source_object_id = 10,
            .source_definition_id = 1,
            .tx_id = 77,
            .tx_cut_id = 770,
            .tx_decision = .pending_participants,
            .commit_lsn = 6,
            .manifest_version = 1,
            .row = try makeRow2(101, "PART-1"),
            .weight = 1,
        },
        .{
            .source_object_id = 20,
            .source_definition_id = 1,
            .tx_id = 78,
            .tx_cut_id = 780,
            .tx_decision = .aborted,
            .commit_lsn = 7,
            .manifest_version = 1,
            .row = try makeRow2(999, "ABORTED"),
            .weight = 1,
        },
    };
    const advanced_1 = try df.ingestWalDeltaBatch(lease, 1, true, true, 1, &batch_half);
    try testing.expect(!advanced_1);
    try testing.expectEqual(@as(u64, 1), df.completed_revision.revision_number);
    try testing.expectEqual(@as(usize, 0), df.completed_revision.row_count);
    try testing.expectEqual(@as(usize, 1), df.pending_tx_len);
    try testing.expectEqual(@as(usize, 1), df.discarded_aborted_tx_records);

    const status_mid = df.inspectStatus(10);
    try testing.expect(status_mid.has_pending_successor);
    try testing.expectEqual(@as(u64, 5), status_mid.freshness_lag_lsn);

    // Step 2: Table 20's participant record for tx 77 arrives with M5 .committed_cut (0x54584331).
    // Both participants now commit atomically as revision 2!
    const batch_commit = [_]ManagedDataflow.WalDeltaRecord{
        .{
            .source_object_id = 20,
            .source_definition_id = 1,
            .tx_id = 77,
            .tx_cut_id = 770,
            .tx_decision = .committed_cut,
            .commit_lsn = 8,
            .manifest_version = 1,
            .row = try makeRow2(102, "PART-2"),
            .weight = 1,
        },
    };
    const advanced_2 = try df.ingestWalDeltaBatch(lease, 1, true, true, 1, &batch_commit);
    try testing.expect(advanced_2);
    try testing.expectEqual(@as(u64, 2), df.completed_revision.revision_number);
    try testing.expectEqual(@as(usize, 2), df.completed_revision.row_count);
    try testing.expectEqual(@as(u64, 770), df.completed_revision.tx_cut_id);
    try testing.expectEqual(@as(usize, 0), df.pending_tx_len);
}

test "upstream schema evolution, governed CONNECTION/SOURCE/SINK catalog and atomic sink outbox commit" {
    var connectors: ManagedDataflow.ConnectorCatalog = .{};

    // Reject inline plaintext credentials
    try testing.expectError(
        error.InlinePlaintextSecretRejected,
        connectors.createConnection(.{
            .object_id = 50,
            .definition_id = 1,
            .name = "bad_conn",
            .connector_type = "webhook",
            .secret_ref_id = 9,
            .contains_inline_plaintext_secret = true,
        }),
    );

    try connectors.createConnection(.{
        .object_id = 50,
        .definition_id = 1,
        .name = "prod_kafka_conn",
        .connector_type = "kafka",
        .secret_ref_id = 9001,
    });
    try connectors.createEndpoint(.{
        .object_id = 60,
        .definition_id = 1,
        .name = "alerts_sink",
        .kind = .sink,
        .connection_object_id = 50,
        .topic_or_route = "alerts.v1",
    });
    try testing.expectEqual(@as(usize, 0), connectors.external_sockets_opened_during_ddl);

    // Cannot drop connection while sink endpoint references it
    try testing.expectError(
        error.ConnectionReferencedByEndpoint,
        connectors.dropConnectionRestrict(50),
    );

    const sources = [_]ManagedDataflow.SourceBinding{
        .{ .object_id = 10, .definition_id = 1 },
    };
    const decl: ManagedDataflow.DataflowDeclaration = .{
        .catalog_id = 1,
        .dataflow_id = 300,
        .name = "alerts_sink_flow",
        .definition_id = 1,
        .kind = .dataflow,
        .sources = &sources,
        .target_sink_object_id = 60,
        .target_sink_definition_id = 1,
    };

    var df = try ManagedDataflow.DataflowRuntime.publish(decl);
    try df.authorize(10);
    var empty_init: FuzeDelta.ZSet = .{};
    const lease = try df.establishSnapshotToLiveHandoff(1, 1, 1, &empty_init);

    // Zero-work EXPLAIN acquires no pins, reads no segments, and dispatches zero external effects
    const explain = df.explainZeroWork();
    try testing.expect(!explain.doesWork());
    try testing.expectEqual(@as(usize, 0), df.external_effects_dispatched_by_engine);

    // Cannot drop sink while active dataflow targets it
    const active_slice = [_]ManagedDataflow.DataflowRuntime{df};
    try testing.expectError(
        error.SinkReferencedByActiveDataflow,
        connectors.dropSinkRestrict(60, &active_slice),
    );

    // Class A compatible lazy ALTER TABLE (definition_id 1 -> 2) projects seamlessly and stages atomic sink outbox intent
    const class_a_batch = [_]ManagedDataflow.WalDeltaRecord{
        .{
            .source_object_id = 10,
            .source_definition_id = 2,
            .evolution_class = .class_a_lazy_compatible,
            .tx_id = 90,
            .tx_cut_id = 900,
            .tx_decision = .committed_cut,
            .commit_lsn = 2,
            .manifest_version = 2,
            .row = try makeRow2(1, "ALERT-A"),
            .weight = 1,
        },
    };
    const committed = try df.ingestWalDeltaBatch(lease, 10, true, true, 1, &class_a_batch);
    try testing.expect(committed);
    try testing.expectEqual(@as(u64, 2), df.sources[0].definition_id);
    try testing.expectEqual(@as(usize, 1), df.outbox_len);
    try testing.expectEqual(@as(u64, 2), df.outbox[0].revision_number);
    try testing.expectEqual(@as(usize, 0), df.external_effects_dispatched_by_engine);

    // Class B phased rewrite on upstream source blocks successor while preserving revision 2
    const class_b_batch = [_]ManagedDataflow.WalDeltaRecord{
        .{
            .source_object_id = 10,
            .source_definition_id = 3,
            .evolution_class = .class_b_phased_rewrite,
            .tx_id = 91,
            .tx_cut_id = 901,
            .tx_decision = .committed_cut,
            .commit_lsn = 3,
            .manifest_version = 3,
            .row = try makeRow2(2, "ALERT-B"),
            .weight = 1,
        },
    };
    try testing.expectError(
        error.SourcePhasedRewriteInProgress,
        df.ingestWalDeltaBatch(lease, 10, true, true, 1, &class_b_batch),
    );
    try testing.expectEqual(ManagedDataflow.BlockedReason.source_phased_rewrite_in_progress, df.blocked_reason);
    try testing.expectEqual(@as(u64, 2), df.completed_revision.revision_number);

    // Policy revocation suspends dataflow and fences lease while preserving last completed revision 2
    try testing.expectError(
        error.DataflowAuthorizationRevoked,
        df.ingestWalDeltaBatch(lease, 11, false, true, 1, &class_a_batch),
    );
    try testing.expectEqual(ManagedDataflow.LifecycleState.suspended, df.state);
    try testing.expectEqual(ManagedDataflow.BlockedReason.policy_revoked, df.blocked_reason);

    // RETIRE permanently closes scheduling while keeping completed revision 2 readable
    try df.retireDataflow();
    try testing.expectEqual(ManagedDataflow.LifecycleState.retired, df.state);
    const final_read = try df.readCompletedRevision(true);
    try testing.expectEqual(@as(u64, 2), final_read.receipt.revision_number);
    try testing.expectError(error.DataflowAlreadyRetired, df.authorize(12));
}
