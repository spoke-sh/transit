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
Across instances, the native principal sequence arbitrates competing prepared
requests: identical signed bytes recover the same receipt, while different work
using that sequence returns `409 QueryConflict`. The requester enforces its
durable active-upload quota even after another instance prepares a new sequence.
Retain the prepared token across interruption; a failed socket must not trigger
automatic preparation of replacement work.

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
route. The optional query workspace is configured separately below.

### Board v1 compatibility

Board and its generated client use the current v1 OpenAPI together. Before 1.0,
incompatible changes are hard cutovers: replace the server, frontend and external
client declarations together. The [versioning policy](../../../docs/handbook/reference/versioning.md)
defines that boundary. Unknown configuration fields reject at startup.

The inspection identity has a signing seed. Viewer authentication, cookies and
sessions are not part of the Board API; access is through the deployment boundary.

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

## Atlas and resource inspection

The only profile is `"profile": "native_v1"`, also the default. Its inspection
principal is non-root and has **only inspect (16)**. A PID-scoped grant filters
process inspection; the atlas requires an unscoped inspector. Resource metadata
and contents require independently recorded grants. Both eight-item atlas pages
share one signed observation. An intervening authority change expires the page.

Board also serves `GET /api/v1/resources/{resource}/records`.
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

## Unified state query workspace

The separate [relational worksheet](relational.md) configures explicit catalog
routes and interactive joins/groups through its own optional `relational` field.

Queries are disabled unless `query` is configured. The object contains
`seed_file`, `connection` (realm, principal, source, resource, requester, requests),
and the `workspace` source/name/limits object from the
[SQL shell guide](../../transit-cli/docs/unified-query.md). This example selects
an explicitly configured KV decoder:

```json
{
  "query": {
    "seed_file": "/run/board/query-seed",
    "connection": {
      "realm": 71, "principal": 1234, "role": null, "source": 1, "resource": 3,
      "requester": 8, "requests": 10
    },
    "workspace": {
      "name": "items",
      "source": {
        "version": 1, "resource": 3,
        "source": {"kv": {"prefix": "646174612f", "key": {"version": 1, "type": "binary"}, "value": {"version": 1, "type": "utf8"}}}
      },
      "limits": {"pages": "1000", "segments": "100", "result_bytes": "1048576"}
    }
  }
}
```

For a Table, copy the complete `workspace` from the provisioned query
configuration. Its source includes the catalog scope, owner, stable object,
immutable metadata reference and recursive `row_type`; names alone cannot
reconstruct that declaration. Current metadata inspection rejects a changed or
retired Table before new query work is prepared.

Use recorded IDs from your installation. The query principal differs from the
inspection principal and uses this realm/upstream. Provision its inspect/send
and independent resource inspect/read grants, requester binding and source policy
through the [query contract](../../../contracts/UNIFIED_QUERY_V1.md) and
[query host](../../transit-query-host/README.md). Run source, requester and courier
outside Board. Board does not acquire ownership or execute their handlers.
For Tables, also grant CONNECT on the database, USAGE on its schema and SELECT
on the source Table to the current login or explicitly selected `connection.role`.
Submitted Table queries freeze that principal, role and credential epoch;
restoring a worksheet cannot substitute a different role for accepted work.
This configured query identity uses the privileged infrastructure-reader profile;
its native resource grants expose more than a restricted Table-only user.

Everyone admitted by the private deployment boundary shares this query identity.
Separate instances and principals provide separate scopes. Removing `query`
restores inspection-only configuration; captured work can continue independently
of the browser and Board configuration.

`POST /api/v1/query` exposes the shared `transit-query.Workspace` operations.
Its body limit is 65536 bytes. `Origin` must equal `public_origin` and
`Content-Type` must be `application/json`. Deadlines and rate limits apply.
Retain an uncertain submission's frozen token for exact retry. A read conflict
permits a read retry; it does not authorize a new query.

Board retries a native `HttpCapacity` refusal at most three times for query
reads and token preparation, waiting 500 ms, one second and two seconds within
the original request deadline. Each attempt repeats the same workspace request
and checks current authority again; failed candidate pages are never disclosed.
Signed submission, denial and other failures do not enter this retry. An
exhausted capacity refusal remains `503 Unavailable`.

The generated OpenAPI describes one v1 request/response model. Atlas advertises
the configured visible query resource. Schemas and semantic validation bound result rows and conflict alternatives
to eight and general Table columns to 128. The client validates full-width
numbers, recursive logical descriptors and nested cell states. Arbitrary upstream URLs and native commands are not accepted.

**Inspect SQL** executes `DESCRIBE`, `SHOW TABLES` and `EXPLAIN SELECT` against
the configured source without admission or snapshots. Its separate metadata
view shows current source/policy evidence and proposed plan/output types;
current denial, changed observations and hiding clear that view.

**Run query** explicitly compiles SQL and starts one finite upload. Browser polling may
advance that authorized upload only after observing its previous input commit;
an uncertain signed submission requires **Retry exact submission**. Editing alone
does not enable execution, and switching Canvas/Browse never starts a query.
Namespaces and immutable
compiled bundles remain tied to the submitted draft. Resume observes a namespace
without rerunning it. Separate controls request cancellation or request
retirement/collection; they cannot promise external cancellation or retract bytes.

For a Table source, **Enable Live draft** explicitly opens a finite evaluation
budget. While enabled, complete valid edits can start queries within that budget;
edits coalesce while accepted work is pending. Pause stops scheduling without
cancelling accepted work. **Follow changes** separately refreshes an eligible
completed query using its submitted plan. See [Live Table views](reactive.md) for
both controls, recovery and their limits.

One result segment is resident. Each visible observation rechecks current source
access and verifies that page, including its manifest, plan and source contract.
Known denial, expiry and history gaps clear source, draft and displayed result;
the original upload plan and frozen uncertain token remain available for exact
recovery. **Refresh query access** rechecks access and retained status without
reading the cleared result. **Resume without rerunning** explicitly selects that
namespace again; its result remains distinct from the current SQL draft.
Temporary connection failure retains permitted rows with their original source
basis and preserves an uncertain token. Hidden tabs hide results and returning
rechecks access. Recovery stays in memory unless explicitly exported; no signing
keys or result pages are written to browser storage. The workspace does not
provide arbitrary business-value decoding or administrative SQL.
