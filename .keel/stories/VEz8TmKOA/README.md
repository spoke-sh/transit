---
# system-managed
id: VEz8TmKOA
status: done
created_at: 2026-03-26T07:49:00
updated_at: 2026-03-26T09:12:55
# authored
title: Integrate Integrity Proof Into Just Screen Flow
type: feat
operator-signal:
scope: VEz2gV93L/VEz3V79iG
index: 4
started_at: 2026-03-26T09:11:36
completed_at: 2026-03-26T09:12:55
---

# Integrate Integrity Proof Into Just Screen Flow

## Summary

Add the `integrity-proof` mission command as a step in the `just screen` recipe so it runs alongside the existing local, tiered, and networked proofs.

## Acceptance Criteria

- [x] [SRS-06/AC-01] `just screen` includes an "integrity proof" step that runs `transit mission integrity-proof` and reports pass/fail alongside the other proof steps. <!-- [SRS-06/AC-01] verify: just screen, SRS-06:start, SRS-06:end, proof: ac-1.log-->
- [x] [SRS-NFR-02/AC-01] The integrity proof output in the screen flow is human-reviewable terminal text with clear pass/fail indicators. <!-- [SRS-NFR-02/AC-01] verify: just screen, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-2.log-->
