# Guide

`transit` is easiest to understand as a lineage-aware log. It is not a queue that forgets history and not a mutable document store that edits records in place.

## Start With The Mental Model

The intended progression is:

1. append immutable records to a stream
2. read or tail the stream in order
3. fork a branch when a conversation, workflow, or experiment diverges
4. keep ancestry explicit so replay and audit stay cheap
5. rely on tiered storage so older history naturally moves into object storage

If a workload naturally wants "what happened, in what order, and where did this path diverge?" it is a strong fit for `transit`.

## When To Use Embedded Mode

Embedded mode is the default fit when:

- one process owns the append and read path
- very low local latency matters more than multi-client coordination
- you want to bundle the log directly into an agent runtime, local application, or model harness

Examples:

- a local-first agent orchestrator that records tool calls and retries
- a training harness that forks evaluation runs from a common checkpoint event stream
- a desktop communication client that keeps a local lineage-aware event store

## When To Use Server Mode

Server mode is the default fit when:

- multiple applications or users need shared access
- you need centralized auth, quotas, and metrics
- one managed node or cluster should own persistence policy

Examples:

- a hosted collaboration tool
- a shared agent coordination bus
- a central event backbone for multiple workers and services

At the current bootstrap stage, the shared-engine server exposes provisional remote append, read, snapshot-tail, branch creation, merge creation, and lineage inspection operations through `transit-core::server::RemoteClient`. The first wire shape now includes request correlation plus explicit acknowledgement and error envelopes, and the first tail-session model now uses logical `open/poll/cancel` operations with credit-based delivery rather than assuming one long-lived socket. The surface is still explicitly single-node; richer CLI client flows and replication-aware behavior are downstream work.

## Modeling Conversations

The communication use case should stay simple:

- channel = root stream
- thread = child branch anchored to a channel message offset
- reply = append to the thread branch
- summary or backlink = optional append to the root stream referencing the branch id

Example root record:

```json
{
  "type": "message.posted",
  "channel_id": "eng",
  "author": "alex",
  "body": "We should split the deployment plan from the model plan.",
  "message_id": "msg-1042"
}
```

Example branch metadata created by an auto-threading classifier:

```json
{
  "branch_reason": "classifier-thread-split",
  "anchor_message_id": "msg-1042",
  "classifier": "thread-boundary-v1",
  "score": 0.93
}
```

That gives you a durable thread origin without mutating the original channel history.

For the current canonical communication contract, use [COMMUNICATION.md](COMMUNICATION.md).

## Modeling Agent And AI Workloads

`transit` should be a natural fit for branch-heavy AI systems.

Recommended patterns:

- one root stream for a task or conversation
- one child branch for each retry, critique path, or alternate plan
- record tool calls and model outputs as immutable events
- keep classifier and evaluator decisions in metadata so later replay explains why a branch exists

This makes comparison and audit much easier than trying to reconstruct branching behavior from ad hoc logs.

The canonical reference contract for this workload now lives in [AI_TRACES.md](AI_TRACES.md). Use it when defining task roots, retry branches, critique branches, merge artifacts, and completion checkpoints.

When you need benchmark or fixture guidance for the same workload, use [EVALUATIONS.md](EVALUATIONS.md) together with [AI_ARTIFACTS.md](AI_ARTIFACTS.md) instead of inventing a separate trace shape.

## Modeling Materialized Views

Treat materializers as replay consumers, not alternate writers.

Recommended rules:

- consume ordered history from the shared engine instead of acknowledging appends inline
- persist checkpoints that bind derived state to source lineage, offset, and manifest generation
- emit snapshots as explicit artifacts instead of relying on hidden mutable indexes
- use prolly trees as the default snapshot design center when branch-local reuse matters
- keep derived-state merge policy view-specific, with explicit merge artifacts when reconciliation needs auditability

For the current canonical contract, use [MATERIALIZATION.md](MATERIALIZATION.md).

## Record Design Tips

- Keep payloads immutable and self-describing.
- Put routing, typing, and lineage hints in headers or metadata.
- Store large blobs in object storage and reference them from records instead of forcing giant append payloads.
- Use branch creation for semantic divergence, not for every consumer-specific view.

For the first canonical split between inline metadata and large external payloads, use [AI_ARTIFACTS.md](AI_ARTIFACTS.md).

## Storage Design Tips

- Treat the hot local head as a latency optimization, not the only source of truth.
- Design segments and manifests so cold replay from object storage is routine.
- Prefer explicit derived views over hidden rewrites of acknowledged history.
- Keep branch creation cheap by referencing ancestor segments until divergence actually occurs.
- Keep fast checksums and cryptographic proofs distinct so verification grows at immutable boundaries instead of on every append.

For the current integrity model and proof boundaries, use [INTEGRITY.md](INTEGRITY.md).

## Working In This Repository

For now this repository is document-first. The expected order of operations is:

1. read [README.md](README.md)
2. read [ARCHITECTURE.md](ARCHITECTURE.md)
3. read [CONSTITUTION.md](CONSTITUTION.md)
4. read [COMMUNICATION.md](COMMUNICATION.md) when the change touches channels, threads, classifier evidence, or communication reconciliation
5. read [MATERIALIZATION.md](MATERIALIZATION.md) when the change touches processing, checkpoints, snapshots, or derived-state merge semantics
6. read [INTEGRITY.md](INTEGRITY.md) when the change touches checksums, digests, manifests, checkpoints, or restore behavior
7. use [CONFIGURATION.md](CONFIGURATION.md), [EVALUATIONS.md](EVALUATIONS.md), and [RELEASE.md](RELEASE.md) as implementation constraints

The current bootstrap developer loop is:

1. enter `nix develop`
2. run `just mission`
3. use `just run mission local-engine-proof --root target/transit-mission/local-engine` when you want the explicit durable-engine proof without the rest of the mission flow
4. use `just run mission tiered-engine-proof --root target/transit-mission/tiered-engine` when you want the explicit publication and restore proof
5. use `just run server run --root target/transit-mission/server --listen-addr 127.0.0.1:0 --serve-for-ms 100` when you want to exercise the first shared-engine daemon bootstrap
6. use `just help` or `just run -- --help` for the CLI surface

If a proposed change conflicts with those documents, update the docs intentionally before or with the code change.
