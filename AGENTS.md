# AGENTS.md

Shared guidance for AI agents working with this repository.

## Project Summary

`transit` is a lineage-aware append-only log with native tiered storage. The same engine is intended to power embedded and server modes. Branching, object storage, and immutable history are product primitives, not optional features.

## Read These First

Before making substantial changes, open these documents in order:

1. `README.md`
2. `ARCHITECTURE.md`
3. `CONSTITUTION.md`
4. the task-specific reference doc such as `CONFIGURATION.md`, `EVALUATIONS.md`, or `RELEASE.md`

Do not invent behavior that conflicts with those documents silently.

## Non-Negotiable Working Rules

1. Preserve the shared engine model.
   Embedded and server mode should share storage semantics.
2. Preserve lineage semantics.
   A branch is a real child stream with explicit ancestry.
3. Preserve immutable history.
   Do not introduce in-place mutation of acknowledged records.
4. Preserve object-storage-native design.
   Do not make local disk the only serious persistence path.
5. Make durability explicit.
   Any append guarantee must state whether it is `memory`, `local`, or `tiered`.

Keep `just mission` as the default human proof path. If verification gets richer, improve that path instead of making the operator memorize an expanding command list.

## Terminology Discipline

Use the same words consistently:

- `record`
- `stream`
- `branch`
- `lineage`
- `segment`
- `manifest`
- `local head`
- `remote tier`

If a change needs new vocabulary, define it in the relevant docs instead of letting terms drift in code reviews or commit messages.

## Implementation Guidance

When editing or adding code:

- keep branch creation cheap and ancestry-preserving
- keep recovery rules explicit about committed versus uncommitted data
- prefer designs that work the same in embedded and server mode
- treat large blobs as referenced objects rather than forcing them through the hot append path
- update the docs when configuration, durability, storage layout, or benchmark scope changes

## Review Guidance

When reviewing work, look for these failure modes first:

- server-only semantics that bypass the shared engine
- branch implementations that copy ancestor history eagerly
- hidden rewrite or compaction that changes acknowledged history
- performance claims with no durability or backend context
- configuration knobs that create separate semantic worlds for embedded and server deployments

## Verification Expectations

The expected evidence bar is:

- targeted correctness tests for the changed behavior
- benchmark evidence for performance-sensitive changes
- explicit storage and durability context
- documentation updates when public behavior changes

If the change touches manifests, segments, or protocol surfaces, also check `RELEASE.md`.

## Commit Discipline

Commit granularity is literal in this repository.

- Make one git commit per completed story.
- Do not batch multiple accepted stories into one commit.
- If a voyage or mission transition produces board-only changes beyond a story commit, record that in a separate management commit.
- If planning work creates an epic, voyage, or backlog stories before implementation starts, record that planning slice in its own commit.
- Before starting the next story, stop and commit the previous story with its code, docs, evidence logs, and generated board artifacts.

The goal is simple: Keel story history and git history should line up without interpretation.
