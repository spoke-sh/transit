# Roadmap

This roadmap contains unfinished work for Transit, ordered by dependency rather
than delivery date. Current behavior belongs in the [public reference](../README.md),
mechanisms in [Internals](../handbook/internals/README.md), and executed checks in the
[proof ledger](../../tests/README.md). A plan does not establish support.

The product goal is programmable, versioned data infrastructure: declare schemas,
datasets, computations and policies, then inspect whether Transit is fulfilling
that declaration. Data and derived computation are the primary model; durable
processes (`Station`), write-ahead streams (`TransitLog`) and connectors are the
mechanisms that **activate** data, materialize changes and coordinate external
effects. The [current data model](../handbook/reference/data-model.md) describes
the supported pieces and the gaps between them.

| Order | Milestone | Outcome |
| --- | --- | --- |
| 1 | [Storage hierarchy, `.tseg` segments and query performance](01-storage-and-query-performance.md) | Four-tier storage (`TransitLog` + `TransitObjectStore`), `.tseg` hybrid segments, Zig codecs/collations and partitioned/OCC concurrency |
| 2 | [Standards, collations and historical catalogs](02-standards-and-catalogs.md) | Capability evidence, collation-preserving snapshots and historical interpretation over shared catalog manifests |
| 3 | [Managed computations and WAL-activated dataflows](03-sql-and-dataflows.md) | `TransitLog`-driven activation, service-managed incremental maintenance and observable freshness/failure |
| 4 | [Multi-model and multi-format foreign relations](04-multi-model-and-foreign-relations.md) | Document projections, finite graphs and zero-copy/mainframe foreign tables (Parquet, Arrow, CSV/JSONL, COBOL/EBCDIC) |
| 5 | [Branches, merges and restore](05-branches-merges-and-restore.md) | $O(1)$ manifest-based application-state branches, segment-index three-way merges and restore |
| 6 | [Service and SDK coverage](06-service-and-sdk-coverage.md) | Broader types, sources and streaming interactions through shared contracts |
| 7 | [Clustered execution and storage-disaggregated placement](07-clustered-execution.md) | Fenced lease transfer, zero-copy S3/NVMe cache warming and locality-aware distributed query execution |
| 8 | [Qualification and complete benchmarks](08-qualification-and-benchmarks.md) | Reproducible full workloads, fault coverage and measured CI costs |
| 9 | [Release distribution](09-releases.md) | Versioned, verified artifacts with runnable installed onboarding |

Performance and storage architecture work is tracked in
[issue #76](https://github.com/spoke-sh/transit/issues/76).
Standards, multi-model and branching work is tracked in
[issue #31](https://github.com/spoke-sh/transit/issues/31).

## Architectural direction across the sequence

1. **Replace B-tree-over-JSON-streams with a four-tier storage hierarchy and `.tseg` segments ([Milestone 1](01-storage-and-query-performance.md)).**
   Split storage into two swappable primitives: **`TransitLog`** (the sequenced
   `TWAL1` write-ahead log and live data-activation delta bus, backed by a native
   Zig local WAL by default in `transit server`, or by Ursula, Kafka or Pulsar in
   distributed deployments) and **`TransitObjectStore`** (the immutable segment
   and manifest store, backed by a local POSIX directory in `transit server` or
   S3/GCS/R2 with a local NVMe read-through cache in cloud deployments). Store
   relational data in 64-byte-aligned **`.tseg` hybrid OLTP/OLAP segments** with
   Arrow-compatible physical column buffers, 5-state cell validity tags, embedded
   primary-key prefix B-tree indexes, zone maps, `.tdel` deletion vectors,
   composable Zig codecs (bitpacking, RLE, dictionary, FSST, plus mainframe
   `COMP-3`, `ZONED`, `COMP`, `IBM_HFP` and `EBCDIC`) and first-class Collation
   (`COLLATE`) support. Progress concurrency from a single global realm sequencer
   to **Partitioned Policy/Data Logs**, **Fenced Partition Leases**, and
   **Lock-Free Multi-Writer OCC** over conditional manifest CAS.
2. **Activate derived views, multi-format foreign sources, $O(1)$ branches and clustered compute ([Milestones 2](02-standards-and-catalogs.md)–[7](07-clustered-execution.md)).**
   Bind historical catalog snapshots to immutable manifest versions and collations;
   drive maintained SQL views, reactive watches and Station processes directly
   from `TransitLog` (`+row`/`-row`) delta streams; read Parquet, Arrow IPC,
   CSV/JSONL and mainframe fixed/variable (`FB`/`VB`) copybook datasets through
   the shared `Fuze` segment boundary; implement $O(1)$ copy-on-write branches
   and three-way merges over immutable `.tseg` manifests; and schedule distributed
   Station and `Fuze` workers over shared object storage with fenced lease handoff.

Handbook publication is implemented. Remaining live-site navigation and recovery
qualification belongs to [qualification](08-qualification-and-benchmarks.md#documentation-publication),
with completed observations in the proof ledger.

## Shared implementation gates

- Name the user-visible declaration, its owner, dependencies, permitted work and
  lifecycle evidence. A healthy process or parsed statement does not fulfill a
  data declaration. State how the user can distinguish publication, unresolved
  work, a complete result and stale or blocked progress.
- Define neutral contracts, ownership, authorization, lifetimes and bounds before
  exposing syntax. Grammar acceptance is separate from executable behavior.
- Preserve exact accepted-operation recovery, current permissions, permanent
  retirement and the distinction between cancellation and uncertainty.
- Keep retained collection size independent of resident memory. Measure provider,
  compute, transport and publication costs separately.
- Apply the [v1 hard-cutover policy](../handbook/reference/versioning.md) to incompatible
  definitions. Never reinterpret accepted work or reset data automatically.
- Run focused proofs and committed-source clean checks. Publish supported
  behavior and measured limits with their public owners as work lands.

Each delivered slice needs an end-to-end acceptance path: describe, validate,
apply, inspect, change and recover through actual public callers. Include denied
access, lost responses, dependency changes, bounded work and incomplete results.
Retain different completion semantics for interactive, captured and maintained
computation; one universal readiness flag is insufficient.

## Maintaining the sequence

Keep one numbered, descriptively named file per future milestone. Insert or
reorder work by updating this index, filenames and links together. Split work
only when it has independently reviewable outcomes and prerequisites.

When work is complete, remove it from this roadmap. Promote any current behavior
or reasoning still held only in the plan into its public owner first. Delete
obsolete delivery notes and completed checklists instead of archiving milestones.
Test evidence is owned separately from delivery history.
