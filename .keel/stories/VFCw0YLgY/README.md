---
# system-managed
id: VFCw0YLgY
status: in-progress
created_at: 2026-03-28T16:27:16
updated_at: 2026-03-28T16:28:55
# authored
title: Fix Docs Header Width And Overlap
type: docs
operator-signal:
scope: VFCvzGZeD/VFCvzxgfk
index: 1
started_at: 2026-03-28T16:28:55
---

# Fix Docs Header Width And Overlap

## Summary

Repair the Transit docs header regression introduced by the wider navbar content so the header remains full-width and the page body clears it cleanly.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] Keep the public docs header full-width and single-line so the page body no longer overlaps the navbar. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end -->
- [ ] [SRS-02/AC-01] Switch to the mobile navbar before desktop items wrap into a broken second row. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end -->
- [ ] [SRS-03/AC-01] Preserve `Spoke` immediately to the left of `GitHub` in the available navigation. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end -->
- [ ] [SRS-NFR-01/AC-01] Keep the docs build path passing through `just docs-build`. <!-- [SRS-NFR-01/AC-01] verify: just docs-build, SRS-NFR-01:start, SRS-NFR-01:end -->
- [ ] [SRS-NFR-02/AC-01] Preserve the existing Transit docs shell pattern while fixing the regression. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end -->
