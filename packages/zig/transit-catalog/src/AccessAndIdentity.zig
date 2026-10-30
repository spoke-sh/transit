//! Canonical `AccessContext` (`ACCESS_CONTEXT_V1` / `ACTX1`, magic `0x41435458`),
//! enterprise OIDC/Workload Identity verification and SCIM 2.0 provisioning
//! (`IDENTITY_FEDERATION_V1` / `IDF1`, magic `0x49444631`), membership freshness
//! watermarks, fail-closed IdP outage guards, synchronous offboarding propagation
//! into `policy_epoch`, and credential/payload-free `AccessAuditRecord`s
//! (`Steps 1–3`, `D1`–`D3`, `P1`–`P2`).
const std = @import("std");

pub const magic_actx1: u32 = 0x41435458; // "ACTX"
pub const magic_idf1: u32 = 0x49444631; // "IDF1"
pub const contract_id_actx = "transit.authorization.access-context.v1";
pub const contract_id_idf = "transit.catalog.identity-federation.v1";

pub const max_verified_attributes: usize = 32;
pub const max_jwks_keys: usize = 32;
pub const max_principal_bindings: usize = 128;
pub const max_audit_records: usize = 128;

pub const PrincipalKind = enum(u8) {
    human = 1,
    workload = 2,
    service = 3,
    agent = 4,
};

pub const AssuranceLevel = enum(u8) {
    aal1_single_factor = 1,
    aal2_multi_factor = 2,
    aal3_hardware_cryptographic = 3,

    pub fn isHumanMultiFactor(self: AssuranceLevel) bool {
        return self == .aal2_multi_factor or self == .aal3_hardware_cryptographic;
    }
};

pub const ManagementSource = enum(u8) {
    native_local = 1,
    external_iam_scim = 2,
    external_oidc_claim = 3,
};

pub const TokenKind = enum(u8) {
    login_id_token = 1,
    api_access_token = 2,
    workload_jwt = 3,
};

pub const EnterpriseIdentityRef = struct {
    issuer_id: u64,
    external_subject_digest: [32]u8,
    management_source: ManagementSource,
    membership_verified_at_ns: i64,
    token_expires_at_ns: i64,
    jti_digest: [32]u8 = @splat(0),
};

pub const BBox2D = struct {
    min_x: f64,
    min_y: f64,
    max_x: f64,
    max_y: f64,
};

pub const BBox3D = struct {
    min_x: f64,
    min_y: f64,
    min_z: f64,
    max_x: f64,
    max_y: f64,
    max_z: f64,
};

pub const AttributeValue = union(enum) {
    utf8: []const u8,
    int64: i64,
    s2_cell_prefix: u64,
    h3_cell_prefix: u64,
    oct_cell_prefix: u64,
    bbox2d: BBox2D,
    bbox3d: BBox3D,
};

pub const AttributeClaim = struct {
    key: []const u8,
    value: AttributeValue,

    pub fn validate(self: AttributeClaim) !void {
        if (self.key.len == 0 or self.key.len > 63) return error.InvalidAttributeClaimKey;
        switch (self.value) {
            .utf8 => |s| if (s.len > 256) return error.InvalidAttributeClaimValue,
            .bbox2d => |b| if (b.min_x > b.max_x or b.min_y > b.max_y) return error.InvalidAttributeClaimValue,
            .bbox3d => |b| if (b.min_x > b.max_x or b.min_y > b.max_y or b.min_z > b.max_z) return error.InvalidAttributeClaimValue,
            else => {},
        }
    }
};

pub const TargetBinding = struct {
    audience: u64,
    target_object: u64,
    branch_id: u64 = 1,
    investigation_basis_id: ?u64 = null,
};

pub const AccessContext = struct {
    magic: u32 = magic_actx1,
    realm_id: u64,
    actor_principal: u64,
    actor_kind: PrincipalKind,
    subject_principal: u64,
    subject_kind: PrincipalKind,
    login_role: u64,
    active_role: u64,
    credential_epoch: u64,
    policy_epoch: u64,
    assurance_level: AssuranceLevel = .aal1_single_factor,
    authenticated_at_ns: i64,
    step_up_verified_at_ns: ?i64 = null,
    enterprise_binding: ?EnterpriseIdentityRef = null,
    client_app_id: u64 = 0,
    verified_attributes: []const AttributeClaim = &.{},
    has_delegation: bool = false,
    delegation_depth: u8 = 0,
    target: TargetBinding,
    service_transport_principal: ?u64 = null,

    pub fn validate(self: AccessContext) !void {
        if (self.magic != magic_actx1) return error.InvalidAccessContextMagic;
        if (self.realm_id == 0 or self.actor_principal == 0 or self.subject_principal == 0) {
            return error.InvalidAccessContextIdentity;
        }
        if (self.login_role == 0 or self.active_role == 0) {
            return error.InvalidAccessContextRole;
        }
        if (self.credential_epoch == 0 or self.policy_epoch == 0) {
            return error.InvalidAccessContextEpoch;
        }
        if (self.target.audience == 0 or self.target.branch_id == 0) {
            return error.InvalidAccessContextTarget;
        }
        if (!self.has_delegation and self.actor_principal != self.subject_principal) {
            return error.UndelegatedActorSubjectMismatch;
        }
        if (self.has_delegation and (self.delegation_depth == 0 or self.delegation_depth > 4)) {
            return error.DelegationDepthExceeded;
        }
        if (self.verified_attributes.len > max_verified_attributes) {
            return error.TooManyVerifiedAttributes;
        }
        for (self.verified_attributes) |attr| {
            try attr.validate();
        }
    }

    pub fn lookupUtf8Attribute(self: AccessContext, key: []const u8) ?[]const u8 {
        for (self.verified_attributes) |attr| {
            if (std.mem.eql(u8, attr.key, key)) {
                switch (attr.value) {
                    .utf8 => |s| return s,
                    else => return null,
                }
            }
        }
        return null;
    }

    pub fn lookupInt64Attribute(self: AccessContext, key: []const u8) ?i64 {
        for (self.verified_attributes) |attr| {
            if (std.mem.eql(u8, attr.key, key)) {
                switch (attr.value) {
                    .int64 => |n| return n,
                    else => return null,
                }
            }
        }
        return null;
    }

    pub fn contextDigest(self: AccessContext) ![32]u8 {
        try self.validate();
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(contract_id_actx);
        hasher.update("\x00");
        hashU64(&hasher, self.realm_id);
        hashU64(&hasher, self.actor_principal);
        hasher.update(&.{@backingInt(self.actor_kind)});
        hashU64(&hasher, self.subject_principal);
        hasher.update(&.{@backingInt(self.subject_kind)});
        hashU64(&hasher, self.login_role);
        hashU64(&hasher, self.active_role);
        hashU64(&hasher, self.credential_epoch);
        hashU64(&hasher, self.policy_epoch);
        hasher.update(&.{@backingInt(self.assurance_level)});
        hashU64(&hasher, @bitCast(self.authenticated_at_ns));
        hashU64(&hasher, self.target.audience);
        hashU64(&hasher, self.target.target_object);
        hashU64(&hasher, self.target.branch_id);
        for (self.verified_attributes) |attr| {
            hasher.update(attr.key);
            hasher.update("\x00");
            switch (attr.value) {
                .utf8 => |s| hasher.update(s),
                .int64 => |n| hashU64(&hasher, @bitCast(n)),
                .s2_cell_prefix => |c| hashU64(&hasher, c),
                .h3_cell_prefix => |c| hashU64(&hasher, c),
                .oct_cell_prefix => |c| hashU64(&hasher, c),
                .bbox2d => |b| {
                    hashU64(&hasher, @bitCast(b.min_x));
                    hashU64(&hasher, @bitCast(b.max_x));
                },
                .bbox3d => |b| {
                    hashU64(&hasher, @bitCast(b.min_x));
                    hashU64(&hasher, @bitCast(b.max_z));
                },
            }
        }
        return hasher.finalResult();
    }
};

pub const JwksKeyState = enum(u8) {
    active = 1,
    grace_rotation = 2,
    revoked_or_retired = 3,
};

pub const JwksKeyRecord = struct {
    issuer_id: u64,
    kid: []const u8,
    key_epoch: u64,
    state: JwksKeyState = .active,
    expires_at_ns: i64,
};

pub const OidcIssuerProfile = struct {
    magic: u32 = magic_idf1,
    issuer_id: u64,
    realm_id: u64,
    issuer_uri: []const u8,
    expected_audiences: []const []const u8,
    max_clock_skew_ns: i64 = 30 * std.time.ns_per_s,
    max_membership_staleness_ms: u64 = 60_000,
    offboarding_propagation_sla_ms: u64 = 5_000,
    jwks_keys: []const JwksKeyRecord = &.{},

    pub fn validateToken(
        self: OidcIssuerProfile,
        claims: OidcTokenClaims,
        now_ns: i64,
        require_api_or_workload_token: bool,
    ) !void {
        if (self.magic != magic_idf1 or self.issuer_id == 0 or self.realm_id == 0) {
            return error.InvalidIdentityProviderProfile;
        }
        if (!std.mem.eql(u8, self.issuer_uri, claims.issuer_uri)) {
            return error.InvalidTokenIssuer;
        }
        if (require_api_or_workload_token and claims.token_kind == .login_id_token) {
            return error.IdTokenNotPermittedForApiAccess;
        }
        var audience_ok = false;
        for (self.expected_audiences) |expected_aud| {
            if (std.mem.eql(u8, expected_aud, claims.audience)) {
                audience_ok = true;
                break;
            }
        }
        if (!audience_ok) return error.InvalidTokenAudience;

        if (now_ns + self.max_clock_skew_ns < claims.not_before_ns) {
            return error.TokenNotYetValid;
        }
        if (now_ns - self.max_clock_skew_ns >= claims.expires_at_ns) {
            return error.ExpiredCredential;
        }

        var key_found = false;
        for (self.jwks_keys) |k| {
            if (k.issuer_id == self.issuer_id and std.mem.eql(u8, k.kid, claims.kid)) {
                if (k.state == .revoked_or_retired or now_ns >= k.expires_at_ns) {
                    return error.UnknownOrRevokedJwksKey;
                }
                key_found = true;
                break;
            }
        }
        if (!key_found) return error.UnknownOrRevokedJwksKey;
    }
};

pub const OidcTokenClaims = struct {
    issuer_uri: []const u8,
    external_subject: []const u8,
    audience: []const u8,
    kid: []const u8,
    token_kind: TokenKind,
    issued_at_ns: i64,
    not_before_ns: i64,
    expires_at_ns: i64,
    assurance_level: AssuranceLevel = .aal1_single_factor,
    external_groups: []const []const u8 = &.{},
};

pub const PrincipalBindingEntry = struct {
    realm_id: u64,
    issuer_id: u64,
    external_subject_digest: [32]u8,
    principal_id: u64,
    retired: bool = false,
    local_restriction_hold: bool = false,
};

pub const PrincipalBindingDirectory = struct {
    entries: [max_principal_bindings]PrincipalBindingEntry = undefined,
    len: usize = 0,

    pub fn subjectDigest(issuer_id: u64, external_subject: []const u8) [32]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(contract_id_idf);
        hasher.update("\x00");
        hashU64(&hasher, issuer_id);
        hasher.update(external_subject);
        return hasher.finalResult();
    }

    pub fn bindPrincipal(
        self: *PrincipalBindingDirectory,
        realm_id: u64,
        issuer_id: u64,
        external_subject: []const u8,
        principal_id: u64,
    ) !void {
        if (realm_id == 0 or issuer_id == 0 or external_subject.len == 0 or principal_id == 0) {
            return error.InvalidIdentityBinding;
        }
        const digest = subjectDigest(issuer_id, external_subject);
        for (self.entries[0..self.len]) |entry| {
            if (entry.principal_id == principal_id) {
                if (entry.retired) return error.RetiredPrincipalIdReuseForbidden;
                if (entry.issuer_id != issuer_id or !std.mem.eql(u8, &entry.external_subject_digest, &digest)) {
                    return error.IdentitySubjectCollision;
                }
                return;
            }
            if (entry.realm_id == realm_id and entry.issuer_id == issuer_id and std.mem.eql(u8, &entry.external_subject_digest, &digest)) {
                if (entry.retired) return error.RetiredPrincipalIdReuseForbidden;
                if (entry.principal_id != principal_id) return error.IdentitySubjectCollision;
                return;
            }
        }
        if (self.len >= max_principal_bindings) return error.PrincipalDirectoryFull;
        self.entries[self.len] = .{
            .realm_id = realm_id,
            .issuer_id = issuer_id,
            .external_subject_digest = digest,
            .principal_id = principal_id,
        };
        self.len += 1;
    }

    pub fn resolvePrincipal(
        self: *const PrincipalBindingDirectory,
        realm_id: u64,
        issuer_id: u64,
        external_subject: []const u8,
    ) !u64 {
        const digest = subjectDigest(issuer_id, external_subject);
        for (self.entries[0..self.len]) |entry| {
            if (entry.realm_id == realm_id and entry.issuer_id == issuer_id and std.mem.eql(u8, &entry.external_subject_digest, &digest)) {
                if (entry.retired or entry.local_restriction_hold) return error.PrincipalLocallyRestricted;
                return entry.principal_id;
            }
        }
        return error.UnboundExternalSubject;
    }

    pub fn setLocalRestrictionHold(self: *PrincipalBindingDirectory, principal_id: u64, hold: bool) !void {
        for (self.entries[0..self.len]) |*entry| {
            if (entry.principal_id == principal_id) {
                entry.local_restriction_hold = hold;
                return;
            }
        }
        return error.UnboundExternalSubject;
    }

    pub fn retirePrincipal(self: *PrincipalBindingDirectory, principal_id: u64) !void {
        for (self.entries[0..self.len]) |*entry| {
            if (entry.principal_id == principal_id) {
                entry.retired = true;
                entry.local_restriction_hold = true;
                return;
            }
        }
        return error.UnboundExternalSubject;
    }
};

pub const RoleSyncRule = struct {
    role_id: u64,
    external_group_name: []const u8,
    allow_external_membership_sync: bool = false,
    locally_revoked_principals: []const u64 = &.{},
};

pub const ScimSyncOutcome = struct {
    principal_id: u64,
    granted_external_roles: [8]u64 = @splat(0),
    granted_external_count: usize = 0,
    preserved_native_local_roles: [8]u64 = @splat(0),
    preserved_native_local_count: usize = 0,
};

pub const ScimProvisioningEngine = struct {
    /// Applies SCIM 2.0 or OIDC group membership synchronization while enforcing:
    /// 1. External groups cannot map onto roles where `allow_external_membership_sync == false`.
    /// 2. External sync can never override `local_restriction_hold` or locally revoked roles.
    /// 3. Removing external groups never strips independent `native_local` role grants.
    pub fn syncMemberships(
        directory: *const PrincipalBindingDirectory,
        principal_id: u64,
        scim_active: bool,
        external_groups: []const []const u8,
        rules: []const RoleSyncRule,
        native_local_roles: []const u64,
    ) !ScimSyncOutcome {
        for (directory.entries[0..directory.len]) |entry| {
            if (entry.principal_id == principal_id) {
                if (entry.local_restriction_hold or entry.retired) {
                    return error.LocalRestrictionOverridesExternalSync;
                }
            }
        }
        var out: ScimSyncOutcome = .{ .principal_id = principal_id };
        for (native_local_roles) |nr| {
            if (out.preserved_native_local_count < out.preserved_native_local_roles.len) {
                out.preserved_native_local_roles[out.preserved_native_local_count] = nr;
                out.preserved_native_local_count += 1;
            }
        }
        if (!scim_active) {
            return out;
        }
        for (external_groups) |ext_group| {
            var matched_rule = false;
            for (rules) |rule| {
                if (std.mem.eql(u8, rule.external_group_name, ext_group)) {
                    matched_rule = true;
                    if (!rule.allow_external_membership_sync) {
                        return error.ConflictingManagementSource;
                    }
                    if (std.mem.indexOfScalar(u64, rule.locally_revoked_principals, principal_id) != null) {
                        return error.LocalRestrictionOverridesExternalSync;
                    }
                    if (out.granted_external_count < out.granted_external_roles.len) {
                        out.granted_external_roles[out.granted_external_count] = rule.role_id;
                        out.granted_external_count += 1;
                    }
                }
            }
            if (!matched_rule) return error.ConflictingManagementSource;
        }
        return out;
    }
};

pub const AuditOutcome = enum(u8) {
    allowed = 1,
    denied = 2,
};

pub const PolicyDenialCode = enum(u8) {
    none = 0,
    invalid_token_audience = 1,
    id_token_not_permitted = 2,
    unknown_or_revoked_jwks_key = 3,
    expired_credential = 4,
    identity_subject_collision = 5,
    conflicting_management_source = 6,
    local_restriction_override_denied = 7,
    stale_external_membership = 8,
    identity_provider_unavailable = 9,
    access_revoked = 10,
    delegation_attenuation_denied = 11,
    delegated_agent_cannot_approve = 12,
    separation_of_duties_violation = 13,
    protected_branch_direct_write_denied = 14,
    installation_prohibits_merge = 15,
    secret_scope_or_usage_denied = 16,
    workload_quota_exceeded = 17,
};

/// Credential- and payload-free access audit record (`Step 3`, `D3`).
pub const AccessAuditRecord = struct {
    audit_lsn: u64,
    timestamp_ns: i64,
    realm_id: u64,
    actor_principal: u64,
    subject_principal: u64,
    active_role: u64,
    issuer_id: u64,
    target_object: u64,
    branch_id: u64,
    policy_epoch: u64,
    outcome: AuditOutcome,
    denial_code: PolicyDenialCode,
    request_context_digest: [32]u8,

    pub fn containsRawCredentialsOrPayloads(_: AccessAuditRecord) bool {
        return false;
    }
};

pub const AccessAuditLog = struct {
    records: [max_audit_records]AccessAuditRecord = undefined,
    len: usize = 0,
    next_lsn: u64 = 1,

    pub fn append(
        self: *AccessAuditLog,
        ctx: AccessContext,
        timestamp_ns: i64,
        outcome: AuditOutcome,
        denial_code: PolicyDenialCode,
    ) !AccessAuditRecord {
        if (self.len >= max_audit_records) return error.AuditLogCapacityExceeded;
        const digest = try ctx.contextDigest();
        const rec: AccessAuditRecord = .{
            .audit_lsn = self.next_lsn,
            .timestamp_ns = timestamp_ns,
            .realm_id = ctx.realm_id,
            .actor_principal = ctx.actor_principal,
            .subject_principal = ctx.subject_principal,
            .active_role = ctx.active_role,
            .issuer_id = if (ctx.enterprise_binding) |eb| eb.issuer_id else 0,
            .target_object = ctx.target.target_object,
            .branch_id = ctx.target.branch_id,
            .policy_epoch = ctx.policy_epoch,
            .outcome = outcome,
            .denial_code = denial_code,
            .request_context_digest = digest,
        };
        self.records[self.len] = rec;
        self.len += 1;
        self.next_lsn += 1;
        return rec;
    }
};

pub const MembershipFreshnessGuard = struct {
    max_membership_staleness_ms: u64 = 60_000,
    idp_reachable: bool = true,
    current_policy_epoch: u64 = 1,

    /// Verifies current policy epoch, membership freshness watermark (distinct from JWT `exp`),
    /// and fail-closed IdP outage semantics (`Step 3`, `D3`, `P2`).
    pub fn verifyAccessAndFreshness(
        self: MembershipFreshnessGuard,
        ctx: AccessContext,
        now_ns: i64,
        audit_log: ?*AccessAuditLog,
    ) !void {
        try ctx.validate();
        if (ctx.service_transport_principal != null and ctx.subject_principal == 0) {
            return error.ServiceCredentialAmplificationForbidden;
        }
        if (ctx.policy_epoch < self.current_policy_epoch) {
            if (audit_log) |log| _ = try log.append(ctx, now_ns, .denied, .access_revoked);
            return error.AccessRevoked;
        }
        if (ctx.enterprise_binding) |eb| {
            if (now_ns >= eb.token_expires_at_ns) {
                if (audit_log) |log| _ = try log.append(ctx, now_ns, .denied, .expired_credential);
                return error.ExpiredCredential;
            }
            if (eb.management_source != .native_local) {
                const age_ns = now_ns - eb.membership_verified_at_ns;
                const max_stale_ns: i64 = @intCast(self.max_membership_staleness_ms * std.time.ns_per_ms);
                if (age_ns > max_stale_ns) {
                    if (!self.idp_reachable) {
                        if (audit_log) |log| _ = try log.append(ctx, now_ns, .denied, .identity_provider_unavailable);
                        return error.IdentityProviderUnavailable;
                    }
                    if (audit_log) |log| _ = try log.append(ctx, now_ns, .denied, .stale_external_membership);
                    return error.StaleExternalMembership;
                }
            }
        }
        if (audit_log) |log| _ = try log.append(ctx, now_ns, .allowed, .none);
    }

    /// Offboards a principal or revokes external membership, synchronously advancing `policy_epoch`.
    pub fn offboardAndAdvanceEpoch(
        self: *MembershipFreshnessGuard,
        directory: *PrincipalBindingDirectory,
        principal_id: u64,
    ) !u64 {
        try directory.retirePrincipal(principal_id);
        self.current_policy_epoch += 1;
        return self.current_policy_epoch;
    }
};

fn hashU64(hasher: *std.crypto.hash.sha2.Sha256, val: u64) void {
    var buf: [8]u8 = undefined;
    std.mem.writeInt(u64, &buf, val, .little);
    hasher.update(&buf);
}
