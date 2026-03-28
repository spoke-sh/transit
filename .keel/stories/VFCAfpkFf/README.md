---
# system-managed
id: VFCAfpkFf
status: backlog
created_at: 2026-03-28T13:19:15
updated_at: 2026-03-28T13:20:05
# authored
title: Remove Blue Hover Link Underline
type: docs
operator-signal:
scope: VFCAdyu9b/VFCAfFwD7
index: 1
---

# Remove Blue Hover Link Underline

## Summary

Remove the remaining blue markdown hover underline/accent by explicitly overriding the shared docs hover link state.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] Override markdown hover link styling so hovered docs links no longer read blue. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end -->
- [ ] [SRS-02/AC-01] Keep hover/focus link affordance clear after removing the blue accent. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end -->
- [ ] [SRS-NFR-01/AC-01] Keep the docs build path passing through `just docs-build`. <!-- [SRS-NFR-01/AC-01] verify: just docs-build, SRS-NFR-01:start, SRS-NFR-01:end -->
- [ ] [SRS-NFR-02/AC-01] Keep the hover treatment visually aligned with the Transit theme. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end -->
