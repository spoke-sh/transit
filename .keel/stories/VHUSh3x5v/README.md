---
# system-managed
id: VHUSh3x5v
status: in-progress
created_at: 2026-04-21T21:21:30
updated_at: 2026-04-21T21:24:19
# authored
title: Add Segment Compression Config And Metadata Contract
type: feat
operator-signal:
scope: VHUSaJ0w8/VHUSdlUHb
index: 1
started_at: 2026-04-21T21:24:19
---

# Add Segment Compression Config And Metadata Contract

## Summary

Add the explicit segment-compression contract for the shared engine, make `zstd` the default codec for newly sealed segments, and surface codec plus stored/uncompressed size metadata through segment descriptors without changing logical record semantics.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] Transit configuration exposes a typed segment-compression contract with `zstd` as the default codec and `none` as an explicit authored fallback. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log -->
- [ ] [SRS-02/AC-01] Segment descriptors surface the codec plus stored and uncompressed byte lengths so compressed storage remains inspectable. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end, proof: ac-2.log -->
- [ ] [SRS-NFR-01/AC-01] The compression contract is shared-engine behavior for both embedded and hosted usage; no server-only default or alternate path is introduced. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log -->
