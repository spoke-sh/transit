# Kernel Types And Storage Skeleton - Software Design Description

> Establish the first executable slice of the transit engine: stream, branch, and merge domain types, local segment and manifest scaffolding, and a meaningful human-facing mission proof path.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage delivers the first executable slice of the transit engine by locking the domain kernel
and storage scaffold before chasing broader server or processing features. The slice is intentionally
small: typed stream/branch/merge lineage entities, local segment and manifest scaffolding, and a
mission proof path that surfaces the new kernel direction to humans.

## Context & Boundaries

### In Scope

- `transit-core` domain types for streams, branches, merges, and lineage metadata
- storage scaffold types for segments and manifests
- the mission proof path through CLI output and `just mission`
- a documented boundary for a future materialization layer

### Out of Scope

- replication and consensus
- a full stream-processing engine
- automatic merge conflict resolution beyond explicit merge policy metadata

```
┌─────────────────────────────────────────┐
│              This Voyage                │
│                                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
│  │ Domain  │  │ Storage │  │ Mission │ │
│  │ Kernel  │  │ Scaffold│  │ Proof   │ │
│  └─────────┘  └─────────┘  └─────────┘ │
└─────────────────────────────────────────┘
        ↑               ↑
   [CLI/Just]    [object_store]
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `object_store` | Rust crate | Preserve the object-store-native storage boundary in the scaffold | Workspace dependency |
| `clap` | Rust crate | CLI proof surfaces and mission status output | Workspace dependency |
| `just` | Tooling | Single human-facing proof path | Repository task runner |
| Keel | Planning/workflow | Mission, epic, voyage, and story coordination | Flake-provided CLI |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Merge modeling | Explicit multi-parent lineage event with merge policy metadata | Keeps merge first-class without rewriting source history |
| Materialization boundary | Adjacent first-party layer (`transit-materialize`) | Protects the hot append path while keeping derived-state work aligned with core storage truth |
| Mission proof path | Keep `just mission` as the default operator entrypoint | Human verification should stay obvious as implementation grows |
| Scope | Single-node only | Prevents storage-kernel work from mixing with premature distributed design |

## Architecture

The voyage establishes three layers:

1. domain kernel in `transit-core`
2. storage scaffold in `transit-core`
3. proof surfaces in `transit-cli` and `Justfile`

## Components

- Domain kernel:
  Purpose: typed stream, branch, merge, and lineage entities.
  Behavior: preserve explicit append-only lineage semantics and merge-policy visibility.
- Storage scaffold:
  Purpose: define local segment and manifest shapes that later code can persist and tier.
  Behavior: keep local and object-store boundaries explicit without committing to a full engine yet.
- Mission proof path:
  Purpose: give humans one command to validate the current kernel slice.
  Behavior: compile, run tests, and surface kernel-oriented CLI status.

## Interfaces

- `transit-core` exports typed kernel and storage scaffold APIs.
- `transit-cli` exposes mission status and storage proof surfaces.
- `just mission` remains the default human-facing orchestration point.

## Data Flow

1. Developer runs `just mission`.
2. Tests and CLI proof commands exercise the current kernel slice.
3. CLI status summarizes board-aligned progress for humans.
4. Future implementation work extends the same kernel and storage scaffold rather than replacing it.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Domain model drifts from branch/merge design | Review plus tests | Fail the story slice and correct the kernel types | Update code and docs together |
| Storage scaffold hides object-store boundaries | Review plus tests | Reject the design slice | Rework scaffold to keep manifests and persistence explicit |
| Mission proof path no longer reflects product reality | `just mission`, story audit, or operator review | Treat as a blocking regression | Update CLI/task surfaces before advancing the mission |
