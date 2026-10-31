# Declarative browser v1

The browser listener in `transit-serving-http.BrowserRuntime` co-hosts with the
native node and SQL. It composes durable catalog declarations, external identity
verification and bounded reads of a published Table projection. Application table
names, columns and predicates belong to declarations, never runtime code.
[The example](../examples/declarative-browser/README.md) uses the executable
`transit migrate plan/apply` workflow for schema and seed data.

The authoritative types are [BrowserDeclarations](../packages/zig/transit-catalog/src/BrowserDeclarations.zig),
[BrowserAdministration](../packages/zig/transit-catalog/src/BrowserAdministration.zig)
and [BrowserContract](../packages/zig/transit-catalog/src/BrowserContract.zig).
[The generated schema](browser-v1.schema.json) contains `AdminRequest`,
`AdminResponse`, `Readiness`, `ProviderDiscovery`, `Session`, `LoggedOut`, `Failure` and
`Snapshot`. Regenerate with `just contract::generate`. Administrative requests
require `definition: "transit.browser.v1.2026-10-30"`; their native envelopes and
retained records independently require the current shared Transit definition.

## Declaration lifecycle

Use `transit-admin browser SEED_FILE REQUEST_JSON NATIVE_URL`. This existing
administrative executable is built alongside `transit` from source. Its input
is a generated, typed public API, not an application-maintained catalog file.
SQL provider/binding/publication declarations are not executable in this profile.
The command signs public native catalog operations; current native rights remain
authoritative for administration, metadata and reads.

Each request carries `connection`, `namespace`, `development` and one `action`:

- `inspect: {kind, key}` returns the retained record, native revision and immutable
  reference, or null. `key` is the 32-byte SHA-256 of a declaration name; binding
  keys are the external identity's 32 bytes.
- `list: {kind, after}` reads at most eight records and returns an exclusive
  numeric `next` continuation. `kind` is `secret`, `provider`, `publication`,
  `binding`, `identity`, `challenge` or `session`.
- `prepare_publication` compiles the reviewed single-Table SELECT against its
  actual current source schema and returns a proposed `Change`. It does not
  publish. The example saves that proposal before passing it to `change`.
- `change` takes a nonzero random 16-byte `mutation`, the exact inspected
  `expected` native revision (null for creation), and a typed declaration.
  Preserve that request through uncertainty and inspect its mutation/reference;
  do not create a new mutation to conceal an unknown outcome. Concurrent changes
  conflict. Repeating the latest identical mutation reports `changed: false`.

A native storage-epoch fence is a conflict, not evidence of rejection. The
record owner can rebuild at most three candidates under the same frozen key,
mutation, payload and expected revision, inspecting the original key before each
repeat. An observed mutation always returns `changed: false`, including a claim
whose acceptance acknowledgement was lost; it cannot authorize another exchange.
Transport uncertainty is returned without automatic replay.

Disable providers/secrets/bindings by conditionally setting `enabled: false`;
restrict an identity with `binding.restricted: true`. Publication states are
`published`, `withdrawn`, `retired`. A state-only transition can retain its
publication revision. Other changes advance the revision, link the exact previous
revision and retain the resource identity. Retirement is permanent. Re-prepare
against a replacement source and explicitly publish a new revision; it never
silently follows a recreated table.

Records use immutable `BRC1` blobs plus conditional `DirectClientToken` progress
in the existing catalog. Previous references retain history. Native operation
identities include namespace, record kind and full key. Activation reconciles
pending native bookkeeping page by page; it never dispatches OAuth effects.
The durable population has no fixed user-count array. Deployment storage quotas
still apply; retention is unlimited without an explicit owning cleanup policy.

## Provider registration

Register exact callback URIs `PUBLIC_ORIGIN/auth/NAME/callback` at the provider.
Provider declarations contain endpoints, client ID, issuer/audience rules, scopes
and a secret **reference**. Secret declarations map a name to a basename below
`browser.secret_directory`; bytes remain in private mounted files. Do not include
credentials in declarations, browser responses or request logs. The legacy model
fields `cached_jwks_json` and nonempty `jwks_keys` are rejected by this runtime.
`client_secret_id` is required by the shared model; the runtime resolves the
explicit named `secret` reference, not a second numeric secret store.

| Provider mode | Registration and exchange |
| --- | --- |
| Google `oidc_rs256_id_token` | Confidential web client, `pkce: "s256"`, scope `openid` (optional `profile email`), issuer `https://accounts.google.com`, sole expected audience equal to client ID. Endpoints and JWKS URI come from [Google discovery](https://accounts.google.com/.well-known/openid-configuration). Transit verifies RS256 signature, issuer, audience, nonce and token times; it does not identify a user by email. |
| GitHub `oauth2_user_profile_json` | OAuth App, `pkce: "s256"`, authorize `https://github.com/login/oauth/authorize`, token `https://github.com/login/oauth/access_token`, user info `https://api.github.com/user`, issuer identifier `https://github.com`. Select `read:user` scope. The confidential code exchange includes S256 verifier, then reads the stable profile ID with its access token. See [GitHub authorization](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps). |
| Facebook `oauth2_appsecret_proof_debug` | Confidential web login, `pkce: "confidential_client"`, scope `public_profile`. Pin the Graph API version supported by the registered app in authorize, token, `/me` and `/debug_token` endpoints. Transit sends the client secret during exchange, HMAC-SHA256 `appsecret_proof` on the profile read, and an app access token for token debugging; app ID, valid flag and stable user ID must agree. This mode does not claim provider PKCE support. See Meta's [manual flow](https://developers.facebook.com/docs/facebook-login/guides/advanced/manual-flow/) and [security guidance](https://developers.facebook.com/docs/facebook-login/security/). |

A minimal Google declaration (replace the client ID; the example helper fills
its deployment's realm) is:

```json
{
  "enabled": true,
  "secret": "google-client",
  "pkce": "s256",
  "jwks_endpoint": "https://www.googleapis.com/oauth2/v3/certs",
  "profile": {
    "provider_name": "google",
    "issuer_profile": {
      "issuer_id": 1,
      "realm_id": 1,
      "issuer_uri": "https://accounts.google.com",
      "expected_audiences": ["YOUR_CLIENT_ID"]
    },
    "verification_mode": "oidc_rs256_id_token",
    "client_id": "YOUR_CLIENT_ID",
    "client_secret_id": 1,
    "authorize_endpoint": "https://accounts.google.com/o/oauth2/v2/auth",
    "token_endpoint": "https://oauth2.googleapis.com/token",
    "userinfo_endpoint": "https://openidconnect.googleapis.com/v1/userinfo",
    "scopes_space_separated": "openid"
  }
}
```

Outbound calls use the shared HTTP connector transport, system CA trust and
hostname verification, no redirects or retries, a five-second exchange deadline
and a 64 KiB response bound. DNS uses bounded IPv4 resolution and is covered by
the encompassing request deadline. Only explicit loopback development permits
HTTP provider endpoints. `provider_ca_file` is an optional deployment trust file.
JWKS has 16 resident cache slots, up to 32 keys per document, declaration-revision
keys, configurable TTL 1–3600 seconds (default 300), and at most one forced unknown
`kid` refresh per second per cached declaration. Failure never extends stale TTL.
`retired_kids` rejects listed keys even if cached and cryptographically valid.
Provider updates invalidate issued challenges and existing sessions. Rotating
mounted secret bytes invalidates pending challenges before exchange, through a
keyed commitment that never stores those bytes. Cookie-key rotation invalidates
pending challenges; retain that key across ordinary task replacement.

Live consent, callback registration and provider app-review eligibility require
operator-owned provider registrations. The independent local provider scenarios
are described in [the test index](../tests/interfaces/README.md).

## Identity, claims and native rights

Login stores a bounded, expiring challenge containing browser-cookie, verifier,
nonce and secret commitments. Callback validates browser binding, expiry,
provider/secret revisions and secret bytes before conditionally changing the
challenge to `claimed {effect, code_digest}`. Only the successful transition may
send the code exchange. A competing/replayed callback, lost claim acknowledgement,
process death or unknown remote response cannot dispatch again. A claimed record
with no complete outcome remains inspectable and unresolved; the user may start
a new login, but the original code/claim is never replayed. Successful verification
persists the stable external identity, completes the claim and creates a session.
Tokens and raw authorization codes are not retained. A lost final redirect can
leave a valid session the browser did not receive; it does not permit code reuse.

Identity hashes bind issuer URI, client ID and stable provider subject. Any valid
account may sign in. Unbound sessions receive **no** native privileges. Inspect
identities via paged `list`, then create a binding keyed by the returned digest.
A binding selects an explicitly provisioned native reader principal, role and
private signing-key secret. Principals 0/1 and the bootstrap role are refused.
Native role membership and object grants must already authorize that reader; a
binding cannot manufacture grants or sign as a principal with the publisher key.
Revoke native rights with the native authorization interface (use its explicit
cascade semantics when dependent read leases exist), or disable/restrict the
binding. Sessions and restrictions survive replacement using the same durable
storage and keys. Sessions expire without sliding renewal; logout conditionally
persists revocation before clearing the cookie.

A publication selects `audience: "public"` or `"bound_identity"`. Public reads
explicitly use the publication's declared publisher credential. Protected reads
require the session's bound reader **and** the publisher to retain current native
rights. A supplied invalid/restricted session is rejected even on a public route;
there is no credential failure fallback to anonymous access.

## Browser HTTP and WebSocket contract

Browser data and authentication paths use one exact configured public origin. HTTP responses use
`Cache-Control: no-store`; successful JSON uses the generated schemas. No CORS
cross-origin access is provided. Unsupported methods/routes fail closed.

| Method and route | Outcome |
| --- | --- |
| GET `/auth/providers?after=CURSOR` | `{providers: [name...], next: string-or-null}`; at most eight inspected provider records per page, enabled names only. |
| POST `/auth/{provider}/login` | 303 provider redirect, one-use login cookie. No request body. |
| GET `/auth/{provider}/callback?state=...&code=...` | 303 `/`, session cookie, clears login cookie. No caller-controlled return URL. |
| GET `/auth/session` | `{authenticated, provider, identity, bound}`; anonymous fields are null/false. Identity is a 64-character hex digest. |
| POST `/auth/logout` | `{authenticated: false}` after durable revocation, clears session cookie. |
| GET `/published/{name}/snapshot` | One complete `Snapshot`; no incomplete row prefix. |
| GET `/published/{name}/watch` | RFC 6455 upgrade with `transit.published.v1`; initial and changed snapshots as JSON text frames. No application request frames or replay cursor. |

HTTP failures are `{err: "TypedErrorName"}`: 404 missing route/record, 409 claimed
callback/conflict, 502 explicit provider rejection, 503 capacity/work/memory bound,
403 other validation or authorization refusal. Transport timeout/EOF does not
establish a rejected or completed durable operation. Error text never includes
provider payloads, codes, tokens or credentials. WS close 1008 means denied,
expired, logged out or withdrawn; 1012 means changed publication/source requiring
a new subscription; 1011 means unavailable/internal execution. Normal finite
watch lifetime ends at 1000. A close reason may contain a typed error name.
Client frames must be masked; ping/pong and close are supported, application
text frames are refused. No compression extension is negotiated.

Cookies are `__Host-transit_login` and `__Host-transit_session`, Secure, HttpOnly,
SameSite=Lax, Path=/, no Domain. Explicit IPv4 loopback development uses
`transit_login` / `transit_session` without Secure. Login and session TTLs are
bounded deployment settings (defaults five minutes and one hour). Duplicate
credentials or identity/authorization forwarding headers are rejected. POST and
WS require exact Origin; ordinary GET requires exact Origin or same-origin
Fetch Metadata. Only OAuth callback admits cross-site navigation, protected by
its browser-bound claim. Duplicate/malformed state/code parameters fail closed.

## Source basis, disclosure and bounds

The executable publication profile is one Table SELECT projection/filter with
optional LIMIT, scalar integer/float/bool/text/decimal output, no parameters,
aggregates, joins or external effects. `prepare_publication` records the exact
source definition, dependency columns, result schema and budgets. The runtime
recompiles against that same live definition and uses its declared collations.
This profile performs no timezone conversion and requires explicit
`descriptor.tzdb_version: null`; it never invents an IANA version or digest.

Snapshot columns carry name, logical type and nullability. Rows are arrays in
column order. All integer cells and decimal coefficients are decimal strings;
decimal scale is in the logical type. Finite floats use JSON numbers, booleans and
null keep their JSON types. Missing/conflict/type-error cells refuse the result.
Attribution contains decimal-string object/revision/partition/LSN/count fields,
`complete: true` and `retention: "current_cut_unpinned"`. This is a checked native
current cut, **not** a durable retention pin or multi-source atomic snapshot.
Concurrent logical source changes refuse the entire buffered HTTP response. A
watch discards that undisclosed attempt and observes a fresh cut at its next
bounded poll. Native bookkeeping-only changes preserve the original data fence.
Reconnect starts
a fresh snapshot and never splices a previous prefix.

Native reads use eight-row/64 KiB pages. Publication row, response-byte, operation
and timeout budgets bound work; maximum configured rows is 10,000 and output is
at most 4 MiB. The row budget bounds scanned rows, including filtered-out rows.
The CPU budget is conservatively enforced as elapsed wall time. Each HTTP request
and watch iteration has a 16 MiB scratch ceiling, wiped after use (32 MiB total
reservation for an open watch including its original HTTP request). Pages have
separate reusable scratch lifetimes; output owns its serialized bytes. A result
that cannot fit fails rather than claiming truncated completion.

Watches check native metadata watermarks every 500 ms; unchanged cuts do not scan
rows or rerun the SELECT. Each check revalidates publication/session/binding,
secret availability and native source rights. Changed snapshots recheck all of
these after buffering and immediately before a bounded write. Revocation cannot
retract bytes already sent. Idle invalidation is observed at the next successful
check; it is not a zero-latency notification guarantee. A watch owns one output
buffer, a joined input task and no backlog queue; writes have one-second deadlines,
watches last at most 50 seconds, and errors close them. Clients reconnect with
backoff for a new current snapshot. Default listener capacity is 16 connections,
four data requests, two control requests and four watches; no slow reader may
retain unbounded memory or detach a background sender.

## Placement, trust and replacement

`transit server` accepts optional `browser` placement fields in `transit.yaml`:
listener address/port, public origin, explicit proxy CIDR or development mode,
native connection/namespace, private key/secret paths, TTLs and capacity options.
Providers, bindings, publications and grants are catalog operations, never
placement settings. See [configuration reference](../docs/handbook/reference/configuration.md).
Startup loads keys, settles pending catalog bookkeeping and binds the listener
before reporting native readiness. Shutdown joins listener/socket tasks.

`GET /health` on the browser listener returns `200 {"ready":true}` after that
startup gate. This infrastructure probe discloses no catalog/session data and
needs no browser Origin, cookie or TLS-forwarding header. Production still
requires the actual socket peer to match `trusted_proxy_cidr`. It reports listener
readiness, not current provider availability or a grant to read data.

For one ECS task behind HTTPS ALB, bind the browser listener on the private task
interface, use the exact CloudFront origin, `development_loopback: false`, and a
restricted IPv4 `trusted_proxy_cidr` for actual ALB peers. The accepted socket
peer must match that CIDR before forwarding headers are trusted. The private
network/security-group boundary must exclude other senders in that subnet.
Require a single `X-Forwarded-Proto: https`, preserve exact original Host, reject
`Forwarded`/`X-Forwarded-Host` and identity forwarding. `X-Forwarded-For` conveys no
authority. Same-origin CloudFront routes must forward cookies, Origin, Fetch
Metadata, query parameters and WS upgrade, disable caching, and preserve the
callback path. The static application stays separately hosted. AWS provisioning
and live ALB/CloudFront behavior are outside this runtime proof.
Configure the target group's HTTP health check to use `/health` and expect 200.
ALB probes send the target's private address in Host, as described in the
[AWS health-check guidance](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-troubleshooting.html);
the separate readiness route accepts that probe while browser routes retain
their exact public Host/Origin checks.

Task replacement must retain the native log/object storage, browser namespace,
connection, mounted secrets and cookie key with a matching shared definition.
Sessions, challenges, declarations, explicit bindings and retained outcomes are
then recovered from the catalog. JWKS cache and sockets are transient. An old
artifact/definition is rejected before execution; do not delete old storage to
work around that refusal. Resolve old accepted work with its matching build and
choose an explicit fresh installation/import procedure under the
[versioning policy](../docs/handbook/reference/versioning.md).
