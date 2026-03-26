# Branch-Aware Materialization Proof Surface - Product Requirements

## Problem Statement

The branch-aware materialization kernel and Prolly Tree snapshots are landed but lack an end-to-end proof path through `just screen`. Without a shipped proof surface, materialization remains unverified at the mission level and processors cannot demonstrate checkpoint, resume, and snapshot behavior.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Exercise the materialization kernel end-to-end in the `just screen` proof path with checkpoint, resume, and Prolly Tree snapshot evidence. | Screen proof includes materialization steps with visible checkpoint and snapshot output | Materialization proof voyage completed |
| GOAL-02 | Demonstrate branch-aware materialization by proving that processors correctly handle branch and merge lineage. | At least one branch-aware materialization scenario exercised in the proof path | Branch-aware story accepted |
| GOAL-03 | Verify that materialization uses the same manifests, checkpoints, and lineage model as the core engine. | Materialization proof shares engine artifacts without a second storage model | Shared-model story accepted |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Core Transit Maintainer | The engineer proving that materialization works end-to-end for mission verification. | A traceable delivery plan for exercising checkpoint, resume, and snapshot behavior through the proof path. |
| Operator | The human proving progress through `just screen`. | Visible materialization evidence in the standard proof flow. |
| Stream Processor Builder | The engineer building derived state on top of transit's lineage-rich history. | Confidence that materialization handles branches, merges, checkpoints, and Prolly Tree snapshots correctly. |

## Scope

### In Scope

- [SCOPE-01] End-to-end materialization proof in the `just screen` path covering checkpoint creation, resume from checkpoint, and Prolly Tree snapshot production.
- [SCOPE-02] At least one branch-aware materialization scenario that processes events across branch and merge boundaries.
- [SCOPE-03] Proof that materialization artifacts (checkpoints, snapshots) use the same manifest and lineage model as the core engine.

### Out of Scope

- [SCOPE-04] Production-grade stream processing framework or user-facing processor API.
- [SCOPE-05] CRDT overlays or collaborative state merging beyond the current materialization kernel.
- [SCOPE-06] Distributed or multi-node materialization coordination.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Extend `just screen` to exercise materialization checkpoint creation after processing appended records. | GOAL-01 | must | Checkpoints are the materialization kernel's primary durability artifact and must be proven. |
| FR-02 | Extend `just screen` to exercise materialization resume from a prior checkpoint. | GOAL-01 | must | Resume semantics distinguish materialization from re-processing and must be demonstrated. |
| FR-03 | Extend `just screen` to exercise Prolly Tree snapshot production and inspection. | GOAL-01 | must | Prolly Trees are the snapshot format and must produce visible proof output. |
| FR-04 | Implement at least one branch-aware materialization scenario that processes events across branch or merge boundaries. | GOAL-02 | must | Branch-awareness is the core thesis of transit materialization. |
| FR-05 | Verify that materialization checkpoints and snapshots reference the same manifests and lineage model as the core engine. | GOAL-03 | should | Materialization must not create a parallel storage model. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Materialization proof output must be human-reviewable in terminal evidence. | GOAL-01, GOAL-02 | must | The screen proof path is the operator's primary review surface. |
| NFR-02 | Materialization must work with the same engine in embedded mode. | GOAL-03 | must | The shared-engine thesis requires materialization to not depend on server-only features. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Checkpoint creation | Screen proof exercising append then checkpoint | Story-level verification artifacts |
| Resume semantics | Screen proof exercising checkpoint then resume then continued processing | Accepted story evidence |
| Prolly Tree snapshots | Screen proof with snapshot inspection output | Accepted story evidence |
| Branch-aware processing | Branch/merge materialization scenario in proof path | Accepted story evidence |
| Shared model | Artifact inspection confirming manifest and lineage reuse | Accepted story evidence |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The landed materialization kernel is stable enough to build a proof surface without rework. | Proof work may need to fix underlying kernel behavior first. | Re-check during first voyage planning. |
| Prolly Tree snapshot inspection can produce meaningful terminal output without a dedicated viewer. | May need a minimal inspection command before the proof is credible. | Validate during story implementation. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should the materialization proof run as a separate screen step or integrate into the existing engine proof? | Epic owner | Open |
| What is the minimal branch-aware scenario that demonstrates the thesis without over-engineering the proof? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] `just screen` exercises materialization checkpoint, resume, and Prolly Tree snapshot with visible evidence.
- [ ] At least one branch-aware materialization scenario is exercised in the proof path.
- [ ] Materialization artifacts share the core engine's manifest and lineage model.
<!-- END SUCCESS_CRITERIA -->
