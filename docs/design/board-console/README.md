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

**Current review:** [D2 — Visualizing the declarative system](D2.md).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | Product structure, administration model, data workspace and future capability families | Reviewed | Useful starting point; reviewer requested monochrome wireframes, two navigation levels and a declarative foundation; D2 refines the flat shell and form-first model |
| [D2](D2.md) | Declarative objects, Workspace/Operations hierarchy and grammar-to-UI mapping | In review | Black-and-white and declarative design principles requested; review the proposed grouping, definition/dependency views and change semantics |

The figures are black-and-white vector wireframes with synthetic examples. They are
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

Follow the shared [review workflow](../README.md#maintaining-the-sequence) and
[template](../TEMPLATE.md); subsequent reviews continue with D3 in this directory.
