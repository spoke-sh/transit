---
# system-managed
id: VGh5zBcvK
status: backlog
created_at: 2026-04-13T10:43:57
updated_at: 2026-04-13T10:45:58
# authored
title: Materialize Authoritative Reference Views From Replay
type: feat
operator-signal:
scope: VGh59soBt/VGh5CIxcc
index: 2
---

# Materialize Authoritative Reference Views From Replay

## Summary

Implement the reference materialization flow that replays authoritative history, derives current views, and resumes from checkpoints without reprocessing settled records.

## Acceptance Criteria

- [ ] [SRS-02/AC-01] The reference materialization flow derives reference views from authoritative replay and can resume from checkpoints for new history only. <!-- verify: cargo test -p transit-materialize reference_projection_ -- --nocapture, SRS-02:start:end -->
- [ ] [SRS-03/AC-01] Derived reference views remain replaceable read models anchored to shared lineage and manifest state rather than hidden mutable truth. <!-- verify: cargo test -p transit-materialize reference_projection_ -- --nocapture, SRS-03:start:end -->
