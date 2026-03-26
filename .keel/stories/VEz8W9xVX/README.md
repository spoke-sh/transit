---
# system-managed
id: VEz8W9xVX
status: backlog
created_at: 2026-03-26T07:49:09
updated_at: 2026-03-26T08:05:36
# authored
title: Integrate Materialization Proof Into Just Screen Flow
type: feat
operator-signal:
scope: VEz2huKbt/VEz3VMCrg
index: 4
---

# Integrate Materialization Proof Into Just Screen Flow

## Summary

Add the `materialization-proof` mission command as a step in the `just screen` recipe.

## Acceptance Criteria

- [ ] [SRS-06/AC-01] `just screen` includes a "materialization proof" step that runs `transit mission materialization-proof` and reports pass/fail. <!-- [SRS-06/AC-01] verify: just screen, SRS-06:start:end -->
- [ ] [SRS-NFR-02/AC-01] The materialization proof output is human-reviewable terminal text. <!-- [SRS-NFR-02/AC-01] verify: just screen, SRS-NFR-02:start:end -->
