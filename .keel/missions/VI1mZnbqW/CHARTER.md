# Productionize Transit Downstream Application Surfaces - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Deliver production-grade replay and materialization surfaces so downstream applications can consume bounded history, resume from rich checkpoints, and reuse verified snapshots without side stores or full-history scans. | board: VI1mae3rd |
| MG-02 | Publish typed workload SDK surfaces for AI traces, conversational lineage, artifacts, backlinks, summaries, and merge metadata so downstream applications stop hand-assembling generic labels. | board: VI1mbSnsy |
| MG-03 | Harden hosted authority semantics around auth, lease fencing, and finality/fork proof contracts so durable external systems can evaluate Transit for production authority and blockchain-style workflows. | board: VI1mcFKum |

## Constraints

- Preserve one shared engine model across embedded and server mode.
- Preserve immutable acknowledged history; derived state and finality markers must be explicit artifacts, never in-place rewrites.
- Preserve object-store-native history and manifest semantics.
- Preserve literal durability language in every acknowledgement, benchmark, and downstream contract.
- Keep downstream application schemas outside Transit core while publishing typed helper APIs for Transit-owned lineage vocabulary.

## Halting Rules

- HALT if a planned implementation would create server-only stream semantics that bypass `transit-core`.
- HALT if a typed workload helper requires mutating acknowledged records or hiding lineage in app-local side tables.
- HALT if hosted authority hardening would overclaim auth, consensus, or finality guarantees beyond implemented proof coverage.
- HALT when all MG-* goals with `board:` verification are satisfied.
