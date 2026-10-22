# Roadmap

This roadmap contains unfinished work for Transit, ordered by dependency rather
than delivery date. Current behavior belongs in the [public reference](../README.md),
mechanisms in [Internals](../handbook/internals/README.md), and executed checks in the
[proof ledger](../../tests/README.md). A plan does not establish support.

The product goal is programmable data infrastructure: describe data, computation
and policies, then inspect whether Transit is fulfilling that declaration. The
[current data model](../handbook/reference/data-model.md) describes the supported
pieces and the gaps between them. Durable execution and storage improvements
serve that lifecycle.

| Order | Milestone | Outcome |
| --- | --- | --- |
| 1 | [Declarative data lifecycle](01-declarative-data-lifecycle.md) | Shared definitions, named data objects, dependencies and inspectable operation state |
| 2 | [Storage and query performance](02-storage-and-query-performance.md) | Lower end-to-end read/write cost with bounded memory |
| 3 | [Standards and historical catalogs](03-standards-and-catalogs.md) | Capability evidence and historical interpretation extending the shared catalog model |
| 4 | [Managed computations and SQL dataflows](04-sql-and-dataflows.md) | Declarative activation, service-managed maintenance and observable freshness/failure |
| 5 | [Multi-model and foreign relations](05-multi-model-and-foreign-relations.md) | Document projections, finite graphs and recoverable external captures |
| 6 | [Branches, merges and restore](06-branches-merges-and-restore.md) | Isolated application-state branches and reviewed merges |
| 7 | [Service and SDK coverage](07-service-and-sdk-coverage.md) | Broader types, sources and streaming interactions through shared contracts |
| 8 | [Clustered execution](08-clustered-execution.md) | Automatic placement, fenced transfer and distributed execution |
| 9 | [Qualification and complete benchmarks](09-qualification-and-benchmarks.md) | Reproducible full workloads, fault coverage and measured CI costs |
| 10 | [Release distribution](10-releases.md) | Versioned, verified artifacts with runnable installed onboarding |

Performance work is tracked in [issue #76](https://github.com/spoke-sh/transit/issues/76).
Standards, multi-model and branching work is tracked in
[issue #31](https://github.com/spoke-sh/transit/issues/31).

The first milestone defines a common lifecycle over existing owners. Performance
work measures those data operations; historical catalogs preserve their meaning
over time. Managed computation adds service-owned scheduling and recovery before
broader models and placement extend the same contracts. Table lifecycle, typed
captured/maintained owners, native authorization and immutable storage are existing
foundations, not new milestones to implement again.

Handbook publication is implemented. Remaining live-site navigation and recovery
qualification belongs to [qualification](09-qualification-and-benchmarks.md#documentation-publication),
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
