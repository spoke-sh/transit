# Implement Immutable Segment Compression In Transit - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Make immutable segment compression real in Transit by compressing sealed rolled segments with `zstd` by default, keeping the active head uncompressed, preserving logical record semantics, and surfacing explicit compression metadata through shared-engine storage artifacts and operator proof paths. | board: VHUSaJ0w8 |

## Constraints

- Preserve Transit's logical record contract: offsets, payload bytes, replay order, branch semantics, merge semantics, and hosted read/tail behavior must not change because segments are stored compressed.
- Scope this mission to immutable segment compression only. Do not introduce per-record payload compression, hosted wire compression, or active-head compression in this delivery slice.
- Keep compression semantics in the shared engine so embedded and hosted modes use the same storage behavior and metadata.
- Make `zstd` the default compression codec for newly sealed segments while still supporting an explicit uncompressed `none` mode for authored configuration and compatibility.
- Segment descriptors and manifests must surface codec metadata and both stored and uncompressed byte sizes so operators can reason about retention, storage footprint, and replay behavior explicitly.
- Integrity must continue to bind the concrete stored segment bytes. Checksums and content digests should validate the sealed stored object, not a second logical re-encoding.
- Verification must cover local replay, tiered publication/restore, and hosted read paths over compressed segments, plus operator-facing documentation that distinguishes segment compression from payload or transport compression.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- HALT when epic `VHUSaJ0w8` is complete, mission verification is recorded, and `keel doctor` reports no blocking board-health errors
- YIELD to human when satisfying the mission would require changing logical record semantics, adding hosted wire compression to the same slice, or introducing codec negotiation broader than the scoped `zstd`/`none` storage contract
