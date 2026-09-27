# Serving design reviews

[Design items](../README.md)

This item formalizes how Transit hosts services, reactive APIs and live views.
[Serving](../../SERVING.md), [Reactive APIs](../../REACTIVE_API.md) and
[Reactive interfaces](../../REACTIVE.md) own the
cross-component design; the [roadmap](../../roadmap/README.md) owns implementation
scope and qualification. The [Board console](../board-console/README.md)
explorations motivate these foundations without changing their recorded outcomes.

**Current review:** [D1 — Serving, reactive APIs and reactive interfaces](D1.md).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | Serving ownership, SSE/WebSocket API contracts, live views and milestone sequence | In review | Reviewer selected application APIs plus Board, preserved private access and snapshot refresh; follow-up places reactive API hosting in M20 before M21 interfaces; detailed contracts remain proposed |

The monochrome diagrams describe proposed boundaries, not deployed components
or executable wire/SQL contracts. Subsequent reviews continue with D2 here.
