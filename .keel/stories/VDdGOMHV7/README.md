---
id: VDdGOMHV7
title: Define Segment And Manifest Integrity Model
type: feat
status: done
created_at: 2026-03-11T23:33:33
updated_at: 2026-03-11T23:40:06
operator-signal: 
scope: VDd1F1tUe/VDdGLscWy
index: 3
started_at: 2026-03-11T23:39:51
submitted_at: 2026-03-11T23:39:59
completed_at: 2026-03-11T23:40:06
---

# Define Segment And Manifest Integrity Model

## Summary

Define the minimum integrity vocabulary for immutable `transit` history so segments and manifests can become verifiable objects instead of opaque storage blobs.

## Acceptance Criteria

- [x] [SRS-01/AC-01] The story defines the minimum immutable integrity artifacts for `transit`, including fast segment checksums, cryptographic segment digests, and manifest roots. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log-->
- [x] [SRS-02/AC-01] The story defines the lineage checkpoint contract and the minimum proof surface required for remote restore and lineage inspection. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end, proof: ac-2.log-->
