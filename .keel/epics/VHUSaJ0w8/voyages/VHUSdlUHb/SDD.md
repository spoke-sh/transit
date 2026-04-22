# Deliver Compressed Rolled Segments And Replay - Software Design Description

> Implement zstd-backed immutable segment compression with explicit descriptor metadata, preserved logical replay semantics, and proof coverage across local, tiered, and hosted flows.

**SRS:** [SRS.md](SRS.md)

## Overview

This voyage makes the existing storage-level compression contract real at the immutable segment boundary. Transit continues to append raw logical records into the active head. When the active head rolls, the shared engine encodes the canonical segment bytes, compresses them with the configured codec, seals the stored bytes with checksum and digest metadata, and publishes the descriptor/manifests that tell replay how to decode the segment later.

## Context & Boundaries

The design deliberately compresses sealed immutable segments only. It does not compress the active head, individual payloads, or hosted request/response envelopes. Embedded mode, hosted mode, and tiered publication keep sharing the same engine path so storage semantics stay aligned.

```
┌─────────────────────────────────────────┐
│              This Voyage                │
│                                         │
│  ┌────────────┐  ┌────────────┐       │
│  │ Roll/Seal  │  │ Replay/    │       │
│  │ Compression│  │ Decompress │       │
│  └────────────┘  └────────────┘       │
└─────────────────────────────────────────┘
        ↑                    ↑
   [Config + Metadata]   [Tiered / Hosted]
```

## Dependencies

| Dependency | Type | Purpose | Version/API |
|------------|------|---------|-------------|
| `zstd` crate | Rust library | Compress and decompress sealed segment bytes | crate dependency added in implementation |
| Existing segment descriptor / manifest model | Internal contract | Surface codec and byte-length metadata to replay and operator paths | `transit-core` storage types |
| Existing integrity pipeline | Internal contract | Continue computing checksum and digest over the concrete stored bytes | shared engine roll/publish path |

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Compression boundary | Compress only rolled immutable segments | The immutable boundary already owns sealing, integrity, and object publication, so it is the cleanest place to add compression without touching append semantics. |
| Default codec | `zstd` | Matches the intended authored configuration contract and gives a practical default without inventing a broad codec matrix. |
| Active head | Remains uncompressed | Preserves the hot append path and avoids mixing compression concerns into crash recovery of the writable head. |
| Integrity scope | Validate stored bytes | Transit integrity should continue to prove the concrete stored artifact rather than a second logical representation in this slice. |
| Size accounting | Keep stored and uncompressed sizes explicit | Operators need both footprint and logical-size visibility, and retention/accounting should remain explicit about which size is used. |

## Architecture

The design touches four boundaries:

- `transit-core` config/types: introduce an explicit segment-compression enum and default it to `zstd`.
- `transit-core` storage metadata: add codec and uncompressed-size metadata to segment descriptors and any status/proof surfaces that reflect segment storage.
- `transit-core` engine: compress on roll, verify stored bytes, then decompress before parsing on replay/recovery/hydration.
- CLI/docs/proofs: explain the feature boundary and prove local, tiered, and hosted behavior over compressed history.

## Components

- Compression contract:
  Purpose: define the authored codec surface.
  Interface: config parsing, defaults, and storage metadata.
  Behavior: `zstd` is the default; `none` preserves uncompressed sealed segments.

- Roll/seal pipeline:
  Purpose: encode canonical segment bytes, optionally compress, then seal the stored artifact.
  Interface: shared-engine roll path.
  Behavior: append path stays raw; only rolled immutable segments are compressed.

- Replay/hydration pipeline:
  Purpose: read stored segment bytes, verify integrity, decode if needed, and parse records.
  Interface: replay, recovery, restore, and hosted read/tail paths.
  Behavior: clients still observe the original logical records with unchanged offsets.

- Operator/proof surfaces:
  Purpose: make codec and size behavior inspectable.
  Interface: descriptors, proofs, docs, and status output as needed.
  Behavior: clearly distinguish segment compression from wire or payload compression.

## Interfaces

Key interface changes expected:

- storage/config interface:
  - typed segment compression codec
  - default `zstd`
  - explicit `none`
- segment descriptor interface:
  - `compression`
  - stored `byte_length`
  - `uncompressed_byte_length`
- replay semantics:
  - no client-visible payload or offset changes
  - decompression is internal to shared-engine replay/hydration paths

## Data Flow

1. Append writes raw logical records into the active head.
2. Segment roll encodes the canonical segment bytes.
3. The engine compresses those bytes when the codec is `zstd`.
4. The engine seals the stored bytes with checksum and content digest metadata.
5. The descriptor/manifest records codec and stored/uncompressed lengths.
6. Replay/restore reads the stored bytes, verifies integrity, decompresses if required, and parses the original records.

## Error Handling

| Error Condition | Detection | Response | Recovery |
|-----------------|-----------|----------|----------|
| Unsupported or invalid codec in authored config | Config parsing/validation | Reject startup or command construction with an explicit error | Operator fixes config to `zstd` or `none` |
| Compression failure during segment roll | Roll path returns error before descriptor publication | Fail the roll/append boundary without publishing an invalid segment | Retry after operator intervention; no hidden fallback |
| Corrupted compressed segment bytes | Stored-byte checksum/digest mismatch or decompression failure | Fail replay/restore with an explicit integrity/decode error | Rehydrate from authoritative tier or repair artifact through existing recovery flows |
| Mixed historical codecs across segments | Descriptor codec differs per segment | Decode per descriptor rather than assuming a global format | Replay remains deterministic because each segment carries its own codec metadata |
