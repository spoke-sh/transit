---
# system-managed
id: VFJJCYE7v
status: done
created_at: 2026-03-29T18:37:02
updated_at: 2026-03-29T18:41:24
# authored
title: Update Foundational And MDX Docs For Controlled Failover
type: feat
operator-signal:
scope: VFJJ7J3v5/VFJJBrC66
index: 1
started_at: 2026-03-29T18:38:48
submitted_at: 2026-03-29T18:41:22
completed_at: 2026-03-29T18:41:24
---

# Update Foundational And MDX Docs For Controlled Failover

## Summary

Update the foundational documents and user-facing MDX guides so the shipped controlled failover slice is documented consistently for operators and first-time users.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Foundational documents explicitly describe promotion readiness, explicit lease handoff, former-primary fencing, and the bounded non-claims around `local`, `replicated`, `tiered`, quorum, and multi-primary behavior. <!-- verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log-->
- [x] [SRS-02/AC-01] Public MDX concept and first-run docs explain the controlled failover slice and point readers to the relevant proof commands. <!-- verify: manual, SRS-02:start, SRS-02:end, proof: ac-2.log-->
- [x] [SRS-03/AC-01] Synced reference docs and the Docusaurus build succeed after the documentation updates. <!-- verify: manual, SRS-03:start, SRS-03:end, proof: ac-3.log-->
