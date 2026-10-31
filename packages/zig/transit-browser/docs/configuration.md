# Configure browser access

Add `browser_file: /absolute/path/browser.json` to the server configuration.
The server supervises the browser process and waits for its listener before
reporting readiness. The listener's `/health` is liveness, not a schema or
provider readiness probe. Migrate the schema before admitting browser traffic.

A configuration for a TLS load balancer is:

```json
{
  "version": 1,
  "address": "0.0.0.0",
  "port": 19110,
  "public_origin": "https://www.example.com",
  "trusted_tls_termination": true,
  "secret_file": "/run/secrets/browser-key",
  "state": {"endpoint": "unix:/tmp/transit-1000/INSTALLATION_DIGEST.sock"},
  "public_reader": {"endpoint": "unix:/tmp/transit-1000/INSTALLATION_DIGEST.sock"},
  "providers": [
    {"provider": "google", "client_id": "registered-client-id", "client_secret_file": "/run/secrets/google"},
    {"provider": "github", "client_id": "registered-client-id", "client_secret_file": "/run/secrets/github"},
    {"provider": "facebook", "client_id": "registered-app-id", "client_secret_file": "/run/secrets/facebook", "facebook_version": "v23.0"}
  ],
  "views": [
    {"name": "catalog", "sql": "SELECT id, title FROM catalog WHERE published = 1 LIMIT 128", "access": "public", "max_rows": 128}
  ],
  "bindings": []
}
```

Use the native SQL socket from the installation rendezvous. The example uses the
managed peer account for same-process-owner bootstrap. Operators can select
separate native SQL accounts and their existing grants through the connection
configuration; network accounts use `authentication: "scram"`, `password_file`
and a trusted `ca_file` with an HTTPS endpoint. Passwords and provider secrets
are file references, never browser parameters. Use absolute paths in this file.
Do not publish queries that disclose state, session hashes or private tables.

The browser key file contains 64 lowercase hexadecimal characters generated
from 32 cryptographically random bytes. Keep it stable across restarts; changing
it invalidates outstanding PKCE challenges. Its rotation does not revoke already
issued sessions; revoke those in the state tables. Secret files should be readable
only by the runtime's OS identity. Do not put secret values in Terraform state,
source control, browser bundles, query strings or logs.

## State and migrations

Apply [schema.sql](../schema.sql) once through `transit console --no-rc` standard
input before serving login. Migration orchestration owns versioning and partial DDL recovery;
the runtime never performs schema migrations automatically. The three ordinary
Transit Tables store challenge hashes, provider-scoped identities and session
hashes. Preserve them with the installation's durable storage.

Challenges expire after five minutes and are claimed by a conditional mutation
before exchanging a provider code. A lost reply can burn a login; the gateway
never issues a new exchange automatically after an uncertain outcome. Start a
new login to recover. Sessions expire after eight hours. Logout revokes the
stored session. To disable an identity, set `disabled = 1` for its full
`subject_hash`; every session read and subsequent snapshot checks that state.
Operators can delete expired challenges and sessions using their normal SQL
retention jobs. Storage and operation quotas remain those of the native account;
the 1,024-active-challenge admission check is a load guard, not a global quota or
rate limiter. Put rate limiting at ingress for an internet-facing deployment.

## Provider setup and identity

Register exact callbacks at the public origin:

- `/auth/callback/google`: Google Web Application client. Requests `openid`,
  uses authorization code and PKCE S256, and verifies the ID token's RSA RS256
  signature against Google's JWKS, issuer, audience/authorized party, nonce and
  validity window. No email claim is used as identity.
- `/auth/callback/github`: GitHub OAuth App. Uses authorization code, PKCE S256,
  client authentication and the authenticated `/user` response's numeric ID.
  No repository or organization scopes are requested.
- `/auth/callback/facebook`: Facebook Login app with a supported explicit Graph
  API version. Uses the server-side code exchange, validates the token's app and
  user through `debug_token`, then checks `/me` with `appsecret_proof`.

Provider redirects and token requests are fixed to the provider's HTTPS
endpoints. Token responses are bounded and are never forwarded to browsers or
persisted in the SQL state. The `test_endpoint` option is restricted to loopback
HTTP and requires `development: true`; production rejects it.

An external identity is a domain-separated digest of provider, client ID and
stable provider subject. Accounts from different providers are separate even if
email addresses match. Every valid account may sign in. **Signing in creates no
native role or grant.** A protected view (the default `access: "bound_identity"`)
requires an explicit `bindings` entry mapping the full identity digest from
`/auth/session` to an existing native SQL account's connection configuration.
The managed `local` owner is forbidden in such bindings. Provision that account
and grant only the intended native objects through Transit's existing authority.
Current grants govern the read and its final disclosure, including after revoke;
this mapping is not an alternative grant database. This interface has no browser
administration or mutation endpoint.

## Reverse proxy and origin rules

Terminate HTTPS at a trusted ALB or reverse proxy. Only that proxy may reach
port 19110. Preserve the public `Host` and `Origin`, forward cookies and
`Sec-Fetch-Site`, set `X-Forwarded-Proto: https`, and forward WebSocket upgrades.
Disable caching for `/auth/*` and `/api/*`. Do not expose the native gateway,
console or SQL listeners to browsers. Origin checking is a browser boundary,
not authentication of non-browser clients: clients can forge these headers.

The configured origin is exact: no wildcard, subdomain, `null`, scheme changes
or trailing slash. Every WebSocket upgrade and POST requires that Origin.
GET requests without Origin require `Sec-Fetch-Site: same-origin`, as browsers
can omit Origin on same-origin GET. OAuth callbacks alone allow cross-site
navigation, and require a one-use state bound to the HttpOnly login cookie and
the selected provider. A supplied mismatching Origin or Host still rejects.
Health GET is the deliberate unauthenticated load-balancer exception.

Production cookies use the `__Host-` prefix, `Secure`, `HttpOnly`, `SameSite=Lax`
and `Path=/`, with no Domain attribute. Duplicate credential cookies and headers
reject. Incoming bearer credentials and principal headers reject. Production
requires the explicit trusted TLS configuration and forwarded HTTPS indication.
Local development uses HTTP, non-prefixed cookies and a loopback-only listener.

## Browser protocol

- `GET /auth/providers` returns `{ "providers": ["google", "github", "facebook"] }`
  for configured providers.
- `POST /auth/login/{provider}` redirects to the selected provider. Use a
  same-origin HTML form so the browser follows navigation and cookie rules.
- `GET /auth/session` returns `{ "identity": null }` without a cookie, or
  `{ "identity": { "id": "provider-scoped-digest", "provider": "github", "bound": false } }`.
  An expired, disabled or revoked credential returns 401.
- `POST /auth/logout` revokes the current session, expires its cookie and
  redirects to `/`.
- `GET /api/views/{name}` returns `{ "rows": [...] }` only after a complete
  bounded read and final disclosure check. Integers are decimal strings, strings
  remain strings, booleans/numbers/null retain their JSON forms. Complex cells
  and incomplete/oversized results fail closed. Clients must validate the
  published view's schema.
- `GET /api/watch/{name}` upgrades with subprotocol `transit.browser.v1`. It emits
  the same complete snapshot immediately and approximately every two seconds,
  rechecking session and native grants each time. It closes normally after about
  50 seconds; reconnect with backoff and replace the displayed snapshot. This is
  a snapshot stream, with no change cursor, event history or exactly-once claim.
  Invalidation closes 1008, source errors close 1011, and normal expiry closes
  1000. Clear stale protected data on error; a closed socket is not evidence that
  previous rows remain authorized. The client may send masked ping/pong/close,
  but no query text or application messages.

Unknown names return 404, rejected origin/state returns 403, and missing session
or binding returns 401. Other failures return a generic 503. Responses are
`no-store`; server diagnostics contain error names, never callback URLs, tokens,
provider bodies or secrets. There are 12 admitted connections, four data requests,
two control requests and two watches, with a 60-second joined request deadline,
a 32 MiB per-request application allocation budget, bounded SQL client reserves,
1 MiB result text and at most 1,024 rows per published view. These defaults suit
a small installation; scale placement and admission deliberately.
