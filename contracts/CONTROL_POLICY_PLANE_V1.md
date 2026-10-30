# Enterprise identity and Control & Policy Plane v1 (`CONTROL_POLICY_PLANE_V1`)

This contract specifies the current-v1 enterprise identity, bounded delegation,
declarative secret management, OAuth 2.1 + PKCE challenge-response dataflows,
branch/publication governance, security-barrier Row-Level Security (RLS) and
Column-Level Security (CLS) dynamic masking, Right-to-Erasure (GDPR/CCPA)
crypto-shredding and purge receipts, Hierarchical Workload Management (WLM), and
zero-work `EXPLAIN POLICY` surfaces across `transit-protocol`, `transit-catalog`,
and `transit-fuze`.

It extends [`AUTHORIZATION_V1`](AUTHORIZATION_V1.md),
[`DATA_LIFECYCLE_V1`](DATA_LIFECYCLE_V1.md),
[`PUBLISHED_RESOURCE_V1`](PUBLISHED_RESOURCE_V1.md), and
[`SQL_RESULTS_V1`](SQL_RESULTS_V1.md) under the
[security reference](../docs/handbook/reference/security.md) and
[collaborative decisions reference](../docs/handbook/reference/collaborative-decisions.md).

## 1. Canonical access context (`ACCESS_CONTEXT_V1` / `ACTX1`)

Every authenticated session, SQL statement, SDK call, Arrow Flight ticket, HTTP
Serving request, and MCP tool invocation evaluates against a canonical
`AccessContext` (`magic = 0x41435458` / `"ACTX"`):

- `realm_id: u64`: Isolation realm.
- `actor_principal: u64` and `actor_kind: PrincipalKind` (`human`, `workload`,
  `service`, `agent`): The immediate authenticated caller executing the request.
- `subject_principal: u64` and `subject_kind: PrincipalKind`: The represented
  principal whose current permissions and row/column policies bound the request.
  For direct execution, `actor_principal == subject_principal`.
- `login_role: u64` and `active_role: u64`: Verified against current role
  membership (`INHERIT` / `SET`) at `policy_epoch`.
- `credential_epoch: u64` and `policy_epoch: u64`: Fencing epochs for credential
  rotation and catalog policy changes.
- `assurance_level: AssuranceLevel`: `aal1_single_factor`, `aal2_multi_factor`,
  or `aal3_hardware_cryptographic`.
- `authenticated_at_ns: i64` and `step_up_verified_at_ns: ?i64`.
- `enterprise_binding: ?EnterpriseIdentityRef`: `(issuer_id, external_subject_digest,
  management_source, membership_verified_at_ns, token_expires_at_ns, jti_digest)`.
- `verified_attributes: []const AttributeClaim`: Cryptographically verified or
  catalog-projected attributes (`utf8`, `int64`, `s2_cell_prefix`,
  `h3_cell_prefix`, `oct_cell_prefix`, `bbox2d`, `bbox3d`) consumed by
  security-barrier RLS and dynamic column masking.
- `delegation: ?DelegationChain`: Bounded 1..4 hop delegation chain (`DLG1`).
- `target: TargetBinding`: `(audience, target_object, branch_id,
  investigation_basis_id)`.

## 2. Enterprise identity federation, SCIM 2.0, and freshness (`IDENTITY_FEDERATION_V1` / `IDF1`)

1. **OIDC & Workload Identity verification (`OidcIssuerProfile` / `JwksKeyring`):**
   - Validates `iss`, `aud` (against configured `expected_audiences`), `exp`,
     `nbf`, `iat`, `jti`, and `kid`.
   - Distinguishes `TokenKind`: `login_id_token` (session bootstrap only),
     `api_access_token` (scoped API/query operations), and `workload_jwt`
     (SPIFFE/Kubernetes/cloud service identity). Presenting a `login_id_token`
     as a bearer API credential rejects with
     `error.IdTokenNotPermittedForApiAccess`.
   - Maps `(issuer_id, external_subject)` to a unique realm-local `PrincipalId`.
     Cross-issuer subject collisions (`error.IdentitySubjectCollision`) and
     reuse of retired `PrincipalId`s are rejected.
2. **SCIM 2.0 membership synchronization and local-authority independence:**
   - External identity establishes *who* the caller is; Transit catalog grants
     establish *what* that principal may do.
   - External group claims may map only onto roles with
     `allow_external_membership_sync = true` (`error.ConflictingManagementSource`).
   - A local operator revocation or `local_restriction_hold = true` can **never**
     be overridden or re-enabled by an external SCIM sync or OIDC login claim
     (`error.LocalRestrictionOverridesExternalSync`).
   - Independent `native_local` grant paths remain intact when external groups
     change.
3. **Freshness watermarks, offboarding, and fail-closed outage handling:**
   - Enforces `now_ns - membership_verified_at_ns <= max_membership_staleness_ms`
     independently of JWT `exp` on admission and before every `ResultSet` batch
     disclosure (`Observation.validateDisclosure`).
   - Offboarding via SCIM (`active: false`) or local revocation synchronously
     advances `policy_epoch`, halting in-flight multi-batch readers between
     pages (`error.AccessRevoked`).
   - When an external IdP is unreachable past `max_membership_staleness_ms`,
     access fails closed (`error.IdentityProviderUnavailable`) while
     `native_local` Ed25519 emergency principals continue to operate.
   - `AccessAuditRecord` logs authentication, delegation, and policy outcomes
     with zero credentials, keys, or private payloads.

## 3. Bounded delegation (`DLG1`), human-only approval (`APV1`), and branch policy

1. **Multi-hop attenuation (`DelegationTicket` / `DLG1`, magic `0x444C4731`):**
   - Effective rights of a delegated chain $D = (d_1, \dots, d_k)$ ($k \le 4$)
     equal the intersection of the represented `subject_principal`'s current
     rights at `policy_epoch`, every hop's `(allowed_actions, allowed_objects,
     allowed_branches, attribute_attenuation)`, and the immediate
     `actor_principal`'s execution eligibility.
   - Adapts OAuth 2.0 Token Exchange (RFC 8693) and MCP enterprise authorization
     into `DelegationTicket`s.
2. **Human-only step-up approval (`ApprovalAttestation` / `APV1`, magic `0x41505631`):**
   - High-consequence actions (`approve` branch merge, `execute_erasure`,
     `publish_attested_resource`) require direct human execution
     (`delegation == null`, `actor_principal == subject_principal`,
     `assurance_level >= .aal2_multi_factor`, fresh `step_up_verified_at_ns`),
     cryptographic binding to `(target_object, target_branch_id,
     expected_target_head_digest, candidate_manifest_digest, policy_epoch)`, and
     separation of duties (`approver_principal != proposer_principal`).
   - Delegated agents can never mint or exercise human-only approval authority
     (`error.CannotDelegateHumanOnlyAction`, `error.DelegatedAgentCannotApprove`).
3. **Unified 8-action branch and publication policy:**
   - Separates `inspect`, `create_branch`, `edit`, `share`, `propose`,
     `approve`, `merge`, and `external_activation`.
   - `branching_only` prohibits all merges (`error.InstallationProhibitsMerge`).
   - `protected_destination` rejects all direct writes across SQL, `/table/v1`,
     Stream/Queue, Document, KV, Flight, SDK, and MCP adapters
     (`error.ProtectedBranchDirectWriteDenied`), permitting advancement only
     via reviewed merge with a valid `ApprovalAttestation`.

## 4. Declarative secrets (`SECRET_MANAGER_V1` / `SEC1`) and OAuth 2.1 + PKCE challenge dataflows

1. **Catalog `SecretDeclaration` (`magic = 0x53454331` / `"SEC1"`):**
   - Supports `CREATE [PERSISTENT | TEMPORARY] SECRET`, `ALTER SECRET`,
     `DROP SECRET`, `SHOW SECRETS`, and `GRANT USAGE ON SECRET` over
     `SecretKind` (`s3`, `gcs`, `r2`, `http_bearer`, `oauth2_bearer`,
     `postgres`, `kms_key_ref`, `webhook_hmac`) and `SecretProvider`
     (`kms_envelope`, `vault_kv`, `workload_identity`, `env_ref`,
     `oauth2_authorization_code_pkce`, `oauth2_client_credentials`,
     `rfc8693_token_exchange`).
   - Unsealed plaintext secret literals in durable SQL declarations are rejected
     (`error.PlaintextSecretLiteralForbidden`).
   - Resolving a secret for a foreign table, `COPY`, remote branch sync, or
     outbound HTTP/gRPC/MCP connector requires **both** `USAGE ON SECRET` at
     `current_policy_epoch` (`error.MissingSecretUsagePrivilege`) **and** an
     exact match on `scope_prefixes`, `audience`, and `tls_policy`
     (`error.SecretScopeMismatch`, `error.SecretAudienceMismatch`,
     `error.SecretTlsPolicyViolation`).
   - `SHOW SECRETS` returns redacted metadata (`REDACTED` value placeholder) and
     current `rotation_epoch` / lease state.
2. **OAuth 2.1 + PKCE challenge-response dataflow state machine (`OauthChallengeGame`):**
   - Evaluates stateful challenge-response turns deterministically over
     `oauth_challenges`, `oauth_callbacks`, and `oauth_consumed_challenges`:
     verifying `state_digest`, TTL window (`received_at` $\in$
     `[issued_at, expires_at]`), single-use anti-replay (`NOT EXISTS`), and
     PKCE `S256` (`base64url(sha256(code_verifier)) == code_challenge`).
   - Emits governed `TokenExchangeOutboxIntent` records for the HTTP connector
     worker, which seals returned tokens into the secret vault (`rotation_epoch++`),
     commits non-secret `SecretLeaseMetadata`, schedules proactive refresh
     timing-wheel intents before `expires_at`, and wakes downstream computations
     from `Suspended (credential_pending)` to `Active`.

## 5. Security-barrier RLS, Geospatial RLS, and Dynamic Data Masking (`RLS_MASKING_V1` / `RLM1`)

- `RlsPolicyDescriptor` (`magic = 0x524C4D31` / `"RLM1"`) combines `PERMISSIVE`
  (disjunctive) and `RESTRICTIVE` (conjunctive) policies for `USING` (reads) and
  `WITH CHECK` (mutations), including 2D/3D spatial predicates (`ST_CoveredBy`,
  `ST_Intersects`, `ST_3DCoveredBy`, `S2_CellContains`, `H3_CellContains`,
  `OCT_CellContains`).
- `SecurityBarrierFilter` evaluates on source batches **before** any untrusted
  user predicate, UDF, join, aggregate, sort, or 5-state `type_error` /
  division-by-zero check, and suppresses zone-map/index side-channel leakage on
  excluded rows.
- `MaskingPolicyDescriptor` transforms restricted columns (`full_redact`,
  `partial_string_mask` scrubbing `GermanString` 4-byte prefixes,
  `keyed_hash_hmac`, `numeric_bucket`, and `spatial_coarsen`) before user
  projections, filters, or sorts run, isolating `ReadCache` keys by
  `rls_and_masking_policy_digest`.

## 6. Right-to-Erasure (GDPR/CCPA) crypto-shredding and purge (`ERASURE_V1` / `ERS1`)

- Destroys per-subject/per-tenant envelope `DEK`/`KEK` keys (`shredSubjectKeys`),
  zeroes active `Workspace` memory (`std.crypto.secureZero`), and projects
  `Cell.missing` erasure tombstones for any unrewritten encrypted blocks.
- Executes cross-branch and cross-snapshot `.tseg` purge compaction while
  recording `CompactionLineageEdge`s (preventing false 3-way merge conflicts on
  unrelated rows) and hash-chained, PII-free `ErasureReceipt`s (`magic =
  0x45525331` / `"ERS1"`).

## 7. Hierarchical Workload Management (`WORKLOAD_MANAGEMENT_V1` / `WLM1`) and `EXPLAIN POLICY`

- `WorkloadGroup` (`magic = 0x574C4D31` / `"WLM1"`) enforces a non-preemptible
  `sys_control_and_recovery` reserve alongside `oltp_critical`,
  `interactive_governance`, `continuous_dataflow`, `agent_burst`, and
  `background_maintenance` groups over `transit-memory.Quota`/`Budget`,
  per-morsel CPU tick budgets, Tier 2 NVMe spill thresholds, and scan-resistant
  I/O token buckets.
- `EXPLAIN POLICY FOR <statement>` executes under `WorkBound.zero_work_explain`
  (zero storage pins or segment reads), returning identity provenance,
  delegation attenuation, branch policy, compiled RLS/masking rules, WLM group
  assignment, and structured `PolicyDenialCode` diagnostics.
