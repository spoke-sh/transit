# AI Trace Contract

`transit` needs one canonical AI workload model so the storage engine, examples, and benchmarks all target the same lineage-heavy shape.

This document defines that first contract.

For large payload handling and object-store-backed artifact references, see [AI_ARTIFACTS.md](AI_ARTIFACTS.md).

## Design Center

The canonical AI trace model should stay close to `transit`'s core primitives:

- a task or run starts as a root stream
- retries, critiques, and alternate plans become child branches
- reconciliation is explicit through merge artifacts
- tool calls, evaluator decisions, and checkpoints are immutable records
- large prompts, outputs, and attachments may be referenced externally without changing lineage semantics

## Canonical Entities

### Task Root

The task root is the main stream for one bounded unit of AI work.

Use it for:

- the initial user request or system goal
- top-level task metadata
- final task completion or abandonment

Canonical lineage action:

- create root stream

### Retry Branch

A retry branch captures a new attempt derived from an earlier point in the task history.

Use it for:

- model retries
- alternate parameter choices
- recovery after tool or model failure

Canonical lineage action:

- branch from the task root or another branch at a chosen offset

### Critique Branch

A critique branch captures reflective or adversarial analysis of a prior path.

Use it for:

- self-critique
- evaluator review
- alternative reasoning paths

Canonical lineage action:

- branch from the path being critiqued

### Tool-Call Event

A tool-call event is an immutable record describing a requested tool action or its result.

Use it for:

- tool invocation intent
- tool result metadata
- execution timing and status

Canonical lineage action:

- append to the active stream or branch

### Evaluator Decision

An evaluator decision records a judgment about a path, artifact, or result.

Use it for:

- ranking candidate paths
- pass/fail scoring
- classifier or judge output

Canonical lineage action:

- append to the active stream or branch

### Merge Artifact

A merge artifact records an explicit reconciliation of two or more candidate paths.

Use it for:

- selecting a winning branch
- synthesizing critique back into a mainline
- documenting why multiple paths converged

Canonical lineage action:

- merge two or more stream heads with explicit parents and policy

### Completion Checkpoint

A completion checkpoint marks a stable point in task progress.

Use it for:

- final answer emission
- handoff to another system
- durable resume points for later processing

Canonical lineage action:

- append to the active stream or branch

## Minimum Metadata

The canonical AI trace model needs a small, consistent metadata set.

### Required For Root And Branch Entities

- `task_id`: stable task or run identifier
- `trace_kind`: root, retry, critique, merge, tool-call, evaluator-decision, or checkpoint
- `actor_id`: human, agent, model, tool runner, or evaluator identity
- `created_at`: creation timestamp
- `reason`: short cause such as `initial-request`, `retry-after-timeout`, or `critique-pass`

### Required For Branches

- `parent_stream_id`: stream being branched from
- `fork_offset`: offset where the branch diverges
- `branch_kind`: retry, critique, alternate-plan, or other explicit category

### Required For Tool Events

- `tool_name`: invoked tool identifier
- `tool_call_id`: stable id for the request/result pair
- `tool_phase`: request or result
- `tool_status`: success, failure, timeout, or partial

### Required For Evaluator Decisions

- `evaluator_id`: model, rule set, or human reviewer identity
- `subject_ref`: stream, branch, record, or artifact being judged
- `decision`: selected, rejected, passed, failed, scored, or classified

### Required For Merge Artifacts

- `merge_parents`: ordered list of parent stream heads
- `merge_policy`: policy name used for reconciliation
- `merge_reason`: why the merge happened

### Required For Completion Checkpoints

- `checkpoint_kind`: final, intermediate, handoff, or resume
- `checkpoint_status`: success, incomplete, failed, or superseded

## Example Shape

```json
{
  "type": "agent.tool_call",
  "task_id": "task-0142",
  "trace_kind": "tool-call",
  "actor_id": "agent.planner.v1",
  "created_at": "2026-03-11T22:00:00Z",
  "reason": "gather-context",
  "tool_name": "search",
  "tool_call_id": "tc-0091",
  "tool_phase": "request",
  "tool_status": "success"
}
```

## What This Contract Deliberately Does Not Do Yet

- define the large-artifact envelope in detail
- define benchmark fixture layouts
- standardize one application schema for every agent framework

The artifact-envelope contract now lives in [AI_ARTIFACTS.md](AI_ARTIFACTS.md). Benchmark fixture layout belongs in the next planning slice.

## Rust Helper Surface

The first-party Rust helper surface lives under
`transit_core::workloads::ai` and is re-exported by `transit_client::workloads`.

Those helpers construct only ordinary Transit inputs:

- task root `LineageMetadata`
- retry and critique branch inputs anchored by `StreamPosition`
- tool-call, evaluator-decision, and checkpoint payload bytes
- explicit `MergeSpec` values for reconciliation
- `ArtifactEnvelope` values for merge artifacts

The helpers do not execute models, host evaluators, or define application
framework schemas. They only preserve canonical trace vocabulary over the
shared stream, branch, merge, and artifact primitives.

For a runnable downstream example that creates a task root, retry and critique
branches, tool and evaluator records, a merge artifact, and completion
checkpoints through embedded and hosted APIs, run:

```bash
cargo run -p transit-client --example workloads
```
