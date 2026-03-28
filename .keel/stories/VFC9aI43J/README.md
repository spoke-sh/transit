---
# system-managed
id: VFC9aI43J
status: backlog
created_at: 2026-03-28T13:14:56
updated_at: 2026-03-28T13:16:15
# authored
title: Tone Down Docs Link Underlines
type: docs
operator-signal:
scope: VFC9XEYwI/VFC9YYrzQ
index: 1
---

# Tone Down Docs Link Underlines

## Summary

Replace the bright light blue public-docs underline with a calmer link-decoration treatment that still reads clearly as a link.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] Replace the bright light blue docs underline with a subtler default decoration treatment. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end -->
- [ ] [SRS-02/AC-01] Keep hover-state link affordance clear after the underline change. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end -->
- [ ] [SRS-NFR-01/AC-01] Keep the docs build path passing through `just docs-build`. <!-- [SRS-NFR-01/AC-01] verify: just docs-build, SRS-NFR-01:start, SRS-NFR-01:end -->
- [ ] [SRS-NFR-02/AC-01] Keep the underline treatment visually aligned with the current Transit theme. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end -->
