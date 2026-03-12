# Ship The First Networked Single-Node Transit Server - Charter

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Deliver the first networked single-node `transit` server on the shared engine with daemon lifecycle, remote append/read/tail/branch/merge/lineage inspection, explicit wire semantics, and a meaningful `just mission` proof path. | board: VDfEx13Wu |

## Constraints

- This mission is the next primary delivery track after the verified durable local engine mission.
- Research mission `VDd0tzmDw` remains active as a feeder; server sequencing from `VDd1J2IDM` and transport-boundary guidance from `VDf8F20kc` are inputs to this mission.
- The server must wrap the shared `transit` engine rather than introducing a server-only storage implementation or alternate lineage model.
- Scope is single-node only for this mission; no replication, consensus, multi-node ownership transfer, or distributed scheduling.
- The first server wire contract must make framing, acknowledgements, errors, and backpressure explicit.
- Transport underlay choices such as WireGuard are deployment concerns for this mission, not the application protocol itself.
- Durability must remain explicit across local and future tiered modes; remote acknowledgements must not obscure what was actually committed.
- `just mission` remains the default human proof path for server-mode verification.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- HALT when all MG-* goals with `board:` verification are satisfied and `keel doctor` reports no blocking board-health errors
- YIELD to human when transport scope, acknowledgement semantics, or server packaging choices would create product ambiguity that cannot be resolved from repo context
