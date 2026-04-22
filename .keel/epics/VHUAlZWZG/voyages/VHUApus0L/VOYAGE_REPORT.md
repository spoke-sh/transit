# VOYAGE REPORT: Deliver Per-Stream Retention Configuration And Visibility

## Voyage Metadata
- **ID:** VHUApus0L
- **Epic:** VHUAlZWZG
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 3/3 stories complete

## Implementation Narrative
### Add Per-Stream Retention Metadata And Create-Time Surface
- **ID:** VHUAuqNpn
- **Status:** done

#### Summary
Add the explicit per-stream retention policy model, thread it through stream creation surfaces, and surface configured retention age/bytes in `transit streams list` without changing the default `retention = none` behavior.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] Stream metadata can represent `retention = none` plus optional `max_age_days` and `max_bytes` without changing existing unconfigured streams. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log -->
- [x] [SRS-02/AC-01] Stream creation surfaces accept `--retention-max-age-days` and `--retention-max-bytes` so retention is configured explicitly per stream. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end, proof: ac-2.log -->
- [x] [SRS-03/AC-01] `transit streams list` shows `retention_age` and `retention_bytes` in human and JSON output for each stream. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-3.log -->
- [x] [SRS-NFR-01/AC-01] Streams without an explicit retention policy continue to behave as `retention = none`; no implicit `30 day` default is introduced. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-4.log -->

### Enforce Retention And Surface Retained Frontier Status
- **ID:** VHUAuquph
- **Status:** done

#### Summary
Enforce age- and size-based retention in the shared engine by trimming only oldest eligible rolled segments, then expose the retained frontier through stream status so bounded replay is visible to operators and downstream tooling.

#### Acceptance Criteria
- [x] [SRS-04/AC-01] The shared engine trims oldest eligible rolled segments under configured age and/or size limits without touching the active segment. <!-- [SRS-04/AC-01] verify: manual, SRS-04:start, SRS-04:end, proof: ac-1.log -->
- [x] [SRS-05/AC-01] Stream status exposes `retained_start_offset` or an equivalent earliest-retained field so callers can see where replayable history begins. <!-- [SRS-05/AC-01] verify: manual, SRS-05:start, SRS-05:end, proof: ac-2.log -->
- [x] [SRS-NFR-02/AC-01] Retention logic remains shared-engine behavior across embedded and hosted surfaces instead of becoming a server-only lifecycle rule. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log -->
- [x] [SRS-NFR-03/AC-01] Retention enforcement remains coarse-grained lifecycle management rather than compaction: retained history stays append-only and no individual retained records are rewritten. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-4.log -->

### Publish Retention Proof Coverage And Operator Guidance
- **ID:** VHUAurAqP
- **Status:** done

#### Summary
Publish proof coverage and operator guidance for retention so create/list/status behavior, bounded replay, and the distinction from compaction remain explicit and testable.

#### Acceptance Criteria
- [x] [SRS-06/AC-01] The proof path exercises retention-aware create/list/status behavior and records evidence for bounded replay surfaces. <!-- [SRS-06/AC-01] verify: manual, SRS-06:start, SRS-06:end, proof: ac-1.log -->
- [x] [SRS-06/AC-02] Operator guidance explains that retention is coarse-grained history aging, not Kafka-style compaction or selective erasure. <!-- [SRS-06/AC-02] verify: manual, SRS-06:continues, SRS-06:end, proof: ac-2.log -->
- [x] [SRS-NFR-04/AC-01] Public guidance names the retained frontier and bounded replay consequences so operators can reason about cursor and replay fallout. <!-- [SRS-NFR-04/AC-01] verify: manual, SRS-NFR-04:start, SRS-NFR-04:end, proof: ac-3.log -->


