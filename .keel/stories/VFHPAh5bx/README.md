---
# system-managed
id: VFHPAh5bx
status: done
created_at: 2026-03-29T10:48:12
updated_at: 2026-03-29T11:05:42
# authored
title: Stabilize Branch Metadata Helpers
type: feat
operator-signal:
scope: VFHP6ptRw/VFHP9H1ZM
index: 1
started_at: 2026-03-29T10:58:07
submitted_at: 2026-03-29T11:05:38
completed_at: 2026-03-29T11:05:42
---

# Stabilize Branch Metadata Helpers

## Summary

Stabilize helper APIs for branch metadata so embedded callers can construct lineage-aware branches with app-owned labels and branch context without hand-assembling raw metadata maps.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Provide stable helper APIs for branch metadata on top of existing lineage primitives rather than ad hoc label assembly. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log -->
- [x] [SRS-01/AC-02] Keep the helper surface generic enough for app-owned thread or branch context without hardcoding paddles-specific conversation policy. <!-- [SRS-01/AC-02] verify: manual, SRS-01:continues, SRS-01:end, proof: ac-2.log -->
- [x] [SRS-NFR-01/AC-01] Preserve Transit as a general lineage substrate while exposing the metadata helpers. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log -->
