# 19. Branches, merges and restore

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** In Progress ([implementation plan](#implementation-plan--2026-10-31); [foundation increment](#foundation-increment--2026-10-31); [earlier component evidence](#delivered-implementation-evidence--2026-10-30))

Add isolated application-state branching, three-way merging and point-in-time
restore built directly on the [immutable `.tseg` segment and Manifest architecture](02-storage-and-query-performance.md)
and [historical catalog binding](10-standards-and-catalogs.md). The
[state model](../handbook/internals/state-model.md) owns the authority/lifetime
model. Branching is the underlying versioning primitive within a realm. Branches
never copy live process identities, grants or effect rights.

Restore here means publishing earlier application data as a new forward successor
under current authority. [Operations](24-operations-and-recovery.md) separately
owns backup capture, installation disaster recovery and runtime upgrades; a
branch snapshot alone is not sufficient recovery material for an installation.

Make branches understandable as separately advancing histories of declared
application data and its catalog interpretation under the realm's current policy.
Branch creation is not inherently export, new ownership or a new authority
boundary. Define branch visibility, permissions and any inheritance explicitly;
creation does not freeze source privileges. A higher-level project/application
fork relationship is outside this milestone. In the target representation,
committed table state uses immutable **Manifests (`manifest/v{N}`)** referencing immutable
**`.tseg` Data Segments** and **`.tdel` Deletion Vectors** in `TransitObjectStore`,
branch-head publication targets an $O(1)$ metadata operation over an already
durable, pinned snapshot without copying all data files. Snapshot preparation
and retained-tail ownership have separate costs and guarantees. Inspection must
show definition/data differences, dependency changes, merge conflicts and pending recomputation
through the shared lifecycle. Copying a definition must not activate its
computations or renew old policy.

Consume [transaction snapshots and publication](05-transactions-and-atomic-composition.md)
without equating a branch to an open transaction. A branch is a durable history
containing multiple commits, with separate merge validation, lifetime and policy.
Merge must preserve its selected atomic domain, constraints and original decision
recovery; segment reuse alone supplies no isolation guarantee. Staged or historical
outbox records cannot become executable merely through branch creation or merge.

## Delivery sequence

The operations and SQL forms in this sequence are delivery targets. The
[source audit](#source-audit-reuse-and-unfinished-integration) distinguishes
existing component helpers from executable branch operations.

Use [#125](https://github.com/spoke-sh/transit/issues/125) for catalog/snapshot
identity and [#127](https://github.com/spoke-sh/transit/issues/127) for durable
WAL/object pins and retention. A new branch includes accepted unflushed rows; pointing
only at the latest flushed Table manifest is insufficient. Select a checkpoint
or pinned-tail representation before implementing branch publication. Keep
authority/process evidence separate from branchable application state.

1. **Publish full-data and schema-only branches from exact retained versions:**
   use bounded independent copies as the correctness oracle while implementing
   $O(1)$ branch-head publication (`refs/heads/<branch> -> manifest/v{N}`) and
   branch-qualified `TransitLog` partitions for subsequent object/partition deltas. Assign
   branch identity and branch-scoped catalog bindings within the realm; evaluate
   current branch-creation and data access rights. Define conditional head publication
   (`If-None-Match` CAS) and source retention/expiry protection so garbage
   collection preserves every `.tseg`/`.tdel` object reachable from any active
   branch or retained snapshot, including its required WAL/history references.
2. **Isolate branch writes over shared `.tseg` segments:** writes on a branch
   append to branch-owned `TransitLog` partitions and flush new `.tseg` segments
   and branch-local `.tdel` deletion vectors without mutating parent segments.
   Parent/child deletion and restart must preserve every reachable byte.
3. **Implement segment-aware two-way/three-way `DIFF` (`DIFF` and `DIFF_SCHEMA`) and reviewed KV/Table merges:**
   given a two-way pair (**`from` Manifest**, **`to` Manifest**) or a three-way
   common ancestor (**`base` Manifest**, **`source` Manifest** and **`target`
   Manifest**), skip identical `.tseg`/`.tdel` entries with matching interpretation,
   visibility and retained-tail coverage in $O(1)$ per entry
   ([A4: `BranchMergeAlgebra.lean`](21-formal-semantics-and-correspondence.md#a4-logical-merge-and-safe-segment-skipping))
   and compute key-aligned diffs using logical change lineage, retained tail
   state, added segments and divergent deletion vectors:
   - **First-class relational and document `DIFF(object, ...)`:** align rows by
     primary key (or `_row_id` / Document tree path) under declared column
     collations ($\kappa$). Unlike ISO SQL `EXCEPT` (which is one-way,
     key-blind and schema-rigid) or table-doubling diff functions, emit compact
     key-aligned delta rows (`_diff_op IN ('added', 'modified', 'removed', 'conflict')`)
     that project across compatible `DefinitionId` evolutions using stable
     `ColumnId` lineage. In three-way branch diffs and merge previews, represent
     cells modified to incompatible values on both `source` and `target` natively
     using Transit's **five-state `conflict` cell tag (`IS CONFLICT`)** so callers
     can filter and inspect merge conflicts directly in standard SQL.
   - **First-class catalog and schema diff (`DIFF_SCHEMA(...)`):** compare
     `CatalogId`, `DefinitionId` and `ColumnId` graphs between two snapshots,
     branches or remotes—distinguishing true column/table renames (`ColumnId`
     preserved) and lazy default projections from drop-and-recreate mutations,
     and reporting affected `CHECK`/`FOREIGN KEY` constraints and downstream
     dataflows.
   - **Reviewed three-way merge publication:** physical compaction can replace
     segment IDs without changing data; use logical lineage/change evidence to
     avoid inventing merge changes or conflicts from that rewrite. Freeze
     `base`/`source`/`target`, align schemas, validate constraints, surface
     row/cell conflicts explicitly, and commit the merged Manifest via
     conditional CAS (`Multi-Writer OCC`), rejecting stale target heads.
     Schema-only promotion preserves target rows unless explicitly migrated.
4. **Extend diff and merge to compatible Documents ([Milestone 7](07-document-storage-and-station-decoupling.md) and [Milestone 16](16-document-profiles-and-gateway-exchange-lifecycle.md)), 2D/3D geospatial & volumetric models ([Milestone 17](17-geospatial-and-spatio-temporal-computing.md)) and qualified graph mappings:**
   support both `versioned` structural three-way diff/merge and `causal_crdt`
   replica state-vector convergence, use `.tseg` 2D/3D bounding-box (`BBOX2D`/`BBOX3D`) and `S2`/`OCT_CELL` Hilbert
   zone maps for per-entry spatial and volumetric pruning during viewport-scoped diffs
   and surface conflicting edits to shared `.topo_arc` / `.topo_face` boundary chains/faces or 3D assembly clash collisions as
   five-state `IS CONFLICT` cells, preserving causal/tombstone semantics,
   fresh replica identities and valid graph endpoints; incompatible histories
   refuse and derived views rebuild or verify against the merged manifest.
5. **Restore as a new forward Manifest successor:** publish a restored snapshot
   as a new monotonic manifest version (`manifest/v{N+1}`) rather than truncating
   history. Define pending input, job and subscription disposition, explicit
   activation and external-outcome reconciliation.
6. **Support Git-like remote $\leftrightarrow$ local incremental mirroring, lazy `.tseg` fetch and local migration testing ("Git remotes for data"):**
   define a transferable content-addressed Merkle DAG (`manifest/v{N}`
   commits $\to$ `DefinitionId` catalog trees $\to$ immutable SHA-256 `.tseg`
   blobs and `.tdel`/`.tack` bitmaps plus `TWAL1` delta tails), then allow a local or
   staging Transit instance to attach to an upstream remote Transit peer
   (`CREATE REMOTE`, `FETCH`, continuous `MIRROR`) under the caller's scoped
   `policy_epoch` grants (enforcing security-barrier RLS and dynamic masking at
   the remote egress boundary):
   - **Incremental delta fetch and lazy `.tseg` hydration:** `FETCH` and `MIRROR`
     transfer only the signed `manifest/v{N}` history and the `.tseg`/`.tdel`
     objects (or `TWAL1` tail frames) added since the last common ancestor
     `manifest/v{K}`, hydrating historical `.tseg` segments eagerly (for offline
     work) or lazily on demand into the local `NvmeCache`.
   - **Local branching, schema migrations and fenced dataflow execution:** a
     developer or agent branches locally (`CREATE BRANCH local_mig FROM
     REMOTE 'prod/main'`), applies candidate DDL migrations (`ALTER TABLE`), and
     runs local queries, dataflows and `Station` behaviors with external
     connector effects strictly fenced to network-free replay over captured
     `DocumentPartition` exchanges ([Milestone 16](16-document-profiles-and-gateway-exchange-lifecycle.md)).
   - **Upstream proposal push:** instead of executing imperative migration scripts
     blindly on production, push only the local branch's delta `.tseg`/`.tdel`
     segments, schema migration plan and candidate manifest to the remote as a
     [Milestone 28 versioned proposal](28-reviewed-data-collaboration.md) for
     three-way `DIFF` / `DIFF_SCHEMA` review, constraint validation and atomic
     `manifest/v{N+1}` publication.

## Policy and collaboration boundary

Extend the [index lifecycle](11-indexing-and-access-paths.md) and
[compaction/clustering policies](13-data-structures-and-performance.md) to
branch-local definitions, generations and coverage. Share compatible immutable
index and `.tseg` objects only with their exact source cuts, WAL overlays and
retention roots. Revalidate uniqueness, row-level `CHECK` expressions and
cross-table `FOREIGN KEY` referential integrity against the combined merge
candidate, including disjoint branch changes that collide on a secondary key or
delete a parent key on one branch while inserting a child reference on the other.
Define **branch-aware compaction and shared-segment garbage collection**: compact
branch-divergent `.tdel` bitmaps and small segments using reachability watermarks
and cost thresholds so compacting `main` neither breaks pinned ancestor/branch
manifests nor causes unmitigated $O(B)$ storage amplification across $B$ active
branches. Rebuild or use another qualified path where coverage is missing;
copying an index definition cannot publish readiness. Qualify parent/child
rebuild, drop, branch-aware compaction and GC with retained readers. Extend the
[performance scorecard](13-data-structures-and-performance.md) with snapshot
preparation/pinning, head publication, merge validation, cross-branch compaction
amplification and index maintenance separately; immutable sharing alone does not
make all branching work constant-time.

Branch creation, read, edit and merge have independent permissions under current
realm policy. Support installations with all merging disabled, and protect
destination heads against equivalent direct writes. This milestone establishes
the native data/policy primitives; [enterprise identity](26-control-and-policy-plane.md)
binds external subjects and delegated actors, and
[reviewed collaboration](28-reviewed-data-collaboration.md) adds published
proposals, intent-bound approval and shared human/agent review. Reading or
copying historical application data cannot restore historical grants.

## Completion evidence

Require copy/merge oracles, write/delete isolation across parent and child
branches, current source/branch authority, GC reachability across multi-branch
manifests, stale-head OCC rejection, collation-aware key conflict detection,
lost-reply recovery and bounded cleanup. Test data, branch and conflict counts
beyond resident RAM and NVMe caches. Include branch creation before flush, concurrent
compaction/GC, retained-tail trim and parent/child restart. Measure head-publication
latency separately from preparing/pinning the durable snapshot, merge work against
actual logical changes and physical rewrites, and shared versus branch-owned
`.tseg` bytes.

Never revive retired processes, restore revoked rights or redispatch historical
effects. Independent exports, higher-level forks, cross-realm collaboration and
live realm rollback require separate contracts.

## Implementation plan — 2026-10-31

### Outcome, baseline and delivery profile

A caller selects an exact retained application-data cut, creates an independently
writable branch, inspects bounded data/schema differences, and conditionally
publishes a validated merge or forward restore. After disconnect or restart the
caller recovers the original operation and its decision. Readers can identify
the branch, definitions, source cut, completeness and current access basis.

**Audited baseline:** fetched `origin/main` at
`0e2fba44727ca858bd1e8e4a775b62fbcf1a665d`, 2026-10-31. This plan replaces the
[October 30 implementation plan](#implementation-plan--2026-10-30), retaining its
[component inventory](#delivered-implementation-evidence--2026-10-30) and the
milestone's full scope. Source inspection establishes the gaps below; this
planning change executes no runtime qualification and marks no work package
complete. Milestone 19 remains **In Progress**.

Start with one local catalog/database, one realm, a fenced authority and the
existing disk-backed storage providers. Tables are the first executable data
profile. Extend KV, Documents and other declared objects only through their
qualified owners. This is a delivery order, not removal of the multi-model or
remote-sync completion criteria. A Table-only slice cannot close M19.

Use [data lifecycle identities](../../contracts/DATA_LIFECYCLE_V1.md),
[direct operations](../../contracts/DIRECT_TABLE_V1.md),
[retained versions](../../contracts/READ_VERSIONS_V1.md),
[current authorization](../../contracts/AUTHORIZATION_V1.md) and the
[state model](../handbook/internals/state-model.md#schema-history-and-branches).
The state-model branch sections are design analysis, not an executable contract.
Resolve differences there as implementation establishes behavior; in particular,
branch publication must use the database owner, not the historical proposal to
coordinate through a Station resource turn.

### Source audit: reuse and unfinished integration

| Area | Evidence at the audited baseline | Implementation consequence |
| --- | --- | --- |
| Live branch selection | [`DataLifecycle.ResourceInitialization`](../../packages/zig/transit-protocol/src/DataLifecycle.zig), [`DirectCatalogRecords.Configuration`](../../packages/zig/transit-catalog/src/DirectCatalogRecords.zig) and [`DirectTableProtocol.Connection`](../../packages/zig/transit-catalog/src/DirectTableProtocol.zig) still require branch one. [`HistoricalTimeline.publishHeadConditional`](../../packages/zig/transit-catalog/src/HistoricalCatalog.zig) rejects multi-commit non-main branching. | Remove restrictions only with durable branch ownership, authorization, readers and publication wired together. A nonzero branch field alone cannot enable the feature. |
| Branch lifecycle helper | [`BranchLifecycle`](../../packages/zig/transit-catalog/src/BranchLifecycle.zig) has a 128-entry branch array, 256-cut array, borrowed row/tail slices and calculated publication metrics. It models creation, ancestry, overlays and reachability. | Replace total-cardinality arrays with paged persistent directories; acquire real pins and WAL partitions. Its metrics are not measured publication latency or storage accounting. |
| Diff helper | [`BranchDiff`](../../packages/zig/transit-fuze/src/BranchDiff.zig) implements finite segment/row/schema comparisons, five-state conflicts and spatial checks over supplied inputs. | Build retained-source iterators, complete schema/dependency comparison, typed result bindings and bounded spill. Prove skip eligibility against interpretation, visibility and tails as well as segment bytes. |
| Merge helper | [`BranchMergeRestore`](../../packages/zig/transit-catalog/src/BranchMergeRestore.zig) uses at most eight candidate tables, 32 rows per table and a 64-entry token-only `MergeTokenJournal`; publication changes `BranchRegistry`. Candidate row slices originate in local work arrays. | Use immutable staged roots and owned batch lifetimes, durable account/token bindings, complete candidate membership and a real atomic decision. Audit escaping slices before reusing algorithms. Raising limits is not the solution. |
| Restore helper | `restoreBranchForward` changes the in-memory registry and returns dataflow/outbox/discontinuity dispositions. | Persist the decision and disposition work; integrate actual computation, reader and effect owners. A returned enum does not suspend a running computation or prevent dispatch. |
| Remote helper | `fetchIncrementalFromRemote` counts supplied segment IDs and returns a policy flag; `hydrateLazySegmentOnDemand` hashes supplied bytes. | Implement authenticated transfer, real egress policy, resumable storage and cache admission. Neither helper establishes network transfer, RLS filtering, mirroring or proposal publication. |
| Existing durable owners | [`DirectCatalog`](../../packages/zig/transit-catalog/src/DirectCatalog.zig), [`DirectClientToken`](../../packages/zig/transit-catalog/src/DirectClientToken.zig), [`TableSnapshot`](../../packages/zig/transit-storage/src/TableSnapshot.zig), [`DirectStorageGraph`](../../packages/zig/transit-catalog/src/DirectStorageGraph.zig) and the [Table transaction profile](05-transactions-and-atomic-composition.md) supply paged ownership, original attempts, retained cuts and common decisions. | Extend these owners rather than installing a second branch registry, permission store or merge receipt authority. Branch heads must agree with ordinary DDL/DML and transaction visibility. |
| Caller integration | The branch helpers are referenced by package exports/tests and each other; the audited live SQL [`Statement`](../../packages/zig/transit-sql/src/Statement.zig) and signed direct request dispatcher do not expose their lifecycle. | Add typed native operations and SQL lowering with capability reporting; parser acceptance cannot establish execution. There is no `transit-sql/src/Parser.zig` at this baseline. |
| Evidence | [`branch_merge_restore.py`](../../tests/catalog/tables/branch_merge_restore.py) compares generated JSON fixtures and checks source-symbol presence. Zig component suites exist; no M19 end-to-end qualification record was found in the [ledger](../history/qualification/README.md). | Preserve the fixtures as contract examples. Add an independent executable oracle and disk/service fault schedules; do not count fixture booleans or symbol checks as executed recovery, GC, masking or scale evidence. |

### Recent foundations and upcoming milestone boundaries

Statuses below are roadmap statuses at the baseline, not claims that every
proposed mechanism in those plans is implemented. Recheck the owning contracts
when each dependent package starts; do not base delivery on unmerged worktrees.

| Owner and status | M19 dependency or handoff |
| --- | --- |
| [M1](01-declarative-data-lifecycle.md), [M2](02-storage-and-query-performance.md), [M4](04-statement-results-and-consumption.md), [M5](05-transactions-and-atomic-composition.md) — Completed | Reuse neutral identities, local durability, logical statement results and the qualified local multi-Table decision domain. M5 completion does not qualify native KV/Document or log/lease participants. M19 must prove schema/data branch-head publication in that domain. |
| [M3](03-live-storage-and-sql-cutover.md) — In Progress | Extend installed lifecycle, exact retained roots, current rights and resumable collection. Preserve accepted unflushed WAL rows and original receipts through archive/trim/reopen. |
| [M6](06-streams-queues-and-durable-runtime.md) — In Progress | Recent direct Stream/Queue owners, shared bitmap storage and database-owned SQL recovery are reusable. Direct KV, mixed participants and the Station transaction cutover remain gates. Never turn copied consumer offsets, `.tack` claims, timers or outbox bytes into execution rights. |
| [M7](07-document-storage-and-station-decoupling.md) — In Progress | Logical merge and `DocumentPartition` storage foundations exist; the plan still gates direct dispatch and consumer/transaction cutover. M19 branches and merges Documents through that owner, not old Station storage. |
| [M8](08-gateway-architecture-and-protocol-ingress.md), [M9](09-client-foundation-and-language-apis.md) — In Progress | Reuse `DatabaseRuntime`, event-driven accepted-work recovery and shared callers. The latest main merge also delivers [declarative browser publications](../handbook/reference/reactive.md#declarative-browser-publications); add branch identity to their source/recovery bindings without confusing browser refresh with native reactive subscriptions. |
| [M10](10-standards-and-catalogs.md) — In Progress | Exact historical catalog/data cuts, stable column lineage, collations and constraint semantics are prerequisites. Historical helper types alone do not supply durable cut acquisition or current-policy enforcement. Close shared gaps with this owner before branch exposure. |
| [M11](11-indexing-and-access-paths.md) — Planned | Branch-local index definitions, coverage and uniqueness integrate when the index owner qualifies them. Until then, use a qualified bounded complete scan where semantics exist, or refuse that profile; never assume copied indexes are ready. |
| [M12](12-sql-and-dataflows.md) — In Progress | Bind copied definitions inactive; preserve result/source provenance. Merge/restore schedules owner-managed invalidation, suspension or recomputation. An in-memory disposition must not claim service activation or DBSP coverage. |
| [M13](13-data-structures-and-performance.md), [M14](14-vectorized-strings-and-search.md) — In Progress; [M15](15-data-centric-compilation-and-specialization.md) — Planned | Share memory/IO budgets, measured compaction policy and qualified collation comparisons. Vectorization, string prefixes and compiled execution optimize the same oracle-tested semantics; none is a correctness prerequisite for the first branch path. |
| [M16](16-document-profiles-and-gateway-exchange-lifecycle.md), [M17](17-geospatial-and-spatio-temporal-computing.md), [M18](18-multi-model-and-foreign-relations.md) — Planned | Gate profile-aware Document provenance, spatial/topological validation, graph endpoints and foreign manifests on their exact owner contracts. Bound the first local slice independently, but keep these M19 integrations open until qualified. |
| [M20](20-service-and-sdk-coverage.md), [M21](21-formal-semantics-and-correspondence.md) — In Progress | M19 supplies shared branch operations and migrates affected consumers; M20 broadens the installed adapter matrix. M21's T6 candidate is `BranchMerge.tla`, A4 is `BranchMergeAlgebra.lean`; these are proposed obligations, not existing `specs/lean` proofs. |
| [M22](22-storage-providers-and-concurrency.md)–[M25](25-clustered-execution.md) — Planned | Local branch CAS is not distributed multi-writer qualification. Remote mirroring is not replication/failover. M24 owns complete installation backup/restore and upgrades; M19 restores selected application data forward under current authority. |
| [M26](26-control-and-policy-plane.md), [M27](27-published-resources-and-investigations.md), [M29](29-board-reimplementation.md) — In Progress; [M28](28-reviewed-data-collaboration.md) — Planned | Use current native policy first, expose exact candidate/target bindings for later delegation, publication and review, and preserve read-only Board inspection and its initial workbench work. M28 owns proposal/approval lifecycle and human-only approval, avoiding a dependency cycle in local M19 completion. M19 owns remote candidate transfer; full `PROPOSE` review journeys close in M28. |
| [M35](35-qualification-and-benchmarks.md) — Planned | Combine later evidence at one revision; M19 must supply its own caller, failure, growth and benchmark evidence now rather than defer correctness to final qualification. |

### Contract decisions to settle before runtime exposure

The following are recommended implementation constraints. Exact fields, errors
and syntax must land in the owning current-v1 contracts before adapters. They
are not already accepted wire definitions or runnable SQL examples.

**Identity and scope.** A branch has immutable realm/catalog identity and a
non-reused branch ID, a mutable name, a generation, a head and current policy
references. Keep logical object lineage and `ColumnId` lineage separate from
branch-local object bindings and physical partitions. Preserve lineage on a fork;
allocate collision-free identities for independent additions. Drop/recreate of a
branch or object name cannot retarget an old operation or cursor. Bind a statement
to one resolved head; bind an explicit transaction to its admitted branch and cut.
Prepared statements acquire a fresh execution cut while preserving their original
metadata contract. Switching branch must not retarget an open transaction.

**Publication and history.** One database decision publishes the complete
candidate schema/data directory and branch head. Every ordinary write path must
participate in that visibility protocol; a head-only CAS over independently live
Table mutations would expose inconsistent snapshots. Reuse M5 guards and decisions,
including private prepared roots and recovery, without routing through Station.
Do not serialize all row payloads through a branch log: retain per-object and
per-partition data logs, with branch-qualified allocation/ownership and a bounded
catalog publication record. A dedicated branch delta namespace is not one mailbox
or a single data-ingestion bottleneck.

A frozen manifest commits to its entire interpretation, dependency closure,
retained roots and per-partition frontiers, provenance and parent edges. Catalog
positions and Table WAL positions remain distinct. A descriptor or digest does
not acquire a pin. Pins must survive owner replacement before publication becomes
visible. Snapshot acquisition over the supported atomic domain must include every
accepted unflushed row at the cut. Unsupported mixed-domain acquisition refuses;
an independently sampled vector cannot be called an atomic snapshot.

**Three-way meaning.** Resolve immutable base/source/target and preserve them
through preview, resolution and publication. Initially reject ambiguous merge bases
or unavailable ancestry rather than choose an arbitrary common ancestor. Bind
resolutions to the candidate digest and expected target generation/head. Source
movement after freezing does not silently enlarge the candidate; target movement
requires a new explicit plan. Distinguish same-key divergent edits, delete/modify,
concurrent inserts, key changes, schema conflicts and non-conflicting edits that
jointly violate constraints. Composite keys use declared collation semantics;
keyless Tables require durable row lineage or explicit refusal, never physical
row offsets as identity. Opaque KV merges are per-key byte comparisons unless an
application supplies an explicit supported interpretation.

A durable conflict record carries base/source/target provenance and resolution
state. A five-state `conflict` cell is a query projection of that evidence, not
an instruction to persist unresolved conflicts into ordinary Table rows. Define
missing-column versus SQL NULL/default behavior through schema projection, not a
renderer. Schema-only omission is not row deletion; promotion validates a migration
against current target rows and preserves them unless an explicit data migration
is included. Unsupported conversions and histories reject before publication.

**Policy and recovery.** Reuse the native policy catalog for separate inspect,
create, read, write, drop, merge, restore and remote-disclosure actions. Specify
branch inheritance and source-lifetime obligations; branch creation freezes neither
grants nor source privileges. Recheck policy at admission, publication and every
protected disclosure, including metadata, conflicts, receipts and empty terminals.
Merge-disabled installations reject merges; protected destinations reject equivalent
DDL/DML, transaction, restore and import bypasses unless explicitly authorized by
the same publication policy. Do not invent a second `GrantSet` authority.

All mutating operations bind the original account/token, request fingerprint,
branch identities, source cuts and expected destination. Extend `DirectClientToken`
and the common operation namespace; do not keep a token-only merge journal.
Decision, receipt and head visibility must agree after lost replies or restart.
Changing request content under an old token rejects. Cancellation before decision
can close staged work; after acceptance it cannot retract publication. Missing
response or timeout is unresolved, never automatic retry under a new identity.

**Lifetime and bounded work.** Unlimited retention remains the default. Logical
branch deletion, pin release, eligible expiry and physical cleanup are separate
operations. The retained graph includes all live heads, historical cuts, read pins,
active transactions, staged candidates, unresolved operations, original receipts
and remote transfer holds. Catalog roots, manifests, branch lists, ancestry walks,
conflict sets and token indexes must be paged independently of their cardinality.
Use reusable scratch/output arenas, bounded batches and declared spill/work quotas;
exhaustion returns typed refusal or resumable progress, not truncated success.

Constant-size head publication means no data-sized copying after preparation;
it is not a claim of constant total work. Paged directory lookup/update has its
own cost. Segment planning visits metadata; equal entries can skip payload reads
only with equal logical interpretation, deletion/visibility state and tail coverage.
Authenticated compaction lineage can justify a skip; a caller-supplied multiset
hash cannot establish equivalence. Constraint checking may require the entire
candidate and dependency closure even when the physical delta is small.

### Data-kind and execution disposition

| Object or evidence | Create, merge and forward-restore rule |
| --- | --- |
| Tables | Share immutable roots plus protected tails; writes use isolated roots and deletion overlays. Publish complete schema/data interpretation and validate all applicable constraints. |
| KV | Include declared application data through the qualified direct KV owner. Do not clone native framework/control records or infer field merge semantics from opaque values. |
| Documents | Preserve revisions, causal predecessors, tombstones, profiles and raw provenance. Allocate fresh replica namespaces durably; gate mutation and merge on M7 participation and exact compatible histories. |
| Streams | Retained payload history may be exposed as explicitly historical slices. New writes use fresh branch-qualified partitions/epochs; consumer progress is not a live consumer assignment. |
| Queues and Station inboxes | Payloads may be historical evidence; copied leases, ACK eligibility, timers and claims never become active work. Re-enqueue requires an explicit new authorized operation. Unsupported inclusion or merge must reject or be explicitly excluded in the manifest. |
| Indexes, views and dataflows | Copy definitions inactive. Reuse derived bytes only with exact coverage; otherwise invalidate and rebuild/recompute through the owner. Retained prior results keep their original basis and cannot masquerade as current. |
| Foreign data and captured exchanges | Bind immutable content and profile/decoder commitments with explicit availability. A URL is not a snapshot. Missing dependencies fail visibly; replay cannot fetch a live replacement as equivalent evidence. |
| Grants, credentials, PIDs, operation receipts, retirement and effect control | Remain current authority/recovery evidence outside branchable application data. Do not rewind them. Historical effect intents/outcomes may be inspected but cannot redispatch or be relabeled successful/cancelled. |

### Work packages and delivery gates

`R0`–`R10` name the remaining work, replacing the earlier `P0`–`P8` sequence.
Each package includes owner documentation and focused executable checks. Add
vertical typed-caller tests as each owner lands; R8 completes the cross-interface
journeys rather than postponing all caller validation until the end.

| Package | Depends on | Reviewable outcome |
| --- | --- | --- |
| R0 | M1/M4/M5 contracts; M10 coordination | Neutral branch/cut/candidate/decision and current-policy contracts, fixture and consumer migration inventory |
| R1 | R0 | Durable paged branch directory, history and original-operation recovery |
| R2 | R1; qualified retained-cut owners | Full-data/schema-only Table creation, protected unflushed tails and independent-copy equivalence |
| R3 | R2 | Isolated ordinary writes/transactions, branch-aware retention/GC and compaction |
| R4 | R2–R3; M10 semantics | Bounded two-/three-way data and schema diffs with complete result evidence |
| R5 | R3–R4 | Whole-candidate constraint validation and atomic merge publication |
| R6 | R3–R5; qualified M6/M7/M11/M16–M18 profiles | KV/Document and specialized model/index integration |
| R7 | R3–R5; execution disposition contracts | Durable forward restore and actual computation/subscription/effect fencing |
| R8 | R0 onward; R4/R5/R7 for full journeys | Shared native/SQL client execution, installed recovery and read-only inspection |
| R9 | R2–R8; qualified egress/capture contracts | Remote fetch/mirror, verified hydration and exact candidate transfer |
| R10 | All applicable gates | Disk/service faults, independent oracles, bounded scale, measured scorecard and public promotion |

#### R0 — Contracts and one current-v1 cutover

Extend `DataLifecycle`, transaction bindings and the direct request/result types
with branch identity, immutable cut references, policy requirements, candidate
progress/conflicts, expected-head guards and original decisions. Define branch
selection for ordinary reads/writes, prepared statements and transactions; define
`DIFF`/`DIFF_SCHEMA` output schemas, terminal coverage and conflict attribution.
Agree manifest encoding, definition commitments, parent edges, pin ownership,
operation states and budgets before choosing new storage files.

Update [DATA_LIFECYCLE_V1](../../contracts/DATA_LIFECYCLE_V1.md),
[DIRECT_TABLE_V1](../../contracts/DIRECT_TABLE_V1.md), affected retained-read and
[SQL session](../../contracts/SQL_SESSION_V1.md)/[result](../../contracts/SQL_RESULTS_V1.md)
contracts and the [reference grammar](../../contracts/sql/README.md).
Allocate new branch-specific contract files only if they have a distinct owner;
keep a single source of generated types. Inventory all single-branch checks,
including transaction, resource-initialization, signed-envelope and configuration
checks, instead of changing only the three guards named in the source audit.

The cutover replaces incompatible definitions, persisted layouts, signed fixtures,
binding resources and affected consumers together under the
[versioning policy](../handbook/reference/versioning.md). Reject missing/foreign
definitions before execution; never default old artifacts to branch one/current
compatibility or silently reset accepted state. Keep grammar-only and executable
capabilities explicit. Exit with neutral fixtures for stale heads, wrong scopes,
name reuse, incompatible definitions and altered-content token reuse.

#### R1 — Durable directory, ancestry and recovery

Extend `DirectCatalogRecords`, `DirectCatalogRoots`, paged `TreeStore` directories
and `HistoricalCatalog` through the existing catalog owner. Persist non-reused
branch/object allocations, names, generations, parent edges and exact head roots.
Replace the runtime role of fixed `BranchRegistry`/`MergeTokenJournal` arrays;
small independent models may remain test-only. Retained manifest contents must
outlive scratch buffers and may not retain function-local row slices.

Use bounded operation transitions for admission, preparation, publication and
cleanup, driven by the service's existing event-driven recovery. Publish head
and recoverable outcome through the same accepted decision. List branches and
walk ancestry with exact cursors and current authorization. Detect missing or
corrupt parents and multiple merge bases explicitly. Exit with disk reopen,
allocation interruption, duplicate-name races, branch-name reuse, and branch/cut/
receipt cardinalities beyond resident caches and old helper capacities.

#### R2 — Exact cut preparation and branch creation

Reuse Table snapshot acquisition, accepted archives and transaction cut guards.
Capture the catalog interpretation and all participating roots at the declared
common decision. Persist `.tseg`/`.tdel`/metadata dependencies and exact retained
WAL/archive tails before branch visibility. Transfer durable pin ownership from
creation work to the published branch atomically, with recoverable abandonment;
TTL expiry of a preparation cannot delete a published branch's dependencies.

Full-data creation shares eligible immutable objects and allocates branch-local
write ownership. Schema-only creation records separate schema/data inclusion,
empty roots and inactive computations without treating omitted data as deletes.
Do not claim no-data-copy creation by first copying the whole database during
unreported preparation. Exit through real typed callers with before-flush and
concurrent-write tests, a bounded independent materialized-copy oracle, and kills
before/after pin acquisition, partition initialization and head publication.

#### R3 — Write isolation, transactions and retained reachability

Route branch-selected DDL, point/bulk DML, prepared statements and transaction
commits through isolated roots and partition identities. Extend the M5 visibility
protocol so source definitions, candidate roots and head movement agree; test
concurrent ordinary writes against merge/restore rather than CAS in isolation.
Preserve current policy checks and one selected atomic domain.

Extend `TableStorageWalk`, `DirectStorageGraph`, catalog retention and local
maintenance to enumerate every branch and preparation root with bounded work.
Keep tail/archive ownership valid through flush, checkpoint and physical WAL
trim. Parent deletion does not sever child ancestry or data; branch deletion
retires live selection while existing reads/operations retain their exact bases.
Bound ancestry read amplification through persistent root structure/checkpointing,
not ever-growing recursive overlays in memory.

Derive compaction eligibility from durable reachability and actual branch-local
visibility. Treat reference counts as safe only if their update/recovery protocol
is proven; a complete fenced mark remains the deletion authority. Benchmark
branch-local and shared rewrites before selecting cost thresholds; retire the
old plan's unmeasured fixed dead-row formula. Exit with parent/child isolation,
retained-reader and prepared-candidate races against GC, trim and compaction,
including crash/restart during each maintenance step.

#### R4 — Streaming data/schema diff and candidate inspection

Adapt `BranchDiff` to retained-source adapters and bounded Fuze batches; carry
schema/column lineage, composite keys, all five cell states, interpretation and
byte ownership. Stream divergent keys and schema/dependency edges with declared
spill budgets. Compare against an independent full logical diff for additions,
deletes, renames, changed defaults, type/collation conversions, key changes and
physical compaction. Unchanged bytes under changed interpretation are not an
unchanged logical value. Keep metadata traversal and payload skip costs separate.

`DIFF_SCHEMA` covers constraints, indexes, views, graph/foreign mappings and exact
dependencies, distinguishing rename from replacement. Two-way and three-way
results include frozen bases, conflict identities and terminal coverage. A limited
preview is not a complete merge assessment. Recheck current rights after buffering,
including empty pages and completion; early close/failure releases temporary holds.
Exit with oracle equivalence, incomplete-result and revocation tests, and scratch
reset/retained-output lifetime tests over multi-batch results.

#### R5 — Atomic three-way merge and exact retry

Freeze and retain base/source/target; derive candidate membership from those
manifests, not an unverified caller list of changed tables. Retain unchanged
objects and dependency closure. Stage schema changes and row mutations privately,
record resumable validation progress and expose attributed conflicts/resolutions.
Require explicit resolution; initially use fail-on-conflict. Any later
source-/target-wins policy must remain scoped, recorded and constraint-checked.

Validate primary/composite keys, supported secondary uniqueness, row `CHECK`s,
foreign keys and graph dependencies against the complete candidate. Include
unchanged referenced tables and disjoint edits that jointly violate constraints.
For schema-only promotion, execute or stage the qualified conversion and validate
current target rows; never bypass checks because the source contains no rows.
Unavailable validation coverage refuses publication rather than accepting a
partial check. Index availability may optimize validation but cannot change truth.

At the publication boundary recheck current policy, expected target generation/
head, every required dependency guard and staged-root durability; publish one
common decision and retain both parents. Recover that original decision after
lost replies without recomputing against moved heads. Exit with stale-head and
policy races, forged/incomplete candidates, missing referenced objects, unique/FK
write skew, cancellation races, rejected-candidate cleanup and disk-reopen token
recovery. Verify unrelated target objects and metadata survive publication.

#### R6 — Multi-model and derived-state integration

Implement per-kind adapters through the direct owners. KV requires M6's qualified
mutation/transaction participant; do not use a raw native resource clone as a
shortcut. Documents require M7's public cutover: preserve causal history,
tombstones and persisted fresh replica epochs, use the selected versioned/CRDT
merge rules, and verify permutation/convergence and incompatible-history refusal.
M16 profiles additionally retain container/part/tree identity and raw byte spans.

Consume M17's exact spatial semantics and topology checks; zone maps are only
conservative pruning, and bounding-box overlap alone is not proof of a geometry
or assembly clash. A viewport-limited preview cannot authorize an unrestricted
merge. Consume M18 graph descriptors and validate endpoints across the full
candidate. Foreign data needs frozen content/decoder commitments or explicit
refusal. Integrate M11 index generations and M12 computations using exact source
coverage and inactive/rebuild states. Exit each profile through its real storage,
caller and constraint oracle; helper spatial booleans and Document labels cannot
close these gates.

#### R7 — Forward restore and execution discontinuities

Resolve and retain the requested historical application-data cut under current
rights, then stage a new successor of the current branch head with restore
provenance. Preserve the prior head/history subject to explicit retention; never
rewind native policy, operation tokens, principal sequences or retired identities.
Use R5's decision/recovery infrastructure for restore too, including stale-target
refusal, exact retry, quota failure and unknown outcomes.

Persist a disposition plan before publication for active transactions, captured
jobs, maintained results, consumer work, subscriptions and external intents.
Old read-only cuts may finish if still retained and authorized; pre-restore writers
must validate against the changed head. Preserve original accepted jobs and their
source attribution; explicitly suspend/recompute dependencies through M12 owners.
Recompute readiness requires completed new evidence, not an immediate `active`
flag. Keep pending/unknown external outcomes in their existing reconciliation
history; restoring data does not cancel an external action or redispatch it.

Fence executable consumers before the restored head is usable; resume through
recorded owner actions, not a best-effort notification after publication. Extend
native reactive and browser contracts separately with branch/generation
attribution and an explicit discontinuity/reset. Never splice a restored snapshot
into an earlier result stream. Exit with actual running consumer/connector
schedules demonstrating zero historical dispatch, durable suspension/recovery,
current-policy revocation and no lost original operation after restart.

#### R8 — Native operations, SQL and existing consumers

Add typed catalog operations/client recovery and node dispatch, then lower the
agreed branch commands, selection and `DIFF` functions through the existing Fuze
SQL compiler and `transit-sql/Statement`/`DatabaseRuntime`. Keep reference grammar,
parser, binder, capability reporting and executable profile synchronized; branch
merge and SQL relational `MERGE INTO` are distinct operations.

Use [transit-sql-client](../../packages/zig/transit-sql-client/README.md) command
completion and `ResultSet` lifecycles. Do not invent console-only jobs, polling
state machines or row protocols. Preserve exact attribution in saved operations,
prepared reads, command receipts, empty/multi-batch diffs and bounded display.
Inspection through Board remains read-only over public clients; any publication
uses its separately authorized application surface. M29 owns the broader UI.

Migrate affected Zig/ABI/generated/SDK and service consumers with the cutover;
M20 owns additional coverage, not repair of broken existing callers. Exit with
installed native and SQL create/write/diff/merge/restore journeys, uncertain
operation recovery after session replacement, revoked disclosure, early close,
unsupported-profile refusal and runtime validation at TypeScript boundaries.

#### R9 — Remote transfer, mirroring and local migration testing

First specify remote identity/trust, current definition negotiation, credential
references, destination ownership, retention holds, resumption and quotas. Separate
borrowed online access from explicitly authorized independent export: downloaded
bytes cannot be made revocable retroactively. Same-realm branching alone grants
no right to copy data into another installation. Refuse unsupported cross-realm
or egress profiles until their contract exists.

Implement transfer of verified missing content and manifest ancestry with bounded
work, durable receive staging and atomic tracking-ref advancement. Prove ancestry
by commitments, not numeric version subtraction. Verify declared bytes, complete
dependency closure and compatibility before exposure; missing archives, definitions,
`.tdel`/`.tack`, raw parts or foreign artifacts are incomplete transfer. Eager
completion means the promised closure is available offline. Lazy completion
records remote availability/retention and authenticates metadata before pruning;
whole-object SHA-256 cannot authenticate an isolated page unless the format adds
verified chunk commitments. Fetch and validate a whole bounded object if necessary.

At every egress boundary apply actual current authorization, RLS/masking where
qualified, and metadata protection. Raw shared segments cannot bypass filtered
views; filtered derivatives get distinct content/provenance and cannot impersonate
an upstream branch root. Reject promotion of a partial/masked view as a complete
unfiltered merge candidate. Apply current checks to repeated/lazy requests too.
M26 policy helpers or caller flags alone are insufficient enforcement.

A mirror follows explicit remote heads with bounded progress, gap/error reporting
and recoverable subscriptions/notifications where available; reconnection cannot
silently replace a pinned local basis. Local testing uses fresh execution bindings
and a connector fence at the actual dispatch boundary. Network-free replay over
M16 captured exchanges must fail on missing evidence rather than fall through to
live calls. Lazy storage hydration is separately authorized network I/O; fully
offline testing requires eager dependency hydration.

Transfer immutable candidate content, schema migration intent, expected upstream
base/target and provenance for M28. Transfer success is not approval, merge or
activation. M19 qualifies transfer and conditional native publication; M28 adds
`PROPOSE`, reviewer identity and approval journeys. Exit with two real instances,
interrupted/resumed transfer, corruption/missing-object cases, revocation while
streaming/hydrating, filtered-egress leakage checks, and connector attempts
observably blocked during local migration tests.

#### R10 — Qualification, performance and public promotion

The acceptance matrix below is planned evidence, not a report of executed tests.
Extend existing domain runners and register any new executable in the
[test inventory](../../tests/runner/suite.json); do not add success-reporting
placeholders. Keep component algebra checks, real disk/service schedules,
formal correspondence and deployment evidence distinct.

| Gate | Required executable evidence |
| --- | --- |
| G1 — Identity and current policy (R0–R1/R8) | Wrong realm/branch/definition, name reuse, revoked reads/receipts, empty-terminal disclosure, all merge-disabled and protected-head bypass paths reject. |
| G2 — Exact creation (R2) | Full copy oracle agrees before/after flush and concurrent commits; partial pin acquisition cannot publish; schema-only records omission explicitly; no grants/PIDs/active work copied. |
| G3 — Isolation and visibility (R3/R5) | Parent/child point/bulk writes and transactions stay isolated; catalog/schema/data readers see one old or new complete cut through crashes and publication races. |
| G4 — Reachability and cleanup (R2–R3) | Concurrent branch drop, candidate abandonment, read release, compaction, GC and tail trim preserve every retained dependency; interrupted cleanup resumes with bounded work. |
| G5 — Diff and merge algebra (R4–R6) | Independent full logical oracle agrees for compaction, divergent deletions/tails, schema/collation changes, composite/keyless identity policy, five-state conflicts and ambiguous ancestry refusal. |
| G6 — Candidate validity (R5–R6) | Changed and unchanged objects, unique/check/FK/graph closure, schema-only migrations and explicit resolutions are all validated; stale or incomplete candidates cannot publish. |
| G7 — Decision recovery (R1/R5/R7/R8) | Lose requests/replies and kill before/after staging, decision and receipt observation; same identity resolves once; changed content rejects; cancellation cannot erase a committed outcome. |
| G8 — Data-kind safety (R6) | Direct KV semantics, versioned/CRDT Documents, fresh replicas/tombstones/provenance, qualified spatial/graph checks and derived-index coverage survive branch/merge/reopen. |
| G9 — Restore and effects (R7) | Monotonic successor preserves prior history/current authority; actual jobs, consumers and both subscription families obey disposition; zero historical external dispatch and explicit unknown outcomes. |
| G10 — Remote lifecycle (R9) | Two-instance eager/lazy transfer and mirror resume, exact content/ancestry, retained dependencies, actual filtering/masking, offline availability and proposal-transfer boundaries. |
| G11 — Growth and resources (all) | Data exceeds RAM/cache; branch, manifest, receipt and conflict counts exceed old helper capacities. Bounded resident bytes, allocations, ancestry work, spill/IO and control fairness hold without retention opt-in. |
| G12 — Caller/result lifecycle (R8) | Installed native/SQL results preserve schema/basis/completion over empty/multi-batch reads, close, denial, missing terminal and uncertain writes. Existing affected adapters remain compatible with the new definition. |

Use [M21 T6](21-formal-semantics-and-correspondence.md#t6-branch-isolation-logical-merge-and-reviewed-publication)
for local publication/retention races and
[A4](21-formal-semantics-and-correspondence.md#a4-logical-merge-and-safe-segment-skipping)
for logical merge/skip equivalence. Add negative controls and concrete Zig trace
replay where claimed, with explicit bounded-model assumptions. Reviewed approval
and delegation extensions stay with M28/M26. Do not claim that finite models or
algebraic proofs establish physical durability, throughput or arbitrary geometry.

Record an M13 scorecard with separately measured snapshot/pin preparation,
head-directory publication, full caller completion, metadata/row diff work,
constraint-validation work, cold/warm branch reads and ancestry depth, shared vs.
branch-owned bytes, compaction/write amplification, index/recompute cost and remote
bytes/hydration. Vary logical delta size independently of physical rewrites and
branch divergence. Include control traffic under load, quotas and failure/recovery;
report hardware, versions, workload, cache budgets and regressions. No fixed
branch count alone proves out-of-core behavior.

Use the pinned `nix develop` environment. During implementation select owning
package checks, `just check contracts`, `just check::native`,
`just test::catalog` and `just test::direct-table-service` as affected; extend the
real service suites for branch scenarios. `just check fast` includes the existing
fixture checker but cannot close G1–G12. Before pushing implementation, run affected
`just ci clean --lane NAME` lanes against committed HEAD: core, storage-query,
interfaces and affected SDK/installation/browser/formal lanes according to the
[task inventory](../../tasks/README.md). Record executed commands and omissions;
selected passes are not complete qualification.

Promote supported semantics and exact limits into the owning data/state/Table/
Document, storage/retention/security, SQL/history, caller and reactive references,
component guides, contracts and `state-model`/storage/query internals. Record raw
source-attributed outcomes in [qualification history](../history/qualification/README.md).
Update milestone and index together only when all required gates close; unavailable
dependent profiles remain named outstanding work. This planning-only change
requires repository link/fence and whitespace checks; runtime evidence stays open.

### First implementation changes

1. Land R0's identity/atomic-domain/disposition decisions and executable neutral
   fixtures, with an inventory of every affected persisted/signed consumer.
2. Implement R1/R2 as one vertical local Table slice: create from an unflushed cut,
   inspect through a typed caller, restart, and compare the frozen branch to an
   independent copy while the parent advances. Include durable pin cleanup.
3. Complete R3 isolation and GC races before enabling writable branches generally;
   then add R4 diff and R5 merge. Integrate R6 profiles as their owners qualify,
   and R7 restore with real execution fences before exposing it in R8.
4. Start R9 protocol/ownership design once exact cut commitments are settled;
   qualify transfer only after local lifetime/recovery gates pass. Close R10 on
   the resulting common revision, without treating M28's future approvals as an
   existing authorization mechanism.

## Local Table branch increment

The next R1/R2 slice starts from `b60f12154`. Its reviewable outcome is a named,
immutable branch of one explicitly selected Table, reached through typed direct
callers. It retains the original definition and data frontier, including unflushed
WAL rows, and recovers the original outcome while the parent advances.

This slice uses the existing `DirectCatalog` client-token owner for admission,
name reservations, nonreused branch IDs and publication. One accepted catalog
successor records both the branch head and terminal operation outcome. A durable
Table pin belongs to that operation before publication and to its published
branch afterward; ordinary release cannot take it away. Cancellation records
abandonment before releasing the original pin and freeing the name.

A single selected Table supplies a coherent definition/data cut through its
existing acceptance owner. It is an explicitly scoped projection, not an atomic
snapshot of the whole main catalog or a fabricated main-branch ancestry chain.
The installed profile remains read-only. Full-data and schema-only results retain
source attribution; schema-only exposes no rows and initially retains the same
source pin. Writable roots, whole-catalog cuts, branch fork history and published
branch deletion remain R2/R3 work.

Required evidence includes typed create/read/recovery, disk reopen after lost
pin and publication replies, parent advancement, independent copied rows,
name conflicts/reuse, current-policy denial including empty output, protected
pin ownership, recoverable cancellation and collector reachability. The stored
catalog directories require a coordinated current-v1 definition cutover and
regenerated contracts, signing fixtures and dependent consumers. This scope
does not close the remaining milestone gates.

## Foundation increment — 2026-10-31

The first implementation increment adds these owners without enabling branch
operations in the installed service:

- [`Branch`](../../packages/zig/transit-protocol/src/Branch.zig) and the
  [neutral contract](../../contracts/BRANCH_V1.md): full-width branch identities,
  content-bound manifests, branch-local ancestry, frozen source/target attempts,
  exact retries, complete candidate-validation bindings and forward decisions.
  The reflected lifecycle schema and independently authored fixtures include
  these types. Existing execution and persisted formats are unchanged; their
  incompatible runtime extension still requires R0's coordinated cutover.
- [`BranchSnapshot`](../../packages/zig/transit-storage/src/BranchSnapshot.zig):
  immutable canonical manifests and paged Table source directories, exact-root
  pagination, explicit object/index-work bounds, original Table pin handles and
  stored interpretation/frontier verification. The
  [owner tests](../../packages/zig/transit-storage/src/branch_snapshot_test.zig)
  cover 137 entries with a one-page cache, old-root disk reopen, quota/work
  refusal, missing artifacts and a real unflushed Table pin that excludes a later
  accepted write. Staging supplies neither live retention nor catalog publication.
- [`BranchAncestry`](../../packages/zig/transit-storage/src/BranchAncestry.zig):
  bounded manifest visits with paged frontier/visited sets and a complete result
  distinguishing a unique maximal common ancestor, unrelated histories and
  ambiguous criss-cross bases. Restore-source provenance is not a merge edge.
  [Tests](../../packages/zig/transit-storage/src/branch_ancestry_test.zig) cover
  disk history deeper than the old 256-cut array, missing/contradictory parents,
  budget refusal and an independent materialized transitive-closure oracle.
- The existing bounded `BranchMergeRestore` model now keeps published rows in
  explicit caller-owned storage, binds retries to all request inputs and checks
  receipt capacity before advancing its head. Schema-only changes requiring
  conversion refuse rather than copying incompatible cell positions. The
  `BranchLifecycle` model no longer fabricates latency or physical-byte metrics.
  These repairs do not turn either model into a durable catalog owner.

R0–R2 remain **partial**, and no end-to-end completion gate is closed by this
increment. In particular, R1 still needs branch directories and recoverable
decisions in `DirectCatalog`; R2/R3 need a coherent catalog/data decision and
accepted pin transfer before ordinary branch writes can be enabled. Current
Table acceptance is independent of catalog-head movement. Connecting private
manifests to head pointers alone would misrepresent that visibility boundary.
R4–R9 still require streaming logical diffs, whole-candidate publication,
multi-model integration, actual execution fencing, caller APIs and remote I/O.
The new private artifacts are not storage-collector roots. Their authorization,
retention and cleanup remain caller responsibilities until owner integration.

## Implementation plan — 2026-10-30

The [original plan at the audited main revision](https://github.com/spoke-sh/transit/blob/0e2fba44727ca858bd1e8e4a775b62fbcf1a665d/docs/roadmap/19-branches-merges-and-restore.md#implementation-plan--2026-10-30)
remains historical planning evidence. Its `P0`–`P8` labels describe the inventory
below. The October 31 plan supersedes its runtime assumptions,
speculative file paths, unmeasured complexity/compaction claims and
claimed Lean proof locations. No previously recorded runtime qualification is
removed or promoted by this revision.

### Delivered implementation evidence — 2026-10-30

Retained component inventory from the earlier plan. These sources and tests exist;
this table does not establish installed branch operations, durable publication,
real remote policy enforcement or completed milestone gates. Tests were not rerun
for this plan. The Python check validates fixtures and source symbols, as described
in the source audit.

| Earlier work package | Delivered component sources | Existing checks and limits |
| --- | --- | --- |
| P1/P2 | [`BranchLifecycle.zig`](../../packages/zig/transit-catalog/src/BranchLifecycle.zig): creation/head/ancestry model, supplied tail materialization, reachability and compaction helpers | [`branch_lifecycle_test.zig`](../../packages/zig/transit-catalog/src/branch_lifecycle_test.zig); bounded in-memory model, not persistent branch ownership or physical GC qualification |
| P3/P5 | [`BranchDiff.zig`](../../packages/zig/transit-fuze/src/BranchDiff.zig): finite segment/row/schema diff and spatial conflict helpers | [`branch_diff_test.zig`](../../packages/zig/transit-fuze/src/branch_diff_test.zig); does not establish installed SQL or M17 spatial execution |
| P4–P7 | [`BranchMergeRestore.zig`](../../packages/zig/transit-catalog/src/BranchMergeRestore.zig): candidate validation, registry merge/restore, token journal and remote helper results | [`branch_merge_restore_test.zig`](../../packages/zig/transit-catalog/src/branch_merge_restore_test.zig), [`fixtures`](../../contracts/catalog/branch-merge-restore-fixtures.json), [`fixture checker`](../../tests/catalog/tables/branch_merge_restore.py); no durable service/transfer proof follows from these helpers |
