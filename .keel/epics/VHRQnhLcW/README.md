---
# system-managed
id: VHRQnhLcW
created_at: 2026-04-21T08:55:09
# authored
title: Single-Stream Batch Append For Hosted Protocol
index: 28
mission: VHRQnhScY
---

# Single-Stream Batch Append For Hosted Protocol

> Transit's hosted append surface is still record-at-a-time, which forces one RPC, acknowledgement, and JSON cycle per logical record for high-cardinality producers. Downstream Rust clients need a first-class single-stream batch append path that preserves per-record offsets, ordering, replay/tail semantics, and explicit batch limits without inventing application-level envelope batching above Transit.

## Documents

| Document | Description |
|----------|-------------|
| [PRD.md](PRD.md) | Product requirements and success criteria |
| `PRESS_RELEASE.md` (optional) | Working-backwards artifact for large user-facing launches; usually skip for incremental/refactor/architecture-only work |

## Voyages

<!-- BEGIN GENERATED -->
**Progress:** 0/1 voyages complete, 2/3 stories done
| Voyage | Status | Stories |
|--------|--------|---------|
| [Deliver Hosted Batch Append Surface](voyages/VHRR4L3Dx/) | in-progress | 2/3 |
<!-- END GENERATED -->
