# Communication Contract And Auto-Threading Model - Software Design Description

> Define the first auto-threaded communication contract on top of native branches

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage is a contract-definition slice. It does not implement a chat UI, moderation runtime, or server collaboration feature in code. Instead, it defines the boundary between `transit` lineage primitives and application-level communication behavior, with enough precision that future implementation and benchmarking work can treat auto-threading as a real workload instead of a narrative placeholder.

## Context & Boundaries

The boundary is deliberate:

- `transit-core` owns root streams, child branches, explicit merges, lineage metadata, and ordered replay.
- A communication layer maps channels to root streams and threads to child branches without inventing parallel threading tables.
- Classifier evidence, human overrides, summaries, backlinks, and reconciliation remain explicit artifacts on top of lineage primitives.
- UI policy, moderation policy, and notification behavior stay above the storage contract.

```
┌──────────────────────────────────────────────────────────────┐
│      Communication Contract And Auto-Threading Model        │
│                                                              │
│  channel/thread map   classifier + override   repo docs      │
│  root/branch/events   lifecycle/reconcile     guide/eval     │
└──────────────────────────────────────────────────────────────┘
              ↑                           ↑
        transit lineage engine       communication layer
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `README.md`, `ARCHITECTURE.md`, `GUIDE.md`, `EVALUATIONS.md` | repo docs | Current communication and workload guidance to align | current |
| `MATERIALIZATION.md` | repo doc | Reference for explicit artifacts, checkpoints, and merge discipline | current |
| `AI_TRACES.md` | repo doc | Reference for workload-style contract authoring and explicit artifact vocabulary | current |
| `crates/transit-core/src/engine.rs` | code | Current branch and merge semantics that communication work must reuse | current |
| Bearing `VDd1F0OXH` | board | Source research and recommendation for this epic | laid |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Channel mapping | Channel = root stream | Keeps communication on the shared engine model |
| Thread mapping | Thread = child branch anchored to a message offset | Preserves explicit ancestry and cheap divergence |
| Classifier evidence | Attach to branch creation metadata or explicit artifacts, not every message append | Keeps message writes lean and auditability explicit |
| Normal reconciliation | Prefer summaries and backlinks over merges for ordinary thread visibility | Most thread display behavior is application-level, not lineage reconciliation |
| Explicit merges | Reserve merge artifacts for workflows such as resolution, synthesis, moderation, or archival reconciliation | Keeps merge semantics meaningful instead of decorative |
| Override model | Human override should be explicit artifacts that explain split, suppress, re-anchor, or reconcile decisions | Preserves audit and replay discipline |

## Architecture

The voyage produces one canonical contract and three aligned operating surfaces:

1. `COMMUNICATION.md` will define the channel/thread event model and lifecycle semantics.
2. `ARCHITECTURE.md` will describe the communication workload as a consumer of shared lineage primitives.
3. `GUIDE.md` and `EVALUATIONS.md` will describe how operators and benchmark authors should reason about auto-threading, overrides, and reconciliation.

## Components

### Communication Contract

- Defines canonical communication entities and their minimum metadata.
- Keeps channels, threads, and replies grounded in stream and branch semantics.

### Classifier And Override Model

- Defines what evidence a classifier must publish when opening a thread.
- Defines how human correction remains explicit and replayable.

### Reconciliation Model

- Separates normal UI constructs such as summaries or backlinks from rarer explicit merge artifacts.
- Keeps merge semantics meaningful and auditable.

### Repository Alignment

- Ensures the repo does not describe communication one way in the guide and another way in evaluation or architecture surfaces.

## Interfaces

This voyage defines documentation and planning interfaces rather than wire protocols:

- epic PRD requirements
- voyage SRS requirements
- story acceptance criteria
- repository contracts for future communication-layer or benchmark work

## Data Flow

1. A channel starts as a root stream.
2. Messages append to that root until a human or classifier identifies a thread boundary.
3. Thread creation publishes a child branch anchored to a specific message offset with explicit evidence.
4. Replies append to the branch while optional backlinks or summaries are published as separate artifacts.
5. If the product needs explicit reconciliation, it emits a summary or merge artifact according to the declared policy.
6. Operators and benchmark authors inspect classifier latency, replay correctness, override traceability, and reconciliation artifacts through the same lineage model.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Communication modeling drifts into side tables that bypass native branches | Review against SRS-01 and NFR-01 | Reject contracts that decouple threads from branch lineage | Re-scope to root stream and branch semantics |
| Classifier evidence leaks into every message append | Review against SRS-02 and NFR-02 | Move evidence to branch metadata or explicit artifacts | Rework the contract before implementation begins |
| Merges become a decorative default for normal thread display | Review against SRS-03 | Prefer summaries or backlinks unless true lineage reconciliation is intended | Keep merges reserved for explicit reconciliation workflows |
| Benchmark guidance loses traceability for overrides or classifier decisions | Review against SRS-NFR-03 | Add explicit workload metadata and correctness checks | Re-align docs and evaluation guidance |
