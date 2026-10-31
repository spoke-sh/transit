# Board data exploration design reviews

[Design items](../README.md)

This design item reimagines Board around data, derived computations and
governing policies. Its current proposal connects a searchable catalog to
focused dataset inspection, schema relationships, SQL workbooks, directed
lineage and change review. D3 develops horizontal activity navigation and one
selection-driven Inspector, with persistent branch/time context. Write-ahead
change streams (`TransitLog`), durable processes (`Station`) and connectors
explain how those declarations are
activated. D2 supplies the retained monochrome baseline; D3 reviews topology
through dataset, workbook and branch-comparison studies.

Earlier items remain intact with their recorded outcomes:
[board-atlas](../board-atlas/README.md) owns the process/resource relief studies,
[board-console](../board-console/README.md) owns the Workspace/Operations shell
and single-worksheet Explore baseline, and
[board-grammar](../board-grammar/README.md) owns the monochrome reactive
declaration profile. [Inspect with Board](../../handbook/guides/inspect-board.md)
and the [data model](../../handbook/reference/data-model.md) own current
implemented behavior and public contracts.

**Current review:** [D3 — Horizontal workbench and one contextual Inspector](D3.md).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | Entity-relationship canvas, five-state profiles, SQL workbooks, data-gravity lineage and branch/DDL comparison | Reviewed | Data-first direction retained; reviewer requested a different theme, greater fidelity and larger screens. D2 develops that feedback. |
| [D2](D2.md) | Focused catalog, dataset, relationship, workbook, lineage and change views; monochrome styling and eight browser-rendered screenshots | In review | Selected monochrome direction is reflected in the artifacts; review the catalog-first default, contextual detail and separate change workflows. |
| [D3](D3.md) | Horizontal activities, optional object navigation, one Inspector and persistent branch/time context across three workflows | Accepted in part | Reviewer endorsed the topology direction; six new browser figures, exact dimensions and responsive behavior remain under review. Theme retained; the existing metadata/result workbench now uses the shared topology. Synthetic storage/execution/comparison dimensions remain proposed. |

Review status tracks the design conversation. The studies and local prototype
do not establish implemented browser routes, arbitrary joins, whole-dataset
profiles or measured latency. Delivery scope and
qualification belong in the [roadmap](../../roadmap/README.md).
The [Board reimplementation milestone](../../roadmap/29-board-reimplementation.md)
owns the installed cutover and browser acceptance over the shared backend
contracts; design acceptance alone does not complete that work.

Follow the shared [review workflow](../README.md#maintaining-the-sequence) and
[template](../TEMPLATE.md) when adding subsequent reviews; the next review in
this item is `D4.md`.

## Supporting material

- [D3 topology studies and figures](D3.md#visual-studies),
  [interactive prototype](d3.html), [interaction source](d3.js),
  [styles](d3.css), [synthetic fixture](d3-fixture.js) and
  [capture/check script](d3-render.mjs).

- [D2 visual studies and full-resolution screenshots](D2.md#visual-studies),
  [local prototype](d2.html), [screen source](d2.js), [styles](d2.css),
  [fixture](d2-fixture.js) and [capture script](d2-render.mjs).
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
