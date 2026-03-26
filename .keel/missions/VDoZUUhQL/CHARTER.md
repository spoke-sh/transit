# Ship The Verifiable Lineage And Materialization Engine - Charter

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Deliver a verified integrity surface where segment checksums, manifest roots, and lineage checkpoints are exercised end-to-end through `just screen` with tamper-detection proof. | board: VEz2gV93L |
| MG-02 | Deliver a verified materialization surface where branch-aware processors can checkpoint, resume, and produce Prolly Tree snapshots exercised end-to-end through `just screen`. | board: VEz2huKbt |
| MG-03 | Deliver client library support (Python at minimum) so external consumers can exercise append, branch, tail, and lineage operations against a running transit server. | board: VEz2iOasp |

## Constraints

- This mission covers single-node integrity, materialization, and client access only. Multi-node replication and consensus belong to mission `VDssqtPXS`.
- The shared-engine thesis must be preserved: integrity and materialization must work identically in embedded and server modes.
- Integrity hardening must not contaminate the hot append path. Verification surfaces attach to segments, manifests, and checkpoints, not individual appends.
- Materialization must use the same manifests, checkpoints, and lineage model as the core engine.
- Client libraries wrap the server protocol; they must not introduce a second storage or lineage model.
- `just screen` remains the default human proof path. Each goal must extend the screen with its verification evidence.
- Durability and storage context must remain explicit in all proof paths.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- HALT when all MG-* goals with `board:` verification are satisfied and `keel doctor` reports no blocking board-health errors
- YIELD to human when integrity scope, materialization boundaries, or client API shape choices would create product ambiguity that cannot be resolved from repo context
