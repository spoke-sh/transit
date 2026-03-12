# Cold History Publication And Restore - Software Design Description

> Extend the local engine with object-store publication, cold-history restore, and shared-engine proof boundaries so tiered storage stays part of the executable design.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage extends the local engine from “durable on local disk” to “tiered and restorable.” It keeps the same engine model while adding publication of immutable objects to object storage and reconstruction of local state from remote history.

## Context & Boundaries

The boundary is deliberate:

- the voyage reuses the same segment, manifest, and engine semantics introduced by the local-core voyage
- object storage becomes part of the normal lifecycle for rolled immutable history
- restore proves that local state can be reconstructed from remote artifacts without a server daemon
- replication and distributed trust remain explicitly out of scope

```
┌────────────────────────────────────────────────────────────┐
│            Cold History Publication And Restore           │
│                                                            │
│  publish rolled segments   remote manifests   cold restore │
│  object-store lifecycle    shared engine      proof path   │
└────────────────────────────────────────────────────────────┘
            ↑                                  ↑
       local engine core                 CLI / just mission
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| Voyage `VDeaFjrZW` | board/design | Provides the local engine core that publication and restore extend | planned |
| `object_store` wiring in `transit-core` | code | Existing filesystem/object-store probe surface to build on | current |
| `storage.rs` segment and manifest descriptors | code | Shared immutable artifact vocabulary | current |
| `INTEGRITY.md` | repo doc | Publication, manifest, and restore integrity boundaries | current |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Publication unit | Publish rolled immutable segments rather than mutable active heads | Matches the append-only and integrity model |
| Restore source of truth | Restore from remote manifests plus referenced segment objects | Keeps remote history explicit and verifiable |
| Shared engine boundary | Put publication and restore behavior in shared engine-facing code, with CLI only proving it | Preserves the one-engine thesis |
| Tiered proof path | Extend `just mission` to exercise tiered durability and cold restore explicitly | Makes object storage part of the human proof surface |

## Architecture

The voyage adds three cooperating concerns on top of the local engine:

1. publisher for rolled segments and updated manifest state
2. remote artifact resolver for manifests and segment objects
3. cold-restore path that rebuilds local state from remote history

## Components

### Segment Publisher

- Publishes sealed immutable segments to object storage.
- Updates or emits manifest state that references the published objects.

### Remote Manifest Resolver

- Resolves the manifest and segment set required to reconstruct a stream head or branch.
- Uses the same object-store abstraction already present in the workspace.

### Cold Restore Loader

- Rehydrates local engine state from remote manifests and segments.
- Rebuilds enough local state for replay, branch inspection, and resumed operation.

### Tiered Proof Surface

- Exposes CLI and `just mission` flows that prove publication and restore behavior.
- Keeps durability and restore claims explicit for operators.

## Interfaces

This voyage defines engine-facing and operator-facing interfaces:

- local-engine publication and restore entry points
- manifest/object-store resolution interfaces
- CLI proof commands and `just mission` coverage for tiered durability and cold restore

## Data Flow

1. A rolled local segment becomes immutable and eligible for publication.
2. The publisher writes the segment object to object storage and updates manifest state.
3. A restore request loads the remote manifest and referenced segment objects.
4. The cold-restore path reconstructs local engine state from those immutable artifacts.
5. CLI and `just mission` prove the same engine surfaces without inventing a server-only path.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Segment publication is interrupted | Remote object or manifest update is incomplete | Do not advertise incomplete remote history as restorable | Retry publication from the last committed local immutable boundary |
| Remote manifest references missing or invalid objects | Restore-time resolution or digest checks fail | Fail restore explicitly instead of synthesizing local state | Repair or republish remote history before retry |
| CLI proof path masks durability level or restore scope | Mission proof output omits storage context | Treat proof as insufficient and update operator surfaces | Re-run with explicit durability/storage reporting |
