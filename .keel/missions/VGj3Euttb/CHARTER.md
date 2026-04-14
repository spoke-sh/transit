# Upstream Hosted Consumer Interface For Direct Downstream Cutover - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Publish the canonical hosted consumer interface in Transit so downstream consumers stop owning duplicate endpoint, auth, acknowledgement, and client/runtime semantics. | board: VGj3EvcuK |

## Constraints

- Keep consumer-owned schema and business policy outside Transit core.
- Require a direct cutover from duplicate downstream runtime/client ownership
  onto the upstream contract; do not preserve a second protocol lineage or
  transitional interface layer.
- Do not silently bless a consumer-specific HTTP or bearer contract unless
  Transit adopts it as a generic hosted consumer surface.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- DO NOT halt while downstream repos still lack an upstream hosted consumer
  contract or direct-cutover proof they can cite.
- HALT when all MG-* goals with `board:` verification are satisfied.
- YIELD to human if the desired hosted interface would force Transit to own
  consumer-specific schema or policy, or if protocol posture needs a product
  decision beyond the current generic hosted-consumer boundary.
