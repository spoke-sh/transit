---
# system-managed
id: VEz8W9xVX
status: done
created_at: 2026-03-26T07:49:09
updated_at: 2026-03-26T23:50:21
# authored
title: Integrate Materialization Proof Into Just Screen Flow
type: feat
operator-signal:
scope: VEz2huKbt/VEz3VMCrg
index: 4
started_at: 2026-03-26T23:47:06
completed_at: 2026-03-26T23:50:21
---

# Integrate Materialization Proof Into Just Screen Flow

## Summary

Add the `materialization-proof` mission command as a step in the `just screen` recipe.

## Acceptance Criteria

- [x] [SRS-06/AC-01] `just screen` includes a "materialization proof" step that runs `transit mission materialization-proof` and reports pass/fail. <!-- [SRS-06/AC-01] verify: just screen, SRS-06:start:end, proof: ac-1.log -->
- [x] [SRS-NFR-02/AC-01] The materialization proof output is human-reviewable terminal text. <!-- [SRS-NFR-02/AC-01] verify: just screen, SRS-NFR-02:start:end, proof: ac-2.log -->
