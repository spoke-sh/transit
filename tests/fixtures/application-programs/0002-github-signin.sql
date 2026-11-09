-- Sign-in is an installed program: ingress -> state decision -> external
-- exchange -> identity/session -> response. Blocks and primitives below are
-- native capability proposals, selected as real migration input under #120.
-- FROM QUEUE owns acquisition/checkpoint/recovery. An ATOMIC block commits
-- its state/output/receipt together; no caller or Platform poller drives it.

CREATE CONNECTION github_oauth TO HTTP (endpoint = 'https://github.com');
CREATE CONNECTION github_api TO HTTP (endpoint = 'https://api.github.com');

-- The caller can invoke these routes, not read/write their backing objects.
-- The public origin, trusted proxy and TLS boundary come from native placement.
-- Callback alone may cross origins, subject to its initiating browser challenge.
CREATE SOURCE browser_auth
  FROM HTTP REQUEST
  INTO QUEUE auth_requests
  WITH (
    origin = SETTING('browser.public_origin'),
    routes = JSON '{
      "github_login": {"method":"POST","path":"/auth/github/login","origin":"same"},
      "github_callback": {"method":"GET","path":"/auth/github/callback","origin":"challenge"},
      "session": {"method":"GET","path":"/auth/session","origin":"same"},
      "logout": {"method":"POST","path":"/auth/logout","origin":"same"},
      "providers": {"method":"GET","path":"/auth/providers","origin":"same"}
    }',
    request_storage = 'protected_transient',
    response_cache = 'no-store',
    errors = 'browser_v1',
    admission = 'public_route_only'
  );

-- Distinct dispatch authority. No redirect following or automatic retries.
-- Responses containing credentials remain protected transient native values;
-- ordinary captures/logs retain status and commitments, not bodies or headers.
CREATE SINK github_token INTO HTTP CONNECTION github_oauth WITH (
  method = 'POST', path = '/login/oauth/access_token',
  request_encoding = 'form', accept = 'application/json',
  response = 'protected_json', capture = 'redacted_metadata',
  request_timeout = '5s', response_max_bytes = 65536,
  follow_redirects = FALSE, max_attempts = 1, unknown_outcome = 'retain'
);
CREATE SINK github_profile INTO HTTP CONNECTION github_api WITH (
  method = 'GET', path = '/user', accept = 'application/vnd.github+json',
  user_agent = 'Spoke', response = 'protected_json', capture = 'redacted_metadata',
  request_timeout = '5s', response_max_bytes = 65536,
  follow_redirects = FALSE, max_attempts = 1, unknown_outcome = 'retain'
);

CREATE DATAFLOW begin_github_signin
  FROM QUEUE auth_requests AS request WHERE route = 'github_login'
  AS BEGIN
    LET policy = SELECT * FROM signin_policy WHERE provider = 'github';
    REQUIRE policy.enabled ELSE 'ProviderDisabled';
    LET secret = SECRET(policy.client_secret);
    LET cookie_key = SECRET('browser.cookie_key');
    LET state = RANDOM_TOKEN(32);
    LET browser = DERIVE_SECRET(cookie_key, state, 'login-cookie');
    LET verifier = DERIVE_SECRET(cookie_key, state, 'pkce');

    BEGIN ATOMIC
      REQUIRE CURRENT_REVISION(signin_policy, 'github') = policy._revision
        AND SECRET_CURRENT(secret) AND SECRET_CURRENT(cookie_key)
        ELSE 'LoginDeclarationChanged';
      PUT INTO login_challenges KEY DIGEST(state) VALUE ROW(
        'github', policy._revision, secret.revision, COMMITMENT(secret),
        cookie_key.revision, COMMITMENT(browser),
        NOW() + SECONDS(policy.challenge_seconds), 'issued', NULL, NULL, NULL
      ) IF ABSENT;
      PRODUCE INTO auth_receipts VALUES (
        request.request_id, NULL, 'github', 'challenge_issued', NOW()
      );
    END;

    RESPOND TO request.request_ref STATUS 303
      GUARD CURRENT_REVISION(signin_policy, 'github') = policy._revision
        AND SECRET_CURRENT(secret) AND SECRET_CURRENT(cookie_key)
      LOCATION URL('https://github.com/login/oauth/authorize', JSON_OBJECT(
        'client_id', policy.client_id, 'redirect_uri',
        policy.public_origin || policy.callback_path,
        'scope', policy.scope, 'state', state,
        'code_challenge', S256(verifier), 'code_challenge_method', 'S256'
      ))
      SET COOKIE '__Host-transit_login' VALUE browser
        SECURE HTTPONLY SAMESITE LAX PATH '/' MAX AGE policy.challenge_seconds;
  END;

-- Admission consumes the challenge and emits exactly one exchange intent in
-- the same transaction. A duplicate callback fails; it cannot enqueue again.
CREATE DATAFLOW claim_github_callback
  FROM QUEUE auth_requests AS request WHERE route = 'github_callback'
  AS BEGIN
    REQUIRE HTTP_QUERY(request.request_ref, 'error') IS NULL
      ELSE 'ProviderExchangeRejected';
    LET state = HTTP_QUERY_UNIQUE(request.request_ref, 'state');
    LET code = HTTP_SECRET_QUERY_UNIQUE(request.request_ref, 'code');
    LET browser = HTTP_SECRET_COOKIE_UNIQUE(request.request_ref, '__Host-transit_login');
    REQUIRE LENGTH(state) = 43 AND code IS NOT NULL AND browser IS NOT NULL
      ELSE 'InvalidCallback';
    LET challenge = GET FROM login_challenges KEY DIGEST(state);
    LET policy = SELECT * FROM signin_policy WHERE provider = 'github';
    LET secret = SECRET(policy.client_secret);
    REQUIRE challenge IS NOT NULL AND challenge.provider = 'github'
      AND challenge.expires_at > NOW()
      AND SECURE_EQUAL(challenge.browser_commitment, COMMITMENT(browser))
      ELSE 'InvalidCallback';
    REQUIRE policy.enabled AND policy._revision = challenge.policy_revision
      AND secret.revision = challenge.secret_revision
      AND SECURE_EQUAL(COMMITMENT(secret), challenge.secret_commitment)
      AND SECRET('browser.cookie_key').revision = challenge.cookie_key_revision
      ELSE 'LoginDeclarationChanged';
    REQUIRE challenge.state = 'issued' ELSE 'CallbackAlreadyClaimed';
    LET effect = OPERATION_ID(request.request_id, 'github-exchange');

    BEGIN ATOMIC
      REQUIRE CURRENT_REVISION(signin_policy, 'github') = policy._revision
        AND SECRET_CURRENT(secret)
        AND SECRET('browser.cookie_key').revision = challenge.cookie_key_revision
        AND challenge.expires_at > NOW() ELSE 'LoginDeclarationChanged';
      PUT INTO login_challenges KEY DIGEST(state)
        VALUE challenge WITH (
          state = 'claimed', effect_id = effect, code_commitment = COMMITMENT(code)
        ) IF REVISION = challenge._revision;
      ENQUEUE INTO github_exchanges VALUES (
        request.request_id, request.request_ref, DIGEST(state), effect
      );
      PRODUCE INTO auth_receipts VALUES (
        request.request_id, effect, 'github', 'exchange_admitted', NOW()
      );
      -- Response ownership transfers with the claim/intent, never afterward.
      HANDOFF request.request_ref TO github_exchanges EFFECT effect;
    END;
  END;

-- Native execution owns the continuation. EXECUTE SINK uses the original
-- effect identity, observing retained outcomes on replay. Dispatch authority
-- is consumed once; an unknown outcome is never permission to send again.
CREATE DATAFLOW complete_github_signin
  FROM QUEUE github_exchanges AS exchange
  WITH (deadline = '5s')
  AS BEGIN
    LET challenge = GET FROM login_challenges KEY exchange.challenge_key;
    LET policy = SELECT * FROM signin_policy WHERE provider = 'github';
    LET secret = SECRET(policy.client_secret);
    REQUIRE challenge.state = 'claimed' AND challenge.effect_id = exchange.effect_id
      AND challenge.expires_at > NOW() ELSE 'CallbackAlreadyClaimed';
    REQUIRE policy.enabled AND policy._revision = challenge.policy_revision
      AND secret.revision = challenge.secret_revision
      AND SECURE_EQUAL(COMMITMENT(secret), challenge.secret_commitment)
      AND SECRET('browser.cookie_key').revision = challenge.cookie_key_revision
      ELSE 'LoginDeclarationChanged';
    LET state = HTTP_QUERY_UNIQUE(exchange.request_ref, 'state');
    LET code = HTTP_SECRET_QUERY_UNIQUE(exchange.request_ref, 'code');
    REQUIRE DIGEST(state) = exchange.challenge_key
      AND SECURE_EQUAL(COMMITMENT(code), challenge.code_commitment)
      ELSE 'InvalidCallback';
    LET verifier = DERIVE_SECRET(SECRET('browser.cookie_key'), state, 'pkce');

    LET token = EXECUTE SINK github_token
      EFFECT OPERATION_ID(exchange.effect_id, 'token')
      GUARD CURRENT_REVISION(signin_policy, 'github') = challenge.policy_revision
        AND SECRET_CURRENT(secret) AND challenge.expires_at > NOW()
        AND SECRET('browser.cookie_key').revision = challenge.cookie_key_revision
      FORM (
        client_id = policy.client_id, client_secret = secret, code = code,
        redirect_uri = policy.public_origin || policy.callback_path,
        code_verifier = verifier
      )
      ON REPLAY OBSERVE ONLY;
    REQUIRE token.status = 200 AND JSON_VALUE(token.body, '$.error') IS NULL
      ELSE 'ProviderExchangeRejected';
    LET access_token = SECRET_JSON_VALUE(token.body, '$.access_token');
    REQUIRE access_token IS NOT NULL ELSE 'ProviderExchangeRejected';

    LET profile = EXECUTE SINK github_profile
      EFFECT OPERATION_ID(exchange.effect_id, 'profile')
      GUARD CURRENT_REVISION(signin_policy, 'github') = challenge.policy_revision
        AND SECRET_CURRENT(secret)
      HEADERS (Authorization = BEARER(access_token))
      ON REPLAY OBSERVE ONLY;
    REQUIRE profile.status = 200 ELSE 'ProviderExchangeRejected';
    LET subject = JSON_INTEGER(profile.body, '$.id');
    REQUIRE subject > 0 ELSE 'InvalidProviderSubject';
    LET identity = IDENTITY_DIGEST(policy.issuer, policy.client_id, CAST(subject AS TEXT));
    LET session_token = RANDOM_SECRET(32);

    BEGIN ATOMIC
      REQUIRE CURRENT_REVISION(signin_policy, 'github') = challenge.policy_revision
        AND SECRET_CURRENT(secret)
        AND SECRET('browser.cookie_key').revision = challenge.cookie_key_revision
        AND challenge.expires_at > NOW()
        AND NATIVE_IDENTITY_ALLOWED(identity) ELSE 'LoginDeclarationChanged';
      INSERT INTO platform_identities VALUES (
        identity, 'github', policy.issuer, policy.client_id, CAST(subject AS TEXT)
      ) ON CONFLICT (id) DO ASSERT SAME ROW;
      PUT INTO browser_sessions KEY COMMITMENT(session_token) VALUE ROW(
        identity, 'github', policy._revision, NOW(),
        NOW() + SECONDS(policy.session_seconds), FALSE
      ) IF ABSENT;
      PUT INTO login_challenges KEY exchange.challenge_key
        VALUE challenge WITH (state = 'complete', identity_id = identity)
        IF REVISION = challenge._revision;
      PRODUCE INTO auth_receipts VALUES (
        exchange.request_id, exchange.effect_id, 'github', 'session_created', NOW()
      );
    END;

    -- Native response delivery rechecks current session/provider/binding policy.
    -- A lost redirect does not replay either effect or create another session.
    RESPOND TO exchange.request_ref STATUS 303 LOCATION '/'
      GUARD NATIVE_SESSION_CURRENT(COMMITMENT(session_token))
      SET COOKIE '__Host-transit_session' VALUE session_token
        SECURE HTTPONLY SAMESITE LAX PATH '/' MAX AGE policy.session_seconds
      CLEAR COOKIE '__Host-transit_login' SECURE HTTPONLY SAMESITE LAX PATH '/';
  ON FAILURE failure
    BEGIN ATOMIC
      -- The native failure continuation retains the same input/effect identity.
      -- Refusal/unknown stays inspectable even if the response capability expired.
      LET current = GET FROM login_challenges KEY exchange.challenge_key;
      IF current.state = 'claimed' AND current.effect_id = exchange.effect_id THEN
        PUT INTO login_challenges KEY exchange.challenge_key VALUE current WITH (
          state = CASE WHEN failure.effect_outcome = 'unknown' THEN 'unresolved' ELSE 'refused' END
        ) IF REVISION = current._revision;
        PRODUCE INTO auth_receipts VALUES (
          exchange.request_id, exchange.effect_id, 'github',
          CASE WHEN failure.effect_outcome = 'unknown' THEN 'exchange_unresolved' ELSE 'exchange_refused' END,
          NOW()
        );
      END IF;
      RESPOND ERROR TO exchange.request_ref USING failure PUBLIC PROFILE 'browser_v1';
    END;
  END;

CREATE DATAFLOW read_session
  FROM QUEUE auth_requests AS request WHERE route = 'session'
  AS BEGIN
    LET token = HTTP_SECRET_COOKIE_UNIQUE(request.request_ref, '__Host-transit_session');
    IF token IS NULL THEN
      RESPOND TO request.request_ref STATUS 200 JSON
        JSON_OBJECT('authenticated', FALSE, 'provider', NULL, 'identity', NULL, 'bound', FALSE);
    ELSE
      LET session = GET FROM browser_sessions KEY COMMITMENT(token);
      REQUIRE session IS NOT NULL AND NOT session.revoked AND session.expires_at > NOW()
        ELSE 'InvalidSession';
      REQUIRE NATIVE_SESSION_CURRENT(COMMITMENT(token)) ELSE 'InvalidSession';
      RESPOND TO request.request_ref STATUS 200
        GUARD NATIVE_SESSION_CURRENT(COMMITMENT(token))
        JSON JSON_OBJECT('authenticated', TRUE, 'provider', session.provider,
          'identity', session.identity_id, 'bound', NATIVE_BINDING_ACTIVE(session.identity_id));
    END IF;
  END;

CREATE DATAFLOW end_session
  FROM QUEUE auth_requests AS request WHERE route = 'logout'
  AS BEGIN
    LET token = HTTP_SECRET_COOKIE_UNIQUE(request.request_ref, '__Host-transit_session');
    BEGIN ATOMIC
      IF token IS NOT NULL THEN
        LET session = GET FROM browser_sessions KEY COMMITMENT(token);
        IF session IS NOT NULL AND NOT session.revoked THEN
          PUT INTO browser_sessions KEY COMMITMENT(token)
            VALUE session WITH (revoked = TRUE) IF REVISION = session._revision;
          PRODUCE INTO auth_receipts VALUES (
            request.request_id, NULL, session.provider, 'session_revoked', NOW()
          );
        END IF;
      END IF;
    END;
    RESPOND TO request.request_ref STATUS 200 JSON JSON_OBJECT('authenticated', FALSE)
      CLEAR COOKIE '__Host-transit_session' SECURE HTTPONLY SAMESITE LAX PATH '/';
  END;

CREATE DATAFLOW list_signin_providers
  FROM QUEUE auth_requests AS request WHERE route = 'providers'
  AS SELECT provider FROM signin_policy WHERE enabled = TRUE
  RESPOND TO request.request_ref USING 'browser_provider_page_v1' PAGE SIZE 8;

-- Operator-granted native roles are deployment bindings, never social-user
-- privileges or bootstrap-owner credentials. Dispatch and invocation differ.
AUTHORIZE SINK github_token AS ROLE SETTING('signin.effect_role');
AUTHORIZE SINK github_profile AS ROLE SETTING('signin.effect_role');
AUTHORIZE DATAFLOW begin_github_signin AS ROLE SETTING('signin.state_role');
AUTHORIZE DATAFLOW claim_github_callback AS ROLE SETTING('signin.state_role');
AUTHORIZE DATAFLOW complete_github_signin AS ROLE SETTING('signin.state_role');
AUTHORIZE DATAFLOW read_session AS ROLE SETTING('signin.state_role');
AUTHORIZE DATAFLOW end_session AS ROLE SETTING('signin.state_role');
AUTHORIZE DATAFLOW list_signin_providers AS ROLE SETTING('signin.state_role');
ACTIVATE SINK github_token;
ACTIVATE SINK github_profile;
ACTIVATE DATAFLOW begin_github_signin;
ACTIVATE DATAFLOW claim_github_callback;
ACTIVATE DATAFLOW complete_github_signin;
ACTIVATE DATAFLOW read_session;
ACTIVATE DATAFLOW end_session;
ACTIVATE DATAFLOW list_signin_providers;
-- Install consumers before admitting requests. No network exchange at install.
AUTHORIZE SOURCE browser_auth;
ACTIVATE SOURCE browser_auth;
