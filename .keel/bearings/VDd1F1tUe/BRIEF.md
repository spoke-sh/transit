# Research Verifiable Lineage And Cryptographic Integrity — Brief

## Context

`transit` already relies on immutable segments, manifests, explicit branch and merge lineage, and object-store-backed recovery. That architecture creates a natural opening for verifiable lineage primitives such as hash-chained segments, Merkle-style manifests, and eventually signed checkpoints or attestations.

## Objectives

- Define the minimum viable integrity model for segments, manifests, and lineage events.
- Separate core integrity metadata from later signing, attestation, or remote-proof features.

## Scope

### In Scope

- Segment and manifest integrity primitives that fit the existing append-only model.
- Verification boundaries for append, segment roll, upload, restore, and lineage inspection.
- Sequencing guidance for when integrity work should begin relative to the kernel and tiered-storage milestones.

### Out Of Scope

- Designing a full trust or key-management system now.
- Shipping heavyweight cryptographic verification on every append acknowledgement.
- Replacing the existing manifest and lineage model with a separate proof system.

## Research Questions

- Is segment-level hashing sufficient for the first storage engine, or do manifests need Merkle-style proofs immediately?
- Which integrity checks must execute on the append path versus at segment roll, upload, or restore time?

## Open Questions

- What should count as the minimum viable proof surface for remote restore: segment hashes, manifest roots, checkpoint signatures, or all three?
- How much cryptographic metadata can be added before it starts distorting the latency story of the hot path?
