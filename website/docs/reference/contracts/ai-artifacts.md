---
title: "AI Artifacts"
sidebar_label: "AI Artifacts"
description: "AI artifact envelope contract."
custom_edit_url: "https://github.com/spoke-sh/transit/blob/main/AI_ARTIFACTS.md"
---
# AI Artifact Envelope

`transit` should keep lineage and control metadata in the log while allowing large AI payloads to live in object storage.

This document defines the first artifact-envelope contract for that split.

## Envelope Goal

The envelope should preserve three things at once:

- small, replay-friendly records in the append path
- durable references to large payloads in object storage
- enough inline metadata for audit, routing, and partial recovery without fetching the full artifact

## When To Use An External Artifact

Store content externally when it is large, binary, repetitive, or expensive to inline.

Typical examples:

- full prompts or prompt bundles
- model outputs that exceed normal event size
- tool attachments such as files, screenshots, or scraped documents
- execution traces, transcripts, or evaluation reports

Inline the content directly when it is small and operationally important enough to justify direct replay without a second lookup.

## Envelope Shape

An artifact envelope is an ordinary `transit` record whose payload is a small descriptor.

Recommended fields:

- `artifact_id`: stable identifier for the referenced payload
- `artifact_kind`: prompt, model-output, tool-attachment, trace, evaluation-report, or other explicit type
- `artifact_ref`: logical reference to the stored object
- `content_type`: media type such as `application/json` or `image/png`
- `content_encoding`: optional encoding such as `gzip`
- `byte_length`: object size in bytes
- `digest`: content digest for integrity and dedupe
- `producer_id`: actor that created the artifact
- `created_at`: timestamp
- `subject_ref`: task, stream, branch, record, or tool-call the artifact belongs to
- `retention_class`: optional retention or durability hint

## Inline Versus External

### Metadata That Must Stay Inline

Keep these in the record itself:

- lineage metadata needed to place the artifact in a task trace
- actor and provenance information
- object reference, size, digest, and content type
- a short summary or preview if useful for audit and routing

These fields let a reader understand what happened without downloading the full payload first.

### Content That Should Usually Be External

Keep these in object storage and reference them from the record:

- large prompt bodies
- large model responses
- binary attachments
- tool outputs with substantial raw content
- detailed execution traces or reports

This keeps the append path efficient and prevents giant records from distorting segment behavior.

## Object-Store Relationship

The envelope contract should stay storage-model-neutral inside `transit` while remaining object-store-friendly.

That means:

- the record stores a logical `artifact_ref`, not a storage-engine-specific internal pointer
- the object may live in filesystem-backed development storage or a remote object store in production
- the digest and size fields support verification without requiring transport-specific assumptions

`transit` should not require one URI scheme here yet. It only needs a stable logical reference plus enough metadata to resolve and verify the payload later.

## Example Envelope

```json
{
  "type": "artifact.recorded",
  "task_id": "task-0142",
  "trace_kind": "tool-call",
  "actor_id": "tool.browser",
  "created_at": "2026-03-11T22:05:00Z",
  "reason": "attach-screenshot",
  "artifact_id": "artifact-0021",
  "artifact_kind": "tool-attachment",
  "artifact_ref": "artifacts/task-0142/tool/browser/0021",
  "content_type": "image/png",
  "byte_length": 483221,
  "digest": "sha256:3b2d...",
  "producer_id": "tool.browser",
  "subject_ref": "tc-0091"
}
```

## Replay And Audit Expectations

The envelope should let a replay client answer these questions before fetching the artifact:

- what produced this artifact
- which branch or task it belongs to
- what kind of content it is
- whether the referenced bytes match the expected digest and size

The full payload can remain lazy-loaded.

## What This Contract Deliberately Defers

- multipart artifact chunking
- versioned artifact mutation rules
- retention and GC policy
- replication semantics for artifact objects

Those are later slices once the canonical trace contract and benchmark fixtures are further along.

