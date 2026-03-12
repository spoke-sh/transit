# Research Multi-Node Replication And Server Semantics — Brief

## Context

The repo says embedded and server are packaging choices on one engine, but it also explicitly defers distributed consensus and cross-node replication. This bearing exists to turn that into an explicit staging plan so server mode can move forward without premature distributed design.

## Objectives

- Separate the next server-mode epic from later multi-node replication work without violating the one-engine thesis.
- Name the invariants a future replicated design must preserve around ordering, durability, lineage, and object storage.

## Scope

### In Scope

- The first server-facing API and operational boundary on top of the shared engine.
- Sequencing guidance for when replication should become active design work.
- Candidate replication units such as segments, manifests, or stream-head ownership.

### Out Of Scope

- Designing or implementing a distributed consensus system now.
- Introducing multi-writer semantics before the single-node engine is proven.
- Splitting server mode into a separate storage format or branch model.

## Research Questions

- What is the first network API that should exist before any replication work: append/read/tail, branch/merge, admin, or all of them?
- Should the first replication research center on segment shipping, manifest replication, leader/follower log ownership, or something else?

## Open Questions

- Which wire protocol and client contract should be stabilized before replication enters active design?
- Does object-store-backed history make segments or manifests the more natural replication unit than individual records?
