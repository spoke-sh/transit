# Ship Replicated Primary Handoff And Failover Semantics - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Deliver a verified replicated primary-handoff slice where a caught-up follower can take over the writable role through explicit lease transfer and former-primary fencing, without introducing quorum acknowledgement or multi-primary semantics. | board: VFDyfjLlI |

## Constraints

- Preserve the shared engine, lineage model, immutable acknowledged history, and object-storage-native storage semantics across the replicated handoff path.
- Reuse the published segment-plus-manifest frontier and read-only follower catch-up path from the prior replication slice as the transfer boundary.
- Keep `local`, `replicated`, `tiered`, and failover semantics explicit; do not overclaim quorum acknowledgement, majority election, or multi-primary behavior.

## Halting Rules

- DO NOT halt while `MG-01` has unfinished board work or while primary handoff semantics still leave stale-primary or failover guarantees ambiguous.
- HALT when `MG-01` is satisfied and `keel doctor` reports no blocking board-health errors.
- YIELD to human when the next step requires product direction on automatic failover, quorum acknowledgement, or multi-primary behavior.
