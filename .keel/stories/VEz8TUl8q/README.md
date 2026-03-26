---
# system-managed
id: VEz8TUl8q
status: backlog
created_at: 2026-03-26T07:48:59
updated_at: 2026-03-26T08:05:29
# authored
title: Add Manifest Root Verification And Lineage Checkpoint Proof To Integrity Command
type: feat
operator-signal:
scope: VEz2gV93L/VEz3V79iG
index: 2
---

# Add Manifest Root Verification And Lineage Checkpoint Proof To Integrity Command

## Summary

Extend the `integrity-proof` command to verify manifest roots match before and after object-store publication and restore, and to create and verify lineage checkpoints across branch and merge operations.

## Acceptance Criteria

- [ ] [SRS-02/AC-01] The integrity proof publishes segments to object storage, restores from the remote manifest, and verifies manifest roots match before and after restore. <!-- [SRS-02/AC-01] verify: cargo test + just screen, SRS-02:start:end -->
- [ ] [SRS-03/AC-01] The integrity proof creates branches and merges, produces lineage checkpoints via `engine.checkpoint()`, and verifies them via `engine.verify_checkpoint()`. <!-- [SRS-03/AC-01] verify: cargo test + just screen, SRS-03:start:end -->
