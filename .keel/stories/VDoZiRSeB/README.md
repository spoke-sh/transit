---
id: VDoZiRSeB
title: Implement Segment Digests and Manifest Roots
type: feat
status: done
created_at: 2026-03-13T21:59:19
updated_at: 2026-03-13T22:01:52
operator-signal: 
scope: VDoZVggut/VDoZgweFQ
index: 1
started_at: 2026-03-13T22:01:30
completed_at: 2026-03-13T22:01:52
---

# Implement Segment Digests and Manifest Roots

## Summary

Implement SHA-256 digests for immutable segments and manifest roots in the storage kernel, enforcing verification during tiered restore and publication.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Implement SHA-256 digests for segments and manifest roots in the storage kernel. <!-- [SRS-01/AC-01] verify: cargo test -p transit-core engine::tests::verify_local_lineage_detects_tampering, SRS-01:start, SRS-01:end -->
- [x] [SRS-02/AC-01] Enforce digest verification during tiered restore and publication. <!-- [SRS-02/AC-01] verify: cargo test -p transit-core engine::tests::restored_state_replays_published_history_with_same_manifest_semantics, SRS-02:start, SRS-02:end -->
