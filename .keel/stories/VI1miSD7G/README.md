---
# system-managed
id: VI1miSD7G
status: done
created_at: 2026-04-27T14:08:01
updated_at: 2026-04-27T14:46:40
# authored
title: Add Typed Communication Threading Builders
type: feat
operator-signal:
scope: VI1mbSnsy/VI1mf8o0n
index: 1
started_at: 2026-04-27T14:40:46
submitted_at: 2026-04-27T14:46:37
completed_at: 2026-04-27T14:46:40
---

# Add Typed Communication Threading Builders

## Summary

Add typed communication helpers for channel, thread, backlink, summary, classifier, and human override artifacts over Transit lineage primitives.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Typed builders cover channel messages, thread branches, thread replies, backlinks, summaries, classifier evidence, and human override artifacts. <!-- [SRS-01/AC-01] verify: cargo test -p transit-core typed_builders_cover_communication_contract_shapes -- --nocapture, SRS-01:start, SRS-01:end, proof: ac-1.log-->
- [x] [SRS-NFR-02/AC-01] Communication helper output is ordinary Transit payload bytes plus lineage or artifact metadata and works through embedded and hosted APIs. <!-- [SRS-NFR-02/AC-01] verify: cargo test -p transit-core communication_helpers_work_through_embedded_and_hosted_apis -- --nocapture && cargo test -p transit-client communication -- --nocapture, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-2.log-->
- [x] [SRS-NFR-01/AC-01] Helper APIs keep application authorization, moderation, and account policy outside Transit-owned types. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log-->
