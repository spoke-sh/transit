# Board data exploration design reviews

[Design items](../README.md)

This design item reimagines Board around Transit's data-first architecture:
data, derived computations and governing policies are the primary user-facing
declarations, while write-ahead change streams (`TransitLog`), durable processes
(`Station`) and connectors (`Sources` and `Sinks`) act as the activation
mechanisms orbiting that data. It introduces a first-class data exploration
surface combining auto-generated Entity Relationship Diagrams (ERDs), zero-SQL
dataset and 5-state column profiling, multi-cell SQL workbooks powered by
`transit console`'s verified interaction model, data-gravity lineage, and
branch/DDL impact previews.

Earlier items remain intact with their recorded outcomes:
[board-atlas](../board-atlas/README.md) owns the process/resource relief studies,
[board-console](../board-console/README.md) owns the Workspace/Operations shell
and single-worksheet Explore baseline, and
[board-grammar](../board-grammar/README.md) owns the monochrome reactive
declaration profile. [Inspect with Board](../../handbook/guides/inspect-board.md)
and the [data model](../../handbook/reference/data-model.md) own current
implemented behavior and public contracts.

**Current review:** [D1 — Data gravity: entity relationships, column exploration and interactive workbooks](D1.md).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | Entity-relationship canvas, zero-SQL 5-state dataset/column explorer, `transit console`-powered SQL workbooks, data-gravity activation lineage and branch/`previewDdl` comparison | In review | Review the four-pillar data-first architecture and six high-fidelity visual studies |

Review status tracks the design conversation. The D1 studies are high-fidelity
styled concepts in the spirit of DuckDB Local UI, MotherDuck Column Explorer and
Databricks Unity Catalog Explorer; they do not establish implemented browser
routes, multi-table arbitrary joins, or measured latency. Delivery scope and
qualification belong in the [roadmap](../../roadmap/README.md).

Follow the shared [review workflow](../README.md#maintaining-the-sequence) and
[template](../TEMPLATE.md) when adding subsequent reviews; the next review in
this item is `D2.md`.

## Supporting material

- [D1 visual studies](D1.md#visual-studies) and [generated PNG assets](images):
  [Figure 1 — Unified Data Explorer & ERD](images/d1-01-erd-explorer.png),
  [Figure 2 — Multi-model ERD & join synthesis](images/d1-02-erd-join-synthesis.png),
  [Figure 3 — Dataset inspector & 5-state Column Explorer](images/d1-03-dataset-column-explorer.png),
  [Figure 4 — Console-powered SQL workbook & assistance](images/d1-04-console-workbook-assistance.png),
  [Figure 5 — Data gravity & activation lineage](images/d1-05-data-gravity-activation.png),
  [Figure 6 — Branch comparison & `previewDdl` impact](images/d1-06-branch-ddl-preview.png).
- [D1 generation prompts and visual system notes](d1-prompts.json).
- [D1 synthetic catalog, 5-state data, assistance and lineage fixture](d1-fixture.json).
- [Data model](../../handbook/reference/data-model.md),
  [collaborative decisions](../../handbook/reference/collaborative-decisions.md),
  [system model](../../handbook/internals/system-model.md),
  [query assistance contract](../../../contracts/QUERY_ASSISTANCE_V1.md) and
  [console guide](../../../apps/transit-cli/docs/console.md).
