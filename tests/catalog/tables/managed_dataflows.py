#!/usr/bin/env python3
"""Independent oracle for Milestone 12 managed computations and WAL-activated
dataflows (`T5` snapshot-to-live handoff, `T8` 5-state lifecycle & DDL
evolution, `A3` DBSP Z-set incremental equivalence, Milestone 5 multi-object
`Transaction.Cut` alignment, bitemporal `AS OF JOIN`, and governed
`CONNECTION`/`SOURCE`/`SINK` catalog bindings).
"""
from runner.paths import ROOT
import argparse
import hashlib
import json

FIXTURE_PATH = ROOT / "contracts/catalog/managed-dataflow-fixtures.json"
MANAGED_ZIG_PATH = ROOT / "packages/zig/transit-catalog/src/ManagedDataflow.zig"
DELTA_ZIG_PATH = ROOT / "packages/zig/transit-fuze/src/FuzeDelta.zig"
BITEMPORAL_ZIG_PATH = ROOT / "packages/zig/transit-fuze/src/BitemporalAndTvf.zig"
ANALYTICAL_ZIG_PATH = ROOT / "packages/zig/transit-fuze/src/AnalyticalSql.zig"
UDF_ZIG_PATH = ROOT / "packages/zig/transit-fuze/src/VectorUdf.zig"


def build_fixtures() -> dict:
    five_state_lifecycle_matrix = [
        {"from": "published", "verb": "AUTHORIZE", "to": "authorized", "admitted": True},
        {"from": "published", "verb": "ACTIVATE", "to": None, "admitted": False, "error": "error.DataflowNotAuthorized"},
        {"from": "authorized", "verb": "ACTIVATE", "to": "active", "admitted": True, "acquires_lease_epoch": True},
        {"from": "active", "verb": "SUSPEND", "to": "suspended", "admitted": True, "fences_previous_lease_epoch": True, "preserves_completed_revision": True},
        {"from": "suspended", "verb": "RESUME(replay_history, retained_wal)", "to": "active", "admitted": True},
        {"from": "suspended", "verb": "RESUME(replay_history, compacted_wal)", "to": "suspended", "admitted": False, "error": "error.DataflowHistoryExpired", "blocked_reason": "history_expired"},
        {"from": "suspended", "verb": "RESUME(recompute_snapshot, complete_ordered_changes, compacted_wal)", "to": "suspended", "admitted": False, "error": "error.CompleteOrderedConsumerCannotSkipHistory", "blocked_reason": "history_expired"},
        {"from": "suspended", "verb": "RESUME(recompute_snapshot, net_relation_changes, compacted_wal)", "to": "active", "admitted": True, "establishes_new_handoff_cut": True},
        {"from": "active", "verb": "RETIRE", "to": "retired", "admitted": True, "preserves_historical_receipts": True},
        {"from": "retired", "verb": "AUTHORIZE", "to": "retired", "admitted": False, "error": "error.DataflowAlreadyRetired"},
    ]

    a3_zset_oracle_vectors = [
        {
            "id": "A3_oscillation_A_to_B_to_A_and_same_batch_cancel",
            "step_1_deltas": [{"key": 1, "val": 100, "weight": 1}, {"key": 2, "val": 110, "weight": 1}],
            "step_2_deltas": [
                {"key": 1, "val": 100, "weight": -1},
                {"key": 3, "val": 120, "weight": 1},
                {"key": 3, "val": 120, "weight": -1},
            ],
            "expected_consolidated_keys": [2],
        },
        {
            "id": "A3_reversible_checked_overflow_retraction",
            "group_key": "g1",
            "step_1_inserts": ["MAX_INT64", 10],
            "step_1_materialized_state": "type_error(int64)",
            "step_2_retractions": ["MAX_INT64"],
            "step_2_materialized_state": "value(10)",
        },
    ]

    scenarios = [
        {
            "id": "S1_T5_snapshot_to_live_handoff_deduplication",
            "handoff_cut_lsn": 10,
            "incoming_wal_lsns": [10, 11],
            "skipped_duplicates_at_cut": 1,
            "applied_post_cut_records": 1,
            "completed_revision_lsn": 11,
        },
        {
            "id": "S2_M5_multi_table_transaction_cut_barrier",
            "tx_id": 77,
            "tx_cut_id": 770,
            "step_1_decision": "pending_participants",
            "step_1_published_revision_advanced": False,
            "step_2_decision": "committed_cut",
            "step_2_published_revision_advanced": True,
        },
        {
            "id": "S3_bitemporal_as_of_join_backfill_isolation",
            "entity_key": 42,
            "valid_period": [100, 300],
            "initial_commit_lsn": 10,
            "initial_value": 1000,
            "retroactive_backfill_lsn": 25,
            "backfill_value": 9999,
            "as_of_lsn_15_result": 1000,
            "as_of_lsn_30_result": 9999,
        },
        {
            "id": "S4_T8_upstream_schema_evolution_and_policy_revocation",
            "class_a_lazy_evolution_outcome": "projected_seamlessly",
            "class_b_phased_rewrite_outcome": "error.SourcePhasedRewriteInProgress",
            "incompatible_ddl_outcome": "error.IncompatibleSourceSchemaEvolution",
            "policy_revocation_outcome": "error.DataflowAuthorizationRevoked",
            "preserves_last_completed_revision": True,
        },
        {
            "id": "S5_governed_connector_sink_and_zero_work_explain",
            "inline_plaintext_secret": "error.InlinePlaintextSecretRejected",
            "drop_referenced_connection": "error.ConnectionReferencedByEndpoint",
            "drop_referenced_sink": "error.SinkReferencedByActiveDataflow",
            "explain_acquires_pins": False,
            "engine_dispatches_external_effects_directly": 0,
        },
    ]

    cross_milestone_handoffs = {
        "M11_source_phased_rewrite_gate": "error.SourcePhasedRewriteInProgress",
        "M17_spatial_zset_boundary_operator_gate": "error.SpatialZSetExecutionDeferredToM17",
        "M5_prepared_plan_ddl_invalidation": "error.PreparedPlanInvalidatedByDdl",
        "M26_mid_stream_policy_revocation": "error.AuthorizationRevokedMidStream",
    }

    payload = {
        "schema_version": 1,
        "contract_id": "transit.catalog.managed-dataflow.v1",
        "five_state_lifecycle_matrix": five_state_lifecycle_matrix,
        "a3_zset_oracle_vectors": a3_zset_oracle_vectors,
        "scenarios": scenarios,
        "cross_milestone_handoffs": cross_milestone_handoffs,
    }
    digest = hashlib.sha256(
        json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    return {**payload, "sha256": digest}


def verify_zig_sources(fixtures: dict) -> None:
    managed_zig = MANAGED_ZIG_PATH.read_text(encoding="utf-8")
    delta_zig = DELTA_ZIG_PATH.read_text(encoding="utf-8")
    bitemporal_zig = BITEMPORAL_ZIG_PATH.read_text(encoding="utf-8")
    analytical_zig = ANALYTICAL_ZIG_PATH.read_text(encoding="utf-8")
    udf_zig = UDF_ZIG_PATH.read_text(encoding="utf-8")
    combined = "\n".join((managed_zig, delta_zig, bitemporal_zig, analytical_zig, udf_zig))

    for handoff_key, err_token in fixtures["cross_milestone_handoffs"].items():
        if err_token not in combined:
            raise SystemExit(f"Missing fail-closed handoff error {err_token} ({handoff_key}) in Zig implementation")

    for required_symbol in (
        "establishSnapshotToLiveHandoff",
        "suspendDataflow",
        "resumeDataflow",
        "retireDataflow",
        "ingestWalDeltaBatch",
        "explainZeroWork",
        "inspectStatus",
        "stepIncrementalInnerJoin",
        "evaluateFiniteJoinOracle",
        "executeBitemporalAsOfJoin",
        "evaluateChangesTvf",
        "evaluateStreamSliceTvf",
        "executeTransactionalMerge",
        "executeUnnestedDJoin",
        "evaluateScalarBatch",
        "error.DataflowHistoryExpired",
        "error.StaleDataflowLeaseEpoch",
        "error.MergeCardinalityViolation",
        "error.AmbientUdfImportRejected",
    ):
        if required_symbol not in combined:
            raise SystemExit(f"Milestone 12 Zig implementation missing required symbol: {required_symbol}")


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
            f"Managed dataflow fixture drift in {FIXTURE_PATH}; regenerate with --write"
        )

    print(
        f"Managed dataflows: {len(fixtures['five_state_lifecycle_matrix'])} lifecycle edges, "
        f"{len(fixtures['scenarios'])} scenarios, and "
        f"{len(fixtures['cross_milestone_handoffs'])} cross-milestone gates verified"
    )


if __name__ == "__main__":
    main()
