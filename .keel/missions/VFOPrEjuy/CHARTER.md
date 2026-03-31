# Ship Quorum Acknowledgement and Automatic Failover - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Deliver verified quorum-based durability, automatic election-based failover, and cluster membership primitives for high-availability Transit clusters. | board: VFOPrFVvq |

## Constraints

- Preserve the one-engine thesis: quorum and failover logic must work in the shared engine.
- Maintain immutable acknowledged history and explicit lineage.
- Keep durability and failover semantics explicit for operators.

## Halting Rules

- DO NOT halt while goals have unfinished board work or while quorum and failover semantics are ambiguous.
- HALT when goals are satisfied and `keel doctor` reports no blocking board-health errors.
- YIELD to human when the next step requires product direction on dynamic rebalancing or multi-primary semantics.
- YIELD to human if quorum implementation requires a breaking change to the existing server protocol.
