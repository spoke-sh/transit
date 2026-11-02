# 30. Board reimplementation and data-first workbench

[Roadmap](README.md) · **Status:** In Progress

Start with the [R1 reactive ownership delivery](#reactive-ownership-delivery-r1--2026-11-02)
and the [approved implementation sequence after PR 326](#next-implementation-sequence-after-pr-326--2026-11-01).
Storage placement and computation inspection are the next deliveries; installed
performance and the full workbench completion gates remain open.

Reimplement Board as the installed interface for discovering data, explaining
computations and reviewing governed changes. Deliver the focused catalog,
dataset previews, relationships, SQL workbooks, directed lineage and change
workflows developed in [board-data D2](../design/board-data/D2.md), with the
horizontal workbench and single-Inspector direction in
[board-data D3](../design/board-data/D3.md). Preserve
operational inspection and expose each capability through its owning public
operation; the interface does not become another catalog, query engine or
permission authority.

## Starting point and scope

At `f699e6ad`, D2 supplies a browser-rendered design prototype, synthetic fixtures
and high-resolution screenshots. It establishes review material, not an
implemented Board replacement. The reviewer endorsed the improved direction
and requested an explicit delivery milestone.

Current [Board](../../apps/transit-board/README.md) already provides bounded
read-only process/resource inspection, separately configured query and
application workspaces, explicit query submission, finite Live Table sessions
and embedded frontend assets. Preserve their supported behavior and recovery
evidence through the replacement. The [Board guide](../handbook/guides/inspect-board.md)
and [API reference](../handbook/reference/board-api.md) remain the current owners.

This milestone owns the complete Board product cutover: public API projections,
frontend implementation, capability-driven navigation, installed distribution
integration, accessibility and real browser acceptance. Backend algorithms,
transaction truth, retention, authorization and reviewed-publication semantics
remain with their existing owners. The D2 theme is the visual baseline; open
interaction questions remain in the [design sequence](../design/board-data/README.md).
D3 records the selected topology direction. Its synthetic storage, execution
and comparison studies remain proposals. The implementation slice below adopts
the topology for existing metadata and result capabilities; it does not complete
the milestone or extend backend evidence.

## Prerequisites and delivery position

Place this milestone after
[versioned proposals and reviewed publication](29-reviewed-data-collaboration.md)
and before [MCP service and interactive Apps](31-mcp-service-and-apps.md).
The full workbench needs the same investigation, proposal and publication
contracts that agent hosts will consume. Delivering the human interface first
provides a concrete caller for those workflows and their failure states.
MCP still consumes shared services directly and must not depend on Board's
frontend or API as an intermediary.

| Required capability | Owning milestone | Board consumption and boundary |
| --- | --- | --- |
| Stable objects, definitions and installed data lifecycles | [Identities](01-declarative-data-lifecycle.md), [live cutover](03-live-storage-and-sql-cutover.md) | Authorized catalog discovery and bounded metadata with distinct definitions, data revisions and observed progress |
| Typed results, transactions and caller recovery | [Statement results](04-statement-results-and-consumption.md), [transactions](05-transactions-and-atomic-composition.md), [client foundation](09-client-foundation-and-language-apis.md), [interface coverage](21-service-and-sdk-coverage.md) | Shared readers, explicit transaction attribution and original-operation settlement; no browser-only result or recovery protocol |
| Historical interpretation, derived computation and multi-model data | [Historical catalogs](10-standards-and-catalogs.md), [managed dataflows](12-sql-and-dataflows.md), [geospatial computing](17-geospatial-and-spatio-temporal-computing.md), [foreign relations](18-multi-model-and-foreign-relations.md) | Exact result bases, accepted projections/decoders, read-only 2D map (`MVT`/`GeoArrow`), progressive-LOD 3D mesh/scene/point-cloud (`glTF`/`3D Tiles`/`.mesh_edgebreaker`) and `PDF` spatial bbox layer inspection, five-state values and registered lineage; no raw storage inspection or arbitrary application-value decoding |
| Branches, policy and comparable investigations | [Branches](20-branches-merges-and-restore.md), [Control & Policy Plane](27-control-and-policy-plane.md), [published resources](28-published-resources-and-investigations.md) | Exact comparison inputs, authorized disclosure and retained investigation lifetimes; a screen label grants no access or retention |
| Review and conditional publication | [Reviewed publication](29-reviewed-data-collaboration.md) | Candidate-bound evidence, configured approval policy, conditional publication and uncertain-outcome recovery |
| Indexes, plans and measured costs | [Indexing](11-indexing-and-access-paths.md), [performance](13-data-structures-and-performance.md) | Shared definitions, build/coverage state, access paths and attributable metrics; statistics and estimates never establish result truth or administrative authority |

The linear position is the full-product completion gate, not a reason to defer
useful Board work. Catalog navigation, the visual shell and finite previews can
land incrementally as their owners qualify. Earlier milestones must continue
to migrate existing Board consumers during contract cutovers and provide their
required inspection and public-caller evidence. They cannot defer those duties
to this milestone. Likewise, this milestone cannot close with mocked or missing
backend operations by transferring its required workflows to a later milestone.

Preserve the private shared-scope inspection profile. Enterprise identity and
review capabilities are separately enabled profiles, not prerequisites for
opening a local catalog or querying a supported dataset. Later
[reactive context](32-reactive-context-and-agent-activation.md), outbound MCP and
complete mixed-language composition are not prerequisites for this cutover.
Existing qualified finite Live behavior remains supported; broader subscriptions
or agent activation require their own contracts.

## Contextual Inspector implementation

Implementation was authorized after the D3 review PR merged on 2026-10-30.
The delivered slice keeps the theme and replaces the workbench topology:
horizontal Data/Workbooks/Operations activities, optional dataset/cell navigation,
one shared Inspector, expansion into the workspace and a narrow-screen replacement
layout. Dataset definitions, schema columns, bounded result profiles and result
observation/completion evidence use their existing public clients. Selection
retains identities only; authorized data stays with its current reader.

The dataset's observed branch/object/definition remains above the workspace.
Workbook connection scope is not relabeled as a common branch or snapshot.
Inspection/expansion does not submit SQL, replace a result or discard drafts.
Published application navigation, definition recovery and the existing Operations
routes retain their owners and authority. The current interaction is described
in the [workbench guide](../../apps/transit-board/docs/workbench.md).

Dedicated Changes navigation, exact branch-comparison projections, object storage
sharing/reclaimability and measured operator metrics remain open delivery work.
No synthetic study values or unsupported actions enter the installed interface.
The milestone remains **In Progress**. Executed controls, clean-checkout outcomes
and remaining qualification limits are recorded in the
[Inspector proof account](../history/qualification/interfaces.md#board-contextual-inspector--2026-10-30).

## Operations and observation delivery — 2026-11-01

The implementation from `origin/main` at `0c64c4b03` delivers the first P0–P4
journeys below. Safe deployment discovery distinguishes configured Catalog,
SQL, relational, query, reactive and application connections from current read
access. An inspection-only built-in deployment lands on Operations; direct
Catalog/Workbook links explain their missing configuration without disabled-read
polling. Published interfaces retain their declared entry and recovery paths.

Operations pairs real node capacity/allocation and selected Table frontier
visualizations with exact grids and one Inspector. Catalog Table storage now
uses the same exact-binding public read composition as the relational caller,
without Explain, SQL execution or new maintenance authority. Relational query
controls and original-session cleanup move to `/recovery/relational`; interface
bindings move to Definition. Both requested panels are absent from Operations.

One deterministic observation reducer now owns Catalog, dataset metadata,
Workbook connection metadata and Operations reads, with typed failures,
generation fencing, visibility cleanup and bounded retry delay. Unavailable
Workbook metadata clears rows and Inspector content while retaining the shared
reader's original identity. Reconnection observes that result without rerunning
SQL. Current behavior and the transition model live in the
[workbench guide](../../apps/transit-board/docs/workbench.md#operations-and-observation-states)
and [interface Internals](../handbook/internals/service-interfaces.md#board-observation-state).

This is a focused delivery, not completion of P0–P4 or the milestone. Existing
process, query, reactive and published-interface lifecycles still have separate
owners; a global scheduling budget, independent temporal model with trace replay
and negative controls, broader failure/layout coverage and measured performance
budgets remain open. The reducer's bounded transition exploration is implemented,
but does not establish those stronger gates. M10 retained-definition/placement
inspection remains available; richer placement diagrams, M12 computation
neighborhoods, durable/governed workbooks and P5–P7 closure remain future work.
The milestone remains **In Progress**.

Executed browser/API evidence, the clean browser preparation workaround and the
incomplete installation lane are recorded in the
[Operations proof account](../history/qualification/interfaces.md#board-operational-inspection-and-connection-states--2026-11-01).

## Reactive ownership delivery (R1) — 2026-11-02

R1 centralizes ordinary observation effects and adapts statement presentation
around the shared `StatementReader`. Configuration, visibility, scope replacement,
deadlines and typed refusals now invalidate disclosure through explicit owners.
Reconnection observes the original result without resubmitting SQL. Lost cleanup
replies remain visibly unconfirmed. Process/resource inspection retains its
existing explicitly stale evidence policy during transient loss; denial and
scope replacement clear that evidence.

All public browser transports use one per-tab scheduler: two active read slots,
one separate control/cleanup slot, bounded queues and staggered read starts.
Query/Live, reviewed publication and relational recovery retain their shared
domain owners and original saved intents. The
[frontend owner inventory](../../apps/transit-board-web/README.md) records their
distinct lifecycles; the workbench guide and Internals own current semantics.

Independent finite observation, statement and admission graphs replay against
production TypeScript with model and implementation negative controls. Concrete
tests separately cover asynchronous dispatch, queue cancellation and response-body
ownership. Real installation fixtures provision all four Catalog/SQL combinations
with distinct read subjects and exercise same-origin local forwarding. These
checks do not establish arbitrary network progress, SSH security or the proposed
R4 resource/performance targets. Executed source-specific results, corrected
regressions and remaining limits are recorded in the
[R1 qualification account](../history/qualification/interfaces.md#board-reactive-ownership-and-independent-connection-profiles--2026-11-02).

The next implementation PR is R2's retained-storage placement and maintenance
inspection, followed by R3's managed-computation projection and neighborhood.
R4 retains the unresolved historical TLS-replacement cause, the newly observed
managed-table authorization refusal after replacement/resume, installed capacity
refusals and the SQL-only Run timeout, measured resource budgets and broader
accessibility checks. R5 and the original milestone gates
remain required; this delivery does not complete M30.

## Next implementation sequence after PR 326 — 2026-11-01

**Review status:** Approved for implementation; R1 is the current delivery. **Source basis:** `origin/main` at
`db0bb4a8f`, the merge of [PR #326](https://github.com/spoke-sh/transit/pull/326).
This sequence scopes separate implementation PRs. R2–R4 follow the R1 delivery;
R5 retains its service prerequisites. Executed evidence is attributed separately
below. M30 remains **In Progress**.

The next outcome is a Board whose visible state and background work have explicit
owners, followed by richer explanations of where data resides and why a
computation has or has not produced a newer result. Keep the existing horizontal
activities, paired visualization/grid and one Inspector. The removed Operations
panels stay removed; original relational work remains reachable through recovery.

### Delivered baseline and remaining obligations

PR #326 delivered independent configuration discovery, usable inspection-only
landing, typed observation failures, node/Table storage visualizations and the
Operations separation. Catalog, dataset metadata, SQL connection metadata and
storage use the deterministic observation reducer. Result readers, process and
resource inspection, finite Live and published interfaces retain other lifecycle
owners. The next work composes those owners and their effects; it does not give
the observation reducer authority over SQL settlement or Live controls.

The [qualification record](../history/qualification/interfaces.md#board-operational-inspection-and-connection-states--2026-11-01)
establishes focused final-source browser/API checks and an earlier clean browser
lane. It leaves three concrete gaps relevant to this sequence: separately
provisioned catalog-only/SQL-only installations, independent model-to-implementation
trace replay, and a complete installation lane. The installation lane stopped at
a SQL read after TLS replacement; its cause remains unresolved. No earlier pass
qualifies a later source automatically.

### PR boundaries and dependency order

| Review unit | Concrete result | Dependency and existing plan coverage |
| --- | --- | --- |
| **R1 — Reactive ownership and executable state evidence** | Shared read scheduling, composed lifecycle adapters, independent finite model/replay and real independent-configuration fixtures | First implementation PR; completes the remaining P0/P1/P4 obligations within the supported profiles and preserves P2 |
| **R2 — Storage placement and maintenance inspection** | Selected retained-definition/row-placement diagram and maintenance budget/state view, each linked to its exact grid and Inspector | R1 plus existing M10 historical callers; completes remaining P3 visual work and the storage part of P5 |
| **R3 — Computation evidence** | Read-only public projection and bounded source → computation → output inspection with last-complete and pending evidence | R1 plus M12 managed lifecycle/revision owners; follows R2 for delivery, without depending on its storage renderer |
| **R4 — Installed and measured acceptance** | Common-revision installation/browser/model results, performance budgets and accessibility evidence for R1–R3 | Measure and investigate from R1 onward; final run follows R3. Closes this delivery sequence, not all of P7 or M30 |
| **R5 — Durable workbooks and governed changes** | Shared persistent investigations, transaction presentation, comparisons and Changes workflows | Separate later implementation plans after the owning M20/M27/M28/M29 services meet the prerequisites below; retains P6 and full P7 closure |

Keep logical commits within each PR: transition/contract owner, consumers,
adversarial or installed proof, then current documentation and executed evidence.
If a prerequisite needs an owner fix, land and qualify that fix separately before
the dependent Board adapter. This sequence does not defer the original
[full completion journeys](#completion-evidence).

### R1 — Complete reactive ownership and prove it

**Lifecycle inventory.** Record each route's scope key, retained identity,
visibility behavior, timer, permitted retry, current disclosure rule and cleanup
owner before replacing hooks. Cover `state.tsx`, `atlas-observation.ts`,
`use-metadata.ts`, `records.tsx`, `participation.tsx`, `interface.tsx`,
`workbench-result.tsx`, `unified-workspace.tsx`, `live-table.tsx` and
`relational-workspace.tsx` in
[`transit-board-web`](../../apps/transit-board-web/README.md). Remove duplicate
polling implementations only as their callers migrate. Reconcile stale component
documentation that still places the relational worksheet on Operations.

**Deterministic transitions and effects.** Extend
[`observation.ts`](../../apps/transit-board-web/src/observation.ts) and its
[`effect adapter`](../../apps/transit-board-web/src/use-observation.ts) with an
explicit scoped scheduler. Use exhaustive event/effect unions and injected time
for deterministic checks. Carry scope, view/request generation and, for results,
original reader identity through queued work and replies. Scope replacement,
hide, denial and disposal invalidate queued work before another effect starts.
Selection stores identities; chart, grid and Inspector read one authorized owner.

Use these proposed scheduling limits:

- At most two simultaneous observation/result read requests per tab, one active
  request chain and one coalesced pending refresh per mounted owner. Register
  outgoing reads at the adapter boundary so composite reads cannot bypass the
  limit or deadlock by holding a permit while acquiring another.
- One separately bounded slot for explicit submission/control and original-work
  cleanup. It cannot carry ordinary background reads or authorize new work.
  Preserve per-owner serialization and the existing deployment-wide reader limits.
- Keep the five-second successful observation cadence, 15-second read deadline
  and 30-second transient backoff ceiling as the initial policy. Stagger reads,
  honor available rate-limit evidence and prevent automatic retries of permanent
  refusal. Manual retries coalesce with current work.
- Hiding cancels observation timers and queued reads and clears disclosure under
  the owning contract. Only already-required bounded cleanup may finish; it cannot
  create a repeating hidden-tab loop. Visibility restoration revalidates the
  original subject/result. It never reruns a statement or resets a Live budget.

Keep `StatementReader` responsible for logical results, completion, window
advancement and close. Adapt presentation around it. Keep finite Live/Follow's
qualified retained-result and exact-control recovery rules in its shared owner;
do not apply metadata's clearing policy indiscriminately. Definition publication
and relational pin recovery keep their saved original intents. Editing, selection,
refresh, reconnect and graph expansion cannot submit new SQL or controls; explicit
authorized Live execution retains its separately enabled finite semantics.

**Independent finite model.** Add a Board model beside the existing
[console/result models](../../tests/verification/models/README.md), using the
pinned TLC runner conventions. Begin with two scopes, two observation owners,
one statement owner and current/stale request classes; use distinct outstanding
identities rather than wrapping a tiny generation counter into an ABA match.
Explore visibility, selection replacement, deadline, denial, configuration,
explicit Run, lost replies and scheduler admission. Export the reachable graph
and replay every exported transition against the actual TypeScript reducer and
effect-dispatch boundary, comparing state, identities and effects.

Require invariants for cleared protected disclosure, stale-reply rejection,
bounded in-flight/queued work and original-operation preservation. Add negative
controls removing generation matching, denial clearing and explicit-Run guarding;
each must produce its named violation, and isolated implementation mutations of
those guards must fail the replay/race suite. Reject unknown actions, incomplete
exports, missing replay edges and timeouts. State finite bounds and any progress
assumption explicitly; neither this check nor the existing 870-transition unit
exploration proves arbitrary browser scheduling, network fairness or latency.
Register the real runner and evidence in the formal task inventory; do not add a
placeholder passing task.

**Installed fixtures.** Extend
[`board_workbench.py`](../../tests/interfaces/installation/board_workbench.py)
and the owning browser suites to start four actual configurations: inspection-only,
catalog-only, SQL-only and both. Use real configuration files and separate least-
privilege upstream identities; discovery-response interception is insufficient.
Check `/?status=all&sort=pid`, `/workbook`, dataset/schema access and preview gates.
Exercise same-origin forwarding through a local TCP tunnel and reject mismatched
Host/Origin without adding credentials to the browser.

**R1 exit gate.** Every inventoried owner either uses the shared scheduler or has
an explicitly tested adapter for its distinct lifecycle; none retains an
unaccounted polling loop. Deterministic and installed schedules cover old success
after denial/hide/scope change, 429, unavailable upstream, malformed/incompatible
responses, service replacement, empty/multi-window results, changed drafts, lost
Run and close replies. Unrelated authorized views remain usable; no protected
DOM/Inspector data returns; no replacement query is created. All four real
deployment profiles pass. Model/replay and its negative controls pass, with
source-attributed limits. R1 does not depend on adding new storage/computation UI.

### R2 — Explain retained storage placement and maintenance

Reuse the existing `HistoricalObject` reads in
[`data-workbench.tsx`](../../apps/transit-board-web/src/data-workbench.tsx),
[`DataCatalog`](../../packages/ts/transit-board-client/src/catalog.ts) and the
[historical catalog contract](../../contracts/HISTORICAL_CATALOG_V1.md#historical-interpretation-coverage).
Extract a selected-object inspection component usable from the dataset and
Operations contexts. A supplied retained selector plus stable object and coverage
kind identifies the observation; selection does not acquire a snapshot or pin.

Show logical definition → physical definition and returned row → WAL/segment
placement relationships using only the selected page. Physical-definition
inspection remains available with metadata rights; row placement requires
SELECT. Keep their continuations separate. The current owner returns one physical
schema generation or at most eight row locations per page. Label partial traversal
and distinguish directory exhaustion from payload verification or query completion.
Do not infer segment sizes, live row counts, reclaimability or complete inventory.

Add the node maintenance diagram using existing configured budgets, state,
activity counters and failure fields. Preserve independent units and reset
semantics. Match Table frontier lanes to their exact partition and boundary
conventions; retain full-width integer labels, unknown versus zero and bounded
backlog coverage. All visuals share selection and evidence with their exact grids.

Register the next review in the
[board-data sequence](../design/board-data/README.md) for monochrome placement,
maintenance and computation wireframes, including narrow layout, keyboard focus,
empty/denied/partial states and Inspector behavior. Design fixtures remain labeled
synthetic; installed screenshots and acceptance use real public evidence.

**R2 exit gate.** Traverse more than one retained page after schema evolution and
rename, then test changed selection, expired retention, revoked metadata and
revoked SELECT independently. Compare diagram/grid identities with an independent
public caller. Inspect accepted WAL data, observed maintenance and a reopened
disk-backed fixture without browser writes. Selection, expansion and paging
neither execute SQL nor start maintenance. Keyboard and pointer selection agree.

### R3 — Explain completed and pending computation

Start with the installed single-source/single-output managed Table profile from
[M12](12-sql-and-dataflows.md#retained-completed-table-revisions--2026-11-01).
Use [`ManagedTable`](../../packages/zig/transit-query-direct/src/ManagedTable.zig),
its retained revision owner and [DATAFLOW_V1](../../contracts/DATAFLOW_V1.md).
Publication, activation, progress, committed completion and retained result
disclosure remain distinct. Output chaining, multi-source execution and historical
SQL row fetching are outside this delivered profile.

Before adding a graph, define a bounded typed public inspection composition for
exact declaration lookup, current observation and selected completed revision.
Board currently has no dedicated adapter for these facts. Put reusable read
composition with the public query/catalog caller, then adapt it in Board's Zig
service and generated browser client. Audit the current grants for each field,
including source/output/control evidence and post-buffering disclosure; a
control-head read alone must not grant access to a retained result. If discovery
cannot use an existing bounded public directory, start with explicit scoped
lookup and deliver the missing directory through its owner before enabling browse.
Do not scan raw storage, guess catalog token layouts or issue hidden Workbook SQL.

The projection must identify declaration/object/definition, control epoch,
observed lifecycle and failure, last completed revision/decision, exact source
and output definitions/cut, and pending work only where supplied by the owner.
Validate neutral responses at runtime. Contract additions or incompatible changes
follow the current-v1 generation/cutover policy and migrate consumers together.
Reading the projection must never initialize, activate, refresh, suspend or
retire a computation, acquire retention or consume result payloads.

Render a directed source → computation → output neighborhood with a shared exact
grid and Inspector. Keep the last completed revision distinct from a pending,
blocked or failed successor while current authorization permits its disclosure.
Known denial clears affected evidence. Independent observations carry separate
bases; only an owner-proved common decision is presented as atomic. Start with
the actual three-node profile; cap any later explicit neighborhood expansion at
32 nodes/64 edges and label truncation. Registered dependency edges do not imply
that output chaining or incremental execution is supported.

**R3 exit gate.** An independent typed/SQL caller agrees with the Board projection.
A real managed fixture completes a revision, advances its source, then exposes
pending and blocked/failed successor evidence without replacing the completed
revision. Cover empty output, source-definition replacement, suspended restart,
retirement, missing revision and revoked source/output/control access. Advance
the fixture through its owning caller, never through graph rendering. Exact
recorded observations replace timing guesses for transient states. Metadata-only
inspection creates no work or result readers.

### R4 — Qualify the installed sequence and its resource budgets

Begin investigation of the recorded post-TLS-replacement SQL failure during R1.
Reproduce it on the merged baseline and capture the owning SQL/transport cause,
original accepted identity and replacement trust state. Fix the responsible
owner or fixture with a focused regression; a passing retry, skipped assertion
or larger timeout does not settle the cause. The later installation tasks must
actually run before the lane is reported complete.

Collect baseline measurements before changing scheduling, then apply these
**proposed acceptance targets**, not claims about current performance. Use the
pinned Chromium, ordinary ReleaseSafe binaries, a named local host, disk-backed
fixtures and recorded viewport/build; report remote-tunnel latency separately.

| Measure | Proposed target and measurement boundary |
| --- | --- |
| First useful observation | p95 at most 2 seconds warm and 5 seconds with a fresh browser context, from navigation start against an already-ready local service to the first authorized primary view; report service startup separately |
| Selection and rendering | p95 at most 100 ms for chart/grid/Inspector selection and for painting a bounded page after response validation; record both intervals separately |
| Scheduling | At most two observation/result reads plus the single bounded explicit-control/cleanup slot per tab; no hidden observation retries and no read-per-render behavior |
| Residency | At most the existing four cells, 100-row/2-MiB window per reader and four readers shared by the deployment; metadata/graph residency stays within selected-page/display caps |
| Retained memory | After 100 settled navigation/open/close cycles and test-only GC, retained JS heap increases by at most 5 MiB over the equivalently settled baseline; report peak heap separately |

Use at least 30 samples for latency percentiles, record raw timings, and freeze
the named fixture and thresholds before acceptance runs. A missed proposed target
requires a measured explanation and an explicit plan revision, not silent budget
inflation. Exercise one, two and four visible tabs plus a hidden tab under the
same deployment capacity, including reader-capacity refusal and lost cleanup
acknowledgements. No cross-tab leader election is proposed; shared service limits
remain authoritative. Increasing retained catalog size must not increase the
selected display's resident pages or trigger a full scan.

Check keyboard-only use, focus return, screen-reader descriptions, reduced motion,
200% zoom, narrow layouts and the original desktop layouts. Retain the 128-file/
8-MiB embedded-asset bounds and five-JavaScript-asset/900-kB checks. Record manual
screen-reader evidence separately from automated accessibility scans.

For each PR, run its owning component/API/browser checks. For final acceptance,
run committed-HEAD clean `installation-ui` and `browser` lanes, plus `formal`
for R1 and `interfaces`/`core` when shared contract or authority changes require
them. Establish the model, caller and browser evidence at the same final revision;
report preparation failures and incomplete tasks explicitly. Publish supported
behavior in the Board guide/API/component docs, the state model in service-interface
Internals and executed results in qualification history. Settle the applicable
initial-pass checkboxes with those results; keep full M30 completion open.

### R5 prerequisites and full milestone closure

The local inspection profile remains usable while later owners develop:

| Later Board delivery | Required service evidence before implementation |
| --- | --- |
| Durable workbook save/share/resume | M28 public identity, revisions, concurrent editing, disclosure and retained investigation/result lifetimes, exercised by a non-browser caller across replacement and revocation |
| Transaction presentation | Existing M4/M5/M9 statement/session owners and a separately authorized Board profile for provisional results, commit/rollback and original uncertain-operation settlement; read-only inspection/Workbook admission remains enforced |
| Branch comparison and Changes | M20 exact comparison bases and conflicts, M27 current policy and M29 candidate-bound review/conditional publication, including moved targets and lost replies |
| Richer workload inspection | M11/M13/M17/M18 and distributed owners supply the particular index, measured resource, spatial/layout or recovery projections; synthetic studies supply no metrics or access |

Plan and qualify each adapter after its non-browser lifecycle is established.
Workbooks must not acquire a browser-local persistence/permission authority, and
an independently run cell must not be relabeled as a shared snapshot. M29 remains
Planned at this source basis. R1–R4 can complete independently, but durable
workbooks, transaction/review journeys, the remaining full-milestone inspection
requirements and common-revision cutover evidence still gate M30 completion.

## Remaining implementation plan — 2026-11-01

**Original design basis:** `origin/main` at `0c64c4b03` (2026-11-01), before
PR #326. This section retains the P0–P7 boundaries, source assessment and acceptance
matrix that guided that delivery. The
[post-merge sequence](#next-implementation-sequence-after-pr-326--2026-11-01)
now owns the next PR boundaries and proposed limits; the
[delivery record](#operations-and-observation-delivery--2026-11-01) identifies
implemented behavior. The milestone remains **In Progress**. Earlier imperative
steps below are original design requirements, not a claim that their work is
still wholly unimplemented.

### Outcomes and immediate decisions

Use two journeys to drive the remaining implementation:

1. **Understand the running system.** Open Operations, select an installation or
   data object, compare a visualization with its exact grid, then inspect the
   evidence explaining storage, progress or a failure. Keep system introspection
   useful without a configured SQL connection.
2. **Understand the interface's state.** Open Board through the installed URL or
   an SSH forward and immediately distinguish a usable inspection deployment,
   an unconfigured data feature, a denied read and a broken connection. Every
   visible action follows an explicit state transition and has a bounded owner.

Remove **Relational worksheet** and **Declared dependencies** from `/operations`.
The latter currently lists the installed interface's bindings; it is not a
storage dependency graph. Keep interface bindings with Definition and actual
object dependencies with the selected dataset/computation. Ordinary SQL belongs
in Workbook. Move original relational-session inspection and pin cleanup to a
dedicated recovery surface before removing their current entry point. Preserve
per-Table storage inspection independently of SQL editing.

Retain D3's horizontal activities and one contextual Inspector. Implement the
state model in the existing strict TypeScript/React application, with effects
calling shared clients. Reactive UI behavior means reacting to typed events;
it does not enable Live SQL, continuous queries, automatic administrative work,
or M32 subscriptions. Existing finite Live/Follow retain their qualified owners.

### Source assessment and milestone handoffs

| Evidence at the source basis | Consequence for this plan |
| --- | --- |
| [`foundations.tsx`](../../apps/transit-board-web/src/foundations.tsx) renders Storage, `RelationalWorkspace` and interface bindings together. [`storage.tsx`](../../apps/transit-board-web/src/storage.tsx) obtains Table storage through the relational description's prepared source binding. | Extract the useful Table inspection and recovery paths before removing the worksheet; deleting the component alone would strand both. |
| [`Capabilities`](../../packages/zig/transit-board-api/src/root.zig) reports the older `query_enabled` and `reactive_table` capabilities, but no separate catalog/SQL-workbench configuration. [`main.zig`](../../apps/transit-board/main.zig) returns `404 QueryDisabled` when the corresponding workbench configuration is absent. | Add explicit per-feature configuration discovery. The older query flag cannot decide whether Catalog or Workbook works. Configuration evidence is not authorization. |
| [`data-workbench.tsx`](../../apps/transit-board-web/src/data-workbench.tsx) collapses metadata errors to strings, retries every five seconds and uses the same unavailable panel for Catalog and Workbook. [`state.tsx`](../../apps/transit-board-web/src/state.tsx), [`use-metadata.ts`](../../apps/transit-board-web/src/use-metadata.ts) and [`workbench-result.tsx`](../../apps/transit-board-web/src/workbench-result.tsx) separately own request and visibility transitions. | Replace these overlapping transitions with typed state/effect owners and feature-specific diagnostics; preserve each client's existing disclosure and recovery semantics. |
| [M4](04-statement-results-and-consumption.md) supplies `Executor`, `ResultSet`, `ReadView`, `ReadWorkspace` and the browser `StatementReader`. [M8](08-gateway-architecture-and-protocol-ingress.md) supplies co-hosted execution and event-driven recovery; [M9](09-client-foundation-and-language-apis.md) is integrating shared contexts and recovery. | Consume logical results and original-operation recovery. The UI machine owns presentation and request lifetimes, not SQL parsing, native fetch sequencing, accepted-work settlement or service recovery polling. |
| [M6's current checkpoint](06-streams-queues-and-durable-runtime.md#progress-checkpoint--2026-11-01) adds SQL workload outcomes, Stream intervals and Queue receipts/ACK, with installed and performance gates still open. [M7](07-document-storage-and-station-decoupling.md) is integrating direct Documents and replacing Station consumers. | Extend kind-specific inspection only through their public callers. Queue claim/ACK and Stream offset settlement are mutations even when they return rows; Workbook's read-only admission must continue to refuse them. Do not infer a completed Station cutover or enable a workload from parser support. |
| [M10's progress scope](10-standards-and-catalogs.md#progress-pr-scope--2026-11-01), merged in `9d7a15fd6`, includes historical catalogs/SQL, physical definitions, row placement, constraints, collations and versioned interpretation descriptors; Board already contains read-only historical inspection. | Reuse these real projections for storage drilldown and exact definitions. Separate metadata rights from SELECT for row placement, directory coverage from payload verification, and current permissions from historical data. Final installed/browser qualification remains required. |
| [M12's installed finite lifecycle](12-sql-and-dataflows.md#installed-table-implementation-slice--2026-11-01) and [retained revisions](12-sql-and-dataflows.md#retained-completed-table-revisions--2026-11-01), integrated by `0c64c4b03`, supply observed controls, output/checkpoint commits and `DFR1` revision manifests. | Prioritize computation inspection showing last completed output, pending/blocked work and exact source/output revisions. Retained revision metadata is not historical SQL row fetching, incremental execution, multi-source support or complete M12 qualification. |
| [M11](11-indexing-and-access-paths.md), [M13](13-data-structures-and-performance.md), [M20](20-branches-merges-and-restore.md) and the distributed operations milestones own index coverage, measured resources, branch roots and recovery evidence. | Request missing bounded projections from these owners before drawing segment inventories, index readiness, shared/exclusive/reclaimable bytes, cache hit rates or replication lag. D3's synthetic numbers establish none of them. |
| [M27](27-control-and-policy-plane.md) and [M28](28-published-resources-and-investigations.md) have contracts and component evidence; [M29](29-reviewed-data-collaboration.md) remains Planned. | Keep the local shared-scope profile independent. Gate durable investigations, policy-aware sharing and reviewed publication on qualified public services and non-browser callers; component fixtures do not establish installed workflow support. |
| [M31](31-mcp-service-and-apps.md) follows Board; [M32](32-reactive-context-and-agent-activation.md) owns later durable interests and activation. | Share semantic projections and suitable presentational components without making MCP depend on Board or inherit its credentials. A UI refresh event is not a durable subscription or a completed computation. |

Preserve the [Inspector qualification](../history/qualification/interfaces.md#board-contextual-inspector--2026-10-30)
and [initial workbench evidence](../history/qualification/interfaces.md#board-catalog-and-bounded-read-workbench--2026-10-28),
including their interrupted clean lanes. Their passes remain attributed to
their revisions; this newer source is not qualified by combining earlier runs.

### Capability discovery and the reported tunnel journey

The reported `/` and `/workbook` pages are consistent with missing workbench
configuration: their catalog and SQL-read API requests receive `QueryDisabled`
when those connections are absent.
This is a source-based explanation, not a diagnosis of the remote installation.
An SSH tunnel alone neither enables a catalog nor grants SQL access. The current
`/health` endpoint checks Board's listener boundary, not upstream data readiness.

Extend the existing generated Board capability projection with independent
descriptors for inspection, node storage, catalog metadata, SQL reads, relational
recovery, finite Live and application operations. Each identifies implementation
support, configuration state, safe scope identity and applicable limits. Discovery
does not execute a query or test every resource. Access and readiness are learned
from the corresponding authorized read; a descriptor never grants permission.
Do not disclose credentials, secret file paths or arbitrary connection strings.
Keep existing descriptor fields only for their distinct capabilities; migrate
incompatible shapes through the current-v1 definition cutover.

The current capability handler also performs an upstream inspection-identity
read. Separate safe deployment configuration discovery from that authorized
observation so an unavailable inspection upstream cannot suppress the shell or
unrelated configured features. Keep private admission and Host/Origin checks;
withhold identity, resource and policy evidence when its read fails. Configuration
discovery is not a replacement for that read or for per-operation authorization.

For the built-in interface, resolve `/` after capability discovery: Catalog when
configured, otherwise Workbook when SQL reads are configured, otherwise
Operations. A configured feature that later fails remains selected with its
actual failure; do not bounce between routes to conceal an outage. Published
interfaces retain their declared entry and reserved recovery routes. Normalize
the former root's `status=all&sort=pid` search parameters without forwarding them
as catalog filters or triggering reads. Explicit deep links remain addressable.

| Condition | Expected presentation and permitted next step |
| --- | --- |
| Inspection available; catalog and SQL unconfigured | Root opens useful Operations. Data/Workbook navigation identifies unavailable configuration. Their direct routes say which connection is unconfigured, link setup documentation and Operations, and issue no periodic disabled data requests. |
| Catalog configured; SQL unconfigured | Catalog and definitions work. Preview/Run are unavailable with an SQL-specific reason; an explicit Workbook link explains setup. A catalog connection is not an SQL connection. |
| SQL configured; catalog unconfigured | Workbook works independently. Catalog explains its missing connection; do not gate SQL on catalog discovery. |
| Configured read denied | Say which feature/scope was denied, clear its protected data and offer an explicit access recheck after an operator correction. Do not label it missing configuration or ask a viewer to sign in. |
| Transport/upstream unavailable | Show the failing boundary when evidenced, last observation status and bounded read retry. Keep unrelated authorized surfaces usable. Reconnection cannot execute a statement again. |
| Invalid Host/Origin or incompatible definition | Show the typed refusal and deployment/build remedy. Do not relax origin checks, retry indefinitely or interpret an incompatible response. |
| Successful zero-row result or empty catalog page | Show verified empty result or page-scoped absence respectively. Neither missing configuration nor a failed read is an empty dataset. |

Configuration is currently loaded at startup. The setup remedy must name that
restart requirement until its owner implements reload. A **Check availability**
action can re-read descriptors after correction; **Retry read** is not the cure
for a connection that has never been configured. Use same-origin relative API
requests through the forwarded Board URL. Test localhost and 127.0.0.1 as their
own origins, including rejected mismatches; never weaken the private boundary.

### Reactive UI state and effect ownership

Define a deterministic `state + event -> next state + effects` reducer with
exhaustive discriminated unions. React renders selectors and dispatches events;
an effect runner performs client calls, timers, aborts and cleanup and returns
typed completion events. Keep domain readers in their existing shared packages;
route/selection composition belongs in `transit-board-web`. Do not introduce a
new runtime package or state-machine dependency without a demonstrated need.

Use composed machines, rather than a global `loading/error/connected` flag:

| Owner | State and retained identity |
| --- | --- |
| Shell | Bootstrapping, usable or failed discovery; build/definition and current configured scope. Failure to inspect a resource does not erase unrelated feature state. |
| Feature | Implementation/configuration disposition (`unsupported`, `unconfigured`, `configured`) and independent observed access/connectivity. Configured does not mean authorized or reachable. |
| Observation | Idle, loading, ready, refreshing, unavailable, denied, incompatible or expired; exact resource/definition, observation basis, continuation and request generation. Hidden/disposed visibility is separate. |
| Statement presentation | Draft revision, submitted revision and original reader identity; submitting/observing/advancing/closing request state, shared result outcome and cleanup status. Verified completion, consumer exhaustion, display limit and remote release remain separate. |
| Workbench selection | Route and scoped stable subject; selected row/column, Inspector dimension, expanded layout and focus return. Selection contains identities, not a second protected data cache. |
| Optional Live/review | Project the existing Live owner or later proposal owner. Their session/candidate/generation, budgets and terminal outcomes never become ordinary observation retry state. |

Every asynchronous event carries its scope generation, view identity and request
generation; results also carry the original reader identity. Match all applicable
fields before applying it. An old completion may require cleanup through its
owner but cannot repopulate a hidden, denied, replaced or differently scoped view.
Do not invent a server policy epoch where the owner supplies none: local request
generations fence UI work, while current authority remains checked upstream.

| Event and guard | Transition and effect |
| --- | --- |
| Descriptors received for current shell | Resolve feature availability and built-in landing; schedule only eligible metadata reads. |
| Feature unconfigured/unsupported | Enter explanatory state, cancel feature reads and disable query effects. Recheck only on explicit availability refresh or a real configuration-generation event. |
| Route/subject selected | Increment generation; abort replaced reads and release obsolete selection. Acquire bounded metadata only. No preview, Run, pin acquisition or maintenance follows selection. |
| Authorized observation received | Install one validated page and its basis atomically. Grid, visualization and Inspector select from that owner. Empty requires successful page evidence. |
| Refresh timer or explicit retry, visible/configured/eligible | Schedule at most one read for that owner. Transient failures use capped backoff; rate limiting honors available retry evidence. A permanent refusal requires its stated remedy. |
| Document hidden or scope replaced | Stop timers, abort current reads and remove protected observation/Inspector content. Preserve only recovery intent allowed by its owner. Visibility restoration revalidates the same owner before disclosure. |
| Current denial | Clear affected rows, metadata, charts, profiles and sensitive diagnostics/drafts according to the existing owner contract. Preserve unresolved operation evidence privately through its existing recovery owner; no automatic replacement work. |
| Definition/cut changes or history expires | Clear the invalid observation and continuation; require a fresh selection/read. Do not combine pages or silently bind a name to a replacement object. |
| Explicit Run, configured/authorized read profile and no conflicting request | Freeze draft revision, release the prior reader and call `StatementReader` once. Later edits mark earlier output; they do not change its basis or execute SQL. |
| Lost Run/advance reply | Observe the original reader through the shared client when supported. If its owner is gone, show lost/incomplete outcome; never rerun and splice a new result. |
| Verified terminal / display cap / Stop waiting / Close | Project the distinct shared outcomes. Closure requests cleanup; missing close acknowledgement is not proof of remote release. Native leases continue to bound abandoned ownership. |
| Graph/grid/Inspector selection | Update shared stable selection and focus only. Drilldown is an explicit bounded metadata read; expanding a view does not execute a query. |

Migrate the existing finite Live/Follow adapter without flattening its retained
last-result and exact-control recovery rules into the stricter metadata clearing
rules. Its qualified temporary-unavailability behavior remains owner-specific;
known denial still clears protected disclosure. Inventory its permitted saved
control intents separately from prohibited persistence of rows or credentials.

Use the current five-second visible observation interval and existing client
rate-limit limits as the baseline. A shared scheduler staggers eligible reads,
allows one in-flight read per owner and proposes at most two data reads per tab,
with bounded control/cleanup priority. These are client limits, not a relaxation
of Board's shared service limits. Polling never reruns a SELECT. No hidden tab
work or tight retry loop is allowed to sustain itself. Keep finite metadata/read
retries distinct from explicit recovery actions and irreversible effects.

### Operations: visual evidence paired with exact grids

Make Operations a read-only investigation of storage and execution. Keep the
installation scope and read state visible above its primary visualization/grid;
use the shared Inspector for a selected fact or object. A visualization and its
grid consume the **same observation**, share selection, filters and coverage,
and never fetch independently. Preserve keyboard access, exact values, units,
null/unavailable distinctions and source links in the grid. A drawing is another
projection of evidence, not a second measurement or a health authority.

| Inspection question | First visualization and grid | Evidence and limits |
| --- | --- | --- |
| What is consuming admission capacity? | Separate capacity bars for accounted storage, data-request allocations and control-request allocations; exact used/limit/peak rows where supplied. | Existing `/api/v1/storage`. Control reserve is not ordinary free space; allocation counters are not filesystem free space or process RSS. Never add unlike counters into a fabricated total. |
| What maintenance is observed? | Labeled disabled/waiting/running/failed state and configured work-budget diagram, with exact counts and failure category alongside. | Existing node storage response. Volatile step counters reset on owner restart and do not establish per-Table completion, rates or an ETA. |
| Where is this Table's accepted data relative to maintenance? | Position lanes for accepted/logical-change, pending backlog, archive, recovery and history boundaries; separate fixed-target/activity indicators for archive and compaction. | Existing signed direct Table `storage` operation. Show partition and exclusive/inclusive conventions from the contract. A bounded pending prefix is a lower bound; it cannot produce a percentage-complete or time estimate. |
| Which retained definition and physical placement explain this row? | Selected physical-definition/placement map linked to the exact bounded directory grid and definition Inspector. | M10 historical catalog reads. Explicit retained selector, metadata-versus-SELECT permission and separate page continuations; no new retention pin, payload scan or claim of complete segment inventory. |
| Why has a computation not produced a newer result? | Directed, bounded source → computation → output neighborhood with separate last-completed revision and pending/blocked progress rows. | M12 public metadata and registered dependencies, integrated after the storage slice. Independent observations do not become one atomic graph snapshot or a freshness guarantee. |

For Table storage, add the missing exact-bound read composition to the public
catalog caller before its Board adapter; `DirectCatalogRead` currently has no
storage action. Reuse the signed direct storage operation and its current rights,
not raw storage access or a browser-built SQL parser. Keep
`SHOW STORAGE FOR name` as an independent SQL oracle. Configurations that only
provide a relational catalog retain a scoped storage adapter over that same
caller until explicitly migrated; do not borrow inspection or SQL credentials
or create another authority. No query, pin journal write, flush or compaction is
needed to inspect storage.

The first slice uses current observations, not an invented history service.
Position axes compare only the same partition and preserve full-width integer
labels; scaled visual coordinates cannot replace exact arithmetic. Do not sum
independent Table observations into installation totals. Charts and grids clear
together on failed revalidation or lost visibility. Add time series only after
the public owner supplies restart/reset identity and sample timing semantics;
then specify a bounded window and explicit gaps before enabling rate charts.

Retain public API bounds: one page per selected source, the existing 1,024-row
pending-backlog examination bound, and explicit Next/Refresh for catalogs and
retained placement. Propose at most 32 visible graph nodes and 64 edges, with
visible truncation and explicit neighborhood expansion; these are display caps,
not new authority page limits or evidence of complete lineage. No background
whole-catalog scan, graph layout on undisclosed data or per-row heap of readers.

Richer segment sizes, tombstones, retention blockers, shared/exclusive bytes,
reclaimability, index build coverage, replication and WLM belong in subsequent
owner-backed projections. Every added metric must specify units, population,
observation/reset identity, pagination, current authorization and unavailable
semantics. Until that contract exists, omit the visualization or mark the
dimension unavailable. Never reconstruct provider internals from paths or
promote a synthetic D3 fixture into an installed fact.

### Reviewable implementation sequence

| Slice | Owners and concrete work | Exit gate |
| --- | --- | --- |
| **P0 — Capability and diagnostic contract** | `transit-board-api`, Board `main.zig`/`Workbench.zig`, generated `@transit/board-client` and launcher configuration. Add independent descriptors, typed failure classification and the route/retained-work inventory. Resolve safe configuration versus access evidence before views depend on it. | Contract/validator checks and direct API tests distinguish unconfigured, denied, incompatible and unreachable; neither discovery nor a stronger configured credential bypasses read-only admission. |
| **P1 — State machine and usable landing** | Board frontend reducers/effect runner, `state.tsx`, metadata hooks, `interface.tsx`, root/catalog/workbook routes and shared-client adapters. Implement the transition tables, capability-driven root and feature-specific setup/refusal states. | Reproduce both reported URLs with no workbench configuration: usable Operations landing and explicit Workbook setup state, no repeated disabled calls or false empty data. Catalog-only and SQL-only deployments work independently. |
| **P2 — Operations separation** | `foundations.tsx`, `relational-workspace.tsx`, `storage.tsx`, public catalog read composition and service routing. Remove both named panels from Operations. Place interface-binding detail in Definition; put supported relational active-result inspection and exact pin cleanup under a proposed `/recovery/relational` route. Preserve new-read access through Workbook or an explicitly named remaining qualified read profile until equivalence is proved. | No SQL editor or interface-binding table on `/operations`. Existing Table-storage detail, original query inspection/close and restart pin cleanup remain reachable; opening recovery executes no query. Published-interface validation, deep links and fixtures migrate with the route. |
| **P3 — Storage visualization and grid** | Shared observation selectors and Inspector plus Operations renderers. Deliver the first three storage views above; register the next `board-data` design review for visual/interaction choices using monochrome wireframes. | Real node and Table values match both projections and an independent public caller. Unknowns, zero, bounded prefixes, restart and maintenance failure remain distinct; pointer and keyboard selection agree. Design review does not substitute for installed evidence. |
| **P4 — Workbench state integration** | `data-workbench.tsx`, `workbench-result.tsx`, Inspector and `@transit/query-client`. Apply the same lifecycle composition to catalog paging, historical selection, previews and session cells; migrate duplicate hooks without recreating shared result truth. | Delayed replies, route/scope changes, hidden tabs, earlier drafts, lost Run replies, empty/multi-window results and revocation cannot disclose stale data, lose original identity or execute twice. |
| **P5 — Richer object and computation evidence** | Existing M10 catalog/history/definition callers, M12 lifecycle/revision readers, and shared dependency projections. Add bounded physical placement and directed computation inspection; later add M11/M13/M20/distributed metrics only as their owners qualify. | Every node/edge/metric links to exact public evidence; missing evidence stays missing. Historical inspection does not acquire retention, and a completed output remains distinct from a pending successor. |
| **P6 — Durable workbooks and governed changes** | M28 investigation/publication services, M20 comparisons, M27 policy and M29 review operations, then Board adapters. Complete the existing full-milestone workbook, transaction, comparison and separate Changes workflows. Define workbook identity/save/concurrency/disclosure in the public owner before adding persistence. | Non-browser lifecycle qualification precedes UI integration. Shared basis versus independent runs, moved candidates, changed targets, denial and uncertain publication preserve original identities. Local inspection remains useful without these profiles. |
| **P7 — Installed cutover and closure** | Embedded assets, installed/local/Compose configurations, browser/API fixtures, public documentation and qualification history. Remove superseded view implementations and migrate callers/contracts together. | The focused acceptance matrix below and the full milestone completion evidence both pass at an attributed common revision; remaining initial-pass checkboxes and interrupted lanes are explicitly settled. |

Start with P0 → P1 → P2 → P3. P4 builds on P1; P5 consumes qualified owner
projections without blocking the initial Operations improvement. P6 is a full
milestone dependency gate, not a prerequisite for correcting the reported
experience. P7 qualifies each landed slice and closes the full milestone only
when P6 and all original completion journeys are delivered.

Inventory retained relational pin journals and active sessions before retiring
their execution path. Migrate overlapping new reads to the shared logical reader
only after supported types, source attribution and cleanup parity pass. Retain
distinct supported profiles explicitly; do not add a fallback decoder, silently
delete journals or retire unresolved original work. Update the owning Board
guides/API and generated contracts in the same implementation changes.

### State, browser and installed acceptance

Specify a finite Board interaction model alongside the existing
[console/result models](../../tests/verification/models/README.md). Use bounded
scopes, readers and request generations to explore event reorderings, hidden
views, denial and reconnect. Export traces and replay them against the actual
TypeScript reducer/effect boundary. Include negative controls that remove
generation matching, denial clearing or explicit-Run guarding; an independent
model without implementation replay is insufficient. This proves only the
stated finite safety properties, not arbitrary browser scheduling or latency.

| Scenario | Required oracle and forbidden outcome |
| --- | --- |
| Reported startup and SSH forwarding | Real embedded inspection-only Board at `/?status=all&sort=pid` and `/workbook`, plus catalog-only, SQL-only and fully configured fixtures. Same-origin forwarded requests succeed; wrong Host/Origin rejects. No generic connection error for known missing configuration, credential copying or indefinite `QueryDisabled` loop. |
| Failure classification | Inject disabled configuration, 403, 429, unavailable upstream, malformed/incompatible response and service restart separately. Assert typed state, offered remedy, bounded request count and continued use of unrelated authorized views. |
| Visual/grid agreement | Independent signed storage and `SHOW STORAGE FOR` observations with known fixture changes; assert identical basis within each visual/grid pair. Exercise null, zero, wide counters, partial backlog and changed definition. Never compare independently acquired cuts as if identical. |
| Storage lifecycle | Write accepted WAL data, observe bounded maintenance and reopen the durable fixture; distinguish logical change from physical progress and volatile counters from durable frontiers. No browser mutation or invented deletion/reclaimability conclusion. |
| Race and disclosure | Delay an old success across selection, denial, hide/show and scope replacement. Both chart and grid stay cleared; Inspector cannot resurrect old data. Revoke only one feature and verify unrelated authorized features remain usable. |
| Statement lifecycle | Explicit Run once, change draft, lose response, advance windows, receive verified empty/completion, close early and lose close acknowledgement. Shared-client oracle preserves identity, partial coverage and cleanup uncertainty; no fresh SELECT on retry or visibility. |
| Removal and recovery | Assert both named sections absent from Operations, Table storage reachable without Explain, bindings reachable in Definition, and exact active-session/pin recovery through the replacement route after browser and service replacement. |
| Historical/computation evidence | Traverse retained definitions and row locations with separate grants; inspect a completed managed revision while a successor blocks/fails. No auto-pin, fabricated full coverage or replacement of last-complete evidence by pending progress. |
| Accessibility and bounds | Real keyboard grid/visual selection, focus return, screen-reader descriptions, reduced motion, zoom and narrow layouts. Bounded catalog/graph/reader/request counts under concurrent tabs and large retained data; no protected values in browser persistence or transition logs. |

Use the existing [Board tasks](../../tasks/transit-board.just): `check`, `test`,
`workbench-test`, `workbench-browser`, `relational-test` and
`relational-browser`, plus query/Live/application and affected connector checks
when their adapters change. Extend the real fixtures in
[`tests/interfaces/board`](../../tests/interfaces/board/),
[`board_workbench.py`](../../tests/interfaces/installation/board_workbench.py)
and the existing Playwright suites. Owner contract changes require their
catalog/SQL/protocol tests and regenerated neutral fixtures before browser work.

Before pushing implementation, select affected committed-HEAD clean lanes from
the current CI inventory: `installation-ui` and `browser`, plus `interfaces`,
`core` and `formal` where shared contracts or models change. Record skipped,
failed and incomplete tasks explicitly. Preserve existing 128-file/8-MiB
embedded assets and five-JavaScript-asset/900-kB checks. Measure request counts,
first useful observation, render/selection delay, resident memory and reader
release under named fixtures; fix numeric acceptance budgets before P7 rather
than claiming performance from wireframes. Keep bounded DOM and data residency
independent of retained cardinality.

Current behavior and setup remedies land in the Board guide/API and component
workbench/configuration guides with each implementation. Publish the UI state
model and its assumptions in the owning service-interface Internals account;
visual rationale stays in the registered `board-data` review sequence. Record
executed source-attributed results in qualification history. This planning
change runs documentation checks only and establishes no new runtime evidence.

## Initial-pass implementation plan

**Review state:** initial-pass implementation authorized on 2026-10-28. The
plan below records the intended scope at repository revision `db4ae576e` and
[board-data D2](../design/board-data/D2.md). The delivered boundary and remaining
qualification are recorded below; the full milestone remains In Progress.

### Implementation boundary and retained capabilities

The initial implementation adds the catalog shell, exact-definition Table pages,
explicit bounded previews, integer/decimal window profiles, registered relationship
pages and unsaved narrative/SQL workbooks. `DirectCatalogRead`, `Executor.read`,
`ReadView` and `ReadWorkspace` own the public adaptation; React uses `DataCatalog`
and `StatementReader`. Configuration and current limits belong in the
[workbench guide](../../apps/transit-board/docs/workbench.md).

| Existing capability | Initial-pass disposition |
| --- | --- |
| Built-in home | Catalog replaces the process-led landing; published application entry screens remain declared |
| Atlas, resource, process/journey, activity and connector inspection | Existing routes retained under Operations; named KV/Document projections remain in Resources |
| Finite Live, Follow and captured queries | Existing public query client retained; the new read workspace has no equivalent subscription/capture contract |
| Relational journal and original pin recovery | Existing relational interface retained to resolve its recorded work; no journal migration or deletion |
| Definition editing and `/recovery/definition` | Existing application client and separately authorized workflows retained |
| SQL assistance and editor history | Existing operational editor retains these features; new session cells use native text editing without a second parser |
| Ordinary new SQL and Table previews | Shared read-only logical result reader; no new raw fetch or snapshot loop in Board |

Implementation refinements to the plan:

- Preview binding is verified against the executed result before disclosure. It
  is not an execution-time definition pin; changed interpretations fail closed.
- Value-allocation exhaustion fails the read instead of returning a smaller
  byte-limited prefix. Row windows remain at most 100 rows and metadata retains
  one source chunk for complete authorization revalidation.
- Command/failure/unresolved outcomes remain in the general Zig Executor. This
  browser facade exposes read results and typed refusals; it does not introduce
  command execution or a browser settlement protocol.
- Cleanup is requested on navigation/replacement. A lost close response is not
  proof of remote release; fixed reader lifetimes and native leases bound abandoned
  ownership. There is no durable or cross-restart browser reader recovery.
- Dedicated graphs, durable/shared workbooks, transaction presentation and
  governed changes remain outside this pass. Registered edge lists do not imply
  foreign keys, join cardinality or freshness.

The [executed workbench account](../history/qualification/interfaces.md#board-catalog-and-bounded-read-workbench--2026-10-28)
records the successful installed functional control, browser evidence and failed
or incomplete disk-backed/clean lanes. The acceptance checklist below remains
the qualification inventory; the initial pass is not fully qualified by the
functional control alone.

### Outcome and scope

Make the installed Board useful for the ordinary data exploration loop:
**find a dataset → understand its definition → explicitly preview rows → inspect
a column → compose and run SQL → understand the result's basis**. Data names,
schemas and results lead; process identities and execution evidence remain
reachable through contextual links and Operations.

Keep React, strict TypeScript, **TanStack Router file routes and Vite+** in the
existing `apps/transit-board-web` application. Rework its composition and visual
system around D2; do not create another frontend, deployment or development-only
demo. The browser and Board service consume high-level public Transit operations
and logical result readers. Board does not implement execution, snapshot/pin
ownership, SQL parsing, fetch-ordinal loops or accepted-operation settlement.

| Surface | Initial pass | Later work in this milestone |
| --- | --- | --- |
| Shell and catalog | Catalog landing, configured scope, bounded object discovery, metadata inspector, capability-driven navigation | Cross-catalog search and additional kinds as their public owners qualify |
| Dataset | Explicit finite Table preview; existing explicitly bound KV/Document projections where supported; exact typed cells and a bounded column profile | Whole-source statistics and additional source/decoder profiles |
| SQL workbook | Session-local narrative and SQL cells with explicit Run and attached logical results; clearly marked unsaved state | Durable workbook identity, concurrent editing, sharing, retained investigations and common snapshot basis |
| Relationships and lineage | Bounded registered dependencies/dependents in the inspector, with links to their objects and operational evidence | Dedicated relationship canvas, suggested joins and directed computation graph with qualified progress/freshness |
| Operations | Preserve existing process, resource, connector, Document, query recovery, finite Live and application-definition capabilities under the new shell | Additional index, replication, resource-management and maintenance evidence |
| Changes | Preserve already supported, separately authorized application-definition workflows | New Table DDL/DML UI, branch comparison, DDL admissibility screen, proposal review and publication |

The new SQL workspace initially admits qualified row-returning reads: SELECT,
SHOW, DESCRIBE and EXPLAIN. General statement mutation, explicit transactions,
automatic execution while editing and durable workbook storage are outside this
pass. Existing opt-in Live/application features retain their own contracts and
authority; their presence does not enable new workspace writes. A session workbook
is explicitly temporary, not a partial implementation of a durable investigation.
Do not show D2's synthetic branches, maintained views, approvals or revision
numbers as available data.

### Current owners and gaps

[Milestone 4](04-statement-results-and-consumption.md#delivered-integration-boundary)
supplies the concrete shared result implementation below. Reuse that
implementation; do not build a Board-only result model from the older worksheet.

| Requirement | Available at the source revision | Work required for this pass |
| --- | --- | --- |
| Catalog metadata | `transit-catalog.DirectCatalogInspection.apply` returns bounded namespace/Table pages; `DirectResourceClient` lists named KV/Documents. Public catalog operations inspect definitions, registered edges and policy references. | Compose authorized browser projections through these public callers. Add missing high-level helpers to the catalog caller owner before using them in Board; do not import catalog storage or issue raw actions from views. |
| Statement execution | `transit-sql-client.Executor.execute` returns rows, command completion, failure or an unresolved original attempt. | Add a Board service adapter over this API, with separately configured SQL access and enforced read-only admission for the new workspace. |
| Result consumption | `transit-sql-results.ResultSet`, `Batch`, `Window` and `Progress` define typed values, ownership, observation and completion. | Expose a bounded browser binding to these semantics; keep shared-client execution and recovery in Zig. No equivalent browser statement reader is currently documented. |
| Existing browser queries | `transit-query-client` owns finite-query/Live scheduling and verification. Board's relational worksheet exposes open/page/close with one-row pages. | Migrate overlapping finite SQL presentation to the logical reader. Preserve distinct captured/Live operations through their existing public owners until an equivalent shared adapter is qualified. |
| Browser transport | Board serves a same-origin API and generated validators. The native SQL session endpoint explicitly rejects browser Origin headers. | Adapt through the existing Zig Board service; do not expose SQL session secrets, forward browser credentials or enable direct browser access to the native endpoint. |
| Search and durable workbooks | Bounded catalog enumeration exists; unified browser search and durable workbook resources are proposed. | Ship explicit page-scoped filtering and pagination first. Do not download the catalog to fabricate global search or save a workbook as authoritative browser state. |

Source owners:
[catalog callers](../../packages/zig/transit-catalog/README.md),
[SQL client](../../packages/zig/transit-sql-client/README.md),
[result library](../../packages/zig/transit-sql-results/README.md),
[browser query client](../../packages/ts/transit-query-client/README.md),
[relational worksheet](../../apps/transit-board/docs/relational.md),
[result contract](../../contracts/SQL_RESULTS_V1.md) and
[SQL session contract](../../contracts/SQL_SESSION_V1.md).
These capabilities do not establish a unified catalog, transaction snapshot or
browser result adapter merely by existing in the repository.

### API and ownership boundary

The intended dependency direction is:

```text
TanStack routes / React views
  → shared TypeScript catalog and statement/result APIs
  → generated, runtime-validated same-origin transport
  → Zig Board presentation adapter
  → public catalog/inspection callers or transit-sql-client.Executor
  → owning Transit service
```

Keep catalog/operational projections in `transit-board-api` and its existing
`@transit/board-client` binding. Add the reusable statement/result facade to
`@transit/query-client`, independent of React, Router and Board navigation.
Its browser carriage derives from shared Zig result/SQL owner types; the Board
API binds that carriage to routes. New type and method names are implementation
proposals, not already available exports. Generated transport declarations remain
separate from the language-native public API.

Views receive catalog objects or one logical result owner with schema,
observation, bounded row/column access, completion/failure and deterministic
close. They do not receive raw native responses, signed query bundles, Arrow
segments, cursor ordinals or status-polling obligations. The shared Zig client
owns submission, retries, settlement, decoding and cleanup; the TypeScript
facade owns validated browser values, bounded display ownership and view
lifetime. Domain transitions stay in their existing Zig owners.

The first implementation change must settle these adapter gaps before building
dependent screens:

1. **Read-only admission.** Restrict the new workspace through the owning SQL
   parser/typed dispatch and current upstream rights. A SQL prefix regex, hidden
   button or an assumed weak credential is insufficient. Prove direct API writes
   are refused even with a stronger configured credential. Keep inspection,
   query and existing application-operator identities separate.
2. **Browser reader lifetime.** Define bounded opaque reader references,
   concurrent-viewer admission, backpressure, idle closure, disconnect and
   service-restart behavior. A reference is not a grant. A lost interactive
   execution remains incomplete; reconnect never reruns the SQL or replaces its
   snapshot. Pin recovery stays with the shared service, not a new Board journal.
3. **Uncertain browser delivery.** Correlate an explicit Run with its original
   attempt across a lost adapter response while the owner survives. Reobserve
   that owner rather than execute again. If its lifetime ended, report that
   loss explicitly. Preserve any accepted operation identity and use the shared
   recovery owner; do not add a browser settlement state machine.
4. **Held-result authorization.** Specify how the owner validates current access
   before redisclosing buffered rows, metadata and terminal counts and how the
   browser rechecks held views. Extend the public owner if needed; rerunning a
   query is not an access probe. Clear protected views on denial or failed access
   validation, abort hidden-view reads and revalidate before showing them again.
5. **Resource budgets.** Publish separate request/response, decoded-value,
   active-reader, workspace-memory, metadata-page and polling limits. Keep
   independent control/cleanup capacity. Oversized values fail explicitly;
   adapters must never silently trim a row or claim complete results at a limit.

Any necessary shared-contract extension lands with its owner, fixtures and
non-browser caller coverage first. Incompatible changes use the current-v1
definition cutover and migrate all affected consumers; there is no parallel
legacy result protocol. Runtime applications keep using `apps/` and `packages/`,
without importing `sdks/` or a storage/backend implementation.

### Reviewable implementation steps

#### 1. Public adapters and replacement inventory

Map every existing route/capability to its retained or replacement surface,
including `/atlas`, `/resources`, process/journey links, `/activity`,
`/operations`, `/definition` and `/recovery/definition`. Inventory current query,
relational, reactive and application consumers, generated declarations, launcher
configuration and installed assets before deleting anything.

Implement the missing shared helpers and browser result facade described above.
Use the existing service configuration and account provisioning owners for the
SQL connection; never discover or reuse an administrator account implicitly.
Catalog-only deployments remain usable when queries are disabled. Feature
availability is the intersection of implemented operations, deployment
configuration and current scoped authority, not a frontend flag.
When catalog access itself is unconfigured or unavailable, explain that state
and retain Operations; do not display a successful empty catalog.

**Gate:** public-caller tests prove authorized metadata, denied reads/writes,
empty and multi-batch results, early close, cancellation, expired ownership,
loss of the initial response and revocation after buffering. No React component
is needed to establish these semantics. Concrete adapter limits are recorded
before screens depend on them.

#### 2. Data-first shell and route composition

Replace the process-led landing with the catalog. Use a persistent scope header,
simple navigation and one primary surface with an optional inspector. Only show
realm/database/schema/branch information actually supplied by the public owner;
a fixed branch can be context without an invented branch-switch operation.
Proposed new routes are `/catalog`, `/datasets/$object` and `/workbook`, with
validated scope/selection search state. Use scoped stable object references in
routes, never a mutable name as the sole identity. The root opens the catalog;
existing operational deep links remain ordinary supported routes.

Implement D2's white/graphite palette, thin dividers, generous spacing and
restrained amber/red/green with text and geometry carrying the same meaning.
Bundle fonts locally. Keep the grid readable at 2560 × 1600 and 1440 × 1000;
collapse the inspector at laptop widths and open it explicitly. Provide semantic
tables, keyboard navigation, focus restoration, accessible labels, zoom and
reduced-motion behavior from the first shell change.

TanStack loaders may acquire bounded metadata; route selection and prefetch never
run SQL, start a preview or resume work. Route changes own cancellation and
cleanup explicitly. Preserve Vite+'s existing asset/handler constraints before
changing chunking or adding a graph/editor dependency.

**Gate:** embedded build, direct nested navigation and browser refresh work
without Node, a checkout, remote assets or a development server. Operations and
recovery remain reachable in inspection-only configurations.

#### 3. Catalog and dataset metadata

Show authorized data objects by name and kind, with definition identity,
observed data position and coverage separately labeled. Start with public Table
metadata and expose named KV/Documents only through their supported metadata
operations. Opaque resources remain inspectable under Operations; they do not
become queryable datasets without an accepted projection/decoder.

Use owner pagination and explicit Next/Refresh. Initial search filters the
visible authorized page and says so; a failed or partial scan never means no
matching objects exist. Add global search only after a bounded authorized owner
exists. Do not infer whole-dataset row counts or populate data revisions by
launching a query. Renames preserve identity; a dropped-and-recreated name must
not redirect a retained selection or result to a different object.

The inspector shows logical schema, optional codec/collation details, current
policy references and bounded registered dependencies/dependents where available.
Distinguish unavailable evidence from an empty graph. Metadata-only navigation
does not acquire row data. Dedicated graph layout and inferred join proposals
remain later work; no foreign key, cardinality or freshness is inferred from a
name, compatible type or dependency edge.

**Gate:** a catalog larger than one page remains bounded; changed continuations,
rename/drop, hidden objects and revoked metadata are handled without mixed cuts,
leaks or a synthetic empty catalog.

#### 4. Explicit previews and bounded profiles

Add **Preview rows** through the same statement/result facade used by the
workbook. Bind preview intent to the selected stable object and definition using
the public query owner; do not concatenate unvalidated names into SQL or resolve
a different object silently after a rename. If the shared owner cannot preserve
that binding, add its typed preparation helper before enabling the action.

Use 100 rows as the proposed display default from D2, subject to a separate byte
budget and the source's supported profile. This is a display window, not a new
wire batch size or a claim about dataset cardinality. Preserve the native
32-row/1-MiB canonical SQL batch limits independently of browser transport and
display limits. Accumulate only the bounded owned window, copying borrowed
nested values before advancing the shared reader. Stop or close at the window
budget without draining the result to find a total. Larger values or earlier
source budgets can produce a smaller, explicitly labeled window.

Use a shared grid/value formatter for previews and workbook results. Preserve
wide integers, decimal scale, temporal units, nested values and all five cell
states; ordinary Table cells do not acquire Document conflicts. Profile only
the received window: state counts sum to its row count, distributions use typed
values, and min/max/distinct are exact only for that named population and a
supported type/collation. Do not use JavaScript floating-point coercion or invent
collation ordering. Unsupported profile metrics say unavailable. Selecting a
column recomputes locally and never starts another scan.

Show result identity, schema, source observation, received/displayed rows,
terminal status and limit reason. A complete `LIMIT 100` result still does not
prove whole-dataset coverage. Empty requires verified zero-row completion;
interruption or a display cap remains visibly incomplete where terminal evidence
was not received.

**Gate:** real Table and supported KV/Document fixtures agree with independent
public-client values, state counts and completion evidence across physical batch
boundaries, wide values, empty results, byte caps and revocation.

#### 5. Session workbook and existing-capability migration

Compose a bounded in-memory workbook with narrative, SQL cells and outputs.
Make its temporary lifetime explicit and warn before discarding unsaved drafts.
Do not persist protected results in local storage, URLs or service-worker caches.
Use one shared result component for SELECT, SHOW, DESCRIBE and EXPLAIN. Keep the
typed command-completion/error/unresolved variants in the shared binding even
though the new UI does not admit general command execution.

Run submits the selected cell once. Bind output to its submitted text/revision,
accepted identity, source basis and terminal evidence. Subsequent edits retain
the earlier result with a visible earlier-draft label. A new run replaces a cell's
reader only after deterministic cleanup; late replies cannot attach to another
draft or scope. Independent cells have independent observations, not a common
snapshot. Keep Stop waiting, Close result and any supported explicit Cancel
distinct. A browser reload loses temporary drafts/readers according to the
declared lifetime; it cannot manufacture successful completion or replay SQL.

Preserve suffix-aware assistance and non-destructive editor history through
their shared owners. View code owns editing and focus, not a SQL grammar or
catalog replica. Retain existing finite Live, Follow, captured-query and
application-definition recovery through their high-level clients. Their controls
remain explicitly enabled, budgeted and separate from ordinary Run.

Cut over each overlapping old query view only when its supported types,
provenance, denial clearing and original recovery paths pass on the shared
adapter. Remove superseded components and route/API consumers in the same
change; do not ship a second legacy workbench or fallback decoder. Capability
profiles with distinct semantics may remain distinct, but all are reached
through the single shell and their public owners. The inventory from step 1
must account for every retained behavior before the initial pass can close.
Inventory original pin journals and pending signed operations before replacement.
Resolve required cleanup through their matching public owner before an
incompatible cutover, or refuse that cutover with the original evidence intact;
never delete a journal or default its saved definition to the new build.

**Gate:** explicit execution, draft/result attribution, metadata results,
reader cleanup, multi-viewer capacity refusal, navigation/reload and existing
Live/application recovery pass against real services. No client SQL-text
heuristic decides outcome kind or command counts.

#### 6. Installed cutover and evidence

Run the embedded Board through installed `transit server`, as well as affected
standalone/local/Compose configurations. Extend the owning fixtures under
`tests/interfaces/board/` and installed Board tests rather than creating a second
mock application. Seed through public callers and compare with independent SQL
or SDK observations. Exercise direct API attempts in addition to UI controls.

Measure metadata requests, time to first visible result, completion/close time,
browser/service resident memory, active readers and asset requests with recorded
hardware, data, concurrency and limits. Catalog/result cardinality must not
increase retained pages, DOM rows, polling or readers without a configured bound.
Record numeric browser memory/response/render budgets before qualification;
D2's screenshot dimensions and the illustrative preview size are not performance
evidence. Preserve the existing 128-file/8-MiB embedded asset ceiling and the
five-JavaScript-asset/900-kB-per-asset browser checks unless a separately measured
change justifies revising their owner.

Use `just transit-board::check`, `test`, `browser`, `relational-test`,
`relational-browser`, `query-test` and `query-browser` as applicable, plus the
existing Document/HTTP/gRPC and application/recovery checks for touched surfaces.
Add shared SQL/catalog package tests when those adapters change. Before pushing
implementation, run affected committed-HEAD clean lanes: `experience` and
`browser`, with `interfaces`/`core` and other dependency-selected lanes when
shared contracts or services change. Register new scenarios in the existing
suite/invariant inventory; a planned command is not a passing check.

Publish supported behavior, configuration and limits in the Board guide/API,
component guides and shared-client owners with the implementation. Put executed
evidence in qualification history, including installed screenshots, keyboard
and screen-reader checks, focus/zoom behavior and the laptop inspector open.
Keep D2 as design evidence. Do not mark the full milestone complete: durable
workbooks, dedicated graphs, transaction presentation and governed change
workflows retain the completion gates below.

### Initial-pass acceptance checklist

- [ ] A fresh installed Board opens a real authorized catalog; inspection-only
  operation remains useful and all retained operational/recovery views are reachable.
- [x] Metadata selection creates no data query. Preview and Run require explicit
  intent and the separately configured query capability.
- [x] Screens use shared catalog/result APIs; native fetch, pin, signing and
  settlement machinery stays below the presentation boundary.
- [ ] Large catalogs/results remain bounded; empty, complete, limited, failed,
  cancelled and unavailable outcomes have distinct evidence-backed presentation.
- [ ] Values, profiles and source attribution match independent callers;
  definition identity, data position and policy observation remain distinct.
- [ ] Current authorization governs metadata and buffered disclosure. Hidden
  views, stale replies, denial and cross-scope navigation cannot restore cleared data.
- [x] SQL edits never execute implicitly; changed drafts cannot relabel earlier
  results; disconnect/reload cannot resubmit a statement as replacement work.
- [ ] Existing supported query, finite Live and application recovery behavior
  survives the cutover, with no new administration through inspection.
- [ ] Installed browser, accessibility, asset and measured resource checks have
  attributable evidence; public documentation matches the delivered profile.

## Full milestone delivery sequence

1. **Inventory the replacement and define missing public projections.** Map
   existing Board routes, screens and guarantees to their replacement owners.
   Enumerate authorized metadata/search, bounded previews/profiles, dependencies,
   workbook/investigation resources and review operations. Reuse public typed
   semantics, generate browser declarations from their owners and validate data
   at runtime. Resolve absent contracts before presenting operations as usable.
   Keep grammar-only and unsupported profiles explicit. A backend owner retains
   its operation even when Board needs a new bounded presentation adapter.
2. **Build the focused shell and catalog.** Implement crisp monochrome styling
   with restrained, redundant impact cues, persistent realm/branch context,
   search and object navigation. Separate definition, data and observation
   identities. Use bounded pagination/search and virtualized display windows
   where needed; catalog size must not determine resident memory or graph size.
   Reveal only capabilities available to the current configured scope. Keep
   query and administrative capabilities separate from read-only inspection.
   Apply [D3's topology](../design/board-data/D3.md): horizontal activity navigation,
   optional object navigation, one primary working surface and one shared
   selection-driven Inspector. Definition, Profile, Storage, Lineage, History,
   Execution and Policy dimensions appear only for relevant subjects and
   qualified public evidence. Keep result coverage/completion and exact
   comparison inputs outside collapsible detail. Context changes cannot
   relabel or implicitly rerun existing results. Retain original Operations
   and recovery paths; validate the proposed laptop/narrow behavior before
   accepting exact dimensions.
3. **Implement dataset previews, profiles and relationship exploration.** Open
   metadata without starting a scan; use an explicit bounded preview through
   the qualified query owner. Preserve lossless numbers, nested types and each
   supported `value`, `null`, `missing`, `type_error` and `conflict` state.
   Profiles identify their population, source basis and excluded states; a
   preview cap is not whole-dataset coverage. Keep logical type, physical codec and collation
   separate, with deeper detail on demand. Focus graphs on a selected
   neighborhood. Distinguish declared `FOREIGN KEY` and `CHECK` constraints,
   partitioning/clustering keys (`PARTITION BY`, `CLUSTER BY`), active Row-Level
   Security (RLS) and dynamic column-masking attribution, unverified join
   candidates and computation dependencies; name/type similarity proves neither a
   foreign key nor cardinality. Inserting generated SQL edits a draft and does not
   run it.
4. **Deliver durable workbooks over shared statement and investigation owners.**
   Combine narrative, SQL cells and their attributable outputs. Define workbook
   identity, save/concurrency behavior, sharing/disclosure and retained result
   references through public resource operations, not browser-local authority.
   Qualify shared assistance and non-destructive history against their own
   contracts. Bind each output to its submitted draft/query, source basis and
   terminal evidence. Keep earlier results distinct from changed drafts, commands
   distinct from row results, and display windows distinct from completion.
   Independent cell runs do not silently form one atomic investigation. A retained
   shared basis uses the qualified snapshot/pin owner with explicit lifetime.
5. **Make execution and transaction state understandable.** Preserve explicit
   Run as the baseline and visible finite budgets for enabled Live sessions.
   Editing never implicitly applies DDL, publishes a proposal or dispatches an
   effect. For supported transaction sessions, show autocommit versus explicit
   scope, provisional results, commit/rollback state and the original operation
   needed to resolve an uncertain commit. Stopping a wait is not rollback, and
   reconnecting never resubmits a write as new work. Freeze accepted bindings;
   verify completion and clean up bounded readers on exhaustion, close or failure.
6. **Expose directed lineage and operational evidence.** Show authorized
   dependencies, last complete results, pending source revisions and attributable
   blocked/failed progress. Keep recorded intents, connector attempts and remote
   outcomes separate. Mark unknown or incomplete coverage rather than inventing
   dependencies or freshness. Preserve existing process/resource, ownership,
   history and connector inspection as reachable operational views. Add
   replication/recovery, segment compaction/tombstone ratios, CDC ingress
   watermarks, Workload Management (WLM) resource-group queues and erasure audit
   evidence only through qualified public inspection operations; no
   provider/storage access or new administrative power is implied by an
   Operations screen.
7. **Implement separate change and review workflows.** Present DDL admissibility
   with exact statement/catalog evidence and registered blockers. Present branch
   proposals with base/source/target identities, typed diffs/conflicts, impact
   basis and configured review policy. Separate preview, approval, publication,
   activation and observed consequence. A changed candidate, target or authority
   invalidates the corresponding action eligibility. Compare modeled impact
   separately from actual outcomes. Keep branching-only installations useful,
   and use separately authorized operations for all administrative work. The
   inspection identity remains read-only; hiding a button is not enforcement.
8. **Complete the installed cutover and publish the supported experience.**
   Implement in the existing Zig Board service and strict TypeScript/Vite+
   frontend/browser libraries. Runtime applications do not import consumer SDKs.
   Embed bounded local assets, support installed `transit server` startup and
   the qualified standalone/launcher deployments without a development server,
   network fonts or CDN dependencies. Preserve private admission, origin checks,
   bounded requests, diagnostics and upstream grant enforcement. Replace
   superseded UI/routes and migrate consumers/generated contracts together under
   the current-v1 cutover policy; do not maintain competing legacy authorities.
   Reject incompatible saved operations/definitions without silently discarding
   accepted work. Promote delivered behavior to the Board guide, API and component
   documentation with exact supported profiles and recovery instructions.

## Completion evidence

Include index discovery, build/rebuild progress, generation/source coverage and
plan inspection in real browser journeys. Preserve the distinction between
estimates and measured execution. Create/rebuild/drop actions require the owning
separately authorized administrative capability; inspection stays read-only and
editing SQL does not start maintenance. Exercise interrupted builds, unavailable
indexes and stale views without presenting them as ready or complete.

Run the real embedded Board against supported installed services and durable
fixtures, with independent public SQL/SDK results as oracles. Prototype screenshots
and browser mocks alone do not establish completion. Define browser coverage,
resident-work and response/render budgets before implementation qualification;
publish measured conditions and limits rather than inheriting timings from a
design image.

| End-to-end journey | Required observations and failure cases |
| --- | --- |
| Discover and inspect | Find an authorized object in a catalog larger than one page, inspect its definition, explicitly preview data and profile a column. Exercise rename/drop, partial search, denied metadata, revocation after buffering, missing history and large/wide results. Compare exact five-state/numeric values and profile denominators with the shared owner. |
| Compose and explain | Inspect a candidate join, insert SQL without execution, run it and change the draft. Keep the earlier result's identity and completeness intact. Exercise empty and multi-batch results, partial prefixes, command counts, reader close, expired investigation pins and independent versus atomic source bases. |
| Save, share and resume | Save a multi-cell workbook through its public owner, reopen it after browser/service replacement and inspect its recorded basis. Handle concurrent edits, missing or withdrawn resources and current disclosure policy. A locally remembered or shared result must not bypass authorization or promise unowned retention. |
| Execute and recover | Exercise supported autocommit and explicit transaction sessions, provisional results, uncertain commit, cancellation races and original-operation recovery. Show Live scope/budget exhaustion and pause without silently resetting the budget or starting administrative work. |
| Explain changing computation | Advance an upstream source while viewing lineage. Distinguish last complete result from pending update, unrelated panel cuts from atomic evidence, and recorded effect from remote outcome. Retain truthful process/resource and connector inspection during unavailable upstream reads. |
| Compare, review and publish | Compare branches, inspect DDL blockers and request review under the configured policy. Exercise disabled merges, disjoint changes violating a domain constraint, moved targets, changed candidates, revoked approvers, incomplete impact results and lost publication replies. Never infer permission from a preview or silently dispatch external effects. |
| Operate the installed interface | Start the packaged Board, follow real dataset/computation links and use keyboard navigation, focus management, zoom, screen readers and non-color state cues. Check spacious 2560 × 1600 and 1440 × 1000 layouts, narrow/zoomed layouts and large-table internal scrolling. Secondary inspectors must not make the primary task unusable. |

Verify authority boundaries at the service as well as in the browser, including
direct API attempts, stale/cross-scope caches and stronger configured identities.
No private value may become public through search, profiles, diagrams, export or
shared workbook links. Bound polling, graph expansion, active readers and resident
rows independently of retained objects/results. Preserve control capacity when
data requests stall.

Record executed component/service/browser evidence in [the proof ledger](../history/qualification/README.md),
with independently reproducible fixtures and actual source revisions. Updated
screenshots must come from the installed implementation and match its qualified
states. Focused Board proofs close here; later
[combined qualification](44-qualification-and-benchmarks.md) repeats the cross-caller
journeys at one release revision and does not postpone these acceptance gates.

## Later workload inspection

The dedicated [Video](36-video-and-multimodal-timelines.md),
[ML/AI](37-ml-ai-and-experiment-provenance.md),
[Robotics](38-robotics-and-sensor-replay.md),
[software evidence](39-software-build-and-deployment-evidence.md),
[planning](40-constrained-planning-and-optimization.md),
[deductive rules and Datalog](41-deductive-rules-datalog-and-equivalence-graphs.md) and
[hardware design and EDA verification](42-hardware-design-rtl-and-eda-verification.md) milestones qualify their
own application journeys after the shared operations exist. Reuse Board's
bounded result, source-basis and lineage views for supported inspection. Keep
captured observations, inferred annotations, candidate plans, incomplete evidence
and accepted publications visibly distinct. Custom application value decoding,
annotation edits, device control and build/deploy policy remain with application
surfaces and separately authorized operations. These extensions neither add
hidden mutations to operator inspection nor expand this milestone's closeout.

## Ownership boundaries

- Earlier lifecycle, result, transaction and SDK/service milestones retain their
  existing Board migration and public-caller promises. This milestone owns the
  cohesive replacement and the missing Board presentation integrations.
- Investigation and reviewed-publication owners remain independently usable
  through non-browser callers. Board does not decide their semantics or become
  their workflow engine.
- MCP/Apps consume the same operations and evidence through their own protocol
  adapters. They may reuse qualified presentation components without depending
  on a running Board deployment or inheriting its configured credential.
- Visual rationale and open interaction choices remain in
  [board-data](../design/board-data/README.md), with earlier console, grammar and
  operational studies linked there. Acceptance of a visual direction is not
  implementation evidence or automatic approval of every depicted operation.
