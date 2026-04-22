# Deliver Compressed Rolled Segments And Replay - SRS

## Summary

Epic: VHUSaJ0w8
Goal: Implement zstd-backed immutable segment compression with explicit descriptor metadata, preserved logical replay semantics, and proof coverage across local, tiered, and hosted flows.

## Scope

### In Scope

- [SCOPE-01] A typed segment-compression contract with `zstd` as the default codec and `none` as an explicit fallback.
- [SCOPE-02] Segment descriptor and manifest metadata for codec plus stored and uncompressed byte lengths.
- [SCOPE-03] Shared-engine roll-time compression of immutable segments while keeping the active head uncompressed.
- [SCOPE-04] Transparent replay, recovery, publication, hydration, and size/accounting behavior for compressed segments across local, tiered, and hosted paths.
- [SCOPE-05] Documentation and proof coverage for the new segment-compression contract.

### Out of Scope

- [SCOPE-06] Per-record payload compression or schema-aware message encoding.
- [SCOPE-07] Hosted request/response or transport-level compression.
- [SCOPE-08] Compression of the active writable head.
- [SCOPE-09] Broad codec negotiation beyond `zstd` and `none`.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Add a typed segment-compression configuration surface with `zstd` as the default codec for newly sealed segments and `none` as an explicit authored fallback. | SCOPE-01 | FR-01 | story: VHUSh3x5v |
| SRS-02 | Surface segment compression metadata in descriptors/manifests, including codec plus stored and uncompressed byte lengths. | SCOPE-02 | FR-02 | story: VHUSh3x5v |
| SRS-03 | Compress rolled immutable segments in the shared engine while keeping the active head uncompressed and append behavior unchanged. | SCOPE-03 | FR-03 | story: VHUSh597Y |
| SRS-04 | Make replay, recovery, publication, and hydration transparently verify and decompress compressed segments so consumers receive the original logical records. | SCOPE-04 | FR-04 | story: VHUSh597Y |
| SRS-05 | Keep size-sensitive behavior explicit by using stored segment bytes for storage accounting and retention-related logic while preserving logical offsets and record counts. | SCOPE-04 | FR-05 | story: VHUSh597Y |
| SRS-06 | Publish proof coverage and operator guidance that explain segment-compression boundaries and distinguish them from payload or transport compression. | SCOPE-05 | FR-06 | story: VHUSh6H7w |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | `zstd` must be the default codec for newly sealed segments across shared-engine embedded and hosted usage; no server-only compression mode is allowed. | SCOPE-01, SCOPE-03 | NFR-01 | story: VHUSh3x5v |
| SRS-NFR-02 | Checksums and content digests must validate the stored segment bytes, and descriptors/manifests must bind the codec required to decode those bytes. | SCOPE-02, SCOPE-04 | NFR-02 | story: VHUSh597Y |
| SRS-NFR-03 | Compression must not change logical payload bytes, offsets, replay order, branch ancestry, merge ancestry, or hosted read/tail semantics. | SCOPE-03, SCOPE-04, SCOPE-05 | NFR-03 | story: VHUSh597Y |
| SRS-NFR-04 | Operator-facing docs and proof output must clearly describe this slice as immutable segment compression rather than payload or wire compression. | SCOPE-05 | NFR-04 | story: VHUSh6H7w |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
