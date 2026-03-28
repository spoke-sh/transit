# Remove Blue Hover Link Underline - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Remove the blue hover underline/link hover accent from markdown docs content so link hover states feel consistent with the intended Transit treatment. | board: VFCAdyu9b |

## Constraints

- Limit the change to markdown link hover treatment in shared docs CSS.
- Preserve clear hover affordance and the existing docs build workflow.
- Do not reopen broader palette or layout work for this slice.

## Halting Rules

- DO NOT halt while `MG-01` has unfinished board work or while markdown hover links still read blue.
- HALT when `MG-01` is satisfied, the docs build passes, and `keel doctor` reports no blocking board-health errors.
- YIELD to human only if removing the blue hover accent conflicts with link affordance in a way repo context cannot resolve.
