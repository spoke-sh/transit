# Publish Embedded Lineage Helper Surface - SRS

## Summary

Epic: VFHP6ptRw
Goal: Expose stable embedded helper surfaces for branch metadata, root-plus-branch replay/materialization inspection, artifact envelopes, and checkpoint-resume workflows while keeping conversation policy out of Transit core.

## Scope

### In Scope

- [SCOPE-01] Stable helper APIs for branch metadata and lineage labels built on `LineageMetadata` and branch-point semantics.
- [SCOPE-02] Embedded replay or materialization views for ancestry-aware root-plus-branch inspection.
- [SCOPE-03] Artifact-envelope helper APIs for summaries, backlinks, merge outcomes, and adjacent explicit artifacts.
- [SCOPE-04] Checkpoint and replay ergonomics for embedded applications that build stateful conversation or agent layers above Transit.
- [SCOPE-05] Proof, example, or documentation coverage that demonstrates the helper layer without encoding product-specific conversation rules.

### Out of Scope

- [SCOPE-06] Paddles-specific classifier policy, moderation logic, or auto-threading defaults.
- [SCOPE-07] Server-only query or UI features that bypass the shared engine surface.
- [SCOPE-08] One universal schema for every communication-level artifact body or application domain built on Transit.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Provide stable helper APIs for branch metadata so embedded callers can construct and inspect branch lineage labels without manually assembling ad hoc key conventions. | SCOPE-01 | FR-01 | manual |
| SRS-02 | Provide embedded replay or materialization views that make root-plus-branch inspection ancestry-aware and easy to consume. | SCOPE-02 | FR-02 | manual |
| SRS-03 | Provide artifact-envelope helper APIs for summaries, backlinks, merge outcomes, and related explicit artifacts on top of Transit’s existing envelope contracts. | SCOPE-03 | FR-03 | manual |
| SRS-04 | Provide checkpoint and replay helper ergonomics that let embedded applications resume or inspect branch-aware state without hidden mutable side data. | SCOPE-04, SCOPE-05 | FR-04 | manual |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | The voyage must preserve Transit as a general lineage substrate and avoid hardcoding paddles-specific conversation policy into the helper layer. | SCOPE-01, SCOPE-03, SCOPE-04 | NFR-01 | manual |
| SRS-NFR-02 | The helper surfaces must preserve shared-engine embedded/server semantics, including lineage, replay, checkpoint, and storage behavior. | SCOPE-01, SCOPE-02, SCOPE-04 | NFR-02 | manual |
| SRS-NFR-03 | Artifact, summary, backlink, merge, and checkpoint helpers must remain explicit and replayable rather than relying on hidden side tables or mutable caches. | SCOPE-02, SCOPE-03, SCOPE-04 | NFR-03 | manual |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
