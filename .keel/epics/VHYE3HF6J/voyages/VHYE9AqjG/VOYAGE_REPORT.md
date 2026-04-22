# VOYAGE REPORT: Deliver Hosted Materialization Cursor And Resume Surface

## Voyage Metadata
- **ID:** VHYE9AqjG
- **Epic:** VHYE3HF6J
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 3/3 stories complete

## Implementation Narrative
### Add Hosted Materialization Cursor And Checkpoint Protocol Contract
- **ID:** VHYEATqz5
- **Status:** done

#### Summary
Define the hosted materialization progress contract by adding durable cursor primitives plus a hosted checkpoint envelope that bind external-daemon materializers to source stream identity, anchor position, and lineage-aware verification data.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] Hosted cursor primitives can create, inspect, advance, and delete materialization progress for a source stream and materialization identity. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log -->
- [x] [SRS-02/AC-01] The hosted checkpoint envelope carries materialization id, source stream id, source anchor position, lineage or manifest verification identity, opaque state bytes, and produced-at timestamp. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end, proof: ac-2.log -->
- [x] [SRS-NFR-01/AC-01] Cursor and checkpoint contracts preserve shared-engine lineage semantics and do not change authoritative append, read, or tail behavior. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log -->

#### Verified Evidence
- [ac-1.log](../../../../stories/VHYEATqz5/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VHYEATqz5/EVIDENCE/ac-2.log)
- [ac-3.log](../../../../stories/VHYEATqz5/EVIDENCE/ac-3.log)

### Implement Hosted Materialization Resume Flow In Transit Client
- **ID:** VHYEAUq0l
- **Status:** done

#### Summary
Implement the hosted resume path in `transit-client` so client-only Rust materializers can validate a hosted checkpoint or cursor, fetch only post-anchor records, and stay entirely on the `transit-server` boundary without `LocalEngine`.

#### Acceptance Criteria
- [x] [SRS-03/AC-01] Hosted resume validates the checkpoint or cursor anchor and returns only records after that anchor while rejecting lineage mismatches or missing anchors. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-1.log -->
- [x] [SRS-04/AC-01] `transit-client` exposes the canonical Rust workflow for hosted checkpoint, resume, and pending-record fetch without requiring `LocalEngine`. <!-- [SRS-04/AC-01] verify: manual, SRS-04:start, SRS-04:end, proof: ac-2.log -->
- [x] [SRS-NFR-02/AC-01] External-daemon consumers can stay on the hosted server/client boundary for the full materialization workflow. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-3.log -->

#### Verified Evidence
- [ac-1.log](../../../../stories/VHYEAUq0l/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VHYEAUq0l/EVIDENCE/ac-2.log)
- [ac-3.log](../../../../stories/VHYEAUq0l/EVIDENCE/ac-3.log)

### Publish Hosted Materialization Proof Coverage And Operator Guidance
- **ID:** VHYEAVyxL
- **Status:** done

#### Summary
Publish end-to-end proof coverage and operator guidance for hosted materialization so downstream teams can checkpoint opaque state, resume incrementally, and understand verification and failure behavior against a separate Transit daemon.

#### Acceptance Criteria
- [x] [SRS-05/AC-01] Proof coverage demonstrates hosted checkpoint, resume, and incremental replay against a separate `transit-server`. <!-- [SRS-05/AC-01] verify: manual, SRS-05:start, SRS-05:end, proof: ac-1.log -->
- [x] [SRS-NFR-03/AC-01] Operator-facing docs explain hosted checkpoint verification, resume semantics, and expected failure modes for client-only materializers. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-2.log -->

#### Verified Evidence
- [ac-1.log](../../../../stories/VHYEAVyxL/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VHYEAVyxL/EVIDENCE/ac-2.log)


