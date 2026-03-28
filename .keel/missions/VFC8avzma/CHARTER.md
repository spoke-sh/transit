# Improve Transit Docs Diagram Contrast - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Raise the contrast and legibility of the Transit Network Shape hero diagram so first-time readers can read the monospace panel comfortably without changing the broader docs route structure or theme identity. | board: VFC8awXmb |

## Constraints

- Limit the implementation to the hero panel and closely related homepage styling; do not reopen the broader docs theme work.
- Preserve the current subway-theme direction and docs information architecture.
- Keep the fix compatible with the existing `just docs-build` workflow.

## Halting Rules

- DO NOT halt while `MG-01` has unfinished board work or while the diagram remains difficult to read.
- HALT when `MG-01` is satisfied, the docs build passes, and `keel doctor` reports no blocking board-health errors.
- YIELD to human only if the readability issue turns out to require broader visual redesign rather than a focused panel fix.
