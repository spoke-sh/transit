# Verifiable Lineage Contract

`transit` should treat integrity as part of the storage model, not as a future bolt-on.

This document defines the first integrity contract for immutable segments, manifests, and lineage checkpoints.

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
