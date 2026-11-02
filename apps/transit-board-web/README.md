# transit-board-web

Strict TypeScript, React, and TanStack Router file routes built with the pinned
Vite+ 0.3.3 toolchain, packaged as `@transit/board-web`. The static output is
embedded by the [Board executable](../transit-board/README.md), which hosts the private inspection and optional Table query APIs on the
same origin. There is no production JavaScript server.

Board loads feature implementations on demand through [the feature registry](src/features.tsx).
Catalog and retained metadata, Operations, datasets, workbooks and shared SQL
results, process/resource inspection, finite queries, Live views and recovery
have separate import boundaries. The shell retains deployment/interface validation,
navigation, observation ownership and shared presentation. Public client subpaths
keep importing a common error or formatter from loading an unrelated transport.

The build groups each feature with its client/validator dependencies. Module
preloading is disabled and CSS is delivered as one stylesheet to avoid a burst
against the embedded host's four request handlers. Every asset remains embedded
in the executable. [Build guards](vite.config.ts) enforce less than 900 kB per
script, fewer than 800 kB across at most four bootstrap scripts, no eager feature
implementations, and at most four additional scripts per feature import. Vite's
separate 500 kB advisory remains enabled. Browser checks exercise deferred
requests, navigation, direct nested-route reload and failed module downloads.
Loading and failed views retain shell navigation; a failed import offers an
explicit reload without starting data reads or automatically repeating work.

Standalone validators share repeated, scope-independent schema fragments during
generation through [the build helper](../../tasks/validator_schema.mjs). Public
schemas and runtime validation rules remain unchanged, and browsers still need
no runtime schema compilation or `eval`. The contract check compares shared and
original validation on positive and negative fixtures and checks generated drift.
Generated validators omit AJV's unused error-message text. Their public result
is boolean; callers retain their typed failure codes and Transit diagnostic
payloads. This reduces embedded script bytes without removing validation checks
or changing the validation contract.

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
evidence. Resource entries render as exact hex bytes after an explicit read. Process/resource
inspection retains one last-observed page during transient unavailability or
capacity refusal, with an explicit stale label and its original cut/time. It
clears on denial, expiry, incompatible response, hiding or scope replacement.
This qualified evidence adapter is separate from current metadata and result
state; a retry never relabels old evidence as a new observation.

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

Records and selected metadata reads use the shared observation owner. A rate-limit
response clears the page and schedules bounded exponential backoff (500 ms through
2 seconds); other transient failures back off through 30 seconds. A manual
refresh coalesces with an active read. Denial, expired history and incompatible
responses require explicit action. Hiding or disposal cancels queued work and
invalidates late replies. These policies confer no access to earlier data.

Recognized HTTP captures offer **Inspect HTTP metadata**. The selected view shows
frozen policy revisions, budgets, trust digest, timing, omitted field counts and
committed member references. Body values, raw routing fields and credentials are
excluded. Only the selected metadata records are verified; this view makes no
claim to have replayed the full body. It follows the same current-grant refresh
and clearing rules as the records view.

The data workbench uses horizontal activities and one contextual Inspector over
current authorized metadata or result views. Optional dataset/cell navigation,
expanded inspection and narrow layouts retain the underlying worksheet. See the
[workbench guide](../transit-board/docs/workbench.md#activities-and-contextual-inspection)
for interaction, evidence and clearing behavior.

## Working in the frontend

The reserved `/recovery/relational` route contains the [relational worksheet](../transit-board/docs/relational.md)
with explicit catalog routes, metadata-only Explain, Run and current/next-page
controls. It shows proposed and active plans separately and holds one row with
explicit prefix/completion status. Current-page reads repeat every five seconds;
hiding and failed access clear displayed rows and metadata. Browser reload uses
authorized active-session inspection without rerunning SQL. Query identities
remain separate from drafts, and no result or credential enters browser storage.

| Source                                                                                           | Owns                                                                                 |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ |
| [routes/](src/routes/)                                                                           | Overview, resource and PID/journey routes; stable URLs and route validation          |
| [observation.ts](src/observation.ts)                                                             | Deterministic scoped read transitions, generation fencing and typed failures         |
| [use-observation.ts](src/use-observation.ts)                                                     | Bounded read effects, deadlines, visibility and cleanup                              |
| [storage.tsx](src/storage.tsx)                                                                   | Paired storage visualizations/grids and selection-based evidence inspection          |
| [quantities.ts](src/quantities.ts), [quantity.tsx](src/quantity.tsx)                             | Exact integer normalization, binary-unit presentation and accessible exact-byte copy |
| [maintenance-model.ts](src/maintenance-model.ts)                                                 | Aggregate maintenance settings/activity with separate units and evidence meanings    |
| [retained-storage.tsx](src/retained-storage.tsx)                                                 | Shared Catalog/Operations selector, bounded directory and scoped coverage reads      |
| [retained-placement.tsx](src/retained-placement.tsx), [retained-model.ts](src/retained-model.ts) | Stable-ID placement diagrams, equivalent grids and one current-page Inspector        |
| [state.tsx](src/state.tsx)                                                                       | Shared process inspection state and polling lifecycle                                |
| [resources.tsx](src/resources.tsx)                                                               | Resource/association/entry reads and generic state presentation                      |
| [components.tsx](src/components.tsx)                                                             | Evidence, status and process views                                                   |
| [atlas.tsx](src/atlas.tsx)                                                                       | Growing catalog, emphasis, selection and explicit resource entry                     |
| [records.tsx](src/records.tsx)                                                                   | Growing record identities and source-backed exchange metadata                        |
| [http-metadata.tsx](src/http-metadata.tsx)                                                       | Selected HTTP policy, timing, omission and completion evidence                       |
| [query-workspace.tsx](src/unified-workspace.tsx)                                                 | One draft/result, explicit submission, current-policy refresh and denial clearing    |
| [workbench-layout.tsx](src/workbench-layout.tsx)                                                 | Shared navigation, selection identities, one inspector and keyboard return           |
| [catalog.tsx](src/catalog.tsx), [dataset.tsx](src/dataset.tsx), [workbook.tsx](src/workbook.tsx) | Catalog/dataset metadata and temporary SQL workbooks                                 |
| [workbench-result.tsx](src/workbench-result.tsx)                                                 | Shared result reader presentation, window profiles and observation evidence          |
| [model.test.ts](src/model.test.ts)                                                               | Model/client boundary tests                                                          |

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
Renderer implementations load by feature using the bounded asset layout above. Source
contract mismatch hides incompatible results while exact pending work survives.

## Reactive ownership

The composition root installs one request scheduler for the tab. Public client
transports acquire a permit around their bounded request/body-consumption chain:
two reads and one separate submission/control/cleanup request may be active.
Read starts are staggered by 75 ms. Separate FIFO queues hold at most 60 reads and four controls;
capacity refusal is typed and queued aborts remove work before dispatch. An active
request keeps its permit until it settles, even when a transport ignores abort.
A composite observation acquires permits only for its individual transport calls.
The scheduler supplies neither authorization nor retries.

| Owner / scope                          | Retained identity and disclosure                                   | Timer, retry and cleanup                                                                                                                                                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `state`, atlas, records, participation | Realm/PID/resource plus exact cursor/revision; one authorized page | Observation owner: five-second current-page reads, explicit continuation, 15-second deadline, transient backoff; scope/hide/dispose invalidate replies                                                                                         |
| HTTP/gRPC/Document metadata            | Resource, record and Document cursor                               | Same owner; current denial or failure clears evidence                                                                                                                                                                                          |
| Catalog, dataset, storage              | Exact namespace/definition/selector and coverage cursor            | Same owner; selection holds keys, views derive from the current page                                                                                                                                                                           |
| Published interface                    | Realm and source contract                                          | Same owner; only the built-in interface survives hiding; failed published reads never disclose an earlier definition                                                                                                                           |
| Workbook result                        | Original shared `StatementReader` identity and submitted SQL       | Statement presentation owner; serial Run/observe/next, five-second current-window validation, bounded transient backoff; hide/config loss clears rows and cancels; restoration observes the original reader; close reports unconfirmed release |
| Unified resource query                 | Retained query namespace, frozen pending request and source basis  | Shared query/Live owners retain their recovery semantics; tab hide aborts reads and pauses finite Live; original controls may settle; no implicit Run                                                                                          |
| Live Table metadata                    | Shared `Session` and exact pending control                         | `LiveView` owns finite events/renewal and pause cleanup; hiding/unmount pauses, showing does not implicitly Follow                                                                                                                             |
| Relational recovery                    | Original query identity, retained pin and pending intent           | Serialized owner; one five-second current-page timer, hidden reads aborted, controls recover the original identity                                                                                                                             |
| Deployment configuration               | Safe configuration flags only                                      | Observation owner may remain visible when hidden; flags do not authorize any data read                                                                                                                                                         |

All these transports use the tab scheduler. Statement completion and Live
settlement remain in their shared clients. The independent finite models and
complete reducer/effect replay run with `just test::board-model`; actual adapter
races are also tested. Neither establishes arbitrary browser scheduling or
server liveness. See [the model scope](../../tests/verification/models/README.md).
