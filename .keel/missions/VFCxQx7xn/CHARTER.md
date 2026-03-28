# Improve Hero Diagram Legibility And Width - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Make the `Transit Network Shape` hero panel readable at first glance by raising lineage contrast and aligning the four linked route items below it to the same usable width as the lineage box. | board: VFCxQxWxm |

## Constraints

- Limit the work to the homepage hero panel and closely related generated board state.
- Preserve the existing Transit docs theme, copy, and hero structure.
- Keep the route links below the diagram intact while making their width visually consistent with the lineage panel.

## Halting Rules

- DO NOT halt while `MG-01` has unfinished board work or while the hero panel remains hard to read or visibly misaligned.
- HALT when `MG-01` is satisfied, `just docs-build` passes, and `keel doctor` reports no blocking board-health errors.
- YIELD to human only if the requested hero-card legibility or width change conflicts with the current Transit docs visual direction.
