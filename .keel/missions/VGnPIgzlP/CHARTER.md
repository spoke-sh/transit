# Publish Projection Consumer API For Hosted Downstream Usage - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Publish a canonical upstream projection consumer API in `transit-client` so downstream Rust repos can derive replaceable read models from hosted Transit replay without reviving private hosted wrappers or a projection-only server truth path. | board: VGnPIhJl2 |

## Constraints

- Preserve the shared-engine thesis: projection reads must stay anchored to authoritative replay and the same stream, lineage, and checkpoint model used elsewhere in Transit.
- Keep consumer schema and reducer meaning outside Transit core. Transit may publish generic projection-consumer mechanics, but downstream repos still own domain payloads and view semantics.
- Do not introduce a hidden mutable projection authority inside `transit-server`. Any published projection read surface must remain rebuildable from replay.
- Preserve literal hosted acknowledgement and error semantics at the client boundary. New helpers may compose hosted reads, but they must not invent a second remote contract.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- HALT when epic `VGnPIhJl2` is complete, mission verification is recorded, and `keel doctor` reports no blocking board-health errors
- YIELD to human when satisfying the goal would require Transit to absorb consumer-owned schema policy, invent a projection-only server truth path, or weaken the shared-engine/replay-first contract
