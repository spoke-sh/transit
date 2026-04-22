# VOYAGE REPORT: Deliver Compressed Rolled Segments And Replay

## Voyage Metadata
- **ID:** VHUSdlUHb
- **Epic:** VHUSaJ0w8
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 3/3 stories complete

## Implementation Narrative
### Add Segment Compression Config And Metadata Contract
- **ID:** VHUSh3x5v
- **Status:** done

#### Summary
Add the explicit segment-compression contract for the shared engine by introducing a typed `SegmentCompression` surface, defaulting authored storage config and `LocalEngineConfig` to `zstd`, and extending segment descriptors with codec plus stored/uncompressed byte metadata while preserving backward compatibility for legacy uncompressed manifests.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] Transit configuration exposes a typed segment-compression contract with `zstd` as the default codec and `none` as an explicit authored fallback. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log -->
- [x] [SRS-02/AC-01] Segment descriptors surface the codec plus stored and uncompressed byte lengths so compressed storage remains inspectable. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end, proof: ac-2.log -->
- [x] [SRS-NFR-01/AC-01] The compression contract is shared-engine behavior for both embedded and hosted usage; no server-only default or alternate path is introduced. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log -->

### Compress Rolled Segments And Preserve Replay Semantics
- **ID:** VHUSh597Y
- **Status:** done

#### Summary
Implement immutable segment compression in the shared engine by compressing sealed rolled segments with `zstd`, keeping the active head uncompressed, decoding compressed bytes transparently on replay and restore, and preserving stored-byte accounting for retention and integrity metadata.

#### Acceptance Criteria
- [x] [SRS-03/AC-01] Rolled immutable segments are compressed according to the authored codec while the active head remains uncompressed. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-1.log -->
- [x] [SRS-04/AC-01] Replay, recovery, tiered publication/hydration, and hosted read paths verify stored bytes and transparently decompress before parsing logical records. <!-- [SRS-04/AC-01] verify: manual, SRS-04:start, SRS-04:end, proof: ac-2.log -->
- [x] [SRS-05/AC-01] Size-sensitive behavior stays explicit about stored bytes while logical offsets, record counts, and replay-visible payloads remain unchanged. <!-- [SRS-05/AC-01] verify: manual, SRS-05:start, SRS-05:end, proof: ac-3.log -->
- [x] [SRS-NFR-02/AC-01] Checksums and content digests continue to validate the stored segment bytes and remain bound to codec metadata in descriptors/manifests. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-4.log -->
- [x] [SRS-NFR-03/AC-01] Compression does not change logical payload bytes, offsets, replay order, branch ancestry, merge ancestry, or hosted read/tail semantics. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-5.log -->

### Publish Compression Proof Coverage And Operator Guidance
- **ID:** VHUSh6H7w
- **Status:** done

#### Summary
Publish proof coverage and public guidance for immutable segment compression so operators can verify the feature end-to-end and understand that Transit is compressing sealed segment storage, not individual messages or hosted transport envelopes.

#### Acceptance Criteria
- [x] [SRS-06/AC-01] Proof coverage demonstrates compressed-segment behavior across local, tiered, and hosted flows with operator-visible evidence. <!-- [SRS-06/AC-01] verify: manual, SRS-06:start, SRS-06:end, proof: ac-1.log -->
- [x] [SRS-NFR-04/AC-01] Operator-facing documentation explicitly distinguishes immutable segment compression from payload compression and transport compression. <!-- [SRS-NFR-04/AC-01] verify: manual, SRS-NFR-04:start, SRS-NFR-04:end, proof: ac-2.log -->


