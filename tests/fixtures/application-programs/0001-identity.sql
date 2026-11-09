-- Fresh Platform application baseline. Replaces the catalog-only history.
-- This is intended migration input, not an optional example. The selected
-- Transit release cannot execute the full program yet: Platform issue #120.
-- Native syntax/operation proposals are specified in the sign-in contract.
-- Never apply this reset over the old ledger or skip unsupported statements.

-- Configuration is versioned application data. Deployment supplies public
-- settings and protected secret references; SQL never contains secret bytes.
CREATE DOCUMENT signin_policy (
  provider TEXT PRIMARY KEY,
  enabled BOOLEAN NOT NULL,
  issuer TEXT NOT NULL,
  client_id TEXT NOT NULL,
  public_origin TEXT NOT NULL,
  callback_path TEXT NOT NULL,
  client_secret TEXT NOT NULL,
  scope TEXT NOT NULL,
  challenge_seconds BIGINT NOT NULL,
  session_seconds BIGINT NOT NULL
) WITH (profile = 'versioned');

INSERT INTO signin_policy VALUES (
  'github', TRUE, 'https://github.com',
  SETTING('github.client_id'), SETTING('browser.public_origin'),
  '/auth/github/callback', 'github', 'read:user', 300, 86400
);

-- These bindings make the declared records the native browser authority's
-- canonical state. They do not create shadow copies of private catalog records.
-- Provider subject, issuer and client ID determine identity, never email/name.
CREATE TABLE platform_identities (
  id VARCHAR(64) PRIMARY KEY,
  provider TEXT NOT NULL,
  issuer TEXT NOT NULL,
  client_id TEXT NOT NULL,
  subject TEXT NOT NULL
) WITH (native_binding = 'browser.identities');

-- Only an authorized operator/onboarding program may add a binding. Login
-- creates none. Native principals, roles and object grants must already exist;
-- principals 0/1 and the bootstrap role are forbidden by the native binding.
CREATE TABLE identity_bindings (
  identity_id VARCHAR(64) PRIMARY KEY,
  principal BIGINT NOT NULL,
  role BIGINT NOT NULL,
  signing_key_reference TEXT NOT NULL,
  enabled BOOLEAN NOT NULL,
  restricted BOOLEAN NOT NULL
) WITH (native_binding = 'browser.bindings');

-- Point reads and conditional writes decide validity; projections cannot.
-- Only commitments are retained, never the raw cookie, code or PKCE verifier.
CREATE KV login_challenges (ROW (
  provider TEXT,
  policy_revision BINARY,
  secret_revision BINARY,
  secret_commitment BINARY,
  cookie_key_revision BINARY,
  browser_commitment BINARY,
  expires_at TIMESTAMPTZ,
  state TEXT,
  effect_id UUID,
  code_commitment BINARY,
  identity_id VARCHAR(64)
)) WITH (native_binding = 'browser.challenges');

CREATE KV browser_sessions (ROW (
  identity_id VARCHAR(64),
  provider TEXT,
  policy_revision BINARY,
  created_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  revoked BOOLEAN
)) WITH (native_binding = 'browser.sessions');

-- HTTP owns a protected request/reply capability, including transient code and
-- cookie fields. Queue records carry only that capability, never their bytes.
-- The capability is purpose-bound, expires, cannot be read through ordinary
-- SQL, and is destroyed on completion/loss. Loss does not authorize a new code.
CREATE QUEUE auth_requests (
  request_id UUID NOT NULL,
  route TEXT NOT NULL,
  request_ref CAPABILITY NOT NULL
) WITH (max_attempts = 1, active_leases = 64);

CREATE QUEUE github_exchanges (
  request_id UUID NOT NULL,
  request_ref CAPABILITY NOT NULL,
  challenge_key BINARY NOT NULL,
  effect_id UUID NOT NULL
) WITH (max_attempts = 1, active_leases = 16);

-- Operator-visible receipts have explicit bounds and no credential payloads.
CREATE STREAM auth_receipts (
  request_id UUID NOT NULL,
  effect_id UUID,
  provider TEXT NOT NULL,
  transition TEXT NOT NULL,
  observed_at TIMESTAMPTZ NOT NULL
) WITH (retention = '7d');
