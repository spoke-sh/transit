# transit-board-web

Strict TypeScript, React, and TanStack Router file routes built with the pinned
Vite+ 0.3.3 toolchain, packaged as `@transit/board-web`. The static output is
embedded by the [Board executable](../transit-board/README.md), which hosts the private inspection and optional Table query APIs on the
same origin. There is no production JavaScript server.

The build splits inspection, query/reactive and application clients from the
React/route entry, with a small shared bundler runtime. Route renderers remain
together and module preloading is disabled to avoid a burst of static requests
against the embedded host's bounded handler pool. This reduces individual file
size; these shared chunks still load on initial entry. All assets remain embedded
in the executable. The browser proof checks the module graph on initial entry,
navigation and direct nested-route reload, with at most five JavaScript assets
and each below 900 kB. Vite's separate 500 kB advisory remains enabled.
Relational validators share the query asset; the other Board validators stay
with inspection. This keeps the same asset count and startup request pattern.

Standalone validators share repeated, scope-independent schema fragments during
generation through [the build helper](../../tasks/validator_schema.mjs). Public
schemas and runtime validation rules remain unchanged, and browsers still need
no runtime schema compilation or `eval`. The contract check compares shared and
original validation on positive and negative fixtures and checks generated drift.
Generated validators omit AJV's unused error-message text. Their public result
is boolean; callers retain their typed failure codes and Transit diagnostic
payloads. This reduces embedded script bytes without removing validation checks
or changing the five-asset and 900 kB browser bounds.

Board provides a v1 workspace for explicitly configured KV/Table/Document sources.
It reuses the shared Zig SQL/finite-upload/page boundary, with runtime-validated
full-width scalar and nested cell states. Source capabilities, budgets, exact
result provenance and earlier-draft results stay visible. The
[configuration guide](../transit-board/docs/configuration.md#unified-state-query-workspace)
describes the separate query identity, exact retry and current-access behavior.

From the repository root:

```sh
just transit-board::install
just transit-board::check
just transit-board::demo
```

`just transit-board::build` and the root Zig builds install locked workspace
dependencies automatically before embedding the frontend; see the
[build commands](../../tasks/README.md). The explicit install above also prepares
the standalone frontend checks.

The [generated Board client](../../packages/ts/transit-board-client/README.md) supplies
wire models and CSP-compatible runtime validation. No signing seed or provider
access reaches the browser. Views open directly without a sign-in form or
Board session. Board sets no cookies and uses no local/session storage or offline
cache.
Known denial unmounts and clears data views; a retry rechecks the configured
Transit read grant. Startup failures also expose a retry action.

The overview, process tabs and journey use readable tables and sequence lanes.
Stable routes carry PID, tab, sort and lifecycle filters. Filtering applies to
the visible authorized page, not undisclosed totals. Polling preserves element
identity/focus, runs at five-second intervals and backs off to 30 seconds after
failures. Each view holds one page, aborts abandoned requests, pauses while hidden,
and never stitches a changed continuation. Historical pagination requires explicit
refresh; no unbounded graph or automatic scan is performed.

Opaque bytes render as escaped text or an explicit binary label. Timing labels
refer to the latest observation; no duration or ETA is inferred. State resources
and associations have generic views with explicit coverage, lifecycle and revision
evidence. Resource entries render as exact hex bytes after an explicit read.

## Visual design exploration

The interface provides a bounded resource atlas and an explicitly configured
KV/Table/Document query workspace.
Processes/Resources emphasis and overhead detail share stable selection. Resource
entry is explicit; Canvas and Browse retain one SQL draft and identified result.
Run compiles/submits once; switching views never runs it. Editing a completed
query preserves its result with a visible draft-changed label.

**Inspect SQL** sends explicit `DESCRIBE`, `SHOW TABLES` and `EXPLAIN SELECT`
statements through the shared query owner. Metadata and proposed plans appear
separately from verified data results, with current source/policy revisions,
output types, ordered operators and full-width limits. Inspection admits no
query work. Editing marks earlier metadata; hiding the view, changed observed
revisions, denied access and failed inspection clear it.

One verified result segment is resident at a time, with exact int64 strings,
nulls and binary labels. Five-second current-policy observations continue while
the resource interior is hidden by Neighborhood. Browser tab hiding clears
visible results; returning rechecks authority. Known denial/expiry clears the
source, draft and result. In v1 it also stops automatic reads, including after
follow-lease expiry; **Refresh query access** explicitly rechecks authorization
without selecting the cleared result again. **Resume without rerunning** selects
a retained namespace and verifies its result under current access. Its saved SQL
is unavailable, so the result is marked separately from the current draft.
The workspace retains frozen pending requests across
in-app route remounts for exact recovery; known denial does not invent their
rejection. Temporary connection failures retain permitted v1 rows with their
original source basis. A full page reload loses in-memory recovery bytes; no
browser storage or client retention pin is created. See the [live-view guide](../transit-board/docs/reactive.md)
for explicit Follow/Pause, complete-result verification and finite refresh budgets.

The atlas shows at most eight processes and eight authorized resources. Relief
marks pending work qualitatively; unavailable bytes, outbox counts and age stay
unknown. Keys include framework metadata. Only the configured query source has
an entry affordance for queries; all resources offer **Inspect records**, subject
to the configured read grant. That view holds eight record identities with
recognized exchange metadata and exact source revisions. It omits captured
bodies and application values, uses explicit continuation, and clears on errors
or tab hiding. Five-second refreshes recheck current authority. Automatic emphasis and animated entry are unsupported.

Records and selected metadata reads retry an explicit rate-limit response at
most three times, 250 ms apart, so they can recover between shared five-second
polls. Retries keep the same resource and continuation, stop on hiding or disposal,
clear displayed data before waiting, and do not retry denial, stale history or
unclassified failures. They do not
change the host's read limit or confer access to previously displayed data.

Recognized HTTP captures offer **Inspect HTTP metadata**. The selected view shows
frozen policy revisions, budgets, trust digest, timing, omitted field counts and
committed member references. Body values, raw routing fields and credentials are
excluded. Only the selected metadata records are verified; this view makes no
claim to have replayed the full body. It follows the same current-grant refresh
and clearing rules as the records view.

## Working in the frontend

The Operations screen includes a [relational worksheet](../transit-board/docs/relational.md)
with explicit catalog routes, metadata-only Explain, Run and current/next-page
controls. It shows proposed and active plans separately and holds one row with
explicit prefix/completion status. Current-page reads repeat every five seconds;
hiding and failed access clear displayed rows and metadata. Browser reload uses
authorized active-session inspection without rerunning SQL. Query identities
remain separate from drafts, and no result or credential enters browser storage.

| Source                                           | Owns                                                                              |
| ------------------------------------------------ | --------------------------------------------------------------------------------- |
| [routes/](src/routes/)                           | Overview, resource and PID/journey routes; stable URLs and route validation       |
| [state.tsx](src/state.tsx)                       | Shared process inspection state and polling lifecycle                             |
| [resources.tsx](src/resources.tsx)               | Resource/association/entry reads and generic state presentation                   |
| [components.tsx](src/components.tsx)             | Evidence, status and process views                                                |
| [atlas.tsx](src/atlas.tsx)                       | Growing catalog, emphasis, selection and explicit resource entry                  |
| [records.tsx](src/records.tsx)                   | Growing record identities and source-backed exchange metadata                     |
| [http-metadata.tsx](src/http-metadata.tsx)       | Selected HTTP policy, timing, omission and completion evidence                    |
| [query-workspace.tsx](src/unified-workspace.tsx) | One draft/result, explicit submission, current-policy refresh and denial clearing |
| [model.test.ts](src/model.test.ts)               | Model/client boundary tests                                                       |

Import public types and transports from `@transit/board-client`; do not copy
wire types into a route. Generated route trees and client validators are not
hand-maintained APIs. Make API changes in the Zig owner, run
`just transit-board::generate`, and use `just transit-board::check` before the
real embedded-browser proof. Keep business-value decoding in downstream UIs.

`just transit-board::browser` requires `just transit-board::browser-install` first. It starts the
actual embedded binary against a disposable realm; checks direct access, deep
links, lazy assets, keyboard focus across polling, causal/effect explanations,
denial clearing and connection retries;
and saves a local screenshot/failed traces under `.cache/`. Chromium needs its
host libraries; on supported CI Linux images Playwright can provision them with
`vp exec --filter @transit/board-web playwright install --with-deps chromium`.

The inspection proof enters the native v1 atlas, selects a process with the
keyboard, and opens the process evidence routes directly. It checks admission,
consumption, output and effect references, plus retained revision evidence during
an outage. Payload escaping uses an admitted mailbox value; resource inspection
checks source keys and writer/revision evidence without displaying application
values. CI retains failed Playwright traces and page context alongside task
completion records.

`just transit-board::query-browser` qualifies the growing atlas and workspace
against real hosts, including live revocation and lossless typed values.
`just transit-board::http-browser` checks actual HTTP capture metadata and live
read revocation against the disk/S3 worker fixture; it additionally requires Docker.

## Accepted Document metadata

Select a growing resource, inspect its records, then select a recognized Document
head. Board shows accepted revision/epoch, type/change format, retained history
floor, merge window, pending publication and retirement. Register conflict counts
cover one bounded page, including detached/deleted history; they are not totals
for visible fields. Next-page requests preserve the original resource revision;
errors clear the view and require an explicit refresh after a changed cut.
Application fields/text remain opaque. Current grants are rechecked on refresh;
hidden views and failed reads clear observations. `just transit-board::document-browser`
exercises the real worker and embedded UI, including live read revocation.

The shell, renderer routes, initial query SQL and navigation actions use
one shared compiled interface. See the [application guide](../transit-board/docs/application.md)
for reserved recovery routes, exact source-contract fencing and operator scope.
Renderer routes build in one entry because separate route requests can exceed
the host's bounded handler pool. Validator groups use the bounded asset layout
described above. Source
contract mismatch hides incompatible results while exact pending work survives.
