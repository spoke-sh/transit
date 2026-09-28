# Board configuration and deployment

[transit-board](../README.md)

## Configuration and provisioning

```json
{
  "upstream": "http://127.0.0.1:8080",
  "realm": 71,
  "principal": 2,
  "seed_file": "/run/board/transit-seed",
  "public_origin": "http://127.0.0.1:8090",
  "listen": "127.0.0.1",
  "port": 8090,
  "request_timeout_ms": 1500,
  "upstream_timeout_ms": 800,
  "read_interval_ms": 100,
  "http_connections": 16,
  "http_requests": 4
}
```

`http_connections` bounds accepted sockets (2–64); `http_requests` bounds data
handlers, with two additional reserved health handlers. Their sum must fit the
socket limit. Header reads use `min(1000, request_timeout_ms)` milliseconds.
Request state is private; the read throttle and query-operation lock are shared
within one instance. Size total memory for all permitted reader workspaces.
This does not add cross-instance query-principal sequence coordination.

An administrator provisions the realm and records a grant for this principal
with **only `inspect` (16)**, optionally restricted to one PID. Board rejects
principal zero and refuses data from a grant with any additional permission.
`seed_file` is that principal's 32-byte Ed25519 seed as 64 hex characters.
Use restrictive file/Secret permissions. Signing credentials never belong in Git/config
maps, frontend assets, query strings, or application history.

Every reachable human or agent shares this instance's explicit Transit scope.
There is no per-user delegation. Configure separate instances/principals for
separate scopes. Upstream URLs, and signing identity are trusted
operator configuration, never accepted from requests.

Browser and agent clients call `GET /api/v1/…` directly, without bearer tokens
or cookies. Every data read still uses Board's signing seed and rechecks its
current Transit permission. Revocation takes effect at that boundary; released
bytes cannot be recalled. Seed rotation takes effect on subsequent data calls;
coordinate it with the authority's grant update.

The OpenAPI lists the process, mailbox, outbox, effect, payload-metadata, history
and journey routes. See [inspection v1](../../../contracts/INSPECTION_V1.md) for
cut/continuation semantics. Query errors are JSON, including unknown API routes;
they never fall through to HTML. The default inspection profile has no mutation
route. The optional growing query profile is configured separately below.

### Migrating the experimental Board v1 profile

M17 adds required `documents` capability and growing-record lens fields, plus the
selected Document metadata response. Update Board and its generated browser client
together; older strict validators reject the additional fields. Existing Table
query payloads retain their original contract. Document inspection adds no write
or query capability to the inspection principal.

This deliberately removes the original viewer-authentication contract. Session
creation/logout endpoints and the `Session` schema are removed, as are the
`session_seconds` capability and the TypeScript `login`/`logout` helpers. Rebuild
API and frontend together; external clients should regenerate from OpenAPI and
stop sending Board credentials. The inspection GET routes remain under `/api/v1/`.

Launcher `update board` regenerates configuration and deploys the new executable.
For standalone configurations, remove `credential_file` and `session_seconds`;
unknown fields fail configuration parsing. Keep `seed_file`: Transit still
requires it. Old ignored access-key files and old browser cookies are unused;
Board no longer reads, issues, or renews them. The reference launcher reapplies
its Board Secret with only the Transit seed after the new pod is ready.

## Deployment boundary

Board is for private deployments. Network reachability admits viewers to its
shared inspection scope; Board does not authenticate individual people or agents.
Use network restrictions or a separately managed authenticated ingress to control
that reachability. Host/Origin checks are browser protections, not authentication.

By default, remote `public_origin` requires HTTPS at a trusted TLS ingress. Board itself
serves private HTTP. Match the configured Host exactly; pass the original Origin.
Strip `Forwarded` and `X-Forwarded-{Host,Proto,For}` headers: Board rejects them
and does not use them to authenticate proxy claims. No CORS or credentialed proxy
surface is available. By default, plain HTTP is accepted only for a `127.0.0.1` public origin.
Keep the listener private and permit egress only to its configured Transit service
and required DNS. No service-account token, storage credential or provider
credential belongs in the pod. Host validation is also required on health probes.

For a trusted development LAN, explicitly set `development_allow_insecure_http`
to `true` to allow an origin such as `http://devbox.local:18102`, with `listen`
set to `0.0.0.0` and `port` set to `18102`. This opt-in sends inspection data over
unencrypted HTTP; exact Host/Origin checks and the upstream read-only grant still
apply. Its default is false. HTTPS remains required for normal remote
deployments. The [launcher settings](../../../launchers/README.md#local-development-configuration)
expose these fields through a Git-ignored `.env` loaded by `.envrc`.

## Growing atlas and optional Table queries

Set `"profile": "growing_v3"` for the growing atlas. The inspection principal
must be non-root, unscoped, and have **only inspect (16)**; separately provision
resource metadata grants. Board checks the current signed identity and pins both
eight-item catalog pages to that observation. Any intervening authority change
expires the page. Legacy PID-scoped inspection remains on the default `legacy_v2`
profile and its existing routes; growing atlas does not implement those routes.

The growing profile also serves `GET /api/v1/resources/{resource}/records`.
Provision `inspect | read` (3) on the resource to expose record identities and
recognized exchange metadata. Metadata-only inspect permission is insufficient.
Each request rechecks the current read grant; no query identity is used. An
optional `revision=N&after=HEX` cursor continues the same resource revision,
where `HEX` is a lowercase key of 1–32 bytes. A changed revision returns 409;
revoked access returns 403 even for a previously valid cursor. The response
omits raw values, capture bodies and adapter context. It does not pin history.

`GET /api/v1/resources/{resource}/http/{exchange}` uses that same current read
grant for selected HTTP metadata. `exchange` is a canonical nonzero uint64 decimal
string. The route reads at most four known immutable members under one current
resource revision: request metadata up to 8 KiB and three terminal records up to
256 bytes each. Every chunk read rechecks authority. Changed state fails rather
than combining cuts; retirement returns 410, and incomplete/corrupt selected
metadata is explicit. No request/response body or raw header member is read.

Queries are disabled unless `query` is configured. For an already provisioned
source/requester installation, add these fields to the ordinary Board config:

```json
{
  "profile": "growing_v3",
  "request_timeout_ms": 5000,
  "upstream_timeout_ms": 1500,
  "query": {
    "seed_file": "/run/board/query-seed",
    "connection": {
      "realm": 71,
      "principal": 1234,
      "source": 1,
      "resource": 3,
      "table": 1,
      "name": "items",
      "requester": 8,
      "requests": 10
    }
  }
}
```

The numeric IDs are examples: use recorded IDs from your own provisioning.
The query principal must differ from the inspection principal and use the same
realm/upstream. Provision its inspect/send and resource inspect/read grants, the
requester binding, source Table and Station peer policy as described in the
[public contract](../../../contracts/PUBLIC_QUERY_V1.md) and
[query host guide](../../transit-query-host/README.md). Run the source, requester
and scoped courier outside Board. Board never runs their handlers or acquires
ownership. Local/Compose/reference launchers do not provision this optional profile.

Everyone admitted by this Board instance's private deployment boundary can use
its shared query identity. Separate instances/principals provide separate scopes;
there is no per-human attribution or delegation. Keep both seed files private.
Removing `query` restores an inspection-only configuration; the original
inspection grant is never widened. Existing captured work may continue after a
browser disconnect or configuration removal.

`GET /api/v1/atlas` accepts optional `position`, `process_after` and
`resource_after` cursors. `POST /api/v1/query` requires `Origin` exactly equal to
`public_origin` and `Content-Type: application/json`, with at most 16384 body
bytes. The OpenAPI specifies the finite operations. No arbitrary upstream URL,
Transit command or opaque value decoder is accepted. Query routes share Board's
request deadline and rate limit; an uncertain submission must retain its frozen
token for an exact retry. A read conflict permits a read retry, never a new query.

## Unified state query workspace

Use `query_v2` instead of `query` to expose a declared KV/Table/Document source.
Both options together reject at startup. `query_v2` contains `seed_file`, the v2
`connection` (realm, principal, source, resource, requester, requests), and the
same `workspace` source/name/limits object as the
[unified shell](../../transit-cli/docs/unified-query.md). The identity must differ
from inspection, use this realm/upstream and hold its own current grants. The
source resource must match the connection. Board does not provision workers.

`POST /api/v1/query-v2` exposes only the shared `transit-query.Workspace` operations.
It has a 49152-byte body bound to carry a finite encoded bundle, the same exact
Origin/content-type checks, and the existing deadline/rate limit. The generated
OpenAPI publishes separate v1/v2 request/response types. Atlas advertises the
visible query resource and version; it never labels an arbitrary resource as a
query source. Generated schemas bound every result row/column/conflict list to
eight. The browser further validates full-width numbers and nested cell types.

Run explicitly compiles SQL and starts one finite upload. Browser polling may
advance that authorized upload only after observing its previous input commit;
an uncertain signed submission requires **Retry exact submission**. Editing or
switching Canvas/Browse never executes a new query. Namespaces and immutable
compiled bundles remain tied to the submitted draft. Resume observes a namespace
without rerunning it. Separate controls request cancellation or request
retirement/collection; they cannot promise external cancellation or retract bytes.

One result segment is resident. Each visible observation rechecks current source
access and verifies that page, including its manifest, plan and source contract.
Known denial, expiry and history gaps clear source/draft/pending/result state.
Connection failure hides rows while preserving an uncertain token. Hidden tabs
hide results and returning rechecks access. No browser storage, Live queries,
arbitrary business-value decoder or administrative SQL is introduced.
