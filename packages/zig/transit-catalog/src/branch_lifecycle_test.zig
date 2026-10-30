const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const s = fuze.TableSchema;
const t = fuze.Types;
const v = t.Values;
const DecimalArithmetic = fuze.DecimalArithmetic;
const H = c.HistoricalCatalog;
const B = c.BranchLifecycle;

test "full-data and schema-only branch creation captures unflushed TWAL1 tail rows, enforces current policy_epoch grants, and matches independent copy oracle" {
    const cols = [_]s.Column{
        .{ .id = 1, .name = "id", .type = .{ .int64 = {} }, .nullable = false },
        .{ .id = 2, .name = "code", .type = .{ .utf8 = {} }, .nullable = false },
    };
    const pk = [_]s.ColumnId{1};
    const schema: s.Schema = .{
        .object = 10,
        .revision = 1,
        .next_column = 3,
        .columns = &cols,
        .primary_key = &pk,
    };

    const r1 = [_]v.Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .bytes = "ALPHA" } } } };
    const r2 = [_]v.Cell{ .{ .value = .{ .atom = .{ .signed = 2 } } }, .{ .value = .{ .atom = .{ .bytes = "BETA" } } } };
    const seg1_rows = [_]H.HistoricalRow{ .{ .cells = &r1 }, .{ .cells = &r2 } };
    const main_segments = [_]H.HistoricalSegment{
        .{ .segment_id = 101, .min_lsn = 1, .max_lsn = 10, .physical_schema = schema, .rows = &seg1_rows },
    };
    const main_tables = [_]H.HistoricalTableBinding{
        .{ .namespace = 1, .name = "orders", .object = 10, .revision = 1, .schema = schema, .segments = &main_segments },
    };
    const cut_v1: H.ManifestCut = .{
        .manifest_version = 1,
        .commit_lsn = 10,
        .branch_id = 1,
        .branch_name = "main",
        .tzdb = try DecimalArithmetic.TzdbVersion.init("tzdb_2026a"),
        .tables = &main_tables,
    };

    var registry = try B.BranchRegistry.initWithMain(cut_v1, 1);

    // Accepted unflushed TWAL1 row on `main` (LSN 11) before `.tseg` flush!
    const r3_unflushed = [_]v.Cell{ .{ .value = .{ .atom = .{ .signed = 3 } } }, .{ .value = .{ .atom = .{ .bytes = "GAMMA_UNFLUSHED" } } } };
    const unflushed_rows = [_]H.HistoricalRow{.{ .cells = &r3_unflushed }};
    const pinned_tails = [_]B.PinnedTailFrontier{
        .{
            .object = 10,
            .wal_partition = 1,
            .exclusive_next_lsn = 12,
            .unflushed_rows = &unflushed_rows,
        },
    };

    // 1. Caller missing `create_branch` privilege or source table `SELECT` right is rejected
    const denied_grants: B.BranchGrantSet = .{
        .policy_epoch = 5,
        .principal = 42,
        .privileges = &.{.read_branch},
        .select_objects = &.{10},
    };
    var schema_only_buf: [2]H.HistoricalTableBinding = undefined;
    try std.testing.expectError(
        error.BranchPermissionDenied,
        registry.createBranchConditional("feat_pricing", "main", null, .full_data, .allow_merge, &pinned_tails, &schema_only_buf, denied_grants),
    );

    const missing_table_select_grants: B.BranchGrantSet = .{
        .policy_epoch = 5,
        .principal = 42,
        .privileges = &.{ .create_branch, .read_branch, .write_branch },
        .select_objects = &.{},
    };
    try std.testing.expectError(
        error.SourceTableSelectDenied,
        registry.createBranchConditional("feat_pricing", "main", null, .full_data, .allow_merge, &pinned_tails, &schema_only_buf, missing_table_select_grants),
    );

    // 2. Authorized caller creates full-data branch `feat_pricing` from `main`
    const valid_grants: B.BranchGrantSet = .{
        .policy_epoch = 5,
        .principal = 42,
        .privileges = &.{ .create_branch, .read_branch, .write_branch },
        .select_objects = &.{10},
        .write_objects = &.{10},
    };
    const feat_branch = try registry.createBranchConditional(
        "feat_pricing",
        "main",
        null,
        .full_data,
        .allow_merge,
        &pinned_tails,
        &schema_only_buf,
        valid_grants,
    );
    try std.testing.expectEqual(@as(u64, 2), feat_branch.branch_id);
    try std.testing.expectEqual(@as(?u64, 1), feat_branch.parent_branch_id);
    try std.testing.expectEqual(@as(u64, 2), feat_branch.delta_wal_partition);
    try std.testing.expectEqual(B.DataflowActivationState.published_inactive, feat_branch.copied_dataflow_state);
    try std.testing.expectEqual(B.OutboxDisposition.fenced_historical, feat_branch.inherited_outbox_disposition);
    try std.testing.expectEqual(B.IndexReadiness.ready_verified_coverage, feat_branch.index_readiness);
    try std.testing.expectEqual(@as(u32, 0), feat_branch.live_process_pids_copied);
    try std.testing.expectEqual(@as(u32, 1), feat_branch.metrics.pinned_unflushed_wal_rows);
    try std.testing.expect(feat_branch.metrics.snapshot_pin_prepare_ns > feat_branch.metrics.head_cas_publish_ns);

    // If-None-Match CAS rejects duplicate branch name
    try std.testing.expectError(
        error.BranchAlreadyExists,
        registry.createBranchConditional("feat_pricing", "main", null, .full_data, .allow_merge, &pinned_tails, &schema_only_buf, valid_grants),
    );

    // 3. Copy-on-write isolation on `feat_pricing`:
    // Delete row index 0 ("ALPHA") from shared segment 101 via branch-local `.tdel` overlay,
    // flush branch-owned segment 201 with row 4 ("DELTA"), and append unflushed branch WAL row 5 ("EPSILON").
    const deleted_indices = [_]u32{0};
    const overlays = [_]B.SegmentDeletionOverlay{
        .{ .branch_id = feat_branch.branch_id, .segment_id = 101, .tdel_generation = 1, .deleted_row_indices = &deleted_indices },
    };
    const r4_branch_seg = [_]v.Cell{ .{ .value = .{ .atom = .{ .signed = 4 } } }, .{ .value = .{ .atom = .{ .bytes = "DELTA" } } } };
    const branch_seg_rows = [_]H.HistoricalRow{.{ .cells = &r4_branch_seg }};
    const branch_owned_segs = [_]H.HistoricalSegment{
        .{ .segment_id = 201, .min_lsn = 21, .max_lsn = 25, .physical_schema = schema, .rows = &branch_seg_rows },
    };
    const r5_branch_wal = [_]v.Cell{ .{ .value = .{ .atom = .{ .signed = 5 } } }, .{ .value = .{ .atom = .{ .bytes = "EPSILON" } } } };
    const branch_wal_rows = [_]H.HistoricalRow{.{ .cells = &r5_branch_wal }};

    const feat_delta: B.BranchTableDelta = .{
        .branch_id = feat_branch.branch_id,
        .table_object = 10,
        .delta_wal_partition = feat_branch.delta_wal_partition,
        .tdel_overlays = &overlays,
        .branch_owned_segments = &branch_owned_segs,
        .unflushed_branch_wal_rows = &branch_wal_rows,
    };

    var mat_rows: [8]H.HistoricalRow = undefined;
    const mat_count = try B.materializeBranchTableRows(main_tables[0], feat_branch, feat_delta, &mat_rows);
    try std.testing.expectEqual(@as(usize, 4), mat_count);

    // Independent full-copy oracle has: row 2 ("BETA"), row 3 ("GAMMA_UNFLUSHED"), row 4 ("DELTA"), row 5 ("EPSILON")
    const expected_oracle = [_]H.HistoricalRow{
        .{ .cells = &r2 },
        .{ .cells = &r3_unflushed },
        .{ .cells = &r4_branch_seg },
        .{ .cells = &r5_branch_wal },
    };
    try B.verifyAgainstIndependentCopyOracle(mat_rows[0..mat_count], &expected_oracle);

    // Verify parent `main` is completely untouched (row 1 "ALPHA" and row 2 "BETA" remain intact on `main`)
    var main_mat_rows: [8]H.HistoricalRow = undefined;
    const main_delta: B.BranchTableDelta = .{ .branch_id = 1, .table_object = 10, .delta_wal_partition = 1 };
    const main_count = try B.materializeBranchTableRows(main_tables[0], registry.branches[0], main_delta, &main_mat_rows);
    try std.testing.expectEqual(@as(usize, 2), main_count);
    try std.testing.expectEqualStrings("ALPHA", main_mat_rows[0].cells[1].value.atom.bytes);

    // 4. Schema-only branch creation copies catalog definitions with 0 rows and marks index readiness `.rebuild_required`
    const schema_branch = try registry.createBranchConditional(
        "staging_schema",
        "main",
        1,
        .schema_only,
        .protected_head,
        &.{},
        &schema_only_buf,
        valid_grants,
    );
    try std.testing.expectEqual(B.BranchMode.schema_only, schema_branch.mode);
    try std.testing.expectEqual(B.IndexReadiness.rebuild_required, schema_branch.index_readiness);
    const schema_delta: B.BranchTableDelta = .{
        .branch_id = schema_branch.branch_id,
        .table_object = 10,
        .delta_wal_partition = schema_branch.delta_wal_partition,
    };
    const schema_mat_count = try B.materializeBranchTableRows(main_tables[0], schema_branch, schema_delta, &mat_rows);
    try std.testing.expectEqual(@as(usize, 0), schema_mat_count);

    // Protected branch head refuses direct writes (`ProtectedBranchDirectWriteForbidden`)
    const next_cut: H.ManifestCut = .{
        .manifest_version = 3,
        .commit_lsn = 30,
        .branch_id = schema_branch.branch_id,
        .branch_name = "staging_schema",
        .tzdb = cut_v1.tzdb,
        .previous_manifest_digest = schema_branch.head_manifest_digest,
        .tables = schema_only_buf[0..1],
    };
    try std.testing.expectError(
        error.ProtectedBranchDirectWriteForbidden,
        registry.advanceBranchHeadConditional("staging_schema", schema_branch.head_manifest_version, next_cut, null, null, true, valid_grants),
    );
}

test "T6 multi-branch GC reachability preserves shared .tseg segments and WAL partitions across branch drops and enforces branch-aware compaction" {
    const cols = [_]s.Column{
        .{ .id = 1, .name = "id", .type = .{ .int64 = {} }, .nullable = false },
    };
    const pk = [_]s.ColumnId{1};
    const schema: s.Schema = .{ .object = 10, .revision = 1, .next_column = 2, .columns = &cols, .primary_key = &pk };
    const r1 = [_]v.Cell{.{ .value = .{ .atom = .{ .signed = 1 } } }};
    const rows = [_]H.HistoricalRow{.{ .cells = &r1 }};
    const seg_101 = [_]H.HistoricalSegment{
        .{ .segment_id = 101, .min_lsn = 1, .max_lsn = 10, .physical_schema = schema, .rows = &rows },
    };
    const tables_v1 = [_]H.HistoricalTableBinding{
        .{ .namespace = 1, .name = "items", .object = 10, .revision = 1, .schema = schema, .segments = &seg_101 },
    };
    const cut_v1: H.ManifestCut = .{
        .manifest_version = 1,
        .commit_lsn = 10,
        .branch_id = 1,
        .branch_name = "main",
        .tzdb = try DecimalArithmetic.TzdbVersion.init("tzdb_2026a"),
        .tables = &tables_v1,
    };

    var registry = try B.BranchRegistry.initWithMain(cut_v1, 1);
    const grants: B.BranchGrantSet = .{
        .policy_epoch = 1,
        .principal = 1,
        .privileges = &.{ .create_branch, .read_branch, .write_branch },
        .select_objects = &.{10},
    };
    var schema_buf: [1]H.HistoricalTableBinding = undefined;
    const child_a = try registry.createBranchConditional("child_a", "main", 1, .full_data, .allow_merge, &.{}, &schema_buf, grants);
    const child_b = try registry.createBranchConditional("child_b", "main", 1, .full_data, .allow_merge, &.{}, &schema_buf, grants);

    const seg_201 = [_]H.HistoricalSegment{
        .{ .segment_id = 201, .min_lsn = 11, .max_lsn = 20, .physical_schema = schema, .rows = &rows },
    };
    const deltas = [_]B.BranchTableDelta{
        .{ .branch_id = child_a.branch_id, .table_object = 10, .delta_wal_partition = child_a.delta_wal_partition, .branch_owned_segments = &seg_201 },
        .{ .branch_id = child_b.branch_id, .table_object = 10, .delta_wal_partition = child_b.delta_wal_partition },
    };

    // Shared segment 101 is referenced by 3 active branches (main, child_a, child_b); segment 201 only by child_a
    const reach1 = try B.computeMultiBranchReachability(&registry, &deltas, &.{});
    try std.testing.expect(reach1.isSegmentReachable(101));
    try std.testing.expectEqual(@as(u32, 3), reach1.segmentRefCount(101));
    try std.testing.expect(reach1.isSegmentReachable(201));
    try std.testing.expectEqual(@as(u32, 1), reach1.segmentRefCount(201));

    // Drop `child_a`: segment 201 becomes unreachable, while shared segment 101 remains reachable (ref count 2)
    try registry.dropBranch("child_a", grants);
    const reach2 = try B.computeMultiBranchReachability(&registry, &deltas, &.{});
    try std.testing.expect(reach2.isSegmentReachable(101));
    try std.testing.expectEqual(@as(u32, 2), reach2.segmentRefCount(101));
    try std.testing.expect(!reach2.isSegmentReachable(201));

    // Branch-aware compaction evaluation:
    // 1. Branch-local segment (ref_count = 1) with 25% dead rows compacts eagerly
    try std.testing.expectEqual(
        B.CompactionAction.compact_branch_local,
        try B.evaluateBranchAwareCompaction(.{
            .segment_id = 201,
            .branch_ref_count = 1,
            .dead_row_ratio = 0.25,
            .shared_tdel_intersection_ratio = 0.0,
        }),
    );
    // 2. Shared segment across 3 branches with 25% dead rows and 0% shared tdel intersection is deferred to avoid O(B) amplification
    try std.testing.expectEqual(
        B.CompactionAction.defer_shared_amplification_guard,
        try B.evaluateBranchAwareCompaction(.{
            .segment_id = 101,
            .branch_ref_count = 3,
            .dead_row_ratio = 0.25,
            .shared_tdel_intersection_ratio = 0.0,
        }),
    );
    // 3. Shared segment across 3 branches with 65% dead rows (>= 0.20 * 3 = 0.60) or >= 50% shared `.tdel` intersection compacts
    try std.testing.expectEqual(
        B.CompactionAction.compact_shared_amortized,
        try B.evaluateBranchAwareCompaction(.{
            .segment_id = 101,
            .branch_ref_count = 3,
            .dead_row_ratio = 0.65,
            .shared_tdel_intersection_ratio = 0.10,
        }),
    );
}
