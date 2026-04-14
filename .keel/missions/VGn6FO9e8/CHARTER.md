# Hosted Tiered Transit Runtime And Published Consumer Surface - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Hosted Transit can boot from authored object-store configuration instead of rejecting non-local durability at startup. | board: VGn6PdlVK |
| MG-02 | Hosted Transit only claims durability and storage guarantees that the running server actually satisfies, including authoritative warm-cache recovery from remote storage. | board: VGn6PdlVK |
| MG-03 | Downstream consumers can cut over directly onto the upstream runtime and client surface without retaining a second protocol or private adapter contract. | board: VGn6PdlVK |

## Constraints

- Keep Transit generic; do not introduce consumer-specific schema, auth
  business policy, or downstream product vocabulary into the runtime.
- A hosted tiered server must treat object storage as the authority and local
  filesystem paths as warm working state plus cache, not as a second durable
  source of truth.
- Do not overclaim runtime guarantees. If a provider, auth posture, or
  durability path is only configured and not fully proven, the docs and ack
  surfaces must say so explicitly.
- This mission exists to enable direct downstream cutover. Do not preserve a
  second hosted protocol lineage or transitional compatibility layer inside
  Transit.

## Halting Rules

- DO NOT halt while any voyage under epic `VGn6PdlVK` has unfinished stories.
- DO NOT halt while hosted server bootstrap still rejects authored
  object-store durability or downstream repos still lack an upstream cutover
  target they can consume directly.
- HALT when all MG-* goals with `board:` verification are satisfied.
- YIELD to human if object-store rollout posture requires a product decision
  beyond generic substrate semantics or if a requested cutover would force
  consumer-specific behavior into Transit.
