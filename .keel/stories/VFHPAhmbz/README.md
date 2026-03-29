---
# system-managed
id: VFHPAhmbz
status: backlog
created_at: 2026-03-29T10:48:12
updated_at: 2026-03-29T10:50:41
# authored
title: Add Artifact Envelope Helper APIs
type: feat
operator-signal:
scope: VFHP6ptRw/VFHP9H1ZM
index: 3
---

# Add Artifact Envelope Helper APIs

## Summary

Add helper APIs for explicit artifact envelopes so embedded callers can publish summaries, backlinks, merge outcomes, and adjacent records without repeating envelope boilerplate.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] Provide helper builders or descriptors for explicit artifact envelopes used by summaries, backlinks, merge outcomes, or adjacent helper records. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end -->
- [ ] [SRS-03/AC-02] Keep references, digests, and subject metadata explicit without forcing one universal conversation schema. <!-- [SRS-03/AC-02] verify: manual, SRS-03:continues, SRS-03:end -->
- [ ] [SRS-NFR-03/AC-01] Preserve explicit artifact and replay semantics rather than hiding helper state in side tables. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end -->
