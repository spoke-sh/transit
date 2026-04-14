# Hosted Transit Authority For External Workloads And Derived State - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Make hosted Transit the authoritative append, replay, and projection substrate for external workload messages so downstream control planes stop treating local embedded storage as the source of truth for domain-owned state. | board: VGh59soBt |

## Constraints

- Preserve the one-engine thesis: embedded and server modes must continue to share lineage, manifest, and checkpoint semantics even as server mode becomes the hosted authority.
- Keep durability explicit. Any server acknowledgement or operator proof must state whether the outcome is `local` or `tiered`; do not overclaim tiered safety before object-store publication completes.
- Do not bake consumer-owned business policy into Transit core. Downstream
  workloads may shape examples and proof fixtures, but domain rules and schema
  ownership stay in the consumer.
- Treat materialized reference views as replaceable read models derived from authoritative streams and checkpoints, not hidden mutable server truth.
- Keep object storage authoritative for long-term durability once the hosted path claims `tiered`; warm filesystem state is cache and working set, not the only serious persistence path.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- HALT when epic `VGh59soBt` is complete, mission verification is recorded, and `keel doctor` reports no blocking board-health errors
- YIELD to human when a decision would force Transit to absorb consumer-owned domain policy, weaken durability claims, or diverge embedded and server semantics
