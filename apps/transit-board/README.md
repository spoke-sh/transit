# transit-board

Zig inspection service with optional separately credentialed query workspaces, containing the static [Board frontend](../transit-board-web/README.md)
and [OpenAPI v1](../../contracts/transit-board-v1.openapi.json). Its runtime libraries are `transit-client`, `transit-board-api`, `transit-query`, and the neutral
`telemetry` package, the shared `transit-station-app` compiler/publication adapter, plus the neutral
[HTTP server](../../packages/zig/transit-http-server/README.md). It has no kernel, Ursula or provider access and runs no application handlers. [Board's design](../../docs/internal/BOARD.md) owns the architecture.

## Configuration guide

[Configuration and deployment](docs/configuration.md) covers identity provisioning,
private access, origin/listener settings, and migration from experimental viewer
keys/sessions. Board has no viewer authentication layer; its upstream Transit
inspection identity remains read-only. The [growing query profile](docs/configuration.md#growing-atlas-and-optional-table-queries) uses a different, explicitly configured identity.
The additive [v2 workspace](docs/configuration.md#unified-state-query-workspace)
supports explicit KV/Table/Document declarations through the same query library
as the shell and SDKs; the original Table workspace keeps its v1 contract.

## Try it

```sh
nix develop
just transit-board::install
just transit-board::demo
```

The demo starts isolated disk-backed Ursula, Transit, and the real counter caller.
It prints a loopback URL. Open it directly; Board has no access keys, sign-in,
or browser sessions. Ctrl-C removes the disposable realm.

For a packaged local neighborhood, `transit server --config PATH` starts Board
by default with version-3 configuration; `--no-ui` disables it for one invocation.
The [local server guide](../transit-cli/docs/server.md#default-board-and-compatibility)
owns its retained identity, grant and restart contract.

For a persistent development system with an actively polling caller, use
`just launchers::local::up` or `just launchers::compose::up` instead. Their
[guide](../../launchers/README.md) covers logs, inputs and restart without losing
the realm. To configure Board against another provisioned realm:

```sh
just transit-board::build
zig-out/bin/transit-board /absolute/path/board.json
```

`just build::debug` also installs Board; use another [build profile](../../tasks/README.md#build-profiles)
for optimized executables. Building requires the locked frontend dependencies;
running the resulting binary requires neither Node nor a checkout/assets directory.
The build embeds up to 128 files / 8 MiB, with no external fonts, CDNs, or runtime
downloads. Each embedded build uses a private temporary asset directory so
concurrent launcher builds cannot empty one another’s frontend output.
Every reachable viewer can read this instance’s configured inspection scope.
The deployment boundary controls who can reach Board.

## Source and API ownership

| Source | Owns |
| --- | --- |
| [main.zig](main.zig) | Listener/origin checks, bounded upstream reads, API routing, static serving and diagnostics |
| [embed_web.py](../../tasks/embed_web.py) | Isolated frontend build, bounded embedded asset manifest and OpenAPI bytes |
| [transit-board-api](../../packages/zig/transit-board-api/README.md) | Typed evidence projections and generated OpenAPI |
| [transit-board-web](../transit-board-web/README.md) | Routes, polling and presentation using the generated client |

The binary serves its contract at `/openapi/v1.json`. API shape belongs to the
API package; routes must not expose raw upstream responses without checking the
configured reader's scope. A Board capability describes this API build, not a
production guarantee or permission to use a resource.

## Bounds and observations

The shared listener defaults to 16 accepted sockets, four data handlers and two
reserved `/health` handlers. Headers have at most one second; the overall request
deadline remains 100–5000 ms. Every handler owns its upstream client, arena and
observation. Query operations are serialized within this Board instance; callers
still preserve exact frozen tokens and coordinate their principal's sequence.
Concurrent gateway admission across instances remains M19 work.
Upstream calls have a shorter timeout; no redirects or response cache. The minimum spacing
between upstream reads is 100 ms by default (configurable up to 5000 ms), shared
across concurrent viewers through an atomic throttle. Excess reads get
`429 RateLimited`; clients back off. HTTP data capacity returns 503, while exhausted
socket/task capacity closes the connection without claiming admission. Headers are
8 KiB, inspection request bodies 4 KiB (routes accept empty bodies), query bodies
16 KiB (48 KiB for the v2 query route), request targets 1024 bytes,
and upstream responses 256 KiB.

Legacy inspection data preserves the public inspection observation plus explicit
causal facts. Pages contain at most 16 facts and journeys at most 32 edges.
Any authority change expires a continuation; busy writes may prevent pagination.
Coverage is explicit after trimming, and no Board cache pins history. A running
lifecycle is not worker liveness; delivered is admission, and closed-unknown is
not external failure. This bounded experimental profile is not a throughput SLA.

## Service diagnostics

Board identifies itself as `transit-board` in service diagnostics. It emits
`board.http.request` records on stderr with method, fixed route
template, status when available, local response-write completion and monotonic
duration. Failed/denied requests and deadlines are visible; successful
`/health` probes are debug-only. Public trace headers are ignored, and credentials, cookies, raw paths,
queries and payloads never appear in these records.

Use `LOG_FORMAT=json` for machine records or the default `text` for foreground
launchers. `LOG_LEVEL` defaults to `info`; `debug`, `warn`, `error` and `off` are
also supported. The [telemetry package](../../packages/zig/telemetry/README.md)
owns the schema, local metric snapshots, context and bounded sink behavior.
`service.starting`, `service.ready`, `service.failed` and `service.stopped` describe
normal execution; abrupt exits and signals are reported by the process manager.
Board's `/health` checks its HTTP/Host boundary, not upstream Transit availability.

Upstream client attempts get their own spans parented to the Board request;
successful attempts are debug-only, failures remain visible at normal verbosity.
An explicitly configured private node can continue that context across ingress
and storage. Local/Compose launchers enable it without forwarding browser-supplied
parents. Use their [per-service settings](../../launchers/README.md#service-diagnostics)
to turn on debug detail while navigating.

## Verification

`just transit-board::check` checks contracts, generated client, strict types, formatting,
lint and frontend unit tests. `just transit-board::test` runs Zig ingress/unit tests and
real disk-backed service proofs. `just transit-board::browser-install` installs the pinned
Chromium; `just transit-board::browser` exercises the real embedded UI with Playwright.
`just transit-board::query-test` qualifies the growing API;
`just transit-board::query-browser` runs its real workspace and revocation proof.
`just transit-board::http-test` inspects actual HTTP captures;
`just transit-board::http-browser` additionally checks the embedded records view
and clearing after revocation. `grpc-test` and `grpc-browser` qualify the same
read boundary for all four finite RPC shapes. These tasks use the disk/S3 worker fixture and require
Docker; the browser task also needs the installed Chromium.
The [test guide](../../tests/README.md) records measured limits and reference evidence.

## State resources

`GET /api/v1/resources`, `/resources/{resource}` and `/resources/{resource}/entries`
under the API prefix expose the [state v1](../../contracts/STATE_V1.md) read
contract. `/api/v1/processes/{pid}/associations` lists authorized associations.
The UI links these from **State resources** and the process **State** tab.
Resource pages show identity, writer, lifetime owner, revision, lifecycle,
retention policy and last committing turn. Coverage marks reclaimed turn detail.
Entry reads are explicit and display hexadecimal bytes without application decoding.
Recognized Station declarations on the same page also show GenServers, typed
Table schemas, registry bindings, supervisor retry state, waits and captured
query progress. Each view links its source PID and exact record/revisions.
Unknown versions stay opaque. Table rows and Arrow result data retain their
application boundary. These read-only views require the same resource grants
and disappear on read revocation.

Provision resource `inspect` (1) for metadata, or `inspect | read` (3) to also
allow entry reads. Coarse PID `inspect` alone discloses no resource. Association
pages also require the PID grant. The bounded API returns at most eight entries
or associations per page and uses the same explicit cut/restart rules. A 410
`StateResourceExpired` is different from an empty KV result. A resource-level
denial does not make other authorized process views unavailable.

M7 removed the counter lens, `lenses` configuration, and response `lens` field.
This is an intentional change to the experimental v1 API: regenerate external
clients from OpenAPI and remove `lenses` from standalone configs. Launcher
`update board` regenerates its configuration. No application value decoder or
executable interpretation plugin remains in Board.

## Growing atlas and workspace

The opt-in `growing_v3` profile exposes eight-process/eight-resource atlas pages
at one current authorized cut. The UI offers Processes/Resources emphasis,
overhead detail, explicit resource entry, and coordinated Canvas/Browse views.
Missing size, outbox and age measurements remain labeled unavailable. Catalog
entry counts include framework keys and do not claim logical Table row counts.

**Inspect records** reads eight keys/revisions through the current resource read
grant. `GET /api/v1/resources/{resource}/records` adds recognized exchange capture,
settlement, dependency, lineage and attempt-budget metadata, each tied to its exact
source record and observation. Raw values and captured bodies are omitted. Pages
use an explicit resource revision and key cursor; a changed revision requires a
fresh read. This route needs no query identity and creates no durable work.
The UI holds one page, clears it on errors or tab hiding, and rechecks every five
seconds. Capture completion, kernel settlement and remote business success remain
separate claims. **Inspect HTTP metadata** selects one exchange and reads frozen
endpoint/followup policy references, TLS/trust digest, finite byte/time budgets,
timing and omission counts through `/api/v1/resources/{resource}/http/{exchange}`.
Each selected metadata member has its key/digest/coverage evidence. Routing values,
credential references, heads and bodies are omitted. A partial capture has no
terminal metadata; retirement rejects the request. This bounded projection is
distinct from full transcript verification. **Inspect RPC metadata** uses
`/api/v1/resources/{resource}/grpc/{exchange}` with the same current-read boundary.
It shows descriptor digest/method shape, directional message/body counts, actual
outgoing half-close and captured status (including zero for OK). Indexed message
records in a partial capture do not claim complete messages. RPC metadata scans
at most 256 member descriptors, loads only selected policy/terminal records and
never interprets protobuf, headers, routing values or credential references.
Unknown outcomes have no complete terminal projection. Both panels share bounded
polling, abort and clear-on-denial/tab-hide behavior.

The separate query route compiles M12's Table SELECT subset through the shared
Zig client. Queries execute in external Station hosts; verified Arrow segments
become typed cells only through the explicit query capability. Source schemas,
exact result/source IDs and full-width integer strings survive both views.
Switching views preserves the draft/result without submitting work. Unknown
submission outcomes retain a frozen token for an explicit exact retry. Known
revocation clears the protected workspace. No offline history or result cache is
created. [Configuration](docs/configuration.md#growing-atlas-and-optional-table-queries)
and [frontend behavior](../transit-board-web/README.md) describe the limits.

The growing profile exposes selected accepted Document metadata at
`GET /api/v1/resources/{resource}/documents/{document}`. `document` is a canonical
nonzero uint64 decimal string. Optional `revision` (resource revision) and `after`
(opaque lowercase hex index key, at most 128 bytes) bind bounded continuation;
`after` requires `revision`. Public current-policy reads supply head evidence and
at most eight retained register counts. No application values or tentative changes
are returned. Changed cuts return `QueryExpired`, retained gaps `HistoryReclaimed`,
and current denial `Forbidden`; permanent Document retirement remains visible as
head metadata with no register page. The inspection identity gains no write power.

The opt-in [live Table guide](docs/reactive.md) describes the composed reactive
host, metadata-only inspection panel, finite query Follow/Pause lifecycle and
separate control credential. M21 browser/placement qualification is in progress.

## Application definitions (M23 in progress)

The optional [definition and operator guide](docs/application.md) describes the
shared compiler, built-in artifact, signed operator endpoint and publication
recovery. Inspection and query credentials cannot become operator credentials.
