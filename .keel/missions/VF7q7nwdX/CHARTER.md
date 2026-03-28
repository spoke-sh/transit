# Launch Transit Public Docs And First-Run Onramp - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Launch a public-facing documentation surface that helps first-time users understand Transit as both an embedded library and a networked server, using a transport-native narrative and a runnable first-run path rather than only internal repo contracts. | board: VF7qPMy1g |

## Constraints

- Preserve the one-engine thesis: embedded and server mode must be explained as two packaging modes over shared storage semantics, not as separate products.
- Keep durability, lineage, and object-storage boundaries explicit in public docs; do not market away the actual guarantees.
- Publish the foundational repo documents alongside the new public guides so narrative docs and canonical contracts stay aligned.
- The first docs launch must be deployable as static output suitable for S3 and CloudFront hosting.

## Halting Rules

- DO NOT halt while `MG-01` has unfinished board work or while first-time users still need repo archaeology to understand the basic product shape.
- HALT when `MG-01` is satisfied and `keel doctor` reports no blocking board-health errors.
- YIELD to human when branding, positioning, or deployment-environment details require product direction that cannot be resolved from repo context.
