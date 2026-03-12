# Ship The First Durable Local Transit Engine - Charter

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Deliver the first durable local `transit` engine with real append, replay, branch, merge, segment roll, manifest persistence, crash recovery, cold-history publication/restore, and a meaningful `just mission` proof path. | board: VDeYUdLSW |

## Constraints

- This mission is now the primary delivery mission for `transit`.
- Mission `VDd0tzmDw` remains active as a research feeder mission; its completed AI workload and integrity slices are inputs to this mission, not blockers to normal execution.
- AI trace and artifact guidance from `VDd1EybWm` must shape event and evaluation surfaces where relevant.
- Integrity boundaries from `VDd1F1tUe` must shape segment, manifest, checkpoint, restore, and release-sensitive decisions where relevant.
- Single-node and local-first only for this mission; no distributed consensus, replication protocol, or multi-node scheduling work.
- Server semantics may inform interfaces, but this mission must not require a network daemon to prove correctness.
- Branch and merge behavior must stay explicit, append-only, and lineage-preserving.
- Object storage must remain a first-class persistence target even when the hottest implementation slice is still local.
- Materialization may be prepared through checkpoint and replay boundaries, but this mission must not collapse into building the full processing layer.
- CRDT semantics remain out of scope for this mission.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- HALT when all MG-* goals with `board:` verification are satisfied and `keel doctor` reports no blocking board-health errors
- YIELD to human when durability guarantees, merge semantics, or cold-restore scope cannot be resolved from repo context without creating product-level ambiguity
