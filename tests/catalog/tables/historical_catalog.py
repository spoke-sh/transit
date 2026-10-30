#!/usr/bin/env python3
"""Independent oracle for Milestone 10 historical catalog manifests, AS OF /
PROJECTING TO resolution, current policy_epoch authorization, 5-state CHECK
constraints, EBCDIC collations, and multi-model descriptors.
"""
from runner.paths import ROOT
import argparse
import hashlib
import json
import struct

FIXTURE_PATH = ROOT / "contracts/catalog/historical-manifest-fixtures.json"
HISTORICAL_ZIG_PATH = ROOT / "packages/zig/transit-catalog/src/HistoricalCatalog.zig"
CONSTRAINTS_ZIG_PATH = ROOT / "packages/zig/transit-fuze/src/TableConstraints.zig"


def tzdb_digest_hex(version_id: str) -> str:
    return hashlib.sha256(b"transit.catalog.tzdb.v1\x00" + version_id.encode("utf-8")).hexdigest()


def build_fixtures() -> dict:
    tz_2026a = tzdb_digest_hex("tzdb_2026a")
    tz_2026b = tzdb_digest_hex("tzdb_2026b")
    assert tz_2026a != tz_2026b

    check_five_state_truth_table = [
        {"cell_state": "value", "predicate_outcome": True, "admitted": True, "reason": None},
        {"cell_state": "null", "predicate_outcome": None, "admitted": True, "reason": None},
        {"cell_state": "value", "predicate_outcome": False, "admitted": False, "reason": "predicate_false"},
        {"cell_state": "missing", "predicate_outcome": None, "admitted": False, "reason": "missing_cell"},
        {"cell_state": "type_error", "predicate_outcome": None, "admitted": False, "reason": "type_error_cell"},
        {"cell_state": "conflict", "predicate_outcome": None, "admitted": False, "reason": "conflict_cell"},
    ]

    # EBCDIC CP037 vs UCS_BASIC (UTF8_BINARY) ordering oracle:
    # In ASCII/UTF-8: '9' (0x39) < 'A' (0x41) < 'a' (0x61)
    # In EBCDIC CP037: 'a' (0x81) < 'A' (0xC1) < '9' (0xF9)
    ebcdic_order_vectors = [
        {
            "inputs": ["99  ", "A1  ", "a1  "],
            "utf8_binary_order": ["99  ", "A1  ", "a1  "],
            "ebcdic_037_pad_order": ["a1  ", "A1  ", "99  "],
            "pad_equivalence": {"left": "A1", "right": "A1  ", "ebcdic_037_pad_equal": True, "utf8_binary_equal": False},
        }
    ]

    # Historical catalog lineage and AS OF / PROJECTING TO acceptance matrix
    historical_lineage = {
        "manifests": [
            {
                "manifest_version": 1,
                "commit_lsn": 10,
                "branch": "main",
                "tzdb_version": "tzdb_2026a",
                "tzdb_digest_hex": tz_2026a,
                "tables": [
                    {
                        "namespace": 1,
                        "name": "orders",
                        "object": 10,
                        "revision": 1,
                        "columns": [
                            {"id": 1, "name": "id", "type": "int64", "collation": "none"},
                            {"id": 2, "name": "legacy_code", "type": "utf8", "collation": "ebcdic_037_pad"},
                        ],
                    }
                ],
            },
            {
                "manifest_version": 2,
                "commit_lsn": 20,
                "branch": "main",
                "tzdb_version": "tzdb_2026a",
                "tzdb_digest_hex": tz_2026a,
                "tables": [
                    {
                        "namespace": 1,
                        "name": "orders",
                        "object": 10,
                        "revision": 2,
                        "columns": [
                            {"id": 1, "name": "id", "type": "int64", "collation": "none"},
                            {"id": 2, "name": "code", "type": "utf8", "collation": "ebcdic_037_pad"},
                            {"id": 3, "name": "region", "type": "utf8", "collation": "none", "origin_default": "EU-WEST"},
                        ],
                    }
                ],
            },
            {
                "manifest_version": 3,
                "commit_lsn": 30,
                "branch": "main",
                "tzdb_version": "tzdb_2026b",
                "tzdb_digest_hex": tz_2026b,
                "tables": [
                    {
                        "namespace": 1,
                        "name": "orders_archive",
                        "object": 10,
                        "revision": 3,
                        "columns": [
                            {"id": 1, "name": "id", "type": "int64", "collation": "none"},
                            {"id": 3, "name": "region", "type": "utf8", "collation": "none", "origin_default": "EU-WEST"},
                        ],
                    },
                    {
                        "namespace": 1,
                        "name": "orders",
                        "object": 20,
                        "revision": 1,
                        "columns": [
                            {"id": 1, "name": "id", "type": "int64", "collation": "none"},
                            {"id": 2, "name": "code", "type": "int64", "collation": "none"},
                        ],
                    },
                ],
            },
        ],
        "scenarios": [
            {
                "id": "S1_as_of_manifest_v1_native_schema",
                "query_table": "orders",
                "as_of_manifest": 1,
                "project_to_manifest": None,
                "resolved_object": 10,
                "historical_revision": 1,
                "output_revision": 1,
                "output_columns": ["id", "legacy_code"],
            },
            {
                "id": "S2_as_of_manifest_v1_projecting_to_v3",
                "query_table": "orders",
                "as_of_manifest": 1,
                "project_to_manifest": 3,
                "resolved_object": 10,
                "historical_revision": 1,
                "output_revision": 3,
                "output_columns": ["id", "region"],
                "synthesized_default_columns": 1,
                "omitted_dropped_columns": 1,
            },
            {
                "id": "S3_recreated_table_lineage_isolation",
                "query_table": "orders",
                "as_of_manifest": 3,
                "project_to_manifest": 1,
                "resolved_object": 20,
                "expected_error": "IncompatibleHistoricalObjectLineage",
            },
            {
                "id": "S4_current_policy_epoch_metadata_vs_select",
                "policy_epoch": 10,
                "metadata_only_describe_as_of": "admitted",
                "metadata_only_select_as_of": "error.RowSelectPermissionDenied",
            },
            {
                "id": "S5_mid_stream_batch_revocation",
                "batch_1_policy_epoch": 11,
                "batch_1_outcome": "disclosed",
                "batch_2_policy_epoch": 12,
                "batch_2_outcome": "error.AuthorizationRevokedMidStream",
            },
            {
                "id": "S6_retention_watermark_expiry",
                "min_retained_manifest_version": 2,
                "query_as_of_manifest": 1,
                "expected_error": "error.HistoricalSnapshotExpired",
            },
        ],
        "cross_milestone_handoffs": {
            "M11_foreign_key_runtime_index_enforcer": "error.ForeignKeyIndexEnforcementUnavailable",
            "M11_online_phased_table_rewrite": "error.OnlinePhasedRewriteRequired",
            "M18_sql_pgq_graph_table_execution": "error.SqlPgqExecutionDeferredToM18",
            "M18_sql_med_foreign_table_scan": "error.SqlMedScanDeferredToM18",
            "M19_multi_commit_branch_divergence": "error.MultiCommitBranchingDeferredToM19",
        },
    }

    return {
        "schema_version": 1,
        "contract_id": "transit.catalog.historical-manifest.v1",
        "check_five_state_truth_table": check_five_state_truth_table,
        "ebcdic_order_vectors": ebcdic_order_vectors,
        "historical_lineage": historical_lineage,
    }


def verify_zig_sources(fixtures: dict) -> None:
    hist_zig = HISTORICAL_ZIG_PATH.read_text(encoding="utf-8")
    constraints_zig = CONSTRAINTS_ZIG_PATH.read_text(encoding="utf-8")

    for handoff_key, err_token in fixtures["historical_lineage"]["cross_milestone_handoffs"].items():
        if err_token not in hist_zig and err_token not in constraints_zig:
            raise SystemExit(f"Missing fail-closed handoff error {err_token} ({handoff_key}) in Zig implementation")

    for required_symbol in (
        "publishHeadConditional",
        "admitHistoricalQuery",
        "fetchNextHistoricalBatch",
        "PropertyGraphDescriptor",
        "ForeignTableDescriptor",
        "ViewDescriptor",
        "error.AuthorizationRevokedMidStream",
        "error.HistoricalSnapshotExpired",
        "error.IncompatibleHistoricalObjectLineage",
    ):
        if required_symbol not in hist_zig:
            raise SystemExit(f"HistoricalCatalog.zig missing required symbol: {required_symbol}")


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
            f"Historical catalog fixture drift in {FIXTURE_PATH}; regenerate with --write"
        )

    print(
        f"Historical catalog: {len(fixtures['historical_lineage']['manifests'])} manifests, "
        f"{len(fixtures['historical_lineage']['scenarios'])} scenarios, and "
        f"{len(fixtures['historical_lineage']['cross_milestone_handoffs'])} cross-milestone gates verified"
    )


if __name__ == "__main__":
    main()
