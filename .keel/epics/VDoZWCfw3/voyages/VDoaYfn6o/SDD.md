# Implement Materialization Kernel - Software Design Description

> Deliver the first processing crate and prolly-tree snapshot implementation.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage delivers the first implementation of the materialization contract. It introduces the `transit-materialize` crate which provides the engine for consuming streams and producing durable derived state.

## Architecture

1. **Reduction Engine:** A traits-based system for defining pure reduction logic.
2. **Snapshot Store:** A content-addressed store for Prolly Tree nodes, initially using the shared `object_store` abstractions.
3. **Checkpoint Manager:** Handles binding materialized state to `LineageCheckpoint`s from the core engine.

## Components

- `Reducer`: Trait for state reduction (records -> state).
- `Materializer`: Orchestrates replay and checkpointing.
- `ProllyTree`: Content-addressed B-Tree for branch-aware snapshots.
- `SnapshotManifest`: Describes a reusable materialization snapshot.

## Data Flow

1. `LocalEngine` provides ordered records via replay/tail.
2. `Reducer` updates in-memory state.
3. `Materializer` periodically persists snapshots to the `SnapshotStore`.
4. `Checkpoint Manager` records the `LineageCheckpoint` after snapshot success.

## Error Handling

<!-- What can go wrong, how we detect it, how we recover -->

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
