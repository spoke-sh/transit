# Ship Quorum Acknowledgement and Automatic Failover - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Deliver a verified quorum-based durability mode that requires acknowledgement from a majority of live nodes. | board: VFOPrFVvq/GOAL-01 |
| MG-02 | Deliver an automatic election-based failover mechanism that promotes a follower to primary when the existing lease expires. | board: VFOPrFVvq/GOAL-02 |
| MG-03 | Deliver a cluster membership primitive that allows nodes to discover their peers and calculate quorum. | board: VFOPrFVvq/GOAL-03 |

## Constraints

- Preserve the one-engine thesis: quorum and failover logic must work in the shared engine.
- Maintain immutable acknowledged history and explicit lineage.
- Keep durability and failover semantics explicit for operators.

## Halting Rules

- DO NOT halt while goals have unfinished board work or while quorum and failover semantics are ambiguous.
- HALT when goals are satisfied and `keel doctor` reports no blocking board-health errors.
- YIELD to human when the next step requires product direction on dynamic rebalancing or multi-primary semantics.
- YIELD to human if quorum implementation requires a breaking change to the existing server protocol.
