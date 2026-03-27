# Ship Multi-Node Consensus And Stream Ownership - Charter

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Deliver verified multi-node stream ownership on the shared engine by integrating lease-backed consensus so only the current leader can append or advance manifests for a stream head without introducing mandatory external coordinators. | board: VDssrPWoX |

## Constraints

- Preserve the one-engine thesis: consensus and stream ownership live in the shared engine, not a server-only control plane.
- Keep lineage, manifest, and durability semantics explicit; ownership must fence concurrent writers without rewriting acknowledged history.

## Halting Rules

- DO NOT halt while `MG-01` has unfinished board work or while stream-ownership validation leaves multi-node append safety ambiguous.
- HALT when `MG-01` is satisfied and `keel doctor` reports no blocking board-health errors.
- YIELD to human when consensus backend scope, ownership transfer semantics, or durability guarantees cannot be resolved from repo context without product ambiguity.
