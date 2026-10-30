const std = @import("std");
const testing = std.testing;
const c = @import("root.zig");
const Access = c.AccessAndIdentity;
const Delegation = c.DelegationAndSecrets;
const ManagedDataflow = c.ManagedDataflow;

test "AccessContext (ACTX1) validation, OIDC/JWKS rotation, and cross-issuer subject collision resistance" {
    const now_ns: i64 = 1_700_000_000 * std.time.ns_per_s;
    const ctx: Access.AccessContext = .{
        .realm_id = 1,
        .actor_principal = 101,
        .actor_kind = .human,
        .subject_principal = 101,
        .subject_kind = .human,
        .login_role = 10,
        .active_role = 10,
        .credential_epoch = 1,
        .policy_epoch = 5,
        .assurance_level = .aal2_multi_factor,
        .authenticated_at_ns = now_ns,
        .verified_attributes = &.{
            .{ .key = "tenant", .value = .{ .utf8 = "acme" } },
            .{ .key = "clearance", .value = .{ .int64 = 3 } },
        },
        .target = .{ .audience = 1000, .target_object = 500, .branch_id = 1 },
    };
    try ctx.validate();
    try testing.expectEqualStrings("acme", ctx.lookupUtf8Attribute("tenant").?);
    try testing.expectEqual(@as(i64, 3), ctx.lookupInt64Attribute("clearance").?);
    const digest1 = try ctx.contextDigest();
    var ctx_diff = ctx;
    ctx_diff.policy_epoch = 6;
    const digest2 = try ctx_diff.contextDigest();
    try testing.expect(!std.mem.eql(u8, &digest1, &digest2));

    // OIDC Issuer Profile & JWKS rotation
    const idp: Access.OidcIssuerProfile = .{
        .issuer_id = 10,
        .realm_id = 1,
        .issuer_uri = "https://idp.acme.example",
        .expected_audiences = &.{"https://transit.acme.example/sql"},
        .jwks_keys = &.{
            .{ .issuer_id = 10, .kid = "key-2026-active", .key_epoch = 2, .state = .active, .expires_at_ns = now_ns + 3600 * std.time.ns_per_s },
            .{ .issuer_id = 10, .kid = "key-2025-retired", .key_epoch = 1, .state = .revoked_or_retired, .expires_at_ns = now_ns + 3600 * std.time.ns_per_s },
        },
    };

    const valid_claims: Access.OidcTokenClaims = .{
        .issuer_uri = "https://idp.acme.example",
        .external_subject = "alice@acme.example",
        .audience = "https://transit.acme.example/sql",
        .kid = "key-2026-active",
        .token_kind = .api_access_token,
        .issued_at_ns = now_ns - 60 * std.time.ns_per_s,
        .not_before_ns = now_ns - 60 * std.time.ns_per_s,
        .expires_at_ns = now_ns + 600 * std.time.ns_per_s,
    };
    try idp.validateToken(valid_claims, now_ns, true);

    // Reject login id_token on API/query endpoints
    var id_token_claims = valid_claims;
    id_token_claims.token_kind = .login_id_token;
    try testing.expectError(error.IdTokenNotPermittedForApiAccess, idp.validateToken(id_token_claims, now_ns, true));

    // Reject wrong audience
    var wrong_aud = valid_claims;
    wrong_aud.audience = "https://other.service.example";
    try testing.expectError(error.InvalidTokenAudience, idp.validateToken(wrong_aud, now_ns, true));

    // Reject retired JWKS kid
    var retired_kid = valid_claims;
    retired_kid.kid = "key-2025-retired";
    try testing.expectError(error.UnknownOrRevokedJwksKey, idp.validateToken(retired_kid, now_ns, true));

    // PrincipalBindingDirectory collision resistance across issuers
    var dir: Access.PrincipalBindingDirectory = .{};
    try dir.bindPrincipal(1, 10, "alice", 101);
    try dir.bindPrincipal(1, 20, "alice", 202); // Same external "sub", different issuer -> distinct PrincipalId
    try testing.expectEqual(@as(u64, 101), try dir.resolvePrincipal(1, 10, "alice"));
    try testing.expectEqual(@as(u64, 202), try dir.resolvePrincipal(1, 20, "alice"));
    // Attempting to bind issuer 20's "alice" onto issuer 10's principal 101 must fail
    try testing.expectError(error.IdentitySubjectCollision, dir.bindPrincipal(1, 20, "alice", 101));
}

test "SCIM 2.0 membership sync non-override of local restrictions and freshness/outage fail-closed guard" {
    const now_ns: i64 = 1_700_000_000 * std.time.ns_per_s;
    var dir: Access.PrincipalBindingDirectory = .{};
    try dir.bindPrincipal(1, 10, "bob", 102);

    const rules = [_]Access.RoleSyncRule{
        .{ .role_id = 50, .external_group_name = "idp_analysts", .allow_external_membership_sync = true, .locally_revoked_principals = &.{999} },
        .{ .role_id = 1, .external_group_name = "idp_admins", .allow_external_membership_sync = false },
    };

    // Valid SCIM sync preserves native local roles
    const sync_ok = try Access.ScimProvisioningEngine.syncMemberships(
        &dir,
        102,
        true,
        &.{"idp_analysts"},
        &rules,
        &.{77},
    );
    try testing.expectEqual(@as(usize, 1), sync_ok.granted_external_count);
    try testing.expectEqual(@as(u64, 50), sync_ok.granted_external_roles[0]);
    try testing.expectEqual(@as(usize, 1), sync_ok.preserved_native_local_count);
    try testing.expectEqual(@as(u64, 77), sync_ok.preserved_native_local_roles[0]);

    // Mapping external group onto local-only role (`allow_external_membership_sync = false`) rejects
    try testing.expectError(
        error.ConflictingManagementSource,
        Access.ScimProvisioningEngine.syncMemberships(&dir, 102, true, &.{"idp_admins"}, &rules, &.{77}),
    );

    // Local restriction hold (`ALTER PRINCIPAL ... DISABLE`) cannot be overridden by SCIM sync
    try dir.setLocalRestrictionHold(102, true);
    try testing.expectError(
        error.LocalRestrictionOverridesExternalSync,
        Access.ScimProvisioningEngine.syncMemberships(&dir, 102, true, &.{"idp_analysts"}, &rules, &.{77}),
    );
    try dir.setLocalRestrictionHold(102, false);

    // Freshness watermark & fail-closed IdP outage guard
    var guard: Access.MembershipFreshnessGuard = .{
        .max_membership_staleness_ms = 60_000,
        .idp_reachable = false,
        .current_policy_epoch = 10,
    };
    var audit_log: Access.AccessAuditLog = .{};

    // Stale external membership (verified 120s ago > 60s max, even though JWT expires in 600s) during IdP outage -> fails closed
    const stale_ext_ctx: Access.AccessContext = .{
        .realm_id = 1,
        .actor_principal = 102,
        .actor_kind = .human,
        .subject_principal = 102,
        .subject_kind = .human,
        .login_role = 50,
        .active_role = 50,
        .credential_epoch = 1,
        .policy_epoch = 10,
        .authenticated_at_ns = now_ns - 120 * std.time.ns_per_s,
        .enterprise_binding = .{
            .issuer_id = 10,
            .external_subject_digest = Access.PrincipalBindingDirectory.subjectDigest(10, "bob"),
            .management_source = .external_iam_scim,
            .membership_verified_at_ns = now_ns - 120 * std.time.ns_per_s,
            .token_expires_at_ns = now_ns + 600 * std.time.ns_per_s,
        },
        .target = .{ .audience = 1000, .target_object = 500, .branch_id = 1 },
    };
    try testing.expectError(
        error.IdentityProviderUnavailable,
        guard.verifyAccessAndFreshness(stale_ext_ctx, now_ns, &audit_log),
    );
    try testing.expectEqual(@as(usize, 1), audit_log.len);
    try testing.expectEqual(Access.PolicyDenialCode.identity_provider_unavailable, audit_log.records[0].denial_code);
    try testing.expect(!audit_log.records[0].containsRawCredentialsOrPayloads());

    // Native local Ed25519 principal succeeds even while external IdP is unreachable
    const native_ctx: Access.AccessContext = .{
        .realm_id = 1,
        .actor_principal = 1,
        .actor_kind = .human,
        .subject_principal = 1,
        .subject_kind = .human,
        .login_role = 1,
        .active_role = 1,
        .credential_epoch = 1,
        .policy_epoch = 10,
        .authenticated_at_ns = now_ns,
        .target = .{ .audience = 1000, .target_object = 500, .branch_id = 1 },
    };
    try guard.verifyAccessAndFreshness(native_ctx, now_ns, &audit_log);

    // Offboarding advances `policy_epoch` and halts mid-stream disclosure
    const new_epoch = try guard.offboardAndAdvanceEpoch(&dir, 102);
    try testing.expectEqual(@as(u64, 11), new_epoch);
    try testing.expectError(error.AccessRevoked, guard.verifyAccessAndFreshness(native_ctx, now_ns, &audit_log));
}

test "Delegation (DLG1) attenuation, human-only approval (APV1) separation of duties, and 8-action branch protection across all adapters" {
    const now_ns: i64 = 1_700_000_000 * std.time.ns_per_s;

    // Cannot mint a delegation hop containing human-only actions (`approve_proposal` or `execute_erasure`)
    try testing.expectError(
        error.CannotDelegateHumanOnlyAction,
        Delegation.exchangeTokenToDelegationHop(1, .{
            .subject_principal = 100,
            .actor_principal = 201,
            .requested_audience = 1000,
            .requested_actions = .{ .select_data = true, .approve_proposal = true },
            .requested_objects = &.{500},
            .requested_branches = &.{ 1, 2 },
            .current_policy_epoch = 10,
            .expires_at_ns = now_ns + 3600 * std.time.ns_per_s,
        }),
    );

    // Valid RFC 8693 token exchange -> Hop 1 (`human 100 -> agent 201`, restricted to NA)
    const hop1 = try Delegation.exchangeTokenToDelegationHop(1, .{
        .subject_principal = 100,
        .actor_principal = 201,
        .requested_audience = 1000,
        .requested_actions = .{ .select_data = true, .propose_branch = true },
        .requested_objects = &.{500},
        .requested_branches = &.{ 1, 2 },
        .requested_regions = &.{"NA"},
        .current_policy_epoch = 10,
        .expires_at_ns = now_ns + 3600 * std.time.ns_per_s,
    });

    const delegated_ctx: Access.AccessContext = .{
        .realm_id = 1,
        .actor_principal = 201,
        .actor_kind = .agent,
        .subject_principal = 100,
        .subject_kind = .human,
        .login_role = 10,
        .active_role = 10,
        .credential_epoch = 1,
        .policy_epoch = 10,
        .authenticated_at_ns = now_ns,
        .has_delegation = true,
        .delegation_depth = 1,
        .target = .{ .audience = 1000, .target_object = 500, .branch_id = 2 },
    };

    const chain: Delegation.DelegationChain = .{ .hops = &.{hop1} };
    const subject_rights: Delegation.DelegationActionMask = .{
        .select_data = true,
        .mutate_data = true,
        .propose_branch = true,
        .approve_proposal = true,
    };

    // Permitted within attenuated scope (`select_data`, object 500, branch 2, region "NA")
    try chain.evaluateAttenuatedAccess(
        delegated_ctx,
        subject_rights,
        &.{ 500, 600 },
        &.{ "NA", "EU" },
        .{ .select_data = true },
        500,
        2,
        "NA",
        10,
        now_ns,
        true,
    );

    // Denied when requesting region "EU" (subject has "EU", but delegation hop attenuated to "NA")
    try testing.expectError(
        error.AccessDenied,
        chain.evaluateAttenuatedAccess(
            delegated_ctx,
            subject_rights,
            &.{ 500, 600 },
            &.{ "NA", "EU" },
            .{ .select_data = true },
            500,
            2,
            "EU",
            10,
            now_ns,
            true,
        ),
    );

    // Denied when agent attempts to borrow human approval power
    try testing.expectError(
        error.DelegatedAgentCannotApprove,
        chain.evaluateAttenuatedAccess(
            delegated_ctx,
            subject_rights,
            &.{500},
            &.{"NA"},
            .{ .approve_proposal = true },
            500,
            2,
            "NA",
            10,
            now_ns,
            true,
        ),
    );

    // Protected destination branch rejects direct writes across ALL 9 adapters
    const head_digest: [32]u8 = @splat(0xAA);
    const cand_digest: [32]u8 = @splat(0xBB);
    const human_reviewer_ctx: Access.AccessContext = .{
        .realm_id = 1,
        .actor_principal = 105,
        .actor_kind = .human,
        .subject_principal = 105,
        .subject_kind = .human,
        .login_role = 10,
        .active_role = 10,
        .credential_epoch = 1,
        .policy_epoch = 10,
        .assurance_level = .aal2_multi_factor,
        .authenticated_at_ns = now_ns,
        .step_up_verified_at_ns = now_ns,
        .target = .{ .audience = 1000, .target_object = 500, .branch_id = 1 },
    };
    const all_branch_actions = [_]Delegation.BranchCollaborationAction{
        .inspect, .create_branch, .edit, .share, .propose, .approve, .merge, .external_activation,
    };
    const adapters = [_]Delegation.AdapterSurface{
        .sql_session,         .direct_table_v1,    .direct_stream_v1,
        .direct_queue_v1,     .document_partition, .kv_partition,
        .arrow_flight_do_put, .sdk_client,         .mcp_tool,
    };
    for (adapters) |surface| {
        try testing.expectError(
            error.ProtectedBranchDirectWriteDenied,
            Delegation.authorizeBranchOperation(
                .protected_destination,
                surface,
                .edit,
                human_reviewer_ctx,
                &all_branch_actions,
                10,
                now_ns,
                null,
                head_digest,
                cand_digest,
            ),
        );
    }

    // `branching_only` rejects all merges
    try testing.expectError(
        error.InstallationProhibitsMerge,
        Delegation.authorizeBranchOperation(
            .branching_only,
            .sql_session,
            .merge,
            human_reviewer_ctx,
            &all_branch_actions,
            10,
            now_ns,
            null,
            head_digest,
            cand_digest,
        ),
    );

    // Self-approval (proposer == approver) fails Separation of Duties
    const self_approval: Delegation.ApprovalAttestation = .{
        .realm_id = 1,
        .approver_principal = 105,
        .approver_role = 10,
        .proposer_principal = 105,
        .policy_epoch = 10,
        .step_up_verified_at_ns = now_ns,
        .target_object = 500,
        .target_branch_id = 1,
        .expected_target_head_digest = head_digest,
        .candidate_manifest_digest = cand_digest,
    };
    try testing.expectError(
        error.SeparationOfDutiesViolation,
        Delegation.authorizeBranchOperation(
            .protected_destination,
            .sql_session,
            .merge,
            human_reviewer_ctx,
            &all_branch_actions,
            10,
            now_ns,
            self_approval,
            head_digest,
            cand_digest,
        ),
    );

    // Distinct human reviewer (105 != proposer 100) with AAL2 step-up succeeds on reviewed merge
    var valid_approval = self_approval;
    valid_approval.proposer_principal = 100;
    try Delegation.authorizeBranchOperation(
        .protected_destination,
        .sql_session,
        .merge,
        human_reviewer_ctx,
        &all_branch_actions,
        10,
        now_ns,
        valid_approval,
        head_digest,
        cand_digest,
    );
}

test "SecretManager (SEC1) dual authorization and OAuth 2.1 + PKCE S256 challenge-response dataflow state machine" {
    const now_ns: i64 = 1_700_000_000 * std.time.ns_per_s;

    // 1. Plaintext secret literal in SQL declaration is rejected
    const bad_plaintext_secret: Delegation.SecretDeclaration = .{
        .secret_id = 1,
        .name = "bad_inline_s3",
        .kind = .s3,
        .provider = .kms_envelope,
        .provider_ref = "AKIA_RAW_PLAINTEXT",
        .has_unsealed_plaintext_literal = true,
        .scope_prefixes = &.{"s3://bucket/"},
    };
    try testing.expectError(error.PlaintextSecretLiteralForbidden, bad_plaintext_secret.validateForCatalog());

    // 2. OAuth2 secret starts in `.pending_challenge` while dependent ManagedDataflow is `Suspended (credential_pending)`
    var github_mcp_secret: Delegation.SecretDeclaration = .{
        .secret_id = 42,
        .name = "github_mcp_oauth",
        .kind = .oauth2_bearer,
        .provider = .oauth2_authorization_code_pkce,
        .provider_ref = "vault://secrets/github/client_secret",
        .scope_prefixes = &.{"https://api.githubcopilot.com/mcp/"},
        .expected_audience = "https://api.githubcopilot.com/mcp/",
        .rotation_epoch = 0,
        .lease_state = .pending_challenge,
        .usage_granted_principals = &.{100},
        .policy_epoch = 10,
    };
    try github_mcp_secret.validateForCatalog();
    const redacted = github_mcp_secret.inspectRedacted();
    try testing.expectEqualStrings("REDACTED", redacted.secret_value_display);

    var df = try ManagedDataflow.DataflowRuntime.publish(.{
        .catalog_id = 1,
        .dataflow_id = 700,
        .name = "mcp_issue_sync_flow",
        .definition_id = 1,
        .kind = .dataflow,
        .sources = &.{.{ .object_id = 10, .definition_id = 1 }},
    });
    try df.authorize(10);
    df.state = .suspended;
    df.blocked_reason = .credential_pending;

    // 3. RFC 7636 Appendix B test vector for PKCE `S256`
    const rfc7636_verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
    const expected_s256 = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM";
    const computed_s256 = try Delegation.OauthChallengeGame.computePkceS256Challenge(rfc7636_verifier);
    try testing.expectEqualStrings(expected_s256, &computed_s256);

    const state_digest: [32]u8 = @splat(0x5A);
    const challenges = [_]Delegation.OauthChallengeRecord{
        .{
            .challenge_id = 9001,
            .secret_id = 42,
            .principal_id = 100,
            .state_digest = state_digest,
            .pkce_code_challenge_s256 = computed_s256,
            .issued_at_ns = now_ns - 30 * std.time.ns_per_s,
            .expires_at_ns = now_ns + 300 * std.time.ns_per_s,
        },
    };

    var game: Delegation.OauthChallengeGame = .{};

    // Wrong PKCE verifier rejects without consuming the challenge
    try testing.expectError(
        error.OauthPkceVerificationFailed,
        game.evaluateCallbackTurn(&challenges, .{
            .callback_id = 1,
            .state_digest = state_digest,
            .authorization_code_handle = 555,
            .pkce_code_verifier = "wrong_verifier_string_that_is_at_least_43_chars_long_12345",
            .received_at_ns = now_ns,
        }),
    );

    // Valid callback turn verifies PKCE S256 and emits a TokenExchangeOutboxIntent
    const intent = try game.evaluateCallbackTurn(&challenges, .{
        .callback_id = 2,
        .state_digest = state_digest,
        .authorization_code_handle = 555,
        .pkce_code_verifier = rfc7636_verifier,
        .received_at_ns = now_ns,
    });
    try testing.expectEqual(@as(u64, 42), intent.secret_id);
    try testing.expectEqual(@as(u64, 9001), intent.challenge_id);

    // Replaying the same callback/challenge is deterministically rejected by anti-replay (`NOT EXISTS`)
    try testing.expectError(
        error.OauthChallengeReplayDetected,
        game.evaluateCallbackTurn(&challenges, .{
            .callback_id = 3,
            .state_digest = state_digest,
            .authorization_code_handle = 555,
            .pkce_code_verifier = rfc7636_verifier,
            .received_at_ns = now_ns + 1,
        }),
    );

    // 4. Connector seals token lease (`rotation_epoch = 1`), schedules proactive refresh, and wakes `df` to `.active`
    const refresh_entry = try Delegation.OauthChallengeGame.sealTokenLeaseAndWakeDataflow(
        &github_mcp_secret,
        now_ns + 3600 * std.time.ns_per_s,
        300 * std.time.ns_per_s,
        &df,
    );
    try testing.expectEqual(@as(u64, 1), github_mcp_secret.rotation_epoch);
    try testing.expectEqual(Delegation.SecretLeaseState.active_lease, github_mcp_secret.lease_state);
    try testing.expectEqual(ManagedDataflow.LifecycleState.active, df.state);
    try testing.expectEqual(ManagedDataflow.BlockedReason.none, df.blocked_reason);
    try testing.expectEqual(now_ns + 3300 * std.time.ns_per_s, refresh_entry.visible_at_ns);

    // 5. Dual authorization (`USAGE ON SECRET` + `SCOPE` + `AUDIENCE` match)
    const authorized_caller: Access.AccessContext = .{
        .realm_id = 1,
        .actor_principal = 100,
        .actor_kind = .human,
        .subject_principal = 100,
        .subject_kind = .human,
        .login_role = 10,
        .active_role = 10,
        .credential_epoch = 1,
        .policy_epoch = 10,
        .authenticated_at_ns = now_ns,
        .target = .{ .audience = 1000, .target_object = 42, .branch_id = 1 },
    };
    const handle = try github_mcp_secret.resolveForDestination(
        authorized_caller,
        "https://api.githubcopilot.com/mcp/v1/tools",
        "https://api.githubcopilot.com/mcp/",
        true,
        10,
        now_ns,
    );
    try testing.expectEqual(@as(u64, 1), handle.rotation_epoch);

    // Mismatched URI scope prefix rejects (`error.SecretScopeMismatch`)
    try testing.expectError(
        error.SecretScopeMismatch,
        github_mcp_secret.resolveForDestination(
            authorized_caller,
            "https://evil.example.com/mcp/",
            "https://api.githubcopilot.com/mcp/",
            true,
            10,
            now_ns,
        ),
    );

    // Caller without `USAGE ON SECRET` rejects (`error.MissingSecretUsagePrivilege`) even when URI matches `SCOPE`
    var unauthorized_caller = authorized_caller;
    unauthorized_caller.actor_principal = 999;
    unauthorized_caller.subject_principal = 999;
    try testing.expectError(
        error.MissingSecretUsagePrivilege,
        github_mcp_secret.resolveForDestination(
            unauthorized_caller,
            "https://api.githubcopilot.com/mcp/v1/tools",
            "https://api.githubcopilot.com/mcp/",
            true,
            10,
            now_ns,
        ),
    );
}

test "Security-barrier RLS, Geospatial RLS, Dynamic Column Masking (RLM1), GDPR crypto-shredding/purge (ERS1), WLM (WLM1), and EXPLAIN POLICY" {
    const fuze = c.fuze;
    const v = fuze.Types.Values;
    const Rls = fuze.RlsAndMasking;
    const Erasure = c.ErasureAndWorkload;
    const now_ns: i64 = 1_700_000_000 * std.time.ns_per_s;

    // 1. Security-barrier RLS + 2D Geospatial RLS (`ST_CoveredBy`)
    const rls_policies = [_]Rls.RlsPolicyDescriptor{
        .{
            .policy_id = 1,
            .name = "tenant_isolation",
            .table_object = 500,
            .mode = .permissive,
            .using_predicate = .{ .column_equals_utf8 = .{ .column_idx = 0, .expected = "acme" } },
        },
        .{
            .policy_id = 2,
            .name = "na_geofence",
            .table_object = 500,
            .mode = .restrictive,
            .using_predicate = .{
                .spatial_covered_by_bbox2d = .{
                    .x_col_idx = 2,
                    .y_col_idx = 3,
                    .min_x = -130.0,
                    .min_y = 24.0,
                    .max_x = -65.0,
                    .max_y = 50.0,
                },
            },
        },
    };
    const barrier: Rls.SecurityBarrierFilter = .{
        .table_rls_enabled = true,
        .policies = &rls_policies,
    };

    // Row 0: authorized ("acme", divisor = 5, lon = -122.3, lat = 47.6)
    const row_ok = [_]v.Cell{
        .{ .value = .{ .atom = .{ .bytes = "acme" } } },
        .{ .value = .{ .atom = .{ .signed = 5 } } },
        .{ .value = .{ .atom = .{ .float = -122.3 } } },
        .{ .value = .{ .atom = .{ .float = 47.6 } } },
    };
    // Row 1: unauthorized tenant ("other", divisor = 0 -> would divide by zero if evaluated before barrier!)
    const row_unauth_div_zero = [_]v.Cell{
        .{ .value = .{ .atom = .{ .bytes = "other" } } },
        .{ .value = .{ .atom = .{ .signed = 0 } } },
        .{ .value = .{ .atom = .{ .float = -122.3 } } },
        .{ .value = .{ .atom = .{ .float = 47.6 } } },
    };
    // Row 2: same tenant "acme", but outside NA geofence (lon = 2.35 Paris, divisor = 0)
    const row_outside_geofence = [_]v.Cell{
        .{ .value = .{ .atom = .{ .bytes = "acme" } } },
        .{ .value = .{ .atom = .{ .signed = 0 } } },
        .{ .value = .{ .atom = .{ .float = 2.35 } } },
        .{ .value = .{ .atom = .{ .float = 48.85 } } },
    };

    const batch_rows = [_][]const v.Cell{ &row_ok, &row_unauth_div_zero, &row_outside_geofence };
    var quotients: [4]i64 = @splat(0);
    // Evaluating `100 / divisor` after SecurityBarrierFilter succeeds with 1 row (`100 / 5 = 20`) and ZERO side-channel error leaks!
    const out_count = try barrier.evaluateCheckedDivisionAfterBarrier(&batch_rows, 100, 1, &quotients);
    try testing.expectEqual(@as(usize, 1), out_count);
    try testing.expectEqual(@as(i64, 20), quotients[0]);

    // Zone-map stats are sanitized under active RLS barrier
    const raw_zm: Rls.ZoneMapSummary = .{
        .row_count = 3,
        .min_int64 = 0,
        .max_int64 = 999_999,
        .bbox2d_min_x = -122.3,
        .bbox2d_max_x = 2.35,
    };
    const safe_zm = barrier.sanitizeZoneMapForCaller(raw_zm);
    try testing.expect(safe_zm.redacted_by_rls_barrier);
    try testing.expectEqual(@as(i64, 0), safe_zm.max_int64);

    // 2. Dynamic Column Masking & GermanString prefix scrubbing
    const ssn_mask: Rls.MaskingPolicyDescriptor = .{
        .policy_id = 10,
        .name = "ssn_partial_mask",
        .column_idx = 0,
        .transform_for_restricted = .{ .partial_string_mask = .{ .visible_suffix_len = 4 } },
        .unmasked_roles = &.{1}, // Only admin role 1 sees unmasked SSN
    };
    var scratch: [16]u8 = @splat(0);
    const ssn_cell: v.Cell = .{ .value = .{ .atom = .{ .bytes = "123-45-6789" } } };
    const masked_res = ssn_mask.applyToCell(50, ssn_cell, &scratch); // Analyst role 50
    try testing.expectEqualStrings("***-**-6789", masked_res.cell.value.atom.bytes);
    // 4-byte GermanString inline sort prefix is scrubbed to "***-", NOT "123-"!
    try testing.expectEqualStrings("***-", &masked_res.german_prefix);

    const unmasked_res = ssn_mask.applyToCell(1, ssn_cell, &scratch); // Admin role 1
    try testing.expectEqualStrings("123-45-6789", unmasked_res.cell.value.atom.bytes);

    // Audience policy digests isolate role 1 (unmasked) vs role 50 (masked) in ReadCache
    const masking_policies = [_]Rls.MaskingPolicyDescriptor{ssn_mask};
    const aud_admin = Rls.audiencePolicyDigest(500, 1, 10, &rls_policies, &masking_policies);
    const aud_analyst = Rls.audiencePolicyDigest(500, 50, 10, &rls_policies, &masking_policies);
    try testing.expect(!std.mem.eql(u8, &aud_admin, &aud_analyst));

    // 3. Right-to-Erasure (GDPR/CCPA) crypto-shredding & cross-branch purge receipts (`ERS1`)
    var key_reg: Erasure.SubjectEnvelopeKeyRegistry = .{};
    const salt: [32]u8 = @splat(0x42);
    const subj_commitment = Erasure.SubjectEnvelopeKeyRegistry.computeBlindedSubjectCommitment(1, salt, "user-pii-subject-42");
    try key_reg.registerSubjectKey(1, 500, subj_commitment, 901, 902);

    const pii_cell: v.Cell = .{ .value = .{ .atom = .{ .bytes = "sensitive-eu-record" } } };
    try testing.expect(key_reg.projectSubjectEncryptedCell(1, 500, subj_commitment, pii_cell) == .value);

    const head_digest: [32]u8 = @splat(0x11);
    const cand_digest: [32]u8 = @splat(0x22);
    const dpo_ctx: Access.AccessContext = .{
        .realm_id = 1,
        .actor_principal = 105,
        .actor_kind = .human,
        .subject_principal = 105,
        .subject_kind = .human,
        .login_role = 1,
        .active_role = 1,
        .credential_epoch = 1,
        .policy_epoch = 10,
        .assurance_level = .aal3_hardware_cryptographic,
        .authenticated_at_ns = now_ns,
        .step_up_verified_at_ns = now_ns,
        .target = .{ .audience = 1000, .target_object = 500, .branch_id = 1 },
    };
    const erasure_approval: Delegation.ApprovalAttestation = .{
        .realm_id = 1,
        .approver_principal = 105,
        .approver_role = 1,
        .proposer_principal = 100,
        .policy_epoch = 10,
        .step_up_verified_at_ns = now_ns,
        .target_object = 500,
        .target_branch_id = 1,
        .expected_target_head_digest = head_digest,
        .candidate_manifest_digest = cand_digest,
    };
    var active_dek_buf = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const post_shred_epoch = try key_reg.shredSubjectKeysAndZeroBuffer(
        dpo_ctx,
        erasure_approval,
        10,
        now_ns,
        head_digest,
        cand_digest,
        subj_commitment,
        &active_dek_buf,
    );
    try testing.expectEqual(@as(u64, 11), post_shred_epoch);
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0 }, &active_dek_buf);
    // Immediate reads project `.missing` (erasure tombstone)
    try testing.expect(key_reg.projectSubjectEncryptedCell(1, 500, subj_commitment, pii_cell) == .missing);

    // Cross-branch `.tseg` purge compaction across `main` (branch 1) and `feature_x` (branch 2)
    const branch_specs = [_]Erasure.BranchSegmentPurgeSpec{
        .{ .branch_id = 1, .source_segment_id = 10, .replacement_segment_id = 11, .subject_row_count = 3, .unrelated_row_count = 97 },
        .{ .branch_id = 2, .source_segment_id = 20, .replacement_segment_id = 21, .subject_row_count = 2, .unrelated_row_count = 48 },
    };
    var lineage_edges: [2]Erasure.CompactionLineageEdge = undefined;
    const receipt = try key_reg.executeCrossBranchPurgeCompaction(
        1,
        1,
        500,
        subj_commitment,
        &branch_specs,
        5000,
        post_shred_epoch,
        &lineage_edges,
    );
    try testing.expectEqual(@as(usize, 2), receipt.affected_branch_count);
    try testing.expectEqual(@as(usize, 5), receipt.total_erased_rows);
    try testing.expect(!receipt.containsRawSubjectPii());
    try testing.expectEqual(@as(u64, 11), lineage_edges[0].replacement_segment_id);

    // 4. Hierarchical Workload Management (`WLM1`) & non-preemptible control reserve
    var agent_wlm: Erasure.WorkloadGroupController = .{
        .descriptor = .{
            .group_id = 5,
            .name = "mcp_agent_burst_group",
            .kind = .agent_burst,
            .max_concurrent_queries = 2,
            .soft_memory_spill_bytes = 1024,
            .hard_memory_limit_bytes = 4096,
            .max_cpu_micros_per_query = 10_000,
        },
    };
    const agent_ctx: Access.AccessContext = .{
        .realm_id = 1,
        .actor_principal = 201,
        .actor_kind = .agent,
        .subject_principal = 100,
        .subject_kind = .human,
        .login_role = 50,
        .active_role = 50,
        .credential_epoch = 1,
        .policy_epoch = 11,
        .authenticated_at_ns = now_ns,
        .has_delegation = true,
        .delegation_depth = 1,
        .target = .{ .audience = 1000, .target_object = 500, .branch_id = 1 },
    };
    // Delegated agent attempting to escalate into `oltp_critical` is rejected
    try testing.expectError(error.WorkloadGroupEscalationDenied, agent_wlm.classifyAndAdmit(agent_ctx, .oltp_critical));
    const cache_hint = try agent_wlm.classifyAndAdmit(agent_ctx, .agent_burst);
    try testing.expectEqual(Erasure.CachePlacementHint.scan_transient, cache_hint);

    // Soft memory limit triggers Tier 2 NVMe spill; hard limit rejects
    try testing.expectEqual(
        Erasure.MorselExecutionOutcome.spill_to_nvme_tier2,
        try agent_wlm.chargeMorselAtBoundary(2048, 1000, false, false),
    );
    try testing.expectError(
        error.WorkloadMemoryQuotaExceeded,
        agent_wlm.chargeMorselAtBoundary(8192, 1000, false, false),
    );

    // 5. Zero-work `EXPLAIN POLICY` & post-revocation lost-reply operation inspection
    const explain_report = try Erasure.explainPolicyForStatement(
        agent_ctx,
        .protected_destination,
        &rls_policies,
        &masking_policies,
        agent_wlm.descriptor,
        false,
        .protected_branch_direct_write_denied,
    );
    try testing.expectEqual(@as(usize, 2), explain_report.active_rls_policy_count);
    try testing.expectEqual(@as(usize, 1), explain_report.active_masking_policy_count);
    try testing.expectEqual(Access.PolicyDenialCode.protected_branch_direct_write_denied, explain_report.denial_code);

    const op_receipt: Erasure.AcceptedOperationReceipt = .{
        .operation_id = 777,
        .owner_principal = 100,
        .accepted_at_policy_epoch = 10,
        .accepted_at_lsn = 4500,
        .committed = true,
        .disclosed_row_count = 25,
    };
    // Metadata inspection of original accepted operation succeeds after read-grant revocation, but row disclosure rejects!
    const status_only = try Erasure.inspectOperationAfterLostReply(op_receipt, 100, false, false);
    try testing.expect(status_only.committed);
    try testing.expectEqual(@as(usize, 0), status_only.disclosed_row_count);
    try testing.expectError(
        error.AccessRevokedOnResultDisclosure,
        Erasure.inspectOperationAfterLostReply(op_receipt, 100, false, true),
    );
}
