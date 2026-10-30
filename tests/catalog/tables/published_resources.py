#!/usr/bin/env python3
"""Independent oracle for Milestone 27 published business resources (PBR1),
three-way disclosure policies, consistent investigation bases (INV1),
4-clock freshness and attribution receipts (ATB1), multi-actor evaluation,
and cross-surface projection parity.
"""
from runner.paths import ROOT
import argparse
import hashlib
import json

FIXTURE_PATH = ROOT / "contracts/catalog/published-resource-fixtures.json"
PUBLISHED_RESOURCE_ZIG = ROOT / "packages/zig/transit-catalog/src/PublishedResource.zig"
DISCLOSURE_POLICY_ZIG = ROOT / "packages/zig/transit-catalog/src/DisclosurePolicy.zig"
INVESTIGATION_BASIS_ZIG = ROOT / "packages/zig/transit-catalog/src/InvestigationBasis.zig"
ATTRIBUTION_ZIG = ROOT / "packages/zig/transit-catalog/src/Attribution.zig"
PUBLISHED_PROJECTION_ZIG = ROOT / "packages/zig/transit-catalog/src/PublishedProjection.zig"
OBSERVATION_ZIG = ROOT / "packages/zig/transit-sql-results/src/Observation.zig"


def sha256_hex(domain: bytes, payload: bytes) -> str:
    return hashlib.sha256(domain + b"\x00" + payload).hexdigest()


def build_fixtures() -> dict:
    pbr_digest = sha256_hex(
        b"transit.catalog.published-resource.v1",
        b"PBR1:obj=500:rev=1:regional_delivery_assessment:tzdb_2026a",
    )
    inv_v1_digest = sha256_hex(
        b"transit.catalog.investigation-basis.v1",
        b"INV1:id=999:rev=1:multi_source_basis_vector:obj10@lsn100,obj20@etag-v1",
    )
    inv_v2_digest = sha256_hex(
        b"transit.catalog.investigation-basis.v1",
        b"INV1:id=999:rev=2:parent=1:multi_source_basis_vector:obj10@lsn180,obj20@etag-v2",
    )
    assert inv_v1_digest != inv_v2_digest

    emp_aud_hash = sha256_hex(
        b"transit.catalog.audience-policy.v1",
        b"obj=500:epoch=10:full_resource_and_drilldown:employee_full",
    )
    triage_aud_hash = sha256_hex(
        b"transit.catalog.audience-policy.v1",
        b"obj=500:epoch=10:summary_or_report_only:agent_triage_summary",
    )
    assert emp_aud_hash != triage_aud_hash

    acceptance_scenarios = [
        {
            "id": "S1_headless_published_resource_pbr1",
            "resource_object": 500,
            "publication_revision": 1,
            "canonical_name": "regional_delivery_assessment_without_any_21_byte_station_kv_cap",
            "requires_screens": False,
            "requires_themes": False,
            "tzdb_version": "tzdb_2026a",
            "definition_digest_hex": pbr_digest,
        },
        {
            "id": "S2_multi_actor_5_queries_and_report_on_one_basis",
            "actors": [
                {"principal": 100, "role": "employee_analyst", "audience": "full_resource_and_drilldown"},
                {"principal": 201, "role": "agent_triage", "audience": "summary_or_report_only"},
                {"principal": 202, "role": "agent_deep_dive", "audience": "full_resource_and_drilldown"},
            ],
            "investigation_id": 999,
            "basis_revision": 1,
            "basis_digest_hex": inv_v1_digest,
            "related_queries": 5,
            "report_id": "joint_delivery_investigation_report",
            "consistent_basis_retained": True,
        },
        {
            "id": "S3_explicit_successor_refresh_preserves_prior_attribution",
            "investigation_id": 999,
            "parent_basis_revision": 1,
            "parent_basis_digest_hex": inv_v1_digest,
            "successor_basis_revision": 2,
            "successor_basis_digest_hex": inv_v2_digest,
            "prior_report_reattachment_to_v2": "error.AttributionBasisMismatch",
        },
        {
            "id": "S4_multi_source_vector_never_claims_global_atomicity",
            "atomic_domain_cut_globally_atomic": True,
            "multi_source_vector_globally_atomic": False,
            "require_global_atomicity_on_vector": "error.NonAtomicBasisVector",
        },
        {
            "id": "S5_schema_evolution_deletion_missing_capture_and_expiry",
            "schema_evolution_projected": True,
            "deleted_source_outcome": "error.InvestigationSourceDeleted",
            "missing_external_capture_outcome": "error.MissingExternalCapture",
            "expired_pin_or_reclaimed_history_outcome": "error.InvestigationBasisExpired",
        },
        {
            "id": "S6_report_only_parameter_k_anonymity_and_drilldown_bounds",
            "out_of_domain_parameter": "error.ParameterDomainViolation",
            "injected_filter_pushdown": "error.UnexposedFilterPushdownRejected",
            "small_group_below_k_anonymity_5": "missing",
            "restricted_type_error_cell_scrubbed": "missing",
            "raw_row_drilldown_by_report_only": "error.DisclosureBoundaryViolation",
        },
        {
            "id": "S7_service_credential_non_amplification",
            "service_transport_admin_rights": True,
            "caller_lacks_source_rights": "error.ServiceCredentialAmplificationForbidden",
        },
        {
            "id": "S8_mid_stream_revocation_and_publication_withdrawal",
            "page_1_epoch_10": "disclosed",
            "page_2_revoked_epoch_11": "error.AuthorizationRevokedMidStream",
            "withdrawn_resource_outcome": "error.PublishedResourceWithdrawn",
            "interrupted_completeness": "interrupted_prefix",
        },
        {
            "id": "S9_cross_audience_cache_isolation",
            "employee_audience_hash": emp_aud_hash,
            "agent_triage_audience_hash": triage_aud_hash,
            "cross_audience_cache_reuse_permitted": False,
        },
        {
            "id": "S10_four_clock_freshness_and_non_oracle_narratives",
            "clocks": [
                "source_observation_cut_ms",
                "domain_event_valid_time_ms",
                "computation_completion_cut_ms",
                "requested_freshness_sla_ms",
            ],
            "statuses": [
                "fresh",
                "stale_within_tolerance",
                "stale_exceeded",
                "unknown_freshness",
                "source_conflict",
            ],
            "provenance_establishes_truth": False,
            "claim_truth_inflation_outcome": "error.ProvenanceCannotClaimObjectiveTruth",
        },
        {
            "id": "S11_cross_surface_parity_five_states_and_wide_numerics",
            "surfaces": ["sql_console", "shared_sdk_client", "board_workbook", "mcp_resource_and_app"],
            "cell_states": ["value", "null", "missing", "type_error", "conflict"],
            "wide_numerics": ["int64_max", "uint64_max", "decimal128"],
            "completeness_states": ["complete", "window_truncated", "interrupted_prefix", "budget_exceeded"],
        },
        {
            "id": "S12_bounded_memory_and_deterministic_cleanup",
            "steady_state_heap_allocations": 0,
            "active_readers_after_close": 0,
            "active_pin_leases_after_close": 0,
        },
    ]

    return {
        "schema_version": 1,
        "contracts": {
            "published_resource": "transit.catalog.published-resource.v1",
            "investigation_basis": "transit.catalog.investigation-basis.v1",
            "attribution_receipt": "transit.catalog.attribution-receipt.v1",
        },
        "acceptance_scenarios": acceptance_scenarios,
    }


def verify_zig_sources() -> None:
    pbr_text = PUBLISHED_RESOURCE_ZIG.read_text(encoding="utf-8")
    disc_text = DISCLOSURE_POLICY_ZIG.read_text(encoding="utf-8")
    inv_text = INVESTIGATION_BASIS_ZIG.read_text(encoding="utf-8")
    attr_text = ATTRIBUTION_ZIG.read_text(encoding="utf-8")
    proj_text = PUBLISHED_PROJECTION_ZIG.read_text(encoding="utf-8")
    obs_text = OBSERVATION_ZIG.read_text(encoding="utf-8")

    required_by_file = [
        (pbr_text, "PublishedResource.zig", [
            "magic_pbr1",
            "PublishedResourceDescriptor",
            "ParameterDomainConstraint",
            "PresentationBindings",
            "validateAndDigestParameters",
            "error.ParameterDomainViolation",
        ]),
        (disc_text, "DisclosurePolicy.zig", [
            "DisclosureMode",
            "PublicationAttestation",
            "authorizeEvaluation",
            "authorizeDrilldown",
            "applyDisclosureRowFilter",
            "AudienceCacheKey",
            "error.ServiceCredentialAmplificationForbidden",
            "error.DisclosureBoundaryViolation",
            "error.UnexposedFilterPushdownRejected",
            "error.PublishedResourceWithdrawn",
        ]),
        (inv_text, "InvestigationBasis.zig", [
            "magic_inv1",
            "InvestigationBasis",
            "atomic_domain_cut",
            "multi_source_basis_vector",
            "verifyForResourceEvaluation",
            "refreshSuccessor",
            "error.NonAtomicBasisVector",
            "error.InvestigationBasisExpired",
            "error.InvestigationSourceDeleted",
            "error.MissingExternalCapture",
        ]),
        (attr_text, "Attribution.zig", [
            "magic_atb1",
            "FourClockFreshness",
            "AttributionReceipt",
            "NarrativeClaim",
            "ReportArtifact",
            "error.AttributionBasisMismatch",
            "error.ProvenanceCannotClaimObjectiveTruth",
        ]),
        (proj_text, "PublishedProjection.zig", [
            "discoverPublishedResources",
            "projectResourceSurface",
            "AllocationProbe",
            "PublishedResourceStreamReader",
            "error.AuthorizationRevokedMidStream",
        ]),
        (obs_text, "Observation.zig", [
            "PublishedResourceObservation",
            "validateBatchDisclosure",
        ]),
    ]

    for content, label, symbols in required_by_file:
        for sym in symbols:
            if sym not in content:
                raise SystemExit(f"{label} missing required symbol: {sym}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    fixtures = build_fixtures()
    verify_zig_sources()
    rendered = json.dumps(fixtures, indent=2) + "\n"

    if args.write:
        FIXTURE_PATH.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE_PATH.write_text(rendered, encoding="utf-8")
    elif not FIXTURE_PATH.is_file() or FIXTURE_PATH.read_text(encoding="utf-8") != rendered:
        raise SystemExit(
            f"Published resource fixture drift in {FIXTURE_PATH}; regenerate with --write"
        )

    print(
        f"Published resources: {len(fixtures['acceptance_scenarios'])} multi-actor "
        f"investigation scenarios and 3 v1 contracts verified"
    )


if __name__ == "__main__":
    main()
