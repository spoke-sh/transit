//! Declarative HTTP/WebSocket ingress, OAuth 2.1 / OIDC identity federation,
//! browser session boundary (`__Host-` cookies, `Origin`/`Sec-Fetch-Site`),
//! and inbound webhook admission composed over `AccessAndIdentity` (`ACTX1`, `IDF1`),
//! `DelegationAndSecrets` (`SEC1`, `OauthChallengeGame`, `WebhookAdmissionEngine`),
//! and `PublishedProjection` (`PBR1`, `DisclosurePolicy`, `WatermarkReactiveWatchSession`).
const std = @import("std");
const c = @import("root.zig");
const AccessAndIdentity = c.AccessAndIdentity;
const DelegationAndSecrets = c.DelegationAndSecrets;
const PublishedResource = c.PublishedResource;
const DisclosurePolicy = c.DisclosurePolicy;
const InvestigationBasis = c.InvestigationBasis;
const Attribution = c.Attribution;
const PublishedProjection = c.PublishedProjection;

pub const max_identity_providers: usize = 16;
pub const max_active_challenges: usize = 64;
pub const max_external_identities: usize = 64;
pub const max_browser_sessions: usize = 64;
pub const bootstrap_owner_principal_id: u64 = 1;

pub const HttpMethod = enum(u8) {
    get = 1,
    post = 2,
};

pub const HeaderPair = struct {
    name: []const u8,
    value: []const u8,
};

/// Declarative browser and webhook HTTP boundary policy (`SERVING_V1`, `REACTIVE_V1`, `CONTROL_POLICY_PLANE_V1`).
/// Enforces exact `public_origin`, `Host` authority, `Origin` / `Sec-Fetch-Site`,
/// `__Host-` cookie attributes, duplicate header/cookie rejection, and rejection
/// of ambient `Authorization` or `X-Transit-Principal` headers.
pub const InboundBoundaryPolicy = struct {
    public_origin: []const u8,
    authority: []const u8,
    secure_https: bool,
    development_loopback: bool,
    trusted_tls_termination: bool = false,

    pub fn init(
        public_origin: []const u8,
        development_loopback: bool,
        trusted_tls_termination: bool,
    ) !InboundBoundaryPolicy {
        if (public_origin.len == 0 or public_origin.len > 256) return error.InvalidPublicOrigin;
        const uri = std.Uri.parse(public_origin) catch return error.InvalidPublicOrigin;
        if (uri.user != null or uri.password != null or uri.query != null or uri.fragment != null) {
            return error.InvalidPublicOrigin;
        }
        const path = switch (uri.path) {
            .raw => |r| r,
            .percent_encoded => |p| p,
        };
        if (path.len != 0 and !std.mem.eql(u8, path, "/")) return error.InvalidPublicOrigin;
        if (public_origin[public_origin.len - 1] == '/') return error.InvalidPublicOrigin;

        const host = if (uri.host) |h| switch (h) {
            .raw => |r| r,
            .percent_encoded => |p| p,
        } else return error.InvalidPublicOrigin;
        if (host.len == 0) return error.InvalidPublicOrigin;

        const secure_https = if (std.mem.eql(u8, uri.scheme, "https"))
            true
        else if (std.mem.eql(u8, uri.scheme, "http") and development_loopback and isLoopbackHost(host))
            false
        else
            return error.InvalidPublicOrigin;

        if (secure_https and !trusted_tls_termination) {
            return error.UntrustedTlsTermination;
        }

        const scheme_sep = std.mem.indexOf(u8, public_origin, "://") orelse return error.InvalidPublicOrigin;
        return .{
            .public_origin = public_origin,
            .authority = public_origin[scheme_sep + 3 ..],
            .secure_https = secure_https,
            .development_loopback = development_loopback,
            .trusted_tls_termination = trusted_tls_termination,
        };
    }

    pub fn sessionCookieName(self: InboundBoundaryPolicy) []const u8 {
        return if (self.secure_https) "__Host-transit_session" else "transit_session";
    }

    pub fn loginCookieName(self: InboundBoundaryPolicy) []const u8 {
        return if (self.secure_https) "__Host-transit_login" else "transit_login";
    }

    pub fn formatSetCookieHeader(
        self: InboundBoundaryPolicy,
        allocator: std.mem.Allocator,
        cookie_name: []const u8,
        cookie_value: []const u8,
        max_age_seconds: u32,
    ) ![]u8 {
        const flags = if (self.secure_https)
            "Path=/; HttpOnly; SameSite=Lax; Secure"
        else
            "Path=/; HttpOnly; SameSite=Lax";
        return std.fmt.allocPrint(
            allocator,
            "{s}={s}; Max-Age={d}; {s}",
            .{ cookie_name, cookie_value, max_age_seconds, flags },
        );
    }

    /// Validates browser/gateway request headers for Host, TLS forwarding, Origin,
    /// Sec-Fetch-Site, and absence of ambient bearer/principal headers.
    pub fn verifyBrowserRequest(
        self: InboundBoundaryPolicy,
        method: HttpMethod,
        headers: []const HeaderPair,
        is_websocket_upgrade: bool,
        is_cross_site_oauth_callback: bool,
    ) !void {
        if ((try uniqueHeaderValue(headers, "authorization")) != null or
            (try uniqueHeaderValue(headers, "x-transit-principal")) != null)
        {
            return error.AmbientAuthHeaderForbidden;
        }
        const host = (try uniqueHeaderValue(headers, "host")) orelse return error.InvalidHostHeader;
        if (!std.ascii.eqlIgnoreCase(host, self.authority)) return error.InvalidHostHeader;

        if (self.secure_https) {
            if (!self.trusted_tls_termination) return error.UntrustedTlsTermination;
            const proto = (try uniqueHeaderValue(headers, "x-forwarded-proto")) orelse return error.InsecureForwardedProto;
            if (!std.ascii.eqlIgnoreCase(std.mem.trim(u8, proto, " \t"), "https")) {
                return error.InsecureForwardedProto;
            }
        }

        const origin = try uniqueHeaderValue(headers, "origin");
        const fetch_site = try uniqueHeaderValue(headers, "sec-fetch-site");

        if (method == .post or is_websocket_upgrade) {
            const orig = origin orelse return error.InvalidOriginHeader;
            if (!std.mem.eql(u8, orig, self.public_origin)) return error.InvalidOriginHeader;
            if (fetch_site) |site| {
                if (!std.ascii.eqlIgnoreCase(site, "same-origin")) return error.CrossSiteRequestForbidden;
            }
            return;
        }

        if (origin) |orig| {
            if (!std.mem.eql(u8, orig, self.public_origin)) return error.InvalidOriginHeader;
        } else if (!is_cross_site_oauth_callback) {
            const site = fetch_site orelse return error.MissingOriginOrFetchSite;
            if (!std.ascii.eqlIgnoreCase(site, "same-origin")) return error.CrossSiteRequestForbidden;
        }
    }

    pub fn extractUniqueCookie(headers: []const HeaderPair, cookie_name: []const u8) !?[]const u8 {
        var found: ?[]const u8 = null;
        for (headers) |hdr| {
            if (!std.ascii.eqlIgnoreCase(hdr.name, "cookie")) continue;
            var parts = std.mem.splitScalar(u8, hdr.value, ';');
            while (parts.next()) |raw_part| {
                const part = std.mem.trim(u8, raw_part, " \t");
                if (part.len == 0) continue;
                const eq_idx = std.mem.indexOfScalar(u8, part, '=') orelse return error.MalformedCookieHeader;
                const name = std.mem.trim(u8, part[0..eq_idx], " \t");
                const val = std.mem.trim(u8, part[eq_idx + 1 ..], " \t");
                if (!std.mem.eql(u8, name, cookie_name)) continue;
                if (val.len == 0 or found != null) return error.DuplicateOrEmptyCookie;
                found = val;
            }
        }
        return found;
    }
};

pub const SubjectVerificationMode = enum(u8) {
    /// OIDC 1.0 RS256 signed `id_token` verified against catalog `OidcIssuerProfile` (`IDF1`) and `JwksKeyring`.
    oidc_rs256_id_token = 1,
    /// OAuth 2.1 + PKCE `S256` token exchange followed by JSON user profile subject extraction (e.g., GitHub `/user`).
    oauth2_user_profile_json = 2,
    /// OAuth 2.1 + PKCE `S256` token exchange with `appsecret_proof = HMAC-SHA256(client_secret, access_token)`
    /// and `/debug_token` app/user binding verification (e.g., Facebook Graph).
    oauth2_appsecret_proof_debug = 3,
};

/// Catalog-declared identity provider profile (`IDF1` + `SEC1`) supporting generic
/// OIDC RS256, OAuth2 user-profile JSON, and OAuth2 `appsecret_proof` + `debug_token` flows.
pub const IdentityProviderDeclaration = struct {
    provider_name: []const u8,
    issuer_profile: AccessAndIdentity.OidcIssuerProfile,
    verification_mode: SubjectVerificationMode,
    client_id: []const u8,
    client_secret_id: u64,
    authorize_endpoint: []const u8,
    token_endpoint: []const u8,
    userinfo_endpoint: []const u8,
    debug_token_endpoint: ?[]const u8 = null,
    scopes_space_separated: []const u8,
    cached_jwks_json: ?[]const u8 = null,

    pub fn validate(self: IdentityProviderDeclaration, allow_loopback_http: bool) !void {
        if (self.provider_name.len == 0 or self.provider_name.len > 64) return error.InvalidIdentityProviderProfile;
        if (self.client_id.len == 0 or self.client_id.len > 256 or self.client_secret_id == 0) {
            return error.InvalidIdentityProviderProfile;
        }
        if (self.issuer_profile.magic != AccessAndIdentity.magic_idf1 or
            self.issuer_profile.issuer_id == 0 or
            self.issuer_profile.realm_id == 0)
        {
            return error.InvalidIdentityProviderProfile;
        }
        try validateEndpointUrl(self.authorize_endpoint, allow_loopback_http);
        try validateEndpointUrl(self.token_endpoint, allow_loopback_http);
        try validateEndpointUrl(self.userinfo_endpoint, allow_loopback_http);
        if (self.debug_token_endpoint) |dbg| {
            try validateEndpointUrl(dbg, allow_loopback_http);
        }
        if (self.verification_mode == .oauth2_appsecret_proof_debug and self.debug_token_endpoint == null) {
            return error.InvalidIdentityProviderProfile;
        }
    }

    pub fn callbackPath(self: IdentityProviderDeclaration, buf: []u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "/auth/{s}/callback", .{self.provider_name});
    }

    pub fn buildAuthorizationRedirectUrl(
        self: IdentityProviderDeclaration,
        allocator: std.mem.Allocator,
        boundary: InboundBoundaryPolicy,
        state: []const u8,
        pkce_challenge_s256: [43]u8,
        nonce: []const u8,
    ) ![]u8 {
        var out: std.ArrayListUnmanaged(u8) = .empty;
        errdefer out.deinit(allocator);

        var redirect_buf: [384]u8 = undefined;
        const redirect_uri = try std.fmt.bufPrint(
            &redirect_buf,
            "{s}/auth/{s}/callback",
            .{ boundary.public_origin, self.provider_name },
        );

        try out.appendSlice(allocator, self.authorize_endpoint);
        try out.appendSlice(allocator, "?response_type=code&client_id=");
        try appendUriComponent(allocator, &out, self.client_id);
        try out.appendSlice(allocator, "&redirect_uri=");
        try appendUriComponent(allocator, &out, redirect_uri);
        try out.appendSlice(allocator, "&scope=");
        try appendUriComponent(allocator, &out, self.scopes_space_separated);
        try out.appendSlice(allocator, "&state=");
        try appendUriComponent(allocator, &out, state);
        try out.appendSlice(allocator, "&code_challenge=");
        try appendUriComponent(allocator, &out, &pkce_challenge_s256);
        try out.appendSlice(allocator, "&code_challenge_method=S256");
        if (self.verification_mode == .oidc_rs256_id_token) {
            try out.appendSlice(allocator, "&nonce=");
            try appendUriComponent(allocator, &out, nonce);
        }
        return out.toOwnedSlice(allocator);
    }

    /// Computes Facebook/Meta `appsecret_proof = HEX_LOWER(HMAC_SHA256(client_secret, access_token))`
    /// using the resolved catalog secret material (`SEC1`).
    pub fn computeAppSecretProofHex(client_secret: []const u8, access_token: []const u8) [64]u8 {
        var mac: [32]u8 = undefined;
        var hmac = std.crypto.auth.hmac.sha2.HmacSha256.init(client_secret);
        hmac.update(access_token);
        hmac.final(&mac);
        return std.fmt.bytesToHex(mac, .lower);
    }

    /// Deterministically verifies the provider's token & identity payloads according to
    /// `self.verification_mode` and returns an owned copy of the verified external subject.
    pub fn verifyProviderExchangePayloads(
        self: IdentityProviderDeclaration,
        allocator: std.mem.Allocator,
        token_response_json: []const u8,
        userinfo_response_json: ?[]const u8,
        debug_token_response_json: ?[]const u8,
        expected_nonce: []const u8,
        now_epoch_s: i64,
    ) ![]u8 {
        const token_parsed = std.json.parseFromSlice(std.json.Value, allocator, token_response_json, .{}) catch return error.InvalidProviderTokenResponse;
        defer token_parsed.deinit();
        if (token_parsed.value != .object) return error.InvalidProviderTokenResponse;
        const tok_obj = token_parsed.value.object;
        if (tok_obj.get("error") != null) return error.ProviderTokenExchangeRejected;

        switch (self.verification_mode) {
            .oidc_rs256_id_token => {
                const id_token_val = tok_obj.get("id_token") orelse return error.MissingOidcIdToken;
                if (id_token_val != .string or id_token_val.string.len == 0) return error.MissingOidcIdToken;
                const jwks = self.cached_jwks_json orelse return error.MissingCatalogJwksSnapshot;
                return self.issuer_profile.verifySignedJwtRs256(
                    allocator,
                    id_token_val.string,
                    jwks,
                    expected_nonce,
                    now_epoch_s,
                    false,
                );
            },
            .oauth2_user_profile_json => {
                _ = try extractBearerAccessToken(tok_obj);
                const profile_json = userinfo_response_json orelse return error.MissingProviderUserInfo;
                return parseJsonSubjectId(allocator, profile_json);
            },
            .oauth2_appsecret_proof_debug => {
                _ = try extractBearerAccessToken(tok_obj);
                const profile_json = userinfo_response_json orelse return error.MissingProviderUserInfo;
                const debug_json = debug_token_response_json orelse return error.MissingProviderDebugToken;
                const subject = try parseJsonSubjectId(allocator, profile_json);
                errdefer allocator.free(subject);
                try verifyDebugTokenPayload(allocator, debug_json, self.client_id, subject);
                return subject;
            },
        }
    }
};

pub const IssuedLoginChallenge = struct {
    challenge_id: u64,
    provider_name: []const u8,
    issuer_id: u64,
    state_token: [43]u8,
    login_cookie_token: [43]u8,
    pkce_code_verifier: [43]u8,
    pkce_code_challenge_s256: [43]u8,
    nonce_token: [43]u8,
    issued_at_ns: i64,
    expires_at_ns: i64,
    consumed: bool = false,
};

pub const ClaimedCallbackExchange = struct {
    challenge_id: u64,
    provider_name: []const u8,
    issuer_id: u64,
    pkce_code_verifier: [43]u8,
    nonce_token: [43]u8,
    outbox_intent: DelegationAndSecrets.TokenExchangeOutboxIntent,
    sealed_secret_handle: DelegationAndSecrets.SealedSecretHandle,
};

pub const ExternalIdentityRecord = struct {
    identity_id: u64,
    issuer_id: u64,
    provider_name: []const u8,
    subject_digest: [32]u8,
    external_identity_hash: [32]u8,
    disabled: bool = false,
    created_at_ns: i64,
    last_login_at_ns: i64,
};

pub const BrowserSessionRecord = struct {
    session_id: u64,
    session_token_digest: [32]u8,
    identity_id: u64,
    issued_at_ns: i64,
    expires_at_ns: i64,
    revoked: bool = false,
};

pub const SessionStatusView = struct {
    authenticated: bool,
    provider_name: ?[]const u8 = null,
    identity_id: ?u64 = null,
    bound: bool = false,
    principal_id: ?u64 = null,
    policy_epoch: u64,

    pub fn formatJson(self: SessionStatusView, allocator: std.mem.Allocator) ![]u8 {
        if (!self.authenticated) {
            return std.fmt.allocPrint(allocator, "{{\"authenticated\":false}}", .{});
        }
        return std.fmt.allocPrint(
            allocator,
            "{{\"authenticated\":true,\"provider\":\"{s}\",\"identity\":\"{d}\",\"bound\":{s}}}",
            .{
                self.provider_name orelse "",
                self.identity_id orelse 0,
                if (self.bound) "true" else "false",
            },
        );
    }
};

/// Declarative browser challenge, external identity, and session ledger composed over
/// `OauthChallengeGame`, `PrincipalBindingDirectory`, and `MembershipFreshnessGuard`.
pub const BrowserSessionLedger = struct {
    realm_id: u64,
    challenge_ttl_ns: i64 = 300 * std.time.ns_per_s,
    session_ttl_ns: i64 = 3600 * std.time.ns_per_s,

    challenges: [max_active_challenges]IssuedLoginChallenge = undefined,
    challenges_len: usize = 0,
    next_challenge_id: u64 = 1,

    challenge_game: DelegationAndSecrets.OauthChallengeGame = .{},

    identities: [max_external_identities]ExternalIdentityRecord = undefined,
    identities_len: usize = 0,
    next_identity_id: u64 = 1,

    sessions: [max_browser_sessions]BrowserSessionRecord = undefined,
    sessions_len: usize = 0,
    next_session_id: u64 = 1,

    /// Computes the canonical external identity hash:
    /// `SHA256("transit.browser.identity.v1\x00" || provider_name || "\x00" || client_id || "\x00" || external_subject)`.
    pub fn externalIdentityHash(
        provider_name: []const u8,
        client_id: []const u8,
        external_subject: []const u8,
    ) [32]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update("transit.browser.identity.v1\x00");
        hasher.update(provider_name);
        hasher.update("\x00");
        hasher.update(client_id);
        hasher.update("\x00");
        hasher.update(external_subject);
        return hasher.finalResult();
    }

    pub fn tokenDigest(raw_token: []const u8) [32]u8 {
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(raw_token, &digest, .{});
        return digest;
    }

    /// Reclaims expired or consumed challenges and expired/revoked sessions so
    /// unauthenticated traffic cannot exhaust fixed-capacity tables.
    pub fn reclaimExpiredState(self: *BrowserSessionLedger, now_ns: i64) void {
        var ch_write: usize = 0;
        for (0..self.challenges_len) |idx| {
            const ch = self.challenges[idx];
            if (!ch.consumed and ch.expires_at_ns >= now_ns) {
                self.challenges[ch_write] = ch;
                ch_write += 1;
            }
        }
        self.challenges_len = ch_write;

        var sess_write: usize = 0;
        for (0..self.sessions_len) |idx| {
            const s = self.sessions[idx];
            if (!s.revoked and s.expires_at_ns > now_ns) {
                self.sessions[sess_write] = s;
                sess_write += 1;
            }
        }
        self.sessions_len = sess_write;
    }

    /// Issues a browser-cookie-bound OAuth 2.1 + PKCE `S256` challenge.
    pub fn beginLoginChallenge(
        self: *BrowserSessionLedger,
        provider: IdentityProviderDeclaration,
        entropy_seed: [32]u8,
        now_ns: i64,
    ) !IssuedLoginChallenge {
        self.reclaimExpiredState(now_ns);
        if (self.challenges_len >= max_active_challenges) {
            return error.ChallengeCapacityExceeded;
        }
        const challenge_id = self.next_challenge_id;
        self.next_challenge_id += 1;

        const state_token = deriveBase64UrlToken(entropy_seed, "state", challenge_id);
        const login_cookie_token = deriveBase64UrlToken(entropy_seed, "cookie", challenge_id);
        const pkce_verifier = deriveBase64UrlToken(entropy_seed, "pkce", challenge_id);
        const nonce_token = deriveBase64UrlToken(entropy_seed, "nonce", challenge_id);
        const pkce_challenge = try DelegationAndSecrets.OauthChallengeGame.computePkceS256Challenge(&pkce_verifier);

        const issued: IssuedLoginChallenge = .{
            .challenge_id = challenge_id,
            .provider_name = provider.provider_name,
            .issuer_id = provider.issuer_profile.issuer_id,
            .state_token = state_token,
            .login_cookie_token = login_cookie_token,
            .pkce_code_verifier = pkce_verifier,
            .pkce_code_challenge_s256 = pkce_challenge,
            .nonce_token = nonce_token,
            .issued_at_ns = now_ns,
            .expires_at_ns = now_ns + self.challenge_ttl_ns,
        };
        self.challenges[self.challenges_len] = issued;
        self.challenges_len += 1;
        return issued;
    }

    /// Atomically verifies and claims the one-use browser login challenge BEFORE
    /// emitting a `TokenExchangeOutboxIntent` or resolving the provider client secret (`SEC1`).
    /// Parallel or replayed callbacks with the same `state` fail immediately with
    /// `OauthChallengeReplayDetected` or `OauthChallengeStateMismatch` before any network effect.
    pub fn claimLoginCallbackForExchange(
        self: *BrowserSessionLedger,
        provider: IdentityProviderDeclaration,
        secret: DelegationAndSecrets.SecretDeclaration,
        callback_state_token: []const u8,
        callback_login_cookie_token: []const u8,
        authorization_code: []const u8,
        connector_principal_id: u64,
        current_policy_epoch: u64,
        now_ns: i64,
    ) !ClaimedCallbackExchange {
        if (callback_state_token.len < 16 or callback_login_cookie_token.len < 16 or authorization_code.len == 0) {
            return error.InvalidOauthCallbackParameters;
        }
        var found_idx: ?usize = null;
        const callback_state_digest = tokenDigest(callback_state_token);
        for (0..self.challenges_len) |idx| {
            const ch = self.challenges[idx];
            if (std.crypto.timing_safe.eql([32]u8, tokenDigest(&ch.state_token), callback_state_digest)) {
                found_idx = idx;
                break;
            }
        }
        const idx = found_idx orelse return error.OauthChallengeStateMismatch;
        const ch = self.challenges[idx];
        if (!std.mem.eql(u8, ch.provider_name, provider.provider_name) or ch.issuer_id != provider.issuer_profile.issuer_id) {
            return error.OauthChallengeProviderMismatch;
        }

        const record: DelegationAndSecrets.OauthChallengeRecord = .{
            .challenge_id = ch.challenge_id,
            .secret_id = provider.client_secret_id,
            .principal_id = connector_principal_id,
            .state_digest = tokenDigest(&ch.state_token),
            .pkce_code_challenge_s256 = ch.pkce_code_challenge_s256,
            .browser_cookie_digest = tokenDigest(&ch.login_cookie_token),
            .nonce_digest = tokenDigest(&ch.nonce_token),
            .issued_at_ns = ch.issued_at_ns,
            .expires_at_ns = ch.expires_at_ns,
        };
        const records = [_]DelegationAndSecrets.OauthChallengeRecord{record};
        var code_hash_buf: [8]u8 = undefined;
        const code_digest = tokenDigest(authorization_code);
        @memcpy(&code_hash_buf, code_digest[0..8]);

        const outbox_intent = try self.challenge_game.evaluateCallbackTurn(&records, .{
            .callback_id = ch.challenge_id,
            .state_digest = callback_state_digest,
            .authorization_code_handle = std.mem.readInt(u64, &code_hash_buf, .little),
            .pkce_code_verifier = &ch.pkce_code_verifier,
            .browser_cookie_digest = tokenDigest(callback_login_cookie_token),
            .received_at_ns = now_ns,
        });
        self.challenges[idx].consumed = true;

        // Authorize outbound token-endpoint effect against catalog `SecretDeclaration` (`SEC1`):
        const connector_ctx: AccessAndIdentity.AccessContext = .{
            .realm_id = self.realm_id,
            .actor_principal = connector_principal_id,
            .actor_kind = .workload,
            .subject_principal = connector_principal_id,
            .subject_kind = .workload,
            .login_role = 1,
            .active_role = 1,
            .credential_epoch = 1,
            .policy_epoch = current_policy_epoch,
            .assurance_level = .aal3_hardware_cryptographic,
            .authenticated_at_ns = now_ns,
            .target = .{
                .audience = 1,
                .target_object = provider.client_secret_id,
                .branch_id = 1,
            },
        };
        const sealed_handle = try secret.resolveForDestination(
            connector_ctx,
            provider.token_endpoint,
            provider.client_id,
            true,
            current_policy_epoch,
            now_ns,
        );

        return .{
            .challenge_id = ch.challenge_id,
            .provider_name = ch.provider_name,
            .issuer_id = ch.issuer_id,
            .pkce_code_verifier = ch.pkce_code_verifier,
            .nonce_token = ch.nonce_token,
            .outbox_intent = outbox_intent,
            .sealed_secret_handle = sealed_handle,
        };
    }

    /// Completes the login turn after the connector's token exchange by verifying the
    /// provider subject, registering/checking the external identity, and minting a
    /// revocable browser session token.
    pub fn completeLoginAfterTokenExchange(
        self: *BrowserSessionLedger,
        allocator: std.mem.Allocator,
        provider: IdentityProviderDeclaration,
        claimed: ClaimedCallbackExchange,
        token_response_json: []const u8,
        userinfo_response_json: ?[]const u8,
        debug_token_response_json: ?[]const u8,
        session_entropy_seed: [32]u8,
        now_ns: i64,
    ) !struct { session_token: [43]u8, identity: ExternalIdentityRecord } {
        self.reclaimExpiredState(now_ns);
        if (provider.issuer_profile.issuer_id != claimed.issuer_id) {
            return error.OauthChallengeProviderMismatch;
        }
        const now_epoch_s: i64 = @divTrunc(now_ns, std.time.ns_per_s);
        const verified_subject = try provider.verifyProviderExchangePayloads(
            allocator,
            token_response_json,
            userinfo_response_json,
            debug_token_response_json,
            &claimed.nonce_token,
            now_epoch_s,
        );
        defer allocator.free(verified_subject);

        const subj_digest = AccessAndIdentity.PrincipalBindingDirectory.subjectDigest(
            provider.issuer_profile.issuer_id,
            verified_subject,
        );
        const ext_hash = externalIdentityHash(provider.provider_name, provider.client_id, verified_subject);

        var identity_idx: ?usize = null;
        for (0..self.identities_len) |idx| {
            if (self.identities[idx].issuer_id == provider.issuer_profile.issuer_id and
                std.crypto.timing_safe.eql([32]u8, self.identities[idx].subject_digest, subj_digest))
            {
                identity_idx = idx;
                break;
            }
        }

        const id_idx = if (identity_idx) |existing_idx| blk: {
            if (self.identities[existing_idx].disabled) return error.ExternalIdentityDisabled;
            self.identities[existing_idx].last_login_at_ns = now_ns;
            break :blk existing_idx;
        } else blk: {
            if (self.identities_len >= max_external_identities) return error.IdentityCapacityExceeded;
            const new_idx = self.identities_len;
            const identity_id = self.next_identity_id;
            self.next_identity_id += 1;
            self.identities[new_idx] = .{
                .identity_id = identity_id,
                .issuer_id = provider.issuer_profile.issuer_id,
                .provider_name = provider.provider_name,
                .subject_digest = subj_digest,
                .external_identity_hash = ext_hash,
                .disabled = false,
                .created_at_ns = now_ns,
                .last_login_at_ns = now_ns,
            };
            self.identities_len += 1;
            break :blk new_idx;
        };

        if (self.sessions_len >= max_browser_sessions) return error.SessionCapacityExceeded;
        const session_id = self.next_session_id;
        self.next_session_id += 1;
        const session_token = deriveBase64UrlToken(session_entropy_seed, "session", session_id);
        self.sessions[self.sessions_len] = .{
            .session_id = session_id,
            .session_token_digest = tokenDigest(&session_token),
            .identity_id = self.identities[id_idx].identity_id,
            .issued_at_ns = now_ns,
            .expires_at_ns = now_ns + self.session_ttl_ns,
            .revoked = false,
        };
        self.sessions_len += 1;

        return .{
            .session_token = session_token,
            .identity = self.identities[id_idx],
        };
    }

    /// Binds an external provider subject to a catalog principal in `PrincipalBindingDirectory`,
    /// forbidding binding to the local bootstrap owner (`bootstrap_owner_principal_id`).
    pub fn bindExternalSubjectToCatalogPrincipal(
        self: *const BrowserSessionLedger,
        directory: *AccessAndIdentity.PrincipalBindingDirectory,
        issuer_id: u64,
        external_subject: []const u8,
        principal_id: u64,
    ) !void {
        if (principal_id == bootstrap_owner_principal_id) {
            return error.BootstrapOwnerExternalBindingForbidden;
        }
        try directory.bindPrincipal(self.realm_id, issuer_id, external_subject, principal_id);
    }

    pub fn setExternalIdentityDisabled(
        self: *BrowserSessionLedger,
        issuer_id: u64,
        external_subject: []const u8,
        disabled: bool,
    ) !void {
        const subj_digest = AccessAndIdentity.PrincipalBindingDirectory.subjectDigest(issuer_id, external_subject);
        for (self.identities[0..self.identities_len]) |*id_rec| {
            if (id_rec.issuer_id == issuer_id and std.crypto.timing_safe.eql([32]u8, id_rec.subject_digest, subj_digest)) {
                id_rec.disabled = disabled;
                return;
            }
        }
        return error.UnknownExternalIdentity;
    }

    pub fn logoutSession(self: *BrowserSessionLedger, raw_session_token: []const u8) bool {
        if (raw_session_token.len < 16) return false;
        const digest = tokenDigest(raw_session_token);
        var revoked_any = false;
        for (self.sessions[0..self.sessions_len]) |*s| {
            if (std.crypto.timing_safe.eql([32]u8, s.session_token_digest, digest)) {
                s.revoked = true;
                revoked_any = true;
            }
        }
        return revoked_any;
    }

    /// Inspects the current browser session status (`authenticated`, `provider_name`, `identity_id`, `bound`).
    /// Unbound sessions (`bound == false`) are valid for `/auth/session` and `/auth/logout`
    /// but confer zero catalog or SQL permissions.
    pub fn inspectSession(
        self: *const BrowserSessionLedger,
        directory: *const AccessAndIdentity.PrincipalBindingDirectory,
        freshness_guard: AccessAndIdentity.MembershipFreshnessGuard,
        raw_session_token: ?[]const u8,
        now_ns: i64,
    ) SessionStatusView {
        const tok = raw_session_token orelse return .{
            .authenticated = false,
            .policy_epoch = freshness_guard.current_policy_epoch,
        };
        if (tok.len < 16) return .{
            .authenticated = false,
            .policy_epoch = freshness_guard.current_policy_epoch,
        };
        const digest = tokenDigest(tok);
        var matched_session: ?BrowserSessionRecord = null;
        for (self.sessions[0..self.sessions_len]) |s| {
            if (std.crypto.timing_safe.eql([32]u8, s.session_token_digest, digest)) {
                matched_session = s;
                break;
            }
        }
        const sess = matched_session orelse return .{
            .authenticated = false,
            .policy_epoch = freshness_guard.current_policy_epoch,
        };
        if (sess.revoked or now_ns >= sess.expires_at_ns) {
            return .{
                .authenticated = false,
                .policy_epoch = freshness_guard.current_policy_epoch,
            };
        }

        var matched_identity: ?ExternalIdentityRecord = null;
        for (self.identities[0..self.identities_len]) |id_rec| {
            if (id_rec.identity_id == sess.identity_id) {
                matched_identity = id_rec;
                break;
            }
        }
        const id_rec = matched_identity orelse return .{
            .authenticated = false,
            .policy_epoch = freshness_guard.current_policy_epoch,
        };
        if (id_rec.disabled) {
            return .{
                .authenticated = false,
                .policy_epoch = freshness_guard.current_policy_epoch,
            };
        }

        const resolved_principal: ?u64 = directory.resolvePrincipalByDigest(
            self.realm_id,
            id_rec.issuer_id,
            id_rec.subject_digest,
        ) catch null;

        return .{
            .authenticated = true,
            .provider_name = id_rec.provider_name,
            .identity_id = id_rec.identity_id,
            .bound = resolved_principal != null,
            .principal_id = resolved_principal,
            .policy_epoch = freshness_guard.current_policy_epoch,
        };
    }

    /// Resolves a browser session into a verified catalog `AccessContext` (`ACTX1`) and
    /// `DisclosurePolicy.CallerAccessContext` for evaluating bound `PublishedResource`s.
    /// Fails closed if the session is missing/expired/revoked, the external identity is
    /// disabled or unbound, or the catalog principal is locally restricted/retired at `current_policy_epoch`.
    pub fn resolveBoundSessionAccessContext(
        self: *const BrowserSessionLedger,
        directory: *const AccessAndIdentity.PrincipalBindingDirectory,
        freshness_guard: AccessAndIdentity.MembershipFreshnessGuard,
        raw_session_token: ?[]const u8,
        active_role: u64,
        target: AccessAndIdentity.TargetBinding,
        consumer_grants: []const DisclosurePolicy.ResourceConsumerGrant,
        caller_source_grants: c.HistoricalCatalog.GrantSet,
        now_ns: i64,
        audit_log: ?*AccessAndIdentity.AccessAuditLog,
    ) !struct {
        access_context: AccessAndIdentity.AccessContext,
        caller_access: DisclosurePolicy.CallerAccessContext,
    } {
        const tok = raw_session_token orelse return error.UnauthenticatedSession;
        if (tok.len < 16) return error.UnauthenticatedSession;
        const digest = tokenDigest(tok);

        var matched_session: ?BrowserSessionRecord = null;
        for (self.sessions[0..self.sessions_len]) |s| {
            if (std.crypto.timing_safe.eql([32]u8, s.session_token_digest, digest)) {
                matched_session = s;
                break;
            }
        }
        const sess = matched_session orelse return error.UnauthenticatedSession;
        if (sess.revoked or now_ns >= sess.expires_at_ns) return error.ExpiredOrRevokedSession;

        var matched_identity: ?ExternalIdentityRecord = null;
        for (self.identities[0..self.identities_len]) |id_rec| {
            if (id_rec.identity_id == sess.identity_id) {
                matched_identity = id_rec;
                break;
            }
        }
        const id_rec = matched_identity orelse return error.UnknownExternalIdentity;
        if (id_rec.disabled) return error.ExternalIdentityDisabled;

        const principal_id = try directory.resolvePrincipalByDigest(
            self.realm_id,
            id_rec.issuer_id,
            id_rec.subject_digest,
        );
        if (principal_id == bootstrap_owner_principal_id) {
            return error.BootstrapOwnerExternalBindingForbidden;
        }

        const actx: AccessAndIdentity.AccessContext = .{
            .realm_id = self.realm_id,
            .actor_principal = principal_id,
            .actor_kind = .human,
            .subject_principal = principal_id,
            .subject_kind = .human,
            .login_role = active_role,
            .active_role = active_role,
            .credential_epoch = sess.session_id,
            .policy_epoch = caller_source_grants.policy_epoch,
            .assurance_level = .aal2_multi_factor,
            .authenticated_at_ns = sess.issued_at_ns,
            .enterprise_binding = .{
                .issuer_id = id_rec.issuer_id,
                .external_subject_digest = id_rec.subject_digest,
                .management_source = .external_oidc_claim,
                .membership_verified_at_ns = id_rec.last_login_at_ns,
                .token_expires_at_ns = sess.expires_at_ns,
            },
            .target = target,
        };
        try freshness_guard.verifyAccessAndFreshness(actx, now_ns, audit_log);

        return .{
            .access_context = actx,
            .caller_access = .{
                .caller_principal = principal_id,
                .consumer_grants = consumer_grants,
                .caller_source_grants = caller_source_grants,
            },
        };
    }
};

fn isLoopbackHost(host: []const u8) bool {
    return std.mem.eql(u8, host, "127.0.0.1") or
        std.mem.eql(u8, host, "localhost") or
        std.mem.eql(u8, host, "::1") or
        std.mem.eql(u8, host, "[::1]");
}

fn uniqueHeaderValue(headers: []const HeaderPair, target_name: []const u8) !?[]const u8 {
    var found: ?[]const u8 = null;
    for (headers) |hdr| {
        if (!std.ascii.eqlIgnoreCase(hdr.name, target_name)) continue;
        const trimmed = std.mem.trim(u8, hdr.value, " \t");
        if (trimmed.len == 0 or found != null) return error.DuplicateOrEmptySecurityHeader;
        found = trimmed;
    }
    return found;
}

fn validateEndpointUrl(endpoint: []const u8, allow_loopback_http: bool) !void {
    if (endpoint.len == 0 or endpoint.len > 512) return error.InvalidEndpointUrl;
    const uri = std.Uri.parse(endpoint) catch return error.InvalidEndpointUrl;
    if (uri.user != null or uri.password != null or uri.fragment != null) return error.InvalidEndpointUrl;
    const host = if (uri.host) |h| switch (h) {
        .raw => |r| r,
        .percent_encoded => |p| p,
    } else return error.InvalidEndpointUrl;
    if (host.len == 0) return error.InvalidEndpointUrl;
    if (std.mem.eql(u8, uri.scheme, "https")) return;
    if (allow_loopback_http and std.mem.eql(u8, uri.scheme, "http") and isLoopbackHost(host)) return;
    return error.InsecureProviderEndpoint;
}

fn extractEndpointHost(endpoint: []const u8) ![]const u8 {
    const uri = std.Uri.parse(endpoint) catch return error.InvalidEndpointUrl;
    const host = if (uri.host) |h| switch (h) {
        .raw => |r| r,
        .percent_encoded => |p| p,
    } else return error.InvalidEndpointUrl;
    if (host.len == 0) return error.InvalidEndpointUrl;
    return host;
}

fn appendUriComponent(allocator: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), value: []const u8) !void {
    var pct_buf: [4]u8 = undefined;
    for (value) |ch| {
        if (std.ascii.isAlphanumeric(ch) or ch == '-' or ch == '.' or ch == '_' or ch == '~') {
            try out.append(allocator, ch);
        } else {
            const s_pct = try std.fmt.bufPrint(&pct_buf, "%{X:0>2}", .{ch});
            try out.appendSlice(allocator, s_pct);
        }
    }
}

fn deriveBase64UrlToken(seed: [32]u8, domain_label: []const u8, id: u64) [43]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update("transit.catalog.declarative-ingress.token.v1\x00");
    hasher.update(&seed);
    hasher.update(domain_label);
    var id_buf: [8]u8 = undefined;
    std.mem.writeInt(u64, &id_buf, id, .little);
    hasher.update(&id_buf);
    const digest = hasher.finalResult();
    var out: [43]u8 = undefined;
    _ = std.base64.url_safe_no_pad.Encoder.encode(&out, &digest);
    return out;
}

fn extractBearerAccessToken(tok_obj: std.json.ObjectMap) ![]const u8 {
    const token_val = tok_obj.get("access_token") orelse return error.MissingProviderAccessToken;
    if (token_val != .string or token_val.string.len == 0 or token_val.string.len > 4096) {
        return error.InvalidProviderAccessToken;
    }
    if (tok_obj.get("token_type")) |tt| {
        if (tt != .string or !std.ascii.eqlIgnoreCase(tt.string, "bearer")) {
            return error.UnsupportedProviderTokenType;
        }
    }
    return token_val.string;
}

fn parseJsonSubjectId(allocator: std.mem.Allocator, profile_json: []const u8) ![]u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, profile_json, .{}) catch return error.InvalidProviderUserInfo;
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidProviderUserInfo;
    const id_val = parsed.value.object.get("id") orelse return error.MissingProviderSubjectId;
    return switch (id_val) {
        .string => |s| {
            if (s.len == 0 or s.len > 255) return error.InvalidProviderSubjectId;
            return allocator.dupe(u8, s);
        },
        .integer => |n| {
            if (n <= 0) return error.InvalidProviderSubjectId;
            return std.fmt.allocPrint(allocator, "{d}", .{n});
        },
        else => error.InvalidProviderSubjectId,
    };
}

fn verifyDebugTokenPayload(
    allocator: std.mem.Allocator,
    debug_json: []const u8,
    expected_client_id: []const u8,
    expected_user_id: []const u8,
) !void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, debug_json, .{}) catch return error.InvalidProviderDebugToken;
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidProviderDebugToken;
    const data_val = parsed.value.object.get("data") orelse return error.InvalidProviderDebugToken;
    if (data_val != .object) return error.InvalidProviderDebugToken;
    const data_obj = data_val.object;

    const valid_val = data_obj.get("is_valid") orelse return error.ProviderDebugTokenInvalid;
    if (valid_val != .bool or !valid_val.bool) return error.ProviderDebugTokenInvalid;

    const app_val = data_obj.get("app_id") orelse return error.ProviderDebugTokenAppMismatch;
    if (app_val != .string or !std.mem.eql(u8, app_val.string, expected_client_id)) {
        return error.ProviderDebugTokenAppMismatch;
    }

    const user_val = data_obj.get("user_id") orelse return error.ProviderDebugTokenSubjectMismatch;
    const debug_user = switch (user_val) {
        .string => |s| try allocator.dupe(u8, s),
        .integer => |n| blk: {
            if (n <= 0) return error.ProviderDebugTokenSubjectMismatch;
            break :blk try std.fmt.allocPrint(allocator, "{d}", .{n});
        },
        else => return error.ProviderDebugTokenSubjectMismatch,
    };
    defer allocator.free(debug_user);

    if (!std.mem.eql(u8, debug_user, expected_user_id)) {
        return error.ProviderDebugTokenSubjectMismatch;
    }
}
