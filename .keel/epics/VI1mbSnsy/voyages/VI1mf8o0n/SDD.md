# Publish Typed AI And Communication Event Builders - Software Design Description

> Provide typed Rust helper APIs and examples for task traces, conversational threads, backlinks, summaries, artifacts, and merge metadata over shared lineage primitives.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage turns the existing workload contracts into typed Rust construction helpers. The helpers produce ordinary Transit primitives: payload bytes, lineage metadata, artifact envelopes, branch positions, and merge specs. They do not add a storage mode or application policy layer.

## Context & Boundaries

The implementation should reuse `transit-core::kernel` and `transit-core::artifact`. If import ergonomics require a new module, prefer a small first-party module over downstream duplication.

```text
AI/communication helper
  -> payload + LineageMetadata / ArtifactEnvelope / MergeSpec
  -> LocalEngine or TransitClient
  -> replay with canonical vocabulary intact
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `AI_TRACES.md` | contract | Canonical AI trace vocabulary | repository |
| `AI_ARTIFACTS.md` | contract | Artifact envelope vocabulary | repository |
| `COMMUNICATION.md` | contract | Channel/thread/backlink vocabulary | repository |
| `transit-core::kernel` | Rust API | Stream, branch, merge, and metadata types | workspace |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Helpers stay policy-neutral | Encode Transit lineage vocabulary only | Downstream apps own schema and business rules. |
| Output uses existing primitives | Return payload bytes and metadata builders rather than custom engine calls | Preserves embedded/server parity. |
| Examples are part of the API proof | Include AI and conversation examples with replay assertions | Reduces downstream ambiguity. |

## Architecture

Typed builders should be small composable constructors. AI trace helpers should cover task, branch, tool, evaluator, merge, and checkpoint events. Communication helpers should cover channel messages, thread creation metadata, replies, backlinks, summaries, classifier evidence, and override artifacts.

## Components

| Component | Purpose | Behavior |
|-----------|---------|----------|
| AI trace builders | Construct canonical agent trace records and lineage metadata | Serializes typed event descriptors and branch/merge metadata. |
| Communication builders | Construct channel/thread records and branch metadata | Produces replayable thread topology without hidden side tables. |
| Artifact integration | Reuse `ArtifactEnvelope` roles for summaries, backlinks, and merge outcomes | Keeps large payload references explicit. |
| Examples/docs | Show downstream usage | Demonstrate embedded and hosted-compatible construction patterns. |

## Interfaces

Candidate surfaces:

- `transit_core::workloads::ai::*`
- `transit_core::workloads::communication::*`
- Builder methods that return `LineageMetadata`, `ArtifactEnvelope`, and serializable event payloads.

## Data Flow

```text
builder input -> typed event payload -> append
builder lineage metadata -> branch or merge creation
replay -> deserialize typed event -> downstream reducer/view
```

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Missing required event field | Builder validation | Return construction error | Caller supplies stable id or required reference |
| Invalid branch anchor | Engine lineage validation | Return existing invalid request | Caller chooses committed anchor position |
| Unsupported downstream schema | Not a Transit concern | Keep payload opaque | Downstream decoder handles domain schema |
