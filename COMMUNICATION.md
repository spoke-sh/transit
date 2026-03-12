# Communication Contract

`transit` needs one explicit communication workload model.

This document defines the minimum contract for channels, native thread branches,
messages, and optional communication artifacts on top of the shared lineage
engine.

## Design Center

The design center is simple:

- a channel is a root stream
- a thread is a child branch anchored to a channel message offset
- messages remain immutable appends
- thread origin should be explicit and replayable
- summaries and backlinks should be explicit artifacts, not hidden UI state

Communication should remain a workload on top of `transit`, not a separate
storage mode.

## Canonical Entities

### Channel Root

The channel root is the main stream for one conversation space.

Use it for:

- channel-level metadata
- root message flow
- optional summary or backlink artifacts that reference child threads

Canonical lineage action:

- create root stream

### Channel Message

A channel message is a root-stream append that belongs to the main conversation.

Use it for:

- normal channel posts
- system messages that should remain in the root conversation timeline
- thread-anchor messages that later cause a branch split

Canonical lineage action:

- append to the channel root

### Thread Branch

A thread branch is a child stream created from a channel root at a specific
message offset.

Use it for:

- topic divergence
- sub-conversations that should remain inspectable and replayable
- classifier- or human-initiated thread splits

Canonical lineage action:

- branch from the channel root at the anchor offset

### Thread Reply

A thread reply is an append to a thread branch.

Use it for:

- replies that belong inside the child conversation
- system or agent actions that should stay scoped to that thread

Canonical lineage action:

- append to the thread branch

### Thread Backlink

A thread backlink is an optional root-stream artifact that references a thread
branch from the parent channel.

Use it for:

- exposing thread state to root-channel readers
- durable references from the channel timeline to the branch
- lightweight reconciliation that does not require a merge

Canonical lineage action:

- append to the channel root

### Thread Summary

A thread summary is an optional artifact that records a derived overview of a
thread without rewriting the thread or channel history.

Use it for:

- summarizing a thread outcome back to the channel
- creating compact branch overviews for operators or users
- attaching a materialized or human-authored synopsis to a thread

Canonical lineage action:

- append to the channel root or to a dedicated summary stream by convention

## Minimum Metadata

The canonical communication model needs a small, consistent metadata set.

### Required For Channel And Thread Artifacts

- `channel_id`: stable channel identifier
- `communication_kind`: channel-root, channel-message, thread-branch, thread-reply, thread-backlink, or thread-summary
- `actor_id`: human, agent, system, or classifier identity
- `created_at`: creation timestamp
- `reason`: short cause such as `user-post`, `topic-drift`, or `summary-published`

### Required For Channel Messages

- `message_id`: stable message identifier
- `author_id`: user or system author identity
- `body_ref`: inline body or referenced payload location

### Required For Thread Branches

- `thread_stream_id`: created child stream identifier
- `parent_stream_id`: root channel stream id
- `anchor_message_id`: message that caused the thread branch
- `fork_offset`: parent offset where the branch diverges
- `thread_kind`: classifier, manual, system, or other explicit category

### Required For Thread Replies

- `message_id`: stable reply identifier
- `thread_stream_id`: branch receiving the reply
- `author_id`: user or system author identity
- `body_ref`: inline body or referenced payload location

### Required For Thread Backlinks

- `thread_stream_id`: referenced thread branch
- `anchor_message_id`: originating channel message
- `backlink_kind`: mention, status, resolution, or other explicit category

### Required For Thread Summaries

- `thread_stream_id`: summarized thread branch
- `summary_kind`: human, model, moderation, or system
- `summary_ref`: inline summary or referenced payload location

## Example Shapes

Example root message:

```json
{
  "type": "message.posted",
  "channel_id": "eng",
  "communication_kind": "channel-message",
  "actor_id": "human.alex",
  "author_id": "alex",
  "created_at": "2026-03-12T07:00:00Z",
  "reason": "user-post",
  "message_id": "msg-1042",
  "body_ref": "inline:We should split the deployment plan from the model plan."
}
```

Example thread backlink:

```json
{
  "type": "thread.backlink",
  "channel_id": "eng",
  "communication_kind": "thread-backlink",
  "actor_id": "system.thread-index",
  "created_at": "2026-03-12T07:00:03Z",
  "reason": "thread-visible-in-root",
  "thread_stream_id": "eng.thread.1042",
  "anchor_message_id": "msg-1042",
  "backlink_kind": "mention"
}
```

## One-Engine Invariants

This contract must preserve the repo's current invariants:

- channels and threads remain a workload on the shared stream and branch model
- thread creation does not rewrite or mutate channel history
- ordinary messages stay lean and append-only
- communication semantics remain shared across embedded and server packaging
- root and thread replay should explain divergence without consulting hidden side tables

## What This Contract Deliberately Leaves To Later Slices

This document does not yet standardize:

- classifier evidence fields for auto-threading decisions
- human override and moderation workflow details
- when communication workflows should emit summaries, backlinks, or explicit merge artifacts
- UI presentation policy or notification behavior

Those questions belong in the next communication slice. The current contract
only defines the base communication model and keeps it grounded in `transit`
lineage primitives.
