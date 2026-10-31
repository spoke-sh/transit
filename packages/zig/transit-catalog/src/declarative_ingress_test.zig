const std = @import("std");
const testing = std.testing;
const c = @import("root.zig");
const fuze = c.fuze;
const s = fuze.TableSchema;
const t = fuze.Types;
const v = t.Values;
const AccessAndIdentity = c.AccessAndIdentity;
const DelegationAndSecrets = c.DelegationAndSecrets;
const PublishedResource = c.PublishedResource;
const DisclosurePolicy = c.DisclosurePolicy;
const InvestigationBasis = c.InvestigationBasis;
const Attribution = c.Attribution;
const PublishedProjection = c.PublishedProjection;
const DeclarativeIngress = c.DeclarativeIngress;

const oidc_test_jwks =
    \\{"keys":[{"kty":"RSA","kid":"test-key","alg":"RS256","use":"sig","n":"z-v6Kd-uFG4QFWNiv220z_KLqwnimdLxDO5JXnDRXquzNzbirp6mEINGejHdPy6L0SaH52k-R1PcnbYbNMpdKQA9-ucMAjiR0hRZdu-Ie13Gzvxj9yDASNa6_fn3VQgm3l4CfSWh331oRWDMsxJQzp0X2nPbmkoQOEEbkIF-D4loxX1mS_Tbh05Tr_JG18NfH3Ru2cpRGkRKOzZjCFTxxadFbTJqeYcxPQ5eKgmJicgquKYtsDFu6Mo8CrgfNbCrtyFS_wgTPKPvnEzcMChpt_m-IiZ7VVNPYvt72svTZkF0OqMcEHUcIAXZ5x6w6Uss0CWTxgjnYbBwNKYYC0-M6w","e":"AQAB"}]}
;

const oidc_jwt_valid = "eyJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2V5In0.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzdGFibGUtMTIzIiwiYXVkIjoiY2xpZW50Iiwibm9uY2UiOiJub25jZSIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDAzNjAwfQ.HFBfYkJ28YCJyzqFlzYGovkHBSJ1IGyQ0nhWLY84xPhqcIM5vtg4EQNxLEFo5lvBik65zuAucDaWkHK64NdssV7TAt5tZpw7FAbcX0gcGP3TNVrJjBXFiTtg5IrOJrHVCf8Ba8brCCuSrPTpf2gvF25NC-watnFWm0NkjqOTIoFTOQeriVwVH8ITpOJHjz-T_cE7YFfXf53gr_gliQyuSQvCrLxq39S9PuYROWwnHUKgKC-FaAGShaXtqkHvHU0_ghopCSCRvV4wfvPy7znqAToVDIfchnA03H6cWWHYSEsa9goWg_aOM3-N1lmsou6vrUSCC9y47JWE0sLV5EU8zg";
const oidc_jwt_wrong_audience = "eyJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2V5In0.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzdGFibGUtMTIzIiwiYXVkIjoib3RoZXIiLCJub25jZSI6Im5vbmNlIiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjE3MDAwMDM2MDB9.l8rJ2UJrIqqLuK5FQDPCskmSSLg6Z9Mshmqft64TuRWNHYqSvFkYNFsNuAZ9Hc5_4uYl04QANcVXg7L35H9eUlW0d49IDElHTNNE7hcGV0j12rgwpyNyqBD9042KmQeP6ZCbQwClWOCuIprgE6qJWsyaRxaS1k5lpvtgt4NAw7iJvbJo-0nERJDHf1OdYgFQnFBDdQjxOFKkJpbsM23FWKPWD3ueVsRqi8Klsp2WwKemTjEU_w6GfHgopOpmcvwPipTUCEoIHVLixn3ozs1jipPzhJBnUJWfC9gkjeLi6qhEiirnTrToZ5Ki2X_IkWI-OwJqSKtfUQECoJd-_DN7OQ";
const oidc_jwt_wrong_nonce = "eyJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2V5In0.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzdGFibGUtMTIzIiwiYXVkIjoiY2xpZW50Iiwibm9uY2UiOiJvdGhlciIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDAzNjAwfQ.Tw4coAoVByJ6PVkadqIOnmDzL7ikBU8NuKkpBhmIgVB2Y9yXbWUIthnBaHH2fkVHgJrX5Jwxzh9NHKx2tRObTTMLTOq5yrSHEz3rVCPZfOCsfu_zVBemds85J11NUYZSW1rfZxp7gMjWju54b9r6TWWA3Czm3d_NCLuZUvQsMEayIN9lUAAeJjFqkJbmiJ-8rD5K_1EHQ5SqP-W2xG8Qns1sLsTBqTO8fhLzkG9dHX3a7mm5zQ0VOH1DaShzjno7YB8py4oFJWfouTmsCqulTVN8koXGLVpy-nTz4aXpZpwt7WgoybiAe_toQ3xP84ltPcwB66NhvEerrCaTWUANFA";
const oidc_jwt_wrong_issuer = "eyJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2V5In0.eyJpc3MiOiJodHRwczovL2V2aWwudGVzdCIsInN1YiI6InN0YWJsZS0xMjMiLCJhdWQiOiJjbGllbnQiLCJub25jZSI6Im5vbmNlIiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjE3MDAwMDM2MDB9.QDZ4lmDCJJx5LJ9aOQCXLkzClgriqre_w9F0P-dtvMoyfONayL_yWEFAW49GdN0kP3V8e8ZBexmng5tvVq5CxtMauX_2DbGMKcD5hK49Gp8m4dyXmxCpayIwNUpq03vh2FVCSaoLOjAUCLY4LILsrizEouSElCv54Vdwi81pBKKvMXqs3Y3ToxbBbGCqTapvku5zlrLYYLS43siqq9QR761z7wA7LfmsE7ZyMrEVDS5YVWwdv7SpEmRYHBbqJi0Hrewz2uIxr0-0NFKghw_yxkD61oQ6n7b7XOb5ocGgTmeO7P30SlDNszmcauFHxn50ENmNtgcclQjiL5hZqgHmVA";
const oidc_jwt_future = "eyJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2V5In0.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzdGFibGUtMTIzIiwiYXVkIjoiY2xpZW50Iiwibm9uY2UiOiJub25jZSIsImlhdCI6MTcwMDAwNTAwMCwiZXhwIjoxNzAwMDAzNjAwfQ.cDTyLehhexeV_i0TDOIktUkWTi5VPWRrQYgm9HOEQs_VjYtIt2-8kFy7svnq5O2IRK3rqmFOJ3_cdx7u8RG8uCgY_1WFZw-CS_3w-sVe_GrG0g8gWr93Jm6X5d_nBsneo6YZbT5AEBPcPk5WqYP61OHkRmcc_UUcwwKS0ppzhiKy2DXVF3PKf-k9HJrteWcQnMGIT6XIpIWr3QMOujqLv4cXWor_XkOY-wZeVZQqBeA2dwdKL1at8eP4ktihd4gRJz_HdswLYP-YKuAoj5lo-JhJhvgbM1z8SRvIsc0yyno6rWXmR0h2iMABr2Z5Y7_cpm7Ynwz0nBU7btLENrw0Ww";
const oidc_jwt_expired = "eyJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2V5In0.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzdGFibGUtMTIzIiwiYXVkIjoiY2xpZW50Iiwibm9uY2UiOiJub25jZSIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDAwMDEwfQ.vIfPWL-A0lDrehcEwMZGowsZBAvywVcHj3NTnDmZNyH8M6QdxqVxiGBOjHgq8MV2T8_oQ0n68Vg-hV2GUQp1QG5PP7s4bgYfzAfjfWsw4KET5HDzqKHP66Aw4b-AnXPRKPlY9ZwJ7hxsGDQ1pj5t-S2-EI2fh9eypjBTsQomXJw0t4ivUcPM0V8LHftrseZ2fXxo9dYz0t4gLRUM9SZh4Da7GjkFSufrwesr2d7Bp_MPAVwENu2JJkW-NroqdH8-2XEWkZjMVphrpFwu69kgMShrPOnsWn_8qdSKgCiUmOMBsPYN-QyHY8vpnNeYsT62qmmVAgRd1wrlOKB4sFefgw";
const oidc_jwt_azp = "eyJhbGciOiJSUzI1NiIsImtpZCI6InRlc3Qta2V5In0.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzdGFibGUtMTIzIiwiYXVkIjpbImNsaWVudCIsIm90aGVyIl0sIm5vbmNlIjoibm9uY2UiLCJpYXQiOjE3MDAwMDAwMDAsImV4cCI6MTcwMDAwMzYwMCwiYXpwIjoib3RoZXIifQ.hbgnxbc1Zjtq6a0IOvKKjUOHsHDHZLG-vUdrw_sQ-xgQiuUcmPlyJEaMAxlpbLI-VZhZQb2wcjSquM_1DT7dUyBRAGIPGtYvtMYioKaGw7wnCGw6b6UtJVOt81EeHKCh4lmD98HW4kSwjLNhNuQmgJA693r-QPFQtqLZjX8jI8EMuramDEYSZmVsNOor_cdVrsvdin5paoe4PWR3qHSlTdCBna81xq9x3BEN764zN9abpTTPFH5u6_Hb4mXErdypg4_iFH51fnWaTgWAOAlXqgmcpbbXEc5j-UHHocfPiNlfjRq87uQOV_HjJbOMtBrZB2Y3mKvfNOu9EjwvYkWrBA";
const oidc_jwt_unknown_kid = "eyJhbGciOiJSUzI1NiIsImtpZCI6InVua25vd24ifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzdGFibGUtMTIzIiwiYXVkIjoiY2xpZW50Iiwibm9uY2UiOiJub25jZSIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDAzNjAwfQ.CnsKfrdE0OIYYfpxRQlNJLuEYwoqLBkFstVx2_Q01nNlDzkXWG_BAQgTfBzE6on0ZMWb_l0a46NKgMjO33k5gBa91howfrjT5krThsRZwhlxTS1c5_VuAGjCvrBWEtRTyIr2cqzvm8lnMr50ca2xNUpalQwxHgd_BFtqMxIDbQL_eXjetgqWUY6UDid6cr5MAge3EMFs-c9O9a_akviDqBsgeMPcnO0DAMHk_4_041osGyv5HIcEuctm9gq0WMX3hWkPtBgFmReN7fNyBOlVjqwe3i7UfBKooWctxtrRgcYuXxmdtuth2EI3j3536U0pek8xNfUYbwPcHlV0bSs79w";
const oidc_jwt_algorithm = "eyJhbGciOiJIUzI1NiIsImtpZCI6InRlc3Qta2V5In0.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJzdWIiOiJzdGFibGUtMTIzIiwiYXVkIjoiY2xpZW50Iiwibm9uY2UiOiJub25jZSIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDAzNjAwfQ.PJ06RfvGycWs0LJrHfKwj2aLf6HPpyirfdKvL31QCRN38MrtITQugWORE7NblfW2OgELEYzEkcSISZI_dmpQESU_2vN4Ss4bQJudZ9Sof7qNbXvUCduOJrm6eQIt4s0a_ogOOAp0Q9eiOsp2G66IK2DiVz6ODu4Fb7MS1d7sVcztBadeOLL7eQ11nppKFf-5Pyu3VYTYb2J0HBjPRN10XH9XRafxfhG4xYUmSq54rHwqhIQNYIu7jgYU5qiEaqX59bEbYbnDW9MgcdnsR-MoBf_-QU-L5wLamHJ-7TfoP8Hx9ZuRrt4WwbkNKU98rDSSB4oNi60crdvsrpn7sAtJcA";

test "RS256 OIDC JWT verification against catalog OidcIssuerProfile and JWKS key lifecycle" {
    const allocator = testing.allocator;
    const active_keys = [_]AccessAndIdentity.JwksKeyRecord{
        .{
            .issuer_id = 301,
            .kid = "test-key",
            .key_epoch = 1,
            .state = .active,
            .expires_at_ns = 1_800_000_000 * std.time.ns_per_s,
        },
    };
    const audiences = [_][]const u8{"client"};
    const profile: AccessAndIdentity.OidcIssuerProfile = .{
        .issuer_id = 301,
        .realm_id = 1,
        .issuer_uri = "https://accounts.google.com",
        .expected_audiences = &audiences,
        .jwks_keys = &active_keys,
    };

    const sub = try profile.verifySignedJwtRs256(
        allocator,
        oidc_jwt_valid,
        oidc_test_jwks,
        "nonce",
        1_700_000_300,
        false,
    );
    defer allocator.free(sub);
    try testing.expectEqualStrings("stable-123", sub);

    // Negative controls: wrong audience, wrong nonce, wrong issuer, future iat, expired exp, wrong azp, unknown kid, HS256 alg
    const negative_tokens = [_][]const u8{
        oidc_jwt_wrong_audience,
        oidc_jwt_wrong_nonce,
        oidc_jwt_wrong_issuer,
        oidc_jwt_future,
        oidc_jwt_expired,
        oidc_jwt_azp,
        oidc_jwt_unknown_kid,
        oidc_jwt_algorithm,
    };
    for (negative_tokens) |bad_jwt| {
        if (profile.verifySignedJwtRs256(allocator, bad_jwt, oidc_test_jwks, "nonce", 1_700_000_300, false)) |unexpected| {
            allocator.free(unexpected);
            return error.InvalidOidcTokenAccepted;
        } else |_| {}
    }

    // Tampered signature byte must fail cryptographic verification:
    const tampered = try allocator.dupe(u8, oidc_jwt_valid);
    defer allocator.free(tampered);
    tampered[tampered.len - 30] = if (tampered[tampered.len - 30] == 'A') 'B' else 'A';
    try testing.expectError(
        error.InvalidOidcSignature,
        profile.verifySignedJwtRs256(allocator, tampered, oidc_test_jwks, "nonce", 1_700_000_300, false),
    );

    // Catalog key revocation (`JwksKeyState.revoked_or_retired`) must fail even when the RSA signature is valid:
    const revoked_keys = [_]AccessAndIdentity.JwksKeyRecord{
        .{
            .issuer_id = 301,
            .kid = "test-key",
            .key_epoch = 1,
            .state = .revoked_or_retired,
            .expires_at_ns = 1_800_000_000 * std.time.ns_per_s,
        },
    };
    var revoked_profile = profile;
    revoked_profile.jwks_keys = &revoked_keys;
    try testing.expectError(
        error.UnknownOrRevokedJwksKey,
        revoked_profile.verifySignedJwtRs256(allocator, oidc_jwt_valid, oidc_test_jwks, "nonce", 1_700_000_300, false),
    );
}

test "InboundBoundaryPolicy enforces HTTPS/loopback origins, Host, Origin, Sec-Fetch-Site, and __Host- cookies" {
    const allocator = testing.allocator;

    try testing.expectError(
        error.InvalidPublicOrigin,
        DeclarativeIngress.InboundBoundaryPolicy.init("http://app.example.test", true, false),
    );
    try testing.expectError(
        error.InvalidPublicOrigin,
        DeclarativeIngress.InboundBoundaryPolicy.init("https://app.example.test/subpath", false, true),
    );
    try testing.expectError(
        error.UntrustedTlsTermination,
        DeclarativeIngress.InboundBoundaryPolicy.init("https://app.example.test", false, false),
    );

    const https_boundary = try DeclarativeIngress.InboundBoundaryPolicy.init("https://app.example.test:8443", false, true);
    try testing.expectEqualStrings("__Host-transit_session", https_boundary.sessionCookieName());
    try testing.expectEqualStrings("__Host-transit_login", https_boundary.loginCookieName());

    const set_cookie = try https_boundary.formatSetCookieHeader(allocator, https_boundary.sessionCookieName(), "tok123", 3600);
    defer allocator.free(set_cookie);
    try testing.expect(std.mem.indexOf(u8, set_cookie, "__Host-transit_session=tok123; Max-Age=3600; Path=/; HttpOnly; SameSite=Lax; Secure") != null);

    // HTTPS boundary requires X-Forwarded-Proto: https and matching Host + Origin:
    try testing.expectError(
        error.InsecureForwardedProto,
        https_boundary.verifyBrowserRequest(.get, &.{
            .{ .name = "Host", .value = "app.example.test:8443" },
            .{ .name = "Origin", .value = "https://app.example.test:8443" },
        }, false, false),
    );
    try https_boundary.verifyBrowserRequest(.post, &.{
        .{ .name = "Host", .value = "app.example.test:8443" },
        .{ .name = "X-Forwarded-Proto", .value = "https" },
        .{ .name = "Origin", .value = "https://app.example.test:8443" },
        .{ .name = "Sec-Fetch-Site", .value = "same-origin" },
    }, false, false);

    // Ambient Authorization header is rejected:
    try testing.expectError(
        error.AmbientAuthHeaderForbidden,
        https_boundary.verifyBrowserRequest(.get, &.{
            .{ .name = "Host", .value = "app.example.test:8443" },
            .{ .name = "X-Forwarded-Proto", .value = "https" },
            .{ .name = "Origin", .value = "https://app.example.test:8443" },
            .{ .name = "Authorization", .value = "Bearer secret" },
        }, false, false),
    );

    // Duplicate cookies are rejected:
    try testing.expectError(
        error.DuplicateOrEmptyCookie,
        DeclarativeIngress.InboundBoundaryPolicy.extractUniqueCookie(&.{
            .{ .name = "Cookie", .value = "__Host-transit_session=a; __Host-transit_session=b" },
        }, "__Host-transit_session"),
    );
}

test "3-provider declarative OAuth/OIDC challenge lifecycle, single-use claim before effect, and webhook HMAC admission" {
    const allocator = testing.allocator;
    const now_ns: i64 = 1_700_000_300 * std.time.ns_per_s;

    const github_provider: DeclarativeIngress.IdentityProviderDeclaration = .{
        .provider_name = "github",
        .issuer_profile = .{
            .issuer_id = 302,
            .realm_id = 1,
            .issuer_uri = "https://github.com",
            .expected_audiences = &.{"gh-client-id"},
        },
        .verification_mode = .oauth2_user_profile_json,
        .client_id = "gh-client-id",
        .client_secret_id = 9002,
        .authorize_endpoint = "https://github.com/login/oauth/authorize",
        .token_endpoint = "https://github.com/login/oauth/access_token",
        .userinfo_endpoint = "https://api.github.com/user",
        .scopes_space_separated = "read:user",
    };
    try github_provider.validate(false);

    const fb_provider: DeclarativeIngress.IdentityProviderDeclaration = .{
        .provider_name = "facebook",
        .issuer_profile = .{
            .issuer_id = 303,
            .realm_id = 1,
            .issuer_uri = "https://www.facebook.com",
            .expected_audiences = &.{"fb-client-id"},
        },
        .verification_mode = .oauth2_appsecret_proof_debug,
        .client_id = "fb-client-id",
        .client_secret_id = 9003,
        .authorize_endpoint = "https://www.facebook.com/v23.0/dialog/oauth",
        .token_endpoint = "https://graph.facebook.com/v23.0/oauth/access_token",
        .userinfo_endpoint = "https://graph.facebook.com/v23.0/me",
        .debug_token_endpoint = "https://graph.facebook.com/debug_token",
        .scopes_space_separated = "public_profile",
    };
    try fb_provider.validate(false);

    const gh_secret: DelegationAndSecrets.SecretDeclaration = .{
        .secret_id = 9002,
        .name = "sec.github_oauth_client",
        .kind = .oauth2_bearer,
        .provider = .oauth2_authorization_code_pkce,
        .provider_ref = "vault://oauth/github",
        .scope_prefixes = &.{"https://github.com/login/oauth/"},
        .expected_audience = "gh-client-id",
        .lease_state = .active_lease,
        .lease_expires_at_ns = now_ns + 86_400 * std.time.ns_per_s,
        .usage_granted_principals = &.{777},
        .policy_epoch = 1,
    };

    var ledger: DeclarativeIngress.BrowserSessionLedger = .{ .realm_id = 1 };
    const seed_1: [32]u8 = @splat(0x11);
    const challenge = try ledger.beginLoginChallenge(github_provider, seed_1, now_ns);

    // 1. Cross-browser callback with wrong login cookie fails WITHOUT consuming the challenge:
    const wrong_cookie: [43]u8 = @splat('X');
    try testing.expectError(
        error.OauthBrowserCookieMismatch,
        ledger.claimLoginCallbackForExchange(
            github_provider,
            gh_secret,
            &challenge.state_token,
            &wrong_cookie,
            "gh-code-1",
            777,
            1,
            now_ns + 5 * std.time.ns_per_s,
        ),
    );

    // 2. Valid browser callback claims the challenge and emits a TokenExchangeOutboxIntent:
    const claimed = try ledger.claimLoginCallbackForExchange(
        github_provider,
        gh_secret,
        &challenge.state_token,
        &challenge.login_cookie_token,
        "gh-code-1",
        777,
        1,
        now_ns + 5 * std.time.ns_per_s,
    );
    try testing.expectEqual(challenge.challenge_id, claimed.outbox_intent.challenge_id);

    // 3. Replaying the same callback state fails BEFORE any second token exchange intent can be emitted:
    try testing.expectError(
        error.OauthChallengeReplayDetected,
        ledger.claimLoginCallbackForExchange(
            github_provider,
            gh_secret,
            &challenge.state_token,
            &challenge.login_cookie_token,
            "gh-code-1",
            777,
            1,
            now_ns + 6 * std.time.ns_per_s,
        ),
    );

    // 4. Complete GitHub login (numeric JSON subject `"id": 424242`) and verify Facebook `appsecret_proof` + `debug_token`:
    const gh_login = try ledger.completeLoginAfterTokenExchange(
        allocator,
        github_provider,
        claimed,
        "{\"access_token\":\"ghs_tok_123\",\"token_type\":\"bearer\"}",
        "{\"id\":424242,\"login\":\"octocat\"}",
        null,
        @splat(0x22),
        now_ns + 5 * std.time.ns_per_s,
    );
    try testing.expectEqual(@as(u64, 1), gh_login.identity.identity_id);

    const fb_proof = DeclarativeIngress.IdentityProviderDeclaration.computeAppSecretProofHex("fb-secret-key", "fb_access_1");
    try testing.expectEqual(@as(usize, 64), fb_proof.len);
    const fb_subject = try fb_provider.verifyProviderExchangePayloads(
        allocator,
        "{\"access_token\":\"fb_access_1\",\"token_type\":\"Bearer\"}",
        "{\"id\":\"fb-user-99\"}",
        "{\"data\":{\"is_valid\":true,\"app_id\":\"fb-client-id\",\"user_id\":\"fb-user-99\"}}",
        "unused-nonce",
        1_700_000_305,
    );
    defer allocator.free(fb_subject);
    try testing.expectEqualStrings("fb-user-99", fb_subject);

    // Facebook debug_token app_id mismatch must fail closed:
    try testing.expectError(
        error.ProviderDebugTokenAppMismatch,
        fb_provider.verifyProviderExchangePayloads(
            allocator,
            "{\"access_token\":\"fb_access_1\",\"token_type\":\"Bearer\"}",
            "{\"id\":\"fb-user-99\"}",
            "{\"data\":{\"is_valid\":true,\"app_id\":\"wrong-app\",\"user_id\":\"fb-user-99\"}}",
            "unused-nonce",
            1_700_000_305,
        ),
    );

    // 5. Declarative inbound webhook admission backed by `SecretKind.webhook_hmac`:
    const webhook_secret: DelegationAndSecrets.SecretDeclaration = .{
        .secret_id = 9010,
        .name = "sec.github_webhook_hmac",
        .kind = .webhook_hmac,
        .provider = .vault_kv,
        .provider_ref = "vault://webhooks/github",
        .scope_prefixes = &.{"https://webhook.ingress.local/"},
        .lease_state = .active_lease,
        .lease_expires_at_ns = now_ns + 86_400 * std.time.ns_per_s,
    };
    const webhook_endpoint: DelegationAndSecrets.WebhookEndpointDeclaration = .{
        .endpoint_id = 701,
        .realm_id = 1,
        .endpoint_path = "/webhooks/github/push",
        .secret_id = 9010,
        .target_object_id = 8801,
    };
    var webhook_engine: DelegationAndSecrets.WebhookAdmissionEngine = .{};
    const raw_payload = "{\"action\":\"opened\",\"number\":279}";
    const ts_s: i64 = 1_700_000_300;
    const valid_sig = DelegationAndSecrets.WebhookAdmissionEngine.computeWebhookHmacSha256(
        "whsec_test_key_material",
        ts_s,
        raw_payload,
    );

    const admitted = try webhook_engine.admitDelivery(
        webhook_endpoint,
        webhook_secret,
        "whsec_test_key_material",
        .{
            .delivery_id = "deliv-001",
            .timestamp_epoch_s = ts_s,
            .raw_payload = raw_payload,
            .signature_hmac_sha256 = valid_sig,
            .received_at_ns = now_ns,
        },
    );
    try testing.expectEqual(@as(u64, 8801), admitted.target_object_id);

    // Replaying the same webhook delivery ID is rejected:
    try testing.expectError(
        error.WebhookDeliveryReplayDetected,
        webhook_engine.admitDelivery(
            webhook_endpoint,
            webhook_secret,
            "whsec_test_key_material",
            .{
                .delivery_id = "deliv-001",
                .timestamp_epoch_s = ts_s,
                .raw_payload = raw_payload,
                .signature_hmac_sha256 = valid_sig,
                .received_at_ns = now_ns + std.time.ns_per_s,
            },
        ),
    );
}

test "Open sign-in vs bound catalog principal, lossless 64-bit JSON snapshots, and watermark-driven reactive watches with dynamic 1008 revocation" {
    const allocator = testing.allocator;
    const now_ns: i64 = 1_700_000_300 * std.time.ns_per_s;
    const now_ms: u64 = 1_700_000_300_000;

    // 1. Set up GitHub provider + session ledger + PrincipalBindingDirectory + MembershipFreshnessGuard:
    const github_provider: DeclarativeIngress.IdentityProviderDeclaration = .{
        .provider_name = "github",
        .issuer_profile = .{
            .issuer_id = 302,
            .realm_id = 1,
            .issuer_uri = "https://github.com",
            .expected_audiences = &.{"gh-client-id"},
        },
        .verification_mode = .oauth2_user_profile_json,
        .client_id = "gh-client-id",
        .client_secret_id = 9002,
        .authorize_endpoint = "https://github.com/login/oauth/authorize",
        .token_endpoint = "https://github.com/login/oauth/access_token",
        .userinfo_endpoint = "https://api.github.com/user",
        .scopes_space_separated = "read:user",
    };
    const gh_secret: DelegationAndSecrets.SecretDeclaration = .{
        .secret_id = 9002,
        .name = "sec.github_oauth_client",
        .kind = .oauth2_bearer,
        .provider = .oauth2_authorization_code_pkce,
        .provider_ref = "vault://oauth/github",
        .scope_prefixes = &.{"https://github.com/login/oauth/"},
        .expected_audience = "gh-client-id",
        .lease_state = .active_lease,
        .lease_expires_at_ns = now_ns + 86_400 * std.time.ns_per_s,
        .usage_granted_principals = &.{777},
        .policy_epoch = 10,
    };

    var ledger: DeclarativeIngress.BrowserSessionLedger = .{ .realm_id = 1 };
    var directory: AccessAndIdentity.PrincipalBindingDirectory = .{};
    var freshness_guard: AccessAndIdentity.MembershipFreshnessGuard = .{ .current_policy_epoch = 10 };

    const challenge = try ledger.beginLoginChallenge(github_provider, @splat(0x31), now_ns);
    const claimed = try ledger.claimLoginCallbackForExchange(
        github_provider,
        gh_secret,
        &challenge.state_token,
        &challenge.login_cookie_token,
        "code-open-1",
        777,
        10,
        now_ns,
    );
    const login = try ledger.completeLoginAfterTokenExchange(
        allocator,
        github_provider,
        claimed,
        "{\"access_token\":\"ghs_1\",\"token_type\":\"bearer\"}",
        "{\"id\":424242}",
        null,
        @splat(0x42),
        now_ns,
    );

    // 2. Open sign-in (`bound == false`): session status is authenticated + unbound,
    // and resolving bound catalog access fails closed with `error.UnboundExternalSubject`!
    const unbound_status = ledger.inspectSession(&directory, freshness_guard, &login.session_token, now_ns);
    try testing.expect(unbound_status.authenticated);
    try testing.expect(!unbound_status.bound);
    try testing.expectEqual(@as(?u64, null), unbound_status.principal_id);

    const status_json = try unbound_status.formatJson(allocator);
    defer allocator.free(status_json);
    try testing.expectEqualStrings("{\"authenticated\":true,\"provider\":\"github\",\"identity\":\"1\",\"bound\":false}", status_json);

    const granted_sources = [_]u64{7001};
    const consumer_grants = [_]DisclosurePolicy.ResourceConsumerGrant{
        .{ .principal_id = 5001, .resource_object = 6001, .audience_kind = .full_resource_and_drilldown },
    };
    const caller_source_grants: c.HistoricalCatalog.GrantSet = .{
        .policy_epoch = 10,
        .select_objects = &granted_sources,
    };
    try testing.expectError(
        error.UnboundExternalSubject,
        ledger.resolveBoundSessionAccessContext(
            &directory,
            freshness_guard,
            &login.session_token,
            801,
            .{ .audience = 1, .target_object = 6001, .branch_id = 1 },
            &consumer_grants,
            caller_source_grants,
            now_ns,
            null,
        ),
    );

    // 3. Binding to the local bootstrap owner (`principal_id == 1`) is forbidden:
    try testing.expectError(
        error.BootstrapOwnerExternalBindingForbidden,
        ledger.bindExternalSubjectToCatalogPrincipal(&directory, 302, "424242", DeclarativeIngress.bootstrap_owner_principal_id),
    );

    // 4. Bind the external subject `"424242"` to catalog principal `5001`:
    try ledger.bindExternalSubjectToCatalogPrincipal(&directory, 302, "424242", 5001);
    const bound_status = ledger.inspectSession(&directory, freshness_guard, &login.session_token, now_ns);
    try testing.expect(bound_status.authenticated);
    try testing.expect(bound_status.bound);
    try testing.expectEqual(@as(?u64, 5001), bound_status.principal_id);

    const resolved = try ledger.resolveBoundSessionAccessContext(
        &directory,
        freshness_guard,
        &login.session_token,
        801,
        .{ .audience = 1, .target_object = 6001, .branch_id = 1 },
        &consumer_grants,
        caller_source_grants,
        now_ns,
        null,
    );
    try testing.expectEqual(@as(u64, 5001), resolved.access_context.subject_principal);

    // 5. Evaluate a bound `PublishedResourceDescriptor` (`PBR1`) into lossless JSON (64-bit integer -> decimal string)
    // and drive a `WatermarkReactiveWatchSession` across watermark changes and dynamic revocation:
    const cols = [_]s.Column{
        .{ .id = 1, .name = "label", .type = .{ .utf8 = {} }, .nullable = false },
        .{ .id = 2, .name = "exact_i64", .type = .{ .int64 = {} }, .nullable = false },
    };
    const pk = [_]s.ColumnId{1};
    const schema: s.Schema = .{
        .object = 6001,
        .revision = 1,
        .next_column = 3,
        .columns = &cols,
        .primary_key = &pk,
    };
    const dep_cols = [_]s.ColumnId{ 1, 2 };
    const deps = [_]c.HistoricalCatalog.DependencyColumnBinding{
        .{ .source_object = 7001, .source_revision = 1, .columns = &dep_cols },
    };
    const descriptor: PublishedResource.PublishedResourceDescriptor = .{
        .namespace_id = 1,
        .resource_object = 6001,
        .definition_id = 6101,
        .publication_revision = 1,
        .previous_revision = null,
        .branch_id = 1,
        .owning_application = 10,
        .created_at_lsn = 90,
        .state = .published,
        .canonical_name = "member_feed",
        .business_title = "Member Feed",
        .business_meaning = "Bound member metrics with 64-bit precision",
        .tzdb_version = try fuze.DecimalArithmetic.TzdbVersion.init("fixture-tzdb", @splat(1)),
        .backing_kind = .managed_dataflow,
        .canonical_plan_or_sql = "SELECT label, exact_i64 FROM member_items ORDER BY label",
        .dependencies = &deps,
        .parameters = &.{},
        .supported_questions = &.{},
        .result_schema = schema,
        .column_semantics = &.{},
        .freshness_requirement = .{ .max_staleness_ms = 60_000, .require_complete_watermark = true },
        .work_bound = .{ .max_rows = 100, .max_bytes = 65536, .max_cpu_micros = 500_000, .max_iops = 64, .execution_timeout_ms = 5000 },
        .presentation = .{},
    };
    const policy: DisclosurePolicy.DisclosurePolicy = .{
        .mode = .caller_source_rights,
    };
    const basis_entries = [_]InvestigationBasis.SourceBasisEntry{
        .{
            .native_source = .{
                .source_object = 7001,
                .source_revision = 1,
                .branch_id = 1,
                .manifest_version = 1,
                .commit_lsn = 100,
                .pin_lease = .{
                    .pin_id = 1,
                    .source_object = 7001,
                    .owner_principal = 5001,
                    .acquired_at_ms = now_ms,
                    .expires_at_ms = now_ms + 3_600_000,
                },
            },
        },
    };
    const basis: InvestigationBasis.InvestigationBasis = .{
        .investigation_id = 9101,
        .basis_revision = 1,
        .created_by_principal = 5001,
        .created_at_ms = now_ms,
        .payload = .{ .multi_source_basis_vector = &basis_entries },
    };

    const row1_cells = [_]v.Cell{
        .{ .value = .{ .atom = .{ .bytes = "bound-only" } } },
        .{ .value = .{ .atom = .{ .signed = 9007199254740993 } } },
    };
    const initial_rows = [_]DisclosurePolicy.GroupSummaryInputRow{
        .{ .cells = &row1_cells, .contributing_source_row_count = 10 },
    };

    var probe: PublishedProjection.AllocationProbe = .{};
    var watch = try PublishedProjection.WatermarkReactiveWatchSession.open(
        descriptor,
        policy,
        basis,
        resolved.caller_access,
        freshness_guard.current_policy_epoch,
        now_ms,
        50_000,
    );

    // Tick 1 (`source_watermark_lsn = 100`): emits initial snapshot with `"9007199254740993"` as a decimal string:
    const tick1 = try watch.pollNextFrame(
        allocator,
        &.{},
        .published,
        resolved.caller_access,
        true,
        freshness_guard.current_policy_epoch,
        now_ms + 100,
        1,
        &initial_rows,
        1,
        100,
        .{
            .source_observation_cut_ms = now_ms,
            .domain_event_valid_time_ms = now_ms,
            .computation_completion_cut_ms = now_ms + 50,
            .requested_freshness_sla_ms = 60_000,
        },
        &probe,
    );
    switch (tick1) {
        .snapshot_frame => |snap| {
            defer allocator.free(snap.json_payload);
            try testing.expect(std.mem.indexOf(u8, snap.json_payload, "[\"bound-only\",\"9007199254740993\"]") != null);
        },
        else => return error.ExpectedInitialSnapshotFrame,
    }
    try testing.expectEqual(@as(u64, 1), watch.frames_emitted);

    // Tick 2 (`source_watermark_lsn = 100`, unchanged): returns `.no_change` without scanning or emitting!
    const tick2 = try watch.pollNextFrame(
        allocator,
        &.{},
        .published,
        resolved.caller_access,
        true,
        freshness_guard.current_policy_epoch,
        now_ms + 200,
        1,
        &initial_rows,
        1,
        100,
        .{
            .source_observation_cut_ms = now_ms,
            .domain_event_valid_time_ms = now_ms,
            .computation_completion_cut_ms = now_ms + 50,
            .requested_freshness_sla_ms = 60_000,
        },
        &probe,
    );
    try testing.expect(tick2 == .no_change);
    try testing.expectEqual(@as(u64, 1), watch.frames_emitted);
    try testing.expectEqual(@as(u64, 1), watch.skipped_unchanged_ticks);

    // Tick 3 (`source_watermark_lsn = 105`, watermark advanced): emits updated frame!
    const row2_cells = [_]v.Cell{
        .{ .value = .{ .atom = .{ .bytes = "live-update" } } },
        .{ .value = .{ .atom = .{ .signed = 42 } } },
    };
    const updated_rows = [_]DisclosurePolicy.GroupSummaryInputRow{
        .{ .cells = &row1_cells, .contributing_source_row_count = 10 },
        .{ .cells = &row2_cells, .contributing_source_row_count = 10 },
    };
    const tick3 = try watch.pollNextFrame(
        allocator,
        &.{},
        .published,
        resolved.caller_access,
        true,
        freshness_guard.current_policy_epoch,
        now_ms + 300,
        1,
        &updated_rows,
        1,
        105,
        .{
            .source_observation_cut_ms = now_ms + 250,
            .domain_event_valid_time_ms = now_ms + 250,
            .computation_completion_cut_ms = now_ms + 280,
            .requested_freshness_sla_ms = 60_000,
        },
        &probe,
    );
    switch (tick3) {
        .snapshot_frame => |snap| {
            defer allocator.free(snap.json_payload);
            try testing.expect(std.mem.indexOf(u8, snap.json_payload, "[\"live-update\",\"42\"]") != null);
        },
        else => return error.ExpectedUpdatedSnapshotFrame,
    }
    try testing.expectEqual(@as(u64, 2), watch.frames_emitted);

    // Tick 4: Dynamic offboarding / policy_epoch advancement immediately closes the watch with RFC 6455 `1008`!
    _ = try freshness_guard.offboardAndAdvanceEpoch(&directory, 5001);
    const tick4 = try watch.pollNextFrame(
        allocator,
        &.{},
        .published,
        resolved.caller_access,
        true,
        freshness_guard.current_policy_epoch,
        now_ms + 400,
        1,
        &updated_rows,
        1,
        106,
        .{
            .source_observation_cut_ms = now_ms + 350,
            .domain_event_valid_time_ms = now_ms + 350,
            .computation_completion_cut_ms = now_ms + 380,
            .requested_freshness_sla_ms = 60_000,
        },
        &probe,
    );
    try testing.expectEqual(PublishedProjection.ReactiveWatchPollOutcome{ .close = 1008 }, tick4);
}
