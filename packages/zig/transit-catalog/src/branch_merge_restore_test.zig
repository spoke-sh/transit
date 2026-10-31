const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const s = fuze.TableSchema;
const t = fuze.Types;
const v = t.Values;
const DecimalArithmetic = fuze.DecimalArithmetic;
const TableConstraints = fuze.TableConstraints;
const BranchDiff = fuze.BranchDiff;
const H = c.HistoricalCatalog;
const B = c.BranchLifecycle;
const M = c.BranchMergeRestore;

test "reviewed 3-way merge revalidates UNIQUE, 5-state CHECK, cross-table FOREIGN KEY, and SQL/PGQ Graph endpoints, enforces Multi-Writer OCC, and recovers lost replies" {
    const acct_cols = [_]s.Column{
        .{ .id = 1, .name = "account_id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "email", .type = .{ .utf8 = {} }, .nullable = false },
        .{ .id = 3, .name = "credit_limit", .type = .{ .int64 = {} }, .nullable = false },
    };
    const order_cols = [_]s.Column{
        .{ .id = 1, .name = "order_id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "account_id", .type = .{ .int64 = {} }, .nullable = false },
    };
    const pk = [_]s.ColumnId{1};
    const acct_schema: s.Schema = .{ .object = 10, .revision = 1, .next_column = 4, .columns = &acct_cols, .primary_key = &pk };
    const order_schema: s.Schema = .{ .object = 11, .revision = 1, .next_column = 3, .columns = &order_cols, .primary_key = &pk };

    // Base state:
    // accounts: (1, 'a@spoke.sh', 100), (2, 'b@spoke.sh', 200)
    // orders: (100, 1)
    const a_r1 = [_]v.Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .bytes = "a@spoke.sh" } } }, .{ .value = .{ .atom = .{ .signed = 100 } } } };
    const a_r2 = [_]v.Cell{ .{ .value = .{ .atom = .{ .signed = 2 } } }, .{ .value = .{ .atom = .{ .bytes = "b@spoke.sh" } } }, .{ .value = .{ .atom = .{ .signed = 200 } } } };
    const o_r1 = [_]v.Cell{ .{ .value = .{ .atom = .{ .signed = 100 } } }, .{ .value = .{ .atom = .{ .signed = 1 } } } };

    const base_acct_hist = [_]H.HistoricalRow{ .{ .cells = &a_r1 }, .{ .cells = &a_r2 } };
    const base_order_hist = [_]H.HistoricalRow{.{ .cells = &o_r1 }};

    const seg_acct = [_]H.HistoricalSegment{.{ .segment_id = 1, .min_lsn = 1, .max_lsn = 10, .physical_schema = acct_schema, .rows = &base_acct_hist }};
    const seg_order = [_]H.HistoricalSegment{.{ .segment_id = 2, .min_lsn = 1, .max_lsn = 10, .physical_schema = order_schema, .rows = &base_order_hist }};

    const fk_orders_acct = [_]TableConstraints.ForeignKeyConstraint{
        .{
            .id = 1,
            .name = "fk_order_account",
            .local_columns = &.{2},
            .target_object = 10,
            .target_revision = 1,
            .target_columns = &.{1},
            .on_delete = .restrict,
            .on_update = .restrict,
        },
    };
    const chk_positive_credit = [_]TableConstraints.CheckAtom{
        .{ .compare_literal = .{ .column = 3, .op = .gt, .literal = .{ .signed = 0 } } },
    };
    const acct_checks = [_]TableConstraints.CheckConstraint{
        .{ .id = 1, .name = "chk_credit_positive", .atoms = &chk_positive_credit },
    };
    const email_unique = [_]M.SecondaryUniqueConstraint{
        .{ .id = 1, .name = "uq_account_email", .column = 2 },
    };

    const base_tables = [_]H.HistoricalTableBinding{
        .{ .namespace = 1, .name = "accounts", .object = 10, .revision = 1, .schema = acct_schema, .checks = &acct_checks, .segments = &seg_acct },
        .{ .namespace = 1, .name = "orders", .object = 11, .revision = 1, .schema = order_schema, .foreign_keys = &fk_orders_acct, .segments = &seg_order },
    };
    const cut_v1: H.ManifestCut = .{
        .manifest_version = 1,
        .commit_lsn = 10,
        .branch_id = 1,
        .branch_name = "main",
        .tzdb = try DecimalArithmetic.TzdbVersion.init("fixture-tzdb", @splat(1)),
        .tables = &base_tables,
    };

    var registry = try B.BranchRegistry.initWithMain(cut_v1, 1);
    const grants: B.BranchGrantSet = .{
        .policy_epoch = 3,
        .principal = 7,
        .privileges = &.{ .create_branch, .read_branch, .write_branch, .merge_branch, .restore_branch },
        .select_objects = &.{ 10, 11 },
        .write_objects = &.{ 10, 11 },
    };
    var schema_buf: [2]H.HistoricalTableBinding = undefined;
    _ = try registry.createBranchConditional("feat_branch", "main", 1, .full_data, .allow_merge, &.{}, &schema_buf, grants);

    var token_journal: M.MergeTokenJournal = .{};
    var out_tables: [2]H.HistoricalTableBinding = undefined;
    var out_segs: [2]H.HistoricalSegment = undefined;

    const base_acct_rows = [_]BranchDiff.RowEntry{ .{ .cells = &a_r1 }, .{ .cells = &a_r2 } };
    const base_order_rows = [_]BranchDiff.RowEntry{.{ .cells = &o_r1 }};

    // Case 1: Disjoint branch inserts that collide on secondary UNIQUE key `email = 'dup@spoke.sh'` must reject!
    const a_src_dup = [_]v.Cell{ .{ .value = .{ .atom = .{ .signed = 3 } } }, .{ .value = .{ .atom = .{ .bytes = "dup@spoke.sh" } } }, .{ .value = .{ .atom = .{ .signed = 300 } } } };
    const a_tgt_dup = [_]v.Cell{ .{ .value = .{ .atom = .{ .signed = 4 } } }, .{ .value = .{ .atom = .{ .bytes = "dup@spoke.sh" } } }, .{ .value = .{ .atom = .{ .signed = 400 } } } };
    const src_acct_dup = [_]BranchDiff.RowEntry{ .{ .cells = &a_r1 }, .{ .cells = &a_r2 }, .{ .cells = &a_src_dup } };
    const tgt_acct_dup = [_]BranchDiff.RowEntry{ .{ .cells = &a_r1 }, .{ .cells = &a_r2 }, .{ .cells = &a_tgt_dup } };

    const dup_candidates = [_]M.MergeCandidateTable{
        .{
            .name = "accounts",
            .object = 10,
            .base_snap = .{ .branch_id = 1, .commit_lsn = 10, .schema = acct_schema, .rows = &base_acct_rows },
            .source_snap = .{ .branch_id = 2, .commit_lsn = 20, .schema = acct_schema, .rows = &src_acct_dup },
            .target_snap = .{ .branch_id = 1, .commit_lsn = 25, .schema = acct_schema, .rows = &tgt_acct_dup },
            .secondary_unique_constraints = &email_unique,
            .checks = &acct_checks,
        },
        .{
            .name = "orders",
            .object = 11,
            .base_snap = .{ .branch_id = 1, .commit_lsn = 10, .schema = order_schema, .rows = &base_order_rows },
            .source_snap = .{ .branch_id = 2, .commit_lsn = 20, .schema = order_schema, .rows = &base_order_rows },
            .target_snap = .{ .branch_id = 1, .commit_lsn = 25, .schema = order_schema, .rows = &base_order_rows },
            .foreign_keys = &fk_orders_acct,
        },
    };
    try std.testing.expectError(
        error.SecondaryUniqueKeyMergeCollision,
        M.validateAndPublishThreeWayMerge(
            &registry,
            &token_journal,
            @splat(0x01),
            1001,
            "feat_branch",
            "main",
            1,
            .fail_on_conflict,
            &dup_candidates,
            &.{},
            &out_tables,
            &out_segs,
            grants,
        ),
    );

    // Case 2: Cross-table FOREIGN KEY write skew:
    // `feat_branch` deletes parent account 2 while `main` inserts child order (101, account_id = 2) -> must reject!
    const src_acct_del2 = [_]BranchDiff.RowEntry{.{ .cells = &a_r1 }};
    const o_r2_child2 = [_]v.Cell{ .{ .value = .{ .atom = .{ .signed = 101 } } }, .{ .value = .{ .atom = .{ .signed = 2 } } } };
    const tgt_order_ins2 = [_]BranchDiff.RowEntry{ .{ .cells = &o_r1 }, .{ .cells = &o_r2_child2 } };

    const fk_skew_candidates = [_]M.MergeCandidateTable{
        .{
            .name = "accounts",
            .object = 10,
            .base_snap = .{ .branch_id = 1, .commit_lsn = 10, .schema = acct_schema, .rows = &base_acct_rows },
            .source_snap = .{ .branch_id = 2, .commit_lsn = 20, .schema = acct_schema, .rows = &src_acct_del2 },
            .target_snap = .{ .branch_id = 1, .commit_lsn = 25, .schema = acct_schema, .rows = &base_acct_rows },
            .secondary_unique_constraints = &email_unique,
            .checks = &acct_checks,
        },
        .{
            .name = "orders",
            .object = 11,
            .base_snap = .{ .branch_id = 1, .commit_lsn = 10, .schema = order_schema, .rows = &base_order_rows },
            .source_snap = .{ .branch_id = 2, .commit_lsn = 20, .schema = order_schema, .rows = &base_order_rows },
            .target_snap = .{ .branch_id = 1, .commit_lsn = 25, .schema = order_schema, .rows = &tgt_order_ins2 },
            .foreign_keys = &fk_orders_acct,
        },
    };
    try std.testing.expectError(
        error.ForeignKeyMergeIntegrityViolation,
        M.validateAndPublishThreeWayMerge(
            &registry,
            &token_journal,
            @splat(0x02),
            1002,
            "feat_branch",
            "main",
            1,
            .fail_on_conflict,
            &fk_skew_candidates,
            &.{},
            &out_tables,
            &out_segs,
            grants,
        ),
    );

    // Case 3: Clean 3-way merge commits via OCC CAS, rejects stale target head, and recovers idempotently on lost reply!
    const a_src_clean = [_]v.Cell{ .{ .value = .{ .atom = .{ .signed = 3 } } }, .{ .value = .{ .atom = .{ .bytes = "c@spoke.sh" } } }, .{ .value = .{ .atom = .{ .signed = 300 } } } };
    const src_acct_clean = [_]BranchDiff.RowEntry{ .{ .cells = &a_r1 }, .{ .cells = &a_r2 }, .{ .cells = &a_src_clean } };
    const clean_candidates = [_]M.MergeCandidateTable{
        .{
            .name = "accounts",
            .object = 10,
            .base_snap = .{ .branch_id = 1, .commit_lsn = 10, .schema = acct_schema, .rows = &base_acct_rows },
            .source_snap = .{ .branch_id = 2, .commit_lsn = 20, .schema = acct_schema, .rows = &src_acct_clean },
            .target_snap = .{ .branch_id = 1, .commit_lsn = 25, .schema = acct_schema, .rows = &base_acct_rows },
            .secondary_unique_constraints = &email_unique,
            .checks = &acct_checks,
        },
        .{
            .name = "orders",
            .object = 11,
            .base_snap = .{ .branch_id = 1, .commit_lsn = 10, .schema = order_schema, .rows = &base_order_rows },
            .source_snap = .{ .branch_id = 2, .commit_lsn = 20, .schema = order_schema, .rows = &base_order_rows },
            .target_snap = .{ .branch_id = 1, .commit_lsn = 25, .schema = order_schema, .rows = &tgt_order_ins2 },
            .foreign_keys = &fk_orders_acct,
        },
    };

    // Stale expected_target_manifest_version (99 != 1) rejects with `StaleTargetBranchHead`
    try std.testing.expectError(
        error.StaleTargetBranchHead,
        M.validateAndPublishThreeWayMerge(
            &registry,
            &token_journal,
            @splat(0x03),
            1003,
            "feat_branch",
            "main",
            99,
            .fail_on_conflict,
            &clean_candidates,
            &.{},
            &out_tables,
            &out_segs,
            grants,
        ),
    );

    const token_clean: [16]u8 = @splat(0xAA);
    const receipt1 = try M.validateAndPublishThreeWayMerge(
        &registry,
        &token_journal,
        token_clean,
        1004,
        "feat_branch",
        "main",
        1,
        .fail_on_conflict,
        &clean_candidates,
        &.{},
        &out_tables,
        &out_segs,
        grants,
    );
    try std.testing.expectEqual(@as(u64, 2), receipt1.published_manifest_version);
    try std.testing.expectEqual(@as(usize, 5), receipt1.merged_row_count); // 3 accounts + 2 orders

    // Lost-reply retry with the same `token_clean` returns the exact original receipt even though `main` is now at v2!
    const receipt_retry = try M.validateAndPublishThreeWayMerge(
        &registry,
        &token_journal,
        token_clean,
        1004,
        "feat_branch",
        "main",
        1,
        .fail_on_conflict,
        &clean_candidates,
        &.{},
        &out_tables,
        &out_segs,
        grants,
    );
    try std.testing.expectEqual(receipt1.published_manifest_version, receipt_retry.published_manifest_version);
    try std.testing.expectEqualSlices(u8, &receipt1.published_manifest_digest, &receipt_retry.published_manifest_digest);
}

test "Document versioned BP-tree and causal_crdt branch merges, Forward Restore under current policy_epoch, and Git-like remote incremental sync" {
    // 1. Document versioned BP-tree merge skips identical subtrees in O(1) and detects conflicts
    const base_doc = [_]M.DocumentSubtreeSpan{
        .{ .path = "$.header", .subtree_sha256 = @splat(0x11), .scalar_bytes = "h1", .part_id = 1, .byte_start = 0, .byte_end = 10 },
        .{ .path = "$.total", .subtree_sha256 = @splat(0x22), .scalar_bytes = "100", .part_id = 1, .byte_start = 10, .byte_end = 20 },
    };
    const src_doc = [_]M.DocumentSubtreeSpan{
        .{ .path = "$.header", .subtree_sha256 = @splat(0x11), .scalar_bytes = "h1", .part_id = 1, .byte_start = 0, .byte_end = 10 },
        .{ .path = "$.total", .subtree_sha256 = @splat(0x33), .scalar_bytes = "150", .part_id = 1, .byte_start = 10, .byte_end = 20 },
    };
    const tgt_doc = [_]M.DocumentSubtreeSpan{
        .{ .path = "$.header", .subtree_sha256 = @splat(0x11), .scalar_bytes = "h1", .part_id = 1, .byte_start = 0, .byte_end = 10 },
        .{ .path = "$.total", .subtree_sha256 = @splat(0x44), .scalar_bytes = "180", .part_id = 1, .byte_start = 10, .byte_end = 20 },
    };
    const doc_ver_res = try M.mergeDocumentBranches(
        .versioned_bp_tree,
        "transit.document.json.v1",
        "transit.document.json.v1",
        0,
        0,
        &base_doc,
        &src_doc,
        &tgt_doc,
        &.{},
        &.{},
    );
    try std.testing.expectEqual(@as(u32, 1), doc_ver_res.skipped_identical_subtrees);
    try std.testing.expectEqual(@as(u32, 1), doc_ver_res.conflict_path_count);

    // Incompatible document profiles refuse to merge
    try std.testing.expectError(
        error.IncompatibleDocumentMergeHistory,
        M.mergeDocumentBranches(.versioned_bp_tree, "transit.document.json.v1", "transit.document.xml.v1", 0, 0, &base_doc, &src_doc, &tgt_doc, &.{}, &.{}),
    );

    // Causal CRDT requires distinct branch replica IDs and preserves tombstones
    const crdt_src = [_]M.CausalDocumentOp{
        .{ .path = "$.items[0]", .counter = 10, .replica_id = 2002, .is_tombstone = true },
    };
    const crdt_tgt = [_]M.CausalDocumentOp{
        .{ .path = "$.items[1]", .counter = 11, .replica_id = 1001, .is_tombstone = false, .value_bytes = "item2" },
    };
    try std.testing.expectError(
        error.DuplicateBranchReplicaIdentity,
        M.mergeDocumentBranches(.causal_crdt, "transit.document.json.v1", "transit.document.json.v1", 1001, 1001, &.{}, &.{}, &.{}, &crdt_src, &crdt_tgt),
    );
    const crdt_res = try M.mergeDocumentBranches(
        .causal_crdt,
        "transit.document.json.v1",
        "transit.document.json.v1",
        2002,
        1001,
        &.{},
        &.{},
        &.{},
        &crdt_src,
        &crdt_tgt,
    );
    try std.testing.expectEqual(@as(u32, 1), crdt_res.preserved_tombstone_count);
    try std.testing.expectEqual(@as(u64, 2002), crdt_res.assigned_fresh_replica_id);

    // 2. Forward Restore (`manifest/v{N+1}`) under current authority + Remote incremental sync
    const cols = [_]s.Column{.{ .id = 1, .name = "id", .type = .{ .int64 = {} }, .nullable = false }};
    const pk = [_]s.ColumnId{1};
    const schema: s.Schema = .{ .object = 10, .revision = 1, .next_column = 2, .columns = &cols, .primary_key = &pk };
    const r1 = [_]v.Cell{.{ .value = .{ .atom = .{ .signed = 1 } } }};
    const rows1 = [_]H.HistoricalRow{.{ .cells = &r1 }};
    const seg1 = [_]H.HistoricalSegment{.{ .segment_id = 101, .min_lsn = 1, .max_lsn = 10, .physical_schema = schema, .rows = &rows1 }};
    const seg2 = [_]H.HistoricalSegment{
        seg1[0],
        .{ .segment_id = 102, .min_lsn = 11, .max_lsn = 20, .physical_schema = schema, .rows = &rows1 },
    };
    const tables_v1 = [_]H.HistoricalTableBinding{.{ .namespace = 1, .name = "items", .object = 10, .revision = 1, .schema = schema, .segments = &seg1 }};
    const tables_v2 = [_]H.HistoricalTableBinding{.{ .namespace = 1, .name = "items", .object = 10, .revision = 1, .schema = schema, .segments = &seg2 }};

    const cut_v1: H.ManifestCut = .{
        .manifest_version = 1,
        .commit_lsn = 10,
        .branch_id = 1,
        .branch_name = "main",
        .tzdb = try DecimalArithmetic.TzdbVersion.init("fixture-tzdb", @splat(1)),
        .tables = &tables_v1,
    };
    var registry = try B.BranchRegistry.initWithMain(cut_v1, 1);
    const grants: B.BranchGrantSet = .{
        .policy_epoch = 8,
        .principal = 1,
        .privileges = &.{ .create_branch, .read_branch, .write_branch, .merge_branch, .restore_branch },
        .select_objects = &.{10},
        .write_objects = &.{10},
    };
    const cut_v2: H.ManifestCut = .{
        .manifest_version = 2,
        .commit_lsn = 20,
        .branch_id = 1,
        .branch_name = "main",
        .tzdb = cut_v1.tzdb,
        .previous_manifest_digest = registry.branches[0].head_manifest_digest,
        .tables = &tables_v2,
    };
    _ = try registry.advanceBranchHeadConditional("main", 1, cut_v2, null, null, true, grants);

    // Revoked caller at policy_epoch 9 cannot restore historical cut v1 (never restores historical grants!)
    const revoked_grants: B.BranchGrantSet = .{
        .policy_epoch = 9,
        .principal = 1,
        .privileges = &.{ .restore_branch, .write_branch },
        .select_objects = &.{},
    };
    try std.testing.expectError(
        error.SourceTableSelectDenied,
        M.restoreBranchForward(&registry, "main", 2, 1, .suspend_on_restore, revoked_grants),
    );

    // Authorized forward restore publishes `manifest/v3` pointing to v1's state without truncating v2
    const restore_out = try M.restoreBranchForward(&registry, "main", 2, 1, .suspend_on_restore, grants);
    try std.testing.expectEqual(@as(u64, 3), restore_out.published_manifest_version);
    try std.testing.expectEqual(@as(u64, 1), restore_out.restored_from_manifest_version);
    try std.testing.expectEqual(B.DataflowActivationState.suspended, restore_out.dataflow_state_after);
    try std.testing.expectEqual(B.OutboxDisposition.fenced_historical, restore_out.outbox_disposition);
    try std.testing.expectEqual(@as(u64, 2), restore_out.discontinuity.previous_manifest_version);
    try std.testing.expectEqual(@as(u64, 3), restore_out.discontinuity.new_manifest_version);

    // 3. Incremental remote FETCH from LCA v1 to v2 transfers only delta segment 102 and skips shared segment 101
    // Need a remote registry at v2 to test delta segment count
    var remote_reg = try B.BranchRegistry.initWithMain(cut_v1, 1);
    _ = try remote_reg.advanceBranchHeadConditional("main", 1, cut_v2, null, null, true, grants);

    const fetch_res = try M.fetchIncrementalFromRemote(
        &remote_reg,
        "main",
        1,
        .lazy_on_demand,
        .{ .caller_policy_epoch = 8, .rls_predicate_active = true },
        grants,
    );
    try std.testing.expectEqual(@as(u32, 1), fetch_res.fetched_manifest_count);
    try std.testing.expectEqual(@as(u32, 1), fetch_res.transferred_segment_count);
    try std.testing.expectEqual(@as(u32, 1), fetch_res.skipped_ancestor_segment_count);
    try std.testing.expectEqual(@as(u32, 1), fetch_res.lazy_unhydrated_segment_count);
    try std.testing.expect(fetch_res.rls_or_masking_applied_at_egress);
    try std.testing.expectEqual(M.ConnectorEffectMode.replay_only_fenced, fetch_res.local_connector_effect_mode);

    // Local remote-mirror branch blocks live connector network dispatch and requires captured exchange replay
    try std.testing.expectError(
        error.LiveConnectorEffectForbiddenOnRemoteMirrorBranch,
        M.checkLocalBranchConnectorExecution(fetch_res.local_connector_effect_mode, .live_network, true),
    );
    try M.checkLocalBranchConnectorExecution(fetch_res.local_connector_effect_mode, .replay_only_fenced, true);

    // Lazy NvmeCache hydration verifies SHA-256 once on admission
    var expected_sha: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("tseg_v1_payload_bytes", &expected_sha, .{});
    _ = try M.hydrateLazySegmentOnDemand(expected_sha, "tseg_v1_payload_bytes");
    try std.testing.expectError(
        error.HydratedSegmentDigestMismatch,
        M.hydrateLazySegmentOnDemand(expected_sha, "corrupted_payload"),
    );

    // Upstream M28 proposal push packages delta `.tseg`/`.tdel` and schema diff
    const delta: B.BranchTableDelta = .{
        .branch_id = 2,
        .table_object = 10,
        .delta_wal_partition = 2,
        .branch_owned_segments = seg2[1..2],
    };
    const proposal = try M.prepareUpstreamProposalPush(501, "local_mig", "prod/main", 2, cut_v2, delta, &.{});
    try std.testing.expectEqual(@as(u64, 501), proposal.proposal_id);
    try std.testing.expectEqual(@as(u32, 1), proposal.delta_segment_count);
}
