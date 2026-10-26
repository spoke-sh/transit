# 22. Board reimplementation and data-first workbench

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
[versioned proposals and reviewed publication](21-reviewed-data-collaboration.md)
and before [MCP service and interactive Apps](23-mcp-service-and-apps.md).
The full workbench needs the same investigation, proposal and publication
contracts that agent hosts will consume. Delivering the human interface first
provides a concrete caller for those workflows and their failure states.
MCP still consumes shared services directly and must not depend on Board's
frontend or API as an intermediary.

| Required capability | Owning milestone | Board consumption and boundary |
| --- | --- | --- |
| Stable objects, definitions and installed data lifecycles | [Identities](01-declarative-data-lifecycle.md), [live cutover](03-live-storage-and-sql-cutover.md) | Authorized catalog discovery and bounded metadata with distinct definitions, data revisions and observed progress |
| Typed results, transactions and caller recovery | [Statement results](04-statement-results-and-consumption.md), [transactions](05-transactions-and-atomic-composition.md), [client foundation](06-client-foundation-and-language-apis.md), [interface coverage](13-service-and-sdk-coverage.md) | Shared readers, explicit transaction attribution and original-operation settlement; no browser-only result or recovery protocol |
| Historical interpretation, derived computation and multi-model data | [Historical catalogs](07-standards-and-catalogs.md), [managed dataflows](09-sql-and-dataflows.md), [foreign relations](11-multi-model-and-foreign-relations.md) | Exact result bases, accepted projections/decoders, five-state values and registered lineage; no raw storage inspection or arbitrary application-value decoding |
| Branches, policy and comparable investigations | [Branches](12-branches-merges-and-restore.md), [Control & Policy Plane](19-control-and-policy-plane.md), [published resources](20-published-resources-and-investigations.md) | Exact comparison inputs, authorized disclosure and retained investigation lifetimes; a screen label grants no access or retention |
| Review and conditional publication | [Reviewed publication](21-reviewed-data-collaboration.md) | Candidate-bound evidence, configured approval policy, conditional publication and uncertain-outcome recovery |
| Indexes, plans and measured costs | [Indexing](08-indexing-and-access-paths.md), [performance](10-data-structures-and-performance.md) | Shared definitions, build/coverage state, access paths and attributable metrics; statistics and estimates never establish result truth or administrative authority |

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
[reactive context](24-reactive-context-and-agent-activation.md), outbound MCP and
complete mixed-language composition are not prerequisites for this cutover.
Existing qualified finite Live behavior remains supported; broader subscriptions
or agent activation require their own contracts.

## Delivery sequence

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

Record executed component/service/browser evidence in [the proof ledger](../../tests/README.md),
with independently reproducible fixtures and actual source revisions. Updated
screenshots must come from the installed implementation and match its qualified
states. Focused Board proofs close here; later
[combined qualification](27-qualification-and-benchmarks.md) repeats the cross-caller
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
