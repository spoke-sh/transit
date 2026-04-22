---
# system-managed
id: VHYEAUq0l
status: done
created_at: 2026-04-22T12:48:53
updated_at: 2026-04-22T13:14:52
# authored
title: Implement Hosted Materialization Resume Flow In Transit Client
type: feat
operator-signal:
scope: VHYE3HF6J/VHYE9AqjG
index: 2
started_at: 2026-04-22T13:12:00
submitted_at: 2026-04-22T13:14:52
completed_at: 2026-04-22T13:14:52
---

# Implement Hosted Materialization Resume Flow In Transit Client

## Summary

Implement the hosted resume path in `transit-client` so client-only Rust materializers can validate a hosted checkpoint or cursor, fetch only post-anchor records, and stay entirely on the `transit-server` boundary without `LocalEngine`.

## Acceptance Criteria

- [x] [SRS-03/AC-01] Hosted resume validates the checkpoint or cursor anchor and returns only records after that anchor while rejecting lineage mismatches or missing anchors. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-1.log -->
- [x] [SRS-04/AC-01] `transit-client` exposes the canonical Rust workflow for hosted checkpoint, resume, and pending-record fetch without requiring `LocalEngine`. <!-- [SRS-04/AC-01] verify: manual, SRS-04:start, SRS-04:end, proof: ac-2.log -->
- [x] [SRS-NFR-02/AC-01] External-daemon consumers can stay on the hosted server/client boundary for the full materialization workflow. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log -->
