---
# system-managed
id: VHUjJj4Gh
created_at: 2026-04-21T22:27:31
# authored
title: Object-Store-Native Published Manifests And Frontier Discovery
index: 32
mission: VHUjJi2Fn
---

# Object-Store-Native Published Manifests And Frontier Discovery

> Transit currently models published state differently on local disk and remote object storage, with filesystem-first manifest handling instead of one object-store-native authority model. We need immutable manifest snapshots plus a small mutable frontier pointer so published segments, manifests, and latest-state discovery use the same semantics through the object_store crate while leaving the hot active head local and append-oriented.

## Documents

| Document | Description |
|----------|-------------|
| [PRD.md](PRD.md) | Product requirements and success criteria |
| `PRESS_RELEASE.md` (optional) | Working-backwards artifact for large user-facing launches; usually skip for incremental/refactor/architecture-only work |

## Voyages

<!-- BEGIN GENERATED -->
**Progress:** 1/1 voyages complete, 3/3 stories done
| Voyage | Status | Stories |
|--------|--------|---------|
| [Deliver Immutable Manifest Snapshots With Frontier Pointer](voyages/VHUjMQyiY/) | done | 3/3 |
<!-- END GENERATED -->
