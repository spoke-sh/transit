# Roadmap

This roadmap contains unfinished work for Transit, ordered by dependency rather
than delivery date. Current behavior belongs in the [public reference](../README.md),
mechanisms in [Internals](../internals/README.md), and executed checks in the
[proof ledger](../../tests/README.md). A plan does not establish support.

| Order | Milestone | Outcome |
| --- | --- | --- |
| 1 | [Storage and query performance](01-storage-and-query-performance.md) | Lower end-to-end read/write cost with bounded memory |
| 2 | [Standards and historical catalogs](02-standards-and-catalogs.md) | Explicit feature capabilities and historical schema/snapshot identities |
| 3 | [SQL and declarative dataflows](03-sql-and-dataflows.md) | Selected SQL operations, dependency lifecycle and maintained-query controls |
| 4 | [Multi-model and foreign relations](04-multi-model-and-foreign-relations.md) | Document projections, finite graphs and recoverable external captures |
| 5 | [Branches, merges and restore](05-branches-merges-and-restore.md) | Isolated application-state branches and reviewed merges |
| 6 | [Service and SDK coverage](06-service-and-sdk-coverage.md) | Broader types, sources and streaming interactions through shared contracts |
| 7 | [Clustered execution](07-clustered-execution.md) | Automatic placement, fenced transfer and distributed execution |
| 8 | [Qualification and complete benchmarks](08-qualification-and-benchmarks.md) | Reproducible full workloads, fault coverage and measured CI costs |
| 9 | [Release distribution](09-releases.md) | Versioned, verified artifacts with runnable installed onboarding |

Performance work is tracked in [issue #76](https://github.com/spoke-sh/transit/issues/76).
Standards, multi-model and branching work is tracked in
[issue #31](https://github.com/spoke-sh/transit/issues/31).

## Shared implementation gates

- Define neutral contracts, ownership, authorization, lifetimes and bounds before
  exposing syntax. Grammar acceptance is separate from executable behavior.
- Preserve exact accepted-operation recovery, current permissions, permanent
  retirement and the distinction between cancellation and uncertainty.
- Keep retained collection size independent of resident memory. Measure provider,
  compute, transport and publication costs separately.
- Apply the [v1 hard-cutover policy](../reference/versioning.md) to incompatible
  definitions. Never reinterpret accepted work or reset data automatically.
- Run focused proofs and committed-source clean checks. Publish supported
  behavior and measured limits with their public owners as work lands.

## Maintaining the sequence

Keep one numbered, descriptively named file per future milestone. Insert or
reorder work by updating this index, filenames and links together. Split work
only when it has independently reviewable outcomes and prerequisites.

When work is complete, remove it from this roadmap. Promote any current behavior
or reasoning still held only in the plan into its public owner first. Delete
obsolete delivery notes and completed checklists instead of archiving milestones.
Test evidence is owned separately from delivery history.
