# Verifiable Integrity Proof Surface - Product Requirements

## Problem Statement

Integrity primitives (segment checksums, manifest roots, lineage checkpoints) are landed but lack an end-to-end proof path through `just screen` with tamper-detection evidence. Without a shipped proof surface, the integrity work remains unverified at the mission level.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Exercise segment checksums, manifest roots, and lineage checkpoints end-to-end in the `just screen` proof path. | Screen proof includes integrity verification steps with pass/fail evidence | Integrity proof voyage completed |
| GOAL-02 | Demonstrate tamper detection by proving that corrupted segments or manifests are caught and reported. | At least one tamper-detection scenario exercised in the proof path | Tamper-detection story accepted |
| GOAL-03 | Verify that integrity surfaces work identically in embedded and server modes without contaminating the hot append path. | Integrity proof covers both embedded and networked engine paths | Shared-engine integrity story accepted |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Core Transit Maintainer | The engineer hardening the integrity surface for mission verification. | A traceable delivery plan for exercising checksums, manifests, and checkpoints through the proof path. |
| Operator | The human proving progress through `just screen`. | Visible integrity evidence in the standard proof flow without a separate toolchain. |
| Application Builder | The engineer relying on transit's immutable history guarantees. | Confidence that segment and manifest integrity is verified, not just assumed. |

## Scope

### In Scope

- [SCOPE-01] End-to-end integrity verification in the `just screen` proof path covering segment checksums, manifest roots, and lineage checkpoints.
- [SCOPE-02] At least one tamper-detection scenario that corrupts a segment or manifest and confirms the engine detects and reports the corruption.
- [SCOPE-03] Proof that integrity verification works through both the local engine and the networked server path.

### Out of Scope

- [SCOPE-04] Cryptographic signature infrastructure, key management, or external PKI integration.
- [SCOPE-05] Stage 2/3 hardening (Merkle Mountain Ranges, incremental witness proofs) beyond the current primitives.
- [SCOPE-06] Performance optimization of integrity verification on the hot append path.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Extend `just screen` to exercise segment checksum verification after local append and segment roll. | GOAL-01 | must | Segment checksums are the foundation of integrity and must be proven in the standard flow. |
| FR-02 | Extend `just screen` to exercise manifest root verification after publication to object storage. | GOAL-01 | must | Manifest roots bind segments to their published locations and must be verified end-to-end. |
| FR-03 | Extend `just screen` to exercise lineage checkpoint verification after branch and merge operations. | GOAL-01 | must | Checkpoints are the highest-level integrity artifact and must appear in the proof surface. |
| FR-04 | Implement at least one tamper-detection scenario that corrupts stored data and confirms detection. | GOAL-02 | must | Integrity without tamper evidence is a claim without proof. |
| FR-05 | Verify that integrity operations produce identical results through the local engine and networked server paths. | GOAL-03 | should | The shared-engine thesis requires integrity to work the same way in both modes. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Integrity verification must not add latency to the hot append path. | GOAL-01, GOAL-03 | must | Constitution principle: integrity attaches to segments, manifests, and checkpoints, not individual appends. |
| NFR-02 | Proof output must be human-reviewable in terminal evidence without external tooling. | GOAL-01, GOAL-02 | must | The screen proof path is the operator's primary review surface. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Segment checksums | Targeted tests plus screen proof flow | Story-level verification artifacts |
| Manifest roots | Publication and restore proof with root verification | Accepted story evidence |
| Lineage checkpoints | Branch/merge proof with checkpoint binding | Accepted story evidence |
| Tamper detection | Corruption injection and detection proof | Accepted story evidence |
| Shared-engine parity | Embedded and server mode proof comparison | Accepted story evidence |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The landed integrity primitives are stable enough to build a proof surface without rework. | Proof work may need to fix underlying primitives first. | Re-check during first voyage planning. |
| Tamper detection can be demonstrated with filesystem-level corruption without needing a dedicated fault-injection framework. | May need tooling work before the tamper scenario is credible. | Validate during story implementation. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Which specific corruption scenario is most valuable for the first tamper-detection proof? | Epic owner | Open |
| Should the screen proof verify integrity inline or as a separate verification pass? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] `just screen` exercises segment checksums, manifest roots, and lineage checkpoints with visible pass/fail evidence.
- [ ] At least one tamper-detection scenario is exercised and produces clear detection output.
- [ ] Integrity verification works through both embedded and networked engine paths.
<!-- END SUCCESS_CRITERIA -->
