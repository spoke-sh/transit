# Add Per-Stream Retention Policies And Retained Frontier Semantics - Product Requirements

## Problem Statement

Transit needs explicit per-stream retention controls for age- and size-bounded history, plus stream status surfaces that show configured retention and the retained frontier, without changing the default append-only behavior.

## Goals & Objectives

| ID | Goal | Success Metric | Target |
|----|------|----------------|--------|
| GOAL-01 | Let operators configure per-stream retention explicitly while keeping Transit’s default history-unbounded behavior unchanged. | Targeted tests and CLI proof coverage show `stream create`, `streams list`, and stream status surfaces preserve `retention = none` by default and expose explicit age/size retention when configured. | Voyage `VHUApus0L` planned |

## Users

| Persona | Description | Primary Need |
|---------|-------------|--------------|
| Transit Operator | Engineer running Transit as shared infrastructure for applications with bounded-retention requirements. | A first-class way to set per-stream age or size retention without accidentally changing every stream’s replay contract. |
| Downstream Application Engineer | Engineer creating streams that should retain history indefinitely by default but may require bounded replay for selected workloads. | Stream creation and inspection surfaces that make retention policy explicit and predictable. |
| Transit Maintainer | Engineer responsible for preserving shared-engine semantics and operator clarity. | A retention design that stays distinct from compaction and surfaces retained-frontier behavior explicitly. |

## Scope

### In Scope

- [SCOPE-01] Per-stream retention metadata with optional `max_age_days` and `max_bytes`, defaulting to no retention when unset.
- [SCOPE-02] Stream creation surfaces that accept `--retention-max-age-days` and `--retention-max-bytes`.
- [SCOPE-03] Shared-engine retention enforcement that removes oldest eligible rolled segments while preserving the active segment.
- [SCOPE-04] Stream inspection surfaces that expose configured retention and the retained frontier via `retained_start_offset` or equivalent earliest-available status.
- [SCOPE-05] Documentation and proof coverage that explain bounded replay and distinguish retention from compaction.

### Out of Scope

- [SCOPE-06] Key-aware log compaction, tombstones, or Kafka-style latest-value retention.
- [SCOPE-07] Any global default retention window such as `30 days` applied implicitly to all streams.
- [SCOPE-08] Partial trimming or in-place rewrite of the active segment.
- [SCOPE-09] Selective subject erasure or GDPR workflow claims beyond coarse-grained retention controls.

## Requirements

### Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| FR-01 | Add per-stream retention metadata that can represent `none`, optional maximum age in days, and optional maximum retained bytes, with no retention applied when the policy is absent. | GOAL-01 | must | Retention must be explicit and opt-in so Transit does not silently change its default replay semantics. |
| FR-02 | Expose retention policy at stream creation time through CLI and supporting engine/protocol surfaces using `--retention-max-age-days` and `--retention-max-bytes`. | GOAL-01 | must | Operators need a practical way to configure retention when streams are created. |
| FR-03 | Enforce retention in the shared engine by removing oldest eligible rolled segments under age and/or size limits while preserving append-only behavior for the active segment. | GOAL-01 | must | The retention model should bound stored history without inventing a compaction semantic. |
| FR-04 | Surface configured retention in `transit streams list` and expose the retained frontier through stream status using `retained_start_offset` or an equivalent earliest-available field. | GOAL-01 | must | Once replay becomes bounded, operators need explicit visibility into policy and the earliest retained offset. |
| FR-05 | Publish proof coverage and operator guidance that explain bounded replay, retained-frontier semantics, and the distinction between retention and compaction. | GOAL-01 | must | This feature changes operator expectations about replay availability and needs explicit guidance. |
<!-- END FUNCTIONAL_REQUIREMENTS -->

### Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Goals | Priority | Rationale |
|----|-------------|-------|----------|-----------|
| NFR-01 | The default retention posture must remain `none`; unconfigured streams must preserve today’s history-unbounded behavior. | GOAL-01 | must | A hidden default retention window would silently change Transit’s core replay contract. |
| NFR-02 | Retention must remain shared-engine semantics that behave the same in embedded and hosted modes. | GOAL-01 | must | This repository does not allow server-only storage semantics to bypass the shared engine model. |
| NFR-03 | Retention must stay semantically distinct from compaction: no key-aware collapse, no latest-value projection, and no in-place mutation of retained records. | GOAL-01 | must | Operators need a clear contract that bounded replay does not imply Kafka-style compaction. |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->

## Verification Strategy

| Area | Method | Evidence |
|------|--------|----------|
| Retention creation surface | Targeted CLI and engine tests for retention metadata plus create-time flags | Story-level evidence under voyage `VHUApus0L` |
| Retention enforcement | Targeted shared-engine tests for age/size trimming and retained frontier behavior | Story-level evidence under voyage `VHUApus0L` |
| Operator visibility | CLI proof coverage and docs review for list/status retention fields and bounded replay guidance | Story-level evidence under voyage `VHUApus0L` |

## Assumptions

| Assumption | Impact if Wrong | Validation |
|------------|-----------------|------------|
| Retention can be delivered by trimming oldest rolled segments without introducing key-aware compaction semantics. | The epic could drift into a broader storage rewrite or compaction design. | Validate in SDD and story contracts that the active segment remains untouched and retained history stays append-only. |
| Stream status surfaces are sufficient to communicate replay bounds if they expose retention policy and retained frontier explicitly. | Operators may still misread bounded replay as silent data loss. | Validate through proof/docs coverage and user-facing field naming. |

## Open Questions & Risks

| Question/Risk | Owner | Status |
|---------------|-------|--------|
| Should the public field name be `earliest_offset` or `retained_start_offset` on the status surface? | Epic owner | Open |
| How should cursor validation behave once a cursor falls behind the retained frontier? | Epic owner | Open |
| What deterministic enforcement point should own retention trimming: append, recovery, explicit maintenance step, or a combination? | Epic owner | Open |

## Success Criteria

<!-- BEGIN SUCCESS_CRITERIA -->
- [ ] Streams default to no retention unless an explicit policy is configured.
- [ ] `transit stream create` exposes `--retention-max-age-days` and `--retention-max-bytes`.
- [ ] `transit streams list` exposes configured `retention_age` and `retention_bytes`.
- [ ] Stream status exposes the earliest retained frontier via `retained_start_offset` or equivalent.
- [ ] Shared-engine retention enforcement trims oldest eligible rolled segments under configured limits without changing the active append path into compaction.
<!-- END SUCCESS_CRITERIA -->
