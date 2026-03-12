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

## Modeling Agent And AI Workloads

`transit` should be a natural fit for branch-heavy AI systems.

Recommended patterns:

- one root stream for a task or conversation
- one child branch for each retry, critique path, or alternate plan
- record tool calls and model outputs as immutable events
- keep classifier and evaluator decisions in metadata so later replay explains why a branch exists

This makes comparison and audit much easier than trying to reconstruct branching behavior from ad hoc logs.

## Record Design Tips

- Keep payloads immutable and self-describing.
- Put routing, typing, and lineage hints in headers or metadata.
- Store large blobs in object storage and reference them from records instead of forcing giant append payloads.
- Use branch creation for semantic divergence, not for every consumer-specific view.

## Storage Design Tips

- Treat the hot local head as a latency optimization, not the only source of truth.
- Design segments and manifests so cold replay from object storage is routine.
- Prefer explicit derived views over hidden rewrites of acknowledged history.
- Keep branch creation cheap by referencing ancestor segments until divergence actually occurs.

## Working In This Repository

For now this repository is document-first. The expected order of operations is:

1. read [README.md](README.md)
2. read [ARCHITECTURE.md](ARCHITECTURE.md)
3. read [CONSTITUTION.md](CONSTITUTION.md)
4. use [CONFIGURATION.md](CONFIGURATION.md), [EVALUATIONS.md](EVALUATIONS.md), and [RELEASE.md](RELEASE.md) as implementation constraints

The current bootstrap developer loop is:

1. enter `nix develop`
2. run `just mission`
3. use `just help` or `just run -- --help` for the CLI surface

If a proposed change conflicts with those documents, update the docs intentionally before or with the code change.
