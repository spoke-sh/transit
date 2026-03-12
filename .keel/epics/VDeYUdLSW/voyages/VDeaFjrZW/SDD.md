# Local Engine Core And Recovery - Software Design Description

> Deliver the first executable local transit engine slice with durable append, replay, branch/merge execution, segment roll, and crash recovery on local storage.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage turns the existing kernel types and storage descriptors into the first executable local engine slice. The design stays intentionally local-first: one process, one durable local engine, explicit lineage behavior, and a proof path that demonstrates recovery instead of assuming it.

## Context & Boundaries

The boundary is deliberate:

- the voyage implements the first local engine behavior inside the current workspace, likely centered in `transit-core`
- branch and merge semantics move from typed descriptors to executable engine behavior
- recovery becomes a first-class capability, not a future promise
- remote object-store publication and cold restore remain the next voyage so this slice stays reviewable

```
┌───────────────────────────────────────────────────────────┐
│               Local Engine Core And Recovery             │
│                                                           │
│  append + roll   replay + tail   branch/merge   recover   │
│  active segment  local manifest  lineage ops    restart   │
└───────────────────────────────────────────────────────────┘
           ↑                                 ↑
      transit-core types                CLI / just mission
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `crates/transit-core/src/kernel.rs` | code | Current lineage types used by engine operations | current |
| `crates/transit-core/src/storage.rs` | code | Current segment and manifest descriptors used by local persistence | current |
| `INTEGRITY.md` | repo doc | Recovery, checksum, and manifest-boundary guidance | current |
| `AI_TRACES.md` | repo doc | Reference workload pressure for later examples and proof paths | current |
| `transit-cli` and `Justfile` | code/tooling | Human-facing mission verification path | current |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Initial engine location | Build the first executable engine surface in `transit-core` instead of introducing a new crate immediately | Keeps the first usable slice close to the current kernel and storage types |
| Persistence focus | Persist local segment and manifest state before tackling remote publication | Recovery and replay need trustworthy local durability first |
| Branch execution | Model branch creation as lineage-aware manifest/head updates without copying ancestor prefixes eagerly | Preserves the core lineage thesis |
| Merge execution | Emit explicit merge records and metadata on local engine state rather than hidden conflict resolution | Keeps reconciliation inspectable and append-only |
| Mission proof | Extend CLI and `just mission` to demonstrate recovery and lineage behavior | Human proof is part of product discipline |

## Architecture

The voyage produces one local-engine layer with four cooperating concerns:

1. active write path for append and segment roll
2. read path for replay and tail over committed local state
3. lineage operations for branch and merge execution
4. recovery path that reconstructs the engine after restart

## Components

### Local Engine State

- Holds stream heads, active segments, and manifest references.
- Owns durable append and segment-roll behavior.

### Local Manifest Store

- Persists enough metadata to replay committed records and restore stream heads after restart.
- Resolves which local immutable segments belong to which stream head or branch.

### Read And Tail Path

- Serves ordered replay from rolled segments and the active head.
- Keeps the local engine usable without requiring remote storage.

### Lineage Coordinator

- Applies branch creation and merge recording to live engine state.
- Preserves explicit ancestry and merge provenance.

### Recovery Loader

- Rebuilds committed engine state from local segments and manifest metadata.
- Rejects or ignores uncommitted bytes that should not appear after restart.

## Interfaces

This voyage defines code-facing and operator-facing interfaces, not network protocols:

- `transit-core` append/read/tail/branch/merge/recover entry points
- local manifest and segment persistence interfaces
- CLI proof commands and `just mission` verification path

## Data Flow

1. Append validates stream-head state and writes into the active local segment.
2. Segment roll seals immutable bytes and persists updated manifest state.
3. Replay and tail use local manifest metadata to serve committed records in logical order.
4. Branch creation and merge recording update lineage state without rewriting acknowledged history.
5. Recovery reconstructs engine state from persisted local artifacts and discards uncommitted data.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Append targets stale or invalid lineage state | Stream-head and lineage validation fails | Reject append or lineage operation | Retry against current committed head |
| Segment roll or manifest persistence is interrupted | Persisted state is incomplete or inconsistent on restart | Refuse to treat incomplete state as committed | Recover from last committed manifest/segment boundary |
| Replay observes a gap or corrupt local metadata | Manifest/segment validation fails | Stop replay and surface explicit error | Repair from committed local state before serving reads |
| Recovery encounters partially written bytes | Restart scan detects data beyond committed boundary | Exclude trailing uncommitted bytes | Rebuild engine from last valid committed state |
