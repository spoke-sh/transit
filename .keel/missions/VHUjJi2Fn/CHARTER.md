# Unify Published Transit Storage Around Object-Store Authority - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Unify Transit's published-storage authority around one object-store-native model by keeping sealed segments and manifest snapshots immutable, adding a small mutable published frontier pointer, and using the same published concepts for filesystem and remote object-store backends while preserving the local append-oriented working plane. | board: VHUjJj4Gh |

## Constraints

- Preserve the shared-engine model across embedded and server deployments.
- Do not force the hot append path or active head through the `object_store` crate.
- Keep published segments and manifest snapshots immutable; only the frontier pointer may be updated in place.
- Preserve existing append, replay, lineage, durability, and retention semantics.

## Halting Rules

- Do not halt while voyage VHUjMQyiY has unfinished story work.
- Halt when epic VHUjJj4Gh is done and the published authority model, frontier pointer, and proof/documentation slice are all landed.
- Yield only if design pressure forces a decision beyond the agreed immutable snapshots plus mutable frontier-pointer model.
