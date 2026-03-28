# Repair Docs Header Layout Regression - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Restore the public docs header so it remains full-width, does not overlap the page body, and keeps the `Spoke` link available without wrapping the desktop shell. | board: VFCvzGZeD |

## Constraints

- Preserve the current Transit docs visual language and the upstream-inspired navbar shell.
- Preserve the `Spoke` link immediately to the left of `GitHub`.
- Prefer a responsive handoff to the mobile navbar over any solution that lets desktop items wrap into the body.

## Halting Rules

- DO NOT halt while `MG-01` has unfinished board work or while the docs header still wraps or overlaps page content.
- HALT when `MG-01` is satisfied, the docs build passes, and `keel doctor` reports no blocking board-health errors.
- YIELD to human only if the requested navbar repair conflicts with the existing Transit docs navigation model.
