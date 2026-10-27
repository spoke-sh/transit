# World simulator and Agentic OS design reviews

[Design items](../README.md)

This design item explores a physics-grounded enterprise world simulator and
spatial Agentic OS operator interface built as a downstream application suite
on top of Transit. The simulator pairs a procedurally generated archipelago of
computing and regional factions with real application code running over standard
industry protocols (`TN3270/ISPF`, `FIX`, `X12 EDI`, `SOAP/XML`, `HTTP/REST`,
`gRPC` and SQL), physical facility interiors populated with OpenUSD
[`nvidia/simready-assets`](https://huggingface.co/datasets/nvidia/simready-assets),
and a continuous modernization optimization loop across both deterministic
Single-Player seeds and a persistent MMO "Mainnet."

Unlike [board-atlas](../board-atlas/README.md),
[board-console](../board-console/README.md),
[board-grammar](../board-grammar/README.md) and
[board-data](../board-data/README.md)—which design Transit's built-in
`transit-board` inspection and data studio—this item designs an external
application ecosystem intended to live in a dedicated repository and GitHub
organization outside the Transit kernel and core [roadmap](../../roadmap/README.md).
It consumes Transit strictly through public client, SQL, [`Fuze`](../../handbook/reference/queries.md),
[`Station`](../../handbook/reference/station.md), connector and
[application installation](../../handbook/reference/applications.md) contracts.

**Current review:** [D1 — A physics-grounded world simulator and spatial Agentic OS surface](D1.md).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | Macro cartographic OS with anchored web apps, computing/regional faction archeology, isometric `SimReady` facilities, first-person agent POV and manual takeover, strangler-fig modernization gameplay, and persistent MMO Mainnet rolling upgrades (`5120 × 3200` visual studies) | In review | Review the three-tier spatial zoom model (`Macro Map` $\rightarrow$ `Meso Isometric Facility` $\rightarrow$ `Micro Agent POV`), faction protocol/codec mapping, and Single-Player vs. MMO Mainnet verification goals |

Review status tracks the design conversation. The visual studies and local
compositing prototype do not establish a shipped simulator binary, OpenUSD
runtime integration, `TN3270`/`FIX` protocol adapters in Transit, or measured
Mainnet uptime. Transit's current implemented capabilities and boundaries live in
the [data model](../../handbook/reference/data-model.md),
[workloads and architectural priorities](../../handbook/reference/workloads.md),
[application installation](../../handbook/reference/applications.md) and
[Inspect with Board](../../handbook/guides/inspect-board.md).

Follow the shared [review workflow](../README.md#maintaining-the-sequence) and
[template](../TEMPLATE.md) when adding subsequent reviews; the next review in
this item is `D2.md`.

## Supporting material

- [D1 visual studies and full-resolution `5120 × 3200` screens](D1.md#visual-studies),
  [interactive spatial prototype](d1.html), [screen logic](d1.js),
  [styles](d1.css), [synthetic world and faction fixture](d1-fixture.json),
  [generation and compositing specification](d1-prompts.json) and
  [Playwright 5K capture script](d1-render.mjs).
- High-resolution `5120 × 3200` (`2560 × 1600 @ 2×`) composite PNG studies in [`images/`](images)
  and base world artwork in [`images/raw/`](images/raw):
  - [Figure 1 — Macro cartographic OS, faction archipelago and anchored protocol apps](images/d1-01-macro-world-map.png) ([base art](images/raw/raw-01-macro-world-map.png))
  - [Figure 2 — Computing factions and software archeology across geological strata](images/d1-02-faction-archeology.png) ([base art](images/raw/raw-02-faction-archeology.png))
  - [Figure 3 — Meso isometric intermodal dock with `nvidia/simready-assets` and live terminals](images/d1-03-isometric-simready-dock.png) ([base art](images/raw/raw-03-isometric-simready-dock.png))
  - [Figure 4 — Micro first-person agent POV, counterfactual branch review and manual takeover](images/d1-04-agent-pov-control.png) ([base art](images/raw/raw-04-agent-pov-control.png))
  - [Figure 5 — Non-stop modernization optimization workbench and fault-injection proof](images/d1-05-modernization-loop.png) ([base art](images/raw/raw-05-modernization-loop.png))
  - [Figure 6 — Persistent MMO Mainnet and five-axis rolling live upgrades](images/d1-06-mmo-mainnet-epochs.png) ([base art](images/raw/raw-06-mmo-mainnet-epochs.png))
- Owning Transit references that ground the simulator's invariants:
  [Data, computation and policies](../../handbook/reference/data-model.md),
  [From data to decisions](../../handbook/reference/collaborative-decisions.md),
  [Workloads and architectural priorities](../../handbook/reference/workloads.md),
  [Application installation, definitions and migration](../../handbook/reference/applications.md),
  [Connectors](../../handbook/reference/connectors.md) and
  [System model](../../handbook/internals/system-model.md).
