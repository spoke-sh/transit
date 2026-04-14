---
# system-managed
id: VGn7eU7Ft
status: done
created_at: 2026-04-14T11:28:12
updated_at: 2026-04-14T11:54:31
# authored
title: Wire Transit Server Run For Tiered Object-Store Authority
type: feat
operator-signal:
scope: VGn6PdlVK/VGn6xmmDh
index: 2
started_at: 2026-04-14T11:49:43
submitted_at: 2026-04-14T11:54:29
completed_at: 2026-04-14T11:54:31
---

# Wire Transit Server Run For Tiered Object-Store Authority

## Summary

Replace the local-only bootstrap guard in `transit server run` with the hosted
runtime path that accepts tiered/object-store authority configuration and binds
the upstream server against it.

## Acceptance Criteria

- [x] [SRS-02/AC-01] `transit server run` accepts hosted tiered/object-store config without forcing `durability = local`. <!-- verify: manual, SRS-02:start:end -->
  proof: `EVIDENCE/ac-1.log`
- [x] [SRS-03/AC-02] Bootstrap errors still identify the failing provider or missing field clearly when hosted runtime setup cannot proceed. <!-- verify: manual, SRS-03:start:end -->
  proof: `EVIDENCE/ac-2.log`
