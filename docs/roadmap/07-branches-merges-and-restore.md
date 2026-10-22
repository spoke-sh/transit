# 7. Branches, merges and restore

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** Planned

Add isolated application-state branching, three-way merging and point-in-time
restore built directly on the [immutable `.tseg` segment and Manifest architecture](02-storage-and-query-performance.md)
and [historical catalog binding](04-standards-and-catalogs.md). The
[state model](../handbook/internals/state-model.md) owns the authority/lifetime
model. Branches never copy live process identities, grants or effect rights.

Make branches understandable as isolated, zero-copy versions of declared
application data and its catalog interpretation. Because committed table state is
represented by immutable **Manifests (`manifest/v{N}`)** referencing immutable
**`.tseg` Data Segments** and **`.tdel` Deletion Vectors** in `TransitObjectStore`,
branch-head publication targets an $O(1)$ metadata operation over an already
durable, pinned snapshot without copying all data files. Snapshot preparation
and retained-tail ownership have separate costs and guarantees. Inspection must
show definition/data differences, dependency changes, merge conflicts and pending recomputation
through the shared lifecycle. Copying a definition must not activate its
computations or renew old policy.

## Delivery sequence

Use [#125](https://github.com/spoke-sh/transit/issues/125) for catalog/snapshot
identity and [#127](https://github.com/spoke-sh/transit/issues/127) for durable
WAL/object pins and retention. A fork includes accepted unflushed rows; pointing
only at the latest flushed Table manifest is insufficient. Select a checkpoint
or pinned-tail representation before implementing branch publication. Keep
authority/process evidence separate from branchable application state.

1. **Publish full-data and schema-only branches via immutable Manifest forks:**
   use bounded independent copies as the correctness oracle while implementing
   $O(1)$ manifest-pointer forks (`refs/heads/<branch> -> manifest/v{N}`) and a
   dedicated branch `TransitLog` partition for subsequent branch deltas. Assign
   distinct catalog identities and grants; define conditional head publication
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

## Completion evidence

Require copy/merge oracles, write/delete isolation across parent and child
branches, current export authority, GC reachability across multi-branch
manifests, stale-head OCC rejection, collation-aware key conflict detection,
lost-reply recovery and bounded cleanup. Test data, branch and conflict counts
beyond resident RAM and NVMe caches. Include forks before flush, concurrent
compaction/GC, retained-tail trim and parent/child restart. Measure head-publication
latency separately from preparing/pinning the durable snapshot, merge work against
actual logical changes and physical rewrites, and shared versus branch-owned
`.tseg` bytes.

Never revive retired processes, restore revoked rights or redispatch historical
effects. Cross-realm forks and live realm rollback require separate contracts.
