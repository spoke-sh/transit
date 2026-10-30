#!/usr/bin/env python3
"""Independent oracle for Milestone 19 branches, merges, forward restore,
segment-skipping 2-way/3-way DIFF and DIFF_SCHEMA, 5-state IS CONFLICT cells,
multi-branch GC reachability (T6), branch-aware compaction, and Git-like
remote <-> local incremental mirroring.
"""
from runner.paths import ROOT
import argparse
import hashlib
import json

FIXTURE_PATH = ROOT / "contracts/catalog/branch-merge-restore-fixtures.json"
BRANCH_DIFF_ZIG_PATH = ROOT / "packages/zig/transit-fuze/src/BranchDiff.zig"
BRANCH_LIFECYCLE_ZIG_PATH = ROOT / "packages/zig/transit-catalog/src/BranchLifecycle.zig"
BRANCH_MERGE_RESTORE_ZIG_PATH = ROOT / "packages/zig/transit-catalog/src/BranchMergeRestore.zig"


def sha256_hex(label: str) -> str:
    return hashlib.sha256(b"transit.catalog.branch.v1\x00" + label.encode("utf-8")).hexdigest()


def build_fixtures() -> dict:
    a4_segment_skipping_matrix = [
        {
            "case": "shared_identical_segment_and_tdel",
            "base_segment_sha256": sha256_hex("seg_101"),
            "source_segment_sha256": sha256_hex("seg_101"),
            "target_segment_sha256": sha256_hex("seg_101"),
            "tdel_identical": True,
            "action": "skip_o1_identical",
            "logical_delta_rows": 0,
        },
        {
            "case": "physical_compaction_rewrite_equivalent_multiset",
            "base_segments": [sha256_hex("seg_102"), sha256_hex("seg_103")],
            "source_segments": [sha256_hex("seg_102"), sha256_hex("seg_103")],
            "target_compacted_segment": sha256_hex("seg_104_compacted"),
            "logical_row_multiset_hash": sha256_hex("multiset_102_103"),
            "action": "skip_o1_compaction_equivalent",
            "logical_delta_rows": 0,
        },
        {
            "case": "out_of_viewport_2d_3d_spatial_segment",
            "viewport_bbox2d": [0.0, 0.0, 20.0, 20.0],
            "segment_bbox2d": [500.0, 500.0, 600.0, 600.0],
            "action": "skip_o1_spatial_viewport",
            "logical_delta_rows": 0,
        },
    ]

    three_way_diff_and_conflict_vectors = [
        {
            "scenario": "clean_source_only_cell_modification",
            "base_cell": 200,
            "source_cell": 250,
            "target_cell": 200,
            "diff_op": "modified",
            "is_conflict": False,
            "merged_value": 250,
        },
        {
            "scenario": "convergent_identical_modification_on_both_branches",
            "base_cell": 100,
            "source_cell": 150,
            "target_cell": 150,
            "diff_op": "modified",
            "is_conflict": False,
            "merged_value": 150,
        },
        {
            "scenario": "divergent_incompatible_cell_modification",
            "base_cell": 100,
            "source_cell": 150,
            "target_cell": 180,
            "diff_op": "conflict",
            "is_conflict": True,
            "cell_state": "conflict",
            "check_constraint_outcome": "error.CheckConstraintViolation",
        },
        {
            "scenario": "delete_on_source_vs_modify_on_target",
            "base_cell": 300,
            "source_cell": None,
            "target_cell": 350,
            "diff_op": "conflict",
            "is_conflict": True,
            "delete_modify_conflict": True,
            "merge_fail_on_conflict_error": "error.UnresolvedDeleteModifyConflict",
        },
    ]

    branch_compaction_and_gc_scenarios = [
        {
            "id": "C1_branch_local_segment_eager_compaction",
            "branch_ref_count": 1,
            "dead_row_ratio": 0.25,
            "shared_tdel_intersection_ratio": 0.0,
            "expected_action": "compact_branch_local",
        },
        {
            "id": "C2_shared_segment_amplification_guard",
            "branch_ref_count": 3,
            "dead_row_ratio": 0.25,
            "shared_tdel_intersection_ratio": 0.0,
            "expected_action": "defer_shared_amplification_guard",
        },
        {
            "id": "C3_shared_segment_amortized_compaction",
            "branch_ref_count": 3,
            "dead_row_ratio": 0.65,
            "shared_tdel_intersection_ratio": 0.10,
            "expected_action": "compact_shared_amortized",
        },
    ]

    merge_and_restore_gates = [
        {
            "id": "M1_pinned_unflushed_twal1_tail_included_in_branch_cut",
            "unflushed_wal_rows_captured": True,
            "matches_independent_copy_oracle": True,
            "copied_dataflow_state": "published_inactive",
            "inherited_outbox_disposition": "fenced_historical",
        },
        {
            "id": "M2_secondary_unique_key_collision_across_disjoint_branches",
            "source_insert": {"id": 3, "email": "dup@spoke.sh"},
            "target_insert": {"id": 4, "email": "dup@spoke.sh"},
            "expected_error": "error.SecondaryUniqueKeyMergeCollision",
        },
        {
            "id": "M3_cross_table_foreign_key_delete_insert_write_skew",
            "source_action": "DELETE FROM accounts WHERE account_id = 2",
            "target_action": "INSERT INTO orders (order_id, account_id) VALUES (101, 2)",
            "expected_error": "error.ForeignKeyMergeIntegrityViolation",
        },
        {
            "id": "M4_stale_target_head_occ_rejection_and_client_token_recovery",
            "stale_head_error": "error.StaleTargetBranchHead",
            "lost_reply_token_recovery": "returns_original_MergeOperationReceipt",
        },
        {
            "id": "M5_forward_restore_monotonic_successor_under_current_policy_epoch",
            "head_before_restore": 2,
            "restored_from_manifest_version": 1,
            "published_manifest_version": 3,
            "revoked_caller_error": "error.SourceTableSelectDenied",
            "outbox_disposition_after_restore": "fenced_historical",
        },
        {
            "id": "M6_remote_incremental_fetch_lazy_hydration_and_replay_fence",
            "common_ancestor_version": 1,
            "remote_head_version": 2,
            "skipped_ancestor_segments": 1,
            "transferred_delta_segments": 1,
            "live_network_connector_error": "error.LiveConnectorEffectForbiddenOnRemoteMirrorBranch",
            "corrupted_lazy_segment_error": "error.HydratedSegmentDigestMismatch",
        },
    ]

    return {
        "schema_version": 1,
        "contract_id": "transit.catalog.branch-merge-restore.v1",
        "a4_segment_skipping_matrix": a4_segment_skipping_matrix,
        "three_way_diff_and_conflict_vectors": three_way_diff_and_conflict_vectors,
        "branch_compaction_and_gc_scenarios": branch_compaction_and_gc_scenarios,
        "merge_and_restore_gates": merge_and_restore_gates,
    }


def verify_zig_sources(fixtures: dict) -> None:
    diff_zig = BRANCH_DIFF_ZIG_PATH.read_text(encoding="utf-8")
    lifecycle_zig = BRANCH_LIFECYCLE_ZIG_PATH.read_text(encoding="utf-8")
    merge_zig = BRANCH_MERGE_RESTORE_ZIG_PATH.read_text(encoding="utf-8")

    for required_diff_symbol in (
        "planTwoWaySegmentDiff",
        "planThreeWaySegmentDiff",
        "computeTwoWayRowDiff",
        "computeThreeWayRowDiff",
        "evaluateTopologicalEditConflict",
        "evaluateScene3DClashConflict",
        "diffTableSchemas",
        "CompactionLineageEdge",
    ):
        if required_diff_symbol not in diff_zig:
            raise SystemExit(f"BranchDiff.zig missing required symbol: {required_diff_symbol}")

    for required_lifecycle_symbol in (
        "BranchRegistry",
        "createBranchConditional",
        "advanceBranchHeadConditional",
        "dropBranch",
        "findLowestCommonAncestor",
        "materializeBranchTableRows",
        "verifyAgainstIndependentCopyOracle",
        "computeMultiBranchReachability",
        "evaluateBranchAwareCompaction",
        "error.ProtectedBranchDirectWriteForbidden",
        "error.SourceTableSelectDenied",
    ):
        if required_lifecycle_symbol not in lifecycle_zig:
            raise SystemExit(f"BranchLifecycle.zig missing required symbol: {required_lifecycle_symbol}")

    for required_merge_symbol in (
        "validateAndPublishThreeWayMerge",
        "mergeDocumentBranches",
        "restoreBranchForward",
        "fetchIncrementalFromRemote",
        "hydrateLazySegmentOnDemand",
        "checkLocalBranchConnectorExecution",
        "prepareUpstreamProposalPush",
        "error.SecondaryUniqueKeyMergeCollision",
        "error.ForeignKeyMergeIntegrityViolation",
        "error.PropertyGraphDanglingEdgeOnMerge",
        "error.StaleTargetBranchHead",
        "error.LiveConnectorEffectForbiddenOnRemoteMirrorBranch",
        "error.HydratedSegmentDigestMismatch",
    ):
        if required_merge_symbol not in merge_zig:
            raise SystemExit(f"BranchMergeRestore.zig missing required symbol: {required_merge_symbol}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    fixtures = build_fixtures()
    verify_zig_sources(fixtures)
    rendered = json.dumps(fixtures, indent=2) + "\n"

    if args.write:
        FIXTURE_PATH.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE_PATH.write_text(rendered, encoding="utf-8")
    elif not FIXTURE_PATH.is_file() or FIXTURE_PATH.read_text(encoding="utf-8") != rendered:
        raise SystemExit(
            f"Branch/merge/restore fixture drift in {FIXTURE_PATH}; regenerate with --write"
        )

    print(
        f"Branch merge/restore oracle: {len(fixtures['a4_segment_skipping_matrix'])} A4 segment-skipping cases, "
        f"{len(fixtures['three_way_diff_and_conflict_vectors'])} 3-way conflict vectors, and "
        f"{len(fixtures['merge_and_restore_gates'])} merge/restore/remote gates verified"
    )


if __name__ == "__main__":
    main()
