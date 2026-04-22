# Add Hosted Materialization Primitives For External Daemon Consumers - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Deliver a hosted materialization workflow that lets external-daemon consumers checkpoint opaque reducer state, resume incrementally from lineage-bound anchors, and stay entirely on the `transit-server` and `transit-client` boundary. | board: VHYE3HF6J |

## Constraints

- Preserve shared-engine semantics so hosted materialization primitives bind to the same lineage, manifest, and replay contracts as local materialization.
- Preserve client-first operation so downstream applications do not need `LocalEngine`, embedded Transit authority, or app-owned offset files.
- Preserve authoritative log semantics so hosted cursors and checkpoints describe derived progress only and never mutate acknowledged stream truth.
- Preserve verification clarity so hosted checkpoints carry enough stream and lineage identity to reject unsafe resume attempts.

## Halting Rules

- HALT if the proposed hosted surface requires downstream applications to embed `LocalEngine` or duplicate authoritative stream state locally.
- HALT if checkpoint or cursor resume semantics cannot be verified against lineage and manifest identity across the hosted boundary.
- HALT when epic `VHYE3HF6J` is complete and only follow-on operator adoption or manual validation remains.
