# Board — system inspection

Status: planned for [M2](roadmap/M2.md), before Station. Board is the UI and
OpenAPI surface through which operators and agents comprehend a running Transit
system. M2 is inspection-only; operational controls are later scope. No Board
executable, frontend, or inspection extensions are implemented yet.

## Purpose and visual language

Board takes inspiration from rail and flight departure/arrival boards: show
what is waiting, what moved, where it is going, and what needs attention. Begin
with kernel primitives so the system remains understandable without Station.
The browser is the first Board API client; agents, CLIs, and other UIs can use
the same documented facts without scraping screens.

Logistics terms organize views; they do not rename protocol identities or create
new execution semantics. Always expose the corresponding Transit term and ID.

| View | Question answered | Kernel evidence |
| --- | --- | --- |
| Board overview | Which processes need attention, and why? | PID, lifecycle, ownership, backlog, blocked input, open effects, observed position |
| Arrivals | What has entered this mailbox and what remains unfinished? | Durable admission, ordered input, consumption/cancellation |
| Departures | What has this process committed for delivery or execution? | Outbox destinations and delivery outcomes; effect intent, authorization, and observations |
| Process detail | What can we establish about this process now? | State revision, activation, runtime binding, deadlines, recovery/retention coverage |
| Journey | How did this input lead to later work? | Recorded input-to-turn, output-to-admission, and effect-to-result links |

Start with a readable table, a process detail page, and a bounded journey view.
A selected journey can use sequence lanes and a small route graph; avoid making
an unrestricted system graph the only way to find work. Sorting/filtering,
keyboard access, textual status, reduced motion, and stable shareable URLs are
part of comprehension. Color and animation must not carry meaning alone.

A lifecycle of `running` is not proof a worker is executing. Delivered output is
not a completed destination turn. Dispatch authorization is not proof a request
was sent. Closed-unknown is not remote failure or cancellation. Use recorded
positions for order; show timing only where evidence exists. Observation time
is distinct from event time. Do not invent ETAs, processing durations, global
causality, or wall-clock history from polling samples.

## Boundary and packaging

```mermaid
flowchart LR
    UI[Embedded static Board UI] --> API[Board OpenAPI service]
    Agent[Agent or other API client] --> API
    API --> Client[transit-client inspection calls]
    Client --> Node[Transit authenticated read boundary]
    Node --> History[(Validated durable state and retained history)]
    API -.-> Lens[Versioned interpretation lenses]
```

`board` is a Zig executable hosting both API and embedded static assets on one
origin. It is an application alongside `transit-node`, with no raw Ursula,
kernel-internal, or provider API access. Its observations and indexes are derived;
Board cannot grant ownership, dispatch effects, advance consumer progress, or
run application handlers. Transit remains the execution authority.

Use TypeScript and TanStack Router with Vite+. React with file-based routes is
the proposed frontend choice. TanStack documents a Vite router plugin, and
Vite+ supports the Vite build/configuration model; compatibility with Rey's
pinned toolchain still needs an executable proof. See
[TanStack's Vite integration](https://tanstack.com/router/latest/docs/framework/react/installation/with-vite)
and [Vite+ production builds](https://viteplus.dev/guide/build).

Build frontend assets first, then embed the complete asset manifest and bytes
into the Zig binary. Shipping the binary must suffice to serve UI and API without
Node.js, a source checkout, a sidecar asset directory, or an asset CDN. Browser
routes need HTML fallback; API and missing asset routes must retain real errors.
Version the assets and API together. Build tooling and dependency pins stay in
the Vite+/pnpm workspace; no production JavaScript server is needed.

Proposed ownership, to create when implementation starts:

| Location | Responsibility |
| --- | --- |
| `apps/board/` | Zig executable, authenticated API hosting, bounded observations, static asset embedding, and lens composition |
| `apps/board-web/` | TanStack Router application and browser interaction tests |
| `packages/zig/board-api/` | Board response/route definitions and OpenAPI generation, reusing public Transit types |
| `packages/ts/board-client/` | Generated typed Board API client shared by the browser and future TypeScript consumers |

The Board executable composes `transit-client` and `board-api`; public Transit
inspection contracts remain in `transit-protocol`. No dependency from Transit
back into Board is permitted. `board` has its own application name rather than
the `transit-` prefix reserved for kernel services.

## Public inspection contract

Current [service v2](../contracts/SERVICE_V2.md) supports a known-PID view with
state, next input, effects, payload metadata, and binding evidence. It does not
provide discovery, a mailbox page, an outbox listing, or retained event history.
The first M2 work is to add these as authenticated, provider-neutral public read
operations in Transit and `transit-client`. Do not bypass that gap by letting
Board scan Ursula or import core's state catalog.

Expose typed, filtered inspection facts, not raw realm journal records containing
other principals' data. Discovery, cross-PID relationships, history, payload
visibility, and aggregates each require an explicit disclosure contract. Current
`inspect` is coarse and includes state bytes; hiding payloads in the UI does not
establish a separate metadata-only permission. Keep public read changes versioned
and preserve existing caller compatibility or declare a deliberate migration.

Board's resource API should be useful independently of its screen layouts.
Proposed areas under `/api/v1/` are capabilities, authorized realms/processes,
process details, mailbox entries, outbox entries, effects, retained history, and
bounded journeys. Resource references preserve realm/PID, activation generation,
state revision, and effect/output identity. Lists have stable IDs, bounded
pagination/filtering, explicit coverage, and machine-readable reasons/errors.
Agents can retrieve evidence for a condition instead of relying on prose alone.

Generate an OpenAPI 3.1 document from Board's typed contract and reuse generated
Transit schemas for shared values, IDs, enums, and errors. This keeps one owner
for each wire definition. OpenAPI 3.1 supports JSON Schema 2020-12; generator and
validator compatibility must be proved, including integer ranges and union
encoding. See the [OpenAPI specification](https://spec.openapis.org/oas/v3.1.1.html).
Serve the versioned schema from the binary and generate the browser client from
that same artifact. CI must detect schema/client drift; TypeScript typing alone
is not runtime validation. This is a Board SDK, not a complete TypeScript Transit
execution client or a replacement for canonical Transit signing rules.

## Consistency, freshness, and retention

Every response must describe its observation basis: source realm, observed
position, policy revision, retained boundary, and completeness. Multi-source
results expose their separate observations; they do not pretend to be one global
snapshot. Explanations link to the records or current-state fields they use.
Distinguish protocol facts, derived conclusions, provider observations, and
application-declared labels. Unsupported or unavailable evidence is not zero.

Define a stable read boundary for paginated queries. Continuations bind filters,
realm, and view identity but never grant permission; reauthorize each page. If a
stable cut cannot be maintained within bounded resources, expire the query and
require an explicit refresh. Retention overtaking a read returns a defined gap
or resynchronization result, never a fabricated complete history.

A checkpoint can establish current state without retaining every prior turn.
Show missing history and unresolved links explicitly. Causation comes from
recorded links, not adjacent journal positions or matching payloads. A denied
resource must not leak through counts, graph endpoints, search, or pagination.

Start with bounded polling and on-demand history pages. Limit records scanned
as well as records returned, concurrent requests, refresh rate, memory, and
journey expansion. Slow clients must not accumulate unlimited work. Back off on
errors; distinguish stale observations, disconnection, denial, and a healthy
empty result. A signed command protocol does not guarantee read fairness;
qualify Board's load against the current sequential authority server.

M2 needs no durable Board database or second event archive. Small caches are
rebuildable and do not pin Transit history or extend its retention contract.
Do not serve cached sensitive results to a new request when current permission
cannot be checked. Browser data caches are bounded and cleared on logout or
known denial; previously disclosed bytes cannot be recalled. Retained snapshots,
exports, offline operation, and resumable push subscriptions need separate scope.

## Access and trust

Proposed first deployment profile: one configured realm and one read-only Transit
principal per Board instance. Operators/agents admitted to that instance share
that principal's explicit inspection scope; this does not claim per-user Transit
isolation. Bind upstream endpoints and identity in trusted server configuration,
not request-supplied URLs or principal IDs. Store signing seeds only on the server.
Board receives only read grants, with no admin, spawn, execute, send, publish,
or effect authority.

Authenticate both browser and agent ingress. A minimal proposal is a configured
Board access credential for agents and a bounded HttpOnly browser session
established through authenticated exchange; never put credentials in URLs or
static bundles. Validate origin/host and keep the service private, with TLS at
a trusted ingress for remote use. Loopback binding alone is not authentication.
Exact session expiry, credential rotation, and deployment trust must pass the
M2 access gate before any live data is exposed.

The node applies current Transit authorization at each read boundary. Board
additionally checks its ingress identity; a valid Board session cannot bypass a
revoked Transit grant. No Transit mutation routes, broad credentialed proxy,
provider diagnostics proxy, or automatic remediation are part of M2. Later
controls require attributable principals, explicit grants, preserved retry
identity, and their own adversarial proofs. See [SECURITY.md](SECURITY.md).

Treat payloads, names, and enrichment metadata as untrusted data: render text
safely, constrain previews, and fetch details explicitly. Static asset caching
must never cache authenticated API responses or embed installation secrets.

## Higher-level interpretation

A **lens** is a versioned Board interpretation of authorized kernel evidence.
It declares a namespaced kind/version, required capabilities, and how presented
facts link back to their source. M2 should prove a small statically registered
lens using an existing example, plus an unknown-version fallback. No Station
implementation is needed to establish this boundary.

Later Station supplies descriptors/fixtures for GenServers, supervisors, and
registries; the HTTP connector adds exchange and attempt views. Identification
must come from explicit, versioned application/framework declarations or an
operator-configured mapping with visible provenance. A numeric `code` tag,
process name, or payload shape alone cannot prove a behavior's identity.

Lenses may explain opaque bytes and recorded relationships but cannot overwrite
core lifecycle, invent causal edges, broaden access, or create execution rights.
An unrecognized schema still has a useful kernel view. Keep enrichment optional
and available as structured API data as well as UI presentation. Dynamically
loaded code, remote plugins, and executing application handlers to interpret
history are outside M2.

## Qualification and later scope

M2's [implementation sequence and exit criteria](roadmap/M2.md) cover the API,
embedded build, live UI, access control, retention gaps, and lens fallback.
Operational controls, multi-user delegation/federation, a complete Transit SDK
in another language, arbitrary dashboards, and full observability infrastructure
remain separate work. Metrics or deployment telemetry may enrich later views;
a provider's liveness report can never replace Transit's execution authority.
