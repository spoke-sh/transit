# Serving design reviews

[Design items](../README.md)

This item formalizes how Transit serves external requests and reactive views.
[Serving](../../SERVING.md) and [Reactive interfaces](../../REACTIVE.md) own the
cross-component design; the [roadmap](../../roadmap/README.md) owns implementation
scope and qualification. The [Board console](../board-console/README.md)
explorations motivate these foundations without changing their recorded outcomes.

**Current review:** [D1 — HTTP serving before reactive views and Flight](D1.md).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | Serving ownership, HTTP admission/recovery, reactive snapshot refresh and milestone sequence | In review | Reviewer selected application APIs plus Board, notifications with snapshot refresh, and preserved private Board access; detailed contracts remain proposed |

The monochrome diagrams describe proposed boundaries, not deployed components
or executable wire/SQL contracts. Subsequent reviews continue with D2 here.
