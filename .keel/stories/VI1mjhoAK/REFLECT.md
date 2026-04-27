---
created_at: 2026-04-27T15:04:57
---

# Reflection - Enforce Hosted Auth Posture In Server Protocol

## Knowledge

<!--
Link existing knowledge files when the insight already exists:
- [123abcDEF](../../knowledge/123abcDEF.md) Existing knowledge title

Capture only novel/actionable knowledge that is likely useful in future work as
an inline candidate block. Unique entries are promoted into `.keel/knowledge/<id>.md`
on submit/accept.

If there is no reusable insight for this story, leave the Knowledge section empty.
Format:
### VI213GsNB: Title
| Field | Value |
|-------|-------|
| **Category** | code/testing/process/architecture |
| **Context** | describe when this applies |
| **Insight** | the fundamental discovery |
| **Suggested Action** | what to do next time |
| **Applies To** | file patterns or components |
| **Linked Knowledge IDs** | optional canonical IDs this insight builds on |
| **Observed At** | RFC3339 timestamp (e.g. 2026-02-22T12:00:00Z) |
| **Score** | 0.0-1.0 (impact significance) |
| **Confidence** | 0.0-1.0 (insight quality) |
| **Applied** | |
-->

## Observations

Accepted: hosted token auth now lives at the framed protocol boundary, rejects missing or invalid tokens before dispatching to `LocalEngine`, and preserves `request_id`, topology, stable `unauthorized` code, and actionable message in remote error envelopes. `none` mode remains the default local-development posture, and docs/config now describe token enforcement plus the remaining mTLS non-claim.
