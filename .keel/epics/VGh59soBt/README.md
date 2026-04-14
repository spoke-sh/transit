---
# system-managed
id: VGh59soBt
created_at: 2026-04-13T10:40:40
# authored
title: Make Transit Server The Hosted Authority For External Workloads And Derived State
index: 22
mission: VGh598Oz0
---

# Make Transit Server The Hosted Authority For External Workloads And Derived State

> Some downstream control planes still open local Transit storage for domain-owned records, while transit-server still treats filesystem state as the primary persistence surface. We need hosted Transit to own authoritative append, replay, and generic materialization mechanics for external control planes without absorbing consumer schemas or introducing a second storage or lineage model.

## Documents

| Document | Description |
|----------|-------------|
| [PRD.md](PRD.md) | Product requirements and success criteria |
| `PRESS_RELEASE.md` (optional) | Working-backwards artifact for large user-facing launches; usually skip for incremental/refactor/architecture-only work |

## Voyages

<!-- BEGIN GENERATED -->
**Progress:** 3/3 voyages complete, 9/9 stories done
| Voyage | Status | Stories |
|--------|--------|---------|
| [Remote Authority Contract And Consumer Wiring](voyages/VGh5B5qMT/) | done | 3/3 |
| [Object-Store Authority With Warm Cache](voyages/VGh5BgrVO/) | done | 3/3 |
| [Materialized Reference Projection Surface](voyages/VGh5CIxcc/) | done | 3/3 |
<!-- END GENERATED -->
