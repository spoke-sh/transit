# Add Spoke Link To Docs Header - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Add a `Spoke` header link in the public docs navbar immediately to the left of `GitHub`, matching the upstream Spoke-site navigation pattern without disturbing the existing docs workflow. | board: VFCNI3lfw |

## Constraints

- Limit the implementation to docs header navigation configuration and closely related generated board state.
- Use the upstream Keel docs precedent for both label and target URL.
- Keep the existing docs build workflow and current Transit routes intact.

## Halting Rules

- DO NOT halt while `MG-01` has unfinished board work or while the public docs header still lacks the `Spoke` link.
- HALT when `MG-01` is satisfied, the docs build passes, and `keel doctor` reports no blocking board-health errors.
- YIELD to human only if the requested `Spoke` target or placement conflicts with other repo-local header constraints.
