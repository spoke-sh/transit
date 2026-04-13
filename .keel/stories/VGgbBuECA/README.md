---
id: VGgbBuECA
title: Adopt Keel Screen In Just Screen
type: feat
status: done
created_at: 2026-04-13T15:41:38
updated_at: 2026-04-13T08:52:22
index: 1
operator-signal: pulse
started_at: 2026-04-13T08:43:49
submitted_at: 2026-04-13T08:52:14
completed_at: 2026-04-13T08:52:22
---

<!-- keel:pulse-materialization: adopt-keel-screen-in-just-screen@2026-05-01T16:00:00Z -->

# Adopt Keel Screen In Just Screen

## Summary

Materialized from routine `adopt-keel-screen-in-just-screen` for eligible window ending `2026-05-01T16:00:00Z`.

## Acceptance Criteria

- [x] [SRS-ROUTINE/AC-01] Complete the authored routine blueprint for this eligible window. <!-- [SRS-ROUTINE/AC-01] verify: manual, SRS-ROUTINE:start, SRS-ROUTINE:end, proof: ac-1.log -->

## Routine Provenance

- Routine: `adopt-keel-screen-in-just-screen`
- Target scope: `VF7c7T2Hl`
- Eligible window ends: `2026-05-01T16:00:00Z`

## Blueprint

- Trigger this routine on every `keel` upgrade or whenever the operator-facing `Justfile` recipes change.
- Check whether `keel screen` is now a supported command and whether it is stable enough to replace the current `keel flow` fallback in `just screen`.
- If `keel screen` exists, update `Justfile` so `just screen` calls it directly, remove the compatibility probe, refresh the docs, and verify the board output remains clean and useful.
- Exit only when the preferred `keel` screen command is wired into the human-facing recipe or the fallback remains explicitly justified in the commit or change notes.
