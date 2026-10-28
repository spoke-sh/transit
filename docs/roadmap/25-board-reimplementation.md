# 25. Board reimplementation and data-first workbench

[Roadmap](README.md) · **Status:** Planned

Reimplement Board as the installed interface for discovering data, explaining
computations and reviewing governed changes. Deliver the focused catalog,
dataset previews, relationships, SQL workbooks, directed lineage and change
workflows developed in [board-data D2](../design/board-data/D2.md). Preserve
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

## Prerequisites and delivery position

Place this milestone after
[versioned proposals and reviewed publication](24-reviewed-data-collaboration.md)
and before [MCP service and interactive Apps](26-mcp-service-and-apps.md).
The full workbench needs the same investigation, proposal and publication
contracts that agent hosts will consume. Delivering the human interface first
provides a concrete caller for those workflows and their failure states.
MCP still consumes shared services directly and must not depend on Board's
frontend or API as an intermediary.

| Required capability | Owning milestone | Board consumption and boundary |
| --- | --- | --- |
| Stable objects, definitions and installed data lifecycles | [Identities](01-declarative-data-lifecycle.md), [live cutover](03-live-storage-and-sql-cutover.md) | Authorized catalog discovery and bounded metadata with distinct definitions, data revisions and observed progress |
| Typed results, transactions and caller recovery | [Statement results](04-statement-results-and-consumption.md), [transactions](05-transactions-and-atomic-composition.md), [client foundation](07-client-foundation-and-language-apis.md), [interface coverage](16-service-and-sdk-coverage.md) | Shared readers, explicit transaction attribution and original-operation settlement; no browser-only result or recovery protocol |
| Historical interpretation, derived computation and multi-model data | [Historical catalogs](08-standards-and-catalogs.md), [managed dataflows](10-sql-and-dataflows.md), [foreign relations](14-multi-model-and-foreign-relations.md) | Exact result bases, accepted projections/decoders, five-state values and registered lineage; no raw storage inspection or arbitrary application-value decoding |
| Branches, policy and comparable investigations | [Branches](15-branches-merges-and-restore.md), [Control & Policy Plane](22-control-and-policy-plane.md), [published resources](23-published-resources-and-investigations.md) | Exact comparison inputs, authorized disclosure and retained investigation lifetimes; a screen label grants no access or retention |
| Review and conditional publication | [Reviewed publication](24-reviewed-data-collaboration.md) | Candidate-bound evidence, configured approval policy, conditional publication and uncertain-outcome recovery |
| Indexes, plans and measured costs | [Indexing](09-indexing-and-access-paths.md), [performance](11-data-structures-and-performance.md) | Shared definitions, build/coverage state, access paths and attributable metrics; statistics and estimates never establish result truth or administrative authority |

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
[reactive context](27-reactive-context-and-agent-activation.md), outbound MCP and
complete mixed-language composition are not prerequisites for this cutover.
Existing qualified finite Live behavior remains supported; broader subscriptions
or agent activation require their own contracts.

## Initial-pass implementation plan

**Review state:** proposed for review; implementation has not started. This plan
is based on repository revision `db4ae576e` and
[board-data D2](../design/board-data/D2.md), reviewed on 2026-10-28. Planning does
not change this milestone's `Planned` status or complete its later workflows.

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
- [ ] Metadata selection creates no data query. Preview and Run require explicit
  intent and the separately configured query capability.
- [ ] Screens use shared catalog/result APIs; native fetch, pin, signing and
  settlement machinery stays below the presentation boundary.
- [ ] Large catalogs/results remain bounded; empty, complete, limited, failed,
  cancelled and unavailable outcomes have distinct evidence-backed presentation.
- [ ] Values, profiles and source attribution match independent callers;
  definition identity, data position and policy observation remain distinct.
- [ ] Current authorization governs metadata and buffered disclosure. Hidden
  views, stale replies, denial and cross-scope navigation cannot restore cleared data.
- [ ] SQL edits never execute implicitly; changed drafts cannot relabel earlier
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
[combined qualification](30-qualification-and-benchmarks.md) repeats the cross-caller
journeys at one release revision and does not postpone these acceptance gates.

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
