# 3. Managed computations and WAL-activated dataflows

[Roadmap](README.md)

Let an application declare a derived result, apply it, and inspect the definition,
source basis, completed revision and pending or blocked work while Transit owns
the qualified scheduling, WAL-driven delta activation and recovery. Extend the
[shared lifecycle](../handbook/reference/data-model.md),
[four-tier storage hierarchy](01-storage-and-query-performance.md),
[SQL reference](../handbook/reference/sql.md) and
[grammar inventory](../handbook/reference/sql/grammar-surface.md).

Typed Tables, joins/grouping, expressions, parameters, named relational
activation, complete Table history and typed maintained revisions already exist.
Maintained owners currently require host-driven activation and wakeups and
recompute at recorded source bases. Connecting maintained computations, reactive
watches and Station actors directly to **`TransitLog` (`TWAL1`) delta streams**
with service-owned scheduling is the core advancement of this milestone;
incremental delta propagation must preserve equivalence with the finite
recomputation oracle.

## Managed computation sequence

1. **Bind computation declarations to catalog and storage watermarks:** define a
   computation declaration's bound inputs (`CatalogId`, `DefinitionId`), lifetime,
   output sink/table, policy references (`policy_epoch`), budget and desired
   activation revision. Publish/alter definitions separately from authorizing
   work. Bind accepted work to its exact definition; a rename or newer definition
   cannot relabel it.
2. **Drive activation from `TransitLog` delta streams and manifest watermarks:**
   implement a service owner that subscribes to source partition `TransitLog`
   tails (`+row`/`-row` change vectors and manifest commits) from the
   computation's last checkpointed `(manifest_version, lsn)` watermark. If a slow
   or paused consumer falls behind a trimmed `TransitLog` segment, seamlessly
   backfill from the committed Tier 3 `.tseg`/`.tdel` manifest diffs before
   resuming live WAL tailing. Record recoverable intent and progress, fence
   competing owners via epoch leases, and preserve pending work across service
   replacement. Admission pressure must not discard accepted work; reserve
   control capacity.
3. **Expose completed source vectors, result revisions, pending successor and attributable failure/blocked reasons:**
   compare progress with authorized observed input positions (`manifest/v{N}`,
   `lsn`) and define freshness at that observation. A completed result remains
   complete for its own basis while later changes are pending.
4. **Define refresh, pause/resume, cancellation, alteration, retirement and cleanup:**
   preserve the last complete result while a successor is incomplete. Define
   dependency/schema changes, revocation, unavailable history, `.tseg` backfill
   to live `TransitLog` handoff and policy expiry without inventing cross-owner
   atomicity.
5. **Adapt the qualified lifecycle to SQL views/subscriptions and typed SDK operations:**
   inspection and `EXPLAIN` do no work. Board consumes the same definitions and
   evidence through its explicit capabilities; it adds no hidden scheduler or
   administrative authority.

## Remaining work

- Extend expression/relational composition while preserving five-state values,
  checked arithmetic, explicit collations, source identities, output types and
  bounded operator state (with Tier 2 NVMe spill for large sorts, joins and
  aggregations).
- Provide logical/physical explanation and output-schema inspection without
  source disclosure, mutation or external work.
- Implement typed `COPY`/import/export (writing `.tseg`, Parquet, Arrow IPC and
  CSV/JSONL), `MERGE`/upsert (using `.tseg` primary-key B-tree indexes and `.tdel`
  deletion vectors), prepared-plan lifetime and explicit transaction sessions
  over multi-writer Manifest OCC.
- Extend the common dependency lifecycle to connections, sources and sinks,
  including conditional alteration and retirement. SQL, SDK and Board use the
  same administrative operations.
- Optimize incremental maintained computation over `TransitLog` (`+row`/`-row`
  Z-set/delta vectors) against the complete finite-recomputation oracle.
  Event-time windows require explicit timestamps, watermarks and late-data rules.
- Bind outputs to recorded connector effects through independently authorized
  activation. Compiling, explaining, reading and replaying never dispatch a
  dataflow.

## Prerequisites and completion

Historical operations consume [catalog contracts](02-standards-and-catalogs.md).
Branch merge and SQL `MERGE` remain distinct. Fuze owns relational and incremental
vector computation; Station and application owners coordinate stateful workflows
and external effects above a generic kernel.

Require independent finite/maintained equivalence at completed source bases,
current grants, lost responses, interrupted publication, WAL trim -> `.tseg`
catch-up handoff, bounded NVMe spill and larger-than-RAM workloads. Qualify
actual callers for each exposed slice.

The acceptance journey declares a derived relation, observes its first complete
result, ingests streaming source changes over `TransitLog`, evolves the schema,
inspects catch-up or blocking, replaces the service and recovers the same
accepted work. Exercise pause, revocation and retirement without reporting a
partial successor as a complete result. Measure freshness lag and control
latency under load separately from correctness.
