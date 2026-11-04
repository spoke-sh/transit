# 30. Board reimplementation and data-first workbench

[Roadmap](README.md) · **Status:** In Progress

The current design revision is [accordion layout and reactive workbook state](#accordion-and-reactive-workbook-design--2026-11-03),
with [board-data D5](../design/board-data/D5.md) and its interactive study.
The reviewer accepted and merged the design study in PR #363, then requested
implementation. The shared plane and bounded reactive workbook profile are
implemented; the broader workbench completion gates remain open.

The existing [R3 implementation plan](#r3--explain-completed-and-pending-computation) covers
public read-only computation evidence, then linked source → computation → output
inspection. R1, automatic local data access and [R2](#readable-storage-delivery-r2--2026-11-02)
are merged, including readable binary quantities, retained storage placement,
maintenance inspection and features loaded on demand. Their recorded qualification
gaps remain open. The [local connections and Document persistence plan](#local-connections-and-document-persistence-plan--2026-11-02)
records the parallel persistence scope. Installed performance and the full
workbench completion gates remain open.

Reimplement Board as the installed interface for discovering data, explaining
computations and reviewing governed changes. Deliver the focused catalog,
dataset previews, relationships, SQL workbooks, directed lineage and change
workflows developed in [board-data D2](../design/board-data/D2.md), with the
single-Inspector direction in [board-data D3](../design/board-data/D3.md) and the
accordion/reactive revision in [board-data D5](../design/board-data/D5.md). Preserve
operational inspection and expose each capability through its owning public
operation; the interface does not become another catalog, query engine or
permission authority.

## Accordion and reactive workbook design — 2026-11-03

**Status: bounded implementation delivered; full milestone qualification remains open.** Design
source basis: `796599b58`; implementation starts at merged `bf78566a8`. The reviewer retains Catalog's overall direction and Operations'
data, requests a folding root layout, removes the long temporary-session paragraph,
and wants SQL cells to recalculate their dependents as the draft changes. They
selected an interactive design study before production changes and separate
Inspector/Assistant tabs in the right pane. [D5](../design/board-data/D5.md) owns
the interaction model, figures, alternatives and open decisions.

The implemented root has an expandable left activity/object rail, one persistent
central surface and an independently expandable right context pane. Catalog,
Workbook and Operations remain first-class destinations. The same observation
owners supply their grids, diagrams and Inspector. Folding, selecting a tab and
resizing are presentation transitions, not execution events. Operations' original
inspection and recovery paths remain reachable.

The implemented workbook is a temporary graph with stable cell identities, compiler-
resolved relation dependencies and distinct draft, execution and output state.
An edit invalidates the changed cell and its descendants immediately. In a visible,
enabled finite Live session, debounce/blur coalesce into one evaluation of the
latest valid candidate. Downstream work binds exact upstream complete relations;
unrelated cells do not rerun. Previous completed output remains visibly earlier.
No display window is substituted for a complete relation or independent source
vector relabeled as an atomic snapshot.

The long notice is replaced with compact Unsaved/lifetime detail and explicit
discard handling. The shell retains temporary drafts across activity navigation,
pauses Live while inactive and revalidates original results on return. Closing the
workbook discards its drafts and releases its session; reload remains unsaved.
Saving drafts through Documents remains the separate L2–L5 scope below.

The delivered relation profile uses the shared SQL client and Fuze parser: named
single-input SELECT cells, chains and branching, projection/scalars/predicates,
LIMIT, COUNT and SUM. Each downstream input is a verified complete typed relation,
with 10,000 rows per relation, 16 MiB retained value storage per session, four cells,
32 cell evaluations and a five-minute lifetime. Multi-input joins/diamonds, grouping,
source-follow and durable computation promotion remain outside this profile.
Quoted `"workbook.name"` references are resolved by the shared owner; no hidden
Tables, browser SQL rewriting or JavaScript query execution is introduced.
Current behavior and exact limits are owned by the
[workbench guide](../../apps/transit-board/docs/workbench.md),
[Board API](../handbook/reference/board-api.md) and
[shared SQL client](../../packages/zig/transit-sql-client/README.md#temporary-workbook-relations).
Executed coverage, source revisions and retained failures are recorded in the
[qualification account](../history/qualification/interfaces.md#accordion-plane-and-finite-workbook-relations--2026-11-03).

### Delivery slices and remaining gates

| Slice | Outcome | Required owner and gate |
| --- | --- | --- |
| A0 — review the state and plane | Review D5 closed/open/narrow layouts, tab semantics, draft/result transitions and copy | Local fixture/browser study only; acceptance does not certify installed behavior |
| A1 — implement the plane | Shared root rail/context tabs; keep Catalog/Operations evidence and explicit Run | Existing shell, selection and observation owners; prove focus, navigation, zoom, denial clearing and no execution from geometry. Assistant unavailable unless its separate capability exists |
| A2 — qualify session graph semantics | Shared binding/validation, exact dependent relations, finite evaluation budget, progress, pause/close and bounded relation storage | SQL/query/client owners first; generated browser types and non-browser callers. Define namespace collisions, cycles, source cuts, input lifetimes, cancellation races and budget accounting before a Board adapter |
| A3 — implement reactive cells | Visible Live scope; immediate invalidation; debounce/blur; only the affected dependency closure runs | Consume A2 via shared clients, retain current typed read-only admission. Bound queued candidates, active work, output windows and service memory/spill. The existing request scheduler still reserves cleanup/control capacity |
| A4 — qualify installed journeys | Same semantics across installed Board and independent public caller | Record actual browser/service evidence and numeric budgets; publish delivered behavior to the Board guide/API and shared owners |

Do not route the graph through hidden Tables, concatenate unvalidated SQL in the
browser, or evaluate full relations in JavaScript. Current
[managed DATAFLOW](../handbook/reference/queries.md#managed-table-computations)
requires an existing output Table, separate publication/authorization/activation,
one source and no managed output chaining. A temporary composable workbook is a
new lifetime/binding profile; this design does not invent executable
`CREATE TEMP DATAFLOW`. Extend the existing current-v1 contracts together where
semantics change. Promotion to durable computation is a separately reviewed,
authorized operation, not an effect of typing, Save or changing tabs.

Assistant context attachment, model/tool requests and retention require their
application/connector owners. Selection does not send data. A suggested edit only
changes the draft; its subsequent evaluation follows the visible workbook mode.
Inspection gains no administrative power through the context pane.

### Acceptance and remaining extension gates

- Edit bursts, IME composition and blur admit the same latest revision once;
  obsolete completions cannot replace a newer draft's output. A→B→C
  and branching use exact complete input revisions; unrelated cells remain untouched.
  Multi-input diamond execution remains an extension gate.
- Reject cycles, missing/deleted inputs, duplicate names, shadowing and type changes
  with attributable diagnostics. Prove rename/reorder preserves stable bindings.
- Exercise complete empty inputs, multi-batch relations larger than the display
  window, byte/memory limits, budget exhaustion, failures and interrupted prefixes.
  Never label a partial relation current/complete or feed it to dependent SQL.
- Pause, route change, hidden tab, close, reload and cancellation races preserve
  original work identity and bounded cleanup. Returning does not reset budgets,
  rerun SQL implicitly or splice source snapshots. Current denial clears buffered
  rows, Inspector evidence and attached assistant context.
- Prove both rails, both tabs, browser Back, narrow/zoomed focus return and activity
  navigation retain the intended draft/selection and never dispatch SQL. Explicit
  workbook closure/discard is separate from folding the plane.

Earlier dated explicit-Run delivery/checklists describe their original profiles
and remain evidence. D5 revises the workbook target; it does not invalidate
their proved safety gates or complete R4/R5, persistence, or this milestone.

## Local connections and Document persistence plan — 2026-11-02

**Status: L1 merged in [PR #335](https://github.com/spoke-sh/transit/pull/335);
Document prerequisites and persistence remain follow-up work.** Original planning
source basis: `ffbf2e9b12dceca856000faf15eebbc252ae580c`. The baseline table below
describes that planning revision; current automatic local access is documented
in the [workbench guide](../../apps/transit-board/docs/workbench.md). The remaining
proposal establishes no new runtime behavior or executed proof.

Make the Board started by `transit server` useful with the installation's local
data account immediately. Store saved workbooks, preferences and explicit
connection profiles in Transit Documents. Users should not assemble a second
connection file to inspect the database they just started, and Board should
exercise the same public data operations as other Transit applications.

This proposal changes the earlier explicit-only local connection policy. It
also separates saving ordinary workbook drafts from publishing retained results
and consistent investigations. The latter keeps its M28 dependency. The dated
delivery records below remain evidence of their original profiles. The plan adds
L0–L5 below to the implementation sequence; R2's remaining acceptance checks,
R3–R4 and the other full-milestone obligations remain open.

### Planning baseline and the missing integration

| Boundary | Current implementation | Required change |
| --- | --- | --- |
| Local Board startup | [`server/Board.zig`](../../apps/transit-cli/server/Board.zig) generates the inspection bootstrap and passes nullable `board.workbench_file` | Derive local data connections from the managed installation; retain the narrow operational inspector internally |
| Local SQL | [`SqlSettings.zig`](../../apps/transit-cli/server/SqlSettings.zig) defines the managed `local` peer account; [`Discovery`](../../packages/zig/transit-sql-client/src/Discovery.zig) identifies its private socket and instance | Connect Board through the existing Unix socket and shared SQL client, without requiring another listener or password account |
| Catalog reads | [`Workbench.zig`](../../apps/transit-board/Workbench.zig) composes `DirectCatalogRead` with an explicitly supplied native data connection | Have the supervisor supply the managed account's exact catalog/branch/role binding through bootstrap, with the same public read checks |
| Browser SQL | [`ReadWorkspace`](../../packages/zig/transit-sql-client/src/ReadWorkspace.zig) and [`Executor.read`](../../packages/zig/transit-sql-client/src/Executor.zig) enforce typed read-only admission and bounded results | Preserve those owners; saving a workbook is a separate typed data mutation, never permission to execute its SQL |
| Workbook state | The [workbench guide](../../apps/transit-board/docs/workbench.md#workbook-and-results) describes four temporary cells discarded on navigation | Add durable identity, accepted revisions, explicit Save/Open and exact save recovery through Documents |
| Document storage | [Direct partition components](../../packages/zig/transit-storage/docs/document-partitions.md) implement bounded recovery and a causal map-tree slice; the [installed Document API](../handbook/reference/documents.md) still uses Station | Qualify the necessary public direct Document lifecycle with M7 before adding durable Board consumers; component availability alone is insufficient |

`workbench_file` currently contains connection settings, not saved workbook
contents. Both the manual connection setup and the absence of durable workbook
data need work, with independent delivery gates.

### Proposed local connection and authority model

1. The local supervisor selects the existing managed `local` account and its
   current role, database, catalog and branch. It supplies a typed bootstrap to
   Board after the account binding is available. SQL uses peer authentication
   on the private Unix socket; catalog reads use the corresponding public native
   data binding. No root/installer key or arbitrary account search is involved.
2. Catalog and SQL use one logical data authority. Their transports can remain
   separate internally. The existing operational principal remains restricted
   to its inspection contract. Board neither borrows a native command sequence
   from another process nor implements an independent credential registry.
3. The managed local account can have broader rights than the Workbook read
   adapter exposes. SQL still passes through typed read-only admission. Writes
   to Board-owned Documents use explicit application operations and the current
   data account; they do not grant generic DDL/DML to the Workbook endpoint.
4. Local deployment deliberately shares that account's authorized data with
   viewers admitted to Board. A browser is not authenticated as an individual
   OS user: peer authentication identifies the Board process. Document owners
   and preferences are scoped to the data account/deployment until a separately
   qualified viewer identity exists. Preserve Host/Origin and private exposure
   checks. Remote deployment authority remains explicit.
5. Current grants remain authoritative for every read and save. Starting Board
   must not add SELECT grants to every Table or restore revoked credentials,
   roles or resource access. Newly created Tables become visible according to
   the existing account policy, without a Board grant-reconciliation loop.

Keep a minimal bootstrap boundary for locating/authenticating to Transit and
configuring the listener. Existing installation identity, secret references and
generated child-launch inputs remain owned by the server. They must contain no
workbook content, authoritative preference state or duplicate profile database.
Board cannot discover the database holding its configuration without this
initial endpoint/identity. Derive the local connection; use a conventional
catalog namespace to discover application data after connecting.

Define a typed local/explicit/disabled data-access selection in the existing
server settings owner, defaulting to local when the managed local SQL service
is enabled. Freeze its exact spelling in L0. Explicit selection names a stored
profile; standalone Board receives a minimal connection to the Transit instance
holding those profiles. Disabling local SQL does not silently re-enable it or
select a stronger account. Missing/disabled, starting, denied and unavailable
remain distinct states. An unready data connection must leave Operations usable.

### Transit-owned application data

Use a conventional Board namespace, proposed `_board`, in the selected catalog.
Names locate declared objects; stable object and Document identities bind all
subsequent work. Validate application ownership and schema before adopting any
existing name. A collision or incompatible definition is an observable failure.

| Declared data | Identity and content | Publication and access |
| --- | --- | --- |
| `workbooks` DOCUMENT collection | One logical Document per workbook; stable cell IDs, ordered cells, SQL/narrative text, title and logical connection selection | Explicit create/save/rename/delete through public Document operations; accepted revision and current owner policy govern disclosure |
| `preferences` DOCUMENT collection | One Document per data account and preference scope; layout/theme and last selected workbook identity | Bounded updates through the same caller; no per-browser identity inferred from a shared account |
| `connections` DOCUMENT collection | Explicit profile identity/revision, endpoint and scope descriptors, account selection and credential references | Profile management requires its own current authorization; reading a profile never grants data access or permission to use a referenced secret |

The derived local connection requires no stored connection profile. Resolution
of an explicit profile rechecks deployment eligibility and credential use before
opening a transport. Ordinary workbook writers cannot turn a profile edit into
an arbitrary outbound request or a stronger service identity. Do not persist
secret bytes, SQL session handles or live reader cursors in these Documents.

Use Document's paged logical directory for listing workbooks and bounded reads
within a workbook. Do not require a separately authoritative Table index or an
atomic cross-resource transaction merely to save one Document. Any later search
index is derived, independently attributed and rebuildable.

Declare these resources through the owning public catalog/application lifecycle.
The supervisor performs one recoverable installation operation, recording its
original identities and receipts through existing lifecycle owners. A restart
resumes that operation or observes its accepted result. Missing or dropped data
after completed installation must not be recreated automatically. Headless
operation and temporarily disabling Board preserve application data. Default
history remains unlimited; deletion, retention and physical reclamation remain
separate public operations. Basic catalog/SQL access does not depend on these
resources being installed or writable.

### Save, concurrency and result semantics

Define an application workbook schema and typed create/list/read/save/delete
operations before browser integration. Put the reusable schema and operation
composition in a real shared Zig library, proposed `transit-workbench`, with
its own manifest, direct dependencies and non-browser checks. It uses public
catalog/Document/SQL clients and owns application validation only. Storage,
authorization, mutation acceptance and recovery stay with those existing owners.
Generate browser declarations and runtime validators from shared public types.
Extend the owning [Document contract](../../contracts/DOCUMENT_V1.md),
[SQL session/result contracts](../../contracts/SQL_SESSION_V1.md) and
[installation contract](../../contracts/APPLICATION_INSTALLATION_V1.md) only where
their public semantics change. Keep the workbook's application schema outside
kernel types; reuse [SQL result evidence](../../contracts/SQL_RESULTS_V1.md).

The initial persistence profile saves drafts explicitly. A new workbook starts
unsaved; Save publishes a revision, Open reads an accepted revision, and editing
marks the local draft dirty. Run remains an explicit finite SQL action and can
operate on an unsaved draft. Saving, reopening, changing preferences or resolving
a connection never runs SQL or repeats a previous statement.

Select Document's `versioned` profile with an expected base revision for the
first saved-workbook implementation. A conflicting save preserves both the
accepted revision and the unsaved draft and requires explicit resolution. No
last-writer-wins overwrite or automatic collaborative merge is proposed. Require
this conditional-update behavior in the shared Document owner; a browser-side
revision check cannot establish it. Later collaborative text can consume the
qualified causal profile without duplicating merge semantics in Board. Its
immutable profile needs a separate declaration or an explicit supported migration;
existing versioned Documents cannot be silently retagged.

Each save binds a stable workbook ID, application schema definition, expected
revision, client operation token and canonical change bytes. Admission retains
the candidate and original operation durably before acknowledging acceptance.
Repeated identical tokens recover that operation; changed bytes conflict. After
a lost response, observe/retry the original save. After browser or Board loss,
an authorized bounded lookup by workbook/account must discover accepted pending
work and its original receipt. Add any missing lookup/recovery operation to the
shared Document/client owner before promising this behavior. Unsent browser edits
remain unsaved; no local-file or browser-storage recovery database is introduced.
Expose dirty, saving, accepted/pending, saved, conflicted, denied and unknown
outcomes distinctly; only an observed committed revision establishes Saved.

The first saved schema contains drafts and presentation preferences. Live rows,
interactive cursors and current execution handles remain transient. Durable
execution/result attachments require M28's public reference, disclosure and
retention lifecycle. A saved draft alone cannot preserve an interactive result,
pin its source or establish a common snapshot across cells. Reopening a workbook
shows its saved content without silently recomputing missing results.

Freeze numeric limits in L0 against the shared owners. Proposed starting budgets
are 64 KiB per Document read page, 256 KiB per save request and four active cell
editors, while preserving the existing 60,000-byte SQL input bound. These are
request/display budgets, not a total workbook or workbook-count limit. Page
inactive cells and large text, and refuse over-budget mutations before acceptance.
Keep the existing four SQL readers, 100-row windows and 2-MiB result-window value
budget. Meter aggregate data/control concurrency and reuse scratch at page/batch
boundaries; durable history and listing cardinality must not scale resident memory.

### Owner prerequisites and implementation sequence

Automatic local access can ship before Document persistence. Durable drafts need
[M7's public lifecycle](07-document-storage-and-station-decoupling.md#remaining-work-packages-and-gates),
conditional versioned updates of maps/ordered cells/text, bounded directory and
value reads, and original-operation recovery through the
[shared client owner](09-client-foundation-and-language-apis.md). They do not require SQL
`CREATE DOCUMENT`/`INSERT` syntax or all of M7's analytical/transaction features.
Use typed callers until SQL operations are actually executable. Coordinate the
public Document transition with M7's current-v1 consumer cutover; do not expose
a second selectable engine or add Board access directly to `DocumentPartition`.

| Step | Reviewable change and owners | Dependency and exit gate |
| --- | --- | --- |
| **L0 — Contract and removal inventory** | Define local data bootstrap, application schemas, save/lookup/concurrency semantics, profile authority and budgets with `transit-protocol`, `transit-data-client`, SQL client and application lifecycle owners. Inventory `workbench_file`, inline `workbench`, settings schemas, launchers, tests and public docs | Non-browser fixtures define allowed/refused behavior, compatibility and exact recovery before adapters. The plan's proposed names are resolved here |
| **L1 — Automatic local catalog and SQL** | Extend `apps/transit-cli/server/Board.zig`, `Sql.zig`, `SqlEnrollment.zig`, `Config.zig` and `SettingsSchema.zig`; compose the existing callers in `apps/transit-board/Workbench.zig` and `main.zig`. Use lifecycle events to update data readiness, with no periodic configuration-file scanner | L0. A fresh default local installation opens Catalog, previews a Table and executes an explicit read without a workbench file, external SQL listener or manual grants. Current denial remains denial; explicitly disabled SQL remains disabled |
| **L2 — Public Document prerequisite** | Coordinate M7 C0–C4's evaluator/storage/catalog/node/client work for the selected profile, including expected-revision updates, bounded logical-document listing and accepted-operation discovery. Keep all changes in their public owners | L0 and M7's coordinated public cutover gates. A non-browser caller creates, edits, lists, reopens and recovers Documents on real disk with long text, concurrent writes, process loss and revocation. No claim of completion from storage unit tests alone |
| **L3 — Workbench data installation and caller** | Add the shared application schema/caller, conventional declarations and recoverable install wiring. Implement public Document composition for workbooks/preferences/profiles and generated Board API bindings; remove file-based profile authority in the coordinated cutover | L2. A non-browser caller saves and reopens the same workbook after replacement; name collisions, changed definitions, denied saves and lost replies preserve original identities. A saved connection cannot escalate authority |
| **L4 — Save/Open and preferences in Board** | Extend `data-workbench.tsx`, `routes/workbook.tsx`, existing statement/observation owners and typed browser clients. Add bounded workbook navigation, save status, conflict handling and preference updates | L3. Real browser reload/service restart preserves accepted drafts; two-tab conflicts are visible; saving/reopening performs no SQL. Operations and local data reads remain independent of workbook-write availability |
| **L5 — Installed cutover and qualification** | Migrate embedded/standalone/Compose/reference configuration consumers, generated schemas, fixtures, examples and public documentation. Measure resource bounds and run the affected clean lanes at one committed revision | L1–L4 and the matrix below. No supported runtime reads legacy workbench files; incompatible histories reject without reset. Publish executed evidence, limitations and public semantics |

L1 is the first implementation PR after L0 review. Its server setting is
`board.local_data` (default `true`); explicit `board.workbench_file` remains a
complete override until L3/L5 replace profile storage. This stage composes existing
public callers and bootstrap types without changing wire or persisted data
semantics. It does not deliver Document persistence or the final file-removal
cutover. L2 belongs to the shared Document work and may already be advancing
independently; recheck its exact
merged capabilities before implementation. L3/L4 must wait for its qualified
public operations. No file-backed, localStorage or private storage fallback is
an interim persistence deliverable.

Basic saved drafts are a narrower application-data feature than
[M28's published resources and investigations](28-published-resources-and-investigations.md).
Full retained result attachments, sharing to a different
audience, consistent investigation bases and governed publication retain the
existing M28/M27/M29 gates. Saving local drafts does not complete those milestones
or M30. Cross-user login, automatic SQL execution, arbitrary administrative SQL
and broad new collaboration UI are outside L0–L5.

### Compatibility and removal

The final profile removes `board.workbench_file` and standalone inline
`workbench` as configuration authorities, including their parser paths, generated
setting descriptions and setup-only fixtures. Deployments select the derived
local profile or an explicit Transit-stored profile through the minimal bootstrap.
Preserve independent feature states and restricted remote scopes in replacement
tests. Do not remove operational recovery journals or unrelated configuration
files under the label of workbench cleanup.

Apply the [current-v1 cutover policy](../handbook/reference/versioning.md): replace
the shared definition for incompatible bootstrap, persisted application or wire
changes; regenerate schemas, signing fixtures and affected bindings together.
Never default a missing persisted definition to the current one. Runtime support
does not include an old-file decoder, silent import or parallel legacy profile.

Existing installations require a specific compatibility inventory before rollout.
Old connection files contain settings, not workbook data. Operators must recreate
explicit profiles using the new public operations while retaining secret
references privately. Resolve pending work with its matching build; incompatible
history remains untouched. An offline converter, if required to preserve an
existing installation, needs a separate reviewed contract and proof. Rebuilding
the executable or restarting alone is not an upgrade procedure. No implementation
step may delete or reset the user's existing `.transit` installation.

### Acceptance matrix and verification

All cases below are planned checks. Each gate needs its actual caller path and
attributed results; a skipped browser, missing prerequisite or incomplete fault
schedule is not a pass.

| Case | Required observation |
| --- | --- |
| Fresh default local server | No Board-specific data configuration; Catalog and explicit Workbook reads work through the managed local scope; PG/MySQL/HTTP listeners can remain disabled |
| Disabled/unready/denied data | Operations remains available; each feature explains the actual state. No stronger-account fallback, repeated disabled requests or automatic grant repair |
| Native and data identity separation | Operational inspector retains exactly its existing rights. Data reads use the intended local account; SQL writes/commands are refused by the shared read gate even when that account can write |
| First install interrupted | Failure before/after declaration acceptance and before Board launch resumes the original installation/Document operation; no duplicate collections or adoption of unrelated names |
| Saved drafts after replacement | Create/save through a public non-browser caller, then inspect in Board; save in Board, restart and read through the same public caller. IDs, text, order and revisions agree |
| Concurrency and uncertainty | Two tabs save against one base; one conflict remains explicit. Lose an accepted save reply, kill Board, then discover and settle the same operation; no duplicate revision or overwritten draft |
| Independent failures | SQL reads work while workbook writes are denied; saved drafts can be read while SQL is unavailable; a failed profile or preference read cannot trigger SQL |
| Revocation and profile changes | Revoke before save admission, after acceptance, after read buffering and before terminal disclosure. Saved profile edits cannot activate stronger authority; an active query retains its original account/source/definition |
| Retention and removal | Close/reopen/disable/headless operation preserves Documents; DROP/delete is not undone by startup; missing history is visible. Saving a result reference cannot retain data or bypass current source rights |
| Large retained state | Many workbooks/revisions and large multi-page text keep page/cache and active-editor residency bounded; quota refusal has no accepted prefix; four-reader/result-window bounds still hold |
| No hidden execution or local persistence | Save/Open/rename/preferences issue only their typed application operations. No SQL resubmission, filesystem workbench state, localStorage/IndexedDB authority, credentials in responses or payloads in telemetry |
| Cutover | Matching current definitions work across installed consumers; missing/foreign definitions and old configuration reject before effects. Existing data and uncertain operations are preserved |

Use the owning Document/client component and real-disk fault checks first.
Extend the existing installed fixtures
[`board_workbench.py`](../../tests/interfaces/installation/board_workbench.py),
[`board_profiles.py`](../../tests/interfaces/installation/board_profiles.py) and
[`server_board_package.py`](../../tests/interfaces/installation/server_board_package.py),
plus the real browser workbench/profile suites. Preserve their independent
catalog/SQL denial and Host/Origin coverage with the new profile mechanism.

For Board implementation, use the existing tasks in
[`tasks/transit-board.just`](../../tasks/transit-board.just):
`just transit-board::install`, `just transit-board::check`,
`just transit-board::workbench-test`, `just transit-board::workbench-browser`
and `just transit-board::test` as affected. Add persistence/fault coverage to
the owning tasks; do not invent commands that merely report success. Select the
affected `just ci clean --lane NAME` lanes from the repository's actual lane
inventory once the implementation/removal map is frozen. Run against committed
HEAD and report component, installed, browser and resource evidence separately.

Update the public [Board guide](../handbook/guides/inspect-board.md),
[workbench guide](../../apps/transit-board/docs/workbench.md),
[Board API](../handbook/reference/board-api.md),
[local server guide](../../apps/transit-cli/docs/server.md), configuration/example
owners, and the Document/application references as behavior lands. Record
executed evidence in qualification history. This plan-only change requires the
repository documentation link/fence and whitespace checks; it does not run or
claim the implementation acceptance matrix.

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

R2's retained-storage placement and maintenance inspection merged in
[PR #338](https://github.com/spoke-sh/transit/pull/338), followed by the proposed
R3 managed-computation projection and neighborhood.
R4 retains the unresolved historical TLS-replacement cause, the newly observed
managed-table authorization refusal after replacement/resume, installed capacity
refusals and the SQL-only Run timeout, measured resource budgets and broader
accessibility checks. R5 and the original milestone gates
remain required; this delivery does not complete M30.

## Readable storage delivery (R2) — 2026-11-02

Merged [PR #338](https://github.com/spoke-sh/transit/pull/338) implements binary
byte quantities with exact detail/copy, shared retained
catalog inspection in Data and Operations, linked physical-definition and
row-placement diagrams/grids, and maintenance settings/state. It uses the
existing public read operations and one selected page; inspection acquires no
retention and starts no query or maintenance. A mismatched historical cursor
now retains its binding diagnosis instead of becoming an internal failure.

The user's bundle refinement is implemented as dynamic feature boundaries and
narrow public client/validator entries. The measured bootstrap is about 689 KiB
across four scripts; the largest script is about 468 KiB. Build guards and
installed delayed/failed-download checks preserve the embedded host's limits
and shell navigation. The [source-attributed account](../history/qualification/interfaces.md#board-readable-storage-and-deferred-features--2026-11-02)
records the exact byte comparison, checks, failures and remaining gaps.

The focused installed storage/API/browser schedule passes at `c88f2dcab`,
with matching rebuilt executables, automatic local access and revoked-restart
checks from main.
[Real D4 figures](../design/board-data/D4.md#installed-figures) are ready for
layout review. The default attempt at that source stops during profile
provisioning with `StaleAuthorizationRevision`. Earlier full attempts encounter
retained-setup capacity refusals; their independent connection-profile passes
remain separately attributed. The focused pass does not qualify the full schedule
or erase those failures. The branch includes `origin/main` at `edeb8618c`, including
automatic local access, saved-declaration recovery and the later Queue/release
changes. The qualification account distinguishes each tested revision.
This does not close R2's full acceptance matrix: metadata-only/SELECT-only
subjects for the new placement fixture need a separate authority schedule,
and manual screen-reader/native-browser-zoom review remains open. Broader
clean-lane outcomes belong in the qualification account. R3 and R4 retain their
separate computation and reliability/performance scopes; M30 remains In Progress.

## Next implementation sequence after PR 326 — 2026-11-01

**Review status:** The sequence was approved; R1 merged in
[PR #332](https://github.com/spoke-sh/transit/pull/332). The expanded R2 plan below
is **Approved; merged in PR #338 with qualification gaps**. R3 is expanded below
as a new plan for review. **Original source basis:** `origin/main` at `db0bb4a8f`, the
merge of [PR #326](https://github.com/spoke-sh/transit/pull/326). R2 records its
newer source separately. This sequence scopes separate implementation PRs; R5
retains its service prerequisites. Executed evidence is attributed separately
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
| **R2 — Readable quantities, storage placement and maintenance inspection** | Consistent binary-unit quantities, selected retained-definition/row-placement diagrams and maintenance budget/state views, linked to their grids and exact Inspector evidence | R1 plus existing M10 historical callers; completes remaining P3 visual work and the storage part of P5 |
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

**Implementation plan — 2026-11-02. Status: Approved; implemented for review with qualification gaps.** Source basis:
`origin/main` at `ffbf2e9b1`, including Board R1 in PR #332 and the subsequent
Stream/Queue integration in PR #333. Planning starts in a separate worktree on
`docs/m30-storage-inspection-plan`. The original implementation scope is preserved below; the
[delivery account](#readable-storage-delivery-r2--2026-11-02) and linked evidence
record what was executed. The plan itself establishes no runtime qualification.

#### Outcome and review scope

Board is the human interface to the database. A person should be able to judge
how much data or memory a value represents, understand the allowance it relates
to, and inspect where selected data resides and what maintenance has observed.
Readable summaries and exact evidence are two presentations of the same typed
observation. Preserve the horizontal activities, paired visualization/grid and
one contextual Inspector.

The next PR delivers these three journeys:

| Journey | Visible outcome | Exact evidence available on selection |
| --- | --- | --- |
| Judge magnitude and capacity | `128 MiB of 512 MiB · 25%`, with an explicit allocation or budget label | Original byte counts, metric meaning, scope and observation basis |
| Locate selected retained data | Logical columns mapped to physical definitions; up to eight returned row identities linked to their WAL or segment locations | Retained selector, stable object/definition, source cut and the selected mapping or location |
| Understand maintenance | Reported state, last failure, completed/failed steps and configured work limits, alongside separate Table progress | Raw settings and counters, reset semantics, partition identity and exact progress boundaries |

The quantity example is illustrative, not a measured installation result.
R3 computation neighborhoods, durable workbook persistence, new administrative
controls and the full R4 performance programme remain separate deliveries.

#### Source assessment and dependencies

| Existing owner at this source | Implementation consequence |
| --- | --- |
| [`storage.tsx`](../../apps/transit-board-web/src/storage.tsx) formats every capacity value as raw bytes. [`StorageFact`](../../apps/transit-board-web/src/storage-model.ts) stores only a rendered string; its grid and Inspector claim exact values. | Retain typed/raw quantities separately from display labels. Update exactness wording when the primary value is rounded. |
| Payload/capture, HTTP/gRPC, query-budget and schema-record views also display byte quantities. | Audit and migrate known byte measures through one app-owned formatter. Arbitrary SQL cells, message contents and identifiers keep their own semantics. |
| [`HistoricalObject`](../../apps/transit-board-web/src/retained-storage.tsx) already reads retained source/coverage and renders text and lists. [`DataCatalog`](../../packages/ts/transit-board-client/src/catalog.ts) already exposes bounded definitions and locations. | Extract a reusable selected-object view and build diagrams over the returned evidence. No new discovery scan, query or retention operation is needed. |
| [`Storage.Response`](../../packages/zig/transit-board-api/src/Storage.zig) exposes allocation, request pools, activity and settings from the [shared storage types](../../packages/zig/transit-protocol/src/Storage.zig). The current UI shows only part of that evidence. | Present the existing fields with accurate units and explanations before proposing new metrics. Node counters are independently sampled and are not attributed to one Table. |
| R1 supplies the observation owner, bounded transport scheduler and scoped Inspector. | New views use those owners. Selection stores identities; late replies cannot repopulate a replaced, hidden or denied scope. |
| [M10 historical coverage](10-standards-and-catalogs.md) and the [historical contract](../../contracts/HISTORICAL_CATALOG_V1.md#historical-interpretation-coverage) distinguish metadata rights from SELECT. | Physical-definition inspection must remain usable without row-placement rights. Validate helper composition so a stronger auxiliary read cannot accidentally gate the metadata-only view. |
| [M3 storage](03-live-storage-and-sql-cutover.md) and [M12 computation](12-sql-and-dataflows.md) retain their own progress/recovery owners. [M6](06-streams-queues-and-durable-runtime.md) has newer merged integration evidence. | Rebase implementation and reproduce relevant failures at its actual source. Neither newer runtime work nor a successful Board observation establishes that earlier failures are resolved. Stream/Queue inspection needs its own public projection and later scope. |

Use the [Board guide](../handbook/guides/inspect-board.md),
[Board API](../handbook/reference/board-api.md),
[storage reference](../handbook/reference/storage.md) and existing public clients.
The expected R2 implementation changes presentation and tests, using current
contracts. If a required fact is absent, propose and qualify it with its domain
owner before adding its Board adapter; never infer it from a filename, ID or
unread storage object.

#### 1. Shared quantity presentation

Add one small pure formatter in the existing Board web app, with a presentation
component where exact details/copy behavior are shared. No new package or
formatting dependency is needed. Proposed behavior:

- Use powers of 1,024: B, KiB, MiB, GiB and TiB, continuing through PiB/EiB when
  full-width inputs require it. Byte values below 1,024 remain integer B.
- Show approximately three significant digits, at most two decimal places, and
  strip trailing zeros. Promote a rounded boundary such as `1024 KiB` to the
  next unit. Mark a rounded value as approximate; never label it exact.
- Accept validated nonnegative safe-integer numbers and exact decimal-string or
  bigint quantities. Normalize without converting full-width strings to Number.
  Compute unit choice and rounding with integer arithmetic; reject invalid,
  fractional, negative or unsafe numeric inputs. Keep wire validators intact.
- Preserve `0 B`, unavailable evidence and an absent setting as distinct states.
  A zero denominator is not a percentage or an invented unlimited allowance;
  current storage contracts require positive limits.
- Retain exact decimal bytes for an Inspector detail and **Copy exact bytes**.
  Make the detail accessible by keyboard and touch, not only a hover tooltip.
  Copy returns the ungrouped decimal integer; user-visible exact details may use
  locale grouping. Copy status reports success or failure without changing data.
- Use original values for ordering, ratios and state decisions. Formatting cannot
  turn a below-limit allocation into an exceeded limit or establish completion.
  Where sorting exists, differently scaled labels still sort numerically.

| Input bytes | Primary presentation | Exact detail |
| --- | --- | --- |
| `0` | `0 B` | `0 bytes` |
| `1023` | `1023 B` | `1,023 bytes` |
| `1024` | `1 KiB` | `1,024 bytes` |
| `1536` | `1.5 KiB` | `1,536 bytes` |
| `134217728` | `128 MiB` | `134,217,728 bytes` |
| `1610612736` | `1.5 GiB` | `1,610,612,736 bytes` |

Apply this to Storage allocation/limits/peaks, Table pending bytes, request and
result budgets, captured/payload sizes, HTTP/gRPC body and framed-byte measures,
and schema-record size labels. Explicitly label both quantities in mixed
rows/bytes or messages/bytes displays. Keep row counts, log positions, offsets,
revisions, identities, hashes and raw hex contents exact in their own units.
Do not infer that an arbitrary numeric SQL column represents bytes.

Update the storage grid caption from its current blanket “exact values” claim.
The grid, visual and Inspector summary use the same formatter; exact byte detail
remains available without restoring raw-byte dominance in the main view.
For comparable bars, choose a common unit for the scale/axis; show the value and
unit in every accessible label. Used/limit pairs share a unit and use a percentage
only when both values refer to the same owner and allowance. Calculate the ratio
before rounding, label over-limit values truthfully even if the drawing is capped,
and use a less-than label when a fixed scale would round a positive value to zero.
Accessible names spell out binary units where abbreviated labels are unclear.
Preserve the distinction between storage accounting, request allocations,
control reserve and configured maintenance memory. Do not sum overlapping pools
or call accounting “disk used” or “free space.”

#### 2. Selected retained placement

Extract the historical selector/list and selected-object inspection from
`data-workbench.tsx` into focused reusable components. Keep the existing Catalog
entry and expose the same inspection from Operations, beside Table storage.
Entering a retained selector and historical schema is explicit; choose an object
from its bounded directory. A current Table may preselect only a matching stable
object actually present in that retained selection. Do not resolve renamed objects
through current-name fallback or automatically acquire a snapshot.

Provide two labeled modes with separate continuations:

- **Physical definitions:** connect logical columns to the returned physical
  schema generation or ADD-time origin using stable column IDs. The current
  owner returns one generation per page. Show type, codec and collation distinctly;
  explain initial-value origin without inventing or decoding application values.
- **Row placement:** connect each returned original row identity to its recorded
  WAL location or immutable segment identity. Group shared destinations within
  the selected page. At most eight row locations are retained/displayed; there
  is no recursive expansion or accumulated segment inventory.

Use a bounded DOM/SVG diagram with an equivalent table, avoiding a graph library.
The physical-definition view follows the existing validated schema bound and
scrolls within its region; row placement is bounded by the eight-row API page.
One selected identity drives highlighting and the existing Inspector in both
views. Show complete digests and exact locations in details, with descriptive
short labels in the diagram. Segment IDs are identities, not counts or sizes.

The owner key includes deployment/scope, retained selector, stable object,
coverage kind and continuation. Replacement resets continuation and selection.
Changing mode or page releases old Inspector evidence before another response
can appear. Hidden/denied/expired/incompatible states clear the affected view;
retry revalidates the same supplied selector. An authorized empty page is distinct
from failure. Unrelated node inspection remains usable when SELECT is refused.

Each diagram and grid carries its source basis and explicit selected-page
coverage. “More pages” and “End of directory” concern traversal only: neither
verifies payloads, completes a query, proves a global snapshot, measures segment
size, nor establishes that data is eligible for deletion. Do not mix this retained
cut with the current Table-storage observation or draw a chronological movement
between independent observations.

#### 3. Maintenance and current Table progress

Extend the existing Maintenance section using returned fields:

- Reported enabled/state, completed and failed steps, and last failure.
- Configured resident memory, worker interval and operation timeout.
- Flush enabled, row/byte/age eligibility thresholds and per-step work rows;
  archive enabled and work frames; compaction enabled and work rows; collection
  record cadence. Keep eligibility thresholds distinct from progress and budgets.

Use a compact labeled state/settings view paired with a precise grid and
Inspector explanations. Format configured milliseconds as readable durations
while retaining exact milliseconds in details. A disabled feature is distinct
from missing evidence. The public node activity has one aggregate worker state;
do not invent per-Table active phases, a maintenance queue or a time series.
Completed/failed step counters reset when their owner restarts; a retained last
failure is not proof that the current worker state is failed.

Keep current Table acceptance, archive, recovery and history lanes partition-local
with their original boundary conventions. Display pending rows and human-readable
pending bytes separately. When `pending_complete` is false, label both as a
bounded observed prefix/lower bound; do not compute a total, ETA or progress
percentage from it. A numeric log-position bar shows position relative to its
stated boundary, not elapsed time or percentage of maintenance completed.
Node settings and Table observations retain separate bases and ownership labels.
Opening or refreshing any view never runs flush, compaction, collection, SQL or
other controls.

#### Feature loading (implementation refinement)

The implementation also addresses the requested bundle decomposition. Split the
shared renderer and Catalog/Dataset/Workbook composition into dynamic feature
imports. Keep public client errors, configuration, interface acquisition and
pure value display separate from optional query, Live and operator clients.
Generate Board validators by contract group; preserve every runtime check and
public operation. Group shared feature dependencies so dynamic imports add at
most four scripts to the bootstrap graph, with one CSS file and no module
preload burst. Retain the 900 kB per-script bound and enforce fewer than 800 kB
across at most four bootstrap scripts at build time. Fail a build that makes a
feature implementation eager. Check cold entry, navigation, deep-link reload,
loading state, a failed import and explicit reload against the embedded host.

#### Implementation and review order

Keep one R2 implementation PR, with scoped logical commits:

| Commit | Deliverable | Review/validation focus |
| --- | --- | --- |
| `feat(board): present byte quantities in binary units` | Shared typed formatting, readable metrics and exact-value detail/copy across the audited byte labels | Boundary/full-width/rounding cases, unchanged units for counts and identities, meaningful capacity ratios |
| `refactor(board): share retained storage inspection` | Reusable bounded selector/object owner for Catalog and Operations | Scope/continuation fencing, current rights, no duplicated poller or implicit retention |
| `feat(board): visualize retained storage placement` | Physical-definition and row-placement diagrams, shared grid selection and Inspector | Exact identity correspondence, page bounds, independent metadata/SELECT access and keyboard use |
| `feat(board): explain maintenance budgets and progress` | Node state/settings and clearer current Table evidence | Correct units, independent observations, reset/partial semantics and no invented progress |
| `test(board): qualify readable storage inspection` | Installed public-caller/browser schedules and access/replacement regressions | Real disk-backed source evidence; prior recovery and original-work guarantees preserved |
| `docs(board): document storage inspection and evidence` | Public behavior, owner inventory, design outcomes and source-attributed checks | Proposal versus implementation, exact commands/results and remaining R4 failures |

Alongside the quantity commit, register `board-data/D4.md` as the next review in
[the design sequence](../design/board-data/README.md), following its template.
Use monochrome wireframes for capacity, placement and maintenance with narrow,
empty, denied, expired and partial states. Include unit/precision and exact-detail
interaction. Design fixtures remain labeled synthetic; acceptance screenshots
come from the real installed service. The design record owns layout rationale;
this roadmap owns implementation scope. R3 can extend the review later with its
actual computation projection.

#### Acceptance and verification

This is the original acceptance matrix. Executed outcomes and outstanding gates
are recorded in the [delivery account](#readable-storage-delivery-r2--2026-11-02).

| Layer | Required evidence |
| --- | --- |
| Quantity/unit checks | Zero/null, each 1,024 boundary and rounding carry, exact powers/fractions, full-width decimal strings including u64 maximum, invalid/unsafe inputs, exact copy content and numeric ordering. Check a near-limit rounded label cannot change the underlying status. |
| Component/owner checks | One observation supplies diagram/grid/Inspector; mode, page, scope, hide and denial invalidate old disclosure. Late success cannot revive it. Independent node inspection survives a denied Table or row-placement read. |
| Installed storage fixture | Use explicit owning callers to provision WAL-backed and segment-backed rows, evolve/rename a Table and retain a selection spanning more than one coverage page. Compare selected identities and exact quantities with an independent public caller; reopen disk-backed storage and verify the same retained basis. Observe maintenance without claiming a forced intermediate state. |
| Authorization/lifetime | Separate metadata-only and SELECT subjects; revoke each right independently and release/expire retention through its owner. Check empty and terminal pages, Inspector/hidden DOM clearing, stale continuations and unavailable transport. Board performs none of the fixture's setup/control operations. |
| Browser/UI | All four existing connection profiles; Operations useful without SQL; no SQL, retention or maintenance requests from selection, paging or refresh. Keyboard and pointer share selection, Escape restores focus, exact detail/copy works without hover. Check narrow layout, 200% zoom, reduced motion, automated accessibility and a recorded manual screen-reader pass. |
| Bounds/integration | One selected coverage page, existing schema bound and two-read/one-control scheduler limits; no full scan or repeated hidden reads. Preserve embedded asset limits and existing workbench/inspection/recovery assertions. |

Iterate with `just transit-board::check`, the affected browser suites and
`just transit-board::workbench-browser` in the pinned environment. The quantity
migration also affects HTTP/gRPC/capture and query-budget surfaces: run their
owning browser checks, including Document inspection if its rendering changes.
Before submitting implementation, run committed-HEAD clean `browser` and
`installation-ui` lanes. Run `test::board-model` to retain R1's existing safety
check; use the clean formal lane if transition/effect owners or model machinery
change. Add dependent core/interface checks only if a public contract or backend
owner actually changes. Publish exact source and preparation outcomes; an
interrupted lane or passing repetition cannot erase a failed attempt.

Update current behavior in the [Board guide](../handbook/guides/inspect-board.md),
[workbench guide](../../apps/transit-board/docs/workbench.md) and frontend owner
inventory. Change the API reference only if its exposed semantics change.
Record executed results in the existing
[qualification owner](../history/qualification/interfaces.md), with real
screenshots and source/tool/fixture attribution. Do not claim R4 latency or heap
budgets from component tests or screenshots.

**R2 exit gate:** the three journeys work through current public read operations;
primary byte quantities are consistently readable; exact values and independent
units remain inspectable; diagram/grid selections agree with public evidence;
page, authorization, lifetime and disclosure bounds hold. No missing backend fact
is fabricated, and no new work is initiated by inspection.

#### Reliability follow-up and subsequent delivery

Carry the [R1 recorded failures](../history/qualification/interfaces.md#board-reactive-ownership-and-independent-connection-profiles--2026-11-02)
into a separately attributable R4 investigation: SQL-only Run timeout/native
capacity, managed-table replacement/resume authorization, and SQL reads after
certificate/CA replacement. Reproduce on the implementation baseline, capture
the owning typed cause and original operation evidence, and fix the responsible
owner with a focused regression. Keep owner fixes independently reviewable; do
not increase timeouts, broaden mutation retries or weaken assertions to obtain
a green Board run. A reproduced failure affecting an R2 journey blocks that
journey's acceptance; unrelated failures remain explicit gaps in the broader lane.

R3 follows with read-only source → computation → output inspection over M12's
completed/pending revision evidence. R4 retains common-revision integration,
performance/multi-tab memory measurements and remaining accessibility work.
R5's durable investigations and governed changes still depend on their public
services. R2 delivery does not complete M30.

### R3 — Explain completed and pending computation

**Review status: Implemented for review; focused R3 qualification passes.**
The public independent-reader owner and Board integration are separate review
units. The [executed account](../history/qualification/interfaces.md#board-computation-inspection--2026-11-02)
records the signed reader, real Board API/browser checks and their limits. R4
and full-milestone completion remain separate. Original planning source basis:
`origin/main` at `5f23092f258b774e545351d83cf76765a0af4451`, the merge of
[PR #338](https://github.com/spoke-sh/transit/pull/338). This plan is based on a
source audit, not a new runtime qualification. It selects R3 as the next feature
and keeps R4 owner fixes independently reviewable.

Make a managed Table's production understandable: show its declared source and
output, the last result that actually committed, and evidence about any successor.
A failed successor must not make the previous complete result appear failed;
an Active control state must not imply that a result exists or is current.
Keep the existing horizontal activities, paired diagram/grid and single
contextual Inspector from [D3](../design/board-data/D3.md).

#### Baseline and prerequisite findings

The scope is the installed single-source/single-output finite Table profile in
[Queries](../handbook/reference/queries.md#managed-table-computations),
[DATAFLOW_V1](../../contracts/DATAFLOW_V1.md) and
[M12's retained revisions](12-sql-and-dataflows.md#retained-completed-table-revisions--2026-11-01).
It does not depend on future incremental or multi-source execution.

| Owner at the planning revision | Available evidence | Required work |
| --- | --- | --- |
| [`ManagedTable`](../../packages/zig/transit-query-direct/src/ManagedTable.zig) | Exact declaration, control KV head/position, pending reference, blocked reason and verified last completion decision | A reusable bounded inspection composition with explicit disclosure rules |
| [`ManagedRevision`](../../packages/zig/transit-query-direct/src/ManagedRevision.zig) | Fixed revision manifest, original definitions/schema/source cut and verified common transaction decision; current source/output/control checks | Factor reusable metadata verification without registering a row reader or traversing result pages |
| [`SessionInspection`](../../packages/zig/transit-sql-service/src/SessionInspection.zig) | `SHOW DATAFLOW` and `SHOW DATAFLOW name REVISION number`; disclosure revalidation | Reuse the typed inspection owner so SQL and Board agree; preserve the statement result lifecycle |
| [`DirectCatalogRead`](../../packages/zig/transit-catalog/src/DirectCatalogRead.zig) and [`Workbench`](../../apps/transit-board/Workbench.zig) | Configured read-only catalog transport, bounded metadata and exact Table reads | No managed-computation request or dedicated discovery API is exposed here |
| [`features.tsx`](../../apps/transit-board-web/src/features.tsx), observation and workbench owners | Deferred modules, scoped read effects, paired views and shared Inspector | A computation feature that composes these owners and stays out of the bootstrap |

**Independent-reader access is a prerequisite, not an assumed adapter detail.**
`ManagedTable.find` looks up a publisher-scoped `DirectClientToken`;
`ManagedTable.load` and `DirectTableBinding.require` compare full connections,
which include principal and role. The current code is therefore not sufficient
evidence that a separately provisioned Board reader can inspect another identity's
computation. Keep the publisher's immutable attribution unchanged. Add the narrow
owner operation needed to resolve and disclose a managed computation to a current
authorized reader; do not substitute the publisher connection, give Board its
credentials, or relax generic token/record/transaction ownership checks.

Freeze that operation's lookup, authorization, provenance and work budgets in
the owning contract before implementing the Board adapter. If discovery requires
a durable declaration reference not currently reachable by the read owner,
deliver its publication/recovery contract and current-v1 migration in the owner
PR. A Board-only registry, guessed token or scan of every KV is not an alternative.
Catalog must not import the query executor to implement this composition.

#### Selected first experience

1. Add **Inspect a computation** in Operations, using the configured catalog
   scope and an explicit schema/name lookup. Typing edits the selector; **Inspect**
   starts the bounded read. Resolve once to stable object and immutable definition
   identities, then fence subsequent reads to them. A same-name replacement
   requires a new explicit selection. Inspection-only and SQL-only deployments
   retain their existing usable views and explain the missing catalog capability.
2. Show a three-node **source Table → computation → output Table** diagram and
   an equivalent grid over the same response. Edges mean declared input/output,
   not measured traffic. Selection in either view opens the same Inspector.
   Source/output links open ordinary current dataset metadata with their own
   observation basis; they do not present the current output as a retained result.
3. Keep **Last completed result** and **Current computation** visibly separate.
   The first shows revision, row count and completion basis. The second shows
   control state/epoch, pending work and the owner's blocked/failure reason.
   Before the first completion, say **No completed result**; a verified zero-row
   revision is **Completed · 0 rows**. No percentage or ETA is inferred.
4. Offer explicit inspection of one positive revision number, initially the
   latest observed completion. Selecting a revision pins only the UI selection,
   not storage retention. A newer completion may update the current summary but
   cannot replace an explicitly selected older revision. Use **Latest completed**
   to choose again. Missing revisions remain missing; never fall back to current
   rows. Do not fetch a revision directory or infer contiguous retained history.
5. Use the existing exact-number presentation and B/KiB/MiB/GiB formatter for any
   byte budgets exposed by the owner. Counts, epochs and partition positions keep
   their own units; the Inspector preserves exact copyable values and provenance.

Start with this explicit lookup rather than a new global computation directory.
Dataset entry links are included only where a public owner supplies a verified
computation binding; arbitrary dependency edges cannot be interpreted as executable
lineage. No new standalone activity or restoration of the removed Relational
worksheet/Declared dependencies panels is proposed. Broader discovery and graph
expansion need a later bounded public directory; the existing future ceiling of
32 nodes/64 edges does not enlarge this three-node delivery.

#### Typed read contract and ownership

Propose a shared `ManagedInspection` module in `transit-query-direct`, with neutral
types and public catalog read primitives where required. Its exact exported names
are implementation choices; these operations and guarantees are the review scope:

| Read | Input and result | Binding and disclosure |
| --- | --- | --- |
| Resolve | One configured scope, schema and computation name → exact computation binding | Owner-proved publication; distinguish unsupported, missing, unpublished/incomplete and denied without exposing hidden objects |
| Observe | Exact binding → current control observation and nullable last-completion identity | Preserve immutable declaration versus mutable head, control storage definition, observed position, epoch, original pending identity and typed blocked reason |
| Inspect revision | Exact binding and positive revision → verified retained metadata | Exact source/output/computation definitions, schema commitment, source position, row count, manifest and original committed decision/cut |

The first complete projection requires current read permission on source, output
and control, consistent with the installed SQL inspection profile. Metadata-only
access is not sufficient for retained result counts or completion evidence.
The independent reader must need no write, activation or administrative grant.
Recheck current authority after buffering and immediately before disclosure,
including repeated observations, empty completions and cached intermediate
metadata. Keep missing and denied behavior consistent with the catalog's existing
non-disclosure policy. Do not expose private recovery envelopes or signing data.

Extract the common metadata verifier from `ManagedRevision.open`; both the row
reader and SQL inspection use it, with their existing lifetime and terminal checks
preserved. Board never calls `next`, allocates a SQL result handle, acquires a pin
or scans output rows. Inspection cannot invoke publication, initialization,
authorization, activation, refresh, suspension, retirement or recovery execution.
Service-owned reconciliation may proceed independently; the fixture must distinguish
that work from work caused by the read.

Verify a completed revision's manifest, revision key and common committed decision,
not merely a descriptor or participant LSN. Keep independently read current heads
and selected revisions separately attributed. If the head changes between reads,
return clearly separated observations or a typed changed-observation refusal;
never stitch them into an atomic snapshot. A prepared transaction can cause the
current head to return `Conflict`; this is unavailable observation, not a failed
computation. A separately authorized fixed revision may still be inspectable,
but that independent read must not claim to recover the unavailable current head.

Pending means only what the durable owner records. Absence of pending work does
not establish freshness. Defer lag, catch-up rate and progress bars unless the
owner supplies a qualified same-partition comparison. When exact source definitions
change, preserve the refusal instead of rebinding the old revision or weakening
authorization to keep a graph visible. Retirement alone does not erase retained
completion evidence; current grants still decide whether it can be disclosed.

Adapt this owner through a proposed same-origin **`POST /api/v1/computations`**
read route, using the existing configured catalog identity and Host/Origin checks.
A separate route keeps the query composition above Catalog and avoids expanding
`DirectCatalogRead` into a query-engine dependency. Reuse public clients in Board's
Zig host. Export the request/response through `transit-board-api`, generated OpenAPI
and a narrow browser client/standalone-validator entry. Keep full-width identities,
positions and counts in neutral decimal encodings and validate responses at runtime.
No browser-supplied connection, principal, URL or arbitrary immutable-record handle
can select a different authority or upstream destination.

Proposed request/reply ceilings are **4 KiB / 256 KiB** for this metadata route,
within the existing host's upstream-response limit. Freeze aggregate upstream
read/work and allocation ceilings in the owner contract before adapter work;
count declaration, schema and manifest verification as well as the final response.
Retain one selected computation and revision with bounded scratch/output memory,
no growing revision cache, no full directory scan and no result-page reads.
Oversize or budget exhaustion is a typed incomplete observation, never truncation
reported as success. Incompatible wire or stored changes require the current-v1
cutover, generated fixtures and affected caller migration together.

#### Reactive behavior and feature loading

Reuse `observation.ts`, `use-observation.ts` and the shared request scheduler.
The observation key includes deployment/configuration generation, catalog scope,
exact computation definition, read kind and selected revision. Inspector selection
also carries the owning response generation. A click in the diagram/grid changes
selection without another network read; switching the target/revision replaces the
relevant observation and invalidates late responses.

| Event | Required presentation and effect |
| --- | --- |
| First lookup or visible refresh | Bounded loading/refreshing state; preserve selection only while its identity remains present |
| New completed revision | Update current evidence; retain an explicitly selected older revision under its own current authorization |
| Pending, blocked or failed successor | Keep successfully authorized last-completion metadata separate; a blocked reason is data, not a transport error |
| Denial, changed binding, malformed response or lost connection | Clear the affected observation and its Inspector; propagate known source/output/control denial to every dependent current/revision view and invalidate their late responses; show the typed cause without reporting zero rows or computation failure |
| Hide, collapse the computation view, navigate away or replace scope | Cancel queued/in-flight reads, invalidate generations and clear disclosed evidence; no background refresh for a closed computation view |
| Close the contextual Inspector | Clear its selection and return focus; the still-visible primary computation view retains its normal observation lifecycle |
| Return, explicit retry or availability check | Use R1's existing eligibility/backoff rules; never resubmit a computation command or loop on disabled/denied access |
| Feature download failure | Keep shell navigation and the explicit reload action; no reads start before the feature loads |

Load the computation renderer/client/validators as one logical deferred feature
when selected. Keep it out of the bootstrap and unrelated Workbook/storage imports;
add its entry to the eager-feature guard. Use the existing diagram primitives or
small native SVG/HTML for three nodes. Preserve all current
[build guards](../../apps/transit-board-web/vite.config.ts): scripts below
900,000 bytes, bootstrap below 800,000 bytes across at most four scripts, at most
four additional scripts per dynamic import, one stylesheet, and the 128-file/
8-MiB embedded-asset ceiling. Record bootstrap and cold-feature totals separately;
do not raise a budget to accommodate this feature.

#### Implementation and review sequence

Keep two feature PRs so the independent-reader prerequisite is reviewable before
the UI depends on it. Known R4 reliability fixes remain separate focused PRs.

| Unit / suggested logical commits | Concrete deliverable | Gate before dependent work |
| --- | --- | --- |
| **R3a — Public inspection owner:** contract and neutral types; native read/discovery authority; shared metadata verifier and SQL adoption; caller proofs/docs | Exact lookup/current/revision inspection usable by a principal other than the publisher, with bounded work and unchanged generic ownership protections | Real independent reader agrees with existing SQL/typed evidence; source/output/control revocation and post-buffering checks pass; current-v1 migration complete if needed |
| **R3b — Board integration:** typed API and generated client; deferred renderer and reactive selection; installed API/browser proofs; public docs/evidence | Explicit lookup, three-node diagram/grid, one Inspector and separate current/completed states | R3a qualified; new route is read-only, existing feature/asset budgets pass and the acceptance matrix below is exercised |
| **R4 reliability follow-up:** reproduce one failure; fix its owner/fixture; focused regression and evidence | Resolve attributable `ControlCapacity`, `StaleAuthorizationRevision` or replacement/read failures | Capture the original operation and owning cause; no blanket retries, raised quotas/timeouts or skipped assertions |
| **R4 combined qualification:** baseline measurements; lifecycle/accessibility exercises; final clean lanes | Common-revision integration and measured budgets for R1–R3 | Completed implementation source; report any unexecuted or failed journey explicitly |

Begin with a short baseline reproduction of failures that could prevent the managed
fixture or Board read route from running. Fix an R3-blocking failure before accepting
that journey; unrelated historical failures do not justify widening the feature PR.
Later successful runs remain separately attributable and do not establish the cause
of an earlier failure. Updating this plan is not itself evidence that a defect is fixed.

#### Acceptance matrix and verification

| Journey | Required executable evidence |
| --- | --- |
| Publication → first completion | A real caller creates/authorizes/activates the installed finite profile; Board distinguishes each observed state, then agrees on exact revision/source/output/cut/decision with typed and SQL callers |
| Completed → pending → blocked/failed successor | Owner-controlled stepping or a deterministic test barrier exposes the accepted pending state; the old completion remains independently attributable; deterministic constraint/budget failure cannot relabel or replace it |
| Empty and older revisions | Zero-row completion has verified decision/count; selecting an earlier revision survives later output writes and refresh; missing revision never substitutes another result |
| Independent read authority | Publisher and Board reader are different principals; metadata-only, source-only, output-only, control-only and fully permitted subjects prove the conjunction; all inspection succeeds without writer rights |
| Revocation after buffering | Independently revoke source, output and control before disclosure, including zero-row/repeated reads; neither API nor Inspector leaks the buffered evidence |
| Definition/control changes | Source definition replacement, same-name replacement, suspended service restart, retirement and missing completion records produce exact evidence/refusals; no implicit rebinding or new computation |
| Observation and module races | Delayed old scope/revision responses, hide/show, concurrent selections, timeout/capacity, malformed replies and failed imports cannot restore cleared evidence or strand navigation |
| Read-only bounds | Instrument public calls to reject writes, pin acquisition, SQL execution and result-page reads; repeated inspect/select/close cycles do not accumulate handles, caches or background requests |
| Real deployment profiles | Catalog-only and automatic-local configurations work with the new public read owner; SQL-only/unconfigured profiles remain usable; restart/revocation and same-origin forwarding use real provisioned subjects |
| Accessible equivalent views | Keyboard-only diagram/grid selection, stable focus/return, screen-reader names and state announcements, reduced motion, narrow layout and native 200% zoom preserve all evidence; state is not color-only |

Use the existing [managed owner fixture](../../tests/catalog/tables/managed_table.zig)
and [installed SQL fixture](../../tests/interfaces/installation/server_managed_tables.py)
for lifecycle/replacement evidence, extending the
[Board workbench fixture](../../tests/interfaces/installation/board_workbench.py)
for the new endpoint and browser journey. Record transient states through the
actual owner; do not rely on sleeping long enough to catch a pending successor.
Synthetic frontend cases supplement, rather than replace, independent caller tests.

Run owning Zig unit/component and authority checks, `just test::managed-tables`,
`just transit-board::generate`, `just transit-board::check`, the Board API unit
target, and the extended `just transit-board::workbench-test` /
`just transit-board::workbench-browser` fixtures. Add assertions to the existing
finite observation/replay and negative-control checks where R3 adds transitions
or identity rules; do not create a competing lifecycle reducer. Run affected
`interfaces`/`core` lanes for native authority/contract changes. Final R4 acceptance
requires clean committed-revision `installation-ui`, `browser` and applicable
`formal` checks; focused passes cannot stand in for a failed full lane.

Measure R4's proposed cold/warm first-observation, selection and retained-heap
targets against this real feature, including one/two/four visible tabs and a
hidden tab, and report tunnel latency separately. Freeze the fixture/thresholds
before runs. Manual screen-reader/native-zoom outcomes remain separate from axe
and synthetic CSS zoom checks. Save real installed review figures in the next
applicable [Board design review](../design/board-data/README.md), labeling any
synthetic studies; keep delivery and acceptance decisions here.

Publish supported semantics and limits in Queries/DATAFLOW_V1, the query package,
Board guide/API/workbench and frontend owner inventory. Put reactive-state reasoning
in service-interface Internals and executed results in qualification history with
source revision, commands, configuration and limits. Run the documentation checker
and version-pin check when manifests change. **R3 is complete only when the public
read owner, independent caller and real Board journey agree at the implementation
revision; broader R4 and full-M30 completion remain separate.**

#### Deferred work and dependency handoff

R3 adds no administrative computation controls, result-row retrieval, global graph,
output chaining, incremental scheduling or synthetic freshness metrics. M12 owns
those computation extensions. Basic workbook Save/Open continues through L2–L4
after [M7's public Document lifecycle](07-document-storage-and-station-decoupling.md#implementation-plan-for-remaining-work),
conditional revisions and original-save recovery qualify without a browser; local
browser/file persistence is not a substitute. Retained/shared results still depend
on M28, and branch comparison/governed publication on M20/M27/M29. R3 neither
implements those services nor closes their remaining milestone obligations.

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
8-MiB embedded-asset bounds and R2's current guards: less than 900,000 bytes per
script, less than 800,000 bytes across at most four bootstrap scripts, no eager
feature implementations and at most four additional scripts per dynamic import.
Record manual screen-reader evidence separately from automated accessibility scans.

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
| Basic saved workbook drafts, proposed in the [local persistence plan](#local-connections-and-document-persistence-plan--2026-11-02) | M7 public Document lifecycle, conditional revisions, bounded reads and exact recovery, plus the shared application schema/caller; qualify without a browser before Save/Open integration |
| Retained/shared workbook results and investigations | M28 public identity, revisions, concurrent editing, disclosure and retained investigation/result lifetimes, exercised by a non-browser caller across replacement and revocation |
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
| [`foundations.tsx`](../../apps/transit-board-web/src/operations.tsx) renders Storage, `RelationalWorkspace` and interface bindings together. [`storage.tsx`](../../apps/transit-board-web/src/storage.tsx) obtains Table storage through the relational description's prepared source binding. | Extract the useful Table inspection and recovery paths before removing the worksheet; deleting the component alone would strand both. |
| [`Capabilities`](../../packages/zig/transit-board-api/src/root.zig) reports the older `query_enabled` and `reactive_table` capabilities, but no separate catalog/SQL-workbench configuration. [`main.zig`](../../apps/transit-board/main.zig) returns `404 QueryDisabled` when the corresponding workbench configuration is absent. | Add explicit per-feature configuration discovery. The older query flag cannot decide whether Catalog or Workbook works. Configuration evidence is not authorization. |
| [`data-workbench.tsx`](../../apps/transit-board-web/src/dataset.tsx) collapses metadata errors to strings, retries every five seconds and uses the same unavailable panel for Catalog and Workbook. [`state.tsx`](../../apps/transit-board-web/src/state.tsx), [`use-metadata.ts`](../../apps/transit-board-web/src/use-metadata.ts) and [`workbench-result.tsx`](../../apps/transit-board-web/src/workbench-result.tsx) separately own request and visibility transitions. | Replace these overlapping transitions with typed state/effect owners and feature-specific diagnostics; preserve each client's existing disclosure and recovery semantics. |
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
   Apply [D5's folding plane](../design/board-data/D5.md) after review: left
   activity/object navigation, one primary working surface and a shared right
   pane with Inspector/Assistant tabs. Retain D3's selection-driven Inspector.
   Definition, Profile, Storage, Lineage, History,
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
   Run until the session graph owner qualifies, then add D5's reactive dependent
   cells within visible finite Live budgets. Keep drafts, exact input revisions,
   in-flight work and last complete results separate; blur/debounce coalesce,
   unrelated cells do not rerun and source-follow remains a separate capability.
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
