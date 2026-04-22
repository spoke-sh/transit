---
# system-managed
id: VHUSaJ0w8
created_at: 2026-04-21T21:21:04
# authored
title: Implement Shared-Engine Segment Compression
index: 31
mission: VHUSaHyuZ
---

# Implement Shared-Engine Segment Compression

> Transit already advertises segment compression in configuration, but rolled segments are still stored as raw bytes with no explicit codec metadata. We need to make immutable segment compression real in the shared engine without changing logical record semantics, making zstd the default codec for sealed segments while preserving replay, lineage, tiered storage, and hosted behavior.

## Documents

| Document | Description |
|----------|-------------|
| [PRD.md](PRD.md) | Product requirements and success criteria |
| `PRESS_RELEASE.md` (optional) | Working-backwards artifact for large user-facing launches; usually skip for incremental/refactor/architecture-only work |

## Voyages

<!-- BEGIN GENERATED -->
**Progress:** 0/1 voyages complete, 0/3 stories done
| Voyage | Status | Stories |
|--------|--------|---------|
| [Deliver Compressed Rolled Segments And Replay](voyages/VHUSdlUHb/) | in-progress | 0/3 |
<!-- END GENERATED -->
