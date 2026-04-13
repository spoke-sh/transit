# Object-Store Authority With Warm Cache - Software Design Description

> Make server durability explicit with object storage as the long-term authority and warm local filesystem state as cache and working set rather than the only persistence path.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage turns the current server durability story into the product posture Transit already claims: object storage is the authoritative long-term tier, while local filesystem state accelerates hot work and restart behavior but is not the only serious persistence path.

## Context & Boundaries

Today `transit-server` still opens a local engine rooted in `TRANSIT_DATA_DIR`, and the service contract overstates tiered behavior relative to the implementation. This voyage closes that gap by making authority and warm-cache semantics explicit.

```
┌──────────────────────────────────────────────────────────────┐
│                         Object Store                         │
│            authoritative tiered segments and manifests       │
└───────────────────────────────┬──────────────────────────────┘
                                │ hydrate / publish
┌───────────────────────────────┴──────────────────────────────┐
│                         transit-server                       │
│             hot append path, hydrate, durability labels      │
└───────────────────────────────┬──────────────────────────────┘
                                │ warm cache / working set
┌───────────────────────────────┴──────────────────────────────┐
│                      Local filesystem cache                  │
│        replaceable local state used for performance/restart  │
└──────────────────────────────────────────────────────────────┘
```

### In Scope

- object-store-backed authority configuration
- warm-cache hydrate and recovery behavior
- explicit durability labeling and proof surfaces

### Out of Scope

- replication and quorum durability changes
- consumer-side workload logic
- projection-specific reducer behavior

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `object_store` abstraction | existing library | Authoritative remote tier for rolled segments and manifests | current |
| `transit-core` local engine and publication logic | existing code | Shared manifest, segment, and replay semantics | current |
| transit-server startup path | existing service | Warm-cache hydrate and durability labeling surface | current |
| Repo proof path | operator surface | Restart and recovery evidence | current |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Authority tier | Object storage becomes the long-term authority once a write is claimed as `tiered` | Matches the product thesis and fixes the current filesystem-first contradiction |
| Local state role | Filesystem state is warm cache and working set, not sole authority | Preserves performance without depending on pod-local persistence for truth |
| Recovery rule | Server may rebuild warm state from remote manifests and segments | Keeps acknowledged tiered history durable across cache loss or redeploy |
| Proof boundary | Operator proofs must show restart or cache-loss recovery explicitly | Prevents silent overclaiming of tiered durability |

## Architecture

The voyage introduces three cooperating layers:

1. Publication authority
   Rolled segments and manifests publish into object storage.
2. Warm cache
   Local state accelerates append, replay, and restart but is disposable.
3. Hydration path
   Server startup or recovery can reconstruct local working state from the authoritative remote tier.

## Components

### Object-Store Authority Adapter

- Purpose: Bind transit-server to a concrete authoritative object-store tier.
- Behavior: Publishes rolled artifacts, resolves manifests, and exposes hydrate inputs.

### Warm Cache Manager

- Purpose: Keep local filesystem state useful without making it authoritative.
- Behavior: Tracks cache location, invalidation, and hydration targets.

### Restart/Recovery Proof

- Purpose: Demonstrate remote-tier recovery after local cache loss or restart.
- Behavior: Exercises publication, deletes or invalidates local state, then proves authoritative replay remains available.

## Interfaces

Interfaces shaped by this voyage:

- transit-server configuration for object-store and warm-cache roots
- acknowledgement or inspection outputs that describe `local` versus `tiered` posture
- proof commands or fixtures that simulate restart and cache recovery

## Data Flow

1. transit-server accepts appends into the hot path.
2. Rolled segments/manifests publish to object storage.
3. Once remote publication completes, the durable posture can be described as `tiered`.
4. Warm local state may be cleared, replaced, or rebuilt.
5. Server restart hydrates from remote manifests and segments into local working state.
6. Replay and verification prove the recovered state matches authoritative history.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Remote publication incomplete | Publish path or proof shows missing manifest/segment objects | Keep durability posture below `tiered` | Retry publication before claiming remote authority |
| Warm cache missing or stale | Startup hydrate detects absent or mismatched local state | Rebuild from authoritative remote tier | Hydrate local working set from object storage |
| Local-only state presented as authoritative | Proof or inspection surface cannot distinguish `local` from `tiered` | Treat as contract failure | Make durability labels explicit in output and docs |
