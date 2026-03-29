# Publish Embedded Lineage Helper Surface - Software Design Description

> Expose stable embedded helper surfaces for branch metadata, root-plus-branch replay/materialization inspection, artifact envelopes, and checkpoint-resume workflows while keeping conversation policy out of Transit core.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage turns existing lineage, replay, materialization, and artifact contracts into an embedded helper surface. It does not invent new conversation semantics. Instead, it stabilizes branch metadata helpers on top of `LineageMetadata`, adds ancestry-aware root-plus-branch inspection helpers, wraps explicit artifact-envelope shapes for common higher-layer patterns such as summaries and backlinks, and tightens checkpoint or replay ergonomics for applications that build stateful layers above Transit.

## Context & Boundaries

In scope: helper APIs for branch metadata, ancestry-aware replay or materialization views, explicit artifact-envelope builders, and checkpoint or replay ergonomics for embedded consumers.

Out of scope: classifier policy, moderation behavior, app-specific thread logic, server-only query surfaces, or a universal schema for every conversation artifact body.

```
┌──────────────────────────────────────────────────────────────┐
│          Embedded Lineage Helper Surface                     │
│                                                              │
│ metadata -> replay views -> artifact helpers -> checkpoints  │
│   app-owned labels -> ancestry view -> explicit envelopes    │
└──────────────────────────────────────────────────────────────┘
          ↑                         ↑
   shared lineage core        materialization/artifact docs
```

## Dependencies

<!-- External systems, libraries, services this design relies on -->

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `crates/transit-core/src/kernel.rs` | source module | Defines `LineageMetadata`, `BranchPoint`, and merge metadata primitives the helper APIs must preserve | current repo |
| `crates/transit-core/src/engine.rs` | source module | Supplies branch creation, replay, and lineage checkpoint APIs the helper surface should wrap rather than replace | current repo |
| `crates/transit-materialize` | crate | Supplies materialization checkpoint and snapshot behavior the replay helpers may compose with | current repo |
| `AI_ARTIFACTS.md` | repo document | Defines the explicit artifact-envelope contract helpers must honor | current repo |
| `COMMUNICATION.md` | repo document | Defines summary, backlink, and branch-metadata conventions that remain application-level but reusable | current repo |
| `MATERIALIZATION.md` | repo document | Defines checkpoint, replay, snapshot, and derived-state invariants the helper layer must preserve | current repo |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Metadata surface | Wrap existing `LineageMetadata` and branch semantics with stable helper constructors or accessors instead of inventing a second metadata model | Preserves the shared engine’s lineage substrate |
| Replay inspection | Expose ancestry-aware root-plus-branch views as embedded helpers instead of flattening branches into one synthetic history | Keeps divergence explicit and audit-friendly |
| Artifact helpers | Provide envelope builders and descriptors, not opaque side tables or product-specific schemas | Transit already prefers explicit artifacts with stable references |
| Checkpoint ergonomics | Improve helper flows around existing checkpoint and replay semantics rather than creating hidden mutable resume state | Preserves replayability and explicit durability boundaries |
| Product boundary | Keep paddles-specific thread or conversation policy out of Transit helper APIs | Maintains Transit as a general substrate |

## Architecture

The voyage has four supporting layers:

- `branch metadata helpers`
  Stable constructors, label helpers, or accessors for app-owned branch context on top of `LineageMetadata`.
- `ancestry-aware replay views`
  Helper views that make root and branch history inspectable together while preserving explicit ancestry and fork boundaries.
- `artifact-envelope helpers`
  Reusable builders or descriptors for explicit summary, backlink, merge-outcome, and adjacent artifact records.
- `checkpoint or replay ergonomics`
  Small helper surfaces that reduce embedded app glue around checkpoint anchors, branch-aware resume, and materialized state inspection.

## Components

- `metadata helper module`
  Encodes stable conventions for common branch metadata keys and access patterns while leaving app-owned labels explicit.
- `replay view adapter`
  Produces ancestry-aware inspection output from existing replay or materialization primitives.
- `artifact helper builder`
  Builds explicit artifact-envelope payloads or descriptors for common higher-layer records such as summaries and backlinks.
- `checkpoint helper adapter`
  Wraps existing checkpoint and replay APIs so applications can resume or inspect branch-aware state with less boilerplate.

## Interfaces

This voyage is expected to touch:

- `LineageMetadata` or adjacent helper APIs for embedded branch construction
- replay or materialization-facing APIs that surface root-plus-branch inspection
- explicit artifact-envelope payload or builder APIs
- checkpoint and replay helper APIs, plus proof or example surfaces that demonstrate them

## Data Flow

1. An embedded caller creates a branch using helper APIs that wrap `LineageMetadata` with stable, explicit conventions.
2. The caller inspects root and branch state through a replay or materialization helper that preserves ancestry and fork points.
3. The caller publishes explicit artifact envelopes for summaries, backlinks, or merge outcomes using helper builders instead of bespoke JSON assembly.
4. The caller anchors derived state or resume logic on existing checkpoint and replay semantics through small ergonomic wrappers.
5. Proof and example surfaces demonstrate that the resulting flow stays replayable, lineage-aware, and product-neutral.

## Error Handling

<!-- What can go wrong, how we detect it, how we recover -->

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Metadata helpers encode paddles-specific policy | Helper keys or types assume one conversation product model | Treat as substrate drift | Push product-specific schema back to the application layer and keep helper APIs generic |
| Replay views flatten or hide ancestry | Inspection surfaces cannot tell where root history ends and branch divergence begins | Treat as a correctness failure | Rework the view around explicit fork metadata and branch lineage |
| Artifact helpers hide references or mutate prior state | Helper APIs stop exposing explicit `artifact_ref`, digest, subject, or audit metadata | Treat as an artifact-contract violation | Re-anchor on the explicit envelope shape from `AI_ARTIFACTS.md` |
| Checkpoint ergonomics introduce hidden mutable resume state | Applications can only resume through side caches instead of explicit checkpoints | Treat as replay drift | Rebuild the helper flow on top of existing checkpoint and replay contracts |
