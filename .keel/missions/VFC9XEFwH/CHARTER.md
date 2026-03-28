# Refine Transit Docs Link Underlines - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Replace the light blue public-docs link underline with a less distracting treatment that still keeps links clearly legible and intentional inside the Transit docs theme. | board: VFC9XEYwI |

## Constraints

- Limit the change to docs link decoration and closely related shared docs CSS; do not reopen the broader theme work.
- Preserve clear link affordance for readers scanning foundational docs and MDX pages.
- Keep the existing docs build workflow and route structure intact.

## Halting Rules

- DO NOT halt while `MG-01` has unfinished board work or while the bright underline treatment remains in place.
- HALT when `MG-01` is satisfied, the docs build passes, and `keel doctor` reports no blocking board-health errors.
- YIELD to human only if link affordance and preferred color direction conflict in a way that cannot be resolved from repo context.
