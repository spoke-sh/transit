---
title: "Integrity"
sidebar_label: "Integrity"
description: "Verifiable lineage and cryptographic integrity contract."
---
# Integrity Model

`transit` should treat integrity as part of the storage model, not as a future bolt-on.

This document defines the first integrity model for immutable segments, manifests, and lineage checkpoints.

## Design Center

The contract should preserve four things at once:

- fast append on the hot path
- explicit proof boundaries at immutable storage artifacts
- remote restore that does not trust object storage blindly
- lineage inspection that can prove which stream head and parent heads a result came from

## Core Principle

`transit` should separate corruption detection from cryptographic proof.

Those are related, but they are not the same job:

- a fast checksum helps detect accidental corruption during local writes, cache reads, or transport
- a cryptographic digest lets a node prove that an immutable segment or manifest is exactly the content it claims to be

Keeping those concerns separate gives `transit` room to stay fast while still growing into verifiable lineage.

## Minimum Integrity Artifacts

### Segment Checksum

A segment checksum is the first and cheapest integrity layer.

Use it for:

- accidental local corruption
- truncated writes
- cache validation
- transport-level mismatch detection

This checksum may be non-cryptographic if it is serving a fast corruption-detection role.

### Segment Content Digest

A segment content digest is the cryptographic identity of one sealed immutable segment.

Use it for:

- object-store publication verification
- remote restore verification
- dedupe or content-addressed references in later designs

Recommended properties:

- computed only after the segment is sealed
- stable across embedded and server mode
- derived from canonical segment bytes, not mutable local state

The first implementation can keep the algorithm configurable. `BLAKE3` is attractive for throughput, while `SHA-256` remains the conservative interoperability baseline.

### Manifest Root

A manifest root is the cryptographic digest of the manifest body that binds lineage and storage together.

It should cover:

- ordered segment descriptors
- each segment content digest
- stream identity and head position
- branch ancestry or merge parent metadata
- publication metadata needed for restore

The manifest root is the minimum viable remote-restore proof surface. If the manifest root verifies and every referenced segment digest verifies, the node can trust the immutable history it is replaying.

### Lineage Checkpoint

A lineage checkpoint is the integrity envelope for a stable stream head or derived-state handoff.

It should bind:

- `stream_id`
- `head_offset`
- `manifest_root`
- parent heads or merge parents when relevant
- checkpoint kind such as `resume`, `materialized-view`, or `published-result`

This checkpoint may initially be unsigned. Signing and attestation can layer later without changing the core proof shape.

## Verification Lifecycle

Integrity should attach to immutable boundaries, not to every append acknowledgement.

### 1. Append

On the hot path:

- validate framing, offsets, and stream-head invariants
- optionally update an incremental checksum state for the active segment
- do not require manifest hashing, Merkle proof generation, or signatures before ack

This keeps append latency aligned with the core storage thesis.

### 2. Segment Roll

When a writable segment becomes immutable:

- finalize the fast checksum
- compute the cryptographic segment content digest
- emit the sealed segment descriptor that future manifests will reference

This is the first natural proof boundary because the bytes are no longer changing.

### 3. Publish To Object Storage

When publishing a sealed segment:

- upload immutable bytes
- verify uploaded content against the segment content digest
- publish or update the manifest
- compute the new manifest root

The append path should not wait on signatures here unless the configured durability mode explicitly requires that stronger guarantee.

### 4. Restore And Replay

When restoring from local cache or object storage:

- load the manifest
- verify the manifest root
- verify referenced segment digests eagerly or lazily before replay
- reject history that fails checksum or digest validation

This is where object-store-native verification stops being optional marketing and becomes real behavior.

### 5. Lineage Inspection And Checkpoint Exchange

When a client, processor, or operator inspects lineage:

- expose the manifest root and segment digests behind the current head
- expose checkpoint metadata that binds a head to those proofs
- allow later tooling to prove that a merge, materialization, or handoff was derived from a specific immutable history

## Minimum Proof Surface

The first credible proof surface for `transit` is:

- manifest root
- segment content digests referenced by that manifest
- lineage checkpoint binding the current head to that manifest root

That is enough for:

- remote restore
- replay verification
- audit of branch and merge provenance
- future materialization checkpoints keyed to immutable history

It is not yet a full signed trust system, and that is acceptable for the first integrity slice.

## Staged Hardening

### Stage 1: Immutable Object Integrity

Ship:

- fast segment checksums
- cryptographic segment digests
- manifest roots
- checkpoint envelopes without signing

### Stage 2: Compact Proof Structures

Add:

- Merkle-style manifest layouts for partial verification
- Merkle Mountain Range or similar append-friendly accumulators for long histories
- range or branch proofs for inspection APIs and cold restore shortcuts

### Stage 3: Trust And Attestation

Consider:

- signed checkpoints
- release-time signing of manifests or published snapshots
- external attestation for shared or regulated deployments

This stage should not contaminate the base engine until the stage-1 surfaces are stable and benchmarked.

## Throughput Discipline

The integrity design should remain explicit about cost:

- append latency should be dominated by configured durability, not proof-generation overhead
- cryptographic digests should be paid at segment roll and publication boundaries
- restore and audit flows may pay heavier verification costs because they are not the hottest path

If an integrity feature cannot state which path pays for it, it is not ready.

## Data Structures Worth Using

The current best candidates are:

- `BLAKE3` tree hashing for high-throughput immutable segment digests
- Merkle manifests for partial verification of long histories
- Merkle Mountain Ranges for append-friendly proof accumulation across segment sequences
- prolly trees for materialized state snapshots keyed to verified lineage checkpoints

These structures belong at immutable boundaries. They should not force CRDT metadata or application semantics into every append.

## What This Contract Deliberately Defers

- per-record signatures
- full key-management design
- distributed attestation
- replication proofs across multiple nodes
- forcing one digest algorithm into the public API before implementation experience exists

Those are later slices after the local engine, object-store flow, and materialization boundaries are sharper.
