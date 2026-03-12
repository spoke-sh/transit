# Verifiable Lineage Contract - Software Design Description

> Define the minimum integrity contract for segments, manifests, and verification checkpoints without slowing the hot append path.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage is a contract-definition slice. It does not implement digesting, Merkle proofs, or signing in code. Instead, it defines the first integrity model `transit` should share across storage, restore, evaluation, and release planning.

## Context & Boundaries

The boundary is deliberate:

- `transit` keeps append acknowledgements focused on local durability and stream invariants.
- Integrity work attaches to immutable artifacts such as sealed segments, manifests, and checkpoints.
- The voyage defines staged hardening without pretending that key management or distributed attestation already exist.

```
┌──────────────────────────────────────────────────────────────┐
│                   Verifiable Lineage Contract               │
│                                                              │
│  Integrity Artifacts   Verification Lifecycle   Doc Alignment│
│  checksum/digest/      append→roll→publish→     architecture │
│  manifest/checkpoint   restore→inspect          eval/release │
└──────────────────────────────────────────────────────────────┘
            ↑                              ↑
      transit storage model          repo operating surfaces
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `README.md`, `ARCHITECTURE.md`, `CONFIGURATION.md`, `EVALUATIONS.md`, `RELEASE.md` | repo docs | Existing storage and operational guidance to align | current |
| `INTEGRITY.md` | repo doc | Canonical integrity contract produced by this voyage | new |
| `crates/transit-core/src/storage.rs` | code scaffold | Current segment and manifest concepts that this contract is shaping | current |
| Bearing `VDd1F1tUe` | board | Source research and recommendation for this epic | laid |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Integrity layering | Separate fast corruption checks from cryptographic proof surfaces | Keeps throughput and proof claims explicit |
| First proof boundary | Seal integrity at segment roll and manifest publication, not on every append | Immutable artifacts are the natural cryptographic unit |
| Checkpoint scope | Define lineage checkpoints as unsigned proof envelopes first | Signing can layer later without changing the base contract |
| Advanced proof structures | Mention Merkle manifests and Merkle Mountain Ranges as later-stage candidates | Useful direction without prematurely committing implementation |

## Architecture

The voyage produces one canonical contract and four aligned operating surfaces:

1. `INTEGRITY.md` defines the artifacts and lifecycle.
2. `ARCHITECTURE.md` incorporates those artifacts into the system model.
3. `EVALUATIONS.md` defines how integrity cost and correctness are measured.
4. `CONFIGURATION.md` and `RELEASE.md` constrain how integrity claims are configured and shipped.

## Components

### Integrity Artifacts

- Defines the checksum, digest, manifest-root, and checkpoint vocabulary.
- Keeps restore and lineage proof work grounded in immutable storage units.

### Verification Lifecycle

- Defines which phase pays for which verification work.
- Protects the append path from accidental proof inflation.

### Documentation Alignment

- Ensures the repository does not describe integrity one way in architecture and a different way in release or evaluation guidance.

## Interfaces

This voyage defines documentation and planning interfaces, not wire protocols:

- epic PRD requirements
- voyage SRS requirements
- story acceptance criteria
- repository contracts for integrity-sensitive future code

## Data Flow

1. Start from the existing segment, manifest, and lineage model.
2. Define the minimum integrity artifacts for immutable history.
3. Define the lifecycle boundary for append, roll, publish, restore, and inspection.
4. Propagate that contract into the repo’s architecture, configuration, evaluation, and release guidance.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| The contract drifts into per-append cryptographic overhead | Review against NFR-01 and architecture thesis | Reject requirements that gate normal ack on heavy proofs | Re-scope proof work to segment roll, publish, restore, or checkpoints |
| Docs disagree about what counts as verified history | Story verification fails across architecture/evaluation/release/config updates | Normalize on `INTEGRITY.md` as the canonical contract | Re-run `keel doctor` and inspect story evidence |
| The voyage promises a trust model beyond current engine maturity | PRD and SRS review against scope | Remove key-management or distributed-proof language from the slice | Defer to later integrity or replication epics |
