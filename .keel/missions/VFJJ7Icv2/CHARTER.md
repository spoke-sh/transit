# Document Controlled Failover Semantics - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Publish a consistent controlled failover contract across the foundational documents and public MDX guides so operators and first-time users see the shipped proof surface, readiness boundary, handoff semantics, former-primary fencing, and the explicit non-claims around `local`, `replicated`, `tiered`, quorum, and multi-primary behavior. | board: VFJJ7J3v5 |

## Constraints

- Preserve the shared-engine model and avoid server-only semantics.
- Do not overclaim failover automation, quorum acknowledgement, or multi-primary behavior.
- Keep the foundational documents and public MDX pages aligned on one vocabulary and one proof path.

## Halting Rules

- DO NOT halt while the controlled failover contract is still inconsistent between the foundational docs, public MDX guides, and synced reference docs.
- HALT when epic `VFJJ7J3v5` is complete and the docs build proves the updated public artifact.
- YIELD to the human only if the requested wording would change the shipped failover semantics instead of documenting them.
