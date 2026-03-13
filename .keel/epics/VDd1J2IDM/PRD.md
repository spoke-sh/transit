# Research Multi-Node Replication And Server Semantics - Product Requirements

> The repo says embedded and server are packaging choices on one engine, but it also explicitly defers distributed consensus and cross-node replication. This bearing exists to turn that into an explicit staging plan so server mode can move forward without premature distributed design.

## Problem Statement

`transit` has now proven two critical foundations: the durable local engine and the first networked single-node server. What it still lacks is a clear replication plan that preserves one engine, explicit lineage, explicit durability, and object-storage-native history. If replication work begins without that plan, the project risks inventing server-only storage behavior, blurring local versus replicated acknowledgements, or taking on consensus and multi-writer semantics too early. This epic exists to define the next staged step for replication and clustered server behavior without collapsing the current model into distributed hand-waving.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Define the first staged replication model that extends the proven single-node server without breaking the shared-engine thesis. | Replication model documented and scoped | Initial replication epic planned |
| GOAL-02 | Define the invariants future replicated work must preserve around ordering, durability, lineage, and storage. | Invariants captured in requirements and future voyages | Architecture constraints published |
| GOAL-03 | Bound replication scope so future delivery can start with leader-follower or segment/manifest shipping instead of jumping straight to consensus. | Scope and exclusions made explicit | First replication voyage planned |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Core Transit Maintainer | Extends the proven local and single-node server foundations | A replication plan that preserves one engine and explicit durability semantics |
| Operator | Runs `transit` beyond one node | A staged clustered model with explicit local versus replicated guarantees |
| Product/Delivery Owner | Coordinates the next delivery track after single-node server completion | A bounded replication epic instead of a vague distributed wish list |

## Scope

### In Scope

- [SCOPE-01] Define the first replication/clustered-server design center that builds on the proven single-node server.
- [SCOPE-02] Decide the first replication unit and operational shape, such as segment shipping, manifest replication, or single-writer leader-follower ownership.
- [SCOPE-03] Define the invariants future replicated work must preserve around ordering, durability, lineage, and object storage.
- [SCOPE-04] Bound the next delivery mission so it stays below consensus, multi-primary, and general distributed scheduling complexity.

### Out of Scope

- [SCOPE-05] Designing or implementing full distributed consensus in this epic.
- [SCOPE-06] Multi-writer or multi-primary semantics.
- [SCOPE-07] Server-only storage formats, branch models, or lineage rules.
- [SCOPE-08] Browser/public transport and client UX work unrelated to clustered server behavior.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Define the first staged replication model that extends the shared engine and proven single-node server without introducing a second storage implementation. | GOAL-01, GOAL-02 | must | Replication work must preserve the one-engine thesis from the start. |
| FR-02 | Define the first replication unit and ownership model explicitly, including the tradeoffs between segment shipping, manifest replication, and leader-follower stream-head ownership. | GOAL-01, GOAL-03 | must | The next delivery step needs one concrete design center instead of generic distributed ambition. |
| FR-03 | Define explicit durability and acknowledgement boundaries for future clustered operation, including what remains local, what becomes replicated, and what stays tiered/object-store-backed. | GOAL-02, GOAL-03 | must | Replication should clarify guarantees, not blur them. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | Preserve ordering, lineage, and object-storage invariants from the proven local and single-node server model. | GOAL-01, GOAL-02 | must | Replication cannot invalidate the architectural core. |
| NFR-02 | Keep the initial clustered scope explicitly below consensus, quorum writes, and multi-primary semantics. | GOAL-01, GOAL-03 | must | The next step needs to be deliverable, not speculative. |
| NFR-03 | Keep durability and acknowledgement language explicit enough for operators to distinguish local, replicated, and tiered guarantees. | GOAL-02, GOAL-03 | must | Clustered behavior must not hide its actual commitment boundary. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

- Prove the epic by decomposing it into voyages that explicitly capture replication model, durability/acknowledgement semantics, and clustered restore/catch-up behavior.
- Validate the architectural boundaries by keeping server-only storage drift, implicit multi-writer semantics, and premature consensus out of scope.
- Re-run `keel doctor` and `keel flow` after decomposition so the new epic remains coherent with the finished research and server missions.

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| The proven single-node server is stable enough to act as the baseline for future clustered semantics | Replication planning may need to revisit server contracts first | Re-check against the completed server epic before starting the first voyage |
| Replication can begin with a staged single-writer model rather than requiring immediate consensus or multi-primary behavior | The first clustered mission may still be too large | Validate during voyage planning |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Which replication unit should anchor the first clustered implementation: segments, manifests, or stream-head ownership? | Architecture | Open |
| How should follower catch-up and object-store restore interact in the first clustered design? | Architecture | Open |
| Which acknowledgement modes should exist before any replicated deployment is called credible? | Architecture | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Separate the completed single-node server work from the next replicated-system mission without weakening the one-engine thesis.
- [ ] Name the ordering, durability, lineage, and storage invariants that a future replicated design must preserve.
- [ ] Bound the initial clustered scope below consensus and multi-primary semantics so the next delivery mission stays tractable.
<!-- END SUCCESS_CRITERIA -->

## Research Analysis

*From bearing assessment:*

### Findings

- The evidence strongly supports a staged recommendation: proceed on server semantics that wrap the shared engine, but keep full replication explicitly downstream of the single-node and tiered-storage milestones [SRC-01] [SRC-02] [SRC-04].
- The constitution rules out any server or replication path that invents a second database or hides multi-writer semantics behind vague claims [SRC-03].

### Opportunity Cost

Pulling distributed design forward would dilute the current kernel mission, and premature replication abstractions would likely be anchored to unstable local semantics [SRC-02] [SRC-04].

### Dependencies

- A stable single-node engine, explicit durability modes, and concrete manifest behavior are prerequisites for any meaningful server or replication design [SRC-02] [SRC-03] [SRC-04].

### Alternatives Considered

- Jump directly to replicated multi-node design, but that would violate the repo’s current sequencing and force distributed assumptions before the base engine semantics are proven [SRC-02] [SRC-04].

---

*This PRD was seeded from bearing `VDd1J2IDM`. See `bearings/VDd1J2IDM/` for original research.*
