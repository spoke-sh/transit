# 18. Branches, merges and restore

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** Planned

Add isolated application-state branching, three-way merging and point-in-time
restore built directly on the [immutable `.tseg` segment and Manifest architecture](02-storage-and-query-performance.md)
and [historical catalog binding](10-standards-and-catalogs.md). The
[state model](../handbook/internals/state-model.md) owns the authority/lifetime
model. Branching is the underlying versioning primitive within a realm. Branches
never copy live process identities, grants or effect rights.

Restore here means publishing earlier application data as a new forward successor
under current authority. [Operations](23-operations-and-recovery.md) separately
owns backup capture, installation disaster recovery and runtime upgrades; a
branch snapshot alone is not sufficient recovery material for an installation.

Make branches understandable as separately advancing histories of declared
application data and its catalog interpretation under the realm's current policy.
Branch creation is not inherently export, new ownership or a new authority
boundary. Define branch visibility, permissions and any inheritance explicitly;
creation does not freeze source privileges. A higher-level project/application
fork relationship is outside this milestone. Because committed table state is
represented by immutable **Manifests (`manifest/v{N}`)** referencing immutable
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

Use [#125](https://github.com/spoke-sh/transit/issues/125) for catalog/snapshot
identity and [#127](https://github.com/spoke-sh/transit/issues/127) for durable
WAL/object pins and retention. A new branch includes accepted unflushed rows; pointing
only at the latest flushed Table manifest is insufficient. Select a checkpoint
or pinned-tail representation before implementing branch publication. Keep
authority/process evidence separate from branchable application state.

1. **Publish full-data and schema-only branches from exact retained versions:**
   use bounded independent copies as the correctness oracle while implementing
   $O(1)$ branch-head publication (`refs/heads/<branch> -> manifest/v{N}`) and a
   dedicated branch `TransitLog` partition for subsequent branch deltas. Assign
   branch identity and branch-scoped catalog bindings within the realm; evaluate
   current branch-creation and data access rights. Define conditional head publication
   (`If-None-Match` CAS) and source retention/expiry protection so garbage
   collection preserves every `.tseg`/`.tdel` object reachable from any active
   branch or retained snapshot, including its required WAL/history references.
2. **Isolate branch writes over shared `.tseg` segments:** writes on a branch
   append to the branch's `TransitLog` partition and flush new `.tseg` segments
   and branch-local `.tdel` deletion vectors without mutating parent segments.
   Parent/child deletion and restart must preserve every reachable byte.
3. **Implement segment-aware two-way/three-way `DIFF` (`DIFF` and `DIFF_SCHEMA`) and reviewed KV/Table merges:**
   given a two-way pair (**`from` Manifest**, **`to` Manifest**) or a three-way
   common ancestor (**`base` Manifest**, **`source` Manifest** and **`target`
   Manifest**), skip all `.tseg` segments and `.tdel` bitmaps shared identically
   in $O(1)$ ([A4: `BranchMergeAlgebra.lean`](20-formal-semantics-and-correspondence.md#a4-logical-merge-and-safe-segment-skipping))
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
4. **Extend diff and merge to compatible Documents ([Milestone 7](07-document-storage-and-station-decoupling.md) and [Milestone 16](16-document-profiles-and-gateway-exchange-lifecycle.md)) and qualified graph mappings:**
   support both `versioned` structural three-way diff/merge and `causal_crdt`
   replica state-vector convergence, preserving causal/tombstone semantics,
   fresh replica identities and valid graph endpoints; incompatible histories
   refuse and derived views rebuild or verify against the merged manifest.
5. **Restore as a new forward Manifest successor:** publish a restored snapshot
   as a new monotonic manifest version (`manifest/v{N+1}`) rather than truncating
   history. Define pending input, job and subscription disposition, explicit
   activation and external-outcome reconciliation.
6. **Support Git-like remote $\leftrightarrow$ local incremental mirroring, lazy `.tseg` fetch and local migration testing ("Git remotes for data"):**
   because committed state forms a content-addressed Merkle DAG (`manifest/v{N}`
   commits $\to$ `DefinitionId` catalog trees $\to$ immutable SHA-256 `.tseg`
   blobs and `.tdel`/`.tack` bitmaps plus `TWAL1` delta tails), allow a local or
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
     [Milestone 27 versioned proposal](27-reviewed-data-collaboration.md) for
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
the native data/policy primitives; [enterprise identity](25-control-and-policy-plane.md)
binds external subjects and delegated actors, and
[reviewed collaboration](27-reviewed-data-collaboration.md) adds published
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
