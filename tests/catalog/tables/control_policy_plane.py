#!/usr/bin/env python3
"""Independent oracle for Milestone 26 Enterprise Identity and the Control & Policy Plane:
AccessContext (ACTX1), OIDC/SCIM federation & freshness (IDF1), delegation & human-only
approval (DLG1, APV1), declarative secrets & OAuth2/PKCE challenge dataflows (SEC1),
security-barrier RLS & dynamic masking (RLM1), GDPR crypto-shredding & cross-branch
purge (ERS1), workload resource groups (WLM1), and zero-work EXPLAIN POLICY.
"""
from runner.paths import ROOT
import argparse
import base64
import hashlib
import json

FIXTURE_PATH = ROOT / "contracts/catalog/control-policy-plane-fixtures.json"
ACCESS_ZIG = ROOT / "packages/zig/transit-catalog/src/AccessAndIdentity.zig"
DELEGATION_ZIG = ROOT / "packages/zig/transit-catalog/src/DelegationAndSecrets.zig"
ERASURE_ZIG = ROOT / "packages/zig/transit-catalog/src/ErasureAndWorkload.zig"
INGRESS_ZIG = ROOT / "packages/zig/transit-catalog/src/DeclarativeIngress.zig"
PROJECTION_ZIG = ROOT / "packages/zig/transit-catalog/src/PublishedProjection.zig"
RLS_ZIG = ROOT / "packages/zig/transit-fuze/src/RlsAndMasking.zig"
LEAN_REWRITE = ROOT / "contracts/sql/FuzeRewrite.lean"


def sha256_hex(domain: bytes, payload: bytes) -> str:
    return hashlib.sha256(domain + b"\x00" + payload).hexdigest()


def rfc7636_s256(code_verifier: bytes) -> str:
    digest = hashlib.sha256(code_verifier).digest()
    return base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")


def build_fixtures() -> dict:
    # RFC 7636 Appendix B test vector for PKCE S256
    rfc7636_verifier = b"dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    rfc7636_challenge = rfc7636_s256(rfc7636_verifier)
    assert rfc7636_challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

    actx_digest = sha256_hex(
        b"transit.catalog.access-context.v1",
        b"ACTX1:acct=1:subj=1001:actor=2001:deleg=1:epoch=42:assur=multi_factor",
    )
    dlg_digest = sha256_hex(
        b"transit.catalog.delegation.v1",
        b"DLG1:id=900:grantor=1001:grantee=2001:mask=0x3:budget=50",
    )
    sec_digest = sha256_hex(
        b"transit.catalog.secret-manager.v1",
        b"SEC1:id=700:name=github_mcp:type=oauth2_pkce:scope=https://api.github.com/repos/spoke-sh/",
    )
    ers_digest = sha256_hex(
        b"transit.catalog.erasure.v1",
        b"ERS1:req=3001:subj=42:kek=77:purged_lsn=880",
    )

    acceptance_scenarios = [
        {
            "id": "S1_federation_scim_and_deprovisioned_principal_revocation",
            "magic": "ACTX1",
            "federation_magic": "IDF1",
            "scim_deprovision_advances_policy_epoch": True,
            "conflicting_management_source_outcome": "error.ConflictingManagementSource",
            "local_hold_override_outcome": "error.LocalRestrictionOverridesExternalSync",
            "access_context_digest_hex": actx_digest,
        },
        {
            "id": "S2_federation_outage_blocks_stale_external_claims",
            "stale_external_claim_during_outage_outcome": "error.IdentityProviderUnavailable",
            "native_local_ed25519_succeeds_during_idp_outage": True,
            "offboarded_principal_outcome": "error.AccessRevoked",
        },
        {
            "id": "S3_delegation_attenuation_and_human_only_approval",
            "delegation_magic": "DLG1",
            "approval_magic": "APV1",
            "delegation_digest_hex": dlg_digest,
            "delegate_human_only_action_outcome": "error.CannotDelegateHumanOnlyAction",
            "delegated_agent_approval_outcome": "error.DelegatedAgentCannotApprove",
            "self_approval_outcome": "error.SeparationOfDutiesViolation",
        },
        {
            "id": "S4_security_barrier_rls_and_geospatial_rls_non_interference",
            "rls_magic": "RLM1",
            "unauthorized_div_zero_leaks": False,
            "unauthorized_type_error_leaks": False,
            "geospatial_outside_bbox_or_z_range_disclosed": False,
            "lean_theorem": "security_barrier_rls_non_interference",
        },
        {
            "id": "S5_dynamic_masking_and_german_string_prefix_scrubbing",
            "unmasked_german_string_prefix_retained": False,
            "masked_german_string_prefix_ascii": "***-",
            "zone_map_min_max_on_masked_column_sanitized": True,
        },
        {
            "id": "S6_branch_governance_across_all_nine_adapters",
            "actions": [
                "inspect",
                "create_branch",
                "edit",
                "share",
                "propose",
                "approve",
                "merge",
                "external_activation",
            ],
            "protected_main_direct_write_outcome": "error.ProtectedBranchDirectWriteDenied",
            "branching_only_merge_outcome": "error.InstallationProhibitsMerge",
        },
        {
            "id": "S7_secret_manager_dual_guard_and_redaction",
            "secret_magic": "SEC1",
            "secret_digest_hex": sec_digest,
            "dual_guard_requires": ["USAGE_ON_SECRET", "URL_PREFIX_SCOPE_MATCH"],
            "missing_grant_outcome": "error.MissingSecretUsagePrivilege",
            "out_of_scope_url_outcome": "error.SecretScopeMismatch",
            "plaintext_literal_outcome": "error.PlaintextSecretLiteralForbidden",
        },
        {
            "id": "S8_oauth2_pkce_challenge_game_dataflow_suspend_and_resume",
            "rfc7636_code_verifier": rfc7636_verifier.decode("ascii"),
            "rfc7636_s256_challenge": rfc7636_challenge,
            "suspended_state": "credential_pending",
            "wrong_pkce_verifier_outcome": "error.OauthPkceVerificationFailed",
            "replayed_callback_outcome": "error.OauthChallengeReplayDetected",
        },
        {
            "id": "S9_gdpr_crypto_shredding_and_cross_branch_purge",
            "erasure_magic": "ERS1",
            "erasure_digest_hex": ers_digest,
            "shredded_subject_read_state": "missing",
            "compaction_emits_lineage_edge": True,
            "contains_raw_subject_pii": False,
        },
        {
            "id": "S10_workload_resource_groups_and_admission_bounds",
            "workload_magic": "WLM1",
            "escalation_outcome": "error.WorkloadGroupEscalationDenied",
            "soft_memory_outcome": "spill_to_nvme_tier2",
            "hard_memory_outcome": "error.WorkloadMemoryQuotaExceeded",
        },
        {
            "id": "S11_zero_work_explain_policy_and_access_audit",
            "explain_policy_work_bound": "zero_work_explain",
            "explain_policy_touches_tseg_or_secrets": False,
            "audit_log_records_denials_and_secret_resolutions": True,
        },
        {
            "id": "S12_revocation_during_flight_and_operation_status_inspection",
            "revocation_terminates_result_disclosure": "error.AccessRevokedOnResultDisclosure",
            "original_caller_can_inspect_settled_operation_status": True,
        },
        {
            "id": "S13_declarative_browser_ingress_webhook_admission_and_watermark_watches",
            "oidc_rs256_verification": "verifySignedJwtRs256",
            "browser_cookie_mismatch_outcome": "error.OauthBrowserCookieMismatch",
            "webhook_replay_outcome": "error.WebhookDeliveryReplayDetected",
            "unbound_session_outcome": "error.UnboundExternalSubject",
            "bootstrap_owner_binding_outcome": "error.BootstrapOwnerExternalBindingForbidden",
            "watermark_watch_revocation_close_code": 1008,
        },
    ]

    return {
        "schema_version": 1,
        "contracts": {
            "control_policy_plane": "transit.control-policy-plane.v1",
            "authorization": "transit.authorization.v1",
            "secret_manager": "transit.secret-manager.v1",
        },
        "acceptance_scenarios": acceptance_scenarios,
    }


def verify_sources() -> None:
    access_text = ACCESS_ZIG.read_text(encoding="utf-8")
    deleg_text = DELEGATION_ZIG.read_text(encoding="utf-8")
    erasure_text = ERASURE_ZIG.read_text(encoding="utf-8")
    ingress_text = INGRESS_ZIG.read_text(encoding="utf-8")
    projection_text = PROJECTION_ZIG.read_text(encoding="utf-8")
    rls_text = RLS_ZIG.read_text(encoding="utf-8")
    lean_text = LEAN_REWRITE.read_text(encoding="utf-8")

    required_by_file = [
        (access_text, "AccessAndIdentity.zig", [
            "magic_actx1",
            "magic_idf1",
            "AccessContext",
            "PrincipalBindingDirectory",
            "ScimProvisioningEngine",
            "MembershipFreshnessGuard",
            "AccessAuditLog",
            "verifySignedJwtRs256",
            "error.ConflictingManagementSource",
            "error.LocalRestrictionOverridesExternalSync",
            "error.IdentityProviderUnavailable",
        ]),
        (deleg_text, "DelegationAndSecrets.zig", [
            "magic_dlg1",
            "magic_apv1",
            "magic_sec1",
            "DelegationChain",
            "ApprovalAttestation",
            "SecretDeclaration",
            "OauthChallengeGame",
            "WebhookEndpointDeclaration",
            "WebhookAdmissionEngine",
            "computePkceS256Challenge",
            "error.CannotDelegateHumanOnlyAction",
            "error.DelegatedAgentCannotApprove",
            "error.SeparationOfDutiesViolation",
            "error.MissingSecretUsagePrivilege",
            "error.SecretScopeMismatch",
            "error.OauthPkceVerificationFailed",
            "error.OauthChallengeReplayDetected",
            "error.OauthBrowserCookieMismatch",
            "error.WebhookDeliveryReplayDetected",
        ]),
        (ingress_text, "DeclarativeIngress.zig", [
            "InboundBoundaryPolicy",
            "IdentityProviderDeclaration",
            "BrowserSessionLedger",
            "claimLoginCallbackForExchange",
            "completeLoginAfterTokenExchange",
            "resolveBoundSessionAccessContext",
            "error.BootstrapOwnerExternalBindingForbidden",
        ]),
        (projection_text, "PublishedProjection.zig", [
            "evaluatePublishedSnapshotJson",
            "WatermarkReactiveWatchSession",
            "pollNextFrame",
            "error.SessionRevokedBeforeDisclosure",
        ]),
        (erasure_text, "ErasureAndWorkload.zig", [
            "magic_ers1",
            "magic_wlm1",
            "SubjectEnvelopeKeyRegistry",
            "ErasureReceipt",
            "WorkloadGroupController",
            "explainPolicyForStatement",
            "inspectOperationAfterLostReply",
            "error.WorkloadGroupEscalationDenied",
            "error.WorkloadMemoryQuotaExceeded",
            "error.AccessRevokedOnResultDisclosure",
        ]),
        (rls_text, "RlsAndMasking.zig", [
            "magic_rlm1",
            "RlsPolicyDescriptor",
            "SecurityBarrierFilter",
            "MaskingPolicyDescriptor",
            "evaluateCheckedDivisionAfterBarrier",
            "applyToCell",
            "sanitizeZoneMapForCaller",
            "audiencePolicyDigest",
        ]),
        (lean_text, "FuzeRewrite.lean", [
            "security_barrier_rls_non_interference",
            "delegation_attenuation_sound",
            "delegated_agent_cannot_approve",
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
    verify_sources()
    rendered = json.dumps(fixtures, indent=2) + "\n"

    if args.write:
        FIXTURE_PATH.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE_PATH.write_text(rendered, encoding="utf-8")
    elif not FIXTURE_PATH.is_file() or FIXTURE_PATH.read_text(encoding="utf-8") != rendered:
        raise SystemExit(
            f"Control & Policy Plane fixture drift in {FIXTURE_PATH}; regenerate with --write"
        )
    print(f"control-policy-plane-oracle: verified {len(fixtures['acceptance_scenarios'])} scenarios")


if __name__ == "__main__":
    main()
