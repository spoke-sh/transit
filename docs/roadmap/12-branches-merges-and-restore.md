# 12. Branches, merges and restore

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** Planned

Add isolated application-state branching, three-way merging and point-in-time
restore built directly on the [immutable `.tseg` segment and Manifest architecture](02-storage-and-query-performance.md)
and [historical catalog binding](07-standards-and-catalogs.md). The
[state model](../handbook/internals/state-model.md) owns the authority/lifetime
model. Branching is the underlying versioning primitive within a realm. Branches
never copy live process identities, grants or effect rights.

Restore here means publishing earlier application data as a new forward successor
under current authority. [Operations](17-operations-and-recovery.md) separately
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
3. **Implement segment-aware three-way diffs and reviewed KV/Table merges:**
   given a common ancestor **`base` Manifest**, **`source` Manifest** and
   **`target` Manifest**, skip all `.tseg` segments shared identically with
   `base` and compute three-way diffs using logical change lineage, retained tail
   state, added segments and divergent deletion vectors. Use segment indexes
   and declared collations to resolve rows. Physical compaction can replace segment IDs
   without changing data; use logical lineage/change evidence to avoid inventing
   merge changes or conflicts from that rewrite. Freeze `base`/`source`/`target`,
   align schemas, validate constraints, surface row/cell conflicts explicitly, and commit the
   merged Manifest via conditional CAS (`Multi-Writer OCC`), rejecting stale
   target heads. Schema-only promotion preserves target rows unless explicitly
   migrated.
4. **Extend merge to compatible Documents and qualified graph mappings:**
   preserve causal/tombstone semantics, fresh replica identities and valid graph
   endpoints; incompatible histories refuse and derived views rebuild or verify
   against the merged manifest.
5. **Restore as a new forward Manifest successor:** publish a restored snapshot
   as a new monotonic manifest version (`manifest/v{N+1}`) rather than truncating
   history. Define pending input, job and subscription disposition, explicit
   activation and external-outcome reconciliation.

## Policy and collaboration boundary

Extend the [index lifecycle](08-indexing-and-access-paths.md) to branch-local
definitions, generations and coverage. Share compatible immutable index objects
only with their exact source cuts, WAL overlays and retention roots. Revalidate
uniqueness against the combined merge candidate, including disjoint row changes
that collide on a secondary key. Rebuild or use another qualified path where
coverage is missing; copying an index definition cannot publish readiness.
Qualify parent/child rebuild, drop, compaction and GC with retained readers.
Extend the [performance scorecard](10-data-structures-and-performance.md) with
snapshot preparation/pinning, head publication, merge validation and index
maintenance separately; immutable sharing alone does not make all branching
work constant-time.

Branch creation, read, edit and merge have independent permissions under current
realm policy. Support installations with all merging disabled, and protect
destination heads against equivalent direct writes. This milestone establishes
the native data/policy primitives; [enterprise identity](19-control-and-policy-plane.md)
binds external subjects and delegated actors, and
[reviewed collaboration](21-reviewed-data-collaboration.md) adds published
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
