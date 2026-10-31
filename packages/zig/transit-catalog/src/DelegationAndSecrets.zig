//! Bounded delegation (`DELEGATION_V1` / `DLG1`, magic `0x444C4731`), strict
//! multi-hop attenuation, human-only intent-bound `ApprovalAttestation` (`APV1`,
//! magic `0x41505631`) with separation of duties, RFC 8693 / MCP token exchange,
//! unified 8-action branch and publication policy (`branching_only` and
//! `protected_destination` across all adapters), declarative `SECRET` catalog
//! management (`SECRET_MANAGER_V1` / `SEC1`, magic `0x53454331`), and the
//! deterministic OAuth 2.1 + PKCE `S256` challenge-response and lease-refresh
//! dataflow state machine (`Steps 4–5`, `D4`–`D5`, `P3`–`P4`).
const std = @import("std");
const c = @import("root.zig");
const Access = @import("AccessAndIdentity.zig");
const ManagedDataflow = c.ManagedDataflow;

pub const magic_dlg1: u32 = 0x444C4731; // "DLG1"
pub const magic_apv1: u32 = 0x41505631; // "APV1"
pub const magic_sec1: u32 = 0x53454331; // "SEC1"

pub const max_delegation_depth: u8 = 4;
pub const max_consumed_challenges: usize = 64;
pub const max_outbox_intents: usize = 32;

pub const DelegationActionMask = packed struct(u16) {
    select_data: bool = false,
    mutate_data: bool = false,
    inspect_branch: bool = false,
    create_branch: bool = false,
    edit_branch: bool = false,
    share_branch: bool = false,
    propose_branch: bool = false,
    approve_proposal: bool = false, // human_only
    merge_branch: bool = false,
    external_activation: bool = false,
    execute_erasure: bool = false, // human_only
    use_secret: bool = false,
    _reserved: u4 = 0,

    pub fn containsHumanOnlyAction(self: DelegationActionMask) bool {
        return self.approve_proposal or self.execute_erasure;
    }

    pub fn intersect(a: DelegationActionMask, b: DelegationActionMask) DelegationActionMask {
        const a_bits: u16 = @bitCast(a);
        const b_bits: u16 = @bitCast(b);
        return @bitCast(a_bits & b_bits);
    }

    pub fn hasAll(self: DelegationActionMask, req: DelegationActionMask) bool {
        const self_bits: u16 = @bitCast(self);
        const req_bits: u16 = @bitCast(req);
        return (self_bits & req_bits) == req_bits;
    }
};

pub const DelegationHop = struct {
    magic: u32 = magic_dlg1,
    delegation_id: u64,
    hop_index: u8,
    subject_principal: u64,
    actor_principal: u64,
    audience: u64,
    allowed_actions: DelegationActionMask,
    allowed_objects: []const u64,
    allowed_branches: []const u64,
    allowed_regions: []const []const u8 = &.{},
    issued_at_policy_epoch: u64,
    expires_at_policy_epoch: u64,
    expires_at_ns: i64,
    purpose_digest: [32]u8 = @splat(0),

    pub fn validateForCreation(self: DelegationHop) !void {
        if (self.magic != magic_dlg1 or self.delegation_id == 0) return error.InvalidDelegationTicket;
        if (self.hop_index == 0 or self.hop_index > max_delegation_depth) return error.DelegationDepthExceeded;
        if (self.subject_principal == 0 or self.actor_principal == 0 or self.subject_principal == self.actor_principal) {
            return error.InvalidDelegationPrincipal;
        }
        if (self.allowed_actions.containsHumanOnlyAction()) {
            return error.CannotDelegateHumanOnlyAction;
        }
        if (self.issued_at_policy_epoch == 0 or self.expires_at_policy_epoch < self.issued_at_policy_epoch) {
            return error.InvalidDelegationEpoch;
        }
    }
};

pub const DelegationChain = struct {
    hops: []const DelegationHop,
    max_depth: u8 = max_delegation_depth,

    /// Evaluates strict multi-hop delegation attenuation (`Step 4`, `D4`, `A6`):
    /// Effective permissions equal the intersection of the represented subject's
    /// current rights at `current_policy_epoch`, every hop's scope, and the immediate
    /// actor's execution eligibility.
    pub fn evaluateAttenuatedAccess(
        self: DelegationChain,
        ctx: Access.AccessContext,
        subject_current_actions: DelegationActionMask,
        subject_allowed_objects: []const u64,
        subject_allowed_regions: []const []const u8,
        required_actions: DelegationActionMask,
        target_object: u64,
        target_branch_id: u64,
        requested_region: ?[]const u8,
        current_policy_epoch: u64,
        now_ns: i64,
        immediate_actor_enabled: bool,
    ) !void {
        if (required_actions.containsHumanOnlyAction()) {
            return error.DelegatedAgentCannotApprove;
        }
        if (self.hops.len == 0) return error.InvalidDelegationTicket;
        if (self.hops.len > self.max_depth or self.hops.len > max_delegation_depth) {
            return error.DelegationDepthExceeded;
        }
        if (!immediate_actor_enabled) return error.ActorExecutionDisabled;

        // Represented subject must currently hold the requested actions, object, and region at `current_policy_epoch`.
        if (!subject_current_actions.hasAll(required_actions)) return error.AccessDenied;
        if (std.mem.indexOfScalar(u64, subject_allowed_objects, target_object) == null) return error.AccessDenied;
        if (requested_region) |req_reg| {
            if (!containsString(subject_allowed_regions, req_reg)) return error.AccessDenied;
        }

        // Verify chain linkage from `ctx.subject_principal` -> ... -> `ctx.actor_principal`.
        if (self.hops[0].subject_principal != ctx.subject_principal) {
            return error.InvalidDelegationPrincipal;
        }
        if (self.hops[self.hops.len - 1].actor_principal != ctx.actor_principal) {
            return error.InvalidDelegationPrincipal;
        }

        var effective_actions = subject_current_actions;
        for (self.hops, 0..) |hop, i| {
            try hop.validateForCreation();
            if (hop.hop_index != i + 1) return error.InvalidDelegationHopOrder;
            if (i > 0 and hop.subject_principal != self.hops[i - 1].actor_principal) {
                return error.InvalidDelegationPrincipal;
            }
            if (hop.audience != ctx.target.audience) return error.InvalidTokenAudience;
            if (current_policy_epoch < hop.issued_at_policy_epoch or current_policy_epoch > hop.expires_at_policy_epoch) {
                return error.AccessRevoked;
            }
            if (now_ns >= hop.expires_at_ns) return error.ExpiredCredential;

            effective_actions = DelegationActionMask.intersect(effective_actions, hop.allowed_actions);
            if (!effective_actions.hasAll(required_actions)) return error.AccessDenied;
            if (std.mem.indexOfScalar(u64, hop.allowed_objects, target_object) == null) return error.AccessDenied;
            if (std.mem.indexOfScalar(u64, hop.allowed_branches, target_branch_id) == null) return error.AccessDenied;
            if (requested_region) |req_reg| {
                if (hop.allowed_regions.len > 0 and !containsString(hop.allowed_regions, req_reg)) {
                    return error.AccessDenied;
                }
            }
        }
    }
};

/// RFC 8693 OAuth 2.0 Token Exchange (`urn:ietf:params:oauth:grant-type:token-exchange`)
/// and MCP Enterprise-Managed Authorization adapter (`Step 4`, `D4`).
pub const Rfc8693TokenExchangeRequest = struct {
    grant_type: []const u8 = "urn:ietf:params:oauth:grant-type:token-exchange",
    subject_principal: u64,
    actor_principal: u64,
    requested_audience: u64,
    requested_actions: DelegationActionMask,
    requested_objects: []const u64,
    requested_branches: []const u64,
    requested_regions: []const []const u8 = &.{},
    current_policy_epoch: u64,
    ttl_epochs: u64 = 5,
    expires_at_ns: i64,
};

pub fn exchangeTokenToDelegationHop(
    delegation_id: u64,
    req: Rfc8693TokenExchangeRequest,
) !DelegationHop {
    if (!std.mem.eql(u8, req.grant_type, "urn:ietf:params:oauth:grant-type:token-exchange")) {
        return error.UnsupportedTokenExchangeGrantType;
    }
    const hop: DelegationHop = .{
        .delegation_id = delegation_id,
        .hop_index = 1,
        .subject_principal = req.subject_principal,
        .actor_principal = req.actor_principal,
        .audience = req.requested_audience,
        .allowed_actions = req.requested_actions,
        .allowed_objects = req.requested_objects,
        .allowed_branches = req.requested_branches,
        .allowed_regions = req.requested_regions,
        .issued_at_policy_epoch = req.current_policy_epoch,
        .expires_at_policy_epoch = req.current_policy_epoch + req.ttl_epochs,
        .expires_at_ns = req.expires_at_ns,
    };
    try hop.validateForCreation();
    return hop;
}

/// Intent-bound human-only step-up approval attestation (`APV1`, `Step 4`, `D4`).
pub const ApprovalAttestation = struct {
    magic: u32 = magic_apv1,
    realm_id: u64,
    approver_principal: u64,
    approver_role: u64,
    proposer_principal: u64,
    require_distinct_approver: bool = true,
    policy_epoch: u64,
    step_up_verified_at_ns: i64,
    max_step_up_age_ns: i64 = 15 * 60 * std.time.ns_per_s,
    target_object: u64,
    target_branch_id: u64,
    expected_target_head_digest: [32]u8,
    candidate_manifest_digest: [32]u8,

    pub fn verifyHumanApproval(
        self: ApprovalAttestation,
        approver_ctx: Access.AccessContext,
        current_policy_epoch: u64,
        now_ns: i64,
        actual_target_head_digest: [32]u8,
        actual_candidate_digest: [32]u8,
    ) !void {
        if (self.magic != magic_apv1) return error.InvalidApprovalAttestation;
        try approver_ctx.validate();

        // Delegated agents or non-human actors can NEVER exercise approval authority.
        if (approver_ctx.has_delegation or
            approver_ctx.actor_principal != approver_ctx.subject_principal or
            approver_ctx.actor_kind != .human or
            approver_ctx.subject_kind != .human)
        {
            return error.DelegatedAgentCannotApprove;
        }
        if (approver_ctx.actor_principal != self.approver_principal) {
            return error.ApprovalPrincipalMismatch;
        }
        if (!approver_ctx.assurance_level.isHumanMultiFactor()) {
            return error.StepUpAuthenticationRequired;
        }
        if (now_ns < self.step_up_verified_at_ns or (now_ns - self.step_up_verified_at_ns) > self.max_step_up_age_ns) {
            return error.StepUpAuthenticationExpired;
        }
        if (self.require_distinct_approver and self.approver_principal == self.proposer_principal) {
            return error.SeparationOfDutiesViolation;
        }
        if (self.policy_epoch != current_policy_epoch or approver_ctx.policy_epoch != current_policy_epoch) {
            return error.StaleApprovalPolicyEpoch;
        }
        if (!std.mem.eql(u8, &self.expected_target_head_digest, &actual_target_head_digest)) {
            return error.ApprovalTargetHeadMoved;
        }
        if (!std.mem.eql(u8, &self.candidate_manifest_digest, &actual_candidate_digest)) {
            return error.ApprovalCandidateDigestMismatch;
        }
    }
};

/// Unified 8-action branch and collaboration model (`Step 5`, `D5`).
pub const BranchCollaborationAction = enum(u8) {
    inspect = 1,
    create_branch = 2,
    edit = 3,
    share = 4,
    propose = 5,
    approve = 6,
    merge = 7,
    external_activation = 8,
};

pub const BranchPolicyProfile = enum(u8) {
    standard_writable = 1,
    branching_only = 2, // Prohibits all merges across the installation/branch
    protected_destination = 3, // Prohibits all direct writes across all adapters; requires reviewed merge + APV1
};

pub const AdapterSurface = enum(u8) {
    sql_session = 1,
    direct_table_v1 = 2,
    direct_stream_v1 = 3,
    direct_queue_v1 = 4,
    document_partition = 5,
    kv_partition = 6,
    arrow_flight_do_put = 7,
    sdk_client = 8,
    mcp_tool = 9,
};

pub fn authorizeBranchOperation(
    profile: BranchPolicyProfile,
    surface: AdapterSurface,
    action: BranchCollaborationAction,
    ctx: Access.AccessContext,
    granted_actions: []const BranchCollaborationAction,
    current_policy_epoch: u64,
    now_ns: i64,
    approval: ?ApprovalAttestation,
    target_head_digest: [32]u8,
    candidate_digest: [32]u8,
) !void {
    _ = surface; // Policy applies identically across all 9 adapter surfaces with zero bypasses.
    try ctx.validate();
    if (ctx.policy_epoch != current_policy_epoch) return error.AccessRevoked;
    if (std.mem.indexOfScalar(BranchCollaborationAction, granted_actions, action) == null) {
        return error.BranchPermissionDenied;
    }

    switch (action) {
        .edit => {
            if (profile == .protected_destination or profile == .branching_only) {
                return error.ProtectedBranchDirectWriteDenied;
            }
        },
        .merge => {
            if (profile == .branching_only) {
                return error.InstallationProhibitsMerge;
            }
            if (profile == .protected_destination) {
                const att = approval orelse return error.ProtectedDestinationRequiresApproval;
                try att.verifyHumanApproval(ctx, current_policy_epoch, now_ns, target_head_digest, candidate_digest);
            }
        },
        .approve => {
            const att = approval orelse return error.MissingApprovalAttestation;
            try att.verifyHumanApproval(ctx, current_policy_epoch, now_ns, target_head_digest, candidate_digest);
        },
        .external_activation => {
            if (ctx.has_delegation) return error.DelegatedExternalActivationDenied;
        },
        else => {},
    }
}

/// Declarative SQL `SECRET` catalog (`SECRET_MANAGER_V1` / `SEC1`, `D4`, `P3`).
pub const SecretKind = enum(u8) {
    s3 = 1,
    gcs = 2,
    r2 = 3,
    http_bearer = 4,
    oauth2_bearer = 5,
    postgres = 6,
    kms_key_ref = 7,
    webhook_hmac = 8,
};

pub const SecretProvider = enum(u8) {
    kms_envelope = 1,
    vault_kv = 2,
    workload_identity = 3,
    env_ref = 4,
    oauth2_authorization_code_pkce = 5,
    oauth2_client_credentials = 6,
    rfc8693_token_exchange = 7,
};

pub const TlsPolicy = enum(u8) {
    strict_verified = 1,
    mutual_tls_pinned = 2,
};

pub const SecretLeaseState = enum(u8) {
    pending_challenge = 1,
    active_lease = 2,
    refresh_due = 3,
    expired = 4,
    revoked = 5,
};

pub const SecretDeclaration = struct {
    magic: u32 = magic_sec1,
    secret_id: u64,
    name: []const u8,
    kind: SecretKind,
    provider: SecretProvider,
    provider_ref: []const u8,
    has_unsealed_plaintext_literal: bool = false,
    scope_prefixes: []const []const u8,
    expected_audience: ?[]const u8 = null,
    tls_policy: TlsPolicy = .strict_verified,
    rotation_epoch: u64 = 1,
    lease_state: SecretLeaseState = .active_lease,
    lease_expires_at_ns: ?i64 = null,
    usage_granted_principals: []const u64 = &.{},
    policy_epoch: u64 = 1,

    pub fn validateForCatalog(self: SecretDeclaration) !void {
        if (self.magic != magic_sec1 or self.secret_id == 0) return error.InvalidSecretDeclaration;
        if (self.name.len == 0 or self.name.len > 63) return error.InvalidSecretName;
        if (self.has_unsealed_plaintext_literal) {
            return error.PlaintextSecretLiteralForbidden;
        }
        if (self.provider_ref.len == 0) return error.MissingSecretProviderReference;
        if (self.scope_prefixes.len == 0) return error.MissingSecretScopePrefix;
    }

    pub fn inspectRedacted(self: SecretDeclaration) SecretInspectionView {
        return .{
            .secret_id = self.secret_id,
            .name = self.name,
            .kind = self.kind,
            .provider = self.provider,
            .scope_count = self.scope_prefixes.len,
            .rotation_epoch = self.rotation_epoch,
            .lease_state = self.lease_state,
            .secret_value_display = "REDACTED",
        };
    }

    /// Dual authorization guard: requires BOTH `USAGE ON SECRET` at `current_policy_epoch`
    /// AND an exact match on `scope_prefixes`, `expected_audience`, and `tls_policy`.
    pub fn resolveForDestination(
        self: SecretDeclaration,
        ctx: Access.AccessContext,
        target_uri: []const u8,
        target_audience: ?[]const u8,
        connection_tls_verified: bool,
        current_policy_epoch: u64,
        now_ns: i64,
    ) !SealedSecretHandle {
        try self.validateForCatalog();
        try ctx.validate();
        if (ctx.policy_epoch != current_policy_epoch or self.policy_epoch != current_policy_epoch) {
            return error.AccessRevoked;
        }
        if (!connection_tls_verified) return error.SecretTlsPolicyViolation;

        if (std.mem.indexOfScalar(u64, self.usage_granted_principals, ctx.subject_principal) == null) {
            return error.MissingSecretUsagePrivilege;
        }
        var scope_matched = false;
        for (self.scope_prefixes) |prefix| {
            if (std.mem.startsWith(u8, target_uri, prefix)) {
                scope_matched = true;
                break;
            }
        }
        if (!scope_matched) return error.SecretScopeMismatch;

        if (self.expected_audience) |exp_aud| {
            const actual_aud = target_audience orelse return error.SecretAudienceMismatch;
            if (!std.mem.eql(u8, exp_aud, actual_aud)) return error.SecretAudienceMismatch;
        }
        if (self.lease_state == .pending_challenge) return error.SecretChallengePending;
        if (self.lease_state == .revoked) return error.AccessRevoked;
        if (self.lease_expires_at_ns) |exp_ns| {
            if (now_ns >= exp_ns) return error.ExpiredCredential;
        }

        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update("transit.catalog.secret-handle.v1\x00");
        var id_buf: [16]u8 = undefined;
        std.mem.writeInt(u64, id_buf[0..8], self.secret_id, .little);
        std.mem.writeInt(u64, id_buf[8..16], self.rotation_epoch, .little);
        hasher.update(&id_buf);
        hasher.update(target_uri);

        return .{
            .secret_id = self.secret_id,
            .rotation_epoch = self.rotation_epoch,
            .sealed_handle_digest = hasher.finalResult(),
        };
    }
};

pub const SecretInspectionView = struct {
    secret_id: u64,
    name: []const u8,
    kind: SecretKind,
    provider: SecretProvider,
    scope_count: usize,
    rotation_epoch: u64,
    lease_state: SecretLeaseState,
    secret_value_display: []const u8 = "REDACTED",
};

pub const SealedSecretHandle = struct {
    secret_id: u64,
    rotation_epoch: u64,
    sealed_handle_digest: [32]u8,
};

pub const OauthChallengeRecord = struct {
    challenge_id: u64,
    secret_id: u64,
    principal_id: u64,
    state_digest: [32]u8,
    pkce_code_challenge_s256: [43]u8,
    browser_cookie_digest: ?[32]u8 = null,
    nonce_digest: ?[32]u8 = null,
    issued_at_ns: i64,
    expires_at_ns: i64,
};

pub const OauthCallbackEvent = struct {
    callback_id: u64,
    state_digest: [32]u8,
    authorization_code_handle: u64,
    pkce_code_verifier: []const u8,
    browser_cookie_digest: ?[32]u8 = null,
    received_at_ns: i64,
};

pub const TokenExchangeOutboxIntent = struct {
    intent_id: u64,
    secret_id: u64,
    challenge_id: u64,
    authorization_code_handle: u64,
    verified_at_ns: i64,
    dispatched: bool = false,
};

pub const RefreshTimingWheelEntry = struct {
    secret_id: u64,
    rotation_epoch: u64,
    visible_at_ns: i64,
    lease_expires_at_ns: i64,
};

/// Deterministic WAL-activated OAuth 2.1 + PKCE `S256` challenge-response and
/// lease-refresh dataflow state machine (`Step 4`, `D4`, `P3`).
pub const OauthChallengeGame = struct {
    consumed_challenge_ids: [max_consumed_challenges]u64 = @splat(0),
    consumed_len: usize = 0,
    outbox_intents: [max_outbox_intents]TokenExchangeOutboxIntent = undefined,
    outbox_len: usize = 0,

    /// Computes RFC 7636 PKCE `S256` challenge: `BASE64URL_NO_PAD(SHA256(code_verifier))`.
    pub fn computePkceS256Challenge(code_verifier: []const u8) ![43]u8 {
        if (code_verifier.len < 43 or code_verifier.len > 128) {
            return error.InvalidPkceCodeVerifierLength;
        }
        var sha_digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(code_verifier, &sha_digest, .{});
        var encoded: [43]u8 = undefined;
        _ = std.base64.url_safe_no_pad.Encoder.encode(&encoded, &sha_digest);
        return encoded;
    }

    /// Evaluates one inbound `OauthCallbackEvent` against issued `OauthChallengeRecord`s
    /// and `consumed_challenge_ids` (`NOT EXISTS` anti-replay join + temporal window +
    /// browser cookie binding + PKCE `S256`).
    pub fn evaluateCallbackTurn(
        self: *OauthChallengeGame,
        challenges: []const OauthChallengeRecord,
        callback: OauthCallbackEvent,
    ) !TokenExchangeOutboxIntent {
        var matched_challenge: ?OauthChallengeRecord = null;
        for (challenges) |ch| {
            if (std.crypto.timing_safe.eql([32]u8, ch.state_digest, callback.state_digest)) {
                matched_challenge = ch;
                break;
            }
        }
        const ch = matched_challenge orelse return error.OauthChallengeStateMismatch;

        // Browser cookie binding (`__Host-` login cookie prevents cross-browser login CSRF):
        if (ch.browser_cookie_digest) |expected_cookie| {
            const actual_cookie = callback.browser_cookie_digest orelse return error.OauthBrowserCookieMismatch;
            if (!std.crypto.timing_safe.eql([32]u8, expected_cookie, actual_cookie)) {
                return error.OauthBrowserCookieMismatch;
            }
        }

        // Anti-replay (`LEFT ANTI JOIN oauth_consumed_challenges`):
        if (std.mem.indexOfScalar(u64, self.consumed_challenge_ids[0..self.consumed_len], ch.challenge_id) != null) {
            return error.OauthChallengeReplayDetected;
        }
        if (callback.received_at_ns < ch.issued_at_ns or callback.received_at_ns > ch.expires_at_ns) {
            return error.OauthChallengeExpired;
        }

        // Deterministic PKCE `S256` commitment check:
        const computed_s256 = try computePkceS256Challenge(callback.pkce_code_verifier);
        if (!std.crypto.timing_safe.eql([43]u8, computed_s256, ch.pkce_code_challenge_s256)) {
            return error.OauthPkceVerificationFailed;
        }

        if (self.consumed_len >= max_consumed_challenges or self.outbox_len >= max_outbox_intents) {
            return error.ChallengeGameCapacityExceeded;
        }
        self.consumed_challenge_ids[self.consumed_len] = ch.challenge_id;
        self.consumed_len += 1;

        const intent: TokenExchangeOutboxIntent = .{
            .intent_id = callback.callback_id,
            .secret_id = ch.secret_id,
            .challenge_id = ch.challenge_id,
            .authorization_code_handle = callback.authorization_code_handle,
            .verified_at_ns = callback.received_at_ns,
        };
        self.outbox_intents[self.outbox_len] = intent;
        self.outbox_len += 1;
        return intent;
    }

    /// Seals the connector's token exchange outcome into `SecretDeclaration` (`rotation_epoch++`),
    /// schedules a proactive refresh timing-wheel entry, and wakes any `ManagedDataflow.DataflowRuntime`
    /// that was `Suspended` on `.credential_pending`.
    pub fn sealTokenLeaseAndWakeDataflow(
        secret: *SecretDeclaration,
        new_lease_expires_at_ns: i64,
        refresh_margin_ns: i64,
        dependent_dataflow: ?*ManagedDataflow.DataflowRuntime,
    ) !RefreshTimingWheelEntry {
        secret.rotation_epoch += 1;
        secret.lease_state = .active_lease;
        secret.lease_expires_at_ns = new_lease_expires_at_ns;

        if (dependent_dataflow) |df| {
            if (df.state == .suspended and df.blocked_reason == .credential_pending) {
                df.state = .active;
                df.blocked_reason = .none;
                df.current_lease_epoch += 1;
            }
        }
        return .{
            .secret_id = secret.secret_id,
            .rotation_epoch = secret.rotation_epoch,
            .visible_at_ns = new_lease_expires_at_ns - refresh_margin_ns,
            .lease_expires_at_ns = new_lease_expires_at_ns,
        };
    }
};

/// Declarative inbound webhook endpoint bound to a catalog `SecretDeclaration`
/// with `SecretKind.webhook_hmac` and a target `STREAM`/`QUEUE`/`TABLE`/`DOCUMENT` object (`Step 4`, `D4`).
pub const WebhookEndpointDeclaration = struct {
    endpoint_id: u64,
    realm_id: u64,
    endpoint_path: []const u8,
    secret_id: u64,
    target_object_id: u64,
    max_timestamp_skew_ns: i64 = 300 * std.time.ns_per_s,
    max_payload_bytes: usize = 65536,

    pub fn validate(self: WebhookEndpointDeclaration) !void {
        if (self.endpoint_id == 0 or self.realm_id == 0 or self.secret_id == 0 or self.target_object_id == 0) {
            return error.InvalidWebhookEndpointDeclaration;
        }
        if (self.endpoint_path.len < 2 or self.endpoint_path[0] != '/') {
            return error.InvalidWebhookEndpointDeclaration;
        }
        if (self.max_timestamp_skew_ns <= 0 or self.max_payload_bytes == 0) {
            return error.InvalidWebhookEndpointDeclaration;
        }
    }
};

pub const WebhookDeliveryEvent = struct {
    delivery_id: []const u8,
    timestamp_epoch_s: i64,
    raw_payload: []const u8,
    signature_hmac_sha256: [32]u8,
    received_at_ns: i64,
};

pub const WebhookAdmittedIntent = struct {
    intent_id: u64,
    endpoint_id: u64,
    target_object_id: u64,
    secret_rotation_epoch: u64,
    delivery_id_digest: [32]u8,
    payload_digest: [32]u8,
    admitted_at_ns: i64,
};

/// Deterministic HMAC-SHA256 webhook signature verifier + replay window + delivery ID
/// deduplicator backed by catalog `SecretDeclaration` (`SecretKind.webhook_hmac`).
pub const WebhookAdmissionEngine = struct {
    pub const max_recent_deliveries: usize = 64;

    recent_delivery_digests: [max_recent_deliveries][32]u8 = undefined,
    recent_delivery_expires_ns: [max_recent_deliveries]i64 = @splat(0),
    recent_len: usize = 0,
    next_intent_id: u64 = 1,

    pub fn computeWebhookHmacSha256(
        secret_key_material: []const u8,
        timestamp_epoch_s: i64,
        raw_payload: []const u8,
    ) [32]u8 {
        var ts_buf: [32]u8 = undefined;
        const ts_slice = std.fmt.bufPrint(&ts_buf, "{d}.", .{timestamp_epoch_s}) catch unreachable;
        var hmac = std.crypto.auth.hmac.sha2.HmacSha256.init(secret_key_material);
        hmac.update(ts_slice);
        hmac.update(raw_payload);
        var out: [32]u8 = undefined;
        hmac.final(&out);
        return out;
    }

    pub fn deliveryDigest(endpoint_id: u64, delivery_id: []const u8) [32]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update("transit.catalog.webhook.delivery.v1\x00");
        var id_buf: [8]u8 = undefined;
        std.mem.writeInt(u64, &id_buf, endpoint_id, .little);
        hasher.update(&id_buf);
        hasher.update(delivery_id);
        return hasher.finalResult();
    }

    pub fn admitDelivery(
        self: *WebhookAdmissionEngine,
        endpoint: WebhookEndpointDeclaration,
        secret: SecretDeclaration,
        sealed_secret_key_material: []const u8,
        event: WebhookDeliveryEvent,
    ) !WebhookAdmittedIntent {
        try endpoint.validate();
        try secret.validateForCatalog();
        if (secret.secret_id != endpoint.secret_id) {
            return error.InvalidSecretDeclaration;
        }
        if (secret.kind != .webhook_hmac) {
            return error.WebhookSecretKindMismatch;
        }
        if (secret.lease_state != .active_lease) {
            return error.SecretLeaseExpiredOrRevoked;
        }
        if (secret.lease_expires_at_ns) |exp_ns| {
            if (event.received_at_ns >= exp_ns) return error.SecretLeaseExpiredOrRevoked;
        }
        if (event.delivery_id.len == 0 or event.delivery_id.len > 256) {
            return error.InvalidWebhookDeliveryId;
        }
        if (event.raw_payload.len == 0 or event.raw_payload.len > endpoint.max_payload_bytes) {
            return error.WebhookPayloadBoundsExceeded;
        }

        const event_ts_ns = event.timestamp_epoch_s * std.time.ns_per_s;
        const delta_ns = if (event.received_at_ns >= event_ts_ns)
            event.received_at_ns - event_ts_ns
        else
            event_ts_ns - event.received_at_ns;
        if (delta_ns > endpoint.max_timestamp_skew_ns) {
            return error.WebhookTimestampOutsideReplayWindow;
        }

        const expected_sig = computeWebhookHmacSha256(sealed_secret_key_material, event.timestamp_epoch_s, event.raw_payload);
        if (!std.crypto.timing_safe.eql([32]u8, expected_sig, event.signature_hmac_sha256)) {
            return error.WebhookSignatureVerificationFailed;
        }

        // Reclaim expired delivery slots first so bounded capacity cannot be exhausted by old traffic:
        var write_idx: usize = 0;
        for (0..self.recent_len) |idx| {
            if (self.recent_delivery_expires_ns[idx] > event.received_at_ns) {
                self.recent_delivery_digests[write_idx] = self.recent_delivery_digests[idx];
                self.recent_delivery_expires_ns[write_idx] = self.recent_delivery_expires_ns[idx];
                write_idx += 1;
            }
        }
        self.recent_len = write_idx;

        const deliv_digest = deliveryDigest(endpoint.endpoint_id, event.delivery_id);
        for (self.recent_delivery_digests[0..self.recent_len]) |existing| {
            if (std.crypto.timing_safe.eql([32]u8, existing, deliv_digest)) {
                return error.WebhookDeliveryReplayDetected;
            }
        }
        if (self.recent_len >= max_recent_deliveries) {
            return error.WebhookReplayWindowCapacityExceeded;
        }
        self.recent_delivery_digests[self.recent_len] = deliv_digest;
        self.recent_delivery_expires_ns[self.recent_len] = event.received_at_ns + endpoint.max_timestamp_skew_ns;
        self.recent_len += 1;

        var payload_digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(event.raw_payload, &payload_digest, .{});

        const intent_id = self.next_intent_id;
        self.next_intent_id += 1;
        return .{
            .intent_id = intent_id,
            .endpoint_id = endpoint.endpoint_id,
            .target_object_id = endpoint.target_object_id,
            .secret_rotation_epoch = secret.rotation_epoch,
            .delivery_id_digest = deliv_digest,
            .payload_digest = payload_digest,
            .admitted_at_ns = event.received_at_ns,
        };
    }
};

fn containsString(haystack: []const []const u8, needle: []const u8) bool {
    for (haystack) |item| {
        if (std.mem.eql(u8, item, needle)) return true;
    }
    return false;
}
