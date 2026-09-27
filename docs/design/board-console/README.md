# Board console design reviews

[Design items](../README.md)

This item formalizes Board as Transit's main administration and data interface.
It covers configuring and operating transports, connectors and integrations,
alongside exploring, visualizing and querying Tables, Documents and KV.
It starts at the first HTTP connector and considers a much wider future system.

The [Board atlas](../board-atlas/README.md) remains the record of spatial and
resource-workspace exploration. This item builds on its selected visual direction
and bounded implementation without changing its recorded outcomes.
[Board](../../BOARD.md) remains the owner of product boundaries and current behavior.

**Current review:** [D5 — Connections, Sources, Sinks and Activity](D5.md).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | Product structure, administration model, data workspace and future capability families | Reviewed | Useful starting point; reviewer requested monochrome wireframes, two navigation levels and a declarative foundation; D2 refines the flat shell and form-first model |
| [D2](D2.md) | Declarative objects, Workspace/Operations hierarchy and grammar-to-UI mapping | Reviewed | Reviewer requested a compact icon toggle, Transit branding, a product/application-oriented realm dropdown and removal of redundant shell text; D3 refines the presentation |
| [D3](D3.md) | Compact navigation, product context and more working space | Reviewed | Reviewer found the shell cleaner and easy to review; D4 carries it forward and merges Data/Queries into Explore |
| [D4](D4.md) | Live SQL-first Explore, context-aware search, result timing, profiles and charts | In review | Figure 1 direction selected; reviewer requested execution/readiness time, data freshness and predicted next readiness in place of result-state badges; search, timing, scheduling and profile/stream contracts remain proposed |
| [D5](D5.md) | Monochrome structure, Connections, Sources, Sinks and Activity | In review | Shared collection/detail structure and eight wireframes proposed; definition readiness, observed outcomes and unknown remote results remain distinct |

The figures are monochrome vector wireframes with synthetic examples; D4 uses
reviewer-requested pale grey to indicate provisional results without a label. They are
neither application screenshots nor evidence of available protocols, permissions
or scale. The proposal preserves M2/M13 and maps dependencies to M15–M19;
new implementation work requires its own place in the linear roadmap.

## Supporting material

- [D1 capability inventory](CAPABILITIES.md): transport, connector, integration,
  identity and data families; candidate configuration, evidence and open contracts.
- [D1 console wireframe](images/d1-01-console.svg).
- [D1 configuration review wireframe](images/d1-02-change.svg).
- [D1 data workspace wireframe](images/d1-03-data.svg).
- [D2 Workspace / Data wireframe](images/d2-01-definitions.svg).
- [D2 source dependencies wireframe](images/d2-02-dependencies.svg).
- [D2 query representations wireframe](images/d2-03-query.svg).
- [D2 Operations / Access wireframe](images/d2-04-operations.svg).
- [D2 SQL examples and expected support](d2-fixture.json).
- [D3 Workspace wireframe](images/d3-01-workspace.svg).
- [D3 query wireframe](images/d3-02-query.svg).
- [D3 Operations wireframe](images/d3-03-operations.svg).
- [D3 realm dropdown wireframe](images/d3-04-realm-selector.svg).
- [D4 table completion wireframe](images/d4-01-typeahead.svg).
- [D4 result with Profile closed](images/d4-01b-profile-closed.svg).
- [D4 column completion wireframe](images/d4-02-columns.svg).
- [D4 result summary wireframe](images/d4-03-result-summary.svg).
- [D4 Query info popover](images/d4-03b-query-info.svg).
- [D4 resource typeahead wireframe](images/d4-04-catalog.svg) and [search fixture](d4-catalog-fixture.json).
- [D4 live stream wireframe](images/d4-05-live-stream.svg).
- [D4 chart wireframe](images/d4-06-chart.svg).
- [D4 wider profile layout study](images/d4-07-wide-profile.svg).
- [D4 global power search](images/d4-08-power-search.svg) and [context comparison](images/d4-09-search-context.svg).
- [D4 search system design](SEARCH.md) and [ranking/context fixture](d4-search-fixture.json).
- [D4 console design notes](CONSOLE.md) and [study fixture](d4-fixture.json).
- [D4 live scheduling notes](LIVE.md) and [live scenarios](d4-live-fixture.json).
- [D4 result timing and prediction design](TIMING.md) and [synthetic timing fixture](d4-timing-fixture.json).
- [D5 monochrome structure guide](STRUCTURE.md) and [synthetic fixture](d5-fixture.json).
- [D5 visual studies and SVG sources](D5.md#visual-studies): shared structure,
  Connections collection/detail, Source, Sink, Activity, attempt evidence and change review.

Follow the shared [review workflow](../README.md#maintaining-the-sequence) and
[template](../TEMPLATE.md); subsequent reviews continue with D6 in this directory.
