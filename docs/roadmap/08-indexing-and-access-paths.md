# 8. Indexing model, access paths and online maintenance

[Roadmap](README.md) · **Status:** Planned

Let an application declare an access path over its data, inspect build progress
and coverage, and use it through SQL and typed queries without changing result
truth, transaction guarantees or current permissions. Deliver bounded primary
and secondary access paths, recoverable online maintenance and shared inspection.
An index definition, a populated generation and eligibility for a particular
query are separate observations.

## Prerequisites and existing obligations

Consume [data identities](01-declarative-data-lifecycle.md),
[local storage](02-storage-and-query-performance.md),
[installed lifecycles](03-live-storage-and-sql-cutover.md),
[statement outcomes](04-statement-results-and-consumption.md),
[transactions](05-transactions-and-atomic-composition.md),
[shared clients](06-client-foundation-and-language-apis.md) and
[collations/historical catalogs](07-standards-and-catalogs.md).
Resolve index identity, key semantics, constraint dependencies and coverage with
those owners before their dependent formats; this delivery position does not
postpone foundational contract work.

The [neutral index contract](../../contracts/INDEX_LIFECYCLE_V1.md) supplies
immutable source/key/constraint bindings, build identities, progress and exact
coverage publication descriptors. Its deterministic validation is foundation
work; catalog operations, secondary structures, online maintenance and planner
eligibility in this milestone remain unimplemented.

The storage milestone already owns bounded memtables, manifests, primary-key
indexes, pruning, range reads and local recovery. The transaction milestone owns
every constraint and isolation guarantee it advertises. Neither can defer an
unmet acceptance criterion here. This milestone adds the shared indexing model,
secondary access paths, online lifecycle and basic planner integration. Later
[performance work](10-data-structures-and-performance.md) compares and optimizes
qualified implementations; a safe usable baseline is required here.

At source `8309a0dc`, the storage component's
[memtable lookup](../../packages/zig/transit-storage/src/TableMemtable.zig)
scans recent entries backwards and reads whole candidate segments; the
[segment footer](../../packages/zig/transit-fuze/src/TSeg.zig) contains a sorted
primary-key array searched by binary search despite its B-tree comments.
The [immutable ordered index](../../packages/zig/transit-station/docs/indexes.md)
has a different publication and retained-root contract. These observations
identify work and comparison baselines, not measured installed performance or
interchangeable implementations.

Start from [Tables](../handbook/reference/tables.md),
[queries](../handbook/reference/queries.md),
[storage](../handbook/reference/storage.md),
[query reasoning](../handbook/internals/query-engine.md) and the
[SQL session contract](../../contracts/SQL_SESSION_V1.md).
SQL constraints define logical requirements; `CREATE INDEX` and access-method
options need an explicit Transit extension contract and capability evidence.
[PostgreSQL's compatibility statement](https://www.postgresql.org/docs/current/sql-createindex.html#SQL-CREATEINDEX-COMPATIBILITY)
does not supply a portable cross-vendor indexing grammar.

## Delivery sequence

1. **Define one catalog and access-method contract.** Bind stable index identity
   and immutable definition to source object/column identities, branch/catalog
   scope, policy, ordered keys and dependencies. Separate logical key comparison
   from physical encoding, abbreviated keys, collation version and layout
   generation. Specify ascending/descending order, NULL placement, duplicates,
   five-state values, fallibility and immutable predicate evaluation. Abbreviated
   keys and hashes require full comparison on collisions. Distinguish an ordinary
   acceleration index from a constraint-owned index: dropping or rebuilding the
   physical structure cannot silently remove a uniqueness guarantee. Define
   permitted combinations and reject unsupported ones before accepting work.
2. **Deliver bounded ordered access over hot and immutable data.** Implement
   single-column and composite primary/secondary equality and range access,
   nonunique entries and constraint-backed unique indexes in the supported local
   transaction domain. Bind entries to stable row/version identities, including
   keyless Tables, and qualify MVCC visibility and deletion handling. Evaluate
   mutable ordered structures separately from paged immutable layouts. Support
   separately published secondary-index objects where appropriate so adding an
   index need not rewrite base data. Specify manifest references and compaction
   remapping; do not freeze a `.tidx` format or BBTree node layout by name alone.
   Bound candidate-segment discovery, index pages, row fetches, batches and
   resident memory. Report overlapping-segment costs and cold/warm I/O; a fast
   per-segment index does not establish bounded table-wide lookup work.
3. **Integrate transaction maintenance and recoverable online builds.** Keep
   row changes, required index changes and constraint validation consistent with
   the owning commit decision. Preserve absent-key/range conflicts and
   read-your-writes; an index cannot choose the isolation algorithm. Build from
   an exact pinned cut including committed unflushed WAL data, retain the
   complete intervening changes, catch up and validate before conditional
   publication of query eligibility. Use storage's snapshot-to-tail and commit
   contracts directly; the later managed-dataflow scheduler is not a prerequisite.
   Record original operation identity, durable progress, quotas and build-owner
   fencing. Define crash/resume, duplicate delivery, unavailable history,
   cancellation races, failed uniqueness validation and concurrent schema changes.
   An incomplete build never establishes complete query coverage. Any asynchronous
   acceleration path must prove coverage of the requested cut or combine with
   the complete committed delta; otherwise use another qualified path. Unique
   constraint enforcement cannot lag behind accepted writes.
4. **Add covering and deterministic partial-index slices.** Define included
   payload columns separately from comparison keys and uniqueness. An index-only
   read must establish requested-version visibility and current authorization;
   a deletion bitmap alone does not prove transaction visibility. Restrict the
   initial partial-predicate language to a documented, side-effect-free subset.
   Use a sound implication check before selecting it for a query; if implication
   is unknown, choose another path. Preserve error/five-state semantics and
   validate updates that enter or leave the indexed subset. Expression-key,
   inverted/document-path, spatial and approximate-vector indexes require their
   own admitted profiles; they are not implied by these ordered-index slices.
5. **Integrate the planner and shared public operations.** Expose define, inspect,
   build/rebuild and retire/drop through owning typed operations and SQL adapters,
   using shared statement outcomes and original-operation recovery. Define DDL
   transaction interactions explicitly; no hidden commits or retry as fresh work.
   Select indexes only when key semantics, definition, source cut, coverage and
   predicate support match. Retain a correct bounded scan path and original
   predicate evaluation where required. `EXPLAIN` reports access path, bounds,
   required visibility checks and eligibility reasons without executing the
   query. Inspection reports definition, generation, coverage, progress, resource
   use and attributable failures under current rights. Recheck rights after
   buffering, including index-only results, metadata and completion evidence.
6. **Qualify retirement, historical reads and the current-v1 cutover.** Preserve
   active readers and retained generations during rebuild, drop and compaction.
   An old root is neither an authorization grant nor a retention pin. Historical
   queries bind exact definitions/collations and data cuts; a current index cannot
   omit rows visible only in older history. Specify reclamation across reader,
   build, branch and backup roots, with later deployment owners extending their
   profiles. Migrate affected formats, messages, SQL/client consumers, generated
   declarations and fixtures together under the current-v1 policy. Reject foreign
   definitions without reinterpreting accepted work or resetting data.

## Completion evidence

| Journey | Required evidence |
| --- | --- |
| Define and inspect | SQL and typed callers observe the same definition, accepted operation, build progress and terminal outcome; denial and unsupported combinations are explicit |
| Query through each admitted access path | Independent full-scan oracle at the same cut agrees on values, multiplicity, specified order, errors and completion; include composite/collated keys, duplicates, empty results and all admitted cell states |
| Change indexed data | Updates, deletes, private writes, aborts, savepoints, uniqueness races and absent-key/range conflicts preserve the selected transaction guarantee |
| Build while serving | Concurrent committed changes, WAL-only rows, interrupted backfill/catch-up and lost replies produce no omitted or double-counted rows and recover the original operation |
| Use history and evolve layout | Rename/drop/recreate, collation changes, rebuild, compaction and deletion-vector replacement preserve old readers or explicitly reject unavailable history |
| Exceed RAM and lose authority | Bounded build/scan/retirement work survives allocation/storage pressure, restart and revocation; no cached coverage or data grants access |

Measure build/catch-up time, maintenance write amplification, index size,
resident high-water memory, candidate segments, pages/bytes fetched and query
latency through installed callers. Include index-disabled controls and workloads
where a scan is cheaper. Do not require every query to use an index or define
success as winning a map microbenchmark. Record scoped results in the
[proof ledger](../../tests/README.md) and
[performance reference](../handbook/reference/performance.md).

## Later owners

- [Managed computations](09-sql-and-dataflows.md) use complete source commits
  and compatible access paths without equating an index generation to a derived
  computation's completed revision.
- [Multi-model access](11-multi-model-and-foreign-relations.md) qualifies graph
  adjacency and selected document projections against this lifecycle; specialized
  index semantics and external-source coverage need independent evidence.
- [Branches](12-branches-merges-and-restore.md) qualify sharing, divergence,
  constraint validation and GC reachability. Immutable reuse alone supplies no
  constant-time preparation, merge or historical-correctness guarantee.
- [Providers](14-storage-providers-and-concurrency.md),
  [replication](15-replication-and-failover.md),
  [operations](16-operations-and-recovery.md) and
  [clustered execution](17-clustered-execution.md) extend writer scope, copy/rebuild
  decisions, recovery readiness and distributed uniqueness explicitly.
- [Board](21-board-reimplementation.md) presents shared definitions, progress,
  coverage and plans. Inspection remains read-only; administrative actions use
  separately authorized public operations.

Publish supported indexing semantics and limits with the public Table/query/SQL
owners and exact contracts as each slice lands. The Control & Policy Plane owns
definitions and authorization; storage and Fuze own access and maintenance.
Direct ingestion and index maintenance must not require per-row Station actors.
