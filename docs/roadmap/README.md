# Roadmap

This roadmap contains unfinished work for Transit, ordered by dependency rather
than delivery date. Current behavior belongs in the [public reference](../README.md),
mechanisms in [Internals](../handbook/internals/README.md), and executed checks in the
[proof ledger](../../tests/README.md). A plan does not establish support.

| Order | Milestone | Outcome |
| --- | --- | --- |
| 1 | [Publish the handbook](01-handbook-publication.md) | Static documentation at transit.spoke.sh with repeatable deployment and rollback |
| 2 | [Storage and query performance](02-storage-and-query-performance.md) | Lower end-to-end read/write cost with bounded memory |
| 3 | [Standards and historical catalogs](03-standards-and-catalogs.md) | Explicit feature capabilities and historical schema/snapshot identities |
| 4 | [SQL and declarative dataflows](04-sql-and-dataflows.md) | Selected SQL operations, dependency lifecycle and maintained-query controls |
| 5 | [Multi-model and foreign relations](05-multi-model-and-foreign-relations.md) | Document projections, finite graphs and recoverable external captures |
| 6 | [Branches, merges and restore](06-branches-merges-and-restore.md) | Isolated application-state branches and reviewed merges |
| 7 | [Service and SDK coverage](07-service-and-sdk-coverage.md) | Broader types, sources and streaming interactions through shared contracts |
| 8 | [Clustered execution](08-clustered-execution.md) | Automatic placement, fenced transfer and distributed execution |
| 9 | [Qualification and complete benchmarks](09-qualification-and-benchmarks.md) | Reproducible full workloads, fault coverage and measured CI costs |
| 10 | [Release distribution](10-releases.md) | Versioned, verified artifacts with runnable installed onboarding |

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
- Apply the [v1 hard-cutover policy](../handbook/reference/versioning.md) to incompatible
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
