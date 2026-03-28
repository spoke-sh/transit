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
| Ack boundary model | Keep `local`, `replicated`, and `tiered` as distinct operator commitments even when they share the same publish path | Avoids semantic drift between cluster handoff and remote durability |
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

## Guarantee Surface

| Commitment | Meaning | Trigger | Operator Reading |
|------------|---------|---------|------------------|
| `local` | The primary has durably accepted an append on the live writable head. | Existing local durability contract completes on the primary node. | The record is safe on the primary, but no clustered replica or remote restore claim has been made yet. |
| `replicated` | The append has crossed the clustered handoff boundary. | The primary rolls the relevant immutable segment and publishes that segment plus manifest update into the remote tier so followers can restore and catch up from published history. | Followers may still be behind, but the cluster now has a durable shared handoff surface outside the primary's hot head. |
| `tiered` | The append is durable as remote history under the tiered-storage contract. | The same published segment, manifest update, and referenced objects are durable in the remote tier and suitable for cold restore independent of primary-local retention. | Operators can reason about restore/retention durability without inferring follower hydration or failover behavior. |

For this first clustered model, the `replicated` and `tiered` commitments can be produced by the same publication event because the remote tier is both the follower catch-up surface and the object-store durability surface. They are still documented separately because clustered availability and tiered retention answer different operator questions.

## Preserved Invariants

- One writable local head remains the ordering authority for a stream or branch; followers never create competing acknowledged heads in this slice.
- Replication ships rolled immutable segments plus manifest updates, so acknowledged records remain immutable and replay order remains identical to the shared engine.
- Followers learn history through published manifests and segments, which preserves lineage, branch ancestry, and merge visibility instead of creating a server-only branch model.
- Object-store publication remains the serious persistence substrate for clustered history; no separate replicated WAL, follower-only log, or alternate manifest format is introduced.
- Referenced large objects must be durable alongside the manifest publication they are named from, so clustered durability does not diverge from object-storage-native semantics.

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

## Delivery Decomposition

The first follow-on execution voyage is:

| Voyage | Goal | Boundaries |
|--------|------|------------|
| `VF7VP3H4s` / `Deliver Remote-Tier Replication Handoff Foundations` | Carry the planned clustered model into shared-engine publication, read-only follower catch-up, and explicit replicated acknowledgement work. | Stay below consensus, quorum writes, failover, and writable-follower behavior. |

Initial story slices under `VF7VP3H4s`:

| Story | Purpose | Explicit Boundary |
|-------|---------|-------------------|
| `VF7VSqtej` / `Surface Published Replication Frontier` | Surface the immutable segment-plus-manifest frontier that defines clustered handoff. | No new replica log or server-only publication format. |
| `VF7VSpveo` / `Bootstrap Read-Only Follower Catch-Up` | Reuse restore semantics so followers can bootstrap and advance from published history. | Followers remain read-only and do not assume ownership transfer or failover semantics. |
| `VF7VSqlep` / `Expose Replicated Acknowledgement Mode` | Make `replicated` commitment wait for publication of the handoff unit and report it explicitly. | Do not equate publication with follower hydration, quorum acknowledgement, or multi-primary capability. |

## Interfaces

This voyage does not introduce runtime APIs. Its interfaces are planning artifacts:

- epic PRD requirements
- voyage SRS requirement mapping
- voyage SDD architecture and decomposition
- downstream story scopes created from the chosen slice

## Data Flow

1. The primary node accepts writes on its local head and rolls immutable segments.
2. A `local` acknowledgement only claims that the append is durable on the primary under the existing shared-engine contract.
3. Rolled segments and manifest updates become the replication surface published into the remote tier.
4. A `replicated` acknowledgement claims that this published immutable surface now exists for follower restore and catch-up, not that any follower has already applied it.
5. A `tiered` acknowledgement claims that the same published surface is durable for cold restore and retention in the remote tier, independent of the primary's hot local head.
6. Followers restore and catch up from the remote tier instead of receiving record-by-record replicated writes.
7. The planning artifacts capture that model, its exclusions, guarantees, and the next execution slice.
8. The mission advances once the epic has actionable voyages and stories anchored to that model.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Clustered model remains too vague | SRS or epic scope still leaves replication unit/ownership ambiguous | Refine the model decision and exclusions before planning | Rework the voyage docs until one design center is explicit |
| Planning drifts into consensus or multi-primary scope | Scope or stories include quorum, elections, or multi-writer semantics | Reject that slice and restate bounded scope | Split later distributed work into a separate future epic/mission |
| Semantics diverge from the shared engine | Proposed scope invents server-only storage or lineage rules | Mark as invalid against repo constraints | Re-anchor the plan to shared-engine manifests, segments, and lineage |
| Durability guarantees stay implicit | Ack language does not distinguish local, replicated, and tiered boundaries | Block planning completion | Rewrite guarantees so commitment boundaries are explicit |
