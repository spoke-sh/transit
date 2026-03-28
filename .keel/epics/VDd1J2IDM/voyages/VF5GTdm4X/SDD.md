# Define Initial Replication Model And Boundaries - Software Design Description

> Define the first clustered replication model, explicit durability boundaries, and the initial execution slice below consensus and multi-primary semantics.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage converts the finished replication bearing into executable planning. The selected first clustered model is a single-primary leader/follower topology that keeps one writable local head on the primary node and replicates rolled segments plus manifest updates through the remote tier. Followers restore and catch up from object-store-backed history and do not accept writes. The output is a planned voyage with concrete downstream stories, not distributed runtime code.

## Context & Boundaries

In scope: selecting the first replication unit and ownership model, defining acknowledgement/durability boundaries, publishing preserved invariants, and decomposing the next execution slice under the existing shared-engine architecture.

Out of scope: implementing replication transport, follower catch-up, cluster membership, consensus, quorum writes, multi-primary coordination, or any server-only persistence path.

```
┌───────────────────────────────────────────────────────────────────┐
│                 First Clustered Model (planned)                  │
│                                                                   │
│  primary node -> rolled segments + manifests -> remote tier       │
│        follower nodes <- restore / catch-up from remote tier      │
└───────────────────────────────────────────────────────────────────┘
            ↑                                         ↑
     one writable local head                  read / catch-up replicas
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `VDfEs25yS` / `VDfEx13Wu` | completed mission/epic | Baseline proven single-node server semantics that clustered work must extend | board artifact |
| `VDssqtPXS` / `VDssrPWoX` | completed mission/epic | Stream ownership and lease-backed consensus slice that informs scope boundaries | board artifact |
| `ARCHITECTURE.md` | repo document | Preserves one-engine, lineage, and object-storage-native constraints | current repo |
| `.keel/bearings/VDd1J2IDM/` | research artifact | Source research that justified the staged replication plan | current repo |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| First clustered model | Single-primary leader/follower topology | Preserves one writable stream head while giving followers an explicit clustered role |
| First replication unit | Rolled segments plus manifest updates | Matches the object-storage-native design and avoids record-by-record replication on the hot path |
| Follower role | Followers restore and catch up from remote-tier history | Reuses existing restore semantics and keeps clustered replicas aligned with published history |
| Excluded alternatives | No quorum writes, multi-primary, or general consensus in the first slice | Keeps the next slice bounded and aligned with the epic PRD |
| Planning output shape | Produce explicit model, invariants, and decomposition artifacts | Converts research into executable work instead of leaving a vague draft epic |
| Storage boundary | Preserve shared-engine semantics and object-store-native history | Prevents replicated work from inventing a second semantic world |

## Architecture

The voyage defines three planning layers that must stay coherent:

- `replication model`
  Names the single-primary leader/follower approach, rolled-segment/manifest replication unit, and one-writer ownership assumptions.
- `guarantee surface`
  Defines acknowledgement, durability, and restore/catch-up boundaries across local, replicated, and tiered modes.
- `delivery decomposition`
  Breaks the chosen model into the first execution voyage and initial stories with explicit exclusions.

## Components

- `primary writer`
  Owns the writable local head, rolls immutable segments, and publishes manifests into the remote tier.
- `remote tier replication unit`
  Carries immutable segments and manifests as the clustered handoff surface between primary and followers.
- `follower catch-up path`
  Restores from remote-tier history and advances via published segments/manifests rather than direct record fan-out.
- `invariants matrix`
  Maps ordering, lineage, durability, and storage rules from the proven single-node system into clustered constraints.
- `execution slice`
  Defines the first implementation voyage and the initial story boundaries needed to start delivery without reopening research scope.

## Interfaces

This voyage does not introduce runtime APIs. Its interfaces are planning artifacts:

- epic PRD requirements
- voyage SRS requirement mapping
- voyage SDD architecture and decomposition
- downstream story scopes created from the chosen slice

## Data Flow

1. The primary node accepts writes on its local head and rolls immutable segments.
2. Rolled segments and manifest updates become the replication surface published into the remote tier.
3. Followers restore and catch up from the remote tier instead of receiving record-by-record replicated writes.
4. The planning artifacts capture that model, its exclusions, and the next execution slice.
5. The mission advances once the epic has actionable voyages and stories anchored to that model.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Clustered model remains too vague | SRS or epic scope still leaves replication unit/ownership ambiguous | Refine the model decision and exclusions before planning | Rework the voyage docs until one design center is explicit |
| Planning drifts into consensus or multi-primary scope | Scope or stories include quorum, elections, or multi-writer semantics | Reject that slice and restate bounded scope | Split later distributed work into a separate future epic/mission |
| Semantics diverge from the shared engine | Proposed scope invents server-only storage or lineage rules | Mark as invalid against repo constraints | Re-anchor the plan to shared-engine manifests, segments, and lineage |
| Durability guarantees stay implicit | Ack language does not distinguish local, replicated, and tiered boundaries | Block planning completion | Rewrite guarantees so commitment boundaries are explicit |
