# Strengthen Embedded Branch Metadata Replay Views And Artifact Helpers - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Deliver a verified embedded helper surface where apps can attach stable branch metadata, inspect root-plus-branch replay and materialization state, publish artifact envelopes for summaries/backlinks/merge outcomes, and resume from checkpoints without baking paddles-specific conversation policy into Transit core. | board: VFHP6ptRw |

## Constraints

- Preserve Transit as a general lineage substrate; do not hardcode conversational product policy, classifier heuristics, or paddles-specific schema into core APIs.
- Preserve the shared engine thesis so embedded and server usage continue to rely on the same lineage, replay, checkpoint, and storage semantics.
- Keep summaries, backlinks, merge outcomes, and checkpoint state explicit and replayable through stable helper contracts rather than hidden side tables or mutable caches.

## Halting Rules

- DO NOT halt while `MG-01` has unfinished board work or while helper design still blurs the boundary between Transit substrate APIs and higher-level conversation behavior.
- HALT when `MG-01` is satisfied and `keel doctor` reports no blocking board-health errors.
- YIELD to human when the next step requires product direction on which conversation-layer conventions belong in paddles versus Transit.
