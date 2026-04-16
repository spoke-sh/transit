---
# system-managed
id: VGzzXWgvv
created_at: 2026-04-16T16:17:31
# authored
title: Durable Consumer Cursors For Transit Streams
index: 27
mission: VGzzOvI8O
---

# Durable Consumer Cursors For Transit Streams

> Multiple independent readers on the same Transit stream cannot advance separately without each client persisting offsets out of band. Transit has no cursor primitive: transit consume is a stateless one-shot read, tail sessions are ephemeral, and the one suggestion that remained (branches) conflates lineage forks with consumer progress. Downstream consumers that want per-reader progress either implement their own durable offset store or misuse branches, both of which leak Transit's consistency and lineage guarantees into application code.

## Documents

| Document | Description |
|----------|-------------|
| [PRD.md](PRD.md) | Product requirements and success criteria |
| `PRESS_RELEASE.md` (optional) | Working-backwards artifact for large user-facing launches; usually skip for incremental/refactor/architecture-only work |

## Voyages

<!-- BEGIN GENERATED -->
**Progress:** 0/1 voyages complete, 2/4 stories done
| Voyage | Status | Stories |
|--------|--------|---------|
| [Embedded Cursor Primitive And Engine Storage](voyages/VGzzmJ8c8/) | in-progress | 2/4 |
<!-- END GENERATED -->
