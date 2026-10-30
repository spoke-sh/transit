# 12. Managed computations and WAL-activated dataflows

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** Planned

Let an application declare a derived result, apply it, and inspect the definition,
source basis, completed revision and pending or blocked work while Transit owns
the qualified scheduling, WAL-driven delta activation and recovery. Extend the
[shared lifecycle](01-declarative-data-lifecycle.md),
[four-tier storage hierarchy](02-storage-and-query-performance.md),
[declarative streams, queues and durable runtime](06-streams-queues-and-durable-runtime.md),
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

Consume the durable catalog/snapshot contract in
[#125](https://github.com/spoke-sh/transit/issues/125) and logical feed/retention
contract in [#127](https://github.com/spoke-sh/transit/issues/127). Storage-level
subscriptions and history preservation belong to milestone 2; this milestone
owns service scheduling, consumer-specific activation and observable freshness.
Connections/sources/sinks remain separate declarations whose publication does
not authorize external work.
Consume [statement results](04-statement-results-and-consumption.md) for finite
reads, explanation and command outcomes; continuous/maintained computation keeps
its own activation, progress and revision lifecycle. Consume
[transaction decisions](05-transactions-and-atomic-composition.md) for multi-object
changes: computation activation and published successors must respect complete
commits, even when participant records arrive separately. Do not publish a
half-committed transaction as a completed result.

1. **Bind computation declarations to catalog and storage watermarks:** define a
   computation declaration's bound inputs (`CatalogId`, `DefinitionId`), lifetime,
   output sink/table, policy references (`policy_epoch`), budget and desired
   activation revision. Publish/alter definitions separately from authorizing
   work. Bind accepted work to its exact definition; a rename or newer definition
   cannot relabel it.
2. **Drive activation from `TransitLog` delta streams and manifest watermarks:**
   implement a service owner that subscribes to source partition `TransitLog`
   tails (`+row`/`-row` change vectors and manifest commits) from the
   computation's last checkpointed source position. Select each consumer's
   contract explicitly: complete ordered changes, net relation changes, or
   finite recomputation at a new basis. A slow consumer requiring every change
   must recover from retained/archived logical history; snapshot diffs cannot
   recover intermediate `A -> B -> A` events. Use manifest reconciliation or
   recomputation only where the consumer's semantics permit it. Define the
   snapshot-to-live handoff and explicit unavailable-history outcomes; never
   silently downgrade complete capture. Record recoverable intent and progress,
   fence competing owners via epoch leases, and preserve pending work across service
   replacement. Admission pressure must not discard accepted work; reserve
   control capacity.
3. **Expose completed source vectors, result revisions, pending successor and attributable failure/blocked reasons:**
   compare progress with authorized observed input positions (`manifest/v{N}`,
   `lsn`) and define freshness at that observation. A completed result remains
   complete for its own basis while later changes are pending.
4. **Define the five-state computation lifecycle (`Published`, `Authorized`, `Active`, `Suspended`, `Retired`) and explicit DDL controls (`ACTIVATE`, `SUSPEND`, `RESUME`, `REFRESH`, `RETIRE`):**
   rather than collapsing dataflow state into an ambiguous boolean `ENABLE` / `DISABLE`
   toggle, keep definition publication, authorization (`policy_epoch` binding),
   active background scheduling, operational suspension and permanent retirement
   distinct:
   - **`ACTIVATE`:** transitions an authorized definition revision into active
     `TransitLog` delta scheduling under a fenced owner lease.
   - **`SUSPEND`:** pauses background delta consumption and external effect
     dispatch while preserving the computation's checkpointed source watermarks
     (`manifest/v{N}`, `lsn`) and continuing to serve reads from the last
     completed result revision (with its exact frozen source basis visible).
   - **`RESUME` (`WITH (on_resume = 'replay_history' | 'recompute_snapshot')`):**
     resumes scheduling according to the consumer's declared recovery profile—either
     replaying every intermediate `+row`/`-row` delta from the checkpointed
     `TransitLog` position (failing explicitly if required history was compacted
     during the suspension) or establishing a fresh snapshot-to-live handoff at
     the current manifest cut.
   - **`REFRESH` and `RETIRE`:** trigger an explicit bounded recomputation, or
     permanently close a definition revision to new activation and scheduling while
     retaining historical provenance and receipts. Preserve the last complete
     result while any successor is incomplete, and define dependency/schema
     changes, revocation, unavailable history and policy expiry without inventing
     cross-owner atomicity.
5. **Adapt the qualified lifecycle to SQL views/subscriptions and typed SDK operations:**
   expose the same typed lifecycle state machine and DDL verbs across SQL
   (`CREATE` / `ALTER MATERIALIZED VIEW` / `DATAFLOW` / `SUBSCRIPTION`), SDKs and
   Board; [SQL grammar and dialect ergonomics](34-sql-grammar-and-dialect-ergonomics.md)
   audits these forms against PostgreSQL (`ENABLE`/`DISABLE`) and Snowflake
   (`SUSPEND`/`RESUME`/`REFRESH`) dialects. Inspection and `EXPLAIN` do no work.
   Board consumes the same definitions and evidence through its explicit
   capabilities; it adds no hidden scheduler or administrative authority.

## Remaining work

Consume [index coverage and access paths](11-indexing-and-access-paths.md) without
changing source cuts or completed-revision meaning. Preserve durable ordered
operator roots, checkpoint/input progress and retained versions when adding
mutable working-state acceleration. Establish finite/maintained correctness,
spill and freshness baselines here; the
[structure/planner/runtime owner](13-data-structures-and-performance.md) then
compares optimized structures and integrated local workloads. Its later delivery
cannot defer this milestone's bounded execution or activation/recovery gates.

- **Deliver the complete analytical and relational SQL surface in Fuze:** expand
  beyond two-table equijoins to multi-way joins ($>2$ tables), non-equi/range
  joins, `SEMI` (`EXISTS`/`IN`), `ANTI` (`NOT EXISTS`) and `LATERAL` joins with
  universal dependent-join (`D-Join`) correlated subquery unnesting (Neumann &
  Kemper, BTW 2015) so arbitrary correlated subqueries lower algebraically to
  set-oriented hash or merge joins rather than $O(N \times M)$ nested loops;
  **Window Functions** (`OVER (PARTITION BY ... ORDER BY ... ROWS/RANGE/GROUPS
  BETWEEN ...)`), ranking/lag/lead/frame functions and `QUALIFY`; **Common Table
  Expressions** (`WITH` and bounded `WITH RECURSIVE` with cycle detection and
  explicit work budgets) and set operations (`UNION [ALL]`, `INTERSECT`,
  `EXCEPT`); **Rich Aggregates** (`AVG`, `MIN`, `MAX`, `STDDEV`, exact and
  approximate quantiles/`PERCENTILE_CONT`, `ARRAY_AGG`/`STRING_AGG`);
  temporal/interval arithmetic; **compile-time (`comptime`) and plan-bound
  perfect-hash lookup tables** for SQL keywords and constant `WHERE col IN (...)`
  string literal sets (paired with 16-byte SIMD vector comparisons inside the
  `Batch` arena); and **deterministic, resource-bounded scalar and
  table User-Defined Functions (UDFs)** (SQL expression macros and sandboxed
  in-engine Wasm UDFs executing directly over vectorized `Fuze` column batches
  without round-tripping through `128 KiB` `Station` actor mailboxes). Preserve
  five-state values, checked arithmetic, explicit collations, source identities,
  output types and bounded operator state (with Tier 2 NVMe spill for large sorts,
  window frames, joins and aggregations).
- **Deliver first-class bitemporal SQL (`AS OF JOIN` and application-time periods):**
  combine system-time knowledge cuts (`FOR SYSTEM_TIME AS OF`) with declarative
  application/valid-time periods (`PERIOD FOR valid_time` backed by
  [Milestone 10's](10-standards-and-catalogs.md) canonical `RANGE<TIMESTAMPTZ>`
  type) and native streaming **`AS OF JOIN`** (matching each left observation to
  the nearest prior or exact valid-time right row per entity key—and supporting
  [Milestone 17's](17-geospatial-and-spatio-temporal-computing.md) piecewise-linear
  4D `TRAJECTORY` interpolation—without $O(N^2)$ inequality joins). Ensure
  point-in-time research, backtesting and decision auditing evaluate what was
  valid in the domain *and* known to the system at the decision cut, preventing
  later backfill corrections from leaking into earlier simulated decisions.
- **Expose first-class SQL `CHANGES(...)` and `STREAM_SLICE(...)` table-valued functions for CDC egress and side-effect-free relational stream queries:**
  allow SQL, Arrow Flight and SDK callers to query committed Table logical changes
  (`+row`/`-row` or net upserts/deletes with transaction, LSN and manifest
  provenance) between two snapshot cuts or watermarks (`SELECT * FROM CHANGES(table, ...)`)
  and to project bounded historical `.tseg` ranges from declared
  [Streams](06-streams-queues-and-durable-runtime.md) into relational joins and
  bitemporal `AS OF JOIN` backtests (`SELECT * FROM STREAM_SLICE(stream, OFFSET ? TO ?)`
  or `STREAM_SLICE(stream, TIMESTAMP ? TO ?)`) without advancing consumer-group
  offsets, preserving 5-state cells and current `policy_epoch` access checks.
- Provide logical/physical explanation and output-schema inspection without
  source disclosure, mutation or external work.
- Implement general `MERGE`/upsert and prepared-plan lifetime through shared SQL
  composition. The [transaction owner](05-transactions-and-atomic-composition.md)
  owns session control, atomicity/isolation, DDL/constraint interactions and
  transaction-bound plan invalidation; those features do not all become transaction
  syntax merely because they can execute in a transaction. SQL `MERGE` is separate
  from branch merge. [Foreign relations](18-multi-model-and-foreign-relations.md)
  now owns typed `COPY`/import/export and streaming CDC ingress together with its
  actual format adapters.
- Extend the common dependency lifecycle to connections, sources and sinks,
  including conditional alteration and retirement. SQL, SDK and Board use the
  same administrative operations.
- Optimize incremental maintained computation over `TransitLog` (`+row`/`-row`
  Z-set/delta vectors) against the complete finite-recomputation oracle,
  providing the Z-set arrangement and operator foundation extended by
  [Milestone 17](17-geospatial-and-spatio-temporal-computing.md) for algebraic
  half-edge `ST_Union` and `INTERIOR`/`BOUNDARY` cell-covering spatial joins.
  Event-time windows and bitemporal views require explicit timestamps, watermarks,
  allowed-lateness bounds and retraction rules.
- Bind outputs to recorded connector effects through independently authorized
  activation. Compiling, explaining, reading and replaying never dispatch a
  dataflow.

## Formal model follow-through

Own the [T5/T8 dataflow lifecycle and DDL interaction models and A3 incremental delta proofs](21-formal-semantics-and-correspondence.md#t8-catalog-ddl-evolution-and-dataflow-lifecycle-state-machines)
as the computation and phased-DDL contracts settle. Verify that `ACTIVATE`,
`SUSPEND`, `RESUME WITH (on_resume = 'replay_history' | 'recompute_snapshot')`,
`REFRESH` and `RETIRE` preserve last-completed-revision invariants when racing
in-flight worker leases (`_lease_epoch`), upstream `ALTER TABLE` schema
evolutions (`DefinitionId v1 -> v2`), `TransitLog` (`TWAL1`) compaction and
`policy_epoch` revocations, and replay the finite state-graph edges against the
production Zig catalog and dataflow state reducers.

## Prerequisites and completion

The later [reactive context milestone](31-reactive-context-and-agent-activation.md)
uses this scheduling and completed-result evidence for business conditions,
durable application interests and MCP subscriptions/tasks. This owner supplies
computation progress; a changed source or delivered notification alone cannot
establish that an agent ran or a business action completed.

Historical operations consume [catalog contracts](10-standards-and-catalogs.md).
Branch merge and SQL `MERGE` remain distinct. Fuze owns relational and incremental
vector computation; Station and application owners coordinate stateful workflows
and external effects above a generic kernel.

Require independent finite/maintained equivalence at completed source bases,
current grants, lost responses, interrupted publication, retained-history and
snapshot-to-tail handoff, bounded NVMe spill and larger-than-RAM workloads. Test
`A -> B -> A`, insert/delete within one flush, schema changes and compaction
without a logical mutation for every admitted consumer profile. Include
multi-object transactions with delayed participant records and aborted work;
completed maintenance must consume the selected committed cut without omissions
or partial publication. Qualify
actual callers for each exposed slice.

The acceptance journey declares a derived relation, observes its first complete
result, ingests streaming source changes over `TransitLog`, evolves the schema,
inspects catch-up or blocking, replaces the service and recovers the same
accepted work. Exercise pause, revocation and retirement without reporting a
partial successor as a complete result. Measure freshness lag and control
latency under load separately from correctness.
