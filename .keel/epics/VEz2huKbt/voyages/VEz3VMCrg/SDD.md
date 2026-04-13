# Materialization End-To-End Proof - Software Design Description

> Exercise materialization checkpoint, resume, Prolly Tree snapshots, and branch-aware processing end-to-end through `just screen`.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage adds a `materialization-proof` CLI mission command to `transit-cli` that exercises the full materialization lifecycle: reducing stream records into derived state, checkpointing, resuming from a checkpoint, building Prolly Tree snapshots, and processing branch-local records. The proof joins the `just screen` flow alongside the integrity proof.

## Context & Boundaries

The materialization kernel (`transit-materialize`) already has `LocalMaterializationEngine`, `Reducer` trait, `ProllyTreeBuilder`, and `SnapshotManifest`. This voyage wires them into a proof surface.

```
┌──────────────────────────────────────────────────────────────┐
│                    just screen                                │
│                                                              │
│  local-engine  tiered-engine  networked-server  integrity    │
│  proof         proof          proof             proof        │
│                                                              │
│  materialization-proof (NEW)   object-store probe            │
└──────────────────────────────────────────────────────────────┘
        ↑                    ↑                    ↑
   transit-core         transit-materialize   object_store
   engine.rs            engine.rs / prolly.rs
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `transit-materialize::engine::LocalMaterializationEngine` | struct | Drives materialization lifecycle | current |
| `transit-materialize::Reducer` | trait | Defines state reduction over records | current |
| `transit-materialize::MaterializationCheckpoint` | struct | Durable checkpoint envelope with `LineageCheckpoint` anchor | current |
| `transit-materialize::prolly::ProllyTreeBuilder` | struct | Builds content-addressed Prolly Tree from entries | current |
| `transit-materialize::prolly::ObjectStoreProllyStore` | struct | Persists Prolly nodes to filesystem-backed object store | current |
| `transit-materialize::prolly::SnapshotManifest` | struct | Binds a Prolly root digest to a source checkpoint | current |
| `transit-core::engine::LocalEngine` | struct | Underlying append/branch engine | current |
| `transit-core::storage::LineageCheckpoint` | struct | Shared integrity anchor | current |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Proof reducer | Simple counting or accumulating reducer that produces inspectable state | Keeps the proof focused on lifecycle, not domain logic |
| Prolly store backend | `ObjectStoreProllyStore` backed by local filesystem | Matches the existing test pattern; produces real persisted nodes |
| Branch-aware scenario | Materialize root stream, then materialize a branch separately | Simplest credible demonstration of branch-local derived state |
| Screen position | After integrity proof, before object-store probe | Natural grouping: engine proofs → integrity → materialization → probe |

## Architecture

The proof command follows the existing mission proof pattern:

1. **Setup** — Open a local engine, create a root stream.
2. **Append & Materialize** — Append records, run `LocalMaterializationEngine.catch_up()`, inspect `current_state()`.
3. **Checkpoint** — Call `engine.checkpoint()` to produce a `MaterializationCheckpoint` with a `LineageCheckpoint` anchor.
4. **Resume** — Append more records, create a new materializer from the checkpoint, call `catch_up()`, verify it only processes new records.
5. **Snapshot** — Build a `ProllyTreeBuilder` from derived entries, store via `ObjectStoreProllyStore`, produce a `SnapshotManifest`.
6. **Branch** — Create a branch, append branch-specific records, materialize the branch, produce a branch-local snapshot with a distinct root digest.

## Components

### ProofReducer

A minimal `Reducer` implementation for the proof:

```rust
struct CountReducer;
// State: { count: u64, last_offset: Option<u64> }
// reduce: increment count, update last_offset
```

### MaterializationProofResult

```
- data_root: String
- root_stream_id: String
- records_appended: u64
- materialized_count: u64
- checkpoint_offset: u64
- checkpoint_manifest_root: String
- resume_records_processed: u64
- snapshot_root_digest: String
- snapshot_manifest_id: String
- branch_stream_id: String
- branch_snapshot_root_digest: String
- branch_snapshot_distinct: bool
```

### Screen Integration

Add a `Prove materialization` step to `just screen`:
```bash
announce "Prove materialization"
just transit mission materialization-proof --root "$screen_root/materialization"
```

## Interfaces

- `transit mission materialization-proof --root <path> [--json]`
- Human-readable terminal output by default.
- `--json` produces `MaterializationProofResult`.

## Data Flow

1. Engine opens → appends records → segments roll.
2. `LocalMaterializationEngine` consumes records via `catch_up()` → `Reducer` accumulates state.
3. `checkpoint()` produces `MaterializationCheckpoint` with `LineageCheckpoint` anchor from engine.
4. More records appended → new materializer created from checkpoint → `catch_up()` processes only new records.
5. Derived state entries fed to `ProllyTreeBuilder` → nodes stored in `ObjectStoreProllyStore` → root digest returned.
6. `SnapshotManifest` binds root digest to source checkpoint.
7. Branch created → branch materializer runs independently → branch snapshot produced with distinct root.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Checkpoint resume processes wrong offset range | Compare `resume_records_processed` against expected count | Fail proof with mismatch details | Investigate checkpoint anchor or engine replay |
| Prolly Tree build fails | `ProllyTreeBuilder.build_from_entries()` returns error | Fail proof with build error | Investigate entry serialization or store backend |
| Branch snapshot matches root snapshot | Compare root digests | Fail proof — branch-local state should differ | Investigate branch isolation in materializer |
| Materializer state doesn't match expected count | Compare `materialized_count` against `records_appended` | Fail proof with count mismatch | Investigate reducer or catch_up logic |
