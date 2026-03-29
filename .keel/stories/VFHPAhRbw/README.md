---
# system-managed
id: VFHPAhRbw
status: backlog
created_at: 2026-03-29T10:48:12
updated_at: 2026-03-29T10:50:41
# authored
title: Add Root Plus Branch Replay Views
type: feat
operator-signal:
scope: VFHP6ptRw/VFHP9H1ZM
index: 2
---

# Add Root Plus Branch Replay Views

## Summary

Add ancestry-aware replay or materialization views that let embedded callers inspect root and branch state together without flattening divergence or stitching history manually.

## Acceptance Criteria

- [ ] [SRS-02/AC-01] Expose a supported helper path for root-plus-branch replay or materialization inspection. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end -->
- [ ] [SRS-02/AC-02] Keep fork boundaries, ancestry, and divergence explicit in the resulting view instead of flattening branch history into one synthetic stream. <!-- [SRS-02/AC-02] verify: manual, SRS-02:continues, SRS-02:end -->
- [ ] [SRS-NFR-02/AC-01] Preserve shared-engine semantics and avoid server-only inspection behavior. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end -->
