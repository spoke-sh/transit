# Deliver Immutable Manifest Snapshots With Frontier Pointer - Software Design Description

> Make published Transit authority object-store-native for filesystem and remote backends by keeping sealed segments and manifest snapshots immutable, discovering the latest published state through a small mutable frontier pointer, and preserving local working-state append semantics.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage moves Transit toward one published-storage authority model without forcing the hot append path into an object-store abstraction. The design separates Transit into two explicit planes:

- `working plane`: local mutable append-oriented state such as `active.segment` and `state.json`
- `published plane`: immutable segments and immutable manifest snapshots, discovered through a small mutable frontier pointer

The filesystem backend should model the published plane with the same namespace and object concepts used for remote object storage. The frontier pointer is the only mutable published artifact.

## Context & Boundaries

### In Scope

- defining the working-plane versus published-plane split
- defining immutable manifest snapshots and the frontier pointer contract
- aligning local filesystem publication with remote object-store concepts
- proof and operator guidance

### Out of Scope

- hot-path active-head append through `object_store`
- manifest delta logs or paged manifest trees
- cross-stream indexing beyond per-stream frontier discovery

```
┌──────────────────────────────────────────────────────────────┐
│                    Transit Shared Engine                    │
│                                                              │
│  Working Plane                    Published Plane            │
│  ┌──────────────────────────┐    ┌────────────────────────┐  │
│  │ active.segment           │    │ immutable segments     │  │
│  │ state.json               │    │ immutable manifests    │  │
│  │ local append lifecycle   │    │ mutable frontier       │  │
│  └──────────────────────────┘    └────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
               ↑                              ↑
        local filesystem                 object_store backends
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `object_store` crate | library | Shared published-plane abstraction for filesystem and remote backends | workspace dependency |
| local filesystem backend | storage backend | Local implementation of object-store concepts for published artifacts | current repo support |
| remote object-store backends | storage backend | Tiered published authority target | current repo support |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Authority split | Two explicit planes: local mutable working state and object-store-native published state | Preserves Transit's append semantics while unifying published authority concepts |
| Manifest model | Immutable full manifest snapshot per publication | Fits object-store strengths and keeps recovery simple |
| Latest discovery | Small mutable frontier pointer per stream | Avoids append-to-object assumptions and expensive/latest listing dependence |
| Local modeling | Filesystem backend uses the same published namespace concepts as remote object storage | Prevents backend-specific semantic drift |

## Architecture

The shared engine continues to own append and segment roll behavior. Publication and restore logic become responsible for treating sealed segments and manifest snapshots as immutable published objects. Recovery/discovery uses the frontier object to locate the latest immutable manifest rather than inferring latest state from backend-specific path conventions.

## Components

- `working-state manager`
  - owns active head, state transitions, and local append lifecycle
  - does not become an object-store append abstraction
- `published segment writer`
  - emits sealed immutable segment objects into the published namespace
- `manifest snapshot writer`
  - emits immutable manifest snapshots that describe the published segment set
- `published frontier writer`
  - updates a small mutable object that points at the latest immutable manifest
- `recovery / discovery reader`
  - resolves latest published state from the frontier pointer and immutable manifest snapshot

## Interfaces

- Published namespace:
  - `streams/<stream>/segments/<segment-id>.segment`
  - `streams/<stream>/manifests/<manifest-id>.json`
  - `streams/<stream>/frontiers/latest.json`
- Frontier payload:
  - `stream_id`
  - `generation`
  - `manifest_id`
  - `manifest_root`
  - `manifest_key`
  - `next_offset`
  - `retained_start_offset`
- Local working plane remains implementation-defined but explicitly separate from the published namespace.

## Data Flow

Publication:

1. append records to the local active head
2. roll sealed segment into an immutable published segment artifact
3. write immutable manifest snapshot describing the published view
4. update the mutable frontier pointer to the latest manifest snapshot

Recovery:

1. resolve latest frontier object
2. fetch referenced immutable manifest snapshot
3. resolve immutable segment objects from the manifest
4. restore or replay published state while preserving existing record semantics

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Frontier points to a missing manifest | Frontier lookup succeeds, manifest fetch fails | Treat frontier as invalid published state | Leave last known good state in place and surface explicit recovery error |
| Manifest references missing segments | Manifest load succeeds, segment fetch fails | Refuse successful restore/publication claim | Surface explicit integrity/recovery error |
| Crash between segment write and frontier update | Missing newer frontier despite new immutable artifacts | Old frontier remains authoritative | Safe retry; latest visible state stays old but consistent |
| Crash after manifest write but before frontier update | New manifest exists but frontier still points at old manifest | Keep old frontier authoritative | Safe retry by re-emitting frontier update |
