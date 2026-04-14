# Materialized Reference Projection Surface - Software Design Description

> Define how authoritative Transit streams materialize into replayable reference views so external consumers can rebuild or query derived state without hidden local persistence.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage defines the first generic reference projection layer for hosted downstream workloads. The goal is to prove that external consumers can derive domain-owned state from authoritative Transit history and checkpoints instead of storing hidden mutable mirrors beside the server. The reducer contracts and proof surfaces remain generic.

## Context & Boundaries

Transit already has checkpointed materialization primitives. This voyage shapes the generic reducer boundaries, proof surfaces, and checkpoint anchors that downstream repos can use for their own schemas.

```
┌──────────────────────────────────────────────────────────────┐
│               Consumer-Owned Transit Streams                 │
│            domain events owned by downstream repos           │
└───────────────────────────────┬──────────────────────────────┘
                                │ replay + checkpoint
┌───────────────────────────────┴──────────────────────────────┐
│                 Reference Materialization Layer              │
│          reference reducers, checkpoints, resume anchors     │
└───────────────────────────────┬──────────────────────────────┘
                                │ inspect / rebuild
┌───────────────────────────────┴──────────────────────────────┐
│                   External Consumer Read Model               │
│               replaceable derived views only                 │
└──────────────────────────────────────────────────────────────┘
```

### In Scope

- reference reducers and checkpoints for consumer-owned workloads
- rebuild and resume proofs for authoritative projections
- inspectable, replaceable read-model outputs

### Out of Scope

- Hub UI or auth policy
- shipping canonical auth/account/session schemas inside Transit
- mutable projection truth stored outside replay/checkpoint flow

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `transit-materialize` | existing crate | Shared checkpoint and reducer machinery | current |
| Transit manifests and lineage checkpoints | existing engine surface | Authoritative anchors for projection resume and rebuild | current |
| Downstream consumer reference workload or fixture | planning input | Example schema used to prove the generic surface without moving ownership into Transit core | current planning slice |
| Repo proof path | operator surface | Demonstrates rebuild and resume behavior | current |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Projection role | Reference views are reference materializations, not mutable server-owned tables | Preserves append-only authority and replaceable read models |
| Resume anchor | Checkpoints reuse the same lineage and manifest anchors as the core engine | Avoids a projection-only authority model |
| Workload vocabulary | Keep reducer and proof vocabulary generic while allowing downstream repos to own their schema details | Makes the slice directly useful without collapsing Transit into a consumer-specific product |
| Proof style | Demonstrate both replay-from-zero and checkpoint-resume equivalence | Shows that derived state is rebuildable, not hidden |

## Architecture

The voyage adds three conceptual components:

1. Reference input families
   Consumer-owned records with enough structure to drive reference reducers.
2. Reference reducers
   Deterministic reducers that produce current derived views from authoritative history.
3. Rebuild and inspection proofs
   Fixtures that prove projections can be reconstructed from replay or resumed checkpoints.

## Components

### Reference Reducer Contract

- Purpose: Describe how consumer-owned records map into derived views without hard-coding domain policy into Transit core.
- Behavior: Applies ordered events and emits a replaceable view plus checkpoint metadata.

### Checkpointed Projection Runner

- Purpose: Apply reference reducers to authoritative history and resume from checkpoints.
- Behavior: Replays records, persists shared resume anchors, and emits inspectable derived state.

### Projection Proof Fixture

- Purpose: Prove replay-from-zero and checkpoint-resume yield equivalent derived state.
- Behavior: Builds reference streams, materializes projections, checkpoints, resumes, and compares output.

## Interfaces

Interfaces shaped by this voyage:

- reference reducer input contracts for consumer-owned workloads
- checkpoint payloads anchored to lineage and manifest state
- proof or inspection outputs exposing derived reference views and resume anchors

## Data Flow

1. Authoritative consumer-owned records append to Transit streams.
2. Materializers replay records and apply reducers.
3. Reducers emit current reference views plus checkpoints.
4. Additional records append.
5. Materializers resume from prior checkpoints and only process new history.
6. Proof surfaces compare resumed state to a full replay to confirm equivalence.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Projection becomes hidden mutable truth | Review or proof depends on out-of-band state | Reject the design | Keep reducers deterministic and rebuildable from history + checkpoints |
| Checkpoint does not anchor to lineage/manifests | Tests show projection resume lacks shared authority anchors | Treat as design failure | Reuse the existing lineage checkpoint model |
| Reference reducers absorb consumer policy or schema ownership | Code review finds provider or product rules in core reducers | Reject the implementation | Push policy and canonical schemas back to the consumer and keep only shared projection mechanics |
