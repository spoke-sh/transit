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

**Current review:** [D1 — One Board for operations and data](D1.md).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | Product structure, administration model, data workspace and future capability families | In review | Review the shared shell, three configuration tiers, explicit change workflow and equal footing for data; no acceptance recorded |

The figures are authored vector wireframes with synthetic examples. They are
neither application screenshots nor evidence of available protocols, permissions
or scale. The proposal preserves M2/M13 and maps dependencies to M15–M19;
new implementation work requires its own place in the linear roadmap.

## Supporting material

- [D1 capability inventory](CAPABILITIES.md): transport, connector, integration,
  identity and data families; candidate configuration, evidence and open contracts.
- [D1 console wireframe](images/d1-01-console.svg).
- [D1 configuration review wireframe](images/d1-02-change.svg).
- [D1 data workspace wireframe](images/d1-03-data.svg).

Follow the shared [review workflow](../README.md#maintaining-the-sequence) and
[template](../TEMPLATE.md); subsequent reviews continue with D2 in this directory.
