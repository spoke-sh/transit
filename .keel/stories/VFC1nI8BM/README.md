---
# system-managed
id: VFC1nI8BM
status: backlog
created_at: 2026-03-28T12:43:59
updated_at: 2026-03-28T12:53:02
# authored
title: Apply Subway-Themed Docs Visual Refresh
type: docs
operator-signal:
scope: VFC1jEl3d/VFC1kvq6u
index: 1
---

# Apply Subway-Themed Docs Visual Refresh

## Summary

Port the upstream Keel docs shell into Transit’s public site, then re-skin it with a subway-inspired palette and a distinct Transit top navigation/header treatment.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] Port the upstream Keel docs shell patterns into Transit, including the navbar slice treatment and shared docs chrome. <!-- [SRS-01/AC-01] verify: build + manual, SRS-01:start, SRS-01:end -->
- [ ] [SRS-02/AC-01] Apply a subway-inspired Transit palette and a visibly distinct top navigation/header color treatment. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end -->
- [ ] [SRS-03/AC-01] Restyle the Transit homepage to match the Keel visual language while preserving Transit-specific copy and docs routes. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end -->
- [ ] [SRS-NFR-01/AC-01] Maintain strong readability and contrast across the refreshed shell. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end -->
- [ ] [SRS-NFR-02/AC-01] Keep the existing docs build workflow passing through `just docs-build`. <!-- [SRS-NFR-02/AC-01] verify: build, SRS-NFR-02:start, SRS-NFR-02:end -->
