# Ship The First Single-Node Transit Lineage Engine - Charter

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Deliver the first executable single-node transit kernel for streams, branches, merges, storage scaffolding, and the adjacent materialization boundary while preserving `just mission` as the human-facing proof path. | board: VDcx2lQGz |

## Constraints

- Single-node only for this mission; no distributed consensus, replication, or multi-node scheduling work.
- The same storage engine must remain valid for embedded and server modes.
- Branch and merge semantics must stay explicit, append-only, and lineage-preserving.
- Object storage remains a first-class persistence target, even if the first slice is still mostly local scaffolding.
- Materialization may start as an adjacent first-party layer, but it must not invent a separate storage model.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- HALT when all MG-* goals with `board:` verification are satisfied and `keel doctor` reports no blocking board-health errors
- YIELD to human when merge policy, materialization ownership, or mission scope decisions cannot be resolved from repo context
