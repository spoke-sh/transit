# Deliver Per-Stream Retention Configuration And Visibility - SRS

## Summary

Epic: VHUAlZWZG
Goal: Let operators configure per-stream retention with no default policy, enforce age/size-based retention in the shared engine, and surface retention policy plus retained start offset in list and status outputs.

## Scope

### In Scope

- [SCOPE-01] Retention metadata that defaults to `none` and can carry optional maximum age in days and maximum retained bytes.
- [SCOPE-02] Stream creation surfaces for `--retention-max-age-days` and `--retention-max-bytes`.
- [SCOPE-03] Shared-engine enforcement that drops oldest eligible rolled segments under configured age and/or size limits.
- [SCOPE-04] Operator-visible list and status surfaces for configured retention and retained frontier state.
- [SCOPE-05] Documentation and proof coverage that explain bounded replay and the distinction from compaction.

### Out of Scope

- [SCOPE-06] Kafka-style key-aware compaction, tombstones, or latest-value semantics.
- [SCOPE-07] Any non-explicit global default such as `30 days` applied to all streams.
- [SCOPE-08] Partial trimming or in-place rewrite of the active segment.
- [SCOPE-09] GDPR selective erasure workflows beyond coarse-grained retention controls.

## Functional Requirements

<!-- BEGIN FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-01 | Add per-stream retention metadata that represents `none`, optional `max_age_days`, and optional `max_bytes`, with `none` preserved when no policy is configured. | SCOPE-01 | FR-01 | story: VHUAuqNpn |
| SRS-02 | Expose `--retention-max-age-days` and `--retention-max-bytes` on stream creation surfaces so operators can configure retention explicitly per stream. | SCOPE-02 | FR-02 | story: VHUAuqNpn |
| SRS-03 | Surface configured retention in `transit streams list` as `retention_age` and `retention_bytes` in human and JSON output. | SCOPE-04 | FR-04 | story: VHUAuqNpn |
| SRS-04 | Enforce retention in the shared engine by removing oldest eligible rolled segments under age and/or size limits while preserving the active segment. | SCOPE-03 | FR-03 | story: VHUAuquph |
| SRS-05 | Surface the retained frontier through stream status using `retained_start_offset` or an equivalent earliest-available field. | SCOPE-04 | FR-04 | story: VHUAuquph |
| SRS-06 | Publish proof coverage and operator guidance that explain bounded replay, retained-frontier semantics, and the distinction between retention and compaction. | SCOPE-05 | FR-05 | story: VHUAurAqP |
<!-- END FUNCTIONAL_REQUIREMENTS -->

## Non-Functional Requirements

<!-- BEGIN NON_FUNCTIONAL_REQUIREMENTS -->
| ID | Requirement | Scope | Source | Verification |
|----|-------------|-------|--------|--------------|
| SRS-NFR-01 | Unconfigured streams must preserve today’s `retention = none` behavior without any implicit age or size policy. | SCOPE-01, SCOPE-02 | NFR-01 | story: VHUAuqNpn |
| SRS-NFR-02 | Retention behavior must remain shared-engine semantics that work the same in embedded and hosted modes. | SCOPE-03, SCOPE-04 | NFR-02 | story: VHUAuquph |
| SRS-NFR-03 | Retention enforcement must stay append-only within retained history by trimming only whole rolled segments and never compacting keys or rewriting the active segment. | SCOPE-03 | NFR-03 | story: VHUAuquph |
| SRS-NFR-04 | Operator-facing docs and proof coverage must describe bounded replay and clearly distinguish retention from compaction semantics. | SCOPE-05 | NFR-03 | story: VHUAurAqP |
<!-- END NON_FUNCTIONAL_REQUIREMENTS -->
