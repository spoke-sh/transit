# VOYAGE REPORT: Published Cutover Surface

## Voyage Metadata
- **ID:** VGn6zxceG
- **Epic:** VGn6PdlVK
- **Status:** done
- **Goal:** -

## Execution Summary
**Progress:** 1/1 stories complete

## Implementation Narrative
### Publish Canonical Downstream Cutover Contract
- **ID:** VGn7hHD5O
- **Status:** done

#### Summary
Refresh the upstream docs and client examples so downstream repos have one
published cutover target and clear instruction to delete private adapters
instead of preserving them.

#### Acceptance Criteria
- [x] [SRS-01/AC-01] The published runtime contract describes the canonical hosted endpoint grammar and runtime posture downstream repos should target. <!-- verify: manual, SRS-01:start:end -->
- [x] [SRS-02/AC-02] `transit-client` remains the documented Rust import surface for hosted consumers. <!-- verify: manual, SRS-02:start:end -->
- [x] [SRS-03/AC-03] Direct-cutover guidance explicitly tells downstream repos to remove duplicate private adapters rather than keep them as a compatibility lane. <!-- verify: manual, SRS-03:start:end -->

#### Verified Evidence
- [ac-1.log](../../../../stories/VGn7hHD5O/EVIDENCE/ac-1.log)
- [ac-2.log](../../../../stories/VGn7hHD5O/EVIDENCE/ac-2.log)
- [ac-3.log](../../../../stories/VGn7hHD5O/EVIDENCE/ac-3.log)


